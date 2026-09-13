extends Node2D
## Pantalla de título: entra con un fundido desde negro.
## Parpadeo de vela y zoom quedan para más adelante.

@export var fade_in_time: float = 2.5

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.anchor_right = 1.0
	black.anchor_bottom = 1.0
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 0.0, fade_in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(layer.queue_free)
