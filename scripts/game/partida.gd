class_name Partida
extends RefCounted
## Lo que ya ha pasado en esta partida: las cosas de una sola vez (el emu del
## camino del bosque sale solo la primera vez que se entra). Vive en el
## SceneTree, que sobrevive a los cambios de escena.
##     if not Partida.ya(get_tree(), "camino_emu"): ...
##     Partida.marcar(get_tree(), "camino_emu")
##
## LA PARTIDA GUARDADA (2026-10-17). Hay una sola partida de historia, sin
## ranuras, y se guarda sola en los puntos de guardado: guardar() apunta en disco
## el punto, los hechos de arriba y como va el peregrino (PeregrinoEstado), tal
## como estan en ese momento. marcar() no escribe en disco: lo que pase despues
## de un punto se pierde si se sale antes del siguiente.
##     Partida.guardar(get_tree(), "hojarasca")
## "Continuar" lo deshace: cargar() devuelve las cosas al SceneTree y dice a que
## escena ir.
##
## SEGUIR JUSTO DONDE SE DEJO (2026-10-18; el usuario: "cuando sales del juego me
## gustaria que el jugador siguiese justo por donde lo dejo, y no volviera
## atras; lo de guardando es una foto a la que poder volver"). Ademas del punto,
## la partida lleva "reanudar": la escena de ahora con lo que ella diga de si
## misma (estado_reanudar() de la escena: donde esta el peregrino, si lleva el
## baculo...), los hechos y el peregrino. Lo apunta guardar_reanudar(), que se
## llama al salir del juego, al volver al titulo, al pausar y cada rato
## (GlobalExit). "Continuar" va ahi si lo hay; si no, al punto. Un punto nuevo lo
## borra (es mas reciente). La escena lo recoge en su _ready con
## reanudar_estado(), que le da lo que apunto (o {} si se entra normal).
## Escenas sin estado_reanudar(), o que devuelven {} (el ataud, el titulo, una
## cinematica a medias), no apuntan nada: se queda lo de antes.

## Aparte van las escenas clave a las que se ha llegado alguna vez
## (desbloquear), que son las que "Nueva partida" deja elegir como inicio.
## Viven en otro archivo para que empezar de nuevo (borrar) no las quite. El
## principio (el ataud) no cuenta: siempre se puede empezar por ahi.

const CLAVE := &"partida_hechos"
## Lo que la escena apunto de si misma, para que su _ready lo recoja al continuar.
const META_REANUDAR := &"partida_reanudar"

const ARCHIVO := "user://partida.json"
const ARCHIVO_DESBLOQUEOS := "user://desbloqueos.json"
const VERSION := 1

## El principio de todo: el ataud, sin el arranque de main (que con partida
## guardada va al titulo).
const PRINCIPIO := "res://scenes/intro/sarcophagus_intro.tscn"

## Los puntos donde se guarda: al pasar ciertos puzles, con la marca de guardado
## en pantalla, y la partida sigue desde ahi con el puzle ya pasado, lista para
## ir a lo siguiente. "clave" son los que salen para elegir en "Nueva partida"
## (con su nombre y su miniatura); los demas solo sirven para continuar.
## Guardar, en muchos sitios; clave, en pocos (el usuario, 2026-10-17: "no quiero
## que haya muchos, al final es poder ir a ciertos puntos, no a todos"): solo el
## comienzo de cada zona grande, como capitulos.
const PUNTOS := {
	# Pasado lo de la cucaracha: la caida en la hojarasca.
	"hojarasca": {
		"escena": "res://scenes/game/caida_hojarasca.tscn",
		"nombre": "punto.hojarasca",
		"clave": true,
	},
	# Cogido el baculo: la hojarasca resuelta, con el camino abierto.
	"hojarasca_resuelta": {
		"escena": "res://scenes/game/caida_hojarasca.tscn",
		"nombre": "punto.hojarasca_resuelta",
		"clave": false,
	},
}

const MARCA := "res://scripts/ui/marca_guardado.gd"

const PEREGRINO_ESTADO := preload("res://scripts/characters/peregrino_estado.gd")


static func ya(arbol: SceneTree, que: String) -> bool:
	return (arbol.get_meta(CLAVE, {}) as Dictionary).has(que)


static func marcar(arbol: SceneTree, que: String) -> void:
	var hechos: Dictionary = arbol.get_meta(CLAVE, {})
	hechos[que] = true
	arbol.set_meta(CLAVE, hechos)


## Si hay partida guardada a la que se pueda volver.
static func hay_guardada() -> bool:
	return PUNTOS.has(_leer(ARCHIVO).get("punto", ""))


## El nombre del punto guardado ("La hojarasca"), ya traducido, o "" si no hay
## partida. Los nombres de PUNTOS son claves de textos/interfaz.csv. Es la foto:
## Continuar puede seguir mas adelante (ver reanudar).
static func nombre_guardado() -> String:
	var punto: String = _leer(ARCHIVO).get("punto", "")
	return TranslationServer.translate(PUNTOS[punto]["nombre"]) if PUNTOS.has(punto) else ""


## Guarda la partida en el punto "punto" (una clave de PUNTOS), con los hechos y
## el estado del peregrino de ahora. Si el punto es clave, lo desbloquea tambien.
## Con marca, se ve la marca de guardado en la esquina.
static func guardar(arbol: SceneTree, punto: String, marca := true) -> void:
	if de_pruebas(arbol.current_scene.scene_file_path if arbol.current_scene else ""):
		return
	if not PUNTOS.has(punto):
		push_error("Partida.guardar: punto desconocido '%s'" % punto)
		return
	_escribir(ARCHIVO, {
		"version": VERSION,
		"punto": punto,
		"hechos": (arbol.get_meta(CLAVE, {}) as Dictionary).keys(),
		"peregrino": PEREGRINO_ESTADO.leer(arbol),
		"fecha": Time.get_datetime_string_from_system(),
	})
	if PUNTOS[punto].get("clave", false):
		desbloquear(punto)
	if marca:
		# En diferido: se suele guardar desde un _ready, con la raiz ocupada
		# metiendo la escena nueva.
		arbol.root.add_child.call_deferred(load(MARCA).new())


## Prepara el SceneTree para seguir la partida guardada (hechos y peregrino) y
## devuelve la escena a la que hay que ir: donde se dejo (reanudar) si se apunto,
## o el ultimo punto. "" si no hay partida.
static func cargar(arbol: SceneTree) -> String:
	var datos := _leer(ARCHIVO)
	var punto: String = datos.get("punto", "")
	if not PUNTOS.has(punto):
		return ""
	var r: Dictionary = datos.get("reanudar", {})
	var escena: String = r.get("escena", "")
	# Una escena de pruebas apuntada por error (antes de de_pruebas) no se sigue:
	# se va al ultimo punto.
	if escena != "" and ResourceLoader.exists(escena) and not de_pruebas(escena):
		empezar_en(arbol, punto, r.get("hechos", []), r.get("peregrino", {}))
		arbol.set_meta(META_REANUDAR, r.get("estado", {}))
		return escena
	return empezar_en(arbol, punto, datos.get("hechos", []), datos.get("peregrino", {}))


## Apunta donde esta el jugador ahora mismo, para que Continuar siga justo ahi.
## Solo si hay partida (desde el primer punto), la escena no es de pruebas
## (de_pruebas) y sabe decir donde esta (estado_reanudar(), en ella o en un hijo
## directo). Devuelve si apunto algo.
static func guardar_reanudar(arbol: SceneTree) -> bool:
	var escena := arbol.current_scene
	if escena == null or de_pruebas(escena.scene_file_path):
		return false
	var nodo: Node = null
	for n in [escena] + escena.get_children():
		if n.has_method("estado_reanudar"):
			nodo = n
			break
	if nodo == null:
		return false
	var estado: Dictionary = nodo.estado_reanudar()
	if estado.is_empty():
		return false
	var datos := _leer(ARCHIVO)
	if not PUNTOS.has(datos.get("punto", "")):
		return false
	# El peregrino como va ahora (la escena lo sabe mejor que PeregrinoEstado, que
	# solo se apunta al cambiar de escena), sin "viene_de": al continuar se entra
	# desde negro, no por un corte de camara.
	var peregrino: Dictionary = estado.get("peregrino", PEREGRINO_ESTADO.leer(arbol)).duplicate()
	peregrino.erase("viene_de")
	datos["reanudar"] = {
		"escena": estado.get("escena", nodo.scene_file_path),
		"estado": estado,
		"hechos": (arbol.get_meta(CLAVE, {}) as Dictionary).keys(),
		"peregrino": peregrino,
		"fecha": Time.get_datetime_string_from_system(),
	}
	_escribir(ARCHIVO, datos)
	return true


## Si la escena de ahora sabe decir donde esta el jugador (Continuar seguiria
## justo aqui). Para el texto del menu de pausa.
static func se_puede_reanudar(arbol: SceneTree) -> bool:
	var escena := arbol.current_scene
	if escena == null or not PUNTOS.has(_leer(ARCHIVO).get("punto", "")):
		return false
	for n in [escena] + escena.get_children():
		if n.has_method("estado_reanudar"):
			return not (n.estado_reanudar() as Dictionary).is_empty()
	return false


## Lo que apunto la escena al salir, para su _ready. Se gasta al leerlo: si se
## sale y se vuelve a entrar en la escena jugando, ya no se usa. {} si se entra
## normal.
static func reanudar_estado(arbol: SceneTree) -> Dictionary:
	var e: Dictionary = arbol.get_meta(META_REANUDAR, {})
	if arbol.has_meta(META_REANUDAR):
		arbol.remove_meta(META_REANUDAR)
	return e


## Deja el SceneTree como recien llegado al punto (sin hechos, salvo los que se
## pasen) y devuelve su escena. Para "Nueva partida" desde una escena clave.
static func empezar_en(arbol: SceneTree, punto: String, hechos: Array = [], peregrino: Dictionary = {}) -> String:
	var h := {}
	for que in hechos:
		h[str(que)] = true
	arbol.set_meta(CLAVE, h)
	if peregrino.is_empty():
		if arbol.has_meta(PEREGRINO_ESTADO.CLAVE):
			arbol.remove_meta(PEREGRINO_ESTADO.CLAVE)
	else:
		arbol.set_meta(PEREGRINO_ESTADO.CLAVE, peregrino)
	return PUNTOS[punto]["escena"]


## Borra la partida guardada y los hechos de esta (empezar de nuevo). Los
## desbloqueos se quedan.
static func borrar(arbol: SceneTree) -> void:
	if FileAccess.file_exists(ARCHIVO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARCHIVO))
	arbol.set_meta(CLAVE, {})
	if arbol.has_meta(META_REANUDAR):
		arbol.remove_meta(META_REANUDAR)
	if arbol.has_meta(PEREGRINO_ESTADO.CLAVE):
		arbol.remove_meta(PEREGRINO_ESTADO.CLAVE)


static func desbloquear(punto: String) -> void:
	var lista := desbloqueados()
	if punto in lista:
		return
	lista.append(punto)
	_escribir(ARCHIVO_DESBLOQUEOS, {"version": VERSION, "puntos": lista})


## Los puntos clave a los que se ha llegado alguna vez, en el orden de PUNTOS.
static func desbloqueados() -> Array:
	var hay: Array = _leer(ARCHIVO_DESBLOQUEOS).get("puntos", [])
	var lista := []
	for punto in PUNTOS:
		if punto in hay and PUNTOS[punto].get("clave", false):
			lista.append(punto)
	return lista


## Las escenas de pruebas (scenes/dev, pruebas_camara, pruebas_storyboard) no
## tocan la partida: se ejecutan a mano o grabando y comparten la carpeta de
## guardado con el juego. (El 2026-10-18 prueba_luz.tscn apunto "donde seguir"
## en la partida del usuario, y Continuar llevaba a la hojarasca de pruebas, a
## oscuras y sin salida.)
static func de_pruebas(escena: String) -> bool:
	return escena.begins_with("res://scenes/dev/") or escena.begins_with("res://scenes/pruebas_")


static func _leer(ruta: String) -> Dictionary:
	if not FileAccess.file_exists(ruta):
		return {}
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return {}
	var datos = JSON.parse_string(f.get_as_text())
	return datos if datos is Dictionary else {}


## Escribe a un archivo aparte y luego lo cambia por el bueno: si el juego se
## cierra a medias, se queda la partida de antes y no un archivo roto.
static func _escribir(ruta: String, datos: Dictionary) -> void:
	var tmp := ruta + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Partida: no se puede escribir %s (%s)" % [ruta, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(datos, "\t"))
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(ruta))
	if err != OK:
		push_error("Partida: no se pudo guardar %s (%s)" % [ruta, err])
