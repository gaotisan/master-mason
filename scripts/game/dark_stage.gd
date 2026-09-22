extends Node2D
## Escenario negro donde va a moverse Magnus. De momento no hay nada mas que la
## camara y la marca de donde pisa el personaje: el fondo es el mismo negro en
## el que termina la pantalla de titulo, asi que el cambio de escena no se ve.
##
## Cuando la escena tenga fondo, aqui es donde toca abrir desde negro.

## Nivel al que llega el viento desde la pantalla de titulo. Solo se fija para
## que la escena arranque igual si se lanza sola desde el editor.
@export var wind_db: float = -14.0

func _ready() -> void:
	WindAmbience.gust_db = 0.0
	WindAmbience.fade_to(wind_db, 0.0)
