extends Node2D
## Pantalla de titulo. Todo se cuenta con luz:
##  0. Negro. Los creditos (title_credits.gd): dos tarjetas que una luz recorre
##     y apaga. Nada mas se mueve hasta que acaban.
##  1. Negro. Aparecen a la vez, muy poco a poco, el titileo de las dos velas y el
##     vaho del cristal del ataud: seguimos dentro del sarcofago.
##  2. Se enciende el foco de arriba sobre la pared alta.
##  3. Se dibuja el contorno del cristal del ataud, el marco del panel.
##  4. Ese mismo foco crece y se queda: su luz es la que acaba llegando a toda la
##     sala. El vaho se apaga mientras, porque con la sala a la vista ya no pinta.
##  5. Un destello recorre las letras del titulo.
##  5b. El aracnobat lleva todo este rato en su trozo de telarana de la esquina de
##     abajo a la derecha, pivotando y dando paseos cortos. Aqui no hace nada.
## El viento suena desde el primer fotograma y va ganando cuerpo, con rachas que
## siguen soplando mientras la pantalla este puesta.
##
## Y la salida, que deshace lo anterior:
##  6. Las velas se ponen nerviosas y se apagan, primero una y luego la otra, y
##     con ellas se apaga el interior del cristal: el rectangulo queda a oscuras
##     mientras fuera el foco sigue dando en la pared. Las letras del titulo se
##     apagan ahi, antes que nada, para que el hueco este vacio al entrar.
##  7. La camara se mete despacio por ese rectangulo, como si salieramos por ahi.
##     Ya entrando, el resto de la sala acompana y pierde la luz.
##  8. Todo es negro, y ahi arranca la escena del personaje.

## Todos los tiempos de la secuencia cuentan desde que acaban los creditos.
@export var show_credits: bool = true
@export var fog_delay: float = 0.5
@export var fog_time: float = 3.4
@export var candle_start: float = 1.0
@export var candle_time: float = 3.0
@export var sun_start: float = 4.6
@export var sun_time: float = 2.6
## Hasta donde llega el charco del foco cuando ya lo ilumina todo.
@export var sun_radius_full: float = 2.9
@export var reveal_start: float = 8.0
@export var reveal_time: float = 4.0
@export var zoom_start: float = 1.05
@export var glint_start: float = 12.6
@export var glint_time: float = 1.4

@export_group("Contorno del cristal")
@export var frame_start: float = 5.6
@export var frame_time: float = 2.4

@export_group("Viento: rachas")
## Solo suenan; ya no mueven nada en pantalla.
@export var gust_first: float = 10.2
@export var gust_cycle: float = 9.0
@export var gust_sweep: float = 2.8

@export_group("Viento")
## Arranca donde lo dejo la escena del ataud, para que no se note el corte.
@export var wind_db_start: float = -9.0
@export var wind_db_dark: float = -5.0
@export var wind_db_sun: float = -3.0
@export var wind_db_peak: float = 0.0
## Nivel al que baja mientras la camara entra en el ataud. La escena siguiente
## arranca con el viento ahi, para que no haya salto.
@export var wind_db_exit: float = -14.0

@export_group("Musica")
## El tema del titulo arranca con los creditos, sobre el negro. El nivel es un
## primer calculo a partir de la sonoridad de los archivos, no de oido: la
## musica esta unos 27 dB por encima del viento, que es una ambientacion muy
## discreta, asi que va muy bajada para no taparlo.
@export var music_db: float = -18.0
## Corto a proposito. El tema no tiene entrada: empieza con material y su momento
## mas fuerte cae sobre 1,0 s, justo cuando la luz esta recorriendo el primer
## credito. Con un fundido largo ese golpe llegaba sin oirse.
@export var music_fade_in: float = 1.2
## Adelanta la pista. Sube esto para que el tema llegue antes a su primer momento
## importante y caiga sobre las letras; baja a 0 para empezar por el principio.
@export var music_start_offset: float = 1.0
## El tema se apaga mientras la camara entra por el cristal, y llega a silencio
## antes del cambio de escena. Es mas corto que zoom_in_time para que quede un
## momento de solo viento y negro antes de que entre el fondo del juego, que lo
## pone dark_stage por su cuenta.
@export var music_fade_out: float = 4.0

@export_group("Salida")
## Momento en que empieza la salida, contado desde el final de los creditos.
## El destello acaba en glint_start + glint_time; se deja ver el titulo un rato.
@export var exit_start: float = 17.0
## Los tiempos de abajo son relativos a exit_start.
## Cuanto tardan las velas en ponerse nerviosas del todo.
@export var unrest_time: float = 3.4
## Se apagan cuando el cristal ya esta casi a oscuras: la llama esta pintada en
## la imagen y solo se puede tapar, y eso solo cuela si alrededor no hay luz.
@export var candle_a_out: float = 3.6
@export var candle_b_out: float = 5.0
@export var candle_out_time: float = 0.55
## El interior del cristal se apaga con las velas, al reves que en el arranque:
## primero el rectangulo, el resto de la sala sigue con la luz del foco.
## Era 1.0. Se retraso porque el aracnobat sale por patas cuando arranca la
## camara (+4.2) y con el valor viejo el cristal estaba ya al 68 % de oscuro a
## esa altura: la huida no se veia. Con 2.4 queda al 28 % y se le ve salir.
@export var window_dark_start: float = 2.4
@export var window_dark_time: float = 4.6
## No llega a negro del todo: dentro se adivina algo hasta que la camara entra.
@export var window_dark_full: float = 0.8
## Las letras del titulo, pintadas en la imagen, se apagan aparte y antes que el
## resto: oscurecer el cristal las baja igual que al panel y se seguirian leyendo
## cuando la camara ya esta dentro del hueco, que es donde quedan raras. El shader
## no las tapa, las funde con el panel.
@export var title_fade_start: float = 1.0
@export var title_fade_time: float = 4.0
## La camara entra por el cristal. Acelera: casi no se nota al principio.
## Era 6.0. Se adelanto para que arranque mientras el aracnobat todavia esta
## aterrizando en la otra telarana: asi lo pierdes de vista porque te estas
## metiendo tu, que es mas bonito que verlo posarse tranquilamente y luego irnos.
@export var zoom_in_start: float = 4.2
@export var zoom_in_time: float = 5.0
@export var zoom_in_end: float = 7.0
## Ya entrando, el resto de la sala acompana: el rebote se va y el foco se
## recoge, durante este tramo inicial del zoom.
@export var room_dim_fraction: float = 0.6
@export var sun_radius_dusk: float = 0.75
@export var sun_intensity_dusk: float = 0.55
@export var frame_light_dusk: float = 0.4
## Tope de lo que puede durar el ultimo apagado, el que lleva a negro lo poco que
## quedaba de luz, como fraccion del zoom. Es solo un tope: cada parametro empieza
## ese apagado cuando acaba el suyo de antes (room_dim_fraction para foco y marco,
## window_dark_start + window_dark_time para el cristal), asi que con los valores
## de ahora duran 1.5 s y 1.7 s y este numero no cambia nada salvo que baje de ~0.3.
@export var black_fraction: float = 0.45
## El negro se completa este tiempo antes de que acabe el zoom, para que los
## ultimos fotogramas ya sean negro y no letras gigantes a medio apagar. Marca el
## final de todos los apagados a negro (black_end), empiecen cuando empiecen.
@export var black_lead: float = 0.5
## Negro antes de cambiar de escena.
@export var black_hold: float = 0.6
## El aracnobat sale por patas. No tiene tiempo propio: se dispara cuando la
## camara arranca (zoom_in_start), porque lo que lo asusta es justamente que algo
## se mueva. Este numero es solo el tiempo de reaccion, y por eso es pequeno.
@export var spider_reaccion: float = 0.15
## A donde se pasa tras el negro: dark_stage, donde cae Magnus.
## Se empieza a cargar en segundo plano cuando la pantalla ya esta en negro
## (ver _pedir_carga), para no tocar la fluidez de nada de lo que se ve.
## En la web sin hilos se sigue cargando al final, en _leave.
@export var next_scene: String = "res://scenes/game/dark_stage.tscn"

const CANDLE_A := Vector2(868, 830)
const CANDLE_B := Vector2(1852, 842)
const SUN := Vector2(1474, 0)
const IMAGE_SIZE := Vector2(2912, 1632)
## Panel interior del marco de la imagen: la ventana del ataud. Medido sobre el
## PNG en el borde interior del marco, justo donde acaban los listones y empiezan
## las telaranas. La sombra del cristal y su contorno se apoyan en esto.
const WINDOW_RECT := Vector4(0.2215, 0.320, 0.755, 0.702)

var _mat: ShaderMaterial
## La mascara, y su version barata para los creditos (ver title_mask_creditos).
var _mask: ColorRect
var _mat_creditos: ShaderMaterial
var _time_a := 0.0
var _time_b := 0.0
var _candle_on := 0.0   # 0..1, cuanto han encendido ya las velas
var _fog_level := 0.0   # 0..1, lo tensa el tween
var _breath := 0.0
var _elapsed := 0.0
var _wind_db := 0.0     # base del volumen; la racha suma por encima
var _unrest := 0.0      # 0..1, lo nerviosas que estan las velas antes de morir
var _candle_a_lvl := 1.0   # 1 encendida, 0 apagada
var _candle_b_lvl := 1.0
var _leaving := false
## Si la carga en segundo plano de next_scene llego a pedirse.
var _carga_pedida := false
## Partida del zoom de entrada, apuntada en su primer paso (ver _zoom_in_step).
var _zin_listo := false
var _zin_z0 := 1.0
var _zin_p0 := Vector2.ZERO
var _zin_anchor := Vector2.ZERO

@onready var _camera: Camera2D = $Camera
@onready var _spider: Node2D = get_node_or_null("Spider")

func _ready() -> void:
	_time_a = randf() * 100.0
	_time_b = randf() * 100.0 + 37.0

	# Capa 100: mascara de oscuridad + vaho, con el shader de revelado.
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var mask := ColorRect.new()
	mask.anchor_right = 1.0
	mask.anchor_bottom = 1.0
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://scripts/intro/title_reveal.gdshader")
	_mat.set_shader_parameter("aspect", IMAGE_SIZE.x / IMAGE_SIZE.y)
	_mat.set_shader_parameter("candle_a", CANDLE_A / IMAGE_SIZE)
	_mat.set_shader_parameter("candle_b", CANDLE_B / IMAGE_SIZE)
	_mat.set_shader_parameter("sun_pos", SUN / IMAGE_SIZE)
	_mat.set_shader_parameter("window_rect", WINDOW_RECT)
	# La mascara mira el brillo del fondo para saber que es letra y que es panel.
	# Lo lee de la textura del fondo, no de lo que ya hay en pantalla: leer la
	# pantalla obliga a copiarla entera cada fotograma, y debajo solo hay este
	# fondo (y la araña, que no pisa ni las letras ni el foco).
	_mat.set_shader_parameter("bg_tex", ($Background as Sprite2D).texture)
	# De repuesto: un fundido global de toda la oscuridad. Se deja en 1 a proposito.
	_mat.set_shader_parameter("darkness", 1.0)
	_mat.set_shader_parameter("candle_radius", 0.0)
	_mat.set_shader_parameter("candle_glow", 0.0)
	_mat.set_shader_parameter("sun_radius", 0.0)
	_mat.set_shader_parameter("sun_intensity", 0.0)
	_mat.set_shader_parameter("room_light", 0.0)
	_mat.set_shader_parameter("frame_light", 0.0)
	_mat.set_shader_parameter("window_dark", 0.0)
	_mat.set_shader_parameter("glint", -1.0)
	_mat.set_shader_parameter("title_fade", 0.0)
	_mat.set_shader_parameter("fog_amount", 0.0)
	mask.material = _mat
	# Mientras salen los creditos todo esta a 0 y la mascara es negro liso: se
	# pinta con un shader que da ese mismo negro sin calcular nada por pixel
	# (title_reveal entero costaba unos 9 ms por fotograma en la P520 ahi). Solo
	# cambia lo que cuesta; los tiempos y lo que se ve son los mismos.
	_mask = mask
	if show_credits:
		_mat_creditos = ShaderMaterial.new()
		_mat_creditos.shader = load("res://scripts/intro/title_mask_creditos.gdshader")
		_mat_creditos.set_shader_parameter("darkness", 1.0)
		mask.material = _mat_creditos
	layer.add_child(mask)
	# La mascara sigue a la camara, y la camara la mueven los tweens, que corren
	# DESPUES de _process: calculado ahi, view_rect iba un fotograma tarde y en el
	# zoom de entrada la luz se quedaba atras del dibujo. Justo antes de pintar ya
	# se han movido todos.
	RenderingServer.frame_pre_draw.connect(_sync_view_rect)

	# Las hojas del vuelo del aracnobat, que si no se cargarian en pleno zoom.
	if _spider and _spider.has_method("precargar_vuelo"):
		_spider.precargar_vuelo()

	if _camera:
		_camera.zoom = Vector2.ONE * zoom_start
	# El viento viene sonando desde el sarcofago (autoload WindAmbience), que lo
	# dejo justo en wind_db_start al desmayarse; aqui solo seguimos subiendolo.
	_wind_db = wind_db_start
	# fade_to con duracion 0 mata de paso el fade del desmayo si aun colea.
	WindAmbience.fade_to(_wind_db, 0.0)
	WindAmbience.gust_db = 0.0

	# La musica entra con los creditos, sobre el negro, antes que ninguna luz.
	MusicAmbience.empezar_titulo(music_db, music_fade_in, music_start_offset)

	if show_credits:
		var credits: CanvasLayer = load("res://scripts/intro/title_credits.gd").new()
		add_child(credits)
		credits.finished.connect(_start_lights)
	else:
		_start_lights()

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_view_rect):
		RenderingServer.frame_pre_draw.disconnect(_sync_view_rect)
	# Si se sale del titulo sin que _leave haya recogido la carga (ESC antes de
	# _leave o durante su espera, o --quit-after en las pruebas), la carga en
	# segundo plano se queda sin recoger y al cerrar sale como objeto sin liberar.
	# Se recoge aqui, pero solo si ya ha acabado: recogerla a medias bloquea hasta
	# que termine, y salir con ESC justo tras los creditos dejaba la ventana
	# congelada varios segundos. Si aun estaba cargando se deja que el motor la
	# corte al cerrar, aunque eso llene el log de errores de parseo falsos: es raro
	# y no se ve en el juego.
	if _carga_pedida:
		_carga_pedida = false
		if ResourceLoader.load_threaded_get_status(next_scene) == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(next_scene)

## Arranca la secuencia de luz. Con creditos, cuando estos acaban; el reloj de
## las rachas empieza a contar aqui.
func _start_lights() -> void:
	# Vuelve la mascara de verdad; en este fotograma todo sigue a 0, asi que da el
	# mismo negro que la de los creditos.
	if _mask and _mask.material != _mat:
		_mask.material = _mat
	_elapsed = 0.0
	_run_sequence()
	_run_exit()

func _run_sequence() -> void:
	# Un unico tween en paralelo; cada paso lleva su propio retardo.
	var tw := create_tween().set_parallel(true)

	# Vaho: entra en el negro y se apaga del todo cuando la sala ya se ve.
	tw.tween_method(_set_fog, 0.0, 1.0, fog_time).set_delay(fog_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_fog, 1.0, 0.0, reveal_time * 0.75).set_delay(reveal_start).set_trans(Tween.TRANS_SINE)

	# Velas
	tw.tween_method(_set_candle_on, 0.0, 1.0, candle_time).set_delay(candle_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Foco superior
	tw.tween_method(_set_shader.bind("sun_intensity"), 0.0, 1.0, sun_time).set_delay(sun_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_shader.bind("sun_radius"), 0.0, 0.42, sun_time).set_delay(sun_start).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Contorno del cristal del ataud, dibujandose en la oscuridad.
	tw.tween_method(_set_shader.bind("frame_light"), 0.0, 1.0, frame_time).set_delay(frame_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# El foco crece hasta abarcar la sala: es su luz la que lo ilumina todo.
	tw.tween_method(_set_shader.bind("sun_radius"), 0.42, sun_radius_full, reveal_time).set_delay(reveal_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# El rebote va por detras del charco, para que se note quien manda.
	tw.tween_method(_set_shader.bind("room_light"), 0.0, 1.0, reveal_time).set_delay(reveal_start).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Destello en las letras
	tw.tween_method(_set_shader.bind("glint"), -0.3, 1.3, glint_time).set_delay(glint_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)



	# Zoom lento hacia fuera durante toda la secuencia
	if _camera:
		tw.tween_property(_camera, "zoom", Vector2.ONE, reveal_start + reveal_time + 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Viento: presente desde el primer fotograma y creciendo. La racha mas fuerte
	# coincide con el momento en que la sala prende, y ahi se queda.
	# Se mueve la base del volumen; la racha suma unos dB por encima en _process.
	tw.tween_method(_set_wind_db, wind_db_start, wind_db_dark, sun_start).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_set_wind_db, wind_db_dark, wind_db_sun, reveal_start - sun_start).set_delay(sun_start).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_set_wind_db, wind_db_sun, wind_db_peak, reveal_time * 0.55).set_delay(reveal_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _run_exit() -> void:
	var tw := create_tween().set_parallel(true)
	var t0 := exit_start

	# Las velas se inquietan. Sube la amplitud del parpadeo que ya tienen.
	tw.tween_method(_set_unrest, 0.0, 1.0, unrest_time).set_delay(t0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Y se apagan una tras otra. Al morir cada una la otra se queda sola un momento.
	tw.tween_method(_set_candle_a, 1.0, 0.0, candle_out_time).set_delay(t0 + candle_a_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_method(_set_candle_b, 1.0, 0.0, candle_out_time).set_delay(t0 + candle_b_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Con las velas se apaga el interior del cristal. Fuera, el foco sigue.
	tw.tween_method(_set_shader.bind("window_dark"), 0.0, window_dark_full, window_dark_time).set_delay(t0 + window_dark_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Y con el cristal se van las letras del titulo, un poco antes: para cuando la
	# camara empieza a meterse por el hueco, dentro ya no hay letras que leer.
	tw.tween_method(_set_shader.bind("title_fade"), 0.0, 1.0, title_fade_time).set_delay(t0 + title_fade_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Ya entrando, el resto de la sala acompana: el rebote se va y el foco se
	# recoge hacia arriba. Es el arranque al reves.
	var dim_time := zoom_in_time * room_dim_fraction
	var dim_start := t0 + zoom_in_start
	# El negro final (mas abajo) acaba en black_end; black_start es lo antes que
	# puede arrancar, pero cada parametro espera ademas a su propio apagado.
	var black_time := zoom_in_time * black_fraction
	var black_start := t0 + zoom_in_start + zoom_in_time - black_lead - black_time
	var black_end := black_start + black_time
	tw.tween_method(_set_shader.bind("room_light"), 1.0, 0.0, dim_time).set_delay(dim_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_shader.bind("sun_radius"), sun_radius_full, sun_radius_dusk, dim_time).set_delay(dim_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_shader.bind("sun_intensity"), 1.0, sun_intensity_dusk, dim_time).set_delay(dim_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_shader.bind("frame_light"), 1.0, frame_light_dusk, dim_time).set_delay(dim_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# El aracnobat ve moverse la camara y sale por patas hacia arriba.
	if _spider and _spider.has_method("volar"):
		tw.tween_callback(_spider.volar).set_delay(t0 + zoom_in_start + spider_reaccion)

	# La camara entra por el cristal. Empieza casi quieta y acelera.
	# Zoom y posicion van juntos alrededor de un punto fijo de la imagen, que se
	# queda quieto en pantalla mientras todo crece: sale de donde este la camara y
	# acaba centrada en el cristal, igual que antes. Con dos tweens sueltos (zoom y
	# posicion con la misma curva) el centro del zoom nadaba: el marco se iba hacia
	# un lado y volvia, un bamboleo de camara en vez de meterse recto.
	# El tween lleva u de 0 a 1 con la curva; el zoom y la posicion de partida se
	# leen en su primer paso (ver _zoom_in_step), no ahora, como hacia el
	# tween_property de antes: si se mueven los tiempos y el zoom lento de la
	# secuencia no ha vuelto a 1 todavia, se parte de donde este, sin salto.
	if _camera:
		var target := Vector2(WINDOW_RECT.x + WINDOW_RECT.z, WINDOW_RECT.y + WINDOW_RECT.w) * 0.5 * IMAGE_SIZE
		tw.tween_method(_zoom_in_step.bind(target), 0.0, 1.0, zoom_in_time).set_delay(t0 + zoom_in_start).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# Lo poco que quedaba de luz se va del todo en el ultimo tramo del zoom.
	# Cada parametro arranca cuando ha acabado su propio apagado de arriba, y no
	# antes: si se pisaban, el de aqui mandaba desde su valor fijo de partida y
	# habia un salto de luz de un fotograma y luego un paron. Acaban todos a la
	# vez, en black_end, que no cambia.
	var sf_start := maxf(black_start, dim_start + dim_time)
	var wd_start := maxf(black_start, t0 + window_dark_start + window_dark_time)
	tw.tween_method(_set_shader.bind("sun_intensity"), sun_intensity_dusk, 0.0, maxf(black_end - sf_start, 0.01)).set_delay(sf_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_method(_set_shader.bind("frame_light"), frame_light_dusk, 0.0, maxf(black_end - sf_start, 0.01)).set_delay(sf_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_method(_set_shader.bind("window_dark"), window_dark_full, 1.0, maxf(black_end - wd_start, 0.01)).set_delay(wd_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# El viento se aleja con nosotros.
	tw.tween_method(_set_wind_db, wind_db_peak, wind_db_exit, zoom_in_time).set_delay(t0 + zoom_in_start).set_trans(Tween.TRANS_SINE)

	# Y con el se va el tema del titulo, que no se cruza con el del juego: se
	# apaga del todo aqui y el otro entra despues, ya en negro y en la escena
	# siguiente. Solaparlos sonaba a cambio de pista; separarlos deja que el
	# negro haga de junta entre las dos escenas.
	tw.tween_callback(MusicAmbience.apagar_titulo.bind(music_fade_out)).set_delay(t0 + zoom_in_start)

	# La escena siguiente (Magnus y sus hojas de sprites) se empieza a cargar
	# cuando la pantalla ya esta en negro del todo, y no antes: cargar en segundo
	# plano resta fluidez, y ni los creditos, ni la entrada de la luz con el tema,
	# ni el zoom por el cristal se pueden tocar. Lo que no haya acabado para
	# _leave se espera sobre el mismo negro, igual que cuando se cargaba de golpe,
	# pero sin congelar la ventana: _leave deja correr los fotogramas mientras
	# tanto. El cambio de escena y el primer fotograma de la siguiente siguen costando
	# lo suyo (instanciarlo y pintarlo), eso no lo quita la carga en segundo plano.
	tw.tween_callback(_pedir_carga).set_delay(black_end)
	tw.tween_callback(_leave).set_delay(t0 + zoom_in_start + zoom_in_time + black_hold)

## Pide la carga en segundo plano de next_scene. Con use_sub_threads las
## dependencias se cargan en paralelo. En la web sin hilos (preset Web,
## threads_enabled=false) "segundo plano" seria este mismo hilo: no se pide y
## _leave carga a la antigua.
func _pedir_carga() -> void:
	if not _carga_pedida and not OS.has_feature("nothreads"):
		_carga_pedida = ResourceLoader.load_threaded_request(next_scene, "", true) == OK

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	WindAmbience.gust_db = 0.0
	WindAmbience.fade_to(wind_db_exit, 0.0)
	# Ya no hay nada que ver: la pantalla es negro liso desde black_end. Sin esto
	# _process seguiria poniendo el viento y, si la espera de abajo pasa de ~1.4 s,
	# volveria la racha de _elapsed 28.2 (+2 dB) sobre el negro.
	set_process(false)
	# Lo que falte de la carga se espera sobre ese negro dejando correr los
	# fotogramas: esperarla con load_threaded_get a secas congelaba la ventana
	# (ni ESC ni Alt+F4, y Windows podia darla por colgada) hasta que acababa.
	while _carga_pedida and ResourceLoader.load_threaded_get_status(next_scene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		if not is_inside_tree() or get_tree().paused:
			return  # ESC o cierre de ventana: GlobalExit._salir pausa y sale
	# Aqui la carga ya ha acabado. Si fallo o no se pidio (web sin hilos), se
	# carga a la antigua.
	var ps: PackedScene = null
	if _carga_pedida and ResourceLoader.load_threaded_get_status(next_scene) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ps = ResourceLoader.load_threaded_get(next_scene) as PackedScene
	_carga_pedida = false  # recogida (o fallida): _exit_tree ya no tiene que hacer nada
	if ps:
		get_tree().change_scene_to_packed(ps)
	else:
		get_tree().change_scene_to_file(next_scene)

## Un paso del zoom de entrada; u va de 0 a 1 ya con la curva aplicada. En el
## primero se apunta de donde parte la camara (zoom z0 en p0) y el punto de la
## imagen que no se mueve en pantalla (anchor): con z0 la camara esta en p0 y con
## zoom_in_end, centrada en target, el cristal.
func _zoom_in_step(u: float, target: Vector2) -> void:
	if not _zin_listo:
		_zin_listo = true
		_zin_z0 = _camera.zoom.x
		_zin_p0 = _camera.position
		_zin_anchor = _zin_p0 + (target - _zin_p0) * zoom_in_end / maxf(zoom_in_end - _zin_z0, 0.001)
	var z := lerpf(_zin_z0, zoom_in_end, u)
	_camera.zoom = Vector2.ONE * z
	_camera.position = _zin_anchor - (_zin_anchor - _zin_p0) * _zin_z0 / z

func _set_unrest(v: float) -> void:
	_unrest = v

func _set_candle_a(v: float) -> void:
	_candle_a_lvl = v
	_mat.set_shader_parameter("candle_a_on", v)

func _set_candle_b(v: float) -> void:
	_candle_b_lvl = v
	_mat.set_shader_parameter("candle_b_on", v)

func _set_shader(value: float, param: String) -> void:
	_mat.set_shader_parameter(param, value)

func _set_candle_on(v: float) -> void:
	_candle_on = v
	_mat.set_shader_parameter("candle_radius", 0.15 * v)
	_mat.set_shader_parameter("candle_glow", v)

func _set_fog(v: float) -> void:
	_fog_level = v

func _set_wind_db(v: float) -> void:
	_wind_db = v

## Fuerza 0..1 de la racha de viento que sopla cada gust_cycle segundos.
func _gust_strength() -> float:
	var t := _elapsed - gust_first
	if t < 0.0:
		return 0.0
	var phase := fmod(t, maxf(gust_cycle, gust_sweep))
	if phase > gust_sweep:
		return 0.0
	return sin((phase / gust_sweep) * PI)

func _process(delta: float) -> void:
	_elapsed += delta

	# Mismo parpadeo que flicker_glow.gd, una semilla distinta por vela.
	# Cuando se inquietan, el parpadeo va mas rapido.
	var speed := 2.5 * (1.0 + _unrest * 1.4)
	_time_a += delta * speed
	_time_b += delta * speed
	var fa := _flicker(_time_a)
	var fb := _flicker(_time_b)
	# Al encenderse tiemblan mas; una vez encendidas solo respiran.
	var unstable := 1.0 - _candle_on
	fa = lerpf(fa, 1.0, 0.35) - unstable * 0.25 * absf(sin(_time_a * 3.3))
	fb = lerpf(fb, 1.0, 0.35) - unstable * 0.25 * absf(sin(_time_b * 2.7))
	# Antes de morir, la llama se hunde a rachas: bajones irregulares y profundos.
	fa *= 1.0 - _unrest * 0.55 * _dip(_time_a)
	fb *= 1.0 - _unrest * 0.55 * _dip(_time_b + 11.0)
	# Y al apagarse, lo que quede de llama se va con el nivel de la vela.
	_mat.set_shader_parameter("candle_a_flicker", fa * _candle_a_lvl)
	_mat.set_shader_parameter("candle_b_flicker", fb * _candle_b_lvl)

	# El vaho respira despacio: sigue ahi dentro, aun respirando.
	_breath += delta
	var pulse := 0.78 + 0.22 * sin(_breath * 1.15)
	_mat.set_shader_parameter("fog_amount", _fog_level * pulse)

	# Rachas de viento: solo suben el volumen, no tocan la imagen.
	WindAmbience.base_db = _wind_db
	WindAmbience.gust_db = _gust_strength() * 2.0

## La mascara de luz esta medida sobre la imagen: hay que decirle que trozo de la
## imagen tiene la camara en pantalla para que la siga en el zoom. Va enganchado
## a frame_pre_draw (ver _ready), con la camara ya movida por los tweens.
func _sync_view_rect() -> void:
	if not _camera:
		return
	var half := IMAGE_SIZE * 0.5 / _camera.zoom
	var lo := (_camera.position - half) / IMAGE_SIZE
	var hi := (_camera.position + half) / IMAGE_SIZE
	_mat.set_shader_parameter("view_rect", Vector4(lo.x, lo.y, hi.x, hi.y))

## Bajon irregular 0..1 para la llama nerviosa: dos senos que no van a compas.
func _dip(t: float) -> float:
	var d := sin(t * 2.9) * sin(t * 1.15 + 0.7)
	return clampf(d * d * 1.6, 0.0, 1.0)

func _flicker(t: float) -> float:
	# 0.5 + 0.2 sin + 0.1 sin: rango 0.2..0.8, normalizado a ~0.25..1.0
	var e := 0.5 + sin(t * 1.2) * 0.2 + sin(t * 4.5) * 0.1
	return e / 0.8
