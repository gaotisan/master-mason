extends Node2D

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sfx: AudioStreamPlayer2D = $HitSound
@onready var fist: Sprite2D = $Sprite2D

var camera: Camera2D
var shake_intensity := 0.0
var default_offset := Vector2.ZERO
var punch_disabled := false  # Nueva variable

@export var debug_draw_impact := false
@export var impact_radius := 260.0
@export var fear_radius_multiplier := 4.8
@export var impact_offset := Vector2(180, 0)

func _ready():
	camera = get_tree().current_scene.find_child("Camera", true, false)
	if camera:
		default_offset = camera.offset

func _process(delta):
	if shake_intensity > 0:
		shake_intensity = lerp(shake_intensity, 0.0, delta * 12)
		if camera:
			camera.offset = Vector2(
				randf_range(-1, 1) * shake_intensity,
				randf_range(-1, 1) * shake_intensity
			)
	elif camera:
		camera.offset = default_offset
	if debug_draw_impact:
		queue_redraw()

func _draw():
	if not debug_draw_impact:
		return
	var center = to_local(fist.global_position + impact_offset)
	draw_circle(center, impact_radius, Color(1, 0, 0, 0.25))
	draw_circle(center, impact_radius * fear_radius_multiplier, Color(1, 1, 0, 0.15))
	draw_circle(center, 6, Color.RED)

func _input(event):
	if punch_disabled:
		return
	if event.is_action_pressed("ui_up") and not anim.is_playing():
		anim.play("hit")

func emit_impact():
	sfx.play()
	shake_intensity = 45
	var center = fist.global_position + impact_offset
	var fear_radius = impact_radius * fear_radius_multiplier
	for bug in get_tree().get_nodes_in_group("squashable"):
		var d = center.distance_to(bug.global_position)
		if d < impact_radius:
			bug.die()
			punch_disabled = true  # Desactivar después de matar
		elif d < fear_radius and bug.has_method("on_near_miss"):
			bug.on_near_miss(center)
	# Y los que se asustan del golpe pero no se pueden aplastar: la araña de la
	# telarana. A estos no se les mide la distancia a proposito -- esta colgada de
	# los hilos de la sala, o sea que el golpe le llega por toda la telarana por
	# lejos que caiga el puño.
	for bug in get_tree().get_nodes_in_group("asustadizo"):
		if bug.has_method("on_near_miss"):
			bug.on_near_miss(center)
