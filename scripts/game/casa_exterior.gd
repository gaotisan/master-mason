@tool
class_name CasaExterior
extends Node2D
## La casa de Dominus vista desde fuera, de noche, al final del bosque.
##
##   "Su arquitectura recordaba a la de una ciudadela en miniatura, con altos
##   torreones, ventanales abuhardillados y osados arbotantes [...] aquella casa
##   no debia mantenerse en pie."
##
## Va en la capa de juego (scroll 1:1 con Magnus). El ORIGEN del nodo es el
## punto del suelo en el centro de la puerta: se coloca la casa poniendo su
## position en la linea de suelo (y = 1200) donde tenga que quedar la puerta.
## Magnus llega por la izquierda; la puerta esta en el tercio izquierdo.
##
## Esta hecha como el bosque: SILUETA. La casa es una mascara blanca con algo de
## valor dentro (piedra, tejas, entramado, filos que coge la luna) y el color se
## lo pone color_silueta, igual que las capas de arboles. Encima, sumada, va la
## luz: ventanas y vano de la puerta en una sola textura con un shader que hace
## temblar cada vela por su cuenta. Asi el nivel puede:
##
##   - tintarla segun la hora con color_silueta (de noche ~#1a2138),
##   - encender la luz poco a poco al acercarse con intensidad_luz (0..1),
##   - abrir la puerta con abrir_puerta() y esperar a puerta_abierta.
##
## Coste: cuatro sprites (silueta, luz, hoja, luz del suelo) y dos emisores de
## humo de 12 particulas. La silueta y la luz van en VRAM comprimida.
##
## Las texturas y casa_meta.json (ventanas, puerta, chimeneas en coordenadas de
## esta escena) salen de tools/mundo/casa_exterior.py.

## Se emite cuando la hoja termina de abrirse.
signal puerta_abierta

## Color de la silueta (casa y hoja). De noche azul casi negro; al atardecer el
## nivel le pone el de su capa de arboles cercana.
@export var color_silueta: Color = Color("1a2138"):
	set(valor):
		color_silueta = valor
		_aplicar_color()

## Cuanta luz sale de la casa: ventanas, vano y el abanico del suelo. El nivel la
## sube desde 0 cuando la casa empieza a asomar entre los arboles: primero se ve
## "una luz temblorosa" y luego la casa.
@export_range(0.0, 1.0, 0.01) var intensidad_luz: float = 1.0:
	set(valor):
		intensidad_luz = clampf(valor, 0.0, 1.0)
		_aplicar_luz()

## Color del humo de las chimeneas. Palido y frio, con poco alfa: de noche el
## humo apenas se distingue del cielo, y asi debe ser.
@export var color_humo: Color = Color(0.64, 0.70, 0.82, 0.55):
	set(valor):
		color_humo = valor
		_aplicar_color()

@export_group("Puerta")
## Como de entornada esta al llegar, 0..1 del giro maximo. "La puerta estaba
## entornada": con 0,3 se ve un filo de luz de unos 20 px, que es lo justo para
## leerse desde lejos sin que parezca abierta.
@export_range(0.0, 1.0, 0.01) var apertura_inicial: float = 0.3:
	set(valor):
		apertura_inicial = valor
		if not _abriendo and not _abierta:
			_poner_apertura(valor)
## Giro de la hoja abierta del todo, en grados. A 90 desapareceria de canto; a
## 80 queda una tira que se lee como la hoja vista de lado.
@export_range(30.0, 89.0, 1.0) var angulo_max: float = 80.0
## Lo que tarda el barrido principal de la hoja, en segundos.
@export var duracion_apertura: float = 2.8

## Offset del punto delante de la puerta, respecto al origen. Por defecto el
## centro del vano: ahi se para Magnus antes de entrar.
@export var offset_punto_puerta: Vector2 = Vector2.ZERO

@onready var _silueta: Sprite2D = $Silueta
@onready var _ventanas: Sprite2D = $Ventanas
@onready var _hoja: Sprite2D = $Puerta
@onready var _luz_suelo: Sprite2D = $LuzPuerta
@onready var _humo: Node2D = $Humo

## Ancho del vano en px de escena. Lo fija la textura de la hoja (puerta.png).
const ANCHO_PUERTA := 220.0

var _apertura := 0.0
var _abriendo := false
var _abierta := false
var _t := 0.0

func _ready() -> void:
	_aplicar_color()
	_aplicar_luz()
	_poner_apertura(apertura_inicial)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	_luz_suelo.modulate.a = _alfa_luz_suelo() * (1.0 + 0.06 * _temblor(_t))

## Abre la hoja hacia dentro: un tiron corto al soltarse el pestillo, una pausa
## y el barrido lento. No la empuja nadie, como el pendulo de dentro: se abre
## sola cuando llega el viejo. Al terminar emite puerta_abierta.
func abrir_puerta() -> void:
	if _abierta:
		puerta_abierta.emit.call_deferred()
		return
	if _abriendo:
		return
	_abriendo = true
	var tw := create_tween()
	var desde := _apertura
	tw.tween_method(_poner_apertura, desde, desde + 0.06, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.45)
	tw.tween_method(_poner_apertura, desde + 0.06, 1.02, duracion_apertura) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Un rebote minimo al llegar al tope: la hoja pesa.
	tw.tween_method(_poner_apertura, 1.02, 1.0, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_abriendo = false
		_abierta = true
		puerta_abierta.emit())

## Punto del suelo delante de la puerta, en coordenadas globales. Es donde tiene
## que llegar Magnus para entrar.
func punto_puerta() -> Vector2:
	return to_global(offset_punto_puerta)

## 0 = cerrada, 1 = abierta del todo. La hoja gira sobre la bisagra izquierda:
## visto de frente eso es encoger en x por el coseno del angulo.
func _poner_apertura(a: float) -> void:
	_apertura = a
	if not is_node_ready():
		return
	var ang := deg_to_rad(angulo_max) * clampf(a, 0.0, 1.05)
	var c := cos(ang)
	_hoja.scale.x = maxf(c, 0.02)
	var mat := _hoja.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("apertura", clampf(a, 0.0, 1.0))
	# La luz del suelo sale por la rendija: su centro va entre el canto de la
	# hoja y la jamba derecha, y se ensancha con ella.
	var hueco := (1.0 - c) / (1.0 - cos(deg_to_rad(angulo_max)))
	_luz_suelo.position.x = ANCHO_PUERTA * 0.5 * c
	_luz_suelo.scale.x = lerpf(0.22, 1.0, clampf(hueco, 0.0, 1.0))
	_luz_suelo.modulate.a = _alfa_luz_suelo()

func _alfa_luz_suelo() -> float:
	var c := cos(deg_to_rad(angulo_max) * clampf(_apertura, 0.0, 1.0))
	var hueco := (1.0 - c) / (1.0 - cos(deg_to_rad(angulo_max)))
	return lerpf(0.3, 1.0, clampf(hueco, 0.0, 1.0)) * intensidad_luz

func _aplicar_color() -> void:
	if not is_node_ready():
		return
	_silueta.self_modulate = color_silueta
	_hoja.self_modulate = color_silueta
	for p in _humo.get_children():
		(p as CanvasItem).self_modulate = color_humo

func _aplicar_luz() -> void:
	if not is_node_ready():
		return
	_ventanas.self_modulate.a = intensidad_luz
	_ventanas.visible = intensidad_luz > 0.0
	_luz_suelo.modulate.a = _alfa_luz_suelo()
	_luz_suelo.visible = intensidad_luz > 0.0

## El mismo tipo de pulso que las velas del shader, pero para la luz del suelo:
## sale por la puerta, asi que tiembla con el fuego de dentro. Centrado en 0.
func _temblor(t: float) -> float:
	return sin(t * 2.3) * 0.5 + sin(t * 5.9 + 1.3) * 0.3 + sin(t * 13.1 + 0.4) * 0.2
