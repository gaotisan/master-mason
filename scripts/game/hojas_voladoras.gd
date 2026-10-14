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
## DE FUERA (2026-10-14): las que llegan de fuera del lecho (marcadas
## "de_fuera": las de los arboles, las que bajan por la luz) no cambian cuantas
## hay en cada columna. Las grandes (>= de_fuera_minima) se quedan en el sitio
## de la de arriba, que se va; las pequenas se hunden entre las demas
## (hundirse s, desvaneciendose). Las que mueve el peregrino si se apilan: es lo
## que hace que cada pasada deje el lecho distinto. Antes las de los arboles se
## apilaban sin fin (el lecho crecia un 20 % cada media hora y en una noche
## subia ~175 px) y las de la luz quitaban la hoja de abajo de su columna sin
## bajar las de encima: bajo el haz las columnas se quedaban huecas por debajo
## (51 px a la media hora: "unos huecazos").
##
## El mundo da la vuelta (ANCHO): lo que sale por un lado entra por el otro, y
## junto al borde se dibuja en los dos lados.
##
## Rendimiento: la fisica solo recorre las que se mueven. Las posadas van todas
## en un MultiMesh por capa (hojas_lecho.gdshader; 2026-10-14): posar o quitar
## una hoja cambia su instancia y los colores de su columna, nada mas. Antes se
## dibujaban por tramos de columnas y cada tramo tocado se repintaba entero:
## cuando la racha del camino dejaba caer cientos de hojas se repintaba casi
## todo el lecho en cada tick (20-60 ms) y el juego iba a tirones. El orden de
## las instancias es el de dibujo: las de abajo antes; una hoja nueva va al
## final (encima) y cuando se llena se rehace todo por niveles (_mm_rehacer).

const ATLAS := preload("res://assets/world/hojarasca/hojas.png")
const COLS_ATLAS := 8
const FILAS_ATLAS := 4
const CELDA := Vector2(64, 128)
const ANCHO := 2912.0
const COL := 8.0
const N_COL := 364
## La luz de una hoja sin el haz (la del claro a oscuras): la base de luz_en y
## lo que queda con luz_viva a 0.
const LUZ_OSCURA := 0.28
const MALLA_SHADER := preload("res://scripts/game/hojas_lecho.gdshader")

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
## El haz: lo pone la escena con poner_haz (el del material del fondo, para que
## haya una sola geometria del haz); estos son los de fondo_haz por si no.
var haz_origen := Vector2(1620.0, -700.0)
var haz_apertura := 0.17
## Lo que queda del haz (1 entero, 0 apagado: el claro a oscuras). Las posadas
## lo hacen en su shader; las que vuelan, en luz_en.
var luz_viva := 1.0:
	set(v):
		luz_viva = v
		if _mm_nodo:
			(_mm_nodo.material as ShaderMaterial).set_shader_parameter("luz_viva", v)

## El haz de la escena: su vertice, adonde pega en el suelo (x_luz, y_suelo) y
## su apertura (rad).
func poner_haz(origen: Vector2, destino: Vector2, apertura: float) -> void:
	haz_origen = origen
	x_luz = destino.x
	y_suelo = destino.y
	haz_apertura = apertura
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
## Ver DE FUERA: lo que mide una hoja de fuera para quedarse en el lecho, y lo
## que tarda en hundirse una mas pequena (s).
@export var de_fuera_minima: float = 0.26
@export var hundirse: float = 1.4
## Viento (px/s^2 en x) que empuja a las que vuelan; la escena lo pone con las
## rachas. Empuja mas a las que van de cara (mas superficie) y despacio.
var viento := 0.0
## Empuje hacia arriba (px/s^2) de una racha muy fuerte (la que destapa el
## camino): las que vuelan suben remolineando mientras sopla.
var viento_arriba := 0.0
## LAS HOJAS DE LA LUZ (2026-10-11). Las que caen de arriba (soltar con
## `ligera`) pesan poco en la luz, como Magnus: su gravedad se multiplica por
## lerp(1, gravedad_luz, ligereza(p)) y bajan por el haz despacio. Las que
## levantan los pies no (el lecho se queda como estaba). La escena pone
## ligereza y gravedad_luz (las de Magnus).
## Las de la escalera (escalon(): con un sitio) bajan planeando hasta su sitio
## y se quedan alli flotando, con un vaiven leve. Son las unicas que aguantan a
## Magnus: apoyo() busca la que tiene bajo los pies y pisar() la hunde un palmo,
## girando; la luz la vuelve a subir a su sitio (un muelle amortiguado) y,
## cuando llega, vuelve a aguantar. Asi la escalera siempre esta.
var ligereza: Callable
var gravedad_luz := 0.3

var _vuelan: Array[Dictionary] = []
var _hundiendo: Array[Dictionary] = []   # de fuera y pequenas, desvaneciendose (ver DE FUERA)
var _cols: Array = []                 # N_COL listas de hojas, de abajo a arriba
var _vuelo: Node2D
var _sucias := {}                     # columna -> true: repintar sus colores (la sombra va por altura)
var _mm: MultiMesh                    # las posadas (ver Rendimiento)
var _mm_nodo: MultiMeshInstance2D
var _mm_libre := 0                    # siguiente instancia libre (se dibujan en orden)

func _ready() -> void:
	_cols.resize(N_COL)
	for c in N_COL:
		_cols[c] = []
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = _malla_hoja()
	_mm.instance_count = 4096
	_mm.visible_instance_count = 0
	_mm_nodo = MultiMeshInstance2D.new()
	_mm_nodo.multimesh = _mm
	_mm_nodo.texture = ATLAS
	_mm_nodo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mat := ShaderMaterial.new()
	mat.shader = MALLA_SHADER
	mat.set_shader_parameter("luz_viva", luz_viva)
	_mm_nodo.material = mat
	add_child(_mm_nodo)
	_vuelo = Node2D.new()
	_vuelo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_vuelo.draw.connect(_dibujar_vuelo)
	add_child(_vuelo)

# --- Columnas ----------------------------------------------------------------

func _c(x: float) -> int:
	return posmod(int(floor(x / COL)), N_COL)

func _ensuciar(c: int) -> void:
	_sucias[c] = true

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
	_pintar_sucias()

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
		"ligera": false,
		"pisada": false,
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
	# Quieta no cambia de luz: se calcula una vez (la entera: lo que quite el
	# haz al apagarse lo hace su shader, ver luz_viva).
	h["luz"] = luz_en(h["p"], false)
	_cols[c].append(h)
	_mm_poner(h)
	_ensuciar(c)
	if not derramar:
		return
	for lado in [-1, 1]:
		var vecina: int = posmod(c + lado, N_COL)
		if _cols[c].size() - _cols[vecina].size() > derrame:
			var arriba: Dictionary = _cols[c].pop_back()
			_mm_quitar(arriba)
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
			var h: Dictionary = col.pop_back()
			_mm_quitar(h)
			fuera.append(h)
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

## Una hoja nueva en el aire. `giro` (rad/s) a INF: al azar. `ligera`: de las
## que caen de arriba (ver LAS HOJAS DE LA LUZ). Devuelve la hoja.
func soltar(pos: Vector2, vel: Vector2, escala: float = -1.0, giro: float = INF, ligera := false) -> Dictionary:
	var h := _nueva(pos, escala)
	h["ligera"] = ligera
	lanzar(h, vel, giro)
	return h

## Una hoja de la escalera: entra por `desde` y baja planeando hasta `sitio`,
## donde se queda flotando. Devuelve la hoja. Si lleva "entrando" (lo pone
## quien la crea), no aguanta hasta llegar a su sitio.
func escalon(desde: Vector2, sitio: Vector2, escala: float) -> Dictionary:
	var h := _nueva(desde, escala)
	h["ligera"] = true
	h["sitio"] = sitio
	h["fase"] = randf() * TAU
	# Tumbada (la celda del atlas es una hoja de pie), algo inclinada: se lee
	# como un sitio donde apoyarse.
	h["giro_base"] = PI * 0.5 * (1.0 if randf() < 0.5 else -1.0) + randf_range(-0.3, 0.3)
	h["vuelta"] = randf_range(-0.3, 0.3)
	h["v"] = Vector2.ZERO
	_vuelan.append(h)
	return h

## La hoja de la escalera (sin pisar y con luz de sobra en su sitio) que los
## pies pueden pisar: dentro de `ancho` px de x a cada lado (mas su medio
## ancho) y con su y entre y0 y y1 (los pies el tick de antes y ahora, con
## margen). La mas alta. Vacio si no hay.
func apoyo(x: float, y0: float, y1: float, ancho: float, luz_minima: float) -> Dictionary:
	var mejor := {}
	for h in _vuelan:
		if not h.has("sitio") or h["pisada"] or h["desliza"] or h.has("entrando"):
			continue
		var p: Vector2 = h["p"]
		if p.y < y0 or p.y > y1:
			continue
		var medio: float = h["esc"] * CELDA.y * 0.25
		if absf(wrapf(p.x - x, -ANCHO / 2.0, ANCHO / 2.0)) > ancho + medio:
			continue
		if ligereza.is_valid() and ligereza.call(p) < luz_minima:
			continue
		if mejor.is_empty() or p.y < mejor["p"].y:
			mejor = h
	return mejor

## La hoja pisada: se hunde de golpe girando; hasta que la luz la devuelve a
## su sitio no aguanta (ver _flotar_en_sitio).
func pisar(h: Dictionary, empuje: Vector2) -> void:
	h["pisada"] = true
	h["v"] = empuje
	h["giro"] = randf_range(5.0, 8.0) * (1.0 if randf() < 0.5 else -1.0)

## La luz en p (con luz_viva: lo que quede del haz; sin, la entera).
func luz_en(p: Vector2, con_viva := true) -> float:
	var dx := (p.x - x_luz) / 1050.0
	var dy := (p.y - y_suelo) / 520.0
	var suelo := LUZ_OSCURA + 0.87 * exp(-(dx * dx + 0.6 * dy * dy) * 1.6)
	var eje := (Vector2(x_luz, y_suelo) - haz_origen).normalized()
	var a := eje.angle_to(p - haz_origen)
	var haz := LUZ_OSCURA + 0.8 * (1.0 - smoothstep(haz_apertura * 0.35, haz_apertura, absf(a)))
	var l := maxf(suelo, haz)
	if con_viva:
		l = lerpf(LUZ_OSCURA, l, luz_viva)
	return l * brillo

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
		if h.has("sitio"):
			_flotar_en_sitio(h, delta)
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
		var g := gravedad
		if h["ligera"] and ligereza.is_valid():
			g *= lerpf(1.0, gravedad_luz, ligereza.call(h["p"]))
		v.y += g * delta
		v *= exp(-k * delta)
		# El pendulo: empuje lateral que cambia de lado, mas fuerte cuanto mas
		# despacio va (recien soltada vuela recta).
		var lenta := clampf(1.0 - v.length() / 600.0, 0.0, 1.0)
		v.x += cos(h["meceo"]) * h["meceo_amp"] * lenta * delta * 3.0
		v.x += viento * (0.4 + 0.6 * plana) * (0.3 + 0.7 * lenta) * delta
		v.y -= viento_arriba * (0.4 + 0.6 * plana) * (0.5 + 0.5 * sin(h["meceo"] * 0.7)) * delta
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
	var j := 0
	while j < _hundiendo.size():
		var hh: Dictionary = _hundiendo[j]
		hh["alfa"] -= delta / maxf(hundirse, 0.01)
		if hh["alfa"] <= 0.0:
			_hundiendo.remove_at(j)
			continue
		j += 1
	_vuelo.queue_redraw()
	_pintar_sucias()

## Hoja de la escalera: planea hacia su sitio (mas despacio al llegar, meciendose
## un poco de lado) y alli se queda con un vaiven leve, casi de cara. Pisada,
## un muelle amortiguado la lleva de vuelta (baja un palmo con el empuje y
## vuelve en un par de segundos), girando hasta asentarse; ya en su sitio,
## vuelve a aguantar.
func _flotar_en_sitio(h: Dictionary, delta: float) -> void:
	h["edad"] += delta
	var t: float = h["edad"] + h["fase"]
	var objetivo: Vector2 = h["sitio"] + Vector2(6.0 * sin(t * 0.8), 4.0 * sin(t * 1.3))
	var falta: Vector2 = objetivo - h["p"]
	var vel: Vector2
	if h["pisada"]:
		var w := 2.2
		vel = h["v"] + (falta * w * w - h["v"] * 2.0 * 0.85 * w) * delta
		h["giro"] = h["giro"] * exp(-1.6 * delta)
		h["rot"] += h["giro"] * delta
		if falta.length() < 12.0 and vel.length() < 25.0:
			h["pisada"] = false
	else:
		if falta.length() < 15.0:
			h.erase("entrando")
		vel = falta * 2.2
		if vel.length() > 160.0:
			vel = vel.normalized() * 160.0
			vel.x += 40.0 * sin(t * 2.2)
		h["rot"] = lerp_angle(h["rot"], h["giro_base"] + 0.12 * sin(t * 1.1), 1.0 - exp(-3.0 * delta))
	h["v"] = vel
	h["p"] = h["p"] + vel * delta
	h["vuelta"] = 0.3 * sin(t * 0.6)

## Las migas se pierden entre las hojas; las hojas se apilan, y las de fuera
## del lecho ocupan el sitio de la de arriba o se hunden (ver DE FUERA).
func _posar(h: Dictionary) -> void:
	if h["esc"] < escala_miga:
		return
	# Ya en el lecho es una hoja mas: lo de su caida (ligera en la luz) se queda
	# en el aire. Si no, al pisarlas flotaban despacio en vez de saltar y caer
	# ("el suelo es totalmente distinto", 2026-10-13).
	var de_fuera: bool = h.get("de_fuera", false)
	h["ligera"] = false
	h.erase("de_fuera")
	if not de_fuera:
		_apilar(h)
		return
	var c := _c(h["p"].x)
	h["p"] = Vector2(fposmod(h["p"].x, ANCHO), tope(h["p"].x))
	h["v"] = Vector2.ZERO
	h["desliza"] = false
	if h["esc"] < de_fuera_minima or _cols[c].is_empty():
		h["alfa"] = 1.0
		_hundiendo.append(h)
		return
	var arriba: Dictionary = _cols[c].pop_back()
	_mm_quitar(arriba)
	h["p"].y = arriba["p"].y
	var cv := cos(h["vuelta"])
	h["vuelta"] = acos(signf(cv) * maxf(absf(cv), 0.55))
	h["luz"] = luz_en(h["p"], false)
	_cols[c].append(h)
	_mm_poner(h)
	_ensuciar(c)

# --- Dibujo ------------------------------------------------------------------

## La hoja del atlas: un cuadro de CELDA centrado, con el uv de la celda entera
## (el shader le pone la celda de cada instancia).
func _malla_hoja() -> ArrayMesh:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	var m := CELDA / 2.0
	a[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-m.x, -m.y), Vector2(m.x, -m.y), Vector2(m.x, m.y), Vector2(-m.x, m.y)])
	a[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	a[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return malla

## Pone una hoja posada en el MultiMesh: al final (encima de todo), y otra copia
## al otro lado si esta junto a un borde (el mundo da la vuelta).
func _mm_poner(h: Dictionary) -> void:
	if _mm_libre + 2 > _mm.instance_count:
		_mm_rehacer()
		return
	var t := _forma(h, true)
	h["mi"] = _mm_libre
	_mm.set_instance_transform_2d(_mm_libre, t)
	_mm_libre += 1
	var p: Vector2 = h["p"]
	if p.x < 40.0 or p.x > ANCHO - 40.0:
		h["mi2"] = _mm_libre
		_mm.set_instance_transform_2d(_mm_libre, t.translated(Vector2(ANCHO if p.x < 40.0 else -ANCHO, 0.0)))
		_mm_libre += 1
	_mm.visible_instance_count = _mm_libre
	_mm_pintar(h, 1.0)

## Quita una hoja posada del MultiMesh (su instancia se queda vacia).
func _mm_quitar(h: Dictionary) -> void:
	for k in ["mi", "mi2"]:
		if h.has(k):
			_mm.set_instance_transform_2d(h[k], Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO))
			h.erase(k)

## El color y el dato de la instancia de una hoja posada, con su sombra.
func _mm_pintar(h: Dictionary, sombra: float) -> void:
	if not h.has("mi"):
		return
	var luz: float = h["luz"]
	var col := _color(h, luz, true, sombra)
	var dato := Color(float(h["celda"]), minf(LUZ_OSCURA * brillo / maxf(luz, 0.001), 1.0), 0.0, 0.0)
	_mm.set_instance_color(h["mi"], col)
	_mm.set_instance_custom_data(h["mi"], dato)
	if h.has("mi2"):
		_mm.set_instance_color(h["mi2"], col)
		_mm.set_instance_custom_data(h["mi2"], dato)

## Las de abajo, en la sombra de las de encima: la sombra va por la altura en
## su columna, asi que al cambiar una columna se repintan sus colores.
func _pintar_sucias() -> void:
	for c in _sucias:
		var col: Array = _cols[c]
		var n := col.size()
		for nivel in n:
			_mm_pintar(col[nivel], 0.55 + 0.45 * float(nivel + 1) / n)
	_sucias.clear()

## Rehace el MultiMesh entero por niveles (primero la de abajo de cada columna):
## cuando se acaban las instancias libres, y con sitio de sobra.
func _mm_rehacer() -> void:
	var total := 0
	var niveles := 0
	for c in N_COL:
		total += _cols[c].size()
		niveles = maxi(niveles, _cols[c].size())
	var cap := maxi(_mm.instance_count, nearest_po2(total * 2 + 256))
	if cap != _mm.instance_count:
		_mm.instance_count = cap
	_mm_libre = 0
	_mm.visible_instance_count = 0
	for nivel in niveles:
		for c in N_COL:
			var col: Array = _cols[c]
			if nivel < col.size():
				var h: Dictionary = col[nivel]
				h.erase("mi")
				h.erase("mi2")
				_mm_poner(h)
	for c in N_COL:
		_sucias[c] = true
	_pintar_sucias()

func _dibujar_vuelo() -> void:
	for h in _vuelan:
		_dibujar_hoja(_vuelo, h, h["desliza"], 1.0)
	for h in _hundiendo:
		_dibujar_hoja(_vuelo, h, true, 1.0)
	_vuelo.draw_set_transform_matrix(Transform2D.IDENTITY)

func _dibujar_hoja(capa: Node2D, h: Dictionary, tumbada: bool, sombra: float) -> void:
	var p: Vector2 = h["p"]
	var celda: int = h["celda"]
	var region := Rect2(Vector2(celda % COLS_ATLAS, celda / COLS_ATLAS) * CELDA, CELDA)
	var col := _color(h, luz_en(p), tumbada, sombra)
	var t := _forma(h, tumbada)
	capa.draw_set_transform_matrix(t)
	capa.draw_texture_rect_region(ATLAS, Rect2(-CELDA / 2.0, CELDA), region, col)
	# Junto a un borde se dibuja tambien al otro lado (el mundo da la vuelta).
	if p.x < 40.0 or p.x > ANCHO - 40.0:
		capa.draw_set_transform_matrix(t.translated(Vector2(ANCHO if p.x < 40.0 else -ANCHO, 0.0)))
		capa.draw_texture_rect_region(ATLAS, Rect2(-CELDA / 2.0, CELDA), region, col)

## Donde y como se ve una hoja: girada, de cara o de canto segun su vuelta y,
## tumbada en el lecho, aplastada en pantalla.
func _forma(h: Dictionary, tumbada: bool) -> Transform2D:
	var p: Vector2 = h["p"]
	var esc: float = h["esc"]
	var c := cos(h["vuelta"])
	if tumbada:
		var ex := esc * signf(c) * maxf(absf(c), 0.55)
		# Aplastada en pantalla: se escala el eje y del mundo despues de girar.
		var t := Transform2D(h["rot"], Vector2(ex, esc), 0.0, Vector2.ZERO)
		return Transform2D(Vector2(1, 0), Vector2(0, h["aplastar"]), p) * t
	var ex2 := esc * c
	# Casi de canto se ve una raya; con 0 desaparece y parpadea.
	if absf(ex2) < esc * 0.08:
		ex2 = esc * 0.08 * (1.0 if c >= 0.0 else -1.0)
	return Transform2D(h["rot"], Vector2(ex2, esc), 0.0, p)

## Su color con la luz dada: tumbada algo mas apagada; el enves, mas apagado y
## menos saturado.
func _color(h: Dictionary, luz: float, tumbada: bool, sombra: float) -> Color:
	var c := cos(h["vuelta"])
	var l: float = luz * h["tono"] * sombra
	if tumbada:
		l *= 0.92
	if c < 0.0:
		l *= 0.78
	return Color(l, l * (0.97 if c >= 0.0 else 0.93), l * (0.95 if c >= 0.0 else 0.85), h.get("alfa", 1.0))
