extends Node2D
## Pantalla de titulo. Secuencia de revelado:
##  1. Negro. Aparecen a la vez, muy poco a poco, el titileo de las dos velas y el
##     vaho del cristal del ataud: seguimos dentro del sarcofago, y la imagen del
##     titulo tiene su propia ventana, asi que el humo se queda contenido ahi.
##  2. Se ilumina el foco superior.
##  3. La claridad del foco se derrama hacia abajo hasta llenar la sala, como un
##     degradado sin borde: los rincones de abajo son los ultimos en subir.
##  4. Un destello recorre las letras del titulo. Las velas siguen parpadeando y
##     queda un resto de vaho respirando dentro de la ventana.

@export var fog_delay: float = 0.5
@export var fog_time: float = 3.4
@export var candle_start: float = 1.0
@export var candle_time: float = 3.0
@export var sun_start: float = 4.6
@export var sun_time: float = 2.6
@export var reveal_start: float = 7.6
@export var reveal_time: float = 4.2
@export var glint_start: float = 12.2
@export var glint_time: float = 1.4
@export var zoom_start: float = 1.05
## Vaho que queda una vez revelada la imagen, para no lavar el titulo.
@export var fog_residue: float = 0.3

const CANDLE_A := Vector2(868, 830)
const CANDLE_B := Vector2(1852, 842)
const SUN := Vector2(1474, 0)
const IMAGE_SIZE := Vector2(2912, 1632)
## Panel interior del marco de la imagen: la ventana del ataud, medida sobre el PNG.
const WINDOW_RECT := Vector4(0.25, 0.288, 0.773, 0.699)

var _mat: ShaderMaterial
var _time_a := 0.0
var _time_b := 0.0
var _candle_on := 0.0   # 0..1, cuanto han encendido ya las velas
var _fog_level := 0.0   # 0..1, lo tensa el tween
var _breath := 0.0

@onready var _camera: Camera2D = $Camera

func _ready() -> void:
	_time_a = randf() * 100.0
	_time_b = randf() * 100.0 + 37.0

	# Capa 100: mascara de oscuridad + vaho, con el shader de revelado.
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var mask := ColorRect.new()
	mask.anchor_right = 1.0
	mask.anchor_bottom = 1.0
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://scripts/intro/title_reveal.gdshader")
	_mat.set_shader_parameter("aspect", IMAGE_SIZE.x / IMAGE_SIZE.y)
	_mat.set_shader_parameter("candle_a", CANDLE_A / IMAGE_SIZE)
	_mat.set_shader_parameter("candle_b", CANDLE_B / IMAGE_SIZE)
	_mat.set_shader_parameter("sun_pos", SUN / IMAGE_SIZE)
	_mat.set_shader_parameter("window_rect", WINDOW_RECT)
	_mat.set_shader_parameter("darkness", 1.0)
	_mat.set_shader_parameter("candle_radius", 0.0)
	_mat.set_shader_parameter("candle_glow", 0.0)
	_mat.set_shader_parameter("sun_radius", 0.0)
	_mat.set_shader_parameter("sun_intensity", 0.0)
	_mat.set_shader_parameter("reveal_reach", 0.0)
	_mat.set_shader_parameter("fog_amount", 0.0)
	_mat.set_shader_parameter("glint", -1.0)
	mask.material = _mat
	layer.add_child(mask)

	if _camera:
		_camera.zoom = Vector2.ONE * zoom_start

	_run_sequence()

func _run_sequence() -> void:
	# Un unico tween en paralelo; cada paso lleva su propio retardo.
	var tw := create_tween().set_parallel(true)

	# Vaho: entra en el negro y se queda en un resto cuando se ve la sala.
	tw.tween_method(_set_fog, 0.0, 1.0, fog_time).set_delay(fog_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_fog, 1.0, fog_residue, reveal_time).set_delay(reveal_start).set_trans(Tween.TRANS_SINE)

	# Velas
	tw.tween_method(_set_candle_on, 0.0, 1.0, candle_time).set_delay(candle_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Foco superior
	tw.tween_method(_set_shader.bind("sun_intensity"), 0.0, 1.0, sun_time).set_delay(sun_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_shader.bind("sun_radius"), 0.0, 0.42, sun_time).set_delay(sun_start).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Revelado: la claridad del foco baja hasta llenar la sala, sin frente visible.
	tw.tween_method(_set_shader.bind("reveal_reach"), 0.0, 2.2, reveal_time).set_delay(reveal_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Destello en las letras
	tw.tween_method(_set_shader.bind("glint"), -0.3, 1.3, glint_time).set_delay(glint_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Zoom lento hacia fuera durante toda la secuencia
	if _camera:
		tw.tween_property(_camera, "zoom", Vector2.ONE, reveal_start + reveal_time + 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_shader(value: float, param: String) -> void:
	_mat.set_shader_parameter(param, value)

func _set_candle_on(v: float) -> void:
	_candle_on = v
	_mat.set_shader_parameter("candle_radius", 0.15 * v)
	_mat.set_shader_parameter("candle_glow", v)

func _set_fog(v: float) -> void:
	_fog_level = v

func _process(delta: float) -> void:
	# Mismo parpadeo que flicker_glow.gd, una semilla distinta por vela.
	_time_a += delta * 2.5
	_time_b += delta * 2.5
	var fa := _flicker(_time_a)
	var fb := _flicker(_time_b)
	# Al encenderse tiemblan mas; una vez encendidas solo respiran.
	var unstable := 1.0 - _candle_on
	fa = lerpf(fa, 1.0, 0.35) - unstable * 0.25 * absf(sin(_time_a * 3.3))
	fb = lerpf(fb, 1.0, 0.35) - unstable * 0.25 * absf(sin(_time_b * 2.7))
	_mat.set_shader_parameter("candle_a_flicker", fa)
	_mat.set_shader_parameter("candle_b_flicker", fb)

	# El vaho respira despacio: sigue ahi dentro, aun respirando.
	_breath += delta
	var pulse := 0.78 + 0.22 * sin(_breath * 1.15)
	_mat.set_shader_parameter("fog_amount", _fog_level * pulse)

func _flicker(t: float) -> float:
	# 0.5 + 0.2 sin + 0.1 sin: rango 0.2..0.8, normalizado a ~0.25..1.0
	var e := 0.5 + sin(t * 1.2) * 0.2 + sin(t * 4.5) * 0.1
	return e / 0.8
