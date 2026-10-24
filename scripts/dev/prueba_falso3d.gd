extends Node2D
## PRUEBA DE FALSO 3D (2026-10-22): el peregrino SIN BACULO andando libre por un suelo
## en perspectiva, en 8 direcciones, con lo que ya hay:
##   frente / espaldas    peregrino_frontal_hd.tres (andar y reposo _sb)
##   derecha / izquierda  peregrino_frames_limpio.tres (andar y reposo; la izquierda, espejo)
##   diagonales           la tercera tanda (raw/master_builder/anim/peregrino_falso3d,
##                        secuencia_v3.py): se (abajo a la derecha) y no (arriba a la
##                        izquierda), con arranque, parada, vuelta, correr y la esquina
##                        desde espaldas; so y ne, espejo
## La tunica con el color IGUALADO entre vistas (igualar.py, una copia:
## peregrino_falso3d_prueba.tres); C la cambia por la original.
## En diagonal cada animacion avanza lo que avanza en su video (falso3d.json: factor por
## fotograma), al ritmo del frontal (un paso cada PASO_FRONTAL s): sin que patinen.
## Al cambiar de direccion GIRA EN EL SITIO (2026-10-23): trozos de la vuelta del frontal
## (vuelta_sb, de frente a espaldas pasando por las diagonales; hacia el otro lado,
## espejada), de la pose base de una vista a la de la otra, y de ahi arranca. Solo darse
## la vuelta andando en diagonal usa los videos de la vuelta (03 y 04).
##   flechas / WASD   andar    Mayus   correr (en diagonal)    +/-  ritmo
##   C  color igualado / original    R  al centro    G  rejilla    Esc  salir
## No toca el juego.

## Alturas de persona por segundo de frente / espaldas y de perfil (el perfil: la del juego).
@export var velocidad_frontal := 0.3
@export var velocidad_perfil := 0.613
## Todo mas rapido o mas lento (animacion y avance a la vez: sin patinar).
@export var ritmo := 1.0
## Lo rapido que gira en el sitio (la vuelta a 24 por segundo, por esto).
@export var ritmo_giro := 1.4
## La camara, en alturas de persona: distancia a la linea mas cercana del suelo y altura.
@export var distancia := 3.2
@export var altura_camara := 0.85
## Alto en pantalla (fraccion de la ventana) en la linea mas cercana.
@export var alto_cerca := 0.5
## El suelo por donde se anda (alturas): x de -ancho a ancho, z de 0 (cerca) a fondo.
@export var ancho := 5.0
@export var fondo := 9.0

const IGUALADA := "res://resources/characters/peregrino_falso3d_prueba.tres"
const FICHA := "res://assets/characters/peregrino/falso3d.json"
## El paso del frontal (andar_frente_sb: 31 fotogramas a 24 por dos pasos).
const PASO_FRONTAL := 0.65
const FPS := 24.0
const HOJAS := {
	"frontal": ["res://resources/characters/peregrino_frontal_hd.tres",
		{"andar_s": "andar_frente_sb", "andar_n": "andar_espalda_sb", "reposo_s": "reposo_frente_sb", "reposo_n": "reposo_espalda_sb",
		"giro": "vuelta_sb"},
		291.0, 755.0, 633.0],
	"perfil": ["res://resources/characters/peregrino_frames_limpio.tres",
		{"andar_e": "andar", "reposo_e": "reposo"}, 143.0, 338.0, 313.0],
	"diagonal": ["res://resources/characters/peregrino_falso3d.tres", {}, 292.0, 757.0, 628.0],
}
## Por octavo (0 = derecha, en el sentido de las agujas en pantalla: 1 abajo-derecha,
## 2 abajo = de frente, ...): la clave de su animacion y si va en espejo.
const DIRS := [["e", false], ["se", false], ["s", false], ["se", true], ["e", true], ["no", false], ["n", false], ["no", true]]
## El octavo contrario de cada diagonal (la vuelta), con el mismo espejo.
const CONTRARIA := {1: 5, 5: 1, 3: 7, 7: 3}

## El fotograma de la vuelta (giro) que es la pose base de cada octavo (medido: el que mas
## se parece a su reposo); los del lado izquierdo (3, 4, 5) van espejados.
const GIRO_EN := {2: 2, 1: 15, 0: 28, 7: 42, 6: 54, 3: 15, 4: 28, 5: 42}

enum E { QUIETO, ARRANCA, ANDA, PARA, VUELTA, ESQUINA, CORRE, PARA_CORRER, GIRO }

var _sprite: AnimatedSprite2D
var _hoja_de := {}        # animacion -> [eje, pies, alto]
const INICIO := Vector2(0, 1.5)
var _pos := INICIO        # en el suelo: x, z (alturas)
var _dir := 2             # el octavo que se ve
var _quiere := 2          # al que va
var _t_giro := 0.0
var _estado := E.QUIETO
var _rejilla := true
var _info: Label
var _original: SpriteFrames
var _igualada: SpriteFrames
var _ficha := {}
var _tramos: Array = []     # el giro en curso: [[desde, hasta, espejo], ...]
var _t_tramo := 0.0
var _espejo_giro := false


func _ready() -> void:
	var f: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHA))
	_ficha = f["anims"] if f is Dictionary else {}
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for fam in HOJAS:
		var h: Array = HOJAS[fam]
		var src: SpriteFrames = load(h[0])
		var claves: Dictionary = h[1].duplicate()
		if claves.is_empty():
			for a in src.get_animation_names():
				claves[String(a)] = String(a)
		for clave in claves:
			var a: StringName = claves[clave]
			sf.add_animation(clave)
			sf.set_animation_speed(clave, src.get_animation_speed(a))
			for i in src.get_frame_count(a):
				sf.add_frame(clave, src.get_frame_texture(a, i), src.get_frame_duration(a, i))
			_hoja_de[StringName(clave)] = [h[2], h[3], h[4]]
	_original = sf
	_igualada = load(IGUALADA) if ResourceLoader.exists(IGUALADA) else sf
	for s in [_original, _igualada]:
		for a in s.get_animation_names():
			var n := String(a)
			s.set_animation_loop(a, n.begins_with("andar_") or n.begins_with("correr_") or n.begins_with("reposo_"))
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _igualada
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.animation_finished.connect(_al_acabar)
	add_child(_sprite)
	var capa := CanvasLayer.new()
	add_child(capa)
	_info = Label.new()
	_info.position = Vector2(40, 30)
	_info.add_theme_font_size_override("font_size", 30)
	_info.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 8)
	capa.add_child(_info)
	_poner("reposo_" + _clave(_dir))


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_ESCAPE: get_tree().quit()
		KEY_R: _pos = INICIO
		KEY_G:
			_rejilla = not _rejilla
			queue_redraw()
		KEY_C:
			var a := _sprite.animation
			var fr := _sprite.frame
			var pr := _sprite.frame_progress
			_sprite.sprite_frames = _original if _sprite.sprite_frames == _igualada else _igualada
			_sprite.play(a)
			_sprite.set_frame_and_progress(fr, pr)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: ritmo *= 1.1
		KEY_MINUS, KEY_KP_SUBTRACT: ritmo /= 1.1


## FALSO3D_DEMO=1 en el entorno: un recorrido solo (para grabarlo con --write-movie):
## [segundos, x, y de las flechas, corre].
const DEMO := [[1.0, 0, 0, 0], [3.0, 1, 1, 0], [2.0, 0, 0, 0], [2.0, 0, 1, 0], [2.0, 0, 0, 0], [3.0, -1, -1, 0], [2.0, 0, 0, 0],
	[2.5, 0, -1, 0], [2.0, 0, 0, 0], [3.0, 1, -1, 0], [2.0, 1, 0, 0], [2.0, 0, 0, 0], [2.5, -1, 1, 0], [2.0, 0, 0, 0]]
var _demo := OS.get_environment("FALSO3D_DEMO") != ""
var _t_demo := 0.0


func _flechas() -> Vector3:
	if _demo:
		var t := _t_demo
		for tramo in DEMO:
			if t < tramo[0]:
				return Vector3(tramo[1], tramo[2], tramo[3])
			t -= tramo[0]
		get_tree().quit()
		return Vector3.ZERO
	return Vector3(
		float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)),
		float(Input.is_key_pressed(KEY_SHIFT)))


func _diagonal(o: int) -> bool:
	return o % 2 == 1


func _clave(o: int) -> String:
	return DIRS[o][0]


func _process(delta: float) -> void:
	_t_demo += delta
	var f3 := _flechas()
	var v := Vector2(f3.x, f3.y)
	var anda := v != Vector2.ZERO
	var corre := f3.z > 0.5
	if anda:
		_quiere = posmod(roundi(v.angle() / (PI / 4.0)), 8)
	match _estado:
		E.QUIETO:
			if anda:
				if _quiere == _dir and _diagonal(_dir):
					_empezar(E.ARRANCA, "arranque_" + _clave(_dir))
				elif _dir == 6 and (_quiere == 5 or _quiere == 7):
					_dir = _quiere
					_empezar(E.ESQUINA, "esquina_n_no")
				elif _quiere == _dir:
					_estado = E.ANDA
					_poner("andar_" + _clave(_dir))
				else:
					_girar(_quiere)
		E.ANDA, E.CORRE:
			if not anda:
				if _diagonal(_dir):
					_parar("parada_correr_" if _estado == E.CORRE else "parada_")
				else:
					_estado = E.QUIETO
					_poner("reposo_" + _clave(_dir))
			elif CONTRARIA.get(_dir, -1) == _quiere and _estado == E.ANDA:
				var vu := "vuelta_%s_%s" % [_clave(_dir), _clave(_quiere)]
				_empezar(E.VUELTA, vu, int(_ficha.get(vu, {}).get("desde_reposo", 0)))
			elif _quiere != _dir:
				_girar(_quiere)
			elif _diagonal(_dir) and corre != (_estado == E.CORRE):
				_estado = E.CORRE if corre else E.ANDA
				_poner(("correr_" if corre else "andar_") + _clave(_dir), true)
		E.PARA, E.PARA_CORRER:
			if anda and _quiere == _dir:
				_estado = E.ANDA
				_poner("andar_" + _clave(_dir))
		E.GIRO:
			_avanzar_giro(delta, anda)
	_mover(delta)
	_colocar()


## Gira en el sitio hasta el octavo `hacia`, por el lado corto: un tramo de la vuelta por
## octavo (de la pose base de uno a la del siguiente).
func _girar(hacia: int) -> void:
	_tramos.clear()
	var o := _dir
	var d := posmod(hacia - o, 8)
	var paso := 1 if d <= 4 else -1
	while o != hacia:
		var o2 := posmod(o + paso, 8)
		var lado := o if o != 2 and o != 6 else o2
		_tramos.append([GIRO_EN[o], GIRO_EN[o2], lado in [3, 4, 5], o2])
		o = o2
	_estado = E.GIRO
	_t_tramo = 0.0
	_sprite.play(&"giro")
	_sprite.speed_scale = 0.0
	_avanzar_giro(0.0, true)


func _avanzar_giro(delta: float, anda: bool) -> void:
	if _tramos.is_empty():
		return
	var t: Array = _tramos[0]
	var n := absf(float(t[1]) - float(t[0]))
	_t_tramo += delta * 24.0 * ritmo_giro
	if _t_tramo >= n:
		_t_tramo -= n
		_dir = t[3]
		_tramos.pop_front()
		if _tramos.is_empty():
			# acabado: en la pose base; si sigue pulsado, arranca
			if anda and _quiere == _dir:
				if _diagonal(_dir):
					_empezar(E.ARRANCA, "arranque_" + _clave(_dir))
				else:
					_estado = E.ANDA
					_poner("andar_" + _clave(_dir))
			else:
				_estado = E.QUIETO
				_poner("reposo_" + _clave(_dir))
			return
		t = _tramos[0]
		n = absf(float(t[1]) - float(t[0]))
	_espejo_giro = t[2]
	var f := float(t[0]) + signf(float(t[1]) - float(t[0])) * minf(_t_tramo, n)
	_sprite.frame = clampi(roundi(f), 0, _sprite.sprite_frames.get_frame_count(&"giro") - 1)


func _empezar(e: int, anim: String, desde := 0) -> void:
	if not _sprite.sprite_frames.has_animation(anim):
		_estado = E.ANDA
		_poner("andar_" + _clave(_dir))
		return
	_estado = e
	_sprite.play(anim)
	_sprite.set_frame_and_progress(desde, 0.0)


## A la parada, entrando por la fase del paso en que vaya.
func _parar(prefijo: String) -> void:
	var p := prefijo + _clave(_dir)
	var datos: Dictionary = _ficha.get(p, {})
	var i := int(datos.get("entrada", {}).get(str(_sprite.frame), 0))
	_empezar(E.PARA_CORRER if prefijo.begins_with("parada_correr") else E.PARA, p, i)


func _al_acabar() -> void:
	var anim := String(_sprite.animation)
	match _estado:
		E.ARRANCA, E.ESQUINA:
			_estado = E.ANDA
			_poner("andar_" + _clave(_dir))
			_sprite.set_frame_and_progress(int(_ficha.get(anim, {}).get("entra", 0)), 0.0)
		E.VUELTA:
			_dir = CONTRARIA.get(_dir, _dir)
			_estado = E.ANDA
			_poner("andar_" + _clave(_dir))
			_sprite.set_frame_and_progress(int(_ficha.get(anim, {}).get("entra", 0)), 0.0)
		E.PARA, E.PARA_CORRER:
			_estado = E.QUIETO
			_poner("reposo_" + _clave(_dir))


## Pone una animacion (andando, en la misma fase del paso).
func _poner(a: String, con_fase := false) -> void:
	if not _sprite.sprite_frames.has_animation(a):
		return
	var fase := 0.0
	var n0 := _sprite.sprite_frames.get_frame_count(_sprite.animation) if _sprite.animation != &"" and _sprite.sprite_frames.has_animation(_sprite.animation) else 0
	if con_fase and n0 > 0:
		fase = (float(_sprite.frame) + _sprite.frame_progress) / float(n0)
	_sprite.play(a)
	var n := _sprite.sprite_frames.get_frame_count(a)
	_sprite.set_frame_and_progress(int(fase * n) % n, fmod(fase * n, 1.0))


## (alturas por segundo que anda la vista k, ritmo de su animacion).
func _natural(k: String, corriendo: bool) -> Vector2:
	if k == "e":
		return Vector2(velocidad_perfil, 1.0) * ritmo
	if k == "n" or k == "s":
		return Vector2(velocidad_frontal, 1.0) * ritmo
	var d: Dictionary = _ficha.get(("correr_" if corriendo else "andar_") + k, {})
	var r := 1.0
	if not corriendo:
		# al paso del frontal: un paso cada PASO_FRONTAL s (el periodo son dos pasos)
		r = (float(d.get("periodo", 30)) / 2.0 / FPS) / PASO_FRONTAL
	return Vector2(float(d.get("avance", 0.01)) * FPS * r, r) * ritmo


func _mover(delta: float) -> void:
	var nat := _natural(_clave(_dir), _estado in [E.CORRE, E.PARA_CORRER])
	if _estado != E.GIRO:
		_sprite.speed_scale = 1.0 if _sprite.animation.begins_with("reposo_") else nat.y
	var factor := 0.0
	var dir_mov := _dir
	match _estado:
		E.ANDA, E.CORRE:
			factor = 1.0
		E.ARRANCA, E.PARA, E.ESQUINA, E.VUELTA:
			var arr: Array = _ficha.get(String(_sprite.animation), {}).get("factor", [])
			if _sprite.frame < arr.size():
				factor = float(arr[_sprite.frame])
			if _estado == E.VUELTA:
				dir_mov = CONTRARIA.get(_dir, _dir)
		E.PARA_CORRER:
			var arr: Array = _ficha.get(String(_sprite.animation), {}).get("factor_correr", [])
			if _sprite.frame < arr.size():
				factor = float(arr[_sprite.frame])
	if factor <= 0.0:
		return
	var ang := dir_mov * PI / 4.0
	var paso := Vector2(cos(ang), sin(ang)) * nat.x * factor * delta
	_pos.y = clampf(_pos.y - paso.y, 0.0, fondo)
	var vs := get_viewport_rect().size
	var lim := minf(ancho, (distancia + _pos.y) * vs.x * 0.42 / (alto_cerca * vs.y * distancia))
	_pos.x = clampf(_pos.x + paso.x, -lim, lim)


func _proyectar(x: float, z: float) -> Vector2:
	var vs := get_viewport_rect().size
	var f := alto_cerca * vs.y * distancia
	var horizonte := vs.y * 0.9 - f * altura_camara / distancia
	return Vector2(vs.x * 0.5 + f * x / (distancia + z), horizonte + f * altura_camara / (distancia + z))


func _colocar() -> void:
	var vs := get_viewport_rect().size
	var f := alto_cerca * vs.y * distancia
	var alto_px := f / (distancia + _pos.y)
	var h: Array = _hoja_de.get(_sprite.animation, [292.0, 757.0, 628.0])
	var s := alto_px / float(h[2])
	var espejo: bool = _espejo_giro if _estado == E.GIRO else DIRS[_dir][1]
	_sprite.position = _proyectar(_pos.x, _pos.y)
	_sprite.offset = Vector2(-h[0], -h[1])
	_sprite.scale = Vector2(-s if espejo else s, s)
	if _demo:
		print("POS %d %.1f %.1f %.1f %s %d %d" % [Engine.get_process_frames(), _sprite.position.x, _sprite.position.y, s * float(h[2]), _sprite.animation, _dir, _sprite.frame])
	_info.text = "FALSO 3D (sin baculo)   %s%s  [%s]   color %s   ritmo x%.2f   [flechas/WASD, Mayus, +/-, C, R, G, Esc]" % [
		_sprite.animation, " (espejo)" if espejo else "", E.keys()[_estado], "IGUALADO" if _sprite.sprite_frames == _igualada else "original", ritmo]


func _draw() -> void:
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.13, 0.13, 0.15))
	var lejos := _proyectar(0, fondo).y
	draw_rect(Rect2(0, lejos, vs.x, vs.y - lejos), Color(0.24, 0.22, 0.2))
	if not _rejilla:
		return
	var c := Color(0.42, 0.38, 0.33)
	for i in int(fondo) + 1:
		draw_line(_proyectar(-ancho * 2, i), _proyectar(ancho * 2, i), c, 2.0)
	for i in range(-int(ancho * 2), int(ancho * 2) + 1):
		draw_line(_proyectar(i, 0), _proyectar(i, fondo), c, 2.0)
