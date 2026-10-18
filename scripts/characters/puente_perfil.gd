class_name PuentePerfil
extends Node2D
## El paso del peregrino de perfil (peregrino.tscn) al de frente / espaldas
## (PeregrinoFrontal) y al reves, sin corte (2026-10-17; el usuario: "en pocos
## sitios vamos a pasar de frontal a side, digamos que solo aqui, asi que lo
## vamos a hacer lo mejor posible").
##
## Los dos personajes salen de videos distintos (otra tunica, otra capucha, el
## baston en otro sitio) y cortar de uno al otro saltaba. Un puente son unos
## fotogramas que llevan el uno al otro por piezas (raw/master_builder/anim/
## peregrino_puente_perfil/puente.py): la silueta cambia de forma poco a poco, el
## baston va como pieza rigida y el dibujo de la tunica entra con un barrido del
## lado que gira hacia la camara. Empiezan en un fotograma del de un lado y
## acaban en el del otro (el de "sigue" de la ficha), asi que antes y despues van
## los personajes de siempre.
##
## Puentes (assets/characters/peregrino/puente_perfil/puente_perfil.json):
##   ida_<sb|cb>_rNN  del reposo de perfil (su fotograma NN; mano: cb) a la vuelta
##                    del frontal hacia la espalda (sigue en su fotograma
##                    "sigue", "dx" px por delante); al reves, de espaldas al perfil
##   frente_<sb|cb>   del reposo de frente al giro del de perfil (sigue en su
##                    fotograma "sigue", "dx" px al lado)
## Se ve con el material que se le ponga (el del de perfil: la luz de la escena).

signal acabado

const FICHA := "res://assets/characters/peregrino/puente_perfil/puente_perfil.json"
const FPS := 24.0

static var _ficha := {}

var _sprite: Sprite2D
var _datos: Dictionary
var _k := 0
var _t := 0.0
var _al_reves := false
var _desde := [Vector2.ZERO, Vector2.ONE]     # posicion y escala (con el signo del espejo)
var _hasta := [Vector2.ZERO, Vector2.ONE]
var _jugando := false


static func ficha() -> Dictionary:
	if _ficha.is_empty():
		_ficha = JSON.parse_string(FileAccess.open(FICHA, FileAccess.READ).get_as_text())
	return _ficha


## Pide en segundo plano las hojas de todos los puentes (la escena, en cuanto
## pueda hacer falta uno): cargarlas al empezar el puente daba un tiron.
static func precargar() -> void:
	if OS.has_feature("nothreads"):
		return
	for nombre in ficha():
		var ruta := String(ficha()[nombre]["hoja"])
		if not ResourceLoader.has_cached(ruta):
			ResourceLoader.load_threaded_request(ruta)


## Los datos de un puente: n, casilla, pies, b0, sigue, dx.
static func datos(nombre: String) -> Dictionary:
	return ficha().get(nombre, {})


## De los ida_<modo>_rNN, el NN mas cercano (en el ciclo de n fotogramas del
## reposo) al fotograma f.
static func variante(modo: String, f: int, n: int) -> int:
	var mejor := -1
	var dist := 1 << 30
	for nombre in ficha():
		var prefijo := "ida_%s_r" % modo
		if not String(nombre).begins_with(prefijo):
			continue
		var v := int(String(nombre).substr(prefijo.length()))
		var d := absi(posmod(f - v + n / 2, n) - n / 2)
		if d < dist:
			dist = d
			mejor = v
	return mejor


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.use_parent_material = true
	add_child(_sprite)
	visible = false


## Pone el puente y lo reproduce (del primer fotograma al ultimo, o al reves), con
## el nodo yendo de la posicion y escala `pos0`, `esc0` (donde esta el personaje
## que se va) a `pos1`, `esc1` (las del que llega; la escala lleva el signo del
## espejo: -1 en x mirando a la izquierda). Emite acabado al terminar (el que
## llega ya se puede ver: el ultimo fotograma ya se ha visto).
func jugar(nombre: String, al_reves: bool, pos0: Vector2, esc0: Vector2, pos1: Vector2, esc1: Vector2) -> void:
	_datos = datos(nombre)
	var ruta := String(_datos["hoja"])
	if ResourceLoader.load_threaded_get_status(ruta) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_sprite.texture = ResourceLoader.load_threaded_get(ruta)
	else:
		_sprite.texture = load(ruta)
	var casilla := Vector2(_datos["casilla"][0], _datos["casilla"][1])
	_sprite.offset = -Vector2(_datos["pies"][0], _datos["pies"][1])
	_sprite.region_rect = Rect2(Vector2.ZERO, casilla)
	_al_reves = al_reves
	_desde = [pos0, esc0]
	_hasta = [pos1, esc1]
	_k = 0
	_t = 0.0
	_jugando = true
	_poner()
	visible = true


func _process(delta: float) -> void:
	if not _jugando:
		return
	_t += delta * FPS
	while _t >= 1.0 and _jugando:
		_t -= 1.0
		_k += 1
		if _k >= int(_datos["n"]):
			_jugando = false
			visible = false
			acabado.emit()
			return
	_poner()


func _poner() -> void:
	var n := int(_datos["n"])
	var i := n - 1 - _k if _al_reves else _k
	var casilla := Vector2(_datos["casilla"][0], _datos["casilla"][1])
	_sprite.region_rect = Rect2(Vector2(casilla.x * i, 0), casilla)
	# la colocacion, suave de un personaje al otro a lo largo del puente
	var u := (float(_k) + 1.0) / float(n + 1)
	u = u * u * (3.0 - 2.0 * u)
	position = (_desde[0] as Vector2).lerp(_hasta[0], u)
	scale = (_desde[1] as Vector2).lerp(_hasta[1], u)
