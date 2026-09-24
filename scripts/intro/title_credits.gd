extends CanvasLayer
## Creditos de apertura, sobre el negro del arranque de la pantalla de titulo.
## Dos tarjetas, una detras de otra:
##   1. Created by / SANTIAGO OCHOA
##   2. Based on the short story / El maestro Constructor / by Andres Ramos
## Se cuentan con luz, como el resto de la pantalla: las letras estan ahi en la
## oscuridad y una luz las recorre de izquierda a derecha, las enciende al pasar y
## se las lleva por detras. Mientras dura la luz, el bloque crece muy poco a poco
## y sube un pelo, como en los titulos de cine. (No se anima el tracking: el
## espaciado de la fuente va en pixeles enteros y daba tirones.)
## La letra es Cinzel, capitales romanas del mismo corte que el titulo tallado.
## El nombre y el titulo del relato van en dorado; las lineas pequenas, en un
## dorado apagado, como piedra con menos luz.
##
## duration() dice cuanto dura todo; el controlador de la pantalla arranca las
## velas cuando acaban los creditos.

signal finished

## Silencio en negro antes de la primera tarjeta.
@export var lead_in: float = 0.7
## Cuanto tarda la luz en cruzar las letras (la cabeza del charco).
@export var sweep_in: float = 1.7
## Cuanto se quedan encendidas del todo antes de que la cola empiece a irse.
@export var hold: float = 0.9
## Cuanto tarda la cola en apagarlas.
@export var sweep_out: float = 1.5
## Negro entre tarjetas.
@export var gap: float = 0.5
## Negro despues de la ultima tarjeta, antes de que empiecen las velas.
@export var tail_black: float = 0.5
## Anchura del charco de luz, en fraccion del ancho de pantalla.
@export var softness: float = 0.32
## Espaciado entre letras, en px. Fijo: animarlo va a saltos de pixel entero.
@export var spacing: int = 12
## Cuanto crece el bloque mientras esta encendido (1.03 = un 3%). Es lo que da la
## sensacion de que las letras se abren, pero continuo.
@export var grow: float = 1.03
## Deriva vertical de la tarjeta mientras esta encendida, en px (hacia arriba).
@export var drift: float = 10.0

const FONT_PATH := "res://assets/fonts/Cinzel-Variable.ttf"
const SHADER_PATH := "res://scripts/intro/credit_reveal.gdshader"
const GOLD := Color(0.93, 0.76, 0.46)
const GOLD_DIM := Color(0.68, 0.55, 0.35)
const SHADOW := Color(0.08, 0.04, 0.0, 0.7)

## Cada tarjeta: lineas con texto, tamano y si va en dorado vivo. Las lineas
## pequenas van en mayusculas (Cinzel no tiene minusculas de verdad).
const CARDS := [
	[
		{"text": "Created by", "size": 46, "bright": false, "upper": true},
		{"text": "SANTIAGO OCHOA", "size": 118, "bright": true},
	],
	[
		{"text": "Based on the short story", "size": 46, "bright": false, "upper": true},
		{"text": "El maestro Constructor", "size": 108, "bright": true},
		{"text": "by Andrés Ramos", "size": 46, "bright": false, "upper": true},
	],
]

var _cards: Array[Control] = []
var _mats: Array[ShaderMaterial] = []
var _base_font: Font

func _ready() -> void:
	layer = 101
	_base_font = load(FONT_PATH)
	var shader: Shader = load(SHADER_PATH)
	var vp := get_viewport().get_visible_rect().size
	for card in CARDS:
		_cards.append(_build_card(card, shader, vp))
	_run()

func duration() -> float:
	var card_time := sweep_in + hold + sweep_out
	return lead_in + CARDS.size() * card_time + (CARDS.size() - 1) * gap + tail_black

## Construye una tarjeta: un VBox centrado con un Label por linea. Cada tarjeta
## lleva su propia fuente (para animar el tracking) y su propio material.
func _build_card(lines: Array, shader: Shader, vp: Vector2) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var font := FontVariation.new()
	font.base_font = _base_font
	font.spacing_glyph = spacing
	# El crecimiento se hace desde el centro de la pantalla.
	root.pivot_offset = vp * 0.5

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("width", vp.x)
	mat.set_shader_parameter("softness", softness)
	mat.set_shader_parameter("head", -1.0)
	mat.set_shader_parameter("tail", -1.5)
	mat.set_shader_parameter("fade", 1.0)
	_mats.append(mat)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	for line in lines:
		var label := Label.new()
		label.text = line["text"]
		label.uppercase = line.get("upper", false)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", line["size"])
		label.add_theme_color_override("font_color", GOLD if line["bright"] else GOLD_DIM)
		if line["bright"]:
			# Un pelo de sombra hacia abajo: letra tallada, no letra plana.
			label.add_theme_color_override("font_shadow_color", SHADOW)
			label.add_theme_constant_override("shadow_offset_y", 4)
			label.add_theme_constant_override("shadow_offset_x", 0)
		label.material = mat
		box.add_child(label)
	return root

func _run() -> void:
	var tw := create_tween().set_parallel(true)
	var t := lead_in
	var card_time := sweep_in + hold + sweep_out
	for i in _cards.size():
		var mat := _mats[i]
		var card := _cards[i]
		# La luz entra: la cabeza cruza las letras, rapida al principio y frenando.
		tw.tween_method(_set_param.bind(mat, "head"), -softness * 1.2, 1.0 + softness * 1.5, sweep_in).set_delay(t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# La cola sale detras, arrancando despacio.
		var t_out := t + sweep_in + hold
		tw.tween_method(_set_param.bind(mat, "tail"), -softness * 1.5, 1.0 + softness * 1.5, sweep_out).set_delay(t_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		# El bloque crece y sube muy despacio durante toda la tarjeta.
		card.scale = Vector2.ONE
		tw.tween_property(card, "scale", Vector2.ONE * grow, card_time).set_delay(t).set_trans(Tween.TRANS_LINEAR)
		card.position = Vector2(0.0, drift * 0.5)
		tw.tween_property(card, "position:y", -drift * 0.5, card_time).set_delay(t).set_trans(Tween.TRANS_LINEAR)
		t += card_time + gap
	tw.tween_callback(_finish).set_delay(duration())

func _set_param(v: float, mat: ShaderMaterial, name: String) -> void:
	mat.set_shader_parameter(name, v)

func _finish() -> void:
	finished.emit()
	queue_free()
