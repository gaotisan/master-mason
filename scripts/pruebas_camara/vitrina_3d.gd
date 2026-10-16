extends Node3D
## PRUEBA: el Magnus 3D (assets/pruebas_3d/magnus.glb, sacado de la hoja de
## giro con raw/master_mason/magnus3d) en una sala oscura con luz de luna y una
## vela, girando, y la camara cortando entre planos: frente, tres cuartos,
## picado, contrapicado y cenital. Es para juzgar el modelo con luz real.
## Teclas: espacio para/sigue el giro, flechas cambian de plano, M menu.

const MENU := "res://scenes/pruebas_camara/menu_pruebas_camara.tscn"

## Segundos por vuelta completa del modelo.
@export var vuelta: float = 12.0
## Segundos por plano antes de cortar al siguiente (0 = no cambia solo).
@export var por_plano: float = 4.0

## [posicion, mirar_a, fov]
var _planos := [
	[Vector3(0, 1.1, 3.2), Vector3(0, 1.0, 0), 40.0],      # frente
	[Vector3(2.3, 1.5, 2.3), Vector3(0, 1.0, 0), 38.0],    # tres cuartos
	[Vector3(1.2, 4.2, 2.6), Vector3(0, 0.7, 0), 45.0],    # picado
	[Vector3(-1.3, 0.25, 2.1), Vector3(0, 1.3, 0), 55.0],  # contrapicado
	[Vector3(0.6, 2.4, 1.2), Vector3(0, 1.5, 0), 50.0],    # cerca, a la capucha
]
var _plano := 0
var _t_plano := 0.0
var _girando := true

@onready var _modelo: Node3D = $Magnus
@onready var _camara: Camera3D = $Camara

func _ready() -> void:
	_poner_plano(0)

func _process(delta: float) -> void:
	if _girando:
		_modelo.rotate_y(TAU * delta / vuelta)
	if por_plano > 0.0:
		_t_plano += delta
		if _t_plano >= por_plano:
			_poner_plano((_plano + 1) % _planos.size())

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		match evento.keycode:
			KEY_M: get_tree().change_scene_to_file(MENU)
			KEY_SPACE: _girando = not _girando
			KEY_RIGHT: _poner_plano((_plano + 1) % _planos.size())
			KEY_LEFT: _poner_plano((_plano - 1 + _planos.size()) % _planos.size())

func _poner_plano(i: int) -> void:
	_plano = i
	_t_plano = 0.0
	var p: Array = _planos[i]
	_camara.fov = p[2]
	_camara.look_at_from_position(p[0], p[1])
