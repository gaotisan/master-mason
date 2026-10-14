extends Node
## SONDA DE RENDIMIENTO (2026-10-14). Arranca la escena que se le diga y, colgada
## de la raiz (sobrevive a los cambios de escena), imprime cada segundo los fps,
## el peor fotograma, cuantos pasan de 20 ms, lo que tarda la grafica en pintar
## (medido en la grafica), las llamadas de dibujo, la memoria de video y los
## nodos; y cada fotograma de mas de TIRON_MS, al momento, con la escena. Puede
## pulsar acciones a su hora para recorrer la escena sin nadie.
##   SONDA_ESCENA=res://... (por defecto main.tscn)
##   SONDA_GUION="t:accion:duracion;..."  (ej. "13:mover_derecha:5;19:saltar:0.3")
##   SONDA_CADA=1  (segundos entre lineas)
##   SONDA_OCULTAR="Bosque,FondoImagen"  (a los 4 s esconde esos nodos de la
##   escena, para ver cuanto cuesta cada cosa en la grafica; vale "*ColorRect*"
##   para los que no tienen nombre; SONDA_OCULTAR_T=12 lo hace a esa hora)
##   SONDA_VARS="HojasDelante:_vuelan,Magnus:velocity"  (anade a cada linea esas
##   variables de nodos de la escena: de un Array o Dictionary, su tamano)
##   SONDA_FOTO="8:C:/ruta/foto.png"  (guarda la pantalla a esa hora, para
##   comparar antes y despues de un cambio). Con SONDA_FOTOS=30 saca esas
##   seguidas (foto_000.png...) y con SONDA_RECORTE="x,y,an,al" solo ese trozo
##   (para ver temblores; mejor con --fixed-fps 60).
##   SONDA_FOTO_SI="Sprite:animation=flotar_pisar"  (en vez de a una hora:
##   cada vez que esa propiedad pasa a valer eso, guarda los SONDA_ANTES=6
##   fotogramas de antes y SONDA_FOTOS de despues, en SONDA_FOTO="0:C:/ruta/f.png"
##   como f_<vez>_<n>.png; con SONDA_SIGUE="Magnus,400,600" el recorte va centrado
##   en ese nodo, de ese tamano en pixeles de la pantalla; leer la pantalla
##   cuesta: con SONDA_FOTO_MIENTRAS="Magnus:_vuelo=2" solo se guardan los de
##   antes mientras pase eso)
## Uso: Godot --path ... res://scenes/dev/sonda_rendimiento.tscn --windowed
##      --resolution 1920x1080 (con LUZ_PRUEBA y demas, para los pilotos).

const TIRON_MS := 50.0

var _t := 0.0
var _acum := 0.0
var _peor := 0.0
var _lentos := 0
var _marcos := 0
var _guion: Array = []
var _hecho := {}
var _cada := 1.0
var _rid: RID
var _ocultado := false
var _vistas: Array[RID] = []   # las SubViewports de la escena (su grafica va aparte)
var _escena: Node
var _cpu := 0.0
var _fis := 0.0
var _antes_us := 0             # reloj real del fotograma anterior (el delta puede ir suavizado)
var _foto_t := -1.0
var _foto_tiempos: Array = []   # SONDA_FOTO_TIEMPOS="1.5,2,3.5": una foto a cada hora
var _foto := ""
var _fotos := 1
var _foto_i := 0
var _recorte := Rect2i()
var _si := PackedStringArray()     # [nodo, propiedad, valor] (SONDA_FOTO_SI)
var _si_antes := false
var _si_vez := 0
var _si_quedan := 0
var _anillo: Array[Image] = []
var _sigue := PackedStringArray()  # [nodo, ancho, alto] (SONDA_SIGUE)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for paso in OS.get_environment("SONDA_GUION").split(";", false):
		var p := paso.split(":")
		_guion.append([float(p[0]), p[1], float(p[2])])
	var cada := OS.get_environment("SONDA_CADA")
	if cada != "":
		_cada = float(cada)
	var foto := OS.get_environment("SONDA_FOTO")
	if foto != "":
		var i := foto.find(":")
		_foto_t = float(foto.substr(0, i))
		_foto = foto.substr(i + 1)
		var n := OS.get_environment("SONDA_FOTOS")
		if n != "":
			_fotos = int(n)
		var r := OS.get_environment("SONDA_RECORTE").split(",", false)
		if r.size() == 4:
			_recorte = Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
	var si := OS.get_environment("SONDA_FOTO_SI")
	if si != "":
		var a := si.split("=")
		var nv := a[0].split(":")
		_si = PackedStringArray([nv[0], nv[1], a[1]])
		_foto_t = -1.0
	_sigue = OS.get_environment("SONDA_SIGUE").split(",", false)
	var tiempos := OS.get_environment("SONDA_FOTO_TIEMPOS")
	if tiempos != "":
		_foto_tiempos = Array(tiempos.split(",", false))
		_foto_t = -1.0
	_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_rid, true)
	var destino := OS.get_environment("SONDA_ESCENA")
	if destino == "":
		destino = "res://main.tscn"
	# colgada de la raiz para sobrevivir a los cambios de escena
	var raiz := get_tree().root
	get_parent().remove_child.call_deferred(self)
	raiz.add_child.call_deferred(self)
	get_tree().change_scene_to_file.call_deferred(destino)

func _vars(esc: Node) -> String:
	var txt := ""
	if esc == null:
		return txt
	for par in OS.get_environment("SONDA_VARS").split(",", false):
		var nv := par.split(":")
		var nodo: Node = esc if nv[0] == "." else (get_node_or_null(nv[0]) if nv[0].begins_with("/") else esc.find_child(nv[0], true, false))
		if nodo == null:
			continue
		var v: Variant = nodo.get(nv[1])
		if v is Array or v is Dictionary:
			v = v.size()
		txt += " | %s.%s %s" % [nv[0], nv[1], str(v)]
	return txt

## Un fotograma, recortado (centrado en SONDA_SIGUE si lo hay).
func _captura() -> Image:
	var img := get_viewport().get_texture().get_image()
	var esc := get_tree().current_scene
	if _sigue.size() == 3 and esc:
		var n := esc.find_child(_sigue[0], true, false) as CanvasItem
		if n:
			var k := float(img.get_width()) / get_viewport().get_visible_rect().size.x
			var c := n.get_global_transform_with_canvas().origin * k
			var w := int(_sigue[1])
			var h := int(_sigue[2])
			var x := clampi(int(c.x) - w / 2, 0, img.get_width() - w)
			var y := clampi(int(c.y) - h * 3 / 4, 0, img.get_height() - h)
			return img.get_region(Rect2i(x, y, w, h))
	if _recorte.size != Vector2i.ZERO:
		return img.get_region(_recorte)
	return img

## SONDA_FOTO_SI: guarda lo de antes y lo de despues de cada vez que pasa.
func _foto_si() -> void:
	var antes := int(OS.get_environment("SONDA_ANTES")) if OS.get_environment("SONDA_ANTES") != "" else 6
	var esc := get_tree().current_scene
	var n := esc.find_child(_si[0], true, false) if esc else null
	var ahora := n != null and str(n.get(_si[1])) == _si[2]
	var mientras := OS.get_environment("SONDA_FOTO_MIENTRAS")
	if mientras != "" and _si_quedan <= 0 and not (ahora and not _si_antes):
		var a := mientras.split("=")
		var nv := a[0].split(":")
		var m := esc.find_child(nv[0], true, false) if esc else null
		if m == null or str(m.get(nv[1])) != a[1]:
			_si_antes = ahora
			return
	var img := _captura()
	if _si_quedan > 0:
		img.save_png(_foto.get_basename() + "_%d_%02d.png" % [_si_vez, antes + _fotos - _si_quedan])
		_si_quedan -= 1
	elif ahora and not _si_antes:
		_si_vez += 1
		for j in _anillo.size():
			_anillo[j].save_png(_foto.get_basename() + "_%d_%02d.png" % [_si_vez, j])
		img.save_png(_foto.get_basename() + "_%d_%02d.png" % [_si_vez, antes])
		_si_quedan = _fotos - 1
		print("FOTO_SI vez %d t=%.2f%s" % [_si_vez, _t, _vars(esc)])
	_si_antes = ahora
	_anillo.append(img)
	while _anillo.size() > antes:
		_anillo.pop_front()

func _pulsar(accion: String, si: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = accion
	ev.pressed = si
	Input.parse_input_event(ev)

func _process(d: float) -> void:
	var ahora := Time.get_ticks_usec()
	var real := (ahora - _antes_us) / 1e6 if _antes_us > 0 else d
	_antes_us = ahora
	_t += d
	_acum += d
	_marcos += 1
	_peor = maxf(_peor, real)
	if real > 0.020:
		_lentos += 1
	if real * 1000.0 > TIRON_MS and _t > 0.5:
		var e := get_tree().current_scene
		var anim := ""
		var mg := e.find_child("Magnus", true, false) if e else null
		if mg and mg.has_node("Sprite"):
			anim = " (%s)" % (mg.get_node("Sprite") as AnimatedSprite2D).animation
		print("TIRON t=%6.2f (reloj %6.2f) %5.0f ms en %s%s%s" % [_t, Time.get_ticks_msec() / 1000.0, real * 1000.0, e.name if e else "-", anim, _vars(e)])
	for i in _guion.size():
		var g: Array = _guion[i]
		if not _hecho.has(i) and _t >= g[0]:
			_hecho[i] = true
			# como un evento (lo ven tambien _input y _unhandled_input: dobles toques)
			_pulsar(g[1], true)
			get_tree().create_timer(g[2]).timeout.connect(_pulsar.bind(g[1], false))
	if not _foto_tiempos.is_empty() and _t >= float(_foto_tiempos[0]):
		var tf := float(_foto_tiempos.pop_front())
		_captura().save_png(_foto.get_basename() + "_%05.2f.png" % tf)
	if _foto_t >= 0.0 and _t >= _foto_t:
		var img := get_viewport().get_texture().get_image()
		if _recorte.size != Vector2i.ZERO:
			img = img.get_region(_recorte)
		var ruta := _foto if _fotos == 1 else _foto.get_basename() + "_%03d.png" % _foto_i
		img.save_png(ruta)
		_foto_i += 1
		if _foto_i >= _fotos:
			_foto_t = -1.0
			print("FOTO %s (%d)" % [_foto, _fotos])
	if _si.size() == 3:
		_foto_si()
	var ocultar_t := OS.get_environment("SONDA_OCULTAR_T")
	if not _ocultado and _t > (float(ocultar_t) if ocultar_t != "" else 4.0) and OS.get_environment("SONDA_OCULTAR") != "":
		_ocultado = true
		for n in OS.get_environment("SONDA_OCULTAR").split(",", false):
			var nodo := get_tree().current_scene.find_child(n, true, false)
			if nodo is CanvasItem:
				(nodo as CanvasItem).visible = false
				print("OCULTO %s (%s)" % [n, nodo.name])
			else:
				print("NO ENCUENTRO %s" % n)
	_cpu = maxf(_cpu, Performance.get_monitor(Performance.TIME_PROCESS))
	_fis = maxf(_fis, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
	if get_tree().current_scene != _escena:
		_escena = get_tree().current_scene
		_vistas.clear()
		if _escena:
			for v in _escena.find_children("*", "SubViewport", true, false):
				var r := (v as SubViewport).get_viewport_rid()
				RenderingServer.viewport_set_measure_render_time(r, true)
				_vistas.append(r)
	if _acum >= _cada:
		var esc := get_tree().current_scene
		var sub := 0.0
		var cada_vista := ""
		for r in _vistas:
			var g := RenderingServer.viewport_get_measured_render_time_gpu(r)
			sub += g
			cada_vista += " %.1f" % g
		print("SONDA t=%6.1f (reloj %6.1f) %-18s fps %3d peor %5.1f ms lentos %3d/%3d | grafica %5.1f ms + vistas %4.1f (%s) | cpu %4.1f fis %4.1f | dibujos %4d objetos %5d | vram %4.0f MB | nodos %5d" % [
			_t, Time.get_ticks_msec() / 1000.0, esc.name if esc else "-", Engine.get_frames_per_second(), _peor * 1000.0, _lentos, _marcos,
			RenderingServer.viewport_get_measured_render_time_gpu(_rid), sub, cada_vista.strip_edges(),
			_cpu * 1000.0, _fis * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT)] + _vars(esc))
		_acum = 0.0
		_cpu = 0.0
		_fis = 0.0
		_peor = 0.0
		_lentos = 0
		_marcos = 0
