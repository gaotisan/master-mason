class_name InputStep
extends Resource
## Un paso de una secuencia de teclas: vale cualquiera de las acciones listadas.

## Acciones del InputMap que satisfacen este paso (cualquiera de ellas).
@export var actions: Array[StringName] = []
## Segundos disponibles desde el paso anterior (o desde que aparece la ayuda). 0 = sin limite.
@export var time_window: float = 0.0
## Reservado para combos futuros: la tecla debe mantenerse pulsada.
@export var hold: bool = false
