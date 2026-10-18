extends "res://scripts/ui/menu_base.gd"
## Menu de la pantalla de titulo, grabado en el cristal del ataud (2026-10-17).
## Lo pone title_screen_controller.gd en modo menu cuando la sala ya esta
## encendida.
##
##  - Reposo: solo el titulo, sin nada escrito debajo (2026-10-18: el usuario
##    quito el "Pulsa cualquier tecla"). Cualquier tecla abre el menu; sin tocar
##    nada, sale solo a los abrir_solo s, pero solo la primera vez: si se vuelve
##    al titulo con Esc, espera a que se pulse.
##  - Al abrirse, las letras pintadas se funden con la placa sin letras (el
##    controlador, mostrar_letras) y en su sitio sale el menu: Continuar (si hay
##    partida), Nueva partida, Opciones y Salir. Esc vuelve al reposo y las
##    letras vuelven.
##  - Nueva partida: el selector de escenas, en fila, con su miniatura: "Desde el
##    principio" (el ataud) y las escenas clave a las que se ha llegado
##    (Partida.desbloqueados). Si queda alguna por llegar, un cuadro a oscuras al
##    final, sin nombre ni dibujo (que hay mas, sin decir que). Con partida
##    guardada pregunta antes de borrarla.
##  - Al elegir, el menu se apaga y el controlador hace la salida de siempre
##    (velas, cristal, camara) hacia la escena (salir_hacia).

const MINIATURA := "res://assets/ui/miniaturas/%s.png"
## Centro del sitio util del cristal (px de la imagen; con el zoom de reposo, 1,
## son tambien px de pantalla): entre las dos velas (CANDLE_A y CANDLE_B de
## title_screen_controller.gd, x 868 y 1852), y algo por encima de ellas. Ahi
## van las letras del titulo (titulo_letras.gd) y el menu. (El 2026-10-18 se
## probo el centro del marco, 1419, 830, y quedaba a la derecha y bajo.)
const CENTRO_CRISTAL := Vector2(1360.0, 800.0)
## Ancho util entre las velas, dejando su resplandor libre: nada del menu debe
## pasar de aqui.
const ANCHO_UTIL := 760.0

@export var tam_carta: float = 250.0
@export var hueco_carta: float = 54.0
@export var aparecer: float = 0.6
@export var apagarse: float = 0.45
## Sin tocar nada, el menu sale solo pasado esto (s) desde que la sala queda
## encendida.
@export var abrir_solo: float = 4.0

## La pantalla de titulo: mostrar_letras(si) y salir_hacia(escena).
var titulo: Node

var _en_reposo := true
var _tw_solo: Tween
var _cartas: Array[Control] = []
var _nombre: Label


func _ready() -> void:
	layer = 102
	tam_opcion = 52
	paso_opcion = 80.0
	centro_x = CENTRO_CRISTAL.x
	_montar()
	_poner_reposo(abrir_solo)


# ---------------------------------------------------------------- reposo

## espera: lo que tarda el menu en salir solo; si es negativa, no sale solo.
func _poner_reposo(espera := -1.0) -> void:
	_limpiar()
	_en_reposo = true
	_atras = Callable()
	_contenido.modulate.a = 1.0
	if _tw_solo and _tw_solo.is_valid():
		_tw_solo.kill()
	if espera >= 0.0:
		_tw_solo = create_tween()
		_tw_solo.tween_interval(espera)
		_tw_solo.tween_callback(_abrir_menu)


func _input(event: InputEvent) -> void:
	if not _en_reposo:
		super(event)
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction \
			or event is InputEventMouseButton):
		return
	get_viewport().set_input_as_handled()
	if _cerrando or not event.is_pressed() or event.is_echo():
		return
	_abrir_menu()


func _abrir_menu() -> void:
	_en_reposo = false
	if _tw_solo and _tw_solo.is_valid():
		_tw_solo.kill()
	titulo.mostrar_letras(false)
	# Las letras se van y, a medio irse, el menu sale en su sitio.
	_cerrando = true
	var tw := create_tween()
	tw.tween_property(_contenido, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void:
		_poner_menu()
		_aparecer())


func _aparecer() -> void:
	_cerrando = true
	_contenido.modulate.a = 0.0
	for r in _llamas + [_brillo]:
		r.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_contenido, "modulate:a", 1.0, aparecer).set_trans(Tween.TRANS_SINE).set_delay(0.3)
	for r in _llamas + [_brillo]:
		tw.tween_property(r, "modulate:a", 1.0, aparecer).set_trans(Tween.TRANS_SINE).set_delay(0.3)
	tw.chain().tween_callback(func() -> void: _cerrando = false)


func _volver_al_reposo() -> void:
	_cerrando = true
	titulo.mostrar_letras(true)
	var tw := create_tween().set_parallel()
	tw.tween_property(_contenido, "modulate:a", 0.0, 0.3)
	for r in _llamas + [_brillo]:
		tw.tween_property(r, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func() -> void:
		_cerrando = false
		_poner_reposo())


# ---------------------------------------------------------------- pantallas

func _ops_menu() -> Array:
	var ops := []
	if Partida.hay_guardada():
		ops.append({"texto": "menu.continuar", "elegir": _continuar, "id": "continuar"})
	ops.append({"texto": "menu.nueva_partida", "elegir": _nueva, "id": "nueva"})
	ops.append({"texto": "menu.opciones", "elegir": _poner_opciones, "id": "opciones"})
	ops.append({"texto": "menu.salir", "elegir": _confirmar_salir, "id": "salir"})
	return ops


## Vuelve al menu con la opcion "id" elegida.
func _poner_menu(id := "") -> void:
	_limpiar()
	var ops := _ops_menu()
	var sel := 0
	for i in ops.size():
		if ops[i]["id"] == id:
			sel = i
	_lista(ops, CENTRO_CRISTAL.y, sel)
	_atras = _volver_al_reposo


func _poner_opciones() -> void:
	_pantalla_opciones(_poner_menu.bind("opciones"), CENTRO_CRISTAL.y + 40.0)


func _confirmar_salir() -> void:
	_pantalla_confirmar("confirmar.salir", "", "confirmar.si_salir", _salir, _poner_menu.bind("salir"), CENTRO_CRISTAL.y)


func _salir() -> void:
	_cerrando = true
	GlobalExit.salir()


func _nueva() -> void:
	if Partida.desbloqueados().is_empty():
		_elegir_inicio("")
	else:
		_poner_selector()


# ---------------------------------------------------------------- selector

func _poner_selector(sel := 0) -> void:
	_limpiar()
	_horizontal = true
	_cartas.clear()
	var entradas := [{"id": "", "nombre": "menu.desde_principio", "mini": "principio"}]
	for p in Partida.desbloqueados():
		entradas.append({"id": p, "nombre": Partida.PUNTOS[p]["nombre"], "mini": p})
	# Que queda alguna escena clave por llegar: un cuadro a oscuras al final.
	var faltan := false
	for p in Partida.PUNTOS:
		if Partida.PUNTOS[p].get("clave", false) and not p in Partida.desbloqueados():
			faltan = true
	var n := entradas.size() + (1 if faltan else 0)
	# Si no caben entre las velas, las cartas se achican.
	var tam := minf(tam_carta, (ANCHO_UTIL - (n - 1) * hueco_carta) / n)
	var x0 := centro_x - (n - 1) * (tam + hueco_carta) * 0.5
	var y := CENTRO_CRISTAL.y - 20.0
	_cabecera("menu.empezar_desde", y - tam * 0.5 - 70.0)
	var ops := []
	for i in entradas.size():
		var e: Dictionary = entradas[i]
		var ruta: String = MINIATURA % e["mini"]
		var tex: Texture2D = load(ruta) if ResourceLoader.exists(ruta) else null
		_cartas.append(_carta(tex, Vector2(x0 + i * (tam + hueco_carta), y), tam))
		ops.append({"texto": e["nombre"], "elegir": _elegir_inicio.bind(e["id"], i)})
	if faltan:
		var oscura := _carta(null, Vector2(x0 + entradas.size() * (tam + hueco_carta), y), tam)
		oscura.modulate = Color(0.45, 0.42, 0.38, 0.55)
	_nombre = _texto_centrado(" ", FUENTE, tam_opcion, ORO_VIVO, y + tam * 0.5 + 66.0)
	_opciones = ops
	_sel = clampi(sel, 0, ops.size() - 1)
	_atras = _poner_menu.bind("nueva")
	_marcar(false)


## Un cuadro del selector: la miniatura con un marco fino como el del ataud.
func _carta(tex: Texture2D, centro: Vector2, tam: float) -> Control:
	var c := Control.new()
	c.size = Vector2(tam, tam)
	c.position = centro - c.size * 0.5
	c.pivot_offset = c.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var marco := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.025, 0.012)
	sb.set_border_width_all(4)
	sb.border_color = Color(ORO_APAGADO, 0.55)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 16
	marco.add_theme_stylebox_override("panel", sb)
	marco.position = Vector2(-9.0, -9.0)
	marco.size = c.size + Vector2(18.0, 18.0)
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(marco)
	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.size = c.size
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(img)
	c.set_meta("marco", sb)
	_contenido.add_child(c)
	return c


func _marcar(prender: bool) -> void:
	if not _horizontal:
		super(prender)
		return
	for i in _cartas.size():
		var elegida := i == _sel
		_cartas[i].modulate = Color.WHITE if elegida else Color(0.5, 0.46, 0.42)
		_cartas[i].scale = Vector2.ONE * (1.06 if elegida else 1.0)
		(_cartas[i].get_meta("marco") as StyleBoxFlat).border_color = Color(ORO, 0.9) if elegida else Color(ORO_APAGADO, 0.55)
	if _nombre == null or _opciones.is_empty():
		return
	_nombre.text = tr(String(_opciones[_sel]["texto"])).to_upper()
	_nombre.size = _nombre.get_minimum_size()
	_nombre.position.x = centro_x - _nombre.size.x * 0.5
	_flanquear(Rect2(_nombre.position, _nombre.size), prender)


# ---------------------------------------------------------------- empezar

func _elegir_inicio(id: String, sel := 0) -> void:
	if not Partida.hay_guardada():
		_empezar(id)
		return
	var volver: Callable = _poner_selector.bind(sel) if not Partida.desbloqueados().is_empty() else _poner_menu.bind("nueva")
	# Sin nombrar el punto guardado: puede ser uno que no sale en el selector
	# ("El baculo") y el jugador no lo reconoceria.
	_pantalla_confirmar("confirmar.nueva", "confirmar.nueva_detalle",
		"confirmar.si_empezar", _empezar.bind(id), volver, CENTRO_CRISTAL.y)


func _empezar(id: String) -> void:
	Partida.borrar(get_tree())
	_irse(Partida.PRINCIPIO if id == "" else Partida.empezar_en(get_tree(), id))


func _continuar() -> void:
	var escena := Partida.cargar(get_tree())
	if escena != "":
		_irse(escena)


## El menu se apaga y el titulo hace su salida hacia la escena.
func _irse(escena: String) -> void:
	_cerrando = true
	var tw := create_tween().set_parallel()
	tw.tween_property(_contenido, "modulate:a", 0.0, apagarse).set_trans(Tween.TRANS_SINE)
	for r in _llamas + [_brillo]:
		tw.tween_property(r, "modulate:a", 0.0, apagarse).set_trans(Tween.TRANS_SINE)
	titulo.salir_hacia(escena)
	tw.chain().tween_callback(queue_free)
