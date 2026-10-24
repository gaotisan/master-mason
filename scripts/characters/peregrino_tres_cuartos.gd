extends Node2D
## El peregrino en TRES CUARTOS: el plano del camino izquierdo del cruce, que cruza
## la pantalla en diagonal (de abajo a la derecha a arriba a la izquierda). Lo
## hace TODO en tres cuartos, sin el de frente: quieto respirando, arrancar,
## andar, pararse, darse la vuelta y correr (con el baculo guardado). Las
## animaciones salen de raw/master_builder/anim/peregrino_diagonal (montar.py y
## secuencia.py: videos de Flow 01-04, 07 y 08) en resources/characters/
## peregrino_diagonal.tres y la ficha assets/characters/peregrino/diagonal.json.
##
## El baculo no se saca ni se guarda aqui (no hay video de ese gesto en tres
## cuartos): llega como lo traia del cruce y asi sigue.
##
## LOS MANDOS: arriba o izquierda, por el camino hacia el fondo; abajo o derecha,
## hacia la camara (el camino va en diagonal: las dos teclas de cada lado valen).
## Dos toques, corre (sin el baculo en la mano). Las teclas que llegan pulsadas
## del cruce (TECLA RETENIDA) le hacen seguir hacia el fondo hasta soltarlas.
##
## DONDE VA: el camino es una curva en la foto (camino, por el centro de la arena,
## medido); los pies van por ella. La posicion es la distancia andada por el
## suelo (_s, en alturas de persona): la curva se pasa al suelo con la camara de
## la foto (horizonte, foco) y cada animacion avanza lo que avanzaba en su video
## (la ficha: "avance"), asi los pies no patinan. El tamano sale de la fila de los
## pies (alto = ALTO_POR_PIES x lo que estan bajo el horizonte, como el de frente).
##
## CORTES: volviendo hacia la camara hasta y_corte, `se_va` (corte al cruce, que le
## recibe por esta boca). Al fondo, en y_salida, `salida` (sigue andando, la
## escena funde a negro); antes se pierde en la niebla (y_niebla).
##
## PRUEBAS: sin `medio` (la escena de pruebas, scenes/dev/prueba_tres_cuartos.tscn)
## va sin la luz de la escena (colores del sprite tal cual) y la prueba le cambia el
## camino (poner_camino) y el modo del baculo (cambiar_baston) cuando quiere.
##
## LUZ: la de la escena (peregrino_camino.gdshader, como el de frente), con la de
## alrededor y, como minimo, rebote_suelo veces la arena que pisa; sombra de
## contacto y alargada apartandose del resplandor.

signal se_va
signal salida(cual: String)
signal al_mando
signal llego

const FRAMES := preload("res://resources/characters/peregrino_diagonal.tres")
const FICHA := "res://assets/characters/peregrino/diagonal.json"
const SHADER := preload("res://scripts/game/peregrino_camino.gdshader")
const Estado := preload("res://scripts/characters/peregrino_estado.gd")
const Imagenes := preload("res://scripts/game/imagenes_cache.gd")
const PANTALLA := Vector2(2912, 1632)
const ALTO_POR_PIES := 324.0 / 195.3
const DOBLE_TOQUE := 0.30
const PISADAS_HOJAS: Array[AudioStream] = [
	preload("res://assets/audio/hojarasca_paso_1.wav"), preload("res://assets/audio/hojarasca_paso_2.wav"),
	preload("res://assets/audio/hojarasca_paso_3.wav"), preload("res://assets/audio/hojarasca_paso_4.wav"),
	preload("res://assets/audio/hojarasca_paso_5.wav"), preload("res://assets/audio/hojarasca_paso_6.wav"),
	preload("res://assets/audio/hojarasca_paso_7.wav"), preload("res://assets/audio/hojarasca_paso_8.wav"),
	preload("res://assets/audio/hojarasca_paso_9.wav"), preload("res://assets/audio/hojarasca_paso_10.wav"),
	preload("res://assets/audio/hojarasca_paso_11.wav"), preload("res://assets/audio/hojarasca_paso_12.wav")]

@export var medio: Texture2D
@export var profundidad: Texture2D
## Si la escena de antes no dice nada.
@export var baston_en_mano := true

@export_group("Camino")
## El centro de la arena, de cerca (abajo) a lejos.
@export var camino := PackedVector2Array([Vector2(2006, 1640), Vector2(1984, 1590), Vector2(1950, 1540),
	Vector2(1906, 1490), Vector2(1852, 1440), Vector2(1788, 1390), Vector2(1716, 1340), Vector2(1637, 1290),
	Vector2(1550, 1240), Vector2(1458, 1190), Vector2(1360, 1140), Vector2(1257, 1090), Vector2(1151, 1040)])
## La camara de la foto: la fila del horizonte, el centro y el foco (px; ~54 grados).
@export var horizonte := 1000.0
@export var centro_x := 1456.0
@export var foco := 2857.0
## Filas de los pies: donde entra, donde corta volviendo, donde sale al fondo y la
## niebla del fondo (de y_niebla.x, entero, a y_niebla.y, todo niebla).
@export var y_entrada := 1470.0
## (con 1575 cortaba con el peregrino de ~950 px: mas grande que en ningun plano)
@export var y_corte := 1535.0
@export var y_salida := 1170.0
@export var y_niebla := Vector2(1205.0, 1150.0)

@export_group("Paso")
## Alturas de persona por fotograma (24 por segundo), andando y corriendo: el
## andar de los videos (0,0168 el 07; los demas, entre 0,009 y 0,025 por como se
## midieron: uno solo para todos).
@export var andar := 0.016
@export var correr := 0.037
## Lo que se acelera el giro respecto al video (en el video tarda ~2,5 s).
@export var giro_rapido := 2.0

@export_group("Luz")
@export var resplandor := Vector2(2420.0, 520.0)
@export var exposicion := 1.0
@export var saturacion := 0.65
@export var nitidez := 0.8
@export var rebote_suelo := 2.2
@export var luz_zona := 0.25
@export var sombra := 0.5
@export var sombra_larga := 0.22

@export_group("Sonido")
@export var pasos_db := -19.0
@export var pasos_alto_ref := 650.0

var controlador: Node

var _estado := "jugando"        # jugando / fuera / saliendo
var _cb := "reposo"             # reposo / arranque / andar / parada / a_vuelta / vuelta / a_vuelta_inv / vuelta_inv / de_vuelta / correr / a_correr / de_correr
var _cara := "lejos"            # lejos (de espaldas, hacia el fondo) / cerca (hacia la camara)
var _con_baston := true
var _magia := 0.0
var _magia_recarga := 0.0
var _s := 0.0
var _alto := 300.0
var _vista := 1.0
var _sprite: AnimatedSprite2D
var _ficha: Dictionary = {}
var _acum := 0.0
var _respira := 0                # posicion en la ida y vuelta del reposo
var _pose := 0                   # cual de las dos poses de reposo (pies juntos del ciclo)
var _sale_de_reposo := false
var _tabla_y := PackedFloat32Array()
var _tabla_s := PackedFloat32Array()
var _tabla_x := PackedFloat32Array()
var _reten: Array[String] = []
var _tecla_antes := ""
var _pulsado_en := {}
var _corriendo := false
var _mat: ShaderMaterial
var _medio: Image
var _prof: Image
var _sombra: Node2D
var _tex_sombra: Texture2D
var _pisada: AudioStreamPlayer2D
var _fondo_mat: ShaderMaterial
var _pies := Vector2.ZERO


func _ready() -> void:
	var e: Dictionary = Estado.leer(get_tree())
	_con_baston = bool(e.get("baston_en_mano", baston_en_mano))
	_magia = float(e.get("magia", 0.0))
	_magia_recarga = float(e.get("magia_recarga", 0.0))
	if e.is_empty():
		for a in OS.get_cmdline_user_args():
			if a in ["espalda", "mano"]:
				_con_baston = a == "mano"
	_ficha = JSON.parse_string(FileAccess.get_file_as_string(FICHA))
	for nombre in _ficha["anims"]:
		var d: Dictionary = _ficha["anims"][nombre]
		for clave in ["pisadas", "juntos"]:
			if d.has(clave):
				d[clave] = (d[clave] as Array).map(func(v): return int(v))
	if medio:
		_medio = Imagenes.de(medio)
	if profundidad:
		_prof = Imagenes.de(profundidad)
	_hacer_tabla()
	# sombra, material, sprite, pisadas
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
	_mat.set_shader_parameter("medio", medio)
	if _medio:
		material = _mat
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	_sprite.use_parent_material = true
	var cas: Array = _ficha["casilla"]
	_sprite.offset = Vector2(float(cas[0]) / 2.0 - float(_ficha["eje"]), float(cas[1]) / 2.0 - float(_ficha["suelo"]))
	add_child(_sprite)
	var r := AudioStreamRandomizer.new()
	for s in PISADAS_HOJAS:
		r.add_stream(-1, s)
	r.random_pitch = 1.08
	r.random_volume_offset_db = 2.0
	_pisada = AudioStreamPlayer2D.new()
	_pisada.stream = r
	_pisada.max_distance = 6000.0
	_pisada.attenuation = 0.5
	add_child(_pisada)
	# entra: del cruce andando hacia el fondo con la tecla retenida; si no, quieto
	_s = _s_de_y(y_entrada)
	for a in ["saltar", "agacharse", "mover_izquierda", "mover_derecha"]:
		if _pulsada(a):
			_reten.append(a)
	if not _reten.is_empty():
		_tecla_antes = "lejos"
		_poner("andar_lejos", int(_datos("andar_lejos")["juntos"][0]))
		_cb = "andar"
	else:
		_a_reposo(0)
	_colocar()
	al_mando.emit.call_deferred()


## Lo que la escena le dice al cortar a otra.
## Otro camino (pruebas): la tabla de nuevo y los pies donde estaban, en el nuevo.
func poner_camino(puntos: PackedVector2Array) -> void:
	var y := _suelo(_s).y
	camino = puntos
	_tabla_y.clear()
	_tabla_s.clear()
	_tabla_x.clear()
	_hacer_tabla()
	_s = _s_de_y(clampf(y, camino[camino.size() - 1].y + 1.0, camino[0].y))
	_colocar()


## Pruebas: del modo con baculo al de sin el (o al reves) de golpe, quieto (aqui no
## hay animacion de sacar ni guardar).
func cambiar_baston(si: bool) -> void:
	_con_baston = si
	_a_reposo(_pose)


## Vuelve al principio del camino, quieto de espaldas (pruebas).
func reiniciar(s := 0.0) -> void:
	_s = s
	_cara = "lejos"
	_estado = "jugando"
	_a_reposo(0)
	_colocar()


## Para el letrero de la prueba.
func info() -> Dictionary:
	return {"anim": String(_sprite.animation), "fotograma": _sprite.frame, "estado": _cb, "cara": _cara,
		"s": _s, "alto": _alto, "pies": _pies, "baston": _con_baston, "corriendo": _corriendo}


func dejar_estado(viene_de: String) -> void:
	Estado.dejar(get_tree(), _con_baston, _magia, _magia_recarga, viene_de)


func estado_reanudar() -> Dictionary:
	return {"fase": "camino_izquierdo", "peregrino": {"baston_en_mano": _con_baston}}


func controles_disponibles() -> Array:
	var lista := [
		{"acciones": [&"saltar", &"mover_izquierda"], "texto": "controles.hacia_fondo"},
		{"acciones": [&"agacharse", &"mover_derecha"], "texto": "controles.hacia_ti"},
	]
	if not _con_baston:
		lista[0]["nota"] = "controles.correr"
	return lista


# ------------------------------------------------------------------ el camino
## La curva pasada al suelo: para cada fila de pies, la x y la distancia andada.
func _hacer_tabla() -> void:
	var y := camino[0].y
	var X0 := 0.0
	var Z0 := 0.0
	var s := 0.0
	while y > camino[camino.size() - 1].y:
		var x := _x_en(y)
		var d := maxf(ALTO_POR_PIES * (y - horizonte), 1.0)
		var X := (x - centro_x) / d
		var Z := foco / d
		if _tabla_y.size() > 0:
			s += Vector2(X - X0, Z - Z0).length()
		X0 = X
		Z0 = Z
		_tabla_y.append(y)
		_tabla_x.append(x)
		_tabla_s.append(s)
		y -= 1.0


## La x del camino en la fila y (la curva entre los puntos).
func _x_en(y: float) -> float:
	for i in range(1, camino.size()):
		var b := camino[i]
		if y >= b.y:
			var a := camino[i - 1]
			var t := (a.y - y) / maxf(a.y - b.y, 0.001)
			var p0 := camino[maxi(i - 2, 0)]
			var p3 := camino[mini(i + 1, camino.size() - 1)]
			return Vector2(a.x, a.y).cubic_interpolate(Vector2(b.x, b.y), Vector2(p0.x, p0.y), Vector2(p3.x, p3.y), t).x
	return camino[camino.size() - 1].x


func _s_de_y(y: float) -> float:
	var i := clampi(int(_tabla_y[0] - y), 0, _tabla_s.size() - 1)
	return _tabla_s[i]


## Los pies en la foto para la distancia andada s.
func _suelo(s: float) -> Vector2:
	var n := _tabla_s.size()
	var lo := 0
	var hi := n - 1
	s = clampf(s, 0.0, _tabla_s[n - 1])
	while hi - lo > 1:
		var m := (lo + hi) / 2
		if _tabla_s[m] <= s:
			lo = m
		else:
			hi = m
	var t := (s - _tabla_s[lo]) / maxf(_tabla_s[hi] - _tabla_s[lo], 1e-5)
	return Vector2(lerpf(_tabla_x[lo], _tabla_x[hi], t), lerpf(_tabla_y[lo], _tabla_y[hi], t))


# ------------------------------------------------------------------ mandos
static func _pulsada(accion: String) -> bool:
	var tecla := {"saltar": KEY_UP, "agacharse": KEY_DOWN, "mover_izquierda": KEY_LEFT, "mover_derecha": KEY_RIGHT}
	return Input.is_action_pressed(accion) or Input.is_key_pressed(tecla[accion])


## "lejos", "cerca" o "".
func _quiere() -> String:
	if not _reten.is_empty():
		_reten = _reten.filter(func(a): return _pulsada(a))
		if not _reten.is_empty():
			return "lejos"
	if _estado == "saliendo":
		return "lejos"
	var lejos := _pulsada("saltar") or _pulsada("mover_izquierda")
	var cerca := _pulsada("agacharse") or _pulsada("mover_derecha")
	return "lejos" if lejos and not cerca else ("cerca" if cerca and not lejos else "")


# ------------------------------------------------------------------ animaciones
func _m() -> String:
	return "cb" if _con_baston else "sb"


func _nombre(base: String) -> String:
	return base + "_" + _m()


func _datos(base: String) -> Dictionary:
	return _ficha["anims"].get(_nombre(base), {})


func _poner(base: String, fotograma: int) -> void:
	_poner_n(_nombre(base), fotograma)


## Con el nombre entero (las paradas: parada_<cara>_<m>_<i>).
func _poner_n(n: String, fotograma: int) -> void:
	_sprite.animation = StringName(n)
	_sprite.frame = clampi(fotograma, 0, _sprite.sprite_frames.get_frame_count(n) - 1)
	_sprite.pause()


func _n() -> int:
	return _sprite.sprite_frames.get_frame_count(_sprite.animation)


func _anim() -> String:
	return String(_sprite.animation)


func _process(delta: float) -> void:
	var q := _quiere()
	# doble toque: correr (sin el baculo en la mano)
	if q != "" and q != _tecla_antes:
		_corriendo = (not _con_baston) and Time.get_ticks_msec() / 1000.0 - float(_pulsado_en.get(q, -10.0)) <= DOBLE_TOQUE
		_pulsado_en[q] = Time.get_ticks_msec() / 1000.0
	elif q == "":
		_corriendo = false
	_tecla_antes = q
	var fps := float(_ficha["fps_reposo"]) if _cb == "reposo" and not _sale_de_reposo else float(_ficha["fps"])
	if _cb in ["a_vuelta", "a_vuelta_inv", "vuelta_inv", "de_vuelta"] or (_cb == "vuelta" and _sprite.frame < int(_datos("vuelta")["inv"])):
		fps *= giro_rapido
	_acum += delta * fps
	while _acum >= 1.0:
		_acum -= 1.0
		_paso(q)
	_cortes()
	_colocar()


## Quieto en la pose de pies juntos i (0 o 1) de la cara de ahora.
func _a_reposo(i: int) -> void:
	_cb = "reposo"
	_pose = i
	_respira = 0
	_poner_n("reposo_%s_%s_%d" % [_cara, _m(), i], 0)


## Un fotograma de animacion (a los fps del video).
## QUIETO EN DIAGONAL: el reposo es una de las dos poses de pies juntos del bucle
## (de tres cuartos, como anda), asi que al soltar termina el medio paso con el
## propio bucle y se queda ahi respirando; arranca por los fotogramas que siguen.
## La vuelta empieza en su fotograma mas parecido al reposo de espaldas (con un
## puente corto); acabado el giro, si no se anda, al reposo de cara. El giro va a
## giro_rapido veces el video (en el video tarda ~2,5 s).
func _paso(q: String) -> void:
	var lejos := _cara == "lejos"
	match _cb:
		"reposo":
			_sale_de_reposo = q != ""
			if q != "":
				if _respira > 0:
					_respira = maxi(_respira - 3, 0)
					_sprite.frame = _respira
					return
				_sale_de_reposo = false
				if q == _cara:
					_cb = "arranque"
					_poner_n("arranque_%s_%s_%d" % [_cara, _m(), _pose], 0)
				elif lejos:
					_cb = "a_vuelta"
					_poner_n("a_vuelta_lejos_%s_%d" % [_m(), _pose], 0)
				else:
					_cb = "a_vuelta_inv"
					_poner_n("a_vuelta_cerca_%s_%d" % [_m(), _pose], 0)
				return
			var k := _n()
			_respira = (_respira + 1) % (2 * k - 2)
			_sprite.frame = _respira if _respira < k else 2 * k - 2 - _respira
		"arranque":
			_avanzar(+1.0 if lejos else -1.0, _perfil(_anim()))
			if _sprite.frame + 1 >= _n():
				_cb = "andar"
				_poner("andar_" + _cara, int(_ficha["anims"][_anim()]["entra"]))
				return
			_sprite.frame += 1
		"andar":
			var d := _datos("andar_" + _cara)
			_avanzar(+1.0 if lejos else -1.0, andar)
			var juntos: Array = d["juntos"]
			var f := _sprite.frame
			if q == _cara and _corriendo and not _con_baston and f == int(juntos[0]):
				_cb = "a_correr"
				_poner("a_correr_" + _cara, 0)
				return
			if q != _cara and _ficha["anims"].has("parada_%s_%s" % [_cara, _m()]):
				# la parada de verdad del video: entra en su cola por la fase del paso,
				# acaba de andar, frena y se queda de pie
				var dp: Dictionary = _ficha["anims"]["parada_%s_%s" % [_cara, _m()]]
				_cb = "parada"
				_poner_n("parada_%s_%s" % [_cara, _m()], int(dp["entrada"][str((f + 1) % _n())]))
				return
			if q != _cara and f in juntos:
				# acabado el medio paso, en una pose de reposo: quieto
				_a_reposo(juntos.find(f))
				return
			_sprite.frame = (f + 1) % _n()
			_pisar(d)
		"parada":
			var dp: Dictionary = _ficha["anims"][_anim()]
			var av: Array = dp["avance"]
			var i := _sprite.frame
			_avanzar(+1.0 if lejos else -1.0, float(av[mini(i, av.size() - 1)]) * andar / float(dp["v_bucle"]))
			if q == _cara and i < int(dp["frena"]):
				# vuelve a andar antes de frenar: al bucle, por la misma fase
				_cb = "andar"
				_poner("andar_" + _cara, (i + 1 + int(dp["fase0"])) % _sprite.sprite_frames.get_frame_count(StringName(_nombre("andar_" + _cara))))
				return
			if i + 1 >= _n():
				_a_reposo(0)
				return
			_sprite.frame = i + 1
			if i < int(dp["frena"]):
				_pisar(_datos("andar_" + _cara), (i + int(dp["fase0"])) % int(_datos("andar_" + _cara)["n"]))
		"a_vuelta":
			if _sprite.frame + 1 >= _n():
				_cb = "vuelta"
				_poner("vuelta", 0)
				return
			_sprite.frame += 1
		"vuelta":
			# de espaldas a andando hacia la camara; acabado el giro, sin tecla, quieto
			var dv := _datos("vuelta")
			var inv := int(dv["inv"])
			var av: Array = dv["avance"]
			_avanzar(-1.0, float(av[mini(_sprite.frame, av.size() - 1)]) * andar / 0.016)
			if _sprite.frame >= inv:
				_cara = "cerca"
				if q != "cerca":
					_cb = "de_vuelta"
					_poner("de_vuelta_cerca", 0)
					return
			if _sprite.frame + 1 >= _n():
				_cara = "cerca"
				_cb = "andar"
				_poner("andar_cerca", 0)
				return
			_sprite.frame += 1
		"a_vuelta_inv":
			if _sprite.frame + 1 >= _n():
				_cb = "vuelta_inv"
				_poner("vuelta", int(_datos("vuelta")["k1"]))
				return
			_sprite.frame += 1
		"vuelta_inv":
			# de cara a de espaldas: la vuelta al reves (solo el giro) y al reposo
			if _sprite.frame <= int(_datos("vuelta")["inv"]):
				_cara = "lejos"
			if _sprite.frame <= 0:
				_cara = "lejos"
				_cb = "de_vuelta"
				_poner("de_vuelta_lejos", 0)
				return
			_sprite.frame -= 1
		"de_vuelta":
			if _sprite.frame + 1 >= _n():
				_a_reposo(0)
				return
			_sprite.frame += 1
		"correr":
			var d := _datos("correr_" + _cara)
			_avanzar(+1.0 if lejos else -1.0, correr)
			var f := _sprite.frame
			if (q != _cara or not _corriendo) and f == int(d["juntos"][0]):
				_cb = "de_correr"
				_poner("de_correr_" + _cara, 0)
				return
			_sprite.frame = (f + 1) % _n()
			_pisar(d)
		"a_correr", "de_correr":
			var sale := _cb == "a_correr"
			_avanzar(+1.0 if lejos else -1.0, lerpf(andar, correr, 0.5))
			if _sprite.frame + 1 >= _n():
				var d := _datos(_anim().trim_suffix("_" + _m()))
				_cb = "correr" if sale else "andar"
				_poner(("correr_" if sale else "andar_") + _cara, int(d["entra"]))
				return
			_sprite.frame += 1


## El avance por fotograma de un arranque o una parada (su perfil de la ficha, la
## animacion por su nombre entero), por la velocidad de andar de aqui.
func _perfil(nombre: String) -> float:
	var d: Dictionary = _ficha["anims"].get(nombre, {})
	var av: Array = d.get("avance", [])
	if av.is_empty():
		return 0.0
	var v0 := float(_datos("andar_" + _cara)["avance"])
	return float(av[mini(_sprite.frame, av.size() - 1)]) / maxf(v0, 1e-4) * andar


func _avanzar(sentido: float, cuanto: float) -> void:
	_s = clampf(_s + sentido * cuanto, 0.0, _tabla_s[_tabla_s.size() - 1])


func _pisar(d: Dictionary, f := -1) -> void:
	if f < 0:
		f = _sprite.frame
	if f in d.get("pisadas", []):
		_pisada.position = _sprite.position
		_pisada.volume_db = pasos_db + linear_to_db(clampf(_alto / pasos_alto_ref, 0.03, 1.5) * maxf(_vista, 0.001))
		_pisada.play()
		if controlador and _alto > 400.0:
			var hojas := controlador.get_node_or_null("Hojas")
			if hojas and hojas.has_method("patear") and randf() < 0.6:
				hojas.patear(_suelo(_s), clampf(_alto / 650.0, 0.6, 1.4))


## Los cortes: hacia la camara, al cruce; al fondo, la salida.
func _cortes() -> void:
	if _estado != "jugando":
		return
	var y := _suelo(_s).y
	var andando := _cb in ["andar", "arranque", "correr", "a_correr", "de_correr", "vuelta"]
	if _cara == "cerca" and andando and y >= y_corte:
		_estado = "fuera"
		se_va.emit()
	elif _cara == "lejos" and y <= y_salida:
		_estado = "saliendo"
		salida.emit("fondo")


# ------------------------------------------------------------------ colocar y luz
func _colocar() -> void:
	var p := _suelo(_s)
	_alto = ALTO_POR_PIES * maxf(p.y - horizonte, 1.0)
	if controlador:
		p += controlador.paralaje(p, _w(p))
	_pies = p
	_sprite.position = p
	_sprite.scale = Vector2.ONE * _alto / float(_ficha["alto"])
	_vista = smoothstep(y_niebla.y, y_niebla.x, _suelo(_s).y)
	if controlador:
		var hojas := controlador.get_node_or_null("Hojas")
		if hojas and hojas.has_method("z_del_suelo"):
			hojas.corte = hojas.z_del_suelo(_suelo(_s).y)
	_luz()
	_sombra.queue_redraw()


func _w(p: Vector2) -> float:
	if _prof == null:
		return 0.0
	var x := clampi(int(p.x / PANTALLA.x * _prof.get_width()), 0, _prof.get_width() - 1)
	var y := clampi(int(p.y / PANTALLA.y * _prof.get_height()), 0, _prof.get_height() - 1)
	return _prof.get_pixel(x, y).r


func _luz() -> void:
	if _medio == null:
		return
	if controlador and _fondo_mat == null:
		_fondo_mat = controlador.get_node("Fondo").material
		_mat.set_shader_parameter("aire", controlador.get_node("AireVista").get_texture())
	var raiz := get_parent() as Node2D
	_mat.set_shader_parameter("origen", raiz.global_position)
	_mat.set_shader_parameter("sobre", raiz.global_scale.x)
	_mat.set_shader_parameter("px_por_texel", _sprite.scale.x * raiz.global_scale.x)
	_mat.set_shader_parameter("pies_y", _pies.y)
	_mat.set_shader_parameter("bruma_alto", _alto * 0.07)
	_mat.set_shader_parameter("bruma_pies", 0.0)
	_mat.set_shader_parameter("ambiente", _ambiente(_pies, _alto))
	_mat.set_shader_parameter("exposicion", exposicion)
	_mat.set_shader_parameter("saturacion", saturacion)
	_mat.set_shader_parameter("contraste_luces", 0.85)
	_mat.set_shader_parameter("suavizar_px", 0.6)
	_mat.set_shader_parameter("nitidez", nitidez)
	_mat.set_shader_parameter("niebla", 0.0)
	_mat.set_shader_parameter("aire_delante", lerpf(1.0, 0.35, clampf(inverse_lerp(250.0, 800.0, _alto), 0.0, 1.0)))
	_mat.set_shader_parameter("vista", _vista)
	_mat.set_shader_parameter("resplandor", resplandor)
	_mat.set_shader_parameter("luz_zona", luz_zona)
	if _fondo_mat:
		for n in ["rayos_fuerza", "luz_fuerza", "color_luz"]:
			var v = _fondo_mat.get_shader_parameter(n)
			if v != null:
				_mat.set_shader_parameter(n, v)


func _muestra(p: Vector2) -> Color:
	var x := clampi(int(p.x / PANTALLA.x * _medio.get_width()), 0, _medio.get_width() - 1)
	var y := clampi(int(p.y / PANTALLA.y * _medio.get_height()), 0, _medio.get_height() - 1)
	return _medio.get_pixel(x, y)


## La luz de alrededor y, como minimo, rebote_suelo veces la arena que pisa.
func _ambiente(pies: Vector2, alto: float) -> Color:
	var suma := Color(0, 0, 0)
	for i in 5:
		for j in 5:
			suma += _muestra(pies + Vector2((i - 2) * alto * 0.3, -alto * (j / 4.0)))
	var alrededor := Color(suma.r / 25.0, suma.g / 25.0, suma.b / 25.0)
	var s2 := Color(0, 0, 0)
	for i in 5:
		s2 += _muestra(pies + Vector2((i - 2) * alto * 0.12, alto * 0.03))
	var suelo := Color(s2.r / 5.0, s2.g / 5.0, s2.b / 5.0) * rebote_suelo
	return Color(maxf(alrededor.r, suelo.r), maxf(alrededor.g, suelo.g), maxf(alrededor.b, suelo.b))


func _dibujar_sombra() -> void:
	var p := _pies
	var a := smoothstep(0.3, 1.0, _vista)
	var ancho := _alto * 0.42
	_sombra.draw_texture_rect(_tex_sombra, Rect2(p - Vector2(ancho * 0.5, ancho * 0.07), Vector2(ancho, ancho * 0.14)),
		false, Color(0.02, 0.015, 0.01, sombra * a))
	if sombra_larga > 0.0:
		var largo := _alto * 0.32
		var ancho_l := _alto * 0.22
		var giro := clampf(Vector2.DOWN.angle_to(p - Vector2(resplandor.x, horizonte)), -1.05, 1.05)
		_sombra.draw_set_transform(p, giro, Vector2.ONE)
		_sombra.draw_texture_rect(_tex_sombra, Rect2(Vector2(-ancho_l * 0.5, -largo * 0.12), Vector2(ancho_l, largo)),
			false, Color(0.02, 0.015, 0.01, sombra_larga * a))
		_sombra.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
