extends Node2D

@export var amplitud: float = 20.0
@export var velocidad: float = 0.5
@export var offset_pivot: Vector2 = Vector2(0, -200)

var _tiempo: float = 0.0

func _ready() -> void:
    for child in get_children():
        if child is Sprite2D:
            child.offset = -offset_pivot
            child.position = Vector2.ZERO # Centramos el nodo hijo

func _process(delta: float) -> void:
    _tiempo += delta
    var oscilacion = sin(_tiempo * velocidad * TAU)
    rotation = deg_to_rad(oscilacion * amplitud)
