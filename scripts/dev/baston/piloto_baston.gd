extends "res://scripts/dev/piloto.gd"
## Piloto del baston (PRUEBA). Le cuelga a Magnus scenes/dev/baston.tscn sin
## tocar magnus.tscn. Teclas, ademas de las de Magnus:
##   B  baston a la espalda / en la mano
##   G  guardarlo del todo / sacarlo (a la espalda)
##   M  gastar un cuarto de magia
##   C  siguiente color
## eventos: como guion pero para el baston, [segundo, "mano"|"baston"|"gastar"|"color"],
## para grabarlo con --write-movie sin nadie al teclado.

const BASTON := preload("res://scenes/dev/baston.tscn")

@export var eventos: Array = []
@export var gasto := 0.25
@export var magia_inicial := 1.0
## Grabando: se comen las teclas de verdad (ESC incluido, que cerraria el juego)
## por si la ventana de la grabacion coge el foco mientras se escribe en otra.
@export var ignorar_teclado := false
## Para mirar la bola de cerca: >1 acerca la camara y la pone a seguir a Magnus.
@export var zoom := 1.0
@export var camara: NodePath = ^"../DarkStage/Camera"

var _baston: Node2D
var _j := 0
var _ayuda: Label

func _ready() -> void:
	super()
	var p := get_node(personaje)
	_baston = BASTON.instantiate()
	p.add_child(_baston)
	_baston.magia = magia_inicial
	# Grabando: la salida con ESC (autoload GlobalExit) ve las teclas antes que
	# este piloto; si la ventana de la grabacion coge el foco, un ESC suelto la
	# cortaba a medias.
	if ignorar_teclado:
		var salida := get_node_or_null("/root/GlobalExit")
		if salida:
			salida.set_process_input(false)
	var capa := CanvasLayer.new()
	add_child(capa)
	_ayuda = Label.new()
	_ayuda.position = Vector2(40, 30)
	_ayuda.add_theme_font_size_override("font_size", 28)
	_ayuda.modulate = Color(1, 1, 1, 0.45)
	capa.add_child(_ayuda)

func _physics_process(delta: float) -> void:
	super(delta)
	while _j < eventos.size() and eventos[_j][0] <= _t:
		_hacer(eventos[_j][1])
		_j += 1
	if zoom > 1.0:
		var cam := get_node(camara) as Camera2D
		cam.zoom = Vector2(zoom, zoom)
		cam.position = get_node(personaje).position + Vector2(0, -250)
	_ayuda.text = "B espalda/mano   G guardar   M gastar   C color      %s   magia %d%%" % [
		"EN LA MANO" if _baston.en_mano else "a la espalda", roundi(_baston.magia * 100.0)]

func _input(event: InputEvent) -> void:
	if ignorar_teclado and (event is InputEventKey or event is InputEventMouse):
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_B: _hacer("mano")
		KEY_G: _hacer("baston")
		KEY_M: _hacer("gastar")
		KEY_C: _hacer("color")

func _hacer(que: String) -> void:
	match que:
		"mano": _baston.alternar_mano()
		"mano_directo": _baston.poner_en_mano(not _baston.en_mano)   # sin animacion (grabaciones)
		"baston": _baston.alternar()
		"gastar": _baston.gastar(gasto)
		"color": _baston.siguiente_color()
