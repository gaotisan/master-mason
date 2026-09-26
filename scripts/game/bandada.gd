extends Node2D
## Una bandada que cruza el cielo del atardecer una sola vez. Va dentro de un
## Parallax2D lento (esta lejos); los pajaros son la tira de cuatro poses de
## pajaro.png y aletean a ritmos algo distintos para que no vayan en formacion
## de desfile.

const TIRA := preload("res://assets/world/bosque/pajaro.png")

@export var cantidad: int = 9
@export var velocidad: float = 150.0
## Escala de los pajaros (la tira es de 128x64 por pose).
@export var tamano: float = 0.42

var _pajaros: Array[Dictionary] = []

## Los suelta por la derecha de la pantalla, a la altura del cielo, volando
## hacia la izquierda y algo hacia arriba. centro = centro de camara en el mundo.
func despegar(centro: Vector2) -> void:
	var capa := get_parent() as Parallax2D
	var escala := capa.scroll_scale.x if capa else 1.0
	# x local de la capa que cae en el borde derecho de la pantalla
	var borde := 2912.0 + (centro.x - 1456.0) * escala
	var frames := _frames()
	for i in cantidad:
		var p := AnimatedSprite2D.new()
		p.sprite_frames = frames
		p.play("aletear")
		p.speed_scale = randf_range(0.8, 1.25)
		p.frame = randi() % 4
		var s := tamano * randf_range(0.75, 1.1)
		p.scale = Vector2(s, s)
		p.flip_h = true
		p.position = Vector2(borde + 80.0 + i * randf_range(40, 90), 360.0 + randf_range(-90, 90) + i * 6.0)
		add_child(p)
		_pajaros.append({"nodo": p, "v": Vector2(-velocidad * randf_range(0.85, 1.15), -randf_range(6, 22)),
			"fase": randf() * TAU, "vida": 0.0})

func _process(delta: float) -> void:
	for i in range(_pajaros.size() - 1, -1, -1):
		var b: Dictionary = _pajaros[i]
		var n: AnimatedSprite2D = b["nodo"]
		b["fase"] += delta
		b["vida"] += delta
		n.position += b["v"] * delta + Vector2(0, sin(b["fase"] * 1.3) * 8.0 * delta)
		# Cruzan la pantalla en unos 25 s; a los 50 ya estan fuera de cualquier
		# encuadre.
		if b["vida"] > 50.0:
			n.queue_free()
			_pajaros.remove_at(i)

func _frames() -> SpriteFrames:
	var f := SpriteFrames.new()
	f.add_animation("aletear")
	f.set_animation_speed("aletear", 9.0)
	f.set_animation_loop("aletear", true)
	for i in 4:
		var a := AtlasTexture.new()
		a.atlas = TIRA
		a.region = Rect2(i * 128, 0, 128, 64)
		f.add_frame("aletear", a)
	if f.has_animation("default"):
		f.remove_animation("default")
	return f
