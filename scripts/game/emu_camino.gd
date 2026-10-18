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

## Cuando ya no se ve (se ha salido del encuadre): el peregrino espera a esto.
signal se_fue

const FICHA := "res://assets/world/camino_bosque/emu.json"
## Las paginas del atlas, precargadas (con la escena, en segundo plano: cargadas
## en _ready eran ~75 ms del tiron de entrada). Tantas como "paginas" de la ficha
## (si construye.py saca mas, se cargan aqui: anadirlas).
const PAGINAS: Array[Texture2D] = [preload("res://assets/world/camino_bosque/emu_0.png"),
	preload("res://assets/world/camino_bosque/emu_1.png"), preload("res://assets/world/camino_bosque/emu_2.png")]
## El relieve de cada pagina (normales y grosor, a la mitad: emu_camino.gdshader).
const RELIEVES: Array[Texture2D] = [preload("res://assets/world/camino_bosque/emu_relieve_0.png"),
	preload("res://assets/world/camino_bosque/emu_relieve_1.png"), preload("res://assets/world/camino_bosque/emu_relieve_2.png")]
const MEDIO := preload("res://assets/world/camino_bosque/medio.png")
## Sonidos de la embestida (raw/master_mason/camino_bosque/emu/sonidos.py).
const PISADAS: Array[AudioStream] = [preload("res://assets/audio/emu_pisada_1.wav"),
	preload("res://assets/audio/emu_pisada_2.wav"), preload("res://assets/audio/emu_pisada_3.wav"),
	preload("res://assets/audio/emu_pisada_4.wav")]
const AIRE := preload("res://assets/audio/emu_paso_aire.wav")
const GOLPE := preload("res://assets/audio/emu_golpe.wav")
const Imagenes := preload("res://scripts/game/imagenes_cache.gd")
const PANTALLA := Vector2(2912, 1632)
## El resplandor del fondo del pasillo (imagen): la luz viene de ahi.
const RESPLANDOR := Vector2(1440, 520)

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
## Hojas que levanta al pasar rozando (las de primer plano, fuera de foco, y
## las del suelo de delante); 0 = ninguna.
@export var hojas_al_pasar := 24
## Tension de la camara (camino_bosque.gd: se le acerca despacio) desde este
## fotograma del video hasta que embiste; al embestir se suelta en tension_suelta s.
@export var tension_desde := 17
@export var tension_suelta := 0.35
## Cuando saliendo ya solo le queda en pantalla esta fraccion de su ancho, se
## va del todo en salida_s: si no, quedaba en el borde una franja oscura como un
## tablon. Vale para salir por cualquier lado.
@export var salida_borde := 0.26
@export var salida_s := 0.12
@export var sombra := 0.45
## Penumbra que deja el cuerpo en el suelo de debajo (opacidad y ancho respecto
## al del emu).
@export var penumbra := 0.35
@export var penumbra_ancho := 1.3
@export_group("Pasa rozando")
## Al final de la embestida, tras el giro de cabeza, pasa rozando la camara.
## Los ultimos fotogramas del video eran una masa parda y borrosa que se
## deslizaba fuera despacio, con puntas de plumas como cuernos ("horrible").
## Desde tapa_desde (fotograma de la ficha) van tapa_vel veces mas deprisa,
## el cuerpo se oscurece (pegado al objetivo y a contraluz: le tapa la luz)
## y se va de foco con mucho barrido (tapa_desenfoque px de pantalla), todo en
## tapa_entra s. (Se probo a taparlo con un cuerpo pintado por shader: se leia
## como un rectangulo con rayas.)
@export var tapa_desde := 167
@export var tapa_vel := 1.8
@export var tapa_entra := 0.06
@export var tapa_desenfoque := 70.0
@export var tapa_estela := 1.6
## Pisadas encima de las del video (que se oian flojas y sin crecer): en que
## segundo del sonido del emu (medido en emu_camino.ogg) y a cuantos dB cada
## una; van creciendo, se le oye venir.
@export var pisadas_t := PackedFloat32Array([6.0, 6.33, 6.63, 6.95, 7.25])
@export var pisadas_db := PackedFloat32Array([-15.0, -11.0, -7.5, -4.5, -3.0])
## El aire que mueve al pasar (su pico cae cuando tapa) y el golpe grave.
@export var aire_db := -5.0
@export var golpe_db := -8.0

## La escena: camara (para el paralaje).
var controlador: Node

var _fotos: Array = []
var _paginas: Array[Texture2D] = []
var _relieves: Array[Texture2D] = []
var _con_aire := false
var _tapa := -1.0
var _pisada := 0
var _aire_puesto := false
var _efectos: Array[AudioStreamPlayer2D] = []
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
var _carga := 1 << 30      # primer fotograma de la embestida (la ventana crece)
var _soltando := -1.0
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
	for i in _fotos.size():
		if float(_fotos[i][13]) > _escala_pie * 1.03:
			_carga = i
			break
	for i in int(d.paginas):
		_paginas.append(PAGINAS[i] if i < PAGINAS.size() else load("res://assets/world/camino_bosque/emu_%d.png" % i))
		_relieves.append(RELIEVES[i] if i < RELIEVES.size() else load("res://assets/world/camino_bosque/emu_relieve_%d.png" % i))
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
	for i in 5:
		var a := AudioStreamPlayer2D.new()
		a.max_distance = 6000.0
		a.attenuation = 0.5
		add_child(a)
		_efectos.append(a)


## La luz de su sitio: la media de la imagen donde esta de pie (sin emu).
func _ambiente() -> Color:
	var fr: Array = _fotos[0]
	var o := Vector2(fr[11], fr[12])
	var s: float = fr[13]
	var img: Image = Imagenes.de(MEDIO)
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
	if _tapa >= 0.0:
		# pasando: su propio reloj, mas deprisa
		_tapa += delta
		_foto = tapa_desde + int(_tapa * _fps * tapa_vel)
	elif _sonido.playing:
		_foto = int(_sonido.get_playback_position() * _fps)
	elif _t >= inicio:
		# Sin sonido (o ya acabado): por el reloj propio.
		_foto = int((_t - inicio) * _fps)
	_sonar_embestida()
	if _foto >= _fotos.size():
		_irse()
		return
	var fr: Array = _fotos[_foto]
	if _tapa < 0.0 and _foto >= tapa_desde:
		_empezar_tapa(fr)
	_sonido.position = _a_pantalla(fr, Vector2(fr[9], fr[10]))
	# Saliendo por la derecha: cuando ya casi no queda nada en pantalla, fuera.
	var izq := _a_pantalla(fr, Vector2(fr[5], 0.0)).x
	var der := _a_pantalla(fr, Vector2(fr[5] + fr[7], 0.0)).x
	var dentro := (minf(der, PANTALLA.x) - maxf(izq, 0.0)) / maxf(der - izq, 1.0)
	if _yendose < 0.0 and float(fr[13]) >= _escala_fin * 0.99 and dentro < salida_borde:
		_yendose = 0.0
	if _yendose >= 0.0:
		_yendose += delta
		self_modulate.a = 1.0 - clampf(_yendose / salida_s, 0.0, 1.0)
		if self_modulate.a <= 0.0:
			_irse()
			return
	_tension(delta)
	queue_redraw()
	_sombra.queue_redraw()

## Pasa rozando: tapa la camara (golpe, rafaga de hojas, golpe grave) desde el
## canto derecho del emu en este fotograma.
func _empezar_tapa(fr: Array) -> void:
	_tapa = 0.0
	_sombra.visible = false
	if controlador:
		controlador.tension = 0.0
		if golpe > 0.0 and not _golpeado:
			_golpeado = true
			controlador.sacudir(golpe)
		var hojas := controlador.get_node_or_null("Hojas")
		if hojas and hojas.has_method("rafaga") and hojas_al_pasar > 0:
			hojas.rafaga(_a_pantalla(fr, Vector2(fr[9], fr[10])), hojas_al_pasar)
	_efecto(GOLPE, golpe_db, Vector2(PANTALLA.x * 0.35, PANTALLA.y * 0.6))

## Pisadas que crecen, y el aire, por el reloj del sonido del emu.
func _sonar_embestida() -> void:
	var pos := _sonido.get_playback_position() if _sonido.playing else _t - inicio
	if _pisada < pisadas_t.size() and pos >= pisadas_t[_pisada]:
		var db := pisadas_db[_pisada] if _pisada < pisadas_db.size() else 0.0
		var p := Vector2(930.0, 1500.0)
		if _foto < _fotos.size():
			var fr: Array = _fotos[_foto]
			p = _a_pantalla(fr, Vector2(fr[9], fr[10]))
		_efecto(PISADAS[_pisada % PISADAS.size()], db, p)
		_pisada += 1
	# el pico del aire (0,28 s) cuando tapa
	if not _aire_puesto and pos >= (tapa_desde - 0.28 * _fps) / _fps:
		_aire_puesto = true
		_efecto(AIRE, aire_db, Vector2(PANTALLA.x * 0.15, PANTALLA.y * 0.5))

func _efecto(stream: AudioStream, db: float, donde: Vector2) -> void:
	for a in _efectos:
		if not a.playing:
			a.stream = stream
			a.volume_db = db
			a.position = donde
			a.play()
			return

## Sin emu (ya salio otra vez: solo la primera): ni se ve ni suena.
func saltar() -> void:
	_acabado = true
	visible = false
	set_process(false)

func _irse() -> void:
	_acabado = true
	visible = false
	if controlador:
		controlador.tension = 0.0
	se_fue.emit()

## Mientras te mira, la camara se le acerca (sube la tension); al embestir, se
## suelta de golpe.
func _tension(delta: float) -> void:
	if not controlador:
		return
	if _foto < _carga:
		controlador.tension = smoothstep(float(tension_desde), float(_carga), float(_foto))
	else:
		if _soltando < 0.0:
			_soltando = 0.0
		_soltando += delta
		controlador.tension = (1.0 - clampf(_soltando / tension_suelta, 0.0, 1.0)) * 			smoothstep(float(tension_desde), float(_carga), float(_carga))

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
	if _foto >= _fotos.size():
		return
	var fr: Array = _fotos[_foto]
	var w := _ventana(fr)
	var o: Vector2 = w[0]
	var s: float = w[1]
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("relieve", _relieves[int(fr[0])])
	if controlador:
		mat.set_shader_parameter("claro", controlador.claro)
		# (el controlador se pone despues de _ready: aqui, la primera vez)
		if not _con_aire and controlador.has_node("AireVista"):
			_con_aire = true
			mat.set_shader_parameter("aire", controlador.get_node("AireVista").get_texture())
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
	var tapado := clampf(_tapa / tapa_entra, 0.0, 1.0) if _tapa >= 0.0 else 0.0
	tapado = smoothstep(0.0, 1.0, tapado)
	mat.set_shader_parameter("tapado", tapado)
	mat.set_shader_parameter("desenfoque_px", lerpf(desenfoque_px * maxf(0.3 * smoothstep(0.85, 1.0, cerca), saliendo),
		tapa_desenfoque, tapado))
	# Estela: lo que se ha movido su centro desde el fotograma anterior.
	var mov := Vector2.ZERO
	if _foto > 0:
		var ant: Array = _fotos[_foto - 1]
		mov = _a_pantalla(fr, Vector2(fr[9], fr[10])) - _a_pantalla(ant, Vector2(ant[9], ant[10]))
	mat.set_shader_parameter("estela", mov.limit_length(160.0) * lerpf(estela, tapa_estela, tapado))
	# Px de pantalla por texel del atlas (el atlas de la embestida va reducido).
	mat.set_shader_parameter("px_por_texel", s * float(fr[7]) / float(fr[3]))
	# Se dibuja con un borde de mas (lo que se abre el desenfoque y la estela,
	# en texels): si no, el canto blando se cortaba recto en el rectangulo. El
	# shader no lee fuera del trozo (region).
	var pagina := _paginas[int(fr[0])]
	var tam := Vector2(pagina.get_size())
	mat.set_shader_parameter("region", Vector4((fr[1] + 0.5) / tam.x, (fr[2] + 0.5) / tam.y,
		(fr[1] + fr[3] - 0.5) / tam.x, (fr[2] + fr[4] - 0.5) / tam.y))
	var px_tex := s * float(fr[7]) / float(fr[3])
	var abre := 0.0
	if _tapa >= 0.0 or mov.length() > 1.0:
		abre = (tapa_desenfoque + mov.limit_length(160.0).length() * tapa_estela * 0.5 + 12.0) / px_tex
	var v_tex := float(fr[7]) / float(fr[3])   # unidades de video por texel
	var dest := Rect2(o + (Vector2(fr[5], fr[6]) - Vector2(abre, abre) * v_tex) * s,
		(Vector2(fr[7], fr[8]) + Vector2(abre, abre) * 2.0 * v_tex) * s)
	draw_texture_rect_region(pagina, dest, Rect2(fr[1] - abre, fr[2] - abre, fr[3] + abre * 2.0, fr[4] + abre * 2.0))

func _dibujar_sombra() -> void:
	# Bajo los pies; cuando se salen por abajo del video, ya estan fuera de la
	# pantalla y no hay sombra.
	var fr: Array = _fotos[_foto]
	if int(fr[16]) == 0:
		return
	var s := float(_ventana(fr)[1])
	var p := _a_pantalla(fr, Vector2(fr[14], fr[15]))
	# Penumbra del cuerpo: con la luz detras, el bulto le quita al suelo de
	# debajo la luz de la niebla; cae hacia la camara (abajo, y algo hacia el
	# lado contrario al resplandor). Ancha y muy suave.
	var cuerpo := _a_pantalla(fr, Vector2(fr[9], fr[10]))
	var ancho_p := float(fr[7]) * s * penumbra_ancho
	var hacia := (p - RESPLANDOR).normalized()
	var cp := Vector2(lerpf(p.x, cuerpo.x, 0.5), p.y) + hacia * ancho_p * 0.12
	_sombra.draw_texture_rect(_tex_sombra, Rect2(cp - Vector2(ancho_p * 0.5, ancho_p * 0.22), Vector2(ancho_p, ancho_p * 0.44)),
		false, Color(0.02, 0.015, 0.01, penumbra))
	var ancho := 380.0 * s
	_sombra.draw_texture_rect(_tex_sombra, Rect2(p - Vector2(ancho * 0.5, ancho * 0.06), Vector2(ancho, ancho * 0.12)),
		false, Color(0.02, 0.015, 0.01, sombra))
