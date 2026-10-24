extends Node
## PRECARGA DEL PEREGRINO (2026-10-14). El peregrino sale en todo el juego con
## todas sus animaciones, de perfil y de frente (el usuario: "se van a usar
## siempre, no puedo cargar por acciones"): peregrino_frames.tres son ~4.400
## fotogramas en 56 hojas (~330 MB de memoria de video). Cargarlo al entrar en
## la hojarasca (con su script, el baston y las acciones) alargaba el negro
## tras el titulo (medido, cargando a la vez: compilar peregrino.gd con lo suyo
## 2,8 s, las animaciones 2 s, las hojas 60-200 ms cada una).
## Se carga una vez, en segundo plano, al segundo de arrancar (en el ataud, aun
## a oscuras) y se guarda aqui para todo el juego: las escenas que lo usan lo
## encuentran ya en la cache de ResourceLoader. Medido con la maquina libre:
## del negro del titulo a la hojarasca, 1,4 s en vez de 3,6; en el ataud, un
## tiron de 0,3-0,6 s al empezar (los de ~0,8 s que salen mas tarde salen
## igual sin la precarga).
## Un solo hilo (sin subhilos) y una cosa cada vez, para quitarle lo minimo al
## ataud.
## SIN_PRECARGA=1 en el entorno la desactiva (para medir).

const RUTAS := [
	# la limpia (tools/anim/hojas: procesar.py + integrar.py del correr nuevo), la del
	# juego desde el 2026-10-22; peregrino_frames.tres queda de origen para las herramientas
	"res://resources/characters/peregrino_frames_limpio.tres",
	# el de frente / espaldas, aparte y solo en HD desde el 2026-10-19 (~270 MB)
	"res://resources/characters/peregrino_frontal_hd.tres",
	"res://scenes/characters/peregrino.tscn",
	"res://scenes/characters/baston.tscn",
	"res://scripts/characters/acciones_perfil.gd",
	# las que se cargan a mano (flotar en peregrino.gd, las limpias de flotar_limpio.json,
	# y la mano en baston.gd)
	"res://assets/characters/peregrino_limpio/peregrino_flotar_bajar.png",
	"res://assets/characters/peregrino_limpio/peregrino_flotar_posarse.png",
	"res://assets/characters/peregrino_limpio/peregrino_flotar_girar.png",
	"res://assets/characters/peregrino_limpio/peregrino_flotar_pisar.png",
	"res://assets/characters/peregrino_limpio/peregrino_flotar_despegar.png",
	"res://assets/characters/peregrino_limpio/peregrino_flotar_llegar.png",
	"res://assets/characters/peregrino_limpio/peregrino_flotar_quieto.png",
	"res://assets/characters/peregrino_limpio/peregrino_coger_baculo.png",
	"res://assets/characters/baston/mano_reposo.png",
	"res://assets/characters/baston/mano_arranque_andar.png",
	"res://assets/characters/baston/mano_andar.png",
	"res://assets/characters/baston/mano_parada_andar.png",
	"res://assets/characters/baston/mano_giro.png",
	"res://assets/characters/baston/mano_sacar_baston.png",
	"res://assets/characters/baston/mano_guardar_baston.png",
]
## Segundos tras arrancar antes de pedirla: que el ataud ya este en marcha.
const ESPERA := 1.0

var _cargados := {}
var _pedidas: Array[String] = []

func _ready() -> void:
	if OS.get_environment("SIN_PRECARGA") != "" or OS.has_feature("nothreads"):
		set_process(false)
		return
	set_process(false)
	get_tree().create_timer(ESPERA).timeout.connect(_pedir)

## Mientras haya alguien en este grupo, la precarga espera: el titulo en modo
## menu (al abrir el juego con partida) se mete en el mientras se enciende la
## sala, para que la carga no le de tirones; con la sala puesta y el menu a la
## vista sale del grupo y la carga empieza.
const GRUPO_ESPERA := &"precarga_espera"

func _pedir() -> void:
	if get_tree().get_first_node_in_group(GRUPO_ESPERA):
		get_tree().create_timer(0.5).timeout.connect(_pedir)
		return
	# Todas cuentan como pedidas desde ya (en_marcha), pero se cargan de una en
	# una: pedidas a la vez, peregrino.tscn cargaba peregrino_frames.tres como
	# dependencia mientras otra peticion cargaba el mismo archivo, y a veces
	# chocaban ("Another resource is loaded from path ...::atlas_264", visto el
	# 2026-10-17).
	_pedidas.assign(RUTAS)
	_siguiente()
	set_process(true)

## La que se esta cargando ahora ("" si ninguna).
var _actual := ""
## Lo de otro que se espera a que acabe antes de seguir ("" si nada).
var _espera := ""


## Lo que esta cargando ahora ("" si nada): quien vaya a cargar algo grande espera.
func cargando() -> String:
	return _actual

func _siguiente() -> void:
	_actual = ""
	_espera = ""
	for r in _pedidas:
		if _cargados.has(r):
			continue
		# (2026-10-19) si otro ya carga algo grande en segundo plano (el peregrino de
		# frente, PeregrinoFrontal.precargar), se espera a que acabe: dos .tres grandes a
		# la vez, a veces fallaba la lectura de uno ("Parse Error")
		var hd := "res://resources/characters/peregrino_frontal_hd.tres"
		if r != hd and ResourceLoader.load_threaded_get_status(hd) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_espera = hd
			return
		if ResourceLoader.load_threaded_request(r) == OK:
			_actual = r
			return
		_cargados[r] = null

## Recoge la que este cargando (y la guarda: mientras haya una referencia, la
## cache no la suelta) y pide la siguiente.
func _process(_delta: float) -> void:
	if _espera != "":
		if ResourceLoader.load_threaded_get_status(_espera) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_siguiente()
		return
	if _actual == "":
		set_process(false)
		return
	match ResourceLoader.load_threaded_get_status(_actual):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		ResourceLoader.THREAD_LOAD_LOADED:
			_cargados[_actual] = ResourceLoader.load_threaded_get(_actual)
		_:
			_cargados[_actual] = null
	_siguiente()
	if _actual == "" and _espera == "":
		set_process(false)

## Si se ha pedido y aun no ha acabado: quien vaya a cargar algo que tire de lo
## mismo (la pantalla de titulo, la escena siguiente) espera a que acabe.
func en_marcha() -> bool:
	return _pedidas.size() > 0 and _cargados.size() < _pedidas.size()

## Si ya esta todo (para quien quiera esperarla).
func lista() -> bool:
	return _pedidas.size() > 0 and _cargados.size() == _pedidas.size()
