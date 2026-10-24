extends Node2D
## Banco de pruebas del peregrino en TRES CUARTOS (el del camino izquierdo del
## cruce), como prueba_frontal para el de frente. El personaje es el del juego,
## scripts/characters/peregrino_tres_cuartos.gd: lo que se ajuste aqui (en sus
## animaciones, raw/master_builder/anim/peregrino_diagonal, o en su script) sale
## igual en la escena. Aqui, sin fondo ni luz: un suelo de rejilla visto con la
## misma camara que la foto del camino (horizonte, foco), un camino recto por el
## suelo con el angulo que se quiera y lo que hace en un letrero.
##
##   arriba / izquierda     hacia el fondo          abajo / derecha   hacia la camara
##   suelto                 se para y respira       doble toque       correr (sin baculo)
##   B                      con / sin baculo (de golpe: no hay animacion de sacarlo)
##   A / D                  angulo del camino (grados respecto a la linea de vista)
##   - / +                  velocidad de andar (alturas de persona por fotograma)
##   T                      camara lenta (x1 / x0,25)       P   pausa;   .   un fotograma
##   Z                      plano general / medio (le sigue)
##   G                      rejilla del suelo (para ver si los pies patinan)
##   R                      vuelve al principio;  Esc, sale

const TRES_CUARTOS := preload("res://scripts/characters/peregrino_tres_cuartos.gd")
const PANTALLA := Vector2(2912, 1632)
## La camara (la del camino izquierdo: horizonte y foco de la foto).
const HORIZONTE := 1000.0
const CENTRO_X := 1456.0
const FOCO := 2857.0
const ALTO_POR_PIES := 324.0 / 195.3

var _p: Node2D
var _angulo := 35.0
var _camara: Camera2D
var _zoom := false
var _rejilla := true
var _lento := false
var _pausa := false
var _paso_uno := false
var _info: Label
var _fondo: Node2D


func _ready() -> void:
	WindAmbience.stop()
	_fondo = Node2D.new()
	_fondo.z_index = -10
	_fondo.draw.connect(_dibujar_fondo)
	add_child(_fondo)
	_p = TRES_CUARTOS.new()
	_p.horizonte = HORIZONTE
	_p.centro_x = CENTRO_X
	_p.foco = FOCO
	# sin cortes ni niebla: el camino entero para andar
	_p.y_corte = 99999.0
	_p.y_salida = -1.0
	_p.y_niebla = Vector2(-2.0, -3.0)
	_p.camino = _camino(_angulo)
	add_child(_p)
	_camara = Camera2D.new()
	_camara.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(_camara)
	var capa := CanvasLayer.new()
	add_child(capa)
	var ayuda := Label.new()
	ayuda.text = "PRUEBA DEL PEREGRINO EN TRES CUARTOS (el del camino izquierdo)\n" + \
		"arriba/izquierda: al fondo   abajo/derecha: hacia la camara   suelto: se para   doble toque: correr (sin baculo)\n" + \
		"B: con / sin baculo   A / D: angulo del camino   - / +: velocidad   T: lento   P: pausa   .: un fotograma\n" + \
		"Z: plano general / medio   G: rejilla   R: al principio   Esc: salir"
	ayuda.position = Vector2(60, 40)
	ayuda.add_theme_font_size_override("font_size", 36)
	ayuda.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	capa.add_child(ayuda)
	_info = Label.new()
	_info.position = Vector2(60, 1480)
	_info.add_theme_font_size_override("font_size", 32)
	_info.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	capa.add_child(_info)


## El camino: una recta por el suelo que sale de cerca de la camara, abajo a la
## derecha, y se aleja hacia la izquierda con `grados` respecto a la linea de vista;
## puntos en la foto de cerca a lejos (como los mide la escena).
func _camino(grados: float) -> PackedVector2Array:
	var dir := Vector2(-sin(deg_to_rad(grados)), cos(deg_to_rad(grados)))   # (X lateral, Z profundidad)
	var inicio := Vector2(0.55, 2.4)     # alturas de persona: a la derecha, cerca
	var pts := PackedVector2Array()
	var t := 0.0
	while pts.size() < 40:
		var g := inicio + dir * t
		var p := _a_pantalla(g)
		if p.y < HORIZONTE + 25.0 or p.x < -400.0:
			break
		pts.append(p)
		t += 0.6
	return pts


## Un punto del suelo (X, Z en alturas de persona) en la pantalla.
func _a_pantalla(g: Vector2) -> Vector2:
	var d := FOCO / maxf(g.y, 0.05)
	return Vector2(CENTRO_X + g.x * d, HORIZONTE + d / ALTO_POR_PIES)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_B:
			var i: Dictionary = _p.info()
			_p.cambiar_baston(not bool(i["baston"]))
		KEY_A, KEY_D:
			_angulo = clampf(_angulo + (-5.0 if event.keycode == KEY_A else 5.0), 0.0, 75.0)
			_p.poner_camino(_camino(_angulo))
		KEY_MINUS, KEY_KP_SUBTRACT:
			_p.andar = maxf(_p.andar - 0.001, 0.004)
		KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
			_p.andar = _p.andar + 0.001
		KEY_T:
			_lento = not _lento
			Engine.time_scale = 0.25 if _lento else 1.0
		KEY_P:
			_pausa = not _pausa
			_p.process_mode = Node.PROCESS_MODE_DISABLED if _pausa else Node.PROCESS_MODE_INHERIT
		KEY_PERIOD:
			if _pausa:
				_paso_uno = true
		KEY_Z:
			_zoom = not _zoom
		KEY_G:
			_rejilla = not _rejilla
		KEY_R:
			_p.reiniciar()
		KEY_ESCAPE:
			get_tree().quit()


func _process(delta: float) -> void:
	if _paso_uno:
		# un fotograma de animacion (a 24 por segundo)
		_paso_uno = false
		_p.process_mode = Node.PROCESS_MODE_INHERIT
		_p._process(1.0 / 24.0 / maxf(Engine.time_scale, 0.01) * Engine.time_scale)
		_p.process_mode = Node.PROCESS_MODE_DISABLED
	var i: Dictionary = _p.info()
	var pies: Vector2 = i["pies"]
	var alto: float = i["alto"]
	if _zoom:
		_camara.zoom = Vector2(2, 2)
		_camara.position = pies - Vector2(0, alto * 0.55) - PANTALLA / 4.0
	else:
		_camara.zoom = Vector2.ONE
		_camara.position = Vector2.ZERO
	_fondo.queue_redraw()
	_info.text = "%s  fotograma %d   (%s, %s)   %s   camino %d grados   andar %.3f alt/fot   alto %d px   recorrido %.2f alt%s%s" % [
		i["anim"], i["fotograma"], i["estado"], i["cara"], "con baculo" if i["baston"] else "sin baculo",
		roundi(_angulo), _p.andar, roundi(alto), i["s"], "   LENTO" if _lento else "", "   PAUSA" if _pausa else ""]


func _dibujar_fondo() -> void:
	var f := _fondo
	f.draw_rect(Rect2(-6000, -6000, 15000, 15000), Color(0.08, 0.09, 0.11))
	f.draw_rect(Rect2(-6000, HORIZONTE, 15000, 9000), Color(0.13, 0.12, 0.11))
	if _rejilla:
		# el suelo cada media altura de persona: en X, de -8 a 8; en Z, de 1,5 a 40
		var col := Color(0.24, 0.22, 0.2)
		for k in range(-16, 17):
			var x := k * 0.5
			f.draw_line(_a_pantalla(Vector2(x, 1.2)), _a_pantalla(Vector2(x, 60.0)), col, 2.0)
		var z := 1.5
		while z < 40.0:
			f.draw_line(_a_pantalla(Vector2(-12, z)), _a_pantalla(Vector2(12, z)), col, 2.0)
			z += 0.5 if z < 6.0 else (1.0 if z < 12.0 else 3.0)
	# el camino (su centro)
	var c: PackedVector2Array = _p.camino
	for k in range(1, c.size()):
		f.draw_line(c[k - 1], c[k], Color(0.55, 0.45, 0.3, 0.6), 3.0)
	f.draw_line(Vector2(-6000, HORIZONTE), Vector2(9000, HORIZONTE), Color(0.3, 0.28, 0.25), 2.0)
