class_name Partida
extends RefCounted
## Lo que ya ha pasado en esta partida: las cosas de una sola vez (el emu del
## camino del bosque sale solo la primera vez que se entra). Vive en el
## SceneTree, que sobrevive a los cambios de escena; no se guarda en disco
## (aun no hay partidas guardadas).
##     if not Partida.ya(get_tree(), "camino_emu"): ...
##     Partida.marcar(get_tree(), "camino_emu")

const CLAVE := &"partida_hechos"


static func ya(arbol: SceneTree, que: String) -> bool:
	return (arbol.get_meta(CLAVE, {}) as Dictionary).has(que)


static func marcar(arbol: SceneTree, que: String) -> void:
	var hechos: Dictionary = arbol.get_meta(CLAVE, {})
	hechos[que] = true
	arbol.set_meta(CLAVE, hechos)
