extends Node2D
## Prueba del andar de frente y de espaldas, con y sin baston, y la vuelta entre
## ellos, aparte del peregrino del juego: magnus.gd no se toca.
##   abajo     anda hacia la camara (de frente) y crece con la cercania
##   arriba    se aleja (de espaldas) y encoge
##   suelto    se queda quieto en el fotograma en que iba (aun no hay reposo)
##   B         con baston / sin baston
##   Z         camara: plano general / medio / primer plano (le sigue)
##   M         gastar un cuarto de magia (destello y estallido); C, otro color
##   R         vuelve al sitio de salida; Esc, sale
## guion: para grabarlo con --write-movie sin nadie al teclado, pasos
## [segundo, "abajo" | "arriba" | "", zoom(, con_baston)]; con guion se ignora
## el teclado.
##
## El avance va atado al fotograma: cada fotograma que pasa, el tamano cambia lo
## mismo que en el video (alli 1/alto es una recta en el tiempo, camara fija y
## paso constante), asi que los pies no patinan. La fila del suelo sale del
## tamano con el horizonte del propio video (baja).
##
## LA VUELTA (con baston): al cambiar de sentido da la vuelta en el sitio
## (vuelta_frontal; de espaldas a frente, la misma al reves) y sigue andando por
## el fotograma 5 del otro andar, que es contra el que se registro. Los videos
## redibujan la tunica a su manera: en cada enganche un fundido corto (FUNDIDO)
## tapa el cambio de textura. Sin baston aun no hay vuelta: cambia de golpe.
##
## La bola del baston, como en el de perfil con el baston en la mano: la madera
## ya viene en el dibujo y la bola es la de scenes/dev/baston.tscn (orbe, luz,
## chispas) puesta por codigo, por detras del sprite, donde dice frontal.json
## (raw/master_mason/anim/baston/frontal.py): en el hueco de la garra.
## El baston del video de frente no tiene garra (acababa en pincho): en la hoja
## se le ha borrado el pincho y la garra (garra_frente.png, la del baston de
## Gemini) va aqui como capa encima del sprite, donde y con la inclinacion que
## dice frontal.json; la bola, detras, en su hueco. De espaldas y en la vuelta
## la garra ya viene en el dibujo. La bola es scenes/dev/baston.tscn sin su
## script (baston.gd va colgado de Magnus).

const FRAMES := preload("res://resources/characters/magnus_frames.tres")
const BASTON := preload("res://scenes/dev/baston.tscn")
const FRONTAL := "res://assets/characters/baston/frontal.json"
const ORBE_EN_MADERA := Vector2(-0.6, -24)   # posicion del Orbe dentro de Madera
const COLORES: Array[Color] = [
	Color(1.0, 0.62, 0.18), Color(0.35, 0.75, 1.0), Color(0.55, 1.0, 0.45),
	Color(0.85, 0.45, 1.0), Color(1.0, 0.3, 0.25)]
const RECARGA := 0.05            # magia por segundo, como baston.gd

## Por andar: fps, cambio de 1/escala por fotograma y lo que baja el suelo por
## unidad de escala. Parejos: los ciclos de dos pasos duran 1,37 s y avanzan lo
## mismo (1/escala cambia 0,077 por ciclo); la escala de cada video (a que
## distancia esta la escala 1) depende de su camara, que no se conoce, y sea la
## que sea los pies no patinan. baja: suelo - horizonte es proporcional al
## tamano y cada video tiene la camara a su altura (ajuste.txt de cada job).
const ANDAR := {
	"andar_frente":      {"fps": 30.0, "paso": -0.077 / 41.0, "baja": 143.8},
	"andar_espalda":     {"fps": 21.2, "paso": 0.077 / 29.0, "baja": 155.3},
	"andar_frente_sin":  {"fps": 24.8, "paso": -0.077 / 34.0, "baja": 180.7},
	"andar_espalda_sin": {"fps": 21.2, "paso": 0.077 / 29.0, "baja": 157.1},
}
const VUELTA := "vuelta_frontal"
const VUELTA_FPS := 30.0
const ENGANCHE := 4              # vuelta <-> andares por su c_005
const FUNDIDO := 0.18            # s (a 0,12 aun se notaba el cambio de tunica al entrar)
const SUELO_SALIDA := 1200.0     # la fila del suelo del juego, con escala 1
const ESCALA_MIN := 0.45
const ESCALA_MAX := 2.6          # 2 = el master (que ya es el video x1,25)
const ZOOMS := [1.0, 1.6, 2.5]

@export var guion: Array = []

var _sprite: AnimatedSprite2D
var _fantasma: Sprite2D
var _camara: Camera2D
var _escala := 1.0
var _y := SUELO_SALIDA
var _acum := 0.0
var _zoom := 0
var _info: Label
var _t := 0.0
var _bola: Node2D
var _garra: Sprite2D
var _orbes: Dictionary = {}
var _magia := 1.0
var _mostrada := 1.0
var _destello := 0.0
var _color := 0
var _con_baston := true
var _cara := "frente"            # hacia donde mira: frente / espalda
var _girando := 0                # 0, +1 (frente -> espalda), -1 (al reves)
var _fundido := 0.0
var _bola_antes := Vector2.ZERO   # en los enganches la bola va de donde estaba a su sitio
var _garra_fundiendo := false     # y la garra pegada (andar_frente) se desvanece


func _ready() -> void:
	_orbes = JSON.parse_string(FileAccess.open(FRONTAL, FileAccess.READ).get_as_text())
	# la bola, antes que el sprite: se dibuja detras (la garra le queda delante)
	_bola = BASTON.instantiate()
	_bola.set_script(null)
	_bola.z_index = 0
	add_child(_bola)
	_bola.get_node("Madera").self_modulate.a = 0.0
	_bola.get_node("Madera/Funda").modulate.a = 0.0
	_bola.get_node("Madera/Chispas").emitting = true
	_poner_color()
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	add_child(_sprite)
	# el fotograma de antes, encima, desvaneciendose en los enganches
	_fantasma = Sprite2D.new()
	_fantasma.visible = false
	add_child(_fantasma)
	_poner_anim("andar_frente", 0)
	# la garra del de frente, encima del sprite (la bola le queda detras)
	_garra = Sprite2D.new()
	_garra.centered = false
	add_child(_garra)
	_camara = Camera2D.new()
	_camara.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(_camara)
	var capa := CanvasLayer.new()
	add_child(capa)
	var ayuda := Label.new()
	ayuda.text = "PRUEBA DEL ANDAR DE FRENTE / DE ESPALDAS\n" + \
		"abajo: hacia la camara (de frente)   arriba: alejandose (de espaldas)\n" + \
		"B: con / sin baston   Z: plano general / medio / primer plano   M: gastar magia   C: color\n" + \
		"R: volver al sitio   Esc: salir"
	ayuda.position = Vector2(60, 50)
	ayuda.add_theme_font_size_override("font_size", 40)
	ayuda.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	capa.add_child(ayuda)
	_info = Label.new()
	_info.position = Vector2(60, 1540)
	_info.add_theme_font_size_override("font_size", 32)
	_info.add_theme_color_override("font_color", Color(0.6, 0.58, 0.52))
	capa.add_child(_info)
	_colocar()


func _input(event: InputEvent) -> void:
	if not guion.is_empty() and (event is InputEventKey or event is InputEventMouse):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_ESCAPE: get_tree().quit()
		KEY_R:
			_escala = 1.0
			_y = SUELO_SALIDA
			_colocar()
		KEY_Z: _zoom = (_zoom + 1) % ZOOMS.size()
		KEY_B: _cambiar_baston(not _con_baston)
		KEY_M: _gastar(0.25)
		KEY_C:
			_color = (_color + 1) % COLORES.size()
			_poner_color()


func _andar_de(cara: String) -> String:
	return "andar_" + cara + ("" if _con_baston else "_sin")


## Cambia de animacion (y de casilla: la vuelta es mas alta), con fundido si se pide.
func _poner_anim(nombre: String, fotograma: int, fundir := false) -> void:
	if fundir:
		_fantasma.texture = _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
		_fantasma.offset = _sprite.offset
		_fundido = 1.0
		_bola_antes = _bola.position
		_garra_fundiendo = _garra.visible
	_sprite.animation = nombre
	_sprite.frame = fotograma
	_sprite.pause()
	var alto := _sprite.sprite_frames.get_frame_texture(nombre, 0).get_size().y
	_sprite.offset = Vector2(0, -(alto / 2.0 - 15.0))   # el suelo a 15 del borde, sea cual sea la casilla
	_acum = 0.0


func _cambiar_baston(si: bool) -> void:
	if si == _con_baston or _girando != 0:
		return
	_con_baston = si
	var anim := _andar_de(_cara)
	_poner_anim(anim, mini(_sprite.frame, _sprite.sprite_frames.get_frame_count(anim) - 1), true)


func _gastar(cuanto: float) -> void:
	if _magia < cuanto:
		_destello = 0.25
		return
	_magia -= cuanto
	_destello = 1.0
	(_bola.get_node("Madera/Estallido") as CPUParticles2D).restart()


func _poner_color() -> void:
	var c: Color = COLORES[_color]
	for n in ["Madera/Orbe", "Madera/Luz"]:
		((_bola.get_node(n) as Sprite2D).material as ShaderMaterial).set_shader_parameter("color", Vector3(c.r, c.g, c.b))
	for n in ["Madera/Recarga", "Madera/Estallido", "Madera/Chispas"]:
		(_bola.get_node(n) as CPUParticles2D).color = c.lightened(0.25)


## La magia como en baston.gd: se recarga sola y la bola llega poco a poco.
func _magia_bola(delta: float) -> void:
	_magia = minf(1.0, _magia + RECARGA * delta)
	_mostrada = lerpf(_mostrada, _magia, 1.0 - exp(-4.0 * delta))
	_destello = move_toward(_destello, 0.0, 3.5 * delta)
	for n in ["Madera/Orbe", "Madera/Luz"]:
		var m := (_bola.get_node(n) as Sprite2D).material as ShaderMaterial
		m.set_shader_parameter("carga", _mostrada)
		m.set_shader_parameter("destello", _destello)
	(_bola.get_node("Madera/Recarga") as CPUParticles2D).emitting = _magia < 0.999
	(_bola.get_node("Madera/Chispas") as CPUParticles2D).emitting = _mostrada > 0.97


func _process(delta: float) -> void:
	var abajo := Input.is_action_pressed("agacharse") or Input.is_key_pressed(KEY_DOWN)
	var arriba := Input.is_action_pressed("saltar") or Input.is_key_pressed(KEY_UP)
	if not guion.is_empty():
		_t += delta
		var paso: Array = guion[0]
		for g in guion:
			if g[0] <= _t:
				paso = g
		abajo = paso[1] == "abajo"
		arriba = paso[1] == "arriba"
		_zoom = ZOOMS.find(float(paso[2]))
		if paso.size() > 3:
			_cambiar_baston(bool(paso[3]))
	var quiere := ""
	if abajo and not arriba:
		quiere = "frente"
	elif arriba and not abajo:
		quiere = "espalda"

	if _girando != 0:
		_seguir_vuelta(delta)
	elif quiere != "" and quiere != _cara:
		if _con_baston:
			# a la vuelta: hacia delante de frente a espaldas, al reves si no
			_girando = 1 if quiere == "espalda" else -1
			var n := _sprite.sprite_frames.get_frame_count(VUELTA)
			_poner_anim(VUELTA, 0 if _girando > 0 else n - 1, true)
		else:
			_cara = quiere
			_poner_anim(_andar_de(_cara), 0, true)
	elif quiere != "":
		var anim := _andar_de(_cara)
		if (_cara == "frente" and _escala < ESCALA_MAX) or (_cara == "espalda" and _escala > ESCALA_MIN):
			if _sprite.animation != anim:
				_poner_anim(anim, 0, true)
			_andar(anim, delta)

	_fundido = move_toward(_fundido, 0.0, delta / FUNDIDO)
	_magia_bola(delta)
	_colocar()
	_info.text = "%s  fotograma %d   escala %.2f (2 = el master)   camara x%.1f   %s   magia %d%%" % [
		_sprite.animation, _sprite.frame, _escala, ZOOMS[_zoom],
		"con baston" if _con_baston else "sin baston", roundi(_magia * 100.0)]


## Fotogramas por tiempo, y el tamano con cada fotograma.
func _andar(anim: String, delta: float) -> void:
	var d: Dictionary = ANDAR[anim]
	_acum += delta * d["fps"]
	var n := _sprite.sprite_frames.get_frame_count(anim)
	while _acum >= 1.0:
		_acum -= 1.0
		_sprite.frame = (_sprite.frame + 1) % n
		var antes := _escala
		_escala = clampf(1.0 / (1.0 / _escala + d["paso"]), ESCALA_MIN, ESCALA_MAX)
		_y += d["baja"] * (_escala - antes)


## La vuelta va en el sitio, a su ritmo; al acabar, el otro andar por ENGANCHE.
func _seguir_vuelta(delta: float) -> void:
	_acum += delta * VUELTA_FPS
	var n := _sprite.sprite_frames.get_frame_count(VUELTA)
	while _acum >= 1.0:
		_acum -= 1.0
		var f := _sprite.frame + _girando
		if f < 0 or f >= n:
			_cara = "espalda" if _girando > 0 else "frente"
			_girando = 0
			_poner_anim(_andar_de(_cara), ENGANCHE, true)
			return
		_sprite.frame = f


func _colocar() -> void:
	_sprite.position = Vector2(1456, _y)
	_sprite.scale = Vector2.ONE * _escala
	_fantasma.visible = _fundido > 0.0
	_fantasma.position = _sprite.position
	_fantasma.scale = _sprite.scale
	_fantasma.modulate.a = _fundido
	# bola y garra, solo con el baston y en lo que tenga datos
	var d = _orbes.get(String(_sprite.animation)) if _con_baston else null
	_bola.visible = d != null
	var con_garra: bool = d != null and d.has("garra")
	if d != null:
		var o: Array = d["orbe"][mini(_sprite.frame, d["orbe"].size() - 1)]
		var e: float = d["escala_bola"]
		_bola.scale = Vector2.ONE * _escala * e
		_bola.position = _sprite.position + (_sprite.offset + Vector2(o[0], o[1])) * _escala \
			- ORBE_EN_MADERA * _escala * e
		if _fundido > 0.0 and _bola_antes != Vector2.ZERO:
			_bola.position = _bola.position.lerp(_bola_antes, _fundido)
	# la garra pegada va en el andar de frente; al salir de el se desvanece con
	# el fundido en su ultima postura (la de la vuelta ya viene en el dibujo)
	if not con_garra and _garra_fundiendo and _fundido > 0.0:
		_garra.modulate.a = _fundido
	else:
		_garra_fundiendo = false
		_garra.modulate.a = 1.0 - _fundido      # y al volver a el, aparece con el fundido
		_garra.visible = con_garra
	if con_garra:
		if _garra.texture == null:
			_garra.texture = load(d["garra_textura"])
			_garra.offset = -Vector2(d["garra_pivote"][0], d["garra_pivote"][1])
		var g: Array = d["garra"][mini(_sprite.frame, d["garra"].size() - 1)]
		_garra.position = _sprite.position + (_sprite.offset + Vector2(g[0], g[1])) * _escala
		_garra.rotation = g[2]
		_garra.scale = Vector2.ONE * _escala * float(d["garra_escala"])
	var z: float = ZOOMS[_zoom]
	_camara.zoom = Vector2(z, z)
	# a zoom 1 la camara no se mueve; con zoom encuadra al personaje: si cabe
	# entero, centrado; si no, la cabeza arriba y que se corten los pies
	var vista := Vector2(2912, 1632) / z
	var centro := Vector2(1456, 816)
	if z != 1.0:
		var alto := 345.0 * _escala
		centro = _sprite.position - Vector2(0, alto / 2.0)
		if alto > vista.y * 0.9:
			centro.y = _sprite.position.y - alto - vista.y * 0.04 + vista.y / 2.0
	_camara.position = centro - vista / 2.0
	queue_redraw()


func _draw() -> void:
	# fondo oscuro y suelo con lineas hacia el punto de fuga, para leer la
	# profundidad; las transversales a escalas fijas (0,5 / 0,75 / 1 / 1,5 / 2 / 2,5).
	# Con la camara de los videos (a media altura del personaje) el horizonte
	# queda muy cerca de los pies: el suelo se ve muy plano.
	const K := 165.0
	const HORIZONTE := SUELO_SALIDA - K
	draw_rect(Rect2(-6000, -6000, 15000, 15000), Color(0.08, 0.09, 0.11))
	draw_rect(Rect2(-6000, HORIZONTE, 15000, 9000), Color(0.13, 0.12, 0.11))
	var fuga := Vector2(1456, HORIZONTE)
	for i in range(-14, 15):
		var lejos := Vector2(1456 + i * 240, HORIZONTE + K * 3.0)
		draw_line(fuga.lerp(lejos, 0.12), lejos, Color(0.2, 0.19, 0.17), 2.0)
	for s in [0.5, 0.75, 1.0, 1.5, 2.0, 2.5]:
		var y: float = HORIZONTE + K * s
		draw_line(Vector2(-6000, y), Vector2(9000, y), Color(0.2, 0.19, 0.17), 2.0)
	# sombra bajo los pies
	draw_set_transform(_sprite.position, 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 80.0 * _escala, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
