extends Node2D

# === CONFIGURACIÓN DE ZONA ===
@export_group("Zone Settings")
@export var zone_radius: float = 150.0
@export var depth: float = 1.0
@export var num_flies: int = 5
@export var enabled: bool = true

@export_group("Fly Appearance")
@export var base_fly_size: float = 3.0
# Ahora puedes cambiar este color por cada instancia en el editor
@export var fly_color: Color = Color(0.12, 0.12, 0.12, 1.0) 
@export var wing_color: Color = Color(0.4, 0.4, 0.45, 0.35)

@export_group("Fly Behavior")
@export var flight_speed: float = 100.0
@export var land_chance: float = 0.012
@export var takeoff_chance: float = 0.3
@export var walk_speed: float = 25.0

# === ESTADO INTERNO ===
var flies: Array = []
var noise = FastNoiseLite.new()
var time_passed: float = 0.0

enum FlyState { FLYING, LANDING, LANDED, WALKING, TAKING_OFF }

func _ready() -> void:
	noise.seed = randi()
	noise.frequency = 2.5
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_spawn_flies()

func _spawn_flies() -> void:
	flies.clear()
	for i in range(num_flies):
		var angle = randf() * TAU
		var dist = randf() * zone_radius * 0.5
		var fly = {
			"pos": Vector2(cos(angle), sin(angle)) * dist,
			"state": FlyState.FLYING,
			"state_timer": randf_range(0.5, 2.0),
			"wing_phase": randf() * TAU,
			"noise_offset": randf() * 100.0,
			"z_height": randf_range(8.0, 15.0),
			"circle_center": Vector2.ZERO,
			"circle_radius": randf_range(20.0, 60.0),
			"circle_angle": randf() * TAU,
			"circle_speed": randf_range(4.0, 8.0) * (1.0 if randf() > 0.5 else -1.0),
			"circle_wobble": randf() * 100.0,
			"walk_dir": Vector2.ZERO,
			"walk_timer": 0.0,
			"facing": 0.0,
			"land_pos": Vector2.ZERO
		}
		fly["circle_center"] = fly["pos"]
		flies.append(fly)

func _process(delta: float) -> void:
	if not enabled: return
	time_passed += delta
	for fly in flies:
		_update_fly(fly, delta)
	queue_redraw()

func _update_fly(fly: Dictionary, delta: float) -> void:
	fly["wing_phase"] += delta * 90.0
	fly["state_timer"] -= delta
	
	match fly["state"]:
		FlyState.FLYING:
			_update_flying(fly, delta)
			if randf() < land_chance: _start_landing(fly)
		FlyState.LANDING:
			_update_landing(fly, delta)
		FlyState.LANDED:
			_update_landed(fly, delta)
		FlyState.WALKING:
			_update_walking(fly, delta)
		FlyState.TAKING_OFF:
			_update_takeoff(fly, delta)

func _update_flying(fly: Dictionary, delta: float) -> void:
	var t = time_passed + fly["noise_offset"]
	fly["circle_angle"] += fly["circle_speed"] * delta
	var current_radius = fly["circle_radius"] * (1.0 + noise.get_noise_1d(t * 2.0) * 0.4)
	var target_pos = fly["circle_center"] + Vector2(cos(fly["circle_angle"]), sin(fly["circle_angle"]) * 0.6) * current_radius
	fly["pos"] = fly["pos"].lerp(target_pos, delta * 10.0)
	fly["z_height"] = lerp(fly["z_height"], 10.0 + noise.get_noise_1d(t * 2.0) * 5.0, delta * 3.0)

func _start_landing(fly: Dictionary) -> void:
	fly["state"] = FlyState.LANDING
	fly["land_pos"] = Vector2(randf_range(-zone_radius * 0.8, zone_radius * 0.8), randf_range(zone_radius * 0.4, zone_radius * 0.9))

func _update_landing(fly: Dictionary, delta: float) -> void:
	fly["pos"] = fly["pos"].lerp(fly["land_pos"], delta * 7.0)
	fly["z_height"] = move_toward(fly["z_height"], 0.0, delta * 45.0)
	if fly["z_height"] <= 0.1:
		_land(fly)

func _land(fly: Dictionary) -> void:
	fly["state"] = FlyState.LANDED
	fly["z_height"] = 0.0
	fly["state_timer"] = randf_range(0.8, 3.0)

func _update_landed(fly: Dictionary, delta: float) -> void:
	if fly["state_timer"] > 0:
		return
	if randf() < takeoff_chance:
		fly["state"] = FlyState.TAKING_OFF
		fly["circle_center"] = fly["pos"]
	else:
		fly["state"] = FlyState.WALKING
		fly["walk_dir"] = Vector2.from_angle(randf() * TAU)
		fly["walk_timer"] = randf_range(0.4, 1.5)
		fly["facing"] = fly["walk_dir"].angle()

func _update_walking(fly: Dictionary, delta: float) -> void:
	fly["walk_timer"] -= delta
	fly["pos"] += fly["walk_dir"] * walk_speed * delta
	# Que no se salga de la zona: si toca el borde, da la vuelta.
	if fly["pos"].length() > zone_radius:
		fly["pos"] = fly["pos"].normalized() * zone_radius
		fly["walk_dir"] = -fly["walk_dir"]
	if fly["walk_timer"] <= 0:
		_land(fly)

func _update_takeoff(fly: Dictionary, delta: float) -> void:
	fly["z_height"] = move_toward(fly["z_height"], 10.0, delta * 50.0)
	if fly["z_height"] >= 9.0: fly["state"] = FlyState.FLYING

func _draw() -> void:
	if not enabled: return
	for fly in flies:
		var pos = fly["pos"]
		var size = base_fly_size * lerp(0.6, 1.0, depth)
		
		# Sombra suave
		if fly["z_height"] > 0.2:
			draw_circle(pos + Vector2(fly["z_height"]*0.2, fly["z_height"]*0.3), size * 0.4, Color(0, 0, 0, 0.15))
		
		var draw_pos = pos - Vector2(0, fly["z_height"])
		# Cuerpo con el color modular configurado
		draw_circle(draw_pos, size * 0.5, fly_color)
		
		# Alas
		if fly["state"] in [FlyState.FLYING, FlyState.TAKING_OFF, FlyState.LANDING]:
			var flap = sin(fly["wing_phase"]) * size * 0.8
			draw_line(draw_pos, draw_pos + Vector2(-size, flap), wing_color, 1.0)
			draw_line(draw_pos, draw_pos + Vector2(size, flap), wing_color, 1.0)
