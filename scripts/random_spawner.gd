extends Timer

@export var min_wait_time: float = 8.0
@export var max_wait_time: float = 20.0
@export var target_particle_path: NodePath

var target_particle: GPUParticles2D

func _ready():
    timeout.connect(_on_timeout)
    if target_particle_path:
        target_particle = get_node(target_particle_path)
    start_random()

func start_random():
    wait_time = randf_range(min_wait_time, max_wait_time)
    start()

func _on_timeout():
    if target_particle:
        target_particle.restart()
        target_particle.emitting = true
    start_random()
