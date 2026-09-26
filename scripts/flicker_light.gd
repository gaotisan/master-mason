extends PointLight2D

@export var noise_seed: int = 0
@export var position_vibration: float = 4.0 # Aumentado de 2.0 para acentuarlo

var time_passed: float = 0.0
@onready var original_pos = position

func _ready():
	# Generador propio y no seed(): seed() resiembra el aleatorio GLOBAL, y todo lo
	# que se prepara despues (moscas, cerdo, cucaracha) salia igual en cada partida.
	# Misma semilla, misma fase: la luz y el halo de cada vela siguen a la par.
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed
	time_passed = rng.randf() * 100.0

func _process(delta):
	# Aumentamos un pelín la velocidad del tiempo para más dinamismo
	time_passed += delta * 2.5 
	
	# Parpadeo de energía sutilmente ajustado
	energy = 0.5 + (sin(time_passed * 1.2) * 0.2) + (sin(time_passed * 4.5) * 0.1)
	
	# MOVIMIENTO ESTILIZADO:
	# Combinamos dos ondas para X y dos para Y con diferentes ritmos.
	# Esto evita el movimiento circular y crea un patrón más "orgánico" y elegante.
	var wave_x = sin(time_passed * 2.1 + noise_seed) + sin(time_passed * 0.7)
	var wave_y = cos(time_passed * 1.5 + noise_seed) + sin(time_passed * 1.2)
	
	var offset = Vector2(wave_x, wave_y) * (position_vibration * 0.5)
	
	position = original_pos + offset
