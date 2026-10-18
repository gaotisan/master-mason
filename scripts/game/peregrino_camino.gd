extends Node2D
## El peregrino en el camino del bosque, de frente, LO LLEVA EL JUGADOR: abajo
## anda hacia la camara, arriba se da la vuelta y se aleja, B saca o guarda el
## baston, doble toque corre (sin baston). Es el del juego (PeregrinoFrontal,
## scenes/characters/peregrino_frontal.tscn: lo que se le mejore alli se ve
## aqui); esto le pone la perspectiva de la foto, su luz
## (peregrino_camino.gdshader), su sombra y el paralaje de la camara.
##
## ENTRA (entrar(), lo pide camino_bosque.gd: tras el emu la primera vez, si no
## enseguida) andando solo desde la bruma del fondo del camino, como si viniera
## de la escena de antes, y al salir de ella el mando pasa al jugador.
## LA BRUMA DEL FONDO va con la distancia (vista): sale de la luz al acercarse y
## se pierde en ella al alejarse. Al llegar delante se para solo y emite
## `llego` (la escena funde a negro: aun no hay la de la camara de detras). Si
## se aleja hasta pies_corte (aun se le ve, entrando en la bruma) emite `se_va`:
## la escena corta a la de antes, como un cambio de camara (el usuario: "para
## darle continuidad al mundo"). Al darle el mando emite `al_mando` (la escena
## empieza a cargar la de antes, para que el corte sea al instante).
##
## TECLA RETENIDA: si llega con arriba pulsada (la que le metio en la bruma en
## la escena de antes: alli arriba es alejarse por el camino, que aqui es
## venir hacia la camara), mientras siga pulsada anda hacia la camara; al
## soltarla, lo normal. Si no, tras el corte se daba la vuelta y se volvia. La
## hojarasca hace lo mismo al reves: el corte queda continuo en los dos sentidos.
##
## COMO LLEGA: como lo dejo la escena de antes (PeregrinoEstado): con el baston
## en la mano o guardado a la espalda, y su magia; las dos cosas valen. Si no
## dice nada (la escena sola), lo de aqui (baston en la mano, sin magia: sin
## bola), o lo que se le pase al lanzarla: camino_bosque.bat espalda / mano.
##
## PERSPECTIVA. Horizonte en la fila 980. El alto de la persona es ALTO_POR_PIES
## veces lo que tiene los pies bajo el horizonte: el de la camara del video del
## andar con baston (195,3 px de bajada por unidad de escala con 324 de alto:
## camara a 1,02 m para 1,7 m de persona). Con el, el pie apoyado no patina; con
## la camara a 1,15 m (lo de antes) patinaba 5 px por paso delante. El video
## sin baston es de una camara mas baja (0,77 m): ese aun patina algo (~10 px
## por paso delante).

signal llego
signal se_va
signal al_mando

const PEREGRINO := preload("res://scenes/characters/peregrino_frontal.tscn")
## Con preload (no por su class_name): asi no depende de la cache de clases.
const Estado := preload("res://scripts/characters/peregrino_estado.gd")
const SHADER := preload("res://scripts/game/peregrino_camino.gdshader")
const MEDIO := preload("res://assets/world/camino_bosque/medio.png")
const PROFUNDIDAD := preload("res://assets/world/camino_bosque/profundidad.png")
const Imagenes := preload("res://scripts/game/imagenes_cache.gd")
## Las pisadas, precargadas (con la escena: cargarlas en _ready sumaba al tiron
## de entrada).
const PISADAS_HOJAS: Array[AudioStream] = [
	preload("res://assets/audio/hojarasca_paso_1.wav"), preload("res://assets/audio/hojarasca_paso_2.wav"),
	preload("res://assets/audio/hojarasca_paso_3.wav"), preload("res://assets/audio/hojarasca_paso_4.wav"),
	preload("res://assets/audio/hojarasca_paso_5.wav"), preload("res://assets/audio/hojarasca_paso_6.wav"),
	preload("res://assets/audio/hojarasca_paso_7.wav"), preload("res://assets/audio/hojarasca_paso_8.wav"),
	preload("res://assets/audio/hojarasca_paso_9.wav"), preload("res://assets/audio/hojarasca_paso_10.wav"),
	preload("res://assets/audio/hojarasca_paso_11.wav"), preload("res://assets/audio/hojarasca_paso_12.wav")]
const PANTALLA := Vector2(2912, 1632)
const HORIZONTE := 980.0
## Alto de la persona con escala 1, de la capucha a los pies (las casillas de
## peregrino_frames: 324 sin baston; con el en la mano, 340 con la garra encima).
const ALTO_ESCALA_1 := 324.0
const ALTO_POR_PIES := ALTO_ESCALA_1 / 195.3
## Fotogramas que sigue andando desde que deja de querer andar: el resto del
## paso hasta los pies juntos, el puente al reposo y el margen del doble toque
## (medido con el baston: entre 8 y 29, segun donde le pille del paso).
const PASADA := 20.0

## Si la escena de antes no dice nada.
@export var baston_en_mano := true
@export var magia := 0.0
@export var magia_recarga := 0.0

@export_group("Recorrido")
## Columna de los pies (el centro del camino) y filas de los pies: del todo
## en la bruma (por ahi entra), donde acaba de salir de ella (ahi toma el mando
## el jugador), por donde se va alejandose (corte a la escena de antes, aun
## medio a la vista), donde se para delante (mas o menos: suelta antes y el
## componente termina el paso, PASADA) y donde no pasa nunca.
@export var columna := 1450.0
@export var pies_bruma := 1120.0
@export var pies_entrada := 1150.0
@export var pies_corte := 1138.0
@export var pies_hasta := 1480.0
@export var pies_tope := 1560.0

@export_group("Luz")
@export var exposicion := 0.85
## Bruma de su distancia: al salir de la del fondo y delante. Apagada
## (2026-10-18: "se difumina demasiado en el bosque"; antes 0,4 y 0,05). Sigue
## saliendo de la bruma del fondo al entrar (vista).
@export var niebla_lejos := 0.0
@export var niebla_cerca := 0.0
## Bruma en los pies (que se pierden en el suelo), en fraccion de su alto: fija
## (60 px) de lejos le comia las piernas y parecia flotar.
@export var bruma_pies := 0.07
## Cuanto tapa esa bruma de los pies (0 = nada). Apagada con la de la distancia
## (antes 0,35).
@export var bruma_pies_fuerza := 0.0
## Lo oscura que es la sombra de contacto y la que alarga hacia la camara (la
## luz le viene de detras).
@export var sombra := 0.5
@export var sombra_larga := 0.22

@export_group("Sonido")
## Las pisadas en las hojas del camino (las de la hojarasca: raw/master_builder/
## audio/hojarasca/construye.py), delante; lejos suenan menos (el componente) y
## en la bruma del fondo, con lo que se le ve (antes sonaban sin verle).
@export var pasos_db := -19.0
## Hojas que aparta al pisar (por pisada, de media), ya cerca (escala > 1).
@export var patadas := 0.7

var controlador: Node
var peregrino: PeregrinoFrontal

var _estado := "esperando"     # esperando / entrando / jugando / llegando / fuera
var _reten := false            # llego con arriba pulsada: hasta soltarla, arriba = hacia la camara
var _espera := -1.0
var _vista := 0.0
var _escala_bruma := 1.0
var _escala_entrada := 1.0
var _escala_hasta := 1.0
var _mat: ShaderMaterial
var _medio: Image
var _prof: Image
var _sombra: Node2D
var _tex_sombra: Texture2D
var _fondo_mat: ShaderMaterial


func _ready() -> void:
	_reten = _arriba()
	var e: Dictionary = Estado.leer(get_tree())
	if not e.is_empty():
		# Con get: las partidas guardadas antes de la magia no traen sus campos, y
		# con [] el _ready se rompia antes de crear al peregrino (no salia).
		baston_en_mano = bool(e.get("baston_en_mano", baston_en_mano))
		magia = float(e.get("magia", magia))
		magia_recarga = float(e.get("magia_recarga", magia_recarga))
	else:
		for a in OS.get_cmdline_user_args():
			if a in ["espalda", "mano"]:
				baston_en_mano = a == "mano"
	_medio = Imagenes.de(MEDIO)
	_prof = Imagenes.de(PROFUNDIDAD)
	_escala_bruma = _escala_de(pies_bruma)
	_escala_entrada = _escala_de(pies_entrada)
	# Sombra de contacto: un ovalo blando, por debajo del peregrino.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 0, 0, 0.4), Color(0, 0, 0, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_tex_sombra = t
	_sombra = Node2D.new()
	_sombra.z_index = -5
	_sombra.draw.connect(_dibujar_sombra)
	add_child(_sombra)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("medio", MEDIO)
	peregrino = PEREGRINO.instantiate()
	peregrino.con_baston = baston_en_mano
	peregrino.magia = magia
	peregrino.magia_recarga = magia_recarga
	peregrino.cara = "frente"
	peregrino.escala_min = 0.15
	peregrino.escala_max = _escala_de(pies_tope)
	peregrino.escala_inicial = _escala_bruma
	peregrino.perspectiva = _pies_de
	peregrino.material = _mat
	peregrino.pasos = _pasos_en_hojas()
	peregrino.pasos_db = -80.0
	add_child(peregrino)
	peregrino.piso.connect(_al_pisar)
	# delante suelta antes: lo que sigue andando hasta pararse (con su paso: sin
	# baston anda algo mas deprisa)
	_escala_hasta = 1.0 / (1.0 / _escala_de(pies_hasta) + PASADA * peregrino.paso_andar("frente"))
	# esperando, quieto y sin verse
	visible = false
	peregrino.process_mode = Node.PROCESS_MODE_DISABLED


## Que entre desde la bruma del fondo dentro de `espera` segundos.
func entrar(espera := 0.0) -> void:
	_espera = espera


## Una pisada al azar de las doce de la hojarasca, con algo de tono y volumen
## distintos.
func _pasos_en_hojas() -> AudioStreamRandomizer:
	var r := AudioStreamRandomizer.new()
	for s in PISADAS_HOJAS:
		r.add_stream(-1, s)
	r.random_pitch = 1.08
	r.random_volume_offset_db = 2.0
	return r


func _arriba() -> bool:
	return Input.is_action_pressed("saltar") or Input.is_key_pressed(KEY_UP)


func _escala_de(pies_y: float) -> float:
	return (pies_y - HORIZONTE) * ALTO_POR_PIES / ALTO_ESCALA_1


## Los pies en el suelo de la foto, sin la camara.
func _suelo(escala: float) -> Vector2:
	return Vector2(columna, HORIZONTE + escala * ALTO_ESCALA_1 / ALTO_POR_PIES)


## Al pisar, ya cerca, aparta alguna hoja del camino (las de Hojas).
func _al_pisar(_pies: Vector2) -> void:
	var escala := peregrino.escala
	if escala < 1.0 or not controlador:
		return
	var hojas := controlador.get_node_or_null("Hojas")
	if hojas == null or not hojas.has_method("patear"):
		return
	var n := int(patadas) + (1 if randf() < fmod(patadas, 1.0) else 0)
	for i in n:
		hojas.patear(_suelo(escala) + Vector2(randf_range(-0.09, 0.09) * escala * ALTO_ESCALA_1, 0.0),
			clampf(escala / 1.8, 0.6, 1.4))


## Donde van los pies con esa escala (lo pide el componente al colocarse).
func _pies_de(escala: float) -> Vector2:
	var p := _suelo(escala)
	if controlador:
		p += controlador.paralaje(p, _w(p))
	return p


## Cercania (1 cerca, 0 el fondo) del suelo en p, la de profundidad.png.
func _w(p: Vector2) -> float:
	var x := clampi(int(p.x / PANTALLA.x * _prof.get_width()), 0, _prof.get_width() - 1)
	var y := clampi(int(p.y / PANTALLA.y * _prof.get_height()), 0, _prof.get_height() - 1)
	return _prof.get_pixel(x, y).r


func _unhandled_input(event: InputEvent) -> void:
	# la tecla del baston (accion "baston": Q o Z, ver Teclas)
	if _estado == "jugando" and event.is_action_pressed("baston") and not event.is_echo():
		peregrino.pulsar_baston()


func _process(delta: float) -> void:
	if _estado == "esperando":
		if _espera < 0.0:
			return
		_espera -= delta
		if _espera > 0.0:
			return
		_estado = "entrando"
		visible = true
		peregrino.process_mode = Node.PROCESS_MODE_INHERIT
	var escala := peregrino.escala
	match _estado:
		"entrando":
			# sale de la bruma andando solo; fuera de ella, el mando
			peregrino.quiere = "frente"
			if escala >= _escala_entrada:
				_estado = "jugando"
				al_mando.emit()
		"jugando":
			var abajo := Input.is_action_pressed("agacharse") or Input.is_key_pressed(KEY_DOWN)
			var arriba := _arriba()
			if _reten and not arriba:
				_reten = false
			if _reten:
				# la tecla con la que venia de la otra escena: sigue hacia la camara
				abajo = true
				arriba = false
			var q := "frente" if abajo and not arriba else ("espalda" if arriba and not abajo else "")
			if q == "frente" and escala >= _escala_hasta:
				# delante: se para solo y ya no anda mas
				q = ""
				_estado = "llegando"
			peregrino.quiere = q
			if peregrino.mirando == "espalda" and escala <= _escala_de(pies_corte):
				# entrando en la bruma del fondo: corte a la escena de antes (sigue
				# alejandose hasta que corta)
				_estado = "fuera"
				peregrino.quiere = "espalda"
				se_va.emit()
		"llegando":
			peregrino.quiere = ""
			if peregrino.estado == "reposo":
				_estado = "fuera"
				llego.emit()
	# lo que se le ve a traves de la bruma del fondo, y con ello sus pisadas
	_vista = smoothstep(_escala_bruma, _escala_entrada, escala)
	peregrino.pasos_db = pasos_db + linear_to_db(maxf(_vista, 0.001))
	if controlador:
		var hojas := controlador.get_node_or_null("Hojas")
		if hojas and hojas.has_method("z_del_suelo"):
			hojas.corte = hojas.z_del_suelo(_suelo(escala).y) if _vista > 0.0 else -1.0
	_luz()
	_sombra.queue_redraw()


## Los parametros de su luz: el ambiente de su sitio, la bruma de su distancia
## y el aire que tiene delante.
func _luz() -> void:
	if controlador and _fondo_mat == null:
		_fondo_mat = controlador.get_node("Fondo").material
		_mat.set_shader_parameter("aire", controlador.get_node("AireVista").get_texture())
	var raiz := get_parent() as Node2D
	_mat.set_shader_parameter("origen", raiz.global_position)
	_mat.set_shader_parameter("sobre", raiz.global_scale.x)
	var escala := peregrino.escala
	var pies := peregrino.pies
	var alto := escala * ALTO_ESCALA_1
	var amb := _ambiente(pies, alto)
	_mat.set_shader_parameter("px_por_texel", escala * raiz.global_scale.x)
	_mat.set_shader_parameter("pies_y", pies.y)
	_mat.set_shader_parameter("bruma_alto", alto * bruma_pies)
	_mat.set_shader_parameter("bruma_pies", bruma_pies_fuerza)
	_mat.set_shader_parameter("ambiente", amb)
	_mat.set_shader_parameter("exposicion", exposicion)
	var cerca := clampf(inverse_lerp(_escala_entrada, _escala_hasta, escala), 0.0, 1.0)
	var niebla := lerpf(niebla_lejos, niebla_cerca, cerca)
	_mat.set_shader_parameter("niebla", niebla)
	_mat.set_shader_parameter("aire_delante", lerpf(1.0, 0.35, cerca))
	_mat.set_shader_parameter("vista", _vista)
	# (el baston a la espalda y su correa usan copias de este material: el
	# componente les copia estos parametros; antes llevaban una luz aproximada
	# y al sacar el baston cambiaba de luz)
	if _fondo_mat:
		for n in ["rayos_fuerza", "luz_fuerza", "color_luz"]:
			var v = _fondo_mat.get_shader_parameter(n)
			if v != null:
				_mat.set_shader_parameter(n, v)


## La luz media de la foto donde esta (sin el): a los lados y en el suelo de
## alrededor, que es lo que le ilumina por delante.
func _ambiente(pies: Vector2, alto: float) -> Color:
	var suma := Color(0, 0, 0)
	var n := 0
	for i in 5:
		for j in 5:
			var p := pies + Vector2((i - 2) * alto * 0.3, -alto * (j / 4.0))
			var x := clampi(int(p.x / PANTALLA.x * _medio.get_width()), 0, _medio.get_width() - 1)
			var y := clampi(int(p.y / PANTALLA.y * _medio.get_height()), 0, _medio.get_height() - 1)
			suma += _medio.get_pixel(x, y)
			n += 1
	return Color(suma.r / n, suma.g / n, suma.b / n)


func _dibujar_sombra() -> void:
	var alto := peregrino.escala * ALTO_ESCALA_1
	var p := peregrino.pies
	var a := smoothstep(0.3, 1.0, _vista)
	var ancho := alto * 0.42
	_sombra.draw_texture_rect(_tex_sombra, Rect2(p - Vector2(ancho * 0.5, ancho * 0.07), Vector2(ancho, ancho * 0.14)),
		false, Color(0.02, 0.015, 0.01, sombra * a))
	# La luz le viene de detras: la sombra se alarga hacia la camara.
	if sombra_larga > 0.0:
		var largo := alto * 0.32
		var ancho_l := alto * 0.22
		_sombra.draw_texture_rect(_tex_sombra, Rect2(p + Vector2(-ancho_l * 0.5, -largo * 0.12), Vector2(ancho_l, largo)),
			false, Color(0.02, 0.015, 0.01, sombra_larga * a))
