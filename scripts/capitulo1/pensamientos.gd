extends CanvasLayer
## Pensamientos del peregrino: el unico texto del capitulo. Primera persona,
## abajo en el centro, sin caja. Uno cada vez, nunca se repite y nunca para el
## juego. Cada pensamiento puede tener varias partes que salen una tras otra en
## el mismo sitio ("¿Esta atardeciendo?" ... "¿O amanece?").
##
## Un pensamiento es de su momento: si no ha podido salir a tiempo, caduca y no
## sale (mejor callado que a destiempo). Los "urgentes" cortan lo que se este
## diciendo. Los "opcionales" (los que dependen de lo que haga el jugador) nunca
## salen dos seguidos.

signal terminado

const FUENTE := preload("res://assets/fonts/IMFellEnglish-Italic.ttf")

@export var tam_letra: int = 60
## Segundos minimos entre el final de un pensamiento y el principio del siguiente.
@export var separacion: float = 1.5
@export var alfa: float = 0.88
## Por defecto, lo que puede esperar un pensamiento en la cola antes de caducar.
@export var caducidad: float = 6.0

var _etiqueta: Label
var _cola: Array = []  # {partes, hasta, opcional}
var _dichos := {}
var _ocupado := false
var _reloj := 0.0
var _libre_desde := -INF
var _ultimo_opcional := false
var _tw: Tween
var _turno := 0  # para cortar un pensamiento a medias
## Para las pruebas grabadas: MAQUETA_TRAZA=1 imprime cada pensamiento con su segundo.
var _trazar := OS.has_environment("MAQUETA_TRAZA")

func _ready() -> void:
	layer = 10
	var ajustes := LabelSettings.new()
	ajustes.font = FUENTE
	ajustes.font_size = tam_letra
	ajustes.font_color = Color(0.91, 0.87, 0.78)
	ajustes.shadow_color = Color(0, 0, 0, 0.7)
	ajustes.shadow_size = 14
	ajustes.shadow_offset = Vector2(0, 3)
	_etiqueta = Label.new()
	_etiqueta.label_settings = ajustes
	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Por debajo del reflejo del peregrino en el agua.
	_etiqueta.position = Vector2(0, 1632.0 * 0.89 - 90.0)
	_etiqueta.size = Vector2(2912, 180)
	_etiqueta.modulate.a = 0.0
	add_child(_etiqueta)

## Pone un pensamiento en cola. La clave evita que se repita.
func decir(clave: String, partes: Array, urgente := false, opcional := false, espera := -1.0) -> void:
	if _dichos.has(clave):
		return
	if opcional and _ultimo_opcional:
		return  # no se marca como dicho: podra salir mas adelante
	_dichos[clave] = true
	_ultimo_opcional = opcional
	var entrada := {partes = partes, hasta = _reloj + (espera if espera > 0.0 else caducidad), opcional = opcional}
	if urgente:
		_cola.clear()
		_cortar()
		_libre_desde = -INF
	_cola.append(entrada)

## Olvida lo que estaba en cola y apaga lo que se esta diciendo.
func callar() -> void:
	_cola.clear()
	_cortar()
	_libre_desde = -INF

func dicho(clave: String) -> bool:
	return _dichos.has(clave)

func hablando() -> bool:
	return _ocupado or not _cola.is_empty()

func _cortar() -> void:
	if not _ocupado:
		return
	_turno += 1
	if _tw and _tw.is_valid():
		_tw.kill()
	var tw := create_tween()
	tw.tween_property(_etiqueta, "modulate:a", 0.0, 0.4)
	_ocupado = false
	terminado.emit()

func _process(delta: float) -> void:
	_reloj += delta
	while not _cola.is_empty() and _cola[0].hasta < _reloj:
		_cola.pop_front()
	if _ocupado or _cola.is_empty() or _reloj - _libre_desde < separacion:
		return
	var entrada: Dictionary = _cola.pop_front()
	_ultimo_opcional = entrada.opcional
	_mostrar(entrada.partes)

func _mostrar(partes: Array) -> void:
	_ocupado = true
	_turno += 1
	var turno := _turno
	for i in partes.size():
		var texto: String = partes[i]
		_etiqueta.text = texto
		if _trazar:
			print("pensamiento t=%.2f %s" % [_reloj, texto])
		_tw = create_tween()
		_tw.tween_property(_etiqueta, "modulate:a", alfa, 0.6)
		_tw.tween_interval(1.2 + 0.04 * texto.length())
		_tw.tween_property(_etiqueta, "modulate:a", 0.0, 1.0 if i == partes.size() - 1 else 0.5)
		await _tw.finished
		if turno != _turno:
			return  # cortado
		if i < partes.size() - 1:
			await get_tree().create_timer(0.35).timeout
			if turno != _turno:
				return
	_ocupado = false
	_libre_desde = _reloj
	terminado.emit()

## Espera a que no quede nada por decir (o a que pase el tope).
func esperar_silencio(tope: float = 8.0) -> void:
	var hasta := _reloj + tope
	while hablando() and _reloj < hasta:
		await get_tree().process_frame
