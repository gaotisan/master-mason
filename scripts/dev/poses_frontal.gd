extends Node2D
## Pinta poses del peregrino frontal tal como las pinta el juego (con
## alta_resolucion: los masters 1:1, ~640 px de la capucha a los pies), sobre
## fondo transparente (el alfa del personaje, sin ribete de croma), y guarda una
## PNG de 1200x1200 por pose, con los pies en (600, 1100). Para las referencias de los videos de Flow
## (raw/master_builder/anim/_fuentes/referencias_diagonal.py).
##   Godot --path . res://scenes/dev/poses_frontal.tscn -- <carpeta> <nombre:animacion:fotograma:baston(1/0)> ...
## baston 1 = con el baculo en la mano (la correa vacia la pone el juego), 0 =
## guardado (el baculo y la correa a la espalda los pone el juego).
## Con un quinto campo a 1 (nombre:animacion:fotograma:0:1) pinta SOLO lo que pone
## el juego encima del video (el baculo y la correa a la espalda), sin el cuerpo:
## para ponerselo a otros videos (raw/master_builder/anim/peregrino_diagonal).

const PEREGRINO := preload("res://scenes/characters/peregrino_frontal.tscn")
const PIES := Vector2(600, 1100)
const TAM := Vector2i(1200, 1200)


func _ready() -> void:
	# en una SubViewport a su tamano: la ventana no pasa del monitor
	var vista := SubViewport.new()
	vista.size = TAM
	vista.disable_3d = true
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vista.transparent_bg = true
	add_child(vista)
	var args := OS.get_cmdline_user_args()
	var carpeta := args[0]
	for pose in args.slice(1):
		var p := String(pose).split(":")
		var pe: PeregrinoFrontal = PEREGRINO.instantiate()
		pe.con_baston = p[3] == "1"
		pe.magia = 0.0
		pe.magia_recarga = 0.0
		pe.escala_inicial = 2.0
		pe.escala_max = 3.0
		pe.position = PIES
		vista.add_child(pe)
		pe._poner_anim(p[1], int(p[2]))
		pe._cb = "perfil"
		pe._colocar()
		if p.size() > 4 and p[4] == "1":
			pe._sprite.self_modulate = Color(1, 1, 1, 0)
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		vista.get_texture().get_image().save_png(carpeta + "/" + p[0] + ".png")
		print("POSE ", p[0], " pies ", pe.pies)
		pe.queue_free()
		await get_tree().process_frame
	get_tree().quit()
