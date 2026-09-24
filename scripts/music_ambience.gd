extends Node
## Musica de la intro y del juego. Gemela de wind_ambience.gd y por el mismo
## motivo: al ser autoload no la toca el cambio de escena, asi que los fundidos
## pueden cruzar de la pantalla de titulo al juego sin que se corte nada.
##
## Los dos temas NO se solapan. El del titulo se apaga mientras la camara se
## mete por el cristal y llega a silencio antes del cambio de escena; el fondo
## del juego entra despues, ya en negro y mas bajo. Cruzarlos se probo y se
## notaba el corte: los dos temas comparten material, y oirlos a la vez unos
## segundos suena a que se ha cambiado de pista, no a que el sitio se aleja.
## Ese hueco de negro y viento solo es justo lo que separa una escena de la otra.
##
## Son dos reproductores y no uno porque un AudioStreamPlayer solo tiene un
## stream, y el del titulo tiene que poder quedarse parado con su posicion.
##
## Las escenas solo piden los cambios (empezar_titulo, apagar_titulo,
## asegurar_fondo); los volumenes y los tweens se llevan aqui.

const TITULO := preload("res://assets/audio/musica_titulo.ogg")
## El de fondo suena en bucle durante todo el juego. Se le quitaron la entrada
## larga (24 s subiendo desde -39 dB, que se comian el principio de la partida)
## y el fundido final, y el empalme va cruzado sobre si mismo a potencia
## constante, asi que da la vuelta sin bajon ni chasquido. El bucle se activa en
## su .import, igual que el del viento: desde aqui no se puede, GDScript no deja
## tocar una propiedad de una constante.
const FONDO := preload("res://assets/audio/musica_fondo.ogg")

## Nivel al que se considera apagado. Por debajo no se oye nada, y es donde
## arrancan y acaban los fundidos.
const SILENCIO := -60.0

var _titulo: AudioStreamPlayer
var _fondo: AudioStreamPlayer
var _tw_titulo: Tween
var _tw_fondo: Tween

func _ready() -> void:
	_titulo = _nuevo_reproductor(TITULO)
	_fondo = _nuevo_reproductor(FONDO)

func _nuevo_reproductor(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = SILENCIO
	add_child(p)
	return p

## Arranca el tema del titulo subiendo desde el silencio. "desde" adelanta la
## pista: el tema empieza ya con material desde el segundo cero y su momento mas
## fuerte cae sobre 1,0 s, asi que moviendo esto se coloca ese momento donde
## interese respecto a las letras de los creditos, que se encienden entre 0,7 y
## 2,4 s. Y el fundido de entrada conviene que sea corto por lo mismo: con uno
## largo, ese primer golpe llega cuando la musica todavia no se oye.
func empezar_titulo(db: float, fundido: float, desde: float = 0.0) -> void:
	_titulo.volume_db = SILENCIO
	_titulo.play(desde)
	_tw_titulo = _fundir(_titulo, _tw_titulo, db, fundido, false)

## Apaga el tema del titulo y lo para. Se llama al empezar a entrar por el
## cristal, para que el silencio llegue antes que el negro.
func apagar_titulo(duracion: float) -> void:
	_tw_titulo = _fundir(_titulo, _tw_titulo, SILENCIO, duracion, true)

## Pone el fondo del juego si no venia sonando ya, opcionalmente tras una espera.
## La espera es la que deja respirar el negro entre el titulo y el personaje; y
## que sea "asegurar" y no "empezar" permite lanzar una escena del juego suelta
## desde el editor y que tambien suene.
func asegurar_fondo(db: float, fundido: float, espera: float = 0.0) -> void:
	if _fondo.playing:
		return
	_fondo.volume_db = SILENCIO
	_fondo.play()
	if _tw_fondo and _tw_fondo.is_valid():
		_tw_fondo.kill()
	_tw_fondo = create_tween()
	if espera > 0.0:
		_tw_fondo.tween_interval(espera)
	_tw_fondo.tween_property(_fondo, "volume_db", db, maxf(fundido, 0.01)).set_trans(Tween.TRANS_SINE)

## Lleva lo que este sonando al silencio y lo para.
func parar(duracion: float) -> void:
	_tw_titulo = _fundir(_titulo, _tw_titulo, SILENCIO, duracion, true)
	_tw_fondo = _fundir(_fondo, _tw_fondo, SILENCIO, duracion, true)

## Fundido de un reproductor. Con duracion <= 0 cambia de golpe. Si parar_al_final
## esta puesto, el reproductor se detiene al llegar: un AudioStreamPlayer a -60 dB
## sigue consumiendo y sigue avanzando por la pista.
func _fundir(p: AudioStreamPlayer, tw: Tween, db: float, duracion: float, parar_al_final: bool) -> Tween:
	if tw and tw.is_valid():
		tw.kill()
	if duracion <= 0.0:
		p.volume_db = db
		if parar_al_final:
			p.stop()
		return null
	var nuevo := create_tween()
	nuevo.tween_property(p, "volume_db", db, duracion).set_trans(Tween.TRANS_SINE)
	if parar_al_final:
		nuevo.tween_callback(p.stop)
	return nuevo
