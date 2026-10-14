extends Node
## PRECARGA DEL PEREGRINO (2026-10-14). El peregrino sale en todo el juego con
## todas sus animaciones, de perfil y de frente (el usuario: "se van a usar
## siempre, no puedo cargar por acciones"): magnus_frames.tres son ~4.400
## fotogramas en 56 hojas (~330 MB de memoria de video). Cargarlo al entrar en
## la hojarasca (con su script, el baston y las acciones) alargaba el negro
## tras el titulo (medido, cargando a la vez: compilar magnus.gd con lo suyo
## 2,8 s, las animaciones 2 s, las hojas 60-200 ms cada una).
## Se carga una vez, en segundo plano, al segundo de arrancar (en el ataud, aun
## a oscuras) y se guarda aqui para todo el juego: las escenas que lo usan lo
## encuentran ya en la cache de ResourceLoader. Medido con la maquina libre:
## del negro del titulo a la hojarasca, 1,4 s en vez de 3,6; en el ataud, un
## tiron de 0,3-0,6 s al empezar (los de ~0,8 s que salen mas tarde salen
## igual sin la precarga).
## Un solo hilo (sin subhilos), para quitarle lo minimo al ataud.
## SIN_PRECARGA=1 en el entorno la desactiva (para medir).

const RUTAS := [
	"res://resources/characters/magnus_frames.tres",
	"res://scenes/characters/magnus.tscn",
	"res://scenes/characters/baston.tscn",
	"res://scripts/characters/acciones_perfil.gd",
	# las que se cargan a mano (flotar en magnus.gd y la mano en baston.gd)
	"res://assets/characters/magnus/magnus_flotar_bajar.png",
	"res://assets/characters/magnus/magnus_flotar_posarse.png",
	"res://assets/characters/magnus/magnus_flotar_girar.png",
	"res://assets/characters/magnus/magnus_flotar_pisar.png",
	"res://assets/characters/magnus/magnus_coger_baculo.png",
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

func _pedir() -> void:
	for r in RUTAS:
		if ResourceLoader.load_threaded_request(r) == OK:
			_pedidas.append(r)
	set_process(true)

## Recoge lo que vaya acabando (y lo guarda: mientras haya una referencia, la
## cache no lo suelta).
func _process(_delta: float) -> void:
	var quedan := false
	for r in _pedidas:
		if _cargados.has(r):
			continue
		match ResourceLoader.load_threaded_get_status(r):
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				quedan = true
			ResourceLoader.THREAD_LOAD_LOADED:
				_cargados[r] = ResourceLoader.load_threaded_get(r)
			_:
				_cargados[r] = null
	if not quedan:
		set_process(false)

## Si ya esta todo (para quien quiera esperarla).
func lista() -> bool:
	return _pedidas.size() > 0 and _cargados.size() == _pedidas.size()
