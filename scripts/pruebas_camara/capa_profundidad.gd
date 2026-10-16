extends Node2D
## Una capa de la prueba de camara de capas: un plano de dibujo a cierta
## profundidad. La camara (camara_capas.gd) le pone escala y posicion cada
## fotograma; aqui se dibuja en coordenadas del mundo (suelo en y = 1200, como
## Magnus) y la perspectiva la pone la camara. El dibujo es de relleno, por
## codigo, solo para que se lea la profundidad: no es arte del juego.

enum Tipo { ARCADA, COLUMNAS, CERCA, SUELO, PRIMER_PLANO }

## Distancia detras del plano de Magnus (negativa: delante de el).
@export var profundidad: float = 0.0
@export var tipo: Tipo = Tipo.SUELO
@export var color: Color = Color(0.1, 0.1, 0.12)
@export var semilla: int = 1

const SUELO_Y := 1200.0
## Lo que se dibuja a lo ancho: de sobra para la camara mas abierta.
const DESDE := -12000.0
const HASTA := 26000.0

var _rng := RandomNumberGenerator.new()

func _draw() -> void:
	_rng.seed = semilla
	match tipo:
		Tipo.ARCADA: _arcada()
		Tipo.COLUMNAS: _columnas()
		Tipo.CERCA: _cerca()
		Tipo.SUELO: _suelo()
		Tipo.PRIMER_PLANO: _primer_plano()

# --- Capas ------------------------------------------------------------------

## Al fondo: un muro altisimo con arcos apuntados y, detras, ventanales con luz
## de luna. Muy oscuro: casi solo se lee por las aberturas.
func _arcada() -> void:
	var luz := Color(0.16, 0.19, 0.26)
	var vano := 1700.0
	var x := DESDE
	while x < HASTA:
		# Luz detras de cada arco, mas o menos fuerte.
		if _rng.randf() < 0.55:
			_brillo(Vector2(x + vano * 0.5, SUELO_Y - 1300), 900.0, Color(luz, 0.35 * _rng.randf_range(0.4, 1.0)))
		x += vano
	x = DESDE
	var arriba := SUELO_Y - 4400
	while x < HASTA:
		var pilar := 300.0
		draw_rect(Rect2(x, arriba, pilar, SUELO_Y - arriba), color)
		# Enjuta: el muro por encima del arco, con el hueco apuntado.
		var x0 := x + pilar
		var x1 := x + vano
		var arranque := SUELO_Y - 1900
		var pts := PackedVector2Array([Vector2(x0, arriba), Vector2(x1, arriba)])
		pts.append_array(_arco_apuntado(x1, x0, arranque, 18))
		draw_colored_polygon(pts, color)
		# Rosetón en el muro de arriba.
		if _rng.randf() < 0.4:
			var c := Vector2((x0 + x1) * 0.5, arriba + 900)
			_brillo(c, 420.0, Color(luz, 0.25))
			draw_circle(c, 210.0, luz.darkened(0.35))
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c, c + Vector2(cos(a), sin(a)) * 210.0, color, 26.0)
			draw_arc(c, 210.0, 0.0, TAU, 40, color, 30.0)
		x += vano
	draw_rect(Rect2(DESDE, SUELO_Y, HASTA - DESDE, 4000), color.darkened(0.3))

## Fila de columnas a media distancia, con el coloso sentado de la zona grande.
func _columnas() -> void:
	var borde := color.lightened(0.12)
	var x := DESDE
	while x < HASTA:
		var ancho := 170.0
		var rota := _rng.randf() < 0.18
		var alto := _rng.randf_range(900.0, 1700.0) if rota else 2600.0
		_columna(x, ancho, alto, rota, borde)
		x += _rng.randf_range(800.0, 1100.0)
	_coloso(7200.0)
	draw_rect(Rect2(DESDE, SUELO_Y, HASTA - DESDE, 4000), color.darkened(0.25))

## Cerca de Magnus por detras: columnas rotas, cadenas colgando, escombros.
func _cerca() -> void:
	var borde := color.lightened(0.1)
	var x := DESDE
	while x < HASTA:
		var r := _rng.randf()
		if r < 0.45:
			_columna(x, 130.0, _rng.randf_range(500.0, 1300.0), true, borde)
		elif r < 0.75:
			_cadena(Vector2(x, SUELO_Y - 2200), _rng.randf_range(700.0, 1500.0))
		else:
			_escombro(x, _rng.randf_range(120.0, 260.0), color)
		x += _rng.randf_range(600.0, 1300.0)
	draw_rect(Rect2(DESDE, SUELO_Y, HASTA - DESDE, 4000), color.darkened(0.2))

## El plano de Magnus: el suelo, la cripta baja (3000-5000), las velas y la
## sala fija del final (11000-14000).
func _suelo() -> void:
	var piedra := color
	# Cripta: techo bajo con bovedas y pilares achaparrados.
	var techo := SUELO_Y - 640
	draw_rect(Rect2(2900, SUELO_Y - 3000, 2200, 3000 - 640), piedra.darkened(0.35))
	var x := 2900.0
	while x < 5100.0:
		draw_rect(Rect2(x - 45, techo, 90, 640), piedra.darkened(0.15))
		if x + 400 < 5150.0:
			var pts := PackedVector2Array()
			pts.append(Vector2(x + 45, techo))
			pts.append_array(_arco_apuntado(x + 45, x + 355, techo + 260, 12))
			pts.append(Vector2(x + 355, techo))
			draw_colored_polygon(pts, piedra.darkened(0.35))
		x += 400.0
	# Sala del final: arco de entrada, muro de fondo y una ventana alta.
	draw_rect(Rect2(10900, SUELO_Y - 2400, 200, 2400), piedra.darkened(0.2))
	draw_rect(Rect2(13900, SUELO_Y - 2400, 200, 2400), piedra.darkened(0.2))
	var luna := Vector2(12500, SUELO_Y - 1000)
	_brillo(luna, 900.0, Color(0.32, 0.38, 0.5, 0.22))
	var ventana := PackedVector2Array([Vector2(12360, SUELO_Y - 600)])
	ventana.append_array(_arco_apuntado(12360, 12640, SUELO_Y - 1200, 12))
	ventana.append(Vector2(12640, SUELO_Y - 600))
	draw_colored_polygon(ventana, Color(0.42, 0.48, 0.6))
	draw_line(Vector2(12500, SUELO_Y - 1340), Vector2(12500, SUELO_Y - 600), piedra.darkened(0.2), 16.0)
	# Haz de la ventana hasta el suelo.
	draw_colored_polygon(PackedVector2Array([Vector2(12360, SUELO_Y - 600), Vector2(12640, SUELO_Y - 600),
		Vector2(12950, SUELO_Y), Vector2(12450, SUELO_Y)]), Color(0.45, 0.52, 0.65, 0.06))
	# Velas sueltas.
	for vx in [900.0, 3700.0, 4600.0, 6400.0, 9800.0, 11800.0]:
		_vela(Vector2(vx, SUELO_Y))
	# Suelo con juntas.
	draw_rect(Rect2(DESDE, SUELO_Y, HASTA - DESDE, 1200), piedra)
	draw_line(Vector2(DESDE, SUELO_Y), Vector2(HASTA, SUELO_Y), piedra.lightened(0.18), 4.0)
	x = DESDE
	while x < HASTA:
		draw_line(Vector2(x, SUELO_Y + 4), Vector2(x - 40, SUELO_Y + 90), piedra.darkened(0.3), 3.0)
		x += _rng.randf_range(260.0, 520.0)
	draw_line(Vector2(DESDE, SUELO_Y + 90), Vector2(HASTA, SUELO_Y + 90), piedra.darkened(0.3), 3.0)

## Delante de Magnus: siluetas casi negras que pasan entre el y la camara.
func _primer_plano() -> void:
	var x := DESDE
	while x < HASTA:
		var ancho := _rng.randf_range(200.0, 340.0)
		draw_rect(Rect2(x, SUELO_Y - 3000, ancho, 4200), color)
		# Raices o hiedra colgando del pilar.
		for i in _rng.randi_range(2, 5):
			var rx := x + _rng.randf_range(-120.0, ancho + 120.0)
			var largo := _rng.randf_range(400.0, 1400.0)
			_hebra(Vector2(rx, SUELO_Y - 3000), largo, color)
		x += _rng.randf_range(2200.0, 3400.0)
	# Escombros por abajo, casi fuera de cuadro.
	x = DESDE
	while x < HASTA:
		_escombro(x, _rng.randf_range(150.0, 320.0), color, SUELO_Y + 380)
		x += _rng.randf_range(900.0, 2000.0)

# --- Piezas -----------------------------------------------------------------

## Arco apuntado de dos centros: puntos de x_desde a x_hasta pasando por la
## clave. El radio es el 80 % de la luz, como un gotico normal.
func _arco_apuntado(x_desde: float, x_hasta: float, y_arranque: float, n: int) -> PackedVector2Array:
	var x0 := minf(x_desde, x_hasta)
	var x1 := maxf(x_desde, x_hasta)
	var luz := x1 - x0
	var r := luz * 0.8
	var medio := (x0 + x1) * 0.5
	var tope := acos(clampf((medio - (x0 + r)) / r, -1.0, 1.0))
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(PI, tope, float(i) / n)
		izq.append(Vector2(x0 + r + r * cos(a), y_arranque - r * sin(a)))
		der.append(Vector2(x1 - r - r * cos(a), y_arranque - r * sin(a)))
	der.reverse()
	var pts := izq
	pts.append_array(der.slice(1))
	if x_desde > x_hasta:
		pts.reverse()
	return pts

func _columna(x: float, ancho: float, alto: float, rota: bool, borde: Color) -> void:
	var y := SUELO_Y - alto
	if rota:
		# Corte irregular arriba.
		var pts := PackedVector2Array([Vector2(x, SUELO_Y), Vector2(x, y + 60)])
		pts.append(Vector2(x + ancho * 0.3, y))
		pts.append(Vector2(x + ancho * 0.55, y + 90))
		pts.append(Vector2(x + ancho, y + 30))
		pts.append(Vector2(x + ancho, SUELO_Y))
		draw_colored_polygon(pts, color)
	else:
		draw_rect(Rect2(x, y, ancho, alto), color)
		draw_rect(Rect2(x - 40, y, ancho + 80, 70), color)          # capitel
		draw_rect(Rect2(x - 30, SUELO_Y - 80, ancho + 60, 80), color)  # basa
	# Filo izquierdo tocado por la luz.
	draw_line(Vector2(x + 6, y + 80), Vector2(x + 6, SUELO_Y - 80), borde, 10.0)

## Figura encapuchada sentada, enorme: lo que da la escala en la zona grande.
func _coloso(cx: float) -> void:
	var c := color.lightened(0.04)
	var base := SUELO_Y
	draw_rect(Rect2(cx - 1000, base - 500, 2000, 500), c.darkened(0.2))  # pedestal
	var cuerpo := PackedVector2Array([
		Vector2(cx - 800, base - 500), Vector2(cx - 760, base - 1500), Vector2(cx - 520, base - 2500),
		Vector2(cx - 380, base - 3200), Vector2(cx - 150, base - 3550), Vector2(cx + 150, base - 3550),
		Vector2(cx + 380, base - 3200), Vector2(cx + 520, base - 2500), Vector2(cx + 760, base - 1500),
		Vector2(cx + 800, base - 500)])
	draw_colored_polygon(cuerpo, c)
	# Hueco de la capucha, y las rodillas.
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 170, base - 3050), Vector2(cx, base - 3380),
		Vector2(cx + 170, base - 3050), Vector2(cx + 120, base - 2800), Vector2(cx - 120, base - 2800)]), c.darkened(0.6))
	draw_rect(Rect2(cx - 900, base - 1250, 1800, 220), c.lightened(0.03))
	draw_line(Vector2(cx - 780, base - 1500), Vector2(cx - 400, base - 3150), c.lightened(0.12), 14.0)

func _cadena(desde: Vector2, largo: float) -> void:
	var y := 0.0
	var oscuro := color.darkened(0.2)
	while y < largo:
		draw_arc(desde + Vector2(0, y + 22), 18.0, 0.0, TAU, 10, oscuro, 7.0)
		y += 40.0
	draw_circle(desde + Vector2(0, largo + 40), 34.0, oscuro)

func _escombro(x: float, tam: float, c: Color, y: float = SUELO_Y) -> void:
	var pts := PackedVector2Array()
	var n := 7
	for i in n + 1:
		var a := PI + PI * i / n
		var r := tam * _rng.randf_range(0.6, 1.0)
		pts.append(Vector2(x + cos(a) * r * 1.6, y + sin(a) * r * 0.7))
	draw_colored_polygon(pts, c.darkened(0.1))

func _hebra(desde: Vector2, largo: float, c: Color) -> void:
	var pts := PackedVector2Array()
	var fase := _rng.randf() * TAU
	for i in 12:
		var t := float(i) / 11.0
		pts.append(desde + Vector2(sin(fase + t * 5.0) * 30.0 * t, largo * t))
	draw_polyline(pts, c, 14.0)

func _vela(pie: Vector2) -> void:
	_brillo(pie + Vector2(0, -150), 260.0, Color(1.0, 0.62, 0.3, 0.18))
	draw_rect(Rect2(pie.x - 9, pie.y - 110, 18, 110), Color(0.62, 0.56, 0.48))
	draw_circle(pie + Vector2(0, -126), 9.0, Color(1.0, 0.82, 0.5))

## Resplandor suave: circulos concentricos muy transparentes.
func _brillo(c: Vector2, radio: float, col: Color) -> void:
	var n := 10
	for i in n:
		var r := radio * (1.0 - float(i) / n)
		draw_circle(c, r, Color(col.r, col.g, col.b, col.a / n * 1.6))
