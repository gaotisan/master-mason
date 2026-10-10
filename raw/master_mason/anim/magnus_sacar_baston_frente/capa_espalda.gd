extends SceneTree
## Lo que pinta la escena (prueba_frontal) encima / alrededor del sprite en el
## fotograma base de un reposo, SIN el sprite y SIN la bola, con alfa, a escala de
## master: 664x904 con la casilla del reposo (584x800) en (40, 104), como las de
## sacar / guardar. Sirve para las referencias de Flow y para los puentes.
##   CAPTURA_DIR    carpeta de salida
##   CAPTURA_ANIM   reposo (por defecto reposo_frente_sb)
##   CAPTURA_CON    1: modo con baston (de el, solo la funda vacia; la bola no)
##   CAPTURA_NOMBRE fichero (por defecto baston_espalda_reposo.png)
## Con el reposo de frente sin baston: el baston a la espalda (solo asoma la
## garra). De espaldas: el baston entero y la funda (sin baston), o la funda vacia
## (con baston).

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var salida := OS.get_environment("CAPTURA_DIR")
	var anim := OS.get_environment("CAPTURA_ANIM") if OS.get_environment("CAPTURA_ANIM") != "" else "reposo_frente_sb"
	var con := OS.get_environment("CAPTURA_CON") == "1"
	var nombre := OS.get_environment("CAPTURA_NOMBRE") if OS.get_environment("CAPTURA_NOMBRE") != "" else "baston_espalda_reposo.png"
	var sv := SubViewport.new()
	sv.size = Vector2i(664, 904)
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var esc = load("res://scenes/dev/prueba_frontal.tscn").instantiate()
	sv.add_child(esc)
	await process_frame
	esc.set_process(false)
	esc._fondo.visible = false
	for c in esc.get_children():
		if c is CanvasLayer:
			c.visible = false
	var madera = esc._bola.get_node("Madera")
	for p in ["Chispas", "Recarga", "Estallido", "Luz", "Orbe"]:
		madera.get_node(p).visible = false
	esc._con_baston = con
	esc._sec = esc._secs[con]
	esc._escala = 1.0
	esc._y = esc.SUELO_SALIDA
	esc._poner_anim(anim, 0)
	esc._colocar()
	if con:
		esc._bola.visible = false        # la bola va en la garra del sprite: fuera
		# la correa vacia cuelga del sprite y se recorta con su silueta: el sprite
		# solo como mascara (sin dibujarse)
		esc._sprite.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	else:
		esc._sprite.visible = false
	# la casilla del reposo (292x400 de hoja, centrada en sprite + offset) en (40, 104) de master
	var centro: Vector2 = esc._sprite.position + esc._sprite.offset
	esc._camara.zoom = Vector2(2, 2)
	esc._camara.position = centro - Vector2(146, 200) - Vector2(20, 52)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(salida + "/" + nombre)
	print("hecho ", nombre)
	quit()
