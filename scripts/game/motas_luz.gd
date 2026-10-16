extends Node2D
## Polvo y vilanos en el aire, encendidos por la luz.
##
## Motas pequenas a distintas distancias: las cercanas, mas grandes y mas
## rapidas (paralaje). Las lleva el viento de la escena (la brisa y la racha
## cuando les llega, via controlador.viento_en) con remolinos suaves y un pelin
## de ascenso. Solo se ven donde les da la luz y mas dentro de un haz (la
## mascara de aire de la escena: B luz, G haces con signo); titilan al girar y
## nacen y mueren con fundido, nunca de golpe. Unas pocas, muy cerca de la
## camara, estan desenfocadas (bokeh): discos grandes y casi transparentes.
## Suman luz (mezcla aditiva). Con la camara se desplazan segun lo cerca que
## estan (paralaje; controlador.camara).
##
## Siguen a la luz de la escena: cuando el sol se abre paso (controlador.claro)
## brillan mas y el aire se llena de polvo encendido (una de cada tres solo se
## ve entonces); con la respiracion de la luz suben y bajan. Una de cada doce
## da chispazos al girar (cara plana que pilla la luz de lleno).

const Imagenes := preload("res://scripts/game/imagenes_cache.gd")

## B luz, G haces con signo (0,5 = nada), a cualquier resolucion.
@export var mascara: Texture2D
@export var zona := Rect2(40, 20, 2832, 1592)
@export var cantidad := 260
@export var bokeh := 9
## Radio (px) de las motas, de la mas lejana a la mas cercana.
@export var radio := Vector2(1.2, 4.0)
@export var bokeh_radio := Vector2(12.0, 28.0)
@export var brillo := 1.0
@export var bokeh_brillo := 0.08
@export var color := Color(1.0, 0.86, 0.66)
## Cuanto mas brillan dentro de un haz.
@export var en_haz := 1.6
## Viento para las motas (px/s): brisa y racha a tope, en las mas lejanas.
@export var viento_brisa := 16.0
@export var viento_racha := 55.0
@export var remolino := 9.0

## La escena: viento_en(x) y brisa.
var controlador: Node

var _mascara: Image
var _escala := Vector2.ONE
var _tex: Texture2D
var _ruido := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _t := 0.0
# Por mota: posicion, velocidad, profundidad 0..1 (1 = cerca), radio, fase y
# frecuencia del titileo, edad y vida.
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _prof := PackedFloat32Array()
var _radio := PackedFloat32Array()
var _fase := PackedFloat32Array()
var _frec := PackedFloat32Array()
var _edad := PackedFloat32Array()
var _vida := PackedFloat32Array()

func _ready() -> void:
	_rng.randomize()
	_ruido.seed = _rng.randi()
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido.frequency = 1.0
	_mascara = Imagenes.de(mascara)
	_escala = Vector2(_mascara.get_width(), _mascara.get_height()) / Vector2(2912, 1632)
	_tex = _punto()
	var mezcla := CanvasItemMaterial.new()
	mezcla.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mezcla
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var total := cantidad + bokeh
	# Los Packed*Array se copian al meterlos en otra lista: uno a uno.
	_pos.resize(total)
	_vel.resize(total)
	_prof.resize(total)
	_radio.resize(total)
	_fase.resize(total)
	_frec.resize(total)
	_edad.resize(total)
	_vida.resize(total)
	for i in total:
		_nacer(i)
		# Al empezar, ya repartidas en su vida.
		_edad[i] = _rng.randf() * _vida[i]

## Disco blando: centro con algo de cuerpo y borde que se pierde.
func _punto() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t

func _nacer(i: int) -> void:
	var es_bokeh := i >= cantidad
	# Mas donde da la luz, que es donde se ven (y algunas en la sombra).
	for _intento in 8:
		_pos[i] = Vector2(_rng.randf_range(zona.position.x, zona.end.x), _rng.randf_range(zona.position.y, zona.end.y))
		if _rng.randf() < 0.2 + 0.8 * _luz(_pos[i]).x:
			break
	_vel[i] = Vector2.ZERO
	_prof[i] = 1.0 if es_bokeh else pow(_rng.randf(), 1.6)
	if es_bokeh:
		_radio[i] = _rng.randf_range(bokeh_radio.x, bokeh_radio.y)
	else:
		_radio[i] = lerpf(radio.x, radio.y, _prof[i]) * _rng.randf_range(0.8, 1.2)
	_fase[i] = _rng.randf() * TAU
	_frec[i] = _rng.randf_range(0.6, 2.4)
	_edad[i] = 0.0
	_vida[i] = _rng.randf_range(8.0, 20.0)

## (luz 0..1, haz -1..1) en un punto de la pantalla.
func _luz(p: Vector2) -> Vector2:
	var x := clampi(int(p.x * _escala.x), 0, _mascara.get_width() - 1)
	var y := clampi(int(p.y * _escala.y), 0, _mascara.get_height() - 1)
	var c := _mascara.get_pixel(x, y)
	return Vector2(c.b, (c.g - 0.5) * 2.0)

func _process(delta: float) -> void:
	_t += delta
	var brisa: float = controlador.brisa if controlador else 0.4
	for i in _pos.size():
		_edad[i] += delta
		if _edad[i] > _vida[i] or not zona.grow(60.0).has_point(_pos[i]):
			_nacer(i)
		var p := _pos[i]
		var racha: float = controlador.viento_en(p.x) if controlador else 0.0
		# Lo cercano cruza la pantalla mas deprisa.
		var k := 0.45 + 1.4 * _prof[i]
		var a := _ruido.get_noise_3d(p.x * 0.003, p.y * 0.003, _t * 0.12) * TAU * 1.5
		var objetivo := Vector2(viento_brisa * brisa + viento_racha * racha, -3.0) * k
		objetivo += Vector2(cos(a), sin(a)) * remolino * k
		_vel[i] = _vel[i].lerp(objetivo, 1.0 - exp(-delta * 0.8))
		_pos[i] = p + _vel[i] * delta
	queue_redraw()

func _draw() -> void:
	var claro: float = controlador.claro if controlador else 0.0
	var luz: float = controlador.luz if controlador else 0.0
	var realce := 1.0 + 1.3 * claro + 0.25 * luz
	for i in _pos.size():
		var p := _pos[i]
		if controlador:
			p += controlador.paralaje(p, _prof[i])
		var li := _luz(p)
		var vida := smoothstep(0.0, 2.0, _edad[i]) * (1.0 - smoothstep(_vida[i] - 2.5, _vida[i], _edad[i]))
		var a: float
		if i >= cantidad:
			a = bokeh_brillo * (0.3 + 0.7 * li.x)
		else:
			# Titileo: la mota gira y coge o pierde la luz.
			var tit := 0.5 + 0.5 * sin(_fase[i] + _t * _frec[i])
			a = brillo * (0.06 + 0.94 * li.x * li.x) * (0.25 + 0.75 * tit * tit) * (0.5 + 0.5 * _prof[i])
			a *= 1.0 + en_haz * maxf(li.y, 0.0) * (1.0 + claro)
			if i % 12 == 0:
				a *= 0.4 + 2.6 * pow(tit, 8.0)
			if i % 3 == 0:
				a *= claro
		a *= vida * realce
		if a < 0.004:
			continue
		var r := _radio[i]
		draw_texture_rect(_tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(color, minf(a, 1.0)))
