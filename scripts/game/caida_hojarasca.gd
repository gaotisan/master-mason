extends Node2D
## La caida en la hojarasca, por separado. El cuento empieza con el anciano
## poniendose en pie y sacudiendose "la hojarasca que se habia quedado adherida
## a sus ropas" en un atardecer de otono: aqui Magnus cae del cielo sobre un
## monton de hojas bajo un haz de luz calida, las levanta con el golpe, se queda
## tumbado mientras vuelven a caer, y al levantarse se le van desprendiendo.
## Luego vadea la hojarasca: las piernas abren camino y cada pie levanta hojas.
## De arriba, de arboles que no se ven, caen hojas sueltas. El mundo da la
## vuelta: lo que sale por un lado entra por el otro.
##
## La hojarasca a la altura de Magnus son hojas de verdad (hojas_voladoras.gd),
## en dos capas apiladas por columnas: una algo detras de el y otra algo delante
## (le tapa los pies). Todo lo que levanta son esas hojas, que vuelven a caer
## encima de donde caigan: el camino que abre se queda abierto, delante se
## amontonan, y cada pasada deja el lecho distinto. Lo unico pintado es el suelo
## lejano y el cercano (lecho.png), que el no pisa.
##
## Arte: tools/mundo/hojarasca.py (hojas con la forma y la luz de la imagen de
## titulo de Midjourney). Es la escena que sigue a la pantalla de titulo
## (next_scene de title_screen_controller.gd); dark_stage queda para pruebas.
##
## Entrada: el titulo acaba en negro, asi que aqui se abre desde negro (el haz y
## el lecho aparecen primero) y Magnus cae ya con luz. El viento es el mismo
## autoload que viene sonando desde el titulo (sin corte): sube suave desde el
## nivel en que lo dejo hasta el de fondo de la escena, a la vez que la luz. El
## fichero de viento es muy bajo (-48 dB de media), por eso viento_db es positivo.
## Rachas de vez en cuando: suben el viento unos dB, caen mas hojas de arriba y
## las que vuelan se desvian con ellas.

## Del negro a la escena (s) y cuando empieza a caer Magnus (s desde el inicio).
@export var entrada: float = 3.0
@export var espera_caida: float = 1.8
## Viento de fondo (dB sobre el fichero) y cuanto tarda en llegar desde el nivel
## en que lo deja el titulo (-14).
@export var viento_db: float = 9.0
@export var viento_subida: float = 6.0
## Rachas: cada cuanto (s), cuanto suben (dB) y cuanto empujan las hojas (px/s^2).
@export var racha_cada_min: float = 7.0
@export var racha_cada_max: float = 16.0
@export var racha_db: float = 4.5
@export var racha_empuje: float = 90.0
## Las dos capas de hojas: cuantas por columna de media (mas el monton de donde
## cae, en px de altura).
@export var hojas_por_columna_delante: float = 7.0
@export var hojas_por_columna_detras: float = 5.0
## El golpe de la caida: cuantas hojas levanta como mucho y con que fuerza (px/s).
@export var golpe_hojas: int = 220
@export var golpe_vel_min: float = 300.0
@export var golpe_vel_max: float = 880.0
## Donde queda el cuerpo tumbado respecto al nodo de Magnus (px en x): de ahi
## salen las hojas del golpe. Medido en la grabacion de la caida.
@export var cuerpo_desde: float = -170.0
@export var cuerpo_hasta: float = 160.0
## Hojas que se le desprenden al levantarse (las "adheridas a sus ropas").
@export var hojas_pegadas: int = 26
## Hojas que caen de arriba (de arboles fuera de pantalla): una cada tanto (s).
@export var arbol_cada_min: float = 1.4
@export var arbol_cada_max: float = 4.0
## Escala de todo lo que levantan los pies (1 = lo de CONTACTOS).
@export var pateo: float = 1.0
## Velocidad de andar de Magnus, para escalar con lo que corre de verdad.
@export var velocidad_referencia: float = 160.0
## Vadear: las piernas cogen las hojas de arriba de las columnas que tienen
## delante (hasta vadeo_alcance px, mas corriendo) y no dejan menos de
## vadeo_queda en cada una: ese es el fondo del camino que abren. vadeo_prob es
## la probabilidad por hoja y fotograma (cuanto tarda en vaciarse la columna).
@export var vadeo_alcance: float = 24.0
@export var vadeo_queda: int = 3
@export var vadeo_prob: float = 0.45
## A donde va lo que apartan las piernas: hacia delante (la ola), por encima del
## pie hacia atras (cae al camino) o a la otra capa (de lado, en profundidad).
@export var vadeo_adelante: float = 0.45
@export var vadeo_atras: float = 0.25
@export var temblor_px: float = 7.0
## Sonidos de las hojas, sacados del audio de un video del peregrino andando por
## hojas (raw/master_mason/audio/hojarasca/construye.py). Las pisadas: una al
## azar de doce, con algo de tono y volumen distintos (AudioStreamRandomizer).
## El arrastre es un bucle que sube con la velocidad (el roce al vadear) y
## calla parado o en el aire. Los pasos propios de Magnus (de suelo duro) se
## bajan aqui para que mande el crujido.
@export var hojas_golpe_db: float = -4.0
@export var hojas_levantarse_db: float = -6.0
@export var hojas_paso_db: float = -9.0
@export var arrastre_db: float = -10.0
@export var magnus_pasos_db: float = -14.0

## Que levanta cada contacto del pie. Los contactos salen de la senal pisada de
## Magnus, en el sprite en que el pie planta (los mismos de sus sonidos):
##   n       hojas (min, max) a velocidad_referencia
##   vel     rango de velocidad de salida (px/s)
##   pie     donde esta el pie respecto al centro, hacia donde mira (px)
##   delante fraccion que sale hacia donde va (el resto, hacia atras)
##   alto    0..1: cuanto se abren hacia arriba (0 rasantes, 1 casi verticales)
## Un pie que entra en la hojarasca empuja casi todo hacia delante y bajo; el
## que despega la tira hacia atras y algo mas alta; al caer de un salto salpica
## a los dos lados.
const CONTACTOS := {
	"paso_suave": {"n": Vector2i(1, 2), "vel": Vector2(60, 220), "pie": 30.0, "delante": 0.7, "alto": 0.35},
	"paso":       {"n": Vector2i(3, 5), "vel": Vector2(110, 420), "pie": 38.0, "delante": 0.7, "alto": 0.45},
	"zancada":    {"n": Vector2i(6, 9), "vel": Vector2(200, 640), "pie": 46.0, "delante": 0.6, "alto": 0.5},
	"frenada":    {"n": Vector2i(9, 13), "vel": Vector2(160, 560), "pie": 60.0, "delante": 0.95, "alto": 0.25},
	"despegue":   {"n": Vector2i(6, 10), "vel": Vector2(160, 520), "pie": 10.0, "delante": 0.2, "alto": 0.55},
	"caida":      {"n": Vector2i(14, 20), "vel": Vector2(180, 720), "pie": 0.0, "delante": 0.5, "alto": 0.6},
}
## animacion -> sprite -> contacto. Lo que no esta aqui (las pisadas de PISADAS)
## sale de PISADA_ANIM.
const SALTOS := {
	"saltar":       {13: "despegue", 48: "caida"},
	"salto_correr": {4: "despegue", 33: "caida"},
	"salto_parado": {18: "despegue", 47: "caida"},
}
const PISADA_ANIM := {
	"andar": "paso", "parada_andar": "paso", "aterrizaje_correr": "zancada",
	"correr": "zancada", "arranque_correr": "zancada", "parada_correr": "frenada",
	"andar_agachado": "paso_suave", "arranque_agachado": "paso_suave",
	"parada_agachado": "paso_suave", "paso_agachado": "paso_suave",
}
## Fuerza de la caida de cada salto (el corriendo cae mas lejos y mas fuerte).
const FUERZA_SALTO := {"salto_parado": 0.8, "saltar": 1.0, "salto_correr": 1.3}
## Ancho del mundo: lo que sale por un lado entra por el otro.
const ANCHO := 2912.0

@onready var _magnus: Node2D = $Magnus
@onready var _sprite: AnimatedSprite2D = $Magnus/Sprite
@onready var _detras: Node2D = $HojasDetras
@onready var _delante: Node2D = $HojasDelante
@onready var _polvo: CPUParticles2D = $Polvo
@onready var _polvo_paso: CPUParticles2D = $PolvoPaso
@onready var _sombra: Sprite2D = $Sombra
@onready var _camara: Camera2D = $Camera

var _arbol_espera := 1.0
var _ultima_x := 0.0
var _velocidad := 0.0                  # px/s de Magnus en x, suavizada
var _temblor := 0.0
var _roce := 0.0                       # volumen lineal del arrastre
var _racha := 0.0                      # 0..1, la racha de viento que sopla ahora
var _racha_espera := 5.0
var _racha_dir := 1.0
var _fantasma: AnimatedSprite2D        # Magnus al otro lado mientras cruza un borde

func _ready() -> void:
	_a_baja_resolucion($Fondo, 4)
	_a_baja_resolucion($NieblaSuelo, 4)
	WindAmbience.gust_db = 0.0
	WindAmbience.fade_to(viento_db, viento_subida)
	_magnus.position = $MagnusSpawn.position
	_ultima_x = _magnus.position.x
	_magnus.impacto.connect(_al_impacto)
	_magnus.pisada.connect(_al_pisar)
	_sprite.animation_changed.connect(_al_cambiar_animacion)
	# La luz de la escena sobre Magnus (sin tocar sus hojas ni su escena).
	var luz := ShaderMaterial.new()
	luz.shader = preload("res://scripts/game/magnus_luz.gdshader")
	_sprite.material = luz
	_crear_fantasma()
	_magnus.pasos_db = magnus_pasos_db
	_delante.sembrar(hojas_por_columna_delante, _monton.bind(0.6))
	_detras.sembrar(hojas_por_columna_detras, _monton.bind(0.4))
	_entrar_desde_negro()
	# Que ya haya alguna hoja cayendo al abrir.
	for i in 3:
		_hoja_de_arriba(randf_range(200.0, 900.0))

## Altura extra (px) del monton donde cae y de dos lomas mas bajas.
func _monton(x: float, cuanto: float) -> float:
	return cuanto * (30.0 * exp(-pow((x - 1456.0) / 260.0, 2.0))
		+ 8.0 * exp(-pow((x - 1976.0) / 200.0, 2.0)) + 6.0 * exp(-pow((x - 756.0) / 240.0, 2.0)))

## Del negro del titulo a la escena: primero la luz, luego cae Magnus. Hasta
## entonces no esta (ni se le puede mover).
func _entrar_desde_negro() -> void:
	var negro: ColorRect = $Entrada/Negro
	negro.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(negro, "color:a", 0.0, entrada).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback($Entrada.hide)
	_magnus.visible = false
	_sombra.visible = false
	_magnus.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().create_timer(espera_caida).timeout.connect(func() -> void:
		_magnus.process_mode = Node.PROCESS_MODE_INHERIT
		_magnus.visible = true
		_sombra.visible = true
		_magnus.caer_desde_arriba())

## Rachas de viento: suben y bajan en unos segundos, de vez en cuando. Mueven el
## volumen del viento (gust_db, por encima del nivel base) y empujan las hojas.
func _soplar(delta: float) -> void:
	_racha_espera -= delta
	if _racha_espera <= 0.0:
		_racha_espera = randf_range(racha_cada_min, racha_cada_max)
		_racha_dir = 1.0 if randf() < 0.6 else -1.0
		var fuerza := randf_range(0.5, 1.0)
		var tw := create_tween()
		tw.tween_property(self, "_racha", fuerza, randf_range(1.2, 2.0)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(self, "_racha", 0.0, randf_range(2.5, 4.0)).set_trans(Tween.TRANS_SINE)
	WindAmbience.gust_db = racha_db * _racha
	var empuje := _racha_dir * racha_empuje * _racha
	_delante.viento = empuje
	_detras.viento = empuje

func _process(delta: float) -> void:
	_soplar(delta)
	# Con racha caen mas hojas de arriba.
	_arbol_espera -= delta * (1.0 + 3.0 * _racha)
	if _arbol_espera <= 0.0:
		_arbol_espera = randf_range(arbol_cada_min, arbol_cada_max)
		_hoja_de_arriba()
	_envolver()
	_seguir_a_magnus(delta)
	if _temblor > 0.0:
		_temblor = maxf(_temblor - delta, 0.0)
		var f := temblor_px * (_temblor / 0.35) ** 2
		_camara.offset = Vector2(randf_range(-f, f) * 0.5, randf_range(-f, f))
	else:
		_camara.offset = Vector2.ZERO

## Una hoja nueva en el aire, en la capa de delante o en la de detras.
func _soltar(pos: Vector2, vel: Vector2, delante: bool, escala: float = -1.0, giro: float = INF) -> void:
	(_delante if delante else _detras).soltar(pos, vel, escala, giro)

## Velocidad, vadeo, sombra de contacto y el lado de la luz para el borde
## encendido de Magnus.
func _seguir_a_magnus(delta: float) -> void:
	if delta <= 0.0:
		return
	var x := _magnus.position.x
	var dx := wrapf(x - _ultima_x, -ANCHO / 2.0, ANCHO / 2.0)
	_ultima_x = x
	_velocidad = lerpf(_velocidad, absf(dx) / delta, 1.0 - exp(-10.0 * delta))
	var en_suelo := _sprite.position.y > -2.0
	if en_suelo and absf(dx) > 0.2 and _velocidad > 25.0:
		_vadear(x, signf(dx))
	# El roce sigue a la velocidad, en volumen lineal y sin saltos, para que
	# arranque y pare como un roce de verdad; parado o en el aire calla.
	var objetivo: float = clampf(_velocidad / velocidad_referencia, 0.0, 1.6) * 0.75 if en_suelo else 0.0
	_roce = move_toward(_roce, objetivo, delta * 2.5)
	$SonidoArrastre.volume_db = arrastre_db + linear_to_db(maxf(_roce, 0.0001))
	# Sombra de contacto: se encoge y aclara al subir en un salto; tumbado es
	# larga (todo el cuerpo).
	var alto := maxf(-_sprite.position.y, 0.0)
	var tumbado := _sprite.animation in [&"caida", &"tumbado"]
	var ancho := 5.6 if tumbado else 3.4
	if _sprite.animation == &"levantarse":
		ancho = lerpf(5.6, 3.4, float(_sprite.frame) / maxf(_sprite.sprite_frames.get_frame_count(&"levantarse") - 1, 1))
	var sube := clampf(alto / 260.0, 0.0, 1.0)
	_sombra.position = Vector2(x + (cuerpo_desde + cuerpo_hasta) * 0.5 * (1.0 if tumbado else 0.0), 1196.0)
	_sombra.scale = Vector2(ancho * (1.0 - 0.35 * sube), 0.75 * (1.0 - 0.35 * sube))
	_sombra.modulate.a = 0.62 * (1.0 - 0.7 * sube) * (0.0 if _magnus.position.y < 1150.0 else 1.0)
	# Borde de luz del lado del haz: en UV del sprite, que se voltea con flip_h.
	var hacia := clampf((1456.0 - x) / 500.0, -1.0, 1.0)
	(_sprite.material as ShaderMaterial).set_shader_parameter(&"lado_luz", hacia * (-1.0 if _sprite.flip_h else 1.0))

## Las piernas abren camino: cogen las hojas de arriba de las columnas que
## tienen delante y las apartan. Unas van hacia delante (se amontonan: la ola),
## otras pasan por encima del pie y caen atras, en el camino, y otras se van a
## la otra capa (de lado, en profundidad). Casi todas rasantes: se arrastran o
## dan un saltito; pocas vuelan. Es continuo, no por pisada.
func _vadear(x: float, dir: float) -> void:
	var rapido := clampf(_velocidad / velocidad_referencia, 0.3, 2.7)
	var hasta := x + dir * vadeo_alcance * (1.0 + 0.4 * rapido)
	var sq := sqrt(rapido)
	for capa in [_delante, _detras]:
		var otra: Node2D = _detras if capa == _delante else _delante
		var prob := vadeo_prob * (1.0 if capa == _delante else 0.8)
		for h in capa.tomar(x - dir * 8.0, hasta, 40, vadeo_queda, prob):
			var r := randf()
			if r < vadeo_adelante:
				capa.lanzar(h, Vector2(dir * randf_range(70.0, 260.0) * sq, -randf_range(10.0, 160.0) * sq))
			elif r < vadeo_adelante + vadeo_atras:
				capa.lanzar(h, Vector2(-dir * randf_range(0.0, 110.0), -randf_range(140.0, 380.0) * sq))
			else:
				otra.lanzar(h, Vector2(dir * randf_range(20.0, 160.0) * sq, -randf_range(60.0, 220.0) * sq))

## Cada contacto del pie con el suelo levanta lo que diga CONTACTOS: las hojas de
## arriba junto al pie, de las dos capas, mas unas migas.
func _al_pisar(anim: StringName, sprite: int) -> void:
	var tipo := ""
	var fuerza := 1.0
	if SALTOS.has(String(anim)):
		tipo = SALTOS[String(anim)].get(sprite, "")
		if tipo == "caida":
			fuerza = FUERZA_SALTO.get(String(anim), 1.0)
	else:
		tipo = PISADA_ANIM.get(String(anim), "paso")
		# A mas velocidad, mas hojas y mas lejos (corriendo, ~2,5x).
		fuerza = clampf(_velocidad / velocidad_referencia, 0.6, 2.2) ** 0.6
	if tipo == "":
		return
	var c: Dictionary = CONTACTOS[tipo]
	var dir: float = _magnus.mirando()
	var n := int(round(randi_range(c["n"].x, c["n"].y) * fuerza * pateo))
	var vel_max: float = c["vel"].y * sqrt(fuerza)
	var lados := [1.0, -1.0] if tipo == "caida" else [1.0]
	for lado in lados:
		var pie: float = _magnus.position.x + dir * lado * c["pie"] + (lado * 45.0 if tipo == "caida" else 0.0)
		var cuantas: int = n / lados.size()
		var radio := 30.0 if tipo != "caida" else 45.0
		var hojas: Array[Dictionary] = _delante.tomar(pie - radio, pie + radio, cuantas * 2 / 3 + 1, 1)
		for h in hojas:
			_delante.lanzar(h, _velocidad_patada(dir, c["vel"].x, vel_max, c["delante"], c["alto"]))
		for h in _detras.tomar(pie - radio, pie + radio, cuantas - hojas.size(), 1):
			_detras.lanzar(h, _velocidad_patada(dir, c["vel"].x, vel_max, c["delante"], c["alto"]))
		# Migas: trozos pequenos que salen mas rapidos y se pierden al caer.
		for i in int(n * 0.6):
			_soltar(Vector2(pie + randf_range(-15.0, 15.0), _delante.tope(pie) - randf() * 6.0),
					_velocidad_patada(dir, c["vel"].x, vel_max, c["delante"], c["alto"]) * 1.2,
					randf() < 0.6, randf_range(0.09, 0.14), randf_range(-20.0, 20.0))
	if tipo in ["caida", "frenada", "zancada"]:
		_polvo_paso.position = Vector2(_magnus.position.x + dir * c["pie"], 1192.0)
		_polvo_paso.amount = 18 if tipo == "caida" else 8
		_polvo_paso.restart()
	if randf() < (1.0 if tipo != "paso_suave" else 0.5):
		_sonar($SonidoPaso, hojas_paso_db + (6.0 if tipo == "caida" else 0.0) + (3.0 if tipo in ["zancada", "frenada"] else 0.0),
			   randf_range(0.94, 1.06) * (0.9 if tipo == "caida" else 1.0))

## Salida de una hoja pateada. La mayoria salen rasantes y despacio (se
## arrastran o dan un saltito) y pocas suben de verdad: con un reparto plano
## todas hacian el mismo arco y se veia falso.
func _velocidad_patada(dir: float, v_min: float, v_max: float, delante: float, alto: float) -> Vector2:
	var lado := dir if randf() < delante else -dir
	var rapidez := lerpf(v_min, v_max, pow(randf(), 1.8))
	var ang := lerpf(0.08, 1.35, pow(randf(), 1.0 / maxf(alto, 0.05) * 0.6))
	return Vector2(lado * cos(ang), -sin(ang)) * rapidez

## El golpe: el cuerpo entra en el monton y lo que habia debajo sale en abanico,
## mas alto en el centro y mas abierto en los extremos; queda el hueco. Polvo,
## migas y un temblor de camara.
func _al_impacto() -> void:
	var x0 := _magnus.position.x
	var a := x0 + cuerpo_desde - 20.0
	var b := x0 + cuerpo_hasta + 20.0
	var hojas: Array[Dictionary] = _delante.tomar(a, b, golpe_hojas * 2 / 3, 2, 0.8)
	var de_detras: Array[Dictionary] = _detras.tomar(a, b, golpe_hojas / 3, 1, 0.8)
	for k in 2:
		var capa: Node2D = _delante if k == 0 else _detras
		for h in (hojas if k == 0 else de_detras):
			var t := clampf((h["p"].x - a) / (b - a), 0.0, 1.0)
			var fuera := (t - 0.5) * 2.0
			var ang := -PI / 2.0 + fuera * 0.9 + randf_range(-0.45, 0.45)
			var centro := 1.0 - absf(fuera) * 0.45
			capa.lanzar(h, Vector2.from_angle(ang) * lerpf(golpe_vel_min, golpe_vel_max, pow(randf(), 1.4)) * centro,
						randf_range(-1.0, 1.0) * 16.0)
	for i in golpe_hojas / 3:
		var x := x0 + randf_range(cuerpo_desde, cuerpo_hasta)
		_soltar(Vector2(x, 1192.0 - randf() * 12.0),
				Vector2.from_angle(-PI / 2.0 + randf_range(-1.2, 1.2)) * randf_range(200.0, 900.0),
				randf() < 0.6, randf_range(0.09, 0.14), randf_range(-20.0, 20.0))
	_polvo.position = Vector2(x0 + (cuerpo_desde + cuerpo_hasta) / 2.0, 1190.0)
	_polvo.restart()
	_temblor = 0.35
	_sonar($SonidoGolpe, hojas_golpe_db)

## Al empezar a levantarse se le van cayendo las hojas que se le quedaron
## encima: primero las del cuerpo aun tumbado, luego mas arriba segun se
## incorpora (63 sprites a 20 fps, 3,15 s).
func _al_cambiar_animacion() -> void:
	if _sprite.animation != &"levantarse":
		return
	_sonar($SonidoLevantarse, hojas_levantarse_db)
	var dur := _sprite.sprite_frames.get_frame_count(&"levantarse") / _sprite.sprite_frames.get_animation_speed(&"levantarse")
	for i in hojas_pegadas:
		var p := pow(randf(), 1.2)
		get_tree().create_timer(p * dur * 0.95).timeout.connect(func() -> void:
			var x := _magnus.position.x + randf_range(-120.0, 120.0) * (1.0 - p * 0.65)
			var y := 1188.0 - (30.0 + 230.0 * p) * randf_range(0.35, 1.0)
			_soltar(Vector2(x, y), Vector2(randf_range(-70.0, 70.0), randf_range(-60.0, 10.0)),
					randf() < 0.6, randf_range(0.3, 0.38)))
	# El sacudon del final: unas pocas mas, de golpe, a la altura del pecho.
	get_tree().create_timer(dur * 0.92).timeout.connect(func() -> void:
		for i in 6:
			_soltar(_magnus.position + Vector2(randf_range(-40.0, 40.0), -randf_range(120.0, 230.0)),
					Vector2(randf_range(-160.0, 160.0), randf_range(-140.0, 0.0)), randf() < 0.6))

## Hoja suelta que entra por arriba, de arboles que no se ven, con brisa floja.
func _hoja_de_arriba(y_ya: float = -1.0) -> void:
	var x := randf_range(150.0, 2760.0)
	var y := -40.0 if y_ya < 0.0 else y_ya
	_soltar(Vector2(x, y), Vector2(randf_range(-35.0, 35.0) + _racha_dir * 60.0 * _racha, 40.0), randf() < 0.6)

func _sonar(s: AudioStreamPlayer, db: float, tono: float = 1.0) -> void:
	if s.stream == null:
		return
	s.volume_db = db
	s.pitch_scale = tono
	s.play()

## Pinta un ColorRect con shader en una SubViewport a 1/factor de su tamano y lo
## pone en su sitio estirado. Para el fondo y la bruma, que son degradados
## blandos: a resolucion completa (2912x1632) se comian la GPU del portatil. Los
## shaders trabajan en UV, asi que dan lo mismo a cualquier tamano.
func _a_baja_resolucion(rect: ColorRect, factor: int) -> void:
	var sitio := rect.position
	var tam := rect.size
	var orden := rect.get_index()
	var vista := SubViewport.new()
	vista.size = Vector2i(tam / factor)
	vista.transparent_bg = true
	vista.disable_3d = true
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	remove_child(rect)
	rect.position = Vector2.ZERO
	rect.size = Vector2(vista.size)
	vista.add_child(rect)
	add_child(vista)
	var imagen := Sprite2D.new()
	imagen.name = String(rect.name) + "Imagen"
	imagen.centered = false
	imagen.position = sitio
	imagen.scale = tam / Vector2(vista.size)
	imagen.texture = vista.get_texture()
	imagen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Lo que sale de la vista lleva el alfa ya multiplicado (la bruma).
	var mezcla := CanvasItemMaterial.new()
	mezcla.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	imagen.material = mezcla
	add_child(imagen)
	move_child(imagen, orden)

# --- El mundo da la vuelta ---------------------------------------------------

## Copia del sprite de Magnus que se dibuja al otro lado de la pantalla mientras
## cruza un borde: asi sale por un lado y entra por el otro a la vez, sin salto.
func _crear_fantasma() -> void:
	_fantasma = AnimatedSprite2D.new()
	_fantasma.name = "MagnusAlOtroLado"
	_fantasma.sprite_frames = _sprite.sprite_frames
	_fantasma.offset = _sprite.offset
	_fantasma.material = _sprite.material
	_fantasma.visible = false
	add_child(_fantasma)
	move_child(_fantasma, _magnus.get_index() + 1)

## Si Magnus pasa de un borde, aparece por el otro (el centro del nodo manda), y
## la copia pinta la parte que aun asoma por el lado contrario.
func _envolver() -> void:
	var x := _magnus.position.x
	if x < 0.0 or x >= ANCHO:
		_magnus.position.x = fposmod(x, ANCHO)
	x = _magnus.position.x
	var lado := ANCHO if x < 260.0 else (-ANCHO if x > ANCHO - 260.0 else 0.0)
	_fantasma.visible = lado != 0.0
	if not _fantasma.visible:
		return
	if _fantasma.animation != _sprite.animation:
		_fantasma.animation = _sprite.animation
	_fantasma.frame = _sprite.frame
	_fantasma.flip_h = _sprite.flip_h
	_fantasma.global_position = _sprite.global_position + Vector2(lado, 0.0)
