extends Node2D
## ACCIONES DE PERFIL DEL PEREGRINO (PRUEBA, 2026-10-12), en la escena de perfil
## (scenes/dev/piloto_baston.tscn), con los objetos justos para probarlas: un
## muro, dos sillares que se mueven (el alto con argolla), una mesa, una
## piedrecita, el palo de Argos y el baculo clavado. Sin tocar magnus.gd:
##   - Mientras dura una accion le quita el control (control_bloqueado, como al
##     sacar el baston), pone la animacion en su Sprite y la lleva a mano,
##     fotograma a fotograma, y mueve el nodo por la raiz del video
##     (assets/characters/magnus/acciones_perfil.json, que escribe
##     raw/master_mason/anim/montar_accion.py): nodo + casilla = video, al
##     pixel. Al acabar le deja el reposo de siempre en el sitio nuevo.
##   - Fuera de las acciones le pone en cada tick los limites (limite_izquierdo
##     y limite_derecho) segun lo que tenga delante a su altura: la cara de un
##     sillar, del muro o de la mesa, o el borde de donde esta subido. Asi se
##     para justo donde empieza la accion (si se pasa, se le devuelve al limite).
## Sin teclas nuevas:
##   - saltar pegado a algo mas alto: trepa (como el muro: trepar; como el
##     sillar mediano: trepar_mediano); la subida se ajusta a la altura real.
##     Si esta algo lejos, se acerca andando y trepa.
##   - seguir andando contra un sillar que se mueve: lo empuja (una pasada: el
##     mediano con el empuje v1, manos en el filo; el alto con el v2, manos
##     planas como en una puerta).
##   - arriba, andando hacia el borde: se deja caer sin pararse (2026-10-13; lo
##     hace Magnus con su salto andando, ver suelo_en en magnus.gd: despega en
##     el borde, aterriza abajo y, con la tecla, sigue andando). Saltando desde
##     encima de un bloque tambien aterriza abajo.
##   - parado en el borde, pulsando hacia el vacio: baja de un saltito (bajar),
##     con la caida ajustada a la altura que haya debajo.
## Teclas de prueba (provisionales; los botones de verdad, ver la memoria de
## controles):
##   E  accion: coger la piedrecita del suelo o de la mesa, lanzar el palo,
##      arrancar el baculo clavado, tirar del sillar con argolla
##   K  clavar el baculo (con el en la mano). La bola va con el: en la garra
##      del dibujo al clavarlo y al arrancarlo, y en el clavado. Clavado, B y G
##      (sacar y guardar) no hacen nada.
##   T  tumbarse (sin el baculo encima: clavado o guardado con G); tumbado, la
##      direccion lo arrastra y T o saltar lo levanta
##   1  golpe (empujon)      2  derribo
##   R  volver a poner los objetos donde estaban
##   V  ritmo del giro (x1, x1,5, x2, x2,5, x3), para probarlo a ojo
## Con el baston en la mano no trepa, ni empuja, ni baja, ni coge (el guion).
## EN TODAS LAS ESCENAS (2026-10-13, el usuario: "una vez revisado, metelo para
## irlo probando en todas las escenas"): va tambien en dark_stage.tscn (todos
## los pilotos), en la hojarasca y en las pruebas de camara y del storyboard,
## como hermano de Magnus y con `generico`: sin objetos, solo lo que no los
## necesita (tumbarse y arrastrarse, golpe, derribo, clavar y arrancar si lleva
## el baston), y sin tocar los limites ni el suelo de la escena. Si la escena
## trae su propio nodo de acciones (los pilotos de acciones, con sus objetos),
## manda ese y el generico se quita.

const DATOS := "res://assets/characters/magnus/acciones_perfil.json"
const TEXTURAS := "res://assets/pruebas_acciones/%s.png"
## Esfuerzo con el que acaba cada accion (la respiracion de Magnus).
const ESFUERZO := {"trepar": 1.0, "trepar_mediano": 0.6, "bajar": 0.3, "empujar": 0.8,
		"empujar_v2": 0.8, "tirar": 0.8, "derribo": 0.9, "golpe": 0.5, "levantarse_tumbado": 0.6}
const GRAVEDAD_PALO := 1500.0
## Lo que tienen que sobrar los pies sobre algo para saltar encima en vez de trepar.
const MARGEN_SALTO := 8.0
## Parado menos que esto tras moverse, aun cuenta como que va andando hacia un borde.
const GRACIA_QUIETO := 0.3
## RITMO DE LAS ACCIONES (2026-10-13, repaso de jugabilidad con otros juegos de
## referencia: Prince of Persia sube un piso, saltar, colgarse y subir, en 2,6 s).
## Multiplica sus fps (24, los del video, con todos sus fotogramas): trepar el
## muro 4,7 -> 3,1 s, al sillar mediano 3,8 -> 2,5 s, el saltito de bajar 4,6 ->
## 3,5 s, empujar y tirar 7,2 -> 5,8 s, coger, lanzar, clavar y arrancar algo
## menos. Golpe, derribo y tumbarse, a su ritmo (son de verse).
const VELOCIDAD := {"trepar": 1.5, "trepar_mediano": 1.5, "bajar": 1.3, "empujar": 1.25,
		"empujar_v2": 1.25, "tirar": 1.25, "coger_suelo": 1.2, "coger_mesa": 1.2,
		"lanzar_palo": 1.2, "arrancar": 1.2, "clavar": 1.2}
## Los pies plantan 6,5 px por encima del nodo (fila 677 de 690 en la casilla,
## a media escala): los objetos apoyan ahi, como en los videos y sus referencias.
const PLANTA := 6.5

@export var magnus_ruta: NodePath = ^"../DarkStage/Magnus"
## Objetos que estorban: [textura, x de la cara izquierda, ancho, alto, empuje
## ("" = quieto), accion con E en su cara ("" = ninguna), se puede trepar], en
## px de juego; el suelo es donde pisa Magnus al empezar.
@export var objetos: Array = [
	# escalon bajo para probar los saltos (2026-10-13): de 95 px no se trepa (no
	# hay video tan bajo), se salta encima andando o corriendo; con la mesa al
	# lado hace de escalera (se salta a la mesa, de 144, y se baja andando a el).
	# Pegado al borde de la escena: sin hueco detras donde quedarse encerrado
	["sillar_mediano", 170.0, 120.0, 95.0, "", "", false],
	["mesa", 300.0, 139.0, 144.0, "", "coger_mesa", false],
	["sillar_mediano", 1150.0, 196.0, 172.0, "empujar", "", true],
	["sillar_alto", 1650.0, 218.0, 362.0, "empujar_v2", "tirar", true],
	["muro", 2090.0, 400.0, 362.0, "", "", true],
]
## Objetos sueltos en el suelo: [textura, x de su izquierda, accion con E].
@export var sueltos: Array = [
	["guijarro", 520.0, "coger_suelo"],
	["palo", 640.0, "lanzar_palo"],
]
## Lo que puede faltar o sobrar para empezar una accion sin acercarse: se
## reparte en el avance de la accion (en el cuerpo, no en los pies quietos).
@export var tolerancia := 40.0
## Al trepar, algo mas (lo que se queda tras empujar el sillar alto: 70 px; menos
## de un paso de Magnus, que no anda tan poco): se reparte en lo que avanza el
## cuerpo al subir.
@export var tolerancia_trepar := 75.0
## Con mas de esto (y menos de acercarse_max) primero se acerca andando.
@export var acercarse_max := 400.0
## Segundos andando contra un sillar o hacia un borde antes de empujar o bajar.
@export var espera_empuje := 0.1
@export var espera_bajar := 0.1
## Saltar junto a algo que se trepa mientras aun se para: se guarda este tiempo.
@export var espera_trepa := 1.2
## Junto a una cara o un borde, la tecla deja de contar esto antes del limite
## (lo que tarda en pararse andando, entrando en la parada al momento) y la
## parada termina en el limite. Lejos, lo de DarkStage.
@export var frenada_obstaculo := 53.0
@export var cerca_obstaculo := 300.0
## Alturas de los videos (px de juego) y cuanto se pueden estirar o encoger.
@export var subida_mediana := 172.0
@export var subida_alta := 362.0
@export var margen_altura := 0.3
## La argolla del sillar alto: altura de su centro sobre el suelo (0,45 del alto
## del peregrino, la de la referencia de tirar).
@export var altura_argolla := 141.0
## Para grabar sin nadie al teclado (como "eventos" de piloto_baston.gd):
## [segundo, "accion"|"clavar"|"tumbarse"|"levantarse"|"golpe"|"derribo"|"recolocar"].
@export var eventos: Array = []
## El de todas las escenas (ver EN TODAS LAS ESCENAS): se quita si hay otro.
@export var generico := false
## La linea de teclas: abajo a la izquierda (arriba van los datos de movimiento
## de DarkStage), o arriba en las escenas que llevan su texto abajo.
@export var ayuda := true
@export var ayuda_arriba := false

enum Modo { LIBRE, ACCION, ACERCANDOSE, TUMBADO }

class Objeto:
	var nombre := ""
	var x0 := 0.0
	var ancho := 0.0
	var alto := 0.0
	var empuje := ""
	var accion := ""
	var trepable := true
	var nodo: Sprite2D
	var x_ini := 0.0
	func x1() -> float:
		return x0 + ancho

class Suelto:
	var nombre := ""
	var accion := ""
	var nodo: Sprite2D
	var pos_ini := Vector2.ZERO
	var activo := true

var _modo := Modo.LIBRE
var _magnus: Node2D
var _sprite: AnimatedSprite2D
var _suelo := 0.0
var _obj: Array[Objeto] = []
var _sueltos: Array[Suelto] = []
var _datos := {}
var _limites := Vector2.ZERO        # los de la escena (DarkStage)
var _frenadas := Vector2.ZERO
var _espera_parada := 34
var _espera := 0.0
var _ayuda: Label
var _clavado: Sprite2D               # el baculo clavado (null si no lo esta)
var _bola: Node2D                    # su bola mientras no la lleva el baston (ver _bola_del_baculo)
var _palo_vuela: Sprite2D            # el palo lanzado, en el aire
var _palo_vel := Vector2.ZERO
# accion en curso: una lista de tramos (empujar: entrada, ciclo, salida)
var _tramos: Array = []
var _k := 0                          # tramo en curso
var _anim := ""
var _d := 1.0                        # hacia donde (1 derecha)
var _t := 0.0                        # segundos dentro del tramo
var _f := -1                         # fotograma puesto
var _base := Vector2.ZERO            # el nodo en el primer fotograma del tramo
var _corr := 0.0                     # lo que falta hasta la colocacion del video (hacia delante)
var _y_fin := 0.0
var _contacto := 0                   # empuje: primer fotograma con el sillar en marcha
var _bloque: Objeto
var _tira := false                   # el sillar va con las manos tirando (hacia atras)
var _seguir := true
var _al_acabar := Callable()
var _ultima := ""
var _trepa_pedido := 0.0             # segundos que queda guardado un salto para trepar
var _x_antes := NAN                  # x de Magnus en el tick anterior (limites)
var _quieto := 0.0                   # segundos que lleva sin moverse (andar, correr, saltar)

func _enter_tree() -> void:
	add_to_group("acciones_magnus")

func _ready() -> void:
	if generico:
		# (el de la misma escena que lleve al mismo Magnus: no el de una escena
		# que aun se esta yendo)
		var mio := get_node_or_null(magnus_ruta)
		for otro in get_tree().get_nodes_in_group("acciones_magnus"):
			if otro != self and not otro.generico and not otro.is_queued_for_deletion() \
					and otro.get_node_or_null(otro.magnus_ruta) == mio:
				set_physics_process(false)
				set_process_unhandled_input(false)
				queue_free()
				return
		objetos = []
		sueltos = []
	_magnus = get_node_or_null(magnus_ruta)
	if _magnus == null or not _magnus.has_method("datos_movimiento"):
		push_warning("acciones_perfil: no encuentro a Magnus en %s" % magnus_ruta)
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	_sprite = _magnus.get_node("Sprite")
	_suelo = _magnus.position.y
	_limites = Vector2(_magnus.limite_izquierdo, _magnus.limite_derecho)
	_frenadas = Vector2(_magnus.frenada_limite_andar, _magnus.frenada_limite_correr)
	_espera_parada = _magnus.espera_parada_andar
	_datos = JSON.parse_string(FileAccess.open(DATOS, FileAccess.READ).get_as_text())
	if not objetos.is_empty():
		# el suelo de cada x (los bloques): andando hacia un borde se deja caer, y
		# saltando desde un bloque aterriza abajo (SUELO VARIABLE de magnus.gd)
		_magnus.suelo_en = _nivel
		# y hasta donde puede llegar un salto: los limites de la escena (las caras
		# las lleva el vuelo)
		_magnus.limites_salto = _limites
	# despues de Magnus: sus limites se le ponen para el tick siguiente y lo
	# que se pase de una cara se le devuelve en el mismo tick
	process_physics_priority = 10
	for o in objetos:
		var ob := Objeto.new()
		ob.nombre = o[0]
		ob.x0 = o[1]
		ob.x_ini = o[1]
		ob.ancho = o[2]
		ob.alto = o[3]
		ob.empuje = o[4]
		ob.accion = o[5] if o.size() > 5 else ""
		ob.trepable = o[6] if o.size() > 6 else true
		ob.nodo = _sprite_de(ob.nombre)
		var tam: Vector2 = ob.nodo.texture.get_size()
		ob.nodo.scale = Vector2(ob.ancho / tam.x, ob.alto / tam.y)
		add_child(ob.nodo)
		if ob.accion == "tirar":
			_poner_argollas(ob)
		_obj.append(ob)
		_colocar_objeto(ob)
	for s in sueltos:
		_nuevo_suelto(s[0], Vector2(s[1], 0.0), s[2])
	# la piedrecita de la mesa, donde la tiene el video
	for ob in _obj:
		if ob.accion == "coger_mesa" and _datos.has("coger_mesa"):
			var dm: Dictionary = _datos["coger_mesa"]
			if not dm["objetos_ini"].is_empty():
				var caja: Array = dm["objetos_ini"][0]
				var x: float = ob.x0 + float(caja[0]) - float(dm["cara"])
				_nuevo_suelto("guijarro", Vector2(x, float(caja[3]) - float(caja[1])), "coger_mesa", _suelo - ob.alto)
	if not ayuda:
		return
	var capa := CanvasLayer.new()
	add_child(capa)
	_ayuda = Label.new()
	_ayuda.position = Vector2(40, 72) if ayuda_arriba else Vector2(40, get_viewport().get_visible_rect().size.y - 150.0)
	_ayuda.add_theme_font_size_override("font_size", 26)
	_ayuda.modulate = Color(1, 1, 1, 0.45)
	capa.add_child(_ayuda)

func _sprite_de(nombre: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(TEXTURAS % nombre)
	s.centered = false
	s.z_index = -5                           # detras del peregrino y de su baston
	return s

## La argolla a cada lado del sillar que se tira, a la altura de la cadera.
func _poner_argollas(ob: Objeto) -> void:
	var tex: Texture2D = load(TEXTURAS % "argolla")
	for lado in [-1.0, 1.0]:
		var a := Sprite2D.new()
		a.texture = tex
		a.centered = false
		a.flip_h = lado > 0.0
		# coordenadas del nodo del sillar (escalado): se deshace la escala
		a.scale = Vector2(1.0 / ob.nodo.scale.x, 1.0 / ob.nodo.scale.y)
		var w := tex.get_width() / ob.nodo.scale.x
		var x := -w + 1.0 if lado < 0.0 else ob.ancho / ob.nodo.scale.x * ob.nodo.scale.x
		a.position = Vector2((x if lado < 0.0 else ob.ancho - 1.0) / ob.nodo.scale.x,
				(ob.alto - altura_argolla - tex.get_height() / 2.0) / ob.nodo.scale.y)
		ob.nodo.add_child(a)

## Un objeto suelto; pos.x = su izquierda, pos.y = su alto (lo pisa a la altura y_apoyo).
func _nuevo_suelto(nombre: String, pos: Vector2, accion: String, y_apoyo := INF) -> Suelto:
	var s := Suelto.new()
	s.nombre = nombre
	s.accion = accion
	s.nodo = _sprite_de(nombre)
	s.nodo.z_index = -4
	var tam: Vector2 = s.nodo.texture.get_size()
	var y := (_suelo if is_inf(y_apoyo) else y_apoyo) - PLANTA - tam.y + 1.0
	s.nodo.position = Vector2(pos.x, y)
	s.pos_ini = s.nodo.position
	add_child(s.nodo)
	_sueltos.append(s)
	return s

func _colocar_objeto(o: Objeto) -> void:
	o.nodo.position = Vector2(o.x0, _suelo - PLANTA - o.alto)

## Lo alto que hay en x (la y de lo que pisaria): el suelo o lo de encima del
## objeto mas alto que ocupe x. Un hueco de menos de HUECO_JUNTOS entre dos
## objetos cuenta como lo mas bajo de los dos (no se cae por el: un sillar
## empujado contra otro, o contra el muro, hace de escalon o de suelo seguido).
const HUECO_JUNTOS := 40.0
func _nivel(x: float) -> float:
	var y := _suelo
	var dentro := false
	for o in _obj:
		if x > o.x0 + 0.01 and x < o.x1() - 0.01:
			y = minf(y, _suelo - o.alto)
			dentro = true
	if dentro:
		return y
	var izq: Objeto = null
	var der: Objeto = null
	for o in _obj:
		if o.x1() <= x + 0.01 and (izq == null or o.x1() > izq.x1()):
			izq = o
		if o.x0 >= x - 0.01 and (der == null or o.x0 < der.x0):
			der = o
	if izq and der and der.x0 - izq.x1() < HUECO_JUNTOS:
		return maxf(_suelo - izq.alto, _suelo - der.alto)
	return y

## Yendo desde x hacia d a la altura y: donde cambia la altura ({x, y, objeto})
## o {} si no cambia hasta el final.
func _siguiente(x: float, y: float, d: float) -> Dictionary:
	var puntos: Array = []
	for o in _obj:
		puntos.append([o.x0, o])
		puntos.append([o.x1(), o])
	puntos.sort_custom(func(a, b): return a[0] * d < b[0] * d)
	# (los bordes de un hueco pequeno entre dos objetos no cuentan: _nivel ya lo
	# llena, y lo que cambia la altura es la cara del otro)
	for p in puntos:
		var b: float = p[0]
		if (b - x) * d <= 0.5:
			continue
		var y2 := _nivel(b + d * 0.5)
		if absf(y2 - y) > 2.0:
			# la cara es del objeto que sube (o del que se deja al bajar)
			var o: Objeto = p[1]
			for q in _obj:
				if b + d * 0.5 > q.x0 and b + d * 0.5 < q.x1() and absf(_suelo - q.alto - y2) < 0.5:
					o = q
			return {"x": b, "y": y2, "objeto": o}
	return {}

func _baston() -> Node:
	for c in _magnus.get_children():
		if "en_mano" in c:
			return c
	return null

func _en_mano() -> bool:
	var b := _baston()
	return b != null and b.en_mano

func _baston_encima() -> bool:
	var b := _baston()
	return b != null and (b.en_mano or b.puesto)

func _estado() -> String:
	return _magnus.datos_movimiento()["estado"]

## Que accion empieza en esa cara o borde y desde donde (el nodo, en x).
func _accion_en(sig: Dictionary, y: float, d: float) -> Dictionary:
	if sig.is_empty():
		return {}
	var h: float = y - sig["y"]                     # > 0 sube, < 0 baja
	var o: Objeto = sig["objeto"]
	if h > 0.0:
		var anim := ""
		if o.trepable and absf(h / subida_mediana - 1.0) <= margen_altura:
			anim = "trepar_mediano"
		elif o.trepable and absf(h / subida_alta - 1.0) <= margen_altura:
			anim = "trepar"
		var en_el_suelo := absf(y - _suelo) < 0.5
		var empuje := o.empuje if o.empuje != "" and en_el_suelo and _datos.has(o.empuje) else ""
		var r := {"trepa": anim, "empuje": empuje, "cara": sig["x"], "y": sig["y"], "objeto": o}
		# se para donde empieza lo mas cercano de lo que se puede hacer en esa
		# cara (empujar, tirar, coger de la mesa; si no, la subida): lo demas
		# corrige la diferencia en su paso de entrada o se acerca andando. Empujar,
		# tirar y coger de la mesa, desde el suelo, como en sus videos (subido al
		# escalon, la mesa es solo una cara: se salta encima)
		var desde := ""
		for cand in [empuje, o.accion if en_el_suelo else ""]:
			if cand != "" and _datos.has(cand) and _datos[cand].has("cara"):
				if desde == "" or float(_datos[cand]["cara"]) < float(_datos[desde]["cara"]):
					desde = cand
		if desde == "":
			desde = anim
		if desde == "":
			r["parada"] = sig["x"] - d * 30.0
		else:
			r["parada"] = sig["x"] - d * float(_datos[desde]["cara"])
		return r
	if not _datos.has("bajar"):
		return {"parada": sig["x"] - d * 30.0, "cara": sig["x"], "y": sig["y"]}
	var parada: float = sig["x"] - d * float(_datos["bajar"]["cara"])
	# baja si donde cae (el saltito avanza lo suyo) esta mas abajo, y no demasiado
	var x_cae: float = sig["x"] + d * float(_datos["bajar"]["cara_fin"])
	var y_cae := _nivel(x_cae)
	var caida := y_cae - y
	if caida < 20.0 or caida > subida_alta * (1.0 + margen_altura) or x_cae < _limites.x or x_cae > _limites.y:
		return {"parada": parada, "cara": sig["x"], "y": sig["y"]}
	return {"baja": "bajar", "cara": sig["x"], "y": y_cae, "parada": parada}

var _tick := 0
var _ev := 0
## ACCIONES_TRAZA, leida una vez (antes en cada tick: es una llamada al sistema).
var _traza := OS.get_environment("ACCIONES_TRAZA")
func _physics_process(delta: float) -> void:
	_tick += 1
	_quieto = 0.0 if _estado() in ["ANDAR", "ARRANQUE_ANDAR", "CORRER", "ARRANQUE_CORRER", "SALTAR", "PARADA_ANDAR", "PARADA_CORRER"] else _quieto + delta
	while _ev < eventos.size() and float(eventos[_ev][0]) <= _tick / 60.0:
		print("acciones: evento %s" % eventos[_ev][1])
		match String(eventos[_ev][1]):
			"accion": _accion()
			"clavar": _clavar()
			"tumbarse": _tumbarse()
			"levantarse":
				if _modo == Modo.TUMBADO:
					_levantarse()
			"golpe": _sin_mas("golpe")
			"derribo": _sin_mas("derribo")
			"recolocar": _recolocar()
		_ev += 1
	# (ACCIONES_TRAZA=2: cada tick, con la altura de los pies)
	var traza := _traza
	if traza != "" and (_tick % 6 == 0 or traza == "2"):
		var dm: Dictionary = _magnus.datos_movimiento()
		print("traza %.2f x %.1f y %.1f %s %s f%d v%.0f lim %.1f-%.1f fren %.0f pies %.1f" % [_tick / 60.0, _magnus.position.x, _magnus.position.y,
			dm["estado"], dm["animacion"], dm["fotograma"], dm["velocidad"], _magnus.limite_izquierdo, _magnus.limite_derecho, _magnus.frenada_limite_andar,
			_magnus.call("_pies_sobre_despegue")] + (" cuerpo %.1f cima %.1f tau %.2f vuelo %d" % [_magnus.get("_vuelo_y"),
			_magnus.get("_vuelo_cima"), _magnus.get("_vuelo_tau"), _magnus.get("_vuelo")] if traza == "2" else ""))
	# (acercandose lo lleva andar_hasta: ver _acercarse)
	_cortar_por_cinematica()
	match _modo:
		Modo.ACCION:
			_avanzar(delta)
		Modo.LIBRE:
			_libre(delta)
		Modo.TUMBADO:
			_tumbado()
	_volar_palo(delta)
	if _ayuda:
		var que := ("[" + _anim + "]") if _modo == Modo.ACCION else ("[tumbado]" if _modo == Modo.TUMBADO else _ultima)
		var teclas := "T tumbarse   1 golpe   2 derribo   V giro x%s" % str(_magnus.giro_ritmo)
		if _baston() != null:
			teclas = "K clavar   " + teclas
		if _obj.is_empty() and _sueltos.is_empty():
			_ayuda.text = teclas + "      " + que
		else:
			_ayuda.text = ("saltar andando hacia algo: encima si llega   saltar pegado: trepar   andar contra el sillar: empujar   andando al borde: se deja caer   parado en el borde: bajar\n"
				+ "E accion   " + teclas + "   R recolocar      " + que)

func _libre(delta: float) -> void:
	var m := _magnus
	var x := m.position.x
	var y := m.position.y
	if is_nan(_x_antes):
		_x_antes = x
	# En el aire (un salto, o dejandose caer de un borde) lo lleva Magnus hasta
	# que toca suelo (las caras y los limites del salto los lleva el vuelo). Al
	# tocar, ya en el suelo nuevo, vuelven los limites de aqui: con los de antes
	# del salto (los de abajo, al caer encima de la mesa) no podia salir andando
	# con la tecla y se quedaba parado. Y lo que llevaba esperando para empujar o
	# bajar no cuenta: subido a la mesa, bajaba nada mas tocar. Sin objetos, los
	# limites y el suelo son los de la escena: no se tocan.
	if (_estado() == "SALTAR" and not _magnus.tras_tocar_suelo()) or _obj.is_empty():
		_x_antes = x
		_espera = 0.0
		return
	var eje := Input.get_axis("mover_izquierda", "mover_derecha")
	var lados := {}
	for d in [-1.0, 1.0]:
		var a := _accion_en(_siguiente(x, y, d), y, d)
		lados[d] = a
	# si ya esta mas cerca que el limite (empezo ahi, o le dejo ahi una accion),
	# el limite es donde esta: no se le mueve, solo no puede acercarse mas
	var lim_i := maxf(_limites.x, _limite_lado(lados[-1.0], -1.0, eje))
	var lim_d := minf(_limites.y, _limite_lado(lados[1.0], 1.0, eje))
	# (con medio px de margen: la posicion es float32 y el limite float64, y
	# recortada al limite parecia ya pasada). Lo de menos adentro de los dos
	# ticks: con lo de mas adentro, cada tick avanzaba un poco y, tras caer
	# de un salto delante de un sillar, lo cruzaba entero andando por dentro.
	if x < lim_i - 0.5 and _x_antes < lim_i - 0.5:
		lim_i = maxf(x, _x_antes)
	if x > lim_d + 0.5 and _x_antes > lim_d + 0.5:
		lim_d = minf(x, _x_antes)
	# un borde que no se va a dejar caer: nunca de pie sobre el vacio (si la
	# parada lo lleva mas alla de donde empieza bajar, se queda en el filo)
	for s in [-1.0, 1.0]:
		var a: Dictionary = lados[s]
		if a.has("baja") and not _cae_andando(a, s, eje):
			var filo: float = float(a["cara"]) - s * 8.0
			if s > 0.0:
				lim_d = minf(lim_d, filo)
			else:
				lim_i = maxf(lim_i, filo)
	m.limite_izquierdo = lim_i
	m.limite_derecho = lim_d
	var d: float = m.mirando()
	var delante: Dictionary = lados[d]
	var cerca := not delante.is_empty() and absf(delante["parada"] - x) < cerca_obstaculo
	m.frenada_limite_andar = frenada_obstaculo if cerca else _frenadas.x
	m.espera_parada_andar = 0 if cerca else _espera_parada
	# no se mete en la piedra ni se sale del borde (si se pasa en este tick)
	if m.position.x > m.limite_derecho:
		m.position.x = m.limite_derecho
	if m.position.x < m.limite_izquierdo:
		m.position.x = m.limite_izquierdo
	_x_antes = m.position.x
	# el salto guardado para trepar, en cuanto se quede quieto
	if _trepa_pedido > 0.0:
		_trepa_pedido -= delta
		if _listo():
			_trepa_pedido = 0.0
			_saltar_pegado(false)
			if _modo != Modo.LIBRE:
				return
	# hacia el otro lado con un limite cerca por alli: Magnus no deja ni girarse
	# (ignora la tecla hacia un limite que tiene a menos de su frenada), asi que
	# se le da la vuelta aqui; luego, si sigue la tecla, baja o empuja
	if not is_zero_approx(eje) and signf(eje) != d and _estado() == "REPOSO" and not m.control_bloqueado:
		var lim: float = m.limite_izquierdo if eje < 0.0 else m.limite_derecho
		if absf(m.position.x - lim) <= m.frenada_limite_andar + 1.0:
			m.girar_hacia(m.position.x + signf(eje) * 100.0)
	# andando contra un sillar o hacia un borde: empuja o baja
	if delante.is_empty() or _estado() != "REPOSO" or signf(eje) != d or _en_mano() or m.control_bloqueado:
		_espera = 0.0
		return
	var falta: float = (delante["parada"] - m.position.x) * d
	# (parado en el borde: a menos de lo que tarda en frenar ni llega a andar,
	# asi que de ahi tambien baja)
	var tol := maxf(tolerancia, frenada_obstaculo + 5.0) if delante.has("baja") else tolerancia
	if absf(falta) > tol:
		_espera = 0.0
		return
	_espera += delta
	if delante.get("empuje", "") != "" and _espera >= espera_empuje:
		_empezar_empuje(delante, d)
	elif delante.has("baja") and _espera >= espera_bajar:
		_empezar_una("bajar", delante, d)

## El limite de un lado: donde empieza lo que haya alli (la parada). Hacia un
## borde que se puede bajar, andando o corriendo con la tecla hacia el, no: se
## deja caer (lo hace Magnus, ver suelo_en), y el limite es la cara de lo que
## haya mas alla, abajo, a 60 px (Magnus acorta el salto para no meterse en
## ella, y cayendo no pasa del limite).
func _limite_lado(a: Dictionary, s: float, eje: float) -> float:
	if a.is_empty():
		return INF * s
	if _cae_andando(a, s, eje):
		var mas_alla: float = float(a["cara"]) + s
		var abajo := _nivel(mas_alla)
		var sig := _siguiente(mas_alla, abajo, s)
		if not sig.is_empty() and float(sig["y"]) < abajo - 2.0:
			return float(sig["x"]) - s * 60.0       # medio cuerpo y algo (con 40 rozaba la cara)
		return INF * s
	return float(a["parada"])

## Va hacia ese borde para dejarse caer: andando o corriendo hacia alli con la
## tecla, y sin el baston en la mano (con el no salta; se para en el filo).
func _cae_andando(a: Dictionary, s: float, eje: float) -> bool:
	if not a.has("baja") or _en_mano() or _magnus.mirando() != s or signf(eje) != s:
		return false
	# (y si se movia hace nada: al caer de un salto junto al filo, con la tecla,
	# sigue andando y se deja caer, no hace el saltito de parado)
	return _estado() in ["ANDAR", "ARRANQUE_ANDAR", "CORRER", "ARRANQUE_CORRER"] or _quieto < GRACIA_QUIETO

## ---- teclas ----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# con el baculo clavado (o clavandolo, o arrancandolo) no hay baston que
	# sacar ni guardar: B y G (piloto_baston.gd, que las mira despues) no hacen nada
	var kb := event as InputEventKey
	var en_el_suelo := _clavado != null or (_modo == Modo.ACCION and _anim in ["clavar", "arrancar"])
	if kb and kb.pressed and kb.keycode in [KEY_B, KEY_G] and en_el_suelo:
		get_viewport().set_input_as_handled()
		_ultima = "(el baculo esta clavado: E para arrancarlo)"
		return
	if _modo == Modo.TUMBADO:
		var k0 := event as InputEventKey
		if event.is_action_pressed("saltar") or (k0 and k0.pressed and not k0.echo and k0.keycode == KEY_T):
			get_viewport().set_input_as_handled()
			_levantarse()
		return
	if _modo != Modo.LIBRE:
		return
	if event.is_action_pressed("saltar"):
		_saltar_pegado()
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_E: _accion()
		KEY_K: _clavar()
		KEY_T: _tumbarse()
		KEY_1: _sin_mas("golpe")
		KEY_2: _sin_mas("derribo")
		KEY_R:
			if not _obj.is_empty() or not _sueltos.is_empty():
				_recolocar()
		KEY_V:
			# probar el ritmo del giro (ver giro_ritmo en magnus.gd)
			var ritmos := [1.0, 1.5, 2.0, 2.5, 3.0]
			var i := ritmos.find(_magnus.giro_ritmo)
			_magnus.giro_ritmo = ritmos[(i + 1) % ritmos.size()]
			_ultima = "(giro a x%s: %.1f s de pie)" % [str(_magnus.giro_ritmo), 61.0 / 24.0 / _magnus.giro_ritmo]

## (y con Magnus en juego: la hojarasca lo esconde y lo para mientras entra
## desde negro, antes de su caida)
func _listo() -> bool:
	return _modo == Modo.LIBRE and _estado() == "REPOSO" and not _magnus.control_bloqueado \
		and _magnus.is_visible_in_tree() and _magnus.can_process()

## Si la escena le pone una cinematica (la caida del cielo) a media accion,
## la accion se deja: el sprite y el estado son de la cinematica.
const CINEMATICA := ["CAYENDO", "CAIDA", "TUMBADO", "LEVANTARSE"]
func _cortar_por_cinematica() -> bool:
	if _modo == Modo.LIBRE or not (_estado() in CINEMATICA):
		return false
	if _traza != "":
		print("acciones: %s cortada por la cinematica" % _anim)
	_modo = Modo.LIBRE
	_tramos = []
	_bloque = null
	_al_acabar = Callable()
	_magnus.control_bloqueado = false
	return true

func _saltar_pegado(desde_tecla := true) -> void:
	var m := _magnus
	if _modo != Modo.LIBRE or _en_mano():
		return
	var d: float = m.mirando()
	var a := _accion_en(_siguiente(m.position.x, m.position.y, d), m.position.y, d)
	if a.get("trepa", "") == "":
		return
	# andando o corriendo hacia algo a lo que llega el salto: salta encima (SUELO
	# VARIABLE de magnus.gd); parado al lado, o si no llega, trepa
	# (frenando aun cuenta: el salto sale andando con lo que le queda, y Magnus
	# ajusta el avance para caer encima, ver SALTAR ENCIMA). Corriendo, salta
	# siempre, como en Prince of Persia: si no llega (poca carrerilla), da contra
	# la cara y cae delante, y de ahi se trepa.
	var h: float = m.position.y - float(a["y"])
	if _estado() in ["CORRER", "ARRANQUE_CORRER"]:
		return
	var va: bool = _estado() in ["ANDAR", "ARRANQUE_ANDAR"] \
		or (_estado() == "PARADA_ANDAR" and float(m.datos_movimiento()["velocidad"]) > 20.0)
	if va and m.altura_salto() >= h + MARGEN_SALTO:
		return
	if not _listo():
		# aun parandose (o girando) junto a algo que se trepa: se guarda el salto
		# y trepa en cuanto este quieto (Magnus no salta contra el muro)
		var ideal0: float = a["cara"] - d * float(_datos[a["trepa"]]["cara"])
		if desde_tecla and absf((ideal0 - m.position.x) * d) <= acercarse_max + 150.0:
			get_viewport().set_input_as_handled()
			_trepa_pedido = espera_trepa
		return
	var anim: String = a["trepa"]
	var ideal: float = a["cara"] - d * float(_datos[anim]["cara"])
	if _se_llega(anim, ideal, d):
		# se queda con la tecla (que Magnus no salte) antes de acercarse
		if desde_tecla:
			get_viewport().set_input_as_handled()
		_acercarse(ideal, d, func(): _empezar_una(anim, _accion_en(_siguiente(m.position.x, m.position.y, d), m.position.y, d), d), tolerancia_trepar)

func _tolerancia(anim: String) -> float:
	return tolerancia_trepar if anim.begins_with("trepar") else tolerancia

## Si desde aqui se puede empezar la accion (ya esta, o algo lejos y se acerca).
func _se_llega(anim: String, ideal: float, d: float) -> bool:
	var falta: float = (ideal - _magnus.position.x) * d
	if absf(falta) <= _tolerancia(anim) or (falta > 0.0 and falta <= acercarse_max):
		return true
	_ultima = "(" + anim + ": demasiado " + ("cerca" if falta < 0.0 else "lejos") + ")"
	return false

## Si esta donde empieza la accion (con tolerancia), la empieza; si esta algo
## lejos, se acerca andando y luego la empieza (ver _se_llega). Mas cerca que
## lo que tarda en pararse (frenada_obstaculo) no llega a andar: tambien empieza.
func _acercarse(ideal: float, d: float, empezar: Callable, tol := -1.0) -> void:
	var m := _magnus
	var falta: float = (ideal - m.position.x) * d
	if tol < 0.0:
		tol = tolerancia
	tol = maxf(tol, frenada_obstaculo + 5.0)
	if absf(falta) <= tol:
		empezar.call()
		return
	_modo = Modo.ACERCANDOSE
	m.limite_derecho = ideal if d > 0.0 else _limites.y
	m.limite_izquierdo = ideal if d < 0.0 else _limites.x
	m.frenada_limite_andar = frenada_obstaculo
	m.espera_parada_andar = 0
	m.andar_hasta(ideal)
	await m.llegado
	_modo = Modo.LIBRE
	m.control_bloqueado = false
	if (m.position.x - ideal) * d > 0.0:
		m.position.x = ideal
	if absf((ideal - m.position.x) * d) <= tol:
		empezar.call()

## Lo lleva deslizando hasta x en el reposo, a ASENTAR px/s, y luego sigue.
const ASENTAR := 80.0
func _asentar(x: float, luego: Callable) -> void:
	_modo = Modo.ACERCANDOSE
	_magnus.control_bloqueado = true
	var t := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_property(_magnus, "position:x", x, absf(x - _magnus.position.x) / ASENTAR)
	await t.finished
	_modo = Modo.LIBRE
	_magnus.control_bloqueado = false
	luego.call()

## E: lo que haya delante, lo mas cerca primero.
func _accion() -> void:
	var m := _magnus
	if not _listo() or _en_mano():
		return
	var d: float = m.mirando()
	var x := m.position.x
	var mejor := {}
	# objetos sueltos (piedrecita, palo) y el baculo clavado
	var cosas: Array = []
	for s in _sueltos:
		# a su altura: lo que esta en el suelo desde el suelo, lo de la mesa desde delante de la mesa
		var apoyo: float = s.nodo.position.y + s.nodo.texture.get_height() - 1.0 + PLANTA
		var a_su_altura := absf(apoyo - m.position.y) < 12.0 or s.accion == "coger_mesa"
		if s.activo and s.nodo.visible and _datos.has(s.accion) and a_su_altura and s.accion != "coger_mesa":
			cosas.append([s.accion, s.nodo.position.x, s.nodo.position.x + s.nodo.texture.get_width(), s])
	if _clavado and _datos.has("arrancar"):
		cosas.append(["arrancar", _clavado.position.x, _clavado.position.x + _clavado.texture.get_width(), null])
	for c in cosas:
		var dat: Dictionary = _datos[c[0]]
		if dat["objetos_ini"].is_empty():
			continue
		# el borde de cerca del objeto, y donde tiene que estar el nodo
		var borde: float = c[1] if d > 0.0 else c[2]
		var ideal: float = borde - d * float(dat["objetos_ini"][0][0])
		var falta: float = (ideal - x) * d
		if falta >= -tolerancia and falta <= acercarse_max and (mejor.is_empty() or falta < mejor["falta"]):
			mejor = {"anim": c[0], "ideal": ideal, "falta": falta, "suelto": c[3]}
	# la cara de delante (mesa, argolla)
	var sig := _siguiente(x, m.position.y, d)
	if not sig.is_empty():
		var o: Objeto = sig["objeto"]
		var queda := true
		if o.accion == "coger_mesa":
			queda = _sueltos.any(func(q): return q.accion == "coger_mesa" and q.activo and q.nodo.visible)
		if o.accion != "" and queda and _datos.has(o.accion) and absf(m.position.y - _suelo) < 0.5:
			var ideal2: float = sig["x"] - d * float(_datos[o.accion]["cara"])
			var falta2: float = (ideal2 - x) * d
			if falta2 >= -tolerancia and falta2 <= acercarse_max and (mejor.is_empty() or falta2 < mejor["falta"]):
				mejor = {"anim": o.accion, "ideal": ideal2, "falta": falta2, "objeto": o, "cara": sig["x"]}
	if mejor.is_empty():
		_ultima = "(nada que hacer aqui)"
		return
	var anim: String = mejor["anim"]
	if _se_llega(anim, mejor["ideal"], d):
		_acercarse(mejor["ideal"], d, func(): _hacer(mejor, d))

func _hacer(c: Dictionary, d: float) -> void:
	var anim: String = c["anim"]
	var dat: Dictionary = _datos[anim]
	# lo que coge o arranca va en el dibujo, donde lo tiene el video respecto a
	# el: si no esta justo en su sitio, al empezar saltaria lo que falte. Antes
	# se desliza hasta alli, despacio (andando se queda unos px corto)
	if not dat["objetos_ini"].is_empty() and absf(c["ideal"] - _magnus.position.x) > 0.5:
		_asentar(c["ideal"], func(): _hacer(c, d))
		return
	_corr = (c["ideal"] - _magnus.position.x) * d
	_y_fin = _magnus.position.y
	_bloque = null
	_tira = false
	match anim:
		"coger_suelo", "coger_mesa", "lanzar_palo":
			var s: Suelto = c.get("suelto")
			if s == null:
				for q in _sueltos:
					if q.accion == anim and q.activo and q.nodo.visible:
						s = q
			if s:
				s.nodo.visible = false         # desde aqui lo trae el video
			if anim == "lanzar_palo":
				_al_acabar = Callable()
		"arrancar":
			_clavado.visible = false
			_al_acabar = func():
				_clavado.queue_free()
				_clavado = null
				# la bola vuelve al baston, ya encendido (ver abajo): sin fundido
				var b := _baston()
				if b:
					b.poner_en_mano(true)
					b.visible = true
				if _bola:
					_bola.visible = false
		"tirar":
			# anda hacia atras lo que dura el tiron: tiene que haber sitio detras
			var atras := _siguiente(_magnus.position.x, _magnus.position.y, -d)
			var hace_falta: float = absf(float(dat["viaje"][0])) + 60.0
			if not atras.is_empty() and absf(float(atras["x"]) - _magnus.position.x) < hace_falta:
				_ultima = "(tirar: no hay sitio detras)"
				return
			_bloque = c["objeto"]
			_tira = true
			_contacto = int(dat.get("contacto", 0))
	_empezar([anim], d)
	if anim == "arrancar":
		# el baston no se ve mientras dura (arrancar no esta en su seguimiento): se
		# pone ya, y al acabar sale con la bola entera en vez de fundirse
		var b := _baston()
		if b:
			b.puesto = true

func _clavar() -> void:
	if not _listo() or not _en_mano() or not _datos.has("clavar"):
		return
	var d: float = _magnus.mirando()
	_corr = 0.0
	_y_fin = _magnus.position.y
	_bloque = null
	_al_acabar = func(): _poner_clavado(d)
	_bola_del_baculo()
	_empezar(["clavar"], d)
	# el baston lo suelta ya, escondido mientras dura (clavar no esta en su
	# seguimiento): si no, al acabar asomaba un momento a la espalda, fundiendose.
	# Desde aqui la bola la lleva _bola, en la garra del dibujo y luego clavada.
	var b := _baston()
	if b:
		b.poner_en_mano(false)
		b.puesto = false

## La bola del baculo mientras no la lleva el baston (clavar, clavado y
## arrancar: el baculo va en el dibujo o en el suelo, con la garra vacia): una
## copia de su Orbe y su Luz con los mismos materiales, que el baston anima
## (carga, color, destello). Mismo orden que en el baston: la bola detras del
## dibujo (la garra por delante) y la luz por encima.
func _bola_del_baculo() -> void:
	var b := _baston()
	if _bola or b == null:
		return
	_bola = Node2D.new()
	_bola.z_index = -1
	for nombre in ["Orbe", "Luz"]:
		var c: Node2D = b.get_node("Madera/" + nombre).duplicate()
		c.position = Vector2.ZERO
		_bola.add_child(c)
	_bola.visible = false
	add_child(_bola)

## La bola en la garra del dibujo: la tabla "orbe" (montar_accion.py), respecto
## al centro de la casilla, como la de mano.json del baston.
func _colocar_bola(o: Array) -> void:
	var lado := -1.0 if _sprite.flip_h else 1.0
	_bola.position = _magnus.position + _sprite.position + _sprite.offset + Vector2(float(o[0]) * lado, float(o[1]))
	_bola.visible = true

## El baculo clavado donde lo deja clavar (el mismo dibujo que al empezar arrancar).
func _poner_clavado(d: float) -> void:
	var dat: Dictionary = _datos["arrancar"]
	if dat["objetos_ini"].is_empty():
		return
	var caja: Array = dat["objetos_ini"][0]
	_clavado = _sprite_de("baculo_clavado")
	_clavado.z_index = -1
	var w: float = _clavado.texture.get_width()
	var x: float = _magnus.position.x + float(caja[0]) if d > 0.0 else _magnus.position.x - float(caja[0]) - w
	_clavado.flip_h = d < 0.0
	_clavado.position = Vector2(x, _magnus.position.y + float(caja[1]))
	add_child(_clavado)
	# su bola, donde la tiene arrancar al empezar, con el nodo ya donde se queda
	# (en el ultimo fotograma de clavar iba 1 px mas arriba)
	if _bola and dat.has("orbe"):
		var o: Array = dat["orbe"][0]
		var ofs := Vector2(float(dat["offset"][0]), float(dat["offset"][1]))
		_bola.position = _magnus.position + _sprite.position + ofs + Vector2(float(o[0]) * d, float(o[1]))

func _tumbarse() -> void:
	if not _listo() or not _datos.has("tumbarse"):
		return
	if _baston_encima():
		_ultima = "(tumbarse: solo sin el baculo encima; G o K)"
		return
	_corr = 0.0
	_y_fin = _magnus.position.y
	_bloque = null
	_al_acabar = func(): _quedar_tumbado("tumbarse")
	_empezar(["tumbarse"], _magnus.mirando())

## Tumbado: el ultimo fotograma de lo que lo dejo tumbado (tumbarse o
## arrastrarse), quieto, hasta que se arrastre o se levante. El arrastre es un
## ciclo que acaba donde empieza y levantarse empieza donde acaban los dos
## (montar_accion.py), asi que se puede encadenar de cualquier manera.
func _quedar_tumbado(anim: String) -> void:
	_modo = Modo.TUMBADO
	_magnus.control_bloqueado = true
	var dat: Dictionary = _datos[anim]
	_sprite.offset = Vector2(dat["offset"][0], dat["offset"][1])
	_sprite.animation = anim
	_sprite.stop()
	_sprite.frame = int(dat["n"]) - 1

func _tumbado() -> void:
	var eje := Input.get_axis("mover_izquierda", "mover_derecha")
	if not is_zero_approx(eje) and signf(eje) == _magnus.mirando() and _datos.has("arrastrarse"):
		_corr = 0.0
		_y_fin = _magnus.position.y
		_bloque = null
		_al_acabar = func(): _quedar_tumbado("arrastrarse")
		_empezar(["arrastrarse"], _magnus.mirando())

func _levantarse() -> void:
	if not _datos.has("levantarse_tumbado"):
		return
	_corr = 0.0
	_y_fin = _magnus.position.y
	_bloque = null
	_al_acabar = Callable()
	_empezar(["levantarse_tumbado"], _magnus.mirando())

## Acciones sin objeto (golpe, derribo): donde este.
func _sin_mas(anim: String) -> void:
	if not _listo() or _en_mano() or not _datos.has(anim):
		return
	_corr = 0.0
	_y_fin = _magnus.position.y
	_bloque = null
	_al_acabar = Callable()
	_empezar([anim], _magnus.mirando())

func _recolocar() -> void:
	for s in _sueltos:
		s.activo = true
		s.nodo.visible = true
		s.nodo.position = s.pos_ini
	for o in _obj:
		o.x0 = o.x_ini
		_colocar_objeto(o)
	_ultima = "(objetos en su sitio)"

## ---- el palo en el aire ------------------------------------------------------

func _soltar_palo(dat: Dictionary) -> void:
	var su: Dictionary = dat["suelta"]
	_palo_vuela = _sprite_de("palo")
	_palo_vuela.centered = true
	_palo_vuela.z_index = 0
	var p: Array = su["pos"]
	var v: Array = su["vel"]
	_palo_vuela.position = _magnus.position + Vector2(float(p[0]) * _d, float(p[1]))
	_palo_vel = Vector2(float(v[0]) * _d, float(v[1])) * float(VELOCIDAD.get(_anim, 1.0))   # suelta al ritmo de la accion
	_palo_vuela.flip_h = _d < 0.0
	add_child(_palo_vuela)

func _volar_palo(delta: float) -> void:
	if _palo_vuela == null:
		return
	_palo_vel.y += GRAVEDAD_PALO * delta
	_palo_vuela.position += _palo_vel * delta
	_palo_vuela.rotation += 9.0 * delta * signf(_palo_vel.x)
	var suelo := _nivel(_palo_vuela.position.x)
	var fuera := _palo_vuela.position.x < _limites.x - 100.0 or _palo_vuela.position.x > _limites.y + 100.0
	if _palo_vuela.position.y >= suelo - 6.0 or fuera:
		# cae tumbado donde haya suelo; queda para cogerlo otra vez
		var x := clampf(_palo_vuela.position.x, _limites.x, _limites.y - 120.0)
		_palo_vuela.queue_free()
		_palo_vuela = null
		for s in _sueltos:
			if s.accion == "lanzar_palo":
				var tam: Vector2 = s.nodo.texture.get_size()
				s.nodo.position = Vector2(x - tam.x / 2.0, _nivel(x) - PLANTA - tam.y + 1.0)
				s.nodo.visible = true
				s.activo = true

## ---- reproducir --------------------------------------------------------------

## Fotogramas por segundo de una accion: los de su video por su VELOCIDAD.
func _fps(anim: String) -> float:
	return float(_datos[anim]["fps"]) * float(VELOCIDAD.get(anim, 1.0))

func _poner_tramo(anim: String) -> void:
	_anim = anim
	_t = 0.0
	_f = -1
	var dat: Dictionary = _datos[anim]
	_sprite.offset = Vector2(dat["offset"][0], dat["offset"][1])
	_sprite.animation = anim
	_sprite.stop()
	_sprite.frame = 0

func _empezar(tramos: Array, d: float) -> void:
	_tramos = tramos
	_k = 0
	_d = d
	_base = _magnus.position
	_magnus.control_bloqueado = true
	_modo = Modo.ACCION
	_ultima = ""
	if _traza != "":
		print("acciones: empieza %s en (%.1f, %.1f) mirando %+d, falta %.1f" % [tramos, _base.x, _base.y, int(d), _corr])
	_poner_tramo(_tramos[0])
	_avanzar(0.0)

## Trepar o bajar: un tramo; la x se corrige con lo que avanza el cuerpo (s.x) y
## la altura de llegada manda en la y (s.y).
func _empezar_una(anim: String, a: Dictionary, d: float) -> void:
	if a.is_empty():
		return
	var dat: Dictionary = _datos[anim]
	var cara: float = a["cara"]
	_corr = (cara - _magnus.position.x) * d - float(dat["cara"])
	if anim == "bajar":
		var x_fin: float = cara + d * float(dat["cara_fin"])
		_y_fin = _nivel(x_fin)
	else:
		_y_fin = a["y"]
	_bloque = null
	_al_acabar = Callable()
	_empezar([anim], d)

## Empujar: de momento una pasada entera (entrada, empuje y salida, ver
## montar_accion.py: los videos no traen un ciclo que cierre). Si algun dia hay
## ciclo, la tabla trae "<e>_entrada", "<e>" con "bucle" y "<e>_salida" y esto
## los encadena (ver _siguiente_tramo).
func _empezar_empuje(a: Dictionary, d: float) -> void:
	var e: String = a["empuje"]
	var o: Objeto = a["objeto"]
	var tramos: Array = [e]
	if _datos.has(e + "_entrada") and _datos.has(e + "_salida"):
		tramos = [e + "_entrada", e, e + "_salida"]
	var hace_falta := 0.0
	for t in tramos:
		hace_falta += float(_datos[t]["bloque_siguiente"])
	if _hueco_delante(o, d) < hace_falta:
		_ultima = "(el sillar no tiene sitio para moverse)"
		_espera = 0.0
		return
	var ent: Dictionary = _datos[tramos[0]]
	_bloque = o
	_tira = false
	_corr = (a["cara"] - _magnus.position.x) * d - float(ent["cara"])
	_contacto = int(ent["contacto"])
	_y_fin = _magnus.position.y
	_seguir = true
	_al_acabar = Callable()
	_empezar(tramos, d)

## Sitio libre delante del sillar (hasta otro objeto o el final de la escena).
func _hueco_delante(o: Objeto, d: float) -> float:
	var frente := o.x1() if d > 0.0 else o.x0
	var tope := (_limites.y + 150.0) if d > 0.0 else (_limites.x - 150.0)
	for q in _obj:
		if q == o:
			continue
		var cara_q := q.x0 if d > 0.0 else q.x1()
		if (cara_q - frente) * d >= -0.5 and (cara_q - tope) * d < 0.0:
			tope = cara_q
	return (tope - frente) * d

func _avanzar(delta: float) -> void:
	var dat: Dictionary = _datos[_anim]
	var n := int(dat["n"])
	_t += delta
	var f := int(_t * _fps(_anim))
	while f >= n:
		if not _siguiente_tramo():
			return
		dat = _datos[_anim]
		n = int(dat["n"])
		f = int(_t * _fps(_anim))
	if f == _f:
		return
	var antes := _f
	_f = f
	_sprite.frame = f
	if dat.has("suelta") and antes < int(dat["suelta"]["f"]) and f >= int(dat["suelta"]["f"]):
		_soltar_palo(dat)
	var r: Array = dat["raiz"][f]
	var s: Array = dat["s"][f]
	var x := 0.0
	var y := _base.y
	if _bloque == null or _tira:
		# una pasada (trepar, bajar, coger, tirar...): lo que falta se reparte
		# con lo que avanza el cuerpo; la altura de llegada manda en la y
		x = _base.x + (float(r[0]) + _corr * float(s[0])) * _d
		y = _base.y + float(s[1]) * (_y_fin - _base.y) if absf(_y_fin - _base.y) > 0.5 else _base.y + float(r[1])
	elif _k == 0:
		# entrada del empuje: lo que falta se anda antes de tocar el sillar
		var rc: float = float(dat["raiz"][maxi(_contacto, 1)][0])
		var w := clampf(float(r[0]) / rc, 0.0, 1.0) if rc > 0.5 else 1.0
		if f >= _contacto:
			w = 1.0
		x = _base.x + (float(r[0]) + _corr * w) * _d
		y = _base.y + float(r[1])           # empujando, el video pisa algo mas alto: se baja
	else:
		x = _base.x + float(r[0]) * _d
		y = _base.y + float(r[1])
	_magnus.position = Vector2(x, y)
	if _bola and dat.has("orbe"):
		_colocar_bola(dat["orbe"][f])
	if _bloque and (_k > 0 or f >= _contacto) and dat.has("objeto"):
		# el sillar va con las manos (empujando delante; tirando, delante tambien)
		var cara := x + float(dat["objeto"][f]) * _d
		_bloque.x0 = cara if _d > 0.0 else cara - _bloque.ancho
		_colocar_objeto(_bloque)

## Al acabar un tramo: el siguiente (o la otra vuelta del ciclo), o se acaba.
func _siguiente_tramo() -> bool:
	var dat: Dictionary = _datos[_anim]
	var resto := _t - float(dat["n"]) / _fps(_anim)
	var paso: Array = dat["siguiente"]
	var adelante := float(paso[0]) + (_corr if (_bloque and _k == 0) else 0.0)
	# ciclo con salida detras (el empuje, si algun dia lo hay); el arrastre se
	# repite tramo a tramo desde el estado tumbado
	if dat.get("bucle", false) and _k + 1 < _tramos.size():
		var eje := Input.get_axis("mover_izquierda", "mover_derecha")
		var sal: Dictionary = _datos[_tramos[_k + 1]]
		_seguir = signf(eje) == _d and _hueco_delante(_bloque, _d) >= float(dat["bloque_siguiente"]) + float(sal["bloque_siguiente"])
		_base.x += adelante * _d
		if _seguir:
			_t = resto
			_f = -1
			return true
	elif _k + 1 < _tramos.size():
		_base.x += adelante * _d
	if _k + 1 >= _tramos.size():
		_terminar()
		return false
	_k += 1
	_poner_tramo(_tramos[_k])
	_t = resto
	return true

func _terminar() -> void:
	var dat: Dictionary = _datos[_anim]
	var r: Array = dat["raiz"][int(dat["n"]) - 1]
	if _bloque == null or _tira:
		# acaba en su altura: la de llegada (trepar, bajar) o la de salida (lo demas)
		_magnus.position = Vector2(_base.x + (float(r[0]) + _corr) * _d, _y_fin)
	else:
		_magnus.position.y = _y_fin
	var acabada := _tramos[0] as String
	_x_antes = _magnus.position.x
	if _traza != "":
		print("acciones: acaba %s en (%.1f, %.1f)%s" % [_anim, _magnus.position.x, _magnus.position.y,
		(" sillar en %.1f" % _bloque.x0) if _bloque else ""])
	_ultima = "(" + _anim + ")"
	_bloque = null
	_tira = false
	_modo = Modo.LIBRE
	var despues := _al_acabar
	_al_acabar = Callable()
	_sprite.offset = _magnus.offset_comun
	_sprite.play("reposo")
	_magnus.control_bloqueado = false
	if despues.is_valid():
		despues.call()
	# llega sin aliento (la respiracion de Magnus va por su esfuerzo, 0..1, y
	# solo arranca al entrar en el reposo: aqui se entra a mano)
	var esfuerzo: float = ESFUERZO.get(acabada, 0.0)
	if _modo == Modo.LIBRE and esfuerzo > float(_magnus.get("_esfuerzo")):
		_magnus.set("_esfuerzo", esfuerzo)
		_magnus.call("_respirar", true)
