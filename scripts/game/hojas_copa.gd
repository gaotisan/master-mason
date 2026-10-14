extends Node2D
## Las hojas que aun quedan en los arboles.
##
## Cuelgan de las ramitas finas de la copa (hojas_copa.json: puntos sobre las
## ramitas, de mascaras.py) y van pegadas a su ramita: el controlador dice donde
## se ve cada punto de la imagen con la copa movida y la camara (donde_se_ve).
## Cada hoja es un pendulo con muelle sobre su pecíolo: el viento la empuja a
## favor (la brisa un poco, la racha mucho), la turbulencia la hace temblar y,
## con viento, gira sobre el pecíolo y ensena el enves. Con la racha alguna se
## suelta y pasa a ser de las que caen (hojas_otono.soltar_desde); en su sitio
## brota otra despacio, mas adelante.
##
## Luz: la copa esta a contraluz. Una hoja a contraluz deja pasar parte de la
## luz de detras y la tine de oxido: es lo de detras (medio.png) por una
## transmision y un tono rojizo, siempre mas oscura que el cielo que tapa (si
## no, sobre el dorado del fondo ni se veia). Cuando el sol se abre paso
## (claro), deja pasar mas. En la sombra sale casi negra.

const ATLAS := preload("res://assets/world/hojarasca/hojas.png")
const COLS_ATLAS := 8
const FILAS_ATLAS := 4
const CELDA := Vector2(64, 128)
const PANTALLA := Vector2(2912, 1632)
## Color medio de las hojas del atlas: se divide por el para tenirlas.
const BASE := Color(0.657, 0.417, 0.139)
const PUNTOS := "res://assets/world/camino_bosque/hojas_copa.json"

## RGB color medio de la zona, A luz.
@export var medio: Texture2D
## B profundidad (0 cerca, 1 lejos): las de ramas mas cercanas, algo mayores.
@export var profundidad: Texture2D
@export var cantidad := 160
## Tamano sobre la celda de 128 px: de la rama mas cercana a la mas lejana.
@export var escala := Vector2(0.24, 0.12)
## Probabilidad por segundo de soltarse, con la racha a tope (va con su cuadrado).
@export var soltar_racha := 0.05
## Lo que tarda en brotar otra donde se solto una (s).
@export var rebrote := Vector2(15.0, 35.0)
## Cuanta luz deja pasar y con que tono.
@export var transmision := 0.45
@export var tinte := Color(1.15, 0.7, 0.36)

## La escena: viento_en(x), brisa, claro, donde_se_ve(p).
var controlador: Node

var _puntos: Array = []
var _medio: Image
var _prof: Image
var _hojas: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _ruido := FastNoiseLite.new()
var _t := 0.0

func _ready() -> void:
	_rng.randomize()
	_ruido.seed = _rng.randi()
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido.frequency = 1.0
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_medio = medio.get_image()
	_prof = profundidad.get_image()
	var f := FileAccess.open(PUNTOS, FileAccess.READ)
	if f:
		_puntos = JSON.parse_string(f.get_as_text())
	for i in mini(cantidad, _puntos.size()):
		_hojas.append(_nueva(0.0))
		_hojas[-1].edad = 100.0   # al empezar ya estan

func _muestra(img: Image, p: Vector2) -> Color:
	var x := clampi(int(p.x / PANTALLA.x * img.get_width()), 0, img.get_width() - 1)
	var y := clampi(int(p.y / PANTALLA.y * img.get_height()), 0, img.get_height() - 1)
	return img.get_pixel(x, y)

func _nueva(espera: float) -> Dictionary:
	var pt: Array = _puntos[_rng.randi() % _puntos.size()]
	var ancla := Vector2(pt[0], pt[1])
	var prof := _muestra(_prof, ancla).b
	# Cuelgan hacia abajo, cada una con su caida.
	var reposo := _rng.randf_range(-0.7, 0.7)
	return {
		"ancla": ancla,
		"prof": prof,
		"escala": lerpf(escala.x, escala.y, prof) * _rng.randf_range(0.8, 1.25),
		"celda": _rng.randi() % (COLS_ATLAS * FILAS_ATLAS),
		"reposo": reposo,
		"ang": reposo,
		"ang_v": 0.0,
		"frec": _rng.randf_range(1.6, 2.8),
		"giro": _rng.randf() * TAU,
		"vel_giro": _rng.randf_range(0.6, 1.4) * (1.0 if _rng.randf() < 0.5 else -1.0),
		"semilla": _rng.randf() * 1000.0,
		"tono": _rng.randf_range(0.8, 1.0),
		"edad": -espera,
	}

func _process(delta: float) -> void:
	_t += delta
	if not controlador:
		return
	var brisa: float = controlador.brisa
	var sueltas := get_node_or_null("../Hojas")
	for i in _hojas.size():
		var h := _hojas[i]
		h.edad += delta
		var x: float = h.ancla.x
		var racha: float = controlador.viento_en(x)
		var s: float = h.semilla
		# Empuje a favor del viento (a la derecha) y temblor.
		var temblor := _ruido.get_noise_2d(_t * 2.2, s) * (0.2 + 0.9 * racha + 0.3 * brisa)
		var objetivo: float = h.reposo - (0.25 * brisa + 1.0 * racha) + temblor
		# Muelle del pecíolo, en pasos cortos (la hoja es ligera y rapida).
		var w := TAU * float(h.frec)
		var n := maxi(1, ceili(delta * 120.0))
		for _k in n:
			h.ang_v += ((objetivo - h.ang) * w * w - h.ang_v * 2.0 * 0.25 * w) * delta / n
			h.ang += h.ang_v * delta / n
		# Con viento gira sobre el pecíolo.
		h.giro += h.vel_giro * delta * (0.4 + 5.0 * racha + 1.0 * brisa)
		# Con la racha, alguna se suelta.
		if h.edad > 2.0 and racha > 0.3 and _rng.randf() < soltar_racha * racha * racha * delta:
			if sueltas and sueltas.has_method("soltar_desde"):
				var p: Vector2 = controlador.donde_se_ve(h.ancla)
				var z := clampf((1.0 - float(h.prof)) * 0.6, 0.05, 0.6)
				sueltas.soltar_desde(p, z, h.escala, h.celda, Vector2(60.0 * racha, -10.0))
			_hojas[i] = _nueva(_rng.randf_range(rebrote.x, rebrote.y))
	queue_redraw()

func _draw() -> void:
	if not controlador:
		return
	var claro: float = controlador.claro
	for h in _hojas:
		if h.edad <= 0.0:
			continue
		var p: Vector2 = controlador.donde_se_ve(h.ancla)
		var m := _muestra(_medio, p)
		var de_cara := cos(float(h.giro))
		var ancho := (1.0 if de_cara >= 0.0 else -1.0) * (0.35 + 0.65 * absf(de_cara))
		var tono: float = h.tono
		# Lo de detras, tamizado por la hoja (por el enves, algo menos).
		var t := transmision * (1.0 + 0.35 * claro) * tono * (1.0 if de_cara >= 0.0 else 0.8)
		var c := Color(m.r * tinte.r, m.g * tinte.g, m.b * tinte.b) * t
		# Brota despacio.
		var a := clampf(float(h.edad) / 3.0, 0.0, 1.0)
		var mod := Color(minf(c.r / BASE.r, 3.0), minf(c.g / BASE.g, 3.0), minf(c.b / BASE.b, 3.0), a)
		var celda: int = h.celda
		var region := Rect2(Vector2(celda % COLS_ATLAS, celda / COLS_ATLAS) * CELDA, CELDA)
		var esc: float = h.escala
		# El pecíolo (abajo en el atlas) en la rama y la hoja colgando.
		draw_set_transform(p, PI + float(h.ang), Vector2(esc * ancho, esc))
		draw_texture_rect_region(ATLAS, Rect2(Vector2(-CELDA.x / 2.0, -CELDA.y), CELDA), region, mod)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
