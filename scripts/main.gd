extends Node

## Esc abre el menu de pausa (2026-10-17; antes cerraba el juego en el acto). Salir
## va por el menu, con confirmacion, o con el cierre de ventana (Alt+F4), que
## sigue saliendo directo. Las escenas que no se pausan (la pantalla de titulo en
## modo menu, que tiene su propio menu) se meten en el grupo GRUPO_SIN_PAUSA; ahi
## Esc es suyo.

const MENU_PAUSA := preload("res://scripts/ui/menu_pausa.gd")
const AJUSTES := preload("res://scripts/ui/ajustes.gd")
const GRUPO_SIN_PAUSA := &"sin_pausa"

## Para no salir dos veces si llegan ESC y el cierre de ventana a la vez.
var _saliendo := false

## Cada cuanto se apunta donde va el jugador (Partida.guardar_reanudar), por si
## el juego se cierra sin pasar por _salir (se cuelga, se va la luz). Ademas se
## apunta al salir y al pausar.
const REANUDAR_CADA := 20.0
var _reanudar_t := 0.0

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_reanudar_t += delta
	if _reanudar_t >= REANUDAR_CADA:
		_reanudar_t = 0.0
		Partida.guardar_reanudar(get_tree())

func _ready():
	# Ocultamos el ratón al iniciar para no romper la atmósfera.
	# MOUSE_MODE_HIDDEN lo oculta pero permite que siga enviando coordenadas.
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	# El cierre de ventana (Alt+F4) tambien pasa por _salir(): si el arbol se
	# cierra solo, lo hace con el audio sonando (ver _salir).
	get_tree().auto_accept_quit = false
	# Volumen y pantalla completa del jugador (user://ajustes.json).
	AJUSTES.cargar()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_salir()
	# Si la ventana pierde el foco (Alt+Tab, un aviso de Windows...), pausa sola,
	# como cualquier juego. Grabando con --write-movie no: alli la ventana va
	# fuera de la pantalla y pierde el foco sin que nadie haga nada.
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and Engine.get_write_movie_path() == "":
		pausar()

func _input(event):
	# con que postura juega (flechas o WASD): lo que ensenan los avisos de tecla
	Teclas.notar(event)
	if event is InputEventKey and event.pressed and not event.echo:
		# Donde no hay pausa (el titulo en modo menu), Esc es de la escena.
		if event.keycode == KEY_ESCAPE and _se_puede_pausar():
			get_viewport().set_input_as_handled()
			pausar()

	# Si necesitas recuperar el ratón por alguna razón técnica (solo debug)
	if OS.is_debug_build() and event.is_action_pressed("ui_focus_next"): # Por ejemplo con TAB
		if Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

## Abre el menu de pausa, si se puede y no esta ya abierto.
func pausar() -> void:
	if _saliendo or get_tree().paused or not _se_puede_pausar():
		return
	Partida.guardar_reanudar(get_tree())
	# En diferido: si no, el mismo Esc que la abre le llegaba al menu y la cerraba.
	get_tree().root.add_child.call_deferred(MENU_PAUSA.new())

func _se_puede_pausar() -> bool:
	return get_tree().current_scene != null and get_tree().get_first_node_in_group(GRUPO_SIN_PAUSA) == null

## Salir del juego (lo usa el menu de pausa, ya confirmado).
func salir() -> void:
	_salir()

## Para el audio y sale unos fotogramas despues. Si se sale en el mismo fotograma
## en que se para, el hilo de mezcla aun no ha soltado las reproducciones (las
## suelta tras un pequeno fundido) y al cerrar salen avisos de recursos y objetos
## sin liberar, que tapan los de verdad en el log.
func _salir() -> void:
	if _saliendo:
		return
	_saliendo = true
	# Donde va el jugador, para seguir justo ahi al volver (Partida).
	Partida.guardar_reanudar(get_tree())
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
