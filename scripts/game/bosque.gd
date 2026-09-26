extends Node2D
## El bosque: el camino de Magnus desde que despierta, al atardecer, hasta la
## casa de Dominus, ya de noche. Sigue el principio del cuento: el valle con la
## ciudad sin nombre a la que no debe ir, el bosque que no se acaba, el camino
## de estrellas y, al final, la luz temblorosa de una casa que no deberia
## mantenerse en pie.
##
## Todo el dibujo son siluetas blancas (tools/mundo/bosque.py) que aqui se
## tintan segun la HORA, y la hora no va con el reloj sino con lo que se ha
## andado: cada tramo del camino tiene su paleta (PALETAS) y entre una y otra se
## interpola por la x de Magnus. Asi el anochecer lo marca el jugador, y si se
## da la vuelta el cielo vuelve a clarear.
##
## Las capas de arboles se repiten (Parallax2D). Sus bordes -- el claro del
## principio y el de la casa -- los pone capa_bosque.gdshader con el paralaje
## de cada capa, no la hoja.

const DIALOGO := "res://scenes/ui/dialogo.tscn"
const CASA_DOMINUS := "res://scenes/game/casa_dominus.tscn"

## Donde cae Magnus y donde esta la puerta de la casa, en x del mundo.
@export var x_inicio: float = 1700.0
@export var x_puerta: float = 15400.0
## Fin del mundo por la derecha (limite de camara).
@export var x_fin: float = 17300.0
## Hasta donde se deja ir a la izquierda: pasado esto, la intuicion lo frena.
@export var x_intuicion: float = 950.0
## Suelo del mundo (pies de Magnus) y altura de la camara. Con la camara en 746
## el suelo cae en la fila 1270 de la pantalla: mas cielo, menos tierra que en
## dark_stage.
@export var y_suelo: float = 1200.0
@export var y_camara: float = 746.0
## Adelanto de la camara hacia donde mira Magnus, y lo que tarda en seguirle.
@export var adelanto_camara: float = 260.0
@export var suavizado_camara: float = 2.4
## Viento al entrar, como en dark_stage.
@export var viento_db: float = -14.0
## Cinematica de caida al empezar. A false aparece de pie (para probar).
@export var caida_al_empezar: bool = true
## Segundos de negro que se abren antes de que caiga.
@export var apertura: float = 2.2

## Paleta de cada tramo. x = donde manda esa paleta del todo. capas = tinte de
## las cuatro capas de arboles de lejos a cerca. luz = modulate de Magnus.
const PALETAS := [
	{"x": 1700.0, "arriba": Color("#5b6f95"), "horizonte": Color("#e9b89a"), "brillo": Color("#ffb27a"),
	 "brillo_pos": Vector2(0.62, 0.74), "brillo_f": 0.45,
	 "valle": Color("#bca8b2"), "valle_a": 1.0,
	 "capas": [Color("#c7cadb"), Color("#9ea6c2"), Color("#707ea2"), Color("#3e4968")],
	 "suelo": Color("#2a2d3e"), "niebla": Color("#f0c9ae"), "niebla_d": 0.26,
	 "estrellas": 0.0, "via": 0.0, "luna": 0.0, "luz": Color(1.0, 0.93, 0.88),
	 "hojas": 1.0, "luciernagas": 0.0, "bulbos": 0.0},
	{"x": 5200.0, "arriba": Color("#3f5078"), "horizonte": Color("#d69a88"), "brillo": Color("#ff9670"),
	 "brillo_pos": Vector2(0.55, 0.8), "brillo_f": 0.34,
	 "valle": Color("#a595a6"), "valle_a": 0.35,
	 "capas": [Color("#a8b0cc"), Color("#7f8bae"), Color("#55648c"), Color("#2d3756")],
	 "suelo": Color("#22263a"), "niebla": Color("#c9a4a2"), "niebla_d": 0.3,
	 "estrellas": 0.12, "via": 0.0, "luna": 0.0, "luz": Color(0.93, 0.86, 0.86),
	 "hojas": 0.8, "luciernagas": 0.0, "bulbos": 0.0},
	{"x": 8800.0, "arriba": Color("#27365b"), "horizonte": Color("#6c85ae"), "brillo": Color("#b9c9e8"),
	 "brillo_pos": Vector2(0.7, 0.3), "brillo_f": 0.18,
	 "valle": Color("#7d8fb3"), "valle_a": 0.0,
	 "capas": [Color("#8a9bbf"), Color("#6577a0"), Color("#44557d"), Color("#232e48")],
	 "suelo": Color("#182036"), "niebla": Color("#8fa5cc"), "niebla_d": 0.34,
	 "estrellas": 0.55, "via": 0.35, "luna": 0.65, "luz": Color(0.72, 0.75, 0.88),
	 "hojas": 0.3, "luciernagas": 0.4, "bulbos": 0.5},
	{"x": 12200.0, "arriba": Color("#16213d"), "horizonte": Color("#4a6a9a"), "brillo": Color("#a3bce4"),
	 "brillo_pos": Vector2(0.77, 0.22), "brillo_f": 0.16,
	 "valle": Color("#5a6f98"), "valle_a": 0.0,
	 "capas": [Color("#6e86b0"), Color("#50668f"), Color("#374a70"), Color("#19223c")],
	 "suelo": Color("#111a30"), "niebla": Color("#7e9ccc"), "niebla_d": 0.3,
	 "estrellas": 1.0, "via": 0.85, "luna": 1.0, "luz": Color(0.58, 0.62, 0.78),
	 "hojas": 0.0, "luciernagas": 1.0, "bulbos": 1.0},
	{"x": 15400.0, "arriba": Color("#131c35"), "horizonte": Color("#40608f"), "brillo": Color("#a3bce4"),
	 "brillo_pos": Vector2(0.77, 0.22), "brillo_f": 0.14,
	 "valle": Color("#5a6f98"), "valle_a": 0.0,
	 "capas": [Color("#647ca6"), Color("#495e87"), Color("#334467"), Color("#161e36")],
	 "suelo": Color("#0f172b"), "niebla": Color("#7593c2"), "niebla_d": 0.26,
	 "estrellas": 1.0, "via": 0.9, "luna": 1.0, "luz": Color(0.58, 0.62, 0.78),
	 "hojas": 0.0, "luciernagas": 0.7, "bulbos": 0.6},
]

## Frases del cuento que aparecen al pasar por cada sitio (sin bloquear: son
## leyendas que se desvanecen). La primera pareja sale al levantarse.
const AL_DESPERTAR := [
	"Debía estar atardeciendo, pensó. O tal vez amanecía…",
	"Lejos, en medio del valle, se elevaban los tranquilos humos de una ciudad sin nombre.",
]
const INTUICION := "Una intuición le decía que no debía aventurarse más allá del bosque."
const LEYENDAS := [
	[2900.0, "Temeroso y vigilante, se internó en el bosque."],
	[4700.0, "Supo que aquel camino llevaba a una ciudad llamada Santiago…"],
	[6500.0, "…y que el suyo era el antiguo oficio de cantero."],
	[8300.0, "Anduvo durante horas. No había conventos, granjas ni aldeas."],
	[10300.0, "Reconoció en el cielo nocturno un camino de estrellas."],
	[13100.0, "Una luz temblorosa le llegó desde lo lejos."],
	[14350.0, "Aquella casa, se dijo, no debía mantenerse en pie."],
]

## Donde empieza (y acaba) el bosque de cada capa, en x del mundo.
const BORDES := [[2500.0, 1e6], [2800.0, 1e6], [3000.0, 14900.0], [3300.0, 14500.0]]
const ESCALAS := [0.15, 0.3, 0.5, 0.72]

@onready var _magnus: Node2D = $Personajes/Magnus
@onready var _sombra: Sprite2D = $Personajes/Sombra
@onready var _camara: Camera2D = $Camara
@onready var _cielo: ColorRect = $Cielo/Rect
@onready var _luna: Sprite2D = $Cielo/Luna
@onready var _valle: Parallax2D = $Valle
@onready var _capas: Array[Parallax2D] = [$Capa0, $Capa1, $Capa2, $Capa3]
@onready var _nieblas: Array[ColorRect] = [$Niebla1/Rect, $Niebla2/Rect]
@onready var _suelo_sprite: Sprite2D = $Suelo/Sprite
@onready var _niebla_baja: ShaderMaterial = $Niebla3/Rect.material
@onready var _frente: Parallax2D = $SueloFrente
@onready var _primer_plano: Parallax2D = $PrimerPlano
@onready var _bulbos: Node2D = $Suelo/Bulbos
@onready var _hojas: GPUParticles2D = $Camara/Hojas
@onready var _luciernagas: GPUParticles2D = $Camara/Luciernagas
## Detras del suelo: las hojas que caen por debajo de la linea se hunden en la
## tierra en vez de verse cayendo sobre ella.
@onready var _hojarasca: CPUParticles2D = $Hojarasca
@onready var _gargola: Node2D = $Gargola
@onready var _casa: Node2D = $Casa
@onready var _estructuras: Node2D = $Estructuras
@onready var _aviso_puerta: Node2D = $AvisoPuerta
@onready var _pajaros: Node2D = $Pajaros/Bandada
@onready var _fundido: ColorRect = $Fundido/Rect

var _dialogo: Node
var _leyenda_siguiente := 0
var _control := false            # el jugador ya tiene el mando (tras levantarse)
var _intuicion_espera := 0.0
var _en_puerta := false
var _entrando := false
var _temblor := 0.0              # sacudida de camara que queda (s)
var _pajaros_salieron := false
var _hora: Dictionary = {}

func _ready() -> void:
	# El dialogo se carga por ruta para que la escena abra aunque aun no exista
	# (se monta aparte); sin el, las leyendas no salen y ya esta.
	if ResourceLoader.exists(DIALOGO):
		_dialogo = (load(DIALOGO) as PackedScene).instantiate()
		add_child(_dialogo)
	_aviso_puerta.setup(&"saltar")
	_crear_ojos_gargola()
	WindAmbience.gust_db = 0.0
	WindAmbience.fade_to(viento_db, 0.0)
	_magnus.position = Vector2(x_inicio, y_suelo)
	_magnus.limite_izquierdo = x_intuicion
	_magnus.limite_derecho = x_puerta + 420.0
	_magnus.impacto.connect(_al_impactar)
	_magnus.cinematica_terminada.connect(_al_levantarse)
	_camara.limit_left = 0
	_camara.limit_right = int(x_fin)
	_camara.position = Vector2(_objetivo_camara(), y_camara)
	_camara.reset_smoothing()
	_colocar_bulbos()
	_actualizar_hora(true)
	_fundido.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fundido, "color:a", 0.0, apertura).set_trans(Tween.TRANS_SINE)
	if caida_al_empezar:
		# Cae ya con la escena casi abierta: si cayese en negro no se veria
		# de donde viene ni adonde llega.
		_magnus.visible = false
		get_tree().create_timer(apertura * 0.8).timeout.connect(func() -> void:
			_magnus.visible = true
			_magnus.caer_desde_arriba())
	else:
		_al_levantarse()

func _process(delta: float) -> void:
	_seguir_camara(delta)
	_actualizar_hora(false)
	_actualizar_sombra()
	_actualizar_gargola()
	_comprobar_leyendas()
	_comprobar_intuicion(delta)
	_comprobar_puerta()
	_comprobar_pajaros()

# --------------------------------------------------------------------------
# Camara
# --------------------------------------------------------------------------

## Hacia donde va la camara: delante de Magnus, sin salirse del mundo. El
## limite se aplica aqui y no solo en los limit_* de la Camera2D: si la
## posicion se fuese mas alla, al volver habria un tramo muerto en que la
## camara se mueve sin que la vista cambie.
func _objetivo_camara() -> float:
	var x: float = _magnus.position.x + adelanto_camara * _magnus.mirando()
	return clampf(x, 1456.0, x_fin - 1456.0)

## Sigue a Magnus en x con retardo exponencial (independiente de los fps) y el
## adelanto hacia donde mira. La y no se mueve: el suelo es plano.
func _seguir_camara(delta: float) -> void:
	var k := 1.0 - exp(-suavizado_camara * delta)
	var x := lerpf(_camara.position.x, _objetivo_camara(), k)
	var sacudida := Vector2.ZERO
	if _temblor > 0.0:
		_temblor = maxf(_temblor - delta, 0.0)
		var f := _temblor / 0.35
		sacudida = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 7.0 * f * f
	_camara.position = Vector2(x, y_camara)
	_camara.offset = sacudida

# --------------------------------------------------------------------------
# Hora del dia
# --------------------------------------------------------------------------

## Interpola la paleta por la x de Magnus y la aplica a todo lo que se tinta.
func _actualizar_hora(forzar: bool) -> void:
	var x := _magnus.position.x
	var h := _paleta_en(x)
	var centro := _camara.get_screen_center_position().x
	var cielo := _cielo.material as ShaderMaterial
	cielo.set_shader_parameter("color_arriba", h["arriba"])
	cielo.set_shader_parameter("color_horizonte", h["horizonte"])
	cielo.set_shader_parameter("color_brillo", h["brillo"])
	cielo.set_shader_parameter("pos_brillo", h["brillo_pos"])
	cielo.set_shader_parameter("fuerza_brillo", h["brillo_f"])
	cielo.set_shader_parameter("estrellas", h["estrellas"])
	cielo.set_shader_parameter("via_lactea", h["via"])
	cielo.set_shader_parameter("desplaza", centro * 0.00002)
	_luna.modulate = Color(0.92, 0.94, 1.0, h["luna"])
	_valle.modulate = Color(h["valle"], h["valle_a"])
	_valle.visible = h["valle_a"] > 0.005
	for i in _capas.size():
		_capas[i].modulate = h["capas"][i]
		var sprite := _capas[i].get_child(0) as Sprite2D
		(sprite.material as ShaderMaterial).set_shader_parameter("camara_x", centro)
	for i in _nieblas.size():
		var m := _nieblas[i].material as ShaderMaterial
		m.set_shader_parameter("color_niebla", h["niebla"])
		m.set_shader_parameter("densidad", h["niebla_d"] * (1.0 if i == 0 else 0.7))
		m.set_shader_parameter("desplaza", centro * (0.00004 if i == 0 else 0.00012))
	# El tinte va en el sprite, no en el Parallax2D: los brillos de los bulbos
	# cuelgan de el y un modulate oscuro en el padre los apagaba.
	_suelo_sprite.modulate = h["suelo"]
	_frente.modulate = (h["suelo"] as Color).darkened(0.1)
	_primer_plano.modulate = (h["suelo"] as Color).darkened(0.72)
	_niebla_baja.set_shader_parameter("color_niebla", h["niebla"])
	_niebla_baja.set_shader_parameter("densidad", h["niebla_d"] * 0.55)
	($Gargola/Silueta as CanvasItem).modulate = (h["capas"][3] as Color).lerp(h["suelo"], 0.4)
	_estructuras.modulate = h["capas"][2]
	_pajaros.modulate = h["capas"][3].darkened(0.2)
	_bulbos.modulate.a = h["bulbos"]
	_hojas.amount_ratio = h["hojas"]
	_hojas.emitting = h["hojas"] > 0.01
	_luciernagas.amount_ratio = h["luciernagas"]
	_luciernagas.emitting = h["luciernagas"] > 0.01
	# La luz de Magnus: la de la hora y, cerca de la casa, la calida de la
	# puerta abierta.
	var calor := clampf(1.0 - absf(x - x_puerta) / 1400.0, 0.0, 1.0)
	_magnus.modulate = (h["luz"] as Color).lerp(Color(0.98, 0.84, 0.7), calor * 0.55)
	# La casa se enciende a lo lejos: primero un punto de luz, luego las ventanas.
	if "intensidad_luz" in _casa:
		_casa.intensidad_luz = clampf((x - 12600.0) / 1600.0, 0.15, 1.0)
	if "color_silueta" in _casa:
		_casa.color_silueta = (h["capas"][3] as Color).darkened(0.25)
	_hora = h

func _paleta_en(x: float) -> Dictionary:
	if x <= PALETAS[0]["x"]:
		return PALETAS[0]
	for i in range(1, PALETAS.size()):
		var b: Dictionary = PALETAS[i]
		if x <= b["x"]:
			var a: Dictionary = PALETAS[i - 1]
			var t := smoothstep(a["x"], b["x"], x)
			return _mezclar(a, b, t)
	return PALETAS[PALETAS.size() - 1]

func _mezclar(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var r := {}
	for k in a:
		var va = a[k]
		var vb = b[k]
		if va is Color:
			r[k] = (va as Color).lerp(vb, t)
		elif va is Vector2:
			r[k] = (va as Vector2).lerp(vb, t)
		elif va is Array:
			var arr := []
			for i in va.size():
				arr.append((va[i] as Color).lerp(vb[i], t))
			r[k] = arr
		else:
			r[k] = lerpf(va, vb, t)
	return r

# --------------------------------------------------------------------------
# Detalles
# --------------------------------------------------------------------------

## Sombra de contacto bajo los pies: fija en el suelo, y en la caida crece y se
## oscurece a medida que el cuerpo se acerca.
func _actualizar_sombra() -> void:
	var alto := maxf(y_suelo - _magnus.position.y, 0.0)
	var cerca := 1.0 - clampf(alto / 1200.0, 0.0, 1.0)
	_sombra.position = Vector2(_magnus.position.x, y_suelo + 2.0)
	_sombra.scale = Vector2(1.0, 1.0) * (0.55 + 0.45 * cerca)
	_sombra.modulate.a = 0.42 * cerca * cerca * (1.0 if _magnus.visible else 0.0)

## Los ojos de la gargola siguen a Magnus: los brillos se desplazan un poco
## hacia el, sin salirse de las cuencas.
func _actualizar_gargola() -> void:
	var ojos := _gargola.get_node_or_null("Ojos") as Node2D
	if ojos == null:
		return
	var dx := clampf((_magnus.position.x - _gargola.position.x) / 900.0, -1.0, 1.0)
	ojos.position.x = dx * 3.0
	var cerca := clampf(1.0 - absf(_magnus.position.x - _gargola.position.x) / 1800.0, 0.0, 1.0)
	ojos.modulate.a = cerca * _hora.get("bulbos", 0.0)

func _al_impactar() -> void:
	_temblor = 0.35
	_hojarasca.global_position = Vector2(_magnus.position.x, y_suelo - 20.0)
	_hojarasca.restart()
	_hojarasca.emitting = true

func _al_levantarse() -> void:
	_control = true
	await get_tree().create_timer(1.2).timeout
	_leyenda(AL_DESPERTAR[0], 5.0)
	await get_tree().create_timer(6.0).timeout
	if _magnus.position.x < LEYENDAS[0][0]:
		_leyenda(AL_DESPERTAR[1], 6.0)

func _leyenda(texto: String, duracion: float) -> void:
	if _dialogo:
		_dialogo.leyenda(texto, duracion)

func _comprobar_leyendas() -> void:
	if not _control or _leyenda_siguiente >= LEYENDAS.size():
		return
	if _magnus.position.x >= LEYENDAS[_leyenda_siguiente][0]:
		_leyenda(LEYENDAS[_leyenda_siguiente][1], 5.5)
		_leyenda_siguiente += 1

## Hacia el valle no se va: al llegar al limite se para solo (limite_izquierdo)
## y sale la frase. Con espera para no repetirla cada vez que se roza.
func _comprobar_intuicion(delta: float) -> void:
	_intuicion_espera = maxf(_intuicion_espera - delta, 0.0)
	if not _control or _intuicion_espera > 0.0:
		return
	if _magnus.position.x < x_intuicion + 160.0 and _magnus.mirando() < 0.0:
		_leyenda(INTUICION, 5.0)
		_intuicion_espera = 14.0

func _comprobar_pajaros() -> void:
	if _pajaros_salieron or _magnus.position.x < 3800.0:
		return
	_pajaros_salieron = true
	_pajaros.call("despegar", _camara.get_screen_center_position())

## Los capullos del suelo que se encienden de noche. La hoja del suelo se repite,
## asi que los brillos van dentro de su Parallax2D y se repiten con ella.
func _colocar_bulbos() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/bosque/bosque_meta.json"))
	var puntos: Array = meta["suelo"]["bulbos"]
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 12
	var textura := _textura_brillo()
	var usados: Array[float] = []
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for p in puntos:
		var x: float = p[0]
		# uno de cada tanto y no todos juntos
		if rnd.randf() > 0.12:
			continue
		var cerca := false
		for u in usados:
			if absf(u - x) < 26.0:
				cerca = true
				break
		if cerca:
			continue
		usados.append(x)
		var s := Sprite2D.new()
		s.texture = textura
		s.material = mat
		s.position = Vector2(x, p[1])
		var r := rnd.randf_range(0.18, 0.34)
		s.scale = Vector2(r, r)
		s.modulate = Color(0.56, 0.85, 1.0, rnd.randf_range(0.6, 1.0))
		_bulbos.add_child(s)

## Dos brillos palidos en las cuencas de la gargola (posiciones en el meta del
## generador, relativas al pie del tronco).
func _crear_ojos_gargola() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/bosque/bosque_meta.json"))
	var ojos := Node2D.new()
	ojos.name = "Ojos"
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var tex := _textura_brillo()
	for o in meta["gargola"]["ojos"]:
		var s := Sprite2D.new()
		s.texture = tex
		s.material = mat
		s.position = Vector2(o[0], o[1])
		s.scale = Vector2(0.16, 0.12)
		s.modulate = Color(1.0, 0.86, 0.55, 0.9)
		ojos.add_child(s)
	ojos.modulate.a = 0.0
	# Hermano de la silueta, no hijo: asi el tinte oscuro no les llega.
	_gargola.add_child(ojos)

func _textura_brillo() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.18, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 128
	t.height = 128
	return t

# --------------------------------------------------------------------------
# La puerta
# --------------------------------------------------------------------------

func _comprobar_puerta() -> void:
	if _entrando or not _control:
		return
	var cerca: bool = absf(_magnus.position.x - x_puerta) < 170.0 and _magnus.mirando() > 0.0
	if cerca == _en_puerta:
		return
	_en_puerta = cerca
	_magnus.salto_bloqueado = cerca
	if cerca:
		_aviso_puerta.position = Vector2(x_puerta, y_suelo - 520.0)
		_aviso_puerta.appear(true)
	else:
		_aviso_puerta.disappear()

func _unhandled_input(evento: InputEvent) -> void:
	if _en_puerta and not _entrando and evento.is_action_pressed("saltar"):
		get_viewport().set_input_as_handled()
		_entrar()

## Empuja la puerta entornada y entra: se le quita el mando, la puerta se abre,
## anda hasta dentro y se funde a negro hacia la casa.
func _entrar() -> void:
	_entrando = true
	_aviso_puerta.succeed(true)
	_magnus.control_bloqueado = true
	if _casa.has_method("abrir_puerta"):
		_casa.abrir_puerta()
	await get_tree().create_timer(0.7).timeout
	_magnus.andar_hasta(x_puerta + 150.0)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(_fundido, "color:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE)
	WindAmbience.fade_to(viento_db - 6.0, 2.0)
	await tw.finished
	get_tree().change_scene_to_file(CASA_DOMINUS)
