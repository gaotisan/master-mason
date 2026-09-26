extends Node2D
## Una araña que vive en un trozo de telarana y no se mueve de ahi.
##
## Dentro de su trozo pivota sobre el cuerpo y da paseos cortos, con paradas
## largas entre medias, y nunca se sale. Se usa en dos sitios:
##
##   title_screen    esquina de abajo a la derecha del panel; ahi ademas se le
##                   llama a volar() y se larga (ver abajo).
##   sarcophagus     esquina de arriba a la derecha, en penumbra. Ahi NO se le
##                   llama a volar() nunca: se queda quieta en su rincon toda la
##                   escena, que es justo lo que se quiere. Si no se llama, las
##                   hojas de las alas no llegan a cargarse siquiera. El titulo, que
##                   siempre vuela, las deja cargadas de antemano con
##                   precargar_vuelo(), para que no se carguen en mitad del zoom.
##
## Cuando se le llama a volar(), se asusta: abre las alas y sube en vertical a la
## telarana de la esquina de arriba, justo encima de donde estaba, donde se posa.
## No se aleja hacia el fondo ni se hace pequeno: se mueve por el plano del
## panel, que es donde esta la telarana. Para cuando aterriza la camara ya esta
## metida, asi que lo normal es no verle posarse.
##
## POR QUE FUNCIONA MEZCLAR LAS DOS VISTAS. El video de origen esta grabado
## cenital cuando anda y de frente cuando vuela, que a priori no pega. Pero el
## cambio esta DENTRO de abrir_alas: sus nueve primeros fotogramas son todavia la
## araña vista desde arriba, y ahi mismo se yergue y se pone de cara. O sea que la
## animacion ya trae el gesto de despegar de la pared. Lo unico que hay que hacer
## aqui es acompanarlo: mientras duran esos nueve fotogramas se deshace el giro
## que la tenia tumbada en la telarana, para que cuando salgan las alas ya este
## derecha. Al aterrizar, lo mismo del reves con cerrar_alas.
##
## Las cuatro hojas salen del MISMO recorte del video y comparten casilla, asi
## que se pueden encadenar sin recolocar nada: basta con cambiar de textura.
##
## Coordenadas: las de la imagen del titulo (2912x1632). El fondo esta centrado
## en la camara, asi que pixel de la imagen = posicion de mundo.

signal posado

## Envergadura vertical de la araña posada, en pixeles de la imagen. Es EL numero
## a tocar si se ve grande o pequena; con las alas abiertas sale solo (x1,8).
@export var alto_px: float = 140.0
## Centro de su trozo de telarana: esquina de abajo a la derecha del panel. El
## espejo exacto del sitio anterior seria x=2084, pero ahi la punta del ala
## derecha toca el liston interior del marco al desplegarse (el panel acaba en
## x=2199 y la envergadura son 125 px por lado).
@export var posada: Vector2 = Vector2(2030, 1035)
## Hasta donde se aleja de ese centro en sus paseos. Es el tamano de la mancha
## tupida de telarana que hay ahi: si se pasa, se queda paseando por el panel
## liso y canta que no esta agarrada a nada.
@export var paseo_radio: Vector2 = Vector2(72, 44)
## Como esta tumbada al empezar, en grados. 0 seria de cara a camara.
@export var angulo_posada: float = 24.0
## Donde acaba: la telarana de la MISMA esquina pero arriba, en lo tupido del
## abanico. Sube casi en vertical, asi que ni se acerca al bloque de letras ni al
## rectangulo con el que el shader del titulo las aplana (x 990-1733, y 545-995).
@export var destino: Vector2 = Vector2(2040, 655)
@export var angulo_destino: float = 18.0
## Por donde arquea la subida. Un pelin a la derecha para que no sea una linea
## recta de manual, pero sin separarse de la vertical.
@export var vuelo_control: Vector2 = Vector2(2090, 840)
## Tono. El bicho es gris azulado y la sala es ambar: sin esto se ve pegado
## encima, frio, como una calcomania. Medido sobre una captura del vuelo, en
## proporcion entre canales (R normalizado a 1):
##
##   panel de alrededor   1 / 0,543 / 0,215
##   cuerpo con el tinte  1 / 0,589 / 0,267   ya pegaba
##   ALA con el tinte     1 / 0,634 / 0,323   se iba, y ademas mas clara
##
## La membrana del ala es palida y azulada, asi que es la que delata al bicho:
## con el tinte de antes (0.90, 0.62, 0.38) quedaba un trozo frio volando por una
## sala ambar. Estos numeros la llevan a 1 / 0,573 / 0,255 y el cuerpo casi al
## tono exacto del panel. No se baja mas el brillo a proposito: el ala TIENE que
## coger la luz de la vela al pasarle por delante, que es medio efecto.
@export var tinte: Color = Color(0.88, 0.56, 0.30)

@export_group("En la telarana")
## Cuanto se esta quieta entre gesto y gesto. Un rango: si fuese fijo se notaria
## el compas. Las paradas largas son la mitad del efecto: lo que asusta de una
## araña es que este inmovil y de pronto no lo este.
@export var espera_min: float = 1.8
@export var espera_max: float = 5.0
## De cada gesto, cuantos son pivotar en el sitio. El resto son paseos cortos.
@export var proporcion_giros: float = 0.55
## Cuanto pivota cada vez, en grados, a un lado o al otro, y cuanto tarda.
@export var giro_grados_min: float = 7.0
@export var giro_grados_max: float = 26.0
@export var giro_tiempo_min: float = 0.9
@export var giro_tiempo_max: float = 2.0
## Largo de un paseo y a que velocidad. Cortos y sin prisa: son recolocaciones,
## no un paseo de verdad.
@export var paseo_min: float = 26.0
@export var paseo_max: float = 78.0
@export var paseo_velocidad: float = 62.0
## Lo que tarda en orientarse hacia donde va antes de andar. Una araña pivota
## primero y sale despues; si gira y anda a la vez, se desliza de lado.
@export var orienta_tiempo: float = 0.34
## Cuanto avanza por fotograma del ciclo de patas, como fraccion de alto_px, y
## cuantos grados de pivote valen lo mismo que un fotograma. Las patas van con el
## movimiento, no con el reloj: si no se mueve ni gira, no mueve las patas.
##
## Estos dos numeros NO salen de medir el paso del bicho, porque en el video
## camina en el sitio y no hay paso que medir: la punta de la pata recorre 74 px
## del master (16,6 en pantalla) por ciclo, y usar eso daria 86 fotogramas por
## segundo al andar, o sea las patas borrosas. Estan puestos para que un paseo
## tipico (unos 50 px en 0,8 s) gaste ciclo y medio de patas, que es lo que se
## ve bien. El ciclo tiene 23 fotogramas.
@export var avance_relativo: float = 0.011
@export var giro_por_fotograma: float = 1.6
## Lo que respira: el abdomen bombea. Tiene que ser casi invisible.
@export var respiracion: float = 0.006
@export var respiracion_hz: float = 0.42

@export_group("Sobresalto")
## Adonde sale corriendo cuando algo golpea cerca. Va mas arriba y FUERA de la
## telarana, al rincon en penumbra: donde esta posada el fondo tiene luminancia
## 57 y ahi 33, o sea que casi se pierde de vista. Esa es la gracia.
@export var refugio: Vector2 = Vector2(2310, 175)
## Sale disparada. Una araña asustada no acelera, ya esta a tope en el primer paso.
@export var huida_velocidad: float = 280.0
## El tinte alla arriba. No es un capricho: el fondo del rincon tiene luminancia
## 33 y el de su telarana 57, o sea que ahi llega un 58 % de luz. Si la araña
## subiera con el mismo tinte se veria IGUAL de clara sobre un fondo mas oscuro,
## que es justo lo que delata a un sprite pegado encima. Con el mismo factor
## aplicado, el contraste contra su fondo se mantiene y lo que se lee es que se
## ha metido en la sombra. Sale de tinte * 0,58.
@export var tinte_refugio: Color = Color(0.336, 0.29, 0.238)
## Cuanto se queda escondida antes de atreverse a volver.
@export var refugio_espera_min: float = 3.0
@export var refugio_espera_max: float = 6.0
## Y a que velocidad vuelve. MUY lenta a proposito: el contraste entre el tiron
## de la huida y el regreso a rastras es todo el efecto. A 12 px/s tarda unos
## 15 s en volver a su sitio, y las patas se le mueven apenas.
@export var regreso_velocidad: float = 12.0

@export_group("Vuelo")
## Lo que dura la subida, con las alas ya fuera. Despegue y aterrizaje duran
## aparte lo que duran sus animaciones (0,92 s y 0,67 s a 24 fps). Corto: son
## unos 400 px y ademas va asustado, no de paseo.
@export var vuelo_tiempo: float = 1.25
@export var fps: float = 24.0
## Lo que se despega de la pared durante el despliegue, ademas de lo que ya sube
## el propio sprite. Para que se vea que se suelta de la telarana.
@export var despegue_subida: float = 18.0
## Sube y baja al ritmo del aleteo. Es lo que hace que vuele en vez de deslizarse:
## sin esto, un sprite recorriendo una curva no pesa nada. Va enganchado al
## fotograma del ciclo, no a un seno suelto, para que gane altura con el ala abajo.
## Al subir en vertical no se ve como un balanceo sino como que trepa a tirones,
## un empujon por aletazo, que es justo lo que hace un bicho que sale asustado.
@export var bamboleo: float = 16.0

## Las hojas, con su rejilla. Todas comparten casilla (292x176 a 1/4).
const ANIMS := {
	"andando": {"hoja": "res://assets/intro/aracnobat_andando.png",     "cols": 6, "filas": 4, "n": 23},
	"abrir":   {"hoja": "res://assets/intro/aracnobat_abrir_alas.png",  "cols": 6, "filas": 4, "n": 22},
	"volando": {"hoja": "res://assets/intro/aracnobat_volando.png",     "cols": 6, "filas": 2, "n": 11},
	"cerrar":  {"hoja": "res://assets/intro/aracnobat_cerrar_alas.png", "cols": 4, "filas": 4, "n": 16},
}
## Envergadura de la araña posada dentro de la casilla de la hoja (292x176),
## promediada sobre el ciclo: al andar estira y encoge las patas.
const ALTO_HOJA := 160.0
## Centro del cuerpo dentro de la casilla, medido sobre los sprites de andando.
## El giro tiene que ir por ahi y no por el centro de la casilla, que con las
## patas abiertas cae en el aire.
const PIVOTE := Vector2(0.22, -5.76)
## Fotograma de abrir_alas en el que ya han salido las alas: hasta ahi es todavia
## araña cenital, y es el tramo en el que se endereza.
const ABRIR_ALZADO := 9
## Fotograma de cerrar_alas a partir del cual ya esta plegada sobre la pared.
const CERRAR_POSADO := 6

enum { ESPERA, GIRO, ORIENTA, PASEO, HUIDA, ESCONDIDA, REGRESO, DESPEGUE, VUELO, ATERRIZAJE, FIN }

var _sprite: Sprite2D
var _estado := ESPERA
var _reloj := 0.0
var _escala := 1.0
var _anim := ""
var _t := 0.0
var _dur := 1.0
var _espera := 0.0
var _gr_desde := 0.0
var _gr_hasta := 0.0
var _pos_desde := Vector2.ZERO
var _pos_hasta := Vector2.ZERO
var _paso := 0.0
var _avance := 1.0
var _grado_px := 1.0
var _salida := Vector2.ZERO
var _tras_orientar := PASEO
var _dist_refugio := 0.0
## Solo para retener las hojas del vuelo en la cache (ver precargar_vuelo).
var _hojas_vuelo: Array[Texture2D] = []

func _ready() -> void:
	_escala = alto_px / ALTO_HOJA
	_avance = maxf(alto_px * avance_relativo, 0.001)
	_grado_px = _avance / maxf(giro_por_fotograma, 0.01)

	_sprite = Sprite2D.new()
	_sprite.offset = PIVOTE
	_sprite.scale = Vector2.ONE * _escala
	_sprite.modulate = tinte
	_sprite.rotation_degrees = angulo_posada
	# light_mask es por CanvasItem y no se hereda: sin esto, poner light_mask=0 en
	# el nodo de la escena no serviria de nada y las velas del ataud le darian luz.
	_sprite.light_mask = light_mask
	add_child(_sprite)
	_poner("andando", 0)

	position = posada
	_dist_refugio = posada.distance_to(refugio)
	_espera = randf_range(espera_min, espera_max)

func _poner(anim: String, f: int) -> void:
	if _anim != anim:
		_anim = anim
		var d: Dictionary = ANIMS[anim]
		_sprite.texture = load(d["hoja"])
		_sprite.hframes = d["cols"]
		_sprite.vframes = d["filas"]
	_sprite.frame = clampi(f, 0, int(ANIMS[anim]["n"]) - 1)

func _n(anim: String) -> int:
	return int(ANIMS[anim]["n"])

## Solo el titulo: deja cargadas las hojas del vuelo antes de necesitarlas. Si
## no, _poner() las carga al cambiar de animacion, y eso cae tres veces en mitad
## del zoom de salida (despegue, vuelo, aterrizaje): un tiron por hoja. Con esto
## load() las encuentra ya en la cache. El ataud no lo llama y sigue sin cargarlas.
func precargar_vuelo() -> void:
	if not _hojas_vuelo.is_empty():
		return
	for k in ["abrir", "volando", "cerrar"]:
		_hojas_vuelo.append(load(ANIMS[k]["hoja"]))

## Suma esfuerzo (px recorridos + grados girados) y saca de ahi el fotograma.
func _gastar(dist: float, grados: float) -> void:
	_paso += dist + absf(grados) * _grado_px
	_sprite.frame = int(_paso / _avance) % _n("andando")

## Le dice que salga por patas hacia arriba. Devuelve lo que tarda en posarse.
func volar() -> float:
	if _estado >= DESPEGUE:
		return 0.0
	_estado = DESPEGUE
	_t = 0.0
	# El giro de la telarana se va sumando sin limite (cada pivote suma o resta
	# unos grados), y el tween de abajo va a 0 absoluto: con 400 grados acumulados
	# daba mas de una vuelta entera en 0,375 s, una pirueta justo al despegar. Se
	# lleva al mismo angulo dentro de -180..180, que se ve igual, y asi deshace
	# como mucho media vuelta por el camino corto.
	_sprite.rotation_degrees = wrapf(_sprite.rotation_degrees, -180.0, 180.0)
	_poner("abrir", 0)
	# Mientras dura el tramo en que todavia es araña cenital, se deshace el giro:
	# cuando salgan las alas ya esta de cara. Es lo que hace que las dos vistas
	# no se peleen.
	var tw := create_tween()
	tw.tween_property(_sprite, "rotation_degrees", 0.0, ABRIR_ALZADO / fps) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Y se suelta de la telarana: sube un poco mas de lo que ya sube el sprite.
	# Sale de donde este en ese momento, no de posada: puede estar de paseo.
	_salida = position + Vector2(0, -despegue_subida)
	var tw2 := create_tween()
	tw2.tween_interval(ABRIR_ALZADO / fps)
	tw2.tween_property(self, "position", _salida,
		(_n("abrir") - ABRIR_ALZADO) / fps).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return duracion_vuelo()

## Lo que tarda desde que abre las alas hasta que esta posada al otro lado.
func duracion_vuelo() -> float:
	return (_n("abrir") + _n("cerrar")) / fps + vuelo_tiempo

## Bezier cuadratica de la telarana de abajo a la de arriba.
func _punto(t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * _salida + 2.0 * u * t * vuelo_control + t * t * destino

func _process(delta: float) -> void:
	_reloj += delta
	# El abdomen bombea. Es casi invisible a proposito: lo que tiene que hacer es
	# que no parezca una calcomania, no que se vea respirar.
	if _estado <= REGRESO:
		var pulso := 1.0 + respiracion * sin(_reloj * TAU * respiracion_hz)
		_sprite.scale = Vector2(_escala, _escala * pulso)

	# La luz se interpola con lo cerca que este del refugio. Solo en los estados de
	# suelo: volando no pinta nada, y ademas en el titulo el refugio ni se usa.
	if _estado <= REGRESO:
		_actualizar_tinte()

	match _estado:
		ESPERA: _hacer_espera(delta)
		GIRO: _hacer_giro(delta)
		ORIENTA: _hacer_orienta(delta)
		HUIDA: _hacer_huida(delta)
		ESCONDIDA: _hacer_escondida(delta)
		REGRESO: _hacer_regreso(delta)
		PASEO: _hacer_paseo(delta)
		DESPEGUE: _hacer_despegue(delta)
		VUELO: _hacer_vuelo(delta)
		ATERRIZAJE: _hacer_aterrizaje(delta)
		FIN: return

## Cuanto mas cerca del refugio, mas apagada. Entre medias interpola, asi que la
## huida la va apagando sobre la marcha y el regreso la va devolviendo a la luz.
func _actualizar_tinte() -> void:
	if _dist_refugio <= 1.0:
		return
	var k: float = clampf(position.distance_to(posada) / _dist_refugio, 0.0, 1.0)
	_sprite.modulate = tinte.lerp(tinte_refugio, k)

## Quieta. Al acabar la espera decide: o pivota en el sitio, o se da un paseo
## corto por su trozo de telarana.
func _hacer_espera(delta: float) -> void:
	_espera -= delta
	if _espera > 0.0:
		return
	if randf() < proporcion_giros:
		_gr_desde = _sprite.rotation_degrees
		var amplitud := randf_range(giro_grados_min, giro_grados_max)
		_gr_hasta = _gr_desde + amplitud * (1.0 if randf() < 0.5 else -1.0)
		_dur = randf_range(giro_tiempo_min, giro_tiempo_max)
		_t = 0.0
		_estado = GIRO
		return

	_pos_desde = position
	_pos_hasta = _destino_paseo()
	if _pos_hasta == position:
		_espera = randf_range(espera_min, espera_max)
		return
	_gr_desde = _sprite.rotation_degrees
	# La cabeza mira hacia donde va: el sprite mira a -Y, o sea 90 grados mas que
	# el angulo del vector.
	var dir := _pos_hasta - _pos_desde
	var objetivo := rad_to_deg(dir.angle()) + 90.0
	# Por el camino corto: sin esto puede dar la vuelta entera para girar 20 grados.
	_gr_hasta = _gr_desde + wrapf(objetivo - _gr_desde, -180.0, 180.0)
	_dur = orienta_tiempo
	_t = 0.0
	_tras_orientar = PASEO
	_estado = ORIENTA

## Un punto de su trozo de telarana, ni tan cerca que no se note ni fuera de la
## mancha. Se sortea dentro de la elipse y se descarta lo que quede muy pegado.
func _destino_paseo() -> Vector2:
	for _i in 12:
		var a := randf() * TAU
		var r := sqrt(randf())
		var p := posada + Vector2(cos(a) * paseo_radio.x, sin(a) * paseo_radio.y) * r
		var d := p.distance_to(position)
		if d >= paseo_min and d <= paseo_max:
			return p
	return position

func _hacer_giro(delta: float) -> void:
	_t += delta
	var k: float = clampf(_t / _dur, 0.0, 1.0)
	# Suave por los dos lados: una araña quieta no arranca a girar de golpe.
	var s := k * k * (3.0 - 2.0 * k)
	var antes := _sprite.rotation_degrees
	_sprite.rotation_degrees = lerpf(_gr_desde, _gr_hasta, s)
	_gastar(0.0, _sprite.rotation_degrees - antes)
	if k >= 1.0:
		# Mismo angulo, acotado: que no se vaya acumulando vuelta tras vuelta.
		_sprite.rotation_degrees = wrapf(_sprite.rotation_degrees, -180.0, 180.0)
		_estado = ESPERA
		_espera = randf_range(espera_min, espera_max)

func _hacer_orienta(delta: float) -> void:
	_t += delta
	var k: float = clampf(_t / maxf(_dur, 0.001), 0.0, 1.0)
	var s := k * k * (3.0 - 2.0 * k)
	var antes := _sprite.rotation_degrees
	_sprite.rotation_degrees = lerpf(_gr_desde, _gr_hasta, s)
	_gastar(0.0, _sprite.rotation_degrees - antes)
	if k >= 1.0:
		_sprite.rotation_degrees = wrapf(_sprite.rotation_degrees, -180.0, 180.0)
		_t = 0.0
		var v: float = paseo_velocidad if _tras_orientar == PASEO else regreso_velocidad
		_dur = maxf(_pos_desde.distance_to(_pos_hasta) / maxf(v, 0.5), 0.05)
		_estado = _tras_orientar

func _hacer_paseo(delta: float) -> void:
	_t += delta
	var k: float = clampf(_t / _dur, 0.0, 1.0)
	# Arranca y para suave; a medio camino va a velocidad de crucero.
	var s := k * k * (3.0 - 2.0 * k)
	var antes := position
	position = _pos_desde.lerp(_pos_hasta, s)
	_gastar(position.distance_to(antes), 0.0)
	if k >= 1.0:
		_estado = ESPERA
		_espera = randf_range(espera_min, espera_max)

## Algo ha golpeado cerca. Lo llama punch_effect al dar el puñetazo, por el grupo
## "asustadizo". Sale corriendo al rincon oscuro y despues vuelve a rastras.
func on_near_miss(_origen: Vector2 = Vector2.ZERO) -> void:
	asustar()

func asustar() -> void:
	if _estado >= DESPEGUE or _estado == HUIDA or _estado == ESCONDIDA:
		return
	_pos_desde = position
	_pos_hasta = refugio
	_gr_desde = _sprite.rotation_degrees
	var dir := _pos_hasta - _pos_desde
	if dir.length() < 1.0:
		return
	_gr_hasta = _gr_desde + wrapf(rad_to_deg(dir.angle()) + 90.0 - _gr_desde, -180.0, 180.0)
	_dur = maxf(dir.length() / maxf(huida_velocidad, 1.0), 0.08)
	_t = 0.0
	_estado = HUIDA

## Sale disparada. A diferencia del paseo, NO se orienta antes: gira mientras
## corre y ademas deprisa, porque lo que asusta de una araña es justamente que se
## mueva antes de que te de tiempo a verla girar.
func _hacer_huida(delta: float) -> void:
	_t += delta
	var k: float = clampf(_t / _dur, 0.0, 1.0)
	var antes_p := position
	var antes_g := _sprite.rotation_degrees
	position = _pos_desde.lerp(_pos_hasta, k)
	_sprite.rotation_degrees = lerpf(_gr_desde, _gr_hasta, minf(k * 2.5, 1.0))
	_gastar(position.distance_to(antes_p), _sprite.rotation_degrees - antes_g)
	if k >= 1.0:
		_sprite.rotation_degrees = wrapf(_sprite.rotation_degrees, -180.0, 180.0)
		_estado = ESCONDIDA
		_espera = randf_range(refugio_espera_min, refugio_espera_max)

## Quieta en el rincon, sin mover ni una pata. Es lo unico que hace bien una
## araña asustada: desaparecer.
func _hacer_escondida(delta: float) -> void:
	_espera -= delta
	if _espera > 0.0:
		return
	_pos_desde = position
	_pos_hasta = posada
	_gr_desde = _sprite.rotation_degrees
	var dir := _pos_hasta - _pos_desde
	if dir.length() < 1.0:
		_estado = ESPERA
		_espera = randf_range(espera_min, espera_max)
		return
	_gr_hasta = _gr_desde + wrapf(rad_to_deg(dir.angle()) + 90.0 - _gr_desde, -180.0, 180.0)
	_dur = orienta_tiempo * 2.5
	_t = 0.0
	_tras_orientar = REGRESO
	_estado = ORIENTA

## Vuelve a su sitio a rastras. Sin suavizado de arranque ni de frenada: a esta
## velocidad no se notaria, y en cambio si se nota que no para de avanzar.
func _hacer_regreso(delta: float) -> void:
	_t += delta
	var k: float = clampf(_t / _dur, 0.0, 1.0)
	var antes := position
	position = _pos_desde.lerp(_pos_hasta, k)
	_gastar(position.distance_to(antes), 0.0)
	if k >= 1.0:
		_estado = ESPERA
		_espera = randf_range(espera_min, espera_max)

func _hacer_despegue(delta: float) -> void:
	_t += delta
	var f := int(_t * fps)
	if f >= _n("abrir"):
		_estado = VUELO
		_t = 0.0
		_poner("volando", 0)
		return
	_poner("abrir", f)

## Sube POR EL PLANO DEL PANEL. No encoge: hubo un intento que la mandaba hacia
## el fondo reduciendola, y con un cuadro plano detras eso no lee como
## profundidad, lee como que se le baja el tamano. Aqui la profundidad no existe
## y no se finge.
##
## Lo que si hace que vuele en vez de deslizarse es el bamboleo, enganchado al
## fotograma del aleteo y no a un seno suelto: en vertical se ve como que trepa a
## tirones, uno por aletazo. Se apaga en los dos extremos, que es donde despega y
## donde se posa.
func _hacer_vuelo(delta: float) -> void:
	_t += delta
	var n := _n("volando")
	var ciclo: float = _t * fps / float(n)
	_poner("volando", int(_t * fps) % n)
	var k: float = clampf(_t / maxf(vuelo_tiempo, 0.01), 0.0, 1.0)
	# Sale ya lanzada y llega frenando, pero suave: es un traslado, no un tiron.
	var s := k * k * (3.0 - 2.0 * k)
	var borde: float = sin(k * PI)
	position = _punto(s) + Vector2(0, -bamboleo * borde * sin(ciclo * TAU))
	if k >= 1.0:
		_estado = ATERRIZAJE
		_t = 0.0
		_poner("cerrar", 0)
		position = destino
		# Se vuelve a tumbar sobre la telarana mientras pliega.
		var tw := create_tween()
		tw.tween_interval(CERRAR_POSADO / fps)
		tw.tween_property(_sprite, "rotation_degrees", angulo_destino,
			(_n("cerrar") - CERRAR_POSADO) / fps).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _hacer_aterrizaje(delta: float) -> void:
	_t += delta
	var f := int(_t * fps)
	if f >= _n("cerrar"):
		_estado = FIN
		_poner("andando", 0)
		posado.emit()
		return
	_poner("cerrar", f)
