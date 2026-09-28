extends Node2D
## Las estelas del peregrino: losas de luz que se enfrian a piedra bajo sus pies
## y que se deshacen al rato si no se vuelven a pisar. Lo que se inventa de la
## nada no dura; solo se queda lo que cae sobre el trazo del arco (ver
## arco_reflejo.gd), que es copia de algo real, el reflejo del sol.
##
## Ciclo de una losa:
##   nace (0-0,25 s): luz dorada que crece
##   se enfria (0,25-1,2 s): faceta a faceta, de oro a arenisca
##   vive: le queda un filo de oro que se apaga con la vida que le queda
##   grietas (0,6 s): se abren juntas de luz; todavia sostiene
##   se deshace (1 s): pierde la colision, los triangulos suben y se apagan
##     (la luz vuelve al sol: nunca caen como escombro)
## Nada se deshace bajo los pies: pisarla la reaviva.
##
## Se dibuja todo en un solo _draw; cada losa tiene su StaticBody2D de un solo
## sentido en la capa 2. Las que nacen sobre el agua (al andar por ella) se
## dibujan en una capa por encima del agua: si no, el agua las taparia.

signal losa_creada(losa)
signal losa_deshecha(losa)

@export var vida: float = 7.0
@export var ancho_min: float = 86.0
@export var ancho_max: float = 106.0
@export var max_losas: int = 90
@export var vida_hilo: float = 1.5

const ORO := Color("ffd68a")
const FILO := Color("f3c56a")
const PIEDRA := [Color("bf9a66"), Color("9c7b52"), Color("ad9170"), Color("86735c")]
const DIR_SOL := Vector2(0.8, -0.6)

class Losa:
	var pos: Vector2
	var ancho: float
	var puntos: PackedVector2Array  # contorno local
	var centro_facetas: Vector2
	var colores: Array = []
	var nacida := 0.0
	var ultima := 0.0
	var reavivada := -99.0
	var estado := 0  # 0 viva, 1 grietas, 2 deshaciendose, 3 volando al arco, 4 muerta
	var t_estado := 0.0
	var permanente := false
	var en_agua := false
	var cuerpo: StaticBody2D
	var deriva: Array = []
	var destino := Vector2.ZERO
	var origen := Vector2.ZERO

class Mota:
	var p: Vector2
	var v: Vector2
	var t0 := 0.0
	var pegada := false
	var tp := 0.0
	var origen := Vector2.ZERO
	var destino := Vector2.ZERO

var activo := false
var peregrino  # peregrino_sueno.gd
var arco  # arco_reflejo.gd

var _losas: Array = []
var _hilo: Array = []  # [pos, t]
var _motas: Array = []  # Mota
var _t := 0.0
var _azar := RandomNumberGenerator.new()
var _halo: Texture2D
var _recogiendo := false
var _bajo_anterior: Losa
var _capa_agua: Node2D

func _ready() -> void:
	_azar.seed = 1234
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_halo = tex
	_capa_agua = Node2D.new()
	_capa_agua.z_index = 9  # relativo: por encima del agua (z 10)
	_capa_agua.draw.connect(_dibujar_capa_agua)
	add_child(_capa_agua)

func conectar(p) -> void:
	peregrino = p
	p.paso_sobre.connect(_al_pasar)
	p.paso_en_aire.connect(func(pos: Vector2): crear(pos))
	p.aterrizo.connect(func(pos: Vector2): if activo: crear(pos))

func _al_pasar(pos: Vector2, direccion: float) -> void:
	if not activo:
		return
	# Un poco por delante del pie, para que el borde se alargue antes de llegar.
	crear(pos + Vector2(direccion * 24.0, 0.0))

## Pone una losa con el borde de arriba en pos, o reaviva la que ya hay ahi.
func crear(pos: Vector2) -> Losa:
	if not activo:
		return null
	# Sobre un suelo que ya estaba no se pone nada: se veria la losa y no el suelo.
	if arco and arco.sobre_recordado(pos):
		return null
	for l in _losas:
		if l.estado <= 1 and absf(l.pos.x - pos.x) < l.ancho * 0.45 and absf(l.pos.y - pos.y) < 16.0:
			_reavivar(l)
			return l
	var nueva := Losa.new()
	nueva.pos = pos
	nueva.ancho = _azar.randf_range(ancho_min, ancho_max)
	nueva.nacida = _t
	nueva.ultima = _t
	_formar(nueva)
	nueva.cuerpo = _cuerpo(nueva)
	nueva.en_agua = arco != null and pos.y >= arco.centro.y - 1.0
	if arco and arco.fija(pos):
		nueva.permanente = true
	_losas.append(nueva)
	losa_creada.emit(nueva)
	_limitar()
	return nueva

func _reavivar(l: Losa) -> void:
	l.ultima = _t
	l.reavivada = _t
	if l.estado == 1:
		l.estado = 0

## Contorno facetado como el habito: arriba plano (se pisa), abajo roto como una
## lasca de cantera. Se triangula en abanico desde un punto descentrado y cada
## faceta toma un tono de arenisca segun mire al sol.
func _formar(l: Losa) -> void:
	var w := l.ancho * 0.5
	var fondo := _azar.randf_range(24.0, 38.0)
	l.puntos = PackedVector2Array([
		Vector2(-w, 0), Vector2(w, 0),
		Vector2(w - 5, _azar.randf_range(6, 10)),
		Vector2(w * 0.45, _azar.randf_range(14, 22)),
		Vector2(_azar.randf_range(-w * 0.15, w * 0.15), fondo),
		Vector2(-w * 0.5, _azar.randf_range(13, 21)),
		Vector2(-w + 4, _azar.randf_range(5, 9)),
	])
	l.centro_facetas = Vector2(_azar.randf_range(-w * 0.2, w * 0.2), _azar.randf_range(6.0, 9.0))
	l.colores.clear()
	l.deriva.clear()
	for i in l.puntos.size():
		var a := l.puntos[i]
		var b := l.puntos[(i + 1) % l.puntos.size()]
		var normal := ((a + b) * 0.5 - l.centro_facetas).normalized()
		var base: Color = PIEDRA[0] if i == 0 else PIEDRA[1 + (i % 3)]
		var luz := 0.86 + 0.22 * normal.dot(DIR_SOL)
		var v := _azar.randf_range(-0.05, 0.05)
		l.colores.append(Color(base.r * (luz + v), base.g * (luz + v), base.b * (luz + v)))
		l.deriva.append(Vector2(_azar.randf_range(-22, 22), _azar.randf_range(-95, -45)))

func _cuerpo(l: Losa) -> StaticBody2D:
	var c := StaticBody2D.new()
	c.collision_layer = 2
	c.collision_mask = 0
	var f := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(l.ancho - 6.0, 10.0)
	f.shape = r
	f.one_way_collision = true
	f.one_way_collision_margin = 10.0
	f.position = Vector2(0, 5)
	c.add_child(f)
	c.position = l.pos
	c.set_meta("losa", l)
	add_child(c)
	return c

func _soltar_cuerpo(l: Losa) -> void:
	if is_instance_valid(l.cuerpo):
		l.cuerpo.queue_free()
	l.cuerpo = null

func _limitar() -> void:
	var vivas := []
	for l in _losas:
		if l.estado == 0 and not l.permanente:
			vivas.append(l)
	if vivas.size() <= max_losas:
		return
	vivas.sort_custom(func(a, b): return a.ultima < b.ultima)
	var bajo := _losa_pisada()
	for i in vivas.size() - max_losas:
		if vivas[i] != bajo:
			_empezar_grietas(vivas[i])

func _losa_pisada() -> Losa:
	if peregrino == null:
		return null
	var s = peregrino.suelo_actual()
	if s != null and s is Node and s.has_meta("losa"):
		return s.get_meta("losa")
	return null

func _empezar_grietas(l: Losa) -> void:
	l.estado = 1
	l.t_estado = _t

## El arco ha encendido un tramo: lo que ya haya encima se queda.
func fijar_las_de(comprobar: Callable) -> void:
	for l in _losas:
		if l.estado <= 1 and not l.permanente and comprobar.call(l.pos):
			l.permanente = true
			_reavivar(l)

func cuantas_fijas() -> int:
	var n := 0
	for l in _losas:
		if l.permanente and l.estado == 0:
			n += 1
	return n

## Cierre del circulo: todo lo que sigue vivo vuela al punto mas cercano del arco
## y se funde en el.
func recoger_hacia_el_arco() -> void:
	_recogiendo = true
	activo = false
	for l in _losas:
		if l.estado <= 2:
			_soltar_cuerpo(l)
			l.estado = 3
			l.t_estado = _t + _azar.randf_range(0.0, 0.35)
			l.origen = l.pos
			l.destino = arco.punto_mas_cercano(l.pos)
	for m in _motas:
		m.pegada = false
		m.origen = m.p
		m.destino = arco.punto_mas_cercano(m.p)
		m.t0 = _t + _azar.randf_range(0.0, 0.35)

func _physics_process(delta: float) -> void:
	_t += delta
	var bajo := _losa_pisada()
	if bajo:
		# El destello de reavivar, solo al pisarla de nuevo; la vida, siempre.
		if bajo != _bajo_anterior:
			_reavivar(bajo)
		else:
			bajo.ultima = _t
			if bajo.estado == 1:
				bajo.estado = 0
	_bajo_anterior = bajo
	for l in _losas:
		match l.estado:
			0:
				if not l.permanente and l != bajo and _t - l.ultima > vida:
					_empezar_grietas(l)
			1:
				if _t - l.t_estado > 0.6:
					l.estado = 2
					l.t_estado = _t
					_soltar_cuerpo(l)
					_soltar_motas(l)
			2:
				if _t - l.t_estado > 1.0:
					l.estado = 4
					losa_deshecha.emit(l)
			3:
				if _t - l.t_estado > 1.2:
					l.estado = 4
	_losas = _losas.filter(func(l): return l.estado != 4)
	_actualizar_hilo()
	_actualizar_motas(delta)
	queue_redraw()

func _actualizar_hilo() -> void:
	if peregrino and activo and not peregrino.is_on_floor():
		var p: Vector2 = peregrino.global_position
		if _hilo.is_empty() or _hilo[-1][0].distance_to(p) > 6.0:
			_hilo.append([p, _t])
	while not _hilo.is_empty() and _t - _hilo[0][1] > vida_hilo:
		_hilo.pop_front()

func _soltar_motas(l: Losa) -> void:
	for i in 4:
		var m := Mota.new()
		m.p = l.pos + Vector2(_azar.randf_range(-l.ancho * 0.4, l.ancho * 0.4), _azar.randf_range(2, 14))
		m.v = Vector2(_azar.randf_range(-12, 12), _azar.randf_range(-55, -28))
		m.t0 = _t
		_motas.append(m)

## Las motas de lo que se olvida suben hacia el sol; las que pasan cerca del trazo
## se quedan posadas en el un rato, y asi el trazo se va dibujando solo.
func _actualizar_motas(delta: float) -> void:
	var quedan := []
	for m in _motas:
		if _recogiendo:
			var v := clampf((_t - m.t0) / 1.2, 0.0, 1.0)
			m.p = m.origen.lerp(m.destino, v * v * (3.0 - 2.0 * v))
			if v < 1.0:
				quedan.append(m)
			continue
		if m.pegada:
			if _t - m.tp < 20.0:
				quedan.append(m)
			continue
		m.p += m.v * delta
		if arco and arco.activo:
			var q: Vector2 = arco.punto_mas_cercano(m.p)
			if q.distance_to(m.p) < 55.0:
				m.p = q
				m.pegada = true
				m.tp = _t
		if _t - m.t0 < 3.5:
			quedan.append(m)
	_motas = quedan

func _draw() -> void:
	# Hilo de luz del salto: sin colision, se apaga en vida_hilo.
	for i in range(1, _hilo.size()):
		var a: Array = _hilo[i - 1]
		var b: Array = _hilo[i]
		var k: float = 1.0 - (_t - b[1]) / vida_hilo
		draw_line(a[0], b[0], Color(FILO, 0.30 * k), 2.0, true)
	for l in _losas:
		if not l.en_agua:
			_dibujar_losa(l, self)
	for m in _motas:
		var k := 1.0
		if _recogiendo:
			var v := clampf((_t - m.t0) / 1.2, 0.0, 1.0)
			k = 1.0 - maxf(0.0, (v - 0.75) / 0.25)
		elif m.pegada:
			k = clampf(1.0 - (_t - m.tp - 16.0) / 4.0, 0.0, 1.0)
		else:
			k = clampf(1.0 - (_t - m.t0) / 3.5, 0.0, 1.0)
		draw_circle(m.p, 2.6, Color(ORO, 0.7 * k))
	_capa_agua.queue_redraw()

func _dibujar_capa_agua() -> void:
	for l in _losas:
		if l.en_agua:
			_dibujar_losa(l, _capa_agua)

func _dibujar_losa(l: Losa, lienzo: CanvasItem) -> void:
	var edad := _t - l.nacida
	var n := l.puntos.size()
	var escala := lerpf(0.7, 1.0, clampf(edad / 0.25, 0.0, 1.0))
	var desplaza := Vector2.ZERO
	var alfa := 1.0
	var u := 0.0
	var centro := l.pos
	if l.estado == 2:
		u = clampf((_t - l.t_estado) / 1.0, 0.0, 1.0)
		alfa = 1.0 - u
	elif l.estado == 3:
		var v := clampf((_t - l.t_estado) / 1.2, 0.0, 1.0)
		v = v * v * (3.0 - 2.0 * v)
		centro = l.origen.lerp(l.destino, v)
		escala *= lerpf(1.0, 0.35, v)
		alfa = 1.0 - maxf(0.0, (v - 0.75) / 0.25)
	# Halo del nacimiento y del reavivado.
	var brillo := maxf(1.0 - edad / 0.45, 0.0)
	brillo = maxf(brillo, 0.6 * maxf(1.0 - (_t - l.reavivada) / 0.25, 0.0))
	if l.estado == 3:
		brillo = 0.6
	if brillo > 0.0:
		var r := l.ancho * 0.75
		lienzo.draw_texture_rect(_halo, Rect2(centro + Vector2(-r, -r * 0.6), Vector2(r * 2, r * 1.3)), false, Color(1.0, 0.82, 0.5, 0.28 * brillo))
	for i in n:
		var a := l.puntos[i] * escala
		var b := l.puntos[(i + 1) % n] * escala
		var c := l.centro_facetas * escala
		var enfriado := clampf((edad - 0.25 - i * 0.06) / 0.9, 0.0, 1.0)
		var col: Color = ORO.lerp(l.colores[i], enfriado)
		if l.estado == 2:
			col = col.lerp(ORO, u * 0.6)
			var d: Vector2 = l.deriva[i] * u
			var giro := u * (0.6 if i % 2 == 0 else -0.6)
			var m := (a + b + c) / 3.0
			a = m + (a - m).rotated(giro) + d
			b = m + (b - m).rotated(giro) + d
			c = m + (c - m).rotated(giro) + d
		elif l.estado == 3:
			col = col.lerp(ORO, 0.7)
		col.a = alfa
		lienzo.draw_colored_polygon(PackedVector2Array([centro + c, centro + a, centro + b]), col)
	if l.estado <= 1:
		# Filo de oro arriba: se apaga con la vida que le queda; en el trazo aguanta.
		var queda := 1.0 if l.permanente else clampf(1.0 - (_t - l.ultima) / vida, 0.0, 1.0)
		var a_filo := (0.62 if l.permanente else 0.36 * queda) + 0.4 * brillo
		lienzo.draw_line(centro + l.puntos[0] * escala, centro + l.puntos[1] * escala, Color(FILO, a_filo), 2.0, true)
		if l.estado == 1:
			var g := clampf((_t - l.t_estado) / 0.6, 0.0, 1.0)
			for i in range(2, n):
				lienzo.draw_line(centro + l.centro_facetas * escala, centro + l.puntos[i] * escala, Color(ORO, 0.85 * g), 1.5, true)
