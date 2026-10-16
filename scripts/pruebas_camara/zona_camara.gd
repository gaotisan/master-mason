extends Node
## Un tramo del nivel con su manera de encuadrar. La camara de capas
## (camara_capas.gd) mira en que zona esta Magnus por su x y va llevando sus
## valores hacia los de la zona, suavemente: asi el cambio de plano se nota
## como un movimiento de camara y no como un salto.

@export var nombre: String = ""
## Tramo en x del mundo (el de Magnus).
@export var desde: float = 0.0
@export var hasta: float = 3000.0
## Tamano de Magnus en pantalla: 1 = como en el resto del juego, 2 = el doble.
@export var zoom: float = 1.0
## Focal de la camara (en pixeles). 0 = la general de la escena. Si desde y
## hasta son distintas, la focal va de una a otra segun avanza Magnus por la
## zona y la camara se aleja o acerca a la vez para que el siga del mismo
## tamano: el efecto vertigo (el fondo se estira y Magnus no cambia).
@export var focal_desde: float = 0.0
@export var focal_hasta: float = 0.0
## A que altura de pantalla queda la linea del suelo (0 arriba, 1 abajo).
@export_range(0.0, 1.0) var suelo_en_pantalla: float = 0.74
## Fija: la camara se queda en el centro de la zona y Magnus la cruza, como las
## salas de Celeste. Si no, le sigue.
@export var fija: bool = false
## Cuanto adelanta la camara hacia donde mira Magnus (pixeles del mundo).
@export var mirada: float = 260.0
## Segundos (aproximados) que tarda la camara en asentarse al entrar.
@export var suavidad: float = 0.9

func contiene(x: float, margen: float = 0.0) -> bool:
	return x >= desde - margen and x < hasta + margen

func progreso(x: float) -> float:
	return clampf((x - desde) / maxf(hasta - desde, 1.0), 0.0, 1.0)
