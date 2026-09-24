extends Node
## Musica de la pantalla de titulo. Es autoload por lo mismo que
## wind_ambience.gd: asi los fundidos no dependen de que la escena siga viva, y
## el tema puede acabar de apagarse mientras la pantalla ya se esta yendo.
##
## Solo suena en el titulo. En el juego no hay musica: manda el viento, que
## viene sonando desde el sarcofago y sigue despues del cambio de escena. Por eso
## el tema se apaga del todo antes del negro en vez de dar paso a otra cosa.
##
## Las escenas solo piden los cambios (empezar_titulo, apagar_titulo); los
## volumenes y los tweens se llevan aqui.

const TITULO := preload("res://assets/audio/musica_titulo.ogg")
## Nivel al que se considera apagado. Por debajo no se oye nada, y es donde
## arrancan y acaban los fundidos.
const SILENCIO := -60.0

var _titulo: AudioStreamPlayer
var _tw_titulo: Tween

func _ready() -> void:
	_titulo = _nuevo_reproductor(TITULO)

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
