extends Node2D
## PRUEBA de planos fijos al estilo Alone in the Dark, sin motor 3D: una galeria
## descrita en 3D (caras planas), proyectada a mano desde la camara del plano
## activo, y Magnus (su sprite de siempre) puesto en el punto que le toca y con
## el tamano que da la distancia. Cada plano (plano_fijo.gd, hijos de Planos)
## cubre un tramo de x; al cruzar a otro tramo hay corte.
##
## Magnus no sabe nada de esto: anda en x como siempre, metido en el nodo
## Proyeccion, al que se le pone cada fotograma la escala, el giro y la
## posicion de pantalla de sus pies. Por eso solo vale para planos en los que
## la galeria se vea de lado o en diagonal: sus animaciones son de perfil.
##
## Orden de dibujo: Sala (suelo, techo, paredes y las columnas que quedan
## detras de Magnus), Proyeccion (Magnus) y Delante (columnas por delante).
## Teclas: F alterna corte seco / fundido, M menu de pruebas, H oculta el texto.

const PANTALLA := Vector2(2912, 1632)
const MENU := "res://scenes/pruebas_camara/menu_pruebas_camara.tscn"
const LARGO := 6000.0
const MEDIO_ANCHO := 700.0
const ALTO := 1100.0
## Plano cercano: lo que queda mas cerca de la camara se recorta.
const CERCA := 20.0

@export var magnus_x_inicial: float = 350.0
## Corte con un pestaneo a negro en vez de seco.
@export var fundido: bool = false
@export var histeresis: float = 60.0
## Distancia a la que la luz cae a un tercio (niebla hacia negro).
@export var niebla: float = 5000.0
@export var luz_ambiente: float = 0.07

@onready var _magnus: Node2D = $Proyeccion/Magnus
@onready var _proyeccion: Node2D = $Proyeccion
@onready var _sala: Node2D = $Sala
@onready var _delante: Node2D = $Delante
@onready var _planos: Node = $Planos
@onready var _texto: Label = $Hud/Texto
@onready var _negro: ColorRect = $Hud/Negro

## Caras: {p: PackedVector3Array, c: PackedColorArray (ya iluminada), n, centro, doble}
var _fijas: Array = []
## Columnas: {centro: Vector3, caras: Array}
var _cajas: Array = []
## Luces: {pos, color, radio, fuerza}
var _luces: Array = []

var _plano: Node
var _pos := Vector3.ZERO
var _der := Vector3.RIGHT
var _arr := Vector3.UP
var _fre := Vector3.BACK
var _focal := 1500.0
var _orto := false
var _escala_orto := 1.0
var _alabeo := 0.0
var _ref_niebla := 0.0
var _seguido := 0.0
var _z_magnus := 0.0

func _ready() -> void:
	WindAmbience.gust_db = 0.0
	WindAmbience.fade_to(-14.0, 0.0)
	_magnus.position = Vector2(magnus_x_inicial, 0.0)
	_magnus.limite_izquierdo = 150.0
	_magnus.limite_derecho = LARGO - 150.0
	_magnus.frenada_limite_andar = 200.0
	_magnus.frenada_limite_correr = 380.0
	_construir()
	_sala.draw.connect(_dibujar_sala)
	_delante.draw.connect(_dibujar_delante)
	_negro.color.a = 0.0

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		match evento.keycode:
			KEY_M: get_tree().change_scene_to_file(MENU)
			KEY_H: _texto.visible = not _texto.visible
			KEY_F: fundido = not fundido

func _process(delta: float) -> void:
	var x := _magnus.position.x
	if _elegir_plano(x):
		_seguido = x
		if fundido:
			_negro.color.a = 1.0
			create_tween().tween_property(_negro, "color:a", 0.0, 0.25)
	if _plano == null:
		return
	_poner_camara(x, delta)
	_colocar_magnus(x)
	_sala.queue_redraw()
	_delante.queue_redraw()
	if _texto.visible:
		_texto.text = "Plano %d/%d  %s   corte %s (F)\n" % [_plano.get_index() + 1, _planos.get_child_count(),
			_plano.nombre, "con fundido" if fundido else "seco"] \
			+ "flechas andar · doble toque correr · espacio saltar · M menu · H ocultar"

func _elegir_plano(x: float) -> bool:
	if _plano != null and _plano.contiene(x, histeresis):
		return false
	for p in _planos.get_children():
		if p.contiene(x):
			_plano = p
			return true
	return false

# --- Camara -----------------------------------------------------------------

func _poner_camara(x: float, delta: float) -> void:
	var pl: Node = _plano
	_alabeo = deg_to_rad(pl.alabeo)
	_orto = pl.ortogonal
	if _orto:
		var g := deg_to_rad(pl.giro)
		var inc := deg_to_rad(pl.inclinacion)
		_fre = Vector3(sin(g) * cos(inc), -sin(inc), cos(g) * cos(inc))
		_pos = pl.mirar_a - _fre * 8000.0
		_escala_orto = pl.escala_orto
		_ref_niebla = 6500.0
	else:
		_pos = pl.posicion
		var objetivo: Vector3 = pl.mirar_a
		if pl.seguir:
			_seguido = lerpf(_seguido, x, 1.0 - exp(-delta * 4.0))
			objetivo.x = lerpf(pl.mirar_a.x, _seguido, pl.seguimiento)
		_fre = (objetivo - _pos).normalized()
		_focal = pl.focal
		_ref_niebla = 0.0
	_der = Vector3(_fre.z, 0.0, -_fre.x).normalized()
	_arr = _fre.cross(_der)

func _a_camara(p: Vector3) -> Vector3:
	var d := p - _pos
	return Vector3(d.dot(_der), d.dot(_arr), d.dot(_fre))

func _a_pantalla(c: Vector3) -> Vector2:
	var s := _escala_orto if _orto else _focal / c.z
	return Vector2(c.x * s, -c.y * s).rotated(_alabeo) + PANTALLA * 0.5

func _niebla(z: float) -> float:
	return exp(-maxf(z - _ref_niebla, 0.0) / niebla)

## Pone el nodo de Magnus para que sus pies (x, suelo, z = 0) caigan donde los
## proyecta la camara, con la escala de esa distancia y el giro del encuadre.
func _colocar_magnus(x: float) -> void:
	var c := _a_camara(Vector3(x, 0.0, 0.0))
	_z_magnus = c.z
	_proyeccion.visible = _orto or c.z > CERCA
	if not _proyeccion.visible:
		return
	var s := _escala_orto if _orto else _focal / c.z
	var t := Transform2D(_alabeo, Vector2(s, s), 0.0, Vector2.ZERO)
	t.origin = _a_pantalla(c) - t.basis_xform(Vector2(x, 0.0))
	_proyeccion.transform = t
	# La luz de la sala tambien le toca a el, un poco.
	var l := _luz_en(Vector3(x, 200.0, 0.0), Vector3.ZERO)
	var f := _niebla(c.z)
	_proyeccion.modulate = Color(minf(0.3 + l.r * 0.9, 1.0) * f, minf(0.3 + l.g * 0.9, 1.0) * f,
		minf(0.3 + l.b * 0.9, 1.0) * f)

# --- Dibujo -----------------------------------------------------------------

func _dibujar_sala() -> void:
	var tri := _Triangulos.new()
	for cara in _fijas:
		_meter_cara(tri, cara)
	for caja in _cajas_ordenadas(true):
		for cara in caja.caras:
			_meter_cara(tri, cara)
	tri.dibujar(_sala)

func _dibujar_delante() -> void:
	var tri := _Triangulos.new()
	for caja in _cajas_ordenadas(false):
		for cara in caja.caras:
			_meter_cara(tri, cara)
	tri.dibujar(_delante)

## Columnas detras (o delante) de Magnus, de la mas lejana a la mas cercana.
func _cajas_ordenadas(detras: bool) -> Array:
	var lista := []
	for caja in _cajas:
		var z := _a_camara(caja.centro).z
		if (z > _z_magnus) == detras:
			lista.append([z, caja])
	lista.sort_custom(func(a, b): return a[0] > b[0])
	return lista.map(func(e): return e[1])

func _meter_cara(tri: _Triangulos, cara: Dictionary) -> void:
	if not cara.doble:
		var mira: float = cara.n.dot(_fre) if _orto else cara.n.dot(cara.centro - _pos)
		if mira >= 0.0:
			return
	var cam := PackedVector3Array()
	for v in cara.p:
		cam.append(_a_camara(v))
	var cols: PackedColorArray = cara.c
	if not _orto:
		var r := _recortar(cam, cols)
		cam = r[0]
		cols = r[1]
		if cam.size() < 3:
			return
	var pts := PackedVector2Array()
	var cs := PackedColorArray()
	for i in cam.size():
		pts.append(_a_pantalla(cam[i]))
		var f := _niebla(cam[i].z)
		var c := cols[i]
		# Lo translucido (haces de luz) se desvanece; lo opaco se oscurece.
		cs.append(Color(c.r, c.g, c.b, c.a * f) if c.a < 1.0 else Color(c.r * f, c.g * f, c.b * f))
	tri.poligono(pts, cs)

## Recorte por el plano cercano (z >= CERCA), para que lo que queda detras de la
## camara no se proyecte del reves.
func _recortar(p: PackedVector3Array, c: PackedColorArray) -> Array:
	var op := PackedVector3Array()
	var oc := PackedColorArray()
	var n := p.size()
	for i in n:
		var a := p[i]
		var b := p[(i + 1) % n]
		var dentro_a := a.z >= CERCA
		if dentro_a:
			op.append(a)
			oc.append(c[i])
		if dentro_a != (b.z >= CERCA):
			var t := (CERCA - a.z) / (b.z - a.z)
			op.append(a.lerp(b, t))
			oc.append(c[i].lerp(c[(i + 1) % n], t))
	return [op, oc]

## Junta todos los triangulos de un lienzo y los manda de una vez.
class _Triangulos:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()

	func poligono(p: PackedVector2Array, c: PackedColorArray) -> void:
		var base := pts.size()
		pts.append_array(p)
		cols.append_array(c)
		for i in range(1, p.size() - 1):
			idx.append(base)
			idx.append(base + i)
			idx.append(base + i + 1)

	func dibujar(lienzo: CanvasItem) -> void:
		if idx.is_empty():
			return
		RenderingServer.canvas_item_add_triangle_array(lienzo.get_canvas_item(), idx, pts, cols)

# --- La sala ----------------------------------------------------------------

func _construir() -> void:
	var ventanas := [1200.0, 2400.0, 3600.0, 4800.0]
	var luna := Color(0.55, 0.62, 0.8)
	var fuego := Color(1.0, 0.6, 0.3)
	for vx in ventanas:
		_luces.append({"pos": Vector3(vx + 80.0, 520.0, 560.0), "color": luna, "radio": 700.0, "fuerza": 1.5})
	_luces.append({"pos": Vector3(2250.0, 200.0, 450.0), "color": fuego, "radio": 450.0, "fuerza": 1.8})
	_luces.append({"pos": Vector3(LARGO - 150.0, 300.0, 0.0), "color": fuego, "radio": 600.0, "fuerza": 1.2})

	var z0 := -MEDIO_ANCHO
	var z1 := MEDIO_ANCHO
	# Suelo en damero, techo, paredes.
	_rejilla(Vector3(0, 0, z0), Vector3(LARGO, 0, 0), Vector3(0, 0, 2 * MEDIO_ANCHO), 30, 7,
		Color(0.5, 0.46, 0.42), Vector3.UP, _fijas, Color(0.44, 0.41, 0.38))
	_rejilla(Vector3(0, ALTO, z0), Vector3(LARGO, 0, 0), Vector3(0, 0, 2 * MEDIO_ANCHO), 10, 2,
		Color(0.3, 0.28, 0.27), Vector3.DOWN, _fijas)
	var pared := Color(0.46, 0.44, 0.42)
	_rejilla(Vector3(0, 0, z1), Vector3(LARGO, 0, 0), Vector3(0, ALTO, 0), 30, 5, pared, Vector3.FORWARD, _fijas)
	_rejilla(Vector3(0, 0, z0), Vector3(LARGO, 0, 0), Vector3(0, ALTO, 0), 30, 5, pared, Vector3.BACK, _fijas)
	_rejilla(Vector3(0, 0, z0), Vector3(0, 0, 2 * MEDIO_ANCHO), Vector3(0, ALTO, 0), 7, 5, pared.darkened(0.1), Vector3.RIGHT, _fijas)
	_rejilla(Vector3(LARGO, 0, z0), Vector3(0, 0, 2 * MEDIO_ANCHO), Vector3(0, ALTO, 0), 7, 5, pared.darkened(0.1), Vector3.LEFT, _fijas)
	# Vigas del techo.
	for k in range(1, 10):
		var vx := 600.0 * k
		_caja(Vector3(vx - 40, ALTO - 100, z0), Vector3(vx + 40, ALTO, z1), Color(0.28, 0.22, 0.17), _fijas, 1)
	# Ventanas de dos lancetas en la pared del fondo, con su charco de luz y su haz.
	for vx in ventanas:
		for lado in [-1.0, 1.0]:
			var xa: float = vx + lado * 12.0
			var xb: float = vx + lado * 150.0
			var x0 := minf(xa, xb)
			var x1 := maxf(xa, xb)
			_cara(PackedVector3Array([Vector3(x0, 380, z1 - 2), Vector3(x1, 380, z1 - 2), Vector3(x1, 860, z1 - 2),
				Vector3((x0 + x1) * 0.5, 960, z1 - 2), Vector3(x0, 860, z1 - 2)]), luna, Vector3.FORWARD, _fijas, true)
		var charco := Color(luna, 0.13)
		_cara(PackedVector3Array([Vector3(vx - 150, 2, z1 - 10), Vector3(vx + 150, 2, z1 - 10),
			Vector3(vx + 330, 2, -120), Vector3(vx + 30, 2, -120)]), charco, Vector3.UP, _fijas, true)
		_cara(PackedVector3Array([Vector3(vx - 150, 860, z1 - 4), Vector3(vx + 150, 860, z1 - 4),
			Vector3(vx + 330, 2, -120), Vector3(vx + 30, 2, -120)]), Color(luna, 0.05), Vector3.ZERO, _fijas, true, true)
	# Brasero.
	_caja(Vector3(2210, 0, 410), Vector3(2290, 90, 490), Color(0.2, 0.2, 0.2), _fijas, 1)
	_cara(PackedVector3Array([Vector3(2222, 90, 450), Vector3(2278, 90, 450), Vector3(2250, 175, 450)]),
		Color(1.0, 0.72, 0.38), Vector3.ZERO, _fijas, true, true)
	# Puerta del fondo, con luz por debajo.
	_cara(PackedVector3Array([Vector3(LARGO - 2, 0, 180), Vector3(LARGO - 2, 0, -180), Vector3(LARGO - 2, 720, -180),
		Vector3(LARGO - 2, 720, 180)]), Color(0.25, 0.2, 0.16), Vector3.LEFT, _fijas)
	_cara(PackedVector3Array([Vector3(LARGO - 3, 0, 180), Vector3(LARGO - 3, 0, -180), Vector3(LARGO - 3, 14, -180),
		Vector3(LARGO - 3, 14, 180)]), Color(1.0, 0.75, 0.45), Vector3.LEFT, _fijas, true)
	# Columnas: fila entera al fondo y solo tres de este lado, para que tapen a
	# ratos sin comerse los planos.
	for k in 10:
		var cx := 300.0 + 600.0 * k
		for cz in ([-520.0, 520.0] if cx in [900.0, 2100.0, 3300.0] else [520.0]):
			var caras := []
			_caja(Vector3(cx - 65, 0, cz - 65), Vector3(cx + 65, ALTO - 100, cz + 65), Color(0.56, 0.53, 0.49), caras, 4)
			_cajas.append({"centro": Vector3(cx, ALTO * 0.5, cz), "caras": caras})

## Rejilla de caras en el rectangulo origen + u*[0,1] + v*[0,1]. Con base2,
## damero de dos colores.
func _rejilla(origen: Vector3, u: Vector3, v: Vector3, nu: int, nv: int, base: Color, n: Vector3,
		destino: Array, base2: Color = Color(0, 0, 0, 0)) -> void:
	for i in nu:
		for j in nv:
			var a := origen + u * (float(i) / nu) + v * (float(j) / nv)
			var du := u / nu
			var dv := v / nv
			var col := base2 if base2.a > 0.0 and (i + j) % 2 == 1 else base
			_cara(PackedVector3Array([a, a + du, a + du + dv, a + dv]), col, n, destino)

## Caja de min a max con sus seis caras hacia fuera; los lados en nv tiras.
func _caja(mn: Vector3, mx: Vector3, base: Color, destino: Array, nv: int) -> void:
	var t := mx - mn
	_rejilla(mn, Vector3(t.x, 0, 0), Vector3(0, t.y, 0), 1, nv, base, Vector3.FORWARD, destino)
	_rejilla(Vector3(mn.x, mn.y, mx.z), Vector3(t.x, 0, 0), Vector3(0, t.y, 0), 1, nv, base, Vector3.BACK, destino)
	_rejilla(mn, Vector3(0, 0, t.z), Vector3(0, t.y, 0), 1, nv, base, Vector3.LEFT, destino)
	_rejilla(Vector3(mx.x, mn.y, mn.z), Vector3(0, 0, t.z), Vector3(0, t.y, 0), 1, nv, base, Vector3.RIGHT, destino)
	_rejilla(Vector3(mn.x, mx.y, mn.z), Vector3(t.x, 0, 0), Vector3(0, 0, t.z), 1, 1, base, Vector3.UP, destino)
	_rejilla(mn, Vector3(t.x, 0, 0), Vector3(0, 0, t.z), 1, 1, base, Vector3.DOWN, destino)

func _cara(p: PackedVector3Array, base: Color, n: Vector3, destino: Array, emisiva: bool = false,
		doble: bool = false) -> void:
	var cols := PackedColorArray()
	var centro := Vector3.ZERO
	for v in p:
		centro += v
		if emisiva:
			cols.append(base)
		else:
			var l := _luz_en(v, n)
			cols.append(Color(base.r * l.r, base.g * l.g, base.b * l.b, base.a))
	destino.append({"p": p, "c": cols, "n": n, "centro": centro / p.size(), "doble": doble})

## Luz que llega a un punto (ambiente + cada luz con caida suave). Con normal,
## las caras de espaldas a la luz reciben menos.
func _luz_en(p: Vector3, n: Vector3) -> Color:
	var l := Color(luz_ambiente, luz_ambiente, luz_ambiente)
	for luz in _luces:
		var d: Vector3 = luz.pos - p
		var dist := maxf(d.length(), 1.0)
		var caida: float = luz.fuerza / (1.0 + pow(dist / luz.radio, 2.0))
		var lambert := 1.0 if n == Vector3.ZERO else clampf(n.dot(d / dist) * 0.6 + 0.4, 0.0, 1.0)
		l += luz.color * caida * lambert
	return l
