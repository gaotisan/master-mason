extends AudioStreamPlayer

var breathing_node: AudioStreamPlayer
var sfx_loop = preload("res://assets/audio/second_rapid_breathing.ogg")
var shader_res = preload("res://scripts/vaho_cristal.gdshader")
var cristal: ColorRect

@export var use_vaho := true
@export var vaho_base_intensity := 0.85

var breath_timestamps := [0.9, 3.1, 5.2, 7.4, 9.1, 11.2, 13.5]
var current_breath_idx := 0
var playback_timer := 0.0
var last_playback := 0.0
var residue_level := 0.0

var is_slowing := false
var breath_pitch := 1.0
var breath_vol := -4.0

func _ready():
	self.volume_db = -5.0
	self.play()
	cristal = get_tree().current_scene.find_child("Cristal", true, false)
	if cristal:
		var mat := ShaderMaterial.new()
		mat.shader = shader_res
		cristal.material = mat
		cristal.color = Color(1, 1, 1, 0)
		mat.set_shader_parameter("intensity", 0.0)
		mat.set_shader_parameter("residue", 0.0)
	breathing_node = AudioStreamPlayer.new()
	add_child(breathing_node)
	breathing_node.stream = sfx_loop
	breathing_node.stream.loop = true
	breathing_node.volume_db = breath_vol
	breathing_node.play()

func _process(delta):
	if not self.playing:
		self.play()
	
	playback_timer = breathing_node.get_playback_position()
	# El loop ha vuelto al principio si la posicion retrocede; no depende de pillar
	# un frame concreto por debajo de un umbral.
	if playback_timer < last_playback:
		current_breath_idx = 0
	last_playback = playback_timer
	residue_level = max(residue_level - 0.03 * delta, 0.0)
	
	if cristal and cristal.material:
		cristal.material.set_shader_parameter("residue", residue_level)
	
	if is_slowing:
		breath_pitch = max(breath_pitch - delta * 0.07, 0.3)
		breath_vol = breath_vol - delta * 1.0
		breathing_node.pitch_scale = breath_pitch
		breathing_node.volume_db = breath_vol
		vaho_base_intensity = max(vaho_base_intensity - delta * 0.1, 0.1)
	
	if current_breath_idx < breath_timestamps.size():
		if playback_timer >= breath_timestamps[current_breath_idx]:
			_do_vaho_pulse(1.3, vaho_base_intensity)
			current_breath_idx += 1

func _do_vaho_pulse(duration: float, power: float):
	if not cristal or not cristal.material:
		return
	var mat := cristal.material
	mat.set_shader_parameter("seed", randf() * 100.0)
	residue_level = clamp(residue_level + 0.15, 0.0, 1.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(v): mat.set_shader_parameter("intensity", v), 0.0, power, duration * 0.3)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(func(v): mat.set_shader_parameter("intensity", v), power, 0.0, duration * 0.7)

func slow_breathing() -> void:
	is_slowing = true

func _exit_tree():
	if breathing_node:
		breathing_node.queue_free()
