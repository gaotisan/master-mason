extends Node
## Bot jugador de la maqueta del capitulo 1: intenta cerrar el arco JUGANDO, solo
## con teclas, para comprobar que se puede. No toca variables del juego: lee la
## posicion y la velocidad del peregrino, lo que tiene bajo los pies, y el arco
## (centro, radio, banda, punto_en, encendidos y sus senales), y decide que teclas
## pulsar como haria una persona: andar, saltar, pisar el aire, mantener el salto
## para flotar y bajar (abajo) para atravesar una losa.
##
## Estrategia: recorre el arco de un arranque al otro. El objetivo es siempre el
## punto medio del siguiente tramo apagado (en el orden del recorrido); el tramo
## se enciende en cuanto los pies pasan por su banda, y entonces el objetivo salta
## al siguiente.
##
## Modos:
##   experto     sabe donde esta el arco, reacciona al instante, flota y pisa el aire.
##   torpe       igual pero ve con retraso (reaccion), apunta con error, no mantiene
##               el salto para flotar, duda de vez en cuando y pisa el aire mas lento.
##   sin_aire    experto que nunca pisa el aire: solo saltos desde el suelo.
##   solo_andar  anda por el agua de lado a lado, sin saltar.
##   explorador  NO sabe donde esta el arco: va a puntos al azar de la pantalla
##               (andando, saltando y pisando el aire). Mide si se cierra solo.
##
##   godot --headless --path . --fixed-fps 60 --quit-after 7200 res://scenes/dev/piloto_bot_arco.tscn

@export var maqueta: NodePath = ^"../Maqueta"
@export_enum("experto", "torpe", "sin_aire", "solo_andar", "explorador") var modo: String = "experto"
## Por que arranque empieza: "cercano" (el del lado del peregrino), "izquierdo"
## (180 -> 0) o "derecho" (0 -> 180).
@export_enum("cercano", "izquierdo", "derecho") var empezar_por: String = "cercano"
@export var semilla: int = 1
## Solo torpe: segundos de retraso con que ve al peregrino.
@export var reaccion: float = 0.25
## Solo torpe: error de punteria (px) sobre el punto medio del tramo.
@export var error_punteria: float = 45.0
## Traza cada 0,25 s del estado (posicion, velocidad, objetivo, teclas).
@export var traza: bool = false
## Tras cerrar, anda hacia el camino para llegar al final de la maqueta.
@export var ir_al_final: bool = true
## Segundo en que imprime el resumen si aun no ha cerrado.
@export var resumen_a_los: float = 119.0
## SOLO EXPERIMENTOS "que pasaria si" (no es jugar limpio): si es > 0 cambia la
## banda del arco al empezar. Por defecto -1, no toca nada.
@export var quiza_banda: float = -1.0
## SOLO EXPERIMENTOS: si es > 0 cambia el impulso del salto desde el suelo.
@export var quiza_salto: float = -1.0

## Tolerancias de la persona: no salta por 45 px, no baja por 60.
const TOL_X := 14.0
const TOL_SUBIR := 45.0
const TOL_BAJAR := 60.0
## Entre dos pasos en el aire deja algo mas que la espera del juego (0,35 s).
const ESPERA_AIRE := 0.40
const TECHO_AIRE := 400.0

var _peregrino: CharacterBody2D
var _arco: Node2D
var _azar := RandomNumberGenerator.new()
var _t := 0.0
var _lit: Array = []
var _orden: Array = []
var _pulsadas := {}
var _salto_pendiente := false
var _abajo_pulsada := false
var _t_paso_aire := -99.0
var _t_ultimo_tramo := 0.0
var _t_cerrado := -1.0
var _t_traza := 0.0
var _saltos := 0
var _pasos_aire := 0
var _bajadas := 0
var _losas := 0
var _repisas := 0
var _fin_dicho := false
var _resumido := false
var _historia: Array = []  # [pos, vel, suelo] por tick, para el torpe
var _objetivo := Vector2.ZERO
var _t_objetivo := -99.0
var _objetivo_tramo := -2
var _duda_hasta := -1.0
var _andar_dir := 1.0
var _t_salto := -99.0
## Observadores de reglas alternativas (solo miran, no cambian el juego):
## cuando se habria encendido cada tramo con banda +-40, y pisando (con los pies
## en el suelo, sobre una losa, una repisa o el agua) dentro de la banda.
var _obs_banda40: Array = []
var _obs_pisando: Array = []

## Los ajustes se pueden cambiar sin tocar la escena, tras "--":
##   ... piloto_bot_arco.tscn -- modo=torpe semilla=3 traza=0 reaccion=0.3
func _leer_argumentos() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"modo": modo = kv[1]
			"empezar_por": empezar_por = kv[1]
			"semilla": semilla = int(kv[1])
			"reaccion": reaccion = float(kv[1])
			"error_punteria": error_punteria = float(kv[1])
			"traza": traza = kv[1] == "1"
			"ir_al_final": ir_al_final = kv[1] == "1"
			"quiza_banda": quiza_banda = float(kv[1])
			"quiza_salto": quiza_salto = float(kv[1])

func _ready() -> void:
	_leer_argumentos()
	_azar.seed = hash(semilla)
	var m := get_node(maqueta)
	_peregrino = m.get_node("Peregrino")
	_arco = m.get_node("Arco")
	var n: int = _arco.tramos
	_lit.resize(n)
	_lit.fill(false)
	_obs_banda40.resize(n)
	_obs_banda40.fill(-1.0)
	_obs_pisando.resize(n)
	_obs_pisando.fill(-1.0)
	if quiza_banda > 0.0:
		print("QUE PASARIA SI: banda del arco %.0f -> %.0f (experimento, no es jugar limpio)" % [_arco.banda, quiza_banda])
		_arco.banda = quiza_banda
	if quiza_salto > 0.0:
		print("QUE PASARIA SI: impulso_salto %.0f -> %.0f (experimento, no es jugar limpio)" % [_peregrino.impulso_salto, quiza_salto])
		_peregrino.impulso_salto = quiza_salto
	_arco.tramo_encendido.connect(_al_encender)
	_arco.cerrado.connect(_al_cerrar)
	_arco.recordado_tocado.connect(func():
		_repisas += 1
		print("REPISA (suelo que ya estaba) pisada t=%.2f pies=%s" % [_t, _peregrino.global_position.round()]))
	var estelas := m.get_node_or_null("Estelas")
	if estelas:
		estelas.losa_creada.connect(func(_l): _losas += 1)
	var izquierdo: bool = empezar_por == "izquierdo" or (empezar_por == "cercano" and _peregrino.global_position.x < _arco.centro.x)
	for i in n:
		_orden.append(n - 1 - i if izquierdo else i)
	print("BOT modo=%s semilla=%d arranca por el %s; peregrino en %s; arco centro=%s radio=%.0f banda=%.0f" % [
		modo, semilla, "izquierdo" if izquierdo else "derecho", _peregrino.global_position, _arco.centro, _arco.radio, _arco.banda])

func _al_encender(i: int, n: int) -> void:
	_lit[i] = true
	print("TRAMO %2d encendido t=%.2f (%d/%d) pies=%s  [saltos=%d pasos_aire=%d bajadas=%d losas=%d]" % [
		i, _t, n, _lit.size(), _peregrino.global_position.round(), _saltos, _pasos_aire, _bajadas, _losas])
	_t_ultimo_tramo = _t

func _al_cerrar() -> void:
	_t_cerrado = _t
	print("CERRADO t=%.2f  [modo=%s saltos=%d pasos_aire=%d bajadas=%d losas=%d repisas=%d]" % [
		_t, modo, _saltos, _pasos_aire, _bajadas, _losas, _repisas])
	print("  al cerrar, con banda +-40 habria %d/%d; pisando habria %d/%d" % [
		_contar(_obs_banda40), _lit.size(), _contar(_obs_pisando), _lit.size()])

func _contar(obs: Array) -> int:
	var n := 0
	for x in obs:
		if x >= 0.0:
			n += 1
	return n

func _observar() -> void:
	var p: Vector2 = _peregrino.global_position
	if p.y > _arco.centro.y + 6.0:
		return
	var i: int = _arco.tramo_de(p)
	var r := p.distance_to(_arco.centro)
	if absf(r - _arco.radio) < 40.0 and _obs_banda40[i] < 0.0:
		_obs_banda40[i] = _t
	if _arco.en_banda(p) and _peregrino.is_on_floor() and _obs_pisando[i] < 0.0:
		_obs_pisando[i] = _t

# --- Teclas ----------------------------------------------------------------------

func _accion(accion: String, pulsar: bool) -> void:
	if _pulsadas.get(accion, false) == pulsar:
		return
	_pulsadas[accion] = pulsar
	var ev := InputEventAction.new()
	ev.action = accion
	ev.pressed = pulsar
	Input.parse_input_event(ev)

func _tecla_abajo(pulsar: bool) -> void:
	if _abajo_pulsada == pulsar:
		return
	_abajo_pulsada = pulsar
	var ev := InputEventKey.new()
	ev.keycode = KEY_DOWN
	ev.pressed = pulsar
	Input.parse_input_event(ev)

## Una pulsacion nueva de saltar: si ya estaba pulsado, se suelta en este tick y
## se vuelve a pulsar en el siguiente, como un dedo.
func _pulsar_salto() -> void:
	if _pulsadas.get("saltar", false):
		_accion("saltar", false)
		_salto_pendiente = true
	else:
		_accion("saltar", true)

func _andar(dir: float) -> void:
	_accion("mover_derecha", dir > 0.0)
	_accion("mover_izquierda", dir < 0.0)

# --- Decision ----------------------------------------------------------------------

func _siguiente() -> int:
	for i in _orden:
		if not _lit[i]:
			return i
	return -1

func _physics_process(delta: float) -> void:
	_t += delta
	var ahora := [_peregrino.global_position, _peregrino.velocity, _peregrino.is_on_floor()]
	_historia.append(ahora)
	var retraso := int(round(reaccion * 60.0)) if modo == "torpe" else 0
	while _historia.size() > retraso + 1:
		_historia.pop_front()
	var visto: Array = _historia[0]
	if _t_cerrado < 0.0:
		_observar()

	if not _resumido and _t >= resumen_a_los:
		_resumido = true
		print("RESUMEN t=%.2f encendidos=%d/%d cerrado=%s  [modo=%s saltos=%d pasos_aire=%d bajadas=%d losas=%d repisas=%d] apagados=%s" % [
			_t, _arco.encendidos(), _lit.size(), _t_cerrado >= 0.0, modo, _saltos, _pasos_aire, _bajadas, _losas, _repisas, _apagados()])
		if _t_cerrado < 0.0:
			print("  observadores: banda +-40 %d/%d, pisando %d/%d" % [_contar(_obs_banda40), _lit.size(), _contar(_obs_pisando), _lit.size()])
	if _salto_pendiente:
		_salto_pendiente = false
		_accion("saltar", true)
		return
	if _abajo_pulsada:
		_tecla_abajo(false)
	if _t_cerrado >= 0.0:
		_despues_del_cierre()
		return

	match modo:
		"solo_andar":
			var x: float = _peregrino.global_position.x
			if x > 2600.0:
				_andar_dir = -1.0
			elif x < 300.0:
				_andar_dir = 1.0
			_andar(_andar_dir)
			return
		"explorador":
			if _t - _t_objetivo > _azar.randf_range(2.5, 5.0) or visto[0].distance_to(_objetivo) < 60.0:
				_t_objetivo = _t
				_objetivo = Vector2(_azar.randf_range(250.0, 2650.0), _azar.randf_range(450.0, 1150.0))
			_ir_a(_objetivo, visto, true)
		_:
			var i := _siguiente()
			if i < 0:
				return
			if modo == "torpe":
				# Duda de vez en cuando: se para un momento a mirar.
				if _duda_hasta < 0.0 and _azar.randf() < 0.004:
					_duda_hasta = _t + _azar.randf_range(0.4, 1.2)
				if _duda_hasta > 0.0:
					if _t < _duda_hasta:
						_andar(0.0)
						_accion("saltar", false)
						return
					_duda_hasta = -1.0
			# El torpe apunta con error; si en 3 s no ha encendido nada, reajusta la
			# punteria (si no, podria quedarse quieto donde cree que es).
			if i != _objetivo_tramo or (modo == "torpe" and _t - _t_objetivo > 3.0):
				_objetivo_tramo = i
				_t_objetivo = _t
				var paso: float = 180.0 / _lit.size()
				_objetivo = _arco.punto_en((i + 0.5) * paso)
				if modo == "torpe":
					_objetivo += Vector2(_azar.randf_range(-1, 1), _azar.randf_range(-1, 1)) * error_punteria
			_ir_a(_objetivo, visto, modo != "sin_aire")

	if traza and _t - _t_traza >= 0.25:
		_t_traza = _t
		var p: Vector2 = ahora[0]
		var v: Vector2 = ahora[1]
		print("traza t=%.2f pies=(%.0f,%.0f) v=(%.0f,%.0f) suelo=%s obj=%d (%.0f,%.0f) teclas=%s" % [
			_t, p.x, p.y, v.x, v.y, ahora[2], _objetivo_tramo, _objetivo.x, _objetivo.y, _teclas_texto()])

	if _t - _t_ultimo_tramo > 20.0:
		_t_ultimo_tramo = _t
		print("SIN AVANCE 20 s t=%.2f encendidos=%d apagados=%s pies=%s" % [_t, _arco.encendidos(), _apagados(), _peregrino.global_position.round()])

## Llevar los pies a un punto: andar, saltar, mantener, pisar el aire o bajar.
func _ir_a(objetivo: Vector2, visto: Array, pisar_aire: bool) -> void:
	var p: Vector2 = visto[0]
	var v: Vector2 = visto[1]
	var suelo: bool = visto[2]
	var d := objetivo - p
	var torpe := modo == "torpe"

	var dir := 0.0
	if absf(d.x) > TOL_X:
		dir = signf(d.x)
	_andar(dir)

	if suelo:
		if d.y < -TOL_SUBIR:
			# Una persona pulsa una vez y mira que pasa: no vuelve a pulsar hasta
			# haber visto el resultado (con el torpe, su retraso de reaccion).
			var calma := 0.15 + (reaccion if torpe else 0.0)
			if not _pulsadas.get("saltar", false):
				if _t - _t_salto > calma:
					_pulsar_salto()
					_t_salto = _t
					_saltos += 1
			elif _t - _t_salto > calma:
				# Aterrizo con el salto pulsado: hay que soltar para volver a saltar.
				_accion("saltar", false)
		else:
			_accion("saltar", false)
			if d.y > TOL_BAJAR and _sobre_losa():
				_tecla_abajo(true)
				_bajadas += 1
	else:
		if d.y < -20.0:
			var umbral_v := 60.0 if torpe else -60.0
			var espera := 0.7 if torpe else ESPERA_AIRE
			if pisar_aire and v.y > umbral_v and _t - _t_paso_aire > espera and _t - _t_salto > espera and p.y > TECHO_AIRE:
				_pulsar_salto()
				_t_paso_aire = _t
				_pasos_aire += 1
			elif torpe and _t - _t_salto > 0.12 and _t - _t_paso_aire > 0.12:
				# No sabe que manteniendo flota: suelta enseguida.
				_accion("saltar", false)
		else:
			_accion("saltar", false)

func _sobre_losa() -> bool:
	var s = _peregrino.suelo_actual()
	return s != null and s is CollisionObject2D and (s.collision_layer & 2) != 0

func _apagados() -> Array:
	var a := []
	for i in _lit.size():
		if not _lit[i]:
			a.append(i)
	return a

## Cerrado: suelta todo, espera a que caiga al agua y anda por el camino hasta el
## final del cuadro.
func _despues_del_cierre() -> void:
	_accion("saltar", false)
	if not ir_al_final or _t - _t_cerrado < 5.0:
		_andar(0.0)
		return
	_andar(1.0)
	if not _fin_dicho and _peregrino.global_position.x > 2842.0:
		_fin_dicho = true
		print("FIN t=%.2f (llega al borde del camino)" % _t)

func _teclas_texto() -> String:
	var s := ""
	for k in _pulsadas:
		if _pulsadas[k]:
			s += k.substr(0, 7) + " "
	if _abajo_pulsada:
		s += "abajo"
	return s
