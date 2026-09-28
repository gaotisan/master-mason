extends CharacterBody2D
## El peregrino en el vacio, con fisica de sueno. Controlador propio de la
## maqueta: reutiliza las animaciones de Magnus pero no su movimiento, que esta
## hecho para un suelo plano (su salto va grabado dentro del sprite y el nodo no
## sube). Aqui el nodo si sube, flota, pisa el aire y se posa en las losas.
##
## La posicion del nodo es donde pisa, como en Magnus.
## Capas: 1 = el agua del abismo (siempre solida), 2 = losas y suelos que ya
## estaban (de un solo sentido: sostienen desde arriba y se atraviesan desde
## abajo y de lado). Bajar (abajo o S) quita la capa 2 un momento.

signal cinematica_terminada
## Cada ~42 px andados con los pies en algo: el gestor de estelas pone o reaviva
## una losa bajo el pie (el borde se alarga contigo, asi que andando no te caes).
signal paso_sobre(pos: Vector2, direccion: float)
## Salto pedido en el aire: se crea una losa bajo el pie y se salta desde ella.
signal paso_en_aire(pos: Vector2)
signal aterrizo(pos: Vector2)

const FRAMES := preload("res://resources/characters/magnus_frames.tres")
const PASO_A := preload("res://assets/audio/magnus_paso_a.wav")
const PASO_B := preload("res://assets/audio/magnus_paso_b.wav")
const GOLPE := preload("res://assets/audio/magnus_caida_golpe.wav")
const LEVANTARSE := preload("res://assets/audio/magnus_levantarse.ogg")
## Pies del salto de parado sobre la linea de suelo, por sprite (copiado de
## magnus.gd): el sprite ya sube dentro de su casilla, asi que al usar sus poses
## en el aire hay que bajarlo eso para que los pies caigan en el nodo.
const PIES_SALTO := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 3, 6, 11, 17, 23, 29, 37, 45, 52, 58, 62, 65, 65, 64, 63, 61, 58, 55, 50, 45, 38, 31, 23, 15, 7, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
const OFFSET := -165.0

@export var velocidad: float = 192.0
## Px por fotograma de andar, el de Magnus: los pies no patinan.
@export var avance_andar: float = 6.4
## Fisica de sueno: un 35 % de la gravedad "normal" de la maqueta y caida lenta.
@export var gravedad: float = 900.0
@export var caida_max: float = 320.0
@export var impulso_salto: float = 790.0
@export var impulso_aire: float = 600.0
@export var espera_aire: float = 0.35
## Manteniendo el salto en lo alto, se queda suspendido hasta este tiempo.
@export var suspension: float = 0.45
@export var paso_losa: float = 42.0
## Altura maxima de los pies: la camara es fija y tiene que caber entero.
@export var techo: float = 340.0

var control := false
var pasos_en_aire := false
var crear_suelo := false
var sonar_pasos := false

var _mirando := 1.0
var _recorrido := 0.0
var _hasta_losa := 0.0
var _reloj := 0.0
var _t_aire := -99.0
var _suspendido := 0.0
var _bajando := 0.0
var _en_suelo_antes := true
var _cinematica := false
var _ultimo_fotograma := -1
var _f_aire := 20.0     # fotograma de salto_parado en el aire, se acerca poco a poco al que pide la velocidad
var _parando := false   # reproduciendo parada_andar

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _pasos: AudioStreamPlayer = $Pasos

static func crear() -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.name = "Peregrino"
	var spr := AnimatedSprite2D.new()
	spr.name = "Sprite"
	spr.sprite_frames = FRAMES
	spr.animation = &"reposo"
	spr.offset = Vector2(0, OFFSET)
	p.add_child(spr)
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(46, 230)
	forma.shape = rect
	forma.position = Vector2(0, -115)
	p.add_child(forma)
	var pasos := AudioStreamPlayer.new()
	pasos.name = "Pasos"
	pasos.volume_db = -12.0
	p.add_child(pasos)
	p.set_script(load("res://scripts/capitulo1/peregrino_sueno.gd"))
	return p

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	floor_snap_length = 6.0
	floor_max_angle = deg_to_rad(50)
	_sprite.play(&"reposo")

func _unhandled_input(evento: InputEvent) -> void:
	if not control or _cinematica:
		return
	if evento.is_action_pressed("saltar") and not evento.is_echo():
		_saltar()
	elif evento is InputEventKey and evento.pressed and not evento.echo \
			and (evento.keycode == KEY_DOWN or evento.keycode == KEY_S):
		if is_on_floor() and _suelo_es_losa():
			_bajando = 0.28
			collision_mask = 1
			position.y += 2.0

func _saltar() -> void:
	if is_on_floor():
		velocity.y = -impulso_salto
		_suspendido = suspension
	elif pasos_en_aire and _reloj - _t_aire >= espera_aire and global_position.y > techo + 60.0:
		_t_aire = _reloj
		paso_en_aire.emit(global_position)
		velocity.y = -impulso_aire
		_suspendido = suspension

func _physics_process(delta: float) -> void:
	_reloj += delta
	if _cinematica:
		return
	var direccion := Input.get_axis("mover_izquierda", "mover_derecha") if control else 0.0
	velocity.x = move_toward(velocity.x, direccion * velocidad, (1600.0 if is_on_floor() else 1000.0) * delta)
	if not is_on_floor():
		var g := gravedad
		if _suspendido > 0.0 and Input.is_action_pressed("saltar") and velocity.y > -140.0:
			g *= 0.08
			_suspendido -= delta
		velocity.y = minf(velocity.y + g * delta, caida_max)
	if _bajando > 0.0:
		_bajando -= delta
		if _bajando <= 0.0:
			collision_mask = 1 | 2
	var x0 := global_position.x
	move_and_slide()
	if global_position.y < techo:
		global_position.y = techo
		velocity.y = maxf(velocity.y, 0.0)
	var andado := absf(global_position.x - x0)
	var en_suelo := is_on_floor()
	if en_suelo and not _en_suelo_antes:
		aterrizo.emit(global_position)
		_hasta_losa = 0.0
	_en_suelo_antes = en_suelo
	if en_suelo and andado > 0.0 and crear_suelo:
		_hasta_losa -= andado
		if _hasta_losa <= 0.0:
			_hasta_losa = paso_losa
			paso_sobre.emit(global_position, signf(velocity.x))
	if direccion != 0.0:
		_mirando = signf(direccion)
		_sprite.flip_h = _mirando < 0.0
	_animar(andado, en_suelo)

func _animar(andado: float, en_suelo: bool) -> void:
	if en_suelo:
		if absf(velocity.x) > 15.0:
			_parando = false
			if _sprite.animation != &"andar":
				_sprite.animation = &"andar"
				_sprite.pause()
			_recorrido += andado
			var f := int(_recorrido / avance_andar) % _sprite.sprite_frames.get_frame_count(&"andar")
			if f != _sprite.frame:
				_sprite.frame = f
			if f != _ultimo_fotograma and (f == 0 or f == 16) and sonar_pasos:
				_pasos.stream = PASO_A if f == 0 else PASO_B
				_pasos.pitch_scale = randf_range(0.97, 1.03)
				_pasos.play()
			_ultimo_fotograma = f
		elif _sprite.animation == &"andar":
			# Al pararse, la parada de Magnus y luego reposo: sin saltar de pose.
			_parando = true
			_sprite.play(&"parada_andar")
		elif _parando and _sprite.animation == &"parada_andar" and _sprite.is_playing():
			pass
		elif _sprite.animation != &"reposo" or not _sprite.is_playing():
			_parando = false
			_sprite.play(&"reposo")
		_sprite.offset.y = OFFSET
		_f_aire = 20.0
	else:
		_parando = false
		if _sprite.animation != &"salto_parado":
			_sprite.animation = &"salto_parado"
			_sprite.pause()
		# La pose sigue a la velocidad vertical (encogido subiendo, erguido en lo
		# alto, estirandose al caer) y se acerca a ella de fotograma en fotograma.
		var objetivo := remap(clampf(velocity.y, -impulso_salto, caida_max), -impulso_salto, caida_max, 20.0, 40.0)
		_f_aire = move_toward(_f_aire, objetivo, 1.0)
		var f := int(round(_f_aire))
		_sprite.frame = f
		_sprite.offset.y = OFFSET + PIES_SALTO[f]

## Lo que tiene bajo los pies (una losa, un suelo que ya estaba, el agua) o null.
func suelo_actual() -> Object:
	if not is_on_floor():
		return null
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < -0.6:
			return c.get_collider()
	return null

func _suelo_es_losa() -> bool:
	var s := suelo_actual()
	return s != null and s is CollisionObject2D and (s.collision_layer & 2) != 0

func mirar_hacia(x: float) -> void:
	_mirando = signf(x - global_position.x) if x != global_position.x else _mirando
	_sprite.flip_h = _mirando < 0.0

## Entrada: cae despacio en el negro con los brazos arriba, se estampa contra un
## suelo que no se ve, se queda tumbado y se levanta. Sin control hasta el final.
func caer_en_el_vacio(desde_y: float, suelo_y: float, duracion: float) -> void:
	_cinematica = true
	control = false
	velocity = Vector2.ZERO
	position.y = desde_y
	_sprite.offset.y = OFFSET
	_sprite.play(&"cayendo")
	var tw := create_tween()
	tw.tween_property(self, "position:y", suelo_y, duracion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	_sprite.play(&"caida")
	_pasos.stream = GOLPE
	_pasos.volume_db = -6.0
	_pasos.play()
	await _sprite.animation_finished
	_sprite.play(&"tumbado")
	await get_tree().create_timer(1.6).timeout
	_sprite.play(&"levantarse")
	_pasos.stream = LEVANTARSE
	_pasos.volume_db = -10.0
	_pasos.play()
	await _sprite.animation_finished
	_pasos.volume_db = -12.0
	_sprite.play(&"reposo")
	_cinematica = false
	cinematica_terminada.emit()

## Tras el cierre del circulo la fisica se vuelve algo mas real: vuelve a pesar.
func volver_a_pesar(duracion: float) -> void:
	pasos_en_aire = false
	crear_suelo = false
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "gravedad", 1500.0, duracion)
	tw.tween_property(self, "caida_max", 900.0, duracion)
	tw.tween_property(self, "impulso_salto", 620.0, duracion)
	tw.tween_property(self, "suspension", 0.0, duracion)
