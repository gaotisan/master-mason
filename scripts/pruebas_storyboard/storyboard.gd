extends Node2D
## PRUEBA de "storyboard jugable": dos planos encadenados con el mismo peregrino.
##
##   1. Lateral: bosque en niebla, capas con perspectiva, la camara le sigue.
##      Al salir por la derecha, corte al mirador.
##   2. Mirador (la imagen del usuario, separada en fondo, ladera y marco):
##      El peregrino entra por abajo y sube por el sendero haciendose pequeno.
##      Va sobre un camino (raíl): derecha = adelante por el sendero, izquierda
##      = atras. Al llegar a la punta se para solo y la camara se acerca
##      despacio, con la ladera moviendose mas que el fondo. Ahi, derecha otra
##      vez = se adentra en la niebla (fundido) y vuelta al plano 1. Bajando por
##      el sendero hasta salir por abajo, corte al plano 1 andando hacia la
##      izquierda.
##
## El peregrino no sabe nada: sigue andando en x. En el mirador su x es la distancia
## recorrida por el sendero, y el nodo Proyeccion le pone cada fotograma el
## punto de pantalla y la escala que tocan ahi (como en la prueba de planos
## fijos). La distancia se mide dividida por la escala, asi que el paso del
## sprite sigue casando con lo que avanza en pantalla.
##
## Teclas: las del peregrino, R reinicia, H oculta el texto, Esc sale.

const PANTALLA := Vector2(2912, 1632)
const SUELO_Y := 1200.0

@export_group("Lateral")
@export var lateral_largo: float = 3600.0
@export var focal: float = 2000.0
@export_range(0.0, 1.0) var suelo_en_pantalla: float = 0.8

@export_group("Mirador")
## El sendero, en pixeles de la imagen original (1456x816), de abajo a la
## punta. El primer punto queda fuera de cuadro para que entre desde abajo.
@export var sendero: PackedVector2Array = PackedVector2Array([
	Vector2(140, 880), Vector2(250, 790), Vector2(360, 742), Vector2(450, 694),
	Vector2(500, 660), Vector2(523, 640)])
## Escala del peregrino segun la altura en la imagen: es 'escala_punta' en la punta
## (la figura pintada medía 63 px) y crece hacia abajo como en un suelo en
## perspectiva con el horizonte en 'horizonte_y'.
@export var escala_punta: float = 0.40
@export var horizonte_y: float = 450.0
## Acercamiento al contemplar: el fondo y la ladera, sobre este punto.
@export var foco_contemplar: Vector2 = Vector2(640, 470)
@export var zoom_fondo: float = 1.07
@export var zoom_ladera: float = 1.14
@export var segundos_acercar: float = 5.0

enum Plano { LATERAL, MIRADOR }

@onready var _peregrino: Node2D = $Peregrino
@onready var _lateral: Node2D = $Lateral
@onready var _capas: Node2D = $Lateral/Capas
@onready var _accion: Node2D = $Lateral/Capas/Accion
@onready var _mirador: Node2D = $Mirador
@onready var _fondo: Node2D = $Mirador/Fondo
@onready var _ladera: Node2D = $Mirador/Ladera
@onready var _proyeccion: Node2D = $Mirador/Ladera/Proyeccion
@onready var _texto: Label = $Hud/Texto
@onready var _aviso: Label = $Hud/Aviso
@onready var _negro: ColorRect = $Hud/Negro

var _plano := Plano.LATERAL
var _cam_x := 0.0
# sendero muestreado: puntos de pantalla, escala y distancia "de Peregrino"
var _pts := PackedVector2Array()
var _esc := PackedFloat32Array()
var _dist := PackedFloat32Array()
var _largo := 0.0
var _contemplar := 0.0     # 0..1, cuanto se ha acercado la camara
var _en_punta := 0.0       # segundos quieto en la punta
var _saliendo := false

func _ready() -> void:
	WindAmbience.gust_db = 0.0
	WindAmbience.fade_to(-16.0, 0.0)
	_muestrear_sendero()
	_peregrino.get_parent().remove_child(_peregrino)
	_entrar_lateral(300.0, 1.0)
	_negro.color.a = 0.0
	_aviso.modulate.a = 0.0

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_R:
			get_tree().reload_current_scene()
		elif e.keycode == KEY_H:
			_texto.visible = not _texto.visible
	# En la punta, tras contemplar: adelante = adentrarse en la niebla.
	if _plano == Plano.MIRADOR and not _saliendo and _en_punta > 2.5 and e.is_action_pressed("mover_derecha"):
		_adentrarse()

func _process(delta: float) -> void:
	match _plano:
		Plano.LATERAL: _proceso_lateral(delta)
		Plano.MIRADOR: _proceso_mirador(delta)
	if _texto.visible:
		_texto.text = ("Plano 1  lateral" if _plano == Plano.LATERAL else "Plano 2  mirador (camino)") \
			+ "\nflechas andar · doble toque correr · espacio saltar · R reinicia · H oculta"

# --- Plano 1: lateral --------------------------------------------------------

func _entrar_lateral(x: float, mirando: float) -> void:
	_plano = Plano.LATERAL
	_lateral.visible = true
	_mirador.visible = false
	_poner_peregrino_en(_accion, Vector2(x, SUELO_Y))
	_peregrino.limite_izquierdo = 150.0
	# El limite, lejos: el corte tiene que llegar antes de que frene.
	_peregrino.limite_derecho = lateral_largo + 3000.0
	_peregrino.frenada_limite_andar = 200.0
	_peregrino.frenada_limite_correr = 380.0
	if mirando < 0.0 and _peregrino.mirando() > 0.0:
		_peregrino.call("_mirar", -1.0)
	elif mirando > 0.0 and _peregrino.mirando() < 0.0:
		_peregrino.call("_mirar", 1.0)
	_cam_x = clampf(x + 300.0 * mirando, PANTALLA.x * 0.5, lateral_largo)

func _proceso_lateral(delta: float) -> void:
	var x := _peregrino.position.x
	var obj := clampf(x + 300.0 * _peregrino.mirando(), PANTALLA.x * 0.5, lateral_largo)
	_cam_x = lerpf(_cam_x, obj, 1.0 - exp(-delta * 4.0))
	var cy := SUELO_Y - (suelo_en_pantalla - 0.5) * PANTALLA.y
	for capa in _capas.get_children():
		var s: float = focal / maxf(focal + capa.profundidad, 50.0)
		capa.scale = Vector2(s, s)
		capa.position = PANTALLA * 0.5 - Vector2(_cam_x, cy) * s
	# Sale por la derecha: corte al mirador, entrando por abajo.
	if x > lateral_largo + PANTALLA.x * 0.5 - 120.0 and _peregrino.mirando() > 0.0:
		_entrar_mirador(_dist[0] + 10.0)

# --- Plano 2: mirador ----------------------------------------------------------

func _entrar_mirador(d: float) -> void:
	_plano = Plano.MIRADOR
	_lateral.visible = false
	_mirador.visible = true
	_contemplar = 0.0
	_en_punta = 0.0
	_poner_peregrino_en(_proyeccion, Vector2(d, 0.0))
	_peregrino.limite_izquierdo = _dist[0] - 400.0
	_peregrino.limite_derecho = _largo
	_peregrino.frenada_limite_andar = 120.0
	_peregrino.frenada_limite_correr = 300.0

func _proceso_mirador(delta: float) -> void:
	var d := _peregrino.position.x
	var p := _en_sendero(d)
	var s: float = p[1]
	var t := Transform2D(0.0, Vector2(s, s), 0.0, Vector2.ZERO)
	t.origin = p[0] - t.basis_xform(Vector2(d, 0.0))
	_proyeccion.transform = t
	# En la punta y quieto: contempla; la camara se acerca.
	var quieto := absf(d - _largo) < 80.0
	_en_punta = _en_punta + delta if quieto else 0.0
	var obj := 1.0 if _en_punta > 0.6 else 0.0
	var vel := delta / segundos_acercar if obj > _contemplar else delta / 1.5
	_contemplar = move_toward(_contemplar, obj, vel)
	var k := smoothstep(0.0, 1.0, _contemplar)
	var foco := foco_contemplar * 2.0
	_zoom_capa(_fondo, lerpf(1.0, zoom_fondo, k), foco)
	_zoom_capa(_ladera, lerpf(1.0, zoom_ladera, k), foco)
	var aviso_obj := 1.0 if _en_punta > 2.5 and not _saliendo else 0.0
	_aviso.modulate.a = move_toward(_aviso.modulate.a, aviso_obj * 0.7, delta * 0.8)
	# Baja por el sendero hasta salir por abajo: corte al lateral, hacia la izquierda.
	if d < _dist[0] - 300.0 and _peregrino.mirando() < 0.0:
		_entrar_lateral(lateral_largo + PANTALLA.x * 0.5 + 100.0, -1.0)

func _zoom_capa(capa: Node2D, z: float, foco: Vector2) -> void:
	capa.scale = Vector2(z, z)
	capa.position = foco * (1.0 - z)

func _adentrarse() -> void:
	_saliendo = true
	var tw := create_tween()
	tw.tween_property(_negro, "color:a", 1.0, 1.6)
	tw.tween_callback(func():
		_entrar_lateral(300.0, 1.0)
		_saliendo = false)
	tw.tween_property(_negro, "color:a", 0.0, 1.2)

# --- Sendero -------------------------------------------------------------------

func _escala_en(y_img: float) -> float:
	return maxf(escala_punta * (y_img - horizonte_y) / (sendero[sendero.size() - 1].y - horizonte_y), 0.05)

## Muestrea el sendero cada pocos pixeles y acumula la distancia que anda
## El peregrino: tramo de pantalla / escala, para que el paso case con el suelo.
func _muestrear_sendero() -> void:
	_pts.clear(); _esc.clear(); _dist.clear()
	var acum := 0.0
	var previo := Vector2.ZERO
	for i in sendero.size() - 1:
		var a := sendero[i]
		var b := sendero[i + 1]
		var n := int(ceil(a.distance_to(b) / 2.0))
		for j in n:
			var q := a.lerp(b, float(j) / n)
			var sp := q * 2.0
			var e := _escala_en(q.y)
			if _pts.size() > 0:
				acum += sp.distance_to(previo) / e
			_pts.append(sp); _esc.append(e); _dist.append(acum)
			previo = sp
	var fin := sendero[sendero.size() - 1]
	acum += (fin * 2.0).distance_to(previo) / _escala_en(fin.y)
	_pts.append(fin * 2.0); _esc.append(_escala_en(fin.y)); _dist.append(acum)
	_largo = acum

## Punto de pantalla y escala a una distancia d del sendero (fuera de rango,
## se prolonga el primer tramo hacia abajo).
func _en_sendero(d: float) -> Array:
	if d <= _dist[0]:
		var dir := (_pts[0] - _pts[1]).normalized()
		return [_pts[0] + dir * (_dist[0] - d) * _esc[0], _esc[0]]
	var i := _dist.bsearch(d)
	i = clampi(i, 1, _dist.size() - 1)
	var t := inverse_lerp(_dist[i - 1], _dist[i], d)
	return [_pts[i - 1].lerp(_pts[i], t), lerpf(_esc[i - 1], _esc[i], t)]

func _poner_peregrino_en(padre: Node, pos: Vector2) -> void:
	if _peregrino.get_parent():
		_peregrino.get_parent().remove_child(_peregrino)
	padre.add_child(_peregrino)
	_peregrino.position = pos
