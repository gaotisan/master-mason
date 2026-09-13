extends Node2D

signal spotted
signal died

@onready var ant_l: Sprite2D = $AntennaL
@onready var ant_r: Sprite2D = $AntennaR
@onready var step_sound: AudioStreamPlayer2D = $StepSound
@onready var body: Sprite2D = $Body
@onready var shadow: Sprite2D = $Shadow
@onready var rim_light: Sprite2D = $RimLight

var squash_audio = preload("res://assets/audio/slime-splatter.ogg")
var spore_scene = preload("res://scenes/intro/spore_cloud.tscn")

@onready var femurs: Array = [
	$LegFrontL/Femur, $LegMidR/Femur, $LegHindL/Femur,
	$LegFrontR/Femur, $LegMidL/Femur, $LegHindR/Femur
]

var tibias: Dictionary = {}

enum State { IDLE, ROTATING, WALKING, PAUSED }
var current_state: State = State.IDLE
var state_timer: float = 0.0
var is_dead := false

var is_scared := false
var has_been_scared_once := false
var last_impact_pos := Vector2.ZERO
var is_investigating := false
var arrived_at_impact := false
var corner_cooldown := false

@export_group("Atmosphere & Polygon")
@export var debug_show_polygon: bool = false
@export var light_polygon: PackedVector2Array = [
	Vector2(650, 80), Vector2(2360, 80), Vector2(2680, 450),
	Vector2(2680, 1130), Vector2(2360, 1500), Vector2(650, 1500),
	Vector2(250, 1130), Vector2(250, 450)
]
@export var fade_margin: float = 60.0
@export var color_center: Color = Color(0.38, 0.38, 0.42)
@export var color_center_warmth: Color = Color(1.4, 1.25, 0.8)
@export var color_edge_fog: Color = Color(0.25, 0.28, 0.35)
@export var min_alpha_fog: float = 0.65

var target_position: Vector2
var target_rotation: float = 0.0
var move_speed: float = 0.0
var noise := FastNoiseLite.new()
var time_passed: float = 0.0

@export_group("Organic Timing")
@export var idle_time_min: float = 3.0
@export var idle_time_max: float = 8.0
@export var bounds_min: Vector2 = Vector2(150, 150)
@export var bounds_max: Vector2 = Vector2(2760, 1480)
@export var failsafe_point: Vector2 = Vector2(1456, 816)

@export_group("Locomotion")
## Velocidad de giro en rad/s. Con el valor antiguo (26) el giro duraba 1-2 frames y parecia un salto.
@export var turn_speed: float = 9.0
## Angulo restante (rad) por debajo del cual arranca a andar mientras termina de girar: la salida es un arco.
@export var start_walk_angle: float = 1.0
## Segundos para pasar de parada a velocidad plena.
@export var accel_time: float = 0.12
## Frena en los ultimos px antes del objetivo sin bajar de esta fraccion de la velocidad.
@export var brake_distance: float = 120.0
@export var brake_min_factor: float = 0.35
## Ruido de rumbo durante la carrera (rad) para que la recta no sea de laser.
@export var heading_noise: float = 0.12

@export_group("Leg Animation")
## Los sprites de las patas pivotan en cadera y rodilla (offset en cockroach.tscn),
## asi que las amplitudes pueden ser mayores sin que las piezas se separen.
@export var femur_swing_amount: float = 0.30
@export var tibia_flex_amount: float = 0.19
@export var front_leg_swing_mult: float = 0.85
@export var hind_leg_swing_mult: float = 1.15
@export var leg_speed: float = 22.0
@export var idle_jitter: float = 0.02
@export var walk_jitter: float = 0.02

var femur_rest: Dictionary = {}
var tibia_rest: Dictionary = {}
var leg_offsets: Array = []
var leg_side: Dictionary = {}
var leg_amp: Dictionary = {}
var speed_factor: float = 0.0
var walk_weight: float = 0.0
var offset_ant_l: float
var offset_ant_r: float
var is_inside: bool = false
var was_walking: bool = false

func _ready() -> void:
	add_to_group("squashable")
	_disable_2d_lights(self)
	noise.seed = randi()
	noise.frequency = 0.4
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	offset_ant_l = ant_l.rotation
	offset_ant_r = ant_r.rotation

	for f in femurs:
		if f:
			femur_rest[f] = f.rotation
			leg_offsets.append(randf_range(0.0, 100.0))
			# Una rotacion positiva adelanta una pata izquierda y atrasa una derecha:
			# el lado invierte el signo para que el tripode alterno sea real.
			var leg_name: String = f.get_parent().name
			leg_side[f] = -1.0 if leg_name.ends_with("R") else 1.0
			if leg_name.begins_with("LegFront"):
				leg_amp[f] = front_leg_swing_mult
			elif leg_name.begins_with("LegHind"):
				leg_amp[f] = hind_leg_swing_mult
			else:
				leg_amp[f] = 1.0
			var t = f.get_node_or_null("Tibia")
			if t:
				tibias[f] = t
				tibia_rest[t] = t.rotation

	target_position = failsafe_point
	_enter_state(State.IDLE)

## La cucaracha simula su propia iluminacion con light_polygon; las luces 2D
## de las velas no le aportan nada y cuestan un pase por sprite.
func _disable_2d_lights(node: Node) -> void:
	if node is CanvasItem:
		node.light_mask = 0
	for c in node.get_children():
		_disable_2d_lights(c)

func _process(delta: float) -> void:
	if is_dead:
		return
	time_passed += delta
	state_timer -= delta

	match current_state:
		State.IDLE, State.PAUSED:
			walk_weight = move_toward(walk_weight, 0.0, delta * 7.0)
			if state_timer <= 0:
				_enter_state(State.ROTATING)
		State.ROTATING:
			walk_weight = move_toward(walk_weight, 0.0, delta * 8.0)
			_process_rotating_logic(delta)
		State.WALKING:
			walk_weight = move_toward(walk_weight, 1.0, delta * 5.0)
			_process_movement_logic(delta)
			if state_timer <= 0:
				_enter_state(State.PAUSED)

	_update_step_sound()
	_update_all_legs_animation(delta)
	_process_antennae(delta)
	_update_visibility_logic()

func _update_step_sound() -> void:
	var is_walking = current_state == State.WALKING and walk_weight > 0.3
	if is_walking and not was_walking:
		step_sound.play()
	elif not is_walking and was_walking:
		step_sound.stop()
	was_walking = is_walking

func _update_visibility_logic() -> void:
	var pos = global_position
	is_inside = Geometry2D.is_point_in_polygon(pos, light_polygon)
	var factor = 1.0 if is_inside else 0.0
	if not is_inside:
		var min_dist = 99999.0
		for i in range(light_polygon.size()):
			var p1 = light_polygon[i]
			var p2 = light_polygon[(i + 1) % light_polygon.size()]
			var closest = Geometry2D.get_closest_point_to_segment(pos, p1, p2)
			var d = pos.distance_to(closest)
			if d < min_dist:
				min_dist = d
		factor = 1.0 - clamp(min_dist / fade_margin, 0.0, 1.0)
	var smooth_factor = smoothstep(0.0, 1.0, factor)
	modulate = color_edge_fog.lerp(color_center * color_center_warmth, smooth_factor)
	modulate.a = lerp(min_alpha_fog, 1.0, smooth_factor)

## Gira en el sitio solo lo justo; el resto del giro lo termina ya en marcha.
func _process_rotating_logic(delta: float) -> void:
	var speed_mod = 1.6 if is_scared else 1.0
	rotation = rotate_toward(rotation, target_rotation, turn_speed * speed_mod * delta)
	if abs(angle_difference(rotation, target_rotation)) < start_walk_angle:
		_enter_state(State.WALKING)

## Avanza en la direccion en la que mira mientras sigue corrigiendo el rumbo hacia el
## objetivo: la salida es un arco, no un giro seco y una recta. Rampa de arranque,
## frenada al llegar y un poco de ruido de rumbo. Nunca se pasa del objetivo.
func _process_movement_logic(delta: float) -> void:
	var to_target = target_position - global_position
	var dist = to_target.length()
	if dist < 0.001:
		_arrive()
		return
	var speed_mod = 1.6 if is_scared else 1.0
	var wander = noise.get_noise_1d(time_passed * 3.0 + 300.0) * heading_noise * clamp(dist / 200.0, 0.0, 1.0)
	var desired = to_target.angle() + PI / 2 + wander
	rotation = rotate_toward(rotation, desired, turn_speed * speed_mod * delta)
	speed_factor = move_toward(speed_factor, 1.0, delta / accel_time)
	var brake = clamp(dist / brake_distance, brake_min_factor, 1.0)
	var forward = Vector2.UP.rotated(rotation)
	var step = min(move_speed * speed_factor * brake * delta, dist)
	global_position += forward * step
	var remaining = target_position - global_position
	if remaining.length() < 8.0 or forward.dot(remaining) <= 0.0:
		if remaining.length() < 40.0:
			global_position = target_position
		_arrive()

func _arrive() -> void:
	if is_investigating and global_position.distance_to(last_impact_pos) < 30:
		arrived_at_impact = true
		global_position = last_impact_pos
	if is_scared:
		corner_cooldown = true
	_enter_state(State.PAUSED)

func _update_all_legs_animation(delta: float) -> void:
	var anim_speed = leg_speed * (1.8 if is_scared else 1.0)
	for i in range(femurs.size()):
		var f = femurs[i]
		if not f:
			continue
		var current_jitter = lerp(idle_jitter, walk_jitter, walk_weight)
		var jitter = noise.get_noise_1d((time_passed + leg_offsets[i]) * 25.0) * current_jitter
		# Tripode alterno: [FrontL, MidR, HindL] en fase 0 y [FrontR, MidL, HindR] en fase PI.
		var base_phase = 0.0 if i < 3 else PI
		var cycle = time_passed * anim_speed + base_phase
		var wave = sin(cycle)
		var side: float = leg_side.get(f, 1.0)
		var amp: float = leg_amp.get(f, 1.0)
		f.rotation = femur_rest[f] + side * wave * femur_swing_amount * amp * walk_weight + jitter
		if tibias.has(f):
			var t = tibias[f]
			t.rotation = tibia_rest[t] + side * sin(cycle - 0.4) * tibia_flex_amount * amp * walk_weight + jitter * 0.5

func _process_antennae(delta: float) -> void:
	var m = 1.0 + walk_weight * (2.8 if is_scared else 1.2)
	var n_l = noise.get_noise_1d(time_passed * 1.6 * m)
	var n_r = noise.get_noise_1d((time_passed + 45.0) * 1.6 * m)
	ant_l.rotation = lerp_angle(ant_l.rotation, offset_ant_l + n_l * 0.7, delta * 14.0)
	ant_r.rotation = lerp_angle(ant_r.rotation, offset_ant_r + n_r * 0.7, delta * 14.0)

func _enter_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.IDLE:
			state_timer = randf_range(idle_time_min, idle_time_max)
		State.ROTATING:
			_pick_new_target()
			var base_speed = randf_range(950, 1150)
			move_speed = base_speed * (1.9 if is_scared else 1.0)
			target_rotation = (target_position - global_position).angle() + PI / 2
		State.WALKING:
			speed_factor = 0.0
			state_timer = randf_range(0.4, 0.7) if is_investigating else (randf_range(0.8, 1.4) if is_scared else randf_range(0.5, 1.0))
		State.PAUSED:
			if corner_cooldown:
				state_timer = randf_range(4.0, 7.0)
				corner_cooldown = false
			elif arrived_at_impact:
				state_timer = randf_range(3.0, 6.0)
			elif is_investigating:
				state_timer = randf_range(0.4, 0.8)
			else:
				state_timer = randf_range(0.1, 0.3) if is_scared else randf_range(0.5, 1.5)
			if arrived_at_impact:
				is_investigating = false
			is_scared = false

func on_near_miss(impact_pos: Vector2) -> void:
	if is_dead:
		return
	is_scared = true
	is_investigating = false
	arrived_at_impact = false
	has_been_scared_once = true
	last_impact_pos = impact_pos
	_enter_state(State.ROTATING)

func _pick_new_target() -> void:
	if is_scared:
		var corners = [
			Vector2(bounds_min.x, bounds_min.y), Vector2(bounds_max.x, bounds_min.y),
			Vector2(bounds_min.x, bounds_max.y), Vector2(bounds_max.x, bounds_max.y)
		]
		corners.sort_custom(func(a, b): return a.distance_to(last_impact_pos) > b.distance_to(last_impact_pos))
		target_position = corners[0] if randf() < 0.7 else corners[1]
		return

	if has_been_scared_once and not arrived_at_impact:
		var dist_to_impact = global_position.distance_to(last_impact_pos)
		if dist_to_impact > 30:
			is_investigating = true
			var step_dist = min(dist_to_impact, randf_range(350, 500))
			var dir = (last_impact_pos - global_position).normalized()
			var timid_dir = dir.rotated(randf_range(-0.3, 0.3))
			var candidate = global_position + (timid_dir * step_dist)
			if _is_pos_valid(candidate):
				target_position = candidate
				return

	is_investigating = false
	for i in range(30):
		var ang = randf_range(0, TAU)
		var candidate = global_position + Vector2(cos(ang), sin(ang)) * randf_range(300, 600)
		if _is_pos_valid(candidate):
			target_position = candidate
			return
	target_position = failsafe_point

func _is_pos_valid(pos: Vector2) -> bool:
	return pos.x > bounds_min.x and pos.x < bounds_max.x and pos.y > bounds_min.y and pos.y < bounds_max.y

func die() -> void:
	if is_dead:
		return
	is_dead = true

	step_sound.stop()
	step_sound.stream = squash_audio
	step_sound.volume_db = 10
	step_sound.play()

	# Partículas de impacto
	var spores = spore_scene.instantiate()
	get_parent().add_child(spores)
	spores.global_position = global_position
	
	var burst = spores.get_node_or_null("Burst")
	if burst:
		burst.emitting = true

	# Visual aplastado
	body.texture = load("res://assets/intro/cockroach_squashed.png")
	body.region_enabled = false
	body.scale = Vector2(1.5, 1.5)

	ant_l.visible = false
	ant_r.visible = false
	shadow.visible = false
	rim_light.visible = false
	for f in femurs:
		f.visible = false

	# Efecto blackout - pasar posición de la cucaracha
	var blackout_script = load("res://scripts/blackout_controller.gd")
	var blackout_node = Node.new()
	blackout_node.set_script(blackout_script)
	blackout_node.name = "BlackoutController"
	get_tree().current_scene.add_child(blackout_node)
	blackout_node.start_blackout(global_position)

	emit_signal("died")
