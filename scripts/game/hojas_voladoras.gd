extends Node2D
## Una capa de hojarasca de verdad, a la profundidad por la que anda Magnus: las
## hojas estan apiladas por columnas (COL px de ancho) y la altura del monton en
## cada x es cuantas hay (alto_hoja px por hoja). No hay dibujo fijo debajo: lo
## que se ve es lo que hay, y si se lleva una hoja de arriba el monton baja.
## La escena tiene dos capas: una algo detras de Magnus y otra algo delante
## (esta le tapa los pies).
##
## Lo que la mueve:
##   tomar()    quita las de arriba de unas columnas (piernas, pisadas, golpe)
##              y las devuelve para que quien llama las lance;
##   lanzar()   pone en vuelo una hoja (tomada de esta capa o de otra);
##   soltar()   una hoja nueva en el aire (las de arriba, las que se le
##              desprenden al levantarse, las migas).
## En el aire una hoja planea: el aire la frena a pocos cientos de px/s y, casi
## plana, se mece como un pendulo, gira sobre su eje largo y ensena cara y enves.
## De cara frena mas que de canto. Al llegar al monton rebota una vez, se
## arrastra si lleva velocidad de lado y se queda ENCIMA de las que haya en esa
## columna. Si una columna queda mucho mas alta que la de al lado, la de arriba
## resbala hacia la baja. Las migas (trozos pequenos) no se apilan: se pierden
## entre las hojas al caer.
##
## El mundo da la vuelta (ANCHO): lo que sale por un lado entra por el otro, y
## junto al borde se dibuja en los dos lados.
##
## Rendimiento: la fisica solo recorre las que se mueven; las posadas se dibujan
## en TRAMOS de columnas y cada tramo solo se repinta cuando cambia (andando, los
## dos o tres junto a los pies).

const ATLAS := preload("res://assets/world/hojarasca/hojas.png")
const COLS_ATLAS := 8
const FILAS_ATLAS := 4
const CELDA := Vector2(64, 128)
const ANCHO := 2912.0
const COL := 8.0
const N_COL := 364
const TRAMOS := 14
const COLS_TRAMO := 26

## Donde descansa la hoja de abajo de cada columna (y) y cuanto sube el monton
## por hoja. La de delante empieza mas abajo en pantalla (mas cerca).
@export var y_base: float = 1212.0
@export var alto_hoja: float = 6.5
## Luz: la mancha del suelo (la cuenta con que se pinto el lecho, luz_en de
## hojarasca.py) o el haz (el cono de fondo_haz), la que sea mas. Una hoja que
## cruza el haz se enciende. `brillo` por capa: la de detras, mas lejos, algo
## mas apagada, para que los planos se separen.
@export var y_suelo: float = 1200.0
@export var x_luz: float = 1456.0
@export var brillo: float = 1.0
const HAZ_ORIGEN := Vector2(1620.0, -700.0)
const HAZ_APERTURA := 0.17
## Gravedad y rozamiento del aire. Con estos numeros una hoja suelta cae a unos
## 150-260 px/s (de canto mas rapido), que a 2912 de ancho es ver caer una hoja.
@export var gravedad: float = 900.0
@export var rozamiento_plano: float = 5.5
@export var rozamiento_canto: float = 2.2
## Fraccion del rozamiento al salir lanzada (ver _physics_process).
@export var lanzada: float = 0.2
## Por debajo de esta escala es una miga.
@export var escala_miga: float = 0.16
## Al llegar deprisa rebota una vez (fraccion de la velocidad) y, si lleva
## velocidad de lado, se arrastra por encima de las otras hasta pararse.
@export var rebote: float = 0.2
@export var roce_suelo: float = 900.0
## Diferencia de hojas entre columnas vecinas a partir de la que la de arriba
## resbala a la mas baja.
@export var derrame: int = 3
## Tope de hojas en el aire (por si acaso).
@export var max_vuelan: int = 900
## Viento (px/s^2 en x) que empuja a las que vuelan; la escena lo pone con las
## rachas. Empuja mas a las que van de cara (mas superficie) y despacio.
var viento := 0.0

var _vuelan: Array[Dictionary] = []
var _cols: Array = []                 # N_COL listas de hojas, de abajo a arriba
var _tramos: Array[Node2D] = []
var _vuelo: Node2D
var _sucios := {}                     # tramo -> true

func _ready() -> void:
	_cols.resize(N_COL)
	for c in N_COL:
		_cols[c] = []
	for t in TRAMOS:
		var capa := Node2D.new()
		capa.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		capa.draw.connect(_dibujar_tramo.bind(capa, t))
		add_child(capa)
		_tramos.append(capa)
	_vuelo = Node2D.new()
	_vuelo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_vuelo.draw.connect(_dibujar_vuelo)
	add_child(_vuelo)

# --- Columnas ----------------------------------------------------------------

func _c(x: float) -> int:
	return posmod(int(floor(x / COL)), N_COL)

func _ensuciar(c: int) -> void:
	_sucios[c / COLS_TRAMO] = true

## Cuantas hojas hay en la columna de x.
func cuantas_en(x: float) -> int:
	return _cols[_c(x)].size()

## y de la superficie del monton en x (suavizada con las vecinas: una hoja mide
## mas que una columna).
func tope(x: float) -> float:
	var c := _c(x)
	var n: float = _cols[c].size() * 0.5 + (_cols[posmod(c - 1, N_COL)].size() + _cols[(c + 1) % N_COL].size()) * 0.25
	return y_base - n * alto_hoja

## Siembra el monton: `media` hojas por columna mas lo que diga `extra(x)` (px).
## Por pasadas (una hoja por columna cada vez) para que cada una caiga sobre lo
## que ya tienen sus vecinas y no sobre un hueco.
func sembrar(media: float, extra: Callable) -> void:
	var cuantas := PackedInt32Array()
	cuantas.resize(N_COL)
	var mas := 0
	for c in N_COL:
		cuantas[c] = int(media + extra.call((c + 0.5) * COL) / alto_hoja + randf())
		mas = maxi(mas, cuantas[c])
	for pasada in mas:
		for c in N_COL:
			if pasada < cuantas[c]:
				var x := (c + randf()) * COL
				_apilar(_nueva(Vector2(x, 0.0), -1.0), false)
	for t in TRAMOS:
		_sucios[t] = true

func _nueva(pos: Vector2, escala: float) -> Dictionary:
	return {
		"p": pos, "v": Vector2.ZERO,
		"rot": randf() * TAU,
		"giro": randf_range(-1, 1) * 9.0,           # rad/s en el plano
		"vuelta": randf() * TAU,                     # fase de la vuelta sobre el eje largo
		"vuelta_vel": randf_range(2.0, 7.0) * (1 if randf() < 0.5 else -1),
		"meceo": randf() * TAU,                      # fase del pendulo
		"meceo_vel": randf_range(2.2, 3.6),
		"meceo_amp": randf_range(70.0, 150.0),
		"esc": randf_range(0.26, 0.34) if escala < 0.0 else escala,
		"celda": randi() % (COLS_ATLAS * FILAS_ATLAS),
		"tono": randf_range(0.88, 1.1),
		"aplastar": randf_range(0.42, 0.62),
		"edad": 0.0,
		"botes": 0,
		"desliza": false,
	}

## La hoja se queda encima de su columna. Con `derramar`, si la columna queda
## mucho mas alta que una vecina, la de arriba resbala hacia ella.
func _apilar(h: Dictionary, derramar: bool = true) -> void:
	var c := _c(h["p"].x)
	h["p"] = Vector2(fposmod(h["p"].x, ANCHO), tope(h["p"].x) + randf_range(-1.5, 2.5))
	h["v"] = Vector2.ZERO
	h["desliza"] = false
	# Tumbada se ve de cara (o de enves), nunca de canto.
	var cv := cos(h["vuelta"])
	h["vuelta"] = acos(signf(cv) * maxf(absf(cv), 0.55))
	# Quieta no cambia de luz: se calcula una vez (repintar un tramo son cientos).
	h["luz"] = luz_en(h["p"])
	_cols[c].append(h)
	_ensuciar(c)
	if not derramar:
		return
	for lado in [-1, 1]:
		var vecina: int = posmod(c + lado, N_COL)
		if _cols[c].size() - _cols[vecina].size() > derrame:
			var arriba: Dictionary = _cols[c].pop_back()
			_ensuciar(c)
			arriba["desliza"] = true
			arriba["v"] = Vector2(lado * randf_range(40.0, 90.0), 0.0)
			_vuelan.append(arriba)
			break

## Quita hojas de arriba de las columnas entre x0 y x1 (en el sentido que sea),
## sin dejar ninguna por debajo de `queda`, como mucho `maximo` y cada una con
## probabilidad `prob`. Devuelve las hojas, ya fuera del monton, para lanzarlas.
func tomar(x0: float, x1: float, maximo: int, queda: int = 1, prob: float = 1.0) -> Array[Dictionary]:
	var fuera: Array[Dictionary] = []
	var a := int(floor(minf(x0, x1) / COL))
	var b := int(floor(maxf(x0, x1) / COL))
	# Empezando por las columnas mas altas: es de donde sobresale la hoja.
	var orden: Array = []
	for ci in range(a, b + 1):
		orden.append(posmod(ci, N_COL))
	orden.sort_custom(func(p: int, q: int) -> bool: return _cols[p].size() > _cols[q].size())
	for c in orden:
		var col: Array = _cols[c]
		while col.size() > queda and fuera.size() < maximo and randf() < prob:
			fuera.append(col.pop_back())
			_ensuciar(c)
		if fuera.size() >= maximo:
			break
	return fuera

## Pone en vuelo una hoja (tomada de esta capa o de la otra).
func lanzar(h: Dictionary, vel: Vector2, giro: float = INF) -> void:
	if _vuelan.size() >= max_vuelan:
		_apilar(h)
		return
	h["v"] = vel
	h["edad"] = 0.0
	h["botes"] = 0
	h["desliza"] = false
	h["giro"] = randf_range(-9.0, 9.0) if giro == INF else giro
	h["vuelta_vel"] = randf_range(2.0, 7.0) * (1 if randf() < 0.5 else -1)
	h["p"] = Vector2(h["p"].x, h["p"].y - 2.0)
	_vuelan.append(h)

## Una hoja nueva en el aire. `giro` (rad/s) a INF: al azar.
func soltar(pos: Vector2, vel: Vector2, escala: float = -1.0, giro: float = INF) -> void:
	lanzar(_nueva(pos, escala), vel, giro)

func luz_en(p: Vector2) -> float:
	var dx := (p.x - x_luz) / 1050.0
	var dy := (p.y - y_suelo) / 520.0
	var suelo := 0.28 + 0.87 * exp(-(dx * dx + 0.6 * dy * dy) * 1.6)
	var eje := (Vector2(x_luz, y_suelo) - HAZ_ORIGEN).normalized()
	var a := eje.angle_to(p - HAZ_ORIGEN)
	var haz := 0.28 + 0.8 * (1.0 - smoothstep(HAZ_APERTURA * 0.35, HAZ_APERTURA, absf(a)))
	return maxf(suelo, haz) * brillo

# --- Fisica de las que se mueven ---------------------------------------------

func _physics_process(delta: float) -> void:
	var i := 0
	while i < _vuelan.size():
		var h: Dictionary = _vuelan[i]
		var v: Vector2 = h["v"]
		if h["desliza"]:
			# Arrastrandose por encima del monton, pegada a su superficie.
			v.x = move_toward(v.x, 0.0, roce_suelo * delta)
			h["giro"] *= exp(-5.0 * delta)
			h["rot"] += h["giro"] * delta
			var x := fposmod(h["p"].x + v.x * delta, ANCHO)
			h["p"] = Vector2(x, tope(x))
			h["v"] = v
			if absf(v.x) < 6.0:
				_vuelan.remove_at(i)
				_posar(h)
				continue
			i += 1
			continue
		h["vuelta"] += h["vuelta_vel"] * delta
		h["meceo"] += h["meceo_vel"] * delta
		h["rot"] += h["giro"] * delta
		# De cara frena mas; |cos| de la vuelta es lo plana que se ve.
		var plana := absf(cos(h["vuelta"]))
		var k := lerpf(rozamiento_canto, rozamiento_plano, plana)
		# Recien lanzada sale de canto y casi sin frenar: si no, el golpe solo
		# las levanta un palmo. En medio segundo ya planea como las demas.
		h["edad"] += delta
		k *= lerpf(lanzada, 1.0, clampf(h["edad"] / 0.55, 0.0, 1.0))
		v.y += gravedad * delta
		v *= exp(-k * delta)
		# El pendulo: empuje lateral que cambia de lado, mas fuerte cuanto mas
		# despacio va (recien soltada vuela recta).
		var lenta := clampf(1.0 - v.length() / 600.0, 0.0, 1.0)
		v.x += cos(h["meceo"]) * h["meceo_amp"] * lenta * delta * 3.0
		v.x += viento * (0.4 + 0.6 * plana) * (0.3 + 0.7 * lenta) * delta
		# Al mecerse se inclina hacia donde se desliza; el giro libre se apaga.
		h["giro"] = lerpf(h["giro"], -sin(h["meceo"]) * 1.6 * lenta, 1.0 - exp(-1.5 * delta))
		var p: Vector2 = h["p"] + v * delta
		p.x = fposmod(p.x, ANCHO)
		var suelo := tope(p.x)
		if p.y >= suelo and v.y > 0.0:
			p.y = suelo
			if v.y > 200.0 and h["botes"] == 0:
				h["botes"] = 1
				v = Vector2(v.x * 0.6, -v.y * rebote)
				h["giro"] *= 0.5
			elif absf(v.x) > 30.0:
				h["desliza"] = true
				v.y = 0.0
			else:
				h["p"] = p
				_vuelan.remove_at(i)
				_posar(h)
				continue
		h["p"] = p
		h["v"] = v
		i += 1
	_vuelo.queue_redraw()
	for t in _sucios:
		_tramos[t].queue_redraw()
	_sucios.clear()

## Las migas se pierden entre las hojas; las hojas se apilan.
func _posar(h: Dictionary) -> void:
	if h["esc"] < escala_miga:
		return
	_apilar(h)

# --- Dibujo ------------------------------------------------------------------

## Las posadas del tramo, por niveles: primero la de abajo de cada columna, luego
## la segunda... asi las de arriba tapan a las de abajo en todo el tramo. Las de
## abajo, en la sombra de las de encima.
func _dibujar_tramo(capa: Node2D, tramo: int) -> void:
	var c0 := tramo * COLS_TRAMO
	var c1 := mini(c0 + COLS_TRAMO, N_COL)
	var niveles := 0
	for c in range(c0, c1):
		niveles = maxi(niveles, _cols[c].size())
	for nivel in niveles:
		for c in range(c0, c1):
			var col: Array = _cols[c]
			if nivel >= col.size():
				continue
			var sombra := 0.55 + 0.45 * float(nivel + 1) / col.size()
			_dibujar_hoja(capa, col[nivel], true, sombra)
	capa.draw_set_transform_matrix(Transform2D.IDENTITY)

func _dibujar_vuelo() -> void:
	for h in _vuelan:
		_dibujar_hoja(_vuelo, h, h["desliza"], 1.0)
	_vuelo.draw_set_transform_matrix(Transform2D.IDENTITY)

func _dibujar_hoja(capa: Node2D, h: Dictionary, tumbada: bool, sombra: float) -> void:
	var p: Vector2 = h["p"]
	var esc: float = h["esc"]
	var celda: int = h["celda"]
	var region := Rect2(Vector2(celda % COLS_ATLAS, celda / COLS_ATLAS) * CELDA, CELDA)
	var luz: float = (h["luz"] if capa != _vuelo else luz_en(p)) * h["tono"] * sombra
	var c := cos(h["vuelta"])
	var ex: float
	if tumbada:
		ex = esc * signf(c) * maxf(absf(c), 0.55)
		luz *= 0.92
	else:
		ex = esc * c
		# Casi de canto se ve una raya; con 0 desaparece y parpadea.
		if absf(ex) < esc * 0.08:
			ex = esc * 0.08 * (1.0 if c >= 0.0 else -1.0)
	# Envés: mas apagado y menos saturado.
	if c < 0.0:
		luz *= 0.78
	var col := Color(luz, luz * (0.97 if c >= 0.0 else 0.93), luz * (0.95 if c >= 0.0 else 0.85))
	# Junto a un borde se dibuja tambien al otro lado (el mundo da la vuelta).
	var copias := [0.0]
	if p.x < 40.0:
		copias.append(ANCHO)
	elif p.x > ANCHO - 40.0:
		copias.append(-ANCHO)
	for desplaza in copias:
		var q := p + Vector2(desplaza, 0.0)
		if tumbada:
			# Aplastada en pantalla: se escala el eje y del mundo despues de girar.
			var t := Transform2D(h["rot"], Vector2(ex, esc), 0.0, Vector2.ZERO)
			t = Transform2D(Vector2(1, 0), Vector2(0, h["aplastar"]), q) * t
			capa.draw_set_transform_matrix(t)
		else:
			capa.draw_set_transform(q, h["rot"], Vector2(ex, esc))
		capa.draw_texture_rect_region(ATLAS, Rect2(-CELDA / 2.0, CELDA), region, col)
