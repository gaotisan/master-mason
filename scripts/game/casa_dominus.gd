extends Node2D
## La casa de Dominus: la primera conversacion, tal como la cuenta el relato.
##
##   1. Magnus empuja la puerta y entra; Dominus sorbe su sopa.
##   2. "Se bienvenido, peregrino." El jugador recupera el mando y puede recorrer
##      la sala: al pasar junto a cada artilugio sale lo que el anciano ve en el.
##   3. Tras mirar un par de cosas (o al acercarse a la mesa, o si se queda
##      quieto demasiado) Dominus pregunta su nombre: se elige callar o intentar
##      inventar uno, y las dos cosas acaban en lo mismo, como en el cuento.
##   4. El anciano cede, se acerca a la mesa y se lo cuenta todo. La charla
##      sigue el texto hasta "Iram" y el favor que Dominus le reclama.
##   5. Fundido y cartel de fin de la demo.
##
## El decorado (casa_interior_decorado.tscn) pone la sala, la puerta y las
## marcas de cada objeto; Dominus y el dialogo son escenas aparte. Aqui solo va
## el guion. Las frases son las del relato, algo recortadas para que quepan en
## pantalla; la raya de dialogo la quita el propio dialogo.

const DECORADO := preload("res://scenes/game/casa_interior_decorado.tscn")
const DOMINUS := preload("res://scenes/characters/dominus.tscn")
const MAGNUS := preload("res://scenes/characters/magnus.tscn")
const DIALOGO := preload("res://scenes/ui/dialogo.tscn")
const FUENTE_TITULO := preload("res://assets/fonts/Cinzel-Variable.ttf")
const ESCENA_INICIO := "res://main.tscn"

## Viento dentro: la puerta cerrada lo apaga casi del todo.
@export var viento_db: float = -26.0
## Segundos de exploracion libre antes de que Dominus pregunte, si no se ha
## mirado lo suficiente.
@export var paciencia: float = 16.0
## Cuantos objetos mirar antes de la pregunta.
@export var objetos_para_preguntar: int = 2
## Radio en px en torno a la marca de un objeto para que cuente como mirado.
@export var radio_objeto: float = 120.0
## Acercamiento de camara cuando se sienta a hablar: zoom y segundos. La sala
## es justo una pantalla, asi que se encuadra entre los dos personajes sin
## dejar ver los bordes del decorado.
@export var zoom_charla: float = 1.3
@export var tiempo_acercamiento: float = 6.0

## Lo que ve el anciano en cada cosa, del relato. Clave = nombre de la marca
## del decorado.
const OBJETOS := {
	"Organo": "Vio el órgano de una iglesia…",
	"Potro": "…y a su lado lo que parecía ser un potro de tortura.",
	"Alambique": "En un rincón silbaba un viejo alambique.",
	"Pendulo": "Un péndulo enorme, rematado en un incensario, que no parecía empujado por mecanismo alguno.",
	"Caldero": "Junto al hombre borbotaba una caldera grande sobre un brasero.",
	"Hacha": "Un hacha junto a la chimenea le había hecho pensar en un leñador.",
	"Trampilla": "Bajo la mesa, una trampilla con una argolla oxidada.",
	"Puertas": "Por todas partes se abrían puertas, mamparas y trampillas.",
}

var _decorado: Node2D
var _dominus: Node2D
var _magnus: Node2D
var _sombra: Sprite2D
var _dialogo: Dialogo
var _vistos := {}
var _explorando := false
var _tiempo_explorando := 0.0
var _preguntado := false

@onready var _fundido: ColorRect = $Fundido/Rect
@onready var _camara: Camera2D = $Camara

func _ready() -> void:
	_decorado = DECORADO.instantiate()
	add_child(_decorado)
	move_child(_decorado, 0)
	var personajes: Node2D = _decorado.get_node("Personajes")
	_dominus = DOMINUS.instantiate()
	personajes.add_child(_dominus)
	_dominus.global_position = _marca("SitioDominus")
	_sombra = _crear_sombra()
	personajes.add_child(_sombra)
	_magnus = MAGNUS.instantiate()
	personajes.add_child(_magnus)
	_dialogo = DIALOGO.instantiate()
	add_child(_dialogo)
	WindAmbience.fade_to(viento_db, 1.5)
	# Magnus arranca fuera, al otro lado de la puerta, con el mando quitado.
	var entrada := _marca("Entrada")
	_magnus.global_position = Vector2(entrada.x - 260.0, entrada.y)
	_magnus.control_bloqueado = true
	_magnus.limite_izquierdo = _marca("LimiteIzq").x
	_magnus.limite_derecho = _marca("LimiteDer").x
	_dominus.sorber_sopa()
	_fundido.color.a = 1.0
	_entrada()

func _process(delta: float) -> void:
	_sombra.global_position = _magnus.global_position + Vector2(0, 2)
	# La luz que le cae segun donde esta: calida junto al fuego, azulada junto a
	# la puerta. La saca el decorado de las mismas luces que pintan el fondo; se
	# mira a media altura del cuerpo.
	if _decorado.has_method("tono_luz"):
		_magnus.modulate = _decorado.tono_luz(_decorado.to_local(_magnus.global_position) + Vector2(0, -165), 0.85)
	if not _explorando:
		return
	_tiempo_explorando += delta
	for nombre in OBJETOS:
		if _vistos.has(nombre) or not _decorado.has_node(nombre):
			continue
		if absf(_magnus.global_position.x - _marca(nombre).x) < radio_objeto:
			_vistos[nombre] = true
			_dialogo.leyenda(OBJETOS[nombre], 4.5)
	var junto_mesa: bool = _magnus.global_position.x > _marca("LimiteDer").x - 160.0
	if not _preguntado and (_vistos.size() >= objetos_para_preguntar or junto_mesa or _tiempo_explorando > paciencia):
		# Deja leer la ultima leyenda antes de interrumpir.
		_preguntado = true
		_explorando = false
		get_tree().create_timer(2.2 if _vistos.size() > 0 else 0.3).timeout.connect(_conversacion)

## Sombra de contacto bajo los pies, la misma que en el bosque: sin ella el
## personaje flota sobre las tablas.
func _crear_sombra() -> Sprite2D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 1))
	g.set_color(1, Color(0, 0, 0, 0))
	g.add_point(0.55, Color(0, 0, 0, 0.45))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 280
	t.height = 46
	var s := Sprite2D.new()
	s.texture = t
	s.modulate = Color(1, 1, 1, 0.5)
	return s

func _marca(nombre: String) -> Vector2:
	var n := _decorado.get_node_or_null(nombre) as Node2D
	return n.global_position if n else Vector2(1456, 1200)

## Empuja la puerta, entra, la puerta se cierra detras y Dominus levanta la vista.
func _entrada() -> void:
	var tw := create_tween()
	tw.tween_property(_fundido, "color:a", 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.6).timeout
	_decorado.abrir_puerta()
	await get_tree().create_timer(0.5).timeout
	_magnus.andar_hasta(_marca("Entrada").x + 260.0)
	await _magnus.llegado
	_decorado.cerrar_puerta()
	await get_tree().create_timer(0.9).timeout
	_dominus.quieto()
	_dominus.mirar_a(_magnus.global_position.x)
	await get_tree().create_timer(1.1).timeout
	await _dice_dominus("—Sé bienvenido, peregrino.")
	# Se cierra la linea antes de soltar el mando: un dialogo abierto se queda
	# en pantalla y es el que recibe las teclas.
	await _dialogo.cerrar()
	await get_tree().create_timer(0.3).timeout
	# El anciano camina respetuoso por la sala, fingiendo interes: el mando es
	# del jugador hasta la pregunta.
	_magnus.control_bloqueado = false
	_dominus.sorber_sopa()
	_explorando = true

func _conversacion() -> void:
	_magnus.control_bloqueado = true
	await _esperar_quieto()
	_magnus.girar_hacia(_dominus.global_position.x)
	_dominus.quieto()
	_dominus.mirar_a(_magnus.global_position.x)
	await get_tree().create_timer(0.6).timeout
	await _dice_dominus("—¿Cuál es tu nombre, peregrino?")
	var opciones: Array[String] = ["Guardar silencio", "Inventar un nombre"]
	var eleccion: int = await _dialogo.elegir(opciones)
	if eleccion == 0:
		await _dialogo.narrar("El anciano no contestó, fingiéndose distraído en el examen de aquellos artilugios.")
	else:
		await _dialogo.narrar("Trató de inventar un nombre, pero enseguida supo que había excedido el tiempo permitido para contestar sin provocar extrañeza.")
	await _dice_dominus("—Yo me llamo Dóminus. Soy curandero e inventor. ¿A quién tengo el placer de hospedar en mi casa?")
	await _dialogo.narrar("Terminó por ceder ante la inquietud que le poseía.")
	_magnus.andar_hasta(_marca("Mesa").x - 430.0)
	await _magnus.llegado
	_magnus.girar_hacia(_dominus.global_position.x)
	_acercar_camara()
	await _dialogo.narrar("Le habló de su extraño despertar en medio del bosque, de su solitario viaje y de su absoluto desconocimiento de sí mismo.")
	_dominus.inclinarse(true)
	await _dialogo.narrar("Dóminus escuchó cada palabra con una extraña avidez, bebiendo de ellas como un moribundo sediento.")
	_dominus.morderse_labio()
	await _dialogo.narrar("Pero arrugó la frente y se mordisqueó el labio cuando el anciano le confesó no recordar ni su nombre.")
	_dominus.inclinarse(false)
	_dominus.ofrecer_sopa()
	await get_tree().create_timer(1.4).timeout
	await _dice_dominus("—¿De modo que no recuerdas nada?")
	await _dice_magnus("—Así es. Por eso he venido a tu casa, pues confiaba en que tú me conocerías. Al menos, muéstrame el camino hasta una aldea donde puedan ayudarme.")
	_dominus.morderse_labio()
	await get_tree().create_timer(1.8).timeout
	await _dice_dominus("—No puedes irte.")
	await _dice_magnus("—¿Qué quieres decir?")
	await _dice_dominus("—Bosques infinitos nos rodean… Su regularidad mataría de aburrimiento a todo el que quisiera atravesarlos.")
	await _dice_magnus("—¿Qué sugieres, pues?")
	await _dice_dominus("—Te sugiero que permanezcas unos días en mi casa. Te diré quién eres y lo que te ha traído hasta aquí. Pero habrás de devolverme el favor.")
	await _dice_magnus("—Pensaba que no me conocías…")
	await _dice_dominus("—Sí te conozco.")
	await _dice_magnus("—¿Y por qué me has preguntado mi nombre?")
	await _dice_dominus("—Todo esto tiene una explicación, Iram, pero habrás de ser paciente. El conocimiento que me pides requiere ser administrado en pequeñas dosis…")
	await get_tree().create_timer(0.8).timeout
	await _dice_magnus("—¿Iram es mi nombre?")
	await _dice_dominus("—Así es.")
	await get_tree().create_timer(1.0).timeout
	await _dice_magnus("—¿Y qué favor es ese que reclamas?")
	_dominus.inclinarse(true)
	await _dice_dominus("—Es sencillo. Pasarás conmigo varios días, y durante ese tiempo me instruirás sobre el mundo.")
	await get_tree().create_timer(1.2).timeout
	_dominus.inclinarse(false)
	_dominus.sorber_sopa()
	_final()

## La camara se acerca despacio al encuentro, centrada entre Magnus y Dominus y
## sin salirse de la sala (2912x1632 = el decorado entero a zoom 1).
func _acercar_camara() -> void:
	var medio := (_magnus.global_position + _dominus.global_position) * 0.5 + Vector2(0, -250)
	var mitad := Vector2(1456, 816) / zoom_charla
	var destino := Vector2(clampf(medio.x, mitad.x, 2912.0 - mitad.x), clampf(medio.y, mitad.y, 1632.0 - mitad.y))
	var tw := create_tween().set_parallel()
	tw.tween_property(_camara, "zoom", Vector2.ONE * zoom_charla, tiempo_acercamiento).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_camara, "position", destino, tiempo_acercamiento).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _dice_dominus(texto: String) -> void:
	_dominus.hablar(true)
	await _dialogo.decir(_dominus, texto, "dominus")
	_dominus.hablar(false)

func _dice_magnus(texto: String) -> void:
	await _dialogo.decir(_magnus, texto, "magnus")

## Espera a que Magnus haya terminado de frenar: se le pide que ande hasta
## donde ya esta, con lo que suelta el eje, termina el paso como si se soltase
## la tecla y avisa con llegado cuando esta en reposo (que es cuando puede
## girarse). Mirar si la posicion cambia no servia: el primer physics_frame
## llega antes de que Magnus se mueva y la espera acababa en seco.
func _esperar_quieto() -> void:
	_magnus.andar_hasta(_magnus.global_position.x)
	await _magnus.llegado

## Fundido lento a negro, el cartel, y cualquier tecla vuelve al principio.
func _final() -> void:
	_dialogo.cerrar()
	var tw := create_tween()
	tw.tween_property(_fundido, "color:a", 1.0, 3.5).set_trans(Tween.TRANS_SINE)
	WindAmbience.fade_to(-14.0, 4.0)
	await tw.finished
	var capa := CanvasLayer.new()
	capa.layer = 60
	add_child(capa)
	var titulo := _rotulo("EL MAESTRO CONSTRUCTOR", 96, 640.0, Color(0.86, 0.78, 0.62))
	var fin := _rotulo("FIN DE LA DEMO", 44, 800.0, Color(0.6, 0.56, 0.5))
	capa.add_child(titulo)
	capa.add_child(fin)
	for r in [titulo, fin]:
		r.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(r, "modulate:a", 1.0, 2.0).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(4.0).timeout
	_esperando_tecla = true

var _esperando_tecla := false

func _unhandled_input(evento: InputEvent) -> void:
	if _esperando_tecla and evento.is_pressed() and not evento.is_echo():
		_esperando_tecla = false
		get_tree().change_scene_to_file(ESCENA_INICIO)

func _rotulo(texto: String, tam: int, y: float, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	var f := FontVariation.new()
	f.base_font = FUENTE_TITULO
	f.spacing_glyph = int(tam * 0.12)
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y - tam * 0.6)
	l.size = Vector2(2912, tam * 1.4)
	return l
