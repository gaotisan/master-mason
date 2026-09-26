extends Node

## Para no salir dos veces si llegan ESC y el cierre de ventana a la vez.
var _saliendo := false

func _ready():
	# Ocultamos el ratón al iniciar para no romper la atmósfera.
	# MOUSE_MODE_HIDDEN lo oculta pero permite que siga enviando coordenadas.
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	# El cierre de ventana (Alt+F4) tambien pasa por _salir(): si el arbol se
	# cierra solo, lo hace con el audio sonando (ver _salir).
	get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_salir()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_salir()

	# Si necesitas recuperar el ratón por alguna razón técnica (solo debug)
	if OS.is_debug_build() and event.is_action_pressed("ui_focus_next"): # Por ejemplo con TAB
		if Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

## Para el audio y sale unos fotogramas despues. Si se sale en el mismo fotograma
## en que se para, el hilo de mezcla aun no ha soltado las reproducciones (las
## suelta tras un pequeno fundido) y al cerrar salen avisos de recursos y objetos
## sin liberar, que tapan los de verdad en el log.
func _salir() -> void:
	if _saliendo:
		return
	_saliendo = true
	_stop_all_audio()
	# Y que nada vuelva a sonar en esa espera (una pisada, una racha).
	get_tree().paused = true
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit()

func _stop_all_audio():
	# Buscar todos los AudioStreamPlayer y AudioStreamPlayer2D, autoloads incluidos
	_stop_audio_recursive(get_tree().root)

func _stop_audio_recursive(node: Node):
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		node.stop()
	for child in node.get_children():
		_stop_audio_recursive(child)
