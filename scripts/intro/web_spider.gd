extends Node2D
## Una araña que vive en un trozo de telarana y no se mueve de ahi.
##
## Dentro de su trozo pivota sobre el cuerpo y da paseos cortos, con paradas
## largas entre medias, y nunca se sale.
##
## SIN GIROS BRUSCOS. La primera version se orientaba hacia un punto cualquiera
## de la mancha antes de cada paseo, en 0,34 s: si el punto le caia detras daba
## media vuelta a 650-750 grados/s y salia recta, y al volver del refugio otros
## 180 grados en 0,85 s. El usuario dijo que parecia una Roomba. Ahora:
##   - mira siempre mas o menos hacia el mismo lado (arco_reposo alrededor de
##     angulo_posada), asi que en calma nunca necesita dar la vuelta;
##   - solo anda hacia donde ya casi mira (giro_paseo_max), a tramos cortos con
##     paradas, no de un tiron; recula solo de vez en cuando, cuando ya se ha
##     ido lejos, y hacia el centro de su tela;
##   - todo giro tranquilo va con tope de velocidad (giro_velocidad_max) y los
##     grandes se parten en pasitos DESIGUALES con pausas (giro_tramo_max), como
##     hace una araña de verdad, que se recoloca pata a pata; iguales hacian
##     tic, tic, tic, como la aguja de un reloj;
##   - de vez en cuando solo recoloca las patas sin irse a ningun sitio (ajuste).
## Las patas siempre van con el cuerpo: si se mueve o gira, las mueve.
##
## Para volver a los paseos de antes (hacia cualquier lado): arco_reposo = 180 y
## giro_paseo_max = 180 a la vez. Solo con uno de los dos, o solo quitando la
## marcha atras, se queda pegada al borde de arriba de su mancha (todos los
## rumbos del arco apuntan algo hacia arriba) y ya solo pivota.
##
## Se usa en dos sitios:
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
## De cada gesto (quitando los ajustes, ver abajo), cuantos son pivotar en el
## sitio. El resto son paseos cortos. Alto a proposito: pocos paseos. Con mas
## (0,55) iba y venia por la misma diagonal, que volvia a parecer un aparato.
@export var proporcion_giros: float = 0.70
## Cuanto pivota cada vez, en grados, a un lado o al otro, y cuanto tarda (si
## con ese tiempo pasase de giro_velocidad_max, tarda lo que haga falta).
@export var giro_grados_min: float = 7.0
@export var giro_grados_max: float = 26.0
@export var giro_tiempo_min: float = 0.9
@export var giro_tiempo_max: float = 2.0
## Largo de un paseo y a que velocidad. Cortos y sin prisa: son recolocaciones,
## no un paseo de verdad.
@export var paseo_min: float = 26.0
@export var paseo_max: float = 78.0
@export var paseo_velocidad: float = 62.0
## Lo MINIMO que tarda cada pasito de giro cuando se orienta hacia algo: antes
## de un paseo y al darse la vuelta en el refugio. Una araña pivota primero y
## sale despues; si gira y anda a la vez, se desliza de lado. Antes era lo que
## tardaba sin mas (0,34 s para lo que fuese, hasta media vuelta), y de ahi
## salian los giros de Roomba; ahora manda el tope de velocidad.
@export var orienta_tiempo: float = 0.6
## Tope de velocidad de giro en calma, en grados/s, en el punto mas rapido del
## gesto (arranca y frena suave, asi que la media es dos tercios de esto). Una
## araña tranquila se reorienta despacio, recolocando patas. Cada pasito sortea
## su propio pico entre el 70 y el 100 % de esto, para que no lleven todos el
## mismo compas.
@export var giro_velocidad_max: float = 50.0
## El giro mas grande que hace de una vez. Si tiene que girar mas (para meterse
## otra vez en su arco al volver), lo parte en pasitos de entre la mitad y todo
## esto, cada uno de un tamano, con una pausa corta entre medias, en vez de
## pegar un barrido de media vuelta.
@export var giro_tramo_max: float = 60.0
## Pausa entre pasito y pasito. 0 y 0 las quita (encadena los pasitos).
@export_range(0.0, 3.0) var giro_pausa_min: float = 0.3
@export_range(0.0, 3.0) var giro_pausa_max: float = 0.8
## Cuanto se aparta su rumbo de angulo_posada, en grados, a un lado o al otro.
## Es lo que hace que en calma nunca tenga que darse la vuelta: siempre mira mas
## o menos hacia el mismo lado de la telarana, como una que la esta vigilando.
@export var arco_reposo: float = 50.0
## Lo mas que gira para orientarse antes de un paseo. Los destinos que pidan
## mas se descartan: anda hacia donde ya casi mira, no se vuelve a buscar sitio.
@export var giro_paseo_max: float = 35.0
## Marcha atras: recula un poquito hacia el centro de su tela, con las patas al
## reves, para no tener que darse la vuelta. Es la EXCEPCION: solo se lo plantea
## cuando ya se ha ido lejos hacia donde mira (mas alla de paseo_atras_umbral de
## su mancha, 0 = el centro, 1 = el borde), y aun asi solo esta proporcion de las
## veces; si no, pivota. Sorteandolo en cada paseo reculaba mas de lo que
## avanzaba, adelante-atras por la misma linea, que es lo que hace un aparato.
## Va a esta fraccion de largo y de velocidad. 0 lo apaga.
@export var paseo_atras_proporcion: float = 0.35
@export var paseo_atras_factor: float = 0.45
@export var paseo_atras_umbral: float = 0.5
## Un paseo no va de un tiron: va a tramos de como mucho esto (px), con una
## parada corta entre tramo y tramo. De un tiron y a velocidad fija es lo que
## lo hacia parecer un aparato; a tramos parece que tantea.
@export var paseo_tramo: float = 30.0
## Parada entre tramo y tramo. 0 y 0 las quita (anda de un tiron).
@export_range(0.0, 3.0) var paseo_pausa_min: float = 0.3
@export_range(0.0, 3.0) var paseo_pausa_max: float = 0.9
## De cada gesto, cuantos son solo recolocar las patas: da unos pasitos en el
## sitio y desplaza el peso un pelin, sin irse a ningun sitio. Es lo que hace
## una araña cuidando la tela. Casi invisible a proposito, y pocos: cada gesto
## que empieza se ve, y muchos la hacen parecer inquieta.
@export var proporcion_ajustes: float = 0.12
## Cuantos fotogramas del ciclo de patas gasta, en cuanto tiempo, y cuanto se
## desplaza el peso (fraccion de alto_px; con 220 px son unos 2 px, ida y vuelta).
@export var ajuste_pasos_min: int = 3
@export var ajuste_pasos_max: int = 7
@export var ajuste_tiempo_min: float = 0.7
@export var ajuste_tiempo_max: float = 1.4
@export var ajuste_relativo: float = 0.008
## Cuanto avanza por fotograma del ciclo de patas, como fraccion de alto_px, y
## cuantos grados de pivote valen lo mismo que un fotograma. Las patas van con el
## movimiento, no con el reloj: si no se mueve ni gira, no mueve las patas.
##
## Estos dos numeros NO salen de medir el paso del bicho, porque en el video
## camina en el sitio y no hay paso que medir: la punta de la pata recorre 74 px
## del master (16,6 en pantalla) por ciclo, y usar eso daria 86 fotogramas por
## segundo al andar, o sea las patas borrosas. Se pusieron para que un paseo de
## unos 50 px en 0,8 s gastase ciclo y medio de patas, que es lo que se ve bien;
## ahora los paseos son tramos mas cortos y lentos, asi que las patas van a unos
## 20-25 fotogramas/s como mucho, el ritmo del video. El ciclo tiene 23.
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
## Pero el giro para encarar el refugio NO es de golpe: rapido, con arranque y
## frenada suaves y con este tope (grados/s en el punto mas rapido). Antes daba
## el giro en el primer 40 % de la carrera y en lineal: si el golpe la pillaba
## volviendo, media vuelta a 1600-1700 grados/s, un chasquido.
@export var huida_giro_velocidad_max: float = 240.0
## Arranca a correr mientras gira, en cuanto le falten como mucho estos grados
## para encarar el refugio, y mientras no lo encara del todo avanza menos cuanto
## mas de lado va (por el coseno del angulo que le falta): asi no sale disparada
## de costado. Desde su postura normal le faltan unos 68, asi que sale casi en el
## acto; si la pilla mirando al lado contrario (volviendo a rastras) gira medio
## segundo antes de salir, en vez de salir corriendo de culo. 0 = gira del todo
## y despues corre.
@export_range(0.0, 180.0) var huida_giro_sin_andar: float = 65.0
## El tinte alla arriba. No es un capricho: el fondo del rincon tiene luminancia
## 33 y el de su telarana 57, o sea que ahi llega un 58 % de luz. Si la araña
## subiera con el mismo tinte se veria IGUAL de clara sobre un fondo mas oscuro,
## que es justo lo que delata a un sprite pegado encima. Con el mismo factor
## aplicado, el contraste contra su fondo se mantiene y lo que se lee es que se
## ha metido en la sombra. Sale de tinte * 0,58.
@export var tinte_refugio: Color = Color(0.336, 0.29, 0.238)
## Cuanto se queda escondida, sin mover una pata, antes de darse la vuelta para
## volver. Despues la vuelta en el rincon lleva otros 3-5 s (ver abajo), asi que
## entre las dos se queda en la sombra unos 6-9 s; con 3-6 s de quieta y la
## vuelta lenta eran casi 15, y la escena entera del susto se alargaba.
@export var refugio_espera_min: float = 2.0
@export var refugio_espera_max: float = 4.0
## La vuelta en el rincon para encarar su sitio es casi media vuelta. Va con sus
## propios topes, mas rapidos que los de la telarana: pasa a oscuras (luminancia
## 33), la queja era por los giros a la luz, y con los de calma tardaba 10 s y el
## susto entero se iba a 40. Sigue por pasitos desiguales, con arranque y frenada.
@export var regreso_giro_velocidad_max: float = 120.0
@export var regreso_giro_tramo_max: float = 90.0
## El primer pasito de esa vuelta es solo esto (grados, mas o menos un cuarto):
## se asoma, duda, y despues se da la vuelta. 0 lo quita.
@export var regreso_asomo: float = 16.0
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

## GIRO es pivotar por pivotar; ORIENTA, lo mismo pero para encarar un paseo o
## el regreso (lo lleva el mismo codigo). Todo lo que va antes de DESPEGUE es
## estar en la telarana; de DESPEGUE en adelante, el vuelo del titulo.
enum { ESPERA, GIRO, ORIENTA, PASEO, HUIDA, ESCONDIDA, REGRESO, AJUSTE, DESPEGUE, VUELO, ATERRIZAJE, FIN }

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
## Giro por pasitos: adonde tiene que acabar mirando (sin acotar, para que los
## tramos sumen exacto), lo minimo que dura cada tramo y la pausa en curso.
var _gr_final := 0.0
var _giro_dur_min := 0.0
var _pausa := 0.0
## Topes del giro en curso (los de calma o los del refugio) y, si lo hay, el
## tamano del primer pasito (el asomo); 0 = sin primer pasito especial.
var _giro_vmax := 50.0
var _giro_tramo := 60.0
var _giro_primero := 0.0
## Paseo a tramos: de donde a donde va entero, en que tramo esta y cuantos son.
var _paseo_origen := Vector2.ZERO
var _paseo_fin := Vector2.ZERO
var _tramo := 0
var _tramos := 1
var _atras := false
## Huida: el giro y la carrera llevan relojes distintos (la carrera puede
## esperar un instante a que el giro vaya encarado).
var _t_mov := 0.0
var _dur_giro := 0.1
## Ajuste: donde estaba, hacia donde echa el peso y cuantos fotogramas gasta.
var _ajuste_base := Vector2.ZERO
var _ajuste_peso := Vector2.ZERO
var _ajuste_pasos := 0
var _paso_desde := 0.0
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
## dist negativa = marcha atras: el ciclo de patas va al reves.
func _gastar(dist: float, grados: float) -> void:
	_paso += dist + absf(grados) * _grado_px
	_marcar_paso()

func _marcar_paso() -> void:
	_sprite.frame = posmod(floori(_paso / _avance), _n("andando"))

## Le dice que salga por patas hacia arriba. Devuelve lo que tarda en posarse.
func volar() -> float:
	if _estado >= DESPEGUE:
		return 0.0
	_estado = DESPEGUE
	_t = 0.0
	# El tween de abajo va a 0 absoluto. El rumbo se acota a -180..180 al acabar
	# cada giro, pero si el susto la pilla a medio giro puede ir un pelin fuera: se
	# lleva al mismo angulo dentro de -180..180, que se ve igual, y asi deshace
	# como mucho media vuelta por el camino corto, nunca una pirueta.
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
	if _estado < DESPEGUE:
		var pulso := 1.0 + respiracion * sin(_reloj * TAU * respiracion_hz)
		_sprite.scale = Vector2(_escala, _escala * pulso)

	# La luz se interpola con lo cerca que este del refugio. Solo en los estados de
	# suelo: volando no pinta nada, y ademas en el titulo el refugio ni se usa.
	if _estado < DESPEGUE:
		_actualizar_tinte()

	match _estado:
		ESPERA: _hacer_espera(delta)
		GIRO: _hacer_giro(delta)
		ORIENTA: _hacer_giro(delta)
		HUIDA: _hacer_huida(delta)
		ESCONDIDA: _hacer_escondida(delta)
		REGRESO: _hacer_regreso(delta)
		PASEO: _hacer_paseo(delta)
		AJUSTE: _hacer_ajuste(delta)
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

## Quieta. Al acabar la espera decide: recolocar patas, pivotar en el sitio o
## darse un paseo corto por su trozo de telarana. Si viene de fuera de su arco
## (acaba de volver del refugio mirando hacia abajo), lo primero es volver a
## mirar hacia su lado, por pasitos.
func _hacer_espera(delta: float) -> void:
	_espera -= delta
	if _espera > 0.0:
		return
	var desvio := _desvio()
	if absf(desvio) > arco_reposo + 0.5:
		# Solo lo justo para entrar: hasta un poco dentro del borde mas cercano,
		# no hasta el centro. Al llegar del refugio son unos 70 grados en vez de
		# 110, dos pasitos en vez de tres.
		var final := signf(desvio) * arco_reposo * randf_range(0.7, 0.9)
		_girar_a(angulo_posada + final, GIRO, ESPERA)
		return
	if randf() < proporcion_ajustes:
		_empezar_ajuste()
		return
	if randf() < proporcion_giros or not _elegir_paseo():
		_pivotar()

## Cuanto se aparta ahora su rumbo del de reposo, en -180..180.
func _desvio() -> float:
	return wrapf(_sprite.rotation_degrees - angulo_posada, -180.0, 180.0)

## Pivote de reposo: unos grados a un lado o al otro, sin salirse del arco. Si
## el sorteo la sacaria, gira hacia el otro lado, que es volver hacia el centro.
func _pivotar() -> void:
	var amplitud := randf_range(giro_grados_min, giro_grados_max)
	var signo := 1.0 if randf() < 0.5 else -1.0
	var desvio := _desvio()
	if absf(desvio + amplitud * signo) > arco_reposo:
		signo = -signo
	var final := clampf(desvio + amplitud * signo, -arco_reposo, arco_reposo)
	_girar_a(angulo_posada + final, GIRO, ESPERA, randf_range(giro_tiempo_min, giro_tiempo_max))

## Un paseo que no la obligue a girar mucho: sortea un rumbo cerca del que ya
## tiene (y dentro de su arco) y un largo; vale si el punto cae dentro de la
## mancha de telarana. Recular se decide UNA vez, antes de probar: solo si ya se
## ha ido lejos hacia donde mira, y entonces recula hacia el centro de su tela,
## ladeada unos grados para no desandar la misma linea. Si en unos intentos no
## sale ninguno, devuelve false y el gesto se queda en pivotar.
func _elegir_paseo() -> bool:
	var rot := _sprite.rotation_degrees
	var radio := Vector2(maxf(paseo_radio.x, 1.0), maxf(paseo_radio.y, 1.0))
	# El sprite mira a -Y: el rumbo 0 es hacia arriba, 90 grados menos que el
	# angulo del vector. Marcha atras, al reves.
	var mirando := Vector2.from_angle(deg_to_rad(rot - 90.0))
	var adelantada := ((position - posada) / radio).dot(mirando)
	var atras := paseo_atras_factor > 0.0 and adelantada > paseo_atras_umbral \
		and randf() < paseo_atras_proporcion
	for _i in 16:
		var rumbo: float
		if atras:
			# El rumbo que le deja el culo mirando al centro, ladeado 8-20 grados.
			var al_centro := rad_to_deg((posada - position).angle()) - 90.0
			rumbo = al_centro + randf_range(8.0, 20.0) * (1.0 if randf() < 0.5 else -1.0)
			rumbo = rot + wrapf(rumbo - rot, -180.0, 180.0)
			if absf(rumbo - rot) > giro_paseo_max:
				continue
		else:
			rumbo = rot + randf_range(-giro_paseo_max, giro_paseo_max)
		if absf(wrapf(rumbo - angulo_posada, -180.0, 180.0)) > arco_reposo:
			continue
		var largo := randf_range(paseo_min, paseo_max) * (paseo_atras_factor if atras else 1.0)
		var ang := deg_to_rad(rumbo - 90.0 + (180.0 if atras else 0.0))
		var p := position + Vector2.from_angle(ang) * largo
		if ((p - posada) / radio).length() > 1.0:
			continue
		_atras = atras
		_paseo_origen = position
		_paseo_fin = p
		_girar_a(rumbo, ORIENTA, PASEO, orienta_tiempo)
		return true
	return false

## Gira hasta mirar a `objetivo` (grados; por el camino corto) y despues pasa a
## `luego`. Con tope de velocidad y, si es mucho, por pasitos con pausas. Los
## topes son los de calma salvo que se pasen otros (vmax, tramo > 0), y `primero`
## > 0 hace que el primer pasito sea solo de esos grados.
func _girar_a(objetivo: float, estado: int, luego: int, dur_min: float = 0.0,
		vmax: float = -1.0, tramo: float = -1.0, primero: float = 0.0) -> void:
	var rot := _sprite.rotation_degrees
	_gr_final = rot + wrapf(objetivo - rot, -180.0, 180.0)
	_tras_orientar = luego
	_giro_dur_min = dur_min
	_giro_vmax = vmax if vmax > 0.0 else giro_velocidad_max
	_giro_tramo = tramo if tramo > 0.0 else giro_tramo_max
	_giro_primero = primero
	_estado = estado
	_siguiente_tramo_giro()

## Lo que queda por girar por debajo de esto se hace en el mismo pasito: un
## pasito final de 3 grados se veria como un tic suelto.
const GIRO_RESTO_MIN := 8.0

## Prepara el pasito siguiente: entre la mitad y todo el tope de tramo (o el
## asomo, si es el primero), sin pasarse de lo que falta, y con su propio pico de
## velocidad. Pasitos iguales y al mismo ritmo parecian un servo; asi parece que
## se recoloca pata a pata. Dura lo que pida ese pico: con el arranque y la
## frenada suaves, el pico es 1,5 veces la media.
func _siguiente_tramo_giro() -> void:
	var rot := _sprite.rotation_degrees
	var falta := _gr_final - rot
	var tope := maxf(_giro_tramo, 1.0)
	if _giro_primero > 0.0:
		tope = minf(tope, _giro_primero * randf_range(0.75, 1.25))
		_giro_primero = 0.0
		var paso0 := minf(absf(falta), tope)
		if absf(falta) - paso0 < GIRO_RESTO_MIN:
			paso0 = absf(falta)
		_empezar_pasito(rot, paso0 * signf(falta))
		return
	var paso := minf(absf(falta), randf_range(0.5, 1.0) * tope)
	if absf(falta) - paso < GIRO_RESTO_MIN:
		paso = absf(falta)
	_empezar_pasito(rot, paso * signf(falta))

func _empezar_pasito(rot: float, grados: float) -> void:
	_gr_desde = rot
	_gr_hasta = rot + grados
	var v := maxf(_giro_vmax, 1.0) * randf_range(0.7, 1.0)
	_dur = maxf(_giro_dur_min, 1.5 * absf(grados) / v)
	_t = 0.0
	_pausa = 0.0

func _hacer_giro(delta: float) -> void:
	if _pausa > 0.0:
		_pausa -= delta
		if _pausa <= 0.0:
			_siguiente_tramo_giro()
		return
	_t += delta
	var k: float = clampf(_t / maxf(_dur, 0.001), 0.0, 1.0)
	# Suave por los dos lados: una araña quieta no arranca a girar de golpe.
	var s := k * k * (3.0 - 2.0 * k)
	var antes := _sprite.rotation_degrees
	_sprite.rotation_degrees = lerpf(_gr_desde, _gr_hasta, s)
	_gastar(0.0, _sprite.rotation_degrees - antes)
	if k < 1.0:
		return
	if absf(_gr_final - _sprite.rotation_degrees) > 0.05:
		# Quedan pasitos: se para un momento, como quien recoloca las patas. Sin
		# pausa (0 y 0), el siguiente sale en el acto: si no, se quedaria aqui.
		_pausa = randf_range(giro_pausa_min, giro_pausa_max)
		if _pausa <= 0.0:
			_siguiente_tramo_giro()
		return
	# Mismo angulo, acotado: que no se vaya acumulando vuelta tras vuelta.
	_sprite.rotation_degrees = wrapf(_sprite.rotation_degrees, -180.0, 180.0)
	match _tras_orientar:
		PASEO:
			_tramos = maxi(1, ceili(_paseo_origen.distance_to(_paseo_fin) / maxf(paseo_tramo, 1.0) - 0.001))
			_tramo = 0
			_empezar_tramo_paseo()
		REGRESO:
			_t = 0.0
			_dur = maxf(_pos_desde.distance_to(_pos_hasta) / maxf(regreso_velocidad, 0.5), 0.05)
			_estado = REGRESO
		_:
			_estado = ESPERA
			_espera = randf_range(espera_min, espera_max)

func _empezar_tramo_paseo() -> void:
	_pos_desde = _paseo_origen.lerp(_paseo_fin, float(_tramo) / _tramos)
	_pos_hasta = _paseo_origen.lerp(_paseo_fin, float(_tramo + 1) / _tramos)
	var v := paseo_velocidad * (paseo_atras_factor if _atras else 1.0)
	_dur = maxf(_pos_desde.distance_to(_pos_hasta) / maxf(v, 0.5), 0.05)
	_t = 0.0
	_pausa = 0.0
	_estado = PASEO

func _hacer_paseo(delta: float) -> void:
	if _pausa > 0.0:
		_pausa -= delta
		if _pausa <= 0.0:
			_tramo += 1
			_empezar_tramo_paseo()
		return
	_t += delta
	var k: float = clampf(_t / _dur, 0.0, 1.0)
	# Cada tramo arranca y para suave.
	var s := k * k * (3.0 - 2.0 * k)
	var antes := position
	position = _pos_desde.lerp(_pos_hasta, s)
	var d := position.distance_to(antes)
	_gastar(-d if _atras else d, 0.0)
	if k < 1.0:
		return
	if _tramo + 1 < _tramos:
		_pausa = randf_range(paseo_pausa_min, paseo_pausa_max)
		if _pausa <= 0.0:
			# Sin parada (0 y 0): tramo siguiente en el acto, o se quedaria aqui.
			_tramo += 1
			_empezar_tramo_paseo()
		return
	_estado = ESPERA
	_espera = randf_range(espera_min, espera_max)

## Recoloca las patas sin irse: unos fotogramas del ciclo a poco ritmo, y el
## cuerpo se echa un par de pixeles hacia un lado y vuelve. Nada mas.
func _empezar_ajuste() -> void:
	_ajuste_base = position
	_ajuste_peso = Vector2.from_angle(randf() * TAU) * alto_px * ajuste_relativo
	_ajuste_pasos = randi_range(ajuste_pasos_min, maxi(ajuste_pasos_min, ajuste_pasos_max))
	_paso_desde = _paso
	_dur = randf_range(ajuste_tiempo_min, ajuste_tiempo_max)
	_t = 0.0
	_estado = AJUSTE

func _hacer_ajuste(delta: float) -> void:
	_t += delta
	var k: float = clampf(_t / maxf(_dur, 0.001), 0.0, 1.0)
	var s := k * k * (3.0 - 2.0 * k)
	position = _ajuste_base + _ajuste_peso * sin(PI * k)
	_paso = _paso_desde + s * _ajuste_pasos * _avance
	_marcar_paso()
	if k >= 1.0:
		position = _ajuste_base
		_estado = ESPERA
		_espera = randf_range(espera_min, espera_max)

## Algo ha golpeado cerca. Lo llama punch_effect al dar el puñetazo, por el grupo
## "asustadizo". Sale corriendo al rincon oscuro y despues vuelve a rastras.
func on_near_miss(_origen: Vector2 = Vector2.ZERO) -> void:
	asustar()

func asustar() -> void:
	if _estado >= DESPEGUE or _estado == HUIDA or _estado == ESCONDIDA:
		return
	var dir := refugio - position
	if dir.length() < 1.0:
		return
	_pos_desde = position
	_pos_hasta = refugio
	_gr_desde = _sprite.rotation_degrees
	_gr_hasta = _gr_desde + wrapf(rad_to_deg(dir.angle()) + 90.0 - _gr_desde, -180.0, 180.0)
	_dur_giro = maxf(1.5 * absf(_gr_hasta - _gr_desde) / maxf(huida_giro_velocidad_max, 1.0), 0.08)
	_dur = maxf(dir.length() / maxf(huida_velocidad, 1.0), 0.08)
	_t = 0.0
	_t_mov = 0.0
	_pausa = 0.0
	_estado = HUIDA

## Sale disparada. Echa a correr en el acto (o casi, ver huida_giro_sin_andar) y
## va encarando el refugio mientras corre: rapido, pero con arranque y frenada,
## no de un chasquido.
func _hacer_huida(delta: float) -> void:
	_t += delta
	var kg: float = clampf(_t / _dur_giro, 0.0, 1.0)
	var antes_p := position
	var antes_g := _sprite.rotation_degrees
	_sprite.rotation_degrees = lerpf(_gr_desde, _gr_hasta, kg * kg * (3.0 - 2.0 * kg))
	# Con el giro acabado corre sin mas. La cuenta va por kg y no por el angulo
	# leido del sprite: ese vuelve con un resto de 1e-5 y con sin_andar = 0 no
	# arrancaba nunca (se quedaba en HUIDA para siempre).
	var falta := absf(_gr_hasta - _sprite.rotation_degrees)
	if kg >= 1.0:
		_t_mov += delta
	elif falta <= huida_giro_sin_andar + 0.01:
		# Aun ladeada: avanza menos cuanto mas de lado va, para no escurrirse de
		# costado a 280 px/s.
		_t_mov += delta * clampf(cos(deg_to_rad(falta)), 0.0, 1.0)
	var k: float = clampf(_t_mov / _dur, 0.0, 1.0)
	position = _pos_desde.lerp(_pos_hasta, k)
	_gastar(position.distance_to(antes_p), _sprite.rotation_degrees - antes_g)
	if k >= 1.0 and kg >= 1.0:
		_sprite.rotation_degrees = wrapf(_sprite.rotation_degrees, -180.0, 180.0)
		_estado = ESCONDIDA
		_espera = randf_range(refugio_espera_min, refugio_espera_max)

## Quieta en el rincon, sin mover ni una pata. Es lo unico que hace bien una
## araña asustada: desaparecer. Despues se asoma un poco, duda, se da la vuelta
## hacia su sitio por pasitos (alli arriba es casi media vuelta, con los topes
## del refugio) y baja a rastras.
func _hacer_escondida(delta: float) -> void:
	_espera -= delta
	if _espera > 0.0:
		return
	_pos_desde = position
	_pos_hasta = posada
	var dir := _pos_hasta - _pos_desde
	if dir.length() < 1.0:
		_estado = ESPERA
		_espera = randf_range(espera_min, espera_max)
		return
	_girar_a(rad_to_deg(dir.angle()) + 90.0, ORIENTA, REGRESO, orienta_tiempo,
		regreso_giro_velocidad_max, regreso_giro_tramo_max, regreso_asomo)

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
