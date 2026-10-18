extends CanvasLayer
## Pensamientos del peregrino: el texto del juego. Primera persona, sin caja,
## en cursiva IM Fell English. Nunca para el juego. Viene de la maqueta del
## capitulo 1 (rama maqueta-capitulo1), con dos cambios: los textos estan en un
## fichero (textos/pensamientos.csv, todos los idiomas juntos; ver
## textos/LEEME.md) y no en el codigo, y el sitio depende de donde este el
## personaje. Cada parte es una frase de las traducciones,
## pensamiento.<clave>.<n> con n desde 1, en el idioma que este puesto (Ajustes).
##
## Uno cada vez y ninguno se repite. Cada pensamiento puede tener varias partes
## que salen una tras otra en el mismo sitio. Si no ha podido salir a tiempo,
## caduca (mejor callado que a destiempo). Los urgentes cortan lo que se este
## diciendo.
##
## Donde: en el lado contrario al personaje (a la derecha si esta en la mitad
## izquierda, y al reves), a media altura sobre la oscuridad. Se elige al
## empezar cada pensamiento y no se mueve mientras se lee: asi no tapa la accion
## ni el haz y equilibra el cuadro.
##
## Voz (para mas adelante): si existe res://assets/voz/<clave>_<n>.ogg, suena con
## su parte y la parte dura lo que dure el audio. Si no, se calcula por letras.

signal empieza(clave: String)
## Al empezar cada parte (n desde 0): para atar algo a una frase concreta.
signal parte(clave: String, n: int)
signal terminado(clave: String)

const FUENTE := preload("res://assets/fonts/IMFellEnglish-Italic.ttf")
const ANCHO := 2912.0

@export var tam_letra: int = 58
@export var color: Color = Color(0.93, 0.88, 0.78)
@export var alfa: float = 0.9
## Caja de cada lado (x desde, x hasta) y altura del centro del texto.
@export var caja_izquierda: Vector2 = Vector2(180.0, 1120.0)
@export var caja_derecha: Vector2 = Vector2(1792.0, 2732.0)
@export var y_centro: float = 610.0
## Tiempos (s): fundidos, lo que dura una parte por letra (con minimo y maximo),
## entre partes de un mismo pensamiento y entre pensamientos.
@export var entrar: float = 0.9
@export var salir: float = 1.0
@export var por_letra: float = 0.055
@export var minimo: float = 2.0
@export var maximo: float = 5.5
@export var entre_partes: float = 0.3
@export var separacion: float = 1.2
## Lo que puede esperar un pensamiento en cola antes de caducar.
@export var caducidad: float = 8.0
@export var voz_db: float = 0.0

## func() -> float: x del personaje en pantalla (para elegir el lado).
var x_de: Callable

var _etiqueta: Label
var _voz: AudioStreamPlayer
var _cola: Array = []          # {clave, hasta}
var _dichos := {}
var _ocupado := false
var _reloj := 0.0
var _libre_desde := -INF
var _turno := 0
var _tw_parte: Tween            # el del texto que se esta diciendo (ver _cortar)

func _ready() -> void:
	layer = 15
	var ajustes := LabelSettings.new()
	ajustes.font = FUENTE
	ajustes.font_size = tam_letra
	ajustes.font_color = color
	ajustes.shadow_color = Color(0, 0, 0, 0.75)
	ajustes.shadow_size = 16
	ajustes.shadow_offset = Vector2(0, 3)
	ajustes.line_spacing = 6
	_etiqueta = Label.new()
	_etiqueta.label_settings = ajustes
	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etiqueta.modulate.a = 0.0
	add_child(_etiqueta)
	_voz = AudioStreamPlayer.new()
	_voz.volume_db = voz_db
	add_child(_voz)

## Las partes de un pensamiento en el idioma de ahora: pensamiento.<clave>.1,
## .2... hasta la primera que no exista. [] si no hay ninguna.
func _partes(clave: String) -> Array:
	var partes := []
	var n := 1
	while true:
		var k := "pensamiento.%s.%d" % [clave, n]
		var t := tr(k)
		if t == k:
			break
		partes.append(t)
		n += 1
	return partes

## Pone un pensamiento en cola. No se repite nunca.
func decir(clave: String, urgente := false) -> void:
	if _dichos.has(clave) or _partes(clave).is_empty():
		return
	_dichos[clave] = true
	if urgente:
		_cola.clear()
		_cortar()
		_libre_desde = -INF
	_cola.append({clave = clave, hasta = _reloj + caducidad})

func dicho(clave: String) -> bool:
	return _dichos.has(clave)

func hablando() -> bool:
	return _ocupado or not _cola.is_empty()

func callar() -> void:
	_cola.clear()
	_cortar()

func _cortar() -> void:
	_turno += 1
	_ocupado = false
	_voz.stop()
	# el tween del texto que se estaba diciendo, fuera: si aun entraba, seguia
	# subiendolo despues del fundido y el texto volvia (2026-10-14)
	if _tw_parte and _tw_parte.is_valid():
		_tw_parte.kill()
	var tw := create_tween()
	tw.tween_property(_etiqueta, "modulate:a", 0.0, 0.3)

func _process(delta: float) -> void:
	_reloj += delta
	if _ocupado or _cola.is_empty() or _reloj < _libre_desde:
		return
	var e: Dictionary = _cola.pop_front()
	if _reloj > e.hasta:
		return  # caducado
	_decir_ya(e.clave)

func _decir_ya(clave: String) -> void:
	_ocupado = true
	_turno += 1
	var turno := _turno
	_colocar()
	empieza.emit(clave)
	var partes := _partes(clave)
	for n in partes.size():
		if turno != _turno:
			return
		_etiqueta.text = String(partes[n])
		parte.emit(clave, n)
		var dura := clampf(minimo + por_letra * _etiqueta.text.length() * 0.5, minimo, maximo)
		var ruta := "res://assets/voz/%s_%d.ogg" % [clave, n + 1]
		if ResourceLoader.exists(ruta):
			_voz.stream = load(ruta)
			_voz.play()
			dura = maxf(_voz.stream.get_length() + 0.4, minimo)
		var tw := create_tween()
		_tw_parte = tw
		tw.tween_property(_etiqueta, "modulate:a", alfa, entrar).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(dura)
		tw.tween_property(_etiqueta, "modulate:a", 0.0, salir).set_trans(Tween.TRANS_SINE)
		await tw.finished
		if turno != _turno:
			return
		if n < partes.size() - 1:
			await get_tree().create_timer(entre_partes).timeout
	_ocupado = false
	_libre_desde = _reloj + separacion
	terminado.emit(clave)

## El lado contrario al personaje, a media altura.
func _colocar() -> void:
	var x: float = x_de.call() if x_de.is_valid() else 0.0
	var caja := caja_derecha if x < ANCHO * 0.5 else caja_izquierda
	_etiqueta.position = Vector2(caja.x, y_centro - 120.0)
	_etiqueta.size = Vector2(caja.y - caja.x, 240.0)
