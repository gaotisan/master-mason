class_name Teclas
extends RefCounted
## Las teclas del juego (2026-10-17): van por POSICION (physical_keycode), no por
## letra, para que en cualquier teclado (QWERTY, AZERTY...) caigan en el mismo
## sitio. Dos posturas, cada accion con su tecla en las dos:
##   con WASD           con flechas
##   A D  moverse       <- ->
##   W / Espacio saltar ^ / Espacio
##   S  agacharse       v
##   Q  baston          Z     (sacar / guardar; mantener: clavar)
##   E  accion          X     (coger, usar, agarrar)
##   F  magia           C
## El aviso de tecla (key_symbol.gd) ensena la de la postura con la que el
## jugador se ha movido por ultima vez (lo apunta GlobalExit, scripts/main.gd,
## con notar()) y con la letra que lleva esa tecla en SU teclado.

const FLECHAS := [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_Z, KEY_X, KEY_C, KEY_SPACE]
const WASD := [KEY_A, KEY_D, KEY_W, KEY_S, KEY_Q, KEY_E, KEY_F, KEY_SPACE]

## true: juega con las flechas (lo de siempre, por defecto); false: con WASD.
static var flechas := true


## Apunta la postura por la tecla de movimiento que se acaba de pulsar.
static func notar(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var p := k.physical_keycode
	if p in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		flechas = true
	elif p in [KEY_A, KEY_D, KEY_W, KEY_S]:
		flechas = false


## La tecla (posicion) de una accion en la postura de ahora; KEY_NONE si no tiene.
static func de(accion: StringName) -> Key:
	if not InputMap.has_action(accion):
		return KEY_NONE
	var primera := KEY_NONE
	var postura: Array = FLECHAS if flechas else WASD
	for ev in InputMap.action_get_events(accion):
		var k := ev as InputEventKey
		if k == null:
			continue
		var p: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		if primera == KEY_NONE:
			primera = p
		if p in postura:
			return p
	return primera


## Lo que pone en esa tecla en el teclado del jugador (la letra de su
## distribucion para esa posicion).
static func nombre(p: Key) -> String:
	var etiqueta := DisplayServer.keyboard_get_label_from_physical(p)
	return OS.get_keycode_string(etiqueta if etiqueta != KEY_NONE else p)
