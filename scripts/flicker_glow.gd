extends Sprite2D
## Halo aditivo de vela: mismo parpadeo que flicker_light.gd pero sin ser una luz 2D.
## Cuesta una fraccion de un PointLight2D y mantiene el brillo local de cada vela.

@export var noise_seed: int = 0
@export var position_vibration: float = 4.0
@export var base_alpha: float = 0.35

var time_passed: float = 0.0
@onready var original_pos = position

func _ready() -> void:
	seed(noise_seed)
	time_passed = randf() * 100.0

func _process(delta: float) -> void:
	time_passed += delta * 2.5
	var energy = 0.5 + (sin(time_passed * 1.2) * 0.2) + (sin(time_passed * 4.5) * 0.1)
	modulate.a = base_alpha * energy * 2.0
	var wave_x = sin(time_passed * 2.1 + noise_seed) + sin(time_passed * 0.7)
	var wave_y = cos(time_passed * 1.5 + noise_seed) + sin(time_passed * 1.2)
	position = original_pos + Vector2(wave_x, wave_y) * (position_vibration * 0.5)
