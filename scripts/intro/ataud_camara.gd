extends Node2D
## Camara del ataud con profundidad (2026-10-22; probada aparte y pasada a
## sarcophagus_intro.tscn el 2026-10-23).
##
## Es el ultimo hijo de la escena del ataud y, sin tocar nada de ella, le da
## profundidad con trucos de camara en primera persona:
##  - la cabeza se mueve (respiracion al compas del audio de la respiracion,
##    un vaiven lento, se arrima un poco hacia la cucaracha y el golpe) y la
##    sala se desplaza por detras del cristal segun la profundidad de cada
##    punto (ataud_profundidad.gdshader); lo de la sala que va suelto (velas,
##    halos, manta, cerdo, pendulo, moscas, sangre) se mueve con su plano;
##  - golpe con "trauma": temblor suave en vez de saltos al azar, un pelo de
##    giro, empujon de zoom y aberracion de color; un instante congelado al
##    pegar (hit-stop), el cristal que se comba (onda en la sala), los bordes
##    que se oscurecen de dolor y una capa de sonido grave y metalica (el mismo
##    golpe, mas bajo, por un bus con filtro, eco corto y reverberacion);
##  - la mano a contraluz (ataud_mano.gdshader): oscura, borde de luz calida,
##    estela al lanzarse; se queda contra el cristal temblando y se retira
##    pesada; mas pequena al llegar al cristal que junto a la cara;
##  - las piezas de la sala (cerdo, pendulo, manta) con la bruma del fondo a su
##    profundidad, para que no parezcan pegadas;
##  - despertar: parpados que se abren y la vista que se enfoca;
##  - foco en el cristal cuando la cucaracha anda por el centro (la sala se
##    desenfoca un poco, lo lejano mas);
##  - motas de polvo en la luz de las velas y unas pocas, grandes y
##    desenfocadas, dentro del ataud; grano por encima de todo;
##  - mirar a los lados: las paredes de bronce de dentro del sarcofago
##    (ampliadas con Midjourney por el usuario, tools/ataud_profundidad/lados.py)
##    a izquierda y derecha de la ventana. Al despertar, agobio: una secuencia
##    distinta cada vez (_planear_agobio) con miradas a los lados, arriba y
##    abajo; los ojos saltan y se adelantan y la cabeza les sigue con inercia;
##    en cada pausa los ojos rebuscan; en un momento intenta incorporarse y se
##    da con la tapa; respiracion mas deprisa. Luego se mira un poco con
##    mover_izquierda/derecha y al soltar vuelve a la ventana. Al girar la
##    cabeza se ladea y baja un pelo; la pared, pegada a la cara, se ve borrosa
##    de un vistazo y solo se enfoca si uno se queda mirandola. Al girar, una lente (ataud_giro.gdshader)
##    curva la imagen como una proyeccion cilindrica y deja estela.
## La Camera2D es de la escena: aqui solo se le ponen offset, zoom y giro.
## El temblor del golpe de punch_effect.gd se sustituye por el de aqui (se
## procesa despues: process_priority).

const SALA := preload("res://assets/intro/ataud_sala.png")
const PROFUNDIDAD := preload("res://assets/intro/ataud_profundidad.png")
const CRISTAL := preload("res://assets/intro/ataud_cristal.png")
const SHADER := preload("res://scripts/intro/ataud_profundidad.gdshader")
const OJOS := preload("res://scripts/intro/ataud_ojos.gdshader")
const BORROSO := preload("res://scripts/intro/ataud_borroso.gdshader")
const DESENFOQUE := preload("res://scripts/intro/ataud_desenfoque.gdshader")
const LADO_IZQ := preload("res://assets/intro/ataud_lado_izq.png")
const LADO_DER := preload("res://assets/intro/ataud_lado_der.png")
const MANO := preload("res://scripts/intro/ataud_mano.gdshader")
const LENTE := preload("res://scripts/intro/ataud_giro.gdshader")
## Distancia focal de la vista, en px del fondo (unos 70 grados de horizontal):
## para pasar el giro en px a angulo.
const FOCAL := 2080.0
## Relleno transparente alrededor de la mano, para la estela.
const RELLENO_MANO := 160.0
const BUS_BRONCE := &"AtaudBronce"
## Lo que las paredes de los lados tapan del borde de la original (fundido).
const FUNDIDO_LADOS := 130.0
## Ojos: muelle muy rigido (las sacadas son casi instantaneas).
const OJO_RIGIDEZ := 32.0
## Lo que se arrima la vista (zoom) durante el agobio: margen para mirar arriba
## y abajo, y algo de opresion.
const ZOOM_AGOBIO := 0.045

## Base de cada llama, en px del fondo (para la calima).
const LLAMAS := [Vector2(642, 711), Vector2(767, 798), Vector2(878, 658), Vector2(986, 743),
		Vector2(1533, 815), Vector2(2315, 891), Vector2(2399, 815)]

@export_group("Cabeza")
## Zoom de base: margen para que al mover la cabeza no asome el borde.
@export var zoom_base := 1.02
## Cuanto sube y baja la cabeza al respirar, en px.
@export var respiracion_px := 7.0
## Cuanto se arrima al cristal al soltar el aire (zoom).
@export var respiracion_zoom := 0.004
## Vaiven lento de la cabeza, en px.
@export var vaiven_px := Vector2(6.0, 4.0)
## Cuanto se arrima la cabeza hacia la cucaracha, en px como mucho.
@export var mirar_px := 6.0

@export_group("Golpe")
@export var golpe_px := 26.0
@export var golpe_giro_grados := 0.7
@export var golpe_zoom := 0.022
## Lo que se congela todo al pegar, en segundos reales (0 = nada).
@export var congelar_golpe := 0.07
## Capa grave y metalica del sonido del golpe.
@export var bronce := true
## Fuerza de la onda del cristal al pegar.
@export var onda_cristal := 1.0

@export_group("Despertar")
@export var despertar := true
## Al abrir los ojos, la cabeza va a un lado y a otro antes de quedarse en la ventana.
@export var agobio := true
## Hasta donde gira en el agobio, en px.
@export var giro_agobio := 1150.0

@export_group("Mirar a los lados")
## Hasta donde se gira con las teclas, en px.
@export var giro_teclas := 900.0
## Rapidez del giro (muelle): mas, mas brusco.
@export var giro_rapidez := 4.5
## Mirando al frente, cada pocos segundos la cabeza se desvia un poco y vuelve
## (inquietud): hasta donde, en px.
@export var inquietud_px := Vector2(200.0, 24.0)

@export_group("Efectos")
## Cuanto se desenfoca la sala con la vista en el cristal (1 = nivel de mipmap
## 2,2 en la pared del fondo).
@export_range(0.0, 1.0) var foco_maximo := 0.7
@export var grano := 0.045
@export var polvo := true
## Fuerza de cada efecto del fondo (0 = apagado, y no cuesta).
@export var niebla := 1.0
@export var suciedad := 1.0
@export var calima := 1.0
@export var cadenas := 1.0

var _camara: Camera2D
var _fondo: Sprite2D
var _mat: ShaderMaterial
var _ojos: ShaderMaterial
var _vista_borrosa: ColorRect
var _capa_ojos: ColorRect
var _mapa: Image
var _ambiente: Node
var _golpe: Node
var _cucaracha: Node2D

## [nodo, tipo, base, profundidad]
var _seguidores: Array = []
## Piezas sueltas de la sala que se desenfocan con el fondo: [material, profundidad, escala].
var _desenfocables: Array = []

var _t := 0.0
var _ruido := FastNoiseLite.new()
var _trauma := 0.0
var _empujon := 0.0
var _temblor_antes := 0.0
var _foco := 0.0
var _mirar := Vector2.ZERO
var _apertura := 1.0
var _borroso := 0.0
var _fuerza_resp := 1.0
var _giro := 0.0
var _giro_vel := 0.0
## Cuando empieza el agobio (en _t); < 0 si no hay o se ha cortado.
var _agobio_desde := -1.0
## El agobio planeado: la cabeza [segundos, objetivo (px), rigidez,
## amortiguacion (< 1 se pasa y rebota)] y los ojos [segundos, objetivo (px)].
var _plan_cabeza: Array = []
var _plan_ojos: Array = []
var _agobio_dura := 0.0
## Cuando intenta incorporarse (segundos dentro del agobio; < 0 si no).
var _embestida_t := -1.0
var _embestida_hecha := false
var _rng := RandomNumberGenerator.new()
var _cabeza_y := 0.0
var _cabeza_y_vel := 0.0
var _ojo := Vector2.ZERO
var _ojo_vel := Vector2.ZERO
var _ojo_obj := Vector2.ZERO
var _proxima_sacada := 0.0
var _zoom_agobio := 0.0
## La desviacion de la cabeza en reposo (inquietud) y cuando cambia.
var _inquieto := Vector2.ZERO
var _proximo_inquieto := 6.0
## Lo que lleva la vista quieta en una pared (para enfocarla).
var _mirando_lado := 0.0
var _lados_mat: Array[ShaderMaterial] = []
var _mano: Sprite2D
var _mano_mat: ShaderMaterial
var _mano_antes := Vector2.ZERO
var _mano_offset := Vector2.ZERO
var _desde_golpe := 99.0
## El golpe que la mato: la mano se va deprisa y sin temblar.
var _golpe_final := false
var _donde_golpe := Vector2.ZERO
var _dolor := 0.0
var _sonido_bronce: AudioStreamPlayer
var _lente: ColorRect
var _lente_mat: ShaderMaterial
var _giro_antes := 0.0


func _ready() -> void:
	process_priority = 100
	var escena := get_parent()
	_camara = escena.find_child("Camera", true, false) as Camera2D
	_fondo = escena.find_child("BackgroundImage", true, false) as Sprite2D
	_ambiente = escena.find_child("AmbientPlayer", true, false)
	_golpe = escena.find_child("PunchEffect", true, false)
	_cucaracha = escena.find_child("Cockroach", true, false) as Node2D
	_mapa = PROFUNDIDAD.get_image()
	if _mapa.is_compressed():
		_mapa.decompress()

	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido.frequency = 1.0
	_ruido.seed = 7

	_preparar_fondo()
	_preparar_seguidores(escena)
	# En diferido: la escena aun esta metiendo a sus hijos.
	_preparar_polvo.call_deferred(escena)
	_preparar_lados.call_deferred(escena)
	_preparar_ojos()
	_preparar_mano()
	if bronce:
		_preparar_bronce()

	if _camara:
		_camara.ignore_rotation = false
		_camara.zoom = Vector2.ONE * zoom_base
	if despertar:
		_despertar()
	if agobio:
		_empezar_agobio(2.4 if despertar else 0.4)


func _preparar_fondo() -> void:
	if _fondo == null:
		return
	var ruido := NoiseTexture2D.new()
	ruido.width = 512
	ruido.height = 512
	ruido.seamless = true
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_octaves = 4
	n.seed = 11
	ruido.noise = n
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("sala", SALA)
	_mat.set_shader_parameter("profundidad", PROFUNDIDAD)
	_mat.set_shader_parameter("cristal", CRISTAL)
	_mat.set_shader_parameter("ruido", ruido)
	_mat.set_shader_parameter("llamas", PackedVector2Array(LLAMAS))
	_mat.set_shader_parameter("niebla", niebla)
	_mat.set_shader_parameter("suciedad", suciedad)
	_mat.set_shader_parameter("calima", calima)
	_mat.set_shader_parameter("cadenas", cadenas)
	_fondo.material = _mat
	# Los recortes iluminados de las velas (fondo_parches_luz.gd) pintan el
	# mismo fondo encima: con el mismo material, se desplazan igual.
	for h in _fondo.get_children():
		if h is CanvasItem:
			h.use_parent_material = true


## Profundidad de la sala en un punto del fondo (px), 0..1.
func profundidad_en(p: Vector2) -> float:
	var x := clampi(int(p.x * 0.5), 0, _mapa.get_width() - 1)
	var y := clampi(int(p.y * 0.5), 0, _mapa.get_height() - 1)
	return _mapa.get_pixel(x, y).r


func _seguir(n: Node, tipo: String, punto: Vector2, d := -1.0) -> void:
	if n == null:
		return
	if d < 0.0:
		d = profundidad_en(punto)
	var base: Vector2 = n.position if tipo in ["pos", "giro"] else Vector2.ZERO
	_seguidores.append([n, tipo, base, d])


func _preparar_seguidores(escena: Node) -> void:
	var manta := escena.find_child("Tunica", false, false) as Sprite2D
	if manta:
		var c := manta.global_position + manta.texture.get_size() * 0.5
		_seguir(manta, "pos", c)
		_desenfocable(manta, profundidad_en(c))
	for nombre in ["Pendulum", "HangingPig", "FliesTable", "FliesLeftCandles"]:
		var n := escena.find_child(nombre, false, false) as Node2D
		if n:
			_seguir(n, "pos", n.global_position)
			if nombre in ["Pendulum", "HangingPig"]:
				_desenfocable(n, profundidad_en(n.global_position))
	var sangre := escena.find_child("BloodEmitters", false, false)
	if sangre:
		for g in sangre.get_children():
			_seguir(g, "pos", g.global_position)
	# Velas y halos: sus scripts mueven la posicion (parpadeo); el plano va por
	# el offset, que no tocan.
	var luces := escena.find_child("Lights", false, false)
	if luces:
		for l in luces.get_children():
			if l is PointLight2D:
				_seguir(l, "luz", l.global_position)
	var halos := escena.find_child("Glows", false, false)
	if halos:
		for h in halos.get_children():
			if h is Sprite2D:
				_seguir(h, "halo", h.global_position)


## Las paredes de bronce a los lados de la ventana, detras de todo lo demas
## menos el fondo; su franja de fundido entra en el borde oscuro de este.
func _preparar_lados(escena: Node) -> void:
	if _fondo == null:
		return
	var i := _fondo.get_index() + 1
	for t in [[LADO_IZQ, -(LADO_IZQ.get_width() - FUNDIDO_LADOS)],
			[LADO_DER, _fondo.texture.get_width() - FUNDIDO_LADOS]]:
		var lado := Sprite2D.new()
		lado.texture = t[0]
		lado.centered = false
		lado.position = Vector2(t[1], 0.0)
		lado.light_mask = 0
		# Pegada a la cara: desenfocada (lo pone _process).
		var m := ShaderMaterial.new()
		m.shader = DESENFOQUE
		lado.material = m
		_lados_mat.append(m)
		escena.add_child(lado)
		escena.move_child(lado, i)
		i += 1
	# Lo que va pegado a la vista (la mano del golpe, el aviso de la tecla) gira
	# con ella.
	for nombre in ["PunchEffect", "InputTutor"]:
		var n := escena.find_child(nombre, false, false)
		if n:
			_seguir(n, "giro", Vector2.ZERO, 1.0)


## La cabeza a un lado, al otro y de vuelta a la ventana, con prisa
## (_planear_agobio). Empieza con los ojos aun entreabiertos y borrosos. Se
## corta en cuanto el jugador toca una tecla.
func _empezar_agobio(espera: float) -> void:
	_agobio_desde = _t + espera
	_planear_agobio()


## Una secuencia de agobio nueva, al azar: 3 o 4 miradas que casi siempre
## cambian de lado, cada una con su amplitud, altura, brusquedad y pausa; los
## ojos se adelantan a cada giro y rebuscan en cada pausa; tras la primera o
## la segunda mirada intenta incorporarse; al final se rinde y vuelve a la
## ventana, despacio.
func _planear_agobio() -> void:
	_rng.randomize()
	_plan_cabeza.clear()
	_plan_ojos.clear()
	_embestida_t = -1.0
	_embestida_hecha = false
	var t := 0.0
	var lado := -1.0 if _rng.randf() < 0.5 else 1.0
	var miradas := _rng.randi_range(3, 4)
	var embestida := _rng.randi_range(0, 1)
	for i in miradas:
		var y := _rng.randf_range(-40.0, 24.0)
		_plan_cabeza.append([t, Vector2(lado * _rng.randf_range(0.35, 0.95) * giro_agobio, y),
				_rng.randf_range(7.0, 11.0), _rng.randf_range(0.45, 0.7)])
		_plan_ojos.append([t, Vector2(lado * _rng.randf_range(60.0, 110.0), y * 0.4)])
		_plan_ojos.append([t + _rng.randf_range(0.12, 0.2), Vector2.ZERO])
		var pausa := _rng.randf_range(0.3, 0.65)
		var k := t + _rng.randf_range(0.25, 0.4)
		while k < t + pausa:
			_plan_ojos.append([k, Vector2(_rng.randf_range(-80.0, 80.0), _rng.randf_range(-22.0, 18.0))])
			k += _rng.randf_range(0.16, 0.34)
		t += pausa + _rng.randf_range(0.0, 0.15)
		if i == embestida:
			# Hacia la ventana y arriba, a incorporarse: se da con la tapa.
			_plan_cabeza.append([t, Vector2(lado * 0.1 * giro_agobio, -18.0), 6.0, 0.8])
			_plan_ojos.append([t, Vector2.ZERO])
			_embestida_t = t + 0.12
			t += 1.0
		if _rng.randf() < 0.78:
			lado = -lado
	_plan_cabeza.append([t, Vector2.ZERO, _rng.randf_range(3.0, 4.0), 0.85])
	_plan_ojos.append([t, Vector2.ZERO])
	_plan_ojos.append([t + 0.5, Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-10.0, 8.0))])
	_plan_ojos.append([t + 1.1, Vector2.ZERO])
	_agobio_dura = t + 1.6


## Si el agobio esta pendiente o en marcha.
func _agobio_vivo() -> bool:
	return _agobio_desde >= 0.0 and _t < _agobio_desde + _agobio_dura


## 0..1 lo que la cabeza va hacia delante al intentar incorporarse: acelera
## hasta la tapa, se queda un instante y cae.
func _embestida() -> float:
	if not _agobiado() or _embestida_t < 0.0:
		return 0.0
	var te := (_t - _agobio_desde) - _embestida_t
	if te < 0.0 or te > 1.1:
		return 0.0
	if te < 0.16:
		return pow(te / 0.16, 2.0)
	if te < 0.26:
		if not _embestida_hecha:
			_embestida_hecha = true
			_chocar_tapa()
		return 1.0
	return 1.0 - ease((te - 0.26) / 0.84, 0.4)


## La cabeza contra la tapa: temblor y dolor (sin sonido: al usuario no le
## gusto el golpe sordo).
func _chocar_tapa() -> void:
	_trauma = minf(_trauma + 0.6, 1.0)
	_dolor = maxf(_dolor, 0.8)


func _agobiado() -> bool:
	return _agobio_vivo() and _t >= _agobio_desde


## Le pone a la pieza (y a sus sprites hijos, sombra incluida) el desenfoque
## que acompana al del fondo.
func _desenfocable(n: CanvasItem, d: float) -> void:
	var m := ShaderMaterial.new()
	m.shader = DESENFOQUE
	m.set_shader_parameter("sala", SALA)
	m.set_shader_parameter("neblina", clampf((1.0 - d) * 0.5, 0.0, 0.45))
	n.material = m
	for h in n.get_children():
		if h is CanvasItem:
			h.use_parent_material = true
	_desenfocables.append([m, d, absf((n as Node2D).global_scale.x)])


func _particulas(textura: Texture2D, cantidad: int, vida: float) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.texture = textura
	p.amount = cantidad
	p.lifetime = vida
	p.local_coords = true
	p.light_mask = 0
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	return p


func _preparar_polvo(escena: Node) -> void:
	if not polvo:
		return
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var punto := GradientTexture2D.new()
	punto.gradient = g
	punto.fill = GradientTexture2D.FILL_RADIAL
	punto.fill_from = Vector2(0.5, 0.5)
	punto.fill_to = Vector2(0.5, 0.0)
	punto.width = 32
	punto.height = 32

	# Motas en la luz de las velas: pequenas, lentas, a la profundidad de cada grupo.
	var zonas := [[Vector2(820, 640), Vector2(330, 260)], [Vector2(2360, 760), Vector2(200, 230)],
			[Vector2(1533, 720), Vector2(150, 200)]]
	for z in zonas:
		var e := _particulas(punto, 26, 14.0)
		var pm := ParticleProcessMaterial.new()
		pm.particle_flag_disable_z = true
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(z[1].x, z[1].y, 0)
		pm.direction = Vector3(0.3, -1, 0)
		pm.spread = 70.0
		pm.initial_velocity_min = 2.0
		pm.initial_velocity_max = 7.0
		pm.gravity = Vector3.ZERO
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.5
		pm.turbulence_noise_scale = 6.0
		pm.turbulence_noise_speed_random = 0.3
		pm.turbulence_influence_min = 0.02
		pm.turbulence_influence_max = 0.06
		pm.scale_min = 0.07
		pm.scale_max = 0.16
		var a := Gradient.new()
		a.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
		a.colors = PackedColorArray([Color(1, 0.8, 0.55, 0), Color(1, 0.8, 0.55, 0.55),
				Color(1, 0.8, 0.55, 0.55), Color(1, 0.8, 0.55, 0)])
		var at := GradientTexture1D.new()
		at.gradient = a
		pm.color_ramp = at
		e.process_material = pm
		e.position = z[0]
		e.preprocess = 14.0
		escena.add_child(e)
		escena.move_child(e, escena.find_child("Glows", false, false).get_index())
		_seguir(e, "pos", z[0])

	# Dentro del ataud: pocas, grandes y desenfocadas, entre el ojo y el cristal.
	var cerca := _particulas(punto, 7, 18.0)
	var pc := ParticleProcessMaterial.new()
	pc.particle_flag_disable_z = true
	pc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pc.emission_box_extents = Vector3(1100, 600, 0)
	pc.direction = Vector3(1, -0.4, 0)
	pc.spread = 180.0
	pc.initial_velocity_min = 3.0
	pc.initial_velocity_max = 9.0
	pc.gravity = Vector3(0, 1.5, 0)
	pc.scale_min = 0.9
	pc.scale_max = 2.0
	var ac := Gradient.new()
	ac.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	ac.colors = PackedColorArray([Color(1, 0.85, 0.7, 0), Color(1, 0.85, 0.7, 0.07),
			Color(1, 0.85, 0.7, 0.07), Color(1, 0.85, 0.7, 0)])
	var act := GradientTexture1D.new()
	act.gradient = ac
	pc.color_ramp = act
	cerca.process_material = pc
	cerca.position = Vector2(1456, 816)
	cerca.preprocess = 18.0
	escena.add_child(cerca)
	_seguir(cerca, "pos", Vector2.ZERO, 1.35)


func _preparar_ojos() -> void:
	# La lente del giro va debajo de los ojos (que leen la pantalla ya curvada).
	var capa_lente := CanvasLayer.new()
	capa_lente.layer = 19
	add_child(capa_lente)
	_lente = ColorRect.new()
	_lente.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lente_mat = ShaderMaterial.new()
	_lente_mat.shader = LENTE
	_lente.material = _lente_mat
	_lente.visible = false
	capa_lente.add_child(_lente)
	var capa := CanvasLayer.new()
	capa.layer = 20
	add_child(capa)
	_vista_borrosa = ColorRect.new()
	_vista_borrosa.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vista_borrosa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mb := ShaderMaterial.new()
	mb.shader = BORROSO
	_vista_borrosa.material = mb
	_vista_borrosa.visible = false
	capa.add_child(_vista_borrosa)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ojos = ShaderMaterial.new()
	_ojos.shader = OJOS
	_ojos.set_shader_parameter("grano", grano)
	_ojos.set_shader_parameter("apertura", _apertura)
	r.material = _ojos
	capa.add_child(r)
	_capa_ojos = r


## La mano del golpe: material a contraluz, relleno para la estela, y su
## animacion (de punch_effect.tscn, copiada para no tocar la de la escena)
## con la mano mas pequena al llegar al cristal, sujeta contra el un pelo mas y
## retirandose pesada (empieza lenta). Dura lo mismo: se puede volver a pegar
## igual de seguido. El golpe que mata la retira deprisa (_al_golpear): lo que
## importa ahi es ver la cucaracha reventada, no la mano.
func _preparar_mano() -> void:
	if _golpe == null:
		return
	_mano = _golpe.get_node_or_null("Sprite2D") as Sprite2D
	if _mano == null:
		return
	var tam := _mano.texture.get_size()
	_mano.region_enabled = true
	_mano.region_rect = Rect2(-Vector2.ONE * RELLENO_MANO, tam + Vector2.ONE * RELLENO_MANO * 2.0)
	_mano.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_mano_offset = _mano.offset
	_mano_mat = ShaderMaterial.new()
	_mano_mat.shader = MANO
	_mano.material = _mano_mat
	_mano_antes = _mano.global_position
	var ap := _golpe.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null or not ap.has_animation("hit"):
		return
	var a := ap.get_animation("hit").duplicate(true) as Animation
	var tp := a.find_track(^"Sprite2D:position", Animation.TYPE_VALUE)
	if tp >= 0 and a.track_get_key_count(tp) == 5:
		a.track_set_key_time(tp, 3, 0.27)
		a.track_set_key_transition(tp, 3, 1.6)
	var te := a.find_track(^"Sprite2D:scale", Animation.TYPE_VALUE)
	if te >= 0 and a.track_get_key_count(te) == 4:
		for k in [[0, 0.95], [1, 0.86], [2, 0.84], [3, 0.95]]:
			a.track_set_key_value(te, k[0], Vector2.ONE * k[1])
	var lib := ap.get_animation_library("").duplicate() as AnimationLibrary
	lib.remove_animation("hit")
	lib.add_animation("hit", a)
	ap.remove_animation_library("")
	ap.add_animation_library("", lib)


## Capa grave del golpe: el mismo sonido, mas bajo, por un bus con filtro,
## un eco cortisimo que resuena (suena a metal hueco) y reverberacion corta.
func _preparar_bronce() -> void:
	var hit := _golpe.get_node_or_null("HitSound") as AudioStreamPlayer2D if _golpe else null
	if hit == null:
		return
	if AudioServer.get_bus_index(BUS_BRONCE) < 0:
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, BUS_BRONCE)
		AudioServer.set_bus_send(i, &"Master")
		var filtro := AudioEffectLowPassFilter.new()
		filtro.cutoff_hz = 1200.0
		AudioServer.add_bus_effect(i, filtro)
		var eco := AudioEffectDelay.new()
		eco.dry = 1.0
		eco.tap1_active = true
		eco.tap1_delay_ms = 9.0
		eco.tap1_level_db = -5.0
		eco.tap2_active = false
		eco.feedback_active = true
		eco.feedback_delay_ms = 9.0
		eco.feedback_level_db = -7.0
		eco.feedback_lowpass = 2500.0
		AudioServer.add_bus_effect(i, eco)
		var sala := AudioEffectReverb.new()
		sala.room_size = 0.3
		sala.damping = 0.6
		sala.wet = 0.3
		sala.dry = 0.9
		AudioServer.add_bus_effect(i, sala)
	_sonido_bronce = AudioStreamPlayer.new()
	_sonido_bronce.stream = hit.stream
	_sonido_bronce.pitch_scale = 0.55
	_sonido_bronce.volume_db = -3.0
	_sonido_bronce.bus = BUS_BRONCE
	add_child(_sonido_bronce)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	var i := AudioServer.get_bus_index(BUS_BRONCE)
	if i >= 0:
		AudioServer.remove_bus(i)


## Parpados cerrados, se entreabren, un parpadeo, y se abren del todo mientras
## la vista se enfoca.
func _despertar() -> void:
	_apertura = 0.0
	_borroso = 3.2
	# A trompicones y distinto cada vez: se entreabre, se le cierra, lo intenta
	# otra vez y se abre del todo.
	var r := RandomNumberGenerator.new()
	r.randomize()
	var tw := create_tween()
	tw.tween_interval(r.randf_range(0.5, 0.9))
	tw.tween_property(self, "_apertura", r.randf_range(0.18, 0.3), r.randf_range(0.45, 0.7)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_apertura", r.randf_range(0.03, 0.08), r.randf_range(0.12, 0.2)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_apertura", r.randf_range(0.38, 0.55), r.randf_range(0.35, 0.5)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_apertura", r.randf_range(0.25, 0.35), r.randf_range(0.15, 0.25)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_apertura", 1.0, r.randf_range(0.9, 1.3)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var tb := create_tween()
	tb.tween_interval(1.0)
	tb.tween_property(self, "_borroso", 0.0, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Un muelle amortiguado (rigidez w en rad/s, amortiguacion: 1 = sin pasarse)
## de pos hacia objetivo; devuelve [pos, vel]. En pasos de 1/240 s: con
## muelles rigidos (los ojos) y pocos fps (la P520 caliente, el grabador a 30)
## un solo paso se dispara.
func _muelle(pos: Vector2, vel: Vector2, objetivo: Vector2, w: float, amortigua: float, delta: float) -> Array:
	var pasos := maxi(1, ceili(delta * 240.0))
	var dt := delta / pasos
	for i in pasos:
		vel += (w * w * (objetivo - pos) - 2.0 * amortigua * w * vel) * dt
		pos += vel * dt
	return [pos, vel]


## 0..1 por donde va la respiracion: 0 justo al empezar a soltar el aire (cada
## vaho del cristal de ambient_controller.gd), con el audio de la respiracion.
func _fase_respiracion() -> float:
	if _ambiente == null or not ("breathing_node" in _ambiente):
		return fmod(_t / 2.1, 1.0)
	var reproductor := _ambiente.get("breathing_node") as AudioStreamPlayer
	var marcas: Array = _ambiente.get("breath_timestamps")
	if reproductor == null or reproductor.stream == null or marcas.is_empty():
		return fmod(_t / 2.1, 1.0)
	var largo := reproductor.stream.get_length()
	var pos := reproductor.get_playback_position()
	var antes: float = marcas[-1] - largo
	var despues: float = marcas[0]
	for i in marcas.size():
		if pos >= marcas[i]:
			antes = marcas[i]
			despues = marcas[i + 1] if i + 1 < marcas.size() else marcas[0] + largo
	return clampf((pos - antes) / maxf(despues - antes, 0.1), 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta

	# Respiracion: arriba al acabar de coger aire, abajo y un pelo hacia el
	# cristal al soltarlo. Cuando se apaga la respiracion (el apagon), se apaga.
	if _ambiente and _ambiente.get("is_slowing"):
		_fuerza_resp = move_toward(_fuerza_resp, 0.0, delta * 0.25)
	var h := cos(_fase_respiracion() * TAU)
	var vista := Vector2(0.0, -h * respiracion_px * _fuerza_resp)

	# Vaiven lento.
	vista += Vector2(_ruido.get_noise_2d(_t * 0.11, 0.0) * vaiven_px.x,
			_ruido.get_noise_2d(0.0, _t * 0.09 + 40.0) * vaiven_px.y) * 1.6

	# Mirar a los lados: con las teclas, un muelle lleva la cabeza hacia donde
	# se pide y, al soltar, de vuelta a la ventana. Tocar una tecla corta el
	# agobio del principio. Con la cucaracha muerta, vuelve a la ventana.
	var eje := Input.get_axis("mover_izquierda", "mover_derecha")
	if _agobio_vivo() and (absf(eje) > 0.1 or Input.is_action_just_pressed("ui_up")):
		_agobio_desde = -1.0
	var viva: bool = _cucaracha != null and is_instance_valid(_cucaracha) and not _cucaracha.get("is_dead")
	var objetivo := Vector2.ZERO
	var w := giro_rapidez
	var amortigua := 1.0
	if _agobiado():
		var tt := _t - _agobio_desde
		var tramo: Array = _plan_cabeza[0]
		for m in _plan_cabeza:
			if tt >= m[0]:
				tramo = m
		objetivo = tramo[1]
		w = tramo[2]
		amortigua = tramo[3]
		for o in _plan_ojos:
			if tt >= o[0]:
				_ojo_obj = o[1]
	else:
		# Mirando al frente la cabeza no esta quieta: cada pocos segundos se
		# desvia un poco (a un lado, arriba, abajo) y casi siempre vuelve.
		if _t >= _proximo_inquieto:
			_proximo_inquieto = _t + _rng.randf_range(1.6, 4.5)
			if _inquieto != Vector2.ZERO and _rng.randf() < 0.6:
				_inquieto = Vector2.ZERO
			else:
				_inquieto = Vector2(_rng.randf_range(-1.0, 1.0) * inquietud_px.x, _rng.randf_range(-1.0, 1.0) * inquietud_px.y)
		if absf(eje) > 0.1:
			objetivo = Vector2(eje * giro_teclas, 0.0)
			w = giro_rapidez
		else:
			objetivo = _inquieto if viva else Vector2.ZERO
			w = giro_rapidez * 0.6
			amortigua = 0.85
		# En reposo los ojos tambien saltan de vez en cuando.
		if _t >= _proxima_sacada:
			_proxima_sacada = _t + _rng.randf_range(0.9, 3.0)
			_ojo_obj = Vector2.ZERO if _rng.randf() < 0.35 else Vector2(_rng.randf_range(-26.0, 26.0), _rng.randf_range(-10.0, 10.0))
	var cabeza := _muelle(Vector2(_giro, _cabeza_y), Vector2(_giro_vel, _cabeza_y_vel), objetivo, w, amortigua, delta)
	_giro = cabeza[0].x
	_cabeza_y = cabeza[0].y
	_giro_vel = cabeza[1].x
	_cabeza_y_vel = cabeza[1].y
	var ojo := _muelle(_ojo, _ojo_vel, _ojo_obj, OJO_RIGIDEZ, 0.9, delta)
	_ojo = ojo[0]
	_ojo_vel = ojo[1]
	# Los ojos van por delante del cuello: al girar se desplazan, y el marco (a
	# un palmo) se mueve mucho mas que la sala. La cabeza baja un pelo cuanto
	# mas deprisa gira.
	var deprisa := clampf(_giro_vel / 1500.0, -1.0, 1.0)
	vista.x += _giro * 0.045 + _ojo.x * 0.1
	vista.y += _cabeza_y * 0.3 + absf(deprisa) * 9.0
	# Intento de incorporarse: hacia delante (zoom) y arriba.
	var emb := _embestida()
	vista.y -= emb * 18.0
	_zoom_agobio = move_toward(_zoom_agobio, ZOOM_AGOBIO if _agobio_vivo() else 0.0, delta * 0.05)
	# En el agobio, mas vaiven (nervios) y la respiracion mas deprisa.
	if _agobiado():
		vista += Vector2(_ruido.get_noise_2d(_t * 0.9, 500.0), _ruido.get_noise_2d(600.0, _t * 0.8)) * 6.0
	if _ambiente and not _ambiente.get("is_slowing"):
		var resp := _ambiente.get("breathing_node") as AudioStreamPlayer
		if resp:
			resp.pitch_scale = move_toward(resp.pitch_scale, 1.08 if _agobio_vivo() else 1.0, delta * 0.15)
	# La pared, pegada a la cara, solo se enfoca si la vista se queda en ella.
	if absf(_giro) > 450.0 and absf(_giro_vel) < 250.0:
		_mirando_lado += delta
	else:
		_mirando_lado = maxf(_mirando_lado - delta * 3.0, 0.0)
	var radio_lado := lerpf(7.0, 1.5, smoothstep(0.35, 1.3, _mirando_lado))
	for m in _lados_mat:
		m.set_shader_parameter("radio", radio_lado)

	# Arrimarse a la cucaracha cuando anda por la ventana, y foco en el cristal
	# si esta cerca del centro.
	var objetivo_mirar := Vector2.ZERO
	var objetivo_foco := 0.0
	if viva:
		var rel := _cucaracha.global_position - Vector2(1456.0 + _giro, 816)
		if absf(rel.x) < 1300.0 and absf(rel.y) < 700.0:
			objetivo_mirar = (rel / Vector2(1300, 700)).limit_length(1.0) * mirar_px
			objetivo_foco = (1.0 - smoothstep(420.0, 800.0, rel.length())) * foco_maximo
	_mirar = _mirar.lerp(objetivo_mirar, 1.0 - exp(-delta * 0.8))
	_foco = move_toward(_foco, objetivo_foco, delta * 0.45)
	vista += _mirar

	# Golpe: punch_effect.gd sube su shake_intensity al impactar; el temblor lo
	# pone esto.
	if _golpe and "shake_intensity" in _golpe:
		var s: float = _golpe.get("shake_intensity")
		if s > _temblor_antes + 5.0:
			_trauma = minf(_trauma + 0.75, 1.0)
			_empujon = 1.0
			_al_golpear()
		_temblor_antes = s
	_trauma = maxf(_trauma - delta * 1.5, 0.0)
	_desde_golpe += delta
	_dolor *= exp(-delta * 4.0)
	_empujon *= exp(-delta * 7.0)
	var sacudida := _trauma * _trauma
	var temblor := Vector2(_ruido.get_noise_2d(_t * 28.0, 100.0), _ruido.get_noise_2d(200.0, _t * 28.0))
	vista += temblor * golpe_px * sacudida

	var zoom := zoom_base * (1.0 + respiracion_zoom * (1.0 - h) * 0.5 * _fuerza_resp + golpe_zoom * _empujon
			+ _zoom_agobio + emb * 0.1)
	if _camara:
		_camara.offset = vista + Vector2(_giro, _cabeza_y) + _ojo
		_camara.zoom = Vector2.ONE * zoom
		# Giro del golpe y, al girar la cabeza, se ladea hacia donde gira.
		_camara.rotation = deg_to_rad(_ruido.get_noise_2d(_t * 22.0, 300.0) * golpe_giro_grados * sacudida
				+ deprisa * 1.3 + _ruido.get_noise_2d(_t * 0.07, 900.0) * 0.6)

	for s in _seguidores:
		var n = s[0]
		if not is_instance_valid(n):
			continue
		var mover: Vector2 = vista * (1.0 - float(s[3]))
		match s[1]:
			"pos":
				n.position = s[2] + mover
			"giro":
				n.position = s[2] + Vector2(_giro, 0.0)
			"luz":
				n.offset = mover
			"halo":
				n.offset = mover / n.scale

	_actualizar_mano(delta)
	_actualizar_lente()

	if _mat:
		_mat.set_shader_parameter("golpe", Vector4(_donde_golpe.x, _donde_golpe.y, _desde_golpe, onda_cristal))
		_mat.set_shader_parameter("vista", vista)
		_mat.set_shader_parameter("foco_cristal", _foco)
		_mat.set_shader_parameter("aberracion", sacudida * 1.5)
	# Lo mismo que el fondo (nivel de mipmap foco * (1 - d) * 2,2) en px.
	for dsf in _desenfocables:
		var nivel: float = _foco * (1.0 - float(dsf[1])) * 2.2
		(dsf[0] as ShaderMaterial).set_shader_parameter("radio", (pow(2.0, nivel) - 1.0) * 1.6 / float(dsf[2]))
	if _ojos:
		_ojos.set_shader_parameter("apertura", _apertura)
		_ojos.set_shader_parameter("dolor", _dolor)
		_capa_ojos.visible = grano > 0.0 or _apertura < 1.0
	if _vista_borrosa:
		_vista_borrosa.visible = _borroso > 0.02
		if _vista_borrosa.visible:
			(_vista_borrosa.material as ShaderMaterial).set_shader_parameter("nivel", _borroso)


## El instante del golpe: congelado, onda del cristal, dolor y sonido grave.
func _al_golpear() -> void:
	_desde_golpe = 0.0
	_dolor = 1.0
	# punch_effect.gd ya ha llamado a die() si le ha dado.
	if _cucaracha and is_instance_valid(_cucaracha) and _cucaracha.get("is_dead") and not _golpe_final:
		_golpe_final = true
		var ap := _golpe.get_node_or_null("AnimationPlayer") as AnimationPlayer if _golpe else null
		if ap:
			ap.speed_scale = 1.8
	if _golpe and _mano:
		_donde_golpe = _mano.global_position + (_golpe.get("impact_offset") as Vector2)
	if _sonido_bronce:
		_sonido_bronce.play()
	if congelar_golpe > 0.0:
		Engine.time_scale = 0.06
		get_tree().create_timer(congelar_golpe, true, false, true).timeout.connect(
				func(): Engine.time_scale = 1.0)


## Estela de la mano segun lo que se ha movido, y temblor contra el cristal.
func _actualizar_mano(delta: float) -> void:
	if _mano == null or not is_instance_valid(_mano):
		return
	var ahora := _mano.global_position
	var escala := maxf(absf(_mano.global_scale.x), 0.01)
	var mov := (ahora - _mano_antes) / escala
	_mano_antes = ahora
	# Si el fotograma va congelado (hit-stop), sin estela.
	if delta < 0.002:
		mov = Vector2.ZERO
	_mano_mat.set_shader_parameter("estela", (mov * 0.6).limit_length(130.0))
	var tiembla := 0.0
	if _desde_golpe < 0.5 and not _golpe_final:
		tiembla = 5.0 * (1.0 - _desde_golpe / 0.5)
	_mano.offset = _mano_offset + Vector2(_ruido.get_noise_2d(_t * 40.0, 700.0),
			_ruido.get_noise_2d(800.0, _t * 40.0)) * tiembla / escala


## La lente del giro: solo mientras la cabeza no esta en la ventana.
func _actualizar_lente() -> void:
	if _lente == null:
		return
	# Solo en giros grandes, y empezando desde cero para que no de un salto al
	# encenderse (la inquietud en reposo no la enciende: cuesta una copia).
	var s0 := sin(atan(_giro / FOCAL))
	var s := signf(s0) * maxf(absf(s0) - 0.12, 0.0) / 0.88
	var paso := (_giro - _giro_antes) / 2912.0 * zoom_base * 0.45
	_giro_antes = _giro
	_lente.visible = absf(s) > 0.0 or absf(paso) > 0.004
	if _lente.visible:
		_lente_mat.set_shader_parameter("giro", s)
		# Solo en los giros bruscos: los lentos y los rebotes, nitidos.
		var brusco := signf(paso) * maxf(absf(paso) - 0.004, 0.0) * 1.6
		_lente_mat.set_shader_parameter("estela", clampf(brusco, -0.016, 0.016))
