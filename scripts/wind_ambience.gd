extends AudioStreamPlayer
## Viento de fondo unico para toda la intro.
##
## Al ser autoload no lo toca el cambio de escena: el sarcofago y la pantalla de
## titulo comparten la misma reproduccion, asi que el viento no se corta ni se
## reinicia al pasar de una a otra. Las escenas solo mueven su volumen.

const WIND := preload("res://assets/audio/viento_cabana.ogg")

## Nivel base. La pantalla de titulo suma sus rachas por encima con gust_db.
var base_db := -5.0:
	set(v):
		base_db = v
		_apply()

## Extra momentaneo de las rachas, aparte del nivel base.
var gust_db := 0.0:
	set(v):
		gust_db = v
		_apply()

var _fade: Tween

func _ready() -> void:
	stream = WIND
	volume_db = base_db
	play()

## Lleva el viento a otro nivel sin saltos. Con duration <= 0 cambia de golpe.
func fade_to(db: float, duration: float) -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	if duration <= 0.0:
		base_db = db
		return
	_fade = create_tween()
	_fade.tween_property(self, "base_db", db, duration).set_trans(Tween.TRANS_SINE)

func _apply() -> void:
	volume_db = base_db + gust_db
