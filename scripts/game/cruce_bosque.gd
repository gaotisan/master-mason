extends "res://scripts/game/camino_bosque.gd"
## El cruce del bosque: el contraplano del camino del bosque (la camara de
## detras). Una imagen de Midjourney con tres caminos (el del centro baja a la
## casa de Dominus, cuya verja asoma en la niebla del fondo; uno a la izquierda y
## otro a la derecha), viva como la del camino: es la misma escena con otra foto
## (camino_bosque.gd: viento en la copa, luz que respira y claros, rayos, hojas,
## polvo, camara con paralaje, musica). Las mascaras salen de
## raw/master_builder/cruce_bosque/ (componer.py pone la casa y el color del
## camino; mascaras.py, lo demas) y van en assets/world/cruce_bosque/.
##
## EL PEREGRINO (peregrino_cruce.gd), de espaldas: llega del camino andando (al
## llegar delante alli, corte aqui) y elige camino. Volviendo hacia la camara,
## corte al camino, que le recibe de espaldas (PeregrinoEstado viene_de
## "cruce_bosque"). Al fondo de cada camino, `salida`: aun no hay escenas detras
## (casa, izquierda, derecha): a negro y ahi se queda.
##
## El emu del camino ya ha pasado (si se abre esta escena sola y se vuelve al
## camino, no sale).

@export_group("Caminos")
## A donde lleva cada camino (vacio: a negro y ahi se queda).
@export_file("*.tscn") var escena_casa := ""
@export_file("*.tscn") var escena_izquierda := ""
@export_file("*.tscn") var escena_derecha := ""


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
	# el mando lo tiene desde el principio: el camino, ya cargando
	_cargar_anterior()


## Al fondo de un camino: a su escena, o a negro si aun no la hay.
func _salir(cual: String) -> void:
	var ruta: String = {"casa": escena_casa, "izquierda": escena_izquierda, "derecha": escena_derecha}.get(cual, "")
	if ruta == "":
		_a_negro()
		return
	_cortar_a(ruta, negro_s)


## Lo que el peregrino puede hacer aqui (menu de pausa): ademas de lo del
## camino, elegir camino.
func controles_disponibles() -> Array:
	var lista := super()
	lista.insert(2, {"acciones": [&"mover_izquierda", &"mover_derecha"], "texto": "controles.elegir_camino"})
	return lista


## Para seguir donde se dejo: en el cruce se sigue desde su principio (de
## espaldas), con el baculo como lo llevaba. Saliendo por un camino, nada.
func estado_reanudar() -> Dictionary:
	var p := get_node_or_null("Peregrino")
	if p and String(p.get("_estado")) == "saliendo":
		return {}
	var d := super()
	if not d.is_empty():
		d["fase"] = "cruce"
	return d
