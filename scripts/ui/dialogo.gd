class_name Dialogo
extends CanvasLayer
## Los textos del juego: las leyendas del paseo por el bosque, la narracion y la
## primera conversacion con Dominus (lineas de cada uno y una eleccion).
##
## SIN CAJAS. Nada de paneles ni marcos: el texto flota sobre la escena, como en
## un libro ilustrado. Lo que lo hace legible encima de cualquier fondo -- el
## horizonte palido del atardecer, el negro del suelo, la sala ambar -- es un
## halo oscuro y difuso que sale de las PROPIAS letras: todo el texto se pinta
## dentro de un CanvasGroup, y el shader del grupo desenfoca su alfa y lo pone
## debajo en marron casi negro. El halo tiene la forma de lo escrito, crece con
## la maquina de escribir y se funde con el texto, cosa que no da ni un
## rectangulo translucido (se ve la caja) ni el outline de la fuente (con alfa,
## los contornos de letras vecinas se pisan y dejan manchas mas oscuras entre
## ellas).
##
## Uso (todo son corrutinas salvo leyenda):
##   await dialogo.narrar("La puerta estaba entornada.")
##   await dialogo.decir(dominus, "—Sé bienvenido, peregrino.", "dominus")
##   var i := await dialogo.elegir(["Sentarse", "Preguntar", "Callar"])
##   await dialogo.cerrar()
##   dialogo.leyenda("Caminó un día y una noche.")   # no bloquea ni coge teclas
##
## La raya de dialogo del relato ("—Sé bienvenido") se quita al mostrarla: quien
## habla ya se sabe por donde sale el texto y por su color.
##
## Mientras hay conversacion abierta (activo == true, de la primera linea hasta
## que acaba cerrar()) este nodo se come las pulsaciones de aceptar y de mover a
## los lados, para que Magnus no salte debajo. Lo que NO puede impedir es que
## Magnus lea Input.is_action_pressed en su _physics_process: eso lo bloquea el
## nivel mirando activo.

## Se emite al pasar de una linea (decir o narrar), justo antes de que la
## corrutina devuelva el control.
signal linea_terminada
## Se emite cuando la maquina de escribir acaba la linea en curso (sola o porque
## se ha pulsado para completarla). Para quien quiera sincronizar algo con el
## final del texto: un gesto de Dominus, un sonido.
signal texto_completo

## Senales internas: la de avanzar a la siguiente linea y la de elegir opcion.
signal _avance
signal _elegido(indice: int)

const FUENTE_REDONDA := preload("res://assets/fonts/IMFellEnglish-Regular.ttf")
const FUENTE_CURSIVA := preload("res://assets/fonts/IMFellEnglish-Italic.ttf")

## Holgura que se suma al ancho medido antes de darselo al RichTextLabel: su
## propio calculo redondea distinto que TextParagraph y, sin esto, a veces
## partia la linea una palabra antes que la medida.
const HOLGURA := 6.0
## Signos tras los que se para la maquina de escribir. Los cierres (comillas,
## parentesis) no cuentan por si mismos: manda lo que haya justo antes, asi que
## «...hola.» para lo que para el punto.
const PUNTOS := ".?!…"
const COMAS := ",;:—"
const CIERRES := "»”’)\"'"

@export_group("Maquina de escribir")
## Letras por segundo.
@export var velocidad: float = 38.0
## Pausa extra tras , ; : y el inciso con raya.
@export var pausa_coma: float = 0.14
## Pausa extra tras . ? ! y los puntos suspensivos.
@export var pausa_punto: float = 0.40
## Lo que tarda cada letra en aparecer. Con 0 aparecen de golpe, como una
## maquina de escribir de verdad; con una decima se ve la tinta llegar y a 38
## letras por segundo hay tres o cuatro a medio hacer, que es lo que la quita de
## mecanica sin que se note que es un efecto.
@export var fundido_letra: float = 0.11
## Cuanto se asienta cada letra mientras aparece (px, bajando). Muy poco: es un
## acompanamiento del fundido, no un salto.
@export var asiento_letra: float = 3.0
## Tras cada cambio (linea nueva, texto completado) se ignora aceptar este rato,
## para que un rebote de la tecla o una pulsacion doble no se salte una linea
## entera sin leerla.
@export var bloqueo_pulsacion: float = 0.14

@export_group("Aspecto")
## Tamanos pensados para 2912x1632 visto a ~0,53 (pantallas de 1536x864): 58 px
## se leen a unos 31 px reales, la narracion a unos 27. La cursiva de IM Fell es
## fina: por debajo de 50 se pierde encima de las ramas.
@export var tam_linea: int = 58
@export var tam_narracion: int = 52
@export var tam_leyenda: int = 50
@export var tam_opcion: int = 52
## Espacio extra entre lineas (px). IM Fell trae una interlinea generosa (1,27
## em); un pelo menos y las dos lineas se leen como una frase, no como dos.
@export var interlinea: int = -6
## Ancho maximo de las lineas de dialogo y de la narracion. El ancho real se
## equilibra: se busca el mas estrecho que no anada lineas, para que un texto de
## dos lineas no quede con una larga y una colgando de dos palabras.
@export var ancho_linea: float = 1000.0
@export var ancho_narracion: float = 1500.0
## Nada se acerca al borde de la pantalla mas que esto.
@export var margen: float = 80.0
## Hueco entre el punto de la cabeza y la base del texto.
@export var separacion_cabeza: float = 12.0
## Altura del centro de la narracion y las leyendas: el tercio de arriba.
@export var altura_narracion: float = 360.0
## Altura del centro de la fila de opciones: sobre el suelo, por debajo de los
## pies (y = 1200 en las escenas de juego).
@export var altura_opciones: float = 1420.0
## Hueco entre dos opciones.
@export var hueco_opciones: float = 150.0

@export_group("Colores")
## Dominus: ambar palido y calido, de vela.
@export var color_dominus := Color("f3dcb0")
## Magnus: pergamino grisaceo, mas frio y apagado que el del anfitrion.
@export var color_magnus := Color("d9d4c8")
## La voz del relato: gris pergamino, un punto por debajo de Magnus.
@export var color_narracion := Color("c9c2b3")
## Opcion elegible sin seleccionar: el color de Magnus a media luz.
@export var color_opcion := Color(0.851, 0.831, 0.784, 0.5)
## Opcion seleccionada: casi blanca de pergamino.
@export var color_opcion_viva := Color("f2eadb")

@export_group("Halo")
## Color del halo: marron casi negro. Negro puro se ve sucio encima del ambar
## de la sala; con un pelo de calor desaparece como sombra.
@export var halo_color := Color(0.035, 0.027, 0.02):
	set(v):
		halo_color = v
		_refrescar_halo()
## Opacidad maxima del halo. Por encima de 0,7 se empieza a leer como mancha;
## por debajo de 0,5 la cursiva no se sostiene encima de las ramas palidas.
@export_range(0.0, 1.0) var halo_fuerza: float = 0.6:
	set(v):
		halo_fuerza = v
		_refrescar_halo()
## Radio del desenfoque en px de la vista (2912 de ancho). Se convierte a px
## reales de pantalla cada vez que cambia la escala, para que el halo mida lo
## mismo en una pantalla de 1536 que en una de 2912. Con 30 quedaba pegado a
## las letras, como un contorno sucio; con 56 es humo.
@export var halo_radio: float = 56.0:
	set(v):
		halo_radio = v
		_refrescar_halo()
## Escala de la curva del halo (1 - e^-alfa/umbral), en alfa desenfocado. Una
## linea de texto desenfocada da un alfa de 0,1-0,2: con 0,09 el nucleo detras de
## las palabras llega a ~80 % de halo_fuerza y los bordes caen solos. Mas bajo =
## mas compacto y parejo; mas alto = mas transparente entre palabras.
@export var halo_umbral: float = 0.09:
	set(v):
		halo_umbral = v
		_refrescar_halo()

## El halo. Lee lo que han pintado los hijos del CanvasGroup (el texto, sobre
## transparente, premultiplicado), desenfoca su alfa y compone: texto encima,
## halo debajo.
##
## El desenfoque son tres anillos de ocho muestras sobre los mipmaps del
## backbuffer (que Godot ya genera con un desenfoque gaussiano), cada anillo
## girado respecto al anterior para que no se dibuje una estrella alrededor de
## los signos sueltos. El alfa medio de una linea de texto es bajo -- las letras
## tapan un 15-20 % de su caja --, asi que no se usa tal cual: pasa por una
## curva que satura (1 - e^-kx), que da un nucleo parejo detras de las palabras
## y una caida larga y suave hacia fuera, como humo, sin borde.
const SHADER_HALO := """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec3 color_halo : source_color = vec3(0.035, 0.027, 0.02);
uniform float fuerza = 0.6;
uniform float radio = 30.0;
uniform float umbral = 0.09;

const vec2 ANILLO[8] = vec2[8](
	vec2(1.0, 0.0), vec2(0.7071, 0.7071), vec2(0.0, 1.0), vec2(-0.7071, 0.7071),
	vec2(-1.0, 0.0), vec2(-0.7071, -0.7071), vec2(0.0, -1.0), vec2(0.7071, -0.7071));

vec2 girar(vec2 v, float c, float s) {
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

void fragment() {
	vec4 texto = textureLod(pantalla, SCREEN_UV, 0.0);
	float lod = max(log2(radio / 5.0), 0.0);
	vec2 paso = SCREEN_PIXEL_SIZE * radio;
	float a = textureLod(pantalla, SCREEN_UV, lod).a * 0.12;
	for (int i = 0; i < 8; i++) {
		vec2 d = ANILLO[i];
		a += textureLod(pantalla, SCREEN_UV + d * paso * 0.35, lod).a * 0.05;
		a += textureLod(pantalla, SCREEN_UV + girar(d, 0.9239, 0.3827) * paso * 0.7, lod).a * 0.035;
		a += textureLod(pantalla, SCREEN_UV + girar(d, 0.9808, 0.1951) * paso * 1.1, lod).a * 0.025;
	}
	// 1 - e^(-x/umbral): con x = umbral ya va por el 63 %, y nunca corta en seco.
	float halo = (1.0 - exp(-a / max(umbral, 0.001))) * fuerza;
	float alfa = texto.a + halo * (1.0 - texto.a);
	vec3 rgb = texto.rgb + color_halo * halo * (1.0 - texto.a);
	COLOR = vec4(rgb / max(alfa, 0.0001), alfa) * COLOR;
}
"""

enum Fase { NADA, ESCRIBIENDO, ESPERANDO, ELIGIENDO }

## Hay conversacion abierta: desde la primera linea (decir, narrar o elegir)
## hasta que termina cerrar(). Solo lectura: la escribe este nodo.
var activo: bool:
	get:
		return _activo

var _activo := false
var _fase := Fase.NADA
var _halo: CanvasGroup
var _material: ShaderMaterial
var _escala := -1.0
var _actual: Pieza          # la linea de decir/narrar que recibe las teclas
var _leyendas: Array[Pieza] = []
var _indicador: Rombo
var _indicador_reloj := 0.0
var _indicador_tween: Tween
var _fila: Node2D           # opciones de elegir()
var _opciones: Array[Label] = []
var _marca: Rombo
var _marca_tween: Tween
var _seleccion := 0
var _bloqueo := 0.0
var _re_una_letra: RegEx


## Un trozo de texto en pantalla: una linea, una narracion o una leyenda.
class Pieza extends RefCounted:
	var rtl: RichTextLabel
	var fx: Revelar             # null si no se escribe letra a letra (leyendas)
	var estilo := ""
	var ancla: Node2D
	var cabeza := Vector2.ZERO  # ultimo punto de la cabeza visto, en px de la vista
	var ancho := 0.0
	var alto := 0.0
	var fin := Vector2.ZERO     # final de la ultima linea, relativo al rtl (indicador)
	var t := 0.0
	var duracion := 0.0         # cuando termina de aparecer la ultima letra
	var escapado := ""          # el texto ya escapado para bbcode, sin el efecto
	var deriva := 0.0           # desplazamiento vertical animado (leyendas)
	var tween: Tween            # la vida de una leyenda, para cortarla si llega otra


## Efecto de RichTextLabel que hace la maquina de escribir. Cada letra tiene su
## instante (tiempos, con las pausas de puntuacion ya sumadas) y aparece en
## fundido_letra segundos a partir de ahi. Se hace asi y no con
## visible_characters porque este deja el texto maquetado entero desde el
## principio: las palabras no saltan de una linea a otra mientras se escriben, y
## cada letra puede fundirse en vez de aparecer de golpe.
class Revelar extends RichTextEffect:
	var bbcode := "revelar"
	var tiempos := PackedFloat32Array()
	var t := 0.0
	var fundido := 0.1
	var asiento := 3.0

	func _process_custom_fx(fx: CharFXTransform) -> bool:
		var i := fx.relative_index
		var t0 := tiempos[i] if i < tiempos.size() else 0.0
		var a := clampf((t - t0) / maxf(fundido, 0.001), 0.0, 1.0)
		a = a * a * (3.0 - 2.0 * a)
		fx.color.a *= a
		fx.offset.y += (1.0 - a) * asiento
		return true


## Rombo pequeno: el indicador de "pulsa para seguir" y la marca de la opcion
## elegida. La fuente no trae florones (ni ❧ ni ◆), asi que se dibuja. El borde
## lleva una polilinea con antialias para que a 0,53 no se vea dentado.
class Rombo extends Node2D:
	var ancho := 13.0
	var alto := 20.0
	var color := Color.WHITE:
		set(v):
			color = v
			queue_redraw()

	func _draw() -> void:
		var pts := PackedVector2Array([
			Vector2(0, -alto * 0.5), Vector2(ancho * 0.5, 0),
			Vector2(0, alto * 0.5), Vector2(-ancho * 0.5, 0)])
		draw_colored_polygon(pts, color)
		pts.append(pts[0])
		draw_polyline(pts, color, 1.5, true)


func _init() -> void:
	layer = 20


func _ready() -> void:
	# Que siga funcionando si el nivel pausa el arbol durante una conversacion.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shader := Shader.new()
	shader.code = SHADER_HALO
	_material = ShaderMaterial.new()
	_material.shader = shader
	_halo = CanvasGroup.new()
	_halo.name = "Halo"
	_halo.material = _material
	_halo.use_mipmaps = true
	_halo.visible = false
	add_child(_halo)
	_refrescar_halo()
	_indicador = Rombo.new()
	_indicador.name = "Indicador"
	_indicador.visible = false
	_halo.add_child(_indicador)


# --- API ---------------------------------------------------------------------

## Linea de un personaje, encima de su cabeza. Espera a que el jugador la pase.
## ancla: el personaje. Si tiene punto_cabeza() se usa (punto en coordenadas
## globales de su canvas); si no, 380 px por encima de su origen, que en Magnus
## (330 px de alto, origen en los pies) deja 50 px de aire sobre la capucha. El
## texto sigue al ancla mientras esta en pantalla.
## estilo: "dominus" o "magnus" (el color).
func decir(ancla: Node2D, texto: String, estilo: String = "dominus") -> void:
	await _linea(texto, estilo, ancla)


## Linea del narrador, centrada en el tercio de arriba, en cursiva. Espera a que
## el jugador la pase.
func narrar(texto: String) -> void:
	await _linea(texto, "narracion", null)


## Leyenda del paseo por el bosque. NO bloquea ni coge teclas: el jugador sigue
## andando. Aparece en 1,2 s, se queda `duracion` segundos entera y se va en
## 1,5 s (en total, duracion + 2,7). Si ya habia una, la vieja se va antes y la
## nueva entra un poco despues, para que no se lean las dos a la vez encima.
func leyenda(texto: String, duracion: float = 4.5) -> void:
	var retraso := 0.0
	for vieja in _leyendas.duplicate():
		_retirar_leyenda(vieja, 0.7)
		retraso = 0.35
	var p := _crear_pieza(texto, "leyenda", null, false)
	p.rtl.modulate.a = 0.0
	_leyendas.append(p)
	_colocar(p)
	var tw := p.rtl.create_tween()
	tw.tween_interval(retraso)
	tw.tween_property(p.rtl, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(duracion, 0.0))
	tw.tween_property(p.rtl, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(_quitar_leyenda.bind(p))
	p.tween = tw
	# Deriva hacia arriba durante toda su vida: 8 px, casi no se ve, pero hace
	# que el texto respire en vez de estar clavado encima del bosque.
	var dw := p.rtl.create_tween()
	dw.tween_property(p, "deriva", -8.0, retraso + 2.7 + duracion)


## Eleccion: dos o tres opciones en fila, abajo en el centro. Izquierda/derecha
## para cambiar, aceptar para confirmar. Devuelve el indice elegido (-1 si se
## corta con cerrar()). La ultima linea dicha se queda en pantalla mientras
## tanto (suele ser la pregunta). Las opciones son cortas: no se parten en
## lineas. Ojo: el Array tiene que ser Array[String]; un literal ["a", "b"]
## pasado directamente ya lo es.
func elegir(opciones: Array[String]) -> int:
	if opciones.is_empty():
		return -1
	_activo = true
	_ocultar_indicador()
	_quitar_fila(0.0)
	_construir_fila(opciones)
	_fase = Fase.ELIGIENDO
	_bloqueo = bloqueo_pulsacion + 0.1
	var indice: int = await _elegido
	_fase = Fase.NADA
	_quitar_fila(0.35)
	return indice


## Funde todo y cierra la conversacion. activo pasa a false al terminar.
## Sirve tambien para cortar una conversacion a medias (una cinematica, un
## susto): si habia una linea o una eleccion esperando, la suelta -- decir y
## narrar vuelven, elegir devuelve -1 -- en vez de dejar esa corrutina colgada
## para siempre. Las leyendas no se tocan.
func cerrar() -> void:
	var fase_previa := _fase
	_fase = Fase.NADA
	_ocultar_indicador()
	_quitar_fila(0.35)
	if _actual:
		_retirar(_actual, 0.35)
		_actual = null
	# Se suelta al final, con todo ya retirado: la corrutina que esperaba sigue
	# en el acto y, si lanza otra linea, que la encuentre limpia.
	if fase_previa == Fase.ESCRIBIENDO or fase_previa == Fase.ESPERANDO:
		_avance.emit()
	elif fase_previa == Fase.ELIGIENDO:
		_elegido.emit(-1)
	await get_tree().create_timer(0.36, true, false, true).timeout
	# Si mientras se fundia ha empezado otra conversacion, esa manda.
	if _actual == null and _fila == null:
		_activo = false


# --- Lineas --------------------------------------------------------------------

func _linea(texto: String, estilo: String, ancla: Node2D) -> void:
	if _fase == Fase.ESCRIBIENDO or _fase == Fase.ESPERANDO:
		push_warning("Dialogo: linea nueva sin esperar a la anterior; hay que usar await.")
	_activo = true
	_fase = Fase.NADA
	for l in _leyendas.duplicate():
		_retirar_leyenda(l, 0.5)
	_ocultar_indicador()
	if _actual:
		# La anterior se va antes de que empiece esta: un respiro entre frases, y
		# asi dos lineas del mismo personaje no se escriben una encima de otra.
		_retirar(_actual, 0.18)
		_actual = null
		await get_tree().create_timer(0.2, true, false, true).timeout
	var p := _crear_pieza(texto, estilo, ancla, true)
	_actual = p
	_colocar(p)
	_fase = Fase.ESCRIBIENDO if p.duracion > 0.0 else Fase.ESPERANDO
	_bloqueo = bloqueo_pulsacion
	if _fase == Fase.ESPERANDO:
		_mostrar_indicador()
	await _avance
	linea_terminada.emit()


func _crear_pieza(texto: String, estilo: String, ancla: Node2D, escribir: bool) -> Pieza:
	var p := Pieza.new()
	p.estilo = estilo
	p.ancla = ancla
	var vista := _tam_vista()
	p.cabeza = Vector2(vista.x * 0.5, vista.y * 0.7)
	var limpio := _componer(texto)
	var fuente: Font = FUENTE_REDONDA
	var tam := tam_linea
	var color := color_dominus
	var maximo := ancho_linea
	match estilo:
		"magnus":
			color = color_magnus
		"narracion":
			fuente = FUENTE_CURSIVA
			tam = tam_narracion
			color = color_narracion
			maximo = ancho_narracion
		"leyenda":
			fuente = FUENTE_CURSIVA
			tam = tam_leyenda
			color = color_narracion
			maximo = ancho_narracion
	maximo = minf(maximo, vista.x - margen * 2.0)
	p.ancho = _ancho_equilibrado(limpio, fuente, tam, maximo)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.clip_contents = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.focus_mode = Control.FOCUS_NONE
	rtl.add_theme_font_override("normal_font", fuente)
	rtl.add_theme_font_size_override("normal_font_size", tam)
	rtl.add_theme_color_override("default_color", color)
	rtl.add_theme_constant_override("line_separation", interlinea)
	rtl.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	rtl.size = Vector2(p.ancho, 0.0)
	var escapado := limpio.replace("[", "[lb]")
	p.escapado = escapado
	if escribir:
		p.fx = Revelar.new()
		p.fx.tiempos = _tiempos(limpio)
		p.fx.fundido = fundido_letra
		p.fx.asiento = asiento_letra
		rtl.install_effect(p.fx)
		rtl.text = "[center][revelar]%s[/revelar][/center]" % escapado
		if not p.fx.tiempos.is_empty():
			p.duracion = p.fx.tiempos[p.fx.tiempos.size() - 1] + fundido_letra
	else:
		rtl.text = "[center]%s[/center]" % escapado
	_halo.add_child(rtl)
	_halo.visible = true
	p.alto = rtl.get_content_height()
	rtl.size = Vector2(p.ancho, p.alto)
	p.rtl = rtl
	p.fin = _fin_ultima_linea(limpio, fuente, tam, p.ancho, p.alto)
	return p


## Quita la raya de dialogo del principio ("—Sé bienvenido" -> "Sé bienvenido").
## Solo la del principio: los incisos (—dijo—) se quedan.
func _limpiar(texto: String) -> String:
	var s := texto.strip_edges()
	while s.begins_with("—") or s.begins_with("–"):
		s = s.substr(1).strip_edges(true, false)
	return s


## Texto listo para maquetar: sin la raya y con las palabras de una letra (y, a,
## o, e, u) pegadas a la siguiente con un espacio duro, como se hace al componer
## en castellano, para que ninguna linea acabe en "y" colgando.
func _componer(texto: String) -> String:
	var s := _limpiar(texto)
	if _re_una_letra == null:
		_re_una_letra = RegEx.create_from_string("(^|\\s)([yaoeuYAOEU]) ")
	# Dos pasadas: en "y a casa" la segunda coincidencia empieza en el espacio
	# que la primera ya ha consumido.
	var duro := String.chr(0xA0)
	for k in 2:
		s = _re_una_letra.sub(s, "$1$2" + duro, true)
	return s


## Instante en que empieza a aparecer cada letra, con las pausas sumadas. La
## pausa va DESPUES del signo y solo si acaba palabra: "3,5" o los dos primeros
## puntos de "..." no paran.
func _tiempos(s: String) -> PackedFloat32Array:
	var t := PackedFloat32Array()
	t.resize(s.length())
	var acumulado := 0.0
	var paso := 1.0 / maxf(velocidad, 1.0)
	for i in s.length():
		t[i] = acumulado
		acumulado += paso + _pausa_tras(s, i)
	return t


func _pausa_tras(s: String, i: int) -> float:
	if i + 1 >= s.length():
		return 0.0
	var siguiente := s[i + 1]
	if siguiente != " " and siguiente != "\n":
		return 0.0
	var j := i
	while j > 0 and CIERRES.contains(s[j]):
		j -= 1
	var c := s[j]
	if PUNTOS.contains(c):
		return pausa_punto
	if COMAS.contains(c):
		return pausa_coma
	return 0.0


func _parrafo(s: String, fuente: Font, tam: int, ancho: float) -> TextParagraph:
	var para := TextParagraph.new()
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	para.add_string(s, fuente, tam)
	para.width = ancho
	return para


## El ancho mas estrecho que no anade lineas. Asi un texto de dos lineas sale
## con dos lineas parecidas, centradas, en vez de una llena y otra con dos
## palabras sueltas. Busqueda binaria: doce pasos sobran para acertar al pixel.
func _ancho_equilibrado(s: String, fuente: Font, tam: int, maximo: float) -> float:
	var natural := fuente.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	if natural <= maximo and not s.contains("\n"):
		return ceilf(natural) + HOLGURA
	var lineas := _parrafo(s, fuente, tam, maximo).get_line_count()
	var bajo := maximo * 0.3
	var alto := maximo
	for k in 12:
		var medio := (bajo + alto) * 0.5
		if _parrafo(s, fuente, tam, medio).get_line_count() > lineas:
			bajo = medio
		else:
			alto = medio
	return ceilf(alto) + HOLGURA


## Donde acaba la ultima linea, relativo a la esquina del texto: ahi va el
## indicador. A media altura de las minusculas, no de la caja de la linea.
func _fin_ultima_linea(s: String, fuente: Font, tam: int, ancho: float, alto: float) -> Vector2:
	var para := _parrafo(s, fuente, tam, ancho)
	var n := para.get_line_count()
	var ancho_ultima := para.get_line_width(n - 1) if n > 0 else 0.0
	var base := alto - fuente.get_height(tam) + fuente.get_ascent(tam)
	return Vector2((ancho + ancho_ultima) * 0.5, base - tam * 0.2)


## Pone la pieza en su sitio. Las lineas de personaje siguen al ancla cada
## fotograma: si la camara o el personaje se mueven, el texto va con el.
func _colocar(p: Pieza) -> void:
	var vista := _tam_vista()
	var pos: Vector2
	if p.estilo == "narracion" or p.estilo == "leyenda":
		pos = Vector2(vista.x * 0.5 - p.ancho * 0.5, altura_narracion - p.alto * 0.5)
	else:
		if p.ancla != null and is_instance_valid(p.ancla) and p.ancla.is_inside_tree():
			p.cabeza = _punto_cabeza(p.ancla)
		pos = p.cabeza + Vector2(-p.ancho * 0.5, -p.alto - separacion_cabeza)
	pos.x = clampf(pos.x, margen, maxf(margen, vista.x - margen - p.ancho))
	pos.y = clampf(pos.y, margen, maxf(margen, vista.y - margen - p.alto))
	p.rtl.position = pos + Vector2(0.0, p.deriva)


## Punto de la cabeza del ancla en px de la vista (los de esta capa). Del
## mundo a la vista con la transformacion del canvas del ancla, que incluye la
## camara.
func _punto_cabeza(ancla: Node2D) -> Vector2:
	var punto: Vector2
	if ancla.has_method("punto_cabeza"):
		punto = ancla.call("punto_cabeza")
	else:
		punto = ancla.global_position + Vector2(0.0, -380.0)
	return ancla.get_canvas_transform() * punto


func _tam_vista() -> Vector2:
	return get_viewport().get_visible_rect().size


## Con todas las letras ya enteras, el texto pasa a ser uno normal sin el
## efecto: un RichTextLabel con un RichTextEffect llama al script por cada letra
## en cada fotograma, y mientras se espera a que el jugador lea no hace falta.
## Las letras quedan exactamente donde estaban (el efecto ya no las movia).
func _fijar(p: Pieza) -> void:
	if p.fx == null or not is_instance_valid(p.rtl):
		return
	p.rtl.text = "[center]%s[/center]" % p.escapado
	p.fx = null


func _retirar(p: Pieza, tiempo: float) -> void:
	var tw := p.rtl.create_tween()
	tw.tween_property(p.rtl, "modulate:a", 0.0, tiempo).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(p.rtl.queue_free)


func _retirar_leyenda(p: Pieza, tiempo: float) -> void:
	_leyendas.erase(p)
	if not is_instance_valid(p.rtl):
		return
	# Se corta su vida normal (aparecer, quedarse, irse) y se funde desde donde
	# este: si aun iba por la mitad del fundido de entrada, tarda menos en irse.
	if p.tween:
		p.tween.kill()
	var desde := p.rtl.modulate.a
	var tw := p.rtl.create_tween()
	tw.tween_property(p.rtl, "modulate:a", 0.0, maxf(tiempo * desde, 0.01))
	tw.tween_callback(p.rtl.queue_free)


func _quitar_leyenda(p: Pieza) -> void:
	_leyendas.erase(p)
	if is_instance_valid(p.rtl):
		p.rtl.queue_free()


# --- Indicador -----------------------------------------------------------------

func _mostrar_indicador() -> void:
	if _actual == null:
		return
	_indicador.color = _actual.rtl.get_theme_color("default_color")
	_indicador.visible = true
	_indicador.modulate.a = 0.0
	_indicador_reloj = 0.0
	if _indicador_tween:
		_indicador_tween.kill()
	_indicador_tween = create_tween()
	_indicador_tween.tween_property(_indicador, "modulate:a", 1.0, 0.3)


func _ocultar_indicador() -> void:
	if _indicador_tween:
		_indicador_tween.kill()
		_indicador_tween = null
	_indicador.visible = false


# --- Opciones ------------------------------------------------------------------

func _construir_fila(opciones: Array[String]) -> void:
	_fila = Node2D.new()
	_fila.name = "Opciones"
	_fila.modulate.a = 0.0
	_halo.add_child(_fila)
	_halo.visible = true
	_opciones.clear()
	var fuente: Font = FUENTE_REDONDA
	var anchos: Array[float] = []
	var total := 0.0
	for texto in opciones:
		var w := fuente.get_string_size(_limpiar(texto), HORIZONTAL_ALIGNMENT_LEFT, -1, tam_opcion).x
		anchos.append(w)
		total += w
	total += hueco_opciones * (opciones.size() - 1)
	var vista := _tam_vista()
	var x := clampf(vista.x * 0.5 - total * 0.5, margen, maxf(margen, vista.x - margen - total))
	var alto_linea := fuente.get_height(tam_opcion)
	for i in opciones.size():
		var l := Label.new()
		l.text = _limpiar(opciones[i])
		l.add_theme_font_override("font", fuente)
		l.add_theme_font_size_override("font_size", tam_opcion)
		l.add_theme_color_override("font_color", color_opcion)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.position = Vector2(x, altura_opciones - alto_linea * 0.5)
		l.size = Vector2(anchos[i] + HOLGURA, alto_linea)
		_fila.add_child(l)
		_opciones.append(l)
		x += anchos[i] + hueco_opciones
	_marca = Rombo.new()
	_marca.ancho = 11.0
	_marca.alto = 16.0
	_marca.color = color_opcion_viva
	_fila.add_child(_marca)
	_seleccion = 0
	_seleccionar(0, true)
	var tw := _fila.create_tween()
	tw.tween_property(_fila, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## La marca va a la izquierda de la opcion, a media altura de las minusculas.
func _pos_marca(i: int) -> Vector2:
	var l := _opciones[i]
	var fuente: Font = FUENTE_REDONDA
	var base := fuente.get_ascent(tam_opcion)
	return l.position + Vector2(-30.0, base - tam_opcion * 0.2)


func _seleccionar(i: int, instantaneo: bool = false) -> void:
	_seleccion = i
	for k in _opciones.size():
		var l := _opciones[k]
		var destino := color_opcion_viva if k == i else color_opcion
		if instantaneo:
			l.add_theme_color_override("font_color", destino)
		else:
			var desde := l.get_theme_color("font_color")
			var tw := l.create_tween()
			tw.tween_method(func(c: Color) -> void: l.add_theme_color_override("font_color", c),
					desde, destino, 0.18)
	if _marca_tween:
		_marca_tween.kill()
	if instantaneo:
		_marca.position = _pos_marca(i)
	else:
		_marca_tween = _marca.create_tween()
		_marca_tween.tween_property(_marca, "position", _pos_marca(i), 0.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _quitar_fila(tiempo: float) -> void:
	if _fila == null:
		return
	var fila := _fila
	_fila = null
	_opciones.clear()
	_marca = null
	_marca_tween = null
	if tiempo <= 0.0:
		fila.queue_free()
		return
	var tw := fila.create_tween()
	tw.tween_property(fila, "modulate:a", 0.0, tiempo).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(fila.queue_free)


# --- Entrada y reloj -------------------------------------------------------------

func _input(evento: InputEvent) -> void:
	if not _activo:
		return
	var aceptar := evento.is_action_pressed("saltar") or evento.is_action_pressed("ui_accept")
	var izquierda := evento.is_action_pressed("mover_izquierda")
	var derecha := evento.is_action_pressed("mover_derecha")
	if not (aceptar or izquierda or derecha):
		return
	# Se consume ANTES de actuar: al avanzar, la corrutina que esperaba sigue en
	# el acto (y puede lanzar la linea siguiente), y la tecla no debe llegar a
	# nadie mas.
	get_viewport().set_input_as_handled()
	if _bloqueo > 0.0:
		return
	match _fase:
		Fase.ESCRIBIENDO:
			if aceptar:
				_completar()
		Fase.ESPERANDO:
			if aceptar:
				_fase = Fase.NADA
				_ocultar_indicador()
				_avance.emit()
		Fase.ELIGIENDO:
			if izquierda and _seleccion > 0:
				_seleccionar(_seleccion - 1)
			elif derecha and _seleccion < _opciones.size() - 1:
				_seleccionar(_seleccion + 1)
			elif aceptar:
				_fase = Fase.NADA
				_confirmar()


## Completa la linea: lo que faltaba aparece a la vez, con el mismo fundido
## corto de cada letra (sin que el texto salte de golpe).
func _completar() -> void:
	if _actual == null or _actual.fx == null:
		return
	var tiempos := _actual.fx.tiempos
	if not tiempos.is_empty():
		_actual.t = maxf(_actual.t, tiempos[tiempos.size() - 1])
	_bloqueo = bloqueo_pulsacion


func _confirmar() -> void:
	# Un destello minimo de la elegida antes de que se funda la fila.
	if _seleccion < _opciones.size():
		var l := _opciones[_seleccion]
		var tw := l.create_tween()
		tw.tween_property(l, "modulate", Color(1.15, 1.12, 1.05), 0.08)
		tw.tween_property(l, "modulate", Color.WHITE, 0.2)
	_elegido.emit(_seleccion)


func _process(delta: float) -> void:
	_actualizar_escala()
	_bloqueo = maxf(_bloqueo - delta, 0.0)
	if _actual:
		if not is_instance_valid(_actual.rtl):
			_actual = null
		else:
			_actual.t += delta
			if _actual.fx:
				_actual.fx.t = _actual.t
			_colocar(_actual)
			if _fase == Fase.ESCRIBIENDO and _actual.t >= _actual.duracion:
				_fase = Fase.ESPERANDO
				_bloqueo = maxf(_bloqueo, bloqueo_pulsacion * 0.5)
				_fijar(_actual)
				_mostrar_indicador()
				texto_completo.emit()
	for p in _leyendas:
		if is_instance_valid(p.rtl):
			_colocar(p)
	if _indicador.visible and _actual:
		# Late despacio (1,3 s) y baja un pelo al latir: se ve que espera, pero
		# no parpadea como un cursor.
		_indicador_reloj += delta
		var fase := _indicador_reloj * TAU / 1.3
		_indicador.self_modulate.a = 0.5 + 0.5 * (0.5 + 0.5 * cos(fase))
		_indicador.position = _actual.rtl.position + _actual.fin + Vector2(24.0, 2.0 + 2.5 * (0.5 - 0.5 * cos(fase)))
	# Sin nada que pintar, el grupo se apaga: se ahorra la copia del backbuffer y
	# los mipmaps de cada fotograma.
	var algo := false
	for hijo in _halo.get_children():
		if hijo is CanvasItem and hijo.visible and not hijo.is_queued_for_deletion():
			algo = true
			break
	_halo.visible = algo


## El radio del halo esta en px de la vista; el shader trabaja en px reales.
func _actualizar_escala() -> void:
	var e := get_viewport().get_final_transform().get_scale().x
	if is_equal_approx(e, _escala):
		return
	_escala = e
	_refrescar_halo()


func _refrescar_halo() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("color_halo", Color(halo_color.r, halo_color.g, halo_color.b))
	_material.set_shader_parameter("fuerza", halo_fuerza)
	_material.set_shader_parameter("umbral", halo_umbral)
	_material.set_shader_parameter("radio", halo_radio * maxf(_escala, 0.1))
	# El grupo solo pinta el rectangulo que ocupan sus hijos mas este margen: el
	# halo tiene que caber dentro. clear_margin mas ancho aun, para que el
	# desenfoque de los bordes lea transparente y no restos del fotograma.
	_halo.fit_margin = halo_radio * 1.6
	_halo.clear_margin = halo_radio * 3.0
