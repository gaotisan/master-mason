class_name PeregrinoEstado
extends RefCounted
## Como deja una escena al peregrino para la siguiente: con el baston en la
## mano o guardado a la espalda, la magia (la carga y si se recarga, como en
## baston.gd) y de que escena viene (para saber por donde entra: volviendo del
## camino, la hojarasca no empieza con la caida). La escena que se va lo deja
## antes de cambiar de escena:
##     PeregrinoEstado.dejar(get_tree(), true, 0.0, 0.0, "camino_bosque")
## y la que llega lo lee al montar al peregrino (de perfil o de frente):
##     var e := PeregrinoEstado.leer(get_tree())   # {} si nadie dijo nada
## Si no hay nada (la escena abierta sola, para probarla), cada escena usa lo
## suyo. Va en el SceneTree, que sobrevive al cambio de escena.

const CLAVE := &"peregrino_estado"


static func dejar(arbol: SceneTree, baston_en_mano: bool, magia := 0.0, magia_recarga := 0.0, viene_de := "") -> void:
	arbol.set_meta(CLAVE, {"baston_en_mano": baston_en_mano, "magia": magia, "magia_recarga": magia_recarga,
		"viene_de": viene_de})


static func leer(arbol: SceneTree) -> Dictionary:
	return arbol.get_meta(CLAVE, {})
