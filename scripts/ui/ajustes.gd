class_name Ajustes
extends RefCounted
## Las opciones del jugador (2026-10-17): volumen general, pantalla completa e
## idioma (2026-10-18).
## Se guardan aparte de la partida (user://ajustes.json) y se aplican al arrancar
## (GlobalExit, scripts/main.gd) y al cambiarlas en el menu de opciones.
##
## Por ahora el volumen es uno solo, el del bus Master: separar musica, efectos
## y ambiente pide que cada sonido vaya a su bus, y eso esta por hacer.

const ARCHIVO := "user://ajustes.json"

## Los idiomas del juego, con su nombre en su propio idioma (asi sale en
## Opciones). Los textos estan en textos/*.csv, una columna por idioma (ver
## textos/LEEME.md); Godot los importa a textos/<fichero>.<idioma>.translation.
const IDIOMAS := {"es": "Español", "en": "English"}
const TEXTOS := ["interfaz", "pensamientos"]

## 0..1, en pasos de PASO_VOLUMEN.
static var volumen := 1.0
static var pantalla_completa := true
## "" = el del sistema (el de Windows si es uno de IDIOMAS; si no, ingles). Se
## queda en "" hasta que el jugador elija uno en Opciones.
static var idioma := ""
static var _traducciones := false

const PASO_VOLUMEN := 0.1


static func cargar() -> void:
	if FileAccess.file_exists(ARCHIVO):
		var f := FileAccess.open(ARCHIVO, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f else null
		if d is Dictionary:
			volumen = clampf(float(d.get("volumen", volumen)), 0.0, 1.0)
			pantalla_completa = bool(d.get("pantalla_completa", pantalla_completa))
			idioma = str(d.get("idioma", idioma))
			if idioma != "" and not IDIOMAS.has(idioma):
				idioma = ""
	aplicar()


static func guardar() -> void:
	var f := FileAccess.open(ARCHIVO, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"volumen": volumen, "pantalla_completa": pantalla_completa,
			"idioma": idioma}, "\t"))


static func aplicar() -> void:
	_poner_idioma()
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volumen, 0.0001)))
	AudioServer.set_bus_mute(0, volumen <= 0.001)
	_poner_pantalla()


static func cambiar_volumen(pasos: int) -> void:
	volumen = clampf(snappedf(volumen + pasos * PASO_VOLUMEN, PASO_VOLUMEN), 0.0, 1.0)
	aplicar()
	guardar()


static func cambiar_pantalla() -> void:
	pantalla_completa = not pantalla_completa
	aplicar()
	guardar()


## El idioma con el que se juega: el elegido o, sin eleccion, el del sistema.
static func idioma_actual() -> String:
	if idioma != "":
		return idioma
	var sistema := OS.get_locale_language()
	return sistema if IDIOMAS.has(sistema) else "en"


static func nombre_idioma() -> String:
	return IDIOMAS[idioma_actual()]


## Pasa al siguiente idioma de IDIOMAS (Opciones solo tiene dos o tres).
static func cambiar_idioma(pasos := 1) -> void:
	var lista := IDIOMAS.keys()
	idioma = lista[wrapi(lista.find(idioma_actual()) + pasos, 0, lista.size())]
	aplicar()
	guardar()


static func _poner_idioma() -> void:
	if not _traducciones:
		_traducciones = true
		for t in TEXTOS:
			for i in IDIOMAS:
				var ruta := "res://textos/%s.%s.translation" % [t, i]
				if ResourceLoader.exists(ruta):
					TranslationServer.add_translation(load(ruta))
				else:
					push_error("Ajustes: falta %s (importar textos/%s.csv)" % [ruta, t])
	TranslationServer.set_locale(idioma_actual())


static func _poner_pantalla() -> void:
	# Grabando con --write-movie la ventana va fuera de la pantalla: no tocarla.
	if Engine.get_write_movie_path() != "" or DisplayServer.get_name() == "headless":
		return
	var modo := DisplayServer.window_get_mode()
	var completa := modo == DisplayServer.WINDOW_MODE_FULLSCREEN or modo == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if pantalla_completa == completa:
		return
	if pantalla_completa:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# El proyecto va sin bordes (para la pantalla completa); en ventana, con
		# su barra, para poder moverla y cerrarla.
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		# Una ventana del 75 % de la pantalla, centrada, con la proporcion del juego.
		var pantalla := DisplayServer.screen_get_size()
		var tam := Vector2i(Vector2(pantalla.x * 0.75, pantalla.x * 0.75 * 1632.0 / 2912.0))
		DisplayServer.window_set_size(tam)
		DisplayServer.window_set_position(DisplayServer.screen_get_position() + (pantalla - tam) / 2)
