class_name PeregrinoFrontal
extends Node2D
## El peregrino visto de frente y de espaldas: el componente del juego, el mismo
## en todas las escenas (como peregrino.tscn el de perfil). Salio de la prueba
## (scripts/dev/prueba_frontal.gd, que ahora lo usa) el 2026-10-15: lo que se
## mejore aqui se ve en todas.
##
## Anda hacia la camara (de frente) o alejandose (de espaldas), se para con los
## pies juntos y respira, se da la vuelta, corre (sin baston, doble toque) y saca
## o guarda el baston; el baston en la mano o a la espalda (en la correa), con o
## sin la bola de la garra (la magia).
##
## LO MANDA LA ESCENA: cada fotograma pone `quiere` ("frente" = hacia la camara,
## "espalda" = alejandose, "" = parado), como si fueran las teclas; el doble toque
## (correr) lo detecta el componente con esos cambios. cambiar_baston(si) saca o
## guarda (andando, termina el paso y se para antes); pulsar_baston() es la tecla
## (lo contrario de lo que vaya a llevar; durante la animacion, se apunta para
## despues). gastar(cuanto) gasta magia.
## girar_desde_perfil() empieza la vuelta en el perfil y girar_a_perfil() la
## hace hasta el perfil y se queda ahi (emite en_perfil): para empalmar con el
## de perfil, peregrino.tscn, en los dos sentidos.
##
## DONDE VA: andando, la escala cambia fotograma a fotograma como en el video
## (1/escala recta en el tiempo: los pies no patinan) y, con ella, la fila de los
## pies (`baja` por unidad de escala: la camara de los videos). Sin mas, los pies
## van en el origen del nodo mas esa bajada. Una escena con su camara pone
## `perspectiva`: dada la escala, donde van los pies (espacio del nodo). Tras
## moverse emite `colocado`. Mirando a la izquierda: scale.x = -1 en el nodo.
##
## Z: usa de -3 a 5 (el baston a la espalda y la bola, por detras y por delante
## del cuerpo, con z absolutos); lo que deba ir delante del peregrino, z >= 6.
## Un material puesto en este nodo (antes de meterlo en la escena) lo usan el
## cuerpo, la garra y la correa vacia (la luz de la escena); y el baston a la
## espalda y su correa, copias de el con los mismos parametros cada fotograma
## (y su tramo de madera, desde / corte, como corte_madera.gdshader: el
## shader de la escena tiene que tener esos dos uniformes; y `encima`, que se
## pone a 1 en lo que va pegado delante del cuerpo: la correa y el palo sobre la
## espalda, para que no lleven luz de fondo en el canto). Asi al sacar o
## guardar el baston (pasa del dibujado aqui al del video) no cambia de luz.
## Sin material, el baston lleva los suyos (y luz_baston).
##
## El avance va atado al fotograma: cada fotograma que pasa, el tamano cambia lo
## mismo que en el video (alli 1/alto es una recta en el tiempo, camara fija y
## paso constante), asi que los pies no patinan. La fila del suelo sale del
## tamano con el horizonte del propio video (baja).
##
## La bola del baston, como en el de perfil con el baston en la mano: la madera
## ya viene en el dibujo y la bola es la de scenes/characters/baston.tscn (orbe, luz,
## chispas) puesta por codigo, por detras del sprite, donde dice frontal.json
## (raw/master_builder/anim/baston/frontal.py): en el hueco de la garra.
## El baston del video de frente no tiene garra (acababa en pincho): en la hoja
## se le ha borrado el pincho y la garra (garra_frente.png, la del baston de
## Gemini) va aqui como capa encima del sprite, donde y con la inclinacion que
## dice frontal.json; la bola, detras, en su hueco. De espaldas y en la vuelta
## la garra ya viene en el dibujo. La bola es scenes/characters/baston.tscn sin su
## script (baston.gd va colgado del peregrino).

signal colocado
## En cada pisada (los fotogramas de PISADAS), con donde estan los pies (espacio
## del nodo): para que la escena levante hojas, polvo o agua.
signal piso(pies: Vector2)
## girar_a_perfil() ha llegado al perfil (y ahi se queda).
signal en_perfil

const FRAMES := preload("res://resources/characters/peregrino_frames.tres")
const BASTON := preload("res://scenes/characters/baston.tscn")
## EL BASTON A LA ESPALDA VISTO DE ESPALDAS: el mismo que lleva en la mano (la
## plantilla de peregrino_guardar_baston_espalda_a/arreglar.py: garra de cuerna y
## tramo retorcido, marron), a su tamano, de raw/master_builder/anim/baston/
## baston_espalda.py (2026-10-15). Antes era baston.png (el del perfil: naranja,
## liso, otra garra) a 1,2 de ancho y los videos de sacar y guardar, que pintan el
## de la mano, se transformaban en el en los puentes (el usuario: "igualarlo todo,
## a la vieja usanza"). La ficha dice donde va la bola en la textura: se pone donde
## iba la de baston.png (ORBE_EN_MADERA del pivote), asi valen las filas. De
## frente (solo asoma la garra por encima del hombro) sigue baston.png.
const BASTON_ESPALDA_TEX := preload("res://assets/characters/baston/baston_espalda.png")
const BASTON_ESPALDA_FICHA := "res://assets/characters/baston/baston_espalda.json"
const FRONTAL := "res://assets/characters/baston/frontal.json"
## Con baston: la secuencia de un solo video (reposo, arranque, andar, vuelta y
## puentes; raw/master_builder/anim/peregrino_secuencia_frontal/secuencia.py).
const SECUENCIA := "res://assets/characters/peregrino/secuencia_frontal.json"
## Sin baston: lo mismo de su propio video (sufijo _sb, puentes ps_), con el
## baston a la espalda en la funda de cuero.
const SECUENCIA_SIN := "res://assets/characters/peregrino/secuencia_frontal_sin.json"
## Sacar y guardar el baston de frente, de un reposo al otro (videos de Flow con
## fotograma inicial y final sacados de esta escena; raw/master_builder/anim/
## peregrino_sacar_baston_frente/animar.py): la bola sigue a la garra del video,
## filas [x, y, escala, giro].
const BASTON_FRENTE := "res://assets/characters/peregrino/baston_frente.json"
const ACCIONES_ESPALDA := "res://assets/characters/peregrino/acciones_espalda.json"   # sacar / guardar de espaldas
const ORBE_EN_MADERA := Vector2(-0.6, -24)   # posicion del Orbe dentro de Madera
const COLORES: Array[Color] = [
	Color(1.0, 0.62, 0.18), Color(0.35, 0.75, 1.0), Color(0.55, 1.0, 0.45),
	Color(0.85, 0.45, 1.0), Color(1.0, 0.3, 0.25)]
## Las particulas de la bola (Recarga, Chispas y Estallido), apagadas como en el perfil
## (baston.gd, particulas = false): aun no se sabe que soltara la bola; queda la bola
## con su brillo.
const PARTICULAS := false
## Como en baston.gd: de espaldas la madera se corta 8 px bajo el pivote (el
## hombro) y el parche de tela tapa el corte.
## Lo que sujeta el baston a la espalda: la CORREA en diagonal con dos presillas
## (2026-10-10; el usuario eligio esta composicion de Gemini: la funda de tubo,
## funda_cuero, de espaldas quedaba "como un pegote"). raw/master_builder/anim/
## baston/correa.py: dos capas como la funda (la correa detras del baston, las
## presillas delante: el palo pasa por dentro) y correa.json.
const FUNDA := "res://assets/characters/baston/correa.json"
const FUNDA_ATRAS := preload("res://assets/characters/baston/correa_atras.png")
const FUNDA_DELANTE := preload("res://assets/characters/baston/correa_delante.png")
## La correa empieza este trecho bajo el pivote del baston (px de hoja, a lo
## largo del palo): justo bajo la capucha, donde sale en la imagen de Gemini.
const CORREA_INICIO := 22.0
## z de la bola, su luz y sus chispas: los de baston.tscn (relativos al baston)
## y, cuando la bola va delante del cuerpo, absolutos sobre el sprite (la bola
## en 2, como MaderaDelante, que va despues y le pone los dedos de la garra
## encima; la luz y las chispas por encima de todo).
const Z_BOLA_RELATIVO := {"Orbe": 0, "Luz": 2, "Recarga": 0, "Estallido": 0, "Chispas": 0}
const Z_BOLA_DELANTE := {"Orbe": 2, "Luz": 5, "Recarga": 5, "Estallido": 5, "Chispas": 5}
const FUNDIDO := 0.18            # s (a 0,12 aun se notaba el cambio de tunica al entrar)
## Fotogramas que se saltan al principio y al final de sacar y guardar: los que
## son el fotograma de esta escena con el que se hizo el video (el baston de
## aqui a escala 1) y no el de la IA; con ellos el baston cambiaba de golpe.
## (Descartado con lo del baston casado con la IA: a cero.)
const RECORTE_ACCION := {"sacar_baston_frente": Vector2i(0, 0), "guardar_baston_frente": Vector2i(0, 0),
	"sacar_baston_espalda": Vector2i(0, 0), "guardar_baston_espalda": Vector2i(0, 0)}
## PISADAS: fotograma en que planta el pie, por animacion (2026-10-15). Medidos
## en 04_limpios: el pie que avanza deja de avanzar (de frente, lo mas bajo en
## la casilla; de espaldas, lo mas alto); casan con los golpes del audio de los
## videos de la secuencia (Pilgrim_walking_turning_full / _animation_sequence)
## a un fotograma o dos. Faltan correr y las paradas.
const PISADAS := {
	"andar_frente_cb": [8, 26], "andar_espalda_cb": [4, 25],
	"arranque_frente_cb": [6], "arranque_espalda_cb": [15],
	"andar_frente_sb": [0, 16], "andar_espalda_sb": [17, 35],
	"arranque_frente_sb": [20], "arranque_espalda_sb": [12, 32]}
const DOBLE_TOQUE := 0.30        # dos pulsaciones a menos: correr (como doble_pulsacion de peregrino.gd)

## Con el baston en la mano (true) o guardado a la espalda (false) al empezar.
## Lo decide la escena (la de antes sabe como lo dejo); despues, cambiar_baston().
@export var con_baston := true
## La magia, como en baston.gd (el de perfil): la carga (0..1, se gasta con
## gastar) y lo que se recarga por segundo. SIN MAGIA (carga 0 y sin recarga: el
## baculo recien cogido en la hojarasca) no hay bola: la garra vacia (el
## usuario, 2026-10-14: "mejor sin bola"). Con recarga, vacia, la bola sigue ahi.
@export_range(0.0, 1.0) var magia := 1.0
@export var magia_recarga := 0.05
## Hacia donde mira al empezar: "frente" (a la camara) o "espalda".
@export_enum("frente", "espalda") var cara := "frente"
## Limites de la escala (1 = la de salida; 2 = el master, que ya es el video x1,25).
@export var escala_min := 0.45
@export var escala_max := 2.6
## La escala al empezar.
@export var escala_inicial := 1.0
## La pisada, la del suelo de cada escena (mejor un AudioStreamRandomizer con
## varias); sin ella, mudo. Suena en cada fotograma de PISADAS, a pasos_db con la
## escala pasos_escala_ref y mas flojo cuanto mas lejos (la presion va con
## 1/distancia, y la distancia con 1/escala).
@export var pasos: AudioStream
@export var pasos_db := -19.0
@export var pasos_escala_ref := 2.0
## El baston a la espalda dibujado aqui (baston.png), de ancho (x, de traves al
## palo) y de largo (y), visto de espaldas y visto de frente; en la vuelta pasa
## de uno a otro con el giro (giro_vuelta), y en lo demas segun de que lado
## este (el "corte" de su fila: 0 de frente, 1 de espaldas). Los videos de sacar
## y guardar empiezan y acaban en un fotograma de esta escena (con el baston a
## 1) y en medio la IA lo dibuja a su manera: de espaldas mas grueso (1,2 de
## ancho), de frente como el nuestro (1). PROBADO Y DESCARTADO (2026-10-15):
## casarlo midiendo con la IA (frente 0,88, trazo engordado, tinte pardo y
## saltarse los fotogramas compuestos): el usuario lo vio "mucho mas descarado"
## al sacarlo y con el baculo ya en la mano; se volvio a esto. La correa no
## cambia.
## (Con baston_espalda.png, ya a su tamano, de espaldas va a 1; el 1,2 era para
## baston.png.)
@export var baston_espalda_escala := Vector2(1.0, 1.0)
@export var baston_frente_escala := Vector2(1.0, 1.0)
## Trazo engordado (texeles; corte_madera.gdshader y el shader de la escena) y
## tinte de la madera: a 0 y en blanco (ver arriba: descartado).
@export var baston_espalda_engordar := 0.0
@export var baston_frente_engordar := 0.0
@export var tinte_baston := Color.WHITE
## Indice del color de la bola (COLORES).
@export var color := 0:
	set(v):
		color = posmod(v, COLORES.size())
		if _bola:
			_poner_color()

## Opcional: dada la escala, donde van los pies (espacio del nodo). Si no, en el
## origen mas lo que bajan con la escala.
var perspectiva := Callable()
## Hacia donde quiere ir: "frente", "espalda" o "". Lo pone la escena.
var quiere := ""
## Segundos que queda el aviso "con el baston en la mano no se corre" (la
## escena lo muestra si quiere).
var aviso := 0.0
## El baston a la espalda (madera y correa) lleva sus propios materiales, no el
## de la escena: su luz se la pone la escena con esto (rgb: lo que oscurece o
## tine; a: lo que se ve, p. ej. con la bruma de la distancia). La bola no.
var luz_baston := Color.WHITE

var escala: float:
	get: return _escala
var animacion: String:
	get: return String(_sprite.animation)
var fotograma: int:
	get: return _sprite.frame
## Lo que cambia 1/escala por fotograma andando hacia `hacia` (el del video).
func paso_andar(hacia := "frente") -> float:
	return absf(float(_sec["paso"].get("andar_%s%s" % [hacia, _suf()], 0.0)))


## Hacia donde mira ahora ("frente" / "espalda"; en plena vuelta, la de antes).
var mirando: String:
	get: return _cara
## Lo que hace: reposo / arranque / andar / correr / parada / puente / vuelta / accion /
## perfil (quieto en el perfil tras girar_a_perfil).
var estado: String:
	get: return _cb
var lleva_baston: bool:
	get: return _con_baston
## Donde estan los pies (espacio del nodo).
var pies: Vector2:
	get: return _sprite.position

var _sprite: AnimatedSprite2D
var _fantasma: Sprite2D
var _escala := 1.0
var _y := 0.0
var _acum := 0.0
var _bola: Node2D
var _funda_atras: Sprite2D
var _funda_delante: Sprite2D
var _funda_atras_f: Sprite2D      # copias de la funda delante del cuerpo
var _funda_delante_f: Sprite2D
var _funda_escala := 0.25         # la de funda_cuero.json
## Donde va el centro de la correa en el baston (px de hoja, ejes del nodo
## Baston sin girar): en el palo (x +1) y bajando desde CORREA_INICIO la mitad de
## su largo (correa.json). La fija _ready.
var _funda_en_baston := Vector2(1.0, 56.0)
## Con el baston en la mano, la funda de cuero se queda VACIA en la espalda (como
## en el perfil): las mismas capas y la misma colocacion que con el baston
## guardado ("funda_espalda" de secuencia_frontal.json), en un nodo aparte (el
## de _bola va con la bola, en la garra). Se ve de espaldas y en la vuelta.
var _funda_vacia: Node2D
var _vacia: Dictionary = {}       # animacion con baston -> filas [x, y, giro, corte, ancho]
var _garra: Sprite2D
var _orbes: Dictionary = {}
var _espalda: Dictionary = {}   # baston a la espalda en las animaciones sin baston
var _mostrada := 1.0
var _destello := 0.0
var _con_baston := true
var _cara := "frente"            # hacia donde mira: frente / espalda
var _fundido := 0.0
var _reloj := 0.0
var _tecla_antes := ""
var _pulsado_en := {}            # cara -> _reloj de su ultima pulsacion
var _corriendo := false          # doble toque y la tecla sigue pulsada
var _soltado_en := -10.0         # _reloj al soltar: andando, se espera DOBLE_TOQUE por si vuelve
var _sec: Dictionary = {}        # la del modo actual (secuencia_frontal[_sin].json)
var _secs: Dictionary = {}       # true: con baston, false: sin
var _acciones: Dictionary = {}   # sacar_ / guardar_baston_frente / _espalda: de, a, orbe
var _accion := ""                # la pedida (sacar_baston / guardar_baston): ver cambiar_baston
var _cb := "reposo"              # reposo / arranque / andar / correr / parada / puente / vuelta / accion
var _cb_dir := 1                 # sentido de la vuelta en curso
var _cb_h0 := 1.0                # arranque: altura de video al entrar y escala entonces
var _cb_base := 1.0
var _bola_antes := Vector2.ZERO   # en los enganches la bola va de donde estaba a su sitio
var _garra_fundiendo := false     # y la garra pegada (andar_frente) se desvanece
var _pisada: AudioStreamPlayer2D
var _ultima_pisada := ""
var _a_perfil := false            # girar_a_perfil pedido: a la vuelta y parar en el perfil
var _perfil_en := -1              # y en que fotograma de la vuelta (-1: el del perfil exacto)
var _mat_madera: ShaderMaterial   # copias del material de la raiz para el baston a la espalda
var _mat_delante: ShaderMaterial
var _mat_funda: ShaderMaterial
var _mat_funda_f: ShaderMaterial  # las copias de delante del cuerpo y la correa vacia (encima)
var _mat_vacia: ShaderMaterial
var _uniformes: Array = []        # los que se copian de la raiz cada fotograma
var _con_garra := false           # el material de la raiz tiene el uniforme `garra`
var _engordar := 0.0              # el trazo del baston a la espalda (ver baston_espalda_engordar)
var _de_espaldas := false         # el baston a la espalda se ve de espaldas (baston_espalda.png)
var _textura_espaldas := false    # la que tiene puesta Madera ahora
var _tex_baston: Texture2D        # la de baston.tscn (baston.png) y su offset
var _offset_baston := Vector2.ZERO
## El halo de la bola por delante del cuerpo en sacar / guardar de espaldas (ver
## _halo_de_espaldas) y el del Orbe de baston.tscn.
var _halo_delante: Sprite2D
var _halo0 := 1.1
var _pendiente := false           # una pulsacion de B que espera (pulsar_baston)
## La vuelta con baston pasa la garra por delante de la cara (vuelta_cb 8-11): la
## esfera delante del cuerpo y encima los dedos de la garra del propio fotograma
## (raw/master_builder/anim/peregrino_secuencia_frontal/garra_vuelta.py).
const VUELTA_GARRA := "res://assets/characters/peregrino/vuelta_garra.json"
var _vuelta_garra: Dictionary = {}     # anim -> {fotograma: [esquina, textura]}
var _esfera_delante: Sprite2D
var _garra_vuelta: Sprite2D
## Radio de la garra (px de la casilla con escala 1) para el uniforme `garra`.
const RADIO_GARRA := 34.0


## Los datos de los JSON, leidos una vez y compartidos por todas las copias
## (solo se leen): mientras el script siga cargado, tambien entre escenas (de
## la hojarasca al camino ya no se vuelven a leer: sumaban al tiron de entrada).
static var _datos := {}
static var _texturas := {}


static func _cargar_datos() -> Dictionary:
	var orbes: Dictionary = JSON.parse_string(FileAccess.open(FRONTAL, FileAccess.READ).get_as_text())
	var espalda: Dictionary = orbes.get("baston_espalda", {})
	var vacia := {}
	var secs := {}
	var acciones := {}
	for con in [true, false]:
		var sec: Dictionary = JSON.parse_string(FileAccess.open(SECUENCIA if con else SECUENCIA_SIN, FileAccess.READ).get_as_text())
		for clave in ["pies_juntos"]:     # el JSON los da en float
			for nombre in sec[clave]:
				sec[clave][nombre] = sec[clave][nombre].map(func(v): return int(v))
		for nombre in sec["orbe"]:
			orbes[nombre] = {"orbe": sec["orbe"][nombre], "escala_bola": sec["escala_bola"]}
		for nombre in sec.get("baston_espalda", {}):
			espalda[nombre] = sec["baston_espalda"][nombre]
		for nombre in sec.get("funda_espalda", {}):
			vacia[nombre] = sec["funda_espalda"][nombre]
		secs[con] = sec
	for ruta in [BASTON_FRENTE, ACCIONES_ESPALDA]:
		if not FileAccess.file_exists(ruta):
			continue
		var bf: Dictionary = JSON.parse_string(FileAccess.open(ruta, FileAccess.READ).get_as_text())
		for nombre in bf:
			if bf[nombre] is Dictionary and FRAMES.has_animation(nombre):
				acciones[nombre] = bf[nombre]
				orbes[nombre] = {"orbe": bf[nombre]["orbe"], "escala_bola": 1.0}
	var funda: Dictionary = JSON.parse_string(FileAccess.open(FUNDA, FileAccess.READ).get_as_text())
	var be: Dictionary = JSON.parse_string(FileAccess.open(BASTON_ESPALDA_FICHA, FileAccess.READ).get_as_text())
	return {"orbes": orbes, "espalda": espalda, "vacia": vacia, "secs": secs, "acciones": acciones, "funda": funda,
		"baston_espalda": be}


## Una textura por su ruta (la de la garra la dice frontal.json), cargada una vez.
static func _textura(ruta: String) -> Texture2D:
	if not _texturas.has(ruta):
		_texturas[ruta] = load(ruta)
	return _texturas[ruta]


func _ready() -> void:
	_con_baston = con_baston
	_cara = cara
	_escala = escala_inicial
	_mostrada = magia
	if _datos.is_empty():
		_datos = _cargar_datos()
	_orbes = _datos["orbes"]
	_espalda = _datos["espalda"]
	_vacia = _datos["vacia"]
	_secs = _datos["secs"]
	_acciones = _datos["acciones"]
	_sec = _secs[_con_baston]
	# la bola, antes que el sprite: se dibuja detras (la garra le queda delante)
	_bola = BASTON.instantiate()
	_bola.set_script(null)
	_tex_baston = (_bola.get_node("Madera") as Sprite2D).texture
	_offset_baston = (_bola.get_node("Madera") as Sprite2D).offset
	# los materiales de baston.tscn los comparten todas sus copias (el baston del
	# de perfil en la misma escena): esta, los suyos
	for n in ["Madera", "Madera/Orbe", "Madera/Luz", "MaderaDelante"]:
		var ci := _bola.get_node(n) as CanvasItem
		ci.material = ci.material.duplicate()
	var orbe := _bola.get_node("Madera/Orbe") as Sprite2D
	_halo0 = float((orbe.material as ShaderMaterial).get_shader_parameter("halo"))
	_halo_delante = orbe.duplicate() as Sprite2D
	_halo_delante.name = "HaloDelante"
	_halo_delante.material = orbe.material.duplicate()
	(_halo_delante.material as ShaderMaterial).set_shader_parameter("solo_halo", 1.0)
	# la garra y el palo del video van en el sprite: el halo, solo fuera de ellos (en la
	# escena el baston va encima del halo). Con el baston a la espalda la garra queda
	# donde baston_espalda.png en Madera (la bola en ORBE_EN_MADERA, como el Orbe).
	var be: Dictionary = _datos["baston_espalda"]
	var tam := Vector2(be["tam"][0], be["tam"][1])
	var lado := orbe.texture.get_size() * orbe.scale
	var mh := _halo_delante.material as ShaderMaterial
	mh.set_shader_parameter("mascara", BASTON_ESPALDA_TEX)
	mh.set_shader_parameter("mascara_uv", Vector4(
		(be["bola"][0] - 0.5 * lado.x) / tam.x, (be["bola"][1] - 0.5 * lado.y) / tam.y, lado.x / tam.x, lado.y / tam.y))
	mh.set_shader_parameter("con_mascara", 1.0)
	# la esfera sola (sin halo: el de la bola de detras sigue igual) por delante del
	# cuerpo, para la vuelta
	_esfera_delante = orbe.duplicate() as Sprite2D
	_esfera_delante.name = "EsferaDelante"
	_esfera_delante.material = orbe.material.duplicate()
	(_esfera_delante.material as ShaderMaterial).set_shader_parameter("halo", 0.0)
	_esfera_delante.show_behind_parent = false
	_esfera_delante.z_as_relative = false
	_esfera_delante.z_index = Z_BOLA_DELANTE["Orbe"]
	_esfera_delante.visible = false
	_bola.get_node("Madera").add_child(_esfera_delante)
	if FileAccess.file_exists(VUELTA_GARRA):
		var vg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VUELTA_GARRA))
		for anim in vg:
			_vuelta_garra[anim] = {}
			for f in vg[anim]:
				_vuelta_garra[anim][int(f)] = [Vector2(vg[anim][f][0], vg[anim][f][1]),
					load("res://assets/characters/peregrino/vuelta_garra/%s_%03d.png" % [anim, int(f)])]
	_halo_delante.show_behind_parent = false
	_halo_delante.z_as_relative = false
	_halo_delante.z_index = Z_BOLA_DELANTE["Orbe"]
	_halo_delante.visible = false
	_bola.get_node("Madera").add_child(_halo_delante)
	_bola.z_index = 0
	add_child(_bola)
	# la funda de cuero, en dos capas pegadas al baston: atras (lenguetas e
	# interior de las bocas), la madera, delante (la pared del tubo)
	var fj: Dictionary = _datos["funda"]
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
	_funda_vacia.use_parent_material = true
	for capa in [FUNDA_ATRAS, FUNDA_DELANTE]:
		var sp := _capa_funda(capa, fj, 0)
		_bola.remove_child(sp)
		_funda_vacia.add_child(sp)
		sp.visible = true
		sp.use_parent_material = true
	var md := _bola.get_node("MaderaDelante") as Sprite2D
	md.z_as_relative = false
	md.z_index = 2
	md.visible = false
	_bola.get_node("Madera").self_modulate.a = 0.0
	_bola.get_node("Madera/Funda").modulate.a = 0.0
	if material is ShaderMaterial:
		# la luz de la escena tambien para el baston a la espalda y su correa
		_mat_madera = material.duplicate()
		_mat_delante = material.duplicate()
		_mat_funda = material.duplicate()
		_mat_funda_f = material.duplicate()
		_mat_vacia = material.duplicate()
		(_bola.get_node("Madera") as CanvasItem).material = _mat_madera
		md.material = _mat_delante
		for sp in [_funda_atras, _funda_delante]:
			(sp as CanvasItem).material = _mat_funda
		for sp in [_funda_atras_f, _funda_delante_f]:
			(sp as CanvasItem).material = _mat_funda_f
		for sp in _funda_vacia.get_children():
			(sp as CanvasItem).use_parent_material = false
			(sp as CanvasItem).material = _mat_vacia
		for m in [_mat_delante, _mat_funda_f, _mat_vacia]:
			m.set_shader_parameter("encima", 1.0)
		for u in (material as ShaderMaterial).shader.get_shader_uniform_list():
			if u["name"] == "garra":
				_con_garra = true
			if not u["name"] in ["corte", "desde", "px_por_texel", "encima", "engordar"]:
				_uniformes.append(u["name"])
	for n in ["Madera/Recarga", "Madera/Estallido", "Madera/Chispas"]:
		(_bola.get_node(n) as CPUParticles2D).emitting = false
	_poner_color()
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	_sprite.use_parent_material = true
	add_child(_sprite)
	_sprite.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_sprite.add_child(_funda_vacia)
	# el fotograma de antes, encima, desvaneciendose en los enganches
	_fantasma = Sprite2D.new()
	_fantasma.visible = false
	_fantasma.use_parent_material = true
	add_child(_fantasma)
	_poner_anim("reposo_%s%s" % [_cara, _suf()], 0)
	# la garra del de frente, encima del sprite (la bola le queda detras)
	_garra = Sprite2D.new()
	_garra.centered = false
	_garra.use_parent_material = true
	add_child(_garra)
	# los dedos de la garra encima de la esfera de delante (vuelta): con la luz de la
	# escena, como el sprite del que salen
	_garra_vuelta = Sprite2D.new()
	_garra_vuelta.centered = false
	_garra_vuelta.use_parent_material = true
	_garra_vuelta.z_as_relative = false
	_garra_vuelta.z_index = Z_BOLA_DELANTE["Orbe"] + 1
	_garra_vuelta.visible = false
	add_child(_garra_vuelta)
	if pasos:
		_pisada = AudioStreamPlayer2D.new()
		_pisada.stream = pasos
		_pisada.max_distance = 6000.0
		_pisada.attenuation = 0.5
		add_child(_pisada)
	_colocar()


## Vuelve al sitio de salida (escala_inicial, sin bajada).
func reiniciar() -> void:
	_escala = escala_inicial
	_y = 0.0
	_colocar()


## Empieza en mitad de la vuelta, de perfil (mirando a la derecha; a la
## izquierda, con el nodo espejado), girando hacia `hacia`: para empalmar con el
## peregrino de perfil. `desde` es el fotograma de la vuelta (vuelta_cb /
## vuelta_sb); si no se da, el del perfil exacto (giro_vuelta 90). Al acabar la
## vuelta sigue lo de siempre: con quiere == hacia, a andar; si no, al reposo.
func girar_desde_perfil(hacia := "espalda", desde := -1) -> void:
	if desde < 0:
		desde = _fotograma_perfil()
	_accion = ""
	_a_perfil = false
	_cara = "frente" if hacia == "espalda" else "espalda"
	_cb = "vuelta"
	_cb_dir = 1 if hacia == "espalda" else -1
	_poner_anim("vuelta" + _suf(), desde)
	_colocar()


## Da la vuelta hasta el perfil (mirando a la derecha; a la izquierda, con el
## nodo espejado) y se queda ahi; al llegar emite en_perfil. Parado, gira al
## acabar de espirar; andando, termina el paso hasta los pies juntos y entra en
## la vuelta sin pararse (los puentes de siempre). Con baston y sin el. Vale
## mirando de frente (la vuelta hacia delante) y de espaldas (hacia atras).
## Mientras, `quiere` no manda; girar_desde_perfil() lo saca de ahi.
## `hasta`: el fotograma de la vuelta en que parar (el de un puente al de
## perfil, PuentePerfil); si no se da, el del perfil exacto.
func girar_a_perfil(hasta := -1) -> void:
	_a_perfil = true
	_perfil_en = hasta


## El fotograma de la vuelta del perfil exacto (giro_vuelta mas cerca de 90).
func _fotograma_perfil() -> int:
	var giro: Array = _sec["giro_vuelta"]
	var f := 0
	for i in giro.size():
		if absf(float(giro[i]) - 90.0) < absf(float(giro[f]) - 90.0):
			f = i
	return f


## Saca (true) o guarda (false) el baston, con su animacion de cara a donde
## mire (andando, termina el paso y se para antes). En la vuelta o a mitad de
## otra accion, no hace nada.
## La tecla del baston (2026-10-17): saca o guarda segun lo que vaya a llevar. Si
## ya esta sacando o guardando (o girando), no se pierde: se apunta y el cambio
## contrario empieza en cuanto acabe (otra pulsacion la anula). Antes se ignoraba
## y el usuario, con el baston ya en la correa y el brazo aun bajando, pulsaba B
## "y parece que la ignora".
func pulsar_baston() -> void:
	if _cb in ["puente", "vuelta", "accion", "perfil"] or _accion != "":
		_pendiente = not _pendiente
		return
	cambiar_baston(not _con_baston)


func cambiar_baston(si: bool) -> void:
	if si == _con_baston or _cb in ["puente", "vuelta", "accion", "perfil"]:
		return
	var accion := "sacar_baston" if si else "guardar_baston"
	if _acciones.has(accion + "_frente"):
		# de cara a donde mire, si de esa cara hay animacion (de espaldas desde el
		# 2026-10-11, con la espalda del chevron en los dos modos); si no, se da la
		# vuelta (la de siempre) y lo hace de frente. Parado, empieza al acabar de
		# espirar; andando, termina el paso y se para (_cb_paso)
		_accion = accion
		return
	_con_baston = si
	# sin animacion, de un modo al otro por el reposo de esa cara
	_cb = "reposo"
	_sec = _secs[si]
	_poner_anim("reposo_%s%s" % [_cara, _suf()], 0, true)


func gastar(cuanto: float) -> void:
	if magia < cuanto:
		_destello = 0.25
		return
	magia -= cuanto
	_destello = 1.0
	if PARTICULAS:
		(_bola.get_node("Madera/Estallido") as CPUParticles2D).restart()


func _process(delta: float) -> void:
	# la pulsacion apuntada (pulsar_baston), en cuanto se puede
	if _pendiente and _accion == "" and not _cb in ["puente", "vuelta", "accion", "perfil"]:
		_pendiente = false
		cambiar_baston(not _con_baston)
	var q := quiere
	# doble toque: al pulsar, si la pulsacion anterior de esa tecla fue hace poco, a
	# correr mientras se mantenga
	_reloj += delta
	if q != "" and q != _tecla_antes:
		_corriendo = _reloj - float(_pulsado_en.get(q, -10.0)) <= DOBLE_TOQUE
		# andando (con la tecla ya pulsada), soltar y volver a pulsar enseguida tambien
		if _cb in ["andar", "arranque"] and q == _cara and _reloj - _soltado_en <= DOBLE_TOQUE:
			_corriendo = true
		_pulsado_en[q] = _reloj
		if _corriendo and _con_baston:
			aviso = 2.5         # con el baston en la mano no se corre (no hay video)
	elif q == "":
		_corriendo = false
		if _tecla_antes != "":
			_soltado_en = _reloj
	_tecla_antes = q
	aviso = maxf(aviso - delta, 0.0)
	_cb_tick(delta, q)
	_fundido = move_toward(_fundido, 0.0, delta / FUNDIDO)
	_magia_bola(delta)
	_colocar()


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


func _poner_color() -> void:
	var c: Color = COLORES[color]
	for n in ["Madera/Orbe", "Madera/Luz", "Madera/HaloDelante", "Madera/EsferaDelante"]:
		((_bola.get_node(n) as Sprite2D).material as ShaderMaterial).set_shader_parameter("color", Vector3(c.r, c.g, c.b))
	for n in ["Madera/Recarga", "Madera/Estallido", "Madera/Chispas"]:
		(_bola.get_node(n) as CPUParticles2D).color = c.lightened(0.25)


## La magia como en baston.gd: se recarga sola y la bola llega poco a poco.
func _magia_bola(delta: float) -> void:
	magia = minf(1.0, magia + magia_recarga * delta)
	_mostrada = lerpf(_mostrada, magia, 1.0 - exp(-4.0 * delta))
	_destello = move_toward(_destello, 0.0, 3.5 * delta)
	for n in ["Madera/Orbe", "Madera/Luz", "Madera/HaloDelante", "Madera/EsferaDelante"]:
		var m := (_bola.get_node(n) as Sprite2D).material as ShaderMaterial
		m.set_shader_parameter("carga", _mostrada)
		m.set_shader_parameter("destello", _destello)
	(_bola.get_node("Madera/Recarga") as CPUParticles2D).emitting = PARTICULAS and magia < 0.999 and not _sin_magia()
	(_bola.get_node("Madera/Chispas") as CPUParticles2D).emitting = PARTICULAS and _mostrada > 0.97


func _sin_magia() -> bool:
	return magia <= 0.0 and magia_recarga <= 0.0


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
		_pisar()


## Si el fotograma nuevo es de una pisada, suena (una vez por fotograma).
func _pisar() -> void:
	var anim := String(_sprite.animation)
	var clave := "%s/%d" % [anim, _sprite.frame]
	if clave == _ultima_pisada:
		return
	_ultima_pisada = clave
	if not _sprite.frame in PISADAS.get(anim, []):
		return
	if _pisada:
		_pisada.position = _sprite.position
		_pisada.volume_db = pasos_db + linear_to_db(clampf(_escala / pasos_escala_ref, 0.03, 1.5))
		_pisada.play()
	piso.emit(_pies())


func _suf() -> String:
	return "_cb" if _con_baston else "_sb"


func _pre() -> String:
	return "pt_" if _con_baston else "ps_"


func _cb_puente(nombre: String) -> void:
	_cb = "puente"
	_poner_anim(nombre, 0)


func _cb_paso(quiere: String) -> void:
	var anim := String(_sprite.animation)
	var n := _sprite.sprite_frames.get_frame_count(anim)
	var c := "f" if _cara == "frente" else "b"
	if _accion != "":
		# sacar / guardar pendiente: a pararse; de espaldas sin su animacion, a darse
		# la vuelta (las teclas no mandan hasta acabar)
		quiere = "" if (_cara == "frente" or _accion_aqui() != "") else "frente"
	if _a_perfil:
		# a la vuelta: pide la otra cara (desde el reposo o los pies juntos)
		quiere = "espalda" if _cara == "frente" else "frente"
	match _cb:
		"perfil":
			return       # quieto en el perfil (girar_a_perfil)
		"reposo":
			# un fotograma con la respiracion dibujada, ida y vuelta: la posicion p
			# es la inspiracion k (0 = el fotograma base, sin aire)
			var kk := int(_sec["k_reposo"])
			var k := _sprite.frame if _sprite.frame < kk else 2 * kk - 2 - _sprite.frame
			if _accion != "" and _accion_aqui() != "":
				# sacar / guardar: parten del fotograma base, como los puentes
				if k == 0:
					_empezar_accion()
				else:
					_sprite.frame = maxi(k - 3, 0)
				return
			if quiere != "":
				var pr: Dictionary = _sec["puente_reposo"][anim]
				# correr (sin baston, 2026-10-12): doble toque hacia donde mira, como en el
				# perfil. Tras el primer toque espera DOBLE_TOQUE antes de echar a andar
				# (solapado con la espiracion), por si llega el segundo
				var puede_correr: bool = quiere == _cara and pr.has("arrc")
				if puede_correr and not _corriendo and _reloj - float(_pulsado_en.get(quiere, -10.0)) < DOBLE_TOQUE:
					_sprite.frame = maxi(k - 3, 0)
					return
				if k == 0:
					if puede_correr and _corriendo:
						_cb_puente(pr["arrc"])
					else:
						_cb_puente(pr["arr"] if quiere == _cara else pr["vu"])
				else:
					_sprite.frame = maxi(k - 3, 0)     # exhala deprisa (0,2 s como mucho)
				return
			_sprite.frame = (_sprite.frame + 1) % n
		"arranque":
			if _sprite.frame + 1 >= n:
				var e: Array = _sec["entra_bucle"][anim]
				_poner_anim(e[0], int(e[1]))
				_cb = "correr" if String(e[0]).begins_with("correr") else "andar"
				return
			_sprite.frame += 1
			_cb_escala_tramo(anim)
		"correr":
			# como andar (mas deprisa); al soltar, cambiar de cara o pedir sacar / guardar,
			# por la fase de salida del bucle a la parada (frena de verdad, como en el video)
			var sale: Array = _sec["a_parada"][anim]
			if (quiere != _cara or not _corriendo) and _sprite.frame == int(sale[1]):
				_cb_puente(sale[0])
				return
			_sprite.frame = (_sprite.frame + 1) % n
			_cb_escala(1.0 / (1.0 / _escala + float(_sec["paso"][anim])))
		"parada":
			# frenando: avanza lo que dice su h (como el arranque, al reves); al acabar, al
			# reposo por su puente
			if _sprite.frame + 1 >= n:
				_cb_puente("%spc%s_r%s" % [_pre(), c, c])
				return
			_sprite.frame += 1
			_cb_escala_tramo(anim)
		"andar":
			var pj: Array = _sec["pies_juntos"][anim]
			# doble toque andando (sin baston, como en el perfil): a correr en los pies
			# juntos, por su puente al arranque de la carrera (ya a la velocidad del andar)
			var ac: Dictionary = _sec.get("a_correr", {}).get(anim, {})
			if quiere == _cara and _corriendo and _sprite.frame in pj and ac.has(str(_sprite.frame)):
				_cb_puente(String(ac[str(_sprite.frame)]))
				return
			# al soltar, un momento por si es el primer toque de un doble: sigue andando
			var q := quiere
			if q == "" and _reloj - _soltado_en < DOBLE_TOQUE:
				q = _cara
			if q != _cara and _sprite.frame in pj:
				if q == "":
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
			elif String(a[0]).begins_with("arranque") or String(a[0]).begins_with("parada"):
				_cb = "arranque" if String(a[0]).begins_with("arranque") else "parada"
				_cb_h0 = float(_sec["h"][a[0]][0])
				_cb_base = _escala
				# entrando a mitad (de andar a correr): el avance va acumulado desde el
				# primer fotograma; la base, la que deja la escala donde esta
				var av = _sec.get("avance", {}).get(a[0])
				if av != null and int(a[1]) > 0:
					_cb_base = 1.0 / (1.0 / _escala - float(av[int(a[1])]))
			else:
				_cb = "reposo"
		"accion":
			if _sprite.frame + 1 < n - (RECORTE_ACCION.get(anim, Vector2i.ZERO) as Vector2i).y:
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
			if _a_perfil and _sprite.frame == (_perfil_en if _perfil_en >= 0 else _fotograma_perfil()):
				_a_perfil = false
				_cb = "perfil"
				en_perfil.emit()
				return
			var f := _sprite.frame + _cb_dir
			if f >= 0 and f < n:
				_sprite.frame = f
				return
			_cara = "espalda" if _cb_dir > 0 else "frente"
			if _cb_dir > 0:
				if quiere == "espalda" and _sec["puentes"].has(_pre() + "vu_arrb"):
					# la vuelta y el andar de espaldas de videos distintos (sin baston,
					# 2026-10-12): por un puente
					_cb_puente(_pre() + "vu_arrb")
				elif quiere == "espalda":
					# 153 -> 154: seguido en el video
					_poner_anim("arranque_espalda" + _suf(), 0)
					_cb = "arranque"
					_cb_h0 = float(_sec["h"]["arranque_espalda" + _suf()][0])
					_cb_base = _escala
				else:
					_cb_puente(_pre() + "vu_rb")
			else:
				# con sacar / guardar pendiente, al reposo de frente (no a andar)
				_cb_puente(_pre() + ("vu_arrf" if quiere == "frente" and _accion == "" else "vu_rf"))


## Sacar o guardar: al sacar ya es el modo con baston (la bola va en la garra
## del video); al guardar lo sigue siendo hasta acabar en el reposo sin baston.
func _empezar_accion() -> void:
	var nombre := _accion_aqui()
	if _accion.begins_with("sacar"):
		_con_baston = true
		_sec = _secs[true]
	_cb = "accion"
	_poner_anim(nombre, (RECORTE_ACCION.get(nombre, Vector2i.ZERO) as Vector2i).x)


## La animacion de la accion pedida (sacar_baston / guardar_baston) para la cara a
## la que mira; "" si de esa cara no hay (se da la vuelta y la hace de frente).
func _accion_aqui() -> String:
	var nombre := "%s_%s" % [_accion, _cara]
	return nombre if _acciones.has(nombre) else ""


## La escala en un arranque o una parada: las carreras traen su "avance" (lo que suma
## 1/escala desde el primer fotograma, como el paso del bucle); el andar, su h (la del
## video, relativa al primer fotograma).
func _cb_escala_tramo(anim: String) -> void:
	var av = _sec.get("avance", {}).get(anim)
	if av != null:
		_cb_escala(1.0 / (1.0 / _cb_base + float(av[_sprite.frame])))
	else:
		var h: Array = _sec["h"][anim]
		_cb_escala(_cb_base * float(h[_sprite.frame]) / _cb_h0)


func _cb_escala(nueva: float) -> void:
	nueva = clampf(nueva, escala_min, escala_max)
	_y += float(_sec["baja"]) * (nueva - _escala)
	_escala = nueva


## Sin baston en la mano: el de scenes/characters/baston.tscn entero (madera, bola,
## luz) a la espalda, por FUERA de la tunica, en diagonal y metido en la funda
## de cuero (funda_cuero.py; la idea es el concepto de Gemini). Cada fila de
## "baston_espalda": [x, y, giro, corte, ancho]. El baston va en 3D, en un plano
## pegado por detras a la espalda (secuencia.py, baston_espalda): entero DETRAS
## del cuerpo y, encima, una copia DELANTE (MaderaDelante de baston.tscn)
## recortada de la bola hasta "corte" (fraccion del alto de baston.png): 0 de
## frente, 1 de espaldas; en la vuelta, 0, solo la garra (la bola ya delante de
## la capucha) o 1 pasado el perfil. La bola y la funda van delante cuando su
## tramo lo esta. "ancho": el de la funda (de canto, de perfil, se ve estrecha).
## La escala del baston a la espalda dibujado aqui: la de espaldas o la de
## frente (ver baston_espalda_escala); en la vuelta, con el giro. De paso, lo
## que se engorda su trazo (_engordar).
func _escala_del_palo(f: Array) -> Vector2:
	var t := 1.0 if float(f[3]) >= 0.5 else 0.0
	_de_espaldas = t > 0.5
	var anim := String(_sprite.animation)
	if anim.begins_with("vuelta"):
		var giro: Array = _sec.get("giro_vuelta", [])
		if not giro.is_empty():
			t = clampf(float(giro[mini(_sprite.frame, giro.size() - 1)]) / 180.0, 0.0, 1.0)
	_engordar = lerpf(baston_frente_engordar, baston_espalda_engordar, t)
	if t > 0.5:
		_de_espaldas = true
	elif anim.begins_with("vuelta"):
		_de_espaldas = false
	return baston_frente_escala.lerp(baston_espalda_escala, t)


## La textura del baston a la espalda: de espaldas, baston_espalda.png (el de la
## mano); de frente, baston.png. Las dos con la bola en el mismo sitio del pivote.
func _textura_del_palo() -> void:
	if _de_espaldas == _textura_espaldas:
		return
	_textura_espaldas = _de_espaldas
	for n in ["Madera", "MaderaDelante"]:
		var sp := _bola.get_node(n) as Sprite2D
		if not _de_espaldas:
			sp.texture = _tex_baston
			sp.offset = _offset_baston
		else:
			var be: Dictionary = _datos["baston_espalda"]
			var tam := Vector2(be["tam"][0], be["tam"][1])
			var b := Vector2(be["bola"][0], be["bola"][1])
			sp.texture = BASTON_ESPALDA_TEX
			sp.offset = ORBE_EN_MADERA - (b - tam / 2.0)


func _baston_a_la_espalda(lista: Array) -> void:
	var f: Array = lista[mini(_sprite.frame, lista.size() - 1)]
	_madera(true)
	_bola.visible = true
	var ancho_palo := _escala_del_palo(f)
	_textura_del_palo()
	_bola.scale = ancho_palo * _escala
	# el trazo, mas gordo (corte_madera.gdshader o el shader de la escena)
	for n in ["Madera", "MaderaDelante"]:
		((_bola.get_node(n) as CanvasItem).material as ShaderMaterial).set_shader_parameter("engordar", _engordar)
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
		# (la correa, a su tamano aunque el palo vaya mas grueso)
		(sp as Sprite2D).scale = Vector2(_funda_escala * ancho / ancho_palo.x, _funda_escala / ancho_palo.y)
	for ci in [delante, _funda_atras, _funda_delante, _funda_atras_f, _funda_delante_f]:
		(ci as CanvasItem).modulate = luz_baston * (tinte_baston if ci == delante else Color.WHITE)
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


func _capa_funda(textura: Texture2D, fj: Dictionary, z: int, absoluta := false) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = textura
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
	madera.self_modulate = Color(luz_baston.r * tinte_baston.r, luz_baston.g * tinte_baston.g, luz_baston.b * tinte_baston.b,
		luz_baston.a if si else 0.0)
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


## Sacar / guardar de espaldas: la bola va detras del sprite (los dedos de la
## garra del video, encima), como en la mano; con el baston ya a la espalda va
## delante y su halo cae sobre la capucha. Al acabar el guardar la capucha se
## encendia de golpe (y al empezar el sacar se apagaba): el halo se reparte entre
## la bola de detras (1 - t) y una copia de solo el halo por delante del cuerpo (t),
## t de 0 en la mano a 1 en la espalda (lo que lleva recorrido la escala de la bola).
func _halo_de_espaldas(t: float) -> void:
	t = clampf(t, 0.0, 1.0)
	var orbe := _bola.get_node("Madera/Orbe") as CanvasItem
	(orbe.material as ShaderMaterial).set_shader_parameter("halo", _halo0 * (1.0 - t))
	(_halo_delante.material as ShaderMaterial).set_shader_parameter("halo", _halo0 * t)
	_halo_delante.visible = t > 0.0 and orbe.visible


## Vuelta con baston, fotogramas en que la garra pasa por delante de la cara: la
## bola, detras del sprite, quedaba tapada por la capucha que se ve en el hueco de
## la garra (el usuario: "la bola se vuelve transparente"). Ahi, la esfera delante
## del cuerpo y encima los dedos de la garra (vuelta_garra.json).
func _garra_por_delante(con_bola: bool) -> void:
	var f = _vuelta_garra.get(String(_sprite.animation), {}).get(_sprite.frame) if con_bola else null
	var si: bool = f != null and (_bola.get_node("Madera/Orbe") as CanvasItem).visible and _fundido <= 0.0
	_esfera_delante.visible = si
	_garra_vuelta.visible = si
	if si:
		_garra_vuelta.texture = f[1]
		_garra_vuelta.position = _sprite.position + (_sprite.offset + f[0]) * _escala
		_garra_vuelta.scale = Vector2.ONE * _escala


## Donde van los pies con la escala de ahora (espacio del nodo).
func _pies() -> Vector2:
	if perspectiva.is_valid():
		return perspectiva.call(_escala)
	return Vector2(0.0, _y)


func _colocar() -> void:
	_sprite.position = _pies()
	_sprite.scale = Vector2.ONE * _escala
	_fantasma.visible = _fundido > 0.0
	_fantasma.position = _sprite.position
	_fantasma.scale = _sprite.scale
	_fantasma.modulate.a = _fundido
	# bola y garra, solo con el baston y en lo que tenga datos
	var d = _orbes.get(String(_sprite.animation)) if _con_baston else null
	_bola.visible = d != null
	# sin magia, sin bola (la garra si: es el remate del baston)
	for n in ["Madera/Orbe", "Madera/Luz"]:
		(_bola.get_node(n) as CanvasItem).visible = not _sin_magia()
	var con_garra: bool = d != null and d.has("garra")
	_madera(false)
	_halo_de_espaldas(0.0)
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
			# la de en la mano, la del extremo de las filas que no es 1
			var mano := maxf(float(d["orbe"][0][2]), float(d["orbe"][-1][2]))
			if String(_sprite.animation).ends_with("_espalda") and mano > 1.0:
				_halo_de_espaldas((mano - e) / (mano - 1.0))
		_bola.scale = Vector2.ONE * _escala * e
		_bola.rotation = giro
		_bola.position = _sprite.position + (_sprite.offset + Vector2(o[0], o[1])) * _escala \
			- ORBE_EN_MADERA.rotated(giro) * _escala * e
		if _fundido > 0.0 and _bola_antes != Vector2.ZERO:
			_bola.position = _bola.position.lerp(_bola_antes, _fundido)
	_garra_por_delante(d != null)
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
			_garra.texture = _textura(d["garra_textura"])
			_garra.offset = -Vector2(d["garra_pivote"][0], d["garra_pivote"][1])
		var g: Array = d["garra"][mini(_sprite.frame, d["garra"].size() - 1)]
		_garra.position = _sprite.position + (_sprite.offset + Vector2(g[0], g[1])) * _escala
		_garra.rotation = g[2]
		_garra.scale = Vector2.ONE * _escala * float(d["garra_escala"])
	colocado.emit()
	_luz_del_baston()


## Con material de escena: el baston a la espalda y su correa con los mismos
## parametros que el cuerpo (los pone la escena, en su _process o al colocarse)
## y el tamano de su texel en pantalla.
func _luz_del_baston() -> void:
	if _mat_madera == null:
		return
	var raiz := material as ShaderMaterial
	# donde esta la garra (en la mano, la del dibujo; a la espalda, la dibujada
	# aqui): la bola va en su hueco, este o no a la vista
	if _con_garra:
		var g := Vector3.ZERO
		if _bola.visible:
			var c := (_bola.get_node("Madera/Orbe") as Node2D).global_position
			g = Vector3(c.x, c.y, RADIO_GARRA * _escala * absf(global_scale.y))
		raiz.set_shader_parameter("garra", g)
	for nombre in _uniformes:
		var v = raiz.get_shader_parameter(nombre)
		for m in [_mat_madera, _mat_delante, _mat_funda, _mat_funda_f, _mat_vacia]:
			m.set_shader_parameter(nombre, v)
	_mat_madera.set_shader_parameter("px_por_texel", absf((_bola.get_node("Madera") as Node2D).global_scale.y))
	_mat_delante.set_shader_parameter("px_por_texel", absf((_bola.get_node("MaderaDelante") as Node2D).global_scale.y))
	_mat_funda.set_shader_parameter("px_por_texel", absf(_funda_atras.global_scale.y))
	_mat_funda_f.set_shader_parameter("px_por_texel", absf(_funda_atras_f.global_scale.y))
	_mat_vacia.set_shader_parameter("px_por_texel", absf((_funda_vacia.get_child(0) as Node2D).global_scale.y))
