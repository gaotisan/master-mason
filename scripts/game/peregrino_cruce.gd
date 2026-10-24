extends "res://scripts/game/peregrino_sendero.gd"
## El peregrino en el cruce del bosque (cruce_bosque.gd), DE ESPALDAS: el
## contraplano del camino del bosque. Un plano frontal (peregrino_sendero.gd): el
## camino del CENTRO, que baja a la casa de Dominus (su verja asoma en la niebla
## del fondo), y la explanada de la entrada.
##
## LOS CAMINOS DE LOS LADOS NO SE ANDAN AQUI (2026-10-20). Salen en diagonal y el
## peregrino de frente no anda en diagonal (probado con una piel en diagonal
## dentro de este plano: no quedaba profesional). Se toman con un CORTE de
## camara: en la explanada, izquierda o derecha le hacen andar hacia la boca de
## ese camino y, a los pocos pasos (|_k| >= k_corte), `boca`: la escena corta al
## plano de ese camino (camino_izquierdo, en tres cuartos; camino_derecho,
## frontal), que le recibe andando. Volviendo de alli, entra por esa boca, hacia
## la camara y andando.
##
## _k (de -1 a 1) lleva sus pies del camino del centro hacia la boca de la
## izquierda o de la derecha; cambia solo mientras anda alejandose (nunca de lado
## parado ni andando hacia la camara): hacia el lado pulsado o, sin pulsar,
## hacia el centro. Una tecla de lado mirando a la camara: se da la vuelta y va.

signal boca(lado: String)

## Las bocas de los caminos de los lados (x, y, z), por el centro de su arena (var:
## un Packed*Array no puede ser const).
var IZQUIERDA := PackedVector3Array([Vector3(1480, 1490, 1490), Vector3(1400, 1400, 1400), Vector3(1226, 1258, 1300),
	Vector3(900, 1272, 1250)])
var DERECHA := PackedVector3Array([Vector3(1480, 1490, 1490), Vector3(1560, 1430, 1430), Vector3(1776, 1312, 1355),
	Vector3(2023, 1228, 1275)])

@export_group("Cruce")
## Hasta donde llega la explanada (z) y, con un lado pulsado, hasta donde se puede
## seguir hacia una boca.
@export var z_decision := 1290.0
@export var z_decision_boca := 1240.0
## Lo que cambia _k por cada unidad de 1/escala andada, cuanto hay que andar hacia
## una boca para el corte y donde aparece volviendo de un camino (k y z).
@export var cambio_camino := 7.0
@export var k_corte := 0.3
@export var k_vuelta := 0.27
@export var z_vuelta := 1350.0

var _k := 0.0
var _inv_antes := 0.0


func _ready() -> void:
	super()
	_inv_antes = 1.0 / peregrino.escala


## Del camino del bosque, como siempre; de un camino de los lados, por su boca,
## hacia la camara y andando.
func _entrar_andando() -> void:
	var viene := str(Estado.leer(get_tree()).get("viene_de", ""))
	if viene in ["camino_izquierdo", "camino_derecho"]:
		_k = -k_vuelta if viene == "camino_izquierdo" else k_vuelta
		_retener("frente")
		if not _reten_teclas.is_empty():
			peregrino.empezar_andando("frente")
		return
	super()


func _antes_de_meter() -> void:
	super()
	var viene := str(Estado.leer(get_tree()).get("viene_de", ""))
	if viene in ["camino_izquierdo", "camino_derecho"]:
		peregrino.cara = "frente"
		peregrino.escala_inicial = _escala_de(z_vuelta)


## Los pies: en el camino del centro o hacia una boca.
func _suelo(escala: float) -> Vector2:
	var z := _z_de(escala)
	var c := _en(camino, z)
	if _k < 0.0:
		return c.lerp(_en(IZQUIERDA, z), -_k)
	return c.lerp(_en(DERECHA, z), _k)


func _quiere(z: float) -> String:
	var q := _direccion()
	if not _reten_teclas.is_empty():
		return q
	var izq := _izquierda()
	var der := _derecha()
	if izq != der and z > z_decision_boca:
		# hacia la boca de ese lado (dandose la vuelta si mira a la camara)
		if not _abajo():
			q = "espalda"
	return q


func _process(delta: float) -> void:
	super(delta)
	if _estado != "jugando":
		return
	var escala := peregrino.escala
	var z := _z_de(escala)
	# el cambio hacia una boca, con lo que anda alejandose
	var inv := 1.0 / escala
	var andado := maxf(inv - _inv_antes, 0.0)
	_inv_antes = inv
	if peregrino.mirando != "espalda" or andado <= 0.0:
		return
	var obj := 0.0
	var izq := _izquierda()
	var der := _derecha()
	if izq != der and _reten_teclas.is_empty() and z > z_decision_boca:
		obj = -1.0 if izq else 1.0
	_k = move_toward(_k, obj, andado * cambio_camino)
	if absf(_k) >= k_corte and obj != 0.0:
		_estado = "fuera"
		boca.emit("izquierda" if _k < 0.0 else "derecha")


## La salida del fondo, solo por el camino del centro.
func _mirar_salidas(z: float) -> void:
	if absf(_k) < 0.05:
		super(z)


## Lo que pasa los datos a los de los lados al cortar (cruce_bosque.gd).
func lado_actual() -> String:
	return "izquierda" if _k < 0.0 else "derecha"
