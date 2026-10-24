extends "res://scripts/game/plano_bosque.gd"
## El cruce del bosque: el contraplano del camino del bosque (la camara de
## detras). Una imagen de Midjourney con tres caminos: el del centro baja a la
## casa de Dominus (su verja asoma en la niebla del fondo); los de los lados se
## toman con un corte a su propio plano (camino_izquierdo, en tres cuartos;
## camino_derecho, frontal). Es un plano_bosque.gd (la escena viva); las mascaras
## salen de raw/master_builder/cruce_bosque/ (componer.py pone la casa y el color
## del camino; mascaras.py, lo demas).
##
## EL PEREGRINO (peregrino_cruce.gd), de espaldas: llega del camino andando (al
## llegar delante alli, corte aqui). Volviendo hacia la camara, corte al camino,
## que le recibe de espaldas. En la explanada, izquierda o derecha: anda hacia la
## boca de ese camino y `boca`: corte al plano de ese camino. Al fondo del
## central, `salida` ("casa"): aun no hay escena, a negro.

@export_group("Caminos")
## A donde lleva cada camino (vacio: a negro y ahi se queda).
@export_file("*.tscn") var escena_casa := ""
@export_file("*.tscn") var escena_izquierda := "res://scenes/game/camino_izquierdo.tscn"
@export_file("*.tscn") var escena_derecha := "res://scenes/game/camino_derecho.tscn"
## Lo que sigue andando hacia la boca antes del corte a su camino (s).
@export var corte_boca_s := 0.1


func _montar_peregrino() -> void:
	super()
	var peregrino := get_node_or_null("Peregrino")
	if peregrino == null:
		return
	peregrino.boca.connect(_a_la_boca)
	# los de los lados, cargando desde ya: el corte, al instante
	_cargar(escena_izquierda)
	_cargar(escena_derecha)


func _a_la_boca(lado: String) -> void:
	var ruta := escena_izquierda if lado == "izquierda" else escena_derecha
	if ruta == "":
		_a_negro()
		return
	_cortar_a(ruta, corte_boca_s)


func _escena_de_salida(_cual: String) -> String:
	return escena_casa


## Lo que el peregrino puede hacer aqui (menu de pausa): ademas de lo del
## camino, tomar los caminos de los lados.
func controles_disponibles() -> Array:
	var lista := super()
	lista.insert(2, {"acciones": [&"mover_izquierda", &"mover_derecha"], "texto": "controles.elegir_camino"})
	return lista
