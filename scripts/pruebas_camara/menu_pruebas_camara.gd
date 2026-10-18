extends Control
## Menu de las pruebas de camara. Nada del juego lleva aqui: se abre a mano
## (pruebas_camara.bat, o F6 sobre la escena en el editor).
## 1 capas (Inside), 2 planos fijos (Alone in the Dark), 3 el peregrino 3D, Esc sale.

const ESCENAS := {
	KEY_1: "res://scenes/pruebas_camara/capas_inside.tscn",
	KEY_2: "res://scenes/pruebas_camara/planos_alone.tscn",
	KEY_3: "res://scenes/pruebas_camara/vitrina_3d.tscn",
}

func _ready() -> void:
	# Desde la linea de comandos: -- capas / -- planos abre directamente.
	var args := OS.get_cmdline_user_args()
	if "capas" in args:
		_abrir.call_deferred(ESCENAS[KEY_1])
	elif "planos" in args:
		_abrir.call_deferred(ESCENAS[KEY_2])
	elif "vitrina" in args:
		_abrir.call_deferred(ESCENAS[KEY_3])

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo and ESCENAS.has(evento.keycode):
		_abrir(ESCENAS[evento.keycode])

func _abrir(ruta: String) -> void:
	get_tree().change_scene_to_file(ruta)
