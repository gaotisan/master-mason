extends Node2D
## Prueba del andar de frente y de espaldas, con y sin baston, y la vuelta entre
## ellos, aparte del peregrino del juego: magnus.gd no se toca.
##   abajo     anda hacia la camara (de frente) y crece con la cercania
##   arriba    se aleja (de espaldas) y encoge
##   suelto    termina el paso y se para con los pies juntos; sin baston,
##             ademas, parada y reposo respirando (con baston aun no hay)
##   B         saca / guarda el baston (de frente y parado, con su animacion;
##             si no, cambia de modo sin mas)
##   Z         camara: plano general / medio / primer plano (le sigue)
##   M         gastar un cuarto de magia (destello y estallido); C, otro color
##   R         vuelve al sitio de salida; Esc, sale
## guion: para grabarlo con --write-movie sin nadie al teclado, pasos
## [segundo, "abajo" | "arriba" | "", zoom(, con_baston)]; con guion se ignora
## el teclado.
##
## El avance va atado al fotograma: cada fotograma que pasa, el tamano cambia lo
## mismo que en el video (alli 1/alto es una recta en el tiempo, camara fija y
## paso constante), asi que los pies no patinan. La fila del suelo sale del
## tamano con el horizonte del propio video (baja).
##
## LA VUELTA: al cambiar de sentido da la vuelta en el sitio (vuelta_frontal
## con baston, vuelta_frontal_sin sin el; de espaldas a frente, la misma al
## reves) y sigue andando por el fotograma del otro andar contra el que se
## registro (ENGANCHE). Los videos redibujan la tunica a su manera: en cada
## enganche un fundido corto (FUNDIDO) tapa el cambio de textura.
##
## La bola del baston, como en el de perfil con el baston en la mano: la madera
## ya viene en el dibujo y la bola es la de scenes/dev/baston.tscn (orbe, luz,
## chispas) puesta por codigo, por detras del sprite, donde dice frontal.json
## (raw/master_mason/anim/baston/frontal.py): en el hueco de la garra.
## El baston del video de frente no tiene garra (acababa en pincho): en la hoja
## se le ha borrado el pincho y la garra (garra_frente.png, la del baston de
## Gemini) va aqui como capa encima del sprite, donde y con la inclinacion que
## dice frontal.json; la bola, detras, en su hueco. De espaldas y en la vuelta
## la garra ya viene en el dibujo. La bola es scenes/dev/baston.tscn sin su
## script (baston.gd va colgado de Magnus).

const FRAMES := preload("res://resources/characters/magnus_frames.tres")
const BASTON := preload("res://scenes/dev/baston.tscn")
const FRONTAL := "res://assets/characters/baston/frontal.json"
## Con baston: la secuencia de un solo video (reposo, arranque, andar, vuelta y
## puentes; raw/master_mason/anim/magnus_secuencia_frontal/secuencia.py).
const SECUENCIA := "res://assets/characters/magnus/secuencia_frontal.json"
## Sin baston: lo mismo de su propio video (sufijo _sb, puentes ps_), con el
## baston a la espalda en la funda de cuero.
const SECUENCIA_SIN := "res://assets/characters/magnus/secuencia_frontal_sin.json"
## Sacar y guardar el baston de frente, de un reposo al otro (videos de Flow con
## fotograma inicial y final sacados de esta escena; raw/master_mason/anim/
## magnus_sacar_baston_frente/animar.py): la bola sigue a la garra del video,
## filas [x, y, escala, giro].
const BASTON_FRENTE := "res://assets/characters/magnus/baston_frente.json"
const ORBE_EN_MADERA := Vector2(-0.6, -24)   # posicion del Orbe dentro de Madera
const COLORES: Array[Color] = [
	Color(1.0, 0.62, 0.18), Color(0.35, 0.75, 1.0), Color(0.55, 1.0, 0.45),
	Color(0.85, 0.45, 1.0), Color(1.0, 0.3, 0.25)]
const RECARGA := 0.05            # magia por segundo, como baston.gd

## Por andar: fps, cambio de 1/escala por fotograma y lo que baja el suelo por
## unidad de escala. Parejos: los ciclos de dos pasos duran 1,37 s y avanzan lo
## mismo (1/escala cambia 0,077 por ciclo); la escala de cada video (a que
## distancia esta la escala 1) depende de su camara, que no se conoce, y sea la
## que sea los pies no patinan. baja: suelo - horizonte es proporcional al
## tamano y cada video tiene la camara a su altura (ajuste.txt de cada job).
const ANDAR := {
	"andar_frente":      {"fps": 30.0, "paso": -0.077 / 41.0, "baja": 143.8},
	"andar_espalda":     {"fps": 21.2, "paso": 0.077 / 29.0, "baja": 155.3},
	"andar_frente_sin":  {"fps": 24.8, "paso": -0.077 / 34.0, "baja": 180.7},
	"andar_espalda_sin": {"fps": 21.2, "paso": 0.077 / 29.0, "baja": 157.1},
}
## Como en baston.gd: de espaldas la madera se corta 8 px bajo el pivote (el
## hombro) y el parche de tela tapa el corte.
## Lo que sujeta el baston a la espalda: la CORREA en diagonal con dos presillas
## (2026-10-10; el usuario eligio esta composicion de Gemini: la funda de tubo,
## funda_cuero, de espaldas quedaba "como un pegote"). raw/master_mason/anim/
## baston/correa.py: dos capas como la funda (la correa detras del baston, las
## presillas delante: el palo pasa por dentro) y correa.json.
const FUNDA := "res://assets/characters/baston/correa.json"
const FUNDA_ATRAS := "res://assets/characters/baston/correa_atras.png"
const FUNDA_DELANTE := "res://assets/characters/baston/correa_delante.png"
## La correa empieza este trecho bajo el pivote del baston (px de hoja, a lo
## largo del palo): justo bajo la capucha, donde sale en la imagen de Gemini.
const CORREA_INICIO := 22.0
## z de la bola, su luz y sus chispas: los de baston.tscn (relativos al baston)
## y, cuando la bola va delante del cuerpo, absolutos sobre el sprite (la bola
## en 2, como MaderaDelante, que va despues y le pone los dedos de la garra
## encima; la luz y las chispas por encima de todo).
const Z_BOLA_RELATIVO := {"Orbe": 0, "Luz": 2, "Recarga": 0, "Estallido": 0, "Chispas": 0}
const Z_BOLA_DELANTE := {"Orbe": 2, "Luz": 5, "Recarga": 5, "Estallido": 5, "Chispas": 5}
## Donde va el centro de la correa en el baston (px de hoja, ejes del nodo
## Baston sin girar): en el palo (x +1) y bajando desde CORREA_INICIO la mitad de
## su largo (correa.json). La fija _ready.
var _funda_en_baston := Vector2(1.0, 56.0)
const VUELTA := "vuelta_frontal"   # con baston; sin el, vuelta_frontal_sin
const VUELTA_FPS := 30.0
## Fotogramas de cada andar con los pies juntos (uno por paso, medio ciclo de
## separacion; medidos por la anchura y el desnivel de los pies y vistos a ojo):
## al soltar la tecla termina el paso hasta uno de ellos y se para ahi. El de
## frente con baston coincide con el enganche de su vuelta.
const PIES_JUNTOS := {"andar_frente": [4, 25], "andar_espalda": [13, 27],
	"andar_frente_sin": [23, 0], "andar_espalda_sin": [8, 23]}
## PARADA Y REPOSO (sin baston, como en el perfil: andar -> parada -> reposo).
## Al llegar a los pies juntos se pasa (con el fundido) a:
##   de frente: parada_frente_sin (da un par de pasitos acercandose y se asienta;
##     entra desde andar c_024 a 0,16, desde c_001 a 0,25) y al acabar
##     reposo_frente_sin por su fotograma 13 (casa a 0,022)
##   de espaldas: reposo_espalda_sin por el fotograma que mejor casa con cada
##     pies juntos (andar c_009 -> 50, c_024 -> 20)
## Desde ahi, la tecla de seguir de cara sale andando por el fotograma del andar
## que mejor casa (SALIDA); la otra, da la vuelta. Todo a 24 fps, los del video.
## (raw/master_mason/anim/magnus_reposo_frente_sin/montar.py y enganches.py)
const PARADA := {"andar_frente_sin": {23: ["parada_frente_sin", 0], 0: ["parada_frente_sin", 0]},
	"andar_espalda_sin": {8: ["reposo_espalda_sin", 50], 23: ["reposo_espalda_sin", 20]}}
const TRAS_PARADA := {"parada_frente_sin": ["reposo_frente_sin", 13]}
const QUIETO := {"parada_frente_sin": "frente", "reposo_frente_sin": "frente", "reposo_espalda_sin": "espalda"}
const SALIDA := {"frente": 23, "espalda": 8}
const QUIETO_FPS := 24.0
## LA VUELTA CON BASTON, SIN FUNDIDO: la vuelta es de otro video y un fundido
## de opacidad dejaba dos dibujos superpuestos (emborronado). Se entra y se sale
## por puentes de flujo optico (raw/master_mason/anim/magnus_puentes_frontal/
## puente.py), desde los pies juntos de cada andar: si va andando, termina el
## paso hasta uno de ellos (medio paso como mucho). Por andar, fotograma de
## pies juntos -> su puente hacia la vuelta.
const VUELTA_DESDE := {"andar_frente": {4: "puente_frente", 25: "puente_frente_b"},
	"andar_espalda": {13: "puente_espalda", 27: "puente_espalda_b"},
	"andar_frente_sin": {23: "puente_frente_sin", 0: "puente_frente_sin_b"},
	"andar_espalda_sin": {8: "puente_espalda_sin", 23: "puente_espalda_sin_b"}}
## Lo mismo desde la parada y el reposo sin baston (el reposo respira muy poco:
## desde cualquier fotograma se entra al puente sin que se note). La parada de
## frente se deja terminar: se entra cuando ya es reposo.
const VUELTA_DESDE_QUIETO := {"reposo_frente_sin": "puente_reposo_frente_sin",
	"reposo_espalda_sin": "puente_reposo_espalda_sin"}
## Cada puente: [extremo de la vuelta: "ini" o "fin", cara del otro extremo].
## Todos van de A a B como en puente.py; los que acaban en la vuelta se
## recorren hacia delante para entrar en ella y al reves para salir.
const PUENTE := {
	"puente_frente": ["ini", "frente"], "puente_frente_b": ["ini", "frente"],
	"puente_espalda": ["fin", "espalda"], "puente_espalda_b": ["fin", "espalda"],
	"puente_frente_sin": ["ini", "frente"], "puente_frente_sin_b": ["ini", "frente"],
	"puente_reposo_frente_sin": ["ini", "frente"],
	"puente_espalda_sin": ["fin", "espalda"], "puente_espalda_sin_b": ["fin", "espalda"],
	"puente_reposo_espalda_sin": ["fin", "espalda"]}
## Los puentes que van DE la vuelta A otra cosa (los demas van hacia ella).
const SALE_DE_VUELTA := ["puente_espalda", "puente_espalda_sin", "puente_reposo_espalda_sin"]
## Para salir de la vuelta: con tecla al andar, sin tecla al reposo (sin baston).
## [puente, animacion final, fotograma]
const SALIR := {
	"con": {"frente": {"andar": ["puente_frente", "andar_frente", 4]},
		"espalda": {"andar": ["puente_espalda", "andar_espalda", 13]}},
	"sin": {"frente": {"andar": ["puente_frente_sin", "andar_frente_sin", 23],
			"reposo": ["puente_reposo_frente_sin", "reposo_frente_sin", 13]},
		"espalda": {"andar": ["puente_espalda_sin", "andar_espalda_sin", 8],
			"reposo": ["puente_reposo_espalda_sin", "reposo_espalda_sin", 20]}}}
const REPOSO_TRAS_VUELTA := {"andar_frente_sin": ["reposo_frente_sin", 13], "andar_espalda_sin": ["reposo_espalda_sin", 20]}
## La parada de frente se acerca: lo que baja el suelo por unidad de escala en
## su video (suelo = 403,6 + 0,941 raiz, x OBJ 309 / 2).
const BAJA_PARADA := 145.4
## Fotograma de cada andar contra el que se registro su vuelta (montar.py de
## magnus_vuelta_frontal y magnus_vuelta_frontal_sin): por ahi se sale de ella.
const ENGANCHE := {"andar_frente": 4, "andar_espalda": 4, "andar_frente_sin": 14, "andar_espalda_sin": 3}
const FUNDIDO := 0.18            # s (a 0,12 aun se notaba el cambio de tunica al entrar)
const SUELO_SALIDA := 1200.0     # la fila del suelo del juego, con escala 1
const ESCALA_MIN := 0.45
const ESCALA_MAX := 2.6          # 2 = el master (que ya es el video x1,25)
const ZOOMS := [1.0, 1.6, 2.5]

@export var guion: Array = []

var _sprite: AnimatedSprite2D
var _fantasma: Sprite2D
var _camara: Camera2D
var _escala := 1.0
var _y := SUELO_SALIDA
var _acum := 0.0
var _zoom := 0
var _info: Label
var _t := 0.0
var _bola: Node2D
var _fondo: Node2D
var _funda_atras: Sprite2D
var _funda_delante: Sprite2D
var _funda_atras_f: Sprite2D      # copias de la funda delante del cuerpo
var _funda_delante_f: Sprite2D
var _funda_escala := 0.25         # la de funda_cuero.json
## Con el baston en la mano, la funda de cuero se queda VACIA en la espalda (como
## en el perfil): las mismas capas y la misma colocacion que con el baston
## guardado ("funda_espalda" de secuencia_frontal.json), en un nodo aparte (el
## de _bola va con la bola, en la garra). Se ve de espaldas y en la vuelta.
var _funda_vacia: Node2D
var _vacia: Dictionary = {}       # animacion con baston -> filas [x, y, giro, corte, ancho]
var _garra: Sprite2D
var _orbes: Dictionary = {}
var _espalda: Dictionary = {}   # baston a la espalda en las animaciones sin baston
var _magia := 1.0
var _mostrada := 1.0
var _destello := 0.0
var _color := 0
var _con_baston := true
var _cara := "frente"            # hacia donde mira: frente / espalda
var _girando := 0                # 0, +1 (frente -> espalda), -1 (al reves)
var _fundido := 0.0
var _andando := false            # venia andando: al soltar, termina el paso
var _relativa: Dictionary = {}   # cuanto crece cada fotograma de la parada (frontal.json)
var _base_parada := 1.0
var _quiere := ""
var _secuencia: Array = []       # tramos [animacion, desde, hasta] de la vuelta con baston
var _tras_secuencia: Array = []  # [cara, andar, fotograma] al acabar
var _cara_final := ""            # hacia donde mira al acabar la vuelta en curso
var _sec: Dictionary = {}        # la del modo actual (secuencia_frontal[_sin].json)
var _secs: Dictionary = {}       # true: con baston, false: sin
var _acciones: Dictionary = {}   # sacar_baston_frente / guardar_baston_frente: de, a, orbe
var _accion := ""                # la pedida con B, de frente y parado (empieza al acabar de espirar)
var _cb := "reposo"              # con baston: reposo / arranque / andar / puente / vuelta
var _cb_dir := 1                 # sentido de la vuelta en curso
var _cb_h0 := 1.0                # arranque: altura de video al entrar y escala entonces
var _cb_base := 1.0
var _bola_antes := Vector2.ZERO   # en los enganches la bola va de donde estaba a su sitio
var _garra_fundiendo := false     # y la garra pegada (andar_frente) se desvanece


func _ready() -> void:
	# el fondo en su nodo, bien al fondo: asi lo que va detras del personaje
	# (el baston a la espalda visto de frente) puede ir por debajo del sprite
	# sin quedar tambien por debajo del fondo
	_fondo = Node2D.new()
	_fondo.z_index = -10
	_fondo.draw.connect(_dibujar_fondo)
	add_child(_fondo)
	_orbes = JSON.parse_string(FileAccess.open(FRONTAL, FileAccess.READ).get_as_text())
	_espalda = _orbes.get("baston_espalda", {})
	_relativa = _orbes.get("escala_relativa", {})
	for con in [true, false]:
		var sec: Dictionary = JSON.parse_string(FileAccess.open(SECUENCIA if con else SECUENCIA_SIN, FileAccess.READ).get_as_text())
		for clave in ["pies_juntos"]:     # el JSON los da en float
			for nombre in sec[clave]:
				sec[clave][nombre] = sec[clave][nombre].map(func(v): return int(v))
		for nombre in sec["orbe"]:
			_orbes[nombre] = {"orbe": sec["orbe"][nombre], "escala_bola": sec["escala_bola"]}
		for nombre in sec.get("baston_espalda", {}):
			_espalda[nombre] = sec["baston_espalda"][nombre]
		for nombre in sec.get("funda_espalda", {}):
			_vacia[nombre] = sec["funda_espalda"][nombre]
		_secs[con] = sec
	_sec = _secs[true]
	if FileAccess.file_exists(BASTON_FRENTE):
		var bf: Dictionary = JSON.parse_string(FileAccess.open(BASTON_FRENTE, FileAccess.READ).get_as_text())
		for nombre in bf:
			if bf[nombre] is Dictionary and FRAMES.has_animation(nombre):
				_acciones[nombre] = bf[nombre]
				_orbes[nombre] = {"orbe": bf[nombre]["orbe"], "escala_bola": 1.0}
	# la bola, antes que el sprite: se dibuja detras (la garra le queda delante)
	_bola = BASTON.instantiate()
	_bola.set_script(null)
	_bola.z_index = 0
	add_child(_bola)
	# la funda de cuero, en dos capas pegadas al baston: atras (lenguetas e
	# interior de las bocas), la madera, delante (la pared del tubo)
	var fj: Dictionary = JSON.parse_string(FileAccess.open(FUNDA, FileAccess.READ).get_as_text())
	_funda_escala = float(fj["escala"])
	if fj.has("largo"):
		_funda_en_baston = Vector2(1.0, CORREA_INICIO + float(fj["largo"]) * _funda_escala / 2.0)
	_funda_atras =_capa_funda(FUNDA_ATRAS, fj, 0)
	_funda_delante = _capa_funda(FUNDA_DELANTE, fj, 2)
	# las copias de delante del cuerpo (z absolutos sobre el sprite, que va en 0):
	# funda de atras 1, madera 2 (MaderaDelante), funda de delante 3
	_funda_atras_f = _capa_funda(FUNDA_ATRAS, fj, 1, true)
	_funda_delante_f = _capa_funda(FUNDA_DELANTE, fj, 3, true)
	# la correa vacia (con el baston en la mano): plana y pegada a la espalda, asi
	# que va RECORTADA con la silueta del personaje (clip_children del sprite, mas
	# abajo, cuando existe): al girar no se sale del cuerpo (el usuario: de lado no
	# se ve, "esta pegada a la espalda"). La correa y encima las presillas.
	_funda_vacia = Node2D.new()
	_funda_vacia.visible = false
	for capa in [FUNDA_ATRAS, FUNDA_DELANTE]:
		var sp := _capa_funda(capa, fj, 0)
		_bola.remove_child(sp)
		_funda_vacia.add_child(sp)
		sp.visible = true
	var md := _bola.get_node("MaderaDelante") as Sprite2D
	md.z_as_relative = false
	md.z_index = 2
	md.visible = false
	_bola.get_node("Madera").self_modulate.a = 0.0
	_bola.get_node("Madera/Funda").modulate.a = 0.0
	_bola.get_node("Madera/Chispas").emitting = true
	_poner_color()
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	add_child(_sprite)
	_sprite.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_sprite.add_child(_funda_vacia)
	# el fotograma de antes, encima, desvaneciendose en los enganches
	_fantasma = Sprite2D.new()
	_fantasma.visible = false
	add_child(_fantasma)
	_poner_anim("reposo_frente_cb", 0)
	# la garra del de frente, encima del sprite (la bola le queda detras)
	_garra = Sprite2D.new()
	_garra.centered = false
	add_child(_garra)
	_camara = Camera2D.new()
	_camara.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(_camara)
	var capa := CanvasLayer.new()
	add_child(capa)
	var ayuda := Label.new()
	ayuda.text = "PRUEBA DEL ANDAR DE FRENTE / DE ESPALDAS\n" + \
		"abajo: hacia la camara (de frente)   arriba: alejandose (de espaldas)\n" + \
		"B: sacar / guardar el baston (de frente y parado; si no, cambia sin mas)   Z: plano general / medio / primer plano\n" + \
		"M: gastar magia   C: color\n" + \
		"R: volver al sitio   Esc: salir"
	ayuda.position = Vector2(60, 50)
	ayuda.add_theme_font_size_override("font_size", 40)
	ayuda.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	capa.add_child(ayuda)
	_info = Label.new()
	_info.position = Vector2(60, 1540)
	_info.add_theme_font_size_override("font_size", 32)
	_info.add_theme_color_override("font_color", Color(0.6, 0.58, 0.52))
	capa.add_child(_info)
	_colocar()


func _input(event: InputEvent) -> void:
	if not guion.is_empty() and (event is InputEventKey or event is InputEventMouse):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_ESCAPE: get_tree().quit()
		KEY_R:
			_escala = 1.0
			_y = SUELO_SALIDA
			_colocar()
		KEY_Z: _zoom = (_zoom + 1) % ZOOMS.size()
		KEY_B: _cambiar_baston(not _con_baston)
		KEY_M: _gastar(0.25)
		KEY_C:
			_color = (_color + 1) % COLORES.size()
			_poner_color()


func _andar_de(cara: String) -> String:
	return "andar_" + cara + ("" if _con_baston else "_sin")


## Cambia de animacion (y de casilla: la vuelta es mas alta), con fundido si se pide.
func _poner_anim(nombre: String, fotograma: int, fundir := false) -> void:
	if fundir:
		_fantasma.texture = _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
		_fantasma.offset = _sprite.offset
		_fundido = 1.0
		_bola_antes = _bola.position
		_garra_fundiendo = _garra.visible
	_sprite.animation = nombre
	_sprite.frame = fotograma
	_sprite.pause()
	var alto := _sprite.sprite_frames.get_frame_texture(nombre, 0).get_size().y
	_sprite.offset = Vector2(0, -(alto / 2.0 - 15.0))   # el suelo a 15 del borde, sea cual sea la casilla
	_acum = 0.0


func _cambiar_baston(si: bool) -> void:
	if si == _con_baston or _girando != 0 or not _secuencia.is_empty() or _cb in ["puente", "vuelta", "accion"]:
		return
	var accion := "sacar_baston_frente" if si else "guardar_baston_frente"
	if _cara == "frente" and _cb == "reposo" and _acciones.has(accion):
		# de frente y parado, con su animacion: empieza al acabar de espirar
		_accion = accion
		return
	_con_baston = si
	# de momento, de un modo al otro por el reposo de esa cara (sacar y guardar
	# el baston tendran su animacion)
	_andando = false
	_cb = "reposo"
	_sec = _secs[si]
	_poner_anim("reposo_%s%s" % [_cara, _suf()], 0, true)


func _gastar(cuanto: float) -> void:
	if _magia < cuanto:
		_destello = 0.25
		return
	_magia -= cuanto
	_destello = 1.0
	(_bola.get_node("Madera/Estallido") as CPUParticles2D).restart()


func _poner_color() -> void:
	var c: Color = COLORES[_color]
	for n in ["Madera/Orbe", "Madera/Luz"]:
		((_bola.get_node(n) as Sprite2D).material as ShaderMaterial).set_shader_parameter("color", Vector3(c.r, c.g, c.b))
	for n in ["Madera/Recarga", "Madera/Estallido", "Madera/Chispas"]:
		(_bola.get_node(n) as CPUParticles2D).color = c.lightened(0.25)


## La magia como en baston.gd: se recarga sola y la bola llega poco a poco.
func _magia_bola(delta: float) -> void:
	_magia = minf(1.0, _magia + RECARGA * delta)
	_mostrada = lerpf(_mostrada, _magia, 1.0 - exp(-4.0 * delta))
	_destello = move_toward(_destello, 0.0, 3.5 * delta)
	for n in ["Madera/Orbe", "Madera/Luz"]:
		var m := (_bola.get_node(n) as Sprite2D).material as ShaderMaterial
		m.set_shader_parameter("carga", _mostrada)
		m.set_shader_parameter("destello", _destello)
	(_bola.get_node("Madera/Recarga") as CPUParticles2D).emitting = _magia < 0.999
	(_bola.get_node("Madera/Chispas") as CPUParticles2D).emitting = _mostrada > 0.97


func _process(delta: float) -> void:
	var abajo := Input.is_action_pressed("agacharse") or Input.is_key_pressed(KEY_DOWN)
	var arriba := Input.is_action_pressed("saltar") or Input.is_key_pressed(KEY_UP)
	if not guion.is_empty():
		_t += delta
		var paso: Array = guion[0]
		for g in guion:
			if g[0] <= _t:
				paso = g
		abajo = paso[1] == "abajo"
		arriba = paso[1] == "arriba"
		_zoom = ZOOMS.find(float(paso[2]))
		if paso.size() > 3:
			_cambiar_baston(bool(paso[3]))
	var quiere := ""
	if abajo and not arriba:
		quiere = "frente"
	elif arriba and not abajo:
		quiere = "espalda"

	_quiere = quiere
	if true:
		# los dos modos con su secuencia de un solo video (lo de abajo es lo de
		# antes, con los andares y la vuelta de videos sueltos: ya no se usa)
		_cb_tick(delta, quiere)
	elif not _secuencia.is_empty():
		_seguir_secuencia(delta)
	elif _girando != 0:
		_seguir_vuelta(delta)
	elif quiere != "" and quiere != _cara and VUELTA_DESDE.has(String(_sprite.animation)):
		# con baston: a la vuelta por un puente, desde los pies juntos; si va
		# andando, termina antes el paso hasta ellos
		var anim := String(_sprite.animation)
		if VUELTA_DESDE[anim].has(_sprite.frame):
			_empezar_vuelta(VUELTA_DESDE[anim][_sprite.frame])
		else:
			_andar(anim, delta, true, VUELTA_DESDE[anim].keys())
	elif quiere != "" and quiere != _cara and VUELTA_DESDE_QUIETO.has(String(_sprite.animation)):
		_empezar_vuelta(VUELTA_DESDE_QUIETO[String(_sprite.animation)])
	elif quiere != "" and quiere != _cara:
		# a la vuelta: hacia delante de frente a espaldas, al reves si no
		_girando = 1 if quiere == "espalda" else -1
		var v := _vuelta()
		_poner_anim(v, 0 if _girando > 0 else _sprite.sprite_frames.get_frame_count(v) - 1, true)
	elif quiere != "":
		var anim := _andar_de(_cara)
		if (_cara == "frente" and _escala < ESCALA_MAX) or (_cara == "espalda" and _escala > ESCALA_MIN):
			if _sprite.animation != anim:
				# de la parada o el reposo, por el fotograma del andar que mejor casa
				_poner_anim(anim, SALIDA[_cara] if QUIETO.has(String(_sprite.animation)) else 0, true)
			_andar(anim, delta)
	elif _andando and ANDAR.has(String(_sprite.animation)):
		# soltada la tecla: termina el paso y se para con los pies juntos (al
		# acabar una vuelta no: la vuelta ya acaba de pie)
		if _sprite.frame in PIES_JUNTOS[String(_sprite.animation)]:
			_andando = false
		else:
			_andar(String(_sprite.animation), delta, true)
		if not _andando:
			_a_la_parada()
	elif QUIETO.has(String(_sprite.animation)):
		_seguir_quieto(delta)

	_fundido = move_toward(_fundido, 0.0, delta / FUNDIDO)
	_magia_bola(delta)
	_colocar()
	_info.text = "%s  fotograma %d   escala %.2f (2 = el master)   camara x%.1f   %s   magia %d%%" % [
		_sprite.animation, _sprite.frame, _escala, ZOOMS[_zoom],
		"con baston" if _con_baston else "sin baston", roundi(_magia * 100.0)]


## Fotogramas por tiempo, y el tamano con cada fotograma. Parando, hasta el
## siguiente fotograma con los pies juntos (PIES_JUNTOS) y ahi se queda.
func _andar(anim: String, delta: float, parando := false, hasta: Array = []) -> void:
	_andando = true
	var d: Dictionary = ANDAR[anim]
	_acum += delta * d["fps"]
	var n := _sprite.sprite_frames.get_frame_count(anim)
	var paradas: Array = hasta if not hasta.is_empty() else PIES_JUNTOS[anim]
	while _acum >= 1.0:
		_acum -= 1.0
		_sprite.frame = (_sprite.frame + 1) % n
		var antes := _escala
		_escala = clampf(1.0 / (1.0 / _escala + d["paso"]), ESCALA_MIN, ESCALA_MAX)
		_y += d["baja"] * (_escala - antes)
		if parando and _sprite.frame in paradas:
			_acum = 0.0
			_andando = false
			return


## Parado con los pies juntos: si hay parada / reposo para ese andar y ese
## fotograma (PARADA), se pasa a el.
func _a_la_parada() -> void:
	var p = PARADA.get(String(_sprite.animation), {}).get(_sprite.frame)
	if p != null:
		_poner_anim(p[0], p[1], true)
		_base_parada = _escala / _rel_parada(p[0], p[1])


func _rel_parada(anim: String, f: int) -> float:
	var r = _relativa.get(anim)
	return 1.0 if r == null else float(r[mini(f, r.size() - 1)])


## La parada (de una pasada, acercandose como en su video) y los reposos (en
## bucle), a su ritmo; al acabar la parada, el reposo.
func _seguir_quieto(delta: float) -> void:
	var anim := String(_sprite.animation)
	_acum += delta * QUIETO_FPS
	var n := _sprite.sprite_frames.get_frame_count(anim)
	while _acum >= 1.0:
		_acum -= 1.0
		if TRAS_PARADA.has(anim) and _sprite.frame + 1 >= n:
			var t: Array = TRAS_PARADA[anim]
			_poner_anim(t[0], t[1])     # casa a 0,022: sin fundido
			return
		_sprite.frame = (_sprite.frame + 1) % n
		if _relativa.has(anim):
			var antes := _escala
			_escala = _base_parada * _rel_parada(anim, _sprite.frame)
			_y += BAJA_PARADA * (_escala - antes)


## La vuelta con baston, sin fundidos: puente (flujo optico) -> vuelta ->
## puente -> el otro andar. De frente a espaldas, la vuelta hacia delante; al
## reves, hacia atras y los puentes del revés.
func _empezar_vuelta(p: String) -> void:
	var v := _vuelta()
	var nv := FRAMES.get_frame_count(v)
	var hacia_espalda: bool = PUENTE[p][0] == "ini"
	# el puente de entrada: hacia la vuelta (los que salen de ella, al reves)
	var entrada: Array = [p, 3, 0] if p in SALE_DE_VUELTA else [p, 0, 3]
	var giro: Array = [v, 0, nv - 1] if hacia_espalda else [v, nv - 1, 0]
	_secuencia = [entrada, giro]
	_girando = 1 if hacia_espalda else -1
	_cara_final = "espalda" if hacia_espalda else "frente"
	_andando = false
	_tramo_siguiente()


## Al acabar la vuelta: el puente de salida, segun haya tecla o no (se decide
## en ese momento, no al empezar).
func _salida_de_vuelta() -> void:
	var opciones: Dictionary = SALIR["con" if _con_baston else "sin"][_cara_final]
	var r: Array = opciones["andar"] if (_quiere == _cara_final or not opciones.has("reposo")) else opciones["reposo"]
	var p: String = r[0]
	_secuencia = [[p, 0, 3] if p in SALE_DE_VUELTA else [p, 3, 0]]
	_tras_secuencia = [_cara_final, r[1], r[2]]
	_tramo_siguiente()


func _tramo_siguiente() -> void:
	var t: Array = _secuencia[0]
	_poner_anim(t[0], t[1])


## Fotograma a fotograma a VUELTA_FPS por los tramos; al acabar, el otro andar
## por el fotograma con el que casa el ultimo puente (pies juntos: si no hay
## tecla, se queda ahi).
func _seguir_secuencia(delta: float) -> void:
	_acum += delta * VUELTA_FPS
	while _acum >= 1.0:
		_acum -= 1.0
		var t: Array = _secuencia[0]
		if _sprite.frame == t[2]:
			_secuencia.pop_front()
			if _secuencia.is_empty():
				if _girando != 0:
					_girando = 0
					_salida_de_vuelta()
					return
				_cara = _tras_secuencia[0]
				_poner_anim(_tras_secuencia[1], _tras_secuencia[2])
				_tras_secuencia = []
				return
			_tramo_siguiente()
		else:
			_sprite.frame += 1 if t[2] > t[1] else -1


## ---------------------------------------------------------------- con baston
## Todo a los 24 fps del video. Reposo (ida y vuelta) -> sale por SALIDAS ->
## puente -> arranque (crece / encoge como en el video) -> andar (bucle, 1/escala
## cambia "paso" por fotograma). Al soltar o pedir la otra cara: hasta los pies
## juntos y puente al reposo o a la vuelta. La vuelta, al acabar: con la tecla
## de esa cara, a andar; si no, puente al reposo.
func _cb_tick(delta: float, quiere: String) -> void:
	# el reposo respira a su ritmo (fps_reposo, 2,5 s por respiracion); para salir
	# de el, exhalando, y todo lo demas, a los fps del video
	var fps := float(_sec["fps"])
	if _cb == "reposo" and quiere == "" and _accion == "":
		fps = float(_sec["fps_reposo"])
	_acum += delta * fps
	while _acum >= 1.0:
		_acum -= 1.0
		_cb_paso(quiere)


func _suf() -> String:
	return "_cb" if _con_baston else "_sb"


func _pre() -> String:
	return "pt_" if _con_baston else "ps_"


func _otra(cara: String) -> String:
	return "espalda" if cara == "frente" else "frente"


func _cb_puente(nombre: String) -> void:
	_cb = "puente"
	_poner_anim(nombre, 0)


func _cb_paso(quiere: String) -> void:
	var anim := String(_sprite.animation)
	var n := _sprite.sprite_frames.get_frame_count(anim)
	var c := "f" if _cara == "frente" else "b"
	match _cb:
		"reposo":
			# un fotograma con la respiracion dibujada, ida y vuelta: la posicion p
			# es la inspiracion k (0 = el fotograma base, sin aire)
			var kk := int(_sec["k_reposo"])
			var k := _sprite.frame if _sprite.frame < kk else 2 * kk - 2 - _sprite.frame
			if _accion != "":
				# sacar / guardar: parten del fotograma base, como los puentes
				if k == 0:
					_empezar_accion()
				else:
					_sprite.frame = maxi(k - 3, 0)
				return
			if quiere != "":
				if k == 0:
					var pr: Dictionary = _sec["puente_reposo"][anim]
					_cb_puente(pr["arr"] if quiere == _cara else pr["vu"])
				else:
					_sprite.frame = maxi(k - 3, 0)     # exhala deprisa (0,2 s como mucho)
				return
			_sprite.frame = (_sprite.frame + 1) % n
		"arranque":
			if _sprite.frame + 1 >= n:
				var e: Array = _sec["entra_bucle"][anim]
				_poner_anim(e[0], int(e[1]))
				_cb = "andar"
				return
			_sprite.frame += 1
			var h: Array = _sec["h"][anim]
			_cb_escala(_cb_base * float(h[_sprite.frame]) / _cb_h0)
		"andar":
			var pj: Array = _sec["pies_juntos"][anim]
			if quiere != _cara and _sprite.frame in pj:
				if quiere == "":
					_cb_puente("%sa%s%d_r%s" % [_pre(), c, _sprite.frame, c])
				else:
					_cb_puente("%sa%s%d_vu" % [_pre(), c, _sprite.frame])
				return
			_sprite.frame = (_sprite.frame + 1) % n
			_cb_escala(1.0 / (1.0 / _escala + float(_sec["paso"][anim])))
		"puente":
			if _sprite.frame + 1 < n:
				_sprite.frame += 1
				return
			var a: Array = _sec["puentes"][anim]["a"]
			_poner_anim(a[0], int(a[1]))
			if String(a[0]).begins_with("vuelta"):
				_cb = "vuelta"
				_cb_dir = 1 if int(a[1]) == 0 else -1
			elif String(a[0]).begins_with("arranque"):
				_cb = "arranque"
				_cb_h0 = float(_sec["h"][a[0]][0])
				_cb_base = _escala
			else:
				_cb = "reposo"
		"accion":
			if _sprite.frame + 1 < n:
				_sprite.frame += 1
				return
			# acaba en el fotograma base del reposo del otro modo
			if anim.begins_with("guardar"):
				_con_baston = false
				_sec = _secs[false]
			_accion = ""
			_cb = "reposo"
			_poner_anim(String(_acciones[anim]["a"]), 0)
		"vuelta":
			var f := _sprite.frame + _cb_dir
			if f >= 0 and f < n:
				_sprite.frame = f
				return
			_cara = "espalda" if _cb_dir > 0 else "frente"
			if _cb_dir > 0:
				if quiere == "espalda":
					# 153 -> 154: seguido en el video
					_poner_anim("arranque_espalda" + _suf(), 0)
					_cb = "arranque"
					_cb_h0 = float(_sec["h"]["arranque_espalda" + _suf()][0])
					_cb_base = _escala
				else:
					_cb_puente(_pre() + "vu_rb")
			else:
				_cb_puente(_pre() + ("vu_arrf" if quiere == "frente" else "vu_rf"))


## Sacar o guardar: al sacar ya es el modo con baston (la bola va en la garra
## del video); al guardar lo sigue siendo hasta acabar en el reposo sin baston.
func _empezar_accion() -> void:
	if _accion.begins_with("sacar"):
		_con_baston = true
		_sec = _secs[true]
	_cb = "accion"
	_poner_anim(_accion, 0)


func _cb_escala(nueva: float) -> void:
	nueva = clampf(nueva, ESCALA_MIN, ESCALA_MAX)
	_y += float(_sec["baja"]) * (nueva - _escala)
	_escala = nueva


func _vuelta() -> String:
	return VUELTA + ("" if _con_baston else "_sin")


## La vuelta va en el sitio, a su ritmo; al acabar, el otro andar por el
## fotograma contra el que se registro (ENGANCHE).
func _seguir_vuelta(delta: float) -> void:
	_acum += delta * VUELTA_FPS
	var n := _sprite.sprite_frames.get_frame_count(_sprite.animation)
	while _acum >= 1.0:
		_acum -= 1.0
		var f := _sprite.frame + _girando
		if f < 0 or f >= n:
			_cara = "espalda" if _girando > 0 else "frente"
			_girando = 0
			_andando = false
			var anim := _andar_de(_cara)
			if _quiere == "" and REPOSO_TRAS_VUELTA.has(anim):
				# sin tecla, la vuelta acaba de pie: al reposo de ese lado
				var r: Array = REPOSO_TRAS_VUELTA[anim]
				_poner_anim(r[0], r[1], true)
			else:
				_poner_anim(anim, ENGANCHE[anim], true)
			return
		_sprite.frame = f


## Sin baston en la mano: el de scenes/dev/baston.tscn entero (madera, bola,
## luz) a la espalda, por FUERA de la tunica, en diagonal y metido en la funda
## de cuero (funda_cuero.py; la idea es el concepto de Gemini). Cada fila de
## "baston_espalda": [x, y, giro, corte, ancho]. El baston va en 3D, en un plano
## pegado por detras a la espalda (secuencia.py, baston_espalda): entero DETRAS
## del cuerpo y, encima, una copia DELANTE (MaderaDelante de baston.tscn)
## recortada de la bola hasta "corte" (fraccion del alto de baston.png): 0 de
## frente, 1 de espaldas; en la vuelta, 0, solo la garra (la bola ya delante de
## la capucha) o 1 pasado el perfil. La bola y la funda van delante cuando su
## tramo lo esta. "ancho": el de la funda (de canto, de perfil, se ve estrecha).
func _baston_a_la_espalda(lista: Array) -> void:
	var f: Array = lista[mini(_sprite.frame, lista.size() - 1)]
	_madera(true)
	_bola.visible = true
	_bola.scale = Vector2.ONE * _escala
	_bola.position = _sprite.position + (_sprite.offset + Vector2(f[0], f[1])) * _escala
	_bola.rotation = f[2]
	_bola.z_index = -3            # el entero, detras del sprite (que va en 0)
	var corte: float = f[3]
	var delante := _bola.get_node("MaderaDelante") as Sprite2D
	delante.visible = corte > 0.001
	(delante.material as ShaderMaterial).set_shader_parameter("desde", 0.0)
	(delante.material as ShaderMaterial).set_shader_parameter("corte", corte)
	var funda_delante: bool = corte > float(_secs[false].get("funda_corte", 0.42))
	_funda_atras_f.visible = funda_delante
	_funda_delante_f.visible = funda_delante
	# la funda es un tubo aplastado: de perfil se ve de canto (estrecha)
	var ancho: float = f[4] if f.size() > 4 and float(f[4]) > 0.0 else 1.0
	for sp in [_funda_atras, _funda_delante, _funda_atras_f, _funda_delante_f]:
		(sp as Sprite2D).scale.x = _funda_escala * ancho
	_bola_delante(corte > 0.001)


## Con el baston en la mano: la funda vacia donde iria con el baston guardado
## (misma fila: pivote del baston, giro, corte y ancho), solo las capas de la
## funda; delante del cuerpo cuando su tramo lo esta (de espaldas, pasado el
## perfil en la vuelta).
func _poner_funda_vacia() -> void:
	var lista = _vacia.get(String(_sprite.animation)) if _con_baston else null
	_funda_vacia.visible = lista != null
	if lista == null:
		return
	var f: Array = lista[mini(_sprite.frame, lista.size() - 1)]
	# hija del sprite: en su espacio (su escala ya va), recortada con su silueta
	_funda_vacia.position = _sprite.offset + Vector2(f[0], f[1])
	_funda_vacia.rotation = f[2]
	var delante: bool = float(f[3]) > float(_secs[true].get("funda_corte", 0.42))
	# aqui el ancho siempre viene (secuencia.py): 0 es que no se ve (de lado en la
	# vuelta). Por detras del cuerpo (de frente) una correa plana en la espalda
	# no asoma: tampoco se ve.
	var ancho: float = float(f[4]) if f.size() > 4 else 1.0
	if ancho < 0.01 or not delante:
		_funda_vacia.visible = false
		return
	for sp in _funda_vacia.get_children():
		(sp as Sprite2D).scale.x = _funda_escala * ancho


## La bola (y su luz y chispas) delante del cuerpo o con el baston de detras.
func _bola_delante(si: bool) -> void:
	var madera := _bola.get_node("Madera")
	for n in ["Orbe", "Luz", "Recarga", "Estallido", "Chispas"]:
		var nodo := madera.get_node(n) as CanvasItem
		nodo.z_as_relative = not si
		nodo.z_index = Z_BOLA_DELANTE[n] if si else Z_BOLA_RELATIVO[n]


func _capa_funda(ruta: String, fj: Dictionary, z: int, absoluta := false) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load(ruta)
	sp.centered = false
	sp.offset = -Vector2(fj["eje"][0], fj["eje"][1])
	sp.scale = Vector2.ONE * float(fj["escala"])
	sp.position = _funda_en_baston
	sp.z_as_relative = not absoluta
	sp.z_index = z
	sp.visible = false
	_bola.add_child(sp)
	return sp


## Con la madera y la funda (a la espalda) o solo la bola (en la mano: la madera
## va en el dibujo y la bola por detras de los dedos de la garra).
func _madera(si: bool) -> void:
	var madera := _bola.get_node("Madera") as Sprite2D
	madera.self_modulate.a = 1.0 if si else 0.0
	madera.z_index = 1 if si else 0
	madera.get_node("Funda").modulate.a = 0.0     # el parche de tela del perfil, aqui no
	(madera.material as ShaderMaterial).set_shader_parameter("corte", 1.0)
	_funda_atras.visible = si
	_funda_delante.visible = si
	if not si:
		_bola.rotation = 0.0
		_bola.z_index = 0
		(_bola.get_node("MaderaDelante") as CanvasItem).visible = false
		_funda_atras_f.visible = false
		_funda_delante_f.visible = false
		_bola_delante(false)


func _colocar() -> void:
	_sprite.position = Vector2(1456, _y)
	_sprite.scale = Vector2.ONE * _escala
	_fantasma.visible = _fundido > 0.0
	_fantasma.position = _sprite.position
	_fantasma.scale = _sprite.scale
	_fantasma.modulate.a = _fundido
	# bola y garra, solo con el baston y en lo que tenga datos
	var d = _orbes.get(String(_sprite.animation)) if _con_baston else null
	_bola.visible = d != null
	var con_garra: bool = d != null and d.has("garra")
	_madera(false)
	if d == null and _espalda.has(String(_sprite.animation)):
		_baston_a_la_espalda(_espalda[String(_sprite.animation)])
	if d != null:
		var o: Array = d["orbe"][mini(_sprite.frame, d["orbe"].size() - 1)]
		var e: float = d["escala_bola"]
		var giro := 0.0
		if o.size() > 3:
			# sacar / guardar: la bola pasa de la de a la espalda (escala 1, girada
			# con el baston) a la de en la mano (escala_bola, derecha) o al reves
			e = o[2]
			giro = o[3]
		_bola.scale = Vector2.ONE * _escala * e
		_bola.rotation = giro
		_bola.position = _sprite.position + (_sprite.offset + Vector2(o[0], o[1])) * _escala \
			- ORBE_EN_MADERA.rotated(giro) * _escala * e
		if _fundido > 0.0 and _bola_antes != Vector2.ZERO:
			_bola.position = _bola.position.lerp(_bola_antes, _fundido)
	_poner_funda_vacia()
	# la garra pegada va en el andar de frente; al salir de el se desvanece con
	# el fundido en su ultima postura (la de la vuelta ya viene en el dibujo)
	if not con_garra and _garra_fundiendo and _fundido > 0.0:
		_garra.modulate.a = _fundido
	else:
		_garra_fundiendo = false
		_garra.modulate.a = 1.0 - _fundido      # y al volver a el, aparece con el fundido
		_garra.visible = con_garra
	if con_garra:
		if _garra.texture == null:
			_garra.texture = load(d["garra_textura"])
			_garra.offset = -Vector2(d["garra_pivote"][0], d["garra_pivote"][1])
		var g: Array = d["garra"][mini(_sprite.frame, d["garra"].size() - 1)]
		_garra.position = _sprite.position + (_sprite.offset + Vector2(g[0], g[1])) * _escala
		_garra.rotation = g[2]
		_garra.scale = Vector2.ONE * _escala * float(d["garra_escala"])
	var z: float = ZOOMS[_zoom]
	_camara.zoom = Vector2(z, z)
	# a zoom 1 la camara no se mueve; con zoom encuadra al personaje: si cabe
	# entero, centrado; si no, la cabeza arriba y que se corten los pies
	var vista := Vector2(2912, 1632) / z
	var centro := Vector2(1456, 816)
	if z != 1.0:
		var alto := 345.0 * _escala
		centro = _sprite.position - Vector2(0, alto / 2.0)
		if alto > vista.y * 0.9:
			centro.y = _sprite.position.y - alto - vista.y * 0.04 + vista.y / 2.0
	_camara.position = centro - vista / 2.0
	_fondo.queue_redraw()


func _dibujar_fondo() -> void:
	var f := _fondo
	# fondo oscuro y suelo con lineas hacia el punto de fuga, para leer la
	# profundidad; las transversales a escalas fijas (0,5 / 0,75 / 1 / 1,5 / 2 / 2,5).
	# Con la camara de los videos (a media altura del personaje) el horizonte
	# queda muy cerca de los pies: el suelo se ve muy plano.
	const K := 165.0
	const HORIZONTE := SUELO_SALIDA - K
	f.draw_rect(Rect2(-6000, -6000, 15000, 15000), Color(0.08, 0.09, 0.11))
	f.draw_rect(Rect2(-6000, HORIZONTE, 15000, 9000), Color(0.13, 0.12, 0.11))
	var fuga := Vector2(1456, HORIZONTE)
	for i in range(-14, 15):
		var lejos := Vector2(1456 + i * 240, HORIZONTE + K * 3.0)
		f.draw_line(fuga.lerp(lejos, 0.12), lejos, Color(0.2, 0.19, 0.17), 2.0)
	for s in [0.5, 0.75, 1.0, 1.5, 2.0, 2.5]:
		var y: float = HORIZONTE + K * s
		f.draw_line(Vector2(-6000, y), Vector2(9000, y), Color(0.2, 0.19, 0.17), 2.0)
	# sombra bajo los pies
	f.draw_set_transform(_sprite.position, 0.0, Vector2(1.0, 0.22))
	f.draw_circle(Vector2.ZERO, 80.0 * _escala, Color(0, 0, 0, 0.35))
	f.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
