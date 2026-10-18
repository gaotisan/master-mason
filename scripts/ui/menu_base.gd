extends CanvasLayer
## Lo comun a los menus del juego (2026-10-17): el de pausa (menu_pausa.gd) y el
## del titulo, dentro del cristal (menu_titulo.gd). Los dos con la letra del
## titulo (Cinzel dorada) y la opcion elegida en dorado vivo entre dos llamitas,
## como las dos velas del titulo.
##
## Cada pantalla es una lista de opciones {texto: clave de textos/interfaz.csv o
## Callable que da el texto ya traducido, elegir: Callable, lado: Callable(pasos)
## opcional (izquierda/derecha cambia un valor), valor: Callable opcional que da
## [texto del valor, se puede bajar, se puede subir]}. Las que tienen valor lo
## llevan a la derecha del nombre, entre los angulitos de siempre ‹ ›. Todo el texto pasa por tr()
## (ver Ajustes y textos/LEEME.md); las funciones de dibujo traducen lo que les
## llega, asi que se les pueden pasar claves.
## Arriba/abajo (o W/S) mueve, Enter/Espacio (o E/X) elige y Esc hace _atras.
## Las de la base: las opciones (Ajustes) y la confirmacion (si/no).

const FUENTE := preload("res://assets/fonts/Cinzel-Variable.ttf")
const FUENTE_NOTA := preload("res://assets/fonts/IMFellEnglish-Italic.ttf")
const LLAMA := preload("res://scripts/ui/llama.gdshader")
const AJUSTES := preload("res://scripts/ui/ajustes.gd")

const ORO := Color(0.93, 0.76, 0.46)
const ORO_VIVO := Color(1.0, 0.84, 0.55)
const ORO_APAGADO := Color(0.68, 0.55, 0.35)
const ANCHO := 2912.0
const ALTO := 1632.0

@export var tam_opcion: int = 62
@export var paso_opcion: float = 104.0

## Centro horizontal de todo lo que se escribe (el titulo lo pone en el cristal).
var centro_x := ANCHO * 0.5
var _contenido: Control
var _llamas: Array[ColorRect] = []
var _llamas_mat: Array[ShaderMaterial] = []
var _tw_llamas: Tween

var _opciones: Array = []
var _etiquetas: Array[Label] = []
var _sel := 0
## Lo que hace Esc en la pantalla de ahora.
var _atras: Callable
## Mientras se va (o cambia de escena) no atiende teclas.
var _cerrando := false
## Lista en fila (el selector de escenas): izquierda y derecha mueven.
var _horizontal := false
## Resplandor calido detras de la opcion elegida, como luz de vela en el cristal:
## sobre el panel del titulo el dorado vivo y el apagado se parecian demasiado.
var _brillo: ColorRect
var _tw_brillo: Tween

const BRILLO := "
shader_type canvas_item;
render_mode blend_add;
uniform float fuerza = 0.16;
void fragment() {
	vec2 d = (UV - 0.5) * 2.0;
	float a = 1.0 - smoothstep(0.0, 1.0, length(d));
	COLOR = vec4(vec3(1.0, 0.62, 0.28) * a * a * fuerza, 1.0);
}
"


## Lo monta cada menu en su _ready, encima de lo suyo (el fondo de la pausa).
func _montar() -> void:
	_brillo = ColorRect.new()
	_brillo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = BRILLO
	var mb := ShaderMaterial.new()
	mb.shader = sh
	_brillo.material = mb
	_brillo.visible = false
	add_child(_brillo)
	_contenido = Control.new()
	_contenido.size = Vector2(ANCHO, ALTO)
	_contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_contenido)
	for i in 2:
		var r := ColorRect.new()
		r.size = Vector2(46.0, 76.0)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = LLAMA
		m.set_shader_parameter("semilla", randf() * 40.0 + i * 17.0)
		r.material = m
		r.visible = false
		add_child(r)
		_llamas.append(r)
		_llamas_mat.append(m)


# ---------------------------------------------------------------- pantallas comunes

func _pantalla_opciones(volver: Callable, y_centro: float, sel := 0) -> void:
	_limpiar()
	_cabecera("menu.opciones", y_centro - paso_opcion * 2.9)
	_lista([
		{"texto": "opciones.volumen", "elegir": func() -> void: pass, "lado": _cambiar_volumen,
			"valor": func() -> Array: return [tr("opciones.porcentaje") % roundi(AJUSTES.volumen * 100.0),
				AJUSTES.volumen > 0.001, AJUSTES.volumen < 0.999]},
		{"texto": "opciones.pantalla_completa", "elegir": _cambiar_pantalla,
			"lado": func(_p: int) -> void: _cambiar_pantalla(),
			"valor": func() -> Array: return [tr("comun.si" if AJUSTES.pantalla_completa else "comun.no"), true, true]},
		{"texto": "opciones.idioma", "elegir": _cambiar_idioma.bind(1, volver, y_centro),
			"lado": _cambiar_idioma.bind(volver, y_centro),
			"valor": func() -> Array: return [AJUSTES.nombre_idioma(), true, true]},
		{"texto": "menu.volver", "elegir": volver},
	], y_centro, sel)
	_atras = volver


func _cambiar_volumen(pasos: int) -> void:
	AJUSTES.cambiar_volumen(pasos)
	_refrescar()


func _cambiar_pantalla() -> void:
	AJUSTES.cambiar_pantalla()
	_refrescar()


## Cambia el idioma y rehace la pantalla entera, que ya esta en el otro.
func _cambiar_idioma(pasos: int, volver: Callable, y_centro: float) -> void:
	AJUSTES.cambiar_idioma(pasos)
	_pantalla_opciones(volver, y_centro, _sel)


## Una pregunta de si/no. La primera opcion es la que no hace nada (volver), y
## es la elegida al abrir: lo que no se deshace nunca va por defecto.
func _pantalla_confirmar(pregunta: String, detalle: String, si: String, hacer: Callable,
		volver: Callable, y_centro: float, no := "confirmar.no_volver") -> void:
	_limpiar()
	_texto_centrado(pregunta, FUENTE, int(tam_opcion * 1.08), ORO, y_centro - paso_opcion * 1.7)
	if detalle != "":
		_texto_centrado(detalle, FUENTE_NOTA, int(tam_opcion * 0.74), ORO_APAGADO, y_centro - paso_opcion * 0.75)
	_lista([
		{"texto": no, "elegir": volver},
		{"texto": si, "elegir": hacer},
	], y_centro + paso_opcion * 0.75, 0)
	_atras = volver


# ---------------------------------------------------------------- teclas

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction):
		return
	# Todo lo de teclado se queda aqui: detras no llega nada mientras dura.
	get_viewport().set_input_as_handled()
	if _cerrando or not event.is_pressed():
		return
	var k := event as InputEventKey
	var fis: Key = k.physical_keycode if k else KEY_NONE
	if (k and k.keycode == KEY_ESCAPE) or event.is_action("ui_cancel"):
		if not event.is_echo() and _atras.is_valid():
			_atras.call()
		return
	var arriba := event.is_action("ui_up") or fis == KEY_W
	var abajo := event.is_action("ui_down") or fis == KEY_S
	var izquierda := event.is_action("ui_left") or fis == KEY_A
	var derecha := event.is_action("ui_right") or fis == KEY_D
	if _horizontal:
		if izquierda:
			_mover(-1)
		elif derecha:
			_mover(1)
	elif arriba:
		_mover(-1)
	elif abajo:
		_mover(1)
	elif izquierda:
		_lado(-1)
	elif derecha:
		_lado(1)
	if not event.is_echo() and (event.is_action("ui_accept") or fis == KEY_E or fis == KEY_X):
		if _opciones.size() > 0:
			(_opciones[_sel]["elegir"] as Callable).call()


func _mover(d: int) -> void:
	if _opciones.size() < 2:
		return
	_sel = wrapi(_sel + d, 0, _opciones.size())
	_marcar(true)


func _lado(d: int) -> void:
	if _opciones.size() > 0 and _opciones[_sel].has("lado"):
		(_opciones[_sel]["lado"] as Callable).call(d)


# ---------------------------------------------------------------- dibujo

func _limpiar() -> void:
	for n in _contenido.get_children():
		n.queue_free()
	_opciones = []
	_etiquetas.clear()
	_horizontal = false
	for r in _llamas:
		r.visible = false
	_brillo.visible = false


## Una lista de opciones centrada en y_centro, con la sel elegida.
func _lista(ops: Array, y_centro: float, sel: int) -> void:
	_opciones = ops
	_sel = clampi(sel, 0, ops.size() - 1)
	var y0 := y_centro - (ops.size() - 1) * paso_opcion * 0.5
	for i in ops.size():
		var l := Label.new()
		l.label_settings = LabelSettings.new()
		l.label_settings.font = FUENTE
		l.label_settings.font_size = tam_opcion
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_contenido.add_child(l)
		_etiquetas.append(l)
		l.set_meta("y", y0 + i * paso_opcion)
		if ops[i].has("valor"):
			# angulo, valor, angulo: los angulos de Cinzel son de altura de
			# minuscula y en la misma linea casi no se veian; van aparte y mas
			# grandes.
			var partes := []
			for tam in [int(tam_opcion * 1.5), tam_opcion, int(tam_opcion * 1.5)]:
				var e := Label.new()
				e.label_settings = LabelSettings.new()
				e.label_settings.font = FUENTE
				e.label_settings.font_size = tam
				e.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_contenido.add_child(e)
				partes.append(e)
			partes[0].text = "‹"
			partes[2].text = "›"
			l.set_meta("valor", partes)
	_refrescar()


## Vuelve a escribir las opciones (las de valor cambian) y las centra.
func _refrescar() -> void:
	for i in _etiquetas.size():
		var t = _opciones[i]["texto"]
		var l := _etiquetas[i]
		l.text = (t.call() if t is Callable else tr(str(t))).to_upper()
		l.size = l.get_minimum_size()
		var y := float(l.get_meta("y"))
		if not l.has_meta("valor"):
			l.position = Vector2(centro_x - l.size.x * 0.5, y - l.size.y * 0.5)
			l.set_meta("rect", Rect2(l.position, l.size))
			continue
		# NOMBRE   ‹ VALOR ›, centrado todo junto.
		var partes: Array = l.get_meta("valor")
		var v: Array = (_opciones[i]["valor"] as Callable).call()
		partes[1].text = String(v[0]).to_upper()
		for e in partes:
			e.size = e.get_minimum_size()
		partes[0].modulate.a = 1.0 if v[1] else 0.0
		partes[2].modulate.a = 1.0 if v[2] else 0.0
		var hueco := tam_opcion * 0.9
		var junto := tam_opcion * 0.35
		var ancho: float = l.size.x + hueco + partes[0].size.x + junto + partes[1].size.x + junto + partes[2].size.x
		var x := centro_x - ancho * 0.5
		l.position = Vector2(x, y - l.size.y * 0.5)
		x += l.size.x + hueco
		for k in 3:
			var e: Label = partes[k]
			# los angulos, a la altura del centro de las mayusculas
			e.position = Vector2(x, y - e.size.y * 0.5 - (tam_opcion * 0.04 if k != 1 else 0.0))
			x += e.size.x + (junto if k < 2 else 0.0)
		l.set_meta("rect", Rect2(l.position, Vector2(x - l.position.x, l.size.y)))
	_marcar(false)


## Pinta la elegida (dorado vivo, entre las llamas) y las demas apagadas. Sin
## halo: la sombra de un Label es un contorno, no un difuminado, y en naranja
## quedaba como un trazo grueso.
func _marcar(prender: bool) -> void:
	for i in _etiquetas.size():
		var s := _etiquetas[i].label_settings
		s.font_color = ORO_VIVO if i == _sel else Color(ORO_APAGADO, 0.78)
		s.shadow_color = Color(0.0, 0.0, 0.0, 0.8 if i == _sel else 0.7)
		s.shadow_size = 8
		s.shadow_offset = Vector2(0.0, 3.0)
		if _etiquetas[i].has_meta("valor"):
			for e in _etiquetas[i].get_meta("valor"):
				e.label_settings.font_color = s.font_color
				e.label_settings.shadow_color = s.shadow_color
				e.label_settings.shadow_size = s.shadow_size
				e.label_settings.shadow_offset = s.shadow_offset
	if _etiquetas.is_empty():
		return
	var l := _etiquetas[_sel]
	_flanquear(l.get_meta("rect", Rect2(l.position, l.size)), prender)


## Pone las dos llamas a los lados de un rectangulo (la opcion elegida).
func _flanquear(r: Rect2, prender: bool) -> void:
	var y := r.position.y + r.size.y * 0.5 - _llamas[0].size.y * 0.62
	_llamas[0].position = Vector2(r.position.x - 44.0 - _llamas[0].size.x, y)
	_llamas[1].position = Vector2(r.end.x + 44.0, y)
	for ll in _llamas:
		ll.visible = true
		ll.modulate.a = 1.0
	# El resplandor, detras del texto y algo mas ancho; al cambiar de opcion se
	# desliza hasta la nueva.
	var tam := r.size + Vector2(320.0, 110.0)
	var donde := r.get_center() - tam * 0.5
	if _tw_brillo and _tw_brillo.is_valid():
		_tw_brillo.kill()
	if prender and _brillo.visible:
		_tw_brillo = create_tween().set_parallel()
		_tw_brillo.tween_property(_brillo, "position", donde, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tw_brillo.tween_property(_brillo, "size", tam, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_brillo.position = donde
		_brillo.size = tam
	_brillo.visible = true
	if _tw_llamas and _tw_llamas.is_valid():
		_tw_llamas.kill()
	if prender:
		# Al cambiar de opcion, las llamas prenden de nuevo, deprisa.
		_tw_llamas = create_tween().set_parallel()
		for m in _llamas_mat:
			_tw_llamas.tween_method(func(v: float) -> void: m.set_shader_parameter("vida", v), 0.35, 1.0, 0.3) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		for m in _llamas_mat:
			m.set_shader_parameter("vida", 1.0)


func _cabecera(texto: String, y: float) -> void:
	_texto_centrado(tr(texto).to_upper(), FUENTE, int(tam_opcion * 0.8), ORO_APAGADO, y)


func _texto_centrado(texto: String, fuente: Font, tam: int, color: Color, y: float, x := -1.0) -> Label:
	var l := Label.new()
	var s := LabelSettings.new()
	s.font = fuente
	s.font_size = tam
	s.font_color = color
	s.shadow_color = Color(0, 0, 0, 0.7)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	l.label_settings = s
	l.text = tr(texto)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contenido.add_child(l)
	l.size = l.get_minimum_size()
	l.position = Vector2((centro_x if x < 0.0 else x) - l.size.x * 0.5, y - l.size.y * 0.5)
	return l
