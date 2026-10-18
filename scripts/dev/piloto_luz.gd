extends "res://scripts/dev/piloto.gd"
## Piloto del flotar en la luz (caida_hojarasca sin la caida). Cada prueba es
## un sitio de salida y un guion de teclas; se elige con `prueba` o con la
## variable de entorno LUZ_PRUEBA (para lanzarlo desde la linea de ordenes):
##   centro       salto de parado en mitad del haz, y otro
##   fuera        salto de parado lejos del haz (el de siempre)
##   entra        salto andando desde la sombra hacia el haz
##   sale         salto andando desde el haz hacia la sombra
##   dentro       salto andando de lado a lado del haz
##   anda_fuera   salto andando lejos del haz (con salto_andando_altura)
##   corre_fuera  salto corriendo lejos del haz (el de siempre)
##   corre_entra  salto corriendo que entra en el haz ya bajando
##   corre_dentro salto corriendo que despega en el borde del haz
##   paseo        de todo un poco, para verlo seguido
##   escalera     un bot sube por las hojas que bajan por la luz hasta el baculo
##   planear      salto de parado; bajando, mantiene salto (con planear_activo, planea)
##                (el rebote sigue como salto de parado y se gira en el aire)
##   dirige       salto de parado en el centro, derecha en el aire
##   gira         salto de parado en el centro, izquierda en el aire: se gira
##   gira_izq     lo mismo mirando a la izquierda (derecha en el aire)
##   gira_tarde   izquierda ya bajando: frena y se gira al tocar suelo
##   demo         los siete casos con rotulo, en bucle hasta Esc (ver DEMO)
## Con traza, cada tick en el aire imprime fotograma, altura, luz y arco.

const PRUEBAS := {
	# La camara y el paralaje del bosque: anda a la derecha, para, corre a la
	# izquierda (doble toque) y para.
	"paralaje": [1300.0, [[0.4, "mover_derecha", true], [3.4, "mover_derecha", false],
		[4.6, "mover_izquierda", true], [4.68, "mover_izquierda", false],
		[4.76, "mover_izquierda", true], [7.0, "mover_izquierda", false]]],
	"centro": [1470.0, [[0.8, "saltar", true], [0.9, "saltar", false],
		[3.6, "saltar", true], [3.7, "saltar", false]]],
	# El mismo salto de parado en mitad del haz, mirando a la izquierda.
	"centro_izq": [1470.0, [[0.8, "saltar", true], [0.9, "saltar", false]]],
	"fuera": [600.0, [[0.8, "saltar", true], [0.9, "saltar", false],
		[2.6, "saltar", true], [2.7, "saltar", false]]],
	"entra": [880.0, [[0.3, "mover_derecha", true], [1.75, "saltar", true], [1.85, "saltar", false],
		[3.0, "mover_derecha", false]]],
	"sale": [1330.0, [[0.3, "mover_derecha", true], [1.05, "saltar", true], [1.15, "saltar", false],
		[2.5, "mover_derecha", false]]],
	"dentro": [1180.0, [[0.3, "mover_derecha", true], [1.15, "saltar", true], [1.25, "saltar", false],
		[2.6, "mover_derecha", false]]],
	"anda_fuera": [400.0, [[0.3, "mover_derecha", true], [1.3, "saltar", true], [1.4, "saltar", false],
		[2.6, "mover_derecha", false]]],
	# Corriendo (doble toque): en la sombra, entrando en el haz y despegando en el.
	"corre_fuera": [200.0, [[0.3, "mover_derecha", true], [0.38, "mover_derecha", false],
		[0.46, "mover_derecha", true], [1.4, "saltar", true], [1.7, "saltar", false],
		[2.8, "mover_derecha", false]]],
	"corre_entra": [560.0, [[0.3, "mover_derecha", true], [0.38, "mover_derecha", false],
		[0.46, "mover_derecha", true], [1.4, "saltar", true], [1.7, "saltar", false],
		[3.6, "mover_derecha", false]]],
	"corre_dentro": [880.0, [[0.3, "mover_derecha", true], [0.38, "mover_derecha", false],
		[0.46, "mover_derecha", true], [1.4, "saltar", true], [1.7, "saltar", false],
		[3.6, "mover_derecha", false]]],
	# En la sombra, salto de parado; andando, salto que entra en el haz; parado
	# en el centro, salto de parado; andando, salto que sale del haz.
	"paseo": [1000.0, [[0.6, "saltar", true], [0.7, "saltar", false],
		[2.0, "mover_derecha", true], [3.25, "saltar", true], [3.35, "saltar", false],
		[4.4, "mover_derecha", false], [5.6, "saltar", true], [5.7, "saltar", false],
		[7.8, "mover_derecha", true], [8.3, "saltar", true], [8.4, "saltar", false],
		[10.0, "mover_derecha", false]]],
	# Dirigir en el aire (parado en el centro, derecha en el aire). Por las
	# hojas de la luz sube un bot (ver _bot): prueba "escalera".
	"escalera": [1420.0, []],
	# PLANEAR (con planear_activo): salto de parado en el haz; bajando, mantiene salto.
	"planear": [1470.0, [[0.8, "saltar", true], [0.9, "saltar", false],
		[1.9, "saltar", true], [3.6, "saltar", false]]],
	# FLOTAR QUIETO: un salto de parado en la luz al que, subiendo, se le suman
	# 400 px (como si saltase desde una hoja alta): flota quieto, gira a media
	# caida y se posa con la bajada de siempre.
	"flotar_alto": [1456.0, [[0.8, "saltar", true], [0.9, "saltar", false],
		[4.0, "mover_izquierda", true], [4.15, "mover_izquierda", false]]],
	# La cinematica de coger el baculo, sin subir: baja el baculo y lo coge.
	"coger": [1380.0, []],
	"coger_b": [1380.0, []],
	# Con el bosque de fondo (LUZ_BOSQUE=1): el viento destapa el camino al
	# segundo, con Magnus quieto en el centro.
	"camino": [1470.0, []],
	# El lecho bajo el haz no crece con las hojas que caen por la luz.
	"monton": [600.0, []],
	"dirige": [1470.0, [[0.8, "saltar", true], [0.9, "saltar", false],
		[1.3, "mover_derecha", true], [2.0, "mover_derecha", false]]],
	# Girarse en el aire: salto de parado en el centro mirando a la derecha e
	# izquierda pulsada nada mas despegar (espera a la pose y se gira); con
	# _izq, al reves. "gira_tarde": izquierda ya bajando, tarde para girarse en
	# el aire (frena y se gira al tocar suelo).
	"gira": [1470.0, [[0.8, "saltar", true], [0.9, "saltar", false],
		[1.15, "mover_izquierda", true], [4.6, "mover_izquierda", false]]],
	"gira_izq": [1470.0, [[0.8, "saltar", true], [0.9, "saltar", false],
		[1.15, "mover_derecha", true], [4.6, "mover_derecha", false]]],
	"gira_tarde": [1470.0, [[0.8, "saltar", true], [0.9, "saltar", false],
		[2.6, "mover_izquierda", true], [4.2, "mover_izquierda", false]]],
	# Con la caida y los pensamientos (escena con caida_al_empezar): salto en la
	# luz en cuanto se levanta, mientras piensa al despertar.
	"historia": [1470.0, [[9.5, "saltar", true], [9.6, "saltar", false]]],
	# La historia entera (con la caida; escena temporal sin caida_al_empezar =
	# false): andando a la derecha hasta dar la vuelta al mundo (pensamiento
	# "vuelta" y luego baja el baculo), o quieto mas de un minuto ("explorar").
	"historia_vuelta": [1456.0, [[11.0, "mover_derecha", true], [30.0, "mover_derecha", false]]],
	"historia_quieto": [1456.0, []],
}
## Lo que el piloto le hace a la escena en cada prueba: [s, "baculo"] lo baja
## deprisa y pone la escalera ya en su sitio (sin la entrada).
const EXTRAS := {
	"escalera": [[0.0, "baculo"]],
	"flotar_alto": [[1.4, "subir_400"]],
	"coger": [[0.0, "baculo"], [1.5, "coger"]],
	# Lo coge y luego B: lo guarda a la espalda y lo vuelve a sacar.
	"coger_b": [[0.0, "baculo"], [1.5, "coger"], [7.0, "tecla_b"], [12.0, "tecla_b"]],
	"camino": [[1.0, "camino"]],
}

## demo: todos los casos seguidos para mirarlos, con un rotulo que dice cual es,
## en bucle hasta Esc. Cada paso espera a lo suyo:
##   ["texto", t]          pone el rotulo
##   ["espera", s]         segundos
##   ["hasta_x", x]        a que Magnus pase de x (sin dar la vuelta al mundo:
##                         una vuelta entera suma 2912)
##   ["pulsa"|"suelta", accion]
const DEMO := [
	["texto", "1 · Salto parado en la sombra"], ["espera", 1.0],
	["pulsa", "saltar"], ["espera", 0.1], ["suelta", "saltar"], ["espera", 1.8],
	["texto", "2 · Salto andando en la sombra"], ["pulsa", "mover_derecha"], ["espera", 1.0],
	["pulsa", "saltar"], ["espera", 0.1], ["suelta", "saltar"],
	["texto", "3 · Salto andando que entra en la luz"], ["hasta_x", 1170.0],
	["pulsa", "saltar"], ["espera", 0.1], ["suelta", "saltar"], ["espera", 1.0],
	["suelta", "mover_derecha"], ["espera", 2.0],
	["texto", "4 · Salto parado en el centro de la luz"],
	["pulsa", "saltar"], ["espera", 0.1], ["suelta", "saltar"], ["espera", 2.6],
	["texto", "5 · Salto andando que sale de la luz"], ["pulsa", "mover_derecha"], ["hasta_x", 1560.0],
	["pulsa", "saltar"], ["espera", 0.1], ["suelta", "saltar"], ["espera", 1.9],
	["suelta", "mover_derecha"], ["espera", 1.5],
	["texto", "6 · Salto corriendo en la sombra"],
	["pulsa", "mover_derecha"], ["espera", 0.08], ["suelta", "mover_derecha"], ["espera", 0.08],
	["pulsa", "mover_derecha"], ["hasta_x", 2350.0],
	["pulsa", "saltar"], ["espera", 0.3], ["suelta", "saltar"],
	["texto", "7 · Salto corriendo que despega en el borde de la luz"], ["hasta_x", 2912.0 + 1190.0],
	["pulsa", "saltar"], ["espera", 0.3], ["suelta", "saltar"], ["espera", 2.2],
	["suelta", "mover_derecha"], ["espera", 2.5],
]

@export var prueba := "centro"
@export var traza := true
## Que las teclas de verdad no lleguen (grabando, la ventana coge el teclado).
## Esc sigue saliendo.
@export var ignorar_teclado := true

var _paso := 0
var _espera := 0.0
var _x_total := 0.0
var _x_antes := 0.0
var _rotulo: Label
var _extra := 0
var _avisado := false

func _ready() -> void:
	# Con LUZ_BOSQUE=1, el bosque de fondo (prueba); LUZ_BOSQUE_EXP, su exposicion.
	if OS.get_environment("LUZ_BOSQUE") != "":
		var escena_b := get_node_or_null(personaje).get_parent()
		escena_b.bosque_de_fondo = true
		var ex := OS.get_environment("LUZ_BOSQUE_EXP")
		if ex != "":
			(escena_b.get_node("Bosque").material as ShaderMaterial).set_shader_parameter("exposicion", ex.to_float())
		if OS.get_environment("LUZ_CAMINO") != "":
			(escena_b.get_node("Bosque").material as ShaderMaterial).set_shader_parameter("camino", 1.0)
	var p: String = OS.get_environment("LUZ_PRUEBA")
	if p != "":
		prueba = p
	if PRUEBAS.has(prueba):
		x_inicial = PRUEBAS[prueba][0]
		guion = PRUEBAS[prueba][1]
	elif prueba == "demo":
		x_inicial = 300.0
		guion = []
		traza = false
		var capa := CanvasLayer.new()
		capa.layer = 30
		add_child(capa)
		_rotulo = Label.new()
		_rotulo.position = Vector2(60, 50)
		_rotulo.add_theme_font_size_override("font_size", 44)
		_rotulo.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 0.9))
		capa.add_child(_rotulo)
	print("piloto_luz prueba=%s x=%.0f" % [prueba, x_inicial])
	super()
	if prueba.ends_with("_izq"):
		get_node_or_null(personaje)._mirar(-1.0)
	_x_total = x_inicial
	_x_antes = x_inicial
	var pensar := get_node_or_null(personaje).get_parent().get_node_or_null("Pensamientos")
	if pensar:
		pensar.empieza.connect(func(clave: String) -> void: print("piloto %.3f piensa %s" % [_t, clave]))
	if ignorar_teclado:
		var salida := get_node_or_null("/root/GlobalExit")
		if salida:
			salida.set_process_input(false)

func _input(event: InputEvent) -> void:
	if ignorar_teclado and (event is InputEventKey or event is InputEventMouse):
		get_viewport().set_input_as_handled()
		var k := event as InputEventKey
		if k and k.pressed and k.keycode == KEY_ESCAPE:
			get_tree().quit()

## Un paso de la demo cada vez que se cumple lo que espera el anterior; al
## acabar, vuelve a empezar la escena.
func _demo(delta: float) -> void:
	var m := get_node_or_null(personaje)
	if m == null:
		return
	_x_total += wrapf(m.position.x - _x_antes, -1456.0, 1456.0)
	_x_antes = m.position.x
	while _paso < DEMO.size():
		var paso: Array = DEMO[_paso]
		match paso[0]:
			"texto":
				_rotulo.text = paso[1]
			"espera":
				_espera += delta
				if _espera < paso[1]:
					return
				_espera = 0.0
			"hasta_x":
				if _x_total < paso[1]:
					return
			"pulsa", "suelta":
				var ev := InputEventAction.new()
				ev.action = paso[1]
				ev.pressed = paso[0] == "pulsa"
				Input.parse_input_event(ev)
				if ev.pressed:
					_pulsadas[paso[1]] = true
				else:
					_pulsadas.erase(paso[1])
		_paso += 1
	get_tree().reload_current_scene()

## Bot de las hojas de la luz: en el suelo va bajo la hoja mas baja que viene
## bajando y salta de parado cuando la tiene a tiro (la recoge al bajar); en el
## aire va hacia la siguiente, la mas baja de las que tiene por encima de los
## pies (la eligio al rebotar: la de enfrente, que viene bajando), y al
## rebotar elige otra. Si cae al suelo, vuelve a empezar.
var _bot_hoja := {}
var _bot_rebotes := 0
var _bot_tecla := ""
var _bot_estaba_cayendo := false

## La hoja de la luz mas baja con su y entre los pies menos `desde` y los pies
## menos `hasta` (px por encima de los pies). Vacio si no hay.
func _bot_elegir(escena: Node, pies_y: float, desde: float, hasta: float) -> Dictionary:
	var mejor := {}
	for h in escena.hojas_de_la_luz():
		var sobre: float = pies_y - h["p"].y
		if sobre < desde or sobre > hasta:
			continue
		if mejor.is_empty() or h["p"].y > mejor["p"].y:
			mejor = h
	return mejor

func _bot(_delta: float) -> void:
	var m := get_node_or_null(personaje)
	var escena := m.get_parent()
	if _t < 1.0:
		return
	var hojas: Array = escena.hojas_de_la_luz()
	var pies_y: float = m.global_position.y - m.altura_pies()
	var en_el_aire: bool = m._estado == m.Estado.SALTAR and (m._vuelo == 1 or m._vuelo == 2)
	if en_el_aire:
		if _bot_estaba_cayendo and m._vuelo == 1:
			_bot_rebotes += 1
			print("piloto %.3f rebote %d en y=%.0f" % [_t, _bot_rebotes, pies_y])
			_bot_hoja = {}
		_bot_estaba_cayendo = m._vuelo == 2
		if _bot_hoja.is_empty() or not hojas.has(_bot_hoja):
			_bot_hoja = _bot_elegir(escena, pies_y, 25.0, 400.0)
		var objetivo_x: float = m.position.x
		if not _bot_hoja.is_empty():
			objetivo_x = _bot_hoja["p"].x
		# Hacia la hoja, mirando donde se pararia soltando ya (la luz lo frena
		# a deriva_aceleracion); a menos de 30 px (la hoja se pisa a 23 mas su
		# medio ancho), suelta: ir por tan poco hacia atras seria un giro entero
		# y se perdia la hoja.
		var v: float = m._velocidad() * m._mirando + m._deriva
		var dx: float = objetivo_x - (m.position.x + v * absf(v) / (2.0 * m.deriva_aceleracion))
		_bot_pulsar("mover_derecha" if dx > 30.0 else ("mover_izquierda" if dx < -30.0 else ""))
		return
	_bot_estaba_cayendo = false
	if m._estado != m.Estado.REPOSO:
		_bot_pulsar("")
		return
	# En el suelo: bajo la hoja mas baja de las que vienen (entre 175 y 330 px
	# sobre los pies) y, ya debajo, salta cuando la tiene a 200 px: la recoge
	# bajando del apogeo (sube 177 en ~1 s; la hoja baja ~35).
	if _bot_rebotes > 0:
		print("piloto %.3f al suelo tras %d rebotes" % [_t, _bot_rebotes])
		_bot_rebotes = 0
	var h := _bot_elegir(escena, pies_y, 175.0, 330.0)
	if h.is_empty():
		_bot_pulsar("")
		return
	var dx0: float = h["p"].x - m.position.x
	if absf(dx0) > 22.0:
		_bot_pulsar("mover_derecha" if dx0 > 0.0 else "mover_izquierda")
		return
	_bot_pulsar("")
	if pies_y - h["p"].y <= 200.0:
		_bot_hoja = h
		for pulsar in [true, false]:
			var ev := InputEventAction.new()
			ev.action = "saltar"
			ev.pressed = pulsar
			Input.parse_input_event(ev)

func _bot_pulsar(tecla: String) -> void:
	if tecla == _bot_tecla:
		return
	if _bot_tecla != "":
		var suelta := InputEventAction.new()
		suelta.action = _bot_tecla
		suelta.pressed = false
		Input.parse_input_event(suelta)
		_pulsadas.erase(_bot_tecla)
	_bot_tecla = tecla
	if tecla != "":
		var pulsa := InputEventAction.new()
		pulsa.action = tecla
		pulsa.pressed = true
		Input.parse_input_event(pulsa)
		_pulsadas[tecla] = true

## Prueba "monton": las hojas del lecho bajo el haz al empezar y a los 4 min
## (las que caen por la luz no tienen que ir subiendo el monton).
var _monton_antes := -1

func _contar_monton() -> int:
	var escena := get_node_or_null(personaje).get_parent()
	var xh: float = escena.x_haz(1150.0)
	var n := 0
	for capa in [escena.get_node("HojasDelante"), escena.get_node("HojasDetras")]:
		for x in range(int(xh) - 160, int(xh) + 160, 8):
			n += capa.cuantas_en(x)
	return n

## LUZ_HOJAS=1: cuantas hojas del lecho vuelan cerca de Magnus (andando), para
## medir como responde el lecho al pasar.
var _hojas_suma := 0.0
var _hojas_ticks := 0

func _contar_hojas_cerca() -> int:
	var m := get_node_or_null(personaje)
	var escena := m.get_parent()
	var n := 0
	for capa in [escena.get_node("HojasDelante"), escena.get_node("HojasDetras")]:
		for h in capa._vuelan:
			if h.has("sitio") or h.get("ligera", false):
				continue
			if absf(h["p"].x - m.position.x) < 260.0 and h["p"].y > 1000.0:
				n += 1
	return n

func _physics_process(delta: float) -> void:
	super(delta)
	if OS.get_environment("LUZ_HOJAS") != "" and _t > 0.4 and _t < 1.75:
		_hojas_suma += _contar_hojas_cerca()
		_hojas_ticks += 1
		if _t + delta >= 1.75:
			print("piloto hojas del lecho volando cerca andando: media %.1f" % (_hojas_suma / maxf(_hojas_ticks, 1)))
	if OS.get_environment("LUZ_VIDA") != "" and int(_t * 4.0) != int((_t - delta) * 4.0):
		var ev := get_node_or_null(personaje).get_parent()
		print("piloto %.2f vida: racha %.2f dir %.0f copa %s respira %s zoom %.3f" % [_t, ev._racha, ev._racha_dir,
				str(ev._copa[2].round()), str(ev._respira.round()), ev._camara.zoom.x])
	if prueba == "camino" and OS.get_environment("LUZ_LECHO") != "" and int(_t * 2.0) != int((_t - delta) * 2.0) and int(_t) % 5 == 0 and int(_t * 2.0) % 2 == 0:
		var esc := get_node_or_null(personaje).get_parent()
		var en_lecho := 0
		var arriba := 0
		for capa in [esc.get_node("HojasDelante"), esc.get_node("HojasDetras")]:
			for c in capa._cols:
				en_lecho += c.size()
			for h in capa._vuelan:
				if h["p"].y < 0.0:
					arriba += 1
		print("piloto %.0f s: lecho %d hojas, %d por encima de la pantalla" % [_t, en_lecho, arriba])
	if prueba == "monton":
		if int(_t) % 60 == 0 and int(_t - delta) % 60 != 0:
			var esc := get_node_or_null(personaje).get_parent()
			var xh: float = esc.x_haz(1150.0)
			var lig := 0
			var tot := 0
			for capa in [esc.get_node("HojasDelante"), esc.get_node("HojasDetras")]:
				for x in range(int(xh) - 200, int(xh) + 200, 8):
					for h in capa._cols[capa._c(float(x))]:
						tot += 1
						if h.get("ligera", false):
							lig += 1
			print("piloto %.0f s: bajo el haz %d de %d hojas del lecho son ligeras" % [_t, lig, tot])
		if _monton_antes < 0:
			_monton_antes = _contar_monton()
		elif int(_t) % 60 == 0 and int(_t - delta) % 60 != 0:
			print("piloto %.0f s: monton bajo el haz %d hojas (al empezar %d)" % [_t, _contar_monton(), _monton_antes])
			if _t >= 240.0:
				get_tree().quit()
	if prueba.begins_with("escalera"):
		_bot(delta)
	if prueba == "demo":
		_demo(delta)
	var extras: Array = EXTRAS.get(prueba, [])
	while _extra < extras.size() and extras[_extra][0] <= _t:
		var e: Array = extras[_extra]
		var escena := get_node_or_null(personaje).get_parent()
		match e[1]:
			"camino":
				escena._abrir_camino()
			"subir_400":
				# en pleno vuelo (subiendo), 400 px mas alto
				var mg: Node = escena.get_node("Magnus")
				mg.set("_vuelo_y", float(mg.get("_vuelo_y")) + 400.0)
			"coger":
				escena._alcanzado = true
				escena._coger_baculo()
			"tecla_b":
				# la tecla del baston (accion "baston", ver Teclas)
				var tecla := InputEventAction.new()
				tecla.action = &"baston"
				tecla.pressed = true
				# directa a la escena: este piloto se come el teclado (ignorar_teclado)
				escena._unhandled_input(tecla)
			"baculo":
				var b: Node2D = escena.get_node("Baculo")
				b.bajada = 0.05
				b.bajar()
				escena.empezar_escalera(false)
				# como _bajar_baculo: con bosque, se apaga (EL BOSQUE SE APAGA CON EL BACULO)
				escena._atenuar_bosque(escena.bosque_atenuado, escena.bosque_apagar)
		_extra += 1
	if not traza:
		return
	var m := get_node_or_null(personaje)
	if m == null or m._estado != m.Estado.SALTAR:
		return
	var s: AnimatedSprite2D = m.get_node("Sprite")
	if m.get_parent()._alcanzado and not _avisado:
		_avisado = true
		print("piloto %.3f BACULO ALCANZADO" % _t)
	print("luz %.3f %s f=%d tau=%.2f vuelo=%d y=%.1f v=%.0f luz=%.2f arco=%.1f x=%.1f vel=%.0f pies=%.1f deriva=%.0f mira=%d%s giro=%d tope=%.0f" % [
		_t, s.animation, s.frame, m._vuelo_tau, m._vuelo, m._vuelo_y, m._vuelo_v, m._luz,
		-s.position.y, m.position.x, m._velocidad(), m.altura_pies(), m._deriva,
		int(m._mirando), "v" if s.flip_h else "", int(m._giro_aire), m._tope_caida()])

## Antes de pintar: el sprite donde dice la fisica para el fotograma que se ve.
## Si algo cambia el fotograma despues del tick de Magnus sin recolocarlo (el
## rebote, que lo llama el nivel), se pinta un fotograma descolocado: el
## parpadeo del rebote (2026-10-12). Lo avisa.
func _process(_delta: float) -> void:
	var m := get_node_or_null(personaje)
	if m == null or m._estado != m.Estado.SALTAR or not (m._vuelo == 1 or m._vuelo == 2):
		return
	var s: AnimatedSprite2D = m.get_node("Sprite")
	var arco: float = m._arco_de_ahora()
	if absf(arco + s.position.y) > 3.0:
		print("piloto %.3f DESCOLOCADO %s f=%d: pintado %.1f, toca %.1f" % [_t, s.animation, s.frame, -s.position.y, arco])
