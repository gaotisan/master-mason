extends CanvasLayer
## Marca de guardado (2026-10-17; el usuario: al pasar ciertos puzles "se ve en
## pantalla una marca de guardado"). En la esquina de abajo a la derecha, la bola
## del baculo (orbe.gdshader, la misma del baston) cargandose como en el juego:
## aparece vacia, sube el liquido de luz y gira mas la espiral mientras entran
## motas de luz en ella; llena, late con su resplandor, suben unas chispas y sale
## "Guardado" al lado. Luego se apaga fundiendose. No para nada ni pide nada.
## (Hasta el 2026-10-18 era una llamita; luego la bola con una onda y un
## destello, "demasiado futurista"; luego con la garra del baculo, que no era.)
##
## La pone Partida.guardar() colgada de la raiz, no de la escena, para que siga
## si la escena cambia mientras esta a la vista.

## Bola y letras como en los menus (2026-10-19; el usuario: que sea "acorde con
## el menu"): el ambar apagado de sus bolas, sin halo, y "Guardado" en el oro de
## la opcion elegida. Antes era el naranja vivo del baculo, que chillaba.
const MENU := preload("res://scripts/ui/menu_base.gd")
const FUENTE := MENU.FUENTE
const ANCHO := 2912.0
const ALTO := 1632.0
const ORBE := preload("res://scripts/characters/baston/orbe.gdshader")
const LUZ := preload("res://scripts/characters/baston/luz_orbe.gdshader")
const MOTAS := preload("res://scripts/ui/motas_carga.gdshader")

## Tiempos (s): aparecer, cargarse, quedarse llena y apagarse.
@export var aparecer: float = 0.5
@export var cargarse: float = 1.8
@export var quedarse: float = 1.8
@export var apagarse: float = 0.9
## Separacion de los bordes de la pantalla (px de la imagen 2912x1632).
@export var margen: Vector2 = Vector2(110.0, 90.0)
## Radio de la bola en pantalla (px).
@export var radio_bola: float = 20.0
## Aire entre el borde de la bola y el texto (px): que el halo no toque las letras.
@export var aire: float = 60.0
@export var tam_letra: int = 38

## La bola ocupa esta fraccion del medio lado de su cuadrado (el resto, halo).
const RADIO_EN_CUADRO := 0.32

var _mat: ShaderMaterial
var _mat_luz: ShaderMaterial
var _mat_motas: ShaderMaterial
var _texto: Label
var _vida := 0.0
var _carga := 0.0
var _recarga := 0.0
var _chispas := 0.0


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	var lado := radio_bola / RADIO_EN_CUADRO * 2.0
	var centro := Vector2(ANCHO, ALTO) - margen - Vector2(lado, lado) * 0.5

	# Su resplandor sobre lo de alrededor (el de luz_orbe en el juego).
	_mat_luz = ShaderMaterial.new()
	_mat_luz.shader = LUZ
	_mat_luz.set_shader_parameter("color", MENU.BOLA_COLOR)
	_rect(centro, radio_bola * 6.0, _mat_luz)

	_mat = ShaderMaterial.new()
	_mat.shader = ORBE
	_mat.set_shader_parameter("radio", RADIO_EN_CUADRO)
	_mat.set_shader_parameter("color", MENU.BOLA_COLOR)
	_mat.set_shader_parameter("halo", 0.0)
	_mat.set_shader_parameter("remolino", 1.8)
	_rect(centro, lado, _mat)

	# Las motas que entran y las chispas que suben, en un cuadrado mayor.
	var lado_motas := radio_bola * 6.5
	_mat_motas = ShaderMaterial.new()
	_mat_motas.shader = MOTAS
	_mat_motas.set_shader_parameter("radio_bola", radio_bola / (lado_motas * 0.5))
	_mat_motas.set_shader_parameter("semilla", randf() * 50.0)
	_mat_motas.set_shader_parameter("color", MENU.BOLA_COLOR)
	_rect(centro, lado_motas, _mat_motas)

	var ajustes := LabelSettings.new()
	ajustes.font = FUENTE
	ajustes.font_size = tam_letra
	ajustes.font_color = MENU.ORO_VIVO
	ajustes.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
	ajustes.shadow_size = 8
	ajustes.shadow_offset = Vector2(0.0, 3.0)
	_texto = Label.new()
	_texto.text = tr("guardado.marca").to_upper()
	_texto.label_settings = ajustes
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texto)
	# Con el tamano ya calculado: a la izquierda de la bola, a su altura.
	_texto.size = _texto.get_minimum_size()
	_texto.position = Vector2(centro.x - radio_bola - aire - _texto.size.x, centro.y - _texto.size.y * 0.5)
	_texto.modulate.a = 0.0

	_aplicar()
	var tw := create_tween()
	tw.tween_method(_poner.bind("vida"), 0.0, 1.0, aparecer).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Se carga: las motas entran mientras sube la luz.
	tw.tween_method(_poner.bind("recarga"), 0.0, 1.0, 0.3)
	tw.parallel().tween_method(_poner.bind("carga"), 0.0, 1.0, cargarse).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Llena: dejan de entrar motas, suben chispas y sale el texto.
	tw.tween_method(_poner.bind("recarga"), 1.0, 0.0, 0.5)
	tw.parallel().tween_method(_poner.bind("chispas"), 0.0, 1.0, 0.5)
	tw.parallel().tween_property(_texto, "modulate:a", 0.85, 0.5)
	tw.tween_interval(maxf(quedarse - 0.5, 0.0))
	tw.tween_method(_poner.bind("vida"), 1.0, 0.0, apagarse).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_texto, "modulate:a", 0.0, apagarse * 0.8)
	tw.tween_callback(queue_free)


func _rect(centro: Vector2, lado: float, mat: ShaderMaterial) -> void:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(lado, lado)
	r.position = centro - r.size * 0.5
	r.material = mat
	add_child(r)


func _poner(v: float, que: String) -> void:
	match que:
		"vida": _vida = v
		"carga": _carga = v
		"recarga": _recarga = v
		"chispas": _chispas = v
	_aplicar()


func _aplicar() -> void:
	_mat.set_shader_parameter("carga", _carga)
	_mat.set_shader_parameter("opacidad", _vida * MENU.BOLA_OPACIDAD)
	_mat_luz.set_shader_parameter("carga", _carga)
	_mat_luz.set_shader_parameter("fuerza", 0.14 * _vida)
	_mat_motas.set_shader_parameter("recarga", _recarga * _vida * 0.7)
	_mat_motas.set_shader_parameter("chispas", _chispas * _vida * 0.7)
