extends "res://scripts/ui/menu_base.gd"
## Menu de pausa (2026-10-17; el usuario: "necesitamos poder pausar el juego
## para ir a mear etc, y ahi tener un menu, para volver o salir, o incluso ver
## los controles que se permiten en ese momento").
##
## Lo abre GlobalExit (scripts/main.gd) con Esc, o solo si la ventana pierde el
## foco. Para el arbol entero: el juego se queda de fondo, quieto, oscurecido y
## con menos color. El viento sigue sonando, apagado como oido de lejos (el bus
## Master pasa por un paso bajo mientras dura); la musica y los sonidos del juego
## se paran con su escena y siguen donde estaban al volver, asi que nada se
## descuadra (el tema del titulo con sus luces, por ejemplo).
##
## Pantallas: el menu (Continuar, Controles, Opciones, Volver al titulo, Salir),
## los controles de ese momento (los da la escena, en una hoja o en varias que se
## pasan con izquierda y derecha, ver _controles), las opciones y la confirmacion de volver al titulo o salir, que
## dice desde donde se seguira (el punto guardado). La lista, las llamas, las
## opciones y la confirmacion son de menu_base.gd.

const KEY_PROMPT := preload("res://scenes/tutorial/key_prompt.tscn")
const TITULO := "res://scenes/intro/title_screen.tscn"
## La pantalla de titulo mira esto para abrirse en modo menu.
const META_TITULO_MENU := &"titulo_modo_menu"

@export var abrir: float = 0.25
@export var cerrar: float = 0.2
## Fundido a negro antes de cambiar de escena (volver al titulo).
@export var a_negro: float = 0.6
## El viento durante la pausa, oido de lejos.
@export var pausa_corte_hz: float = 900.0
@export var pausa_db: float = -5.0

const FONDO := "
shader_type canvas_item;
uniform sampler2D pantalla : hint_screen_texture, filter_linear;
uniform float fuerza = 0.0;
void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g) * vec3(1.0, 0.93, 0.82), 0.65 * fuerza);
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.35, 1.0);
	float vineta = 1.0 - smoothstep(0.2, 0.8, length(d)) * 0.65;
	c *= mix(1.0, 0.42 * vineta, fuerza);
	COLOR = vec4(c, 1.0);
}
"

var _fondo_mat: ShaderMaterial
var _negro: ColorRect
var _efectos: Array[AudioEffect] = []
var _hojas: Array = []                 # las de controles (ver _controles)
var _hoja := 0                         # la que se ve


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	# El viento (autoload) sigue sonando; lo demas se para con el arbol.
	WindAmbience.process_mode = Node.PROCESS_MODE_ALWAYS
	var paso_bajo := AudioEffectLowPassFilter.new()
	paso_bajo.cutoff_hz = pausa_corte_hz
	var bajar := AudioEffectAmplify.new()
	bajar.volume_db = pausa_db
	for e in [paso_bajo, bajar]:
		AudioServer.add_bus_effect(0, e)
		_efectos.append(e)

	var fondo := ColorRect.new()
	fondo.size = Vector2(ANCHO, ALTO)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = FONDO
	_fondo_mat = ShaderMaterial.new()
	_fondo_mat.shader = sh
	fondo.material = _fondo_mat
	add_child(fondo)

	_montar()

	_negro = ColorRect.new()
	_negro.size = Vector2(ANCHO, ALTO)
	_negro.color = Color(0, 0, 0, 0)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_negro)

	_poner_menu()
	_contenido.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_method(_poner_fuerza, 0.0, 1.0, abrir).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_contenido, "modulate:a", 1.0, abrir).set_trans(Tween.TRANS_SINE)


func _poner_fuerza(v: float) -> void:
	_fondo_mat.set_shader_parameter("fuerza", v)


# ---------------------------------------------------------------- pantallas

func _poner_menu(sel := 0) -> void:
	_limpiar()
	var ops := [
		{"texto": "menu.continuar", "elegir": _continuar},
		{"texto": "menu.controles", "elegir": _poner_controles},
		{"texto": "menu.opciones", "elegir": _poner_opciones},
	]
	# Volver al titulo solo si hay partida a la que volver: sin ella (en el ataud,
	# antes del primer guardado) el titulo no tendria nada que continuar.
	if Partida.hay_guardada():
		ops.append({"texto": "menu.volver_titulo", "elegir": _confirmar_titulo})
	ops.append({"texto": "menu.salir_juego", "elegir": _confirmar_salir})
	_lista(ops, ALTO * 0.5, sel)
	_atras = _continuar


func _poner_controles() -> void:
	_hojas = _controles()
	_hoja = 0
	for i in _hojas.size():
		if _hojas[i].get("ahora", false):
			_hoja = i
	_poner_hoja()


## La hoja de controles _hoja. Con varias (una por como lleve el baculo), su
## titulo entre angulos y el "Volver" las pasa con izquierda y derecha.
func _poner_hoja() -> void:
	_limpiar()
	_cabecera("menu.controles", 300.0)
	var hoja: Dictionary = _hojas[_hoja] if _hoja < _hojas.size() else {}
	var filas: Array = hoja.get("filas", [])
	var con_titulo := hoja.has("titulo")
	if con_titulo:
		_titulo_hoja(hoja, 425.0)
	if filas.is_empty():
		_texto_centrado("controles.ninguna", FUENTE_NOTA, 52, ORO_APAGADO, 760.0)
	else:
		var alto_fila := 160.0 if con_titulo else 176.0
		var y0 := ALTO * 0.5 - (filas.size() - 1) * alto_fila * 0.5 + 10.0
		if con_titulo:
			# todas las hojas desde la misma altura: al pasar de una a otra no salta nada
			y0 = 596.0
		for i in filas.size():
			_fila_control(filas[i], y0 + i * alto_fila)
		var y := y0 + filas.size() * alto_fila - 40.0
		if hoja.has("nota"):
			_texto_centrado(hoja["nota"], FUENTE_NOTA, 44, ORO, y)
			y += 66.0
		var otra := tr("controles.wasd" if Teclas.flechas else "controles.flechas")
		_texto_centrado(tr("controles.tambien") % otra, FUENTE_NOTA, 36, ORO_APAGADO, y)
	var volver := {"texto": "menu.volver", "elegir": _poner_menu.bind(1)}
	if _hojas.size() > 1:
		volver["lado"] = func(d: int) -> void:
			_hoja = wrapi(_hoja + d, 0, _hojas.size())
			_poner_hoja()
	_lista([volver], ALTO - 230.0, 0)
	_atras = _poner_menu.bind(1)


## El titulo de la hoja (‹ BACULO EN LA MANO ›, los angulos como en los valores
## de las opciones) y, si es como va ahora, una nota debajo.
func _titulo_hoja(hoja: Dictionary, y: float) -> void:
	var t := int(tam_opcion * 0.9)
	var nombre := _texto_centrado(tr(String(hoja["titulo"])).to_upper(), FUENTE, t, ORO, y)
	if _hojas.size() > 1:
		var hueco := t * 0.9
		var izq := _texto_centrado("‹", FUENTE, int(t * 1.5), ORO_APAGADO, y - t * 0.04)
		var der := _texto_centrado("›", FUENTE, int(t * 1.5), ORO_APAGADO, y - t * 0.04)
		izq.position.x = nombre.position.x - hueco - izq.size.x
		der.position.x = nombre.position.x + nombre.size.x + hueco
	if hoja.get("ahora", false):
		_texto_centrado("controles.ahora", FUENTE_NOTA, 38, ORO_APAGADO, y + t * 0.95)


func _poner_opciones() -> void:
	_pantalla_opciones(_poner_menu.bind(2), ALTO * 0.5)


func _confirmar_titulo() -> void:
	_pantalla_confirmar("confirmar.titulo", _desde_donde(), "confirmar.si_titulo", _volver_al_titulo,
		_poner_menu.bind(3), ALTO * 0.5, "confirmar.no_seguir")


func _confirmar_salir() -> void:
	_pantalla_confirmar("confirmar.salir", _desde_donde(), "confirmar.si_salir", _salir,
		_poner_menu.bind(4 if Partida.hay_guardada() else 3), ALTO * 0.5, "confirmar.no_seguir")


func _desde_donde() -> String:
	if Partida.se_puede_reanudar(get_tree()):
		return tr("pausa.aqui")
	var nombre := Partida.nombre_guardado()
	if nombre == "":
		return tr("pausa.sin_guardar")
	return tr("pausa.desde") % nombre


# ---------------------------------------------------------------- acciones

func _continuar() -> void:
	if _cerrando:
		return
	_cerrando = true
	var tw := create_tween().set_parallel()
	tw.tween_method(_poner_fuerza, 1.0, 0.0, cerrar).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_contenido, "modulate:a", 0.0, cerrar).set_trans(Tween.TRANS_SINE)
	for r in _llamas + [_brillo]:
		tw.tween_property(r, "modulate:a", 0.0, cerrar)
	tw.chain().tween_callback(_soltar)


func _volver_al_titulo() -> void:
	if _cerrando:
		return
	_cerrando = true
	Partida.guardar_reanudar(get_tree())
	# El viento se va con el negro; el titulo lo trae de nuevo desde el silencio.
	WindAmbience.fade_to(-40.0, a_negro)
	var tw := create_tween()
	tw.tween_property(_negro, "color:a", 1.0, a_negro).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		# Los sonidos de la escena, parados antes de quitar la pausa: si no,
		# siguen donde iban el fotograma que tarda el cambio de escena.
		GlobalExit._stop_audio_recursive(get_tree().current_scene)
		_soltar()
		get_tree().set_meta(META_TITULO_MENU, true)
		get_tree().change_scene_to_file(TITULO))


func _salir() -> void:
	_cerrando = true
	GlobalExit.salir()


## Quita la pausa y el menu.
func _soltar() -> void:
	for e in _efectos:
		for i in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
			if AudioServer.get_bus_effect(0, i) == e:
				AudioServer.remove_bus_effect(0, i)
	_efectos.clear()
	WindAmbience.process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().paused = false
	queue_free()


# ---------------------------------------------------------------- controles

## Una fila de los controles: las teclas a la izquierda del centro (las de esta
## postura, con la letra de su teclado: KeyPrompt) y lo que hacen a la derecha.
func _fila_control(fila: Dictionary, y: float) -> void:
	var acciones: Array = fila.get("acciones", [])
	var tam_tecla := 112.0
	var x := centro_x - 60.0
	for i in range(acciones.size() - 1, -1, -1):
		var kp: KeyPrompt = KEY_PROMPT.instantiate()
		kp.key_size_px = tam_tecla
		kp.base_tint = Color(0.62, 0.58, 0.53, 0.9)
		_contenido.add_child(kp)
		kp.setup(acciones[i])
		kp.fade = 1.0
		kp.position = Vector2(x - tam_tecla * 0.5, y + 52.0)
		x -= tam_tecla + 18.0
	var nota: String = fila.get("nota", "")
	var nombre := _texto_centrado(tr(String(fila.get("texto", ""))).to_upper(), FUENTE, 50, ORO, y)
	nombre.position = Vector2(centro_x + 10.0, y - nombre.size.y * (0.75 if nota != "" else 0.5))
	if nota != "":
		var n := _texto_centrado(nota, FUENTE_NOTA, 38, ORO_APAGADO, y)
		n.position = Vector2(centro_x + 12.0, y + 4.0)


## Las hojas de controles de ahora: [{filas, titulo, nota, ahora}]. Cada escena
## de juego dice los suyos, segun lo que el peregrino pueda hacer en ese momento,
## con controles_disponibles() -> [{acciones: [StringName], texto, nota
## (opcional)}] (una hoja) o con hojas_controles() -> [{filas: [...lo mismo],
## titulo, nota (lo que se puede y no), ahora (true en la de como va)}] (una por
## postura: la hojarasca, por como lleve el baculo). Texto, nota y titulo, claves
## de textos/interfaz.csv. El ataud no lleva script propio para esto: va aqui.
func _controles() -> Array:
	var escena := get_tree().current_scene
	if escena == null:
		return []
	# La escena, o la de juego que lleve dentro (las de pruebas de scenes/dev).
	for n in [escena] + escena.get_children():
		if n.has_method("hojas_controles"):
			return n.hojas_controles()
		if n.has_method("controles_disponibles"):
			return [{"filas": n.controles_disponibles()}]
	if escena.scene_file_path in ["res://main.tscn", Partida.PRINCIPIO]:
		return [{"filas": [{"acciones": [&"ui_up"], "texto": "controles.golpear"}]}]
	return []
