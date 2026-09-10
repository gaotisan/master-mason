extends Node2D

@onready var canvas := $CanvasModulate
@onready var camera := $Camera

var time := 0.0
var flicker_enabled := false

func _ready():
    print("TITLE SCREEN START")

    # Empieza completamente negro
    canvas.color = Color(0, 0, 0)

    start_intro()

    # Zoom lento cinematográfico
    var cam_tween = create_tween()
    cam_tween.tween_property(camera, "zoom", Vector2(1.08, 1.08), 12.0)

func _process(delta):
    time += delta

    if flicker_enabled:
        # Flicker MUY suave tipo vela
        var flicker = 0.97 + sin(time * 6.0) * 0.015 + randf() * 0.01
        var target = Color(flicker, flicker * 0.92, flicker * 0.75)
        canvas.color = canvas.color.lerp(target, 0.08)

func start_intro():
    var tween = create_tween()

    # 1. Negro → apenas visible
    tween.tween_property(canvas, "color", Color(0.08, 0.06, 0.04), 2.0)

    # 2. Luz de velas
    tween.tween_property(canvas, "color", Color(0.45, 0.35, 0.25), 2.5)

    # Activar flicker
    tween.tween_callback(Callable(self, "_enable_flicker"))

    # 3. Iluminación final
    tween.tween_property(canvas, "color", Color(1, 1, 1), 3.0)

func _enable_flicker():
    flicker_enabled = true
