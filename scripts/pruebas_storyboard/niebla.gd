extends Node2D
## Bancos de niebla que pasan despacio: manchas suaves muy transparentes que se
## desplazan en x y dan la vuelta. Sutil a proposito.

@export var cantidad: int = 7
@export var color: Color = Color(0.95, 0.8, 0.6, 0.10)
@export var velocidad: float = 25.0
@export var area: Rect2 = Rect2(-400, 300, 3700, 1400)
@export var tamano: Vector2 = Vector2(5.0, 2.0)
@export var semilla: int = 3

var _manchas: Array[Sprite2D] = []
var _vel: Array[float] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	for i in cantidad:
		var s := Sprite2D.new()
		s.texture = tex
		s.modulate = color
		var f := rng.randf_range(0.7, 1.3)
		s.scale = tamano * f
		s.position = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		add_child(s)
		_manchas.append(s)
		_vel.append(velocidad * rng.randf_range(0.6, 1.4))

func _process(delta: float) -> void:
	for i in _manchas.size():
		var s := _manchas[i]
		s.position.x += _vel[i] * delta
		if s.position.x > area.end.x + 600:
			s.position.x = area.position.x - 600
