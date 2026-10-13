extends Node2D
## Hojas lejanas que caen entre los arboles del bosque de fondo de la
## hojarasca (con bosque_de_fondo, ver caida_hojarasca.gd): pequenas, apagadas
## y lentas (estan lejos, en la niebla), con el paralaje del bosque (sigue: lo
## que acompanan a la camara; el suelo es 1) y empujadas por las rachas. Dan
## vida y profundidad al fondo sin tocar la luz: donde no les da el haz casi
## no se ven. Van detras de todo lo del mundo (justo despues del bosque).

const ATLAS := preload("res://assets/world/hojarasca/hojas.png")
const COLS := 8
const FILAS := 4
const CELDA := Vector2(64, 128)
const ANCHO := 2912.0

@export var cuantas: int = 38
@export var escala: Vector2 = Vector2(0.06, 0.12)
## Caida (px/s) y vaiven de lado (px).
@export var velocidad: Vector2 = Vector2(22.0, 48.0)
@export var vaiven: Vector2 = Vector2(10.0, 30.0)
## Brillo: en la niebla y donde les da el haz.
@export var brillo: float = 0.42
@export var brillo_haz: float = 0.6
@export var sigue: float = 0.3
## Por debajo, la bruma y el lecho: se van y vuelven a caer desde arriba.
@export var y_hasta: float = 1000.0

var _h: Array[Dictionary] = []
var _escena: Node

func _ready() -> void:
	_escena = get_parent()
	for i in cuantas:
		_h.append(_nueva(randf_range(-40.0, y_hasta)))

func _nueva(y: float) -> Dictionary:
	return {
		"p": Vector2(randf() * ANCHO, y),
		"v": randf_range(velocidad.x, velocidad.y),
		"esc": randf_range(escala.x, escala.y),
		"rot": randf() * TAU,
		"giro": randf_range(-1.2, 1.2),
		"fase": randf() * TAU,
		"amp": randf_range(vaiven.x, vaiven.y),
		"w": randf_range(0.5, 1.1),
		"celda": randi() % (COLS * FILAS),
		"tono": randf_range(0.8, 1.15),
	}

func _process(delta: float) -> void:
	visible = _escena.bosque_de_fondo
	if not visible:
		return
	var viento: float = _escena._racha * _escena._racha_dir
	for h in _h:
		h["fase"] += h["w"] * delta
		var p: Vector2 = h["p"]
		p.y += h["v"] * delta * (1.0 + 0.3 * absf(viento))
		p.x += (cos(h["fase"]) * h["amp"] * h["w"] + viento * 70.0) * delta
		h["rot"] += (h["giro"] + sin(h["fase"]) * 0.8) * delta
		if p.y > y_hasta:
			var n := _nueva(-30.0)
			h.merge(n, true)
			p = n["p"]
		h["p"] = Vector2(fposmod(p.x, ANCHO), p.y)
	queue_redraw()

func _draw() -> void:
	# Paralaje: el nodo se mueve con el mundo; las hojas vuelven atras lo que
	# no les toca por estar lejos (como el bosque, bosque_fondo.gdshader).
	var atras: Vector2 = _escena._respira * (1.0 - sigue)
	for h in _h:
		var p: Vector2 = h["p"]
		var l: float = (brillo + brillo_haz * _escena.luz_en(p)) * h["tono"]
		var celda: int = h["celda"]
		var region := Rect2(Vector2(celda % COLS, celda / COLS) * CELDA, CELDA)
		var esc: float = h["esc"]
		# Gira sobre su eje largo al caer: se ve de canto a ratos.
		var ex: float = esc * maxf(absf(cos(h["fase"] * 1.3)), 0.15)
		draw_set_transform(p + atras, h["rot"], Vector2(ex, esc))
		draw_texture_rect_region(ATLAS, Rect2(-CELDA / 2.0, CELDA), region, Color(l, l * 0.9, l * 0.84, 0.85))
	draw_set_transform(Vector2.ZERO)
