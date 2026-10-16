extends Node2D
## Pajaros que, de vez en cuando, cruzan a lo lejos por delante de la luz.
##
## Casi siempre un cuervo suelto; a veces (bandada_prob) una bandada pequena,
## mas lejos y mas alta: 4-8 pajaros menores en formacion suelta, cada uno con
## su sitio en el grupo (que va cambiando despacio), su tamano y su aleteo.
##
## Cada pajaro es una silueta oscura: cuerpo, cabeza, cola y dos alas de dos
## tramos (brazo y mano). Las alas son un pequeno modelo 3D proyectado (vista
## lateral y un pelin desde abajo), asi el ala de este lado y la del otro se
## cruzan como en un pajaro de verdad y de plano no desaparecen. Bate a rachas
## (unos aletazos, planea con las alas algo levantadas, otra vez), con la
## bajada mas rapida que la subida, y el cuerpo sube un pelin con cada
## aletazo. Salen de detras de los troncos y se pierden en la niebla del otro
## lado (fundidos), y se funden con el color de su zona. Lejos: casi no se
## mueven con la camara.

const Imagenes := preload("res://scripts/game/imagenes_cache.gd")

## RGB color medio de la zona (medio.png).
@export var medio: Texture2D
## Segundos hasta el primero y entre un paso y el siguiente.
@export var primero := Vector2(9.0, 16.0)
@export var cada := Vector2(25.0, 55.0)
## Probabilidad de que el paso sea una bandada en vez de un cuervo suelto.
@export var bandada_prob := 0.3
@export var bandada_cuantos := Vector2i(4, 8)
## Cuervo suelto: envergadura (px), velocidad (px/s) y altura a la que cruza.
## Por el hueco de niebla clara bajo la copa: en la copa se perdia entre las
## hojas que cuelgan de las ramas.
@export var envergadura := Vector2(32.0, 42.0)
@export var velocidad := Vector2(150.0, 230.0)
@export var altura := Vector2(470.0, 660.0)
## Bandada: mas pequenos y mas lentos en pantalla (mas lejos). Cruzan el
## hueco de niebla clara bajo la copa: en la copa, entre ramas y hojas, no se
## distinguian de las hojas.
@export var bandada_envergadura := Vector2(16.0, 26.0)
@export var bandada_velocidad := Vector2(110.0, 160.0)
@export var bandada_altura := Vector2(430.0, 640.0)
## Por donde entran y salen (px de x).
@export var tramo := Vector2(780.0, 2120.0)
@export var color := Color(0.07, 0.055, 0.05)
## Cuanto se funden con el color de la niebla de su zona.
@export var niebla := 0.35

## La escena: camara.
var controlador: Node

const PANTALLA := Vector2(2912, 1632)
## Inclinacion de la vista (rad): un pelin desde abajo.
const VISTA := -0.38

var _medio: Image
var _rng := RandomNumberGenerator.new()
var _ruido := FastNoiseLite.new()
var _hasta := 10.0
var _t := 0.0
var _activo := false
# El grupo: donde va, hacia donde, a que velocidad y con que pendiente.
var _pos := Vector2.ZERO
var _dir := 1.0
var _vel := 200.0
var _pendiente := 0.0
var _niebla_extra := 0.0
# Cada pajaro: sitio en el grupo, media envergadura y su aleteo.
var _pajaros: Array[Dictionary] = []

func _ready() -> void:
	_rng.randomize()
	_ruido.seed = _rng.randi()
	_ruido.frequency = 1.0
	_medio = Imagenes.de(medio)
	_hasta = _rng.randf_range(primero.x, primero.y)

func _process(delta: float) -> void:
	_t += delta
	if not _activo:
		_hasta -= delta
		if _hasta <= 0.0:
			_salir()
		return
	_pos.x += _dir * _vel * delta
	_pos.y += _pendiente * _vel * delta
	for b in _pajaros:
		_aletear(b, delta)
	var fin := tramo.y if _dir > 0.0 else tramo.x
	# Se acaba cuando ha salido el ultimo del grupo.
	var atras := 0.0
	for b in _pajaros:
		atras = minf(atras, float(b.sitio.x) * _dir)
	if (_pos.x - fin) * _dir + atras > 200.0:
		_activo = false
		_hasta = _rng.randf_range(cada.x, cada.y)
	queue_redraw()

func _aletear(b: Dictionary, delta: float) -> void:
	b.modo_t -= delta
	if b.modo_t <= 0.0:
		b.batiendo = not b.batiendo
		b.modo_t = _rng.randf_range(0.8, 1.6) if b.batiendo else _rng.randf_range(0.6, 1.4)
	var objetivo: float
	if b.batiendo:
		# La bajada (cos < 0) mas rapida que la subida. Los pequenos baten mas.
		b.fase += delta * TAU * float(b.frec) * (1.3 if cos(b.fase) < 0.0 else 0.8)
		objetivo = sin(b.fase)
		b.bote = lerpf(b.bote, -cos(b.fase) * 0.06, 1.0 - exp(-delta * 12.0))
	else:
		objetivo = 0.25
		b.bote = lerpf(b.bote, 0.0, 1.0 - exp(-delta * 4.0))
	b.aleteo = lerpf(b.aleteo, objetivo, 1.0 - exp(-delta * 18.0))

func _pajaro(s: float, sitio: Vector2) -> Dictionary:
	return {
		"s": s,
		"sitio": sitio,
		"semilla": _rng.randf() * 100.0,
		"fase": _rng.randf() * TAU,
		"frec": 3.6 * 30.0 / maxf(s * 2.0, 1.0) * 0.5 + 1.8,
		"batiendo": _rng.randf() < 0.8,
		"modo_t": _rng.randf_range(0.3, 1.4),
		"aleteo": 0.25,
		"bote": 0.0,
	}

func _salir() -> void:
	_activo = true
	_pajaros.clear()
	_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	var ini := tramo.x if _dir > 0.0 else tramo.y
	_pendiente = _rng.randf_range(-0.12, 0.06)
	if _rng.randf() < bandada_prob:
		# Bandada: un lider y el resto detras, escalonados y a distintas alturas.
		_vel = _rng.randf_range(bandada_velocidad.x, bandada_velocidad.y)
		_pos = Vector2(ini - _dir * 150.0, _rng.randf_range(bandada_altura.x, bandada_altura.y))
		_niebla_extra = 0.08
		var n := _rng.randi_range(bandada_cuantos.x, bandada_cuantos.y)
		for i in n:
			var sitio := Vector2.ZERO if i == 0 else Vector2(
				-_dir * _rng.randf_range(25.0, 70.0) * i, _rng.randf_range(-45.0, 45.0) + 6.0 * i)
			_pajaros.append(_pajaro(_rng.randf_range(bandada_envergadura.x, bandada_envergadura.y) * 0.5, sitio))
	else:
		_vel = _rng.randf_range(velocidad.x, velocidad.y)
		_pos = Vector2(ini - _dir * 150.0, _rng.randf_range(altura.x, altura.y))
		_niebla_extra = 0.0
		_pajaros.append(_pajaro(_rng.randf_range(envergadura.x, envergadura.y) * 0.5, Vector2.ZERO))

## Punto del ala proyectado: x a lo largo del cuerpo, el ala gira alrededor
## del cuerpo (aleteo) y la vista lo inclina un pelin.
func _ala(x: float, largo: float, ang: float, lado: float) -> Vector2:
	var y3 := sin(ang) * largo
	var z3 := cos(ang) * largo * lado
	return Vector2(x, -(y3 * cos(VISTA) + z3 * sin(VISTA)))

func _draw() -> void:
	if not _activo:
		return
	var x0 := tramo.x if _dir > 0.0 else tramo.y
	var x1 := tramo.y if _dir > 0.0 else tramo.x
	var largo_tramo := (x1 - x0) * _dir
	for b in _pajaros:
		# El sitio en el grupo se mueve despacio: la formacion respira.
		var s: float = b.s
		var semilla: float = b.semilla
		var deriva := Vector2(_ruido.get_noise_2d(_t * 0.4, semilla), _ruido.get_noise_2d(semilla, _t * 0.4)) * 18.0
		var p: Vector2 = _pos + b.sitio + deriva
		if controlador:
			p += controlador.paralaje(p, 0.1)
		# Aparecen y se pierden a lo largo del tramo.
		var recorrido := (p.x - x0) * _dir
		var a := smoothstep(-150.0, 60.0, recorrido) * (1.0 - smoothstep(largo_tramo - 60.0, largo_tramo + 180.0, recorrido))
		if a <= 0.01:
			continue
		var mx := clampi(int(p.x / PANTALLA.x * _medio.get_width()), 0, _medio.get_width() - 1)
		var my := clampi(int(p.y / PANTALLA.y * _medio.get_height()), 0, _medio.get_height() - 1)
		var m := _medio.get_pixel(mx, my)
		var c := color.lerp(Color(m.r, m.g, m.b), niebla + _niebla_extra)
		c.a = a
		var aleteo: float = b.aleteo
		var bote: float = b.bote
		draw_set_transform(p + Vector2(0.0, bote * s), atan(_pendiente) * _dir, Vector2(_dir, 1.0))
		# Aleteo: el brazo sube/baja algo menos que la mano.
		var brazo := aleteo * 0.9
		var mano := aleteo * 1.25 - 0.1
		for lado in [-1.0, 1.0]:   # primero el ala de alla, luego la de aca
			var hombro := Vector2(0.05 * s, 0.0)
			var codo := _ala(0.02 * s, 0.5 * s, brazo, lado)
			var punta := _ala(-0.18 * s, 0.5 * s, mano, lado) + (codo - Vector2(0.02 * s, 0.0))
			draw_line(hombro, codo, c, 0.16 * s, true)
			draw_line(codo, punta, c, 0.09 * s, true)
			if lado < 0.0:
				# Cuerpo entre las dos alas: tronco, cabeza y cola.
				draw_line(Vector2(-0.32 * s, 0.0), Vector2(0.28 * s, -0.02 * s), c, 0.17 * s, true)
				draw_circle(Vector2(0.36 * s, -0.04 * s), 0.085 * s, c, true, -1.0, true)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-0.3 * s, -0.05 * s), Vector2(-0.56 * s, -0.08 * s),
					Vector2(-0.56 * s, 0.06 * s), Vector2(-0.3 * s, 0.05 * s)]), c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
