extends SceneTree
## Lo que pinta la escena (el peregrino de frente, PeregrinoFrontal, dentro de
## prueba_frontal) encima / alrededor del sprite en el fotograma base de un reposo,
## SIN el sprite y SIN la bola, con alfa, a escala de master: 664x904 con la casilla
## del reposo (584x800) en (40, 104), como las de sacar / guardar. Sirve para las
## referencias de Flow y para los puentes.
##   CAPTURA_DIR    carpeta de salida
##   CAPTURA_ANIM   reposo (por defecto reposo_frente_sb)
##   CAPTURA_CON    1: modo con baston (de el, solo la funda vacia; la bola no)
##   CAPTURA_NOMBRE fichero (por defecto baston_espalda_reposo.png)
##   CAPTURA_SOLO   con baston: "atras" (solo la correa) o "delante" (solo las
##                  presillas) de la correa vacia; por defecto, las dos
##   CAPTURA_FILA_DE sin baston: el baston a la espalda en la fila de la correa
##                  vacia de esa animacion del modo con baston (la espalda nueva sin
##                  baston, magnus_espalda_sin_baston: la correa en el mismo sitio)
## Con el reposo de frente sin baston: el baston a la espalda (solo asoma la
## garra). De espaldas: el baston entero y la funda (sin baston), o la funda vacia
## (con baston).
## (2026-10-15: el peregrino ya es el componente; antes leia los internos del
## prueba_frontal viejo. De espaldas el baston es baston_espalda.png, el de la mano.)

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
	var p = esc._peregrino
	esc.set_process(false)
	p.set_process(false)
	p.colocado.disconnect(esc._seguirle)
	esc._fondo.visible = false
	for c in esc.get_children():
		if c is CanvasLayer:
			c.visible = false
	# sin bola (el componente la vuelve a encender en _colocar si hay magia)
	p.magia = 0.0
	p.magia_recarga = 0.0
	var madera = p._bola.get_node("Madera")
	for n in ["Chispas", "Recarga", "Estallido", "Luz", "Orbe"]:
		madera.get_node(n).visible = false
	p._con_baston = con
	p._sec = p._secs[con]
	p._escala = 1.0
	p._y = 0.0
	p._poner_anim(anim, 0)
	var fila_de := OS.get_environment("CAPTURA_FILA_DE")
	if fila_de != "":
		p._espalda[anim] = p._vacia[fila_de]
	p._colocar()
	if con:
		p._bola.visible = false        # la bola va en la garra del sprite: fuera
		# la correa vacia cuelga del sprite: el sprite transparente y sin recortar
		# (CLIP_CHILDREN_ONLY, sobre fondo transparente, pinta la silueta en negro;
		# en el reposo la correa queda dentro de la silueta)
		p._sprite.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
		p._sprite.self_modulate.a = 0.0
		var solo := OS.get_environment("CAPTURA_SOLO")
		if solo == "atras":
			p._funda_vacia.get_child(1).visible = false
		elif solo == "delante":
			p._funda_vacia.get_child(0).visible = false
	else:
		p._sprite.visible = false
	# la casilla del reposo (292x400 de hoja, centrada en sprite + offset) en (40, 104) de master
	var centro: Vector2 = p.to_global(p._sprite.position + p._sprite.offset)
	esc._camara.zoom = Vector2(2, 2)
	esc._camara.position = centro - Vector2(146, 200) - Vector2(20, 52)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(salida + "/" + nombre)
	print("hecho ", nombre)
	quit()
