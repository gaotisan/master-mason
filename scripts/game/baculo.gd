extends Node2D
## El baculo del peregrino, que baja del cielo por el haz y se queda flotando.
## Dentro de la luz las cosas pesan poco: no cae, desciende como una pluma,
## meciendose de lado y enderezandose, y al llegar a su altura se queda
## suspendido con un vaiven lento. No es Magnus flotando como en el espacio:
## es un objeto ligero que el aire sostiene.
##
## Es el mismo baston que Magnus llevara a la espalda: se instancia su escena
## (scenes/dev/baston.tscn: madera, bola, halo y chispas) sin su script, que
## lo ata al Sprite de Magnus. Asi el aspecto sale de un solo sitio. Mientras
## flota, la bola esta apagada; encender() la enciende (la bola roja al cogerlo).
##
## Lo ilumina la misma luz que a Magnus (magnus_luz.gdshader).
##
##   bajar()          aparece arriba del todo y desciende; emite `posado`.
##   encender(color)  enciende la bola poco a poco.

signal posado

const BASTON := preload("res://scenes/dev/baston.tscn")
const MOTA := preload("res://assets/world/hojarasca/mota.png")

## Eje del haz (el de fondo_haz): de su vertice al suelo donde cae Magnus.
const HAZ_ORIGEN := Vector2(1620.0, -700.0)
const HAZ_DESTINO := Vector2(1456.0, 1200.0)

## Altura (y del centro) a la que se queda flotando, y cuanto tarda en bajar.
@export var y_flotar: float = 470.0
## 6,5 s: el pensamiento del asombro ("Algo baja por la luz… despacio, como si
## no pesara") tiene que leerse mientras aun baja, no cuando ya flota.
@export var bajada: float = 6.5
## Vaiven al bajar: lo que se mece a cada lado al principio (px y rad) y cada
## cuanto (s); se va apagando hasta quedarse casi recto.
@export var meceo_px: float = 70.0
@export var meceo_rad: float = 0.32
@export var meceo_periodo: float = 4.2
## Flotando: arriba y abajo (px) y cada cuanto (s), y una inclinacion leve.
@export var flota_px: float = 10.0
@export var flota_periodo: float = 3.8
@export var inclinacion: float = 0.07
## Lo que tarda la bola en encenderse del todo (s).
@export var encendido: float = 1.6

var _pivote: Node2D
var _baston: Node2D
var _orbe: Sprite2D
var _luz_orbe: Sprite2D
var _halo: Sprite2D
var _t := 0.0
var _estado := 0          # 0 oculto, 1 bajando, 2 flotando
var _y := 0.0             # altura sin el vaiven

func _ready() -> void:
	_halo = Sprite2D.new()
	_halo.texture = MOTA
	_halo.modulate = Color(1.0, 0.78, 0.45, 0.0)
	var suma := CanvasItemMaterial.new()
	suma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_halo.material = suma
	_halo.scale = Vector2(4.0, 4.0)
	add_child(_halo)
	_pivote = Node2D.new()
	add_child(_pivote)
	_baston = BASTON.instantiate()
	_baston.set_script(null)   # sin el seguimiento de la espalda
	_baston.z_index = 0
	_pivote.add_child(_baston)
	var madera: Sprite2D = _baston.get_node("Madera")
	# La madera cuelga de su origen (su offset): se sube eso para que el baston
	# gire y se meza por su centro. Se lee de la escena del baston, que cambia.
	_baston.position = Vector2(0.0, -madera.offset.y)
	madera.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var luz := ShaderMaterial.new()
	luz.shader = preload("res://scripts/game/magnus_luz.gdshader")
	# No esta en el suelo: sin rebote de las hojas ni oclusion de pies. Borde de
	# luz fino: con el de Magnus (3 px) las puntas de la garra se encendian
	# enteras y, al girar, parpadeaban como puntitos.
	luz.set_shader_parameter(&"rebote_fuerza", 0.0)
	luz.set_shader_parameter(&"oclusion", 0.0)
	luz.set_shader_parameter(&"borde_px", 1.0)
	luz.set_shader_parameter(&"borde_fuerza", 0.3)
	madera.material = luz
	# La bola, apagada. Sus materiales se copian: los de la escena del baston
	# son compartidos y no hay que tocar el que lleve Magnus a la espalda.
	_orbe = madera.get_node("Orbe")
	_luz_orbe = madera.get_node("Luz")
	for s in [_orbe, _luz_orbe]:
		s.material = s.material.duplicate()
		(s.material as ShaderMaterial).set_shader_parameter("carga", 0.0)
		s.visible = false
	for nombre in ["Recarga", "Estallido", "Chispas"]:
		(madera.get_node(nombre) as CPUParticles2D).emitting = false
	visible = false

## x del eje del haz a una altura y.
static func x_haz(y: float) -> float:
	var t := (y - HAZ_ORIGEN.y) / (HAZ_DESTINO.y - HAZ_ORIGEN.y)
	return lerpf(HAZ_ORIGEN.x, HAZ_DESTINO.x, t)

## Donde esta la bola (en la garra), en coordenadas de la escena.
func punta() -> Vector2:
	return _orbe.global_position

func flotando() -> bool:
	return _estado == 2

func bajar() -> void:
	visible = true
	_estado = 1
	_t = 0.0
	_y = -300.0
	var tw := create_tween()
	tw.tween_property(self, "_y", y_flotar, bajada).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_halo, "modulate:a", 0.3, bajada * 0.6)
	tw.tween_callback(func() -> void:
		_estado = 2
		_t = 0.0
		posado.emit())

## Enciende la bola del color dado, de apagada a llena, con su estallido.
func encender(color: Color) -> void:
	var v := Vector3(color.r, color.g, color.b)
	for s in [_orbe, _luz_orbe]:
		s.visible = true
		var m := s.material as ShaderMaterial
		m.set_shader_parameter("color", v)
		create_tween().tween_method(func(c: float) -> void: m.set_shader_parameter("carga", c),
			0.0, 1.0, encendido).set_trans(Tween.TRANS_SINE)
	var madera: Node = _baston.get_node("Madera")
	for nombre in ["Estallido", "Chispas"]:
		var p := madera.get_node(nombre) as CPUParticles2D
		p.color = color.lightened(0.25)
	(madera.get_node("Estallido") as CPUParticles2D).restart()
	(madera.get_node("Chispas") as CPUParticles2D).emitting = true

func _process(delta: float) -> void:
	if _estado == 0:
		return
	_t += delta
	var x_off := 0.0
	var rot := 0.0
	var y := _y
	if _estado == 1:
		# Se mece de lado como una pluma; el vaiven se apaga al acercarse.
		var queda := clampf(1.0 - _t / bajada, 0.0, 1.0)
		var w := TAU / meceo_periodo
		x_off = meceo_px * queda * sin(w * _t)
		rot = meceo_rad * queda * cos(w * _t) + inclinacion
	else:
		y += flota_px * sin(TAU * _t / flota_periodo)
		rot = inclinacion + 0.025 * sin(TAU * _t / (flota_periodo * 1.7))
	position = Vector2(x_haz(y) + x_off, y)
	_pivote.rotation = rot
	# El halo, en la garra.
	_halo.position = _orbe.global_position - global_position
	if _estado == 2:
		_halo.modulate.a = 0.26 + 0.05 * sin(TAU * _t / 2.9)
