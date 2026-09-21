extends Node2D

signal spotted
signal died

@onready var ant_l: Sprite2D = $AntennaL
@onready var ant_r: Sprite2D = $AntennaR
@onready var step_sound: AudioStreamPlayer2D = $StepSound
@onready var body: Sprite2D = $Body
@onready var shadow: Sprite2D = $Shadow
@onready var rim_light: Sprite2D = $RimLight

var squash_audio = preload("res://assets/audio/slime-splatter.ogg")
var spore_scene = preload("res://scenes/intro/spore_cloud.tscn")

## Hoja del aplastado: cuerpo y antenas por separado, sacados del png de una
## pieza. Los offsets ponen el centro de giro de cada antena en su raiz, y las
## posiciones son su raiz en pixeles de la imagen (1024x1536, centro 512,768)
## llevada al sistema del cuerpo y escalada como el.
const DEAD_SHEET := "res://assets/intro/cockroach_squashed_parts.png"
const DEAD_SCALE := 1.5
## Pico real de FastNoiseLite Perlin, medido: get_noise_1d no llega a +-1.
const NOISE_PEAK := 0.40
const DEAD_BODY_REGION := Rect2(0, 0, 1024, 1536)
const DEAD_ANT_L := {
	"region": Rect2(16, 1552, 372, 204), "offset": Vector2(-185.0, -96.0), "base": Vector2(377, 270)
}
const DEAD_ANT_R := {
	"region": Rect2(420, 1552, 385, 213), "offset": Vector2(192.5, -95.5), "base": Vector2(626, 276)
}
## Tibia y tarso de las cuatro patas traseras, seccionadas por la rodilla. Las
## delanteras se quedan enteras en el cuerpo: la izquierda cruzaba la antena y
## no compensaba volver a seccionar por ahi. "side" hace que las de un lado y
## las del otro se encojan en espejo durante el espasmo.
const DEAD_LEGS := [
	{"region": Rect2(1040, 16, 169, 288), "offset": Vector2(-46.5, 143.0), "base": Vector2(136, 639), "side": 1.0},
	{"region": Rect2(1225, 16, 210, 296), "offset": Vector2(68.0, 143.0), "base": Vector2(841, 642), "side": -1.0},
	{"region": Rect2(1451, 16, 125, 441), "offset": Vector2(-43.5, 218.5), "base": Vector2(165, 916), "side": 1.0},
	{"region": Rect2(1592, 16, 72, 301), "offset": Vector2(34.0, 147.5), "base": Vector2(800, 1070), "side": -1.0},
]

@onready var femurs: Array = [
	$LegFrontL/Femur, $LegMidR/Femur, $LegHindL/Femur,
	$LegFrontR/Femur, $LegMidL/Femur, $LegHindR/Femur
]

var tibias: Dictionary = {}

enum State { IDLE, ROTATING, WALKING, PAUSED }
var current_state: State = State.IDLE
var state_timer: float = 0.0
var is_dead := false

var is_scared := false
var has_been_scared_once := false
var last_impact_pos := Vector2.ZERO
var is_investigating := false
var arrived_at_impact := false
var corner_cooldown := false

@export_group("Atmosphere & Polygon")
@export var debug_show_polygon: bool = false
@export var light_polygon: PackedVector2Array = [
	Vector2(650, 80), Vector2(2360, 80), Vector2(2680, 450),
	Vector2(2680, 1130), Vector2(2360, 1500), Vector2(650, 1500),
	Vector2(250, 1130), Vector2(250, 450)
]
@export var fade_margin: float = 60.0
@export var color_center: Color = Color(0.38, 0.38, 0.42)
@export var color_center_warmth: Color = Color(1.4, 1.25, 0.8)
@export var color_edge_fog: Color = Color(0.2, 0.22, 0.27)
@export var min_alpha_fog: float = 0.9
## Dentro del cristal el tinte varia con el brillo del fondo que hay detras de la
## cucaracha (leido de una copia reducida de la imagen): mas clara junto a las
## velas, algo mas apagada en las zonas oscuras, nunca negra.
@export var bg_light_dark: float = 0.12
@export var bg_light_bright: float = 0.50
@export var brightness_min: float = 0.85
@export var brightness_max: float = 1.35
@export var bg_sample_radius: float = 100.0
## Cuanto afecta el parpadeo de la vela mas cercana (0 = nada).
@export var flicker_influence: float = 0.25

var target_position: Vector2
var target_rotation: float = 0.0
var move_speed: float = 0.0
var noise := FastNoiseLite.new()
var time_passed: float = 0.0

@export_group("Organic Timing")
@export var idle_time_min: float = 3.0
@export var idle_time_max: float = 8.0
@export var bounds_min: Vector2 = Vector2(150, 150)
@export var bounds_max: Vector2 = Vector2(2760, 1480)
@export var failsafe_point: Vector2 = Vector2(1456, 816)

@export_group("Locomotion")
## Velocidad de giro en rad/s. Con el valor antiguo (26) el giro duraba 1-2 frames y parecia un salto.
@export var turn_speed: float = 9.0
## Angulo restante (rad) por debajo del cual arranca a andar mientras termina de girar: la salida es un arco.
@export var start_walk_angle: float = 1.0
## Segundos para pasar de parada a velocidad plena. Corto: la cucaracha sale
## disparada, no acelera como un coche.
@export var accel_time: float = 0.05
## Frena en los ultimos px antes del objetivo sin bajar de esta fraccion de la
## velocidad. Poca cosa: solo evita el frenazo seco, el paron sigue siendo brusco.
@export var brake_distance: float = 40.0
@export var brake_min_factor: float = 0.75
## Ruido de rumbo durante la carrera (rad) para que la recta no sea de laser.
@export var heading_noise: float = 0.12
## Al huir elegia esquina solo por lo lejos que quedaba del impacto, sin mirar
## donde estaba ella: si el golpe caia en medio, corria hacia el puno. Este peso
## anade "y ademas que le de la espalda al golpe" al criterio.
@export var corner_flee_bias: float = 900.0

@export_group("Leg Animation")
## Los sprites de las patas pivotan en cadera y rodilla (offset en cockroach.tscn),
## asi que las amplitudes pueden ser mayores sin que las piezas se separen.
@export var femur_swing_amount: float = 0.30
@export var tibia_flex_amount: float = 0.19
@export var front_leg_swing_mult: float = 0.85
@export var hind_leg_swing_mult: float = 1.15
## Amplitud extra durante la huida: al huir no solo mueve las patas mas deprisa,
## tambien las abre mas. Sube la sensacion de panico sin subir la frecuencia.
@export var scared_swing_mult: float = 1.3
## La cadencia va ligada a la velocidad real de suelo: la cucaracha avanza esta
## fraccion de su cuerpo por cada ciclo completo de patas. Mas bajo = patas mas
## rapidas y menos sensacion de patinar.
@export var stride_body_lengths: float = 0.7
## Al huir la zancada se alarga ademas de acelerar, como en el bicho real. Sin
## esto la cadencia tocaba techo en la huida (pedia 12 Hz, se le daban 7,5) y la
## zancada real se estiraba a 1,13 veces el cuerpo: volvia a patinar justo en el
## momento mas visible de la escena.
@export var stride_scared_mult: float = 1.35
## Limites de cadencia en Hz. El tope no depende de la maquina a proposito: asi
## la cucaracha se mueve igual en todos los equipos. 9,5 Hz es lo que pide la
## huida con la zancada larga; el paseo se queda igual que antes, en 6,4.
@export var cadence_min_hz: float = 2.5
@export var cadence_max_hz: float = 9.5
@export var idle_jitter: float = 0.02
@export var walk_jitter: float = 0.02

@export_group("Body Motion")
## La camara es cenital, asi que el cuerpo no puede cabecear hacia el especta-
## dor: lo que se ve desde arriba es una guiñada (pivota hacia el tripode que
## apoya), un vaiven lateral y el rebote como un pulso de escala. Lo llevan Body
## y RimLight; las patas se quedan ancladas y la sombra no acompaña, que es lo
## que hace que se lea como un cuerpo sobre el suelo y no como un sprite rigido.
## Las distancias van en unidades locales del sprite (el cuerpo mide 1309 de
## alto) y el nodo raiz las escala a 0,18: ~5,5 unidades locales son 1 pixel.
@export var body_yaw_amount: float = 0.021
@export var body_sway_amount: float = 7.0
## Al doble de la cadencia: hay dos apoyos por ciclo.
@export var body_bob_scale: float = 0.006
## El cuerpo entra en las curvas por detras del rumbo. Segundos de retardo: el
## desfase sale de la velocidad de giro, asi que solo se nota al girar de verdad.
@export var body_turn_lag: float = 0.008
## Tope del retardo en rad (~5 grados), para que un giro de panico no lo descoyunte.
@export var body_turn_lag_max: float = 0.09

@export_group("Step Sound")
## El wav es una carrerilla continua de 1,4 s, no un paso suelto: su tono sigue
## a la cadencia de las patas para que oido y vista vayan juntos. La referencia
## es la cadencia del paseo normal, donde suena a su tono original.
@export var step_pitch_ref_hz: float = 6.4
@export var step_pitch_min: float = 0.75
@export var step_pitch_max: float = 1.6
## El corte seco al parar se oia; ahora se apaga en este tiempo.
@export var step_fade_out: float = 0.12

@export_group("Death Throes")
## Las antenas siguen barriendo despues del golpe. El blackout deja la imagen
## nitida 1,5 s y no la emborrona de verdad hasta los 4,5, asi que hay sitio de
## sobra; pasado ese rato ya no se distingue nada.
@export var death_twitch_time: float = 4.0
## Amplitud del barrido en rad al principio (~12,6 grados de pico), decayendo
## a cero. El ruido se normaliza antes: Perlin solo llega a +-0,39 de pico y
## +-0,10 de media, asi que sin dividir la amplitud real era la cuarta parte.
@export var death_twitch_amount: float = 0.22
## Ciclos por segundo del barrido. La antena derecha va al 0,83 de este ritmo
## para que las dos no parezcan sincronizadas.
@export var death_twitch_hz: float = 1.8
## La derecha se queda quieta antes que la izquierda: las dos apagandose a la
## vez se lee como un mecanismo.
@export var death_twitch_asymmetry: float = 0.78
## Las patas se quedan rigidas antes que las antenas y se mueven bastante
## menos: una cucaracha muerta encoge las patas y las deja, no las barre.
@export var death_leg_time: float = 2.6
@export var death_leg_amount: float = 0.09
@export var death_leg_hz: float = 2.6
## Reloj maestro del cadaver. El desmayo empieza a los 9 s y a los 10,5 la
## pantalla ya es negra, asi que animar mas alla no lo ve nadie.
@export var death_total_time: float = 9.0
## Meneo lento de las antenas que releva al estertor y aguanta hasta el final.
## Entra segun se apaga el estertor y no se suma a el, asi que los primeros
## segundos quedan exactamente igual que antes. 0,09 rad son ~5 grados de tope,
## que a la escala de la escena mueven la punta unos 7 pixeles: se ve incluso
## con el desenfoque del desmayo encima.
@export var death_idle_tremor: float = 0.09
@export var death_idle_hz: float = 0.7
## Cuales de los parpadeos del desmayo disparan una sacudida tardia, por orden.
## No todos: siete seguidas pareceria que sigue viva. Estos tres caen a los
## 5,1, 6,9 y 7,5 s. Mas alla de los 8 el desenfoque del desmayo ya borra
## cualquier movimiento, asi que animar ahi no lo ve nadie.
@export var death_blink_twitches: PackedInt32Array = [0, 2, 3]
## Segundos tras arrancar el parpadeo. No cierran del todo (bajan entre el 45 y
## el 75 %) y duran 0,3-0,5 s, asi que a los 0,18 el parpado esta subiendo: es
## cuando mas sobresalta ver moverse algo que dabas por muerto.
@export var blink_twitch_delay: float = 0.18
@export var blink_twitch_amount: float = 0.20
@export var blink_twitch_width: float = 0.35
## Cada sacudida es MAS fuerte que la anterior, no mas floja. El desenfoque del
## desmayo crece con el tiempo (radio de 11 px a los 5,5 s y de 22 a los 7,7), y
## un movimiento por debajo de ese radio no se percibe: para seguir viendose, la
## sacudida tiene que crecer al mismo ritmo que lo que la tapa.
@export var death_blink_ramp: float = 1.3
## Las patas acompañan la sacudida, pero menos: ya estan rigidas. Aun asi el
## tramo de tibia es corto, asi que por debajo de esto tampoco vence al borroso.
@export var death_leg_blink_ratio: float = 0.6
## Espasmos secos encima del barrido, en segundos desde el golpe. Los dos
## latigos van en sentidos opuestos: se lee como una convulsion, no como viento.
@export var death_spasm_times: PackedFloat32Array = [0.10, 0.34, 0.90, 1.8]
@export var death_spasm_amount: float = 0.22
@export var death_spasm_width: float = 0.18

var femur_rest: Dictionary = {}
var tibia_rest: Dictionary = {}
var leg_offsets: Array = []
var leg_side: Dictionary = {}
var leg_amp: Dictionary = {}
var speed_factor: float = 0.0
## Velocidad de suelo del ultimo frame y cadencia resultante (solo lectura).
var ground_speed: float = 0.0
var cadence_hz: float = 0.0
var leg_phase: float = 0.0
var body_length: float = 236.0
var _prev_global_pos := Vector2.ZERO
var walk_weight: float = 0.0
var offset_ant_l: float
var offset_ant_r: float
## Fase del ruido de las antenas. Se integra en vez de escalar time_passed: al
## multiplicar el tiempo por un factor que cambia (m), arrancar a andar saltaba a
## una zona del ruido sin relacion con la anterior y las antenas daban un
## latigazo, tanto mayor cuanto mas llevaba corriendo la escena.
var ant_phase: float = 0.0
var step_fade: Tween = null
var step_base_db: float = 0.0
## Reposo de las piezas que acompañan al cuerpo, para poder recolocarlas cada
## frame sin acumular deriva.
var body_rest_pos := Vector2.ZERO
var body_rest_scale := Vector2.ONE
var rim_rest_pos := Vector2.ZERO
var rim_rest_scale := Vector2.ONE
var ant_rest_l := Vector2.ZERO
var ant_rest_r := Vector2.ZERO
var ant_rest_scale_l := Vector2.ONE
var ant_rest_scale_r := Vector2.ONE
## El angulo de ruido de cada antena se guarda aparte de su rotacion final: si
## se suavizara sobre la rotacion ya girada por el cuerpo, se realimentaria.
var ant_l_angle: float = 0.0
var ant_r_angle: float = 0.0
var body_yaw: float = 0.0
var body_offset := Vector2.ZERO
var body_bob: float = 1.0
var body_lag: float = 0.0
var _prev_rotation: float = 0.0
## Negativo mientras esta viva; el golpe lo pone a cero y a partir de ahi cuenta.
var death_time: float = -1.0
## Las cuatro tibias traseras, creadas al morir.
var dead_legs: Array[Sprite2D] = []
## Momento de la proxima sacudida por parpadeo, y su fuerza. -1 = ninguna.
var blink_twitch_at: float = -1.0
var blink_twitch_gain: float = 1.0
var is_inside: bool = false
var was_walking: bool = false

var bg_sprite: Sprite2D
var bg_lum: Image
const BG_SCALE := 8
var candle_lights: Array = []

func _ready() -> void:
	add_to_group("squashable")
	_disable_2d_lights(self)
	noise.seed = randi()
	noise.frequency = 0.4
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	offset_ant_l = ant_l.rotation
	offset_ant_r = ant_r.rotation
	ant_phase = randf_range(0.0, 100.0)
	step_base_db = step_sound.volume_db
	ant_l_angle = offset_ant_l
	ant_r_angle = offset_ant_r
	ant_rest_l = ant_l.position
	ant_rest_r = ant_r.position
	ant_rest_scale_l = ant_l.scale
	ant_rest_scale_r = ant_r.scale
	body_rest_pos = body.position
	body_rest_scale = body.scale
	rim_rest_pos = rim_light.position
	rim_rest_scale = rim_light.scale
	_prev_rotation = rotation

	for f in femurs:
		if f:
			femur_rest[f] = f.rotation
			leg_offsets.append(randf_range(0.0, 100.0))
			# Una rotacion positiva adelanta una pata izquierda y atrasa una derecha:
			# el lado invierte el signo para que el tripode alterno sea real.
			var leg_name: String = f.get_parent().name
			leg_side[f] = -1.0 if leg_name.ends_with("R") else 1.0
			if leg_name.begins_with("LegFront"):
				leg_amp[f] = front_leg_swing_mult
			elif leg_name.begins_with("LegHind"):
				leg_amp[f] = hind_leg_swing_mult
			else:
				leg_amp[f] = 1.0
			var t = f.get_node_or_null("Tibia")
			if t:
				tibias[f] = t
				tibia_rest[t] = t.rotation

	_setup_background_light()
	body_length = body.region_rect.size.y * global_scale.y
	_prev_global_pos = global_position
	target_position = failsafe_point
	_enter_state(State.IDLE)

## Copia reducida del fondo para leer su luminancia, y las luces de las velas
## para tomar su parpadeo.
func _setup_background_light() -> void:
	var holder: Node = get_parent()
	if holder == null:
		return
	bg_sprite = holder.find_child("BackgroundImage", true, false) as Sprite2D
	if bg_sprite and bg_sprite.texture:
		var img: Image = bg_sprite.texture.get_image()
		if img:
			img = img.duplicate()
			if img.is_compressed():
				img.decompress()
			img.resize(maxi(1, img.get_width() / BG_SCALE), maxi(1, img.get_height() / BG_SCALE), Image.INTERPOLATE_BILINEAR)
			bg_lum = img
	candle_lights = holder.find_children("*", "PointLight2D", true, false)

func _bg_luminance(world: Vector2) -> float:
	if bg_lum == null:
		return 0.35
	var local = bg_sprite.to_local(world) + bg_sprite.texture.get_size() * 0.5
	var x = clampi(int(local.x / BG_SCALE), 0, bg_lum.get_width() - 1)
	var y = clampi(int(local.y / BG_SCALE), 0, bg_lum.get_height() - 1)
	return bg_lum.get_pixel(x, y).get_luminance()

## 0 = fondo oscuro tras la cucaracha, 1 = fondo brillante (velas, niebla clara).
func _background_light() -> float:
	var p = global_position
	var r = bg_sample_radius
	var l_avg = (_bg_luminance(p) * 2.0 + _bg_luminance(p + Vector2(-r, 0)) + _bg_luminance(p + Vector2(r, 0)) + _bg_luminance(p + Vector2(0, -r)) + _bg_luminance(p + Vector2(0, r))) / 6.0
	var light = smoothstep(bg_light_dark, bg_light_bright, l_avg)
	if flicker_influence > 0.0 and not candle_lights.is_empty():
		var nearest: PointLight2D = null
		var best = INF
		for l in candle_lights:
			var d = l.global_position.distance_squared_to(p)
			if d < best:
				best = d
				nearest = l
		if nearest:
			light *= lerp(1.0, clamp(nearest.energy / 0.5, 0.6, 1.4), flicker_influence)
	return clamp(light, 0.0, 1.0)

## La cucaracha simula su propia iluminacion con light_polygon; las luces 2D
## de las velas no le aportan nada y cuestan un pase por sprite.
func _disable_2d_lights(node: Node) -> void:
	if node is CanvasItem:
		node.light_mask = 0
	for c in node.get_children():
		_disable_2d_lights(c)

func _process(delta: float) -> void:
	if is_dead:
		_update_death_throes(delta)
		return
	time_passed += delta
	state_timer -= delta

	match current_state:
		State.IDLE, State.PAUSED:
			walk_weight = move_toward(walk_weight, 0.0, delta * 7.0)
			if state_timer <= 0:
				_enter_state(State.ROTATING)
		State.ROTATING:
			walk_weight = move_toward(walk_weight, 0.0, delta * 8.0)
			_process_rotating_logic(delta)
		State.WALKING:
			walk_weight = move_toward(walk_weight, 1.0, delta * 9.0)
			_process_movement_logic(delta)
			if state_timer <= 0:
				# Se le acaba el tiempo de huida sin llegar a la esquina: cuenta igual
				# que llegar. Antes el paron largo de panico salia o no segun la
				# geometria, porque solo se armaba en _arrive().
				if is_scared:
					corner_cooldown = true
				_enter_state(State.PAUSED)

	ground_speed = _prev_global_pos.distance_to(global_position) / maxf(delta, 0.0001)
	_prev_global_pos = global_position

	_update_all_legs_animation(delta)
	_update_body_motion(delta)
	_update_step_sound(delta)
	_process_antennae(delta)
	_update_visibility_logic()

func _update_step_sound(delta: float) -> void:
	var is_walking = current_state == State.WALKING and walk_weight > 0.3
	if is_walking:
		# El sample dura 1,4 s y las carreras de panico duran mas: se relanza al
		# acabarse. El AudioStreamRandomizer le cambia tono y volumen cada vez,
		# asi que no se oye el punto de union.
		if step_fade:
			_kill_step_fade()
		if not step_sound.playing:
			step_sound.volume_db = step_base_db
			step_sound.play()
	elif was_walking:
		_fade_step_out()
	if step_sound.playing:
		var target_pitch = clampf(cadence_hz / step_pitch_ref_hz, step_pitch_min, step_pitch_max)
		step_sound.pitch_scale = lerpf(step_sound.pitch_scale, target_pitch, 1.0 - exp(-8.0 * delta))
	was_walking = is_walking

func _kill_step_fade() -> void:
	if is_instance_valid(step_fade):
		step_fade.kill()
	step_fade = null
	step_sound.volume_db = step_base_db

func _fade_step_out() -> void:
	_kill_step_fade()
	step_fade = create_tween()
	step_fade.tween_property(step_sound, "volume_db", step_base_db - 24.0, step_fade_out)
	step_fade.tween_callback(step_sound.stop)
	step_fade.tween_callback(_on_step_fade_done)

func _on_step_fade_done() -> void:
	step_sound.volume_db = step_base_db
	step_fade = null

func _update_visibility_logic() -> void:
	var pos = global_position
	is_inside = Geometry2D.is_point_in_polygon(pos, light_polygon)
	var factor = 1.0 if is_inside else 0.0
	if not is_inside:
		var min_dist = 99999.0
		for i in range(light_polygon.size()):
			var p1 = light_polygon[i]
			var p2 = light_polygon[(i + 1) % light_polygon.size()]
			var closest = Geometry2D.get_closest_point_to_segment(pos, p1, p2)
			var d = pos.distance_to(closest)
			if d < min_dist:
				min_dist = d
		factor = 1.0 - clamp(min_dist / fade_margin, 0.0, 1.0)
	var smooth_factor = smoothstep(0.0, 1.0, factor)
	var brightness = lerp(brightness_min, brightness_max, _background_light())
	var lit = color_center * color_center_warmth * brightness
	lit.a = 1.0
	modulate = color_edge_fog.lerp(lit, smooth_factor)
	modulate.a = lerp(min_alpha_fog, 1.0, smooth_factor)

## Gira en el sitio solo lo justo; el resto del giro lo termina ya en marcha.
func _process_rotating_logic(delta: float) -> void:
	var speed_mod = 1.6 if is_scared else 1.0
	rotation = rotate_toward(rotation, target_rotation, turn_speed * speed_mod * delta)
	if abs(angle_difference(rotation, target_rotation)) < start_walk_angle:
		_enter_state(State.WALKING)

## Avanza en la direccion en la que mira mientras sigue corrigiendo el rumbo hacia el
## objetivo: la salida es un arco, no un giro seco y una recta. Rampa de arranque,
## frenada al llegar y un poco de ruido de rumbo. Nunca se pasa del objetivo.
func _process_movement_logic(delta: float) -> void:
	var to_target = target_position - global_position
	var dist = to_target.length()
	if dist < 0.001:
		_arrive()
		return
	var speed_mod = 1.6 if is_scared else 1.0
	var wander = noise.get_noise_1d(time_passed * 3.0 + 300.0) * heading_noise * clamp(dist / 200.0, 0.0, 1.0)
	var desired = to_target.angle() + PI / 2 + wander
	rotation = rotate_toward(rotation, desired, turn_speed * speed_mod * delta)
	speed_factor = move_toward(speed_factor, 1.0, delta / accel_time)
	var brake = clamp(dist / brake_distance, brake_min_factor, 1.0)
	var forward = Vector2.UP.rotated(rotation)
	var step = min(move_speed * speed_factor * brake * delta, dist)
	global_position += forward * step
	var remaining = target_position - global_position
	if remaining.length() < 8.0 or forward.dot(remaining) <= 0.0:
		if remaining.length() < 40.0:
			global_position = target_position
		_arrive()

func _arrive() -> void:
	if is_investigating and global_position.distance_to(last_impact_pos) < 30:
		arrived_at_impact = true
		global_position = last_impact_pos
	if is_scared:
		corner_cooldown = true
	_enter_state(State.PAUSED)

## La fase de las patas avanza con la velocidad de suelo, no con un reloj fijo:
## a 3,5 Hz constantes la cucaracha recorria casi 1,2 veces su cuerpo por zancada
## y parecia patinar. Ahora la zancada es siempre la misma distancia.
func _update_all_legs_animation(delta: float) -> void:
	var stride = stride_body_lengths * (stride_scared_mult if is_scared else 1.0)
	var stride_px = maxf(stride * body_length, 1.0)
	cadence_hz = clampf(ground_speed / stride_px, cadence_min_hz, cadence_max_hz)
	leg_phase += cadence_hz * TAU * delta
	var swing_mult = scared_swing_mult if is_scared else 1.0
	for i in range(femurs.size()):
		var f = femurs[i]
		if not f:
			continue
		var current_jitter = lerp(idle_jitter, walk_jitter, walk_weight)
		var jitter = noise.get_noise_1d((time_passed + leg_offsets[i]) * 25.0) * current_jitter
		# Tripode alterno: [FrontL, MidR, HindL] en fase 0 y [FrontR, MidL, HindR] en fase PI.
		var base_phase = 0.0 if i < 3 else PI
		var cycle = leg_phase + base_phase
		var wave = sin(cycle)
		var side: float = leg_side.get(f, 1.0)
		var amp: float = leg_amp.get(f, 1.0)
		f.rotation = femur_rest[f] + side * wave * femur_swing_amount * swing_mult * amp * walk_weight + jitter
		if tibias.has(f):
			var t = tibias[f]
			t.rotation = tibia_rest[t] + side * sin(cycle - 0.4) * tibia_flex_amount * swing_mult * amp * walk_weight + jitter * 0.5

## Movimiento del cuerpo sobre las patas. Todo va escalado por walk_weight menos
## el retardo de giro, que si se nota cuando gira parada en el sitio.
func _update_body_motion(delta: float) -> void:
	var ang_vel = angle_difference(_prev_rotation, rotation) / maxf(delta, 0.0001)
	_prev_rotation = rotation
	var lag_target = clampf(-ang_vel * body_turn_lag, -body_turn_lag_max, body_turn_lag_max)
	body_lag = lerpf(body_lag, lag_target, 1.0 - exp(-12.0 * delta))

	# En fase con el tripode: sin(leg_phase) es el mismo termino que mueve los
	# femures del tripode [FrontL, MidR, HindL].
	var sway = sin(leg_phase) * walk_weight
	body_yaw = sway * body_yaw_amount + body_lag
	body_offset = Vector2(sway * body_sway_amount, 0.0)
	# El rebote es una escala uniforme alrededor del centro del cuerpo, asi que
	# las piezas de alrededor tienen que escalar su posicion ademas de su tamaño;
	# si no, la base de las antenas se despega de la cabeza.
	body_bob = 1.0 + cos(leg_phase * 2.0) * body_bob_scale * walk_weight

	# Body y RimLight comparten region y se solapan: el mismo transformado a los
	# dos o el reflejo se despega de la silueta.
	body.rotation = body_yaw
	body.position = body_rest_pos.rotated(body_yaw) + body_offset
	body.scale = body_rest_scale * body_bob
	rim_light.rotation = body_yaw
	rim_light.position = rim_rest_pos.rotated(body_yaw) * body_bob + body_offset
	rim_light.scale = rim_rest_scale * body_bob

func _process_antennae(delta: float) -> void:
	var m = 1.0 + walk_weight * (2.8 if is_scared else 1.2)
	ant_phase += delta * 1.6 * m
	var n_l = noise.get_noise_1d(ant_phase)
	var n_r = noise.get_noise_1d(ant_phase + 72.0)
	# Suavizado exponencial: con delta * 14 el tembleque dependia de los FPS, y
	# por debajo de 14 el factor pasaba de 1 y las antenas se pasaban de largo.
	var t = 1.0 - exp(-14.0 * delta)
	ant_l_angle = lerp_angle(ant_l_angle, offset_ant_l + n_l * 0.7, t)
	ant_r_angle = lerp_angle(ant_r_angle, offset_ant_r + n_r * 0.7, t)
	# Nacen en la cabeza, asi que giran y se desplazan con el cuerpo. Body pivota
	# sobre el origen del nodo raiz, que es su centro, y las antenas orbitan ese
	# mismo punto: sin esto la base se despegaba ~2 px al balancearse.
	ant_l.rotation = ant_l_angle + body_yaw
	ant_r.rotation = ant_r_angle + body_yaw
	ant_l.position = ant_rest_l.rotated(body_yaw) * body_bob + body_offset
	ant_r.position = ant_rest_r.rotated(body_yaw) * body_bob + body_offset
	ant_l.scale = ant_rest_scale_l * body_bob
	ant_r.scale = ant_rest_scale_r * body_bob

func _enter_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.IDLE:
			state_timer = randf_range(idle_time_min, idle_time_max)
		State.ROTATING:
			_pick_new_target()
			var base_speed = randf_range(950, 1150)
			move_speed = base_speed * (1.9 if is_scared else 1.0)
			target_rotation = (target_position - global_position).angle() + PI / 2
		State.WALKING:
			speed_factor = 0.0
			state_timer = randf_range(0.4, 0.7) if is_investigating else (randf_range(0.8, 1.4) if is_scared else randf_range(0.5, 1.0))
		State.PAUSED:
			if corner_cooldown:
				state_timer = randf_range(4.0, 7.0)
				corner_cooldown = false
			elif arrived_at_impact:
				state_timer = randf_range(3.0, 6.0)
			elif is_investigating:
				state_timer = randf_range(0.4, 0.8)
			else:
				state_timer = randf_range(0.1, 0.3) if is_scared else randf_range(0.5, 1.5)
			if arrived_at_impact:
				is_investigating = false
			is_scared = false

func on_near_miss(impact_pos: Vector2) -> void:
	if is_dead:
		return
	is_scared = true
	is_investigating = false
	arrived_at_impact = false
	has_been_scared_once = true
	last_impact_pos = impact_pos
	_enter_state(State.ROTATING)

func _pick_new_target() -> void:
	if is_scared:
		var corners = [
			Vector2(bounds_min.x, bounds_min.y), Vector2(bounds_max.x, bounds_min.y),
			Vector2(bounds_min.x, bounds_max.y), Vector2(bounds_max.x, bounds_max.y)
		]
		var flee_dir := global_position - last_impact_pos
		flee_dir = flee_dir.normalized() if flee_dir.length() > 1.0 else Vector2.UP.rotated(rotation)
		corners.sort_custom(func(a, b): return _corner_score(a, flee_dir) > _corner_score(b, flee_dir))
		target_position = corners[0] if randf() < 0.7 else corners[1]
		return

	if has_been_scared_once and not arrived_at_impact:
		var dist_to_impact = global_position.distance_to(last_impact_pos)
		if dist_to_impact > 30:
			is_investigating = true
			var step_dist = min(dist_to_impact, randf_range(350, 500))
			var dir = (last_impact_pos - global_position).normalized()
			var timid_dir = dir.rotated(randf_range(-0.3, 0.3))
			var candidate = global_position + (timid_dir * step_dist)
			if _is_pos_valid(candidate):
				target_position = candidate
				return

	is_investigating = false
	for i in range(30):
		var ang = randf_range(0, TAU)
		var candidate = global_position + Vector2(cos(ang), sin(ang)) * randf_range(300, 600)
		if _is_pos_valid(candidate):
			target_position = candidate
			return
	target_position = failsafe_point

## Puntua una esquina para huir: lejos del impacto y, ademas, en la direccion
## contraria al golpe.
func _corner_score(corner: Vector2, flee_dir: Vector2) -> float:
	var to_corner := corner - global_position
	var align := 0.0
	if to_corner.length() > 1.0:
		align = to_corner.normalized().dot(flee_dir)
	return corner.distance_to(last_impact_pos) + align * corner_flee_bias

## Recoloca una antena viva sobre su pieza de la hoja del aplastado. El offset
## lleva el centro de giro a la raiz, asi que al girar la base no se despega de
## la cabeza. Son hermanas de Body, no hijas, de ahi el * DEAD_SCALE.
func _setup_dead_antenna(ant: Sprite2D, sheet: Texture2D, d: Dictionary) -> void:
	ant.texture = sheet
	ant.region_enabled = true
	ant.region_rect = d["region"]
	ant.offset = d["offset"]
	ant.position = (d["base"] - DEAD_BODY_REGION.size * 0.5) * DEAD_SCALE
	ant.scale = Vector2(DEAD_SCALE, DEAD_SCALE)
	ant.rotation = 0.0
	ant.visible = true

## Las tibias no existen mientras esta viva: se crean al morir y se cuelgan del
## nodo raiz, igual que las antenas, para heredar su giro pero no el del cuerpo.
func _make_dead_leg(sheet: Texture2D, d: Dictionary) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = sheet
	s.region_enabled = true
	s.region_rect = d["region"]
	s.offset = d["offset"]
	s.position = (d["base"] - DEAD_BODY_REGION.size * 0.5) * DEAD_SCALE
	s.scale = Vector2(DEAD_SCALE, DEAD_SCALE)
	s.light_mask = 0
	add_child(s)
	return s

## Coletazo: barrido de ruido que se apaga, con espasmos secos encima en los
## primeros segundos. Las dos antenas se mueven en sentidos opuestos durante el
## espasmo para que parezca una convulsion y no una corriente de aire.
func _update_death_throes(delta: float) -> void:
	if death_time < 0.0:
		return
	death_time += delta
	if death_time > death_total_time:
		ant_l.rotation = 0.0
		ant_r.rotation = 0.0
		for leg in dead_legs:
			leg.rotation = 0.0
		death_time = -1.0
		return
	var kl := 1.0 - clampf(death_time / death_twitch_time, 0.0, 1.0)
	var kr := 1.0 - clampf(death_time / (death_twitch_time * death_twitch_asymmetry), 0.0, 1.0)
	var env_l := kl * kl
	var env_r := kr * kr
	var spasm := 0.0
	for t in death_spasm_times:
		var u := death_time - t
		if u >= 0.0 and u < death_spasm_width:
			spasm += sin(u / death_spasm_width * PI) * death_spasm_amount
	# Barrido continuo con la amplitud modulada por ruido. Solo con ruido el
	# latigo se quedaba quieto la mayor parte del tiempo: Perlin pasa mucho mas
	# rato cerca de cero que cerca de su pico, y salian tirones sueltos.
	# Sacudida tardia enganchada a un parpadeo. Va aparte del estertor y con su
	# propia envolvente, para no alterar en nada los primeros segundos.
	var late := 0.0
	if blink_twitch_at >= 0.0:
		var bu := death_time - blink_twitch_at
		if bu >= blink_twitch_width:
			blink_twitch_at = -1.0
		elif bu >= 0.0:
			late = sin(bu / blink_twitch_width * PI) * blink_twitch_amount * blink_twitch_gain
	# Meneo lento de relevo: entra cuando el estertor se apaga (1 - kl) y se va
	# con el reloj maestro. La raiz hace que aguante en vez de caer en picado.
	var kt := 1.0 - clampf(death_time / death_total_time, 0.0, 1.0)
	var n_t := noise.get_noise_1d(death_time * 1.1 + 700.0) / NOISE_PEAK
	var tremor_env := death_idle_tremor * sqrt(kt) * (1.0 - kl)
	var tremor := sin(death_time * TAU * death_idle_hz + 0.9) * (0.5 + 0.5 * n_t) * tremor_env
	var n_l := noise.get_noise_1d(death_time * 3.0 + 500.0) / NOISE_PEAK
	var n_r := noise.get_noise_1d(death_time * 3.0 + 900.0) / NOISE_PEAK
	var w_l := sin(death_time * TAU * death_twitch_hz) * (0.55 + 0.45 * n_l)
	var w_r := sin(death_time * TAU * death_twitch_hz * 0.83 + 1.7) * (0.55 + 0.45 * n_r)
	ant_l.rotation = (w_l * death_twitch_amount + spasm) * env_l + late + tremor
	ant_r.rotation = (w_r * death_twitch_amount - spasm * 0.7) * env_r - late * 0.7 - tremor * 0.8

	# Las patas: mismo espasmo pero mas corto, mas rigido y en espejo entre lados.
	var kg := 1.0 - clampf(death_time / death_leg_time, 0.0, 1.0)
	var env_g := kg * kg * kg
	for i in dead_legs.size():
		var ph := float(i) * 1.7
		var side: float = DEAD_LEGS[i]["side"]
		var ng := noise.get_noise_1d(death_time * 2.5 + 120.0 * i + 40.0) / NOISE_PEAK
		var wg := sin(death_time * TAU * death_leg_hz + ph) * (0.45 + 0.55 * ng)
		dead_legs[i].rotation = (wg * death_leg_amount + spasm * side) * env_g + late * side * death_leg_blink_ratio

## Un parpadeo del desmayo. Solo algunos disparan sacudida, y cada una es mas
## floja que la anterior.
func _on_blackout_blink(index: int) -> void:
	if not is_dead or death_time < 0.0:
		return
	var k := death_blink_twitches.find(index)
	if k < 0:
		return
	blink_twitch_at = death_time + blink_twitch_delay
	blink_twitch_gain = pow(death_blink_ramp, float(k))

func _is_pos_valid(pos: Vector2) -> bool:
	return pos.x > bounds_min.x and pos.x < bounds_max.x and pos.y > bounds_min.y and pos.y < bounds_max.y

func die() -> void:
	if is_dead:
		return
	is_dead = true

	_kill_step_fade()
	step_sound.stop()
	step_sound.pitch_scale = 1.0
	step_sound.stream = squash_audio
	step_sound.volume_db = 10
	step_sound.play()

	# Partículas de impacto
	var spores = spore_scene.instantiate()
	get_parent().add_child(spores)
	spores.global_position = global_position
	
	var burst = spores.get_node_or_null("Burst")
	if burst:
		burst.emitting = true

	# Visual aplastado
	var sheet: Texture2D = load(DEAD_SHEET)
	body.rotation = 0.0
	body.position = body_rest_pos
	body.texture = sheet
	body.region_enabled = true
	body.region_rect = DEAD_BODY_REGION
	body.scale = Vector2(DEAD_SCALE, DEAD_SCALE)

	# Las antenas ya no se ocultan: son piezas sueltas de la misma hoja y se
	# quedan en pantalla dando el coletazo.
	_setup_dead_antenna(ant_l, sheet, DEAD_ANT_L)
	_setup_dead_antenna(ant_r, sheet, DEAD_ANT_R)
	for d in DEAD_LEGS:
		dead_legs.append(_make_dead_leg(sheet, d))
	death_time = 0.0

	shadow.visible = false
	rim_light.visible = false
	for f in femurs:
		f.visible = false

	# Efecto blackout - pasar posición de la cucaracha
	var blackout_script = load("res://scripts/blackout_controller.gd")
	var blackout_node = Node.new()
	blackout_node.set_script(blackout_script)
	blackout_node.name = "BlackoutController"
	get_tree().current_scene.add_child(blackout_node)
	if blackout_node.has_signal("blinked"):
		blackout_node.blinked.connect(_on_blackout_blink)
	blackout_node.start_blackout(global_position)

	emit_signal("died")
