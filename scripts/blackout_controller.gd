extends Node

var canvas_layer: CanvasLayer
var blackout_overlay: ColorRect
var shader_mat: ShaderMaterial
var ambient_controller: Node
var haze_effect: GPUParticles2D

var is_active := false
var effect_time := 0.0
var delay_finished := false
var start_position := Vector2(1456, 816)

var blur := 0.0
var vignette := 0.0
var blackout := 0.0
var blink := 0.0
var tint := 0.0

# Todos dentro de la fase 2 (3.0-7.5 s), cada vez mas seguidos hacia el desmayo.
var blink_schedule := [3.6, 4.6, 5.4, 6.0, 6.5, 6.9, 7.2]
var next_blink_idx := 0
var is_blinking := false
var blink_tween: Tween

@export var next_scene: String = "res://scenes/intro/title_screen.tscn"

signal blackout_complete
## Se emite al empezar cada parpadeo, con su indice. La cucaracha se engancha
## aqui para sacudirse justo cuando el parpado vuelve a subir, en vez de llevar
## copiados los tiempos de blink_schedule y desincronizarse si se tocan.
signal blinked(index: int)

func start_blackout(origin_pos: Vector2 = Vector2(1456, 816)) -> void:
	if is_active:
		return
	is_active = true
	effect_time = 0.0
	delay_finished = false
	next_blink_idx = 0
	start_position = origin_pos
	
	ambient_controller = get_tree().current_scene.find_child("AmbientPlayer", true, false)
	
	# Crear el haze desde la posición de la cucaracha
	var haze_scene = load("res://scenes/intro/spore_haze.tscn")
	haze_effect = haze_scene.instantiate()
	get_tree().current_scene.add_child(haze_effect)
	haze_effect.global_position = start_position
	haze_effect.emitting = true
	
	# Canvas layer para el shader
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.name = "BlackoutCanvas"
	get_tree().current_scene.add_child(canvas_layer)
	
	blackout_overlay = ColorRect.new()
	blackout_overlay.anchor_right = 1.0
	blackout_overlay.anchor_bottom = 1.0
	blackout_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	shader_mat = ShaderMaterial.new()
	shader_mat.shader = load("res://scripts/blackout_effect.gdshader")
	blackout_overlay.material = shader_mat
	
	canvas_layer.add_child(blackout_overlay)
	_update_shader()

func _process(delta: float) -> void:
	if not is_active:
		return
	
	effect_time += delta
	
	if effect_time < 1.5:
		return
	
	if not delay_finished:
		delay_finished = true
		if ambient_controller and ambient_controller.has_method("slow_breathing"):
			ambient_controller.slow_breathing()
	
	var t = effect_time - 1.5
	
	# Fase 1: Tinte suave (0-3s)
	if t < 3.0:
		var p = t / 3.0
		tint = p * 0.3
		blur = p * 0.5
		vignette = p * 0.15
	
	# Fase 2: Malestar con parpadeos (3-7.5s)
	elif t < 7.5:
		var p = (t - 3.0) / 4.5
		tint = 0.3 + p * 0.15
		blur = 0.5 + p * 2.0
		vignette = 0.15 + p * 0.45
		_check_blinks(t)
	
	# Fase 3: Desmayo (7.5-10s)
	elif t < 10.0:
		if blink_tween and blink_tween.is_running():
			blink_tween.kill()
			is_blinking = false
		var p = (t - 7.5) / 2.5
		blur = 2.5 + p * 1.0
		vignette = 0.6 + p * 0.35
		blackout = p * p
		blink = min(blink + delta * 0.6, 1.0)
	
	# Mantener negro antes de cambiar escena
	elif t < 11.5:
		blackout = 1.0
		blink = 1.0
	
	# Cambiar escena
	else:
		is_active = false
		emit_signal("blackout_complete")
		_change_scene()
	
	_update_shader()

func _check_blinks(t: float) -> void:
	if next_blink_idx >= blink_schedule.size():
		return
	if is_blinking:
		return
	if t >= blink_schedule[next_blink_idx]:
		_do_blink()
		next_blink_idx += 1

func _do_blink() -> void:
	is_blinking = true
	blinked.emit(next_blink_idx)
	var close_val = randf_range(0.45, 0.75)
	var dur = randf_range(0.3, 0.5)
	
	blink_tween = create_tween()
	blink_tween.tween_property(self, "blink", close_val, dur * 0.4).set_trans(Tween.TRANS_SINE)
	blink_tween.tween_property(self, "blink", 0.0, dur * 0.6).set_trans(Tween.TRANS_SINE)
	blink_tween.tween_callback(func(): is_blinking = false)

func _update_shader() -> void:
	if shader_mat:
		shader_mat.set_shader_parameter("blur_amount", blur)
		shader_mat.set_shader_parameter("vignette_intensity", vignette)
		shader_mat.set_shader_parameter("blackout", blackout)
		shader_mat.set_shader_parameter("blink", blink)
		shader_mat.set_shader_parameter("tint_amount", tint)

func _change_scene() -> void:
	get_tree().change_scene_to_file(next_scene)
