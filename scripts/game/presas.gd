extends Node2D
## Las hojas-presa: cuando aparece el baculo, unas hojas grandes bajan de el y se
## quedan flotando en el haz en zigzag, de izquierda a derecha y cada una mas
## alta, como presas de escalada que llevan hasta el. Se alcanzan saltando: en
## la luz se pesa poco y apoyarse en una impulsa (eso lo hara Magnus cuando
## tenga su flotar; aqui de momento estan, se ven y dicen donde estan).
##
## Se distinguen de las hojas de decorado: mas grandes, de cara y casi
## horizontales, con el borde encendido, y solo dentro del haz.
##
##   aparecer(desde)  bajan una a una desde `desde` (el baculo) a su sitio.
##   sitios()         donde esta cada una ahora (para el apoyo, mas adelante).

const ATLAS := preload("res://assets/world/hojarasca/hojas.png")
const MOTA := preload("res://assets/world/hojarasca/mota.png")
const CELDA := Vector2(64, 128)

## Cuantas, desde que altura hasta cual (y) y cuanto se apartan del eje del haz
## a cada lado.
@export var cuantas: int = 6
@export var y_abajo: float = 1060.0
@export var y_arriba: float = 600.0
@export var aparte: float = 105.0
## Lo que tarda cada una en llegar a su sitio y entre una y la siguiente (s).
@export var bajada: float = 1.8
@export var entre: float = 0.35
@export var escala: float = 0.9

var _hojas: Array[Dictionary] = []   # {nodo, sitio, fase}
var _t := 0.0

func aparecer(desde: Vector2) -> void:
	for i in cuantas:
		var f := float(i) / maxf(cuantas - 1, 1)
		var y := lerpf(y_abajo, y_arriba, f)
		var lado := -1.0 if i % 2 == 0 else 1.0
		var sitio := Vector2(preload("res://scripts/game/baculo.gd").x_haz(y) + lado * aparte, y)
		var nodo := _hacer_hoja(i)
		nodo.position = desde
		nodo.modulate.a = 0.0
		add_child(nodo)
		var h := {nodo = nodo, sitio = sitio, fase = randf() * TAU, llegada = false}
		_hojas.append(h)
		var tw := create_tween()
		tw.tween_interval(entre * i)
		tw.tween_property(nodo, "modulate:a", 1.0, 0.6)
		tw.parallel().tween_property(nodo, "position", sitio, bajada).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void: h.llegada = true)

func sitios() -> Array[Vector2]:
	var r: Array[Vector2] = []
	for h in _hojas:
		r.append((h.nodo as Node2D).position)
	return r

func _hacer_hoja(i: int) -> Node2D:
	var nodo := Node2D.new()
	var brillo := Sprite2D.new()
	brillo.texture = MOTA
	var suma := CanvasItemMaterial.new()
	suma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	brillo.material = suma
	brillo.modulate = Color(1.0, 0.75, 0.4, 0.28)
	brillo.scale = Vector2(2.6, 1.1)
	nodo.add_child(brillo)
	var hoja := Sprite2D.new()
	hoja.texture = ATLAS
	hoja.region_enabled = true
	var celda := (i * 5 + 3) % 32
	hoja.region_rect = Rect2(Vector2(celda % 8, celda / 8) * CELDA, CELDA)
	hoja.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Tumbada de lado (la hoja del atlas va de punta arriba) y algo aplastada:
	# una plataforma vista de canto, no una hoja de frente.
	hoja.rotation = PI / 2.0 + randf_range(-0.12, 0.12)
	hoja.scale = Vector2(escala * 0.62, escala)
	hoja.modulate = Color(1.15, 1.02, 0.85)
	nodo.add_child(hoja)
	return nodo

func _process(delta: float) -> void:
	_t += delta
	for h in _hojas:
		if not h.llegada:
			continue
		var nodo: Node2D = h.nodo
		var fase: float = h.fase
		nodo.position = h.sitio + Vector2(3.0 * sin(_t * 0.9 + fase), 6.0 * sin(_t * 1.4 + fase))
		nodo.rotation = 0.05 * sin(_t * 1.1 + fase)
