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
## Limites de Magnus en x: donde tiene que quedarse, con medio personaje de
## margen a cada borde de la camara fija (0-2912). La tecla hacia ese lado deja
## de contar antes, lo que tarda en pararse con el paso que lleve (frenada_*),
## y termina el paso y frena como al soltar: andando llega casi al borde y
## corriendo se para antes. Un salto hacia el borde se acorta para no pasarlo, y
## pegado al borde salta en el sitio. Es una demo para estudiar el movimiento:
## cuanto mas sitio, mejor.
@export var limite_izquierdo: float = 170.0
@export var limite_derecho: float = 2742.0
@export var frenada_andar: float = 200.0
@export var frenada_correr: float = 380.0

@onready var _magnus: Node2D = $Magnus

func _ready() -> void:
	WindAmbience.gust_db = 0.0
	WindAmbience.fade_to(wind_db, 0.0)
	# La marca manda: moverla en el editor mueve la entrada.
	_magnus.position = $MagnusSpawn.position
	_magnus.limite_izquierdo = limite_izquierdo
	_magnus.limite_derecho = limite_derecho
	_magnus.frenada_limite_andar = frenada_andar
	_magnus.frenada_limite_correr = frenada_correr
	if caida_al_empezar:
		_magnus.caer_desde_arriba()
