extends Node2D
## Escenario negro donde va a moverse Magnus. De momento no hay nada mas que la
## camara y la marca de donde pisa el personaje: el fondo es el mismo negro en
## el que termina la pantalla de titulo, asi que el cambio de escena no se ve.
## Es adonde lleva la pantalla de titulo, y tambien el escenario de pruebas de
## Magnus (los pilotos de scenes/dev lo instancian).
##
## Cuando la escena tenga fondo, aqui es donde toca abrir desde negro.

## Nivel al que llega el viento desde la pantalla de titulo. Solo se fija para
## que la escena arranque igual si se lanza sola desde el editor.
@export var wind_db: float = -14.0
## Entrada de Magnus: en vez de aparecer ya de pie, cae desde fuera de pantalla
## sobre el negro, se estampa contra el suelo (que no se ve, pero el golpe lo
## dibuja), se queda tumbado y se levanta hasta la pose de siempre. Hasta que
## esta de pie no hay control. A false aparece de pie como antes.
@export var caida_al_empezar: bool = true
## Limites de Magnus en x. La camara es fija (0-2912 px) y sobre el negro, si
## se sale, no hay forma de saber donde esta. Los limites de magnus.gd no son
## una pared: pasado el limite la tecla hacia ese lado deja de contar y frena
## terminando el paso. Por eso van metidos hacia dentro lo que recorre en el
## peor caso mas medio sprite (146 px). El peor caso no es saltar justo antes
## del limite (~400 px) sino pasarlo corriendo: la parada de correr espera a su
## fase buena sin frenar (hasta 45 ticks, ~330 px) y un salto corriendo pulsado
## al final de esa espera lleva otros ~470 px. Medido con pilotos: ~800 px, con
## Magnus en 163-2750 y los pies dentro de la vista por los dos lados.
@export var limite_izquierdo: float = 960.0
@export var limite_derecho: float = 1952.0

@onready var _magnus: Node2D = $Magnus

func _ready() -> void:
	WindAmbience.gust_db = 0.0
	WindAmbience.fade_to(wind_db, 0.0)
	# La marca manda: moverla en el editor mueve la entrada.
	_magnus.position = $MagnusSpawn.position
	_magnus.limite_izquierdo = limite_izquierdo
	_magnus.limite_derecho = limite_derecho
	if caida_al_empezar:
		_magnus.caer_desde_arriba()
