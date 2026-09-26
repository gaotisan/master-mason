class_name CasaInteriorDecorado
extends Node2D
## Decorado de la sala de Dominus: "una sala pequena y abarrotada", con el
## organo de una iglesia, el potro de tortura, el alambique que silba, la
## caldera sobre el brasero, el hacha junto a la chimenea, puertas y trampillas
## por todas partes y el pendulo enorme rematado en un incensario "que no
## parecia empujado por mecanismo alguno".
##
## Es SOLO el decorado: aqui no hay logica de juego. El nivel mete a Magnus,
## a Dominus y la mesa dentro de Personajes (que queda entre el fondo y el
## primer plano) y usa las marcas para colocarlos y para los puntos que se
## pueden examinar.
##
## Todo lo quieto va horneado en sala_fondo.png, pintado por codigo en
## tools/mundo/casa_interior.py. Aqui solo vive lo que se mueve, y barato: un
## unico _process para el pendulo y las llamas, particulas con pocas unidades y
## halos aditivos en vez de luces 2D.
##
## Coordenadas de pantalla (2912x1632), las mismas que el fondo: pixel de la
## imagen = posicion local. Pies de los personajes en y = 1200. La pared toca
## el suelo algo mas arriba (1150), para que lo que se apoya en ella quede
## DETRAS de los pies y no a su altura.
##
## La sala esta mal a proposito, pero poco: la puerta alta sin escalera, la
## escalera que acaba en el aire, la puerta pintada con otra perspectiva, la
## puertecita de raton con luz por debajo, el reloj sin agujas junto a un
## pendulo que no mueve nada. Todo es la imaginacion de Dominus.

## La puerta ha terminado de abrirse. abrir_puerta() tambien se puede esperar
## directamente: await decorado.abrir_puerta()
signal puerta_abierta
signal puerta_cerrada

## Apertura de la puerta al empezar: 0 cerrada, 1 abierta del todo. Por defecto
## entornada, como en el relato ("la puerta estaba entornada"): deja ver una
## rendija de noche azul.
@export_range(0.0, 1.0) var apertura_inicial: float = 0.12
## Segundos de cerrada a abierta. Si ya esta a medias, tarda la parte que falta.
@export var duracion_puerta: float = 1.8
## Angulo de la hoja abierta del todo, en grados. Pasado ~80 la esquina de la
## hoja se sale de pantalla por la izquierda.
@export_range(10.0, 88.0) var angulo_abierta: float = 76.0

## Periodo completo del pendulo (ida y vuelta), en segundos.
@export var periodo_pendulo: float = 5.6
## Amplitud del pendulo, en grados a cada lado.
@export var amplitud_pendulo: float = 22.0
## Cuanto sigue el incensario a la vara. Cuelga de cadenas cortas: 0 seria
## siempre vertical, 1 rigido con la vara. Un poco de rigidez y un pequeno
## retraso le dan peso sin que se note el truco.
@export_range(0.0, 1.0) var rigidez_incensario: float = 0.22

## Segundos entre silbido y silbido del alambique (minimo, maximo).
@export var intervalo_silbido: Vector2 = Vector2(2.8, 5.6)

## Si esta activo, los hijos de Personajes se tintan cada poco con la luz de
## la sala (tono_luz). Apagado por defecto: lo decide el nivel.
@export var tenir_personajes: bool = false
## Cuanto tinte aplicar a los personajes (0 nada, 1 todo).
@export_range(0.0, 1.0) var fuerza_tinte: float = 0.6

## Puntos que se pueden examinar, todos a ras de suelo (y = 1200), delante de
## su objeto. Caldero y Hacha quedan pasado LimiteDer: la mesa corta el paso
## la primera vez, pero se dejan por si el nivel abre el camino.
const EXAMINABLES: PackedStringArray = ["Organo", "Potro", "Alambique", "Pendulo", "Puertas",
		"Trampilla", "Caldero", "Hacha"]
## Centro real de la trampilla en el suelo (la marca Trampilla esta en la linea
## de los pies, encima de ella). Queda medio bajo la mesa, a proposito.
const CENTRO_TRAMPILLA := Vector2(2100.0, 1296.0)

# --- Puerta -----------------------------------------------------------------
# Hueco de la entrada en el fondo: x 140..340, y 750..1150. La hoja tiene la
# bisagra a la izquierda y se abre hacia dentro, o sea hacia la camara: por
# eso al abrirse no solo estrecha, tambien crece (se acerca) y su canto baja
# siguiendo el suelo. Se proyecta columna a columna para que la textura no se
# tuerza como en un trapecio afin.
const BISAGRA_X := 140.0
const PUERTA_ARRIBA := 750.0
const PUERTA_ABAJO := 1150.0
const PUERTA_ANCHO := 200.0
const GROSOR_PUERTA := 12.0
## Punto hacia el que se escapa lo lejano. No es exactamente la fuga de las
## tablas del suelo (esa esta muy arriba, fuera de pantalla); con este la hoja
## se ve bien en todo el recorrido.
const CENTRO_PROYECCION := Vector2(1456.0, 700.0)
const DISTANCIA_CAMARA := 1400.0
const COLUMNAS_HOJA := 8
## Alfa del charco de luna del suelo con la puerta abierta del todo.
const LUNA_MAX := 0.22

# --- Luces (las mismas que pintan el fondo, ver casa_interior.py) -----------
# [x, y, color, potencia, radio]
const LUCES := [
	[2790.0, 1030.0, Color("ff9a4a"), 2.7, 400.0],
	[2548.0, 1085.0, Color("ff7a36"), 1.5, 200.0],
	[455.0, 792.0, Color("ffc27a"), 1.05, 150.0],
	[785.0, 792.0, Color("ffc27a"), 1.05, 150.0],
	[1180.0, 668.0, Color("ffbf78"), 0.95, 140.0],
	[1312.0, 1000.0, Color("ffb870"), 0.7, 90.0],
	[2676.0, 640.0, Color("ffc27a"), 0.8, 140.0],
	[2846.0, 640.0, Color("ffc27a"), 0.8, 140.0],
	[2150.0, 940.0, Color("ffb468"), 1.05, 280.0],
	[245.0, 990.0, Color("7d9fe0"), 0.45, 160.0],
]
const AMBIENTE := Color(0.0626, 0.0417, 0.0298)
const CAIDA := 1.6
const EXPOSICION := 1.45

## Apertura actual de la puerta (0..1). Se puede animar desde fuera.
var apertura: float = 0.0:
	set = _set_apertura

var _t := 0.0
var _tween_puerta: Tween
var _siguiente_silbido := 3.0
var _siguiente_tinte := 0.0
var _rng := RandomNumberGenerator.new()
var _llamas: Array[Sprite2D] = []
var _escala_llamas: Array[Vector2] = []
var _fase_llamas: PackedFloat32Array = []

@onready var _hoja: Polygon2D = $PuertaEntrada/Hoja
@onready var _canto: Polygon2D = $PuertaEntrada/Canto
@onready var _luz_luna: Sprite2D = $LuzLuna
@onready var _pendulo: Node2D = $PenduloIncensario
@onready var _incensario: Node2D = $PenduloIncensario/Incensario
@onready var _sombra_incensario: Node2D = $PenduloIncensario/Sombra/Incensario
@onready var _vapor_alambique: GPUParticles2D = $EfectosAlambique/Vapor
@onready var _personajes: Node2D = $Personajes


func _ready() -> void:
	# Generador propio: flicker_glow.gd siembra el aleatorio global con su
	# noise_seed y aqui no queremos depender de quien se inicialice antes.
	_rng.seed = 7117
	_siguiente_silbido = _rng.randf_range(1.0, intervalo_silbido.y)
	for n in $Llamas.get_children():
		var llama := n as Sprite2D
		if llama == null:
			continue
		_llamas.append(llama)
		_escala_llamas.append(llama.scale)
		_fase_llamas.append(_rng.randf() * TAU)
	apertura = apertura_inicial
	_colocar_hoja()
	_colocar_pendulo()


func _process(delta: float) -> void:
	_t += delta
	_colocar_pendulo()
	_mover_llamas()
	_siguiente_silbido -= delta
	if _siguiente_silbido <= 0.0:
		# restart() borra las bocanadas vivas, pero la anterior ya se ha ido:
		# su vida (1,4 s) es menor que el intervalo minimo.
		_vapor_alambique.restart()
		_siguiente_silbido = _rng.randf_range(intervalo_silbido.x, intervalo_silbido.y)
	if tenir_personajes:
		_siguiente_tinte -= delta
		if _siguiente_tinte <= 0.0:
			_siguiente_tinte = 0.1
			for n in _personajes.get_children():
				var n2d := n as Node2D
				if n2d:
					# el alfa no se toca: es del nivel (fundidos, apariciones)
					var tono := tono_luz(n2d.position, fuerza_tinte)
					tono.a = n2d.modulate.a
					n2d.modulate = tono


# ---------------------------------------------------------------------------
# API
# ---------------------------------------------------------------------------

## Abre la puerta hasta el tope. Emite puerta_abierta al acabar. Si ya estaba
## abierta, la senal sale en el fotograma siguiente (para que quien haga
## "abrir_puerta(); await puerta_abierta" no se quede colgado).
func abrir_puerta() -> void:
	if await _mover_puerta(1.0):
		puerta_abierta.emit()


## Cierra la puerta. Emite puerta_cerrada al acabar.
func cerrar_puerta() -> void:
	if await _mover_puerta(0.0):
		puerta_cerrada.emit()


## Posicion (local al decorado) de una de las marcas: "Entrada", "Mesa",
## "SitioDominus", "LimiteIzq", "Organo"...
func marcador(nombre: String) -> Vector2:
	var m := get_node_or_null(nombre) as Marker2D
	if m == null:
		push_warning("casa_interior_decorado: no hay marca '%s'" % nombre)
		return Vector2.ZERO
	return m.position


## Todos los puntos examinables: nombre -> posicion a ras de suelo.
func puntos_examinables() -> Dictionary:
	var res := {}
	for nombre in EXAMINABLES:
		res[nombre] = marcador(nombre)
	return res


## Tramo por el que puede andar Magnus: x minima y maxima.
func limites() -> Vector2:
	return Vector2(marcador("LimiteIzq").x, marcador("LimiteDer").x)


## Color de la luz que cae en un punto de la sala, sacado de las mismas luces
## que pintan el fondo. Pensado para modulate de un personaje: con fuerza 1 un
## sprite queda tan calido (o tan azul junto a la puerta) como el decorado que
## tiene detras. No baja de ~0,45 de brillo (un personaje tiene que leerse
## aunque la pared de detras este casi negra) ni se pasa mucho de 1.
func tono_luz(pos: Vector2, fuerza: float = 1.0) -> Color:
	var r := AMBIENTE.r
	var g := AMBIENTE.g
	var b := AMBIENTE.b
	for l in LUCES:
		var radio2: float = l[4] * l[4]
		var d2 := pos.distance_squared_to(Vector2(l[0], l[1]))
		var f: float = l[3] * pow(radio2 / (radio2 + d2), CAIDA)
		var c: Color = l[2]
		r += c.r * f
		g += c.g * f
		b += c.b * f
	# misma curva de tono que el revelado del fondo
	var cr := 1.0 - exp(-r * EXPOSICION)
	var cg := 1.0 - exp(-g * EXPOSICION)
	var cb := 1.0 - exp(-b * EXPOSICION)
	var lum := maxf((cr + cg + cb) / 3.0, 0.001)
	var brillo := clampf(0.45 + lum * 0.8, 0.45, 1.0)
	# junto al fuego el rojo pasaria de 1 y quemaria el sprite: tope suave
	var tinte := Color(minf(cr / lum * brillo, 1.15), minf(cg / lum * brillo, 1.1), minf(cb / lum * brillo, 1.05))
	return Color.WHITE.lerp(tinte, clampf(fuerza, 0.0, 1.0))


# ---------------------------------------------------------------------------
# Puerta
# ---------------------------------------------------------------------------

## Devuelve true si llego al destino (false si otra orden la interrumpio).
func _mover_puerta(destino: float) -> bool:
	if _tween_puerta and _tween_puerta.is_valid():
		_tween_puerta.kill()
	var dur := duracion_puerta * absf(destino - apertura)
	if dur < 0.02:
		apertura = destino
		await get_tree().process_frame
		return true
	var tween := create_tween()
	_tween_puerta = tween
	# Arranca lenta (pesa, y quien empuja no se fia) y frena al final.
	tween.tween_property(self, "apertura", destino, dur) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	return _tween_puerta == tween


func _set_apertura(v: float) -> void:
	apertura = clampf(v, 0.0, 1.0)
	if is_node_ready():
		_colocar_hoja()


## Pone la hoja en su angulo: columnas proyectadas en perspectiva, el canto
## (grosor) en el borde libre, algo mas oscura cuanto mas de lado se ve, y el
## charco de luna del suelo segun cuanto hueco queda a la vista.
func _colocar_hoja() -> void:
	var th := deg_to_rad(angulo_abierta) * apertura
	var dir := Vector2(cos(th), sin(th))        # direccion de la hoja en (x, z)
	var normal := Vector2(-sin(th), cos(th))    # su cara de dentro
	var tam := _hoja.texture.get_size() if _hoja.texture else Vector2(PUERTA_ANCHO, PUERTA_ABAJO - PUERTA_ARRIBA)
	var puntos := PackedVector2Array()
	var uvs := PackedVector2Array()
	puntos.resize((COLUMNAS_HOJA + 1) * 2)
	uvs.resize((COLUMNAS_HOJA + 1) * 2)
	for i in COLUMNAS_HOJA + 1:
		var u := float(i) / COLUMNAS_HOJA
		var xz := Vector2(BISAGRA_X, 0.0) + dir * PUERTA_ANCHO * u
		puntos[i] = _proyectar(xz.x, xz.y, PUERTA_ARRIBA)
		puntos[COLUMNAS_HOJA + 1 + i] = _proyectar(xz.x, xz.y, PUERTA_ABAJO)
		uvs[i] = Vector2(u * tam.x, 0.0)
		uvs[COLUMNAS_HOJA + 1 + i] = Vector2(u * tam.x, tam.y)
	_hoja.polygon = puntos
	_hoja.uv = uvs
	if _hoja.polygons.is_empty():
		var quads: Array = []
		for i in COLUMNAS_HOJA:
			quads.append(PackedInt32Array([i, i + 1, COLUMNAS_HOJA + 2 + i, COLUMNAS_HOJA + 1 + i]))
		_hoja.polygons = quads
	var k := 1.0 - 0.3 * sin(th)
	_hoja.self_modulate = Color(k, k, k)
	# Canto: del borde libre por dentro al mismo borde por fuera
	var libre := Vector2(BISAGRA_X, 0.0) + dir * PUERTA_ANCHO
	var fuera := libre - normal * GROSOR_PUERTA
	_canto.polygon = PackedVector2Array([
		_proyectar(libre.x, libre.y, PUERTA_ARRIBA), _proyectar(fuera.x, fuera.y, PUERTA_ARRIBA),
		_proyectar(fuera.x, fuera.y, PUERTA_ABAJO), _proyectar(libre.x, libre.y, PUERTA_ABAJO)])
	_canto.visible = apertura > 0.005
	_luz_luna.modulate.a = LUNA_MAX * smoothstep(0.04, 0.55, apertura)


func _proyectar(x: float, z: float, y: float) -> Vector2:
	var s := DISTANCIA_CAMARA / (DISTANCIA_CAMARA - z)
	return CENTRO_PROYECCION + (Vector2(x, y) - CENTRO_PROYECCION) * s


# ---------------------------------------------------------------------------
# Pendulo y llamas
# ---------------------------------------------------------------------------

## Oscila con un seno exacto, sin amortiguar y sin nada que lo empuje: es la
## regularidad la que inquieta, no el movimiento. El incensario cuelga de sus
## cadenas y por eso casi no gira con la vara; lleva un retraso minimo.
func _colocar_pendulo() -> void:
	var fase := _t * TAU / maxf(periodo_pendulo, 0.1)
	var amp := deg_to_rad(amplitud_pendulo)
	var ang := amp * sin(fase)
	var retraso := amp * 0.12 * sin(fase - 0.9)
	var rel := ang * (rigidez_incensario - 1.0) + retraso
	_pendulo.rotation = ang
	_incensario.rotation = rel
	_sombra_incensario.rotation = rel


## Parpadeo de las velas: estiran y encogen un poco y se mecen. Tres senos
## por llama con fases distintas bastan para que no vayan a la par.
func _mover_llamas() -> void:
	for i in _llamas.size():
		var tt := _t * 6.5 + _fase_llamas[i]
		var p := sin(tt) * 0.5 + sin(tt * 2.3 + 1.7) * 0.3 + sin(tt * 5.1 + 0.4) * 0.2
		_llamas[i].scale = _escala_llamas[i] * Vector2(1.0 - p * 0.06, 1.0 + p * 0.12)
		_llamas[i].skew = sin(_t * 1.4 + _fase_llamas[i]) * 0.07
