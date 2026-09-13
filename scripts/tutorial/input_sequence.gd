class_name InputSequence
extends Resource
## Secuencia de teclas que el jugador debe pulsar en orden. Para una ayuda simple
## basta un solo paso sin tiempo; para combos y "danzas" se encadenan pasos con
## ventana de tiempo y, si se quiere, un pulso de ritmo.

@export var steps: Array[InputStep] = []
## Segundos entre pulsos de ritmo. 0 = sin ritmo (las teclas solo se marcan en orden).
@export var beat_interval: float = 0.0
