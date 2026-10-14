extends Node2D
## Hojas de otono que caen de la copa y se posan en el camino.
##
## Son las hojas de la hojarasca (mismo atlas, assets/world/hojarasca/hojas.png)
## a distintas distancias: las lejanas salen de la copa que se ve al fondo,
## pequenas y lentas en pantalla; las cercanas entran por arriba, grandes y
## rapidas. Cada una cae hasta el suelo que le toca por su distancia (el plano
## del camino, con fuga al fondo), se queda tumbada un rato y se funde.
##
## Vuelan como las del titulo: el viento de la escena (brisa y la racha cuando
## les llega, via controlador.viento_en) con remolinos, un vaiven de pendulo,
## volteretas segun el aire en contra y un arrastre propio por hoja (si no,
## viajan en fila). Con la racha se sueltan muchas mas.
##
## Luz: en el aire, a contraluz, una hoja deja pasar parte de la luz de detras
## y la tine de oxido (lo de detras, medio.png, por una transmision y un tono):
## siempre mas oscura que lo que tapa; en la sombra, casi negra. Tumbada en el
## suelo coge el color del suelo, algo mas calida. Las lejanas, mas fundidas.
##
## Primer plano: de vez en cuando una pasa pegada a la camara, grande, rapida y
## fuera de foco (atlas desenfocado). Da profundidad, como en cine.
## Camara: cada hoja se desplaza con la camara segun lo cerca que esta.
##
## Suelo: cuando la racha pasa por el camino levanta hojas de las que hay
## tiradas: salen del suelo, dan uno o varios saltitos a favor del viento y se
## vuelven a posar; alguna sale volando.

const ATLAS := preload("res://assets/world/hojarasca/hojas.png")
const ATLAS_DESENFOCADO := preload("res://assets/world/camino_bosque/hojas_desenfocadas.png")
const COLS_ATLAS := 8
const FILAS_ATLAS := 4
const CELDA := Vector2(64, 128)
const PANTALLA := Vector2(2912, 1632)
## Color medio de las hojas del atlas: se divide por el para teñirlas.
const BASE := Color(0.657, 0.417, 0.139)

## RGB color medio de la zona, A luz.
@export var medio: Texture2D
## G: donde hay copa (de ahi caen las lejanas).
@export var ramas: Texture2D
## Fondo del camino: horizonte del plano del suelo.
@export var fuga := Vector2(1430.0, 1000.0)
## Segundos entre hoja y hoja con la brisa sola y con la racha a tope.
@export var cada := 1.2
@export var cada_racha := 0.15
@export var maximo := 90
## Hojas por segundo que levanta del camino la racha a tope, y desde que racha.
@export var levantar := 8.0
@export var levantar_desde := 0.25
## Tamano sobre el atlas (celda de 128 px de alto), de la mas lejana a la mas cercana.
@export var escala := Vector2(0.06, 0.5)
## Las de primer plano: que parte de las cercanas lo son y su tamano.
@export var primer_plano := 0.14
@export var escala_primer_plano := Vector2(0.9, 1.4)
## En px/s de una hoja cercana; las lejanas, a escala.
@export var gravedad := 110.0
@export var caida_max := 150.0
@export var viento_brisa := 45.0
@export var viento_racha := 280.0
@export var turbulencia := 70.0
## Segundos que se ve tumbada en el suelo antes de fundirse.
@export var posada := Vector2(4.0, 9.0)
## Cuanta luz deja pasar una hoja en el aire y con que tono.
@export var transmision := 0.5
@export var tinte := Color(1.15, 0.7, 0.36)

## La escena: viento_en(x) y brisa.
var controlador: Node

var _medio: Image
var _ramas: Image
var _hojas: Array[Dictionary] = []
var _hasta := 1.0
var _por_levantar := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _ruido := FastNoiseLite.new()

func _ready() -> void:
	_rng.randomize()
	_ruido.seed = _rng.randi()
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido.frequency = 1.0
	_medio = medio.get_image()
	_ramas = ramas.get_image()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Al empezar ya hay alguna en el aire.
	for i in 6:
		_soltar(true)

func _muestra(img: Image, p: Vector2) -> Color:
	var x := clampi(int(p.x / PANTALLA.x * img.get_width()), 0, img.get_width() - 1)
	var y := clampi(int(p.y / PANTALLA.y * img.get_height()), 0, img.get_height() - 1)
	return img.get_pixel(x, y)

## Donde toca el suelo una hoja a esa distancia (0 lejos, 1 cerca).
func _suelo(z: float) -> float:
	return fuga.y + (PANTALLA.y + 120.0 - fuga.y) * pow(z, 1.1)

## Tamano en pantalla segun la distancia (las de primer plano, aparte).
func _escala(z: float) -> float:
	if z > 1.0:
		return lerpf(escala_primer_plano.x, escala_primer_plano.y, inverse_lerp(1.15, 1.5, z))
	return lerpf(escala.x, escala.y, pow(z, 1.3))

## Una hoja que se suelta de la copa (hojas_copa.gd): sigue cayendo desde donde
## se ve, con su tamano y su dibujo, sin fundido (ya estaba a la vista).
func soltar_desde(p: Vector2, z: float, esc: float, celda: int, vel: Vector2) -> void:
	if _hojas.size() >= maximo:
		return
	var k := lerpf(0.16, 1.0, pow(z, 1.3))
	var desde: Vector2 = p - controlador.paralaje(p, z) if controlador else p
	_soltar_en(desde, z, {
		"escala": esc,
		"celda": celda,
		"vel": vel * k,
		"aparece": 0.01,
	})

## Una hoja de las del camino que levanta la racha (cerca, donde se ve).
func _levantar(racha: float) -> void:
	if _hojas.size() >= maximo:
		return
	var y := lerpf(1120.0, 1600.0, sqrt(_rng.randf()))
	var z := pow((y - fuga.y) / (PANTALLA.y + 120.0 - fuga.y), 1.0 / 1.1)
	var ancho := lerpf(120.0, 600.0, (y - fuga.y) / (PANTALLA.y - fuga.y))
	var x := clampf(fuga.x + _rng.randf_range(-1.4, 1.4) * ancho, 40.0, PANTALLA.x - 40.0)
	var k := lerpf(0.16, 1.0, pow(z, 1.3))
	var vuela := _rng.randf() < 0.2
	_soltar_en(Vector2(x, y), z, {
		"vel": Vector2((40.0 + viento_racha * racha * 0.5) * k,
			-(_rng.randf_range(200.0, 320.0) if vuela else _rng.randf_range(40.0, 140.0)) * k),
		"suelo": y + (_rng.randf_range(80.0, 300.0) * k if vuela else _rng.randf_range(2.0, 12.0)),
		"saltos": 0 if vuela else _rng.randi_range(1, 3),
		"aparece": 0.25,
	})

func _soltar(en_el_aire := false) -> void:
	if _hojas.size() >= maximo:
		return
	var z: float
	var pos: Vector2
	if _rng.randf() < 0.45:
		# Lejana, de la copa que se ve al fondo.
		z = _rng.randf_range(0.05, 0.45)
		pos = Vector2(_rng.randf_range(950.0, 1950.0), _rng.randf_range(40.0, 750.0))
		for _intento in 20:
			var p := Vector2(_rng.randf_range(950.0, 1950.0), _rng.randf_range(40.0, 750.0))
			if _muestra(_ramas, p).g > 0.3:
				pos = p
				break
		pos.y = minf(pos.y, _suelo(z) - 250.0)
	else:
		# Cercana: entra por arriba (mas por la izquierda, que el viento va a la
		# derecha). Algunas, pegadas a la camara: primer plano (z > 1).
		z = _rng.randf_range(0.45, 1.0)
		if not en_el_aire and _rng.randf() < primer_plano:
			z = _rng.randf_range(1.15, 1.5)
		pos = Vector2(_rng.randf_range(-300.0, PANTALLA.x - 200.0), -CELDA.y * _escala(z) - 20.0)
	if en_el_aire:
		pos.y = lerpf(pos.y, _suelo(z), _rng.randf_range(0.0, 0.6))
	_soltar_en(pos, z, {})

## Crea la hoja; "extra" pisa lo que haga falta (velocidad, suelo, saltos...).
func _soltar_en(pos: Vector2, z: float, extra: Dictionary) -> void:
	var h := {
		"pos": pos,
		"vel": Vector2.ZERO,
		"z": z,
		"k": lerpf(0.16, 1.0, pow(z, 1.3)),   # cuanto de grande y rapida en pantalla
		"escala": _escala(z) * _rng.randf_range(0.8, 1.2),
		"suelo": _suelo(z) + _rng.randf_range(-15.0, 15.0) * z,
		"edad": 0.0,
		"posada": -1.0,
		"dura": _rng.randf_range(posada.x, posada.y),
		"celda": _rng.randi() % (COLS_ATLAS * FILAS_ATLAS),
		"ang_base": _rng.randf_range(-PI, PI),
		"ang": 0.0,
		"giro": _rng.randf_range(0.3, 0.9) * (1.0 if _rng.randf() < 0.5 else -1.0),
		"arrastre": _rng.randf_range(0.6, 1.4),
		"vaiven": _rng.randf() * TAU,
		"vel_vaiven": _rng.randf_range(2.0, 3.2),
		"vuelta": _rng.randf() * TAU,
		"vel_vuelta": _rng.randf_range(2.5, 5.5) * (1.0 if _rng.randf() < 0.5 else -1.0),
		"tumbada": _rng.randf_range(-0.5, 0.5) + (PI * 0.5 if _rng.randf() < 0.5 else -PI * 0.5),
		"tono": _rng.randf_range(0.85, 1.0),
		"saltos": 0,
		"aparece": 0.6,
	}
	h.merge(extra, true)
	_hojas.append(h)

func _process(delta: float) -> void:
	_t += delta
	var brisa: float = controlador.brisa if controlador else 0.4
	# Con la racha la copa suelta mas: el ritmo va de "cada" a "cada_racha".
	var racha_media: float = controlador.viento_en(PANTALLA.x * 0.5) if controlador else 0.0
	_hasta -= delta / lerpf(cada, cada_racha, racha_media)
	if _hasta <= 0.0:
		_soltar()
		_hasta = _rng.randf_range(0.4, 1.6)
	var racha_camino: float = controlador.viento_en(fuga.x) if controlador else 0.0
	if racha_camino > levantar_desde:
		_por_levantar += delta * levantar * (racha_camino - levantar_desde) / (1.0 - levantar_desde)
		while _por_levantar >= 1.0:
			_por_levantar -= 1.0
			_levantar(racha_camino)

	var vivas: Array[Dictionary] = []
	for h in _hojas:
		h.edad += delta
		if h.posada >= 0.0:
			h.posada += delta
			if h.posada < h.dura:
				vivas.append(h)
			continue
		var k: float = h.k
		var p: Vector2 = h.pos
		var racha: float = controlador.viento_en(p.x) if controlador else 0.0
		var a := _ruido.get_noise_3d(p.x * 0.002, p.y * 0.002, _t * 0.15) * TAU
		var viento := (Vector2(viento_brisa * brisa + viento_racha * racha, 0.0)
			+ Vector2(cos(a), sin(a) * 0.6) * turbulencia) * k
		var relativo: float = (viento - h.vel).length() / k
		h.vaiven += h.vel_vaiven * delta
		h.vuelta += h.vel_vuelta * delta * (0.5 + relativo / 400.0)
		var lado := sin(h.vaiven)
		# De plano frena mas el aire (y cae menos); de canto corta el aire.
		var plano := absf(cos(h.vuelta))
		var kk: float = lerpf(1.0, 2.6, plano) * h.arrastre
		h.vel += (viento - h.vel) * (1.0 - exp(-kk * delta))
		h.vel.y = minf(h.vel.y + gravedad * k * delta * (1.0 - 0.45 * plano), caida_max * k)
		# Pendulo: se desliza de lado y sube un poco al final de cada vaiven.
		h.pos += (h.vel + Vector2(lado * 55.0, -absf(lado) * 16.0) * k) * delta
		h.ang = h.ang_base + lado * 0.7 + h.vel.x * 0.0005 / k
		h.ang_base += (h.giro + signf(h.giro) * relativo / 260.0 * 2.2) * delta
		if h.pos.y >= h.suelo:
			h.pos.y = h.suelo
			if h.saltos > 0 and racha > 0.15:
				# Otro saltito a favor del viento.
				h.saltos -= 1
				h.vel = Vector2(h.vel.x * 0.7, -_rng.randf_range(30.0, 90.0) * k)
			else:
				h.posada = 0.0
		if h.pos.x < PANTALLA.x + 250.0 and h.pos.x > -350.0 and h.pos.y < PANTALLA.y + 200.0:
			vivas.append(h)
	_hojas = vivas
	queue_redraw()

func _draw() -> void:
	for h in _hojas:
		var z: float = h.z
		# La camara mueve mas lo cercano (las de primer plano, mas que nada).
		var p: Vector2 = h.pos
		if controlador:
			p += controlador.paralaje(p, z)
		var m := _muestra(_medio, p)
		var atlas: Texture2D = ATLAS_DESENFOCADO if z > 1.0 else ATLAS
		var celda: int = h.celda
		var region := Rect2(Vector2(celda % COLS_ATLAS, celda / COLS_ATLAS) * CELDA, CELDA)
		var esc: float = h.escala
		var a := clampf(h.edad / h.aparece, 0.0, 1.0)
		var xf: Transform2D
		var de_cara := 1.0
		if h.posada >= 0.0:
			# Tumbada en el suelo: de lado y aplastada por la perspectiva.
			xf = Transform2D(Vector2(1, 0), Vector2(0, 0.32), p) * Transform2D(h.tumbada, Vector2(esc, esc), 0.0, Vector2.ZERO)
			a *= 1.0 - smoothstep(h.dura * 0.5, h.dura, h.posada)
		else:
			de_cara = cos(h.vuelta)
			# Nunca del todo de canto: de canto es una raya que parpadea.
			var ancho: float = (1.0 if de_cara >= 0.0 else -1.0) * (0.45 + 0.55 * absf(de_cara))
			xf = Transform2D(h.ang, Vector2(esc * ancho, esc), 0.0, p)
		# A contraluz deja pasar la luz; por el enves algo mas oscura. Lejos se
		# funde con la niebla de su zona.
		var tono: float = h.tono
		var fondo := Color(m.r, m.g, m.b)
		var c: Color
		if h.posada >= 0.0:
			c = Color(m.r * 1.05, m.g * 0.9, m.b * 0.7) * tono
		else:
			var claro: float = controlador.claro if controlador else 0.0
			var t := transmision * (1.0 + 0.35 * claro) * tono * (1.0 if de_cara >= 0.0 else 0.8)
			c = Color(m.r * tinte.r, m.g * tinte.g, m.b * tinte.b) * t
		# Las lejanas se funden un poco mas con lo de alrededor.
		c = c.lerp(fondo, maxf(1.0 - z, 0.0) * 0.35)
		# Fuera de foco y tan cerca: algo transparente (el desenfoque ya la abre).
		if z > 1.0:
			a *= 0.85
		var mod := Color(minf(c.r / BASE.r, 3.0), minf(c.g / BASE.g, 3.0), minf(c.b / BASE.b, 3.0), a)
		# Rastro: cuando va deprisa, dos copias tenues por detras.
		var vel: Vector2 = h.vel
		var rapidez := clampf((vel.length() / h.k - 220.0) / 380.0, 0.0, 1.0) if h.posada < 0.0 else 0.0
		if rapidez > 0.0:
			for j in 2:
				var atras := vel * (0.012 * (j + 1))
				draw_set_transform_matrix(Transform2D(xf.x, xf.y, xf.origin - atras))
				draw_texture_rect_region(atlas, Rect2(-CELDA / 2.0, CELDA), region,
					Color(mod.r, mod.g, mod.b, a * rapidez * (0.28 if j == 0 else 0.13)))
		draw_set_transform_matrix(xf)
		draw_texture_rect_region(atlas, Rect2(-CELDA / 2.0, CELDA), region, mod)
	draw_set_transform_matrix(Transform2D.IDENTITY)
