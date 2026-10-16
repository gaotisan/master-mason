extends Node2D
## Una capa del plano lateral del storyboard (bosque en niebla, con la paleta
## del mirador). Se dibuja en coordenadas del mundo, suelo en y = 1200; la
## perspectiva la pone storyboard.gd segun la profundidad. Dibujo de relleno.

enum Tipo { CIELO, CASTILLOS, ARBOLES, SUELO, PRIMER_PLANO }

@export var profundidad: float = 0.0
@export var tipo: Tipo = Tipo.SUELO
@export var color: Color = Color(0.2, 0.16, 0.15)
@export var semilla: int = 1

const SUELO_Y := 1200.0
const DESDE := -6000.0
const HASTA := 12000.0
const NIEBLA := Color(0.82, 0.66, 0.47)

var _rng := RandomNumberGenerator.new()

func _draw() -> void:
	_rng.seed = semilla
	match tipo:
		Tipo.CIELO: _cielo()
		Tipo.CASTILLOS: _castillos()
		Tipo.ARBOLES: _arboles(9, 1.0)
		Tipo.SUELO: _suelo()
		Tipo.PRIMER_PLANO: _primer_plano()

func _cielo() -> void:
	# Degradado de arriba (oscuro, malva) al horizonte (niebla dorada).
	var arriba := Color(0.33, 0.25, 0.25)
	draw_rect(Rect2(-600000.0, -60000.0, 1200000.0, 46000.0), arriba)
	var n := 48
	for i in n:
		var t := float(i) / n
		var y0 := lerpf(-14000.0, SUELO_Y + 200, t)
		var y1 := lerpf(-14000.0, SUELO_Y + 200, float(i + 1) / n)
		draw_rect(Rect2(-600000.0, y0, 1200000.0, y1 - y0 + 2), arriba.lerp(NIEBLA, pow(t, 0.7)))
	draw_rect(Rect2(-600000.0, SUELO_Y + 200, 1200000.0, 6000), NIEBLA.darkened(0.15))
	_brillo(Vector2(2600, -900), 2600.0, Color(1.0, 0.82, 0.55, 0.5))
	draw_circle(Vector2(2600, -900), 160.0, Color(1.0, 0.9, 0.7, 0.9))

func _castillos() -> void:
	var x := DESDE
	while x < HASTA:
		if _rng.randf() < 0.5:
			_castillo(x, _rng.randf_range(1.0, 1.8))
		x += _rng.randf_range(3000.0, 5000.0)
	draw_rect(Rect2(DESDE, SUELO_Y, HASTA - DESDE, 4000), color)

func _castillo(x: float, e: float) -> void:
	var base := SUELO_Y
	draw_rect(Rect2(x, base - 900 * e, 1400 * e, 900 * e), color)
	for i in 5:
		var tx := x + _rng.randf_range(0, 1300) * e
		var alto := _rng.randf_range(600, 1700) * e
		var ancho := _rng.randf_range(120, 260) * e
		draw_rect(Rect2(tx, base - alto, ancho, alto), color)
		draw_colored_polygon(PackedVector2Array([Vector2(tx - 30 * e, base - alto), Vector2(tx + ancho + 30 * e, base - alto),
			Vector2(tx + ancho * 0.5, base - alto - ancho * 1.8)]), color)

func _arboles(nivel: int, escala: float) -> void:
	var x := DESDE
	while x < HASTA:
		if _rng.randf() < 0.25:
			_pino(Vector2(x, SUELO_Y), _rng.randf_range(1400, 2200) * escala)
		else:
			_arbol(Vector2(x, SUELO_Y), _rng.randf_range(900, 1500) * escala, nivel)
		x += _rng.randf_range(500.0, 1100.0)
	draw_rect(Rect2(DESDE, SUELO_Y, HASTA - DESDE, 4000), color)

func _suelo() -> void:
	# Arboles sueltos en el plano de Magnus, por detras de el.
	var x := DESDE
	while x < HASTA:
		_arbol(Vector2(x, SUELO_Y + 10), _rng.randf_range(1300, 1900), 9)
		x += _rng.randf_range(1400.0, 2600.0)
	# Tierra con hierba seca y camino de piedra.
	draw_rect(Rect2(DESDE, SUELO_Y, HASTA - DESDE, 1400), color)
	draw_rect(Rect2(DESDE, SUELO_Y - 4, HASTA - DESDE, 30), color.lightened(0.12))
	x = DESDE
	while x < HASTA:
		var h := _rng.randf_range(20, 70)
		draw_line(Vector2(x, SUELO_Y + 4), Vector2(x + _rng.randf_range(-15, 15), SUELO_Y - h),
			Color(0.45, 0.33, 0.22).lerp(color, _rng.randf()), 3.0)
		x += _rng.randf_range(10, 40)

func _primer_plano() -> void:
	var x := DESDE
	while x < HASTA:
		var r := _rng.randf()
		if r < 0.35:
			# Tronco cercano, casi negro, que cruza la pantalla.
			var ancho := _rng.randf_range(160, 300)
			draw_rect(Rect2(x, SUELO_Y - 4000, ancho, 5000), color)
			for i in 4:
				var y := SUELO_Y - _rng.randf_range(600, 3200)
				_rama(Vector2(x + ancho * 0.5, y), deg_to_rad(_rng.randf_range(-170, -10)), _rng.randf_range(400, 900), 40.0, 5)
		else:
			# Matorral y hojas por abajo.
			for i in 30:
				var bx := x + _rng.randf_range(0, 900)
				draw_line(Vector2(bx, SUELO_Y + 300), Vector2(bx + _rng.randf_range(-60, 60), SUELO_Y + 300 - _rng.randf_range(80, 300)), color, 8.0)
		x += _rng.randf_range(1400.0, 2800.0)

func _arbol(pie: Vector2, alto: float, nivel: int) -> void:
	var ancho := alto * 0.06
	draw_colored_polygon(PackedVector2Array([pie + Vector2(-ancho, 0), pie + Vector2(ancho, 0),
		pie + Vector2(ancho * 0.4, -alto * 0.55), pie + Vector2(-ancho * 0.4, -alto * 0.55)]), color)
	var copa := pie + Vector2(0, -alto * 0.55)
	for i in 3:
		_rama(copa, deg_to_rad(-90 + _rng.randf_range(-40, 40)), alto * 0.32, ancho * 0.7, nivel - 3)

func _rama(desde: Vector2, ang: float, largo: float, grosor: float, nivel: int) -> void:
	var hasta := desde + Vector2(cos(ang), sin(ang)) * largo
	draw_line(desde, hasta, color, maxf(grosor, 1.5))
	if nivel <= 0:
		return
	for i in _rng.randi_range(2, 3):
		_rama(hasta, ang + _rng.randf_range(-0.7, 0.7), largo * _rng.randf_range(0.6, 0.8), grosor * 0.62, nivel - 1)

func _pino(pie: Vector2, alto: float) -> void:
	draw_rect(Rect2(pie.x - alto * 0.015, pie.y - alto * 0.2, alto * 0.03, alto * 0.2), color)
	for i in 9:
		var t := float(i) / 9.0
		var y := pie.y - alto * (0.12 + t * 0.85)
		var w := alto * 0.22 * (1.0 - t * 0.9)
		draw_colored_polygon(PackedVector2Array([Vector2(pie.x - w, y + alto * 0.12), Vector2(pie.x + w, y + alto * 0.12),
			Vector2(pie.x, y - alto * 0.05)]), color)

func _brillo(c: Vector2, radio: float, col: Color) -> void:
	for i in 12:
		draw_circle(c, radio * (1.0 - float(i) / 12), Color(col.r, col.g, col.b, col.a / 12 * 1.5))
