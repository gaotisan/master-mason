extends Node2D
## Balanceo pesado e irregular para objetos colgados
## Diferente al péndulo: más lento, con inercia y micro-movimientos

@export var amplitud_base: float = 2.0
@export var amplitud_micro: float = 0.5
@export var velocidad_base: float = 0.3
@export var velocidad_micro: float = 1.2
@export var offset_pivot: Vector2 = Vector2(0, -300)

var _tiempo: float = 0.0
var _offset_aleatorio: float = 0.0

func _ready() -> void:
	# Offset aleatorio para que no sincronice con otros objetos
	_offset_aleatorio = randf() * 100.0
	
	# Mover pivot al punto de anclaje
	for child in get_children():
		if child is Sprite2D:
			child.offset = -offset_pivot

func _process(delta: float) -> void:
	_tiempo += delta
	var t = _tiempo + _offset_aleatorio
	
	# Onda principal: lenta y pesada
	var onda_base = sin(t * velocidad_base * TAU) * amplitud_base
	
	# Ondas secundarias: irregularidad orgánica
	var onda_media = sin(t * velocidad_base * 1.7 * TAU + 0.5) * amplitud_base * 0.3
	var onda_micro = sin(t * velocidad_micro * TAU) * amplitud_micro
	
	# Combinar con easing para sensación de peso
	var angulo_total = onda_base + onda_media + onda_micro
	
	# Añadir micro-rotación extra cuando cambia de dirección (inercia)
	var inercia = cos(t * velocidad_base * TAU) * 0.3
	angulo_total += inercia
	
	rotation = deg_to_rad(angulo_total)
