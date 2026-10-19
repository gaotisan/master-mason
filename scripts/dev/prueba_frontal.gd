extends Node2D
## Banco de pruebas del peregrino de frente y de espaldas. El personaje es el
## del juego, scenes/characters/peregrino_frontal.tscn (PeregrinoFrontal, ahi
## esta todo: andar, vuelta, reposo, correr, sacar y guardar el baston, la
## bola); aqui solo las teclas, la camara y un suelo para leer la profundidad.
##   abajo     anda hacia la camara (de frente) y crece con la cercania
##   arriba    se aleja (de espaldas) y encoge
##   suelto    termina el paso y se para con los pies juntos y respira
##   doble toque: correr (sin baston; parado o andando)
##   B         saca / guarda el baston (de frente o de espaldas; andando, se
##             para antes)
##   Z         camara: plano general / medio / primer plano (le sigue)
##   M         gastar un cuarto de magia (destello y estallido); C, otro color
##   O         sin bola / con bola (sin magia ni recarga: la garra vacia, para ver
##             la garra y el grosor del palo); empieza sin bola
##   R         vuelve al sitio de salida; Esc, sale
## guion: para grabarlo con --write-movie sin nadie al teclado, pasos
## [segundo, "abajo" | "arriba" | "", zoom(, con_baston)]; con guion se ignora
## el teclado.

const PEREGRINO := preload("res://scenes/characters/peregrino_frontal.tscn")
const SUELO_SALIDA := 1200.0     # la fila del suelo del juego, con escala 1
const ZOOMS := [1.0, 1.6, 2.5]

@export var guion: Array = []

var _peregrino: PeregrinoFrontal
var _camara: Camera2D
var _zoom := 0
var _info: Label
var _t := 0.0
var _fondo: Node2D


func _ready() -> void:
	# el viento de la intro (el autoload WindAmbience) suena en todas las escenas;
	# en esta de prueba no pinta nada
	WindAmbience.stop()
	# el fondo en su nodo, bien al fondo: asi lo que va detras del personaje
	# (el baston a la espalda visto de frente) puede ir por debajo del sprite
	# sin quedar tambien por debajo del fondo
	_fondo = Node2D.new()
	_fondo.z_index = -10
	_fondo.draw.connect(_dibujar_fondo)
	add_child(_fondo)
	_peregrino = PEREGRINO.instantiate()
	# sin bola de salida (O la pone): la garra y el palo se ven mejor
	_peregrino.magia = 0.0
	_peregrino.magia_recarga = 0.0
	_peregrino.position = Vector2(1456, SUELO_SALIDA)
	add_child(_peregrino)
	_camara = Camera2D.new()
	_camara.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(_camara)
	var capa := CanvasLayer.new()
	add_child(capa)
	var ayuda := Label.new()
	ayuda.text = "PRUEBA DEL ANDAR DE FRENTE / DE ESPALDAS\n" + \
		"abajo: hacia la camara (de frente)   arriba: alejandose (de espaldas)   doble toque: correr (sin baston; parado o andando)\n" + \
		"B: sacar / guardar el baston (de frente o de espaldas; andando, se para antes)   Z: plano general / medio / primer plano\n" + \
		"M: gastar magia   C: color   O: sin bola / con bola\n" + \
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
	_peregrino.colocado.connect(_seguirle)
	_seguirle()


func _input(event: InputEvent) -> void:
	if not guion.is_empty() and (event is InputEventKey or event is InputEventMouse):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_ESCAPE: get_tree().quit()
		KEY_R: _peregrino.reiniciar()
		KEY_Z: _zoom = (_zoom + 1) % ZOOMS.size()
		KEY_B: _peregrino.pulsar_baston()
		KEY_M: _peregrino.gastar(0.25)
		KEY_C: _peregrino.color += 1
		KEY_O:
			var con := _peregrino.magia_recarga > 0.0
			_peregrino.magia = 0.0 if con else 1.0
			_peregrino.magia_recarga = 0.0 if con else 0.05


## Va antes que el peregrino (el padre se procesa primero): le dice que quiere.
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
			_peregrino.cambiar_baston(bool(paso[3]))
	var quiere := ""
	if abajo and not arriba:
		quiere = "frente"
	elif arriba and not abajo:
		quiere = "espalda"
	_peregrino.quiere = quiere


## Tras moverse el peregrino: camara, suelo y letrero.
func _seguirle() -> void:
	var pies := _peregrino.to_global(_peregrino.pies)
	var escala := _peregrino.escala
	var z: float = ZOOMS[_zoom]
	_camara.zoom = Vector2(z, z)
	# a zoom 1 la camara no se mueve; con zoom encuadra al personaje: si cabe
	# entero, centrado; si no, la cabeza arriba y que se corten los pies
	var vista := Vector2(2912, 1632) / z
	var centro := Vector2(1456, 816)
	if z != 1.0:
		var alto := 345.0 * escala
		centro = pies - Vector2(0, alto / 2.0)
		if alto > vista.y * 0.9:
			centro.y = pies.y - alto - vista.y * 0.04 + vista.y / 2.0
	_camara.position = centro - vista / 2.0
	_fondo.queue_redraw()
	_info.text = "%s  fotograma %d   escala %.2f (2 = el master)   camara x%.1f   %s   magia %d%%" % [
		_peregrino.animacion, _peregrino.fotograma, escala, z,
		"con baston" if _peregrino.lleva_baston else "sin baston", roundi(_peregrino.magia * 100.0)]
	if _peregrino.aviso > 0.0:
		_info.text += "      CON EL BASTON EN LA MANO NO SE CORRE: B PARA GUARDARLO"


func _dibujar_fondo() -> void:
	var f := _fondo
	# fondo oscuro y suelo con lineas hacia el punto de fuga, para leer la
	# profundidad; las transversales a escalas fijas (0,5 / 0,75 / 1 / 1,5 / 2 / 2,5).
	# Con la camara de los videos (a media altura del personaje) el horizonte
	# queda muy cerca de los pies: el suelo se ve muy plano.
	const K := 165.0
	const HORIZONTE := SUELO_SALIDA - K
	f.draw_rect(Rect2(-6000, -6000, 15000, 15000), Color(0.08, 0.09, 0.11))
	f.draw_rect(Rect2(-6000, HORIZONTE, 15000, 9000), Color(0.13, 0.12, 0.11))
	var fuga := Vector2(1456, HORIZONTE)
	for i in range(-14, 15):
		var lejos := Vector2(1456 + i * 240, HORIZONTE + K * 3.0)
		f.draw_line(fuga.lerp(lejos, 0.12), lejos, Color(0.2, 0.19, 0.17), 2.0)
	for s in [0.5, 0.75, 1.0, 1.5, 2.0, 2.5]:
		var y: float = HORIZONTE + K * s
		f.draw_line(Vector2(-6000, y), Vector2(9000, y), Color(0.2, 0.19, 0.17), 2.0)
	# sombra bajo los pies
	f.draw_set_transform(_peregrino.to_global(_peregrino.pies), 0.0, Vector2(1.0, 0.22))
	f.draw_circle(Vector2.ZERO, 80.0 * _peregrino.escala, Color(0, 0, 0, 0.35))
	f.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
