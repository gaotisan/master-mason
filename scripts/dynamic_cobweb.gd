extends Node2D
class_name DynamicCobweb

@export_group("Apariencia")
@export var web_color: Color = Color(0.85, 0.85, 0.9, 0.35)
@export var line_width: float = 1.5
@export var antialiased: bool = true

@export_group("Movimiento")
@export var wind_speed: float = 0.8
@export var wind_strength: float = 3.0
@export var turbulence: float = 0.5

var _original_points: Array[PackedVector2Array] = []
var _lines: Array[Line2D] = []
var _time: float = 0.0

func _ready() -> void:
	_setup_cobwebs()

func _process(delta: float) -> void:
	_time += delta
	_animate_webs()

func _setup_cobwebs() -> void:
	var web_definitions: Array = [
		{"points": [Vector2(180, 95), Vector2(350, 140), Vector2(550, 180), Vector2(780, 200), Vector2(1000, 195)], "sway_factor": 0.6},
		{"points": [Vector2(550, 180), Vector2(500, 280), Vector2(420, 400)], "sway_factor": 0.8},
		{"points": [Vector2(1820, 100), Vector2(1650, 150), Vector2(1450, 200), Vector2(1250, 230), Vector2(1100, 210)], "sway_factor": 0.6},
		{"points": [Vector2(1450, 200), Vector2(1500, 320), Vector2(1580, 450)], "sway_factor": 0.8},
		{"points": [Vector2(400, 120), Vector2(600, 115), Vector2(850, 130), Vector2(1100, 125), Vector2(1400, 110), Vector2(1600, 120)], "sway_factor": 0.4},
		{"points": [Vector2(95, 550), Vector2(150, 620), Vector2(220, 720), Vector2(320, 850), Vector2(450, 950)], "sway_factor": 0.7},
		{"points": [Vector2(120, 400), Vector2(180, 500), Vector2(260, 620)], "sway_factor": 0.65},
		{"points": [Vector2(1900, 520), Vector2(1820, 620), Vector2(1720, 750), Vector2(1600, 880), Vector2(1500, 960)], "sway_factor": 0.7},
		{"points": [Vector2(1880, 380), Vector2(1800, 480), Vector2(1700, 600)], "sway_factor": 0.65},
		{"points": [Vector2(200, 950), Vector2(350, 920), Vector2(550, 900), Vector2(750, 920)], "sway_factor": 0.5},
		{"points": [Vector2(1250, 930), Vector2(1450, 910), Vector2(1650, 940), Vector2(1800, 970)], "sway_factor": 0.5},
		{"points": [Vector2(870, 80), Vector2(865, 150), Vector2(850, 250), Vector2(830, 350)], "sway_factor": 1.0},
		{"points": [Vector2(1050, 80), Vector2(1055, 160), Vector2(1070, 270), Vector2(1090, 380)], "sway_factor": 1.0},
		{"points": [Vector2(860, 200), Vector2(920, 220), Vector2(980, 215), Vector2(1040, 210)], "sway_factor": 0.3},
	]
	
	for web_def in web_definitions:
		var line = Line2D.new()
		line.width = line_width
		line.default_color = web_color
		line.antialiased = antialiased
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		
		var smooth_points = _create_smooth_curve(web_def["points"])
		line.points = smooth_points
		line.set_meta("sway_factor", web_def["sway_factor"])
		line.set_meta("phase_offset", randf() * TAU)
		
		_original_points.append(smooth_points)
		_lines.append(line)
		add_child(line)

func _create_smooth_curve(control_points: Array) -> PackedVector2Array:
	var result = PackedVector2Array()
	if control_points.size() < 2:
		for p in control_points:
			result.append(p)
		return result
	
	var curve = Curve2D.new()
	for i in range(control_points.size()):
		var point = control_points[i]
		var in_vec = Vector2.ZERO
		var out_vec = Vector2.ZERO
		if i > 0:
			in_vec = (control_points[i-1] - point) * 0.25
		if i < control_points.size() - 1:
			out_vec = (control_points[i+1] - point) * 0.25
		curve.add_point(point, in_vec, out_vec)
	
	var num_samples = control_points.size() * 8
	for j in range(num_samples + 1):
		var t = float(j) / float(num_samples)
		result.append(curve.sample_baked(t * curve.get_baked_length()))
	return result

func _animate_webs() -> void:
	for i in range(_lines.size()):
		var line = _lines[i]
		var original = _original_points[i]
		var sway = line.get_meta("sway_factor")
		var phase = line.get_meta("phase_offset")
		var new_points = PackedVector2Array()
		var point_count = original.size()
		
		for j in range(point_count):
			var orig_point = original[j]
			var t = float(j) / float(point_count - 1) if point_count > 1 else 0.0
			var movement_factor = t * sway
			var wave1 = sin(_time * wind_speed + phase + j * 0.1) * wind_strength
			var wave2 = sin(_time * wind_speed * 1.7 + phase * 0.5 + j * 0.15) * wind_strength * turbulence
			var offset = Vector2((wave1 + wave2 * 0.5) * movement_factor, (wave2 * 0.3) * movement_factor)
			new_points.append(orig_point + offset)
		line.points = new_points

func set_wind(speed: float, strength: float) -> void:
	wind_speed = speed
	wind_strength = strength

func set_visibility_fade(alpha: float) -> void:
	for line in _lines:
		var c = line.default_color
		line.default_color = Color(c.r, c.g, c.b, alpha)

func pulse_wind(duration: float = 2.0, intensity: float = 8.0) -> void:
	var original_strength = wind_strength
	var tween = create_tween()
	tween.tween_property(self, "wind_strength", intensity, duration * 0.3)
	tween.tween_property(self, "wind_strength", original_strength, duration * 0.7)
