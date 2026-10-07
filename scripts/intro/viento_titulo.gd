extends Node2D
## Viento de la pantalla de titulo: mueve los arbustos del fondo y suelta hojas.
## Lo alimenta el controlador cada fotograma con la racha que suena y la brisa
## de fondo (racha, brisa).
##
## ARBUSTOS. Cada uno es una rama elastica anclada en su raiz (la esquina o el
## borde de donde sale): un muelle amortiguado lleva el desplazamiento de su
## punta. La racha lo empuja a favor del viento; al pasar, rebota y vuelve, cada
## arbusto a su ritmo. La racha cruza la pantalla de izquierda a derecha, asi que
## llega antes a los de la izquierda. El shader (title_hojas_viento.gdshader)
## reparte ese desplazamiento por la imagen: nada en la raiz, todo en la punta,
## y con un pelin de retraso en la punta.
##
## HOJAS SUELTAS. Cuando la racha le llega a un arbusto, suelta unas pocas de
## donde de verdad hay hoja (la mascara del fondo). Vuelan en un viento con
## remolinos: la racha (que tambien les llega con retraso segun donde esten),
## la brisa y una turbulencia suave que les curva la trayectoria. Cada hoja se
## balancea como un pendulo, gira sobre si misma (por el enves algo mas oscura)
## y, cuando va deprisa, deja un rastro muy tenue.
## Son las hojas de la hojarasca (la escena siguiente), en un atlas propio a la
## escala y con el tono de las del fondo (raw/master_mason/titulo_hojas/
## hojas_sueltas.py). Van por debajo de la mascara de luz: se encienden y se
## apagan con la sala.

const ATLAS := preload("res://assets/intro/title_hojas_sueltas.png")
const MASCARA := preload("res://assets/intro/title_hojas_mascara.png")
const COLS_ATLAS := 8
const FILAS_ATLAS := 4
const CELDA := Vector2(32, 64)
const IMAGEN := Vector2(2912, 1632)

## Arbustos del fondo (px de la imagen): raiz, centro y radio de su zona, largo
## de rama, frecuencia propia del muelle (Hz) y cuantas hojas suelta por racha
## (min, max). Los de la izquierda sueltan mas: sus hojas cruzan por las paredes
## de arriba y de abajo; las de los lados cruzarian el cristal y no sueltan.
const ARBUSTOS := [
	[Vector2(0, 0),       Vector2(480, 170),   520.0, 1050.0, 0.55, Vector2i(2, 3)],  # arriba izda
	[Vector2(2912, 0),    Vector2(1950, 210),  620.0, 1500.0, 0.45, Vector2i(1, 2)],  # arriba dcha
	[Vector2(0, 850),     Vector2(270, 840),   330.0, 560.0,  0.80, Vector2i(0, 0)],  # izda
	[Vector2(2912, 850),  Vector2(2640, 840),  330.0, 560.0,  0.80, Vector2i(0, 0)],  # dcha
	[Vector2(0, 1632),    Vector2(480, 1450),  560.0, 1050.0, 0.60, Vector2i(2, 3)],  # abajo izda
	[Vector2(2912, 1632), Vector2(2420, 1440), 620.0, 1150.0, 0.50, Vector2i(0, 1)],  # abajo dcha
]

## Racha 0..1 y brisa 0..1: las pone el controlador cada fotograma.
var racha := 0.0
var brisa := 0.0
## El material del fondo (el del shader de los arbustos).
var material_fondo: ShaderMaterial

@export_group("Arbustos")
## Cuanto se inclina la punta de un arbusto con la racha a tope (px; x a favor
## del viento, y negativo = hacia arriba).
@export var inclinacion_racha := Vector2(15.0, -3.0)
## Vaiven con la brisa sola (px en la punta).
@export var vaiven_brisa := 4.0
## Amortiguamiento de los muelles: bajo = rebota mas al pasar la racha.
@export var amortiguamiento := 0.22
## Velocidad a la que cruza la racha la pantalla (px/s).
@export var racha_px_s := 1700.0

@export_group("Hojas sueltas")
## Hoja suelta con la brisa: segundos de media entre una y otra (0 = ninguna).
@export var suelta_cada := 6.0
## Tamano respecto al atlas (alli ~59 px; las del fondo miden 40-60 px).
@export var escala := Vector2(0.8, 1.1)
## Viento para las hojas (px/s): el de la racha a tope y el de fondo.
@export var viento_racha := Vector2(560.0, -70.0)
@export var viento_brisa := 150.0
## Remolinos: cuanto y a que escala (px) curvan la trayectoria.
@export var turbulencia := 260.0
@export var turbulencia_escala := 520.0
@export var gravedad := 80.0
@export var caida_max := 120.0

var _t := 0.0
var _historia: Array[Vector2] = []   # (tiempo, racha) para el retraso
var _empuje: Array[Vector2] = []
var _empuje_vel: Array[Vector2] = []
var _agitacion := PackedFloat32Array()
var _soltadas: Array[bool] = []
var _fase: Array[float] = []
var _hojas: Array[Dictionary] = []
var _hasta_suelta := 0.0
var _mascara: Image
var _ruido := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_rng.randomize()
	_ruido.seed = _rng.randi()
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido.frequency = 1.0
	_mascara = MASCARA.get_image()
	for a in ARBUSTOS:
		_empuje.append(Vector2.ZERO)
		_empuje_vel.append(Vector2.ZERO)
		_agitacion.append(0.0)
		_soltadas.append(false)
		_fase.append(_rng.randf() * TAU)
	_hasta_suelta = _siguiente_suelta()
	if material_fondo:
		var raiz := PackedVector2Array()
		var centro := PackedVector2Array()
		var radio := PackedFloat32Array()
		var largo := PackedFloat32Array()
		for a in ARBUSTOS:
			raiz.append(a[0])
			centro.append(a[1])
			radio.append(a[2])
			largo.append(a[3])
		material_fondo.set_shader_parameter("raiz", raiz)
		material_fondo.set_shader_parameter("centro", centro)
		material_fondo.set_shader_parameter("radio", radio)
		material_fondo.set_shader_parameter("largo", largo)

func _process(delta: float) -> void:
	_t += delta
	_historia.append(Vector2(_t, racha))
	while _historia.size() > 2 and _historia[1].x < _t - 3.0:
		_historia.pop_front()
	_mover_arbustos(delta)
	_mover_hojas(delta)
	queue_redraw()

## La racha tal como estaba hace `retraso` segundos.
func _racha_hace(retraso: float) -> float:
	var t := _t - retraso
	for i in range(_historia.size() - 1, -1, -1):
		if _historia[i].x <= t:
			if i + 1 < _historia.size():
				var a := _historia[i]
				var b := _historia[i + 1]
				return lerpf(a.y, b.y, clampf((t - a.x) / maxf(b.x - a.x, 1e-5), 0.0, 1.0))
			return _historia[i].y
	return 0.0

## La racha en un punto: llega antes por la izquierda.
func _racha_en(x: float) -> float:
	return _racha_hace(clampf(x, 0.0, IMAGEN.x) / racha_px_s)

func _mover_arbustos(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	for i in ARBUSTOS.size():
		var a: Array = ARBUSTOS[i]
		var g := _racha_en((a[1] as Vector2).x)
		_agitacion[i] = g
		# Adonde le lleva el viento: la brisa lo mece despacio (dos senos que no
		# van a compas) y la racha lo tumba a favor del viento, con algo de
		# temblor mientras sopla.
		var f: float = _fase[i]
		var mece := Vector2(sin(_t * 0.37 + f) * 0.6 + sin(_t * 0.83 + f * 1.7) * 0.4,
			(sin(_t * 0.51 + f * 2.3) * 0.5) * 0.4)
		var objetivo := mece * vaiven_brisa * brisa + Vector2(vaiven_brisa * 0.4 * brisa, 0.0)
		objetivo += inclinacion_racha * g * (1.0 + 0.25 * sin(_t * 3.1 + f))
		# Muelle amortiguado hacia ese objetivo.
		var w := TAU * float(a[4])
		var acc := (objetivo - _empuje[i]) * w * w - _empuje_vel[i] * 2.0 * amortiguamiento * w
		_empuje_vel[i] += acc * dt
		_empuje[i] += _empuje_vel[i] * dt
		# Suelta hojas cuando le llega la racha.
		if g > 0.3 and not _soltadas[i]:
			_soltadas[i] = true
			var n: Vector2i = a[5]
			for k in _rng.randi_range(n.x, n.y):
				_soltar(i, _rng.randf_range(0.0, 0.9))
		elif g < 0.05:
			_soltadas[i] = false
	if material_fondo:
		material_fondo.set_shader_parameter("empuje", PackedVector2Array(_empuje))
		material_fondo.set_shader_parameter("empuje_vel", PackedVector2Array(_empuje_vel))
		material_fondo.set_shader_parameter("agitacion", _agitacion)
		material_fondo.set_shader_parameter("brisa", brisa)

## Viento que nota una hoja en p: brisa, la racha cuando le llega a ese x y una
## turbulencia suave (rotacional, para que curve sin acumular) que cambia con el
## tiempo.
func _viento_en(p: Vector2) -> Vector2:
	var g := _racha_en(p.x)
	var v := Vector2(viento_brisa * brisa, 0.0) + viento_racha * g
	var q := p / turbulencia_escala
	var e := 0.05
	var z := _t * 0.35
	var dx := _ruido.get_noise_3d(q.x + e, q.y, z) - _ruido.get_noise_3d(q.x - e, q.y, z)
	var dy := _ruido.get_noise_3d(q.x, q.y + e, z) - _ruido.get_noise_3d(q.x, q.y - e, z)
	v += Vector2(dy, -dx) / (2.0 * e) * turbulencia * (0.35 + 0.65 * g)
	return v

func _mover_hojas(delta: float) -> void:
	if suelta_cada > 0.0 and brisa > 0.4:
		_hasta_suelta -= delta
		if _hasta_suelta <= 0.0:
			_soltar([0, 4][_rng.randi() % 2], 0.0)
			_hasta_suelta = _siguiente_suelta()

	var vivas: Array[Dictionary] = []
	for h in _hojas:
		if h.espera > 0.0:
			h.espera -= delta
			vivas.append(h)
			continue
		h.edad += delta
		var viento := _viento_en(h.pos)
		var relativo: float = (viento - h.vel).length()
		h.vaiven += h.vel_vaiven * delta
		h.vuelta += h.vel_vuelta * delta * (0.5 + relativo / 400.0)
		var lado := sin(h.vaiven)
		# De plano frena mas el aire (y cae menos); de canto corta el aire.
		var plano := absf(cos(h.vuelta))
		# Cada hoja con su peso: unas se las lleva el aire antes que otras, y asi
		# no viajan todas en fila a la misma velocidad.
		var k: float = lerpf(1.0, 2.6, plano) * h.arrastre
		h.vel += (viento - h.vel) * (1.0 - exp(-k * delta))
		h.vel.y = minf(h.vel.y + gravedad * delta * (1.0 - 0.45 * plano), caida_max)
		# Pendulo: se desliza de lado y sube un poco al final de cada vaiven.
		h.pos += (h.vel + Vector2(lado * 65.0, -absf(lado) * 20.0)) * delta
		h.ang = h.ang_base + lado * 0.7 + h.vel.x * 0.0005
		# Con el aire en contra da volteretas: cuanto mas le sopla, mas gira. Si
		# no, mantenia el angulo con el que salio y cruzaban como palitos.
		h.ang_base += (h.giro + signf(h.giro) * relativo / 260.0 * 2.2) * delta
		if h.pos.x < IMAGEN.x + 120.0 and h.pos.y < IMAGEN.y + 120.0 and h.pos.x > -120.0 and h.pos.y > -200.0:
			vivas.append(h)
	_hojas = vivas

func _draw() -> void:
	for h in _hojas:
		if h.espera > 0.0:
			continue
		var de_cara := cos(h.vuelta)
		# Nunca del todo de canto: de canto es una raya que parpadea, y las hojas
		# que caen se ven casi siempre de cara o al bies.
		var ancho: float = (1.0 if de_cara >= 0.0 else -1.0) * (0.45 + 0.55 * absf(de_cara))
		var luz: float = (0.82 + 0.18 * absf(de_cara)) * (1.0 if de_cara >= 0.0 else 0.85) * h.tono
		# Aparece en medio de su arbusto, entre hojas iguales: un fundido corto basta.
		var a := clampf(h.edad / 0.3, 0.0, 1.0)
		var celda: int = h.celda
		var region := Rect2(Vector2(celda % COLS_ATLAS, celda / COLS_ATLAS) * CELDA, CELDA)
		var esc := Vector2(h.escala * ancho, h.escala)
		# Rastro: cuando va deprisa, dos copias tenues por detras (lo que el ojo
		# ve de un objeto rapido); despacio no hay.
		var vel: Vector2 = h.vel
		var rapidez := clampf((vel.length() - 220.0) / 380.0, 0.0, 1.0)
		if rapidez > 0.0:
			for j in 2:
				var atras := vel * (0.012 * (j + 1))
				draw_set_transform(h.pos - atras, h.ang, esc)
				draw_texture_rect_region(ATLAS, Rect2(-CELDA / 2.0, CELDA), region,
					Color(luz, luz, luz, a * rapidez * (0.28 if j == 0 else 0.13)))
		draw_set_transform(h.pos, h.ang, esc)
		draw_texture_rect_region(ATLAS, Rect2(-CELDA / 2.0, CELDA), region, Color(luz, luz, luz, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Suelta una hoja del arbusto i, de un sitio donde de verdad hay hoja.
func _soltar(i: int, espera: float) -> void:
	var a: Array = ARBUSTOS[i]
	var c: Vector2 = a[1]
	var r: float = a[2]
	var pos := c
	for _n in 24:
		var p := c + Vector2.from_angle(_rng.randf() * TAU) * r * 0.65 * sqrt(_rng.randf())
		if p.x < 20 or p.y < 20 or p.x > IMAGEN.x - 20 or p.y > IMAGEN.y - 20:
			continue
		var mp := Vector2i(int(p.x / IMAGEN.x * _mascara.get_width()), int(p.y / IMAGEN.y * _mascara.get_height()))
		if _mascara.get_pixelv(mp).r > 0.55:
			pos = p
			break
	_hojas.append({
		"pos": pos,
		"vel": Vector2.ZERO,
		"espera": espera,
		"edad": 0.0,
		"celda": _rng.randi() % (COLS_ATLAS * FILAS_ATLAS),
		"escala": _rng.randf_range(escala.x, escala.y),
		"ang_base": _rng.randf_range(-PI, PI),
		"ang": 0.0,
		"giro": _rng.randf_range(0.3, 0.9) * (1.0 if _rng.randf() < 0.5 else -1.0),
		"arrastre": _rng.randf_range(0.6, 1.4),
		"vaiven": _rng.randf() * TAU,
		"vel_vaiven": _rng.randf_range(2.2, 3.4),
		"vuelta": _rng.randf() * TAU,
		"vel_vuelta": _rng.randf_range(2.5, 5.5) * (1.0 if _rng.randf() < 0.5 else -1.0),
		"tono": _rng.randf_range(0.9, 1.0),
	})

func _siguiente_suelta() -> float:
	return suelta_cada * _rng.randf_range(0.5, 1.5)
