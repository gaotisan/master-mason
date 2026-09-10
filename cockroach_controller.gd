extends Node2D

signal spotted
signal died

@onready var ant_l: Sprite2D = $AntennaL
@onready var ant_r: Sprite2D = $AntennaR
@onready var step_sound: AudioStreamPlayer2D = $StepSound
@onready var body: Sprite2D = $Body
@onready var shadow: Sprite2D = $Shadow
@onready var rim_light: Sprite2D = $RimLight

@onready var femurs: Array = [
        $LegFrontL/Femur,
        $LegMidR/Femur,
        $LegHindL/Femur,
        $LegFrontR/Femur,
        $LegMidL/Femur,
        $LegHindR/Femur
]

var tibias: Dictionary = {}

enum State { IDLE, ROTATING, WALKING, PAUSED, DEAD }
var current_state: State = State.IDLE
var state_timer: float = 0.0
var is_dead := false

# --------------------------------------------------
# ÁREA REAL DEL PUÑO (AJUSTADA AL SPRITE)
# --------------------------------------------------
# Centro aproximado del impacto (según imagen del puño)
const PUNCH_CENTER := Vector2(1560, 700)

# Semiejes de la elipse del golpe
const PUNCH_RADIUS_X := 260.0
const PUNCH_RADIUS_Y := 200.0
# --------------------------------------------------

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
@export var bounds_min: Vector2 = Vector2(50, 50)
@export var bounds_max: Vector2 = Vector2(2860, 1580)
@export var failsafe_point: Vector2 = Vector2(1456, 816)

@export_group("Leg Animation")
@export var femur_swing_amount: float = 0.28
@export var tibia_flex_amount: float = 0.18
@export var leg_speed: float = 22.0
@export var idle_jitter: float = 0.03
@export var walk_jitter: float = 0.02

var femur_rest: Dictionary = {}
var tibia_rest: Dictionary = {}
var leg_offsets: Array = []
var walk_weight: float = 0.0
var offset_ant_l: float
var offset_ant_r: float
var is_inside: bool = false
var was_walking: bool = false

# --------------------------------------------------

func _ready() -> void:
        noise.seed = randi()
        noise.frequency = 0.4
        noise.noise_type = FastNoiseLite.TYPE_PERLIN

        offset_ant_l = ant_l.rotation
        offset_ant_r = ant_r.rotation

        for f in femurs:
                if f:
                        femur_rest[f] = f.rotation
                        leg_offsets.append(randf_range(0.0, 100.0))
                        var t = f.get_node_or_null("Tibia")
                        if t:
                                tibias[f] = t
                                tibia_rest[t] = t.rotation

        target_position = failsafe_point
        _enter_state(State.IDLE)

# --------------------------------------------------
# INPUT: MISMO EVENTO QUE DISPARA EL PUÑO
# --------------------------------------------------
func _input(event):
        if is_dead:
                return

        if event is InputEventKey and event.pressed and event.keycode == KEY_UP:
                if _is_hit_by_punch():
                        _squash()

# Detección elíptica del impacto
func _is_hit_by_punch() -> bool:
        var d := global_position - PUNCH_CENTER
        return (d.x * d.x) / (PUNCH_RADIUS_X * PUNCH_RADIUS_X) + \
               (d.y * d.y) / (PUNCH_RADIUS_Y * PUNCH_RADIUS_Y) <= 1.0

# --------------------------------------------------

func _process(delta: float) -> void:
        if is_dead:
                return

        time_passed += delta
        state_timer -= delta

        match current_state:
                State.IDLE, State.PAUSED:
                        walk_weight = move_toward(walk_weight, 0.0, delta * 7.0)
                        if state_timer <= 0:
                                _enter_state(State.ROTATING if randf() < 0.7 else State.IDLE)

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

# --------------------------------------------------
# APLASTADO (MISMA POSICIÓN, ROTACIÓN Y ESCALA)
# --------------------------------------------------
func _squash():
        is_dead = true
        current_state = State.DEAD

        step_sound.stop()

        # Cambiamos SOLO la textura
        body.texture = load("res://assets/intro/cockroach_squashed.png")
        body.region_enabled = false
        # NO tocamos rotation ni scale

        ant_l.visible = false
        ant_r.visible = false
        shadow.visible = false
        rim_light.visible = false

        for f in femurs:
                if f:
                        f.visible = false

        emit_signal("died")

# --------------------------------------------------

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

func _process_rotating_logic(delta: float) -> void:
        rotation = rotate_toward(rotation, target_rotation, 20.0 * delta)
        if abs(angle_difference(rotation, target_rotation)) < 0.05:
                rotation = target_rotation
                _enter_state(State.WALKING)

func _process_movement_logic(delta: float) -> void:
        global_position += Vector2.UP.rotated(rotation) * move_speed * delta
        if global_position.distance_to(target_position) < 40:
                _enter_state(State.PAUSED)

func _update_all_legs_animation(delta: float) -> void:
        for i in range(femurs.size()):
                var f = femurs[i]
                if not f:
                        continue
                var current_jitter = lerp(idle_jitter, walk_jitter, walk_weight)
                var jitter = noise.get_noise_1d((time_passed + leg_offsets[i]) * 25.0) * current_jitter
                var base_phase = 0.0 if i < 3 else PI
                var cycle = time_passed * leg_speed + base_phase
                var wave = sin(cycle)
                f.rotation = femur_rest[f] + wave * femur_swing_amount * walk_weight + jitter
                if tibias.has(f):
                        var t = tibias[f]
                        t.rotation = tibia_rest[t] + sin(cycle - 0.4) * tibia_flex_amount * walk_weight + jitter * 0.5

func _process_antennae(delta: float) -> void:
        var m = 1.0 + walk_weight * 1.2
        var n_l = noise.get_noise_1d(time_passed * 1.6 * m)
        var n_r = noise.get_noise_1d((time_passed + 45.0) * 1.6 * m)
        ant_l.rotation = lerp_angle(ant_l.rotation, offset_ant_l + n_l * 0.7, delta * 14.0)
        ant_r.rotation = lerp_angle(ant_r.rotation, offset_ant_r + n_r * 0.7, delta * 14.0)

func _enter_state(new_state: State) -> void:
        if is_dead:
                return
        current_state = new_state
        match new_state:
                State.IDLE:
                        state_timer = randf_range(idle_time_min, idle_time_max)
                State.ROTATING:
                        _pick_new_target()
                        move_speed = randf_range(900, 1150)
                        target_rotation = (target_position - global_position).angle() + PI / 2
                State.WALKING:
                        state_timer = randf_range(0.25, 0.7)
                State.PAUSED:
                        state_timer = randf_range(0.4, 1.8)

func _pick_new_target() -> void:
        for i in range(30):
                var ang = (rotation - PI / 2) + randf_range(-deg_to_rad(65), deg_to_rad(65))
                var candidate = global_position + Vector2(cos(ang), sin(ang)) * randf_range(200, 700)
                if _is_pos_valid(candidate):
                        target_position = candidate
                        return
        target_position = failsafe_point

func _is_pos_valid(pos: Vector2) -> bool:
        return pos.x > bounds_min.x and pos.x < bounds_max.x and pos.y > bounds_min.y and pos.y < bounds_max.y
