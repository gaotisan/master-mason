extends Node2D
## PRUEBA de camara al estilo Inside / Limbo: capas planas a distintas
## profundidades y una camara "3D" que solo hace cuentas de perspectiva.
##
## Cada capa (capa_profundidad.gd) esta a una distancia detras del plano de
## El peregrino (negativa = delante). Con la camara a una distancia D de ese plano y
## una focal F, un punto p de una capa a profundidad e sale en pantalla en
##     centro + (p - camara) * F / (D + e)
## Asi el zoom no es solo escalar la imagen: acercar la camara (D menor) agranda
## mucho mas lo cercano que lo lejano, y el paralaje sale solo, en x y en y.
## Cambiando F y D a la vez se puede dejar al peregrino del mismo tamano y estirar
## el fondo (el vertigo de Hitchcock).
##
## Los encuadres los ponen las zonas (zona_camara.gd, hijas de Zonas).
## Teclas: M vuelve al menu de pruebas, H oculta el texto.

const SUELO_Y := 1200.0
const PANTALLA := Vector2(2912, 1632)
const MENU := "res://scenes/pruebas_camara/menu_pruebas_camara.tscn"

## Focal general (pixeles). Mas alta = mas teleobjetivo, menos paralaje.
@export var focal: float = 2000.0
@export var peregrino_x_inicial: float = 400.0
@export var limite_izquierdo: float = 150.0
@export var limite_derecho: float = 13850.0
## Cuanto tarda en girarse la mirada de la camara cuando el peregrino se da la vuelta.
@export var suavidad_mirada: float = 1.2
## Margen para no saltar de zona en zona si el peregrino se queda en la frontera.
@export var histeresis: float = 40.0

@onready var _peregrino: Node2D = $Capas/Accion/Peregrino
@onready var _capas: Node2D = $Capas
@onready var _zonas: Node = $Zonas
@onready var _texto: Label = $Hud/Texto

var _zona: Node
var _zoom := 1.0
var _focal := 2000.0
var _centro := Vector2.ZERO
var _mirada := 0.0
var _colocada := false

func _ready() -> void:
	WindAmbience.gust_db = 0.0
	WindAmbience.fade_to(-14.0, 0.0)
	_peregrino.position = Vector2(peregrino_x_inicial, SUELO_Y)
	_peregrino.limite_izquierdo = limite_izquierdo
	_peregrino.limite_derecho = limite_derecho
	_peregrino.frenada_limite_andar = 200.0
	_peregrino.frenada_limite_correr = 380.0
	_focal = focal

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		if evento.keycode == KEY_M:
			get_tree().change_scene_to_file(MENU)
		elif evento.keycode == KEY_H:
			_texto.visible = not _texto.visible

func _process(delta: float) -> void:
	var x := _peregrino.position.x
	_elegir_zona(x)
	if _zona == null:
		return
	var z: Node = _zona
	var t: float = z.progreso(x)

	# Objetivos de la zona.
	var zoom_obj: float = z.zoom
	var focal_obj := focal
	if z.focal_desde > 0.0:
		var hasta: float = z.focal_hasta if z.focal_hasta > 0.0 else z.focal_desde
		focal_obj = lerpf(z.focal_desde, hasta, t)
	var mirada_obj: float = 0.0 if z.fija else _peregrino.mirando() * z.mirada
	var cx_obj: float = (z.desde + z.hasta) * 0.5 if z.fija else x + _mirada
	# El suelo se queda a la misma altura de pantalla sea cual sea el zoom.
	var cy_obj: float = SUELO_Y - (z.suelo_en_pantalla - 0.5) * PANTALLA.y / zoom_obj

	if not _colocada:
		# Primer fotograma: sin transicion (el piloto puede haber movido al peregrino).
		_colocada = true
		_zoom = zoom_obj
		_focal = focal_obj
		_mirada = mirada_obj
		_centro = Vector2(x + mirada_obj if not z.fija else cx_obj, cy_obj)
	else:
		var k := 1.0 - exp(-delta * 3.0 / maxf(z.suavidad, 0.01))
		_zoom = exp(lerpf(log(_zoom), log(zoom_obj), k))
		_focal = lerpf(_focal, focal_obj, k)
		_mirada = lerpf(_mirada, mirada_obj, 1.0 - exp(-delta * 3.0 / suavidad_mirada))
		# Siguiendo, la x va mas pegada que el resto para que el peregrino no se escape.
		var kx := k if z.fija else 1.0 - exp(-delta * 8.0)
		_centro.x = lerpf(_centro.x, cx_obj, kx)
		_centro.y = lerpf(_centro.y, cy_obj, k)

	_aplicar()
	if _texto.visible:
		_texto.text = "%s   zoom %.2f   focal %d   distancia %d\n" % [z.nombre, _zoom, int(_focal), int(_focal / _zoom)] \
			+ "flechas andar · doble toque correr · espacio saltar · abajo agacharse · M menu · H ocultar"

func _elegir_zona(x: float) -> void:
	if _zona != null and _zona.contiene(x, histeresis):
		return
	for z in _zonas.get_children():
		if z.contiene(x):
			_zona = z
			return

## Pone cada capa con su escala y posicion segun la camara actual.
func _aplicar() -> void:
	var distancia := _focal / _zoom
	for capa in _capas.get_children():
		var s := _focal / maxf(distancia + capa.profundidad, 50.0)
		capa.scale = Vector2(s, s)
		capa.position = PANTALLA * 0.5 - _centro * s
