class_name KeyPrompt
extends Node2D
## Una tecla dibujada en pantalla que "se pulsa sola" para ensenar al jugador
## que tecla tocar. Estados: esperando (pulsacion en bucle), acierto (destello
## dorado y desvanecimiento) y fallo (sacudida). Reutilizable en fila para combos.

signal finished

@export var texture_idle: Texture2D
@export var texture_pressed: Texture2D
## Anchura de la tecla en pantalla, en px del lienzo.
@export var key_size_px: float = 220.0
## Periodo de la pulsacion en bucle y tiempo que permanece hundida.
@export var press_period: float = 1.4
@export var press_hold: float = 0.22
@export var symbol_color: Color = Color(0.68, 0.57, 0.4)
## Tinte y opacidad en reposo: apagado, para que no chille sobre la escena.
@export var base_tint: Color = Color(0.62, 0.58, 0.53, 0.7)
@export var success_flash: Color = Color(1.15, 1.05, 0.85, 0.95)

# Calibracion de las dos texturas (px de textura): anchura de la tecla, eje
# central, borde inferior y altura del centro de la cara superior. Sirven para
# anclar ambas por la base y colocar el simbolo sobre la cara en cada estado.
const CAL_IDLE := {"width": 828.0, "center_x": 626.0, "bottom": 992.0, "face_y": 520.0}
const CAL_PRESSED := {"width": 768.0, "center_x": 628.0, "bottom": 916.0, "face_y": 588.0}

@onready var cap: Sprite2D = $Cap
@onready var symbol: Node2D = $Symbol

var action: StringName = &""
## Visibilidad 0..1. La tecla usa el valor tal cual y el simbolo su cuadrado, para
## que la flecha, mas clara, no siga leyendose cuando la tecla ya casi no se ve.
var fade: float = 0.0:
	set(v):
		fade = v
		if is_node_ready():
			_apply_fade()
var _active := false
var _time := 0.0
var _pressed := false
var _done := false

func _ready() -> void:
	symbol.color = symbol_color
	symbol.size = 100.0
	if action != &"":
		symbol.set_from_action(action)
	_apply_state(false)
	modulate = Color(base_tint.r, base_tint.g, base_tint.b, 1.0)
	_apply_fade()

func _apply_fade() -> void:
	cap.self_modulate = Color(1, 1, 1, base_tint.a * fade)
	var k := 0.85 if _pressed else 1.0
	symbol.modulate = Color(k, k, k, fade * fade)

func setup(p_action: StringName) -> void:
	action = p_action
	if is_node_ready():
		symbol.set_from_action(action)

## Aparece con un fundido; si activa, empieza a pulsarse en bucle.
func appear(activate: bool) -> void:
	_done = false
	_active = activate
	_time = press_period - 0.5
	var tw := create_tween()
	tw.tween_property(self, "fade", 1.0, 0.8).set_trans(Tween.TRANS_SINE)

func set_active(activate: bool) -> void:
	_active = activate
	if not _active:
		_apply_state(false)

## Acierto: se hunde, destella y, si se pide, se desvanece.
func succeed(fade_out: bool) -> void:
	_active = false
	_done = true
	_apply_state(true)
	var rest := Color(base_tint.r, base_tint.g, base_tint.b, 1.0)
	var flash := Color(success_flash.r, success_flash.g, success_flash.b, 1.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate", flash, 0.08)
	tw.tween_property(self, "modulate", rest, 0.25)
	if fade_out:
		tw.tween_interval(0.15)
		tw.tween_property(self, "fade", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): finished.emit())

## Fallo: sacudida lateral y vuelve a esperar.
func fail() -> void:
	var x0 := position.x
	var tw := create_tween()
	for i in range(4):
		tw.tween_property(self, "position:x", x0 + (12.0 if i % 2 == 0 else -12.0), 0.04)
	tw.tween_property(self, "position:x", x0, 0.04)

func disappear() -> void:
	_active = false
	var tw := create_tween()
	tw.tween_property(self, "fade", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): finished.emit())

func _process(delta: float) -> void:
	if not _active or _done:
		return
	_time += delta
	var pressed := fmod(_time, press_period) < press_hold
	if pressed != _pressed:
		_apply_state(pressed)

func _apply_state(pressed: bool) -> void:
	_pressed = pressed
	var cal: Dictionary = CAL_PRESSED if pressed else CAL_IDLE
	var tex: Texture2D = texture_pressed if pressed else texture_idle
	if tex == null:
		tex = texture_idle
		cal = CAL_IDLE
	cap.texture = tex
	cap.centered = false
	var s: float = key_size_px / cal["width"]
	cap.scale = Vector2(s, s)
	cap.offset = Vector2(-cal["center_x"], -cal["bottom"])
	# El simbolo va sobre la cara superior; ocupa ~45% de la anchura de la tecla.
	symbol.position = Vector2(0, (cal["face_y"] - cal["bottom"]) * s)
	var sym_scale := key_size_px * 0.45 / 100.0
	symbol.scale = Vector2(sym_scale, sym_scale)
	_apply_fade()
