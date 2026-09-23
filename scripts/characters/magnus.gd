extends Node2D
## Magnus. La posicion del nodo es el punto donde pisa: el sprite lleva un
## offset (-165 en la casilla comun, -185 en la del salto corriendo) para que la
## linea de suelo de la casilla caiga en el origen.
##
## Las animaciones encadenan asi:
##   reposo -> arranque_andar  -> andar  -> parada_andar  -> reposo
##   reposo -> arranque_correr -> correr -> parada_correr -> reposo
## Los arranques y las paradas son de una pasada; reposo, andar y correr, bucles.
##
## El salto no mueve el nodo: la subida y la bajada ya estan dentro del sprite,
## que se grabo saltando en el sitio. Si ademas moviesemos el nodo, saltaria dos
## veces.
##
## Sonido: cada pisada se dispara desde el sprite en que el pie planta, y en
## reposo suena la respiracion en bucle. Los pasos no van en un bucle de audio
## porque andar y correr avanzan con la distancia, no con el reloj, y a la larga
## se desfasarian. Los archivos salen de raw/master_mason/audio/magnus/.

## Medidos sobre los sprites: la zancada es la separacion maxima entre los pies.
## Ver raw/master_mason/anim/magnus_comun.txt.
## Estas dos no son libres: el fotograma solo cambia en ticks de fisica, asi que
## su duracion tiene que ser un numero entero de ticks o la cadencia va a
## tirones. Con velocidad / avance = fotogramas por segundo y la fisica a 60 Hz,
## 192 y 435 dan 30 fotogramas por segundo justos, o sea 2 ticks por fotograma
## clavados. Los valores anteriores, 229 y 416, daban 1,677 y 2,091 ticks: unos
## fotogramas duraban 17 ms y otros 33, que andando es una variacion de 2 a 1 y
## se ve como un temblor en la cadencia de las piernas.
##
## Si quieres otra velocidad, la regla es velocidad = 30 * avance (2 ticks) o
## 20 * avance (3 ticks, mas lento pero igual de regular). Cualquier otro numero
## reintroduce el tiron.
@export var velocidad_andar: float = 192.0
@export var velocidad_correr: float = 435.0
## Px recorridos por fotograma de animacion. Con esto el ciclo avanza segun lo
## que se anda, no segun el reloj, y los pies no patinan a ninguna velocidad.
## Medidos siguiendo el pie plantado respecto al eje del tronco, fotograma a
## fotograma, sobre las mascaras de 04_limpios: 12,8 px de master al andar y
## 28,9 al correr, que a media escala son los de aqui. No vale deducirlos de la
## zancada ni de la velocidad: asi salian 9,5 y 17,3, el cuerpo recorria un 48%
## mas de lo que decian las piernas y por eso se deslizaba.
@export var avance_andar: float = 6.4
@export var avance_correr: float = 14.5
## Fotograma del bucle por el que se entra al terminar el arranque.
##
## El arranque y el bucle no tienen por que encajar: arranque_correr y correr
## salen de videos distintos, asi que la pose en la que acaba uno no es la del
## fotograma 0 del otro. Comparando el ultimo fotograma del arranque contra los
## 24 del ciclo -- silueta y color, normalizados por altura -- entrar por el 0
## da un salto de 1,8 pasos normales del ciclo, y entrar por el 12 lo deja en
## 1,1, que ya no se distingue de un fotograma cualquiera.
##
## Andar no lo necesita: su arranque y su ciclo salen del mismo video y entrar
## por el 0 ya da 0,5 pasos. El 33 medía algo mejor, 0,2, pero no se ve.
@export var entrada_andar: int = 19
@export var entrada_correr: int = 9
## El arranque de andar se corta en el 18 y su velocidad no es una rampa recta
## sino la medida en los sprites, fotograma a fotograma (ver AVANCE_ARRANQUE_ANDAR).
## A partir del 18 el arranque ya ES el ciclo -- cada fotograma casa con el ciclo
## en su misma posicion, 18->f19, 22->f22... -- y su cola (26-33) afloja mientras
## el nodo seguia a tope: de +2 a +15 px master por fotograma de patinazo, que
## era el deslizamiento "sutil pero se nota" de los primeros segundos. -1 lo
## reproduce entero con la rampa antigua.
@export var corte_arranque_andar: int = 18
## Cuantos fotogramas del ciclo se espera, como mucho, a un apoyo que case con la
## parada al soltar la tecla. Puestos al ciclo entero = esperar SIEMPRE, que es lo
## que hace que la parada se vea igual de bien cada vez. Cuesta responsividad: al
## andar hasta 20 fotogramas (0,67 s) y al correr hasta 23 (0,77 s), porque el
## personaje termina el paso antes de frenar. 0 = entrar al instante, como antes.
@export var espera_parada_andar: int = 34
@export var espera_parada_correr: int = 24
## Cuanto salto de pose se tolera al entrar en la parada, en "pasos normales" del
## ciclo (la diferencia mediana entre dos fotogramas consecutivos). Se espera a un
## fotograma del ciclo que baje de esto; cuanto mas bajo, mejor se ve y mas se
## tarda en parar. Las distancias medidas estan en DIST_PARADA_*.
##
##   correr: 1,25 -> solo la fase 22 (la mejor, 1,21), espera hasta 23 fotogramas
##           1,60 -> once fases, espera hasta 9 fotogramas (0,30 s)
##   andar:  1,30 -> nueve fases (f2-f3, f24-f30), espera hasta 20 fotogramas
@export var tolerancia_parada_correr: float = 1.25
@export var tolerancia_parada_andar: float = 1.30
## Ultimo fotograma que se usa del arranque de correr; -1 lo reproduce entero.
##
## Los ultimos fotogramas de esa animacion tienen el brazo yendo hacia atras y
## volviendo de golpe, sin frenar en el extremo: se ve como si rebotase contra
## algo. Medido siguiendo la mano: del 31 al 32 recorre 32 px hacia atras y del
## 32 al 33 recorre 30 hacia delante, sin un solo fotograma de demora. Que es un
## fallo y no el gesto se ve en el otro extremo de la misma animacion, el 20-21,
## donde la mano solo se mueve 4,6 px, o sea que ahi el brazo si se demora.
##
## Cortando en el 28 el rebote no llega a verse, y de paso el empalme con el
## bucle mejora: 0,75 pasos normales del ciclo en vez de 1,11.
@export var corte_arranque_correr: int = 22
## Girar con la animacion de giro en vez de voltear el sprite de golpe.
##
## La animacion son 9 fotogramas: perfil, 22, 45, 67 grados, frontal, y de vuelta
## los cuatro espejados. Salen de una hoja de rotacion dibujada aparte, no de un
## video. El volteo del sprite se hace al TERMINAR, no al empezar: durante el
## giro se conserva el flip_h que hubiera, y por eso la misma animacion sirve
## para los dos sentidos -- volteada se lee de izquierda a derecha.
##
## A false vuelve al flip_h instantaneo de antes.
@export var giro_activo: bool = true
## Margen para que dos pulsaciones cuenten como doble y arranque a correr.
@export var doble_pulsacion: float = 0.30
## Fraccion del arranque en la que el personaje todavia no ha movido los pies.
## Medido sobre los sprites: 2 fotogramas de 34 al andar, 3 al correr. Al correr
## la fraccion se cuenta sobre el arranque ya cortado, 3 de 28.
@export var quieto_al_arrancar_andar: float = 0.06
@export var quieto_al_arrancar_correr: float = 0.11
## Fraccion de la parada en la que el cuerpo frena de verdad. El resto de la
## animacion es el abrigo asentandose, con los pies ya plantados: si el nodo
## sigue avanzando ahi, parece una cinta mecanica.
## Medido siguiendo el pie respecto al cuerpo: se planta en 5 fotogramas de 21
## al andar y en 3 de 39 al correr.
@export var frenada_andar: float = 0.25
@export var frenada_correr: float = 0.10
## Momento del salto en que toca el suelo, como fraccion de la animacion. A
## partir de ahi el impulso que llevaba se apaga. Medido siguiendo la fila del
## pie mas bajo en 04_limpios: despega en el sprite 15 de 70 y toca el suelo en
## el 46 (indice 45 de 69). El salto de parado y el de andando son el mismo:
## el sprite no lleva desplazamiento cocido, lo pone el nodo con _impulso.
@export var aterrizaje: float = 0.652
## A partir de aqui el salto se puede cortar con otra tecla. Sin esto, la
## recuperacion deja al personaje 0,4 s sin responder despues de haber caido.
## Es el sprite 60 de 70, 0,23 s despues de tocar el suelo: antes esta en
## cuclillas y ningun fotograma de andar se le parece (0,060, casi 5 pasos
## normales del ciclo); a partir de aqui baja a 0,046 (3,5 pasos, lo mismo que
## se acepto para entrar al salto corriendo). El impulso ya esta apagado.
@export var salto_interrumpible: float = 0.855
## Lo mismo para el salto corriendo, que es otra animacion con otros tiempos:
## medido siguiendo el punto mas bajo del personaje, despega en el fotograma 3
## de 38, llega al apogeo en el 17 y toca el suelo en el 30.
@export var aterrizaje_correr: float = 0.81
@export var salto_correr_interrumpible: float = 0.85
## El salto corriendo va en su propia casilla, 340x400 en la hoja frente a los
## 292x360 del resto, porque en el apogeo el personaje se sale de la comun por
## arriba y por la izquierda. El offset pone la linea de suelo de cada casilla en
## el origen del nodo: alto/2 menos los 15 px de margen de suelo a media escala.
@export var offset_comun := Vector2(0, -165)
@export var offset_salto_correr := Vector2(0, -185)
## Cinematica de entrada (caer_desde_arriba): cae desde fuera de pantalla, se
## estampa, se queda tumbado y se levanta. Mientras dura no se acepta entrada.
## Las cuatro animaciones van en casilla propia (380x360) pero con la linea de
## suelo en la misma fila que la comun, asi que usan offset_comun.
##
## El descenso lo pone el nodo, no el sprite: el bucle "cayendo" tiene la
## cabeza fijada. Con 1200 px en 1,1 s y aceleracion cuadratica llega al suelo
## a unos 2200 px/s, 36 px por tick: se lee como caida y no como flotar.
@export var caida_altura: float = 1200.0
@export var caida_duracion: float = 1.1
## Cuanto se queda tumbado antes de empezar a levantarse. Sin pausa el golpe
## no pesa; con mas de dos segundos parece que no va a levantarse.
@export var tumbado_espera: float = 1.2

## Se emite cuando la cinematica de entrada deja al personaje en reposo y con
## el control devuelto.
signal cinematica_terminada
## Niveles de sonido. Los archivos estan a -6 dBFS de pico; esto es lo que se
## les baja en el juego.
@export var pasos_db: float = -6.0
@export var respiracion_db: float = -12.0
## Variacion de tono entre pisadas para que no suenen a metralleta.
@export var pasos_variacion: float = 0.03

## Sprite en que planta cada pie (medido en 04_limpios: maxima separacion de los
## pies al andar, pie que toca el suelo al correr) -> golpe que suena.
const PISADAS := {
	"andar": {
		0: preload("res://assets/audio/magnus_paso_a.wav"),
		16: preload("res://assets/audio/magnus_paso_b.wav"),
	},
	"correr": {
		4: preload("res://assets/audio/magnus_paso_correr_a.wav"),
		16: preload("res://assets/audio/magnus_paso_correr_b.wav"),
	},
}

enum Estado { REPOSO, ARRANQUE_ANDAR, ANDAR, PARADA_ANDAR,
			  ARRANQUE_CORRER, CORRER, PARADA_CORRER, SALTAR, GIRO,
			  CAYENDO, CAIDA, TUMBADO, LEVANTARSE }

## Estados de la cinematica de entrada: sin control del jugador.
const CINEMATICA := [Estado.CAYENDO, Estado.CAIDA, Estado.TUMBADO, Estado.LEVANTARSE]

var _estado: Estado = Estado.REPOSO
var _mirando := 1.0          # 1 derecha, -1 izquierda
var _recorrido := 0.0        # para mover la animacion con la distancia
var _impulso := 0.0          # velocidad que llevaba al despegar, se conserva en el aire
var _corria_al_saltar := false
var _frenando_desde := 0.0   # velocidad que llevaba al empezar a frenar
var _velocidad_suelo := 0.0
var _parada_espera := 0      # ticks esperando un apoyo bueno para parar de andar
var _parada_entrada := 0     # fotograma de la parada por el que se entro  # la que traia al entrar en un arranque por pose; sostiene hasta que la rampa la alcanza
var _giro_pendiente := 0.0   # hacia donde hay que girar cuando acabe de frenar
var _giro_corriendo := false
var _giro_destino := 0.0     # hacia donde mira al acabar la animacion de giro
var _ultima_pulsacion := {}  # accion -> instante, para detectar el doble
var _ultimo_fotograma := -1  # el ultimo que puso este script, para no repetir pisadas
var _fundido: Tween         # fundido de la respiracion al entrar y salir del reposo

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _pasos: AudioStreamPlayer = $Pasos
@onready var _respiracion: AudioStreamPlayer = $Respiracion

func _ready() -> void:
	_sprite.animation_finished.connect(_al_terminar)
	_poner("reposo")

func _unhandled_input(evento: InputEvent) -> void:
	if _en_cinematica():
		return
	if evento.is_action_pressed("saltar") and _puede_saltar():
		# El salto se lleva la velocidad que llevaba: saltar corriendo tiene que
		# avanzar en el aire, no caer en el sitio.
		_impulso = _velocidad()
		_corria_al_saltar = _estado == Estado.CORRER or _estado == Estado.ARRANQUE_CORRER
		_cambiar(Estado.SALTAR)
		return
	for accion in ["mover_izquierda", "mover_derecha"]:
		if not evento.is_action_pressed(accion):
			continue
		var ahora := Time.get_ticks_msec() / 1000.0
		var antes: float = _ultima_pulsacion.get(accion, -99.0)
		_ultima_pulsacion[accion] = ahora
		if ahora - antes <= doble_pulsacion:
			_arrancar(accion, true)
		elif _puede_arrancar():
			_arrancar(accion, false)

func _physics_process(delta: float) -> void:
	# En la cinematica de entrada el nodo lo mueve el tween de la caida y las
	# animaciones se encadenan solas: aqui no hay nada que hacer.
	if _en_cinematica():
		return
	var direccion := Input.get_axis("mover_izquierda", "mover_derecha")

	# Girando no se acepta nada: son 0,30 s, y cortarlo a medias deja al
	# personaje mirando a un sitio con el sprite de otro.
	if _estado == Estado.GIRO:
		return

	# Soltar la tecla lanza la frenada. Tambien durante el arranque: si no, un
	# toque corto dejaria al personaje 1,4 s andando solo antes de hacer caso.
	if is_zero_approx(direccion):
		_giro_pendiente = 0.0   # soltar cancela el cambio de sentido
		var arrancando := _estado == Estado.ARRANQUE_ANDAR or _estado == Estado.ARRANQUE_CORRER
		if arrancando and _velocidad() <= 0.0:
			# Soltar en la zona muerta del arranque: los pies no se han movido y
			# no hay nada que frenar. La parada empieza a media zancada -- esta
			# hecha para venir del ciclo -- y metida aqui es un fotograma que no
			# encaja con nada. Pasaba con cada doble pulsacion real, que suelta
			# entre toque y toque: arranque f0 -> parada f0,3,4 -> arranque de
			# correr f0, dos saltos de 0,97 y 1,25 pasos. De pie a pie es 0,23.
			_cambiar(Estado.REPOSO)
		elif _estado == Estado.ANDAR:
			_pedir_parada_andar()
		elif _estado == Estado.ARRANQUE_ANDAR:
			_cambiar(Estado.PARADA_ANDAR)
		elif _estado == Estado.CORRER:
			_pedir_parada_correr()
		elif _estado == Estado.ARRANQUE_CORRER:
			_cambiar(Estado.PARADA_CORRER)
	elif _en_movimiento():
		_parada_espera = 0   # volver a pulsar cancela la parada que estaba esperando
		# Cambiar de sentido no puede ser un volteo en seco a toda velocidad.
		# Se pasa por la frenada y se voltea cuando la velocidad ya es cero,
		# que es el momento en que menos se nota. No hay animacion de giro,
		# asi que esto es lo mas parecido que se puede montar con lo que hay.
		if signf(direccion) != _mirando:
			_giro_pendiente = signf(direccion)
			_giro_corriendo = _corriendo()
			_cambiar(Estado.PARADA_CORRER if _corriendo() else Estado.PARADA_ANDAR)
	elif _puede_cortar_salto():
		# Ya ha caido y sigue con la tecla pulsada: sale andando sin esperar a
		# que termine de recomponerse. Aqui no vale mirar solo las pulsaciones,
		# porque si la tecla no se ha soltado no hay ninguna nueva.
		_arrancar("mover_derecha" if direccion > 0.0 else "mover_izquierda", _corria_al_saltar)

	_resolver_giro()

	# El arranque de correr termina antes de que se acabe la animacion, asi que
	# aqui no sirve animation_finished: hay que mirar el fotograma.
	if _estado == Estado.ARRANQUE_CORRER and _sprite.frame >= _ultimo_util():
		_cambiar(Estado.CORRER)
	elif _estado == Estado.ARRANQUE_ANDAR and corte_arranque_andar > 0 and _sprite.frame >= _ultimo_util():
		_cambiar(Estado.ANDAR)

	var velocidad := _velocidad()
	if velocidad > 0.0:
		var paso := velocidad * delta
		position.x += paso * _mirando
		_recorrido += paso
		# Solo los bucles mueven la animacion con la distancia. Arranques y
		# paradas van a fps fijo: ahi el personaje acelera o frena y no hay
		# relacion constante entre lo que avanza y la pose.
		if _estado == Estado.ANDAR or _estado == Estado.CORRER:
			var avance := avance_andar if _estado == Estado.ANDAR else avance_correr
			var n := _sprite.sprite_frames.get_frame_count(_sprite.animation)
			# El epsilon es por la frontera exacta: 192/60 da 3,2 px por tick y el
			# avance es 6,4, o sea 2 ticks justos por fotograma, pero ni 3,2 ni
			# 6,4 son exactos en binario y la suma se queda en 6,3999...; sin el
			# margen ese fotograma dura un tick de mas y el siguiente uno de
			# menos. Correr no lo sufre porque 435/60 = 7,25 y 14,5 si son
			# exactos. Medido: 4 fotogramas descuadrados de cada 107 al andar.
			var fotograma := int(_recorrido / avance + 1e-6) % n
			_sprite.frame = fotograma
			_pisar(fotograma, n)

## Cuanto avanza el cuerpo ahora mismo.
##
## En arranques y paradas no puede ser la velocidad de crucero: la animacion
## empieza con el personaje quieto y acaba parandolo. Si se aplica la velocidad
## entera desde el primer fotograma, el muneco se desplaza antes de dar el paso
## y parece que patina; y si se pone a cero al soltar la tecla, se queda clavado
## mientras la animacion todavia esta frenando.
func _velocidad() -> float:
	match _estado:
		Estado.ANDAR:
			return velocidad_andar
		Estado.CORRER:
			return velocidad_correr
		Estado.ARRANQUE_ANDAR:
			if corte_arranque_andar > 0:
				var k := clampi(_sprite.frame, 0, AVANCE_ARRANQUE_ANDAR.size() - 1)
				return maxf(AVANCE_ARRANQUE_ANDAR[k], _velocidad_suelo)
			return maxf(velocidad_andar * _rampa_subida(quieto_al_arrancar_andar), _velocidad_suelo)
		Estado.ARRANQUE_CORRER:
			if corte_arranque_correr > 0:
				var kc := clampi(_sprite.frame, 0, AVANCE_ARRANQUE_CORRER.size() - 1)
				return maxf(AVANCE_ARRANQUE_CORRER[kc], _velocidad_suelo)
			return maxf(velocidad_correr * _rampa_subida(quieto_al_arrancar_correr), _velocidad_suelo)
		Estado.PARADA_ANDAR:
			var k := clampi(_sprite.frame, 0, FRENADA_ANDAR_PERFIL.size() - 1)
			var base: float = FRENADA_ANDAR_PERFIL[clampi(_parada_entrada, 0, FRENADA_ANDAR_PERFIL.size() - 1)]
			return _frenando_desde * FRENADA_ANDAR_PERFIL[k] / maxf(base, 0.05)
		Estado.PARADA_CORRER:
			return _frenando_desde * _rampa_bajada(frenada_correr)
		Estado.SALTAR:
			var p := _progreso()
			var toca := _aterrizaje()
			if p <= toca:
				return _impulso
			# Al tocar suelo el impulso se va en lo que queda de aterrizaje.
			var resto := maxf(1.0 - toca, 0.001)
			return _impulso * maxf(0.0, 1.0 - (p - toca) / (resto * 0.5))
	return 0.0

## Ultimo fotograma que se usa de la animacion actual. Normalmente el ultimo que
## hay, pero el arranque de correr se corta antes (ver corte_arranque_correr).
func _ultimo_util() -> int:
	var n := _sprite.sprite_frames.get_frame_count(_sprite.animation)
	if _estado == Estado.ARRANQUE_CORRER and corte_arranque_correr > 0:
		return mini(corte_arranque_correr, n - 1)
	if _estado == Estado.ARRANQUE_ANDAR and corte_arranque_andar > 0:
		return mini(corte_arranque_andar, n - 1)
	return n - 1

## 0..1 segun por donde va la animacion de una pasada. Va contra el ultimo
## fotograma UTIL, no contra el ultimo que exista: si no, al cortar el arranque
## la rampa se quedaria a media subida y al entrar en el bucle la velocidad
## pegaria un salto.
func _progreso() -> float:
	var u := _ultimo_util()
	if u <= 0:
		return 1.0
	return clampf(float(_sprite.frame) / float(u), 0.0, 1.0)

## Sube de 0 a 1, pero sin arrancar hasta pasada la parte en que los pies aun
## no se han movido.
func _rampa_subida(zona_quieta: float) -> float:
	var p := _progreso()
	if p <= zona_quieta:
		return 0.0
	return (p - zona_quieta) / (1.0 - zona_quieta)

## Baja de 1 a 0 en la primera parte de la animacion y se queda en 0. No puede
## repartirse por toda la parada: los pies se plantan enseguida y a partir de
## ahi cualquier avance se lee como patinazo.
func _rampa_bajada(tramo: float) -> float:
	if tramo <= 0.0:
		return 0.0
	return maxf(0.0, 1.0 - _progreso() / tramo)

## Soltar la tecla andando: esperar (poco) a un apoyo que case con la parada y
## entrar por el fotograma de la parada mas parecido a la pose actual.
func _pedir_parada_andar() -> void:
	var f := _sprite.frame
	var casa: bool = DIST_PARADA_ANDAR[clampi(f, 0, DIST_PARADA_ANDAR.size() - 1)] <= tolerancia_parada_andar
	if casa or _parada_espera >= espera_parada_andar * 2 or espera_parada_andar <= 0:
		_parada_espera = 0
		var entrada: int = POSE_ANDAR_A_PARADA[clampi(f, 0, POSE_ANDAR_A_PARADA.size() - 1)]
		_cambiar(Estado.PARADA_ANDAR)
		_sprite.frame = entrada
		_parada_entrada = entrada
	else:
		_parada_espera += 1

## Soltar corriendo: esperar a la unica fase que casa con la parada.
func _pedir_parada_correr() -> void:
	var f := _sprite.frame
	var casa: bool = DIST_PARADA_CORRER[clampi(f, 0, DIST_PARADA_CORRER.size() - 1)] <= tolerancia_parada_correr
	if casa or _parada_espera >= espera_parada_correr * 2 or espera_parada_correr <= 0:
		_parada_espera = 0
		_cambiar(Estado.PARADA_CORRER)
	else:
		_parada_espera += 1

func _arrancar(accion: String, corriendo: bool) -> void:
	var hacia := -1.0 if accion == "mover_izquierda" else 1.0
	# Arrancar hacia el otro lado no es arrancar: primero hay que darse la vuelta.
	if giro_activo and hacia != _mirando and _estado != Estado.GIRO:
		_empezar_giro(hacia, corriendo)
		return
	_mirar(hacia)
	# La velocidad que ya llevaba, antes de cambiar de estado.
	#
	# La primera pulsacion de un doble arranca a andar sin remedio: no hay forma
	# de saber que era la primera de un doble hasta que llega la segunda. Lo que
	# si se puede evitar es el escalon de cuando llega. Si el arranque de correr
	# empezase en su fotograma 0, el personaje se pararia en seco -- la rampa de
	# subida vale 0 ahi -- y la animacion volveria a empezar. Medido: con un
	# doble de 0,25 s la velocidad caia de 29,7 a 0 px/s de un tick al
	# siguiente, y andando ya lanzado la caida era de los 229 enteros. Eso es lo
	# que se veia como "arranca a andar, luego corre y fluctua".
	var llevaba := _velocidad()
	var desde_anim := String(_sprite.animation)
	var desde_frame := _sprite.frame
	var nuevo := Estado.ARRANQUE_CORRER if corriendo else Estado.ARRANQUE_ANDAR
	if _estado == nuevo:
		return
	_cambiar(nuevo)
	_enganchar_arranque(llevaba, desde_anim, desde_frame)

## Coloca el arranque en el fotograma cuya rampa ya da la velocidad que se
## llevaba, para que no haya escalon al entrar. Es la inversa de _rampa_subida:
## si la rampa vale (p - zona) / (1 - zona), la p que da una velocidad v es
## zona + (v / crucero) * (1 - zona).
func _enganchar_arranque(llevaba: float, desde_anim: String = "", desde_frame: int = 0) -> void:
	# Saliendo del salto con la tecla pulsada: sigue andando. El cuerpo esta
	# parado (el impulso se apago al tocar suelo) y agachado, asi que la
	# velocidad no dice nada y manda la POSE: POSE_DESDE_SALTO da, para cada
	# sprite del salto desde el que se puede cortar, el fotograma del arranque
	# de andar que mas se le parece. Fuera de la tabla, el arranque desde 0.
	if desde_anim == "saltar" and _estado == Estado.ARRANQUE_ANDAR:
		var i := desde_frame - SALTO_CORTE_DESDE
		if i >= 0 and i < POSE_DESDE_SALTO.size():
			_sprite.frame = POSE_DESDE_SALTO[i]
		return
	if llevaba <= 0.0:
		return
	var corriendo := _estado == Estado.ARRANQUE_CORRER
	if corriendo and corte_arranque_correr > 0 and not (desde_anim in ["arranque_andar", "andar"]):
		for k in range(AVANCE_ARRANQUE_CORRER.size()):
			if AVANCE_ARRANQUE_CORRER[k] >= llevaba:
				_sprite.frame = k
				return
		_sprite.frame = AVANCE_ARRANQUE_CORRER.size() - 1
		return
	if not corriendo and corte_arranque_andar > 0:
		for k in range(AVANCE_ARRANQUE_ANDAR.size()):
			if AVANCE_ARRANQUE_ANDAR[k] >= llevaba:
				_sprite.frame = k
				return
		_sprite.frame = AVANCE_ARRANQUE_ANDAR.size() - 1
		return
	# Viniendo de andar, manda la POSE: ver las tablas arriba. La velocidad que
	# se traia se sostiene aparte para que no haya bajon.
	if corriendo and desde_anim in ["arranque_andar", "andar"]:
		var tabla: Array = POSE_DESDE_ARRANQUE_ANDAR if desde_anim == "arranque_andar" else POSE_DESDE_ANDAR
		if desde_frame >= 0 and desde_frame < tabla.size():
			_sprite.frame = tabla[desde_frame]
			_velocidad_suelo = llevaba
			return
	var crucero := velocidad_correr if corriendo else velocidad_andar
	var zona := quieto_al_arrancar_correr if corriendo else quieto_al_arrancar_andar
	var n := _sprite.sprite_frames.get_frame_count(_sprite.animation)
	if n <= 1 or crucero <= 0.0:
		return
	var p := zona + clampf(llevaba / crucero, 0.0, 1.0) * (1.0 - zona)
	_sprite.frame = clampi(int(round(p * (n - 1))), 0, n - 1)

func _puede_saltar() -> bool:
	return _estado != Estado.SALTAR or not _salto_bloquea()

## Durante el vuelo no se acepta nada; despues de caer, si.
func _salto_bloquea() -> bool:
	return _estado == Estado.SALTAR and _progreso() < _interrumpible()

## Los dos saltos son animaciones distintas con tiempos distintos.
func _aterrizaje() -> float:
	return aterrizaje_correr if _sprite.animation == "salto_correr" else aterrizaje

func _interrumpible() -> float:
	return salto_correr_interrumpible if _sprite.animation == "salto_correr" else salto_interrumpible

func _en_movimiento() -> bool:
	if _estado == Estado.ANDAR or _estado == Estado.ARRANQUE_ANDAR:
		return true
	return _estado == Estado.CORRER or _estado == Estado.ARRANQUE_CORRER

func _corriendo() -> bool:
	return _estado == Estado.CORRER or _estado == Estado.ARRANQUE_CORRER

## Voltea y arranca al otro lado en cuanto la frenada ha dejado el cuerpo quieto.
func _resolver_giro() -> void:
	if is_zero_approx(_giro_pendiente):
		return
	if _estado != Estado.PARADA_ANDAR and _estado != Estado.PARADA_CORRER:
		_giro_pendiente = 0.0
		return
	if _estado == Estado.PARADA_ANDAR:
		if _velocidad() > _frenando_desde * 0.3:
			return
	elif _progreso() < frenada_correr:
		return
	var hacia := _giro_pendiente
	var corriendo := _giro_corriendo
	_giro_pendiente = 0.0
	if giro_activo:
		_empezar_giro(hacia, corriendo)
		return
	_mirar(hacia)
	_cambiar(Estado.ARRANQUE_CORRER if corriendo else Estado.ARRANQUE_ANDAR)

## Entra en la animacion de giro. El sprite NO se voltea aqui: se voltea al
## terminar, en _al_terminar. Durante el giro se conserva el flip_h que hubiera,
## que es lo que hace que la misma animacion valga para los dos sentidos.
func _empezar_giro(hacia: float, corriendo: bool) -> void:
	_giro_destino = hacia
	_giro_corriendo = corriendo
	_cambiar(Estado.GIRO)

## Estados desde los que una pulsacion de direccion arranca el movimiento.
func _puede_arrancar() -> bool:
	if _estado == Estado.GIRO:
		return false
	if _estado == Estado.REPOSO:
		return true
	if _estado == Estado.PARADA_ANDAR or _estado == Estado.PARADA_CORRER:
		return true
	return _puede_cortar_salto()

func _puede_cortar_salto() -> bool:
	return _estado == Estado.SALTAR and not _salto_bloquea()

## Volteo instantaneo. Todas las animaciones son de perfil puro: no hay ni un
## fotograma frontal ni de tres cuartos, asi que el cambio de sentido salta de
## un perfil al otro sin nada en medio y se nota. Disimularlo deformando el
## sprite (estrecharlo hasta casi nada y devolverlo ya volteado) se probo y no
## cuela: con una silueta tan marcada -- barba, capucha, capa -- se lee como un
## fallo, no como un giro. La solucion es una animacion de giro de verdad, unos
## pocos fotogramas de perfil a frontal; ver docs/sprites_magnus.md.
func _mirar(direccion: float) -> void:
	if is_zero_approx(direccion):
		return
	_mirando = signf(direccion)
	_sprite.flip_h = _mirando < 0.0

func _cambiar(nuevo: Estado) -> void:
	if _estado == nuevo:
		return
	# La frenada tiene que partir de la velocidad que llevaba de verdad, no de
	# la de crucero. Si no, un toque corto -- en el que apenas ha acelerado --
	# entra a frenar a toda velocidad y el personaje pega un tiron hacia
	# delante en vez de quedarse casi donde estaba.
	if nuevo == Estado.PARADA_ANDAR or nuevo == Estado.PARADA_CORRER:
		_frenando_desde = _velocidad()
	_estado = nuevo
	match nuevo:
		Estado.REPOSO:          _poner("reposo")
		Estado.ARRANQUE_ANDAR:  _poner("arranque_andar")
		Estado.ANDAR:           _poner("andar")
		Estado.PARADA_ANDAR:    _poner("parada_andar")
		Estado.ARRANQUE_CORRER: _poner("arranque_correr")
		Estado.CORRER:          _poner("correr")
		Estado.PARADA_CORRER:   _poner("parada_correr")
		Estado.SALTAR:          _poner("salto_correr" if _corria_al_saltar else "saltar")
		Estado.GIRO:            _poner("giro")
		Estado.CAYENDO:         _poner("cayendo")
		Estado.CAIDA:           _poner("caida")
		Estado.TUMBADO:         _poner("tumbado")
		Estado.LEVANTARSE:      _poner("levantarse")

func _en_cinematica() -> bool:
	return _estado in CINEMATICA

## Cinematica de entrada. Coloca al personaje caida_altura px por encima de
## donde esta (la marca de suelo de la escena) y lo deja caer con aceleracion
## hasta volver ahi. El resto lo encadena _al_terminar:
##   cayendo (bucle, mientras baja) -> caida (impacto) -> tumbado (espera) ->
##   levantarse -> reposo, y ahi se emite cinematica_terminada.
## El fotograma 7 de cayendo (el 32 del video) es el que enlaza con caida sin
## salto, asi que el bucle se arranca por el fotograma que, tras caida_duracion
## a sus fps, deja el impacto justo ahi. Si la duracion se cambia en el editor
## sigue cuadrando: se calcula, no esta cocido.
func caer_desde_arriba() -> void:
	var suelo := position.y
	position.y = suelo - caida_altura
	_mirar(1.0)
	_cambiar(Estado.CAYENDO)
	var n := _sprite.sprite_frames.get_frame_count("cayendo")
	var fps := _sprite.sprite_frames.get_animation_speed("cayendo")
	_sprite.frame = posmod(7 - int(round(caida_duracion * fps)), n)
	var tw := create_tween()
	tw.tween_property(self, "position:y", suelo, caida_duracion) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.finished.connect(func() -> void:
		if _estado == Estado.CAYENDO:
			_cambiar(Estado.CAIDA))

## Andar y correr los mueve _physics_process con la distancia recorrida, asi que
## el nodo NO debe reproducirlos: se le pone la animacion y se le para.
##
## Si se le deja reproduciendo, hay dos cosas moviendo el fotograma a la vez. El
## nodo avanza por su reloj en _process -- 0,4 fotogramas por tick de fisica a
## 24 fps y 60 Hz, mas si la pantalla va mas rapida -- y el siguiente tick lo
## devuelve al que toca por distancia. El sprite salta adelante y atras entre dos
## poses, y como los poligonos de la tunica cambian de un fotograma al siguiente,
## se ve como si al personaje le cambiase la ropa mientras corre.
##
## El resto de animaciones si van a fps fijo y las reproduce el nodo.
const MANUALES := ["andar", "correr"]

## Por que fotograma del arranque de correr entrar segun la pose que se traiga.
## Cuando se pide correr ya andando -- o con la segunda pulsacion de un doble,
## que llega con el arranque de andar ya en marcha -- entrar por el fotograma
## que da la velocidad que se lleva (el 14) deja la pose a 2,2-2,8 pasos de
## cualquier fotograma de andar: mas que el rebote del brazo que se quito. Estas
## tablas dan, para cada fotograma de origen, el fotograma del arranque de
## correr que MAS SE PARECE (silueta y color, medido): media 1,05 y 1,34 pasos.
## La velocidad no se pierde por entrar antes: _velocidad_suelo la sostiene
## hasta que la rampa la alcanza.
## Velocidad del nodo en cada fotograma del arranque de andar, en px/s de hoja.
## Sale del avance real del pie plantado respecto al eje del tronco, medido sobre
## 04_limpios (master px por fotograma: 0, 0.7, 2.2, 2.6, 4.6, 6.3, 7.1, 8.2, 8.3,
## 9.9, 10.3, 12.1, 11.3, 11.0, 11.7, 11.7, 13.5, 12.6, 12.6), a media escala y
## a los 30 fps a los que va la animacion: v = master/2 * 30. El ultimo da 189,
## contra los 192 del ciclo. Con la recta antigua el nodo hacia 256 px master en
## el arranque y los pies 292, y ademas mal repartidos.
## Lo mismo para correr, y aqui el error era mayor y al reves. Midiendo el pie
## plantado: 6 fotogramas quieto, el 6 avanza 5,4 px master, el 7 dieciseis, y del
## 8 en adelante YA VA A CRUCERO (32, 31, 26, 25, 29, 33...). La rampa recta daba
## 5,7 en el fotograma 8: las piernas corriendo a tope con el cuerpo al 20 %, o
## sea el pie resbalando hacia atras todo el arranque. En px/s de hoja.
const AVANCE_ARRANQUE_CORRER := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 81.0, 240.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0]

const AVANCE_ARRANQUE_ANDAR := [0.0, 10.5, 33.0, 39.0, 69.0, 94.5, 106.5, 123.0, 124.5, 148.5, 154.5, 181.5, 169.5, 165.0, 175.5, 175.5, 189.0, 189.0, 189.0]

const POSE_DESDE_ARRANQUE_ANDAR := [0, 0, 0, 0, 0, 3, 4, 4, 4, 4, 4, 6, 6, 6, 6, 8, 8, 8, 8, 8, 8, 7, 6, 6, 6, 6, 5, 5, 5, 5, 5, 7, 7, 5]
## PARAR DE ANDAR. La parada esta grabada desde UNA sola fase de la zancada: sus
## fotogramas casan con el ciclo alrededor de f26-f29 (y f3), a >= 1,1 pasos, y la
## otra mitad del ciclo no tiene equivalente. Entrando siempre por su fotograma 0
## el salto de pose iba de 1,1 a 3,8 pasos segun donde soltaras (media 2,4): el
## "efecto raro al pararse". Lo que hacen los juegos con una sola parada es dejar
## que el personaje TERMINE EL PASO hasta un apoyo que case: aqui, como mucho
## `espera_parada_andar` fotogramas del ciclo (10 = 0,33 s; 5 de media).
## PARADA_ANDAR_BUENOS son los fotogramas del ciclo desde los que la entrada
## queda a <= 1,3 pasos; POSE_ANDAR_A_PARADA dice por que fotograma de la parada
## entrar desde cada fotograma del ciclo.
## Distancia de pose, en pasos normales, al entrar en la parada desde cada
## fotograma del ciclo. Medido sobre los sprites (silueta y color).
const DIST_PARADA_ANDAR := [1.7, 1.5, 1.3, 1.3, 1.7, 1.8, 1.8, 2.0, 2.1, 2.4, 2.5, 2.4, 2.4, 2.2, 2.3, 2.4, 2.7, 3.3, 3.2, 2.9, 2.8, 2.3, 2.2, 1.7, 1.3, 1.1, 1.1, 1.2, 1.1, 1.1, 1.2, 1.4, 1.6, 1.8]
const DIST_PARADA_CORRER := [1.7, 1.7, 1.7, 1.5, 1.5, 1.4, 1.4, 1.6, 1.6, 1.7, 1.6, 1.8, 2.1, 2.1, 2.1, 2.1, 1.9, 1.9, 2.0, 1.9, 1.5, 1.3, 1.2, 1.6]
const POSE_ANDAR_A_PARADA := [5, 5, 4, 6, 1, 6, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 3, 3, 4, 4, 4, 5, 5]
## Y el nodo no frena en seco: el pie plantado de la parada sigue avanzando 3-6 px
## master por fotograma durante 14 fotogramas antes de plantarse del todo. Este es
## el perfil medido, como fraccion de la velocidad de andar en cada fotograma de la
## parada; la velocidad que se traia se escala para empezar exacta en el fotograma
## de entrada.
const FRENADA_ANDAR_PERFIL := [1.0, 0.95, 0.85, 0.75, 0.65, 0.55, 0.48, 0.42, 0.40, 0.40, 0.42, 0.40, 0.36, 0.32, 0.27, 0.20, 0.14, 0.10, 0.08, 0.05, 0.0]

const POSE_DESDE_ANDAR := [5, 5, 6, 5, 6, 4, 6, 6, 6, 6, 4, 6, 4, 8, 8, 8, 8, 8, 7, 8, 7, 6, 6, 6, 6, 7, 4, 4, 5, 5, 6, 6, 5, 5]

## Por que fotograma del arranque de andar seguir cuando el salto (saltar) se
## corta con la tecla pulsada. El indice 0 es el sprite 60 del salto (indice
## SALTO_CORTE_DESDE, el primero en que salto_interrumpible deja cortar); tiene
## que ir a la par con ese export. Medido por silueta y color contra los 34 del
## arranque: del sprite 60 al 64 aun esta medio agachado y lo mas parecido es
## un paso ya lanzado (f20-24, 0,043-0,048); del 65 al 70 esta de pie y lo mas
## parecido es el arranque recien empezado (f4-5, 0,025-0,035).
const SALTO_CORTE_DESDE := 59
const POSE_DESDE_SALTO := [21, 20, 21, 23, 24, 5, 5, 5, 5, 4, 4]

func _poner(nombre: String) -> void:
	_recorrido = 0.0
	_ultimo_fotograma = -1
	_velocidad_suelo = 0.0
	_parada_entrada = 0
	if nombre in MANUALES:
		var andando := nombre == "andar"
		var entrada := entrada_andar if andando else entrada_correr
		# El recorrido arranca ya colocado en esa entrada, no a cero: es lo que
		# mantiene la cuenta de distancia y el fotograma diciendo lo mismo.
		_recorrido = float(entrada) * (avance_andar if andando else avance_correr)
		_sprite.animation = nombre
		_sprite.stop()
		_sprite.frame = entrada
		# Y la pisada se da por vista, o al entrar sonarian de golpe todos los
		# contactos entre el fotograma 0 y la entrada.
		_ultimo_fotograma = entrada
	else:
		_sprite.play(nombre)
	_sprite.offset = offset_salto_correr if nombre == "salto_correr" else offset_comun
	_respirar(nombre == "reposo")

## Suena la pisada si entre el ultimo fotograma puesto y este se ha pasado por un
## sprite de contacto. Se mira el tramo entero, no solo el fotograma actual, por
## si un tick de fisica salta mas de un sprite, que pasa en cuanto se corre
## rapido: a 416 px/s y 14,5 px por fotograma toca cambiar 28,7 veces por
## segundo, y basta una bajada de framerate para saltarse un contacto.
func _pisar(fotograma: int, n: int) -> void:
	if fotograma == _ultimo_fotograma:
		return
	var golpes: Dictionary = PISADAS.get(String(_sprite.animation), {})
	var avanzados := (fotograma - _ultimo_fotograma + n) % n
	for k in range(1, avanzados + 1):
		var i := (_ultimo_fotograma + k) % n
		if golpes.has(i):
			_pasos.stream = golpes[i]
			_pasos.volume_db = pasos_db
			_pasos.pitch_scale = randf_range(1.0 - pasos_variacion, 1.0 + pasos_variacion)
			_pasos.play()
	_ultimo_fotograma = fotograma

## Arranca o apaga la respiracion con un fundido corto: cortarla en seco al
## empezar a andar da un chasquido.
func _respirar(activa: bool) -> void:
	if _fundido:
		_fundido.kill()
	# Apagar lo que ya esta apagado no es nada: sin esto se creaba un tween
	# vacio y Godot lo avisaba como error en cada cambio de animacion de la
	# cinematica de entrada, que encadena varias sin pasar por el reposo.
	if not activa and not _respiracion.playing:
		return
	_fundido = create_tween()
	if activa:
		if not _respiracion.playing:
			_respiracion.volume_db = -40.0
			_respiracion.play()
		_fundido.tween_property(_respiracion, "volume_db", respiracion_db, 0.4)
	elif _respiracion.playing:
		_fundido.tween_property(_respiracion, "volume_db", -40.0, 0.25)
		_fundido.tween_callback(_respiracion.stop)

## Los bucles no emiten esta senal; solo llegan aqui arranques, paradas y salto.
func _al_terminar() -> void:
	match _estado:
		Estado.ARRANQUE_ANDAR:  _cambiar(Estado.ANDAR)
		Estado.ARRANQUE_CORRER: _cambiar(Estado.CORRER)
		Estado.PARADA_ANDAR, Estado.PARADA_CORRER, Estado.SALTAR:
			_cambiar(Estado.REPOSO)
		Estado.CAIDA:
			# Tumbado es un solo fotograma en bucle: no avisa de nada. La espera
			# la pone un temporizador, y se comprueba el estado al volver por si
			# algo lo hubiera sacado de ahi mientras tanto.
			_cambiar(Estado.TUMBADO)
			get_tree().create_timer(tumbado_espera).timeout.connect(func() -> void:
				if _estado == Estado.TUMBADO:
					_cambiar(Estado.LEVANTARSE))
		Estado.LEVANTARSE:
			_cambiar(Estado.REPOSO)
			cinematica_terminada.emit()
		Estado.GIRO:
			# Ahora si: el ultimo fotograma del giro es el perfil del otro lado,
			# que es exactamente el sprite de siempre volteado, asi que voltear
			# aqui no se nota.
			_mirar(_giro_destino)
			var sigue := Input.get_axis("mover_izquierda", "mover_derecha")
			if is_zero_approx(sigue) or signf(sigue) != _mirando:
				_cambiar(Estado.REPOSO)
			else:
				_cambiar(Estado.ARRANQUE_CORRER if _giro_corriendo else Estado.ARRANQUE_ANDAR)
