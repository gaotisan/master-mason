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
## de Midjourney (raw/master_mason/hojarasca_bosque/bosque_hojarasca.png) en dos
## planos (bosque_cerca.png y bosque_lejos.png, de capas.py) detras del haz, en
## sombra (Bosque, bosque_fondo.gdshader). Antes se probaron una de Gemini y
## una facetada, ya borradas.
## scenes/dev/prueba_bosque.tscn lo prueba con el baculo ya bajando.
@export var bosque_de_fondo: bool = false:
	set(v):
		bosque_de_fondo = v
		if is_node_ready():
			_poner_bosque()
			_poner_haz()
## Con el bosque, el haz un pelin mas fuerte (por esto la fuerza del dibujo de
## fondo_haz.gdshader): delante de los arboles tiene que seguir siendo lo que
## brilla (el usuario, 2026-10-13: "que se vea un pelin mas").
@export var haz_con_bosque: float = 1.35
## EL BOSQUE SE APAGA CON EL BACULO (2026-10-17; el usuario, viendo la escena
## de pruebas sin bosque: "es agradable de ver... cuando va bajando el baculo
## se oscurece progresivamente el fondo y llegamos a una escena sin el fondo o
## muy atenuado, donde lo importante es la luz y el baculo; cuando lo
## conseguimos coger, en el efecto vuelve a salir el fondo y ya sale el camino
## revelado"). Al empezar a bajar el baculo el bosque baja a bosque_atenuado en
## bosque_apagar s; al cogerlo, con el destello, vuelve entero en bosque_volver
## s mientras la racha abre el camino. El refuerzo del haz con bosque
## (haz_con_bosque) va con lo que se ve de el.
## bosque_atenuado 0: la oscuridad del fondo con el haz y nada mas, como la
## escena de pruebas (el usuario: "me gustaba esa tonalidad y luz... me daba
## como paz, no se si me gustara intuir los troncos detras"; con 0,08 se
## intuian).
@export_range(0.0, 1.0) var bosque_atenuado: float = 0.0
@export var bosque_apagar: float = 4.0
@export var bosque_volver: float = 2.5
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
## Volviendo del camino del bosque (un corte de camara, alli no sopla): el viento
## vuelve en viento_corte s, que se note el sitio (la musica sigue igual).
@export var viento_corte: float = 1.5
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
## Por la luz bajan hojas despacio (ver Las hojas de la luz; las que sirven,
## desde que baja el baculo): nadie dice que sirvan; pisando de una en otra, a
## izquierda y derecha, se sube hasta el baculo. Alcanzarlo es cogerlo (ver
## Coger el baculo): destello, racha que abre el camino y baja con el.
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
## CAMBIO DE MUSICA AL COGER EL BACULO (2026-10-16; el usuario: que cambie a la
## musica de la escena siguiente, "y asi el corte de camara ya no conlleva
## cambio de musica"). En la quietud del agarre esta se aparta (final_musica)
## y ya no vuelve: se va en cambio_musica s mientras entra, con el remolino, la
## del camino del bosque (MusicAmbience: sigue por el corte sin empezar de
## nuevo). Aqui va a musica_camino_db, que suena tan fuerte como esta a
## musica_db (medido en LUFS: la del camino es 2 dB mas baja de por si); en el
## bosque, sin viento, baja a su nivel en unos segundos. Volviendo del camino,
## o con la hojarasca ya resuelta, suena la del camino.
@export var musica_camino_db: float = -12.0
@export var cambio_musica: float = 4.0

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
## mano (el sistema del baston, scenes/characters/baston.tscn, con la magia a cero
## y sin recarga: en la mano solo anda) y la garra vacia, sin bola (la de la
## cinematica se vacia y se va; ver SIN MAGIA en baston.gd).
@export var coger_cae: int = 40
@export var coger_flota: float = 0.15
@export var coger_descarga: float = 1.5
## LA LUZ SE APAGA (2026-10-14; el usuario: "al coger el baston, con el
## torbellino, la luz y las hojas que caen por ahi desaparecen y queda el fondo
## sin la luz, oscuro, cayendo las hojas normales"). Desde luz_apagar_tras s
## tras el agarre, en luz_apagar s: el haz, su reflejo en el bosque, la mancha
## de luz del suelo y de las hojas, la niebla calida, las motas, la luz sobre
## Magnus y lo que aligera (ya no se flota). Las hojas de la escalera se sueltan
## y caen como las demas, y dejan de bajar las de la luz; las de los arboles
## siguen. Con el, el peregrino cae (coger_cae): la luz pierde su espesor.
@export var luz_apagar_tras: float = 1.5
@export var luz_apagar: float = 2.4
## EL FINAL DEL AGARRE (2026-10-14; el usuario eligio "las mejoras": remolino de
## verdad, el haz se retira y la quietud; las motas de la bola volando al
## sendero se probaron y se quitaron: "un poco cutres"):
## agarre_quietud: el medio segundo de quietud del guion (1.7): las hojas se
##   quedan quietas en el aire y el haz da un destello (agarre_destello: cuanto
##   se avivan el haz y su luz en el bosque); luego todo se suelta con la racha,
##   un tiron de camara y el remolino.
@export var agarre_quietud: float = 0.5
@export var agarre_destello: float = 1.4
## El remolino (hojas_voladoras.gd: EL REMOLINO) cruza el claro de remolino_desde
## a remolino_hasta en remolino_dura s, levantando las hojas del lecho por donde
## pasa (camino_hojas_lecho en total), y al apagarse las despide a la derecha.
@export var remolino_desde: float = 250.0
@export var remolino_hasta: float = 2750.0
@export var remolino_dura: float = 3.2
## Hojas del lecho que levanta en total. Con las 600 del barrido de antes
## llegaban a volar ~1.200 a la vez (las del remolino no caen) y la fisica no
## daba abasto: el final iba a 5 fps y a camara lenta (2026-10-14).
@export var remolino_hojas: int = 280
## LA CAMARA DEL FINAL (2026-10-14; "otra vuelta de tuerca para que quede
## profesional"): en la quietud se acerca (final_acerca, sobre el zoom de
## siempre); con el remolino sigue hacia el sendero (final_hacia: px de lado y
## final_acerca2 de zoom, para que el borde de la imagen no asome) y, ya con el
## mando, vuelve sola en final_vuelve s.
@export var final_acerca: float = 0.05
@export var final_acerca2: float = 0.085
@export var final_hacia: float = 120.0
@export var final_vuelve: float = 3.5
## Sonido del final: la musica baja final_musica dB en la quietud y con el
## remolino da paso a la del camino (ver musica_camino_db); la nota del hilo,
## grave (final_nota de tono), al agarrarlo.
@export var final_musica: float = -10.0
@export var final_nota: float = 0.5
## LA SALIDA POR EL CAMINO (2026-10-15; el usuario: "si el usuario avanza y
## llega a la altura del camino, el juego toma el control (a lo Broken Sword) y
## el peregrino entra por el camino"). Con el camino abierto, en su boca
## (salida_x, a la altura del lecho), ARRIBA (2026-10-15; el usuario: "lo ideal
## seria entrar cuando le demos a la tecla de arriba, ya que no tiene sentido
## saltar"; antes entraba solo al llegar y, volviendo del camino, costaba volver
## a entrar): a menos de salida_boca px, arriba no salta (salto_bloqueado de
## magnus.gd, como junto a una puerta) y el juego toma el mando: se para donde
## este (magnus.gd: andar_hasta), se vuelve de espaldas y se aleja por el camino
## con la toma de frente (el baston como lo lleve, en la mano o a la espalda);
## al adentrarse en la bruma, corte de camara a camino_bosque (que se va
## cargando desde que se le quita el mando), sin negro: el usuario, "para darle
## continuidad al mundo" (la vuelta, igual).
@export var salida_x: float = 2440.0
@export var salida_boca: float = 170.0
## Donde se pierde el camino con la camara sin mover (el fondo lejano va con la
## camara: paralaje_lejos de bosque_fondo.gdshader). Los pies van de donde se
## para hacia aqui, en linea recta y a la escala de la toma.
@export var salida_fuga: Vector2 = Vector2(2380.0, 1005.0)
## La musica se aparta estos s antes del corte (en seco sonaba a golpe; como
## hace camino_bosque al volver).
@export var salida_musica: float = 0.6
## La toma de frente (scenes/characters/peregrino_frontal.tscn, el peregrino de
## frente de todo el juego), a salida_escala. Del de perfil a ella y al reves, por
## los puentes de PuentePerfil (scripts/characters/puente_perfil.gd: el fotograma
## de la vuelta o del giro en que se sigue y a cuantos px van los dos, en su
## ficha; los puentes estan hechos con el frontal a 0,98). Adentrandose, al bajar
## de salida_hasta de escala (entra en la bruma), el corte.
@export var salida_escala: float = 0.98
@export var salida_hasta: float = 0.78
## Desde la toma de frente se puede volver al de perfil (abajo hasta la boca, o
## los lados en ella). Apagado (2026-10-17): el paso de frente al perfil no casa
## (el usuario: "que no pueda volver a la hojarasca, se quede ahi"); el de
## espaldas al perfil si, pero tambien es volver.
@export var volver_al_perfil := false
## Volviendo de camino_bosque, la escala a la que aparece en la bruma.
@export var salida_entra: float = 0.7

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
## Pisar: px a cada lado de los pies (mas el medio ancho de la hoja; 2026-10-14:
## 28, la planta y algo, en vez de 46: "a veces parece que no toca la hoja y
## rebota"), margen
## por encima de los pies del tick anterior (poco: una hoja que cae sobre las
## piernas no se pisa, hay que bajar sobre ella) y por debajo de los de ahora, luz
## minima en la hoja para que aguante, y altura minima de los pies (casi en el
## suelo, la hoja ya va a posarse).
@export var pisar_ancho: float = 28.0
@export var pisar_margen: Vector2 = Vector2(4.0, 2.0)
@export var pisar_luz: float = 0.35
@export var pisar_altura: float = 30.0
## Hasta cuanto por debajo de los pies (px) mira la hoja que pisara al bajar
## flotando (magnus.gd: hoja_debajo; estira las piernas al acercarse), y en
## cuanto (s, la mitad del camino) se pone la hoja pisada bajo su pie.
@export var pisar_mira: float = 260.0
@export var pisar_centrar: float = 0.05
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
## (Solo sin la animacion de cogerlo; con ella, ver coger_margen.)
@export var alcance: float = 30.0
@export var cuerpo_alcance: Vector2 = Vector2(160.0, 270.0)
## COGERLO A LA PAR (2026-10-14). El usuario: "se activa solo el coger el
## baston, que no me parece mal, pero lo hace mucho antes de llegar; hay un
## mega salto raro; tendria que hacerlo cuando este a la par". Con la vara (que
## cuelga bajo la bola) lo cogia en cuanto la cabeza la rozaba, y la cinematica
## le ponia la mano en la bola de golpe: hasta ~120 px de lado y lo que faltara
## de alto. Ahora lo coge cuando la mano (la de coger_baculo en su primer
## fotograma, con los pies donde estan) llega a menos de coger_margen de la
## bola (x de lado, y de alto), y lo que falte lo corrige en coger_ajuste s,
## con la bola yendo a la mano.
## 2026-10-15 (el usuario: "super complicado cogerlo; cuando saltamos y estamos
## a su altura o un poco mas bajo deberia coger"): por encima de la bola sigue
## coger_margen.y; por debajo, hasta coger_bajo px. Cuanto mas lejos, mas tarda
## el ajuste (coger_ajuste mas 1 s por cada coger_ajuste_px), que no de un tiron.
@export var coger_margen: Vector2 = Vector2(85.0, 36.0)
@export var coger_bajo: float = 95.0
@export var coger_ajuste: float = 0.3
@export var coger_ajuste_px: float = 400.0

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
const SALIDA_ESCENA := "res://scenes/game/camino_bosque.tscn"
const PEREGRINO_FRONTAL := preload("res://scenes/characters/peregrino_frontal.tscn")
## Como deja al peregrino para la escena siguiente (baston y magia) y de donde
## viene al entrar; y lo ya hecho en la partida (hojarasca_resuelta).
const PEREGRINO_ESTADO := preload("res://scripts/characters/peregrino_estado.gd")
const PARTIDA := preload("res://scripts/game/partida.gd")
const FONDO_Z := -10
## El baston en la mano tras cogerlo (ver coger_cae).
const BASTON_EN_MANO := preload("res://scenes/characters/baston.tscn")
## Lo que se carga a mano (las hojas de flotar en magnus.gd _cargar_flotar y las
## del baston en la mano en baston.gd): con preload son dependencias de la
## escena y entran en la carga en segundo plano del titulo; si no, se cargaban
## al abrir la escena o al coger el baculo, con el juego parado.
const _PRECARGA := [
	preload("res://assets/characters/magnus/magnus_flotar_bajar.png"),
	preload("res://assets/characters/magnus/magnus_flotar_posarse.png"),
	preload("res://assets/characters/magnus/magnus_flotar_girar.png"),
	preload("res://assets/characters/magnus/magnus_flotar_pisar.png"),
	preload("res://assets/characters/magnus/magnus_flotar_despegar.png"),
	preload("res://assets/characters/magnus/magnus_flotar_llegar.png"),
	preload("res://assets/characters/magnus/magnus_flotar_quieto.png"),
	preload("res://assets/characters/magnus/magnus_coger_baculo.png"),
	preload("res://assets/characters/baston/mano_reposo.png"),
	preload("res://assets/characters/baston/mano_arranque_andar.png"),
	preload("res://assets/characters/baston/mano_andar.png"),
	preload("res://assets/characters/baston/mano_parada_andar.png"),
	preload("res://assets/characters/baston/mano_giro.png"),
	preload("res://assets/characters/baston/mano_sacar_baston.png"),
	preload("res://assets/characters/baston/mano_guardar_baston.png"),
]

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
var _coger_x0 := 0.0                    # de donde viene al empezar (ver coger_ajuste)
var _coger_ajuste_t := 0.3              # lo que dura ese ajuste esta vez
var _coger_xt := 0.0
var _coger_alto0 := 0.0
var _coger_bola0 := Vector2.ZERO
var _baston_mano: Node2D                # el de la mano, preparado y escondido (ver _preparar_baston)
var _luz_viva := 1.0                    # lo que queda del haz (ver luz_apagar)
var _destello := 0.0                    # el del agarre (ver agarre_destello)
var _remolino_t := -1.0                 # tiempo del remolino (ver remolino_dura); -1 sin remolino
var _remolino_x := 0.0
var _remolino_cuenta := 0.0             # hojas por levantar (fraccion que se arrastra)
var _cine_lado := 0.0                   # la camara del final: px de lado y zoom de mas
var _cine_zoom := 0.0
var _polvo_remolino: CPUParticles2D
var _camino_abierto := false            # cogido el baculo, su boca lleva a la escena siguiente
var _en_camino := false                 # en el sector del camino (ver EL SECTOR DEL CAMINO)
var _retenida := ""                     # llegando del corte: "frente" mientras siga pulsada arriba
var _lado_suelto := false               # entrando andando: izquierda/derecha no cuentan hasta soltarlas
var _parando := false                   # de frente hacia la boca: ya pidio parar en ella
var _parada_e := 0.0                    # la escala a la que se va a parar y la de cuando lo pidio (1/e)
var _parada_inv := 0.0
var _volviendo := false                 # en la boca de espaldas, abajo: se da la vuelta y al perfil
var _al_perfil_ya := false              # pasando al de perfil
var _cortando := false                  # ya va el corte a camino_bosque
var _frontal_dir := 1.0                 # el de frente espejado (-1) o no
var _sec_frontal: Dictionary = {}       # secuencia_frontal[_sin].json (los pies juntos de cada andar)
var _salida_carga := false              # camino_bosque pedida en segundo plano
var _cam_quieta := 0.0                  # 1: la camara deja de respirar (salida y entrada por el camino)
var _cam_fija := Vector2.ZERO
var _entra_ref := 0.98                  # entrando por el camino: la escala que va en la boca (ver _camino_tick)
var _frontal: Node2D                    # la toma de frente del sector del camino (PeregrinoFrontal)
var _resuelta := false                  # ya cogido el baculo en esta partida (ver _poner_resuelta)
var _en_boca := false                   # en la boca del camino: arriba entra (sin saltar)
var _frontal_luz: ShaderMaterial        # su magnus_luz (con el suelo donde pisa)

var _luz_apagada := false               # ya no bajan hojas por la luz
var _niebla_mat: ShaderMaterial         # el de NieblaSuelo (que se va a una SubViewport)
var _niebla_base := -1.0
var _bosque_haz_base := Vector2(-1.0, -1.0)  # la luz del haz en el bosque con la luz entera (bosque_en_el_haz y bosque_resplandor del fondo)
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
	_repartir_haz()
	_poner_haz()
	_a_baja_resolucion($Fondo, 4)
	_poner_bosque()
	_niebla_mat = $NieblaSuelo.material as ShaderMaterial
	_a_baja_resolucion($NieblaSuelo, 4)
	# El fondo, por debajo de todo: el baston de Magnus (scenes/characters/baston.tscn)
	# va con z_index -1 para quedar detras del cuerpo, y con el fondo en 0 se
	# quedaba tambien detras del fondo (con el baston en la mano no se veia la bola).
	for nombre in ["FondoImagen", "Bosque", "HojasLejanas", "Motas"]:
		(get_node(nombre) as CanvasItem).z_index = FONDO_Z
	var estado := PEREGRINO_ESTADO.leer(get_tree())
	WindAmbience.gust_db = 0.0
	WindAmbience.fade_to(viento_db, viento_corte if estado.get("viene_de", "") == "camino_bosque" else viento_subida)
	_magnus.position = $MagnusSpawn.position
	_ultima_x = _magnus.position.x
	_magnus.impacto.connect(_al_impacto)
	_magnus.pisada.connect(_al_pisar)
	_magnus.despega_de_hoja.connect(_al_despegar_de_hoja)
	_sprite.animation_changed.connect(_al_cambiar_animacion)
	# La luz de la escena sobre Magnus (sin tocar sus hojas ni su escena).
	var luz := ShaderMaterial.new()
	luz.shader = preload("res://scripts/game/magnus_luz.gdshader")
	luz.set_shader_parameter("haz_origen", _haz_origen)
	luz.set_shader_parameter("haz_destino", _haz_destino)
	luz.set_shader_parameter("haz_apertura", _haz_apertura)
	_sprite.material = luz
	_crear_fantasma()
	# tras el negro de la entrada (si la hay), el baston de la mano
	_resuelta = estado.get("viene_de", "") == "camino_bosque" or PARTIDA.ya(get_tree(), "hojarasca_resuelta")
	if not _resuelta:
		get_tree().create_timer(0.3).timeout.connect(_preparar_baston)
		MusicAmbience.apagar_camino(0.0)
	_magnus.pasos_db = magnus_pasos_db
	# En la luz se pesa poco: sus saltos de parado y andando flotan en el haz.
	_magnus.ligereza = luz_en
	_magnus.hoja_debajo = _hoja_debajo
	for capa in [_delante, _detras]:
		capa.ligereza = luz_en
		capa.gravedad_luz = _magnus.gravedad_luz
	# Pisar hojas mira a Magnus despues de que se mueva en el tick.
	process_physics_priority = 10
	_delante.sembrar(hojas_por_columna_delante, _monton.bind(0.6))
	_detras.sembrar(hojas_por_columna_detras, _monton.bind(0.4))
	if _resuelta:
		_poner_resuelta.call_deferred(estado)
	elif caida_al_empezar:
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
	if not _resuelta:
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
	_mirar_salida()
	_camino_tick()
	if _cogiendo:
		_coger_tick(delta)
	else:
		_seguir_a_magnus(delta)
	_vida_del_bosque(delta)
	_alumbrar_baston()
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
	_respira = (d + _sigue + Vector2(_cine_lado, 0.0)).lerp(_cam_fija, _cam_quieta)
	_camara.zoom = Vector2.ONE * camara_zoom * (1.0 + _cine_zoom)
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
	if _suelta_espera <= 0.0 and not _luz_apagada:
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
	_centrar_hoja_pisada(pies, delta)
	_pies_antes = pies.y
	_seguir_el_salto()
	_mirar_baculo(pies)
	_mover_remolino(delta)

## Donde quedan los pies (los de altura_pies) bajo el centro de la hoja al
## apoyarse en ella (magnus.gd: PISAR_EN_HOJA menos lo que levanta el pie en
## flotar_pisar). Se pisa cuando llegan ahi, no antes: con 10 px de margen por
## debajo se pisaba antes de tocarla y los pies bajaban de golpe (2026-10-14).
const PIES_EN_HOJA := 3.5

## Cae con los pies sobre una hoja de la luz: rebota y la hoja se hunde.
func _pisar_hoja(pies: Vector2) -> void:
	var y0 := minf(_pies_antes, pies.y) - pisar_margen.x - PIES_EN_HOJA
	var y1 := pies.y + pisar_margen.y - PIES_EN_HOJA
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

## La hoja que pisaria al bajar (la mas alta de las que tiene debajo, a menos de
## pisar_mira): su y, o INF. La usa magnus.gd para estirar las piernas al llegar.
func _hoja_debajo(pies: Vector2) -> float:
	var mejor := {}
	for capa in [_delante, _detras]:
		var h: Dictionary = capa.apoyo(pies.x, pies.y - pisar_margen.x, pies.y + pisar_mira, pisar_ancho, pisar_luz)
		if not h.is_empty() and (mejor.is_empty() or h["p"].y < mejor["p"].y):
			mejor = h
	if mejor.is_empty() or mejor["p"].y < escalera_aguanta:
		return INF
	return mejor["p"].y

## Apoyado en una hoja, la hoja se pone bajo su pie (el no la sigue de lado:
## ver PISAR LA HOJA SIN DESCUADRE en magnus.gd).
func _centrar_hoja_pisada(pies: Vector2, delta: float) -> void:
	if _hoja_pisada_capa == null or not _magnus.get("_pisando"):
		return
	var h: Dictionary = _magnus.get("_pisar_hoja")
	if h.is_empty():
		return
	var dx := wrapf(pies.x - h["p"].x, -ANCHO / 2.0, ANCHO / 2.0)
	h["p"].x += dx * (1.0 - exp(-delta * 0.693 / maxf(pisar_centrar, 0.001)))

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
## alcanzado: lo coge (coger_baculo; sin esa animacion, solo el destello y el
## camino).
func _mirar_baculo(pies: Vector2) -> void:
	if _alcanzado or not _baculo.flotando():
		return
	if _sprite.sprite_frames.has_animation(&"coger_baculo") and not _cogiendo:
		# COGERLO A LA PAR: la mano del primer fotograma, con los pies donde estan
		var d: Dictionary = _magnus.get("_flotar")["coger_baculo"]
		var punta: Vector2 = _baculo.punta()
		var dir := signf(punta.x - _magnus.position.x)
		if dir == 0.0:
			dir = _magnus.mirando()
		var g: Array = d["garra"][0]
		var alto_ahora: float = (_magnus.position.y - pies.y) - float(d["pies"][0])
		var mano := Vector2(_magnus.position.x + dir * float(g[0]), _magnus.position.y + float(g[1]) - alto_ahora)
		var bajo := mano.y - punta.y            # + : la mano por debajo de la bola
		if absf(wrapf(mano.x - punta.x, -ANCHO / 2.0, ANCHO / 2.0)) <= coger_margen.x \
				and bajo >= -coger_margen.y and bajo <= coger_bajo:
			_alcanzado = true
			_coger_baculo()
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
	# de donde parte (COGERLO A LA PAR): los pies donde estan
	var pies_alto: float = _magnus.altura_pies()
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
	_coger_x0 = _magnus.position.x
	_coger_xt = _coger_x0 + wrapf(punta.x - _coger_dir * float(g[0]) - _coger_x0, -ANCHO / 2.0, ANCHO / 2.0)
	_coger_alto = maxf(_magnus.position.y + float(g[1]) - punta.y, 0.0)
	_coger_alto0 = maxf(pies_alto - float(_coger_dat["pies"][0]), 0.0)
	_coger_bola0 = punta
	var falta := maxf(absf(_coger_xt - _coger_x0), absf(_coger_alto0 - _coger_alto))
	_coger_ajuste_t = coger_ajuste + falta / maxf(coger_ajuste_px, 1.0)
	_baculo.coger()
	_baculo.estallar()
	_baculo.descargar(coger_descarga)
	# EL FINAL DEL AGARRE: quietud con destello y, pasada la quietud, la racha y
	# el remolino (que cruza el haz aun encendido:
	# la luz se retira despues, ver luz_apagar_tras). Lo que pensaba al verlo
	# bajar se calla.
	_pensar.callar()
	_atenuar_bosque(1.0, bosque_volver)
	_quietud_del_agarre()
	get_tree().create_timer(agarre_quietud).timeout.connect(_abrir_camino)
	_apagar_luz()
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
	# lo que faltaba para la mano en la bola, en coger_ajuste s (COGERLO A LA PAR)
	var b := smoothstep(0.0, _coger_ajuste_t, _coger_t) if _coger_ajuste_t > 0.0 else 1.0
	alto = lerpf(_coger_alto0, alto, b)
	_magnus.position.x = lerpf(_coger_x0, _coger_xt, b)
	_ultima_x = _magnus.position.x
	_sprite.position.y = -alto
	var g: Array = d["garra"][k]
	var mano := _magnus.position + Vector2(_coger_dir * float(g[0]), float(g[1]) - alto)
	_baculo.bola_en(_coger_bola0.lerp(mano, b))
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
	_preparar_baston()
	_baston_mano.set("puesto", true)
	_baston_mano.call("poner_en_mano", true)
	_magnus.soltar_cinematica()
	_camino_abierto = bosque_de_fondo
	_resuelta = true
	PARTIDA.marcar(get_tree(), "hojarasca_resuelta")
	# al caer con el, lo piensa (el sendero ya esta encendido)
	get_tree().create_timer(0.8).timeout.connect(_pensar.decir.bind("camino"))
	# y la camara vuelve sola a lo de siempre
	var cam := create_tween().set_parallel()
	cam.tween_property(self, "_cine_lado", 0.0, final_vuelve).set_trans(Tween.TRANS_SINE).set_delay(1.2)
	cam.tween_property(self, "_cine_zoom", 0.0, final_vuelve).set_trans(Tween.TRANS_SINE).set_delay(1.2)

## B: sacar o guardar el baston a voluntad en cuanto lo tiene (el usuario,
## 2026-10-14; la misma tecla que en piloto_baston.gd). De parado, con la
## animacion de sacar o guardar; andando, en el sitio (baston.gd: alternar_mano).
## Con el baculo clavado no hace nada: el nodo de las acciones, que la ve antes,
## se la queda.
func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != KEY_B:
		return
	if _en_camino:
		# en el camino, el de frente (saca o guarda con su animacion)
		if _frontal and not _cortando and not _al_perfil_ya:
			get_viewport().set_input_as_handled()
			_frontal.call("pulsar_baston")
		return
	if _baston_mano == null or not _baston_mano.get("puesto") or _cogiendo:
		return
	get_viewport().set_input_as_handled()
	_baston_mano.call("alternar_mano")

## La luz de la escena sobre el baston a la espalda (2026-10-14; el usuario: "al
## guardarlo a la espalda se ilumina, estando vacio, no tiene sentido"). En la
## mano va en el dibujo de Magnus y le da magnus_luz.gdshader; a la espalda son
## sprites aparte (baston.tscn) y salian con su color de siempre, la garra
## dorada en el claro a oscuras. Se les tine con lo que ese shader le daria a
## Magnus donde esta el baston (su tinte, sin el borde ni el rebote).
const _BASTON_SOMBRA := Color(0.46, 0.37, 0.3)   # color_sombra de magnus_luz.gdshader
const _BASTON_LUZ := Color(1.0, 0.83, 0.6)       # color_luz
func _alumbrar_baston() -> void:
	if _baston_mano == null or not _baston_mano.get("puesto"):
		return
	var p: Vector2 = _baston_mano.global_position
	var dx := (p.x - _haz_destino.x) / 1050.0
	var dy := (p.y - _haz_destino.y) / 520.0
	var suelo := 0.28 + 0.87 * exp(-(dx * dx + 0.6 * dy * dy) * 1.6)
	var eje := (_haz_destino - _haz_origen).normalized()
	var a := acos(clampf(eje.dot((p - _haz_origen).normalized()), -1.0, 1.0))
	var haz := 0.28 + 0.8 * (1.0 - smoothstep(_haz_apertura * 0.35, _haz_apertura, a))
	var l := lerpf(0.28, maxf(suelo, haz), smoothstep(0.68, 0.9, _luz_viva))
	var t := clampf((l - 0.28) / 0.87, 0.0, 1.0)
	var c := _BASTON_SOMBRA.lerp(_BASTON_LUZ, t) * (0.8 + 0.3 * t)
	for ruta in ["Madera", "MaderaDelante", "FundaAtras", "FundaDelante", "Madera/Funda"]:
		var n := _baston_mano.get_node_or_null(ruta) as CanvasItem
		if n == null:
			continue
		# solo el color: el alfa lo lleva baston.gd (fundidos y cortes)
		if ruta == "Madera":
			n.self_modulate = Color(c.r, c.g, c.b, n.self_modulate.a)
		else:
			n.modulate = Color(c.r, c.g, c.b, n.modulate.a)

## El baston que tendra en la mano, preparado al abrir la escena (tras el negro
## de la entrada) y escondido (puesto = false): crearlo al coger el baculo
## (lee sus json, duplica las SpriteFrames de Magnus y monta las de la mano)
## paraba el juego ~0,8 s justo al devolver el mando. Sin magia: la bola vacia.
func _preparar_baston() -> void:
	if _baston_mano != null:
		return
	var b: Node2D = BASTON_EN_MANO.instantiate()
	b.set("puesto", false)
	b.set("magia", 0.0)
	b.set("magia_recarga", 0.0)
	_magnus.add_child(b)
	b.set("_mostrada", 0.0)
	_baston_mano = b

## La quietud del agarre: las hojas y las motas del haz se quedan quietas en el
## aire agarre_quietud s, el haz da un destello, y al soltarse, un tiron de
## camara.
func _quietud_del_agarre() -> void:
	for capa in [_delante, _detras]:
		capa.pausa = agarre_quietud
	$Motas.speed_scale = 0.0
	# la camara se acerca en la quietud y luego acompana al remolino al sendero
	var cam := create_tween()
	cam.tween_property(self, "_cine_zoom", final_acerca, agarre_quietud).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	cam.tween_property(self, "_cine_zoom", final_acerca2, remolino_dura).set_trans(Tween.TRANS_SINE)
	var lado := create_tween()
	lado.tween_interval(agarre_quietud)
	lado.tween_property(self, "_cine_lado", final_hacia, remolino_dura).set_trans(Tween.TRANS_SINE)
	# los bordes se cierran un poco mientras todo se para
	var pase := $Gradacion/Pase.material as ShaderMaterial
	var vineta0 := _parametro(pase, "vineta")
	var vin := create_tween()
	vin.tween_method(func(x: float) -> void: pase.set_shader_parameter("vineta", x), vineta0, vineta0 + 0.2, 0.15)
	vin.tween_interval(agarre_quietud - 0.15)
	vin.tween_method(func(x: float) -> void: pase.set_shader_parameter("vineta", x), vineta0 + 0.2, vineta0, 1.6).set_trans(Tween.TRANS_SINE)
	# la musica se aparta y, con el remolino, da paso a la del camino; la nota
	# del hilo, grave
	var musica: AudioStreamPlayer = $Musica
	if musica.playing:
		var mu := create_tween()
		mu.tween_property(musica, "volume_db", musica_db + final_musica, 0.12)
		mu.tween_interval(agarre_quietud)
		mu.tween_property(musica, "volume_db", -60.0, cambio_musica).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		mu.tween_callback(musica.stop)
	MusicAmbience.sonar_camino(musica_camino_db, cambio_musica, agarre_quietud)
	_sonar($SonidoHilo, hilo_db, final_nota)
	var tw := create_tween()
	tw.tween_method(_poner_destello, 0.0, 1.0, 0.06)
	tw.tween_interval(agarre_quietud - 0.06)
	tw.tween_callback(func() -> void:
		$Motas.speed_scale = 1.0
		_temblor = 0.22)
	tw.tween_method(_poner_destello, 1.0, 0.0, 0.6).set_trans(Tween.TRANS_SINE)

## El remolino, cada tick: avanza por el claro, levanta hojas del lecho bajo el
## y lo pasa a las capas de hojas (ver EL REMOLINO en hojas_voladoras.gd).
func _mover_remolino(delta: float) -> void:
	if _remolino_t < 0.0:
		return
	_remolino_t += delta
	var u := clampf(_remolino_t / maxf(remolino_dura, 0.01), 0.0, 1.0)
	var x := lerpf(remolino_desde, remolino_hasta, u * u * (3.0 - 2.0 * u))
	var vel := (x - _remolino_x) / maxf(delta, 0.001)
	_remolino_x = x
	var f := smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.82, 1.0, u))
	for capa in [_delante, _detras]:
		capa.remolino = f
		capa.remolino_x = x
		capa.remolino_vel = vel
	# polvo que levanta en la base (el del golpe, sin parar mientras pasa)
	if _polvo_remolino == null:
		_polvo_remolino = $Polvo.duplicate() as CPUParticles2D
		_polvo_remolino.one_shot = false
		_polvo_remolino.explosiveness = 0.0
		_polvo_remolino.amount = 60
		_polvo_remolino.lifetime = 1.8
		_polvo_remolino.emission_rect_extents = Vector2(95.0, 8.0)
		_polvo_remolino.initial_velocity_min = 40.0
		_polvo_remolino.initial_velocity_max = 180.0
		_polvo_remolino.gravity = Vector2(0.0, -40.0)
		add_child(_polvo_remolino)
	_polvo_remolino.position = Vector2(x, $Polvo.position.y)
	_polvo_remolino.emitting = f > 0.25
	if f > 0.3:
		# las que tocan este tick (repartidas por lo que dura con fuerza), a medias
		# entre las dos capas
		_remolino_cuenta += float(remolino_hojas) * delta / maxf(remolino_dura * 0.7, 0.01)
		var n := floori(_remolino_cuenta)
		_remolino_cuenta -= n
		for capa in [_delante, _detras]:
			for h in capa.tomar(x - 110.0, x + 110.0, (n + 1) / 2, 3, 0.8):
				capa.lanzar(h, Vector2(randf_range(-60.0, 60.0), -randf_range(250.0, 520.0)))
	if u >= 1.0:
		_remolino_t = -1.0
		_polvo_remolino.emitting = false
		for capa in [_delante, _detras]:
			capa.remolino = 0.0

## Al coger el baculo, una racha enorme: barre el lecho de izquierda a derecha
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
	# el lecho: el remolino lo cruza de izquierda a derecha y se lleva las hojas
	# (antes, un barrido recto en 1,4 s: ver _barrer_lecho)
	_remolino_t = 0.0
	_remolino_x = remolino_desde
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

## Con el bosque, el fondo va dentro de su shader (bosque_fondo.gdshader: lo
## lee y le suma el bosque en la misma pasada) y no se pinta aparte; sin el,
## se pinta el fondo solo.
func _poner_bosque() -> void:
	var imagen := get_node_or_null("FondoImagen") as Sprite2D
	if imagen == null:
		return
	$Bosque.visible = bosque_de_fondo
	imagen.visible = not bosque_de_fondo
	($Bosque.material as ShaderMaterial).set_shader_parameter("fondo", imagen.texture)

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
	# al apagarse, el haz se retira hacia arriba (retiro en fondo_haz.gdshader) y
	# su fuerza solo cae al final; el destello del agarre lo aviva un instante
	m.set_shader_parameter("haz_fuerza", _haz_fuerza_base * (lerpf(1.0, haz_con_bosque, _bosque_presencia) if bosque_de_fondo else 1.0)
			* smoothstep(0.0, 0.25, _luz_viva) * (1.0 + agarre_destello * _destello))
	m.set_shader_parameter("retiro", 1.0 - _luz_viva)

## Lo que se ve del bosque (ver EL BOSQUE SE APAGA CON EL BACULO).
var _bosque_presencia := 1.0
var _bosque_tween: Tween

func _atenuar_bosque(hasta: float, segundos: float) -> void:
	if not bosque_de_fondo:
		return
	if _bosque_tween != null:
		_bosque_tween.kill()
	_bosque_tween = create_tween()
	_bosque_tween.tween_method(_poner_presencia_bosque, _bosque_presencia, hasta, segundos).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _poner_presencia_bosque(v: float) -> void:
	_bosque_presencia = v
	($Bosque.material as ShaderMaterial).set_shader_parameter("presencia", v)
	_poner_haz()

## El haz es uno: el del material del fondo (_leer_haz). Se le pasa a lo que
## lo usa (antes cada uno tenia su copia: cambiar el haz en uno sacaba al
## baculo del haz o dejaba las hojas mal iluminadas).
func _repartir_haz() -> void:
	# (la luz del haz en el bosque la pone el propio fondo: fondo_haz.gdshader)
	_baculo.poner_haz(_haz_origen, _haz_destino)
	for capa in [$HojasDelante, $HojasDetras]:
		capa.poner_haz(_haz_origen, _haz_destino, _haz_apertura)
	# el suelo pintado del lecho lleva la luz cocida: su shader la quita al
	# apagarse el haz (ver luz_apagar)
	var lecho := ShaderMaterial.new()
	lecho.shader = preload("res://scripts/game/lecho_luz.gdshader")
	lecho.set_shader_parameter("haz_origen", _haz_origen)
	lecho.set_shader_parameter("haz_destino", _haz_destino)
	lecho.set_shader_parameter("haz_apertura", _haz_apertura)
	$Lecho.material = lecho

## Lleva la luz del haz (0 apagado, 1 entero) a todo lo que la usa (ver
## luz_apagar).
## EL HAZ SE RETIRA (2026-10-14; el usuario: "hazme las mejoras" del final):
## en vez de apagarse entero a la vez, el haz se recoge de abajo arriba hacia el
## cielo (retiro = 1 - v en fondo_haz.gdshader). Lo que esta en el suelo (el
## lecho, sus hojas, la bruma, el peregrino) se queda a oscuras cuando el corte
## pasa por el suelo, al principio; las motas del haz, a medio camino.
func _poner_luz_viva(v: float) -> void:
	_luz_viva = v
	_aplicar_luz()

## El destello del agarre (0..1, ver agarre_destello): aviva el haz un instante.
func _poner_destello(d: float) -> void:
	_destello = d
	_aplicar_luz()

func _aplicar_luz() -> void:
	var v := _luz_viva
	_poner_haz()
	if _bosque_haz_base.x < 0.0:
		_bosque_haz_base = Vector2(_parametro(_fondo_mat, "bosque_en_el_haz"), _parametro(_fondo_mat, "bosque_resplandor"))
	var aviva := smoothstep(0.0, 0.25, v) * (1.0 + agarre_destello * _destello)
	_fondo_mat.set_shader_parameter("bosque_en_el_haz", _bosque_haz_base.x * aviva)
	_fondo_mat.set_shader_parameter("bosque_resplandor", _bosque_haz_base.y * aviva)
	var suelo := smoothstep(0.68, 0.9, v)
	if _niebla_mat:
		if _niebla_base < 0.0:
			_niebla_base = _parametro(_niebla_mat, "fuerza")
		_niebla_mat.set_shader_parameter("fuerza", _niebla_base * lerpf(0.25, 1.0, suelo))
	$Motas.modulate.a = smoothstep(0.3, 0.8, v)
	# y suben con ella: el polvo del haz se va hacia arriba
	$Motas.gravity = Vector2(3.0, 4.0).lerp(Vector2(0.0, -120.0), 1.0 - v)
	($Lecho.material as ShaderMaterial).set_shader_parameter("luz_viva", suelo)
	(_sprite.material as ShaderMaterial).set_shader_parameter("luz_viva", suelo)
	for capa in [_delante, _detras]:
		capa.luz_viva = suelo

## Un parametro del material, o el del shader si el material no lo pone.
static func _parametro(m: ShaderMaterial, nombre: String) -> float:
	var v: Variant = m.get_shader_parameter(nombre)
	if v == null and m.shader:
		v = RenderingServer.shader_get_parameter_default(m.shader.get_rid(), nombre)
	return float(v) if v != null else 0.0

## Al coger el baculo el haz se apaga (ver luz_apagar): las hojas de la
## escalera caen como las demas y dejan de bajar las de la luz.
func _apagar_luz() -> void:
	_luz_apagada = true
	_escalera = false
	for h in _hojas_luz:
		h.erase("sitio")
		h.erase("entrando")
		h["ligera"] = false
		h["de_fuera"] = true
		h["v"] = Vector2(randf_range(-20.0, 20.0), 30.0)
	_hojas_luz.clear()
	var tw := create_tween()
	tw.tween_interval(luz_apagar_tras)
	tw.tween_method(_poner_luz_viva, 1.0, 0.0, luz_apagar).set_trans(Tween.TRANS_SINE)

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
	if _luz_viva <= 0.0:
		return 0.0
	var eje := (_haz_destino - _haz_origen).normalized()
	var a := acos(clampf(eje.dot((p - _haz_origen).normalized()), -1.0, 1.0))
	return (1.0 - smoothstep(_haz_apertura * luz_entera, _haz_apertura * luz_borde, a)) * _luz_viva

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

## EL SECTOR DEL CAMINO (2026-10-15). En la boca del camino (salida_x) el
## peregrino pasa a la toma de frente (PeregrinoFrontal) y ahi lo lleva el
## jugador como en camino_bosque (el usuario: "ese sector haria que lo moviera
## el usuario tambien, para delante y para atras, para que quede siempre de la
## misma forma"):
##   arriba     se adentra de espaldas; al entrar en la bruma (salida_hasta),
##              corte de camara a camino_bosque
##   abajo      vuelve hacia la camara y se para en la boca, de frente, y de ahi
##              no pasa: no se vuelve a la hojarasca (el usuario, 2026-10-17: el
##              paso de frente al perfil "no funciona", "que se quede ahi"); de
##              espaldas en la boca, se da la vuelta y lo mismo. Con
##              volver_al_perfil, como antes: en la boca sigue el de perfil con la
##              segunda mitad de su giro (puente frente_*)
##   izq./der.  nada (con volver_al_perfil: en la boca, al perfil; de espaldas,
##              por la ida al reves)
##   B          saca o guarda el baston (con sus animaciones de frente/espaldas)
## Se entra desde el perfil en la boca: la primera vez solo, al llegar andando
## (el usuario: "la primera vez que se meta solo en el camino, que no haga falta
## darle a arriba, luego ya normal"), y luego con arriba (ahi no salta:
## salto_bloqueado). Se para donde este, se da la vuelta de espaldas y se queda
## en posicion. Volviendo de camino_bosque aparece en la bruma (salida_entra) de
## frente y quieto; si llega con arriba pulsada (la que lo metio en la bruma
## alli), anda hacia la camara hasta soltarla: tras el corte de camara la tecla
## que se mantiene sigue llevandolo hacia donde iba.
const _DE_PIE := [&"reposo", &"arranque_andar", &"andar", &"parada_andar",
	&"arranque_correr", &"correr", &"parada_correr"]

## De perfil, en la boca del camino: la primera vez entra solo; despues, arriba.
func _mirar_salida() -> void:
	var falta := wrapf(salida_x - _magnus.position.x, -ANCHO / 2.0, ANCHO / 2.0)
	var boca := _camino_abierto and not _en_camino and not _cogiendo and absf(falta) <= salida_boca
	if boca != _en_boca:
		_en_boca = boca
		_magnus.salto_bloqueado = boca
	if not boca or _magnus.control_bloqueado or not _sprite.animation in _DE_PIE:
		return
	var primera := not PARTIDA.ya(get_tree(), "hojarasca_camino")
	var llega: bool = primera and _sprite.animation != &"reposo" and signf(falta) == _magnus.mirando()
	if llega or Input.is_action_just_pressed("saltar"):
		_entrar_al_camino()

## Se para donde este (en marcha, tras su parada: ir al centro de la boca no se
## puede afinar, con el baston en la mano la parada recorre 160-230 px), se da la
## vuelta de espaldas con la toma de frente y se queda en posicion.
func _entrar_al_camino() -> void:
	_en_camino = true
	_en_boca = false
	_magnus.salto_bloqueado = false
	_pensar.callar()
	PARTIDA.marcar(get_tree(), "hojarasca_camino")
	_pedir_camino()
	_magnus.andar_hasta(_magnus.position.x)
	await _magnus.llegado
	_cam_fija = _respira
	_cam_quieta = 1.0
	var dir: float = _magnus.mirando()
	var en_mano := bool(_baston_mano.get("en_mano"))
	# del perfil a la vuelta de la toma de frente por su puente (PuentePerfil): la
	# respiracion, antes, al fotograma de partida mas cercano de los puentes
	var modo := "cb" if en_mano else "sb"
	var v := PuentePerfil.variante(modo, _sprite.frame, _sprite.sprite_frames.get_frame_count(&"reposo"))
	await _respirar_hasta(v)
	var nombre := "ida_%s_r%02d" % [modo, v]
	var d := PuentePerfil.datos(nombre)
	var pies0 := _magnus.position
	# la toma de frente se crea ya (crearla al acabar el puente daba un tiron),
	# escondida y quieta, y sin que la lleve el jugador hasta que aparezca
	var f := _crear_frontal(en_mano, salida_escala, dir, Vector2(pies0.x + float(d["dx"]) * dir, pies0.y))
	f.visible = false
	f.set_process(false)
	_al_perfil_ya = true
	var puente := _puente_perfil()
	puente.jugar(nombre, false, pies0, Vector2(dir, 1.0), pies0, Vector2(dir, 1.0))
	_magnus.visible = false
	await puente.acabado
	if not is_instance_valid(f):
		return
	f.call("girar_desde_perfil", "espalda", int(d["sigue"]))
	f.set_process(true)
	f.visible = true
	_al_perfil_ya = false

## El de perfil, quieto, lleva su respiracion al fotograma f del reposo por el
## camino corto, a 24 fps (exhala o inspira deprisa; 0,2-0,3 s como mucho): de
## ahi salen los puentes al frontal.
func _respirar_hasta(f: int) -> void:
	if _sprite.animation != &"reposo":
		return
	var n := _sprite.sprite_frames.get_frame_count(&"reposo")
	_sprite.pause()
	while _sprite.frame != f and is_inside_tree():
		var d := posmod(f - _sprite.frame, n)
		_sprite.frame = posmod(_sprite.frame + (1 if d <= n / 2 else -1), n)
		await get_tree().create_timer(1.0 / 24.0, false).timeout
	_sprite.play()

## El nodo de los puentes perfil <-> frontal, con la luz del de perfil, en su sitio
## del arbol (justo tras el, como la toma de frente).
func _puente_perfil() -> PuentePerfil:
	var p := get_node_or_null("PuentePerfil") as PuentePerfil
	if p == null:
		p = PuentePerfil.new()
		p.name = "PuentePerfil"
		add_child(p)
		move_child(p, _magnus.get_index() + 1)
	p.material = _sprite.material
	return p

## Volviendo de camino_bosque: en la bruma del camino, de frente.
func _llegar_del_camino(con_baston: bool) -> void:
	_en_camino = true
	_magnus.visible = false
	_magnus.control_bloqueado = true
	var pies0 := Vector2(salida_x, _magnus.position.y)
	# el de perfil (escondido) ya en la boca: la camara y lo que lo sigue no
	# esperan a un sitio que no es
	_magnus.position = pies0
	_ultima_x = pies0.x
	_cam_fija = _respira
	_cam_quieta = 1.0
	_pedir_camino()
	_crear_frontal(con_baston, salida_entra, 1.0, pies0)
	_retenida = "frente" if Input.is_action_pressed("saltar") else ""

## La toma de frente en el sitio del de perfil (justo tras el en el arbol: las
## hojas de delante le tapan los pies como a el), espejada si dir es -1, con el
## baston como lo lleve (recien cogido, sin magia: sin bola, la garra vacia).
## Los pies van de pies0 a la fuga del camino, en recta, segun la escala.
func _crear_frontal(con_baston: bool, escala: float, dir: float, pies0: Vector2) -> Node2D:
	var f: Node2D = PEREGRINO_FRONTAL.instantiate()
	f.set("con_baston", con_baston)
	f.set("magia", _baston_mano.get("magia"))
	f.set("magia_recarga", _baston_mano.get("magia_recarga"))
	f.set("cara", "frente")
	f.set("escala_inicial", escala)
	# sus pisadas: las de la hojarasca, al nivel de las de aqui en la boca (el
	# componente las baja con la distancia: a pasos_db en pasos_escala_ref)
	f.set("pasos", ($SonidoPaso as AudioStreamPlayer).stream)
	f.set("pasos_db", hojas_paso_db + linear_to_db(float(f.get("pasos_escala_ref")) / salida_escala))
	_frontal_luz = (_sprite.material as ShaderMaterial).duplicate() as ShaderMaterial
	f.material = _frontal_luz
	f.scale.x = dir
	f.position = pies0
	var fuga := _fuga_del_camino() - pies0
	fuga.x *= dir
	_entra_ref = salida_escala
	f.set("perspectiva", func(e: float) -> Vector2: return fuga * (1.0 - e / _entra_ref))
	f.connect("colocado", _al_colocar_frontal)
	_frontal = f
	_frontal_dir = dir
	_parando = false
	_volviendo = false
	_al_perfil_ya = false
	_cortando = false
	_lado_suelto = false
	_sec_frontal.clear()
	for con in [true, false]:
		_sec_frontal[con] = JSON.parse_string(FileAccess.open("res://assets/characters/magnus/secuencia_frontal%s.json"
				% ("" if con else "_sin"), FileAccess.READ).get_as_text())
	add_child(f)
	move_child(f, _magnus.get_index() + 1)
	_sombra.visible = true
	return f

func _pedir_camino() -> void:
	PuentePerfil.precargar()
	if not _salida_carga and not OS.has_feature("nothreads"):
		_salida_carga = ResourceLoader.load_threaded_request(SALIDA_ESCENA, "", true) == OK

## Cada fotograma en el sector del camino: las teclas al de frente, la parada en
## la boca, el paso al perfil y el corte a camino_bosque.
func _camino_tick() -> void:
	if not _en_camino or _frontal == null or _al_perfil_ya:
		return
	var f := _frontal
	var arriba := Input.is_action_pressed("saltar")
	var abajo := Input.is_action_pressed("agacharse")
	var lado := Input.get_axis("mover_izquierda", "mover_derecha")
	if not _lado_suelto:
		_lado_suelto = is_zero_approx(lado)
		lado = 0.0
	if _retenida != "" and not arriba:
		_retenida = ""
	var quiere := ""
	if _retenida != "":
		quiere = _retenida
	elif arriba and not abajo:
		quiere = "espalda"
	elif abajo and not arriba:
		quiere = "frente"
	var e := float(f.get("escala"))
	var mira := String(f.get("mirando"))
	var est := String(f.get("estado"))
	if _cortando:
		f.set("quiere", "espalda")
		return
	# adentrandose: en la bruma, el corte
	if mira == "espalda" and est in ["arranque", "andar"] and e <= salida_hasta:
		_cortando = true
		f.set("quiere", "espalda")
		_cortar_a_camino()
		return
	var en_boca := e >= salida_escala - 0.02
	# de frente hacia la boca: se para en ella; mientras, la boca y el tamano se
	# ajustan a donde se va a parar (ver _prever_parada) y alli, al perfil
	if _parando:
		f.set("quiere", "")
		var u := clampf((_parada_inv - 1.0 / e) / maxf(_parada_inv - 1.0 / _parada_e, 1e-5), 0.0, 1.0)
		_entra_ref = lerpf(salida_escala, _parada_e, u)
		f.scale = Vector2(_frontal_dir, 1.0) * lerpf(1.0, salida_escala / _parada_e, u)
		if est == "reposo":
			if volver_al_perfil:
				_al_perfil()
			else:
				_parando = false
		return
	# de espaldas en la boca, abajo: la vuelta (y quieto de frente, al perfil)
	if _volviendo:
		f.set("quiere", "frente" if est == "reposo" and mira == "espalda" else "")
		if est == "reposo" and mira == "frente":
			if volver_al_perfil:
				_al_perfil()
			else:
				_volviendo = false
		return
	if en_boca and est == "reposo":
		if mira == "frente" and (quiere == "frente" or lado != 0.0):
			# de frente en la boca: de ahi no pasa (sin volver_al_perfil)
			if volver_al_perfil:
				_al_perfil()
			else:
				f.set("quiere", "")
			return
		if mira == "espalda" and quiere == "frente":
			_volviendo = true
			f.set("quiere", "frente")
			return
		if mira == "espalda" and lado != 0.0 and quiere == "":
			if volver_al_perfil:
				_al_perfil()
			return
	# sin volver_al_perfil, de frente no pasa de la boca: parado cerca de ella (la
	# parada prevista lo deja algo antes: medido 0,92-0,95) no vuelve a arrancar
	# hacia la camara, y andando, por si la parada no llega a tiempo, tampoco mas alla
	if not volver_al_perfil and mira == "frente" and quiere == "frente" 			and (e >= salida_escala + 0.02 or (est == "reposo" and e >= salida_escala - 0.07)):
		f.set("quiere", "")
		return
	if quiere == "frente" and mira == "frente" and est == "andar":
		var prev := _prever_parada(f)
		if not prev.is_empty() and absf(float(prev[0]) - salida_escala) <= absf(float(prev[1]) - salida_escala) \
				and float(prev[0]) >= salida_escala - 0.03:
			_parando = true
			_parada_e = prev[0]
			_parada_inv = 1.0 / e
			f.set("quiere", "")
			return
	f.set("quiere", quiere)

## Andando de frente, la escala a la que se pararia con los pies juntos si se
## soltase ahora y si se soltase en el paso siguiente: [e_a, e_b]. Solo se para
## con los pies juntos (dos veces por ciclo) y al soltar aun anda el margen del
## doble toque (0,3 s, ~8 fotogramas).
func _prever_parada(f: Node2D) -> Array:
	var anim := String(f.get("animacion"))
	var sec: Dictionary = _sec_frontal[bool(f.get("lleva_baston"))]
	if not sec["pies_juntos"].has(anim):
		return []
	var frames: SpriteFrames = load("res://resources/characters/magnus_frames.tres")
	var n := frames.get_frame_count(anim)
	var fr := int(f.get("fotograma"))
	var faltan: Array = []
	for pj in sec["pies_juntos"][anim]:
		var k := posmod(int(pj) - fr, n)
		faltan.append(k if k >= 8 else k + n)
	faltan.sort()
	var paso: float = f.call("paso_andar", "frente")
	var inv := 1.0 / float(f.get("escala"))
	var f_a: int = faltan[0]
	var f_b: int = faltan[1] if faltan.size() > 1 and int(faltan[1]) > f_a else f_a + n / 2
	return [1.0 / (inv - paso * f_a), 1.0 / (inv - paso * f_b)]

## Del de frente al de perfil, en la boca, por los puentes de PuentePerfil
## (2026-10-17: cortar de un video al otro saltaba). De frente: del reposo de
## frente, por frente_<cb|sb>, a la segunda mitad del giro del de perfil (el
## usuario, 2026-10-15: de frente a perfil con la vuelta del video de frente
## quedaba "muy muy rara"); sin espejar acaba mirando a la izquierda (al claro);
## espejado, a la derecha. De espaldas: la vuelta del de frente hasta el
## fotograma del puente de la ida (girar_a_perfil) y la ida al reves, hasta el
## reposo del de perfil, mirando hacia donde quedo. El puente parte de donde
## este de verdad la toma de frente (su escala al pararse no es justo la de los
## puentes) y acaba donde va el de perfil.
func _al_perfil() -> void:
	_al_perfil_ya = true
	_parando = false
	_volviendo = false
	var f := _frontal
	f.set("quiere", "")
	var con := bool(f.get("lleva_baston"))
	_baston_mano.call("poner_en_mano", con)
	var modo := "cb" if con else "sb"
	var y := _magnus.position.y
	var dir := Vector2(_frontal_dir, 1.0)
	var puente := _puente_perfil()
	if String(f.get("mirando")) == "frente":
		var nombre := "frente_" + modo
		var d := PuentePerfil.datos(nombre)
		var pies: Vector2 = f.to_global(f.get("pies"))
		var k := float(f.get("escala")) * absf(f.scale.y) / 0.98
		_magnus.position = Vector2(pies.x + float(d["dx"]) * _frontal_dir, y)
		_ultima_x = _magnus.position.x
		_magnus.call("_mirar", _frontal_dir)
		puente.jugar(nombre, false, pies, dir * k, Vector2(pies.x, y), dir)
		_frontal = null
		f.queue_free()
		await puente.acabado
		if not is_inside_tree():
			return
		_magnus.visible = true
		_magnus.call("_empezar_giro", -_frontal_dir, false)
		_sprite.frame = int(d["sigue"])
		while _sprite.animation == &"giro":
			await get_tree().process_frame
			if not is_inside_tree():
				return
	else:
		var nombre := "ida_%s_r00" % modo
		var d := PuentePerfil.datos(nombre)
		f.call("girar_a_perfil", int(d["sigue"]))
		await f.en_perfil
		if not is_inside_tree():
			return
		var pies: Vector2 = f.to_global(f.get("pies"))
		var k := float(f.get("escala")) * absf(f.scale.y) / 0.98
		var dx := float(d["dx"]) * _frontal_dir
		_magnus.position = Vector2(pies.x - dx, y)
		_ultima_x = _magnus.position.x
		_magnus.call("_mirar", _frontal_dir)
		puente.jugar(nombre, true, Vector2(pies.x - dx * k, pies.y), dir * k, _magnus.position, dir)
		_frontal = null
		f.queue_free()
		await puente.acabado
		if not is_inside_tree():
			return
		_sprite.play(&"reposo")
		_sprite.frame = 0
		_magnus.visible = true
	_magnus.control_bloqueado = false
	_en_camino = false
	_al_perfil_ya = false
	create_tween().tween_property(self, "_cam_quieta", 0.0, 1.5).set_trans(Tween.TRANS_SINE)

## LA HOJARASCA YA RESUELTA (2026-10-15; el usuario, volviendo de camino_bosque:
## "tiene que volver a la escena pero ya habiendo pasado todo, volveria por el
## caminito y ya esta, con todos los puzles pasados"). Si viene del camino
## (PeregrinoEstado) o ya cogio el baculo en esta partida (Partida,
## "hojarasca_resuelta"): sin negro ni caida (del camino se llega con un corte de
## camara), el baculo ya cogido (el baston como lo traiga), el haz apagado, el
## sendero abierto y sin los pensamientos de la historia. Del camino aparece en
## el (_llegar_del_camino); si no, de pie en su sitio y con el mando.
func _poner_resuelta(estado: Dictionary) -> void:
	$Entrada.hide()
	# la del camino: la que ya sonaba (del camino) a su nivel de aqui, o desde
	# el silencio; sin el extra del claro de sol de alli
	MusicAmbience.sonar_camino(musica_camino_db, cambio_musica if MusicAmbience.camino_sonando() else musica_entrada)
	create_tween().tween_property(MusicAmbience, "camino_extra_db", 0.0, cambio_musica)
	_alcanzado = true
	_baculo_bajando = true
	_baculo.visible = false
	_luz_apagada = true
	_poner_luz_viva(0.0)
	($Bosque.material as ShaderMaterial).set_shader_parameter("camino", 1.0)
	_camino_abierto = bosque_de_fondo
	_con_mando = 0.0
	_preparar_baston()
	_baston_mano.set("magia", float(estado.get("magia", 0.0)))
	_baston_mano.set("magia_recarga", float(estado.get("magia_recarga", 0.0)))
	_baston_mano.set("puesto", true)
	_baston_mano.call("poner_en_mano", bool(estado.get("baston_en_mano", true)))
	if estado.get("viene_de", "") == "camino_bosque" and bosque_de_fondo:
		_llegar_del_camino(bool(estado.get("baston_en_mano", true)))

## La fuga del camino donde se ve ahora (con la camara quieta).
func _fuga_del_camino() -> Vector2:
	var lejos := _parametro($Bosque.material as ShaderMaterial, "paralaje_lejos")
	return salida_fuga + _cam_fija * (1.0 - lejos)

## Cada vez que se coloca la toma de frente: su sombra y su suelo (la luz de
## magnus_luz oscurece los pies y les da el rebote junto a y_suelo).
func _al_colocar_frontal() -> void:
	if _frontal == null:
		return
	var pies: Vector2 = _frontal.to_global(_frontal.get("pies"))
	var u := float(_frontal.get("escala")) / salida_escala
	_sombra.position = pies + Vector2(0.0, -4.0 * u)
	_sombra.scale = Vector2(3.4, 0.75) * u
	_sombra.modulate.a = 0.62 * smoothstep(0.6, 0.95, u)
	_frontal_luz.set_shader_parameter("y_suelo", pies.y)

## Corte de camara a camino_bosque (sin negro): en cuanto este cargada (si aun
## no, sigue andando mientras tanto), salida_musica s y se cambia de escena en
## seco. La musica del camino sigue sonando (MusicAmbience); la de aqui, si aun
## no se habia ido, se aparta en ese rato.
func _cortar_a_camino() -> void:
	_pedir_camino()
	while _salida_carga and ResourceLoader.load_threaded_get_status(SALIDA_ESCENA) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	var musica: AudioStreamPlayer = $Musica
	if musica.playing:
		create_tween().tween_property(musica, "volume_db", -60.0, salida_musica).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(salida_musica).timeout
	WindAmbience.gust_db = 0.0
	var ps: PackedScene = null
	if _salida_carga and ResourceLoader.load_threaded_get_status(SALIDA_ESCENA) == ResourceLoader.THREAD_LOAD_LOADED:
		ps = ResourceLoader.load_threaded_get(SALIDA_ESCENA) as PackedScene
	_salida_carga = false
	# la escena siguiente lee con que baston llega (el del de frente: en el
	# camino se puede sacar o guardar), su magia y de donde viene
	var con: bool = bool(_frontal.get("lleva_baston")) if _frontal else bool(_baston_mano.get("en_mano"))
	PEREGRINO_ESTADO.dejar(get_tree(), con, float(_baston_mano.get("magia")),
			float(_baston_mano.get("magia_recarga")), "caida_hojarasca")
	if ps:
		get_tree().change_scene_to_packed(ps)
	else:
		get_tree().change_scene_to_file(SALIDA_ESCENA)

## Si Magnus pasa de un borde, aparece por el otro (el centro del nodo manda), y
## la copia pinta la parte que aun asoma por el lado contrario.
func _envolver() -> void:
	var x := _magnus.position.x
	if x < 0.0 or x >= ANCHO:
		_magnus.position.x = fposmod(x, ANCHO)
		if _con_mando >= 0.0 and not _resuelta:
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
	if _con_mando < 0.0 or _vueltas > 0 or _resuelta or _pensar.dicho("explorar"):
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
	_atenuar_bosque(bosque_atenuado, bosque_apagar)
	empezar_escalera()
	_sonar($SonidoHilo, hilo_db)

## Ya flotando arriba, lo reconoce (si no lo ha cogido ya).
func _al_posar_baculo() -> void:
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if not _alcanzado:
			_pensar.decir("baculo"))
