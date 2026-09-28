extends Node2D
## El trazo del arco sobre el agua del abismo.
##
## Cuando nace el sol, su reflejo resbala por el agua hasta el baston y alli el
## trazo se abre como la pata de un compas que gira: la mitad de arriba de un
## circulo con centro en el pie del baston. La mitad de abajo la pone el agua (el
## reflejo del shader del agua), igual que con el sol partido por el horizonte.
## El jugador solo tiene que construir el arco de medio punto; el agua completa
## el circulo.
##
## El arco se divide en tramos. Un tramo se enciende cuando se CONSTRUYE en el:
## cuando el peregrino esta de pie dentro de la banda (sobre una losa, una repisa
## o el agua en los arranques) o cuando nace una losa en ella (pisar el aire).
## Pasar volando por encima no cuenta. Lo que se construye sobre un tramo
## encendido ya no se deshace: es copia de algo real. Con todos encendidos se
## cierra: las dovelas se colocan desde los dos arranques hacia arriba y la
## ultima es la clave.
##
## Pistas, de menos a mas y solo si el jugador no avanza (nunca flechas):
##   siempre: lo que se pone encima aguanta; las motas de lo olvidado se posan en el
##   45 s sin avanzar: una chispa recorre el primer hueco, cada 12 s
##   60 s sin avanzar: el trazo sube un poco de brillo
##   5+ tramos y 30 s parado: pista_trozo (el pensamiento "Le falta un trozo.")

signal tramo_encendido(indice: int, encendidos: int)
signal recordado_tocado
signal pista_trozo
signal clave_puesta
signal cerrado

const Sintetizador := preload("res://scripts/capitulo1/sintetizador.gd")
const TRAZO := Color("e9c27a")
const CARBON := Color("2b2a2e")
const PIEDRA_FRIA := [Color("8a93a0"), Color("707a88"), Color("5b6370")]
const DOVELA := [Color("c9a574"), Color("b39064"), Color("9a7b55")]
## Pentatonica de Re, de los arranques (grave) a la clave (aguda).
const NOTAS := [293.66, 329.63, 369.99, 440.0, 493.88, 587.33]

@export var centro := Vector2(1250, 1150)
@export var radio: float = 460.0
@export var banda: float = 75.0
@export var tramos: int = 12
@export var alfa_base: float = 0.13
## Suelos que ya estaban: repisas invisibles sobre el arco, en grados (0 a la
## derecha, 90 arriba).
@export var recordados_grados: Array = [35.0, 145.0]

var activo := false
var peregrino  # peregrino_sueno.gd
var estelas  # estelas.gd

var _encendidos: Array = []
var _t := 0.0
var _t_ultimo := 0.0
var _alfa := 0.0
var _alfa_objetivo := 0.0
var _barrido := 0.0     # 0..1: hasta donde se ha abierto el trazo (de 0 a 180 grados)
var _destello := -1.0   # x del reflejo que resbala por el agua, -1 = no
var _destello_desde := 0.0
var _llegada := -99.0   # instante en que el reflejo llega al pie del baston
var _chispa := -1.0     # 0..1 del recorrido de la chispa, -1 = no
var _chispa_desde := 0.0
var _chispa_hasta := 0.0
var _t_chispa := -99.0
var _dijo_trozo := false
var _cierre := -1.0     # instante del cierre, -1 = abierto
var _clave := false
var _recordados: Array = []
var _mitad_baja: Node2D
var _brillos: Node2D
var _halo: Texture2D
var _notas: Array = []
var _reproductores: Array = []
var _voz := 0
var _dron: AudioStreamPlayer
var _acorde: AudioStreamPlayer
var _toc: AudioStreamPlayer

func _ready() -> void:
	_encendidos.resize(tramos)
	_encendidos.fill(false)
	_halo = _textura_halo()
	# La mitad de abajo del circulo, cuando el reflejo se vuelve piedra de verdad,
	# se dibuja por encima del agua (z relativo: 1 + 11 > 10).
	_mitad_baja = Node2D.new()
	_mitad_baja.z_index = 11
	_mitad_baja.draw.connect(_dibujar_mitad_baja)
	add_child(_mitad_baja)
	# Brillos sobre el agua (el reflejo que resbala), en suma de luz.
	_brillos = Node2D.new()
	_brillos.z_index = 11
	var suma := CanvasItemMaterial.new()
	suma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_brillos.material = suma
	_brillos.draw.connect(_dibujar_brillos)
	add_child(_brillos)
	for f in NOTAS:
		_notas.append(Sintetizador.cuenco(f, 3.5, 0.40))
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.volume_db = -14.0
		add_child(p)
		_reproductores.append(p)
	_dron = AudioStreamPlayer.new()
	_dron.stream = Sintetizador.dron([110.0, 164.81, 220.0])
	_dron.volume_db = -60.0
	add_child(_dron)
	_acorde = AudioStreamPlayer.new()
	_acorde.stream = Sintetizador.acorde([146.83, 293.66, 369.99, 440.0, 587.33])
	_acorde.volume_db = -10.0
	add_child(_acorde)
	_toc = AudioStreamPlayer.new()
	_toc.stream = Sintetizador.toc()
	_toc.volume_db = -4.0
	add_child(_toc)

## El reflejo del sol resbala por el agua hasta el pie del baston y ahi el trazo
## se abre girando. Tambien aparecen (invisibles) los suelos que ya estaban.
func aparecer(desde_x: float, duracion: float) -> void:
	_destello_desde = desde_x
	_destello = desde_x
	var tw := create_tween()
	tw.tween_property(self, "_destello", centro.x, duracion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_destello = -1.0
	_llegada = _t
	_alfa = alfa_base
	_alfa_objetivo = alfa_base
	var tb := create_tween()
	tb.tween_property(self, "_barrido", 1.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.3)
	await tb.finished
	_activar()
	create_tween().tween_property(_dron, "volume_db", -26.0, 6.0)

## Lo mismo sin animacion (para empezar la maqueta en las estelas).
func aparecer_ya() -> void:
	_alfa = alfa_base
	_alfa_objetivo = alfa_base
	_barrido = 1.0
	_activar()
	_dron.volume_db = -26.0

func _activar() -> void:
	for g in recordados_grados:
		_recordados.append(_crear_recordado(g))
	activo = true
	_t_ultimo = _t
	_dron.play()

func _crear_recordado(grados: float) -> Dictionary:
	var p := punto_en(grados)
	var c := StaticBody2D.new()
	c.collision_layer = 2
	c.collision_mask = 0
	var f := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(124, 10)
	f.shape = r
	f.one_way_collision = true
	f.one_way_collision_margin = 10.0
	f.position = Vector2(0, 5)
	c.add_child(f)
	c.position = p
	c.set_meta("recordado", true)
	add_child(c)
	return {grados = grados, pos = p, cuerpo = c, revelado = -1.0}

func punto_en(grados: float) -> Vector2:
	var a := deg_to_rad(grados)
	return centro + Vector2(cos(a), -sin(a)) * radio

## 0 a la derecha, 90 arriba, 180 a la izquierda. Lo que queda un poco por debajo
## del horizonte cuenta como si estuviera en el (0 o 180, segun el lado).
func grados_de(p: Vector2) -> float:
	return rad_to_deg(atan2(maxf(centro.y - p.y, 0.0), p.x - centro.x))

func en_banda(p: Vector2) -> bool:
	if p.y > centro.y + 6.0:
		return false
	return absf(p.distance_to(centro) - radio) < banda

func tramo_de(p: Vector2) -> int:
	var g := clampf(grados_de(p), 0.0, 179.99)
	return int(g / (180.0 / tramos))

## Lo que se pone aqui se queda: esta sobre un tramo encendido.
func fija(p: Vector2) -> bool:
	return activo and en_banda(p) and _encendidos[tramo_de(p)]

## Hay un suelo que ya estaba justo aqui (no se pone losa encima).
func sobre_recordado(p: Vector2) -> bool:
	for r in _recordados:
		if absf(p.y - r.pos.y) < 16.0 and absf(p.x - r.pos.x) < 62.0 + 30.0:
			return true
	return false

func punto_mas_cercano(p: Vector2) -> Vector2:
	return punto_en(clampf(grados_de(p), 0.0, 180.0))

func encendidos() -> int:
	return _encendidos.count(true)

## Una losa nueva en la banda enciende su tramo (pisar el aire sobre el trazo).
func al_crear_losa(l) -> void:
	if activo and _cierre < 0.0 and en_banda(l.pos):
		var i := tramo_de(l.pos)
		if not _encendidos[i]:
			_encender(i)

## Solo pruebas: enciende todo y cierra.
func forzar_cierre() -> void:
	for i in tramos:
		_encendidos[i] = true
	_cerrar()

func _physics_process(delta: float) -> void:
	_t += delta
	if not activo or _cierre >= 0.0 or peregrino == null:
		return
	if not peregrino.is_on_floor():
		return
	var pies: Vector2 = peregrino.global_position
	# Suelos que ya estaban: al pisarlos aparecen y ya no se van.
	var bajo = peregrino.suelo_actual()
	for r in _recordados:
		if r.revelado < 0.0 and bajo == r.cuerpo:
			r.revelado = _t
			_toc.pitch_scale = 0.55
			_toc.play()
			recordado_tocado.emit()
	if en_banda(pies):
		var i := tramo_de(pies)
		if not _encendidos[i]:
			_encender(i)

func _encender(i: int) -> void:
	_encendidos[i] = true
	_t_ultimo = _t
	var n := encendidos()
	var nota: AudioStreamWAV = _notas[mini(i, tramos - 1 - i) * (NOTAS.size() - 1) / maxi(1, tramos / 2 - 1)]
	var voz: AudioStreamPlayer = _reproductores[_voz]
	_voz = (_voz + 1) % _reproductores.size()
	voz.stream = nota
	voz.play()
	if estelas:
		var a0 := i * 180.0 / tramos
		var a1 := a0 + 180.0 / tramos
		estelas.fijar_las_de(func(p: Vector2) -> bool:
			var g := grados_de(p)
			return en_banda(p) and g >= a0 - 0.5 and g <= a1 + 0.5)
	tramo_encendido.emit(i, n)
	if n == tramos:
		_cerrar()

func _cerrar() -> void:
	if _cierre >= 0.0:
		return
	_cierre = _t
	activo = false
	create_tween().tween_property(_dron, "volume_db", -60.0, 1.2)
	cerrado.emit()

func _process(_delta: float) -> void:
	var dt := get_process_delta_time()
	if _cierre < 0.0 and activo:
		var parado := _t - _t_ultimo
		_alfa_objetivo = alfa_base * (1.4 if parado > 60.0 else 1.0)
		if parado > 45.0 and _chispa < 0.0 and _t - _t_chispa > 12.0:
			_lanzar_chispa()
		if not _dijo_trozo and encendidos() >= 5 and parado > 30.0:
			_dijo_trozo = true
			pista_trozo.emit()
	_alfa = move_toward(_alfa, _alfa_objetivo, 0.05 * dt)
	if _chispa >= 0.0:
		_chispa += dt / 3.0
		if _chispa > 1.0:
			_chispa = -1.0
	if _cierre >= 0.0:
		var c := _t - _cierre
		if not _clave and c > 2.7:
			_clave = true
			_toc.pitch_scale = 1.0
			_toc.play()
			_acorde.play()
			clave_puesta.emit()
	queue_redraw()
	_mitad_baja.queue_redraw()
	_brillos.queue_redraw()

## Chispa: sale del borde de lo encendido y recorre el primer hueco.
func _lanzar_chispa() -> void:
	_t_chispa = _t
	var paso := 180.0 / tramos
	for i in tramos:
		if not _encendidos[i]:
			var j := i
			while j < tramos and not _encendidos[j]:
				j += 1
			_chispa_desde = i * paso
			_chispa_hasta = j * paso
			_chispa = 0.0
			return

## Intensidad del trazo en un angulo: no es una linea de interfaz sino un trazo
## rayado a mano, que respira y se funde junto al agua.
func _pulso(g: float) -> float:
	var irregular := 0.75 + 0.25 * sin(g * 0.21 + 1.3) * sin(g * 0.07 + 0.4)
	var pie := smoothstep(0.0, 8.0, g) * smoothstep(0.0, 8.0, 180.0 - g)
	return irregular * lerpf(0.35, 1.0, pie)

func _draw() -> void:
	var paso := 180.0 / tramos
	var latido := 1.0 + 0.07 * sin(TAU * _t / 4.5)
	var c := _t - _cierre if _cierre >= 0.0 else -1.0
	var hasta := 180.0 * _barrido
	# Se dibuja en trozos cortos para que la intensidad varie por el camino.
	var sub := 4
	for i in tramos:
		for s in sub:
			var a0 := i * paso + s * paso / sub
			var a1 := a0 + paso / sub
			if a0 >= hasta and c < 0.0:
				break
			a1 = minf(a1, hasta) if c < 0.0 else a1
			var g := (a0 + a1) * 0.5
			var col: Color
			var ancho: float
			if c >= 0.0:
				col = Color(TRAZO, lerpf(0.4, 0.85, clampf(c / 0.4, 0.0, 1.0)))
				ancho = 3.0
			elif _encendidos[i]:
				col = Color(TRAZO, minf(0.38 * latido * lerpf(0.8, 1.0, _pulso(g)), 1.0))
				ancho = 3.0
			else:
				col = Color(TRAZO, _alfa * latido * _pulso(g))
				ancho = 1.6
			draw_arc(centro, radio, -deg_to_rad(a1), -deg_to_rad(a0), 4, col, ancho, true)
	# Punta del compas mientras se abre.
	if _barrido > 0.0 and _barrido < 1.0:
		var p := punto_en(hasta)
		draw_texture_rect(_halo, Rect2(p - Vector2(22, 22), Vector2(44, 44)), false, Color(1.0, 0.88, 0.6, 0.6))
	if _chispa >= 0.0:
		var g := lerpf(_chispa_desde, _chispa_hasta, _chispa)
		var a := sin(PI * _chispa)
		draw_texture_rect(_halo, Rect2(punto_en(g) - Vector2(26, 26), Vector2(52, 52)), false, Color(1.0, 0.86, 0.55, 0.7 * a))
	for r in _recordados:
		if r.revelado >= 0.0:
			_dibujar_recordado(r)
	if c >= 0.0:
		_dibujar_dovelas(c, self, false)

## El reflejo del sol resbalando por el agua hasta el baston, con la estela que
## deja, y el destello al llegar al pie. Va sobre el agua y en suma de luz.
func _dibujar_brillos() -> void:
	var y := centro.y + 6.0
	if _destello >= 0.0:
		_brillos.draw_line(Vector2(_destello, y), Vector2(_destello_desde, y), Color(1.0, 0.85, 0.6, 0.18), 2.0, true)
		_brillos.draw_texture_rect(_halo, Rect2(Vector2(_destello - 150, y - 9), Vector2(300, 18)), false, Color(1.0, 0.88, 0.62, 0.8))
		_brillos.draw_texture_rect(_halo, Rect2(Vector2(_destello - 60, y - 4), Vector2(120, 8)), false, Color(1.0, 0.95, 0.8, 0.8))
	var k := 1.0 - (_t - _llegada) / 0.9
	if k > 0.0:
		_brillos.draw_texture_rect(_halo, Rect2(Vector2(centro.x - 95, y - 50), Vector2(190, 100)), false, Color(1.0, 0.88, 0.62, 0.5 * k))

## Losa fria, gris y con trazo de carbon: no la ha hecho el, ya estaba. Lleva una
## marca de cantero.
func _dibujar_recordado(r: Dictionary) -> void:
	var k := clampf((_t - r.revelado) / 0.5, 0.0, 1.0)
	var p: Vector2 = r.pos
	var w := 62.0
	var pts := PackedVector2Array([p + Vector2(-w, 0), p + Vector2(w, 0), p + Vector2(w - 6, 12), p + Vector2(w * 0.3, 22), p + Vector2(-w * 0.35, 20), p + Vector2(-w + 5, 11)])
	var centro_l := p + Vector2(8, 9)
	for i in pts.size():
		var col: Color = PIEDRA_FRIA[i % 3]
		col.a = k
		draw_colored_polygon(PackedVector2Array([centro_l, pts[i], pts[(i + 1) % pts.size()]]), col)
	draw_polyline(PackedVector2Array([pts[0], pts[1]]), Color(CARBON, 0.8 * k), 2.0, true)
	# Marca de cantero: un angulo con una barra.
	var m := p + Vector2(-14, 8)
	draw_line(m, m + Vector2(8, 8), Color(CARBON, 0.7 * k), 1.6, true)
	draw_line(m + Vector2(8, 8), m + Vector2(16, 0), Color(CARBON, 0.7 * k), 1.6, true)
	draw_line(m + Vector2(4, 3), m + Vector2(12, 3), Color(CARBON, 0.7 * k), 1.6, true)
	if k < 1.0:
		# Soplo de polvo al aparecer.
		for j in 6:
			var q := p + Vector2((j - 2.5) * 22.0, -4.0 - 26.0 * k)
			draw_circle(q, 2.5, Color(0.75, 0.78, 0.82, 0.5 * (1.0 - k)))

## Dovelas: se colocan de dos en dos desde los arranques hacia arriba; la clave
## es la ultima. En la mitad de abajo (espejo) cuajan despues, sobre el agua.
func _dibujar_dovelas(c: float, lienzo: CanvasItem, abajo: bool) -> void:
	var paso := 180.0 / tramos
	var r1 := radio - 22.0
	var r2 := radio + 22.0
	var signo := -1.0 if abajo else 1.0
	for i in tramos:
		var par := mini(i, tramos - 1 - i)
		var inicio := (2.9 + par * 0.12) if abajo else (1.4 + par * 0.2)
		var k := clampf((c - inicio) / 0.3, 0.0, 1.0)
		if k <= 0.0:
			continue
		var a0 := deg_to_rad(i * paso + 0.4)
		var a1 := deg_to_rad((i + 1) * paso - 0.4)
		var am := (a0 + a1) * 0.5
		var desde := Vector2(0, -24.0 * (1.0 - k)) * signo
		var puntos := PackedVector2Array()
		for a in [a0, am, a1]:
			puntos.append(centro + Vector2(cos(a), -sin(a) * signo) * r2 + desde)
		for a in [a1, am, a0]:
			puntos.append(centro + Vector2(cos(a), -sin(a) * signo) * r1 + desde)
		var mitad := centro + Vector2(cos(am), -sin(am) * signo) * radio + desde
		for j in puntos.size():
			var col: Color = DOVELA[(i + j) % 3]
			if abajo:
				col = col.darkened(0.12)
			col.a = k
			lienzo.draw_colored_polygon(PackedVector2Array([mitad, puntos[j], puntos[(j + 1) % puntos.size()]]), col)
		# Juntas de oro entre dovelas.
		var junta := Color(TRAZO, 0.55 * k)
		lienzo.draw_line(centro + Vector2(cos(a0), -sin(a0) * signo) * r1, centro + Vector2(cos(a0), -sin(a0) * signo) * r2, junta, 1.5, true)
	if not abajo:
		# La clave, un poco mas alta que las demas, cae la ultima.
		var kc := clampf((c - 2.45) / 0.25, 0.0, 1.0)
		if kc > 0.0:
			var arriba := centro + Vector2(0, -radio)
			var caida := Vector2(0, -40.0 * (1.0 - kc))
			var cl := PackedVector2Array([arriba + Vector2(-26, -30) + caida, arriba + Vector2(26, -30) + caida, arriba + Vector2(19, 26) + caida, arriba + Vector2(-19, 26) + caida])
			lienzo.draw_colored_polygon(PackedVector2Array([arriba + caida, cl[0], cl[1]]), Color(DOVELA[0], kc))
			lienzo.draw_colored_polygon(PackedVector2Array([arriba + caida, cl[1], cl[2]]), Color(DOVELA[1], kc))
			lienzo.draw_colored_polygon(PackedVector2Array([arriba + caida, cl[2], cl[3]]), Color(DOVELA[2], kc))
			lienzo.draw_colored_polygon(PackedVector2Array([arriba + caida, cl[3], cl[0]]), Color(DOVELA[1].lightened(0.1), kc))
			if _clave:
				var destello := clampf(1.0 - (c - 2.7) / 1.2, 0.0, 1.0)
				lienzo.draw_texture_rect(_halo, Rect2(arriba - Vector2(90, 90), Vector2(180, 180)), false, Color(1.0, 0.85, 0.55, 0.5 * destello))

func _dibujar_mitad_baja() -> void:
	if _cierre < 0.0:
		return
	_dibujar_dovelas(_t - _cierre, _mitad_baja, true)

func _textura_halo() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t
