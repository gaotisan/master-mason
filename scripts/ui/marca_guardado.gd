extends CanvasLayer
## Marca de guardado (2026-10-17; el usuario: al pasar ciertos puzles "se ve en
## pantalla una marca de guardado"). Una llamita como las velas del titulo, en la
## esquina de abajo a la derecha, con "Guardado" al lado: prende, tiembla un poco
## y se apaga, y se va sola. No para nada ni pide nada.
##
## La pone Partida.guardar() colgada de la raiz, no de la escena, para que siga
## si la escena cambia mientras esta a la vista.

const FUENTE := preload("res://assets/fonts/Cinzel-Variable.ttf")
const ORO_APAGADO := Color(0.68, 0.55, 0.35)
const ANCHO := 2912.0
const ALTO := 1632.0

## Cuanto tarda en prender, cuanto se queda y cuanto tarda en apagarse (s).
@export var prender: float = 0.7
@export var quedarse: float = 2.2
@export var apagarse: float = 1.0
## Separacion de los bordes de la pantalla (px de la imagen 2912x1632).
@export var margen: Vector2 = Vector2(110.0, 90.0)
@export var tam_llama: Vector2 = Vector2(70.0, 112.0)
@export var tam_letra: int = 38

const LLAMA := preload("res://scripts/ui/llama.gdshader")

var _mat: ShaderMaterial
var _texto: Label


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	var abajo_dcha := Vector2(ANCHO, ALTO) - margen

	var llama := ColorRect.new()
	llama.mouse_filter = Control.MOUSE_FILTER_IGNORE
	llama.size = tam_llama
	llama.position = abajo_dcha - tam_llama
	_mat = ShaderMaterial.new()
	_mat.shader = LLAMA
	_mat.set_shader_parameter("semilla", randf() * 50.0)
	llama.material = _mat
	add_child(llama)

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
	# Con el tamano ya calculado: a la izquierda de la llama, a la altura de su
	# cuerpo (no de la punta).
	_texto.size = _texto.get_minimum_size()
	_texto.position = Vector2(llama.position.x - _texto.size.x - 18.0,
		abajo_dcha.y - tam_llama.y * 0.38 - _texto.size.y * 0.5)
	_texto.modulate.a = 0.0

	_poner(0.0)
	var tw := create_tween()
	tw.tween_method(_poner, 0.0, 1.0, prender).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(quedarse)
	tw.tween_method(_poner, 1.0, 0.0, apagarse).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _poner(v: float) -> void:
	_mat.set_shader_parameter("vida", v)
	_texto.modulate.a = v * 0.85
