extends Node2D
## Camino del bosque: una imagen de Midjourney (bosque otonal en niebla, un
## camino de hojas que lleva a una luz) que esta viva.
##
## La imagen no se recorta: camino_fondo.gdshader desplaza las ramas finas de la
## copa donde dice la mascara (raw/master_builder/camino_bosque/mascaras.py) y le
## pone encima el aire que pinta camino_aire.gdshader a 1/4 de resolucion en la
## SubViewport AireVista. Troncos, camino y suelo no se mueven: por el camino
## andara el peregrino. Este script lleva lo que tiene que ir a una.
##
## VIENTO. Brisa de fondo que va y viene y, cada pocos segundos, una racha que
## entra por la izquierda y cruza: la copa se inclina franja a franja (cinco
## muelles amortiguados a lo ancho: se inclinan, rebotan al pasar y vuelven).
## Todo lo lee en el mismo sitio (viento_en), asi que copa, niebla, rayos,
## hojas, polvo y el viento que suena van juntos.
##
## LUZ. El resplandor del fondo respira despacio, como el sol tras la bruma, y
## los haces giran un pelin cuando la copa se inclina. Con el viento, la luz
## que pasa entre las ramas tiembla. Cada poco el sol se abre paso (CLARO): el
## resplandor y los haces crecen unos segundos y vuelven.
##
## SONIDO. Musica de fondo en bucle (assets/audio/musica_camino_bosque.ogg, de
## raw/master_builder/audio/camino_bosque/construye.py): entra con la imagen y,
## cuando el sol se abre paso, sube un pelin. La lleva MusicAmbience: es la
## misma que suena en la hojarasca desde que se coge el baculo y sigue por el
## corte sin empezar de nuevo (2026-10-16); aqui solo se lleva a musica_db. El
## viento de siempre (WindAmbience) aqui se apaga (bosque cerrado; el usuario
## queria descansar de el): es lo que cambia con el corte. Las rachas siguen
## viendose en la copa.
##
## SACUDIDA. sacudir() da un golpe de camara que se amortigua (el emu al pasar
## rozando): mueve camara, asi que tiembla todo con su paralaje.
##
## EL PEREGRINO (peregrino_camino.gd), de frente y LO LLEVA EL JUGADOR. Entra
## desde la bruma del fondo del camino: la primera vez, cuando se va el emu (el
## emu sale solo esa vez: Partida "camino_emu"); las demas, enseguida. Al
## llegar delante se para y la escena funde a negro (aun no hay la escena de la
## camara de detras). Si se aleja hacia la bruma, CORTE a la escena de antes
## (escena_anterior), sin negro, como un cambio de camara (el usuario: "para
## darle continuidad al mundo"; se carga desde que tiene el mando), diciendole
## como va (PeregrinoEstado, con viene_de "camino_bosque": por ahi sabe que
## vuelve por el camino con todo ya hecho, sin la caida). Es el
## componente del juego (PeregrinoFrontal); como llega (baston, magia) lo dice
## la escena de antes. Usa z de -3 a 5: lo que va delante de el (emu, hojas,
## polvo) va en z 6 y el fondo en -10.
##
## CAMARA (2.5D). Respira despacio: deriva y se acerca un pelin, con periodos
## que no se repiten, y cada punto se mueve segun su distancia
## (profundidad.png): el fondo con paralaje y oclusion en camino_fondo.gdshader;
## el emu, las hojas y el polvo con paralaje(p, w). La escena va
## ampliada un pelin (sobre) para que el movimiento nunca deje ver el borde de
## la imagen. Cada cosa se mueve segun su distancia (la
## profundidad de la mascara, la de cada hoja y mota): paralaje. Lo lee todo de
## camara/acercamiento.

const PANTALLA := Vector2(2912, 1632)
const FRANJAS := 17
const MUELLES := 5
const VIENTO_MASCARA := preload("res://assets/world/camino_bosque/viento.png")
const RUIDO := preload("res://assets/world/camino_bosque/ruido.png")
const Imagenes := preload("res://scripts/game/imagenes_cache.gd")
## Con preload (no por su class_name): asi no dependen de la cache de clases.
const Estado := preload("res://scripts/characters/peregrino_estado.gd")
const PartidaHechos := preload("res://scripts/game/partida.gd")

## Entrada desde negro (s); 0 = sin fundido.
@export var fundido_entrada := 3.0

@export_group("Peregrino")
## La escena de la que viene por el camino y a la que vuelve si se aleja.
@export_file("*.tscn") var escena_anterior := "res://scenes/game/caida_hojarasca.tscn"
## Segundos tras irse el emu (o tras entrar, sin emu) hasta que asoma.
@export var tras_emu := 0.3
@export var sin_emu_espera := 1.2
## Lo que tarda el fundido a negro al llegar delante.
@export var negro_s := 1.6
## Lo que sigue andando por la bruma antes del corte a la escena de antes (antes
## se iba la musica en ese rato; ahora sigue, ver SONIDO).
@export var corte_musica_s := 0.6

@export_group("Sonido")
## Nivel de la musica (dB) y lo que sube con el claro de sol a tope.
@export var musica_db := -20.0
@export var musica_claro_db := 1.5
## Segundos que tarda la musica en entrar (o, si ya sonaba en la hojarasca, en
## llegar a musica_db: alli va mas alta, con el viento).
@export var musica_entrada := 6.0
## Nivel del viento en esta escena: apagado (el ogg es muy bajo; en la
## hojarasca va a +9). Se funde a este nivel al entrar: en musica_entrada s
## desde negro, en viento_corte s tras un corte de camara (que se note el sitio).
@export var viento_db := -80.0
@export var viento_corte := 1.5
## Golpe de camara: px en lo mas cercano y lo que tarda en amortiguarse (s).
@export var sacudida_px := 10.0
@export var sacudida_s := 0.7

@export_group("Camara")
## Lo que deriva lo mas cercano (px, en horizontal; en vertical, algo mas de la
## mitad); 0 = camara quieta. Con 22 px y ciclos de 14 a 41 s (lo de antes) el
## paralaje no se notaba (el usuario, 2026-10-15): ahora ±55 px y ciclos de 10
## a 20 s; probado en los extremos (±60): los cantos de los troncos aguantan.
@export var camara_px := 55.0
## Cuanto mas rapida va la deriva (1 = los periodos de _mover_camara).
@export var camara_ritmo := 1.0
## Acercamiento maximo (0,005 = 0,5 %): lo cercano crece mas que el fondo.
@export var camara_acercamiento := 0.03
## TENSION (la pone el emu mientras te mira, 0..1): la camara se le acerca
## despacio (acercamiento de mas, centrado en el: el emu se queda quieto en
## pantalla y lo demas se abre a su alrededor) y la deriva se calma; al
## embestir se suelta de golpe.
@export var tension_acercamiento := 0.035
@export var tension_hacia := Vector2(930.0, 1150.0)
## Ampliacion de toda la escena: margen para que el paralaje no deje ver el
## borde de la imagen (con 55 px y 3 %, 98 px en el borde; mas el golpe del
## emu, hasta 16: 1,08).
@export var sobre := 1.08

@export_group("Luz")
## Segundos entre un claro y el siguiente, y su fuerza 0..1.
@export var claro_cada := Vector2(15.0, 35.0)
@export var claro_fuerza := Vector2(0.6, 1.0)

@export_group("Viento")
## Brisa de fondo 0..1 (de media; va y viene).
@export var brisa_media := 0.45
## Segundos entre el final de una racha y el principio de la siguiente.
@export var racha_cada := Vector2(5.0, 12.0)
## Fuerza de una racha (min, max) 0..1.
@export var racha_fuerza := Vector2(0.4, 1.0)
## A que velocidad cruza la racha la pantalla (px/s).
@export var racha_px_s := 1100.0
## Punta de la copa con la racha a tope (px; x a favor del viento).
@export var inclinacion_copa := Vector2(13.0, 2.5)
## Frecuencia propia (Hz) y amortiguamiento de los muelles de la copa.
@export var copa_hz := 0.35
@export var copa_amortiguamiento := 0.25
## Cuanto giran los haces (rad) por px de inclinacion de la copa.
@export var giro_rayos := 0.0009
## dB de mas en el viento que suena con la racha a tope.
@export var racha_db := 4.0

@onready var _fondo: Sprite2D = $Fondo
@onready var _aire_vista: SubViewport = $AireVista
@onready var _aire: ColorRect = $AireVista/Aire

var brisa := 0.45
## Desplazamiento de la camara (px en lo mas cercano) y acercamiento: lo leen
## los shaders, las hojas y las motas.
var camara := Vector2.ZERO
var acercamiento := 0.0
## Tension 0..1 (la pone el emu: ver tension_acercamiento).
var tension := 0.0
## Claro 0..1 (el sol se abre paso) y respiracion de la luz -1..1: los leen el
## polvo y las hojas para encenderse con la luz.
var claro := 0.0
var luz := 0.0

var _mf: ShaderMaterial
var _ma: ShaderMaterial
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _ruido := FastNoiseLite.new()

var _historia: Array[Vector2] = []   # (tiempo, racha) en la entrada, para el retraso
var _viento_x := PackedFloat32Array()
var _racha := 0.0
var _r_inicio := -100.0
var _r_sube := 1.5
var _r_dura := 1.0
var _r_baja := 3.0
var _r_fuerza := 0.0
var _hasta_racha := 3.0
var _copa := PackedVector2Array()
var _copa_v := PackedVector2Array()
var _viento_suelo := Vector2.ZERO
var _viento_fondo := Vector2.ZERO
var _viento_medio := Vector2.ZERO
var _viento_cerca := Vector2.ZERO
var _mascara_viento: Image
var _ruido_img: Image
var _param := {}
var _cargando_anterior := false
var _sacudida := 0.0
var _c_inicio := -100.0
var _c_sube := 4.0
var _c_dura := 4.0
var _c_baja := 6.0
var _c_fuerza := 0.0
var _hasta_claro := 8.0

func _ready() -> void:
	# Continuando donde se dejo: el camino empieza por su principio (es corto);
	# se gasta para que no lo recoja la hojarasca si se vuelve a ella.
	PartidaHechos.reanudar_estado(get_tree())
	_rng.randomize()
	_ruido.seed = _rng.randi()
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido.frequency = 1.0
	_mf = _fondo.material
	_ma = _aire.material
	scale = Vector2(sobre, sobre)
	position = -(sobre - 1.0) * PANTALLA * 0.5
	_mf.set_shader_parameter("niebla", _aire_vista.get_texture())
	_mascara_viento = Imagenes.de(VIENTO_MASCARA)
	_ruido_img = Imagenes.de(RUIDO)
	var sh := _mf.shader.get_rid()
	for n in ["rama_px", "rama_racha_px", "ramita_px", "ramita_racha_px", "rama_vel", "ramita_vel", "foco"]:
		var v = _mf.get_shader_parameter(n)
		_param[n] = v if v != null else RenderingServer.shader_get_parameter_default(sh, n)
	_viento_x.resize(FRANJAS)
	_copa.resize(MUELLES)
	_copa_v.resize(MUELLES)
	_hasta_racha = _rng.randf_range(1.5, 4.0)
	_hasta_claro = _rng.randf_range(6.0, 12.0)
	for n in ["Hojas", "HojasCopa", "Motas", "Emu", "Peregrino"]:
		var nodo := get_node_or_null(n)
		if nodo:
			nodo.set("controlador", self)
	# viniendo por el camino de otra escena: corte de camara, sin negro (el
	# usuario: corte "para darle continuidad al mundo")
	var corte := str(Estado.leer(get_tree()).get("viene_de", "")) != ""
	if corte:
		fundido_entrada = 0.0
	# Musica en bucle (desde silencio o, tras el corte, la que ya sonaba); y el
	# viento a su nivel de escena.
	MusicAmbience.sonar_camino(musica_db, musica_entrada, 0.0 if MusicAmbience.camino_sonando() else 0.4)
	var viento := get_node_or_null("/root/WindAmbience")
	if viento:
		viento.fade_to(viento_db, viento_corte if corte else musica_entrada)
	if fundido_entrada > 0.0:
		var negro := ColorRect.new()
		negro.color = Color.BLACK
		negro.size = PANTALLA
		negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		negro.z_index = 100     # por encima de todo (el emu, las hojas y el polvo van en 6)
		add_child(negro)
		var tw := create_tween()
		tw.tween_interval(0.4)
		tw.tween_property(negro, "modulate:a", 0.0, fundido_entrada).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(negro.queue_free)
	_montar_peregrino()

## El emu solo la primera vez; el peregrino entra tras el o enseguida.
func _montar_peregrino() -> void:
	var peregrino := get_node_or_null("Peregrino")
	if peregrino == null:
		return
	peregrino.llego.connect(_al_llegar)
	peregrino.se_va.connect(_volver)
	peregrino.al_mando.connect(_cargar_anterior)
	var emu := get_node_or_null("Emu")
	var forzar_emu := "emu" in OS.get_cmdline_user_args()
	if emu and (forzar_emu or not PartidaHechos.ya(get_tree(), "camino_emu")):
		emu.se_fue.connect(func():
			PartidaHechos.marcar(get_tree(), "camino_emu")
			peregrino.entrar(tras_emu))
	else:
		if emu:
			emu.saltar()
		peregrino.entrar(sin_emu_espera)

## Un negro por encima de todo que entra en negro_s (la musica se va con el).
func _a_negro() -> Tween:
	var negro := ColorRect.new()
	negro.color = Color.BLACK
	negro.size = PANTALLA * 1.2
	negro.position = -PANTALLA * 0.1
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	negro.z_index = 100
	negro.modulate.a = 0.0
	add_child(negro)
	var tw := create_tween().set_parallel()
	tw.tween_property(negro, "modulate:a", 1.0, negro_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	MusicAmbience.apagar_camino(negro_s)
	return tw

## Delante: a negro y ahi se queda (aun no hay la escena de la camara de detras).
func _al_llegar() -> void:
	_a_negro()

## En segundo plano, para que el corte a la escena de antes sea al instante.
func _cargar_anterior() -> void:
	if escena_anterior != "" and not _cargando_anterior:
		_cargando_anterior = true
		ResourceLoader.load_threaded_request(escena_anterior)

## Se aleja hacia la bruma: corte a la escena de antes (la musica sigue). Si la
## carga aun no ha acabado, sigue andando mientras; si tarda, a negro.
func _volver() -> void:
	if escena_anterior == "":
		return
	_cargar_anterior()
	var t := 0.0
	var negro := false
	while t < corte_musica_s or ResourceLoader.load_threaded_get_status(escena_anterior) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		t += get_process_delta_time()
		if t > 2.0 and not negro:
			negro = true
			_a_negro()
	var p: PeregrinoFrontal = $Peregrino.peregrino
	Estado.dejar(get_tree(), p.lleva_baston, p.magia, p.magia_recarga, "camino_bosque")
	var ps := ResourceLoader.load_threaded_get(escena_anterior) as PackedScene
	if ps:
		get_tree().change_scene_to_packed(ps)
	else:
		get_tree().change_scene_to_file(escena_anterior)

func _exit_tree() -> void:
	var sonido := get_node_or_null("/root/WindAmbience")
	if sonido:
		sonido.gust_db = 0.0

## La racha 0..1 tal como le llega a la x dada (entra por la izquierda). Se lee
## de una tabla por franjas que se rehace cada fotograma: hojas y polvo lo piden
## cientos de veces y buscar en la historia cada vez salia caro.
func viento_en(x: float) -> float:
	var f := clampf(x / PANTALLA.x, 0.0, 1.0) * (FRANJAS - 1)
	var i := mini(int(f), FRANJAS - 2)
	return lerpf(_viento_x[i], _viento_x[i + 1], f - i)

func _process(delta: float) -> void:
	_t += delta
	_avanzar_viento(delta)
	_avanzar_claro(delta)
	_sacudida = maxf(_sacudida - delta / sacudida_s, 0.0)
	_subir_parametros()

func _avanzar_viento(dt: float) -> void:
	brisa = brisa_media * (0.8 + 0.45 * _ruido.get_noise_1d(_t * 0.06 + 11.0))
	_hasta_racha -= dt
	var fin := _r_inicio + _r_sube + _r_dura + _r_baja
	if _hasta_racha <= 0.0 and _t > fin:
		_r_inicio = _t
		_r_sube = _rng.randf_range(1.0, 2.2)
		_r_dura = _rng.randf_range(0.4, 2.5)
		_r_baja = _rng.randf_range(2.5, 4.5)
		_r_fuerza = _rng.randf_range(racha_fuerza.x, racha_fuerza.y)
		_hasta_racha = _r_sube + _r_dura + _r_baja + _rng.randf_range(racha_cada.x, racha_cada.y)
	var e := _t - _r_inicio
	var env := 0.0
	if e < _r_sube:
		env = smoothstep(0.0, _r_sube, e)
	elif e < _r_sube + _r_dura:
		env = 1.0
	else:
		env = 1.0 - smoothstep(_r_sube + _r_dura, _r_sube + _r_dura + _r_baja, e)
	# Una racha no es lisa: dentro lleva remolinos.
	_racha = _r_fuerza * env * (0.82 + 0.18 * _ruido.get_noise_1d(_t * 1.7 + 50.0))
	_historia.append(Vector2(_t, _racha))
	while _historia.size() > 2 and _historia[1].x < _t - 4.0:
		_historia.pop_front()
	for i in FRANJAS:
		_viento_x[i] = _racha_hace(PANTALLA.x * i / (FRANJAS - 1) / racha_px_s)

	# Copa: un muelle por franja, cada uno con la racha que le llega. Algo de
	# brisa la tiene siempre un pelin inclinada y viva.
	for i in MUELLES:
		var x := PANTALLA.x * i / (MUELLES - 1)
		var obj := inclinacion_copa * viento_en(x) + Vector2(0.7 * brisa, 0.0)
		var m := _muelle(_copa[i], _copa_v[i], obj, copa_hz * (0.9 + 0.05 * i), copa_amortiguamiento, dt)
		_copa[i] = m[0]
		_copa_v[i] = m[1]

	# Niebla: cada capa con su viento, integrado para que las rachas aceleren
	# sin saltos. La de suelo viene ademas despacio hacia la camara.
	var rm := viento_en(1456.0)
	_viento_suelo += dt * Vector2((0.005 + 0.014 * rm) * (0.6 + brisa), 0.014)
	_viento_fondo += dt * Vector2(6.0 + 16.0 * rm, -0.5)
	_viento_medio += dt * Vector2(11.0 + 34.0 * rm, -0.8)
	_viento_cerca += dt * Vector2(24.0 + 70.0 * rm, -1.5)


## Golpe de camara (el emu al pasar rozando): se amortigua en sacudida_s.
func sacudir(fuerza := 1.0) -> void:
	_sacudida = maxf(_sacudida, fuerza)

## Claro: el sol se abre paso entre la bruma (sube despacio, se queda y se va).
func _avanzar_claro(dt: float) -> void:
	_hasta_claro -= dt
	if _hasta_claro <= 0.0:
		_c_inicio = _t
		_c_sube = _rng.randf_range(3.0, 5.0)
		_c_dura = _rng.randf_range(3.0, 6.0)
		_c_baja = _rng.randf_range(5.0, 8.0)
		_c_fuerza = _rng.randf_range(claro_fuerza.x, claro_fuerza.y)
		_hasta_claro = _c_sube + _c_dura + _c_baja + _rng.randf_range(claro_cada.x, claro_cada.y)
	var e := _t - _c_inicio
	if e < _c_sube:
		claro = _c_fuerza * smoothstep(0.0, _c_sube, e)
	elif e < _c_sube + _c_dura:
		claro = _c_fuerza
	else:
		claro = _c_fuerza * (1.0 - smoothstep(_c_sube + _c_dura, _c_sube + _c_dura + _c_baja, e))

## Muelle amortiguado: devuelve [posicion, velocidad]. En pasos de 1/120 s como
## mucho: con el paso de un fotograma lento (15-25 FPS) los muelles rapidos se
## disparan.
func _muelle(pos: Vector2, vel: Vector2, objetivo: Vector2, frec: float, amort: float, dt: float) -> Array:
	var w := TAU * frec
	var n := maxi(1, ceili(dt * 120.0))
	var h := dt / n
	for i in n:
		vel += ((objetivo - pos) * w * w - vel * 2.0 * amort * w) * h
		pos += vel * h
	return [pos, vel]

## Lo que se desplaza en pantalla un punto p de la escena que esta a la
## distancia w (1 lo mas cerca, 0 el fondo): lo mismo que hace el fondo.
func paralaje(p: Vector2, w: float) -> Vector2:
	var foco: Vector2 = _param.foco
	return (camara + (p - foco) * acercamiento) * w

## Donde se ve en pantalla un punto de la imagen (p. ej. el arranque de una
## hoja en una rama): lo mismo que hace camino_fondo.gdshader con la copa y la
## camara, con la misma textura de ruido. Asi las hojas de la copa van pegadas
## a su ramita.
func donde_se_ve(a: Vector2) -> Vector2:
	var mv := _mascara_viento.get_pixel(
		clampi(int(a.x * 0.5), 0, _mascara_viento.get_width() - 1),
		clampi(int(a.y * 0.5), 0, _mascara_viento.get_height() - 1))
	var foco: Vector2 = _param.foco
	var d := (camara + (a - foco) * acercamiento) * (1.0 - mv.b)
	if mv.r > 0.002:
		var f := clampf(a.x / PANTALLA.x, 0.0, 1.0) * 4.0
		var i := mini(int(f), 3)
		var k := smoothstep(0.0, 1.0, f - i)
		var e := _copa[i].lerp(_copa[i + 1], k)
		var ag := lerpf(viento_en(PANTALLA.x * i / 4.0), viento_en(PANTALLA.x * (i + 1) / 4.0), k)
		var nr := _ruido_en(a / 700.0 + _param.rama_vel * _t, 0)
		var nt := _ruido_en(a / 150.0 + _param.ramita_vel * _t, 2)
		d += mv.r * (e
			+ nr * 2.0 * (float(_param.rama_px) * brisa + float(_param.rama_racha_px) * ag)
			+ nt * 2.0 * (float(_param.ramita_px) * brisa + float(_param.ramita_racha_px) * ag))
	return a + d

## Dos canales del ruido (desde el canal c) en uv, con repeticion y bilineal,
## menos 0,5: igual que texture(ruido, uv).xy - 0.5 en el shader.
func _ruido_en(uv: Vector2, c: int) -> Vector2:
	var w := _ruido_img.get_width()
	var h := _ruido_img.get_height()
	var x := uv.x * w - 0.5
	var y := uv.y * h - 0.5
	var x0 := floori(x)
	var y0 := floori(y)
	var fx := x - x0
	var fy := y - y0
	var p00 := _ruido_img.get_pixel(posmod(x0, w), posmod(y0, h))
	var p10 := _ruido_img.get_pixel(posmod(x0 + 1, w), posmod(y0, h))
	var p01 := _ruido_img.get_pixel(posmod(x0, w), posmod(y0 + 1, h))
	var p11 := _ruido_img.get_pixel(posmod(x0 + 1, w), posmod(y0 + 1, h))
	var m := p00.lerp(p10, fx).lerp(p01.lerp(p11, fx), fy)
	if c == 0:
		return Vector2(m.r - 0.5, m.g - 0.5)
	return Vector2(m.b - 0.5, m.a - 0.5)

func _racha_hace(retraso: float) -> float:
	var tt := _t - retraso
	if _historia.is_empty() or tt >= _historia[-1].x:
		return _racha
	for i in range(_historia.size() - 1, 0, -1):
		var a := _historia[i - 1]
		if a.x <= tt:
			var b := _historia[i]
			return lerpf(a.y, b.y, (tt - a.x) / maxf(b.x - a.x, 1e-4))
	return _historia[0].y

## Deriva de la camara: sumas de senos lentas con periodos que no casan (no
## se nota que se repite) y acercamiento que va y viene en ~40 s.
func _mover_camara() -> void:
	var t := _t * camara_ritmo
	camara = Vector2(
		0.6 * sin(TAU * t / 19.0) + 0.4 * sin(TAU * t / 11.3 + 1.1),
		(0.5 * sin(TAU * t / 15.0 + 2.0) + 0.3 * sin(TAU * t / 9.7 + 0.4)) * 0.6) * camara_px
	acercamiento = camara_acercamiento * (0.5 - 0.5 * cos(TAU * t / 27.0))
	# tension: la deriva se calma y se acerca al emu (centrado en el)
	if tension > 0.0:
		var k := smoothstep(0.0, 1.0, tension)
		var foco: Vector2 = _param.get("foco", Vector2(1440.0, 900.0))
		camara *= 1.0 - 0.7 * k
		acercamiento = acercamiento * (1.0 - 0.7 * k) + tension_acercamiento * k
		camara -= (tension_hacia - foco) * tension_acercamiento * k
	# Golpe: temblor rapido que se apaga (al cuadrado: corta al final sin saltos).
	if _sacudida > 0.0:
		var k := _sacudida * _sacudida * sacudida_px
		camara += Vector2(_ruido.get_noise_1d(t * 17.0 + 900.0), _ruido.get_noise_1d(t * 17.0 + 1300.0)) * k * 1.6

func _subir_parametros() -> void:
	_mover_camara()
	MusicAmbience.camino_extra_db = musica_claro_db * claro
	var agitacion := PackedFloat32Array()
	var media := 0.0
	for i in MUELLES:
		agitacion.append(viento_en(PANTALLA.x * i / (MUELLES - 1)))
		media += _copa[i].x
	media /= MUELLES
	_mf.set_shader_parameter("tiempo", _t)
	_mf.set_shader_parameter("brisa", brisa)
	_mf.set_shader_parameter("empuje", _copa)
	_mf.set_shader_parameter("agitacion", agitacion)
	_mf.set_shader_parameter("camara", camara)
	_mf.set_shader_parameter("acercamiento", acercamiento)
	_mf.set_shader_parameter("brisa_suelo", clampf(viento_en(PANTALLA.x * 0.5) + 0.3 * brisa, 0.0, 1.0))

	luz = _ruido.get_noise_1d(_t * 0.05 + 600.0) * 1.6
	_ma.set_shader_parameter("tiempo", _t)
	_ma.set_shader_parameter("viento_suelo", _viento_suelo)
	_ma.set_shader_parameter("viento_fondo", _viento_fondo)
	_ma.set_shader_parameter("viento_medio", _viento_medio)
	_ma.set_shader_parameter("viento_cerca", _viento_cerca)
	_ma.set_shader_parameter("rayos_giro", media * giro_rayos)
	_ma.set_shader_parameter("luz_global", luz)
	_ma.set_shader_parameter("luz_deriva", Vector2(_t * 0.006, _t * 0.0015))
	_ma.set_shader_parameter("parpadeo", clampf(viento_en(PANTALLA.x * 0.5) + 0.25 * brisa, 0.0, 1.0))
	_ma.set_shader_parameter("camara", camara)
	_ma.set_shader_parameter("claro", claro)


## Lo que el peregrino puede hacer aqui, para los controles del menu de pausa
## (scripts/ui/menu_pausa.gd): de frente solo anda hacia el fondo o hacia la
## camara, y lleva el baculo.
func controles_disponibles() -> Array:
	return [
		{"acciones": [&"saltar"], "texto": "controles.hacia_fondo"},
		{"acciones": [&"agacharse"], "texto": "controles.hacia_ti"},
		{"acciones": [&"baston"], "texto": "controles.baculo", "nota": "controles.baculo_sacar"},
	]



## Para seguir donde se dejo (Partida.guardar_reanudar): en el camino se sigue
## desde su principio, con el baculo como lo llevaba. Al final del camino (el
## fundido a negro de la llegada) no se apunta nada.
func estado_reanudar() -> Dictionary:
	var p := get_node_or_null("Peregrino")
	if p == null:
		for n in get_children():
			if n.get("peregrino") is PeregrinoFrontal:
				p = n
				break
	if p == null or String(p.get("_estado")) in ["llegando", "fuera"]:
		return {}
	var frontal: PeregrinoFrontal = p.get("peregrino")
	var peregrino := {"baston_en_mano": bool(frontal.con_baston) if frontal else true}
	return {"fase": "camino", "peregrino": peregrino}
