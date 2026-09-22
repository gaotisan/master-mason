extends Node2D
## Magnus. La posicion del nodo es el punto donde pisa: el sprite lleva un
## offset de -165 para que la linea de suelo de la casilla caiga en el origen.
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
@export var velocidad_andar: float = 229.0
@export var velocidad_correr: float = 416.0
## Px recorridos por fotograma de animacion. Con esto el ciclo avanza segun lo
## que se anda, no segun el reloj, y los pies no patinan a ninguna velocidad.
## Medidos siguiendo el pie plantado respecto al eje del tronco, fotograma a
## fotograma, sobre las mascaras de 04_limpios: 12,8 px de master al andar y
## 28,9 al correr, que a media escala son los de aqui. No vale deducirlos de la
## zancada ni de la velocidad: asi salian 9,5 y 17,3, el cuerpo recorria un 48%
## mas de lo que decian las piernas y por eso se deslizaba.
@export var avance_andar: float = 6.4
@export var avance_correr: float = 14.5
## Margen para que dos pulsaciones cuenten como doble y arranque a correr.
@export var doble_pulsacion: float = 0.30
## Fraccion del arranque en la que el personaje todavia no ha movido los pies.
## Medido sobre los sprites: 2 fotogramas de 34 al andar, 3 de 38 al correr.
@export var quieto_al_arrancar_andar: float = 0.06
@export var quieto_al_arrancar_correr: float = 0.08
## Fraccion de la parada en la que el cuerpo frena de verdad. El resto de la
## animacion es el abrigo asentandose, con los pies ya plantados: si el nodo
## sigue avanzando ahi, parece una cinta mecanica.
## Medido siguiendo el pie respecto al cuerpo: se planta en 5 fotogramas de 21
## al andar y en 3 de 39 al correr.
@export var frenada_andar: float = 0.25
@export var frenada_correr: float = 0.10
## Momento del salto en que toca el suelo, como fraccion de la animacion. A
## partir de ahi el impulso que llevaba se apaga. Medido siguiendo la altura
## sobre el suelo: aterriza en el fotograma 46 de 75.
@export var aterrizaje: float = 0.62
## A partir de aqui el salto se puede cortar con otra tecla. Sin esto, la
## recuperacion deja al personaje 0,4 s sin responder despues de haber caido.
@export var salto_interrumpible: float = 0.72
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
			  ARRANQUE_CORRER, CORRER, PARADA_CORRER, SALTAR }

var _estado: Estado = Estado.REPOSO
var _mirando := 1.0          # 1 derecha, -1 izquierda
var _recorrido := 0.0        # para mover la animacion con la distancia
var _impulso := 0.0          # velocidad que llevaba al despegar, se conserva en el aire
var _corria_al_saltar := false
var _frenando_desde := 0.0   # velocidad que llevaba al empezar a frenar
var _giro_pendiente := 0.0   # hacia donde hay que girar cuando acabe de frenar
var _giro_corriendo := false
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
	var direccion := Input.get_axis("mover_izquierda", "mover_derecha")

	# Soltar la tecla lanza la frenada. Tambien durante el arranque: si no, un
	# toque corto dejaria al personaje 1,4 s andando solo antes de hacer caso.
	if is_zero_approx(direccion):
		_giro_pendiente = 0.0   # soltar cancela el cambio de sentido
		if _estado == Estado.ANDAR or _estado == Estado.ARRANQUE_ANDAR:
			_cambiar(Estado.PARADA_ANDAR)
		elif _estado == Estado.CORRER or _estado == Estado.ARRANQUE_CORRER:
			_cambiar(Estado.PARADA_CORRER)
	elif _en_movimiento():
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
			var fotograma := int(_recorrido / avance) % n
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
			return velocidad_andar * _rampa_subida(quieto_al_arrancar_andar)
		Estado.ARRANQUE_CORRER:
			return velocidad_correr * _rampa_subida(quieto_al_arrancar_correr)
		Estado.PARADA_ANDAR:
			return _frenando_desde * _rampa_bajada(frenada_andar)
		Estado.PARADA_CORRER:
			return _frenando_desde * _rampa_bajada(frenada_correr)
		Estado.SALTAR:
			var p := _progreso()
			if p <= aterrizaje:
				return _impulso
			# Al tocar suelo el impulso se va en lo que queda de aterrizaje.
			var resto := maxf(1.0 - aterrizaje, 0.001)
			return _impulso * maxf(0.0, 1.0 - (p - aterrizaje) / (resto * 0.5))
	return 0.0

## 0..1 segun por donde va la animacion de una pasada.
func _progreso() -> float:
	var n := _sprite.sprite_frames.get_frame_count(_sprite.animation)
	if n <= 1:
		return 1.0
	return float(_sprite.frame) / float(n - 1)

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

func _arrancar(accion: String, corriendo: bool) -> void:
	_mirar(-1.0 if accion == "mover_izquierda" else 1.0)
	_cambiar(Estado.ARRANQUE_CORRER if corriendo else Estado.ARRANQUE_ANDAR)

func _puede_saltar() -> bool:
	return _estado != Estado.SALTAR or not _salto_bloquea()

## Durante el vuelo no se acepta nada; despues de caer, si.
func _salto_bloquea() -> bool:
	return _estado == Estado.SALTAR and _progreso() < salto_interrumpible

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
	var tramo := frenada_correr if _estado == Estado.PARADA_CORRER else frenada_andar
	if _progreso() < tramo:
		return
	var hacia := _giro_pendiente
	var corriendo := _giro_corriendo
	_giro_pendiente = 0.0
	_mirar(hacia)
	_cambiar(Estado.ARRANQUE_CORRER if corriendo else Estado.ARRANQUE_ANDAR)

## Estados desde los que una pulsacion de direccion arranca el movimiento.
func _puede_arrancar() -> bool:
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
		Estado.SALTAR:          _poner("saltar")

func _poner(nombre: String) -> void:
	_recorrido = 0.0
	_ultimo_fotograma = -1
	_sprite.play(nombre)
	_respirar(nombre == "reposo")

## Suena la pisada si entre el ultimo fotograma puesto y este se ha pasado por un
## sprite de contacto. Se mira el tramo entero, no solo el fotograma actual, por
## si un tick de fisica salta mas de un sprite. No se usa frame_changed porque
## el AnimatedSprite2D tambien mueve el fotograma por su cuenta entre ticks y
## se colarian pisadas dobles.
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
