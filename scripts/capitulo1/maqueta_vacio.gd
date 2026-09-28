extends Node2D
## Maqueta del capitulo 1: el vacio, el baston, la luz, el sol, las estelas y el
## arco que abre el primer camino. Es para probar la jugabilidad; el arte (cielo,
## sol, baston, camino) es provisional y esta dibujado por codigo.
##
##   1. Cae en el negro. No hay suelo que se vea ni pasos que suenen.
##   2. A lo lejos, un baston clavado en el vacio. Al llegar a el, tira: sale un
##      rayo hacia arriba y hay luz, pero aun no hay sol.
##   3. Nace el sol, partido por el horizonte. Abajo aparece el agua: refleja.
##   4. El reflejo resbala hasta el baston y se abre el trazo de un arco.
##   5. Pisar crea losas que se deshacen; saltar en el aire pisa el aire. Lo que
##      cae sobre el trazo se queda.
##   6. Con el arco entero: dovelas, clave, el reflejo cuaja en piedra y se
##      desenrolla el camino hacia el sol. Ya no se pisa el aire: vuelve a pesar.
##
## Camara fija, todo cabe en un cuadro (2912x1632).

const Peregrino := preload("res://scripts/capitulo1/peregrino_sueno.gd")
const Estelas := preload("res://scripts/capitulo1/estelas.gd")
const Arco := preload("res://scripts/capitulo1/arco_reflejo.gd")
const Pensamientos := preload("res://scripts/capitulo1/pensamientos.gd")
const Sintetizador := preload("res://scripts/capitulo1/sintetizador.gd")
const SHADER_AGUA := preload("res://scripts/capitulo1/agua_reflejo.gdshader")
const SHADER_CIELO := preload("res://scripts/capitulo1/cielo.gdshader")
const FUENTE := preload("res://assets/fonts/IMFellEnglish-Italic.ttf")

const ANCHO := 2912.0
const ALTO := 1632.0

@export var horizonte: float = 1150.0
@export var x_baston: float = 1250.0
@export var x_sol: float = 2380.0
@export var radio_sol: float = 170.0
@export var x_inicio: float = 430.0
## "estelas" empieza con el sol ya nacido y el control dado (para probar).
@export_enum("entrada", "estelas") var empezar_en: String = "entrada"
## Solo pruebas: cierra el arco a los n segundos de empezar las estelas.
@export var cerrar_a_los: float = -1.0

enum Fase { ENTRADA, VACIO, BASTON, ESTELAS, CIERRE, CAMINO, FIN }

var _fase := Fase.ENTRADA
var _t := 0.0
var _t_estelas := 0.0
var _luz := 0.0
var _sol := 0.0
var _sol_r := 0.0
var _presencia := 0.0
var _columna := 0.0
var _columna_alfa := 0.0
var _camino := 0.0
var _vio_deshacer := false
var _primera_fija := -1.0

var _cielo: ColorRect
var _agua: ColorRect
var _sol_nodo: Node2D
var _baston: Node2D
var _camino_nodo: Node2D
var _arco: Arco
var _estelas: Estelas
var _peregrino: Peregrino
var _pens: Pensamientos
var _pared_derecha: StaticBody2D
var _fundido: ColorRect
var _fin: Label
var _halo: Texture2D
var _columna_tex: Texture2D
var _hojas: Array = []
var _brillo: AudioStreamPlayer

func _ready() -> void:
	if has_node("/root/WindAmbience"):
		get_node("/root/WindAmbience").fade_to(-40.0, 3.0)
	if has_node("/root/MusicAmbience"):
		get_node("/root/MusicAmbience").apagar_titulo(2.0)
	_construir()
	if empezar_en == "estelas":
		_empezar_en_estelas()
	else:
		_entrada()

# --- Construccion -------------------------------------------------------------

func _construir() -> void:
	_halo = _textura_halo()
	_columna_tex = _textura_columna()
	var camara := Camera2D.new()
	camara.position = Vector2(ANCHO, ALTO) * 0.5
	add_child(camara)
	camara.make_current()

	_cielo = ColorRect.new()
	_cielo.size = Vector2(ANCHO, ALTO)
	_cielo.z_index = -20
	_cielo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mc := ShaderMaterial.new()
	mc.shader = SHADER_CIELO
	mc.set_shader_parameter("horizonte_uv", horizonte / ALTO)
	mc.set_shader_parameter("sol_uv", Vector2(x_sol / ANCHO, horizonte / ALTO))
	mc.set_shader_parameter("baston_u", x_baston / ANCHO)
	_cielo.material = mc
	add_child(_cielo)

	_sol_nodo = Node2D.new()
	_sol_nodo.z_index = -10
	_sol_nodo.draw.connect(_dibujar_sol)
	add_child(_sol_nodo)

	_baston = Node2D.new()
	_baston.z_index = 0
	_baston.draw.connect(_dibujar_baston)
	add_child(_baston)

	_arco = Arco.new()
	_arco.name = "Arco"
	_arco.centro = Vector2(x_baston, horizonte)
	_arco.z_index = 1
	add_child(_arco)

	_estelas = Estelas.new()
	_estelas.name = "Estelas"
	_estelas.z_index = 2
	add_child(_estelas)

	_peregrino = Peregrino.crear() as Peregrino
	_peregrino.z_index = 3
	_peregrino.position = Vector2(x_inicio, horizonte)
	add_child(_peregrino)

	_estelas.arco = _arco
	_estelas.conectar(_peregrino)
	_arco.peregrino = _peregrino
	_arco.estelas = _estelas

	_agua = ColorRect.new()
	_agua.position = Vector2(0, horizonte)
	_agua.size = Vector2(ANCHO, ALTO - horizonte)
	_agua.z_index = 10
	_agua.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ma := ShaderMaterial.new()
	ma.shader = SHADER_AGUA
	ma.set_shader_parameter("horizonte_uv", horizonte / ALTO)
	_agua.material = ma
	add_child(_agua)

	_camino_nodo = Node2D.new()
	_camino_nodo.z_index = 11
	_camino_nodo.draw.connect(_dibujar_camino)
	add_child(_camino_nodo)

	# El agua sostiene siempre (capa 1); paredes a los lados del cuadro.
	_suelo(Vector2(0, horizonte), Vector2.UP)
	_suelo(Vector2(110, 0), Vector2.RIGHT)
	_pared_derecha = _suelo(Vector2(ANCHO - 110, 0), Vector2.LEFT)

	_pens = Pensamientos.new()
	add_child(_pens)

	var capa := CanvasLayer.new()
	capa.layer = 20
	add_child(capa)
	_fundido = ColorRect.new()
	_fundido.color = Color(0, 0, 0, 0)
	_fundido.size = Vector2(ANCHO, ALTO)
	_fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_fundido)
	_fin = Label.new()
	var ls := LabelSettings.new()
	ls.font = FUENTE
	ls.font_size = 64
	ls.font_color = Color(0.91, 0.87, 0.78)
	_fin.label_settings = ls
	_fin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fin.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fin.size = Vector2(ANCHO, ALTO)
	_fin.text = "Fin de la maqueta\n\n(saltar para volver a empezar)"
	_fin.modulate.a = 0.0
	capa.add_child(_fin)

	_brillo = AudioStreamPlayer.new()
	_brillo.stream = Sintetizador.acorde([220.0, 329.63, 440.0], 6.0, 0.25)
	_brillo.volume_db = -14.0
	add_child(_brillo)

	_estelas.losa_creada.connect(_al_crear_losa)
	_estelas.losa_creada.connect(_arco.al_crear_losa)
	_estelas.losa_deshecha.connect(_al_deshacerse)
	_arco.recordado_tocado.connect(func(): _pens.decir("ya_estaba", ["Esto ya estaba aquí.", "¿Quién lo pondría?"], false, true))
	_arco.pista_trozo.connect(func(): _pens.decir("trozo", ["Le falta un trozo."], false, true, 20.0))
	_arco.cerrado.connect(_cierre)

	var azar := RandomNumberGenerator.new()
	azar.seed = 99
	for i in 140:
		_hojas.append([azar.randf(), azar.randf_range(-3.0, 1.0), azar.randf_range(3.0, 7.0), azar.randi() % 3, azar.randf_range(0.0, TAU)])

func _suelo(p: Vector2, normal: Vector2) -> StaticBody2D:
	var c := StaticBody2D.new()
	c.collision_layer = 1
	c.collision_mask = 0
	var f := CollisionShape2D.new()
	var w := WorldBoundaryShape2D.new()
	w.normal = normal
	f.shape = w
	c.add_child(f)
	c.position = p
	add_child(c)
	return c

## Degradado horizontal 0-1-0 para la columna de luz: un rayo, no un huso.
func _textura_columna() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 4
	return t

func _textura_halo() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t

# --- Secuencia ----------------------------------------------------------------

func _entrada() -> void:
	_fase = Fase.ENTRADA
	_peregrino.modulate = Color(0.5, 0.5, 0.56)
	get_tree().create_timer(1.3).timeout.connect(func(): _pens.decir("cayendo", ["¿Estoy cayendo?"]))
	await _peregrino.caer_en_el_vacio(-260.0, horizonte, 3.6)
	_peregrino.control = true
	_fase = Fase.VACIO
	_pens.decir("donde", ["¿Dónde estoy?", "¿Cómo he llegado aquí?"], false, false, 4.0)
	get_tree().create_timer(16.0).timeout.connect(func():
		if _fase == Fase.VACIO:
			_pens.decir("nombre", ["¿Cómo me llamo?", "Lo tenía hace un momento."]))

func _tomar_baston() -> void:
	_fase = Fase.BASTON
	_peregrino.control = false
	_peregrino.velocity.x = 0.0
	_peregrino.mirar_hacia(x_baston)
	# Se pone junto al baston, y el baston delante de el: lo agarra.
	var lado := -1.0 if _peregrino.global_position.x < x_baston else 1.0
	create_tween().tween_property(_peregrino, "position:x", x_baston + lado * 34.0, 0.4)
	_baston.z_index = 4
	_pens.decir("clavado", ["Está clavado.", "¿En qué, si aquí no hay nada?"], true)
	await get_tree().create_timer(0.8).timeout
	await _pens.esperar_silencio(6.0)
	await get_tree().create_timer(0.6).timeout
	# Tira hacia arriba: el rayo sale de la punta y sube hasta el cielo.
	_brillo.play()
	var tw := create_tween()
	tw.tween_property(self, "_columna", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "_columna_alfa", 1.0, 0.2)
	await tw.finished
	var tl := create_tween().set_parallel()
	tl.tween_property(self, "_luz", 0.75, 2.5).set_trans(Tween.TRANS_SINE)
	tl.tween_property(self, "_presencia", 0.25, 2.5)
	tl.tween_property(self, "_columna_alfa", 0.0, 3.0).set_delay(0.6)
	tl.tween_property(_peregrino, "modulate", Color.WHITE, 2.5)
	await get_tree().create_timer(1.0).timeout
	_pens.decir("luz", ["Hay luz…", "¿Pero de dónde sale?"], true)
	await get_tree().create_timer(1.0).timeout
	await _pens.esperar_silencio(7.0)
	_baston.z_index = 0
	await get_tree().create_timer(0.8).timeout
	# Nace el sol, bajo, partido por el horizonte. El agua aparece al reflejarlo.
	_sol_r = radio_sol * 0.88
	var ts := create_tween().set_parallel()
	ts.tween_property(self, "_sol_r", radio_sol, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	ts.tween_property(self, "_sol", 1.0, 3.0)
	ts.tween_property(self, "_luz", 1.0, 3.0)
	ts.tween_property(self, "_presencia", 1.0, 3.5)
	await get_tree().create_timer(1.8).timeout
	_pens.decir("atardece", ["¿Está atardeciendo?", "¿O amanece?"], true)
	await ts.finished
	await _pens.esperar_silencio(6.0)
	await _arco.aparecer(x_sol - radio_sol * 0.5, 3.0)
	_empezar_estelas()

func _empezar_en_estelas() -> void:
	_luz = 1.0
	_sol = 1.0
	_sol_r = radio_sol
	_presencia = 1.0
	_peregrino.position = Vector2(x_inicio, horizonte)
	_arco.aparecer_ya()
	_empezar_estelas()

func _empezar_estelas() -> void:
	_fase = Fase.ESTELAS
	_t_estelas = 0.0
	_peregrino.control = true
	_peregrino.pasos_en_aire = true
	_peregrino.crear_suelo = true
	_peregrino.sonar_pasos = true
	_estelas.activo = true
	get_tree().create_timer(16.0).timeout.connect(func():
		if _fase == Fase.ESTELAS:
			_pens.decir("viejo", ["¿Ese viejo soy yo?"], false, false, 12.0))

func _al_crear_losa(_l) -> void:
	if _fase == Fase.ESTELAS:
		_pens.decir("hecho", ["¿Esto lo he hecho yo?"], false, false, 4.0)

func _al_deshacerse(_l) -> void:
	if not _vio_deshacer and _fase == Fase.ESTELAS:
		_vio_deshacer = true
		_pens.decir("deshace", ["Se deshace.", "Como todo lo que intento recordar."], false, false, 8.0)

func _cierre() -> void:
	_fase = Fase.CIERRE
	_peregrino.volver_a_pesar(2.0)
	_estelas.recoger_hacia_el_arco()
	_pens.callar()
	await get_tree().create_timer(4.2).timeout
	_pens.decir("nada", ["Nada surge de la nada.", "¿Quién me decía eso?"], true)
	# La pared de la derecha se aparta al borde: el final espera dentro del cuadro.
	_pared_derecha.position.x = ANCHO - 130.0
	create_tween().tween_property(self, "_camino", 1.0, 4.0).set_trans(Tween.TRANS_SINE)
	_fase = Fase.CAMINO

func _terminar() -> void:
	_fase = Fase.FIN
	_peregrino.control = false
	var tw := create_tween()
	tw.tween_property(_fundido, "color:a", 1.0, 2.5)
	tw.tween_property(_fin, "modulate:a", 1.0, 1.5)

func _unhandled_input(evento: InputEvent) -> void:
	if _fase == Fase.FIN and _fin.modulate.a > 0.9 and evento.is_action_pressed("saltar"):
		get_tree().reload_current_scene()

func _process(delta: float) -> void:
	_t += delta
	match _fase:
		Fase.VACIO:
			if absf(_peregrino.global_position.x - x_baston) < 70.0:
				_tomar_baston()
		Fase.ESTELAS:
			_t_estelas += delta
			if _primera_fija < 0.0 and _estelas.cuantas_fijas() > 0:
				_primera_fija = _t
			if _vio_deshacer and _primera_fija > 0.0 and _t - _primera_fija > 8.0:
				_pens.decir("estas_no", ["Estas no se van.", "¿Por qué estas no?"], false, true)
			if cerrar_a_los > 0.0 and _t_estelas > cerrar_a_los:
				cerrar_a_los = -1.0
				_arco.forzar_cierre()
		Fase.CAMINO:
			var x := _peregrino.global_position.x
			# De uno en uno: si no, caducan mientras se dice el anterior.
			if not _pens.hablando():
				if not _pens.dicho("aguanta"):
					if x > x_baston + _arco.radio + 140.0:
						_pens.decir("aguanta", ["Esta sí aguanta."])
				elif x > 2250.0:
					_pens.decir("bosque", ["Huele a bosque.", "Y aquí no hay árboles."])
			if x > ANCHO - 180.0 and _pens.dicho("bosque") and not _pens.hablando():
				_terminar()
	var mc: ShaderMaterial = _cielo.material
	mc.set_shader_parameter("luz", _luz)
	mc.set_shader_parameter("sol", _sol)
	(_agua.material as ShaderMaterial).set_shader_parameter("presencia", _presencia)
	_sol_nodo.queue_redraw()
	_baston.queue_redraw()
	_camino_nodo.queue_redraw()

# --- Dibujo provisional ---------------------------------------------------------

## Sol facetado de 16 lados con halo. La mitad de abajo la tapa el agua, que la
## refleja: por eso se ve partido, "¿atardece o amanece?".
func _dibujar_sol() -> void:
	if _sol_r <= 0.5:
		return
	var c := Vector2(x_sol, horizonte)
	var halo := _sol_r * 2.6
	_sol_nodo.modulate.a = _sol
	_sol_nodo.draw_texture_rect(_halo, Rect2(c - Vector2(halo, halo), Vector2(halo, halo) * 2.0), false, Color(0.79, 0.56, 0.29, 0.22))
	# Facetas casi del mismo tono, sin aristas: se intuyen, no se dibujan.
	var n := 16
	var borde := PackedVector2Array()
	var foco := c + Vector2(0, -0.35 * _sol_r)  # abanico descentrado: no gajos
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := c + Vector2(cos(a0), sin(a0)) * _sol_r
		var p1 := c + Vector2(cos(a1), sin(a1)) * _sol_r
		var col := Color("f5e1b2") if i % 2 == 0 else Color("f4dfae")
		_sol_nodo.draw_colored_polygon(PackedVector2Array([foco, p0, p1]), col)
		borde.append(p0)
	borde.append(borde[0])
	_sol_nodo.draw_polyline(borde, Color("e9b872", 0.7), 2.0, true)

## Baston clavado en el vacio: en el negro solo se intuye (una linea tenue que
## late y la punta). Luego es el eje del arco, la pata del compas.
func _dibujar_baston() -> void:
	var pie := Vector2(x_baston, horizonte)
	var punta := pie + Vector2(0, -290)
	var late := 0.5 + 0.5 * sin(_t * 1.6)
	var a := 1.0 if _luz > 0.05 else 0.22 + 0.10 * late
	_baston.draw_line(pie, punta, Color(0.35, 0.26, 0.19, a), 7.0, true)
	_baston.draw_line(pie + Vector2(2, 0), punta + Vector2(2, 0), Color(0.52, 0.39, 0.27, a), 2.5, true)
	var cristal := PackedVector2Array([punta + Vector2(0, -22), punta + Vector2(8, -8), punta + Vector2(0, 4), punta + Vector2(-8, -8)])
	_baston.draw_colored_polygon(cristal, Color(1.0, 0.92, 0.72, 0.5 + 0.5 * a))
	var h := 40.0 + 20.0 * late
	_baston.draw_texture_rect(_halo, Rect2(punta + Vector2(-h, -8 - h), Vector2(h, h) * 2.0), false, Color(1.0, 0.85, 0.55, 0.30 if _luz < 0.05 else 0.18))
	if _columna_alfa > 0.0:
		var alto := (punta.y + 30.0) * _columna
		var arriba := punta + Vector2(0, -alto)
		_baston.draw_texture_rect(_columna_tex, Rect2(Vector2(pie.x - 45, arriba.y), Vector2(90, alto)), false, Color(1.0, 0.9, 0.7, 0.55 * _columna_alfa))
		_baston.draw_line(punta, arriba, Color(1.0, 0.96, 0.85, _columna_alfa), 4.0, true)

## Camino de tierra y hojarasca que se desenrolla desde el pie derecho del arco
## hacia el sol. Va por encima del agua (no se refleja: es provisional).
func _dibujar_camino() -> void:
	if _camino <= 0.0:
		return
	var x0 := x_baston + _arco.radio - 10.0
	var x1 := lerpf(x0, ANCHO, _camino)
	var pts := PackedVector2Array()
	var paso := 24.0
	var x := x0
	while x < x1:
		pts.append(Vector2(x, horizonte - 1.0 + 2.0 * sin(x * 0.05)))
		x += paso
	pts.append(Vector2(x1, horizonte))
	var fondo := PackedVector2Array()
	for i in range(pts.size() - 1, -1, -1):
		fondo.append(Vector2(pts[i].x, horizonte + 30.0 + 6.0 * sin(pts[i].x * 0.13)))
	var cuerpo := pts.duplicate()
	cuerpo.append_array(fondo)
	if cuerpo.size() >= 3:
		_camino_nodo.draw_colored_polygon(cuerpo, Color("3b2e24"))
		_camino_nodo.draw_polyline(pts, Color("6a5238"), 5.0, true)
	var colores := [Color("a86a34"), Color("c9913e"), Color("7e4a2a")]
	for h in _hojas:
		var hx: float = lerpf(x0, ANCHO, h[0])
		if hx > x1:
			continue
		var p := Vector2(hx, horizonte + h[1])
		var r: float = h[2]
		var giro: float = h[4]
		var hoja := PackedVector2Array([p + Vector2(r, 0).rotated(giro), p + Vector2(0, r * 0.45).rotated(giro), p + Vector2(-r, 0).rotated(giro), p + Vector2(0, -r * 0.45).rotated(giro)])
		_camino_nodo.draw_colored_polygon(hoja, colores[h[3]])
