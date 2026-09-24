extends Node
## Piloto de teclas: reproduce una secuencia de pulsaciones con reloj fijo para
## grabar al personaje sin nadie al teclado (godot --write-movie). Sirve para
## comparar una animacion antes y despues de un cambio con los mismos gestos.
##
## Las pulsaciones se inyectan como InputEventAction por Input.parse_input_event,
## que es lo que hace que lleguen a _unhandled_input Y actualicen Input.get_axis,
## igual que una tecla de verdad.
##
##   guion: lista de [segundo, accion, pulsar]. Se ejecuta en _physics_process,
##   asi que el instante se redondea al tick (1/60 s), como en el juego.

@export var guion: Array = [
	# doble pulsacion -> correr hacia la derecha, y se mantiene
	[0.50, "mover_derecha", true], [0.60, "mover_derecha", false], [0.70, "mover_derecha", true],
	# primer salto con la tecla pulsada: aterriza y sigue corriendo
	[2.50, "saltar", true], [2.60, "saltar", false],
	# segundo salto soltando la direccion en el aire: aterriza y se queda
	[4.80, "saltar", true], [4.90, "saltar", false], [5.00, "mover_derecha", false],
]
## Donde arranca el personaje, para que le quepan los saltos en pantalla.
@export var x_inicial: float = 320.0
@export var personaje: NodePath

var _t := 0.0
var _i := 0

func _ready() -> void:
	var p := get_node_or_null(personaje)
	if p:
		p.position.x = x_inicial

func _physics_process(delta: float) -> void:
	_t += delta
	while _i < guion.size() and guion[_i][0] <= _t:
		var paso: Array = guion[_i]
		var ev := InputEventAction.new()
		ev.action = paso[1]
		ev.pressed = paso[2]
		Input.parse_input_event(ev)
		print("piloto %.3f %s %s" % [_t, paso[1], "pulsa" if paso[2] else "suelta"])
		_i += 1
