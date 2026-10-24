extends Node
## Compara en el juego la hoja de sprites de un personaje con su gemela (la que
## dejan las herramientas de tools/anim/hojas: limpiar.py, ...), sin tocar el
## personaje ni su escena: cambia el SpriteFrames de su sprite en caliente.
##   H   hoja actual / gemela (el mismo fotograma de la misma animacion)
##   K   fondo claro detras del personaje (donde mas se ven bordes y halos)
## El peregrino de perfil anade en marcha las animaciones de flotar (otras hojas,
## flotar.json): al cambiar se le vuelven a anadir.
## Desde el 2026-10-22 el juego ya usa la limpia: por defecto la "gemela" es la
## ANTERIOR (la hoja, el correr y el flotar de antes), para comparar.

@export var personaje: NodePath
@export_file("*.tres") var gemela := "res://resources/characters/peregrino_frames.tres"
@export var nombre_gemela := "ANTERIOR"
## La ficha de flotar de la gemela (las hojas de flotar van aparte, en rejilla); vacio: la misma.
@export_file("*.json") var flotar_gemela := "res://assets/characters/peregrino/flotar.json"
## Las medidas del bloque de correr de la gemela (otros fotogramas: ver usar_correr en
## peregrino.gd); vacio: las de siempre (el correr viejo, el de la hoja anterior).
@export_file("*.json") var correr_gemela := ""

var _sprite: AnimatedSprite2D
var _original: SpriteFrames
var _en_gemela := false
var _flotar_original := ""
var _correr_original := ""
var _claro: Node2D
var _rotulo: Label


func _ready() -> void:
	var p := get_node(personaje)
	_sprite = p.get_node("Sprite") as AnimatedSprite2D
	_original = _sprite.sprite_frames
	if "flotar_ficha" in p:
		_flotar_original = p.get("flotar_ficha")
	if "correr_ficha" in p:
		_correr_original = p.get("correr_ficha")
	_claro = Node2D.new()
	_claro.visible = false
	_claro.draw.connect(func() -> void: _claro.draw_rect(Rect2(-20000, -20000, 40000, 40000), Color(0.86, 0.85, 0.82)))
	p.get_parent().add_child.call_deferred(_claro)
	p.get_parent().move_child.call_deferred(_claro, 0)
	var capa := CanvasLayer.new()
	capa.layer = 50
	add_child(capa)
	_rotulo = Label.new()
	_rotulo.position = Vector2(40, 30)
	_rotulo.add_theme_font_size_override("font_size", 34)
	_rotulo.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 8)
	capa.add_child(_rotulo)
	_poner_rotulo()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_H:
		_cambiar()
	elif k.keycode == KEY_K:
		_claro.visible = not _claro.visible
		_poner_rotulo()


func _cambiar() -> void:
	_en_gemela = not _en_gemela
	var anim := _sprite.animation
	var f := _sprite.frame
	var prog := _sprite.frame_progress
	var jugando := _sprite.is_playing()
	_sprite.sprite_frames = load(gemela) if _en_gemela else _original
	var p := get_node(personaje)
	if p.has_method("_cargar_flotar"):
		if flotar_gemela != "" and "flotar_ficha" in p:
			p.set("flotar_ficha", flotar_gemela if _en_gemela else _flotar_original)
		p.call("_cargar_flotar")
	if p.has_method("usar_correr"):
		p.call("usar_correr", correr_gemela if _en_gemela else _correr_original)
	if _sprite.sprite_frames.has_animation(anim):
		_sprite.animation = anim
		_sprite.set_frame_and_progress(f, prog)
		if jugando:
			_sprite.play()
	_poner_rotulo()


func _poner_rotulo() -> void:
	_rotulo.text = "HOJA %s  (H cambia)     fondo %s  (K)" % [nombre_gemela if _en_gemela else "ACTUAL", "CLARO" if _claro.visible else "normal"]
