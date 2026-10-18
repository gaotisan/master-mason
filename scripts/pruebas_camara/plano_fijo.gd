extends Node
## Un plano de camara de la prueba de planos fijos (planos_fijos.gd), como los
## de Alone in the Dark: mientras el peregrino este en su tramo de x, la sala se ve
## desde aqui. Al salir del tramo, corte al plano siguiente.
##
## Coordenadas de la sala: x a lo largo de la galeria (la x del peregrino), y hacia
## arriba desde el suelo, z de -700 (pared de este lado) a 700 (pared del
## fondo). El peregrino anda por z = 0.

@export var nombre: String = ""
@export var desde: float = 0.0
@export var hasta: float = 1500.0
## Perspectiva: donde esta la camara y adonde mira.
@export var posicion: Vector3 = Vector3(0, 800, -650)
@export var mirar_a: Vector3 = Vector3(1000, 0, 0)
## Focal en pixeles: mas baja = gran angular, deforma mas y achica lo lejano.
@export var focal: float = 1500.0
## Inclinacion lateral del encuadre (plano holandes), en grados.
@export var alabeo: float = 0.0
## La camara no se mueve pero gira para seguir al peregrino (panoramica).
@export var seguir: bool = false
## Cuanto le sigue: 0 nada, 1 le deja centrado.
@export_range(0.0, 1.0) var seguimiento: float = 0.7

@export_group("Ortogonal (isometrico)")
## Sin perspectiva: todo del mismo tamano a cualquier distancia. Con giro 45 y
## inclinacion 30 es la vista isometrica clasica. Se centra en mirar_a.
@export var ortogonal: bool = false
@export var giro: float = 45.0
@export var inclinacion: float = 30.0
@export var escala_orto: float = 0.85

func contiene(x: float, margen: float = 0.0) -> bool:
	return x >= desde - margen and x < hasta + margen
