extends "res://scripts/game/peregrino_camino.gd"
## El peregrino en el cruce del bosque (cruce_bosque.gd), DE ESPALDAS: es el
## contraplano del camino del bosque, la camara de detras. Lo mismo que en el
## camino (peregrino_camino.gd: el componente, su luz, su sombra, el paralaje,
## las pisadas), con los caminos de esta foto.
##
## ENTRA andando: en el camino venia hacia aquella camara y al llegar delante
## corto aqui, asi que aparece abajo, grande, de espaldas, y sigue andando si se
## mantiene la tecla (TECLA RETENIDA: abajo, que alli le traia hacia la camara,
## aqui le aleja mientras siga pulsada; arriba ya es alejarse). Sin escena de
## antes (abierta sola, o al continuar la partida), quieto de espaldas.
##
## LOS TRES CAMINOS. Arriba se aleja por el camino en el que este y abajo vuelve
## hacia la camara. En la explanada de la entrada (hasta z_decision) izquierda o
## derecha eligen camino: el del centro, que baja a la casa de Dominus (su verja
## asoma en la niebla del fondo); el de la izquierda, que sale casi de lado; el
## de la derecha, que sube entre las rocas. Con izquierda o derecha tambien
## anda (en la explanada, o por el camino de ese lado). El cambio de camino va
## con lo que anda (nunca se desliza de lado parado): entre dos caminos, sus
## pies van entre los dos (_k, de -1 izquierda a 1 derecha); pasada la
## explanada, al mas cercano.
## Cada camino es una lista de puntos (x, y, z): donde se ven los pies y la fila
## que tendrian en suelo llano a esa distancia (la escala sale de z). En llano
## z = y; en el de la derecha, que sube, z > y. Andar no cambia: el componente
## avanza 1/escala recto en el tiempo y aqui solo se dice donde caen los pies.
##
## SALIDAS. Al fondo de cada camino emite `salida` ("casa", "izquierda" o
## "derecha") y sigue andando; la escena decide (de momento, a negro). Por el
## del centro, antes, se pierde en la niebla de delante de la casa (vista). Si
## vuelve hacia la camara hasta pies_corte_vuelta, `se_va`: corte al camino del
## bosque, que le recibe de espaldas.

signal salida(cual: String)

## Los caminos en la foto (x, y, z), del pie de la camara al fondo: todos salen
## del mismo punto (por donde entra).
const CENTRO: Array[Vector3] = [Vector3(1480, 1490, 1490), Vector3(1470, 1400, 1400), Vector3(1478, 1290, 1290),
	Vector3(1490, 1190, 1190), Vector3(1497, 1120, 1120), Vector3(1500, 1062, 1062)]
const IZQUIERDA: Array[Vector3] = [Vector3(1480, 1490, 1490), Vector3(1420, 1430, 1430), Vector3(1200, 1350, 1350),
	Vector3(900, 1285, 1285), Vector3(600, 1225, 1225), Vector3(300, 1160, 1160), Vector3(60, 1105, 1105)]
const DERECHA: Array[Vector3] = [Vector3(1480, 1490, 1490), Vector3(1560, 1430, 1430), Vector3(1790, 1355, 1355),
	Vector3(2040, 1275, 1275), Vector3(2240, 1195, 1200), Vector3(2410, 1105, 1150), Vector3(2530, 1015, 1115),
	Vector3(2610, 945, 1092)]

@export_group("Cruce")
## Donde entra (z, la del primer punto de los caminos) y, volviendo hacia la
## camara, donde corta al camino del bosque.
@export var pies_inicio := 1490.0
@export var pies_corte_vuelta := 1522.0
## Hasta donde se puede elegir camino (z): la explanada de la entrada y la boca
## de los caminos (con 1330, la explanada sola, andando se cruzaba en 1,5 s).
@export var z_decision := 1290.0
## Lo que cambia _k por cada unidad de 1/escala andada (con 7, de un camino a
## otro en unos tres segundos de andar por la explanada).
@export var cambio_camino := 7.0
## z en que sale por cada camino: sigue andando hasta el final del camino, que
## tiene que quedar lejos (al llegar al ultimo punto anda en el sitio): el
## fundido tarda 1,6 s y por la derecha, a 1135, llegaba al final en 1 s.
@export var z_salida := {"casa": 1080.0, "izquierda": 1140.0, "derecha": 1165.0}
## La niebla de delante de la casa: de z_niebla.x (se le ve entero) a z_niebla.y
## (todo niebla), solo por el camino del centro.
@export var z_niebla := Vector2(1135.0, 1068.0)
## El resplandor del fondo (el filo de contraluz): el de esta foto.
@export var resplandor := Vector2(1630.0, 560.0)

var _k := 0.0
var _objetivo := 0.0
var _inv_antes := 0.0


func _ready() -> void:
	# (las mascaras, el horizonte (1000) y pies_tope, en cruce_bosque.tscn)
	super()
	# del camino o sola: a la vista y con el mando desde el principio
	visible = true
	peregrino.process_mode = Node.PROCESS_MODE_INHERIT
	_escala_entrada = _escala_de(1120.0)
	_escala_hasta = _escala_de(pies_inicio)
	_estado = "jugando"
	_vista = 1.0
	_inv_antes = 1.0 / peregrino.escala
	_mat.set_shader_parameter("resplandor", resplandor)
	# del camino, andando hacia aquella camara: aqui sigue andando, alejandose
	var del_camino := str(Estado.leer(get_tree()).get("viene_de", "")) == "camino_bosque"
	_reten_abajo = del_camino and _abajo()
	if del_camino and (_reten_abajo or _arriba()):
		peregrino.empezar_andando("espalda")


func _antes_de_meter() -> void:
	peregrino.cara = "espalda"
	peregrino.escala_inicial = _escala_de(pies_inicio)
	peregrino.escala_max = _escala_de(pies_tope)


## Aqui entra desde el principio (_ready); lo que pida la escena no cambia nada.
func entrar(_espera := 0.0) -> void:
	pass


func _izquierda() -> bool:
	return Input.is_action_pressed("mover_izquierda") or Input.is_key_pressed(KEY_LEFT)


func _derecha() -> bool:
	return Input.is_action_pressed("mover_derecha") or Input.is_key_pressed(KEY_RIGHT)


## La fila que tendrian sus pies en suelo llano (de ella sale la escala).
func _z_de(escala: float) -> float:
	return horizonte + escala * ALTO_ESCALA_1 / ALTO_POR_PIES


## El camino en el que esta (el mas cercano de los tres).
func camino() -> String:
	var r := roundi(_k)
	return "izquierda" if r < 0 else ("derecha" if r > 0 else "casa")


## Los pies en el suelo de la foto, sin la camara: en su camino (o entre dos).
func _suelo(escala: float) -> Vector2:
	var z := _z_de(escala)
	var c := _en(CENTRO, z)
	if _k < 0.0:
		return c.lerp(_en(IZQUIERDA, z), -_k)
	return c.lerp(_en(DERECHA, z), _k)


## Donde caen los pies a la distancia z en un camino. Mas cerca que su primer
## punto, en llano hacia abajo; mas lejos que el ultimo, en el ultimo.
func _en(lista: Array[Vector3], z: float) -> Vector2:
	if z >= lista[0].z:
		return Vector2(lista[0].x, lista[0].y + (z - lista[0].z))
	for i in range(1, lista.size()):
		var b := lista[i]
		if z >= b.z:
			var a := lista[i - 1]
			var t := (a.z - z) / maxf(a.z - b.z, 0.001)
			return Vector2(lerpf(a.x, b.x, t), lerpf(a.y, b.y, t))
	return Vector2(lista[-1].x, lista[-1].y)


func _process(_delta: float) -> void:
	var escala := peregrino.escala
	var z := _z_de(escala)
	var en_explanada := z > z_decision
	match _estado:
		"jugando":
			var abajo := _abajo()
			var arriba := _arriba()
			if _reten_abajo and not abajo:
				_reten_abajo = false
			if _reten_abajo:
				# la tecla con la que venia del camino: sigue alejandose
				arriba = true
				abajo = false
			var izq := _izquierda()
			var der := _derecha()
			if izq != der:
				var lado := -1 if izq else 1
				if en_explanada:
					_objetivo = lado
				# tambien anda: en la explanada, o por el camino de ese lado
				if (en_explanada or roundi(_k) == lado) and not abajo:
					arriba = true
			var q := "frente" if abajo and not arriba else ("espalda" if arriba and not abajo else "")
			if q == "frente" and escala >= _escala_de(pies_corte_vuelta):
				# de vuelta hacia la camara: corte al camino del bosque (sigue andando)
				_estado = "fuera"
				se_va.emit()
			peregrino.quiere = q
			var c := camino()
			if peregrino.mirando == "espalda" and absf(_k - roundi(_k)) < 0.05 and z <= float(z_salida[c]):
				# al fondo de su camino: sale (y sigue andando por el)
				_estado = "saliendo"
				peregrino.quiere = "espalda"
				salida.emit(c)
		"saliendo":
			peregrino.quiere = "espalda"
	# el cambio de camino, con lo que anda (parado no se mueve de lado)
	var inv := 1.0 / escala
	var andado := absf(inv - _inv_antes)
	_inv_antes = inv
	var obj := _objetivo if en_explanada else float(roundi(_k))
	_objetivo = obj
	_k = move_toward(_k, obj, andado * cambio_camino)
	# por el del centro, al fondo, se pierde en la niebla de delante de la casa
	var centro := 1.0 - absf(_k)
	_vista = 1.0 - (1.0 - smoothstep(z_niebla.y, z_niebla.x, z)) * centro
	peregrino.pasos_db = pasos_db + linear_to_db(maxf(_vista, 0.001))
	if controlador:
		var hojas := controlador.get_node_or_null("Hojas")
		if hojas and hojas.has_method("z_del_suelo"):
			hojas.corte = hojas.z_del_suelo(_suelo(escala).y)
	_luz()
	_sombra.queue_redraw()
