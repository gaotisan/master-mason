extends Node
## Por donde arranca el juego (2026-10-17):
##  - sin partida guardada (la primera vez), directo al ataud, sin menu delante:
##    el ataud, los creditos y el titulo, y la hojarasca, como un arranque en frio;
##  - con partida, la pantalla de titulo en modo menu (Continuar, Nueva partida...);
##  - sin partida pero con alguna escena desbloqueada (empezo de nuevo desde el
##    principio y cerro dentro del ataud), tambien el menu, sin Continuar: si no,
##    tendria que pasar otra vez el ataud entero para poder elegir escena.
## La partida existe desde que se cae en la hojarasca (Partida, el primer punto
## de guardado): la primera vez, si se cierra el juego dentro del ataud, se
## vuelve a empezar por el.

const TITULO := "res://scenes/intro/title_screen.tscn"


func _ready() -> void:
	if Partida.hay_guardada() or not Partida.desbloqueados().is_empty():
		get_tree().set_meta(&"titulo_modo_menu", true)
		get_tree().change_scene_to_file.call_deferred(TITULO)
	else:
		get_tree().change_scene_to_file.call_deferred(Partida.PRINCIPIO)
