extends Node2D
## La caida en la hojarasca, por separado. El cuento empieza con el anciano
## poniendose en pie y sacudiendose "la hojarasca que se habia quedado adherida
## a sus ropas" en un atardecer de otono: aqui Magnus cae del cielo sobre un
## monton de hojas, a oscuras junto a un haz de luz calida, las levanta con el
## golpe, se queda tumbado mientras vuelven a caer, y al levantarse se le van
## desprendiendo. Cae fuera del haz, en el tercio izquierdo (MagnusSpawn,
## 2026-10-14; antes en el centro): en la luz se flota, y caer de golpe a
## traves de ella la contradecia justo antes de que el jugador lo descubra
## (al levantarse ve la columna, va hacia ella y salta: "ligero").
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
## A false (scenes/dev/prueba_luz.tscn y piloto_luz.tscn), sin entrada ni
## caida: Magnus de pie en su sitio y con el mando desde el principio, sin
## pensamientos.
@export var caida_al_empezar: bool = true
## Para probar las hojas de la luz: el baculo baja nada mas empezar, sin
## esperar a la vuelta.
@export var baculo_al_empezar: bool = false
## El bosque de fondo (2026-10-13; encendido en la escena del juego): la imagen
## de Midjourney bosque_hojarasca.png en dos planos (bosque_cerca.png y
## bosque_lejos.png, de raw/master_mason/hojarasca_bosque/capas.py) detras del
## haz, en sombra (Bosque, bosque_fondo.gdshader). Antes se probaron
## bosque_fondo.jpg (Gemini) y bosque_fondo_mj.png (facetada).
## scenes/dev/prueba_bosque.tscn lo prueba con el baculo ya bajando.
@export var bosque_de_fondo: bool = false:
	set(v):
		bosque_de_fondo = v
		if is_node_ready():
			$Bosque.visible = v
			_poner_haz()
## Con el bosque, el haz un pelin mas fuerte (por esto la fuerza del dibujo de
## fondo_haz.gdshader): delante de los arboles tiene que seguir siendo lo que
## brilla (el usuario, 2026-10-13: "que se vea un pelin mas").
@export var haz_con_bosque: float = 1.35
## Con el bosque: el camino de la derecha esta tapado de hojas (apagado, ver
## bosque_fondo.gdshader) y al alcanzar el baculo una racha se las lleva y
## aparece en camino_abrir s (_abrir_camino).
@export var camino_abrir: float = 3.5
@export var camino_hojas_lecho: int = 600
## Lo que la racha del camino empuja hacia arriba en lo mas fuerte (px/s^2;
## la gravedad es 900): las levanta y remolinean mientras sopla.
@export var camino_levante: float = 2300.0
@export var camino_hojas_fondo: int = 160
## VIDA DEL BOSQUE (con bosque_de_fondo): el fondo deja de ser una foto plana
## (bosque_fondo.gdshader). La camara acompana al peregrino: se adelanta hacia
## donde va (camara_adelanto px corriendo, unas tres cuartas partes andando; por la
## velocidad y no por la x, asi no salta al dar la vuelta al mundo) y sube
## hasta camara_subida px cuando el sube por las hojas; ademas respira muy
## despacio (deriva de camara_deriva px con periodos que no casan). Antes de
## tener el mando (la caida), solo respira. El suelo y el peregrino se mueven
## con ella; los troncos de delante algo menos y la niebla de detras casi nada
## (paralaje: es cuando se mueve la camara cuando se ve que hay fondo).
## camara_zoom: acercamiento fijo para que al moverse no se vean los bordes
## (tiene que cubrir adelanto + deriva en x y subida + deriva en y).
## La copa se mece con el viento: cada racha entra por el lado del que sopla y
## cruza el bosque a racha_px_s (cinco muelles a lo ancho, con su punta de
## inclinacion_copa px con la racha a tope); la del baculo lo sacude entero.
@export var camara_deriva: Vector2 = Vector2(10.0, 4.0)
@export var camara_adelanto: float = 56.0
@export var camara_subida: float = 32.0
@export var camara_zoom: float = 1.05
@export var inclinacion_copa: Vector2 = Vector2(13.0, 2.5)
@export var copa_hz: float = 0.35
@export var copa_amortiguamiento: float = 0.25
@export var racha_px_s: float = 1100.0
## Viento de fondo (dB sobre el fichero) y cuanto tarda en llegar desde el nivel
## en que lo deja el titulo (-14).
@export var viento_db: float = 0.0
@export var viento_subida: float = 6.0
## Rachas: cada cuanto (s), cuanto suben (dB) y cuanto empujan las hojas (px/s^2).
@export var racha_cada_min: float = 7.0
@export var racha_cada_max: float = 16.0
@export var racha_db: float = 3.5
@export var racha_empuje: float = 90.0

@export_group("Historia")
## Lo que pasa, en orden: cae y se levanta (pensamiento "despertar"); anda y,
## al salir por un lado y entrar por el otro la primera vez, se pregunta como ha
## vuelto al mismo sitio y si es la luz de antes ("vuelta"); al acabar, baja el
## baculo por el haz en silencio, solo con la nota de un hilo que vibra
## (SonidoHilo; 2026-10-14, antes decia "Algo baja por la luz…": que hablen la
## imagen, las hojas y el sonido); al quedarse flotando arriba lo reconoce
## ("baculo"). Desconcierto, silencio, reconocimiento.
## Aparte, antes o despues del baculo: la primera vez que salta en la luz y
## flota, al volver al suelo se da cuenta de que alli apenas pesa ("ligero").
## Por la luz bajan hojas despacio, desde el principio (ver Las hojas de la
## luz): nadie dice que sirvan; rebotando de una en otra, a izquierda y
## derecha, se sube hasta el baculo. Alcanzarlo, de momento, hace latir la
## bola (falta la animacion de cogerlo).
## El baculo SOLO baja tras la vuelta: es cuando se da cuenta de que no va a
## ninguna parte (asi lo quiere el usuario, sin atajo por tiempo; si en un
## minuto no ha salido por ningun borde, solo el empujon de "explorar"). Los textos
## estan en textos/pensamientos_es.json.
## Espera tras levantarse antes del primer pensamiento (s).
@export var espera_despertar: float = 1.0
## Si a los tantos segundos de levantarse aun no ha salido por ningun borde, se
## dice que no puede quedarse ahi ("explorar"), una sola vez: el empujon para
## que salga a explorar en vez de quedarse dando vueltas en la luz.
@export var explorar_tras: float = 60.0
## Desde que acaba el pensamiento de la vuelta, cuanto hasta que empieza a bajar
## (s). La nota del hilo empieza a la vez, cuando el baculo asoma por arriba.
@export var espera_baculo: float = 0.0
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
## Equilibrio (2026-10-14, con la musica de fondo; el usuario: las hojas y el
## viento "ensordecedores"): medido en LUFS como suena en el juego, la musica
## queda de base (~-28), las pisadas por debajo (~-36 de pico), el arrastre y
## el viento mas abajo (~-43; ~-40 con racha) y la nota del hilo a la altura de
## la musica. Antes las pisadas iban 8 dB por encima de la musica y el viento la
## tapaba en cada racha; se bajaron en tres escalones de 3 dB (con -30/-37 y
## -33/-40 aun se oian "un pelin demasiado por encima").
@export var hojas_golpe_db: float = -13.0
@export var hojas_levantarse_db: float = -15.0
@export var hojas_paso_db: float = -19.0
@export var arrastre_db: float = -20.0
@export var magnus_pasos_db: float = -24.0
## La nota del hilo mientras baja el baculo (assets/audio/baculo_hilo.wav, de
## raw/master_mason/audio/baculo/hilo.py): por debajo de los pasos en las hojas.
@export var hilo_db: float = -14.0
## Musica de fondo (2026-10-14): "The Pilgrim's Light", de Flow Music, en bucle
## sin costura (assets/audio/musica_hojarasca.ogg, de raw/master_mason/audio/
## musica_hojarasca/bucle.py). Ambiente de base, con las hojas y el viento
## por debajo (ver Equilibrio en hojas_golpe_db). Entra al levantarse, subiendo en
## musica_entrada s: la caida suena solo a viento y hojas. Sin caida (pruebas),
## desde el principio.
@export var musica_db: float = -14.0
@export var musica_entrada: float = 8.0

@export_group("Coger el baculo")
## COGER EL BACULO (2026-10-14; video del usuario, raw/master_mason/anim/
## magnus_coger_baculo). Al alcanzarlo lo agarra (coger_baculo, de flotar.json,
## mirando hacia el; el nodo se pone para que la garra del dibujo caiga en la
## bola) y en ese instante el destello, que tapa el cambio de pose y de baston
## (el del juego y el del video son el mismo dibujo; desde ahi la madera la
## lleva el dibujo y solo queda la bola, en su garra). Con el destello, la
## racha que levanta las hojas y abre el camino (_abrir_camino). Colgado del
## baculo aun flota: baja solo coger_flota de lo que le queda hasta el
## fotograma coger_cae, mientras la bola se descarga (coger_descarga s) y queda
## vacia; luego, sin la magia, cae (guion: "la luz pierde su espesor") y el
## video aterriza agachado y se incorpora. Al acabar sigue con el baculo en la
## mano (el sistema del baston, scenes/dev/baston.tscn, con la magia a cero:
## en la mano solo anda) y la bola vacia.
@export var coger_cae: int = 40
@export var coger_flota: float = 0.15
@export var coger_descarga: float = 1.5

@export_group("La luz")
## Zona de la luz para jugar (fracciones de la apertura del haz): pesa poco del
## todo hasta luz_entera y nada desde luz_borde. El haz se pinta entero solo en
## su centro (0,35) y se apaga en el borde (1): con eso de zona, en los lados
## del haz iluminado no flotaba y habia que estar casi en el centro.
@export var luz_entera: float = 0.8
@export var luz_borde: float = 1.1

@export_group("Las hojas de la luz")
## En la luz se pesa poco (el salto flota, ver magnus.gd) y por el haz bajan
## hojas despacio, planeando casi de cara. Solo esas aguantan a Magnus: si cae
## con los pies sobre una, rebota como si volviera a saltar, y la hoja se hunde
## un palmo girando y la luz la vuelve a su camino (hojas_voladoras.gd).
## 2026-10-12: antes eran una escalera fija (seis hojas quietas en zigzag);
## el usuario: "queda muy facil y feo; mas sutil, que caigan hojas al suelo y
## sea el jugador quien deduzca que se pueden ir usando; lanzarlas a una
## frecuencia que parezca esa misma escalera, pero que no este siempre sino que
## se vayan cayendo al suelo y vayan cayendo otras". Asi: entran por arriba
## (escalera_desde) una a cada lado del eje del haz por turnos, a escalera_lado
## px (cada una algo mas cerca o mas lejos), y bajan a escalera_bajada px/s
## meciendose de lado como una hoja que cae (escalera_vaiven px, inclinandose
## hacia donde va; todas casi a la vez, como si las meciera el mismo aire: a
## destiempo, la de enfrente se iba a veces a 190 px y no se llegaba); cada
## escalera_paso / escalera_bajada s (con azar, escalera_azar) entra otra, asi
## que en cualquier momento estan mas o menos en zigzag, escalera_paso px una
## sobre otra: la misma escalera, bajando, pero que se lee como hojas que caen
## (la primera prueba, con todas igual de tumbadas, a la misma distancia y casi
## quietas de lado, se veia como una escalera).
## Y entre ellas caen otras que no aguantan (luz_sueltas_*): de todos los
## tamanos, sobre todo pequenas, que caen mas deprisa y dando vueltas como
## cualquier hoja. El usuario: "si pones solo las de la escalera se va a notar
## mucho". Lo que las distingue es como caen: las que sirven, despacio y casi
## de cara. Al llegar a escalera_hasta dejan de aguantar y caen al
## lecho como las demas. Algo mayores que las demas (escalera_escala).
## No estan al empezar (2026-10-13, el usuario: "que empiecen a salir cuando
## salga el baculo, para que un jugador perspicaz se de cuenta"): cuando baja
## el baculo entran todas por arriba en fila (escalera_entrada px una tras
## otra, la de mas abajo primero) y planean hasta su sitio de la escalera, que
## ya va bajando; mientras entran no aguantan. Antes solo caen las sueltas
## pequenas (las medianas, que se confunden con las de la escalera, tambien
## esperan al baculo).
## Con la gravedad de la luz el salto de parado sube los pies 177 px sobre la
## hoja; la siguiente esta 140 px mas arriba y viene bajando (a 26 px/s): se
## sube ~110 px por rebote y en 5-6 rebotes se llega al baculo. Con 112 y 32
## (lo de la escalera fija) se subian ~55: diez o doce rebotes seguidos, cada
## uno con su giro, demasiado. De espaldas no se
## va en el aire: cada rebote es girarse (magnus.gd, GIRAR EN EL AIRE: 1,05 s)
## y luego avanzar los 124 px de un lado al otro. Un bot sube hasta el baculo
## (piloto_luz, prueba "escalera").
@export var escalera_paso: float = 140.0
@export var escalera_lado: float = 62.0
@export var escalera_bajada: float = 26.0
@export var escalera_azar: float = 0.18
@export var escalera_vaiven: float = 14.0
@export var escalera_vaiven_periodo: float = 4.6
@export var escalera_desde: float = -40.0
@export var escalera_hasta: float = 1110.0
## Por encima de esta y aun no aguantan: desde las de mas abajo se llega al
## baculo (arriba del todo), pero no se sube mas alla ni se sale por arriba.
@export var escalera_aguanta: float = 400.0
@export var escalera_escala: float = 0.38
@export var escalera_entrada: float = 110.0
## Las que no aguantan: cada cuanto entra una por arriba (s, al azar entre los
## dos), a cuantos px del eje del haz como mucho, y su tamano: la mayoria
## (1 - luz_sueltas_medianas) pequenas, las demas como las del suelo.
@export var luz_sueltas_cada_min: float = 0.5
@export var luz_sueltas_cada_max: float = 1.5
@export var luz_sueltas_ancho: float = 120.0
@export var luz_sueltas_pequenas: Vector2 = Vector2(0.12, 0.24)
@export var luz_sueltas_medianas_escala: Vector2 = Vector2(0.26, 0.34)
@export var luz_sueltas_medianas: float = 0.3
## Pisar: px a cada lado de los pies (mas el medio ancho de la hoja), margen
## por encima de los pies del tick anterior (poco: una hoja que cae sobre las
## piernas no se pisa, hay que bajar sobre ella) y por debajo de los de ahora, luz
## minima en la hoja para que aguante, y altura minima de los pies (casi en el
## suelo, la hoja ya va a posarse).
@export var pisar_ancho: float = 46.0
@export var pisar_margen: Vector2 = Vector2(4.0, 10.0)
@export var pisar_luz: float = 0.35
@export var pisar_altura: float = 30.0
## Empuje que se lleva la hoja pisada (px/s hacia abajo) y su crujido (dB).
@export var pisar_empuje: float = 240.0
## Lo que cede la hoja al apoyarse en ella (px/s hacia abajo, sin girar): baja
## con el mientras flexiona y despega (magnus.gd, PISAR LA HOJA); al despegar
## sale pateada con pisar_empuje, girando.
@export var pisar_cede: float = 90.0
@export var hoja_pisada_db: float = -23.0
## El baculo se alcanza cuando la parte de arriba del cuerpo (de los hombros a
## la cabeza: alturas sobre los pies; en el aire, con las piernas recogidas, la
## cabeza queda a ~270 de los pies) pasa a menos de alcance px de su vara.
@export var alcance: float = 30.0
@export var cuerpo_alcance: Vector2 = Vector2(160.0, 270.0)

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
	"flotar_posarse": {0: "caida"},
}
const PISADA_ANIM := {
	"andar": "paso", "parada_andar": "paso", "aterrizaje_correr": "zancada",
	"correr": "zancada", "arranque_correr": "zancada", "parada_correr": "frenada",
	"andar_agachado": "paso_suave", "arranque_agachado": "paso_suave",
	"parada_agachado": "paso_suave", "paso_agachado": "paso_suave",
}
## Fuerza de la caida de cada salto (el corriendo cae mas lejos y mas fuerte).
## Posarse flotando apenas levanta hojas (llega sin golpe).
const FUERZA_SALTO := {"salto_parado": 0.8, "saltar": 1.0, "salto_correr": 1.3, "flotar_posarse": 0.35}
## Ancho del mundo: lo que sale por un lado entra por el otro.
const ANCHO := 2912.0
const FONDO_Z := -10
## El baston en la mano tras cogerlo (ver coger_cae).
const BASTON_EN_MANO := preload("res://scenes/dev/baston.tscn")

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
var _vx := 0.0                         # lo mismo con signo (para la camara)
var _temblor := 0.0
var _roce := 0.0                       # volumen lineal del arrastre
var _racha := 0.0                      # 0..1, la racha de viento que sopla ahora
var _racha_espera := 5.0
var _racha_dir := 1.0
var _fantasma: AnimatedSprite2D        # Magnus al otro lado mientras cruza un borde
var _vueltas := 0                      # veces que ha salido por un borde con el mando
var _con_mando := -1.0                 # 0 desde que se levanta (-1: aun no tiene el mando)
var _baculo_bajando := false
@onready var _pensar: CanvasLayer = $Pensamientos
@onready var _baculo: Node2D = $Baculo
var _hojas_luz: Array[Dictionary] = []  # las que bajan por la luz (las que aguantan)
var _escalera := false                  # ya bajan (desde que baja el baculo)
var _hoja_pisada_capa: Node2D = null    # la capa de la hoja en la que se apoya (ver pisar_cede)
var _cogiendo := false                  # en la cinematica de coger el baculo (ver coger_cae)
var _coger_t := 0.0
var _coger_dat: Dictionary = {}
var _coger_dir := 1.0
var _coger_alto := 0.0                  # lo que hay que bajar el dibujo hasta el suelo al agarrar
var _coger_cayo := false
var _hoja_luz_espera := 0.0             # s hasta que entre la siguiente por arriba
var _hoja_luz_lado := -1.0              # de que lado entra la siguiente
var _luz_reloj := 0.0                   # el vaiven comun de las que bajan por la luz
var _suelta_espera := 0.0               # s hasta la siguiente de las que no aguantan
var _levante := 0.0                     # empuje hacia arriba de la racha del camino (0..1)
var _vida_t := 0.0                      # reloj de la vida del bosque
var _vida_brisa := 0.45                 # brisa de fondo 0..1
var _vida_ruido := FastNoiseLite.new()
var _vida_historia: Array[Vector2] = [] # (tiempo, racha) para el retraso de la racha por franjas
var _copa := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _copa_v := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _respira := Vector2.ZERO            # desplazamiento de la camara (px del mundo)
var _sigue := Vector2.ZERO              # lo que acompana al peregrino (adelanto, subida)
var _sigue_obj := Vector2.ZERO          # su objetivo ya suavizado una vez
var _pies_antes := 0.0                 # y de los pies el tick anterior (para pisar hojas)
var _luz_del_salto := 0.0              # la mas luz que le ha dado en el salto en curso
var _en_el_aire := false
var _ligero_pendiente := false         # ya floto: decir "ligero" en cuanto se pueda
var _alcanzado := false

func _ready() -> void:
	_fondo_mat = $Fondo.material as ShaderMaterial
	_leer_haz()
	$Bosque.visible = bosque_de_fondo
	_poner_haz()
	_a_baja_resolucion($Fondo, 4)
	_a_baja_resolucion($NieblaSuelo, 4)
	# El fondo, por debajo de todo: el baston de Magnus (scenes/dev/baston.tscn)
	# va con z_index -1 para quedar detras del cuerpo, y con el fondo en 0 se
	# quedaba tambien detras del fondo (con el baston en la mano no se veia la bola).
	for nombre in ["FondoImagen", "Bosque", "HojasLejanas", "Motas"]:
		(get_node(nombre) as CanvasItem).z_index = FONDO_Z
	WindAmbience.gust_db = 0.0
	WindAmbience.fade_to(viento_db, viento_subida)
	_magnus.position = $MagnusSpawn.position
	_ultima_x = _magnus.position.x
	_magnus.impacto.connect(_al_impacto)
	_magnus.pisada.connect(_al_pisar)
	_magnus.despega_de_hoja.connect(_al_despegar_de_hoja)
	_sprite.animation_changed.connect(_al_cambiar_animacion)
	# La luz de la escena sobre Magnus (sin tocar sus hojas ni su escena).
	var luz := ShaderMaterial.new()
	luz.shader = preload("res://scripts/game/magnus_luz.gdshader")
	_sprite.material = luz
	_crear_fantasma()
	_magnus.pasos_db = magnus_pasos_db
	# En la luz se pesa poco: sus saltos de parado y andando flotan en el haz.
	_magnus.ligereza = luz_en
	for capa in [_delante, _detras]:
		capa.ligereza = luz_en
		capa.gravedad_luz = _magnus.gravedad_luz
	# Pisar hojas mira a Magnus despues de que se mueva en el tick.
	process_physics_priority = 10
	_delante.sembrar(hojas_por_columna_delante, _monton.bind(0.6))
	_detras.sembrar(hojas_por_columna_detras, _monton.bind(0.4))
	if caida_al_empezar:
		_entrar_desde_negro()
	else:
		$Entrada.hide()
		_empezar_musica()
	if baculo_al_empezar:
		_bajar_baculo.call_deferred()
	_pensar.x_de = func() -> float: return _magnus.position.x
	_magnus.cinematica_terminada.connect(_al_levantarse)
	_pensar.terminado.connect(_al_terminar_pensamiento)
	_baculo.posado.connect(_al_posar_baculo)
	# Que ya haya alguna hoja cayendo al abrir, y alguna suelta en la luz (las
	# de la escalera esperan al baculo).
	for i in 3:
		_hoja_de_arriba(randf_range(200.0, 900.0))
	for i in 6:
		_hoja_suelta_luz(randf_range(0.0, 1000.0))

## Altura extra (px) del monton donde cae (en MagnusSpawn) y de dos lomas mas
## bajas: una bajo el haz y otra a la derecha.
func _monton(x: float, cuanto: float) -> float:
	var caida: float = $MagnusSpawn.position.x
	return cuanto * (30.0 * exp(-pow(wrapf(x - caida, -ANCHO / 2.0, ANCHO / 2.0) / 260.0, 2.0))
		+ 6.0 * exp(-pow((x - 1456.0) / 240.0, 2.0)) + 8.0 * exp(-pow((x - 2076.0) / 200.0, 2.0)))

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
	_delante.viento_arriba = camino_levante * _levante
	_detras.viento_arriba = camino_levante * _levante

func _process(delta: float) -> void:
	_soplar(delta)
	_animar_a_explorar(delta)
	# Con racha caen mas hojas de arriba.
	_arbol_espera -= delta * (1.0 + 3.0 * _racha)
	if _arbol_espera <= 0.0:
		_arbol_espera = randf_range(arbol_cada_min, arbol_cada_max)
		_hoja_de_arriba()
	if _ligero_pendiente and _con_mando >= 0.0 and not _pensar.hablando():
		_ligero_pendiente = false
		_pensar.decir("ligero")
	_envolver()
	if _cogiendo:
		_coger_tick(delta)
	else:
		_seguir_a_magnus(delta)
	_vida_del_bosque(delta)
	if _temblor > 0.0:
		_temblor = maxf(_temblor - delta, 0.0)
		var f := temblor_px * (_temblor / 0.35) ** 2
		_camara.offset = _respira + Vector2(randf_range(-f, f) * 0.5, randf_range(-f, f))
	else:
		_camara.offset = _respira

## VIDA DEL BOSQUE (ver camara_deriva): brisa, muelles de la copa, respiracion
## de la camara y lo que lee bosque_fondo.gdshader. Sin el bosque, la camara
## quieta como siempre.
func _vida_del_bosque(delta: float) -> void:
	if not bosque_de_fondo:
		_respira = Vector2.ZERO
		_camara.zoom = Vector2.ONE
		return
	_vida_t += delta
	var t := _vida_t
	_vida_brisa = 0.45 * (0.8 + 0.45 * _vida_ruido.get_noise_1d(t * 0.06 + 11.0))
	_vida_historia.append(Vector2(t, _racha))
	while _vida_historia.size() > 2 and _vida_historia[1].x < t - 4.0:
		_vida_historia.pop_front()
	var empuje := PackedVector2Array()
	var agitacion := PackedFloat32Array()
	for i in 5:
		var llega := _racha_en(2912.0 * i / 4.0)
		var obj := Vector2(inclinacion_copa.x * _racha_dir, inclinacion_copa.y) * minf(llega, 1.8) \
				+ Vector2(0.7 * _vida_brisa * _racha_dir, 0.0)
		var w := TAU * copa_hz * (0.9 + 0.05 * i)
		var n := maxi(1, ceili(delta * 120.0))
		var h := delta / n
		for _k in n:
			_copa_v[i] += ((obj - _copa[i]) * w * w - _copa_v[i] * 2.0 * copa_amortiguamiento * w) * h
			_copa[i] += _copa_v[i] * h
		empuje.append(_copa[i])
		agitacion.append(minf(llega, 1.5))
	# La camara: sumas de senos lentas con periodos que no casan, y lo que
	# acompana al peregrino (ver camara_adelanto), suavizado dos veces para que
	# arranque y pare sin tirones (como un operador, no pegada a el).
	var d := Vector2(0.6 * sin(TAU * t / 31.0) + 0.4 * sin(TAU * t / 17.3 + 1.3),
			0.5 * sin(TAU * t / 23.0 + 2.0) + 0.3 * sin(TAU * t / 13.7 + 0.4)) * camara_deriva
	var obj := Vector2.ZERO
	if _con_mando >= 0.0 or not caida_al_empezar:
		var pies_y: float = _magnus.global_position.y - _magnus.altura_pies()
		obj = Vector2(clampf(_vx / 250.0, -1.0, 1.0) * camara_adelanto,
				-clampf((1150.0 - pies_y) / 700.0, 0.0, 1.0) * camara_subida)
	var k := 1.0 - exp(-2.2 * delta)
	_sigue_obj = _sigue_obj.lerp(obj, k)
	_sigue = _sigue.lerp(_sigue_obj, k)
	_respira = d + _sigue
	_camara.zoom = Vector2.ONE * camara_zoom
	var m := $Bosque.material as ShaderMaterial
	m.set_shader_parameter("tiempo", t)
	m.set_shader_parameter("brisa", _vida_brisa)
	m.set_shader_parameter("empuje", empuje)
	m.set_shader_parameter("agitacion", agitacion)
	m.set_shader_parameter("camara", _respira)

## La racha tal como le llega a la x dada: entra por el lado del que sopla
## (_racha_dir) y cruza a racha_px_s.
func _racha_en(x: float) -> float:
	var retraso := (x if _racha_dir > 0.0 else 2912.0 - x) / racha_px_s
	var tt := _vida_t - retraso
	if _vida_historia.is_empty() or tt >= _vida_historia[-1].x:
		return _racha
	for i in range(_vida_historia.size() - 1, 0, -1):
		var a := _vida_historia[i - 1]
		if a.x <= tt:
			var b := _vida_historia[i]
			return lerpf(a.y, b.y, (tt - a.x) / maxf(b.x - a.x, 1e-4))
	return _vida_historia[0].y

## Una hoja nueva en el aire, en la capa de delante o en la de detras.
func _soltar(pos: Vector2, vel: Vector2, delante: bool, escala: float = -1.0, giro: float = INF,
		ligera := false) -> Dictionary:
	return (_delante if delante else _detras).soltar(pos, vel, escala, giro, ligera)

## Velocidad, vadeo, sombra de contacto y el lado de la luz para el borde
## encendido de Magnus.
func _seguir_a_magnus(delta: float) -> void:
	if delta <= 0.0:
		return
	var x := _magnus.position.x
	var dx := wrapf(x - _ultima_x, -ANCHO / 2.0, ANCHO / 2.0)
	_ultima_x = x
	_velocidad = lerpf(_velocidad, absf(dx) / delta, 1.0 - exp(-10.0 * delta))
	_vx = lerpf(_vx, dx / delta, 1.0 - exp(-6.0 * delta))
	var en_suelo: bool = not _magnus.en_el_aire()
	if en_suelo and absf(dx) > 0.2 and _velocidad > 25.0:
		_vadear(x, signf(dx))
	# El roce sigue a la velocidad, en volumen lineal y sin saltos, para que
	# arranque y pare como un roce de verdad; parado o en el aire calla.
	var objetivo: float = clampf(_velocidad / velocidad_referencia, 0.0, 1.6) * 0.75 if en_suelo else 0.0
	_roce = move_toward(_roce, objetivo, delta * 2.5)
	$SonidoArrastre.volume_db = arrastre_db + linear_to_db(maxf(_roce, 0.0001))
	# Sombra de contacto: se encoge y aclara al subir en un salto; tumbado es
	# larga (todo el cuerpo).
	# La altura de los pies (en las de flotar el dibujo ya va alto en su casilla:
	# el arco solo no la dice).
	var alto: float = _magnus.altura_pies() if _magnus.en_el_aire() else maxf(-_sprite.position.y, 0.0)
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
	var h := _soltar(Vector2(x, y), Vector2(randf_range(-35.0, 35.0) + _racha_dir * 60.0 * _racha, 40.0), randf() < 0.6,
			-1.0, INF, true)
	# de fuera del lecho: no lo hace crecer (hojas_voladoras.gd, DE FUERA)
	h["de_fuera"] = true

## x del eje del haz a una altura y.
func x_haz(y: float) -> float:
	var t := (y - _haz_origen.y) / (_haz_destino.y - _haz_origen.y)
	return lerpf(_haz_origen.x, _haz_destino.x, t)

## Las hojas que bajan por la luz y aguantan (ver Las hojas de la luz).
func hojas_de_la_luz() -> Array[Dictionary]:
	return _hojas_luz

## Empiezan a bajar las de la escalera (con el baculo). entrando: entran por
## arriba y planean hasta su sitio; si no, ya estan en el (pruebas).
func empezar_escalera(entrando := true) -> void:
	if _escalera:
		return
	_escalera = true
	_repartir_hojas_luz(entrando)

## La escalera entera, cada una en su sitio como si llevaran un rato entrando
## por arriba (la de mas arriba, la ultima en entrar). Entrando, salen de
## encima de la pantalla en fila, la de mas abajo primero.
func _repartir_hojas_luz(entrando: bool) -> void:
	var y := escalera_desde + randf() * escalera_paso
	var lado := -1.0
	var ys: Array[float] = []
	while y < escalera_hasta:
		ys.append(y)
		y += escalera_paso * randf_range(1.0 - escalera_azar, 1.0 + escalera_azar)
	for k in ys.size():
		var desde := escalera_desde - 60.0 - (ys.size() - 1 - k) * escalera_entrada if entrando else INF
		_hoja_luz(ys[k], lado, desde)
		lado = -lado
	# la siguiente, del otro lado que la de arriba, cuando haya bajado su paso
	_hoja_luz_lado = 1.0
	_hoja_luz_espera = maxf((escalera_desde + escalera_paso - ys[0]) / escalera_bajada, 0.0) if ys.size() > 0 else 0.0

## Una hoja de la luz a la altura y, a un lado del eje del haz. Con desde_y,
## entra desde esa altura planeando hasta su sitio.
func _hoja_luz(y: float, lado: float, desde_y: float = INF) -> void:
	var dx := lado * escalera_lado * randf_range(0.9, 1.1)
	var fase := randf_range(-0.5, 0.5)
	var amp := escalera_vaiven * randf_range(0.7, 1.3)
	var p := Vector2(x_haz(y) + dx + amp * sin(TAU * _luz_reloj / escalera_vaiven_periodo + fase), y)
	var esc := escalera_escala * randf_range(0.9, 1.1)
	var desde := p if is_inf(desde_y) else Vector2(x_haz(desde_y) + dx, desde_y)
	var h: Dictionary = (_delante if randf() < 0.6 else _detras).escalon(desde, p, esc)
	if not is_inf(desde_y):
		h["entrando"] = true
	h["luz_y"] = y
	h["luz_dx"] = dx
	h["luz_amp"] = amp
	h["luz_fase"] = fase
	h["luz_rot"] = h["giro_base"]
	_hojas_luz.append(h)

## Cada tick: entra la que toca por arriba y todas bajan su camino (su sitio,
## que la hoja sigue planeando y al que vuelve si la pisan); abajo del todo
## dejan de aguantar y caen al lecho como las demas.
func _bajar_hojas_luz(delta: float) -> void:
	_luz_reloj += delta
	_suelta_espera -= delta
	if _suelta_espera <= 0.0:
		_suelta_espera = randf_range(luz_sueltas_cada_min, luz_sueltas_cada_max)
		_hoja_suelta_luz(escalera_desde)
	_hoja_luz_espera -= delta
	if _escalera and _hoja_luz_espera <= 0.0:
		_hoja_luz_espera += escalera_paso / escalera_bajada * randf_range(1.0 - escalera_azar, 1.0 + escalera_azar)
		_hoja_luz(escalera_desde, _hoja_luz_lado)
		_hoja_luz_lado = -_hoja_luz_lado
	var i := 0
	while i < _hojas_luz.size():
		var h: Dictionary = _hojas_luz[i]
		var y: float = h["luz_y"] + escalera_bajada * delta
		if y > escalera_hasta:
			h.erase("sitio")
			h["v"] = Vector2(0.0, escalera_bajada)
			h["de_fuera"] = true
			_hojas_luz.remove_at(i)
			continue
		h["luz_y"] = y
		var fase: float = TAU * _luz_reloj / escalera_vaiven_periodo + h["luz_fase"]
		h["sitio"] = Vector2(x_haz(y) + h["luz_dx"] + h["luz_amp"] * sin(fase), y)
		# se inclina hacia donde se mece, como una hoja que cae
		h["giro_base"] = h["luz_rot"] + 0.3 * cos(fase)
		i += 1

## Una de las que caen por la luz y no aguantan (ver Las hojas de la luz), a
## la altura y: de cualquier tamano, sobre todo pequena; cae como las demas
## (ligera: en la luz, mas despacio que fuera, pero mas deprisa que las que
## aguantan, y dando vueltas).
func _hoja_suelta_luz(y: float) -> void:
	var x := x_haz(y) + randf_range(-luz_sueltas_ancho, luz_sueltas_ancho)
	var r := luz_sueltas_medianas_escala if _escalera and randf() < luz_sueltas_medianas else luz_sueltas_pequenas
	var h := _soltar(Vector2(x, y), Vector2(randf_range(-20.0, 20.0), randf_range(10.0, 40.0)), randf() < 0.6,
			randf_range(r.x, r.y), INF, true)
	h["de_fuera"] = true

# --- Pisar hojas, flotar y el baculo (cada tick de fisica, despues de Magnus) ---

func _physics_process(delta: float) -> void:
	_bajar_hojas_luz(delta)
	var alto: float = _magnus.altura_pies()
	var pies := Vector2(_magnus.global_position.x, _magnus.global_position.y - alto)
	if _magnus.cayendo() and alto > pisar_altura:
		_pisar_hoja(pies)
	_pies_antes = pies.y
	_seguir_el_salto()
	_mirar_baculo(pies)

## Cae con los pies sobre una hoja de la luz: rebota y la hoja se hunde.
func _pisar_hoja(pies: Vector2) -> void:
	var y0 := minf(_pies_antes, pies.y) - pisar_margen.x
	var y1 := pies.y + pisar_margen.y
	var mejor := {}
	var capa_mejor: Node2D = null
	for capa in [_delante, _detras]:
		var h: Dictionary = capa.apoyo(pies.x, y0, y1, pisar_ancho, pisar_luz)
		if not h.is_empty() and (mejor.is_empty() or h["p"].y < mejor["p"].y):
			mejor = h
			capa_mejor = capa
	if mejor.is_empty() or mejor["p"].y < escalera_aguanta or not _magnus.rebotar(1.0, mejor):
		return
	# Se apoya en ella: cede con su peso, sin girar; la patada, al despegar.
	capa_mejor.pisar(mejor, Vector2(0.0, pisar_cede))
	mejor["giro"] = 0.0
	_hoja_pisada_capa = capa_mejor
	# Unas migas de la hoja y un crujido suave, mas agudo que en el suelo.
	for i in 3:
		_soltar(mejor["p"] + Vector2(randf_range(-8.0, 8.0), 0.0),
				Vector2(randf_range(-60.0, 60.0), randf_range(20.0, 120.0)), randf() < 0.6,
				randf_range(0.09, 0.13), randf_range(-20.0, 20.0))
	_sonar($SonidoPaso, hoja_pisada_db, randf_range(1.12, 1.22))

## Despega de la hoja en la que se apoyaba: sale pateada, girando.
func _al_despegar_de_hoja(h: Dictionary) -> void:
	if _hoja_pisada_capa == null or h.is_empty():
		return
	_hoja_pisada_capa.pisar(h, Vector2(randf_range(-30.0, 30.0), pisar_empuje))
	_hoja_pisada_capa = null

## La primera vez que flota de verdad (le ha dado bien la luz en un salto),
## al volver al suelo lo piensa: en la luz apenas pesa.
func _seguir_el_salto() -> void:
	if _magnus.en_el_aire():
		_en_el_aire = true
		_luz_del_salto = maxf(_luz_del_salto, _magnus.luz())
		return
	if _en_el_aire and _luz_del_salto >= 0.6 and not _pensar.dicho("ligero"):
		_ligero_pendiente = true
	_en_el_aire = false
	_luz_del_salto = 0.0

## Si la parte de arriba del cuerpo llega a la vara del baculo, lo ha
## alcanzado (de momento la bola se enciende; falta la animacion de cogerlo).
func _mirar_baculo(pies: Vector2) -> void:
	if _alcanzado or not _baculo.flotando():
		return
	var a := pies - Vector2(0.0, cuerpo_alcance.x)
	var b := pies - Vector2(0.0, cuerpo_alcance.y)
	var vara: Array = _baculo.vara()
	if _distancia_segmentos(a, b, vara[0], vara[1]) <= alcance:
		_alcanzado = true
		if _sprite.sprite_frames.has_animation(&"coger_baculo"):
			_coger_baculo()
		else:
			_baculo.alcanzado()
			_abrir_camino()

## Empieza a coger el baculo (ver coger_cae).
func _coger_baculo() -> void:
	_coger_dat = _magnus.get("_flotar")["coger_baculo"]
	_magnus.tomar_cinematica()
	_cogiendo = true
	_coger_t = 0.0
	_coger_cayo = false
	var punta: Vector2 = _baculo.punta()
	var dir := signf(punta.x - _magnus.position.x)
	_coger_dir = dir if dir != 0.0 else _magnus.mirando()
	_magnus._mirar(_coger_dir)
	_sprite.animation = &"coger_baculo"
	_sprite.frame = 0
	var o: Array = _coger_dat["offset"]
	_sprite.offset = Vector2(-float(o[0]) if _sprite.flip_h else float(o[0]), float(o[1]))
	var g: Array = _coger_dat["garra"][0]
	_magnus.position.x = punta.x - _coger_dir * float(g[0])
	_ultima_x = _magnus.position.x
	_coger_alto = maxf(_magnus.position.y + float(g[1]) - punta.y, 0.0)
	_baculo.coger()
	_baculo.estallar()
	_baculo.descargar(coger_descarga)
	_abrir_camino()
	_coger_tick(0.0)

## Un fotograma de la cinematica: el del video por el tiempo, lo que le queda
## por bajar, la bola en la garra y la sombra.
func _coger_tick(delta: float) -> void:
	_coger_t += delta
	var d := _coger_dat
	var n := int(d["n"])
	var fps := float(d["fps"])
	var kf := _coger_t * fps
	var k := mini(int(kf), n - 1)
	if _sprite.frame != k:
		_sprite.frame = k
	var cae := float(coger_cae)
	var suelo := float(d["suelo"])
	var alto := 0.0
	if kf < cae:
		var u := kf / cae
		alto = _coger_alto * (1.0 - coger_flota * u * u * (3.0 - 2.0 * u))
	elif kf < suelo:
		var u := (kf - cae) / maxf(suelo - cae, 1.0)
		alto = _coger_alto * (1.0 - coger_flota) * (1.0 - u * u)
	elif not _coger_cayo:
		_coger_cayo = true
		_caer_con_baculo()
	_sprite.position.y = -alto
	var g: Array = d["garra"][k]
	_baculo.bola_en(_magnus.position + Vector2(_coger_dir * float(g[0]), float(g[1]) - alto))
	var arriba := clampf((alto + float(d["pies"][k])) / 260.0, 0.0, 1.0)
	_sombra.position = Vector2(_magnus.position.x, 1196.0)
	_sombra.scale = Vector2(3.4 * (1.0 - 0.35 * arriba), 0.75 * (1.0 - 0.35 * arriba))
	_sombra.modulate.a = 0.62 * (1.0 - 0.7 * arriba)
	if kf >= float(n):
		_acabar_coger()

## Toca el suelo con el baculo: las hojas de los pies saltan y un golpe sordo.
func _caer_con_baculo() -> void:
	var x := _magnus.position.x
	for capa in [_delante, _detras]:
		for h in capa.tomar(x - 70.0, x + 70.0, 10, 2, 0.8):
			capa.lanzar(h, Vector2(randf_range(-260.0, 260.0), -randf_range(250.0, 600.0)))
	_temblor = 0.2
	_sonar($SonidoGolpe, hojas_golpe_db - 5.0, 1.15)

## Acaba la cinematica: el baculo queda en la mano (el sistema del baston) con
## la bola vacia, y el jugador vuelve a tener el mando.
func _acabar_coger() -> void:
	_cogiendo = false
	_baculo.visible = false
	var b: Node2D = BASTON_EN_MANO.instantiate()
	b.set("magia", 0.0)
	b.set("magia_recarga", 0.0)
	_magnus.add_child(b)
	b.set("_mostrada", 0.0)
	b.call("poner_en_mano", true)
	_magnus.soltar_cinematica()

## PRUEBA del bosque de fondo. Al alcanzar el baculo (de momento, lo que hace
## de cogerlo) una racha enorme: barre el lecho de izquierda a derecha
## levantando hojas (camino_hojas_lecho), arrastra las que caen y, en el fondo,
## se lleva las que tapaban el camino (camino_hojas_fondo: pequenas, que estan
## lejos), que aparece en camino_abrir s. El usuario: "un mega efecto para que
## las hojas dejen verlo".
func _abrir_camino() -> void:
	if not bosque_de_fondo:
		return
	_racha_dir = 1.0
	_racha_espera = maxf(_racha_espera, camino_abrir + 9.0)   # que no la pise otra
	var tw := create_tween()
	tw.tween_property(self, "_racha", 2.6, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(1.6)
	tw.tween_property(self, "_racha", 0.0, camino_abrir + 1.5).set_trans(Tween.TRANS_SINE)
	var tl := create_tween()
	tl.tween_property(self, "_levante", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tl.tween_interval(2.0)
	tl.tween_property(self, "_levante", 0.0, 2.2).set_trans(Tween.TRANS_SINE)
	_sonar($SonidoLevantarse, hojas_levantarse_db + 4.0, 0.85)
	var m := $Bosque.material as ShaderMaterial
	var tc := create_tween()
	tc.tween_interval(0.6)
	tc.tween_method(func(v: float) -> void: m.set_shader_parameter("camino", v),
			0.0, 1.0, camino_abrir).set_trans(Tween.TRANS_SINE)
	# el lecho, barrido de izquierda a derecha en 1,4 s
	var tramos := 28
	for i in tramos:
		get_tree().create_timer(0.15 + 1.4 * i / float(tramos)).timeout.connect(
				_barrer_lecho.bind(2912.0 * i / tramos, 2912.0 * (i + 1) / tramos, camino_hojas_lecho / tramos))
	# las del camino, en el fondo
	for i in camino_hojas_fondo:
		get_tree().create_timer(randf_range(0.3, camino_abrir + 0.5)).timeout.connect(func() -> void:
			# a lo largo del camino: de abajo a la izquierda a arriba a la derecha;
			# pequenas (migas: no se apilan al caer, que son del fondo) y algo
			# claras, que se vean volar en lo oscuro
			var u := randf()
			var p := Vector2(lerpf(2280.0, 2900.0, u) + randf_range(-30.0, 30.0),
					lerpf(1110.0, 850.0, u) + randf_range(-25.0, 25.0))
			var h: Dictionary = _detras.soltar(p, Vector2(randf_range(160.0, 420.0), -randf_range(80.0, 260.0)),
					randf_range(0.09, 0.155))
			h["tono"] = randf_range(1.5, 2.1))

## La racha levanta hojas del lecho entre x0 y x1 (las de arriba, dejando
## siempre unas pocas en cada columna) y se las lleva hacia la derecha.
func _barrer_lecho(x0: float, x1: float, n: int) -> void:
	for capa in [_delante, _detras]:
		for h in capa.tomar(x0, x1, n / 2 + 1, 3, 0.7):
			capa.lanzar(h, Vector2(randf_range(300.0, 800.0), -randf_range(500.0, 1100.0)))

## Distancia entre dos segmentos (a-b y c-d) en el plano.
static func _distancia_segmentos(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	var m := minf(_al_segmento(a, c, d), _al_segmento(b, c, d))
	return minf(m, minf(_al_segmento(c, a, b), _al_segmento(d, a, b)))

static func _al_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## La musica de fondo entra desde el silencio (ver musica_db). Una vez.
func _empezar_musica() -> void:
	var m: AudioStreamPlayer = $Musica
	if m.playing:
		return
	m.volume_db = -60.0
	m.play()
	create_tween().tween_property(m, "volume_db", musica_db, musica_entrada).set_trans(Tween.TRANS_SINE)

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

# --- La luz que aligera ------------------------------------------------------

var _haz_origen := Vector2(1620.0, -700.0)
var _haz_destino := Vector2(1456.0, 1200.0)
var _haz_apertura := 0.17

## El haz de la fisica es el que se ve: se leen del material del fondo su
## vertice, adonde apunta y su apertura.
## La fuerza del haz que se dibuja: la del shader, por haz_con_bosque si hay
## bosque detras.
var _haz_fuerza_base := -1.0
var _fondo_mat: ShaderMaterial   # el del Fondo (que luego se va a una SubViewport)

func _poner_haz() -> void:
	var m := _fondo_mat
	if m == null:
		return
	if _haz_fuerza_base < 0.0:
		var f: Variant = m.get_shader_parameter("haz_fuerza")
		_haz_fuerza_base = float(f) if f != null else 0.16
	m.set_shader_parameter("haz_fuerza", _haz_fuerza_base * (haz_con_bosque if bosque_de_fondo else 1.0))

func _leer_haz() -> void:
	var m := $Fondo.material as ShaderMaterial
	if m == null:
		return
	for p in [["haz_origen", "_haz_origen"], ["haz_destino", "_haz_destino"], ["haz_apertura", "_haz_apertura"]]:
		# Sin valor en el material, el que trae el shader.
		var valor: Variant = m.get_shader_parameter(p[0])
		if valor == null and m.shader:
			valor = RenderingServer.shader_get_parameter_default(m.shader.get_rid(), p[0])
		if valor != null:
			set(p[1], valor)

## Cuanta luz del haz hay en un punto de la escena (0..1) para jugar: el cono
## de fondo_haz.gdshader, entero hasta luz_entera de su apertura y nada desde
## luz_borde (ver La luz). Es la ligereza de Magnus: donde vale 1, sus saltos
## flotan del todo.
func luz_en(p: Vector2) -> float:
	var eje := (_haz_destino - _haz_origen).normalized()
	var a := acos(clampf(eje.dot((p - _haz_origen).normalized()), -1.0, 1.0))
	return 1.0 - smoothstep(_haz_apertura * luz_entera, _haz_apertura * luz_borde, a)

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
		if _con_mando >= 0.0:
			_vueltas += 1
			if _vueltas == 1:
				_pensar.decir("vuelta", true)
	x = _magnus.position.x
	var lado := ANCHO if x < 260.0 else (-ANCHO if x > ANCHO - 260.0 else 0.0)
	_fantasma.visible = lado != 0.0
	if not _fantasma.visible:
		return
	# (con el baston en la mano, Magnus lleva otras SpriteFrames)
	if _fantasma.sprite_frames != _sprite.sprite_frames:
		_fantasma.sprite_frames = _sprite.sprite_frames
	if _fantasma.animation != _sprite.animation:
		_fantasma.animation = _sprite.animation
	_fantasma.frame = _sprite.frame
	_fantasma.flip_h = _sprite.flip_h
	_fantasma.offset = _sprite.offset
	_fantasma.global_position = _sprite.global_position + Vector2(lado, 0.0)

# --- Historia ----------------------------------------------------------------

## Si en un minuto no ha salido por ningun borde, una vez: "No puedo quedarme
## aqui..."
func _animar_a_explorar(delta: float) -> void:
	if _con_mando < 0.0 or _vueltas > 0 or _pensar.dicho("explorar"):
		return
	_con_mando += delta
	if _con_mando > explorar_tras and not _pensar.hablando():
		_pensar.decir("explorar")

func _al_levantarse() -> void:
	_con_mando = 0.0
	_empezar_musica()
	get_tree().create_timer(espera_despertar).timeout.connect(_pensar.decir.bind("despertar"))

## Acabada la vuelta ("¿Es la luz de antes?"), la luz contesta: baja el baculo
## y el se asombra. La vuelta es una sola frase (~6 s desde que cruza el
## borde): con tres eran ~15 s y el jugador ya no miraba.
func _al_terminar_pensamiento(clave: String) -> void:
	if clave == "vuelta":
		get_tree().create_timer(espera_baculo).timeout.connect(_bajar_baculo)

func _bajar_baculo() -> void:
	if _baculo_bajando:
		return
	_baculo_bajando = true
	_baculo.bajar()
	empezar_escalera()
	_sonar($SonidoHilo, hilo_db)

## Ya flotando arriba, lo reconoce.
func _al_posar_baculo() -> void:
	get_tree().create_timer(1.2).timeout.connect(_pensar.decir.bind("baculo"))
