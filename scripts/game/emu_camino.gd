extends Node2D
## El emu del principio de la escena: de pie en primer plano a la izquierda del
## camino, mira, eriza las plumas, se te queda mirando y se viene hacia la
## camara hasta salirse del encuadre.
##
## Sale de un video con croma (raw/master_mason/camino_bosque/emu/construye.py:
## fotogramas recortados en atlas, emu.json, y su sonido, emu_camino.ogg). El
## video va en la escena como una ventana (pantalla = o + s * video) y la
## trayectoria de la ventana viene calculada en la ficha, fotograma a
## fotograma: con el borde de abajo bajo el de la pantalla (se sale por abajo
## como en el video) y, en la embestida, crece y saca de la pantalla los bordes
## de arriba y de la izquierda antes de que el emu los toque: nunca se ve el
## corte. Donde y como se cambia en
## construye.py (PIES, ESCALA_PIE...), que ademas comprueba los bordes.
##
## El reloj es el del sonido (los fotogramas van con el, no se desincronizan).
## Antes de empezar se ve el primer fotograma, quieto: es la penumbra del
## fundido de entrada.

const FICHA := "res://assets/world/camino_bosque/emu.json"
const PANTALLA := Vector2(2912, 1632)

## Segundos desde el principio de la escena hasta que echa a andar el video.
@export var inicio := 1.5
## (A -8 los graznidos se oian poco: el usuario lo pidio mas alto.)
@export var emu_db := -1.0
## Desenfoque por cercania (px de pantalla con el emu pegado a la camara: la
## camara esta enfocada al bosque) y cuanto de la estela de movimiento se pinta.
@export var desenfoque_px := 22.0
@export var estela := 0.6
## Golpe de camara cuando pasa rozando (fuerza; 0 = sin golpe).
@export var golpe := 1.0
## Cuando saliendo ya solo le queda en pantalla esta fraccion de su ancho, se
## va del todo en salida_s: si no, quedaba en el borde una franja oscura como un
## tablon. Vale para salir por cualquier lado.
@export var salida_borde := 0.26
@export var salida_s := 0.12
@export var sombra := 0.45

## La escena: camara (para el paralaje).
var controlador: Node

var _fotos: Array = []
var _paginas: Array[Texture2D] = []
var _fps := 24.0
var _video := Vector2(1280, 720)
var _escala_pie := 1.0
var _escala_fin := 2.0
var _t := 0.0
var _foto := 0
var _acabado := false
var _golpeado := false
var _escala_max := 2.0
var _yendose := -1.0
var _sombra: Node2D
var _tex_sombra: Texture2D
@onready var _sonido: AudioStreamPlayer2D = $Sonido

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var f := FileAccess.open(FICHA, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	_fotos = d.fotogramas
	_fps = float(d.fps)
	_video = Vector2(d.video[0], d.video[1])
	_escala_pie = float(d.escala_pie)
	_escala_fin = float(d.escala_fin)
	for fr in _fotos:
		_escala_max = maxf(_escala_max, float(fr[13]))
	for i in int(d.paginas):
		_paginas.append(load("res://assets/world/camino_bosque/emu_%d.png" % i))
	_sonido.volume_db = emu_db
	# Sombra de contacto: un ovalo blando por detras del emu.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_tex_sombra = t
	_sombra = Node2D.new()
	_sombra.show_behind_parent = true
	_sombra.draw.connect(_dibujar_sombra)
	add_child(_sombra)
	(material as ShaderMaterial).set_shader_parameter("ambiente", _ambiente())

## La luz de su sitio: la media de la imagen donde esta de pie (sin emu).
func _ambiente() -> Color:
	var fr: Array = _fotos[0]
	var o := Vector2(fr[11], fr[12])
	var s: float = fr[13]
	var img: Image = load("res://assets/world/camino_bosque/medio.png").get_image()
	var suma := Color(0, 0, 0)
	var n := 0
	for i in 9:
		for j in 9:
			var p := o + Vector2(fr[5] + fr[7] * (i + 0.5) / 9.0, fr[6] + fr[8] * (j + 0.5) / 9.0) * s
			var x := clampi(int(p.x / PANTALLA.x * img.get_width()), 0, img.get_width() - 1)
			var y := clampi(int(p.y / PANTALLA.y * img.get_height()), 0, img.get_height() - 1)
			suma += img.get_pixel(x, y)
			n += 1
	return Color(suma.r / n, suma.g / n, suma.b / n)

func _process(delta: float) -> void:
	if _acabado:
		return
	_t += delta
	if _t >= inicio and not _sonido.playing and _foto == 0:
		_sonido.play()
	if _sonido.playing:
		_foto = int(_sonido.get_playback_position() * _fps)
	elif _t >= inicio:
		# Sin sonido (o ya acabado): por el reloj propio.
		_foto = int((_t - inicio) * _fps)
	if _foto >= _fotos.size():
		_acabado = true
		visible = false
		return
	var fr: Array = _fotos[_foto]
	_sonido.position = _a_pantalla(fr, Vector2(fr[9], fr[10]))
	# Saliendo por la derecha: cuando ya casi no queda nada en pantalla, fuera.
	var izq := _a_pantalla(fr, Vector2(fr[5], 0.0)).x
	var der := _a_pantalla(fr, Vector2(fr[5] + fr[7], 0.0)).x
	var dentro := (minf(der, PANTALLA.x) - maxf(izq, 0.0)) / maxf(der - izq, 1.0)
	if _yendose < 0.0 and float(fr[13]) >= _escala_fin * 0.99 and dentro < salida_borde:
		_yendose = 0.0
	if _yendose >= 0.0:
		_yendose += delta
		modulate.a = 1.0 - clampf(_yendose / salida_s, 0.0, 1.0)
		if modulate.a <= 0.0:
			_acabado = true
			visible = false
			return
	# Golpe de camara al pasar rozando (cuando ya casi llena la pantalla).
	if not _golpeado and golpe > 0.0 and controlador and float(fr[13]) > _escala_fin * 1.04:
		_golpeado = true
		controlador.sacudir(golpe)
	queue_redraw()
	_sombra.queue_redraw()

## Ventana del fotograma: esquina en pantalla (con la camara de la escena: el
## emu esta delante) y escala.
func _ventana(fr: Array) -> Array:
	var o := Vector2(fr[11], fr[12])
	if controlador:
		o += controlador.paralaje(Vector2(930.0, 1615.0), 0.97)
	return [o, float(fr[13])]

func _a_pantalla(fr: Array, v: Vector2) -> Vector2:
	var w := _ventana(fr)
	return w[0] + v * float(w[1])

func _draw() -> void:
	var fr: Array = _fotos[_foto]
	var w := _ventana(fr)
	var o: Vector2 = w[0]
	var s: float = w[1]
	var mat := material as ShaderMaterial
	# Bordes del cuadro del video en pantalla: el shader funde el emu ahi por si
	# alguno cayera dentro (no deberia: construye.py lo comprueba).
	mat.set_shader_parameter("cuadro", Vector4(o.x, o.y, _video.x * s, _video.y * s))
	mat.set_shader_parameter("pies_y", _a_pantalla(fr, Vector2(fr[14], fr[15])).y)
	var cerca := clampf(inverse_lerp(_escala_pie, _escala_fin, s), 0.0, 1.0)
	mat.set_shader_parameter("cerca", cerca)
	# Desenfoque: la camara esta enfocada al bosque; muy cerca, el emu se va de
	# foco (asi ademas la poca definicion del video de cerca se lee como optica).
	# Solo al pasar rozando (la salida), y un poco justo antes: mientras viene
	# por el camino tiene que verse nitido (si no, era una mancha sin plumas).
	var saliendo := clampf(inverse_lerp(_escala_fin, _escala_max, s), 0.0, 1.0)
	mat.set_shader_parameter("desenfoque_px", desenfoque_px * maxf(0.3 * smoothstep(0.85, 1.0, cerca), saliendo))
	# Estela: lo que se ha movido su centro desde el fotograma anterior.
	var mov := Vector2.ZERO
	if _foto > 0:
		var ant: Array = _fotos[_foto - 1]
		mov = _a_pantalla(fr, Vector2(fr[9], fr[10])) - _a_pantalla(ant, Vector2(ant[9], ant[10]))
	mat.set_shader_parameter("estela", mov.limit_length(160.0) * estela)
	# Px de pantalla por texel del atlas (el atlas de la embestida va reducido).
	mat.set_shader_parameter("px_por_texel", s * float(fr[7]) / float(fr[3]))
	var dest := Rect2(o + Vector2(fr[5], fr[6]) * s, Vector2(fr[7], fr[8]) * s)
	draw_texture_rect_region(_paginas[int(fr[0])], dest, Rect2(fr[1], fr[2], fr[3], fr[4]))

func _dibujar_sombra() -> void:
	# Bajo los pies; cuando se salen por abajo del video, ya estan fuera de la
	# pantalla y no hay sombra.
	var fr: Array = _fotos[_foto]
	if int(fr[16]) == 0:
		return
	var s := float(_ventana(fr)[1])
	var p := _a_pantalla(fr, Vector2(fr[14], fr[15]))
	var ancho := 380.0 * s
	_sombra.draw_texture_rect(_tex_sombra, Rect2(p - Vector2(ancho * 0.5, ancho * 0.06), Vector2(ancho, ancho * 0.12)),
		false, Color(0.02, 0.015, 0.01, sombra))
