extends Node2D
## El baculo del peregrino, que baja del cielo por el haz y se queda flotando.
## Dentro de la luz las cosas pesan poco: no cae, desciende como una pluma,
## meciendose de lado y enderezandose, y al llegar a su altura se queda
## suspendido con un vaiven lento. No es Magnus flotando como en el espacio:
## es un objeto ligero que el aire sostiene.
##
## Es el mismo baston que Magnus llevara a la espalda: se instancia su escena
## (scenes/dev/baston.tscn: madera, bola, halo y chispas) sin su script, que
## lo ata al Sprite de Magnus. Asi el aspecto sale de un solo sitio. Mientras
## flota, la bola esta apagada; encender() la enciende.
##
## Lo ilumina la misma luz que a Magnus (magnus_luz.gdshader).
##
##   bajar()          aparece arriba del todo y desciende; emite `posado`.
##   encender(color)  enciende la bola poco a poco.
##   vara()           los dos extremos de la vara, en la escena (para tocarlo).
##   alcanzado()      Magnus ha llegado a el subiendo por las hojas: de momento
##                    la bola late una vez (falta la animacion de cogerlo).
##
## 2026-10-11: sin el halo de la garra (la "luz extra en la punta"). 2026-10-12:
## baja ya con la bola encendida (sin chispas) y arriba del todo (y_flotar
## 200; era 130 y la bola casi se salia por arriba, y con el acercamiento de
## la camara del bosque, 1,05, otra vez): se llega subiendo por las hojas que
## bajan por la luz. Bola ambar
## (2026-10-12; era roja): "el color ambar que teniamos antes, el de la escena
## frontal" (el primero de los de prueba de baston.gd y prueba_frontal.gd).

signal posado

const BASTON := preload("res://scenes/dev/baston.tscn")

## Eje del haz (el de fondo_haz): de su vertice al suelo donde cae Magnus.
const HAZ_ORIGEN := Vector2(1620.0, -700.0)
const HAZ_DESTINO := Vector2(1456.0, 1200.0)

## Altura (y del centro) a la que se queda flotando, y cuanto tarda en bajar.
@export var y_flotar: float = 200.0
## 6,5 s: lo que dura la nota del hilo (caida_hojarasca.gd, SonidoHilo) antes
## de apagarse; baja en silencio, sin pensamiento.
@export var bajada: float = 6.5
## Vaiven al bajar: lo que se mece a cada lado al principio (px y rad) y cada
## cuanto (s); se va apagando hasta quedarse casi recto.
@export var meceo_px: float = 70.0
@export var meceo_rad: float = 0.32
@export var meceo_periodo: float = 4.2
## Flotando: arriba y abajo (px) y cada cuanto (s), y una inclinacion leve.
@export var flota_px: float = 10.0
@export var flota_periodo: float = 3.8
@export var inclinacion: float = 0.07
## Lo que tarda la bola en encenderse del todo (s), y su color.
@export var encendido: float = 1.6
@export var color_bola: Color = Color(1.0, 0.62, 0.18)
## Lo que se abre la luz de la bola en el destello al cogerlo (ver estallar).
@export var estallido_escala: float = 5.0

var _pivote: Node2D
var _baston: Node2D
var _orbe: Sprite2D
var _luz_orbe: Sprite2D
var _media_vara := 0.0    # media longitud de la madera (px)
var _t := 0.0
var _estado := 0          # 0 oculto, 1 bajando, 2 flotando, 3 cogido (ver coger)
var _y := 0.0             # altura sin el vaiven

func _ready() -> void:
	_pivote = Node2D.new()
	add_child(_pivote)
	_baston = BASTON.instantiate()
	_baston.set_script(null)   # sin el seguimiento de la espalda
	_baston.z_index = 0
	_pivote.add_child(_baston)
	var madera: Sprite2D = _baston.get_node("Madera")
	# La madera cuelga de su origen (su offset): se sube eso para que el baston
	# gire y se meza por su centro. Se lee de la escena del baston, que cambia.
	_baston.position = Vector2(0.0, -madera.offset.y)
	_media_vara = madera.texture.get_height() * 0.5 * absf(madera.scale.y)
	madera.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var luz := ShaderMaterial.new()
	luz.shader = preload("res://scripts/game/magnus_luz.gdshader")
	# No esta en el suelo: sin rebote de las hojas ni oclusion de pies. Borde de
	# luz fino: con el de Magnus (3 px) las puntas de la garra se encendian
	# enteras y, al girar, parpadeaban como puntitos.
	luz.set_shader_parameter(&"rebote_fuerza", 0.0)
	luz.set_shader_parameter(&"oclusion", 0.0)
	luz.set_shader_parameter(&"borde_px", 1.0)
	luz.set_shader_parameter(&"borde_fuerza", 0.3)
	madera.material = luz
	# La bola, apagada. Sus materiales se copian: los de la escena del baston
	# son compartidos y no hay que tocar el que lleve Magnus a la espalda.
	_orbe = madera.get_node("Orbe")
	_luz_orbe = madera.get_node("Luz")
	for s in [_orbe, _luz_orbe]:
		s.material = s.material.duplicate()
		(s.material as ShaderMaterial).set_shader_parameter("carga", 0.0)
		s.visible = false
	for nombre in ["Recarga", "Estallido", "Chispas"]:
		(madera.get_node(nombre) as CPUParticles2D).emitting = false
	visible = false

## x del eje del haz a una altura y.
static func x_haz(y: float) -> float:
	var t := (y - HAZ_ORIGEN.y) / (HAZ_DESTINO.y - HAZ_ORIGEN.y)
	return lerpf(HAZ_ORIGEN.x, HAZ_DESTINO.x, t)

## Donde esta la bola (en la garra), en coordenadas de la escena.
func punta() -> Vector2:
	return _orbe.global_position

func flotando() -> bool:
	return _estado == 2

func bajar() -> void:
	visible = true
	encender(color_bola, false)
	_estado = 1
	_t = 0.0
	_y = -300.0
	var tw := create_tween()
	tw.tween_property(self, "_y", y_flotar, bajada).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_estado = 2
		_t = 0.0
		posado.emit())

## Los dos extremos de la vara (arriba, abajo), en coordenadas de la escena.
func vara() -> Array:
	var eje := Vector2(0.0, _media_vara).rotated(_pivote.rotation)
	var centro := _pivote.global_position
	return [centro - eje, centro + eje]

## Magnus lo ha alcanzado: la bola late una vez (un destello que sube y se va).
func alcanzado() -> void:
	for s in [_orbe, _luz_orbe]:
		var m := s.material as ShaderMaterial
		var tw := create_tween()
		tw.tween_method(func(d: float) -> void: m.set_shader_parameter("destello", d), 0.0, 0.7, 0.18)
		tw.tween_method(func(d: float) -> void: m.set_shader_parameter("destello", d), 0.7, 0.0, 0.9) 			.set_trans(Tween.TRANS_SINE)

## Enciende la bola del color dado, de apagada a llena; con `efectos`, con su
## estallido y sus chispas.
func encender(color: Color, efectos := true) -> void:
	var v := Vector3(color.r, color.g, color.b)
	for s in [_orbe, _luz_orbe]:
		s.visible = true
		var m := s.material as ShaderMaterial
		m.set_shader_parameter("color", v)
		create_tween().tween_method(func(c: float) -> void: m.set_shader_parameter("carga", c),
			0.0, 1.0, encendido).set_trans(Tween.TRANS_SINE)
	if not efectos:
		return
	var madera: Node = _baston.get_node("Madera")
	for nombre in ["Estallido", "Chispas"]:
		var p := madera.get_node(nombre) as CPUParticles2D
		p.color = color.lightened(0.25)
	(madera.get_node("Estallido") as CPUParticles2D).restart()
	(madera.get_node("Chispas") as CPUParticles2D).emitting = true

## COGIDO (caida_hojarasca.gd, coger el baculo): la madera ya va en el dibujo
## de Magnus (el video del agarre); aqui queda solo la bola, que el nivel pone
## en la garra del dibujo (bola_en) y que se descarga (descargar) hasta quedar
## vacia: un cristal apagado con la brasa del fondo (orbe.gdshader, carga 0).
## Va delante de Magnus: detras, la cara la tapaba cuando la garra le pasa por
## delante.
func coger() -> void:
	_estado = 3
	_pivote.rotation = 0.0
	# toda la madera (tambien MaderaDelante y las fundas: si no, se veian dos
	# bastones); la bola y su luz, hijas de Madera, siguen
	for hijo in _baston.get_children():
		if hijo is Sprite2D:
			(hijo as Sprite2D).self_modulate.a = 0.0
	z_index = 1

## Al cogerlo, el destello de magia (el usuario: "el baston suelta un destello
## de magia"): la bola late (alcanzado) y su luz se abre de golpe y vuelve.
func estallar() -> void:
	alcanzado()
	var s0 := _luz_orbe.scale
	var tw := create_tween()
	tw.tween_property(_luz_orbe, "scale", s0 * estallido_escala, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_luz_orbe, "scale", s0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func bola_en(p: Vector2) -> void:
	global_position += p - _orbe.global_position

func descargar(duracion: float) -> void:
	for s in [_orbe, _luz_orbe]:
		var m := s.material as ShaderMaterial
		var c0: float = float(m.get_shader_parameter("carga"))
		create_tween().tween_method(func(c: float) -> void: m.set_shader_parameter("carga", c),
			c0, 0.0, duracion).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	if _estado == 0 or _estado == 3:
		return
	_t += delta
	var x_off := 0.0
	var rot := 0.0
	var y := _y
	if _estado == 1:
		# Se mece de lado como una pluma; el vaiven se apaga al acercarse.
		var queda := clampf(1.0 - _t / bajada, 0.0, 1.0)
		var w := TAU / meceo_periodo
		x_off = meceo_px * queda * sin(w * _t)
		rot = meceo_rad * queda * cos(w * _t) + inclinacion
	else:
		y += flota_px * sin(TAU * _t / flota_periodo)
		rot = inclinacion + 0.025 * sin(TAU * _t / (flota_periodo * 1.7))
	position = Vector2(x_haz(y) + x_off, y)
	_pivote.rotation = rot
