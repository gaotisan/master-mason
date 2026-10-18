extends Node
## Musica de la pantalla de titulo. Es autoload por lo mismo que
## wind_ambience.gd: asi los fundidos no dependen de que la escena siga viva, y
## el tema puede acabar de apagarse mientras la pantalla ya se esta yendo.
##
## Solo suena en el titulo, y se apaga del todo antes del negro en vez de dar
## paso a otra cosa: tras el negro manda el viento, que viene sonando desde el
## sarcofago y sigue despues del cambio de escena. La hojarasca tiene su propia
## musica de fondo, que entra mas tarde, al levantarse el peregrino
## (caida_hojarasca.gd, musica_db).
##
## LA DEL CAMINO DEL BOSQUE (2026-10-16; el usuario: que al coger el baculo
## cambie a la musica de la escena siguiente, "y asi el corte de camara ya no
## conlleva cambio de musica y da mas continuidad"). Entra en la hojarasca al
## coger el baculo y sigue sonando por los cortes entre la hojarasca y el camino
## sin empezar de nuevo; cada escena solo la lleva a su nivel (lo que marca el
## sitio es el viento: en la hojarasca sopla, en el bosque no).
##
## Las escenas solo piden los cambios (empezar_titulo, apagar_titulo); los
## volumenes y los tweens se llevan aqui.

const TITULO := preload("res://assets/audio/musica_titulo.ogg")
const CAMINO := preload("res://assets/audio/musica_camino_bosque.ogg")
## Nivel al que se considera apagado. Por debajo no se oye nada, y es donde
## arrancan y acaban los fundidos.
const SILENCIO := -60.0

var _titulo: AudioStreamPlayer
var _tw_titulo: Tween
var _camino: AudioStreamPlayer
var _tw_camino_db: Tween
var _tw_camino_nivel: Tween

## Nivel de la del camino (dB), sin la entrada ni el extra.
var camino_db := SILENCIO:
	set(v):
		camino_db = v
		_poner_camino()
## Extra momentaneo de la del camino (el claro de sol de camino_bosque.gd).
var camino_extra_db := 0.0:
	set(v):
		camino_extra_db = v
		_poner_camino()
## Entrada y salida de la del camino, 0..1 en lineal de amplitud (en dB
## arrancaria de golpe).
var camino_nivel := 0.0:
	set(v):
		camino_nivel = v
		_poner_camino()

func _ready() -> void:
	_titulo = _nuevo_reproductor(TITULO)
	var pista := CAMINO.duplicate() as AudioStreamOggVorbis
	pista.loop = true
	_camino = _nuevo_reproductor(pista)

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

## Si el tema del titulo esta sonando (el menu del titulo lo vuelve a poner si
## se acaba).
func titulo_sonando() -> bool:
	return _titulo.playing

## Apaga el tema del titulo y lo para. Se llama al empezar a entrar por el
## cristal, para que el silencio llegue antes que el negro.
func apagar_titulo(duracion: float) -> void:
	_tw_titulo = _fundir(_titulo, _tw_titulo, SILENCIO, duracion, true)

## La del camino a db en entrada s. Si no sonaba, arranca desde el silencio
## (tras retraso s); si ya sonaba (viene de la otra escena), sigue por donde iba
## y solo cambia de nivel.
func sonar_camino(db: float, entrada: float, retraso: float = 0.0) -> void:
	if not _camino.playing:
		camino_db = db
		camino_nivel = 0.0
		_camino.play()
	elif _tw_camino_db and _tw_camino_db.is_valid():
		_tw_camino_db.kill()
	if camino_db != db:
		_tw_camino_db = create_tween()
		_tw_camino_db.tween_property(self, "camino_db", db, entrada).set_trans(Tween.TRANS_SINE)
	if _tw_camino_nivel and _tw_camino_nivel.is_valid():
		_tw_camino_nivel.kill()
	_tw_camino_nivel = create_tween()
	_tw_camino_nivel.tween_property(self, "camino_nivel", 1.0, entrada * (1.0 - camino_nivel)).set_delay(retraso)

## Apaga la del camino y la para. Con duracion <= 0, de golpe.
func apagar_camino(duracion: float) -> void:
	if _tw_camino_nivel and _tw_camino_nivel.is_valid():
		_tw_camino_nivel.kill()
	if duracion <= 0.0 or not _camino.playing:
		camino_nivel = 0.0
		_camino.stop()
		return
	_tw_camino_nivel = create_tween()
	_tw_camino_nivel.tween_property(self, "camino_nivel", 0.0, duracion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tw_camino_nivel.tween_callback(_camino.stop)

func camino_sonando() -> bool:
	return _camino.playing

func _poner_camino() -> void:
	if _camino:
		_camino.volume_db = camino_db + camino_extra_db + linear_to_db(maxf(camino_nivel, 0.001))

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
