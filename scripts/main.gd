extends Node

func _ready():
	# Ocultamos el ratón al iniciar para no romper la atmósfera.
	# MOUSE_MODE_HIDDEN lo oculta pero permite que siga enviando coordenadas.
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_stop_all_audio()
			get_tree().quit()
	
	# Si necesitas recuperar el ratón por alguna razón técnica (solo debug)
	if OS.is_debug_build() and event.is_action_pressed("ui_focus_next"): # Por ejemplo con TAB
		if Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _stop_all_audio():
	for node in get_tree().get_nodes_in_group("audio"):
		node.stop()
	# Buscar todos los AudioStreamPlayer y AudioStreamPlayer2D
	_stop_audio_recursive(get_tree().root)

func _stop_audio_recursive(node: Node):
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		node.stop()
	for child in node.get_children():
		_stop_audio_recursive(child)
