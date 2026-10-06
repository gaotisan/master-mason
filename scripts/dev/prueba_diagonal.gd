extends Node2D
## Prueba del andar en diagonal (andar_diagonal, de magnus_andar_diagonal), aparte
## del peregrino del juego: magnus.gd no se toca.
##   izquierda / derecha           anda de perfil (andar)
##   abajo + izquierda / derecha   anda en diagonal hacia la camara (andar_diagonal,
##                                 espejado a la izquierda) y crece con la cercania
##   arriba + izquierda / derecha  se aleja en diagonal: de momento con el mismo
##                                 ciclo al reves (falta un video de espaldas)
##   R                             vuelve al sitio de salida; Esc, sale
## La escala va con la fila del suelo: en la 1200 (la del juego) es 1.

const FRAMES := preload("res://resources/characters/magnus_frames.tres")
const SUELO_JUEGO := 1200.0
const FONDO_Y := 820.0          # fila mas lejana a la que se puede ir
const CERCA_Y := 1560.0         # fila mas cercana
const ESCALA_POR_PX := 0.0011   # cuanto crece por cada px que se acerca
const VELOCIDAD_PERFIL := 192.0 # la de andar del juego (6,4 px x 30 fps)
const VELOCIDAD_DIAGONAL := 150.0
const DIRECCION_DIAGONAL := Vector2(0.72, 0.69)   # hacia la camara y a la derecha

var _sprite: AnimatedSprite2D
var _salida := Vector2(900, SUELO_JUEGO)
var _modo := "reposo"


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	_sprite.offset = Vector2(0, -165)
	add_child(_sprite)
	position = Vector2.ZERO
	_sprite.position = _salida
	_poner("reposo")
	var ayuda := Label.new()
	ayuda.text = "PRUEBA DEL ANDAR EN DIAGONAL\n" + \
		"izquierda / derecha: de perfil\n" + \
		"abajo + izquierda / derecha: diagonal hacia la camara\n" + \
		"arriba + izquierda / derecha: diagonal alejandose (ciclo al reves, provisional)\n" + \
		"R: volver al sitio   Esc: salir"
	ayuda.position = Vector2(60, 50)
	ayuda.add_theme_font_size_override("font_size", 40)
	ayuda.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	add_child(ayuda)


func _poner(nombre: String, hacia_atras := false) -> void:
	if _sprite.animation != nombre or not _sprite.is_playing():
		if hacia_atras:
			_sprite.play_backwards(nombre)
		else:
			_sprite.play(nombre)
	_modo = nombre


func _escala(y: float) -> float:
	return clampf(1.0 + (y - SUELO_JUEGO) * ESCALA_POR_PX, 0.55, 1.45)


func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()
	if Input.is_key_pressed(KEY_R):
		_sprite.position = _salida
	var x := Input.get_axis("mover_izquierda", "mover_derecha")
	var abajo := Input.is_action_pressed("agacharse")
	var arriba := Input.is_action_pressed("saltar")
	var p := _sprite.position
	var s := _escala(p.y)
	if not is_zero_approx(x) and (abajo or arriba):
		var v := Vector2(DIRECCION_DIAGONAL.x * signf(x), DIRECCION_DIAGONAL.y * (1.0 if abajo else -1.0))
		p += v * VELOCIDAD_DIAGONAL * s * delta
		_sprite.flip_h = x < 0.0
		_poner("andar_diagonal", arriba)
	elif not is_zero_approx(x):
		p.x += signf(x) * VELOCIDAD_PERFIL * s * delta
		_sprite.flip_h = x < 0.0
		_poner("andar")
	else:
		if _modo == "andar_diagonal":
			_sprite.pause()          # quieto de tres cuartos, en el fotograma en que iba
		elif _modo != "reposo":
			_poner("reposo")
	p.x = clampf(p.x, 150.0, 2760.0)
	p.y = clampf(p.y, FONDO_Y, CERCA_Y)
	_sprite.position = p
	_sprite.scale = Vector2.ONE * _escala(p.y)
	_sprite.z_index = int(p.y)
	queue_redraw()


func _draw() -> void:
	# Fondo oscuro y un suelo con lineas de perspectiva, para que se lea la
	# profundidad.
	draw_rect(Rect2(0, 0, 2912, 1632), Color(0.08, 0.09, 0.11))
	draw_rect(Rect2(0, FONDO_Y - 40, 2912, 1632 - FONDO_Y + 40), Color(0.13, 0.12, 0.11))
	var fuga := Vector2(1456, FONDO_Y - 420)
	for i in range(-12, 13):
		var abajo := Vector2(1456 + i * 330, 1632)
		var t := (FONDO_Y - 40 - fuga.y) / (abajo.y - fuga.y)
		draw_line(fuga.lerp(abajo, t), abajo, Color(0.2, 0.19, 0.17), 2.0)
	for y in [FONDO_Y, 960.0, 1100.0, SUELO_JUEGO, 1350.0, 1500.0]:
		draw_line(Vector2(0, y), Vector2(2912, y), Color(0.2, 0.19, 0.17), 2.0)
	# sombra bajo los pies
	var s := _escala(_sprite.position.y) if _sprite else 1.0
	if _sprite:
		draw_set_transform(_sprite.position, 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, 70.0 * s, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
