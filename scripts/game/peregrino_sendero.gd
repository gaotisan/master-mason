extends "res://scripts/game/peregrino_camino.gd"
## El peregrino en un plano FRONTAL con un camino que va hacia el fondo (el cruce
## del bosque, el camino derecho...): lo mismo que en el camino del bosque
## (peregrino_camino.gd: el componente de frente, su luz, su sombra, el paralaje,
## las pisadas) con un camino de la foto por el que van los pies.
##
## EL CAMINO es una lista de puntos (x, y, z) de cerca a lejos: donde se ven los
## pies (x, y, por el CENTRO de la arena, medido en la foto) y la fila que
## tendrian en suelo llano a esa distancia (z: de ella sale la escala). En llano
## z = y; si el camino sube, y < z. Entre los puntos, una curva que pasa por
## ellos (Catmull-Rom). Andar no cambia: el componente avanza 1/escala recto en el
## tiempo y aqui solo se dice donde caen los pies.
##
## ENTRA por abajo, de espaldas y andando (el corte de la escena de antes le pillo
## andando hacia aqui), en pies_inicio. TECLA RETENIDA: las teclas de direccion
## que llegan pulsadas de la otra escena (alli significaban otra cosa) le hacen
## seguir hacia donde iba mientras sigan pulsadas; al soltarlas, lo normal.
## Arriba se aleja y abajo viene hacia la camara; el baculo con su tecla.
## Volviendo hasta pies_corte_vuelta, `se_va` (corte a la escena de antes). Al
## fondo, en z_salida, `salida` (y sigue andando); antes, si hay z_niebla, se
## pierde en la niebla del fondo.
##
## LUZ: la de alrededor (la del camino del bosque) y, como minimo, rebote_suelo
## veces el brillo de la arena que pisa: entre matas y troncos oscuros de suyo, la
## de alrededor le dejaba casi en silueta. La sombra alargada se aparta del
## resplandor (en diagonal si no esta delante de el).

signal salida(cual: String)

@export_group("Sendero")
## El camino (x, y, z) de cerca a lejos.
@export var camino := PackedVector3Array([Vector3(1480, 1490, 1490), Vector3(1480, 1100, 1100)])
## Por donde entra (z) y, volviendo hacia la camara, donde corta (z).
@export var pies_inicio := 1490.0
@export var pies_corte_vuelta := 1522.0
## z en que sale por el fondo, y como se llama esa salida.
@export var z_salida := 1080.0
@export var nombre_salida := "fondo"
## La niebla del fondo: de z_niebla.x (se le ve entero) a z_niebla.y (todo
## niebla); (0, 0): sin niebla.
@export var z_niebla := Vector2.ZERO
## El resplandor del fondo (el filo de contraluz y hacia donde no cae la sombra).
@export var resplandor := Vector2(1456.0, 520.0)
## Ver LUZ.
@export var rebote_suelo := 2.2
@export var luz_zona := 0.25
## Escena de la que viene por abajo (PeregrinoEstado viene_de): de ella entra
## andando de espaldas. "" = de cualquiera.
@export var entra_de := ""

var _reten_teclas: Array[String] = []   # las que llegaron pulsadas
var _reten_hacia := ""                  # y hacia donde le llevan


func _ready() -> void:
	super()
	visible = true
	peregrino.process_mode = Node.PROCESS_MODE_INHERIT
	_escala_entrada = _escala_de(camino[camino.size() - 1].z)
	_escala_hasta = _escala_de(pies_inicio)
	_estado = "jugando"
	_vista = 1.0
	_mat.set_shader_parameter("resplandor", resplandor)
	_mat.set_shader_parameter("luz_zona", luz_zona)
	_entrar_andando()


## Como entra: de la escena de abajo, andando de espaldas si se trae alguna tecla
## pulsada; si no (sola, o al continuar), quieto de espaldas.
func _entrar_andando() -> void:
	var viene := str(Estado.leer(get_tree()).get("viene_de", ""))
	if viene == "" or (entra_de != "" and viene != entra_de):
		return
	_retener("espalda")
	if not _reten_teclas.is_empty():
		peregrino.empezar_andando("espalda")


## Apunta las teclas de direccion pulsadas ahora: mientras sigan, hacia `hacia`.
func _retener(hacia: String) -> void:
	_reten_teclas.clear()
	for a in ["saltar", "agacharse", "mover_izquierda", "mover_derecha"]:
		if _pulsada(a):
			_reten_teclas.append(a)
	_reten_hacia = hacia


func _antes_de_meter() -> void:
	peregrino.cara = "espalda"
	peregrino.escala_inicial = _escala_de(pies_inicio)
	peregrino.escala_max = _escala_de(pies_tope)


func _viene_de_delante(_viene_de: String) -> bool:
	return false


## Entra desde el principio (_ready); lo que pida la escena no cambia nada.
func entrar(_espera := 0.0) -> void:
	pass


static func _pulsada(accion: String) -> bool:
	var tecla := {"saltar": KEY_UP, "agacharse": KEY_DOWN, "mover_izquierda": KEY_LEFT, "mover_derecha": KEY_RIGHT}
	return Input.is_action_pressed(accion) or Input.is_key_pressed(tecla[accion])


func _izquierda() -> bool:
	return _pulsada("mover_izquierda")


func _derecha() -> bool:
	return _pulsada("mover_derecha")


## Hacia donde quiere ir ("frente", "espalda" o ""), con la tecla retenida.
func _direccion() -> String:
	if not _reten_teclas.is_empty():
		_reten_teclas = _reten_teclas.filter(func(a): return _pulsada(a))
		if not _reten_teclas.is_empty():
			return _reten_hacia
	var arriba := _arriba()
	var abajo := _abajo()
	return "frente" if abajo and not arriba else ("espalda" if arriba and not abajo else "")


## La fila que tendrian sus pies en suelo llano (de ella sale la escala).
func _z_de(escala: float) -> float:
	return horizonte + escala * ALTO_ESCALA_1 / ALTO_POR_PIES


## Los pies en el suelo de la foto, sin la camara.
func _suelo(escala: float) -> Vector2:
	return _en(camino, _z_de(escala))


## Donde caen los pies a la distancia z en un camino. Mas cerca que su primer
## punto, en llano hacia abajo; mas lejos que el ultimo, en el ultimo.
static func _en(lista: PackedVector3Array, z: float) -> Vector2:
	if z >= lista[0].z:
		return Vector2(lista[0].x, lista[0].y + (z - lista[0].z))
	for i in range(1, lista.size()):
		var b := lista[i]
		if z >= b.z:
			var a := lista[i - 1]
			var t := (a.z - z) / maxf(a.z - b.z, 0.001)
			var p0 := lista[maxi(i - 2, 0)]
			var p3 := lista[mini(i + 1, lista.size() - 1)]
			return Vector2(a.x, a.y).cubic_interpolate(Vector2(b.x, b.y), Vector2(p0.x, p0.y), Vector2(p3.x, p3.y), t)
	return Vector2(lista[lista.size() - 1].x, lista[lista.size() - 1].y)


func _process(_delta: float) -> void:
	var escala := peregrino.escala
	var z := _z_de(escala)
	match _estado:
		"jugando":
			var q := _quiere(z)
			if q == "frente" and escala >= _escala_de(pies_corte_vuelta):
				# de vuelta hacia la camara: corte a la escena de antes (sigue andando)
				_estado = "fuera"
				se_va.emit()
			peregrino.quiere = q
			_mirar_salidas(z)
		"saliendo":
			peregrino.quiere = "espalda"
	_vista = _vista_en(z)
	peregrino.pasos_db = pasos_db + linear_to_db(maxf(_vista, 0.001))
	if controlador:
		var hojas := controlador.get_node_or_null("Hojas")
		if hojas and hojas.has_method("z_del_suelo"):
			hojas.corte = hojas.z_del_suelo(_suelo(escala).y)
	_luz()
	_sombra.queue_redraw()


## Lo que quiere hacer ahora (las que lo heredan anaden lo suyo).
func _quiere(_z: float) -> String:
	return _direccion()


## Al fondo del camino: sale (y sigue andando por el).
func _mirar_salidas(z: float) -> void:
	if peregrino.mirando == "espalda" and z <= z_salida:
		_estado = "saliendo"
		peregrino.quiere = "espalda"
		salida.emit(nombre_salida)


## Lo que se le ve a esa distancia (la niebla del fondo).
func _vista_en(z: float) -> float:
	if z_niebla.x <= 0.0:
		return 1.0
	return smoothstep(z_niebla.y, z_niebla.x, z)


## La sombra: la de contacto y la alargada, apartandose del resplandor (por la
## recta del suelo que va de su pie en el horizonte a los pies del peregrino).
func _dibujar_sombra() -> void:
	var alto := peregrino.escala * ALTO_ESCALA_1
	var p := peregrino.pies
	var a := smoothstep(0.3, 1.0, _vista)
	var ancho := alto * 0.42
	_sombra.draw_texture_rect(_tex_sombra, Rect2(p - Vector2(ancho * 0.5, ancho * 0.07), Vector2(ancho, ancho * 0.14)),
		false, Color(0.02, 0.015, 0.01, sombra * a))
	if sombra_larga > 0.0:
		var largo := alto * 0.32
		var ancho_l := alto * 0.22
		var giro := clampf(Vector2.DOWN.angle_to(p - Vector2(resplandor.x, horizonte)), -1.05, 1.05)
		_sombra.draw_set_transform(p, giro, Vector2.ONE)
		_sombra.draw_texture_rect(_tex_sombra, Rect2(Vector2(-ancho_l * 0.5, -largo * 0.12), Vector2(ancho_l, largo)),
			false, Color(0.02, 0.015, 0.01, sombra_larga * a))
		_sombra.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## La luz de alrededor y la arena clara que pisa (ver LUZ).
func _ambiente(pies: Vector2, alto: float) -> Color:
	var alrededor := super(pies, alto)
	var suma := Color(0, 0, 0)
	for i in 5:
		var p := pies + Vector2((i - 2) * alto * 0.12, alto * 0.03)
		var x := clampi(int(p.x / PANTALLA.x * _medio.get_width()), 0, _medio.get_width() - 1)
		var y := clampi(int(p.y / PANTALLA.y * _medio.get_height()), 0, _medio.get_height() - 1)
		suma += _medio.get_pixel(x, y)
	var suelo := Color(suma.r / 5.0, suma.g / 5.0, suma.b / 5.0) * rebote_suelo
	return Color(maxf(alrededor.r, suelo.r), maxf(alrededor.g, suelo.g), maxf(alrededor.b, suelo.b))
