extends Node2D
## Escenario negro donde va a moverse Magnus. De momento no hay nada mas que la
## camara y la marca de donde pisa el personaje: el fondo es el mismo negro en
## el que termina la pantalla de titulo, asi que el cambio de escena no se ve.
##
## Cuando la escena tenga fondo, aqui es donde toca abrir desde negro.

## Nivel al que llega el viento desde la pantalla de titulo. Solo se fija para
## que la escena arranque igual si se lanza sola desde el editor.
@export var wind_db: float = -14.0
## Fondo musical del juego. No viene puesto desde el titulo: alli el tema se
## apaga del todo y aqui entra el otro, ya en negro. Va mas bajo que el tema del
## titulo porque esto tiene que sonar debajo de todo durante horas, no llevar una
## escena. Como es "asegurar", tambien suena si se lanza la escena sola.
@export var music_db: float = -26.0
## Espera antes de que entre, contada desde que arranca la escena. Es el hueco de
## negro y viento que separa un tema del otro.
@export var music_delay: float = 2.0
@export var music_fade: float = 5.0
## Entrada de Magnus: en vez de aparecer ya de pie, cae desde fuera de pantalla
## sobre el negro, se estampa contra el suelo (que no se ve, pero el golpe lo
## dibuja), se queda tumbado y se levanta hasta la pose de siempre. Hasta que
## esta de pie no hay control. A false aparece de pie como antes.
@export var caida_al_empezar: bool = true

@onready var _magnus: Node2D = $Magnus

func _ready() -> void:
	WindAmbience.gust_db = 0.0
	WindAmbience.fade_to(wind_db, 0.0)
	MusicAmbience.asegurar_fondo(music_db, music_fade, music_delay)
	if caida_al_empezar:
		_magnus.caer_desde_arriba()
