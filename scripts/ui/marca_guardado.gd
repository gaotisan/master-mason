extends CanvasLayer
## Marca de guardado (2026-10-17; el usuario: al pasar ciertos puzles "se ve en
## pantalla una marca de guardado"). En la esquina de abajo a la derecha, la bola
## del baculo (orbe.gdshader, la misma del baston): aparece vacia, se llena de
## luz mientras guarda, y al llenarse da un destello, suelta una onda de luz y
## sale "Guardado" al lado; late un poco y se vacia apagandose. No para nada ni
## pide nada. (Hasta el 2026-10-18 era una llamita; al usuario no le gustaba.)
##
## La pone Partida.guardar() colgada de la raiz, no de la escena, para que siga
## si la escena cambia mientras esta a la vista.

const FUENTE := preload("res://assets/fonts/Cinzel-Variable.ttf")
const ORO_APAGADO := Color(0.68, 0.55, 0.35)
const ANCHO := 2912.0
const ALTO := 1632.0
const ORBE := preload("res://scripts/characters/baston/orbe.gdshader")
const ONDA := preload("res://scripts/ui/onda_guardado.gdshader")

## Tiempos (s): aparecer, llenarse, quedarse llena y vaciarse apagandose.
@export var aparecer: float = 0.5
@export var llenarse: float = 1.4
@export var quedarse: float = 1.8
@export var apagarse: float = 1.0
## Cuanto tarda en abrirse la onda de luz al llenarse.
@export var onda: float = 1.1
## Separacion de los bordes de la pantalla (px de la imagen 2912x1632).
@export var margen: Vector2 = Vector2(110.0, 90.0)
## Radio de la bola en pantalla (px).
@export var radio_bola: float = 32.0
@export var tam_letra: int = 38

## La bola ocupa esta fraccion del medio lado de su cuadrado (el resto, halo).
const RADIO_EN_CUADRO := 0.32

var _mat: ShaderMaterial
var _mat_onda: ShaderMaterial
var _texto: Label


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	var lado := radio_bola / RADIO_EN_CUADRO * 2.0
	var centro := Vector2(ANCHO, ALTO) - margen - Vector2(lado, lado) * 0.5

	# La onda, por debajo de la bola y en un cuadrado mayor para que se abra.
	var lado_onda := lado * 1.9
	var anillo := ColorRect.new()
	anillo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anillo.size = Vector2(lado_onda, lado_onda)
	anillo.position = centro - anillo.size * 0.5
	_mat_onda = ShaderMaterial.new()
	_mat_onda.shader = ONDA
	_mat_onda.set_shader_parameter("radio_bola", radio_bola / (lado_onda * 0.5))
	_mat_onda.set_shader_parameter("avance", 0.0)
	anillo.material = _mat_onda
	add_child(anillo)

	var bola := ColorRect.new()
	bola.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bola.size = Vector2(lado, lado)
	bola.position = centro - bola.size * 0.5
	_mat = ShaderMaterial.new()
	_mat.shader = ORBE
	_mat.set_shader_parameter("radio", RADIO_EN_CUADRO)
	_mat.set_shader_parameter("carga", 0.0)
	_mat.set_shader_parameter("opacidad", 0.0)
	bola.material = _mat
	add_child(bola)

	var ajustes := LabelSettings.new()
	ajustes.font = FUENTE
	ajustes.font_size = tam_letra
	ajustes.font_color = ORO_APAGADO
	ajustes.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	ajustes.shadow_size = 10
	ajustes.shadow_offset = Vector2(0.0, 3.0)
	_texto = Label.new()
	_texto.text = tr("guardado.marca").to_upper()
	_texto.label_settings = ajustes
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texto)
	# Con el tamano ya calculado: a la izquierda de la bola, a su altura.
	_texto.size = _texto.get_minimum_size()
	_texto.position = Vector2(centro.x - radio_bola - 26.0 - _texto.size.x, centro.y - _texto.size.y * 0.5)
	_texto.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_method(_param.bind("opacidad"), 0.0, 1.0, aparecer).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(_param.bind("carga"), 0.0, 1.0, llenarse).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Llena: destello, la onda y el texto, a la vez.
	tw.tween_method(_param.bind("destello"), 0.6, 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_onda, 0.0, 1.0, onda).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_texto, "modulate:a", 0.85, 0.5)
	tw.tween_interval(maxf(quedarse - 0.6, 0.0))
	# Se vacia apagandose.
	tw.tween_method(_param.bind("carga"), 1.0, 0.35, apagarse).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(_param.bind("opacidad"), 1.0, 0.0, apagarse).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_texto, "modulate:a", 0.0, apagarse * 0.8)
	tw.tween_callback(queue_free)


func _param(v: float, nombre: String) -> void:
	_mat.set_shader_parameter(nombre, v)


func _onda(v: float) -> void:
	_mat_onda.set_shader_parameter("avance", v)
