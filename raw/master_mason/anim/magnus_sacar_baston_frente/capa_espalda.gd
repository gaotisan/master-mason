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
	# fondo opaco (negro y luego blanco, ver _sin_fondo): sobre fondo transparente
	# los bordes salian casi negros
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var capa_fondo := CanvasLayer.new()
	capa_fondo.layer = -100
	sv.add_child(capa_fondo)
	var fondo := ColorRect.new()
	fondo.size = Vector2(sv.size)
	fondo.color = Color.BLACK
	capa_fondo.add_child(fondo)
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
	if not con and p._textura_espaldas:
		_madera_master(p)
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
	var negro := sv.get_texture().get_image()
	fondo.color = Color.WHITE
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var blanco := sv.get_texture().get_image()
	_sin_fondo(negro, blanco).save_png(salida + "/" + nombre)
	print("hecho ", nombre)
	quit()


## (2026-10-16) La capa con su alfa, de pintarla sobre negro y sobre blanco: alfa =
## 1 - (blanco - negro), color = negro / alfa. Antes se pintaba sobre un fondo
## transparente y la mezcla de Godot dejaba los bordes semitransparentes casi negros
## (luminancia 3 con alfa 10-60, frente a 76 dentro): al pegar la capa en los videos
## de sacar y guardar de espaldas, el palo y la correa llevaban un contorno oscuro y
## se veian mas gordos que en la escena (el usuario lo vio al guardar el baston).
func _sin_fondo(negro: Image, blanco: Image) -> Image:
	negro.convert(Image.FORMAT_RGBA8)
	blanco.convert(Image.FORMAT_RGBA8)
	var n := negro.get_data()
	var b := blanco.get_data()
	var o := PackedByteArray()
	o.resize(n.size())
	for i in range(0, n.size(), 4):
		var dif := (float(b[i] - n[i]) + float(b[i + 1] - n[i + 1]) + float(b[i + 2] - n[i + 2])) / 3.0
		var a := clampf(1.0 - dif / 255.0, 0.0, 1.0)
		if a < 1.0 / 255.0:
			continue
		for c in 3:
			o[i + c] = clampi(roundi(n[i + c] / a), 0, 255)
		o[i + 3] = roundi(a * 255.0)
	return Image.create_from_data(negro.get_width(), negro.get_height(), false, Image.FORMAT_RGBA8, o)


## (2026-10-16) De espaldas, el baston con la textura de master (baston_espalda_master.png,
## el doble de baston_espalda.png) a media escala: la captura va a zoom 2 y con la de hoja
## salia ampliada con filtro lineal, borrosa y ~1/3 mas gruesa (13 px de palo frente a
## 9-10). Los videos de sacar y guardar la llevan en la correa y al acabar, con la escena
## pintando la de hoja, el baculo adelgazaba de golpe (el usuario lo vio).
func _madera_master(p) -> void:
	var ruta := ProjectSettings.globalize_path("res://raw/master_mason/anim/baston/baston_espalda_master.png")
	var img := Image.load_from_file(ruta)
	img.fix_alpha_edges()       # como al importar (fix_alpha_border): sin, el filtrado oscurece el borde
	var tex := ImageTexture.create_from_image(img)
	var ficha: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ruta.replace(".png", ".json")))
	var b := Vector2(ficha["bola"][0], ficha["bola"][1])
	for n in ["Madera", "MaderaDelante"]:
		var sp := p._bola.get_node(n) as Sprite2D
		sp.texture = tex
		sp.scale = Vector2(0.5, 0.5)
		# la bola, donde la de hoja (ORBE_EN_MADERA en el nodo, que ahora va a la mitad)
		sp.offset = p.ORBE_EN_MADERA * 2.0 - (b - tex.get_size() / 2.0)
