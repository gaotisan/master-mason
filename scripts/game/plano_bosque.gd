extends "res://scripts/game/camino_bosque.gd"
## Un plano del bosque de Dominus detras del camino (el cruce, los caminos de los
## lados): la misma escena viva que el camino del bosque (camino_bosque.gd:
## viento en la copa, luz que respira y claros, rayos, hojas, polvo, camara con
## paralaje, musica), con otra foto y su peregrino. Las mascaras salen de
## raw/master_builder/<plano>/mascaras.py (fondo_vivo.py) a assets/world/<plano>/.
##
## EL PEREGRINO (el del nodo Peregrino: peregrino_sendero.gd de frente,
## peregrino_tres_cuartos.gd en diagonal) entra andando desde la escena de antes
## y, volviendo hacia la camara, `se_va`: corte a ella (escena_anterior). Al fondo,
## `salida`: a escena_fondo o, si aun no la hay, a negro y ahi se queda.
## El emu del camino ya ha pasado (si se abre una de estas sola y se va al camino,
## no sale).

@export_group("Salidas")
## A donde lleva el fondo de este plano (vacio: a negro y ahi se queda).
@export_file("*.tscn") var escena_fondo := ""


func _ready() -> void:
	PartidaHechos.marcar(get_tree(), "camino_emu")
	super()


func _montar_peregrino() -> void:
	var peregrino := get_node_or_null("Peregrino")
	if peregrino == null:
		return
	peregrino.se_va.connect(_volver)
	peregrino.al_mando.connect(_cargar_anterior)
	peregrino.salida.connect(_salir)
	# el mando lo tiene desde el principio: la de antes, ya cargando
	_cargar_anterior()


## Al fondo: a su escena, o a negro si aun no la hay.
func _salir(cual: String) -> void:
	var ruta := _escena_de_salida(cual)
	if ruta == "":
		_a_negro()
		return
	_cortar_a(ruta, negro_s)


func _escena_de_salida(_cual: String) -> String:
	return escena_fondo


## Los mandos de aqui (menu de pausa): los que diga su peregrino, si los dice.
func controles_disponibles() -> Array:
	var p := get_node_or_null("Peregrino")
	if p and p.has_method("controles_disponibles"):
		return p.controles_disponibles()
	return super()


## Para seguir donde se dejo: desde su principio, con el baculo como lo llevaba.
## Saliendo por el fondo, nada.
func estado_reanudar() -> Dictionary:
	var p := get_node_or_null("Peregrino")
	if p and String(p.get("_estado")) in ["saliendo", "fuera"]:
		return {}
	if p and p.has_method("estado_reanudar"):
		return p.estado_reanudar()
	var d := super()
	if not d.is_empty():
		d["fase"] = nombre_escena
	return d
