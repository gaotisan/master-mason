extends Node2D

# Referencias a nodos
@onready var ant_l: Sprite2D = $AntennaL
@onready var ant_r: Sprite2D = $AntennaR
@onready var legs = [
	$Leg_Front_L, $Leg_Mid_L_CANDIDATOS, $Leg_Hind_L_CANDIDATOS,
	$Leg_Front_R_CANDIDATOS, $Leg_Mid_R, $Leg_Hind_R
]

# Generador de ruido para movimiento orgánico
var noise = FastNoiseLite.new()
var time_passed: float = 0.0

# Parámetros heredados y ajustados para Godot 4
@export var base_speed: float = 1.2
@export var twitch_intensity: float = 0.7
@export var twitch_threshold: float = 0.35
@export var agility: float = 12.0
@export var movement_range: float = 0.6

# Variables de estado
var offset_l: float
var offset_r: float
var agility_l: float
var agility_r: float
var leg_offsets: Array = []

func _ready() -> void:
	# Configuración del ruido (Perlin para naturalidad)
	noise.seed = randi()
	noise.frequency = 0.4
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

	# Guardar rotaciones iniciales
	offset_l = ant_l.rotation
	offset_r = ant_r.rotation
	
	# Inicializar asimetría de antenas
	agility_l = agility * randf_range(0.85, 1.0)
	agility_r = agility * randf_range(0.85, 1.0)
	
	# Guardar offsets de las patas
	for leg in legs:
		if leg:
			leg_offsets.append(leg.rotation)

func _process(delta: float) -> void:
	time_passed += delta

	# --- LÓGICA DE ANTENAS (Tu sistema de micro-espasmos) ---
	var n_slow_l = noise.get_noise_1d(time_passed * base_speed)
	var n_slow_r = noise.get_noise_1d((time_passed + 50.0) * base_speed)

	var twitch_l = 0.0
	var twitch_r = 0.0
	
	if n_slow_l > twitch_threshold:
		twitch_l = noise.get_noise_1d(time_passed * 30.0) * twitch_intensity
	if n_slow_r > twitch_threshold:
		twitch_r = noise.get_noise_1d((time_passed + 75.0) * 30.0) * twitch_intensity

	var target_l = offset_l + (n_slow_l * movement_range) + twitch_l
	var target_r = offset_r + (n_slow_r * movement_range) + twitch_r

	ant_l.rotation = lerp_angle(ant_l.rotation, target_l, delta * agility_l)
	ant_r.rotation = lerp_angle(ant_r.rotation, target_r, delta * agility_r)

	# --- LÓGICA DE PATAS (Adaptación orgánica) ---
	# Las patas usan un ruido mucho más lento para simular el peso
	for i in range(legs.size()):
		var leg = legs[i]
		if leg:
			var leg_noise = noise.get_noise_1d((time_passed * 0.5) + (i * 10.0))
			var leg_target = leg_offsets[i] + (leg_noise * 0.1)
			leg.rotation = lerp_angle(leg.rotation, leg_target, delta * 4.0)
