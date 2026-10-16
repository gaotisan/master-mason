extends Node2D
## Magnus. La posicion del nodo es el punto donde pisa: el sprite lleva un
## offset (-165 en la casilla comun, -185 en la del salto corriendo) para que la
## linea de suelo de la casilla caiga en el origen.
##
## Las animaciones encadenan asi:
##   reposo -> arranque_andar  -> andar  -> parada_andar  -> reposo
##   reposo -> arranque_correr -> correr -> parada_correr -> reposo
## Los arranques y las paradas son de una pasada; reposo, andar y correr, bucles.
##
## El salto no mueve el nodo: la subida y la bajada ya estan dentro del sprite,
## que se grabo saltando en el sitio. Si ademas moviesemos el nodo, saltaria dos
## veces.
##
## Sonido: cada pisada se dispara desde el sprite en que el pie planta. Los
## pasos no van en un bucle de audio porque andar y correr avanzan con la
## distancia, no con el reloj, y a la larga se desfasarian. La respiracion sigue
## al esfuerzo (ver respiracion_db): tras correr o saltar se oye y se va
## apagando, y en reposo normal no suena. Los archivos salen de
## raw/master_mason/audio/magnus/.

## Medidos sobre los sprites: la zancada es la separacion maxima entre los pies.
## Ver raw/master_mason/anim/magnus_comun.txt.
## Estas dos no son libres: el fotograma solo cambia en ticks de fisica, asi que
## su duracion tiene que ser un numero entero de ticks o la cadencia va a
## tirones. Con velocidad / avance = fotogramas por segundo y la fisica a 60 Hz,
## 192 y 435 dan 30 fotogramas por segundo justos, o sea 2 ticks por fotograma
## clavados. Los valores anteriores, 229 y 416, daban 1,677 y 2,091 ticks: unos
## fotogramas duraban 17 ms y otros 33, que andando es una variacion de 2 a 1 y
## se ve como un temblor en la cadencia de las piernas.
##
## Si quieres otra velocidad, la regla es velocidad = 30 * avance (2 ticks) o
## 20 * avance (3 ticks, mas lento pero igual de regular). Cualquier otro numero
## reintroduce el tiron.
@export var velocidad_andar: float = 192.0
@export var velocidad_correr: float = 435.0
## Px recorridos por fotograma de animacion. Con esto el ciclo avanza segun lo
## que se anda, no segun el reloj, y los pies no patinan a ninguna velocidad.
## Medidos siguiendo el pie plantado respecto al eje del tronco, fotograma a
## fotograma, sobre las mascaras de 04_limpios: 12,8 px de master al andar y
## 28,9 al correr, que a media escala son los de aqui. No vale deducirlos de la
## zancada ni de la velocidad: asi salian 9,5 y 17,3, el cuerpo recorria un 48%
## mas de lo que decian las piernas y por eso se deslizaba.
@export var avance_andar: float = 6.4
@export var avance_correr: float = 14.5
## Fotograma del bucle por el que se entra al terminar el arranque.
##
## El arranque y el bucle no tienen por que encajar: arranque_correr y correr
## salen de videos distintos, asi que la pose en la que acaba uno no es la del
## fotograma 0 del otro. Comparando el ultimo fotograma del arranque contra los
## 24 del ciclo -- silueta y color, normalizados por altura -- entrar por el 0
## daba un salto de 1,8 pasos normales del ciclo. Con el arranque cortado en el
## 22 (corte_arranque_correr) el mejor es el 9: 0,72 pasos, que ya no se
## distingue de un fotograma cualquiera.
##
## En andar el arranque y el ciclo salen del mismo video, y a partir del 18 el
## arranque ya ES el ciclo (ver corte_arranque_andar): se corta en el 18 y se
## entra por el 19, que es su continuacion (0,54 pasos).
@export var entrada_andar: int = 19
@export var entrada_correr: int = 9
## El arranque de andar se corta en el 18 y su velocidad no es una rampa recta
## sino la medida en los sprites, fotograma a fotograma (ver AVANCE_ARRANQUE_ANDAR).
## A partir del 18 el arranque ya ES el ciclo -- cada fotograma casa con el ciclo
## en su misma posicion, 18->f19, 22->f22... -- y su cola (26-33) afloja mientras
## el nodo seguia a tope: de +2 a +15 px master por fotograma de patinazo, que
## era el deslizamiento "sutil pero se nota" de los primeros segundos. -1 lo
## reproduce entero con la rampa antigua.
@export var corte_arranque_andar: int = 18
## Cuantos fotogramas del ciclo se espera, como mucho, a un apoyo que case con la
## parada al soltar la tecla. Puestos al ciclo entero = esperar SIEMPRE, que es lo
## que hace que la parada se vea igual de bien cada vez. Cuesta responsividad: al
## andar hasta 20 fotogramas (0,67 s) y al correr hasta 23 (0,77 s), porque el
## personaje termina el paso antes de frenar. 0 = entrar al instante, como antes.
@export var espera_parada_andar: int = 34
@export var espera_parada_correr: int = 24
## Cuanto salto de pose se tolera al entrar en la parada, en "pasos normales" del
## ciclo (la diferencia mediana entre dos fotogramas consecutivos). Se espera a un
## fotograma del ciclo que baje de esto; cuanto mas bajo, mejor se ve y mas se
## tarda en parar. Las distancias medidas estan en DIST_PARADA_*.
##
##   correr: 1,25 -> solo la fase 22 (la mejor, 1,21), espera hasta 23 fotogramas
##           1,60 -> once fases, espera hasta 9 fotogramas (0,30 s)
##   andar:  1,30 -> nueve fases (f2-f3, f24-f30), espera hasta 20 fotogramas
@export var tolerancia_parada_correr: float = 1.25
@export var tolerancia_parada_andar: float = 1.30
## Ultimo fotograma que se usa del arranque de correr; -1 lo reproduce entero.
##
## Los ultimos fotogramas de esa animacion tienen el brazo yendo hacia atras y
## volviendo de golpe, sin frenar en el extremo: se ve como si rebotase contra
## algo. Medido siguiendo la mano: del 31 al 32 recorre 32 px hacia atras y del
## 32 al 33 recorre 30 hacia delante, sin un solo fotograma de demora. Que es un
## fallo y no el gesto se ve en el otro extremo de la misma animacion, el 20-21,
## donde la mano solo se mueve 4,6 px, o sea que ahi el brazo si se demora.
##
## Cortando antes el rebote no llega a verse. Se corta en el 22 porque del 8
## en adelante los pies ya van a crucero (ver AVANCE_ARRANQUE_CORRER), y el
## empalme con el bucle por entrada_correr queda en 0,72 pasos.
@export var corte_arranque_correr: int = 22
## Girar con la animacion de giro en vez de voltear el sprite de golpe.
##
## La animacion sale de un video: un giro de espaldas a la camara, con dos
## pasos, entero y a su ritmo (47 fotogramas a 30 fps, 1,6 s; antes eran 5
## vistas de IA en 0,25 s y se veia brusco). Empieza y acaba en el
## reposo. El volteo del sprite se hace al TERMINAR, no al empezar: durante el
## giro se conserva el flip_h que hubiera, y por eso la misma animacion sirve
## para los dos sentidos -- volteada se lee de izquierda a derecha.
##
## A false vuelve al flip_h instantaneo de antes.
@export var giro_activo: bool = true
## Ritmo de los giros (2026-10-13): los videos a su ritmo duran 2,5 s (de pie),
## 2,8 (agachado) y 2,9 (con el baston en la mano). El usuario: "vamos a
## bajarlo, toma como referencia otros juegos parecidos". Prince of Persia
## (1989; SDLPoP, seqtbl.c, a 12 fps) gira de pie en 8 fotogramas, 0,67 s, y
## sale corriendo desde el 4.o. Recortarlo no vale: hasta el 56 de 61 la pose
## esta a mas de 1,8 pasos del final (la capa se asienta), un salto de pose al
## salir andando. A x2,5 (60 fotogramas por segundo, 1 s) "es un pelin rapido,
## demasiado": x2, 1,27 s de pie (48 fotogramas por segundo, todos).
@export var giro_ritmo: float = 2.0
## Margen para que dos pulsaciones cuenten como doble y arranque a correr.
@export var doble_pulsacion: float = 0.30
## Fraccion del arranque en la que el personaje todavia no ha movido los pies,
## para la rampa recta antigua: solo se usa con corte_arranque_* a -1. Con los
## cortes puestos la velocidad sale de las tablas AVANCE_ARRANQUE_*, que ya
## traen su zona quieta medida.
@export var quieto_al_arrancar_andar: float = 0.06
@export var quieto_al_arrancar_correr: float = 0.11
## Fraccion de la parada en la que el cuerpo frena de verdad. El resto de la
## animacion es el abrigo asentandose, con los pies ya plantados: si el nodo
## sigue avanzando ahi, parece una cinta mecanica.
## Medido siguiendo el pie respecto al cuerpo: se planta en 5 fotogramas de 21
## al andar y en 3 de 39 al correr.
@export var frenada_andar: float = 0.25
@export var frenada_correr: float = 0.10
## Momento del salto en que toca el suelo, como fraccion de la animacion. A
## partir de ahi el impulso que llevaba se apaga. Medido siguiendo la fila del
## pie mas bajo en 04_limpios: despega en el sprite 15 de 70 y toca el suelo en
## el 46 (indice 45 de 69). El salto de parado y el de andando son el mismo:
## el sprite no lleva desplazamiento cocido, lo pone el nodo con _impulso.
@export var aterrizaje: float = 0.652
## A partir de aqui el salto se puede cortar con otra tecla. Sin esto, la
## recuperacion deja al personaje 0,4 s sin responder despues de haber caido.
## Es el sprite 60 de 70, 0,23 s despues de tocar el suelo: antes esta en
## cuclillas y ningun fotograma de andar se le parece (0,060, casi 5 pasos
## normales del ciclo); a partir de aqui baja a 0,046 (3,5 pasos, lo mismo que
## se acepto para entrar al salto corriendo). El impulso ya esta apagado.
@export var salto_interrumpible: float = 0.855
## Lo mismo para el salto corriendo, que es otra animacion con otros tiempos:
## medido siguiendo el punto mas bajo del personaje, despega en el fotograma 3
## de 38, llega al apogeo en el 17 y toca el suelo en el 30.
@export var aterrizaje_correr: float = 0.81
@export var salto_correr_interrumpible: float = 0.85
## Y para el salto de parado (66 sprites): toca el suelo en el 47 (indice 46,
## 0,71) y se puede cortar desde el indice 60 (0,92), cuando ya esta casi de
## pie; antes esta agachado y el arranque no se le parece. Del 47 al 65 se
## incorpora hasta la pose de reposo, a la que llega a 0,05.
@export var aterrizaje_parado: float = 0.71
@export var salto_parado_interrumpible: float = 0.92
## Empuje extra del salto corriendo, que en el sprite es un brinco corto: la
## subida cocida son 94 px de hoja y el vuelo 0,47 s, o sea 204 px a 435 px/s,
## dos tercios de la altura del personaje. Aqui se le anade lo que le falta:
##   salto_correr_altura   arco vertical del SPRITE durante el vuelo, en px de
##                         hoja, sincronizado con el fotograma (despegue -> toca)
##   salto_correr_impulso  multiplica la velocidad que llevaba mientras vuela
##   salto_correr_vuelo    speed_scale de la animacion en el aire (<1 = mas tiempo)
## Con 80, 1,3 y 0,75 sube unos 175 px y avanza unos 340: algo mas de una altura.
@export var salto_correr_altura: float = 80.0
@export var salto_correr_impulso: float = 1.3
@export var salto_correr_vuelo: float = 0.75
## Sprites del despegue y de la toma de suelo del salto corriendo, medidos
## siguiendo el pie mas bajo en 04_limpios: despega en el 3 (indice 2) y toca en
## el 30 (indice 29). Entre los dos va el arco.
@export var salto_correr_despegue: int = 2
@export var salto_correr_toca: int = 29
## CARRERILLA. Un contador de 0 a 1 que se llena corriendo a crucero con la
## tecla hacia delante (estado CORRER, carrerilla_tiempo segundos hasta lleno) y
## se vacia en cuanto deja de pedir correr (soltando, frenando, andando, parado:
## carrerilla_vaciado segundos de lleno a vacio); en el aire del salto corriendo
## se congela. El salto corriendo escala con el las tres cosas que pone el nodo:
## el arco (salto_correr_altura -> salto_correr_altura_max), el empuje
## (salto_correr_impulso -> salto_correr_impulso_max) y, derivado del arco, el
## ritmo en el aire (ver _ritmo_vuelo: con la misma gravedad, mas altura es mas
## vuelo, asi que la animacion va mas lenta para que los fotogramas del aire
## duren lo que dura el salto; nunca mas lento que salto_correr_vuelo_min ni
## que VUELO_MIN, que ya se lee como camara lenta). Cada salto gasta carrerilla_gasto_salto de lo que
## llevaba: saltar en cadena no repite el salto maximo sin fin, que en un viejo
## no se cree. Recien arrancado a correr el contador esta a 0 y el salto es el
## de antes. A false, el contador no se mueve de 0 y todo es como antes.
@export var carrerilla_activa: bool = true
@export var carrerilla_tiempo: float = 1.5
@export var carrerilla_vaciado: float = 0.4
@export var carrerilla_gasto_salto: float = 0.5
@export var salto_correr_altura_max: float = 130.0
@export var salto_correr_impulso_max: float = 1.6
@export var salto_correr_vuelo_min: float = 0.6
## ALTURA VARIABLE del salto corriendo: un toque corto da un brinco mas bajo
## (el arco anadido baja hasta salto_corto_factor) y mantener la tecla durante
## la subida da el arco entero. El arco va atado al fotograma, asi que cambiarle
## la amplitud de golpe seria un salto vertical: soltada antes del despegue (el
## arco aun vale 0) el brinco es corto desde el principio; soltada en el aire,
## la amplitud se acerca al objetivo con una curva exponencial
## (SALTO_CORTO_TAU, en fraccion del vuelo) y solo mientras sube, sin quitarle
## nunca mas del 60 % de su velocidad de subida (SALTO_CORTO_FRENO). Soltar
## pronto da el brinco corto entero; soltar cerca del apogeo, casi el salto
## entero, que es lo que haria el cuerpo. Menos arco es menos vuelo con la
## misma gravedad (_ritmo_vuelo): cae antes y avanza algo menos. A false,
## siempre el arco entero.
@export var salto_variable_activo: bool = true
@export var salto_corto_factor: float = 0.55
## EMPALMES DEL SALTO CORRIENDO.
## arco_desde_despegue: el arco del nodo empieza en 0 en el primer tick del
##   vuelo. El sprite va a 60 fps y la fisica lee el fotograma del despegue con
##   frame_progress ya a 1, asi que antes el primer tick se comia un fotograma
##   entero de arco (11 px de golpe, luego 8; con la carrerilla llena 18 y 10).
##   A false, como antes.
## aterrizaje_carrera_suavizado: al tocar suelo con la direccion pulsada sigue
##   corriendo a la velocidad del aire y el sobrante sobre la de correr se
##   apaga con esta constante de tiempo (segundos), en vez de caer de golpe a
##   435 en un tick (antes 565 -> 435; con la carrerilla llena 696 -> 435, que se
##   leia como un frenazo). Las piernas van por distancia: solo ciclan algo mas
##   deprisa unas decimas. 0 = de golpe, como antes.
## Y el empuje extra de la carrerilla (lo que pasa de salto_correr_impulso) no
## se aplica con los pies en el suelo, antes del despegue, sino que entra en
## los SALTO_EMPUJE_RAMPA primeros fotogramas del vuelo: si no, los pies
## resbalaban a x1,6 tres ticks antes de despegar.
@export var arco_desde_despegue: bool = true
@export var aterrizaje_carrera_suavizado: float = 0.12
const SALTO_EMPUJE_RAMPA := 3.0
## Ritmo minimo en el aire: por debajo el salto parece a camara lenta.
const VUELO_MIN := 0.55
## Px que sube el pie mas bajo cocido en el sprite del salto corriendo (97 en
## el apogeo, f17-19): con el arco del nodo, la altura del salto para
## _ritmo_vuelo.
const SUBIDA_SALTO_CORRER := 97.0
## Altura variable: constante de la curva con que la amplitud baja hacia el
## brinco corto (en fraccion del vuelo), y cuanto de la velocidad de subida del
## arco puede quitarle como mucho.
## Y en que tramo del vuelo tras soltar entra ese freno, de nada a entero (unos
## tres ticks).
const SALTO_CORTO_TAU := 0.12
const SALTO_CORTO_FRENO := 0.6
const SALTO_CORTO_ENTRADA := 0.06
## Al tocar suelo con la direccion pulsada se sigue corriendo SIN pasar por el
## arranque: entra el ciclo por este fotograma, el que mas se parece a la pose
## de la toma de suelo (c_30 -> f17, 2,5 pasos normales del ciclo; los demas
## fotogramas estan a 2,7-3,1). Antes se cortaba en el 85 % hacia el arranque
## por velocidad, y como el impulso ya se habia apagado al tocar suelo, el
## personaje se clavaba 0,3 s al caer y volvia a acelerar: eso era lo raro.
@export var salto_correr_a_correr: int = 17
## Soltando la direccion, tras el salto entra "aterrizaje_correr" (video
## 166-199: se incorpora y da dos pasos cortos hasta quedarse de pie) y de ahi
## a reposo. La velocidad baja durante la toma de suelo hasta esta fraccion de
## la de correr, y se apaga en la primera parte de esa animacion.
@export var aterrizaje_correr_velocidad: float = 0.5
@export var aterrizaje_correr_frenada: float = 0.6
## El salto corriendo va en su propia casilla, 340x400 en la hoja frente a los
## 292x360 del resto, porque en el apogeo el personaje se sale de la comun por
## arriba y por la izquierda. El offset pone la linea de suelo de cada casilla en
## el origen del nodo: alto/2 menos los 15 px de margen de suelo a media escala.
@export var offset_comun := Vector2(0, -165)
@export var offset_salto_correr := Vector2(0, -185)
## FLOTAR EN LA LUZ (estado Pluma del guion, capitulos 1-2). Con `ligereza`
## puesta -- la pone el nivel: cuanta luz que aligera hay en un punto de la
## escena, de 0 a 1 --, los saltos vuelan con la gravedad multiplicada por
## gravedad_luz alli donde le da la luz, y con la de siempre donde no. Se mira
## en cada tick donde esta el cuerpo: si entra o sale de la luz a medio salto,
## la gravedad cambia en ese momento, y el borde blando del haz la cambia poco
## a poco. Despega igual en todas partes; con menos gravedad sube mas, tarda
## mas y, a la misma velocidad de lado, llega mas lejos. Sin ligereza (o fuera
## de la luz) es el salto de siempre.
##
## Como: el sprite trae el vuelo cocido. Midiendo el cuerpo en 04_limpios (media
## de la cabeza y del centroide), cada salto se parte en una parabola -- el
## vuelo: una sola gravedad, del despegue al apogeo y a la toma de suelo -- y
## lo que sobra, que es la pose (tablas en VUELO). Lo que se ve sin luz es esa
## parabola mas el arco que le anade el nodo (el del corriendo con su
## carrerilla, salto_andando_altura en el andando), que tambien es una
## parabola. El nodo integra la suma con la gravedad del sitio y pone el
## fotograma que le toca:
##   subiendo, por la velocidad: los fotogramas pasan al ritmo al que la
##     gravedad la gasta (a 0,30, a 18 fps en vez de 60). Sube 1/0,30 veces
##     mas alto y tarda 1/0,30 veces mas: el mismo salto con menos gravedad.
##   bajando, por lo que lleva caido de lo que le queda hasta el suelo: el
##     fotograma en que el pie toca llega siempre justo al tocar.
## La diferencia entre la altura integrada y la cocida en el fotograma que se ve
## es el arco del sprite (position.y). Sin luz, el fotograma de cada tick es el
## de siempre.
## El de parado y el andando van siempre por aqui (_volar). El corriendo sigue
## con su arco de siempre (la carrerilla, la altura variable) hasta que le da
## la luz, y desde ese tick pasa a la fisica con la altura y la velocidad que
## llevaba (_luz_en_carrera); ahi soltar la tecla subiendo es mas gravedad.
## luz_quita_tiron: el arranque del sprite es un tiron (la IA lanza el cuerpo y
##   lo frena en cuatro fotogramas: 17 px por encima de la parabola en el de
##   parado, 6 en el andando, 9 en el corriendo). En la luz, estirado, se ve
##   como un salto dentro del salto. A 1 dentro de la luz el cuerpo sigue la
##   parabola limpia y solo se mueven tunica y piernas; a 0 se conserva. Fuera
##   de la luz no se toca.
## gravedad_luz: el guion decia 0,35; probado en el juego (2026-10-11) el
##   usuario lo quiso "un pelin mas pronunciado, que suba un pelin mas": 0,30.
## salto_andando_altura: arco que se le suma al salto andando (px), en todas
##   partes. El cocido sube el cuerpo 23 px con una gravedad de 762 px/s^2, la
##   mitad que el de parado: "demasiado bajo, dentro de la luz e incluso de
##   normal" (2026-10-11). Con el arco dura lo mismo y sube mas; con 25 sube
##   48, como el de parado, y su gravedad pasa a 1465 px/s^2.
## EN EL AIRE, EN LA LUZ (2026-10-11):
## deriva_max, deriva_aceleracion: con la direccion pulsada se va de lado hasta
##   deriva_max px/s (o lo que ya llevara hacia ahi), ganando
##   deriva_aceleracion px/s^2 con la luz entera y nada fuera de ella: en la
##   luz se pesa poco y el aire lo lleva; a oscuras, el salto va donde iba.
##   Solo hacia donde mira: de espaldas no se va (2026-10-12, ver GIRAR EN EL
##   AIRE); hacia atras frena lo que llevaba y se da la vuelta si puede. Al
##   tocar suelo se apaga en una decima.
## rebote_hoja: rebotar() (lo llama el nivel cuando cae con los pies sobre una
##   hoja en la luz) le vuelve a dar la velocidad de despegue del salto de
##   parado por esto: "como si volviera a saltar". Desde la hoja se salta de
##   parado: el andando y el corriendo siguen como el de parado (su fisica, sus
##   fotogramas, su bajada flotando y su giro), y lo que llevaban de lado pasa
##   a la deriva.
var ligereza: Callable
## PISAR LA HOJA SIN DESCUADRE (2026-10-14). El usuario: "cuando flota y rebota
## en las hojas hay un descuadre en la animacion donde se activa el rebote y en
## los pies; a veces parece que no toca la hoja y rebota". Grabado: bajaba
## flotando con las piernas recogidas y al pisar saltaba de golpe al primer
## fotograma de flotar_pisar (piernas estiradas, 29 px mas de cuerpo sobre los
## pies). Ahora:
## - hoja_debajo (lo pone el nivel: (pies) -> y de la hoja que pisaria al bajar,
##   o INF): bajando flotando, esa hoja hace de suelo para repartir los
##   fotogramas, asi que estira las piernas al acercarse y llega a ella con la
##   pose de tocar suelo, como al posarse;
## - flotar_pisar empieza en el fotograma cuya altura del cuerpo sobre los pies
##   mas se parece a la que trae (hasta PISAR_ENTRADA_MAX, antes del impulso);
## - apoyado no sigue la hoja de lado: la hoja va bajo su pie (el nivel la
##   lleva) y el no se desliza.
var hoja_debajo: Callable
@export var gravedad_luz: float = 0.30
@export_range(0.0, 1.0) var luz_quita_tiron: float = 1.0
@export var salto_andando_altura: float = 25.0
## SALTO ANDANDO FUERA DE LA LUZ (2026-10-13). El usuario: "el salto vertical
## del andar sube quiza muy poco, no es capaz de subir nada". Con el de arriba los
## pies llegaban a ~102 px (un tercio de Magnus). En los plataformas como Inside o
## Limbo el salto salva algo mas de media altura del personaje, y los bloques de
## media altura se tienen que poder saltar ("ademas de escalarlos"): con 110 los
## pies llegan a ~187 px (el sillar mediano mide 172) y el cuerpo sube 133. Y con
## la gravedad de verdad (la del salto de parado, 1841 px/s^2) en vez de la que
## saldria de meter ese arco en el mismo vuelo (~3700, un brinco seco): el vuelo
## dura 0,77 s en vez de 0,53, a menos fotogramas por segundo. El corriendo es
## para saltar lejos (~540 px: pasa por encima de un sillar). En la luz manda
## salto_andando_altura (lo afinado para flotar); a media luz, a medias.
## salto_andando_gravedad a 0, como antes.
@export var salto_andando_altura_oscuro: float = 110.0
@export var salto_andando_gravedad: float = 1841.0
## SALTO DE PARADO MAS ALTO (2026-10-14). El usuario: "el salto en parado es
## demasiado pequeno, se eleva muy poco en la vertical (cuando no esta la luz);
## tiene que ser mas o menos comparable a cuando lo hace andando", y "en la luz
## tenga un salto algo mas potente en parado y facilite un poco el puzle". Como
## el andando: un arco que se le suma al cocido (el cuerpo subia 48 px), con la
## gravedad de verdad (salto_andando_gravedad) estirando el vuelo a menos
## fotogramas por segundo. Fuera de la luz, 85: el cuerpo sube ~133, como el
## andando (el vuelo dura 0,76 s en vez de 0,45). En la luz, 12: sube
## (48 + 12) / 0,30 = 200 px en vez de 160. A media luz, a medias. El rebote
## en la hoja no cambia (sube lo del salto de parado cocido).
@export var salto_parado_altura_oscuro: float = 85.0
@export var salto_parado_altura: float = 12.0
@export var deriva_max: float = 170.0
@export var deriva_aceleracion: float = 520.0
@export var rebote_hoja: float = 1.0
## caida_max_luz: en la luz no cae mas deprisa que esto (px/s): baja despacio,
##   como una pluma ("si no, vas cayendo lentamente"; "bajar al suelo flotando,
##   efecto sin gravedad"). Era 400 (un salto llegaba casi sin notarlo); con
##   120 (2026-10-12) un salto parado en la luz baja en ~1,35 s y la bajada del
##   video entra entera a un fotograma por tick (ver _volar_flotando). Fuera de
##   la luz, sin tope; en el borde, el tope se abre con lo que baja la luz.
@export var caida_max_luz: float = 120.0
## FLOTAR CON SUS ANIMACIONES (2026-10-12). Los videos de flotar de Flow,
## montados por raw/master_mason/anim/magnus_flotar/montar_flotar.py
## (assets/characters/magnus/flotar.json y sus hojas), se anaden al cargar.
## Hito 1: el salto de parado que llega al apogeo con luz (flotar_luz_min o
## mas) baja flotando con su video y se posa sin golpe: la bajada son los
## fotogramas del salto del apogeo al 37 (flotar_desde..37: el 38 es la pose
## de flotar, que es el primer fotograma del video) y luego flotar_bajar, todo
## repartido por lo que lleva caido (como la bajada del salto); el cuerpo, donde
## dice la fisica; los pies tocan el suelo en el ultimo de flotar_bajar y sigue
## flotar_posarse (a su ritmo) hasta el reposo. Fuera de la luz, el salto de
## siempre.
@export var flotar_luz_min: float = 0.3
@export var flotar_desde: int = 32
@export var posarse_db: float = -6.0
## FLOTAR QUIETO (2026-10-15). El usuario: cayendo desde alto no se podia girar
## ("ese caer, a la altura que sea, no puedes girar"): la bajada (flotar_bajar)
## reparte sus 81 fotogramas en todo lo que queda hasta el suelo, y desde el 12
## ya estira las piernas, lejos de la pose de flotar en la que empieza el giro.
## Ahora, si al llegar a la pose de flotar queda mas altura de la que necesita
## la bajada para posarse a un fotograma por tick (mas flotar_quieto_margen s),
## flota con flotar_quieto (un video que mantiene la pose; solo se mueve la
## tela) mientras quede, girando cuando se quiera, y entra en flotar_bajar por
## el fotograma que mas se parece al que lleva ("a_bajar" de flotar.json) justo
## a tiempo de posarse. Bucle: tras el ultimo, flotar_quieto_vuelta (el 191
## calca al 3). Ver raw/master_mason/anim/magnus_flotar/montar_quieto.py.
@export var flotar_quieto_margen: float = 0.2
@export var flotar_quieto_vuelta: int = 3
## GIRAR EN EL AIRE (2026-10-12): "no puedes ir de espaldas o avanzar de
## espaldas en el aire; si das un rebote y quieres cambiar de direccion, gira y
## luego avanza". En la luz, con la direccion contraria a donde mira, se da la
## vuelta por delante (flotar_girar: la primera mitad del giro del video, de
## perfil a de frente, y ella misma espejada y al reves; 63 fotogramas a uno
## por tick, 1,05 s) y luego avanza hacia alli. Girando frena lo que llevaba
## de lado y casi de frente (giro_aire_avanza) empieza a avanzar hacia alli. El
## vuelo sigue con su fisica, el cuerpo donde dice (como en la bajada
## flotando), y si cae sobre una hoja rebota sin cortar el giro. Al acabar
## mira al otro lado (flip_h: el ultimo del giro es la pose de flotar
## espejada) y sigue flotando desde ella.
## giro_aire_desde: subiendo, el giro empieza en este fotograma del salto de
##   parado o despues (antes las piernas van recogidas y no casan con el
##   primero del giro, la pose de flotar); pedido antes, espera a llegar.
## giro_aire_hasta: bajando flotando, el ultimo de flotar_bajar desde el que
##   aun se gira (luego estira las piernas hacia el suelo). Mas tarde solo
##   frena, y al tocar suelo se gira con el giro de siempre.
## giro_aire_avanza: fotograma del giro desde el que ya avanza hacia donde se
##   vuelve (el 31 es el de frente; en el 24 ya casi da la cara). Antes no:
##   se veria ir de lado hacia atras.
## giro_aire_caida_min: girando y despues, la luz lo sostiene lo justo para
##   que el giro y la bajada flotando entera vayan a un fotograma por tick (la
##   tunica fluida, ver caida_max_luz), pero sin bajar mas despacio que esto
##   (px/s). Si ni asi cabe, no se gira en el aire.
## RESPUESTA DEL GIRO EN EL AIRE (2026-10-14). El usuario: "en la luz cuando
## giramos para un lado... tarda mucho en responder, quiza haya muchos
## fotogramas iniciales; la velocidad no me desagrada, es mas bien tiempo de
## respuesta". Medido en la hoja: los primeros 15 fotogramas del giro solo
## hacen el 17 % del cambio (el video arranca despacio), y se esperaba al 28
## del salto, cuando la pose ya casa desde el 24.
## giro_aire_inicio: el giro empieza en este fotograma (antes casi no se mueve).
## giro_aire_arranque: fotogramas por tick al empezar, que bajan a uno por tick
##   al llegar a giro_aire_rampa; el resto del giro, a su velocidad de siempre.
@export var giro_aire_desde: int = 28
@export var giro_aire_hasta: int = 12
@export var giro_aire_avanza: int = 24
@export var giro_aire_caida_min: float = 45.0
@export var giro_aire_inicio: int = 0
@export var giro_aire_arranque: float = 2.5
@export var giro_aire_rampa: int = 24
const FLOTAR := "res://assets/characters/magnus/flotar.json"
## Cinematica de entrada (caer_desde_arriba): cae desde fuera de pantalla, se
## estampa, se queda tumbado y se levanta. Mientras dura no se acepta entrada.
## Las cuatro animaciones van en casilla propia (380x360) pero con la linea de
## suelo en la misma fila que la comun, asi que usan offset_comun.
##
## El descenso lo pone el nodo, no el sprite: el bucle "cayendo" tiene la
## cabeza fijada. Con 1200 px en 1,4 s y aceleracion cuadratica llega al suelo
## a unos 1700 px/s, 29 px por tick: se lee como caida y no como flotar. Con
## 1,1 s se veia un pelin rapida.
@export var caida_altura: float = 1200.0
@export var caida_duracion: float = 1.4
## Cuanto se queda tumbado antes de empezar a levantarse. Sin pausa el golpe
## no pesa; con mas de dos segundos parece que no va a levantarse. Con 1,2 el
## golpe pesaba poco.
@export var tumbado_espera: float = 1.8
## Sonidos de la cinematica, sacados del audio del propio video de la caida
## (raw/master_mason/audio/magnus/construye.py, seccion CAIDA). El aire acaba
## justo en el golpe, asi que se arranca caida_duracion antes del impacto; el
## roce de levantarse esta acelerado para durar lo que dura la animacion.
## golpe_sprite es el sprite de "caida" en que suena el golpe en el video
## (medido en construye.py: el ataque cae en el 6,7, o sea al empezar el 7,
## cuando el cuerpo da contra el suelo; los pies lo tocan tres sprites antes
## sin ruido).
@export var golpe_db: float = -3.0
@export var cinematica_db: float = -9.0
@export var golpe_sprite: int = 7
const SONIDOS_CAIDA := {
	"aire": preload("res://assets/audio/magnus_caida_aire.ogg"),
	"golpe": preload("res://assets/audio/magnus_caida_golpe.wav"),
	"levantarse": preload("res://assets/audio/magnus_levantarse.ogg"),
}

## Golpes de las animaciones que reproduce el nodo (arranques, paradas, saltos):
## animacion -> sprite en que suena -> sonido. Se disparan desde frame_changed.
## Los sprites de contacto estan medidos en 04_limpios siguiendo la fila del pie
## mas bajo (un contacto es cuando baja hasta el suelo tras haber estado
## levantado); los de los saltos, ademas, contra el ataque del audio de su
## propio video (raw/master_mason/audio/magnus/construye.py, seccion SALTOS).
## Antes todo esto era mudo: al arrancar a correr los primeros 0,6 s no sonaba
## nada, y los saltos ni despegaban ni caian.
const GOLPES := {
	"arranque_correr": {17: preload("res://assets/audio/magnus_paso_correr_a.wav")},
	"parada_andar":    {8:  preload("res://assets/audio/magnus_paso_b.wav")},
	# Agachado (mas flojas, pasos_agachado_db): el pie cercano llega en el 22
	# del arranque; en la parada, el de atras se junta en el 12.
	"arranque_agachado": {22: preload("res://assets/audio/magnus_paso_a.wav")},
	"parada_agachado":   {12: preload("res://assets/audio/magnus_paso_b.wav")},
	# El paso agachado: apoya el pie de delante y despues junta el de atras.
	"paso_agachado":     {18: preload("res://assets/audio/magnus_paso_a.wav"),
						  77: preload("res://assets/audio/magnus_paso_b.wav")},
	"parada_correr":   {5:  preload("res://assets/audio/magnus_paso_correr_b.wav")},
	"aterrizaje_correr": {19: preload("res://assets/audio/magnus_paso_b.wav")},
	"saltar": {
		13: preload("res://assets/audio/magnus_salto_despegue.wav"),
		48: preload("res://assets/audio/magnus_salto_caida.wav"),
	},
	"salto_correr": {
		4:  preload("res://assets/audio/magnus_salto_correr_despegue.wav"),
		33: preload("res://assets/audio/magnus_salto_correr_caida.wav"),
	},
	"salto_parado": {
		18: preload("res://assets/audio/magnus_salto_parado_despegue.wav"),
		47: preload("res://assets/audio/magnus_salto_parado_caida.wav"),
	},
}
## Sprite del golpe de la caida del salto corriendo en GOLPES, para cuando no
## se llega a el (se corta al ciclo al tocar suelo).
const SALTO_CORRER_CAIDA_SPRITE := 33

## Vuelo cocido de los tres saltos, para flotar en la luz (ver
## FLOTAR EN LA LUZ y _volar). Medido en 04_limpios (master a la mitad = px del
## juego) con raw/master_mason/anim/magnus_salto_parado/tablas_vuelo.py:
##   despegue, toca  fotograma en que se va del suelo (el del sonido del
##                   despegue) y en el que el pie vuelve a tocarlo
##   apogeo, alto    donde la parabola del cuerpo llega arriba (fotograma con
##                   fraccion) y cuanto sube sobre el despegue (px); de ahi
##                   salen su gravedad (1841, 762 y 2009 px/s^2 a 60 fps: la
##                   IA no los hizo con la misma) y su velocidad de despegue
##   centro          altura del centro del cuerpo sobre los pies al despegar:
##                   ahi se mira la luz
##   pose            cuerpo cocido menos parabola, por fotograma desde el
##                   despegue: +-2 px salvo el tiron del arranque
##   pies            altura cocida de los pies sobre el suelo, por fotograma
const VUELO := {
	&"salto_parado": {"despegue": 18, "toca": 45, "apogeo": 31.73, "alto": 48.2, "centro": 134.0,
		"pose": [0.0, 5.1, 11.1, 15.2, 17.1, 15.5, 12.4, 9.1, 6.7, 4.4, 2.7, 1.6, 0.7, 0.1, -0.1,
			-0.5, -0.6, -0.4, -0.5, -0.3, -0.3, -0.1, 0.1, 0.5, 1.2, 1.3, 1.7, 0.0],
		"pies": [1.0, 3.0, 6.5, 11.0, 17.0, 23.0, 29.5, 37.0, 44.5, 52.0, 58.0, 62.5, 64.5, 65.0, 64.5,
			63.0, 61.0, 58.0, 55.0, 50.0, 45.0, 38.0, 31.0, 23.0, 15.5, 7.5, 1.5, 0.0]},
	&"saltar": {"despegue": 13, "toca": 45, "apogeo": 27.84, "alto": 23.32, "centro": 166.0,
		"pose": [0.0, 3.6, 6.0, 4.6, 2.8, 1.8, 1.1, 0.9, 0.9, 0.8, 0.7, 0.3, -0.1, 0.1, 0.0, 0.0, 0.1,
			0.4, 0.3, 0.8, 1.0, 1.2, 1.6, 1.9, 1.8, 1.8, 1.7, 1.5, 1.0, 0.5, -0.1, -0.6, 0.0],
		"pies": [0.0, 5.0, 10.5, 16.5, 22.5, 32.5, 42.5, 53.5, 61.5, 67.5, 71.5, 76.5, 76.5, 77.5, 77.5,
			77.5, 77.5, 76.5, 76.5, 75.5, 74.5, 73.5, 72.5, 71.5, 62.5, 51.5, 40.0, 29.5, 21.5, 13.5,
			8.5, 4.5, 0.5]},
	# Casilla propia (offset_salto_correr); despegue y toca, los de
	# salto_correr_despegue y salto_correr_toca. Solo en la luz.
	&"salto_correr": {"despegue": 2, "toca": 29, "apogeo": 15.64, "alto": 51.9, "centro": 149.3,
		"pose": [0.0, 3.1, 6.0, 8.9, 6.6, 4.7, 2.6, 1.1, 0.0, 0.1, 0.0, 0.1, 0.1, 0.0, 0.0, 0.1,
			0.5, 0.4, 1.4, 2.2, 2.7, 3.3, 3.5, 3.7, 3.0, 2.5, 1.3, 0.0],
		"pies": [0.5, 0.5, 5.5, 17.5, 24.5, 35.0, 45.0, 55.5, 66.0, 75.0, 79.5, 83.0, 87.0, 89.5,
			92.5, 94.0, 94.5, 94.0, 91.5, 87.5, 82.0, 74.5, 64.5, 53.0, 40.5, 26.5, 14.0, 0.0]},
}

## Se emite cuando la cinematica de entrada deja al personaje en reposo y con
## el control devuelto.
signal cinematica_terminada
## Acaba de despegar de la hoja en la que se apoyaba (ver PISAR LA HOJA): el
## nivel la patea entonces.
signal despega_de_hoja(hoja: Dictionary)
## Se emite en el sprite en que el cuerpo da contra el suelo en la caida de
## entrada (el mismo del golpe de sonido): el nivel levanta ahi la hojarasca.
signal impacto
## Se emite cuando andar_hasta() ha llevado al personaje a su sitio y ya esta
## en reposo.
signal llegado
## Se emite en cada contacto con el suelo que suena: pisadas (PISADAS) y golpes
## de arranques, paradas y saltos (GOLPES); anim y sprite dicen cual. El nivel
## lo usa para que el suelo reaccione al pie (la hojarasca de caida_hojarasca).
signal pisada(anim: StringName, sprite: int)

## CONTROL DESDE FUERA. Los niveles y los dialogos necesitan quitarle las teclas
## al jugador sin romper la maquina de estados: con control_bloqueado las
## pulsaciones se ignoran y el eje deja de venir del teclado. Si el personaje
## iba andando, se para como si hubiera soltado la tecla (termina el paso y
## frena); no hay ningun corte en seco.
var control_bloqueado := false
## Deja andar pero no saltar: junto a una puerta, arriba es "empujar".
var salto_bloqueado := false
## SUELO VARIABLE (2026-10-13). Si el nivel lo da, suelo_en.call(x) es la y del
## suelo en x (la del nodo cuando pisa ahi: encima de un bloque, su cara de
## arriba). Sin el, el suelo es siempre la altura de donde despega.
##   - Andando o corriendo con la tecla hacia un borde, al llegar se deja caer
##     sin pararse: salta solo justo antes (el salto andando o corriendo de
##     siempre, despegando en el borde) y aterriza en el suelo de abajo, y con
##     la tecla pulsada sigue andando. El usuario: "tienes que seguir andando y
##     de forma natural dejarse caer".
##   - Saltando, aterriza en el suelo que tenga debajo al bajar, mas bajo que el
##     despegue (de un bloque al suelo) o mas alto (encima de un bloque, si el
##     cuerpo llega). En el aire, una cara mas alta que los pies es una pared.
##     Ver SALTAR ENCIMA.
## En el aire el nodo sigue a la altura del despegue y el sprite baja por debajo
## (el arco); al tocar suelo el nodo baja lo que faltaba (_aterrizar_abajo).
## Por debajo del despegue cae con gravedad_caida (sin luz): con la del salto
## andando (1465 px/s^2) bajar el muro alto flotaba, mas de un segundo en el aire.
var suelo_en: Callable
@export var gravedad_caida: float = 1841.0   # la del salto de parado, medida (~la real a esta escala)
## Hasta donde llega un salto con suelo variable (las caras las lleva el vuelo):
## los limites del mundo, que pone el nivel. Sin ellos no hay tope.
var limites_salto := Vector2(-INF, INF)
## Este salto es dejarse caer de un borde andando: el saltito del video, sin el
## arco de mas del salto andando (con el, de una mesa a un escalon pasaba por
## encima del escalon); por debajo del despegue cae con gravedad_caida.
var _salto_borde := false
## SALTAR ENCIMA (2026-10-13). El usuario: "los saltos no valen para nada, no
## suben nada aunque pudieran" y "los de media altura, ademas de escalarlos,
## deberiamos poder saltarlos". Con el arco de siempre los pies pasaban del
## sillar mediano (172 px) solo encogidos: el cuerpo no subia lo bastante para
## caer encima con la pose de tocar suelo (al pasar la cara tocaba de golpe, un
## tiron de 30 px hacia arriba), y para llegar habia que pulsar en una ventana
## de 0,2 s. Como los saltos de contexto de otros plataformas (Inside, Limbo,
## Another World: se salta a donde se puede subir), al despegar sin luz mira la
## primera cara mas alta que tenga delante (hasta salto_encima_alcance px) y, si
## llega, sube lo justo para caer encima (el cuerpo salto_encima_holgura px por
## encima de lo que pide la pose de tocar suelo alli, sin pasar de
## salto_andando_altura_max) y avanza lo justo para estar encima antes de que
## el cuerpo baje de alli: sin dar contra la cara si puede, y como mucho a
## salto_encima_empuje_max por velocidad_andar. Asi lo hace el andando, y el de
## parado con la tecla hacia la cara (sin tecla salta en el sitio). La
## holgura es lo que cae encima: con menos, las piernas bajaban de golpe.
@export var salto_andando_altura_max: float = 175.0
@export var salto_encima_alcance: float = 300.0
@export var salto_encima_holgura: float = 24.0
@export var salto_encima_empuje_max: float = 1.4
## Lo que el nodo pasa de la cara antes de que el cuerpo baje de alli.
const ENCIMA_PASA := 12.0
## Saltando a algo bajo, el arco no baja de esto por el de siempre (del
## escalon a la mesa, 49 px, subia 133 px: el salto entero para un escalon).
const ENCIMA_ARCO_MIN := 0.5
## En el aire, lo que le puede faltar al cuerpo para caer encima de algo al pasar
## su cara: lo que sube de golpe al tocar alli.
const ENCIMA_TIRON := 10.0
## Bajando, si el suelo sube (pasa por encima de una cara): fotograma y altura
## del suelo desde donde se reparten los que quedan, y en cuanto tiempo.
var _ancla_suelo := 0.0
var _ancla_tau := 0.0
var _ancla_t := 0.0
var _ancla_dura := 0.0
## La altura del cuerpo (sobre el despegue) con la que toca encima de lo que
## apunta el salto en curso (NAN si no apunta a nada): la bajada se reparte
## desde el apogeo hasta ahi, y no solo desde que pasa la cara.
var _encima_suelo := NAN
## Deja andar pero no correr: el doble toque (y andar_hasta corriendo, y el
## giro corriendo) sale andando. Con el baston en la mano solo se anda.
var correr_bloqueado := false
## Limites del mundo en x. Mas alla, la tecla hacia ese lado no cuenta: se para
## terminando el paso, igual que al soltar. La frenada recorre hasta ~340 px
## corriendo, asi que el limite no es una pared exacta: dejar ese margen.
@export var limite_izquierdo: float = -INF
@export var limite_derecho: float = INF
## Cuanto antes del limite deja de contar la tecla, segun el paso: lo que
## recorre como mucho desde que suelta hasta quedarse quieto. Andando son la
## espera a un apoyo bueno (hasta 131 px) y la frenada (50-56); corriendo, la
## espera a la fase de la parada (hasta 341) y su frenada. Con 0 (por defecto)
## el limite es donde deja de contar la tecla y la frenada lo pasa.
@export var frenada_limite_andar: float = 0.0
@export var frenada_limite_correr: float = 0.0
## Recorrido de un salto, para recortarlo junto a un limite (ver
## _impulso_hasta_limite), medido del despegue al reposo soltando la direccion.
## Saltar andando: 165 px con 192 px/s, proporcional al impulso (0,86 s; 0,9
## con margen). Salto corriendo: 452 px con 435 px/s, pero no proporcional: al
## caer resbala en aterrizaje_correr a una velocidad fija (la mitad de la de
## correr, frenando), unos 45 px pase lo que pase. Se toma 0,95 s por px/s mas
## esos 45 px, que da 458 para el salto entero.
const RECORRIDO_SALTO_CORRER := 0.95
const RESBALE_SALTO_CORRER := 45.0
const RECORRIDO_SALTO := 0.9
## Distancia a la que andar_hasta() da el objetivo por alcanzado y suelta el
## eje. La parada de andar recorre 50-130 px tras soltar.
@export var margen_llegada: float = 70.0
var _objetivo_x := NAN
var _objetivo_correr := false
var _esperando_llegada := false
## Agacharse (tecla abajo). Mantenerla lo deja agachado; soltarla, se levanta.
## Agachado no se desplaza ni salta: para hacer otra cosa hay que levantarse.
## Si se pulsa andando o corriendo, frena como si se soltara la direccion y se
## agacha al quedar quieto; en el aire, al caer.
## Cualquier cambio a medias se deshace por el mismo camino: soltar mientras
## baja lo vuelve a subir desde la pose en que iba (la misma animacion hacia
## atras), y volver a pulsar mientras se levanta lo vuelve a bajar. Asi nunca
## salta de pose. Sale de raw/master_mason/anim/magnus_agacharse.
@export var agacharse_activo: bool = true
## Volumen del roce de la ropa al bajar y al levantarse.
@export var agacharse_db: float = -16.0
## Un toque agachado da un solo paso (paso_agachado). Apagado (2026-10-06): con
## los dos videos se veian dos movimientos y el usuario prefirio lo de antes
## (arranque, ciclo y parada: dos pasos).
@export var paso_agachado_activo: bool = false
## Andar agachado: agachado, con la direccion hacia donde mira, arranca
## (arranque_agachado), anda (andar_agachado) y, soltando la direccion o la tecla
## abajo, sigue hasta un punto del paso desde el que la parada casa y se para
## (parada_agachado), que acaba en el agachado; sin la tecla abajo, ahi se
## levanta. Quieto y agachado, la direccion contraria lo gira sin levantarse
## (giro_agachado, de un video: 65 fotogramas a 24 fps, 2,8 s, por detras, todos
## a su ritmo; voltea al terminar); andando agachado no, primero se para.
## El ciclo va movido por la distancia, como andar y correr, para que los pies no
## patinen: velocidad y avance no son libres, velocidad = 20 * avance da 3 ticks
## de fisica justos por fotograma (20 fotogramas por segundo, algo mas lento que
## el video, 24). El avance es lo que retrocede el pie apoyado en los sprites:
## 9,8 px de master el pie cercano y 8,8 el lejano (perspectiva); con la media,
## 9,3, ninguno patina mas de medio px. En el juego, la mitad por la escala de la
## hoja. 93 px/s: la mitad de andar, a hurtadillas.
## Sale de raw/master_mason/anim/magnus_andar_agachado.
@export var velocidad_agachado: float = 93.0
@export var avance_agachado: float = 4.65
## Cuanto se espera, como mucho, a un punto del paso desde el que pararse
## (fotogramas del ciclo); el ciclo entero, 42, es esperar siempre.
@export var espera_parada_agachado: int = 42
## Las pisadas agachado suenan mas flojas que andando: esto se suma a pasos_db.
@export var pasos_agachado_db: float = -8.0
## Niveles de sonido. Los archivos estan a -6 dBFS de pico; esto es lo que se
## les baja en el juego.
@export var pasos_db: float = -6.0
## La respiracion responde al ESFUERZO, no al estado. Un bucle a volumen fijo
## mientras estas parado es un metronomo y en diez segundos molesta. Ahora hay
## una cuenta de esfuerzo de 0 a 1 que sube corriendo, andando y saltando y baja
## en reposo; el volumen va de respiracion_tranquilo_db (esfuerzo 0) a
## respiracion_db (esfuerzo 1), y al llegar a cero se apaga. Parado sin mas no
## suena; tras correr entra fuerte y se va en respiracion_recuperacion segundos.
## Al acabar la cinematica de entrada (se ha estampado y levantado) empieza a 1.
@export var respiracion_db: float = -22.0
## -40 o menos es apagada del todo.
@export var respiracion_tranquilo_db: float = -40.0
## Segundos de reposo para pasar de esfuerzo 1 a 0.
@export var respiracion_recuperacion: float = 7.0
## Segundos de correr y de andar para llegar a esfuerzo 1, y lo que suma un salto.
@export var esfuerzo_correr: float = 4.0
@export var esfuerzo_andar: float = 20.0
@export var esfuerzo_salto: float = 0.35
## Para que el bucle no sea un metronomo: cada ciclo varia el volumen al azar
## dentro de +-esta cifra, y con esta probabilidad se salta un ciclo entero.
## El tono no se toca: cambiarlo alargaria o acortaria el ciclo y la respiracion
## se desfasaria del pecho.
@export var respiracion_variacion_db: float = 2.0
@export var respiracion_saltar_ciclo: float = 0.25
## Variacion de tono entre pisadas para que no suenen a metralleta.
@export var pasos_variacion: float = 0.03
## Salto pedido antes de poder hacerlo: se recuerda este tiempo (segundos de
## fisica) y sale en cuanto se puede. Sin esto, pulsar un poco antes de que
## termine de caer, o durante el giro, no hacia nada y parecia que el juego no
## respondia. Durante el giro se mantiene vivo hasta que el giro acaba.
@export var margen_salto: float = 0.15
## Reposo sin respiracion audible: al dar la vuelta el bucle (el valle entre dos
## respiraciones) a veces se sostiene un poco, para que la misma respiracion de
## 2,5 s no se lea como un bucle al minuto de estar quieto. Solo con la
## respiracion callada: con ella sonando, el pecho tiene que ir con el audio.
@export var reposo_pausa_prob: float = 0.35
@export var reposo_pausa_min: float = 0.4
@export var reposo_pausa_max: float = 1.2

## Sprite en que planta cada pie (medido en 04_limpios: maxima separacion de los
## pies al andar, pie que toca el suelo al correr) -> golpe que suena.
const PISADAS := {
	"andar": {
		0: preload("res://assets/audio/magnus_paso_a.wav"),
		16: preload("res://assets/audio/magnus_paso_b.wav"),
	},
	"correr": {
		4: preload("res://assets/audio/magnus_paso_correr_a.wav"),
		16: preload("res://assets/audio/magnus_paso_correr_b.wav"),
	},
	# Agachado, el talon del pie que llega toca el suelo (el cercano en el
	# sprite 17, el lejano en el 38). Las mismas pisadas que andando, mas flojas
	# (pasos_agachado_db).
	"andar_agachado": {
		17: preload("res://assets/audio/magnus_paso_a.wav"),
		38: preload("res://assets/audio/magnus_paso_b.wav"),
	},
}

enum Estado { REPOSO, ARRANQUE_ANDAR, ANDAR, PARADA_ANDAR,
			  ARRANQUE_CORRER, CORRER, PARADA_CORRER, SALTAR, GIRO,
			  CAYENDO, CAIDA, TUMBADO, LEVANTARSE, ATERRIZAJE_CORRER,
			  AGACHANDO, AGACHADO, INCORPORANDO, ARRANQUE_AGACHADO, ANDAR_AGACHADO,
			  PARADA_AGACHADO, GIRO_AGACHADO, PASO_AGACHADO }

## Estados de la cinematica de entrada: sin control del jugador.
const CINEMATICA := [Estado.CAYENDO, Estado.CAIDA, Estado.TUMBADO, Estado.LEVANTARSE]
## Agacharse: bajando, agachado (bucle) y levantandose.
const AGACHADO := [Estado.AGACHANDO, Estado.AGACHADO, Estado.INCORPORANDO,
					Estado.ARRANQUE_AGACHADO, Estado.ANDAR_AGACHADO, Estado.PARADA_AGACHADO,
					Estado.GIRO_AGACHADO, Estado.PASO_AGACHADO]
## "agacharse" sale de un video pedido para el (magnus_agacharse_flow): empieza en
## el reposo del juego, baja de un tiron, se pasa un poco y sube despacio hasta el
## agachado del juego (c_089), y entra en el bucle por el AGACHADO_ANTES_DE_SUBIR.
## Antes estaba hecho a trozos del video viejo (puente, bajada y el levantarse al
## reves) para esquivar su rebote, y los empalmes se notaban. Soltar la tecla en
## cualquier punto lo deshace hacia atras desde ese fotograma.
## Fotograma del bucle "agachado" que va justo antes del primero de
## "incorporarse" (el c_089, 139 del video): por ahi entra al bucle al acabar de
## agacharse y se vuelve a el si se deshace el levantarse hasta el final. El
## bucle es la ida y vuelta c_077..c_089 (24 fotogramas, 12 fps): en el tramo
## entero del video la cabeza daba saltitos de 1 px.
const AGACHADO_ANTES_DE_SUBIR := 12
## Andar agachado. Andando agachado va mas erguido y con la zancada abierta:
## ningun fotograma del ciclo (42) casa con el agachado quieto (a 4,7-5,6 pasos), por
## eso hay arranque y parada, sacados del mismo video. Medidos sobre los sprites
## (distancia en pasos del ciclo, 0,170), ver
## raw/master_mason/anim/magnus_andar_agachado/como_se_hizo.txt y tablas.py:
##   agachado -> arranque        1,0-1,5 pasos, desde cualquier fotograma del bucle
##   arranque -> ciclo           por el ENTRADA_AGACHADO, 1,0 pasos (un paso normal;
##                               por el 21, que era antes, 1,45: un tiron)
##   ciclo -> parada             solo desde los fotogramas de PARADA_AGACHADO_DESDE
##                               (0,8-1,3 pasos); la parada empieza con un pie
##                               concreto y desde la otra media zancada salta 3
##   parada -> agachado          por el PARADA_AGACHADO_A_AGACHADO, 0,6 pasos
const ENTRADA_AGACHADO := 20
## fotograma del ciclo -> fotograma de parada_agachado por el que se entra.
const PARADA_AGACHADO_DESDE := {40: 0, 41: 0, 0: 0, 1: 1, 2: 2, 3: 4}
const PARADA_AGACHADO_A_AGACHADO := 5
## Hasta este fotograma del arranque aun no ha movido los pies: soltar lo deja
## agachado sin mas. Luego el paso ya esta dado y se termina.
const ARRANQUE_AGACHADO_QUIETO := 3
## Un solo paso agachado (paso_agachado, magnus_paso_agachado): el pie de delante
## sale, el cuerpo avanza sobre el y el de atras se junta; de agachado a agachado,
## 39 px mas alla. Si se suelta la direccion (sin soltar abajo) en los primeros
## fotogramas del arranque, que todavia son el agachado (los pies no se han
## movido), se pasa a el: un toque da un paso. Antes daba dos, porque la parada
## solo cierra con el otro pie y habia que pasar por medio ciclo. Mantenida, sigue
## el arranque y el ciclo. Fotograma del arranque -> fotograma del paso por el que
## se entra (0,08-0,18 de distancia; desde el 5 ya no casa).
const ARRANQUE_A_PASO := [0, 1, 1, 1, 1]
## Lo que se espera agachado, con la direccion pulsada, antes de arrancar a andar:
## si se suelta antes, es un toque y da un paso (paso_agachado) sin pasar por el
## arranque. Pasado esto, arranca; soltar en sus fotogramas 0-4 aun da el paso.
const TOQUE_AGACHADO := 0.2
## Avance del nodo (px del juego) en cada fotograma del paso: lo que avanza el
## cuerpo en el video (montar.py lo imprime); los sprites van retrasados eso
## mismo, asi que los pies apoyados no se mueven.
const AVANCE_PASO_AGACHADO := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
		0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
		0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0,
		1.5, 3.0, 4.0, 6.0, 8.0, 9.5, 11.5, 13.5, 15.5, 17.5, 19.5, 21.0, 22.5, 24.0, 25.5, 26.0, 27.0,
		27.5, 28.0, 29.0, 30.0, 30.5, 31.0, 32.0, 33.5, 34.5, 35.0, 35.0, 36.0, 36.0, 36.5, 37.0, 37.0,
		37.5, 37.5, 38.0, 38.5, 38.5, 38.5, 39.0, 39.0, 39.0, 39.0, 39.0]
## Cuanto ha avanzado el nodo (px del juego) en cada fotograma del arranque y de
## la parada: lo que retrocede el pie apoyado en los sprites (magnus_andar_agachado/
## avance.py y como_se_hizo.txt), suavizado. El arranque acaba a 4,4 px por
## fotograma, casi los 4,65 del ciclo; la parada frena de 4,7 a 0 en 16.
const AVANCE_ARRANQUE_AGACHADO := [0.0, 0.0, 0.3, 0.5, 1.6, 2.8, 4.4, 6.3, 8.5, 11.0, 13.7, 16.7,
		19.3, 22.0, 24.7, 27.5, 30.7, 34.0, 37.3, 40.2, 43.2, 46.4, 49.7, 53.1, 56.6, 60.6, 65.0]
const AVANCE_PARADA_AGACHADO := [0.0, 4.8, 9.5, 14.0, 18.5, 23.0, 27.0, 31.0, 34.5, 38.0, 41.5,
		44.0, 46.5, 49.0, 51.0, 52.2, 53.0, 53.0, 53.0, 53.0, 53.0, 53.0, 53.0, 53.0, 53.0, 53.0,
		53.0, 53.0, 53.0, 53.0, 53.0]
const SONIDOS_AGACHARSE := {
	"bajar": preload("res://assets/audio/magnus_agacharse.wav"),
	"subir": preload("res://assets/audio/magnus_incorporarse.wav"),
}

var _estado: Estado = Estado.REPOSO
var _mirando := 1.0          # 1 derecha, -1 izquierda
var _recorrido := 0.0        # para mover la animacion con la distancia
var _impulso := 0.0          # velocidad que llevaba al despegar, se conserva en el aire
var _corria_al_saltar := false
var _saltaba_parado := false  # salto desde el reposo: animacion salto_parado
var _frenando_desde := 0.0   # velocidad que llevaba al empezar a frenar
var _velocidad_suelo := 0.0  # la que traia al entrar en un arranque por pose; sostiene hasta que la rampa la alcanza
var _parada_espera := 0      # ticks esperando un apoyo bueno para parar de andar
var _parada_entrada := 0     # fotograma de la parada por el que se entro
var _giro_pendiente := 0.0   # hacia donde hay que girar cuando acabe de frenar
var _giro_corriendo := false
var _giro_destino := 0.0     # hacia donde mira al acabar la animacion de giro
var _ultima_pulsacion := {}  # accion -> instante (de _reloj), para detectar el doble
var _reloj := 0.0            # segundos de fisica desde que existe el nodo
var _ultimo_fotograma := -1  # el ultimo que puso este script, para no repetir pisadas
var _fundido: Tween         # fundido de la respiracion al salir del reposo
var _esfuerzo := 0.0         # 0 descansado .. 1 agotado; manda en la respiracion
var _resp_pos := 0.0         # posicion del bucle de respirar en el ultimo tick, para ver cuando da la vuelta
var _resp_ciclo_db := 0.0    # variacion de volumen del ciclo en curso (o -80 si se salta)
var _resp_base_db := -40.0   # volumen que pide el esfuerzo, suavizado; el ciclo se le suma aparte
var _salto_pedido := -99.0   # instante (de _reloj) del ultimo salto pedido que no se pudo hacer
var _carrerilla := 0.0       # 0..1, ver carrerilla_activa
var _salto_impulso := 1.3    # empuje, ritmo en el aire y arco del salto corriendo en curso,
var _salto_vuelo := 0.75     #   fijados al saltar segun la carrerilla
var _arco_max := 80.0
var _arco_amp := 80.0        # amplitud del arco ahora (baja hacia el brinco corto al soltar)
var _arco_t := -1.0          # por donde iba el vuelo (0..1) el tick anterior; -1 aun en el suelo
var _arco_t0 := -1.0         # fotogramas de vuelo que marcaba el sprite en el primer tick del vuelo (ver arco_desde_despegue)
var _salto_soltado := false  # se solto la tecla de salto en la subida (altura variable)
var _t_soltado := 0.0        # por donde iba el vuelo (0..1) al soltarla
var _sobrante := 0.0         # px/s por encima de la de correr tras caer corriendo; se apaga solo
var _agachar_atras := false  # la animacion de agacharse/levantarse va hacia atras (deshaciendose)
var _parando_agachado := -1  # andando agachado: fotogramas esperando un apoyo para pararse (-1 = no para)
var _x_tabla := 0.0          # arranque y parada agachado: x del nodo en el fotograma 0 de su tabla de avance
var _agachado_desde := 0     # fotograma del bucle agachado en que arranco (para volver si se suelta)
var _toque_agachado := -1.0  # _reloj al pulsar hacia delante agachado (-1: nada pendiente)
var _vuelo := 0              # salto de parado o andando: 0 aun en el suelo, 1 subiendo, 2 bajando, 3 ya ha tocado
var _vuelo_y := 0.0          # altura del cuerpo sobre la del despegue (px, arriba +), integrada
var _vuelo_v := 0.0          # su velocidad (px/s, arriba +)
var _vuelo_cima := 0.0       # altura del apogeo, al pasarlo
var _vuelo_tau := 0.0        # fotograma que toca (con fraccion)
var _luz := 0.0              # luz que aligera donde esta el cuerpo (0..1), del ultimo tick
var _f_g := 1.0              # gravedad del vuelo sin luz (px/s^2) y su ritmo (fotogramas/s)
var _f_ritmo := 60.0
var _f_tau_ref := 0.0        # subiendo, el fotograma va de aqui con lo que se gasta de esta velocidad
var _f_v_ref := 0.0
var _f_tau_cima := 0.0       # fotograma del apogeo, desde donde reparte la bajada
var _f_corte := 1.0          # gravedad de mas subiendo con la tecla suelta (altura variable del corriendo)
var _f_v0 := 0.0             # velocidad de despegue de este salto (px/s)
var _deriva := 0.0           # px/s de lado que le ha dado el jugador en el aire, en la luz (ver deriva_max)
var _vuelo_de := &""         # el salto de este vuelo (su clave en VUELO), aunque se vea otra animacion
var _flota := false          # baja flotando con las animaciones de flotar (ver FLOTAR CON SUS ANIMACIONES)
var _pisando := false        # apoyado en una hoja de la luz, antes de despegar de ella (ver PISAR LA HOJA)
var _cinematica_nivel := false  # el nivel lleva al personaje (ver tomar_cinematica)
var _pisar_hoja: Dictionary = {}
var _pisar_t := 0.0
var _pisar_dx := 0.0         # x del nodo respecto a la hoja al apoyarse
var _pisar_fuerza := 1.0
var _pisar_arco := 0.0
var _flota_iv := 0.0         # por donde va en la bajada flotando (fotograma de la secuencia salto + flotar_bajar)
var _quieto := -1.0          # flotando quieto: fotograma de flotar_quieto (ver FLOTAR QUIETO); -1 si no
var _flotar := {}            # flotar.json (vacio si no esta)
var _giro_aire := 0.0        # girandose en el aire hacia ahi (-1/1), 0 si no (ver GIRAR EN EL AIRE)
var _giro_aire_pedido := 0.0 # pedido, esperando a que la pose case o a que quepa
var _giro_iv := 0.0          # fotograma del giro en el aire
var _tras_giro := false      # flotando tras girarse: la luz lo sostiene (giro_aire_caida_min)

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _pasos: AudioStreamPlayer = $Pasos
@onready var _respiracion: AudioStreamPlayer = $Respiracion

func _ready() -> void:
	_cargar_flotar()
	_sprite.animation_finished.connect(_al_terminar)
	_sprite.frame_changed.connect(_al_cambiar_fotograma)
	_sprite.animation_looped.connect(_al_dar_vuelta)
	_poner("reposo")

func _unhandled_input(evento: InputEvent) -> void:
	if _en_cinematica() or control_bloqueado:
		return
	# Agachado, o con la tecla abajo pulsada en el suelo, no se salta ni se
	# arranca: primero hay que levantarse. En el aire si, que el salto guardado
	# y la direccion al caer siguen valiendo.
	if _en_agachado() or (_quiere_agacharse() and _estado != Estado.SALTAR):
		return
	if evento.is_action_pressed("saltar"):
		# Si ahora no se puede (en el aire, agachado al caer, girando), se
		# recuerda margen_salto segundos y lo lanza _physics_process. Guardarlo
		# no toca nada: ni impulso ni esfuerzo hasta que el salto sale de verdad.
		if _puede_saltar():
			_saltar()
		elif not salto_bloqueado:
			_salto_pedido = _reloj
		return
	for accion in ["mover_izquierda", "mover_derecha"]:
		if not evento.is_action_pressed(accion):
			continue
		# Reloj de la fisica, no Time.get_ticks_msec(): ese es reloj de pared, y
		# grabando con Movie Maker el juego va al 4 % de la velocidad real, con
		# lo que dos toques a 0,2 s de juego estaban a 5 s de pared y el doble
		# toque no se reconocia (salia andando en vez de corriendo).
		# Contra un limite del mundo, la tecla hacia ese lado no hace nada.
		if _fuera_de_limite(-1.0 if accion == "mover_izquierda" else 1.0):
			continue
		var ahora := _reloj
		var antes: float = _ultima_pulsacion.get(accion, -99.0)
		_ultima_pulsacion[accion] = ahora
		if ahora - antes <= doble_pulsacion:
			# Doble toque hacia el otro lado: el primer toque ya lanzo el giro y
			# el segundo llega con el giro a medias. Arrancar aqui lo cortaba
			# (volteo en seco con el sprite de otro angulo); lo que toca es
			# que el giro termine y salga corriendo, que es lo que hace
			# _al_terminar con _giro_corriendo.
			if _estado == Estado.GIRO:
				_giro_corriendo = not correr_bloqueado
			else:
				var desde_reposo := _estado == Estado.REPOSO
				_arrancar(accion, true)
				# Doble toque desde parado (lo normal: el primer toque suelta en la
				# zona muerta del arranque de andar y vuelve a reposo): el arranque
				# de correr entra por el 3 y no por el 0. Sigue quieto hasta el 5,
				# pero la pose esta mas cerca del reposo (0,67 pasos frente a 0,84)
				# y echa a correr 0,1 s antes.
				if desde_reposo and _estado == Estado.ARRANQUE_CORRER:
					_sprite.frame = ARRANQUE_CORRER_DESDE_REPOSO
		elif _puede_arrancar():
			_arrancar(accion, false)

func _physics_process(delta: float) -> void:
	_reloj += delta
	# En la cinematica de entrada el nodo lo mueve el tween de la caida y las
	# animaciones se encadenan solas: aqui no hay nada que hacer.
	if _en_cinematica():
		return
	_actualizar_esfuerzo(delta)
	_apagar_sobrante(delta)
	var direccion := _eje()
	# Con la tecla abajo en el suelo la direccion no cuenta: andando o corriendo
	# frena como al soltar, y al quedar quieto se agacha.
	var abajo := _quiere_agacharse()
	if abajo and _estado != Estado.SALTAR and not _en_agachado():
		direccion = 0.0
	_actualizar_carrerilla(delta, direccion)
	_avisar_llegada()

	if _en_agachado():
		_actualizar_agachado(abajo, direccion)
		_avanzar_agachado(delta)
		_actualizar_saltos()
		return
	if abajo and _estado == Estado.REPOSO:
		_cambiar(Estado.AGACHANDO)
		return

	# Girando no se acepta nada: cortarlo a medias deja al
	# personaje mirando a un sitio con el sprite de otro. Un salto pedido
	# mientras tanto se guarda vivo y sale al terminar el giro (_al_terminar).
	if _estado == Estado.GIRO:
		_sprite.speed_scale = giro_ritmo
		if _salto_en_espera():
			_salto_pedido = _reloj
		return

	# Soltar la tecla lanza la frenada. En los arranques, pasada la zona muerta,
	# se termina el arranque y se para desde el ciclo (ver abajo).
	if is_zero_approx(direccion):
		_giro_pendiente = 0.0   # soltar cancela el cambio de sentido
		var arrancando := _estado == Estado.ARRANQUE_ANDAR or _estado == Estado.ARRANQUE_CORRER
		if arrancando and (_velocidad() <= 0.0 \
				or (_estado == Estado.ARRANQUE_ANDAR and _sprite.frame <= arranque_andar_de_pie)):
			# Soltar en la zona muerta del arranque: los pies casi no se han
			# movido y no hay nada que frenar. La parada empieza a media zancada
			# -- esta hecha para venir del ciclo -- y metida aqui es un fotograma
			# que no encaja con nada. Pasaba con cada doble pulsacion real, que
			# suelta entre toque y toque (80-120 ms, arranque f2-f3): arranque ->
			# parada f0 -> arranque de correr f6, tres poses sueltas en 0,2 s.
			# De pie a pie es 0,23 pasos.
			_cambiar(Estado.REPOSO)
		elif _estado == Estado.ANDAR:
			_pedir_parada_andar()
		elif _estado == Estado.ARRANQUE_ANDAR:
			# Pasada la zona muerta el paso ya esta dado, y se termina. Ningun
			# fotograma del primer paso del arranque casa con la parada (1,9-2,6
			# pasos; el tope es tolerancia_parada_andar, 1,3): cortar aqui era un
			# salto de pose, "hace el movimiento, se corta y reinicia". Sigue el
			# arranque, entra al ciclo por su corte y ahi _pedir_parada_andar
			# espera el primer apoyo que case (el 24-25 del ciclo): un toque
			# corto da un paso entero, unos 0,7 s, y se para con su animacion.
			pass
		elif _estado == Estado.CORRER:
			_pedir_parada_correr()
		elif _estado == Estado.ARRANQUE_CORRER:
			# Lo mismo corriendo: ningun fotograma del arranque casa con la
			# parada (1,6-2,4 pasos), y entrar en ella aqui era el mismo salto de
			# pose. Sigue el arranque hasta el ciclo (corte_arranque_correr) y
			# ahi _pedir_parada_correr espera a la fase que casa: soltar a medio
			# arranque son 0,5-1 s mas de carrera y la parada entera.
			pass
	elif _en_movimiento():
		_parada_espera = 0   # volver a pulsar cancela la parada que estaba esperando
		# Cambiar de sentido no puede ser un volteo en seco a toda velocidad:
		# se pasa por la frenada y, ya casi quieto, _resolver_giro lanza la
		# animacion de giro.
		if signf(direccion) != _mirando:
			_giro_pendiente = signf(direccion)
			_giro_corriendo = _corriendo()
			if _estado == Estado.ANDAR:
				# La misma entrada por pose que al soltar (_pedir_parada_andar),
				# pero sin esperar al apoyo: cambiar de sentido no espera. Entrar
				# siempre por el f0 era un salto de pose de 1,1 a 3,8 pasos.
				var entrada: int = pose_andar_a_parada[clampi(_sprite.frame, 0, pose_andar_a_parada.size() - 1)]
				_cambiar(Estado.PARADA_ANDAR)
				_sprite.frame = entrada
				_parada_entrada = entrada
			else:
				_cambiar(Estado.PARADA_CORRER if _corriendo() else Estado.PARADA_ANDAR)
	elif _estado == Estado.SALTAR and _sprite.animation == "salto_correr" \
			and _progreso() >= _aterrizaje() and signf(direccion) == _mirando:
		# Saltando a la carrera con la tecla pulsada: en cuanto toca suelo sigue
		# corriendo, directo al ciclo y a la velocidad que traia. Sin frenazo.
		_seguir_corriendo_tras_salto()
	elif _puede_cortar_salto():
		# Ya ha caido y sigue con la tecla pulsada: sale andando sin esperar a
		# que termine de recomponerse. Aqui no vale mirar solo las pulsaciones,
		# porque si la tecla no se ha soltado no hay ninguna nueva.
		_arrancar("mover_derecha" if direccion > 0.0 else "mover_izquierda", _corria_al_saltar)
	elif _puede_arrancar() and _giro_pendiente != signf(direccion):
		# Direccion mantenida sin pulsacion nueva: la tecla venia pulsada de
		# antes (durante la cinematica, o cambiada a mitad de un giro), o la
		# pone andar_hasta. Las pulsaciones nuevas ya han arrancado en
		# _unhandled_input, que va antes que este tick, asi que el doble toque
		# no cambia. Andando por teclado arranca andando; andar_hasta, como
		# pidiera. Hacia atras, _arrancar deja el giro para cuando haya frenado;
		# si ya hay uno pendiente hacia ese lado no se vuelve a pedir, que le
		# quitaria el correr a un cambio de sentido corriendo.
		var corriendo := _objetivo_correr if control_bloqueado else false
		_arrancar("mover_derecha" if direccion > 0.0 else "mover_izquierda", corriendo)

	_resolver_giro()

	# El arranque de correr termina antes de que se acabe la animacion, asi que
	# aqui no sirve animation_finished: hay que mirar el fotograma.
	if _estado == Estado.ARRANQUE_CORRER and _sprite.frame >= _ultimo_util():
		_cambiar(Estado.CORRER)
	elif _estado == Estado.ARRANQUE_ANDAR and corte_arranque_andar > 0 and _sprite.frame >= _ultimo_util():
		_cambiar(Estado.ANDAR)

	# Andando hacia un borde (SUELO VARIABLE): salta solo para despegar en el
	# borde y dejarse caer al suelo de abajo, sin pararse.
	if _borde_delante(direccion):
		_saltar()
		_salto_borde = true

	# Salto guardado: sale en cuanto se puede. Va despues de lo de arriba a
	# proposito: con la tecla pulsada, el corte del salto anterior ya ha salido
	# andando y este sale como salto andando, no como uno de parado en mitad
	# de la marcha.
	# En la cola del salto corriendo se mantiene vivo, como en el giro: es
	# corta (0,1 s) y el salto tiene que salir en cuanto entra el aterrizaje.
	# Igual en los fotogramas quietos del arranque de correr: sale al coger
	# velocidad, como salto corriendo.
	if _salto_en_espera():
		if _puede_saltar():
			_saltar()
		elif _salto_en_cola_correr() or _arrancando_a_correr_quieto():
			_salto_pedido = _reloj

	var velocidad := _velocidad()
	if velocidad > 0.0:
		var paso := velocidad * delta
		if _estado == Estado.SALTAR and suelo_en.is_valid():
			position.x = _avance_en_el_aire(position.x + paso * _mirando)
		else:
			position.x += paso * _mirando
		_recorrido += paso
		# Solo los bucles mueven la animacion con la distancia. Arranques y
		# paradas van a fps fijo: ahi el personaje acelera o frena y no hay
		# relacion constante entre lo que avanza y la pose.
		if _estado == Estado.ANDAR or _estado == Estado.CORRER:
			var avance := avance_andar if _estado == Estado.ANDAR else avance_correr
			var n := _sprite.sprite_frames.get_frame_count(_sprite.animation)
			# El epsilon es por la frontera exacta: 192/60 da 3,2 px por tick y el
			# avance es 6,4, o sea 2 ticks justos por fotograma, pero ni 3,2 ni
			# 6,4 son exactos en binario y la suma se queda en 6,3999...; sin el
			# margen ese fotograma dura un tick de mas y el siguiente uno de
			# menos. Correr no lo sufre porque 435/60 = 7,25 y 14,5 si son
			# exactos. Medido: 4 fotogramas descuadrados de cada 107 al andar.
			var fotograma := int(_recorrido / avance + 1e-6) % n
			if _estado == Estado.ANDAR and not avance_ciclo_andar.is_empty():
				fotograma = _fotograma_andar(_recorrido)
			_sprite.frame = fotograma
			_pisar(fotograma, n)

	_pedir_giro_aire(direccion)
	_derivar(direccion, velocidad, delta)
	_actualizar_saltos()

## Cuanto avanza el cuerpo ahora mismo.
##
## En arranques y paradas no puede ser la velocidad de crucero: la animacion
## empieza con el personaje quieto y acaba parandolo. Si se aplica la velocidad
## entera desde el primer fotograma, el muneco se desplaza antes de dar el paso
## y parece que patina; y si se pone a cero al soltar la tecla, se queda clavado
## mientras la animacion todavia esta frenando.
func _velocidad() -> float:
	match _estado:
		Estado.ANDAR:
			if not avance_ciclo_andar.is_empty():
				# con un 0 en la tabla la distancia no llegaria nunca al siguiente
				# fotograma y se quedaria clavado andando en el sitio
				return maxf(avance_ciclo_andar[clampi(_sprite.frame, 0, avance_ciclo_andar.size() - 1)], 0.5) * ritmo_ciclo_andar
			return velocidad_andar
		Estado.ANDAR_AGACHADO:
			return velocidad_agachado
		Estado.ARRANQUE_AGACHADO, Estado.PARADA_AGACHADO:
			# El nodo lo lleva la tabla (_avanzar_agachado); esto es solo lo que
			# va, para quien lo pregunte (el panel de datos).
			var tabla: Array = AVANCE_ARRANQUE_AGACHADO if _estado == Estado.ARRANQUE_AGACHADO else AVANCE_PARADA_AGACHADO
			var f := clampi(_sprite.frame, 0, tabla.size() - 2)
			return (tabla[f + 1] - tabla[f]) * _sprite.sprite_frames.get_animation_speed(_sprite.animation)
		Estado.CORRER:
			return velocidad_correr + _sobrante
		Estado.ARRANQUE_ANDAR:
			if corte_arranque_andar > 0:
				var k := clampi(_sprite.frame, 0, avance_arranque_andar.size() - 1)
				return maxf(avance_arranque_andar[k], _velocidad_suelo)
			return maxf(velocidad_andar * _rampa_subida(quieto_al_arrancar_andar), _velocidad_suelo)
		Estado.ARRANQUE_CORRER:
			if corte_arranque_correr > 0:
				var kc := clampi(_sprite.frame, 0, AVANCE_ARRANQUE_CORRER.size() - 1)
				return maxf(AVANCE_ARRANQUE_CORRER[kc], _velocidad_suelo)
			return maxf(velocidad_correr * _rampa_subida(quieto_al_arrancar_correr), _velocidad_suelo)
		Estado.PARADA_ANDAR:
			if not velocidad_parada_andar.is_empty():
				return velocidad_parada_andar[clampi(_sprite.frame, 0, velocidad_parada_andar.size() - 1)]
			var k := clampi(_sprite.frame, 0, frenada_andar_perfil.size() - 1)
			var base: float = frenada_andar_perfil[clampi(_parada_entrada, 0, frenada_andar_perfil.size() - 1)]
			return _frenando_desde * frenada_andar_perfil[k] / maxf(base, 0.05)
		Estado.PARADA_CORRER:
			return _frenando_desde * _rampa_bajada(frenada_correr)
		Estado.SALTAR:
			var p := _progreso()
			var toca := _aterrizaje()
			var a_la_carrera := _sprite.animation == "salto_correr"
			var aire := _impulso * (_empuje_salto_correr() if a_la_carrera else 1.0)
			if p <= toca:
				return aire
			var resto := maxf(1.0 - toca, 0.001)
			if a_la_carrera:
				# Solo se llega aqui soltando la direccion (con ella pulsada se
				# salta al ciclo al tocar suelo). De la velocidad del aire a la de
				# entrada del aterrizaje, en lo que queda de animacion. El salto
				# corriendo exige _impulso > velocidad_andar (ver _saltar), asi que
				# aire >= 250 y esto siempre frena; el minf es por si acaso.
				var fin := minf(velocidad_correr * aterrizaje_correr_velocidad, aire)
				return lerpf(aire, fin, clampf((p - toca) / resto, 0.0, 1.0))
			# Al tocar suelo el impulso se va en lo que queda de aterrizaje.
			return _impulso * maxf(0.0, 1.0 - (p - toca) / (resto * 0.5))
		Estado.ATERRIZAJE_CORRER:
			return velocidad_correr * aterrizaje_correr_velocidad * _rampa_bajada(aterrizaje_correr_frenada)
	return 0.0

## Ultimo fotograma que se usa de la animacion actual. Normalmente el ultimo que
## hay, pero el arranque de correr se corta antes (ver corte_arranque_correr).
func _ultimo_util() -> int:
	var n := _sprite.sprite_frames.get_frame_count(_sprite.animation)
	if _estado == Estado.ARRANQUE_CORRER and corte_arranque_correr > 0:
		return mini(corte_arranque_correr, n - 1)
	if _estado == Estado.ARRANQUE_ANDAR and corte_arranque_andar > 0:
		return mini(corte_arranque_andar, n - 1)
	return n - 1

## 0..1 segun por donde va la animacion de una pasada. Va contra el ultimo
## fotograma UTIL, no contra el ultimo que exista: si no, al cortar el arranque
## la rampa se quedaria a media subida y al entrar en el bucle la velocidad
## pegaria un salto.
func _progreso() -> float:
	var u := _ultimo_util()
	if u <= 0:
		return 1.0
	return clampf(float(_sprite.frame) / float(u), 0.0, 1.0)

## Sube de 0 a 1, pero sin arrancar hasta pasada la parte en que los pies aun
## no se han movido.
func _rampa_subida(zona_quieta: float) -> float:
	var p := _progreso()
	if p <= zona_quieta:
		return 0.0
	return (p - zona_quieta) / (1.0 - zona_quieta)

## Baja de 1 a 0 en la primera parte de la animacion y se queda en 0. No puede
## repartirse por toda la parada: los pies se plantan enseguida y a partir de
## ahi cualquier avance se lee como patinazo.
func _rampa_bajada(tramo: float) -> float:
	if tramo <= 0.0:
		return 0.0
	return maxf(0.0, 1.0 - _progreso() / tramo)

## Soltar la tecla andando: esperar (poco) a un apoyo que case con la parada y
## entrar por el fotograma de la parada mas parecido a la pose actual.
func _pedir_parada_andar() -> void:
	var f := _sprite.frame
	var casa: bool = dist_parada_andar[clampi(f, 0, dist_parada_andar.size() - 1)] <= tolerancia_parada_andar
	if casa or _parada_espera >= espera_parada_andar * 2 or espera_parada_andar <= 0:
		_parada_espera = 0
		var entrada: int = pose_andar_a_parada[clampi(f, 0, pose_andar_a_parada.size() - 1)]
		_cambiar(Estado.PARADA_ANDAR)
		_sprite.frame = entrada
		_parada_entrada = entrada
	else:
		_parada_espera += 1

## Soltar corriendo: esperar a la unica fase que casa con la parada.
func _pedir_parada_correr() -> void:
	var f := _sprite.frame
	var casa: bool = DIST_PARADA_CORRER[clampi(f, 0, DIST_PARADA_CORRER.size() - 1)] <= tolerancia_parada_correr
	if casa or _parada_espera >= espera_parada_correr * 2 or espera_parada_correr <= 0:
		_parada_espera = 0
		_cambiar(Estado.PARADA_CORRER)
	else:
		_parada_espera += 1

func _arrancar(accion: String, corriendo: bool) -> void:
	corriendo = corriendo and not correr_bloqueado
	var hacia := -1.0 if accion == "mover_izquierda" else 1.0
	# Arrancar hacia el otro lado no es arrancar: primero hay que darse la vuelta.
	# Parado, en el acto. Si aun lleva velocidad (una parada a medio frenar, la
	# cola de un salto, el aterrizaje del salto corriendo), el giro se deja
	# pendiente y lo lanza _resolver_giro cuando ha frenado: girar aqui pasaba
	# de 140-514 px/s a cero en un tick. (Aqui nunca se llega en GIRO: el doble
	# toque se desvia antes y _puede_arrancar lo excluye.)
	if giro_activo and hacia != _mirando:
		if _estado == Estado.REPOSO:
			_empezar_giro(hacia, corriendo)
		else:
			# Un doble toque durante la frenada lo convierte en giro corriendo;
			# una pulsacion suelta no le quita el correr que ya llevaba.
			_giro_corriendo = corriendo or (_giro_pendiente == hacia and _giro_corriendo)
			_giro_pendiente = hacia
		return
	# En el aire no se arranca: un doble toque hacia delante saltando cortaba el
	# salto en seco (arco y altura cocida a 0 en un tick). En la cola del salto
	# corriendo hacia delante tampoco: con la tecla pulsada, _physics_process
	# sigue corriendo en este mismo tick (_seguir_corriendo_tras_salto); si se
	# arrancaba aqui, salia andando a 192 desde ~465 px/s.
	if _salto_bloquea() or _salto_en_cola_correr():
		return
	_mirar(hacia)
	# La velocidad que ya llevaba, antes de cambiar de estado.
	#
	# La primera pulsacion de un doble arranca a andar sin remedio: no hay forma
	# de saber que era la primera de un doble hasta que llega la segunda. Lo que
	# si se puede evitar es el escalon de cuando llega. Si el arranque de correr
	# empezase en su fotograma 0, el personaje se pararia en seco -- la rampa de
	# subida vale 0 ahi -- y la animacion volveria a empezar. Medido: con un
	# doble de 0,25 s la velocidad caia de 29,7 a 0 px/s de un tick al
	# siguiente, y andando ya lanzado la caida era de los 229 enteros. Eso es lo
	# que se veia como "arranca a andar, luego corre y fluctua".
	var llevaba := _velocidad()
	var desde_anim := String(_sprite.animation)
	var desde_frame := _sprite.frame
	var nuevo := Estado.ARRANQUE_CORRER if corriendo else Estado.ARRANQUE_ANDAR
	if _estado == nuevo:
		return
	_cambiar(nuevo)
	_enganchar_arranque(llevaba, desde_anim, desde_frame)

## Coloca el arranque en el fotograma cuya rampa ya da la velocidad que se
## llevaba, para que no haya escalon al entrar. Es la inversa de _rampa_subida:
## si la rampa vale (p - zona) / (1 - zona), la p que da una velocidad v es
## zona + (v / crucero) * (1 - zona).
func _enganchar_arranque(llevaba: float, desde_anim: String = "", desde_frame: int = 0) -> void:
	# Saliendo del salto con la tecla pulsada: sigue andando. El cuerpo esta
	# parado (el impulso se apago al tocar suelo) y agachado, asi que la
	# velocidad no dice nada y manda la POSE: POSE_DESDE_SALTO da, para cada
	# sprite del salto desde el que se puede cortar, el fotograma del arranque
	# de andar que mas se le parece. Fuera de la tabla, el arranque desde 0.
	# Del corte_arranque_andar en adelante el arranque ya ES el ciclo, asi que
	# se entra al ciclo por ese mismo fotograma: si se dejaba en el arranque, el
	# corte de _physics_process lo pasaba a andar en el mismo tick y _poner lo
	# llevaba a entrada_andar, y la pose medida (f20-24) no se veia nunca.
	if desde_anim == "saltar" and _estado == Estado.ARRANQUE_ANDAR:
		var i := desde_frame - SALTO_CORTE_DESDE
		if i >= 0 and i < POSE_DESDE_SALTO.size():
			var k: int = POSE_DESDE_SALTO[i]
			if corte_arranque_andar > 0 and k >= corte_arranque_andar:
				_cambiar(Estado.ANDAR)
				_sprite.frame = k
				_recorrido = _recorrido_andar(k)
				_ultimo_fotograma = k
			else:
				_sprite.frame = k
		return
	if llevaba <= 0.0:
		return
	var corriendo := _estado == Estado.ARRANQUE_CORRER
	if corriendo and corte_arranque_correr > 0 and not (desde_anim in ["arranque_andar", "andar"]):
		for k in range(AVANCE_ARRANQUE_CORRER.size()):
			if AVANCE_ARRANQUE_CORRER[k] >= llevaba:
				_sprite.frame = k
				return
		_sprite.frame = AVANCE_ARRANQUE_CORRER.size() - 1
		return
	if not corriendo and corte_arranque_andar > 0:
		for k in range(avance_arranque_andar.size()):
			if avance_arranque_andar[k] >= llevaba:
				_sprite.frame = k
				return
		_sprite.frame = avance_arranque_andar.size() - 1
		return
	# Viniendo de andar, manda la POSE: ver las tablas arriba. La velocidad que
	# se traia se sostiene aparte para que no haya bajon.
	if corriendo and desde_anim in ["arranque_andar", "andar"]:
		var tabla: Array = POSE_DESDE_ARRANQUE_ANDAR if desde_anim == "arranque_andar" else POSE_DESDE_ANDAR
		if desde_frame >= 0 and desde_frame < tabla.size():
			_sprite.frame = tabla[desde_frame]
			_velocidad_suelo = llevaba
			return
	var crucero := velocidad_correr if corriendo else velocidad_andar
	var zona := quieto_al_arrancar_correr if corriendo else quieto_al_arrancar_andar
	var n := _sprite.sprite_frames.get_frame_count(_sprite.animation)
	if n <= 1 or crucero <= 0.0:
		return
	var p := zona + clampf(llevaba / crucero, 0.0, 1.0) * (1.0 - zona)
	_sprite.frame = clampi(int(round(p * (n - 1))), 0, n - 1)

## Lleva al personaje andando (o corriendo) hasta x, sin teclado: bloquea el
## control y emite llegado cuando ya esta parado alli. Mueve la misma maquina de
## estados que las teclas (arranque, ciclo, parada), asi que se ve igual que si
## lo llevase el jugador. El control sigue bloqueado al llegar: quien lo pidio
## decide cuando devolverlo. Si x queda mas alla de un limite del mundo, se para
## en el limite y llegado sale igual.
func andar_hasta(x: float, corriendo: bool = false) -> void:
	_objetivo_x = x
	_objetivo_correr = corriendo
	_esperando_llegada = true
	control_bloqueado = true

## Se da la vuelta hacia x si no mira ya hacia alli (con la animacion de giro).
## Solo desde reposo: en marcha, el cambio de sentido ya pasa por la frenada.
func girar_hacia(x: float) -> void:
	var hacia := signf(x - position.x)
	if is_zero_approx(hacia) or hacia == _mirando or _estado != Estado.REPOSO:
		return
	if giro_activo:
		_empezar_giro(hacia, false)
	else:
		_mirar(hacia)

## 1 si mira a la derecha, -1 a la izquierda.
func mirando() -> float:
	return _mirando

## Donde anclar lo que dice: un poco por encima de la capucha.
func punto_cabeza() -> Vector2:
	return global_position + Vector2(0, -372)

## Con los pies fuera del suelo en un salto (del despegue a la toma de suelo).
## El nivel lo usa para no vadear hojas con los pies en el aire.
func en_el_aire() -> bool:
	if _estado != Estado.SALTAR:
		return false
	var f := _sprite.frame
	if _sprite.animation == &"salto_correr":
		return f >= salto_correr_despegue and f < salto_correr_toca
	if _sprite.animation in [&"flotar_bajar", &"flotar_girar", &"flotar_pisar", &"flotar_quieto"]:
		return true
	var v: Dictionary = VUELO.get(_sprite.animation, {})
	return not v.is_empty() and f >= v["despegue"] and f < v["toca"]

## Saltando, si ya ha tocado suelo (la cola: se incorpora o sale andando). El
## nivel vuelve ahi a ponerle sus limites, ya en el suelo nuevo.
func tras_tocar_suelo() -> bool:
	if _estado != Estado.SALTAR:
		return false
	if _vuelo == 3:
		return true
	var f := _sprite.frame
	if _sprite.animation == &"salto_correr":
		return f >= salto_correr_toca
	var v: Dictionary = VUELO.get(_sprite.animation, {})
	return not v.is_empty() and f >= int(v["toca"])

## Altura de los pies sobre el suelo en un salto (px): la cocida del
## fotograma mas el arco. 0 en el suelo.
func altura_pies() -> float:
	if not en_el_aire():
		return 0.0
	if _sprite.animation in [&"flotar_bajar", &"flotar_girar", &"flotar_pisar", &"flotar_quieto"]:
		var pf: Array = _flotar[String(_sprite.animation)]["pies"]
		return maxf(float(pf[clampi(_sprite.frame, 0, pf.size() - 1)]) - _sprite.position.y, 0.0)
	var v: Dictionary = VUELO[_sprite.animation]
	var pies: Array = v["pies"]
	var i := clampi(_sprite.frame - int(v["despegue"]), 0, pies.size() - 1)
	return maxf(float(pies[i]) - _sprite.position.y, 0.0)

## Bajando en un salto con la fisica del vuelo (en la luz, o el de parado y el
## andando en cualquier sitio): lo que puede rebotar en una hoja.
func cayendo() -> bool:
	return _estado == Estado.SALTAR and _vuelo == 2 and not _pisando and not _cinematica_nivel

## Luz que aligera donde esta el cuerpo ahora (0..1).
func luz() -> float:
	return _luz if _estado == Estado.SALTAR else 0.0

## Rebota en una hoja (ver rebote_hoja): vuelve a subir con la velocidad de
## despegue por `fuerza`, desde la altura a la que esta. La pose sigue sin
## salto: el fotograma de la bajada pasa al de la subida con las piernas igual
## (la bajada espejada: casi en el suelo, piernas estiradas = recien
## despegado; arriba del todo, recogidas = cerca del apogeo). Devuelve si
## reboto.
func rebotar(fuerza: float = 1.0, hoja: Dictionary = {}) -> bool:
	if not cayendo():
		return false
	if not hoja.is_empty() and _sprite.sprite_frames.has_animation(&"flotar_pisar"):
		_empezar_pisar(hoja, fuerza)
		return true
	return _despegar_de_hoja(fuerza, -1.0)

## PISAR LA HOJA (2026-10-14; video de magnus_pisar_hoja. El usuario: "como
## pisa las hojas y se impulsa con ellas queda un poco falso"). Con la hoja
## (rebotar(fuerza, hoja)) no rebota de golpe: se apoya en ella con
## flotar_pisar (toca, flexiona con la hoja y empuja, ~0,5 s) con los pies
## encima, siguiendola (la hoja pisada se hunde un palmo y el baja con ella), y
## al acabar despega como el salto de parado desde su fotograma del despegue
## (lo de siempre, _despegar_de_hoja), con el cuerpo donde estaba.
func _empezar_pisar(hoja: Dictionary, fuerza: float) -> void:
	_pisando = true
	_pisar_hoja = hoja
	_pisar_t = 0.0
	_pisar_fuerza = fuerza
	_pisar_dx = position.x - float(hoja["p"].x)
	_flota = false
	_quieto = -1.0
	_tras_giro = false
	# Cae en la hoja a medio girarse: se apoya mirando aun a donde miraba y el
	# giro queda pedido; tras el impulso vuelve a empezar cuando la pose case.
	if _giro_aire != 0.0:
		_giro_aire_pedido = _giro_aire
		_giro_aire = 0.0
	# entra por el fotograma que mas se parece a la pose que trae (PISAR LA
	# HOJA SIN DESCUADRE): la altura del cuerpo sobre los pies
	var d: Dictionary = _flotar["flotar_pisar"]
	var f0 := 0
	var trae := _cuerpo_sobre_pies()
	if not is_nan(trae):
		var mejor := INF
		for f in mini(PISAR_ENTRADA_MAX + 1, int(d["n"])):
			var dif := absf(float(d["cuerpo"][f]) - float(d["pies"][f]) - trae)
			if dif < mejor - 0.5:
				mejor = dif
				f0 = f
	_pisar_t = float(f0) / float(d["fps"])
	_sprite.animation = &"flotar_pisar"
	_sprite.offset = _offset_flotar(&"flotar_pisar")
	_sprite.set_frame_and_progress(f0, 0.0)
	_pisar_arco = maxf(position.y - float(hoja["p"].y) - PISAR_EN_HOJA, 0.0)
	# (como en el rebote: el nivel llama despues del tick de Magnus)
	_sprite.position.y = -_pisar_arco

## Un tick apoyado en la hoja: el fotograma por el tiempo, el nodo con la
## hoja y, al acabar, el despegue. Devuelve el arco.
func _volar_pisando(delta: float) -> float:
	var d: Dictionary = _flotar["flotar_pisar"]
	var n := int(d["n"])
	_pisar_t += delta
	var f := mini(int(_pisar_t * float(d["fps"])), n - 1)
	if f != _sprite.frame:
		_sprite.set_frame_and_progress(f, 0.0)
	var p: Vector2 = _pisar_hoja.get("p", Vector2(position.x - _pisar_dx, position.y - _pisar_arco - PISAR_EN_HOJA))
	# (de lado no la sigue: la hoja va bajo su pie, ver PISAR LA HOJA SIN DESCUADRE)
	_pisar_arco = maxf(position.y - p.y - PISAR_EN_HOJA, 0.0)
	if _pisar_t * float(d["fps"]) < float(n):
		return _pisar_arco
	# Despega: el cuerpo del ultimo fotograma de pisar es el del despegue
	# (misma medida, ver _despegue en flotar.json), en la medida del salto que
	# traia: _despegar_de_hoja lo pasa al de parado si venia de otro.
	_pisando = false
	_vuelo = 2
	despega_de_hoja.emit(_pisar_hoja)
	var desp: Dictionary = _flotar["_despegue"]
	var b0: float = desp.get(String(_vuelo_de), desp["salto_parado"])
	_vuelo_y = _pisar_arco + float(d["cuerpo"][n - 1]) - b0
	_despegar_de_hoja(_pisar_fuerza, 1.0, PISAR_DESPEGUE_TAU)
	return _arco_de_ahora()

## El fotograma del salto de parado por el que sigue al despegar de la hoja: el
## ultimo de pisar va con las piernas estiradas (cuerpo 245,7 px sobre los
## pies) y el del despegue (18) agachado (216): los pies subian 29 px de golpe.
## El 21-22 es el que mas se le parece (240-241).
const PISAR_DESPEGUE_TAU := 21.5
## Lo que se hunde el apoyo en la hoja (px): con los pies en su centro la planta
## quedaba ~5 px por encima de la hoja (grabado: se veia el hueco).
const PISAR_EN_HOJA := 5.0
## Ultimo fotograma de flotar_pisar por el que se puede entrar (del 13 en
## adelante ya empuja hacia arriba).
const PISAR_ENTRADA_MAX := 12
## Cuanto antes de llegar a la hoja (s) empieza a estirar las piernas hacia ella.
const PISAR_ANTICIPA := 0.45

## La altura del cuerpo sobre los pies en el fotograma de ahora, en la medida de
## flotar.json (NAN si no se sabe): para entrar a pisar con la misma pose.
func _cuerpo_sobre_pies() -> float:
	var an := String(_sprite.animation)
	var f := _sprite.frame
	if _flotar.has(an) and _flotar[an].has("cuerpo") and _flotar[an].has("pies"):
		var c: Array = _flotar[an]["cuerpo"]
		return float(c[clampi(f, 0, c.size() - 1)]) - float(_flotar[an]["pies"][clampi(f, 0, c.size() - 1)])
	if VUELO.has(_sprite.animation) and _flotar.has("_despegue") and _flotar["_despegue"].has(an):
		var v: Dictionary = VUELO[_sprite.animation]
		var i := clampi(f - int(v["despegue"]), 0, (v["pies"] as Array).size() - 1)
		return _cocido_vuelo(v, float(i)) + float(v["pose"][mini(i, (v["pose"] as Array).size() - 1)]) 				+ float(_flotar["_despegue"][an]) - float(v["pies"][i])
	return NAN

## El rebote de siempre (sin pisar, o al acabar de pisar con bajado = 1: desde
## el fotograma del despegue, o tau_dado). bajado < 0: lo que llevaba bajado.
func _despegar_de_hoja(fuerza: float, bajado_dado: float, tau_dado: float = -1.0) -> bool:
	var v: Dictionary = VUELO[_vuelo_de]
	var bajado := clampf((_vuelo_tau - _f_tau_cima) / maxf(float(v["toca"]) - _f_tau_cima, 0.001), 0.0, 1.0)
	if bajado_dado >= 0.0:
		bajado = bajado_dado
	elif _flota:
		# Bajando flotando: lo bajado de su secuencia, y vuelve a la subida del
		# salto (hasta que haya el video del rebote).
		bajado = clampf(_flota_iv / maxf(_flota_largo() - 1.0, 1.0), 0.0, 1.0)
		_flota = false
		_quieto = -1.0
	_tras_giro = false
	var fps := _sprite.sprite_frames.get_animation_speed(&"salto_parado")
	var parado := _parabola_vuelo(VUELO[&"salto_parado"], 0.0, fps)
	if _vuelo_de != &"salto_parado" and _flotar.has("_despegue") and _flotar["_despegue"].has(String(_vuelo_de)):
		# Desde una hoja se salta de parado, sin carrerilla, venga del salto
		# que venga: la fisica y los fotogramas del de parado (y con ellos su
		# bajada flotando y el giro en el aire). La altura del cuerpo pasa de
		# una medida a la otra (alturas sobre el despegue de cada salto) y lo
		# que llevaba de lado sigue como deriva (la luz lo lleva y lo frena).
		var desp: Dictionary = _flotar["_despegue"]
		_vuelo_y += float(desp[String(_vuelo_de)]) - float(desp["salto_parado"])
		_deriva += _velocidad() * _mirando
		_impulso = 0.0
		_corria_al_saltar = false
		_saltaba_parado = true
		_vuelo_de = &"salto_parado"
		v = VUELO[_vuelo_de]
		_f_g = parado.y
		_f_ritmo = fps
		_f_v0 = parado.x
		_f_corte = 1.0
		_f_tau_cima = float(v["apogeo"])
	var d0 := float(v["despegue"])
	var t1 := float(v["toca"])
	var tau := _f_tau_cima - bajado * (_f_tau_cima - d0)
	if tau_dado >= 0.0:
		tau = clampf(tau_dado, d0, _f_tau_cima)
	# Desde una hoja se empuja como desde parado, sin carrerilla: sube lo que
	# el salto de parado con su gravedad (con la velocidad del corriendo, un
	# rebote eran 460 px).
	_vuelo_v = parado.x * sqrt(_f_g / parado.y) * rebote_hoja * fuerza
	_vuelo = 1
	_vuelo_tau = tau
	_f_tau_ref = tau
	_f_v_ref = _vuelo_v
	# Si ya pedia girarse (la tecla hacia atras al caer en la hoja), del rebote
	# sale girandose: sin el fotograma de la subida en medio. Girandose ya, el
	# giro sigue (el lleva el fotograma).
	if _giro_aire == 0.0 and _giro_aire_pedido != 0.0 and _puede_girar_en_el_aire():
		_empezar_giro_aire()
	if _giro_aire == 0.0:
		if _sprite.animation != _vuelo_de:
			_sprite.animation = _vuelo_de
			_sprite.offset = offset_comun
		var f := clampi(roundi(tau), int(d0), int(t1))
		if f != _sprite.frame:
			_sprite.set_frame_and_progress(f, 0.0)
	# El nivel llama a esto despues del tick de Magnus, que ya ha puesto el arco
	# del fotograma de antes: sin recolocarlo, el del rebote se pintaba un
	# fotograma con ese arco, ~100 px mas abajo ("un parpadeo muy
	# desagradable", 2026-10-12).
	_sprite.position.y = -_arco_de_ahora()
	return true

## El arco que pone el cuerpo donde dice la fisica con el fotograma que se ve
## ahora, sin avanzar nada (lo mismo que calculan _volar y los suyos).
func _arco_de_ahora() -> float:
	var anim := String(_sprite.animation)
	var f := _sprite.frame
	if anim == "flotar_pisar":
		return _pisar_arco
	if anim == "flotar_bajar" or anim == "flotar_girar":
		var d: Dictionary = _flotar[anim]
		var b0: float = _flotar["_despegue"][String(_vuelo_de)]
		return maxf((_vuelo_y + b0) - float(d["cuerpo"][f]), -float(d["pies"][f]) - _desnivel())
	var v: Dictionary = VUELO.get(_sprite.animation, {})
	if v.is_empty():
		return -_sprite.position.y
	var i := clampi(f - int(v["despegue"]), 0, v["pose"].size() - 1)
	var cocido := _cocido_vuelo(v, float(i)) + float(v["pose"][i])
	return maxf(_vuelo_y + (1.0 - luz_quita_tiron * _luz) * _pose_vuelo(v, _vuelo_tau) - cocido, -float(v["pies"][i]) - _desnivel())

## Dirigir el salto en el aire con la luz (ver deriva_max). Fuera del vuelo, la
## deriva se apaga.
func _derivar(direccion: float, velocidad: float, delta: float) -> void:
	if _estado == Estado.SALTAR and (_vuelo == 1 or _vuelo == 2):
		# Sin tecla, la luz lo frena igual que lo lleva: soltando se queda donde
		# esta (si no, seguia a la deriva y no habia forma de colocarse). Hacia
		# atras, igual: de espaldas no se va, se gira (_pedir_giro_aire). Girando,
		# casi de frente avanza ya hacia donde se vuelve.
		var objetivo := 0.0
		var hacia := signf(direccion)
		if _giro_aire != 0.0:
			objetivo = -velocidad * _mirando
			if hacia == _giro_aire and _sprite.frame >= giro_aire_avanza:
				objetivo += hacia * deriva_max
		elif hacia == _mirando:
			objetivo = hacia * maxf(deriva_max, velocidad) - velocidad * _mirando
		elif hacia != 0.0:
			objetivo = -velocidad * _mirando
		_deriva = move_toward(_deriva, objetivo, deriva_aceleracion * _luz * delta)
	else:
		_deriva = move_toward(_deriva, 0.0, 1500.0 * delta)
	if _deriva != 0.0:
		position.x += _deriva * delta

## El eje de movimiento de este tick: el teclado, o el objetivo de andar_hasta
## con el control bloqueado; en los dos casos, cero hacia un limite ya pasado.
func _eje() -> float:
	var d := 0.0
	if control_bloqueado:
		if not is_nan(_objetivo_x):
			var falta := _objetivo_x - position.x
			if absf(falta) > margen_llegada:
				d = signf(falta)
			else:
				_objetivo_x = NAN
	else:
		d = Input.get_axis("mover_izquierda", "mover_derecha")
	if not is_zero_approx(d) and _fuera_de_limite(signf(d)):
		d = 0.0
		if control_bloqueado:
			# Objetivo de andar_hasta mas alla del limite: el limite cuenta como
			# llegada. Si no, _objetivo_x no se borraba nunca, llegado no salia y
			# un `await llegado` se quedaba colgado con el control quitado.
			_objetivo_x = NAN
	return d

## Con frenada_limite_* la tecla deja de contar ANTES del limite, lo que tarda
## en pararse con el paso que lleve: asi el limite es donde acaba de verdad, y
## andando puede acercarse mucho mas que corriendo.
## Frenando de correr hacia el limite, aun con la de correr (2026-10-13): con la
## de andar, mas corta, la tecla volvia a contar en cuanto empezaba la parada y
## salia andando a 192 desde 435 px/s en un tick, a media frenada.
func _fuera_de_limite(hacia: float) -> bool:
	var corriendo := _corriendo() or (_estado == Estado.PARADA_CORRER and signf(hacia) == _mirando)
	var m := frenada_limite_correr if corriendo else frenada_limite_andar
	return (hacia < 0.0 and position.x <= limite_izquierdo + m) or (hacia > 0.0 and position.x >= limite_derecho - m)

## Un salto hacia un limite no puede llevarle mas alla: se recorta el impulso
## para que el recorrido del salto (vuelo y toma de suelo, ver
## RECORRIDO_SALTO_*) quepa en lo que queda hasta el limite.
func _impulso_hasta_limite(impulso: float, a_la_carrera: bool) -> float:
	var limite := limite_derecho if _mirando > 0.0 else limite_izquierdo
	if suelo_en.is_valid():
		# SUELO VARIABLE: las caras las lleva el vuelo (_avance_en_el_aire); el
		# salto solo se acorta para no pasar los limites del mundo
		limite = limites_salto.y if _mirando > 0.0 else limites_salto.x
	if is_inf(limite) or impulso <= 0.0:
		return impulso
	var queda := maxf((limite - position.x) * _mirando, 0.0)
	if a_la_carrera:
		return minf(impulso, maxf(queda - RESBALE_SALTO_CORRER, 0.0) / _recorrido_salto_correr())
	# el andando, con lo que dure de mas su vuelo fuera de la luz (salto_andando_gravedad)
	var v: Dictionary = VUELO[&"saltar"]
	var fps := _sprite.sprite_frames.get_animation_speed(&"saltar")
	var n := float(v["toca"] - v["despegue"])
	var extra := n / _ritmo_salto_andando(v, _arco_salto_andando(0.0), fps, 0.0) - n / fps
	return minf(impulso, queda / (RECORRIDO_SALTO + maxf(extra, 0.0)))

## Segundos por px/s que recorre el salto corriendo en curso (ver
## RECORRIDO_SALTO_CORRER, medido con el empuje y el ritmo de siempre). Con la
## carrerilla cambian el empuje y el tiempo en el aire, asi que al medido se le
## suma lo que cambia la parte que depende de ellos: el vuelo (a su ritmo, con
## la rampa del empuje extra al principio: SALTO_EMPUJE_RAMPA fotogramas a
## medias) y la mitad de la cola tras tocar suelo (donde frena de la del aire a
## la del aterrizaje). Lo de antes del despegue va siempre a
## salto_correr_impulso y no cambia. Con los valores de siempre da
## RECORRIDO_SALTO_CORRER justo. Supone el arco entero: el brinco corto cae
## antes y se queda corto.
func _recorrido_salto_correr() -> float:
	var fps := _sprite.sprite_frames.get_animation_speed("salto_correr")
	var n := _sprite.sprite_frames.get_frame_count("salto_correr")
	var cola := float(n - 1 - salto_correr_toca) * 0.5 / fps
	var vuelo := float(salto_correr_toca - salto_correr_despegue) / fps
	var antes := salto_correr_impulso * (cola + vuelo / maxf(salto_correr_vuelo, 0.01))
	var ritmo := maxf(_salto_vuelo, 0.01)
	var extra := _salto_impulso - salto_correr_impulso
	var ahora := _salto_impulso * (cola + vuelo / ritmo) - extra * SALTO_EMPUJE_RAMPA * 0.5 / (fps * ritmo)
	return RECORRIDO_SALTO_CORRER + ahora - antes

## Empuje, arco y ritmo del salto corriendo para una carrerilla m (0..1). A 0,
## los de siempre, exactos.
func _fijar_salto_correr(m: float) -> void:
	_salto_impulso = lerpf(salto_correr_impulso, salto_correr_impulso_max, m)
	_arco_max = lerpf(salto_correr_altura, salto_correr_altura_max, m)
	_salto_vuelo = _ritmo_vuelo(_arco_max)

## Ritmo de la animacion en el aire (speed_scale) para un arco anadido de amp
## px, con la misma gravedad que el salto de siempre: el tiempo de vuelo va con
## la raiz de la altura (la cocida del sprite mas el arco), asi que el ritmo
## con su inversa. Con el arco de siempre da salto_correr_vuelo justo; mas alto
## va mas lento, pero nunca por debajo de salto_correr_vuelo_min ni de
## VUELO_MIN (camara lenta); mas bajo (el brinco corto), mas rapido. Antes era
## un ritmo fijo por carrerilla, y el toque con la carrerilla llena quedaba mas
## bajo que el salto de siempre pero mas rato en el aire: un planeo.
func _ritmo_vuelo(amp: float) -> float:
	var ritmo := salto_correr_vuelo * sqrt((SUBIDA_SALTO_CORRER + salto_correr_altura) 		/ maxf(SUBIDA_SALTO_CORRER + amp, 1.0))
	if amp > salto_correr_altura:
		ritmo = maxf(ritmo, maxf(salto_correr_vuelo_min, VUELO_MIN))
	return ritmo

## Multiplicador del empuje del salto corriendo en este momento: el de siempre
## (salto_correr_impulso) con los pies en el suelo, y el extra de la carrerilla
## entrando en los primeros SALTO_EMPUJE_RAMPA fotogramas del vuelo.
func _empuje_salto_correr() -> float:
	var extra := _salto_impulso - salto_correr_impulso
	if extra == 0.0:
		return salto_correr_impulso
	var f := float(_sprite.frame - salto_correr_despegue) + _sprite.frame_progress
	if _sprite.frame < salto_correr_despegue:
		f = 0.0
	return salto_correr_impulso + extra * clampf(f / SALTO_EMPUJE_RAMPA, 0.0, 1.0)

## Con andar_hasta en curso, la llegada se avisa cuando ya esta en reposo. El
## arranque no se pide aqui: el eje de _eje() lo arranca en _physics_process
## igual que una tecla mantenida.
func _avisar_llegada() -> void:
	if control_bloqueado and _esperando_llegada and is_nan(_objetivo_x) and _estado == Estado.REPOSO:
		_esperando_llegada = false
		llegado.emit()

## Girando no: el salto cortaria el giro con el sprite a 45 o 90 grados y
## saldria mirando al lado de antes. Se guarda (ver margen_salto) y sale al
## acabar el giro.
## Tampoco desde la cola del salto corriendo (_salto_en_cola_correr): se
## guarda y sale en el primer tick del aterrizaje, o del ciclo si la
## direccion sigue pulsada.
## Ni en los fotogramas quietos del arranque de correr (_arrancando_a_correr_quieto):
## se guarda y sale como salto corriendo de verdad en cuanto hay velocidad.
func _puede_saltar() -> bool:
	if salto_bloqueado or _estado == Estado.GIRO or _salto_en_cola_correr() \
			or _arrancando_a_correr_quieto() or _en_agachado():
		return false
	return _estado != Estado.SALTAR or not _salto_bloquea()

## SUELO VARIABLE: andando o corriendo con la tecla hacia donde mira, el suelo
## de delante baja justo donde despegaria si saltase ahora (lo que anda hasta el
## fotograma del despegue): es el momento de saltar para despegar en el borde.
## Con el control quitado no (andar_hasta va a su sitio, y el nivel lleva sus
## acciones), ni sin poder saltar (con el baston en la mano: el nivel lo para en
## el borde).
func _borde_delante(direccion: float) -> bool:
	if not suelo_en.is_valid() or control_bloqueado or salto_bloqueado or signf(direccion) != _mirando:
		return false
	var v := _velocidad()
	var anda := _estado == Estado.ANDAR \
		or (_estado == Estado.ARRANQUE_ANDAR and _sprite.frame > arranque_andar_de_pie)
	var corre := (_estado == Estado.CORRER or _estado == Estado.ARRANQUE_CORRER) and v > velocidad_andar
	if not (anda or corre) or not _puede_saltar():
		return false
	var anim := &"salto_correr" if corre else &"saltar"
	var fps := _sprite.sprite_frames.get_animation_speed(anim)
	var hasta_despegar := float(VUELO[anim]["despegue"]) / fps * v
	# (si ya pisa el vacio, al arrancar muy pegado al filo, salta ya: nada de
	# andar por el aire)
	var delante: float = suelo_en.call(position.x + _mirando * (hasta_despegar + 1.0))
	return delante > position.y + 2.0

## SUELO VARIABLE: lo que el suelo de donde esta queda por debajo del nodo (px;
## negativo si esta mas alto: encima de un bloque al que ha saltado). En el aire
## el nodo sigue a la altura del despegue: es lo que el suelo de aterrizaje queda
## bajo el del despegue.
func _desnivel() -> float:
	if not suelo_en.is_valid():
		return 0.0
	return float(suelo_en.call(position.x)) - position.y

## Solo lo que baja (cayendo por debajo del despegue cae con gravedad_caida).
func _bajada() -> float:
	return maxf(_desnivel(), 0.0)

## SUELO VARIABLE, en el aire: una cara mas alta que los pies hace de pared (se
## para contra ella, mirando por delante del cuerpo, y sigue cayendo), y no pasa
## de limites_salto (el vuelo a otro suelo dura mas de lo que mide
## _impulso_hasta_limite). Tambien si los pies pasan pero el cuerpo no va a
## llegar a caer encima (ver _llega_encima).
const MEDIO_CUERPO := 28.0
func _avance_en_el_aire(nx: float) -> float:
	var delante := _mirando * MEDIO_CUERPO
	var aqui: float = suelo_en.call(position.x + delante)
	var alli: float = suelo_en.call(nx + delante)
	if alli < aqui - 1.0 and not _llega_encima(position.y - alli):
		nx = position.x
	return clampf(nx, limites_salto.x, limites_salto.y)

## En el aire, si puede pasar por encima de algo h px mas alto que el despegue:
## con los pies por encima y, en los saltos con su tabla de vuelo, con el cuerpo
## (o su apogeo, si aun sube) alto para tocar alli con la pose de tocar suelo
## (ENCIMA_TIRON de margen). Antes bastaban los pies: encogidos pasaban y al
## tocar el cuerpo subia de golpe lo que le faltaba.
func _llega_encima(h: float) -> bool:
	if _pies_sobre_despegue() < h + 1.0:
		return false
	var en_vuelo := _vuelo == 1 or _vuelo == 2
	var v: Dictionary = VUELO.get(_vuelo_de if en_vuelo else _sprite.animation, {})
	if v.is_empty():
		return true
	var n := int(v["toca"]) - int(v["despegue"])
	var para_tocar := h + _cocido_vuelo(v, float(n)) - ENCIMA_TIRON
	if _vuelo == 1:
		return _vuelo_y + _vuelo_v * _vuelo_v / (2.0 * maxf(_f_g, 1.0)) >= para_tocar
	if _vuelo == 2:
		return _vuelo_y >= para_tocar
	# (el corriendo sin la fisica: su arco llega arriba a media subida; mientras
	# sube cuenta lo que va a subir)
	var i := clampi(_sprite.frame - int(v["despegue"]), 0, n)
	var cuerpo := _cocido_vuelo(v, float(i)) + float(v["pose"][i]) - _sprite.position.y
	if _sprite.animation == &"salto_correr" and _arco_t >= 0.0 and _arco_t < 0.5:
		cuerpo = maxf(cuerpo, float(v["alto"]) + _arco_amp)
	return cuerpo >= para_tocar

## SUELO VARIABLE: la primera cara mas alta que el suelo de aqui a menos de
## `alcance` px por delante: {x: lo que falta hasta ella, alto: lo que sube,
## ancho: lo que dura arriba a esa altura}, o {}.
func _cara_delante(alcance: float) -> Dictionary:
	var dx := 2.0
	while dx <= alcance:
		var y: float = suelo_en.call(position.x + _mirando * dx)
		if y < position.y - 2.0:
			var ancho := 0.0
			while ancho < 1000.0 and absf(float(suelo_en.call(position.x + _mirando * (dx + ancho + 4.0))) - y) < 2.0:
				ancho += 4.0
			return {"x": dx, "alto": position.y - y, "ancho": ancho}
		dx += 2.0
	return {}

## SALTAR ENCIMA: arco, ritmo y avance (px/s en el aire) para caer encima de la
## cara de delante, o {} si no hay ninguna a la que llegue (sigue el salto de
## siempre). Mas deprisa de lo que llevaba no va que salto_encima_empuje_max
## por velocidad_andar.
func _salto_encima(v: Dictionary, amp0: float, fps: float, impulso: float, alcance := -1.0) -> Dictionary:
	var cara := _cara_delante(salto_encima_alcance if alcance < 0.0 else alcance)
	if cara.is_empty():
		return {}
	var dist: float = cara["x"]
	var alto: float = cara["alto"]
	var ancho: float = cara["ancho"]
	var n := int(v["toca"]) - int(v["despegue"])
	# con el cuerpo a esta altura sobre el despegue toca alli con la pose de tocar
	# suelo; sube lo que pide (a un escalon, un brinco; al sillar, un salto
	# grande), pero no menos de ENCIMA_ARCO_MIN del de siempre
	var para_tocar := alto + _cocido_vuelo(v, float(n))
	var amp := maxf(para_tocar + salto_encima_holgura - float(v["alto"]), amp0 * ENCIMA_ARCO_MIN)
	if amp > salto_andando_altura_max:
		return {}
	var ritmo := _ritmo_salto_andando(v, amp, fps, 0.0)
	var vuelo := _vuelo_previsto(v, _parabola_vuelo(v, amp, ritmo), ritmo)
	var dt := get_physics_process_delta_time()
	var t_pies := -1.0          # desde aqui los pies pasan por encima de la cara
	var t_fin := -1.0           # hasta aqui el cuerpo aun puede caer encima
	for k in vuelo.size():
		var c: Vector2 = vuelo[k]
		if t_pies < 0.0 and c.y > alto + 1.0:
			t_pies = float(k) * dt
		if c.x >= para_tocar:
			t_fin = float(k) * dt
	if t_pies < 0.0 or t_fin <= t_pies:
		return {}
	# el nodo pasa la cara antes de t_fin: llegando cuando los pies ya pasan, o
	# parado contra ella hasta entonces y luego lo que le queda; y en t_fin (toca
	# encima) aun no ha pasado del otro lado (un escalon estrecho, el salto
	# corriendo)
	var minimo := maxf((dist + ENCIMA_PASA) / t_fin, (MEDIO_CUERPO + ENCIMA_PASA) / (t_fin - t_pies))
	var tope := minf(maxf(impulso, velocidad_andar * salto_encima_empuje_max), (dist + ancho - ENCIMA_PASA) / t_fin)
	if minimo > tope:
		return {}
	var sin_tocar := maxf(dist - MEDIO_CUERPO - 1.0, 0.0) / maxf(t_pies, dt)
	var imp := clampf(impulso, minimo, tope)
	if imp > sin_tocar and sin_tocar >= minimo:
		imp = sin_tocar
	return {"amp": amp, "ritmo": ritmo, "impulso": imp, "suelo": para_tocar}

## SALTAR ENCIMA, corriendo: en el primer tick en el aire, sin luz, si delante
## hay donde caer encima, el vuelo pasa ya a la fisica (como en la luz) con el
## arco y el avance para caer alli, sin el empuje extra de la carrerilla (el
## avance lo pone la ayuda). Si no, el salto largo de siempre (por encima de un
## sillar, o corto contra su cara).
func _encima_corriendo() -> bool:
	if not suelo_en.is_valid() or control_bloqueado:
		return false
	var v: Dictionary = VUELO[&"salto_correr"]
	if ligereza.is_valid() and float(ligereza.call(global_position + Vector2(0.0, -float(v["centro"])))) > 0.0:
		return false
	var fps := _sprite.sprite_frames.get_animation_speed(&"salto_correr")
	var encima := _salto_encima(v, _arco_amp, fps, _impulso * _salto_impulso, 700.0)
	if encima.is_empty():
		return false
	var ritmo: float = encima["ritmo"]
	var p := _parabola_vuelo(v, encima["amp"], ritmo)
	var d0 := int(v["despegue"])
	var tau := float(_sprite.frame) + _sprite.frame_progress
	_vuelo_de = &"salto_correr"
	# desde donde se ve el cuerpo (ya algo subido), con la velocidad que lo lleva
	# al apogeo previsto: con la de la parabola a esta altura del vuelo se
	# quedaba 20 px corto, a la altura del bloque, y la bajada se saltaba
	# fotogramas
	var y0 := _cocido_vuelo(v, tau - float(d0))
	var vel := sqrt(maxf(2.0 * p.y * (p.x * p.x / (2.0 * p.y) - y0), 0.0))
	_empezar_vuelo(tau, y0, vel, p.y, ritmo)
	_f_v0 = p.x
	_encima_suelo = encima["suelo"]
	_salto_impulso = salto_correr_impulso
	_impulso = float(encima["impulso"]) / salto_correr_impulso
	return true

## El vuelo que saldria ahora sin luz y en llano, tick a tick como lo lleva
## _volar: (cuerpo, pies) sobre el despegue, desde el despegue hasta tocar suelo.
func _vuelo_previsto(v: Dictionary, p: Vector2, ritmo: float) -> Array:
	var r: Array = []
	var dt := get_physics_process_delta_time()
	var d0 := int(v["despegue"])
	var t1 := int(v["toca"])
	var g := p.y
	var vel := p.x
	var y := 0.0
	var tau := float(d0)
	var tau_cima := float(d0) + p.x / g * ritmo
	var cima := p.x * p.x / (2.0 * g)
	var suelo := _cocido_vuelo(v, float(t1 - d0))
	var sube := true
	for k in 300:
		if sube and vel - g * dt > 0.0:
			y += vel * dt - g * dt * dt * 0.5
			vel -= g * dt
			tau = float(d0) + (tau_cima - float(d0)) * (1.0 - vel / p.x)
		else:
			if sube:
				var resto := dt - vel / g
				y = cima - g * resto * resto * 0.5
				vel = -g * resto
				sube = false
			else:
				var v1 := vel - g * dt
				y += (vel + v1) * 0.5 * dt
				vel = v1
			if y <= suelo + 0.001:
				break
			var caido := clampf((cima - y) / maxf(cima - suelo, 0.001), 0.0, 1.0)
			tau = maxf(tau, tau_cima + (float(t1) - tau_cima) * sqrt(caido))
		var f := clampi(roundi(tau), d0, t1)
		var i := f - d0
		var arco := y + _pose_vuelo(v, tau) - (_cocido_vuelo(v, float(i)) + float(v["pose"][i]))
		r.append(Vector2(y, float(v["pies"][i]) + maxf(arco, -float(v["pies"][i]))))
	return r

## Segundos en caer h px desde u px/s hacia abajo, con gravedad g.
func _tiempo_de_caida(h: float, u: float, g: float) -> float:
	if h <= 0.0:
		return 0.0
	return (-u + sqrt(u * u + 2.0 * g * h)) / maxf(g, 1.0)

## Al tocar suelo, el nodo pasa a ese suelo, arriba o abajo (el sprite ya estaba alli).
func _aterrizar_abajo() -> void:
	position.y += _desnivel()

## Altura de los pies sobre el suelo del despegue en el fotograma de ahora (px, sin
## recortar: negativa si ya baja por debajo). Saltando, una cara mas alta que esto
## es una pared.
func _pies_sobre_despegue() -> float:
	var anim := _sprite.animation
	if anim == &"flotar_bajar" or anim == &"flotar_girar" or anim == &"flotar_quieto":
		var pf: Array = _flotar[String(anim)]["pies"]
		return float(pf[clampi(_sprite.frame, 0, pf.size() - 1)]) - _sprite.position.y
	var v: Dictionary = VUELO.get(anim, {})
	if v.is_empty() or _sprite.frame < int(v["despegue"]):
		return -_sprite.position.y
	var pies: Array = v["pies"]
	return float(pies[clampi(_sprite.frame - int(v["despegue"]), 0, pies.size() - 1)]) - _sprite.position.y

## SUELO VARIABLE: lo mas alto (px sobre el suelo) a lo que llegaria el salto
## que saldria ahora: el nivel decide con esto si algo se salta o se trepa.
## Andando, lo mas alto donde cae encima (ver SALTAR ENCIMA); corriendo, donde
## cae encima con la carrerilla que lleve (el cuerpo alto para tocar alli, ver
## _llega_encima): al sillar mediano, con mas de un segundo corriendo.
func altura_salto() -> float:
	var v := _velocidad()
	var corre := (_estado == Estado.CORRER or _estado == Estado.ARRANQUE_CORRER) and v > velocidad_andar
	if corre:
		var m := _carrerilla if carrerilla_activa else 0.0
		var vc: Dictionary = VUELO[&"salto_correr"]
		var nc := int(vc["toca"]) - int(vc["despegue"])
		return float(vc["alto"]) + lerpf(salto_correr_altura, salto_correr_altura_max, m) \
			- _cocido_vuelo(vc, float(nc)) + ENCIMA_TIRON
	var anda := _estado == Estado.ANDAR or (_estado == Estado.ARRANQUE_ANDAR and _sprite.frame > arranque_andar_de_pie) \
		or _estado == Estado.PARADA_ANDAR
	if anda:
		var vs: Dictionary = VUELO[&"saltar"]
		var n := int(vs["toca"]) - int(vs["despegue"])
		return salto_andando_altura_max + float(vs["alto"]) - salto_encima_holgura - _cocido_vuelo(vs, float(n))
	return _pies_max(&"salto_parado")

func _pies_max(anim: StringName) -> float:
	var mx := 0.0
	for p in VUELO[anim]["pies"]:
		mx = maxf(mx, float(p))
	return mx

## Arranque de correr aun sin velocidad de correr (quieto hasta el fotograma 5,
## 81 px/s en el 6). Tras un doble toque desde parado, o un giro corriendo, se
## pasa siempre por ahi, y saltar en esos fotogramas daba un salto de parado y,
## al caer, andando: se perdia la carrera. Se espera hasta el fotograma 7 (como
## mucho 0,13 s desde la entrada por el 3; 0,23 s saliendo del giro, que entra
## por el 0) y sale salto corriendo.
func _arrancando_a_correr_quieto() -> bool:
	return _estado == Estado.ARRANQUE_CORRER and _velocidad() <= velocidad_andar

## Ya en el suelo al final del salto corriendo, con la direccion suelta (con
## ella pulsada ya habria pasado al ciclo). Relanzar aqui como "saltar" era un
## escalon: de ~514 a 192 px/s en un tick y de la zancada de la toma de suelo
## al primer sprite del otro salto. Son 6 fotogramas, 0,1 s; el aterrizaje
## que viene detras arranca a 217 px/s, la misma que deja esta cola, y desde
## ahi el salto sale sin escalon.
func _salto_en_cola_correr() -> bool:
	return _estado == Estado.SALTAR and _sprite.animation == &"salto_correr" and not _salto_bloquea()

## Hay un salto pedido hace menos de margen_salto y nada lo impide desde fuera.
func _salto_en_espera() -> bool:
	return not control_bloqueado and not salto_bloqueado and _reloj - _salto_pedido <= margen_salto

## Salta ya. Desde la cola de otro salto (ya caido, a partir de _interrumpible)
## lo relanza desde el principio: _cambiar no reentra en el mismo estado y
## play() con el mismo nombre no rebobina, asi que antes esa pulsacion se
## tragaba pero subia el esfuerzo y cambiaba el impulso del salto en curso.
func _saltar() -> void:
	_salto_pedido = -99.0
	_salto_borde = false
	var relanzar := _estado == Estado.SALTAR
	# El salto se lleva la velocidad que llevaba: saltar corriendo tiene que
	# avanzar en el aire, no caer en el sitio. Relanzando, como mucho la de
	# andar: la cola de "saltar" o del de parado ya viene frenando, y de
	# la del salto corriendo no se relanza (ver _salto_en_cola_correr), que ahi
	# aun va a ~490 px/s y en "saltar" seria un frenazo en un tick.
	_impulso = minf(_velocidad(), velocidad_andar) if relanzar else _velocidad() - (_sobrante if _estado == Estado.CORRER else 0.0)
	# Salto corriendo solo si ya corre de verdad. En los fotogramas quietos del
	# arranque de correr (0-5, velocidad 0) el salto corriendo brincaba en el
	# sitio y al caer resbalaba hacia delante hasta 217 px/s.
	_corria_al_saltar = (_estado == Estado.CORRER or _estado == Estado.ARRANQUE_CORRER) \
		and _impulso > velocidad_andar
	# Quieto (reposo, una parada ya frenada, o la zona muerta del arranque de
	# andar, del 0 al ARRANQUE_ANDAR_DE_PIE, con los pies aun juntos): salto de
	# parado, que empieza y acaba en la pose de reposo. "saltar" sale de un video
	# andando y su primer sprite esta a 0,38 del reposo: desde parado se veia
	# arrancar una zancada de la nada. Pasaba al pulsar direccion y salto a la
	# vez. Los 0-39 px/s de esa zona muerta no se llevan al aire. (Los
	# fotogramas quietos del arranque de correr ni llegan aqui: el salto se
	# guarda hasta que corre, ver _arrancando_a_correr_quieto.)
	var de_pie := _estado == Estado.ARRANQUE_ANDAR and _sprite.frame <= arranque_andar_de_pie
	if de_pie:
		_impulso = 0.0
	_saltaba_parado = not _corria_al_saltar and _impulso <= 0.0 \
		and (not _en_movimiento() or _estado == Estado.ARRANQUE_CORRER or de_pie)
	# Lo que pone el nodo al salto corriendo, segun la carrerilla que lleve (a 0,
	# los valores de siempre, exactos). Antes del recorte junto al limite, que
	# depende de ellos. Y el estado de la altura variable, de cero.
	var m := _carrerilla if carrerilla_activa else 0.0
	_fijar_salto_correr(m)
	# Junto a un limite, primero se gasta menos carrerilla: el salto mas grande
	# que quepa entero, bajando hacia el de siempre. Recortar solo el empuje
	# dejaba el arco y el vuelo de la carrerilla llena sobre un avance de 150 px:
	# un bote en el sitio. Si ni el de siempre cabe, se recorta el empuje abajo.
	if _corria_al_saltar and m > 0.0 and _impulso_hasta_limite(_impulso, true) < _impulso:
		var bajo := 0.0
		var alto := m
		for i in 7:
			var medio := (bajo + alto) * 0.5
			_fijar_salto_correr(medio)
			if _impulso_hasta_limite(_impulso, true) < _impulso:
				alto = medio
			else:
				bajo = medio
		m = bajo
		_fijar_salto_correr(m)
	if _corria_al_saltar and carrerilla_activa:
		_carrerilla *= 1.0 - clampf(carrerilla_gasto_salto, 0.0, 1.0)
	_arco_amp = _arco_max
	_arco_t = -1.0
	_arco_t0 = -1.0
	_salto_soltado = false
	_vuelo = 0
	_flota = false
	_quieto = -1.0
	_giro_aire = 0.0
	_giro_aire_pedido = 0.0
	_tras_giro = false
	# Junto a un limite el salto se acorta para no pasarlo. Si ya casi no queda
	# sitio, salta en el sitio (de parado): un brinco a la carrera que no avanza
	# se leia como un fallo.
	var tope := _impulso_hasta_limite(_impulso, _corria_al_saltar)
	if tope < _impulso:
		_impulso = tope
		if _impulso < velocidad_andar * 0.3:
			_impulso = 0.0
			_corria_al_saltar = false
			_saltaba_parado = true
	_esfuerzo = minf(_esfuerzo + esfuerzo_salto, 1.0)
	if relanzar:
		_estado = Estado.REPOSO  # para que _cambiar reponga la animacion
	_cambiar(Estado.SALTAR)
	if relanzar:
		_sprite.set_frame_and_progress(0, 0.0)

## Durante el vuelo no se acepta nada; despues de caer, si.
func _salto_bloquea() -> bool:
	return _estado == Estado.SALTAR and _progreso() < _interrumpible()

## Los dos saltos son animaciones distintas con tiempos distintos.
func _aterrizaje() -> float:
	match String(_sprite.animation):
		"salto_correr": return aterrizaje_correr
		"salto_parado": return aterrizaje_parado
		"flotar_bajar", "flotar_girar", "flotar_pisar", "flotar_quieto": return 1.0
		"flotar_posarse": return 0.0
	return aterrizaje

func _interrumpible() -> float:
	match String(_sprite.animation):
		"salto_correr": return salto_correr_interrumpible
		"salto_parado": return salto_parado_interrumpible
		"flotar_bajar", "flotar_girar", "flotar_pisar", "flotar_quieto": return 2.0
		"flotar_posarse": return 0.55
	return salto_interrumpible

func _en_movimiento() -> bool:
	if _estado == Estado.ANDAR or _estado == Estado.ARRANQUE_ANDAR:
		return true
	return _estado == Estado.CORRER or _estado == Estado.ARRANQUE_CORRER

func _corriendo() -> bool:
	return _estado == Estado.CORRER or _estado == Estado.ARRANQUE_CORRER

## Voltea y arranca al otro lado en cuanto la frenada ha dejado el cuerpo quieto.
## Vale para las paradas y para lo que llega con velocidad desde un salto (la
## cola del salto y el aterrizaje del salto corriendo); ahi se espera, como en
## la parada de andar, a que quede por debajo del 30 % de la de andar.
func _resolver_giro() -> void:
	if is_zero_approx(_giro_pendiente):
		return
	if _estado not in [Estado.PARADA_ANDAR, Estado.PARADA_CORRER, Estado.SALTAR, Estado.ATERRIZAJE_CORRER]:
		_giro_pendiente = 0.0
		return
	# En el aire o agachado al caer no se gira: seria cortar el salto.
	if _salto_bloquea():
		return
	if _estado == Estado.PARADA_ANDAR:
		if _velocidad() > _frenando_desde * 0.3:
			return
	elif _estado == Estado.PARADA_CORRER:
		if _progreso() < frenada_correr:
			return
	elif _velocidad() > velocidad_andar * 0.3:
		return
	var hacia := _giro_pendiente
	var corriendo := _giro_corriendo
	_giro_pendiente = 0.0
	# La parada de correr se corta en su fotograma 4 y el pie planta en el 5:
	# sin esto, la frenada entera de un cambio de sentido corriendo era muda y
	# se leia como un patinazo.
	if _estado == Estado.PARADA_CORRER and _sprite.frame < 5:
		_sonar(GOLPES["parada_correr"][5], pasos_db, 0.0, true)
		pisada.emit(&"parada_correr", 5)
	if giro_activo:
		_empezar_giro(hacia, corriendo)
		return
	_mirar(hacia)
	_cambiar(Estado.ARRANQUE_CORRER if corriendo else Estado.ARRANQUE_ANDAR)

## Entra en la animacion de giro. El sprite NO se voltea aqui: se voltea al
## terminar, en _al_terminar. Durante el giro se conserva el flip_h que hubiera,
## que es lo que hace que la misma animacion valga para los dos sentidos.
func _empezar_giro(hacia: float, corriendo: bool) -> void:
	_giro_destino = hacia
	_giro_corriendo = corriendo
	_cambiar(Estado.GIRO)

## Estados desde los que una pulsacion de direccion arranca el movimiento.
func _puede_arrancar() -> bool:
	if _estado == Estado.GIRO:
		return false
	if _estado == Estado.REPOSO or _estado == Estado.ATERRIZAJE_CORRER:
		return true
	if _estado == Estado.PARADA_ANDAR or _estado == Estado.PARADA_CORRER:
		return true
	return _puede_cortar_salto()

func _puede_cortar_salto() -> bool:
	return _estado == Estado.SALTAR and not _salto_bloquea()

## Volteo del sprite. Con giro_activo se aplica al terminar la animacion de
## giro, que acaba en el perfil del otro lado (el montaje esta en _empezar_giro
## y _al_terminar); sin el, es el cambio de sentido instantaneo de antes.
func _mirar(direccion: float) -> void:
	if is_zero_approx(direccion):
		return
	_mirando = signf(direccion)
	_sprite.flip_h = _mirando < 0.0

func _cambiar(nuevo: Estado) -> void:
	if _estado == nuevo:
		return
	# Apoyado en una hoja solo se esta dentro de un salto (ver PISAR LA HOJA).
	_pisando = false
	# La frenada tiene que partir de la velocidad que llevaba de verdad, no de
	# la de crucero. Si no, un toque corto -- en el que apenas ha acelerado --
	# entra a frenar a toda velocidad y el personaje pega un tiron hacia
	# delante en vez de quedarse casi donde estaba.
	if nuevo == Estado.PARADA_ANDAR or nuevo == Estado.PARADA_CORRER:
		_frenando_desde = _velocidad()
	if nuevo != Estado.CORRER:
		_sobrante = 0.0
	if nuevo != Estado.SALTAR:
		_giro_aire = 0.0
		_giro_aire_pedido = 0.0
	_estado = nuevo
	match nuevo:
		Estado.REPOSO:          _poner("reposo")
		Estado.ARRANQUE_ANDAR:  _poner("arranque_andar")
		Estado.ANDAR:           _poner("andar")
		Estado.PARADA_ANDAR:    _poner("parada_andar")
		Estado.ARRANQUE_CORRER: _poner("arranque_correr")
		Estado.CORRER:          _poner("correr")
		Estado.PARADA_CORRER:   _poner("parada_correr")
		Estado.SALTAR:
			if _corria_al_saltar:
				_poner("salto_correr")
			elif _saltaba_parado:
				_poner("salto_parado")
			else:
				_poner("saltar")
		Estado.GIRO:            _poner("giro")
		Estado.CAYENDO:         _poner("cayendo")
		Estado.CAIDA:           _poner("caida")
		Estado.TUMBADO:         _poner("tumbado")
		Estado.LEVANTARSE:
			_poner("levantarse")
			_sonar(SONIDOS_CAIDA["levantarse"], cinematica_db)
		Estado.ATERRIZAJE_CORRER: _poner("aterrizaje_correr")
		Estado.AGACHANDO:
			_agachar_atras = false
			_poner("agacharse")
			_sonar(SONIDOS_AGACHARSE["bajar"], agacharse_db, 0.0, true)
		Estado.AGACHADO:
			_agachar_atras = false
			_poner("agachado")
		Estado.INCORPORANDO:
			_agachar_atras = false
			_poner("incorporarse")
			_sonar(SONIDOS_AGACHARSE["subir"], agacharse_db, 0.0, true)
		Estado.ARRANQUE_AGACHADO:
			_poner("arranque_agachado")
			_x_tabla = position.x
		Estado.ANDAR_AGACHADO:
			_parando_agachado = -1
			_poner("andar_agachado")
		Estado.PARADA_AGACHADO:
			_poner("parada_agachado")
			_x_tabla = position.x
		Estado.GIRO_AGACHADO:
			_poner("giro_agachado")
		Estado.PASO_AGACHADO:
			_poner("paso_agachado")
			_x_tabla = position.x

func _en_cinematica() -> bool:
	return _estado in CINEMATICA or _cinematica_nivel

## CINEMATICA DEL NIVEL (2026-10-14; la primera, coger el baculo en
## caida_hojarasca.gd). El nivel se queda con el personaje: sin fisica, sin
## control y sin que el sprite avance solo; el pone la animacion, el fotograma,
## el offset, el arco (_sprite.position.y) y el nodo. Lo que hubiera a medias
## en el aire (apoyado en una hoja, flotando, girandose) se olvida.
func tomar_cinematica() -> void:
	_cinematica_nivel = true
	_pisando = false
	_flota = false
	_quieto = -1.0
	_tras_giro = false
	_giro_aire = 0.0
	_giro_aire_pedido = 0.0
	_salto_pedido = -99.0
	_sprite.speed_scale = 0.0

## Devuelve el personaje: de pie en reposo, con los pies en el nodo.
func soltar_cinematica() -> void:
	_cinematica_nivel = false
	_vuelo = 0
	_impulso = 0.0
	_deriva = 0.0
	_sprite.speed_scale = 1.0
	_sprite.position.y = 0.0
	if _estado == Estado.REPOSO:
		_poner("reposo")
	else:
		_cambiar(Estado.REPOSO)

func _en_agachado() -> bool:
	return _estado in AGACHADO

## Tecla abajo pulsada, con el control en manos del jugador.
func _quiere_agacharse() -> bool:
	return agacharse_activo and not control_bloqueado and Input.is_action_pressed("agacharse")

## Agachandose, agachado o levantandose: la tecla abajo manda, y un cambio de
## idea a medias se deshace por el mismo camino (la animacion hacia atras desde
## el fotograma en que iba) en vez de saltar a otra pose.
func _actualizar_agachado(abajo: bool, direccion: float = 0.0) -> void:
	# Hacia donde mira y sin limite delante: la unica direccion que cuenta.
	var adelante := not is_zero_approx(direccion) and signf(direccion) == _mirando
	match _estado:
		Estado.AGACHANDO:
			if not abajo and not _agachar_atras:
				_agachar_atras = true
				_sprite.play_backwards(&"agacharse")
			elif abajo and _agachar_atras:
				_agachar_atras = false
				_sprite.play(&"agacharse")
		Estado.AGACHADO:
			if not abajo:
				_toque_agachado = -1.0
				_cambiar(Estado.INCORPORANDO)
			elif adelante:
				# Se espera TOQUE_AGACHADO a ver si es un toque (un paso) o se
				# mantiene (andar): arrancar enseguida y cambiar al paso al
				# soltar se veia como un primer meneo (el arranque va mas erguido).
				if _toque_agachado < 0.0 and paso_agachado_activo:
					_toque_agachado = _reloj
				elif not paso_agachado_activo or _reloj - _toque_agachado >= TOQUE_AGACHADO:
					_toque_agachado = -1.0
					_agachado_desde = _sprite.frame
					_cambiar(Estado.ARRANQUE_AGACHADO)
			elif _toque_agachado >= 0.0 and is_zero_approx(direccion):
				_toque_agachado = -1.0
				_cambiar(Estado.PASO_AGACHADO)
			elif not is_zero_approx(direccion):
				_toque_agachado = -1.0
				# Hacia atras: se gira sin levantarse. Como el de pie, voltea al
				# terminar (_al_terminar); sin giro_activo, volteo en seco.
				if giro_activo:
					_giro_destino = signf(direccion)
					_cambiar(Estado.GIRO_AGACHADO)
				else:
					_mirar(direccion)
		Estado.ARRANQUE_AGACHADO:
			# Soltar la direccion antes de mover los pies da un solo paso
			# (paso_agachado); soltar abajo ahi lo deja como estaba. Despues, el
			# paso del arranque ya esta dado: se termina y la parada sale del ciclo.
			if paso_agachado_activo and not (abajo and adelante) and _sprite.frame < ARRANQUE_A_PASO.size() and abajo:
				var k: int = ARRANQUE_A_PASO[_sprite.frame]
				var x := position.x
				_cambiar(Estado.PASO_AGACHADO)
				_sprite.frame = k
				_x_tabla = x - _mirando * AVANCE_PASO_AGACHADO[k]
			elif not (abajo and adelante) and _sprite.frame <= ARRANQUE_AGACHADO_QUIETO:
				_cambiar(Estado.AGACHADO)
				_sprite.frame = _agachado_desde
				position.x = _x_tabla
		Estado.ANDAR_AGACHADO:
			if abajo and adelante:
				_parando_agachado = -1     # volver a pulsar cancela la parada
			else:
				# Sigue andando hasta un punto del paso desde el que la parada casa
				# (como al parar de andar) y se para; acaba agachado. Sin la tecla
				# abajo, AGACHADO lo levanta en el tick siguiente.
				if _parando_agachado < 0:
					_parando_agachado = 0
				var f := _sprite.frame
				if PARADA_AGACHADO_DESDE.has(f) or _parando_agachado >= espera_parada_agachado:
					var k: int = PARADA_AGACHADO_DESDE.get(f, 0)
					_cambiar(Estado.PARADA_AGACHADO)
					_sprite.frame = k
					# El tick del cambio tambien avanza (sin esto, un tick parado).
					_x_tabla = position.x + _mirando * (velocidad_agachado * get_physics_process_delta_time() - AVANCE_PARADA_AGACHADO[k])
		Estado.INCORPORANDO:
			if abajo and not _agachar_atras:
				_agachar_atras = true
				_sprite.play_backwards(&"incorporarse")
			elif not abajo and _agachar_atras:
				_agachar_atras = false
				_sprite.play(&"incorporarse")

## Andando agachado: el nodo avanza y el ciclo va por la distancia recorrida
## (como andar y correr en _physics_process), con sus pisadas. Mientras espera el
## apoyo para pararse sigue andando: los pies no pueden quedarse clavados a
## media zancada.
func _avanzar_agachado(delta: float) -> void:
	if _estado == Estado.ARRANQUE_AGACHADO or _estado == Estado.PARADA_AGACHADO or _estado == Estado.PASO_AGACHADO:
		# El nodo va por la tabla del fotograma (con la fraccion del fotograma,
		# para que no vaya a escalones): el pie apoyado se queda clavado.
		var tabla: Array = AVANCE_PARADA_AGACHADO
		if _estado == Estado.ARRANQUE_AGACHADO:
			tabla = AVANCE_ARRANQUE_AGACHADO
		elif _estado == Estado.PASO_AGACHADO:
			tabla = AVANCE_PASO_AGACHADO
		var f := clampi(_sprite.frame, 0, tabla.size() - 1)
		# En el ultimo fotograma no hay siguiente: se sigue al ritmo del anterior.
		# (Sin esto el nodo se paraba el ultimo fotograma del arranque, 3 ticks,
		# y arrancaba otra vez en el ciclo: un tiron.)
		var siguiente: float = tabla[f + 1] if f + 1 < tabla.size() else tabla[f] + (tabla[f] - tabla[maxi(f - 1, 0)])
		var x := lerpf(tabla[f], siguiente, _sprite.frame_progress)
		position.x = _x_tabla + _mirando * x
		return
	if _estado != Estado.ANDAR_AGACHADO:
		return
	var paso := velocidad_agachado * delta
	position.x += paso * _mirando
	_recorrido += paso
	var n := _sprite.sprite_frames.get_frame_count(&"andar_agachado")
	var antes := _sprite.frame
	var fotograma := int(_recorrido / avance_agachado + 1e-6) % n
	_sprite.frame = fotograma
	_pisar(fotograma, n)
	if _parando_agachado >= 0 and fotograma != antes:
		_parando_agachado += 1

## Toma de suelo del salto corriendo con la direccion pulsada: al ciclo de
## correr por el fotograma que mas se parece a la pose, y la cuenta de distancia
## colocada ahi para que el fotograma y el recorrido digan lo mismo.
func _seguir_corriendo_tras_salto() -> void:
	# La del aire sigue, y lo que pasa de la de correr se apaga solo (ver
	# aterrizaje_carrera_suavizado).
	var aire := _velocidad()
	_cambiar(Estado.CORRER)
	if aterrizaje_carrera_suavizado > 0.0:
		_sobrante = maxf(aire - velocidad_correr, 0.0)
	_sprite.frame = salto_correr_a_correr
	_recorrido = float(salto_correr_a_correr) * avance_correr
	_ultimo_fotograma = salto_correr_a_correr
	# El golpe de la caida esta en el sprite 33 del salto, que por aqui no se
	# llega a ver: suena en el propio corte, que es el momento del impacto.
	_sonar(GOLPES["salto_correr"][SALTO_CORRER_CAIDA_SPRITE], pasos_db, 0.0, true)
	pisada.emit(&"salto_correr", SALTO_CORRER_CAIDA_SPRITE)

## Arco y ritmo de los saltos. El sprite trae el salto cocido; el arco del nodo
## se le suma durante el vuelo, atado al fotograma (con la fraccion de
## fotograma, para que no vaya a escalones) y no al reloj, asi que sigue
## cuadrando aunque cambie el ritmo. Fuera del vuelo lo deja todo a cero: se
## llama cada tick.
##   salto corriendo: parabola de _arco_amp (la carrerilla y la altura
##                    variable) a _ritmo_vuelo(_arco_amp)
##   los demas (el de parado, el andando): solo lo cocido, a ritmo 1; con
##                    ligereza, el vuelo lo lleva _volar (flotar en la luz)
func _actualizar_saltos() -> void:
	var f := _sprite.frame
	var en_salto := _estado == Estado.SALTAR
	var correr := en_salto and _sprite.animation == &"salto_correr"
	var velocidad := giro_ritmo if _estado == Estado.GIRO_AGACHADO else 1.0
	var arco := 0.0
	if correr and _vuelo != 0:
		# Le ha dado la luz en este salto: lo lleva la fisica hasta el suelo.
		arco = _volar(get_physics_process_delta_time())
		velocidad = 0.0 if _vuelo == 1 or _vuelo == 2 else 1.0
	elif correr and f >= salto_correr_despegue and f < salto_correr_toca and _arco_t0 < 0.0 and _encima_corriendo():
		# A caer encima de algo (ver _encima_corriendo): desde ya, la fisica.
		arco = _volar(get_physics_process_delta_time())
		velocidad = 0.0 if _vuelo == 1 or _vuelo == 2 else 1.0
	elif correr and f >= salto_correr_despegue and f < salto_correr_toca:
		# Fotogramas de vuelo que lleva, y desde donde cuenta la parabola: con
		# arco_desde_despegue, desde lo que marcaba el sprite en el primer tick
		# del vuelo, asi que ese tick vale 0 y el arco acaba igual en toca.
		var tf := float(f - salto_correr_despegue) + _sprite.frame_progress
		if _arco_t0 < 0.0:
			_arco_t0 = tf if arco_desde_despegue else 0.0
		var tramo := float(maxi(salto_correr_toca - salto_correr_despegue, 1))
		var t := clampf((tf - _arco_t0) / maxf(tramo - _arco_t0, 1.0), 0.0, 1.0)
		var corto := _arco_max * clampf(salto_corto_factor, 0.0, 1.0)
		if salto_variable_activo:
			if not _salto_soltado and not _salto_mantenido():
				_salto_soltado = true
				# Soltada antes de que el arco suba (primer tick del vuelo, arco
				# en 0): el brinco corto entero desde el principio, sin transicion.
				if _arco_t < 0.0 and t <= 0.0:
					_arco_amp = corto
				_t_soltado = t
			var avance := maxf(t - _arco_t, 0.0) if _arco_t >= 0.0 else 0.0
			if _salto_soltado and t < 0.5 and _arco_amp > corto:
				# Hacia el brinco corto con una curva exponencial: baja mucho al
				# principio y cada vez menos, asi que la subida no vuelve a
				# acelerar (con un tramo recto, al acabarse el tramo la subida
				# doblaba de golpe su velocidad: un segundo empujon)...
				var objetivo := corto + (_arco_amp - corto) * exp(-avance / SALTO_CORTO_TAU)
				# ...y sin quitarle mas del 60 % de su velocidad de subida (se
				# anula al llegar al apogeo).
				var freno := SALTO_CORTO_FRENO * _arco_amp * (1.0 - 2.0 * t) / maxf(t * (1.0 - t), 0.01) * avance
				# Y entrando poco a poco (SALTO_CORTO_ENTRADA): soltar tarde, con la
				# subida aun rapida, le quitaba el 60 % de golpe en un tick.
				var entrada := clampf((t - _t_soltado) / SALTO_CORTO_ENTRADA, 0.0, 1.0)
				_arco_amp = lerpf(_arco_amp, maxf(corto, maxf(objetivo, _arco_amp - freno)), entrada)
		_arco_t = t
		velocidad = _ritmo_vuelo(_arco_amp)
		arco = _arco_amp * 4.0 * t * (1.0 - t)
		# En cuanto le da la luz, sigue la fisica desde aqui (FLOTAR EN LA LUZ).
		if _luz_en_carrera(arco, velocidad):
			velocidad = 0.0
	elif en_salto and not correr and (VUELO.has(_sprite.animation) or _flota or _giro_aire != 0.0 or _pisando):
		arco = _volar(get_physics_process_delta_time())
		# En el aire el fotograma lo pone _volar; el sprite no avanza solo.
		velocidad = 0.0 if _vuelo == 1 or _vuelo == 2 else 1.0
	_sprite.speed_scale = velocidad
	_sprite.position.y = -arco

## El arco del salto andando con esa luz al despegar (ver SALTO ANDANDO FUERA DE LA LUZ).
func _arco_salto_andando(luz: float) -> float:
	return lerpf(salto_andando_altura_oscuro, salto_andando_altura, clampf(luz, 0.0, 1.0))

## El ritmo de su vuelo (fotogramas/s) para que caiga con salto_andando_gravedad:
## _parabola_vuelo da g = ritmo^2 (gc + 8 amp / n^2). En la luz, el de siempre.
func _ritmo_salto_andando(v: Dictionary, amp: float, fps: float, luz: float) -> float:
	if salto_andando_gravedad <= 0.0:
		return fps
	var n := float(v["toca"] - v["despegue"])
	var n_cima: float = v["apogeo"] - v["despegue"]
	var gc: float = 2.0 * v["alto"] / (n_cima * n_cima)
	var r := sqrt(salto_andando_gravedad / (gc + 8.0 * amp / (n * n)))
	return lerpf(r, fps, clampf(luz, 0.0, 1.0))

## Parabola del vuelo que se ve con el ritmo de siempre (sin luz): la cocida del
## sprite a `ritmo` fotogramas/s mas un arco anadido de `amp` px atado al vuelo
## (el del salto corriendo y su carrerilla; salto_andando_altura en el andando).
## Las dos son parabolas que empiezan y acaban igual, asi que la suma tambien:
## devuelve su velocidad de despegue (x, px/s) y su gravedad (y, px/s^2).
func _parabola_vuelo(v: Dictionary, amp: float, ritmo: float) -> Vector2:
	var n_cima: float = v["apogeo"] - v["despegue"]
	var gc: float = 2.0 * v["alto"] / (n_cima * n_cima)   # px/fotograma^2
	var tf: float = float(v["toca"] - v["despegue"]) / ritmo   # s de vuelo
	return Vector2(gc * n_cima * ritmo + 4.0 * amp / tf, gc * ritmo * ritmo + 8.0 * amp / (tf * tf))

## Altura cocida del cuerpo en el fotograma (con fraccion) n del vuelo, sin la
## pose: la parabola que se le ajusto al sprite.
func _cocido_vuelo(v: Dictionary, n: float) -> float:
	var n_cima: float = v["apogeo"] - v["despegue"]
	var gc: float = 2.0 * v["alto"] / (n_cima * n_cima)
	return gc * n_cima * n - gc * n * n * 0.5

## La pose (cuerpo cocido menos parabola) en tau, interpolada.
func _pose_vuelo(v: Dictionary, tau: float) -> float:
	var pose: Array = v["pose"]
	var j := clampf(tau - float(v["despegue"]), 0.0, float(pose.size() - 1))
	var j0 := mini(floori(j), pose.size() - 2)
	return lerpf(float(pose[j0]), float(pose[j0 + 1]), j - j0)

## Arranca la fisica del vuelo en el fotograma tau con el cuerpo a altura y
## (sobre el despegue, sin la pose) y velocidad vel, sobre la parabola de
## gravedad g y ritmo `ritmo` (fotogramas/s sin luz). Si ya baja, se coloca el
## apogeo donde estuvo, para que la bajada reparta igual que sin luz.
func _empezar_vuelo(tau: float, y: float, vel: float, g: float, ritmo: float) -> void:
	_vuelo_tau = tau
	_vuelo_y = y
	_vuelo_v = vel
	_f_g = g
	_f_ritmo = ritmo
	_f_tau_ref = tau
	_f_v_ref = vel
	_f_tau_cima = tau + vel / g * ritmo
	_f_corte = 1.0
	_ancla_dura = 0.0
	_encima_suelo = NAN
	if vel > 0.0:
		_vuelo = 1
	else:
		_vuelo = 2
		_vuelo_cima = y + vel * vel / (2.0 * g)

## Salto corriendo, aun con su arco de siempre: si le da la luz donde esta el
## cuerpo, pasa a la fisica del vuelo desde la altura y la velocidad que lleva
## (lo mismo que se ve), con la parabola de su carrerilla y su ritmo. Soltar
## la tecla subiendo (la altura variable) pasa a ser mas gravedad mientras
## sube: soltada al despegar, llega a la altura del brinco corto.
func _luz_en_carrera(arco: float, ritmo: float) -> bool:
	var v: Dictionary = VUELO[&"salto_correr"]
	var d0: int = v["despegue"]
	var f := _sprite.frame
	var cuerpo := _cocido_vuelo(v, float(f - d0)) + float(v["pose"][clampi(f - d0, 0, v["pose"].size() - 1)]) + arco
	_luz = 0.0
	if ligereza.is_valid():
		_luz = clampf(ligereza.call(global_position + Vector2(0.0, -(float(v["centro"]) + cuerpo))), 0.0, 1.0)
	# SUELO VARIABLE: sobre un suelo mas bajo que el despegue (salta desde un
	# bloque) tambien pasa a la fisica, que lo lleva hasta ese suelo.
	if _luz <= 0.0 and absf(_desnivel()) <= 0.5:
		return false
	var fps := _sprite.sprite_frames.get_animation_speed(_sprite.animation)
	var r := fps * ritmo
	var p := _parabola_vuelo(v, _arco_amp, r)
	var tau := float(f) + _sprite.frame_progress
	# El vuelo es de este salto (en los otros lo apunta _volar al despegar; este
	# entra ya en el aire: sin esto, el primer salto corriendo de la partida que
	# entraba en la luz no tenia salto y daba error).
	_vuelo_de = &"salto_correr"
	_empezar_vuelo(tau, cuerpo - _pose_vuelo(v, tau), p.x - p.y * (tau - d0) / r, p.y, r)
	_f_v0 = p.x
	if salto_variable_activo:
		var corto := minf(_arco_max * clampf(salto_corto_factor, 0.0, 1.0), _arco_amp)
		var pc := _parabola_vuelo(v, corto, fps * _ritmo_vuelo(corto))
		_f_corte = maxf((p.x * p.x / p.y) / maxf(pc.x * pc.x / pc.y, 0.001), 1.0)
	return true

## Vuelo de los saltos con la gravedad del sitio (ver FLOTAR EN LA LUZ). Lleva
## el fotograma y devuelve el arco. El de parado y el andando, del despegue a la
## toma de suelo; el corriendo, desde que le da la luz. Antes del despegue y
## despues de tocar suelo no hace nada: el sprite va solo, a ritmo 1.
func _volar(delta: float) -> float:
	if _vuelo == 3:
		return 0.0
	if _pisando:
		return _volar_pisando(delta)
	if _vuelo == 0:
		_vuelo_de = _sprite.animation
	var v: Dictionary = VUELO[_vuelo_de]
	var d0: int = v["despegue"]
	var t1: int = v["toca"]
	if _vuelo == 0 and _sprite.frame < d0:
		return 0.0
	# El suelo de la toma (SUELO VARIABLE: por debajo del despegue lo que baje
	# el suelo de debajo).
	var suelo := _cocido_vuelo(v, float(t1 - d0)) - _desnivel()
	if _vuelo == 0:
		# Despega: la parabola arranca en el fotograma del despegue, y este
		# tick ya vuela (a ritmo 1 deja el fotograma siguiente, el de siempre).
		# Arrancarla por donde decia frame_progress la adelantaba un fotograma
		# entero (al cambiar de fotograma el sprite deja el progreso casi en 1)
		# y en la luz el cuerpo bajaba 3-5 px de golpe al despegar.
		var fps := _sprite.sprite_frames.get_animation_speed(_sprite.animation)
		var amp := 0.0
		var ritmo := fps
		var luz0 := 0.0
		if ligereza.is_valid():
			luz0 = clampf(ligereza.call(global_position + Vector2(0.0, -float(v["centro"]))), 0.0, 1.0)
		if _sprite.animation == &"saltar" and _salto_borde:
			pass                           # dejarse caer: el saltito del video, a su ritmo
		elif _sprite.animation == &"saltar":
			# el andando: fuera de la luz sube mas y con la gravedad de verdad
			# (salto_andando_altura_oscuro, salto_andando_gravedad); en la luz,
			# lo afinado para flotar
			amp = _arco_salto_andando(luz0)
			ritmo = _ritmo_salto_andando(v, amp, fps, luz0)
		elif _sprite.animation == &"salto_parado":
			# el de parado, igual (SALTO DE PARADO MAS ALTO): el ritmo sale de la
			# misma gravedad, con su propio vuelo cocido
			amp = lerpf(salto_parado_altura_oscuro, salto_parado_altura, luz0)
			ritmo = _ritmo_salto_andando(v, amp, fps, luz0)
		# SALTAR ENCIMA: sin luz, el andando, y el de parado con la tecla hacia delante
		var hacia := 0.0 if control_bloqueado else Input.get_axis("mover_izquierda", "mover_derecha")
		var encima := {}
		if suelo_en.is_valid() and luz0 <= 0.0 and not _salto_borde and (_sprite.animation == &"saltar" \
				or (_sprite.animation == &"salto_parado" and signf(hacia) == _mirando)):
			encima = _salto_encima(v, amp, fps, _impulso)
			if not encima.is_empty():
				amp = encima["amp"]
				ritmo = encima["ritmo"]
				_impulso = encima["impulso"]
		var p := _parabola_vuelo(v, amp, ritmo)
		_empezar_vuelo(d0, 0.0, p.x, p.y, ritmo)
		_f_v0 = p.x
		_encima_suelo = encima.get("suelo", NAN)
	# La luz donde esta el cuerpo (su centro, que sube con el salto).
	_luz = 0.0
	if ligereza.is_valid():
		var centro := global_position + Vector2(0.0, -(float(v["centro"]) + _vuelo_y))
		_luz = clampf(ligereza.call(centro), 0.0, 1.0)
	var ge := _f_g * lerpf(1.0, gravedad_luz, _luz)
	if _vuelo == 1 and not _salto_mantenido():
		ge *= _f_corte
	if _vuelo == 2 and _vuelo_y < 0.0 and _luz <= 0.0 and _bajada() > 0.0:
		ge = maxf(ge, gravedad_caida)      # SUELO VARIABLE: cae por debajo del despegue
	if _vuelo == 1:
		if _vuelo_v - ge * delta > 0.0:
			_vuelo_y += _vuelo_v * delta - ge * delta * delta * 0.5
			_vuelo_v -= ge * delta
		else:
			# Pasa el apogeo dentro de este tick: se guarda su altura exacta,
			# que es la que reparte la bajada.
			var t_cima := _vuelo_v / ge
			_vuelo_cima = _vuelo_y + _vuelo_v * t_cima * 0.5
			var resto := delta - t_cima
			_vuelo_y = _vuelo_cima - ge * resto * resto * 0.5
			_vuelo_v = -ge * resto
			_vuelo = 2
			# Llega arriba con luz: baja flotando (ver FLOTAR CON SUS ANIMACIONES).
			# Si ya flota (acabo de girarse subiendo), sigue por donde iba.
			if not _flota:
				_flota = _vuelo_de == &"salto_parado" and _flotar.has("flotar_bajar") and _luz >= flotar_luz_min
				_flota_iv = 0.0
	else:
		# Bajando, en la luz el aire lo sostiene: no pasa de caida_max_luz. Si
		# entra en la luz cayendo mas deprisa, frena hasta ahi en unas decimas.
		var v1 := _vuelo_v - ge * delta
		if _luz > 0.0:
			var tope := _tope_caida()
			if _vuelo_v >= -tope:
				# Al llegar al tope ya no acelera (antes el tope era blando y
				# con la gravedad empujando se quedaba 66 px/s por encima).
				v1 = maxf(v1, -tope)
			else:
				# Mas deprisa que el tope (entra en la luz cayendo, o la luz lo
				# sostiene para girarse): frena hacia el, sin la gravedad del
				# tick (con ella el freno no podia con la gravedad y se quedaba
				# 50 px/s por encima).
				v1 = minf(lerpf(_vuelo_v, -tope, 1.0 - exp(-delta / 0.12)), -tope)
		_vuelo_y += (_vuelo_v + v1) * 0.5 * delta
		_vuelo_v = v1
	# Girarse en el aire (ver GIRAR EN EL AIRE): empieza cuando la pose casa y
	# mientras dura lleva el fotograma; al acabar sigue lo que toque.
	if _giro_aire_pedido != 0.0 and _giro_aire == 0.0 and _puede_girar_en_el_aire():
		_empezar_giro_aire()
	if _giro_aire != 0.0:
		var arco_giro := _volar_girando()
		if _giro_aire != 0.0 or _vuelo == 3:
			return arco_giro
	if _flota:
		return _volar_flotando()
	if _vuelo == 1:
		# Subiendo: el fotograma va con la velocidad que ha gastado, de donde
		# empezo a subir (el despegue, o donde reboto) al del apogeo.
		_vuelo_tau = _f_tau_ref + (_f_tau_cima - _f_tau_ref) * (1.0 - _vuelo_v / _f_v_ref)
	elif _vuelo_y <= suelo + 0.001:
		# Toca suelo: el sprite sigue solo desde el fotograma de la toma (y el
		# nodo baja al suelo de abajo, si lo hay).
		_vuelo = 3
		_aterrizar_abajo()
		_sprite.set_frame_and_progress(t1, 0.0)
		return 0.0
	else:
		# Bajando: lo caido sobre lo que hay del apogeo al suelo (sin luz cae
		# como t^2: el fotograma va con la raiz). Si el suelo baja a media bajada
		# (pasa un borde cayendo) no vuelve atras: espera a que lo caido le alcance.
		# (saltando encima de algo, la bajada se reparte ya hasta alli: ver SALTAR ENCIMA)
		var suelo_mapa := suelo if is_nan(_encima_suelo) else maxf(suelo, _encima_suelo)
		var caido := clampf((_vuelo_cima - _vuelo_y) / maxf(_vuelo_cima - suelo_mapa, 0.001), 0.0, 1.0)
		var tau_bajada := _f_tau_cima + (t1 - _f_tau_cima) * sqrt(caido)
		if not suelo_en.is_valid():
			_vuelo_tau = tau_bajada
		else:
			# SUELO VARIABLE: si el suelo sube a media bajada (pasa por encima de
			# una cara), lo caido sobre una bajada mas corta se saltaba fotogramas
			# de golpe: desde ahi los que quedan se reparten en lo que tarde en
			# tocar. Si cambia otra vez, se vuelve a repartir; si baja, como
			# siempre (espera a que lo caido le alcance).
			if _ancla_dura > 0.0 and absf(suelo_mapa - _ancla_suelo) > 0.5:
				_ancla_dura = 0.0
			if _ancla_dura <= 0.0 and tau_bajada > _vuelo_tau + 1.5:
				_ancla_suelo = suelo_mapa
				_ancla_tau = _vuelo_tau
				_ancla_t = 0.0
				_ancla_dura = maxf(_tiempo_de_caida(_vuelo_y - suelo_mapa, -_vuelo_v, ge), delta)
			if _ancla_dura > 0.0:
				_ancla_t += delta
				tau_bajada = _ancla_tau + (float(t1) - _ancla_tau) * clampf(_ancla_t / _ancla_dura, 0.0, 1.0)
			_vuelo_tau = maxf(_vuelo_tau, tau_bajada)
	# Fotograma: el mas cercano a tau (con el ritmo de siempre tau es entero en
	# cada tick y da el fotograma de siempre).
	var f := clampi(roundi(_vuelo_tau), d0, t1)
	if f != _sprite.frame:
		_sprite.set_frame_and_progress(f, 0.0)
	# Arco: el cuerpo se ve en lo integrado mas lo que la pose le sube o le baja
	# (el tiron del arranque, salvo lo que la luz le quita: luz_quita_tiron),
	# menos lo que el fotograma que se ve ya trae cocido. La pose va
	# interpolada en tau: con los fotogramas despacio (cada tres ticks en la
	# luz) el cuerpo sigue moviendose suave y solo la pose va a saltos. Con el
	# ritmo de siempre tau es entero y el arco da 0. Los pies, nunca por debajo
	# del suelo.
	var i := f - d0
	var cocido := _cocido_vuelo(v, float(i)) + float(v["pose"][i])
	var arco := _vuelo_y + (1.0 - luz_quita_tiron * _luz) * _pose_vuelo(v, _vuelo_tau) - cocido
	return maxf(arco, -float(v["pies"][i]) - _desnivel())

## Bajada flotando (ver FLOTAR CON SUS ANIMACIONES), con la fisica ya
## integrada en este tick: elige el fotograma de la secuencia (los del salto
## de flotar_desde a 37, luego flotar_bajar) por lo caido y devuelve el arco
## que pone el cuerpo donde dice la fisica. Al tocar suelo pasa a posarse.
func _volar_flotando() -> float:
	var v: Dictionary = VUELO[_vuelo_de]
	var fb: Dictionary = _flotar["flotar_bajar"]
	var cuerpo: Array = fb["cuerpo"]
	var b0: float = _flotar["_despegue"][String(_vuelo_de)]
	# El suelo de la fisica (alturas sobre el despegue): el cuerpo cuando los
	# pies tocan, en el ultimo de flotar_bajar (y lo que baje el suelo de debajo).
	var suelo: float = float(cuerpo[cuerpo.size() - 1]) - b0 - _desnivel()
	if _vuelo == 2 and _vuelo_y <= suelo + 0.001:
		_posarse_flotando()
		return 0.0
	# Ritmo parejo: lo que queda de la secuencia, repartido en lo que le queda
	# hasta tocar (con la gravedad y el tope de ahora, que cambian si sale o
	# entra en la luz); a lo sumo dos por tick. Con la bajada lenta de la luz
	# (caida_max_luz) va a uno por tick o menos: todos los fotogramas, como los
	# saltos de siempre (a 2,5 veces su video). Repartido por lo caido, metia
	# 87 fotogramas en 45 ticks (4,5 veces el video, saltandose la mitad) y la
	# tunica se veia "tosca, a cortes" (2026-10-12).
	var dt := get_physics_process_delta_time()
	# (PISAR LA HOJA SIN DESCUADRE) bajando, con una hoja debajo, se reparte
	# hasta ella: llega con los pies estirados, en la pose de tocar. Solo en
	# lo ultimo (PISAR_ANTICIPA s) y sin un giro pedido: repartir toda la bajada
	# hasta una hoja cercana corria los fotogramas y cerraba enseguida el giro
	# en el aire (giro_aire_hasta): pulsando hacia atras solo frenaba, "no
	# responde" (2026-10-14).
	var suelo_ritmo := suelo
	if _vuelo == 2 and hoja_debajo.is_valid() and _giro_aire_pedido == 0.0:
		var hy: float = hoja_debajo.call(Vector2(global_position.x, global_position.y - altura_pies()))
		if is_finite(hy):
			var pies: Array = fb["pies"]
			var hl := position.y - hy - PISAR_EN_HOJA
			var suelo_hoja := float(cuerpo[cuerpo.size() - 1]) - b0 + hl - float(pies[pies.size() - 1])
			if suelo_hoja > suelo and _tiempo_hasta_suelo(_vuelo_y - suelo_hoja) <= PISAR_ANTICIPA:
				suelo_ritmo = suelo_hoja
	var queda := _tiempo_hasta_suelo(_vuelo_y - suelo_ritmo)
	var de_salto := 38 - flotar_desde
	# FLOTAR QUIETO: lo que queda hasta posarse en el suelo o en la hoja de debajo
	# (esta, aunque aun quede lejos: si sigue debajo, ahi se posara)
	var queda_q := queda
	if _flotar.has("flotar_quieto") and _vuelo == 2:
		queda_q = _tiempo_hasta_suelo(_vuelo_y - _suelo_quieto(suelo, b0, cuerpo, fb))
		if _quieto >= 0.0:
			var j0: int = _flotar["flotar_quieto"]["a_bajar"][clampi(int(_quieto), 0, int(_flotar["flotar_quieto"]["n"]) - 1)]
			if queda_q > _tiempo_posarse(j0):
				return _volar_quieto(dt, b0)
			# a posarse, por el fotograma de la bajada que mas se parece
			_quieto = -1.0
			_flota_iv = float(de_salto + j0)
		elif _flota_iv >= float(de_salto) - 0.001 and _flota_iv < float(de_salto) + 1.0 \
				and queda_q > _tiempo_posarse(0) + flotar_quieto_margen:
			# llega a la pose de flotar con altura de sobra: flota quieto
			_quieto = 0.0
			_tras_giro = false
			return _volar_quieto(dt, b0)
	var faltan := (_flota_largo() - 1.0) - _flota_iv
	var paso := clampf(faltan / maxf(queda / dt, 1.0), 0.0, 2.0)
	if _flotar.has("flotar_quieto") and _vuelo == 2 and _flota_iv < float(de_salto) \
			and queda_q > _tiempo_posarse(0) + flotar_quieto_margen:
		# hacia el flotar quieto: los del salto hasta la pose, a uno por tick
		paso = 1.0
	_flota_iv += paso
	var k := floori(_flota_iv + 0.0001)
	if k < de_salto:
		# Aun los del salto (del apogeo a la pose de flotar).
		_vuelo_tau = float(flotar_desde) + _flota_iv
		var f := clampi(flotar_desde + k, int(v["despegue"]), int(v["toca"]))
		if _sprite.animation != _vuelo_de:
			_sprite.animation = _vuelo_de
			_sprite.offset = offset_comun
		if f != _sprite.frame:
			_sprite.set_frame_and_progress(f, 0.0)
		var i := f - int(v["despegue"])
		var cocido := _cocido_vuelo(v, float(i)) + float(v["pose"][i])
		return _vuelo_y + (1.0 - luz_quita_tiron * _luz) * _pose_vuelo(v, _vuelo_tau) - cocido
	_vuelo_tau = 38.0 + (_flota_iv - de_salto)
	var j := clampi(k - de_salto, 0, cuerpo.size() - 1)
	if _sprite.animation != &"flotar_bajar":
		_sprite.animation = &"flotar_bajar"
		_sprite.offset = _offset_flotar(&"flotar_bajar")
	if j != _sprite.frame:
		_sprite.set_frame_and_progress(j, 0.0)
	var arco := (_vuelo_y + b0) - float(cuerpo[j])
	return maxf(arco, -float(fb["pies"][j]) - _desnivel())

## Un tick flotando quieto (FLOTAR QUIETO): el bucle a su ritmo y el cuerpo
## donde dice la fisica (como en la bajada).
func _volar_quieto(dt: float, b0: float) -> float:
	var fq: Dictionary = _flotar["flotar_quieto"]
	var n := int(fq["n"])
	_quieto += float(fq["fps"]) * dt
	while _quieto >= float(n):
		_quieto -= float(n - flotar_quieto_vuelta)
	var f := clampi(int(_quieto), 0, n - 1)
	_vuelo_tau = 38.0
	if _sprite.animation != &"flotar_quieto":
		_sprite.animation = &"flotar_quieto"
		_sprite.offset = _offset_flotar(&"flotar_quieto")
	if f != _sprite.frame:
		_sprite.set_frame_and_progress(f, 0.0)
	var arco := (_vuelo_y + b0) - float(fq["cuerpo"][f])
	return maxf(arco, -float(fq["pies"][f]) - _desnivel())

## Segundos que tarda la bajada en posarse desde su fotograma j, a uno por tick
## (todos los fotogramas, como los saltos).
func _tiempo_posarse(j: int) -> float:
	return float(int(_flotar["flotar_bajar"]["n"]) - 1 - j) * get_physics_process_delta_time()

## Donde se posaria (altura de la fisica): el suelo, o la hoja que tenga debajo
## si la hay (como suelo_ritmo de _volar_flotando, pero sin esperar a tenerla
## cerca: flotando quieto hay que saber con tiempo cuando empezar a posarse).
func _suelo_quieto(suelo: float, b0: float, cuerpo: Array, fb: Dictionary) -> float:
	if not hoja_debajo.is_valid() or _giro_aire_pedido != 0.0:
		return suelo
	var hy: float = hoja_debajo.call(Vector2(global_position.x, global_position.y - altura_pies()))
	if not is_finite(hy):
		return suelo
	var pies: Array = fb["pies"]
	var hl := position.y - hy - PISAR_EN_HOJA
	return maxf(suelo, float(cuerpo[cuerpo.size() - 1]) - b0 + hl - float(pies[pies.size() - 1]))

## Segundos hasta que el cuerpo baje h px (hasta el suelo de la bajada), con
## la velocidad, la gravedad y el tope de caida de ahora (ver caida_max_luz).
func _tiempo_hasta_suelo(h: float) -> float:
	var g := maxf(_f_g * lerpf(1.0, gravedad_luz, _luz), 1.0)
	var tope := _tope_caida()
	var u := -_vuelo_v
	var t0 := 0.0
	if u < 0.0:
		# Aun sube (flotando tras girarse subiendo): hasta el apogeo, y la
		# bajada desde alli.
		t0 = -u / g
		h += u * u / (2.0 * g)
		u = 0.0
	if h <= 0.0:
		return t0
	if u >= tope:
		return t0 + h / tope
	var t1 := (tope - u) / g
	var d1 := u * t1 + 0.5 * g * t1 * t1
	if d1 >= h or is_inf(tope):
		return t0 + (-u + sqrt(u * u + 2.0 * g * h)) / g
	return t0 + t1 + (h - d1) / tope

## Fotogramas de la bajada flotando: los del salto hasta la pose de flotar y
## los de flotar_bajar.
func _flota_largo() -> float:
	return float(38 - flotar_desde + int(_flotar["flotar_bajar"]["n"]))

## Toca suelo flotando: pasa a posarse (a su ritmo, hasta el reposo).
func _posarse_flotando() -> void:
	_vuelo = 3
	_aterrizar_abajo()
	_tras_giro = false
	_sprite.animation = &"flotar_posarse"
	_sprite.offset = _offset_flotar(&"flotar_posarse")
	_sprite.set_frame_and_progress(0, 0.0)
	_sonar(GOLPES["salto_parado"][47], pasos_db + posarse_db, 0.0, true)
	pisada.emit(&"flotar_posarse", 0)

## Altura de la fisica (sobre el despegue) a la que tocan los pies bajando
## flotando: la del cuerpo en el ultimo de flotar_bajar.
func _suelo_flotar() -> float:
	var cuerpo: Array = _flotar["flotar_bajar"]["cuerpo"]
	return float(cuerpo[cuerpo.size() - 1]) - float(_flotar["_despegue"][String(_vuelo_de)]) - _desnivel()

## Tope de la caida ahora (px/s; INF sin luz): caida_max_luz, abierto en el
## borde con lo que baja la luz. Girandose en el aire o flotando tras girarse,
## ademas, lo justo para que lo que queda (el giro y la bajada flotando entera)
## vaya a un fotograma por tick, sin bajar de giro_aire_caida_min: la luz lo
## sostiene mientras se da la vuelta, como en el video.
func _tope_caida() -> float:
	if _luz <= 0.0:
		return INF
	var tope := lerpf(caida_max_luz / maxf(_luz, 0.001), caida_max_luz, _luz)
	if (_giro_aire != 0.0 or _tras_giro) and _flotar.has("flotar_bajar"):
		var h := _vuelo_y - _suelo_flotar()
		var faltan := _fotogramas_hasta_posarse()
		if h > 0.0 and faltan > 0.0:
			tope = minf(tope, maxf(h / (faltan * get_physics_process_delta_time()), giro_aire_caida_min))
	return tope

## Fotogramas hasta tocar suelo flotando: girandose, lo que queda del giro y
## la bajada entera desde la pose de flotar (en la que acaba el giro); si no,
## lo que queda de la bajada.
func _fotogramas_hasta_posarse() -> float:
	var de_salto := float(38 - flotar_desde)
	if _giro_aire != 0.0:
		return float(_flotar["flotar_girar"]["n"]) - 1.0 - _giro_iv + _flota_largo() - 1.0 - de_salto
	return _flota_largo() - 1.0 - _flota_iv

## Con la direccion contraria a donde mira, en un vuelo con la fisica, pide
## girarse en el aire (ver GIRAR EN EL AIRE); empieza en _volar cuando puede.
## Soltarla, o volver a la de antes, lo deja si aun no ha empezado.
func _pedir_giro_aire(direccion: float) -> void:
	if _estado != Estado.SALTAR or not (_vuelo == 1 or _vuelo == 2) \
			or is_zero_approx(direccion) or signf(direccion) == _mirando:
		_giro_aire_pedido = 0.0
	elif _giro_aire == 0.0:
		_giro_aire_pedido = signf(direccion)

## Si puede empezar a girarse ahora: con luz, en el salto de parado (sus
## fotogramas son los que casan con la pose de flotar en que empieza el
## giro), con la pose cerca de la de flotar (giro_aire_desde subiendo,
## giro_aire_hasta bajando) y con sitio para el giro y la bajada entera sin
## bajar mas despacio que giro_aire_caida_min.
func _puede_girar_en_el_aire() -> bool:
	if not _flotar.has("flotar_girar") or _vuelo_de != &"salto_parado" or _luz < flotar_luz_min:
		return false
	var de_salto := float(38 - flotar_desde)
	if _flota:
		# flotando quieto, siempre (la pose casa en todo el bucle); en la
		# bajada, hasta giro_aire_hasta
		if _quieto < 0.0 and _flota_iv > de_salto + float(giro_aire_hasta):
			return false
	elif _vuelo != 1 or _vuelo_tau < float(giro_aire_desde):
		return false
	# Subiendo, lo que aun sube suma altura y tiempo.
	var g := maxf(_f_g * lerpf(1.0, gravedad_luz, _luz), 1.0)
	var h := _vuelo_y - _suelo_flotar()
	var t := 0.0
	if _vuelo_v > 0.0:
		h += _vuelo_v * _vuelo_v / (2.0 * g)
		t = _vuelo_v / g
	var faltan := float(_flotar["flotar_girar"]["n"]) - 1.0 - float(giro_aire_inicio) + _flota_largo() - 1.0 - de_salto
	return h >= giro_aire_caida_min * maxf(faltan * get_physics_process_delta_time() - t, 0.0)

## Empieza a girarse en el aire: el primer fotograma del giro es la pose de
## flotar (mirando a donde mira; volteado con flip_h si mira a la izquierda).
func _empezar_giro_aire() -> void:
	_giro_aire = _giro_aire_pedido
	_giro_aire_pedido = 0.0
	_quieto = -1.0
	_giro_iv = float(giro_aire_inicio)
	_sprite.animation = &"flotar_girar"
	_sprite.offset = _offset_flotar(&"flotar_girar")
	_sprite.set_frame_and_progress(giro_aire_inicio, 0.0)

## Un tick del giro en el aire, con la fisica ya integrada: un fotograma por
## tick y el cuerpo donde dice la fisica (como en la bajada flotando). Al
## acabar mira al otro lado y deja el sprite en lo que toque (_acabar_giro_aire).
## Si toca suelo girando (no deberia: la luz lo sostiene para que quepa, ver
## _tope_caida), acaba el giro y se posa.
func _volar_girando() -> float:
	var fg: Dictionary = _flotar["flotar_girar"]
	var b0: float = _flotar["_despegue"][String(_vuelo_de)]
	if _vuelo == 2 and _vuelo_y <= _suelo_flotar() + 0.001:
		_mirar(_giro_aire)
		_giro_aire = 0.0
		_posarse_flotando()
		return 0.0
	var f := floori(_giro_iv + 0.0001)
	if f >= int(fg["n"]):
		_acabar_giro_aire()
		return 0.0
	if f != _sprite.frame:
		_sprite.set_frame_and_progress(f, 0.0)
	# deprisa al empezar (RESPUESTA DEL GIRO EN EL AIRE), luego a uno por tick
	_giro_iv += lerpf(giro_aire_arranque, 1.0, clampf(_giro_iv / maxf(float(giro_aire_rampa), 1.0), 0.0, 1.0))
	var arco := (_vuelo_y + b0) - float(fg["cuerpo"][f])
	return maxf(arco, -float(fg["pies"][f]) - _desnivel())

## Acaba el giro en el aire: mira al otro lado y sigue flotando desde la pose de
## flotar (el principio de flotar_bajar), ya volteado; sin luz para flotar,
## con los fotogramas del salto.
func _acabar_giro_aire() -> void:
	_mirar(_giro_aire)
	_giro_aire = 0.0
	if _flotar.has("flotar_bajar") and (_flota or _luz >= flotar_luz_min):
		_flota = true
		_tras_giro = true
		_flota_iv = float(38 - flotar_desde)
		_sprite.animation = &"flotar_bajar"
		_sprite.offset = _offset_flotar(&"flotar_bajar")
		_sprite.set_frame_and_progress(0, 0.0)
	else:
		_flota = false
		_quieto = -1.0
		_sprite.animation = _vuelo_de
		_sprite.offset = offset_comun

## El offset de una animacion de flotar. Sus casillas no estan centradas en
## el eje del cuerpo (offset x de ~-28), y flip_h voltea el dibujo pero no el
## offset: mirando a la izquierda hay que voltearlo a mano. Sin esto, al pasar
## a flotar el dibujo saltaba 56 px hacia donde mira ("avanza, se desplaza y
## luego cae", 2026-10-12); las de siempre tienen el x del offset en 0.
func _offset_flotar(anim: StringName) -> Vector2:
	var o: Array = _flotar[String(anim)]["offset"]
	return Vector2(-o[0] if _sprite.flip_h else o[0], o[1])

## Anade las animaciones de flotar (flotar.json y sus hojas) a las del sprite.
func _cargar_flotar() -> void:
	if not FileAccess.file_exists(FLOTAR):
		return
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(FLOTAR))
	if not datos is Dictionary:
		return
	_flotar = datos
	var sf := _sprite.sprite_frames
	for nombre in _flotar:
		if String(nombre).begins_with("_"):
			continue
		var d: Dictionary = _flotar[nombre]
		if sf.has_animation(nombre):
			continue
		var hoja: Texture2D = load(d["hoja"])
		if hoja == null:
			continue
		sf.add_animation(nombre)
		sf.set_animation_speed(nombre, d["fps"])
		sf.set_animation_loop(nombre, d["bucle"])
		var w: int = d["casilla"][0]
		var h: int = d["casilla"][1]
		for i in int(d["n"]):
			var t := AtlasTexture.new()
			t.atlas = hoja
			t.region = Rect2((i % int(d["cols"])) * w, (i / int(d["cols"])) * h, w, h)
			sf.add_frame(nombre, t)

## La tecla de salto sigue pulsada (y el jugador tiene el control y puede
## saltar: con salto_bloqueado, arriba es otra cosa y cuenta como soltada).
func _salto_mantenido() -> bool:
	return not control_bloqueado and not salto_bloqueado and Input.is_action_pressed("saltar")

## Carrerilla: sube corriendo a crucero con la tecla hacia delante (no en la
## espera de la parada tras soltar, ni con la tecla anulada por la frenada del
## limite), se congela en el aire del salto corriendo y baja en todo lo demas.
## Ver carrerilla_activa.
func _actualizar_carrerilla(delta: float, direccion: float) -> void:
	if not carrerilla_activa:
		_carrerilla = 0.0
	elif _estado == Estado.CORRER and signf(direccion) == _mirando:
		_carrerilla = minf(_carrerilla + delta / maxf(carrerilla_tiempo, 0.01), 1.0)
	elif not (_estado == Estado.SALTAR and _sprite.animation == &"salto_correr"):
		_carrerilla = maxf(_carrerilla - delta / maxf(carrerilla_vaciado, 0.01), 0.0)

## Tras caer corriendo, lo que pasa de la de correr se apaga solo (ver
## aterrizaje_carrera_suavizado); por debajo de 2 px/s ya es cero.
func _apagar_sobrante(delta: float) -> void:
	if _estado != Estado.CORRER or aterrizaje_carrera_suavizado <= 0.0:
		_sobrante = 0.0
		return
	_sobrante *= exp(-delta / aterrizaje_carrera_suavizado)
	if _sobrante < 2.0:
		_sobrante = 0.0

## Datos para el panel de estudio del movimiento (datos_movimiento.gd). Solo
## lectura.
func datos_movimiento() -> Dictionary:
	return {
		"estado": Estado.keys()[_estado],
		"animacion": String(_sprite.animation),
		"fotograma": _sprite.frame,
		"velocidad": _velocidad(),
		"carrerilla": _carrerilla,
		"arco": -_sprite.position.y,
		"luz": _luz,
	}

## Un sonido suelto por el reproductor de las pisadas, que en la cinematica
## esta libre. desde = segundos del archivo por los que empezar.
func _sonar(sonido: AudioStream, db: float, desde: float = 0.0, variar: bool = false) -> void:
	_pasos.stream = sonido
	_pasos.volume_db = db
	_pasos.pitch_scale = randf_range(1.0 - pasos_variacion, 1.0 + pasos_variacion) if variar else 1.0
	_pasos.play(desde)

## Golpes de las animaciones que reproduce el nodo (ver GOLPES), y el de la
## caida, que suena en el sprite en que el cuerpo da contra el suelo, no al
## entrar en la animacion: entre lo uno y lo otro hay siete sprites, 0,3 s.
func _al_cambiar_fotograma() -> void:
	if _estado == Estado.CAIDA:
		_apoyar_caida()
		if _sprite.frame == golpe_sprite:
			_sonar(SONIDOS_CAIDA["golpe"], golpe_db)
			impacto.emit()
			return
	var golpes: Dictionary = golpes_anim.get(String(_sprite.animation), {})
	if golpes.has(_sprite.frame):
		var agachado := _sprite.animation in [&"arranque_agachado", &"parada_agachado", &"paso_agachado"]
		_sonar(golpes[_sprite.frame], pasos_db + (pasos_agachado_db if agachado else 0.0), 0.0, true)
		pisada.emit(_sprite.animation, _sprite.frame)

## Cinematica de entrada. Coloca al personaje caida_altura px por encima de
## donde esta (la marca de suelo de la escena) y lo deja caer con aceleracion
## hasta volver ahi. El resto lo encadena _al_terminar:
##   cayendo (bucle, mientras baja) -> caida (impacto) -> tumbado (espera) ->
##   levantarse -> reposo, y ahi se emite cinematica_terminada.
## El fotograma 7 de cayendo (el 32 del video) es el que enlaza con caida sin
## salto, asi que el bucle se arranca por el fotograma que, tras caida_duracion
## a sus fps, deja el impacto justo ahi. Si la duracion se cambia en el editor
## sigue cuadrando: se calcula, no esta cocido. Truncando, no redondeando: en
## caida_duracion pasan duracion * fps fotogramas con decimales (33,6) y el
## impacto llega en el ultimo entero; con round() caia en el 6.
func caer_desde_arriba() -> void:
	# En la cinematica _physics_process no llega a _actualizar_saltos: lo que
	# hubiera dejado un salto (el ritmo del aire, un arco) se quedaria puesto en
	# las animaciones de la caida.
	_sprite.speed_scale = 1.0
	_sprite.position.y = 0.0
	var suelo := position.y
	position.y = suelo - caida_altura
	_mirar(1.0)
	_cambiar(Estado.CAYENDO)
	var n := _sprite.sprite_frames.get_frame_count("cayendo")
	var fps := _sprite.sprite_frames.get_animation_speed("cayendo")
	_sprite.frame = posmod(7 - int(caida_duracion * fps), n)
	var tw := create_tween()
	tw.tween_property(self, "position:y", suelo, caida_duracion) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.finished.connect(func() -> void:
		if _estado == Estado.CAYENDO:
			_cambiar(Estado.CAIDA)
			# play() no emite frame_changed si el indice no cambia: el apoyo
			# del primer sprite se pone aqui.
			_apoyar_caida())
	# El aire esta recortado para acabar en el golpe. Si la caida dura mas que
	# el archivo, se espera; si dura menos, se entra por el medio.
	var aire: AudioStream = SONIDOS_CAIDA["aire"]
	var sobra := caida_duracion - aire.get_length()
	if sobra <= 0.0:
		_sonar(aire, cinematica_db, -sobra)
	else:
		get_tree().create_timer(sobra).timeout.connect(func() -> void:
			if _estado == Estado.CAYENDO:
				_sonar(aire, cinematica_db))

## Andar y correr los mueve _physics_process con la distancia recorrida, asi que
## el nodo NO debe reproducirlos: se le pone la animacion y se le para.
##
## Si se le deja reproduciendo, hay dos cosas moviendo el fotograma a la vez. El
## nodo avanza por su reloj en _process -- medio fotograma por tick de fisica a
## 30 fps y 60 Hz, mas si la pantalla va mas rapida -- y el siguiente tick lo
## devuelve al que toca por distancia. El sprite salta adelante y atras entre dos
## poses, y como los poligonos de la tunica cambian de un fotograma al siguiente,
## se ve como si al personaje le cambiase la ropa mientras corre.
##
## El resto de animaciones si van a fps fijo y las reproduce el nodo.
const MANUALES := ["andar", "correr", "andar_agachado"]

## Pies en el suelo desde que llega el nodo. En los cinco primeros sprites de
## "caida" (c_01..c_05) el personaje del video aun no habia tocado: su punto mas
## bajo queda a 25, 20, 22, 23 y 10 px por encima de la linea de suelo de la
## casilla (fila 337). El nodo llega al suelo a ~28 px por tick y se quedaba
## flotando ahi 0,17 s antes de caer: la caida se leia ligera. Bajando el
## sprite esos px, llega y apoya a la vez; del sexto en adelante ya apoya solo.
const CAIDA_APOYO := [25.0, 20.0, 22.0, 23.0, 10.0]

## Solo durante CAIDA; _physics_process no toca el sprite en la cinematica.
func _apoyar_caida() -> void:
	var f := _sprite.frame
	_sprite.position.y = CAIDA_APOYO[f] if f < CAIDA_APOYO.size() else 0.0

## Velocidad del nodo en cada fotograma del arranque de andar, en px/s de hoja.
## Sale del avance real del pie plantado respecto al eje del tronco, medido sobre
## 04_limpios (master px por fotograma: 0, 0.7, 2.2, 2.6, 4.6, 6.3, 7.1, 8.2, 8.3,
## 9.9, 10.3, 12.1, 11.3, 11.0, 11.7, 11.7, 13.5, 12.6, 12.6), a media escala y
## a los 30 fps a los que va la animacion: v = master/2 * 30. El ultimo da 189,
## contra los 192 del ciclo. Con la recta antigua el nodo hacia 256 px master en
## el arranque y los pies 292, y ademas mal repartidos.
const AVANCE_ARRANQUE_ANDAR := [0.0, 10.5, 33.0, 39.0, 69.0, 94.5, 106.5, 123.0, 124.5, 148.5, 154.5, 181.5, 169.5, 165.0, 175.5, 175.5, 189.0, 189.0, 189.0]
## Ultimo fotograma del arranque de andar en que soltar vuelve a reposo en vez
## de pasar por la parada. Solo el 0 tiene velocidad 0, pero hasta el 3 el nodo
## ha avanzado ~2,7 px y los pies siguen casi juntos: la parada, que empieza a
## media zancada, ahi es un fotograma que no encaja con nada.
const ARRANQUE_ANDAR_DE_PIE := 3

## Velocidad del nodo en cada fotograma del arranque de correr, y aqui el error
## (con la rampa recta) era mayor y al reves. Midiendo el pie
## plantado: 6 fotogramas quieto, el 6 avanza 5,4 px master, el 7 dieciseis, y del
## 8 en adelante YA VA A CRUCERO (32, 31, 26, 25, 29, 33...). La rampa recta daba
## 5,7 en el fotograma 8: las piernas corriendo a tope con el cuerpo al 20 %, o
## sea el pie resbalando hacia atras todo el arranque. En px/s de hoja.
const AVANCE_ARRANQUE_CORRER := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 81.0, 240.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0, 435.0]
## Por que fotograma entra el arranque de correr con un doble toque desde
## reposo. Medido contra el reposo f0 (silueta y color, en pasos normales del
## ciclo de andar): f0 0,84, f1 0,64, f2 0,66, f3 0,67, f4 0,83, f5 0,99. El 3
## sigue quieto (velocidad 0 hasta el 5) y ahorra 0,1 s de fotogramas quietos.
const ARRANQUE_CORRER_DESDE_REPOSO := 3

## Por que fotograma del arranque de correr entrar segun la pose que se traiga.
## Cuando se pide correr ya andando -- o con la segunda pulsacion de un doble,
## que llega con el arranque de andar ya en marcha -- entrar por el fotograma
## que da la velocidad que se lleva (el 14) deja la pose a 2,2-2,8 pasos de
## cualquier fotograma de andar: mas que el rebote del brazo que se quito. Estas
## tablas (esta y POSE_DESDE_ANDAR, mas abajo) dan, para cada fotograma de origen, el fotograma del arranque de
## correr que MAS SE PARECE (silueta y color, medido): media 1,05 y 1,34 pasos.
## La velocidad no se pierde por entrar antes: _velocidad_suelo la sostiene
## hasta que la rampa la alcanza.
const POSE_DESDE_ARRANQUE_ANDAR := [0, 0, 0, 0, 0, 3, 4, 4, 4, 4, 4, 6, 6, 6, 6, 8, 8, 8, 8, 8, 8, 7, 6, 6, 6, 6, 5, 5, 5, 5, 5, 7, 7, 5]

## PARAR DE ANDAR. La parada esta grabada desde UNA sola fase de la zancada: sus
## fotogramas casan con el ciclo alrededor de f26-f29 (y f3), a >= 1,1 pasos, y la
## otra mitad del ciclo no tiene equivalente. Entrando siempre por su fotograma 0
## el salto de pose iba de 1,1 a 3,8 pasos segun donde soltaras (media 2,4): el
## "efecto raro al pararse". Lo que hacen los juegos con una sola parada es dejar
## que el personaje TERMINE EL PASO hasta un apoyo que case: aqui, como mucho
## `espera_parada_andar` fotogramas del ciclo como tope (34 = el ciclo entero, o
## sea esperar siempre); la espera real la marca tolerancia_parada_andar: se
## espera a un fotograma con DIST_PARADA_ANDAR por debajo, hasta 20 fotogramas.
## POSE_ANDAR_A_PARADA dice por que fotograma de la parada entrar desde cada
## fotograma del ciclo.
## Distancia de pose, en pasos normales, al entrar en la parada desde cada
## fotograma del ciclo. Medido sobre los sprites (silueta y color).
const DIST_PARADA_ANDAR := [1.7, 1.5, 1.3, 1.3, 1.7, 1.8, 1.8, 2.0, 2.1, 2.4, 2.5, 2.4, 2.4, 2.2, 2.3, 2.4, 2.7, 3.3, 3.2, 2.9, 2.8, 2.3, 2.2, 1.7, 1.3, 1.1, 1.1, 1.2, 1.1, 1.1, 1.2, 1.4, 1.6, 1.8]
const DIST_PARADA_CORRER := [1.7, 1.7, 1.7, 1.5, 1.5, 1.4, 1.4, 1.6, 1.6, 1.7, 1.6, 1.8, 2.1, 2.1, 2.1, 2.1, 1.9, 1.9, 2.0, 1.9, 1.5, 1.3, 1.2, 1.6]
const POSE_ANDAR_A_PARADA := [5, 5, 4, 6, 1, 6, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 3, 3, 4, 4, 4, 5, 5]
## Y el nodo no frena en seco: el pie plantado de la parada sigue avanzando 3-6 px
## master por fotograma durante 14 fotogramas antes de plantarse del todo. Este es
## el perfil medido, como fraccion de la velocidad de andar en cada fotograma de la
## parada; la velocidad que se traia se escala para empezar exacta en el fotograma
## de entrada.
const FRENADA_ANDAR_PERFIL := [1.0, 0.95, 0.85, 0.75, 0.65, 0.55, 0.48, 0.42, 0.40, 0.40, 0.42, 0.40, 0.36, 0.32, 0.27, 0.20, 0.14, 0.10, 0.08, 0.05, 0.0]

const POSE_DESDE_ANDAR := [5, 5, 6, 5, 6, 4, 6, 6, 6, 6, 4, 6, 4, 8, 8, 8, 8, 8, 7, 8, 7, 6, 6, 6, 6, 7, 4, 4, 5, 5, 6, 6, 5, 5]

## Por que fotograma del arranque de andar seguir cuando el salto (saltar) se
## corta con la tecla pulsada. El indice 0 es el sprite 60 del salto (indice
## SALTO_CORTE_DESDE, el primero en que salto_interrumpible deja cortar); tiene
## que ir a la par con ese export. Medido por silueta y color contra los 34 del
## arranque: del sprite 60 al 64 aun esta medio agachado y lo mas parecido es
## un paso ya lanzado (f20-24, 0,043-0,048); del 65 al 70 esta de pie y lo mas
## parecido es el arranque recien empezado (f4-5, 0,025-0,035).
## Las tablas del andar, como variables: el baston en la mano (scripts/dev/baston)
## pone las suyas, medidas sobre su video, y al guardarlo devuelve estas.
var avance_arranque_andar: Array = AVANCE_ARRANQUE_ANDAR
var arranque_andar_de_pie: int = ARRANQUE_ANDAR_DE_PIE
var dist_parada_andar: Array = DIST_PARADA_ANDAR
var pose_andar_a_parada: Array = POSE_ANDAR_A_PARADA
var frenada_andar_perfil: Array = FRENADA_ANDAR_PERFIL
var pisadas: Dictionary = PISADAS
var golpes_anim: Dictionary = GOLPES
## Andar con un paso que no es parejo (el baston: un paso corto y otro largo).
## Px de hoja que avanza el pie plantado de cada fotograma del ciclo al
## siguiente, medidos; vacio = avance_andar en todos. Con tabla, el nodo va en
## cada fotograma a avance * ritmo_ciclo_andar px/s y el fotograma sale de la
## distancia acumulada, asi que cada uno sigue durando 2 ticks justos a 30 y
## los pies no patinan aunque la velocidad cambie de un paso al otro.
var avance_ciclo_andar: Array = []:
	set(v):
		avance_ciclo_andar = v
		_acum_andar = [0.0]
		for a in v:
			_acum_andar.append(_acum_andar[-1] + float(a))
var ritmo_ciclo_andar := 30.0
var _acum_andar: Array = [0.0]
## Velocidad del nodo (px/s) en cada fotograma de la parada de andar, medida;
## vacio = frenada_andar_perfil escalada a la que traia.
var velocidad_parada_andar: Array = []

## Distancia del ciclo de andar en la que empieza el fotograma k.
func _recorrido_andar(k: int) -> float:
	if avance_ciclo_andar.is_empty():
		return float(k) * avance_andar
	return _acum_andar[clampi(k, 0, _acum_andar.size() - 1)]

## Fotograma del ciclo de andar (con tabla) para una distancia recorrida.
func _fotograma_andar(recorrido: float) -> int:
	var total: float = _acum_andar[-1]
	var r := fposmod(recorrido + 1e-4, total)
	return clampi(_acum_andar.bsearch(r, false) - 1, 0, avance_ciclo_andar.size() - 1)

const SALTO_CORTE_DESDE := 59
const POSE_DESDE_SALTO := [21, 20, 21, 23, 24, 5, 5, 5, 5, 4, 4]

func _poner(nombre: String) -> void:
	_recorrido = 0.0
	_ultimo_fotograma = -1
	_velocidad_suelo = 0.0
	_parada_entrada = 0
	if nombre in MANUALES:
		var entrada := entrada_andar
		var avance := avance_andar
		if nombre == "correr":
			entrada = entrada_correr
			avance = avance_correr
		elif nombre == "andar_agachado":
			entrada = ENTRADA_AGACHADO
			avance = avance_agachado
		# El recorrido arranca ya colocado en esa entrada, no a cero: es lo que
		# mantiene la cuenta de distancia y el fotograma diciendo lo mismo.
		_recorrido = float(entrada) * avance
		if nombre == "andar":
			_recorrido = _recorrido_andar(entrada)
		_sprite.animation = nombre
		_sprite.stop()
		_sprite.frame = entrada
		# Y la pisada se da por vista, o al entrar sonarian de golpe todos los
		# contactos entre el fotograma 0 y la entrada.
		_ultimo_fotograma = entrada
	else:
		_sprite.play(nombre)
	_sprite.offset = offset_salto_correr if nombre == "salto_correr" else offset_comun
	# Agachandose la respiracion ni se arranca ni se corta: sigue la que hubiera
	# (tras correr, jadea tambien agachado) y _actualizar_esfuerzo la va apagando.
	if not nombre in ["agacharse", "agachado", "incorporarse", "arranque_agachado", "andar_agachado", "parada_agachado",
			"giro_agachado", "paso_agachado"]:
		_respirar(nombre == "reposo")

## Suena la pisada si entre el ultimo fotograma puesto y este se ha pasado por un
## sprite de contacto. Se mira el tramo entero, no solo el fotograma actual, por
## si un tick de fisica salta mas de un sprite, que pasa en cuanto se corre
## rapido: a 435 px/s y 14,5 px por fotograma toca cambiar 30 veces por
## segundo, y basta una bajada de framerate para saltarse un contacto.
func _pisar(fotograma: int, n: int) -> void:
	if fotograma == _ultimo_fotograma:
		return
	var golpes: Dictionary = pisadas.get(String(_sprite.animation), {})
	var avanzados := (fotograma - _ultimo_fotograma + n) % n
	for k in range(1, avanzados + 1):
		var i := (_ultimo_fotograma + k) % n
		if golpes.has(i):
			_pasos.stream = golpes[i]
			_pasos.volume_db = pasos_db + (pasos_agachado_db if _sprite.animation == &"andar_agachado" else 0.0)
			_pasos.pitch_scale = randf_range(1.0 - pasos_variacion, 1.0 + pasos_variacion)
			_pasos.play()
			pisada.emit(_sprite.animation, i)
	_ultimo_fotograma = fotograma

## Sube y baja la cuenta de esfuerzo y, en reposo, lleva el volumen de la
## respiracion a donde le toca. El nivel que pide el esfuerzo no va con tween
## sino acercandose cada tick (30 dB/s): asi no hay dos cosas moviendolo y el
## fundido de entrada sale solo. La variacion de cada ciclo se le suma aparte y
## de golpe, en la costura del bucle, que es el valle entre dos respiraciones y
## ahi no se oye. Antes iba todo junto por el mismo move_toward, y un ciclo
## saltado (-80 dB) se llevaba tambien la mitad del siguiente mientras el
## volumen volvia a subir. Cuando el esfuerzo llega a cero, se apaga con el
## fundido de siempre.
func _actualizar_esfuerzo(delta: float) -> void:
	match _estado:
		Estado.CORRER, Estado.ARRANQUE_CORRER:
			_esfuerzo = minf(_esfuerzo + delta / maxf(esfuerzo_correr, 0.1), 1.0)
		Estado.ANDAR, Estado.ARRANQUE_ANDAR, Estado.ARRANQUE_AGACHADO, Estado.ANDAR_AGACHADO, Estado.PASO_AGACHADO:
			_esfuerzo = minf(_esfuerzo + delta / maxf(esfuerzo_andar, 0.1), 1.0)
		Estado.REPOSO, Estado.AGACHANDO, Estado.AGACHADO, Estado.INCORPORANDO, Estado.PARADA_AGACHADO, Estado.GIRO_AGACHADO:
			_esfuerzo = maxf(_esfuerzo - delta / maxf(respiracion_recuperacion, 0.1), 0.0)
	if not (_estado == Estado.REPOSO or _en_agachado()) or not _respiracion.playing \
			or (_fundido and _fundido.is_running()):
		return
	if _esfuerzo <= 0.0:
		_respirar(false)
		return
	# Cada vuelta del bucle, una variacion nueva; a veces, un ciclo en silencio.
	var pos := _respiracion.get_playback_position()
	if pos < _resp_pos - 1.0:
		_resp_ciclo_db = -80.0 if randf() < respiracion_saltar_ciclo else randf_range(-respiracion_variacion_db, respiracion_variacion_db)
	_resp_pos = pos
	var objetivo := lerpf(respiracion_tranquilo_db, respiracion_db, _esfuerzo)
	_resp_base_db = move_toward(_resp_base_db, objetivo, 30.0 * delta)
	_respiracion.volume_db = -80.0 if _resp_ciclo_db <= -80.0 else _resp_base_db + _resp_ciclo_db

## Arranca la respiracion al entrar en reposo -- solo si hay esfuerzo que
## recuperar -- o la apaga con un fundido corto al salir: cortarla en seco al
## empezar a andar da un chasquido.
func _respirar(activa: bool) -> void:
	if _fundido:
		_fundido.kill()
		_fundido = null
	if activa:
		if _esfuerzo <= 0.0:
			return
		# Empieza 6 dB por debajo de su sitio y _actualizar_esfuerzo la sube.
		# Siempre desde el principio del bucle (el valle entre dos respiraciones),
		# a la par que el fotograma 0 del pecho, que es por donde entra el reposo.
		# Tambien si vuelve al reposo con el fundido de salida a medias (un toque
		# corto, un giro en el sitio): seguir el audio por donde iba dejaba el
		# pecho y el sonido desfasados media respiracion hasta el siguiente paseo.
		# play() sobre un reproductor que ya suena apaga lo anterior con una
		# rampa corta, sin chasquido.
		_resp_base_db = lerpf(respiracion_tranquilo_db, respiracion_db, _esfuerzo) - 6.0
		_respiracion.volume_db = _resp_base_db
		_resp_ciclo_db = 0.0
		_resp_pos = 0.0
		_respiracion.play(0.0)
		return
	# Apagar lo que ya esta apagado no es nada: sin esto se creaba un tween
	# vacio y Godot lo avisaba como error en cada cambio de animacion de la
	# cinematica de entrada, que encadena varias sin pasar por el reposo.
	if not _respiracion.playing:
		return
	_fundido = create_tween()
	_fundido.tween_property(_respiracion, "volume_db", -40.0, 0.25)
	_fundido.tween_callback(_respiracion.stop)

## Reposo con la respiracion callada: a veces se sostiene el valle entre dos
## respiraciones (la costura del bucle) un rato al azar, para que no se lea el
## bucle. Con la respiracion sonando no: el pecho tiene que ir con el audio.
## animation_looped y no frame_changed al fotograma 0, porque ese tambien salta
## al entrar en reposo desde otra animacion, y ahi no toca pararse.
func _al_dar_vuelta() -> void:
	if _estado != Estado.REPOSO or _sprite.animation != &"reposo" or _respiracion.playing \
			or randf() >= reposo_pausa_prob:
		return
	_sprite.pause()
	get_tree().create_timer(randf_range(reposo_pausa_min, reposo_pausa_max), false).timeout.connect(func() -> void:
		if _estado == Estado.REPOSO and _sprite.animation == &"reposo" and not _sprite.is_playing():
			_sprite.play())

## Los bucles no emiten esta senal; solo llegan aqui arranques, paradas y salto.
func _al_terminar() -> void:
	match _estado:
		Estado.ARRANQUE_ANDAR:  _cambiar(Estado.ANDAR)
		Estado.ARRANQUE_CORRER: _cambiar(Estado.CORRER)
		Estado.PARADA_ANDAR, Estado.PARADA_CORRER, Estado.ATERRIZAJE_CORRER:
			_cambiar(Estado.REPOSO)
		Estado.AGACHANDO:
			# Hacia delante acaba abajo y asentado, en el c_090: el bucle sigue por
			# el c_089; hacia atras, deshecho, de pie.
			if _agachar_atras:
				_cambiar(Estado.REPOSO)
			else:
				_cambiar(Estado.AGACHADO)
				_sprite.frame = AGACHADO_ANTES_DE_SUBIR
		Estado.ARRANQUE_AGACHADO:
			# El arranque acaba ya lanzado: el cuerpo va casi a la velocidad del
			# ciclo, que sigue desde ahi.
			_cambiar(Estado.ANDAR_AGACHADO)
		Estado.PASO_AGACHADO:
			# Acaba en el agachado del bucle (el mismo sprite), un paso mas alla.
			position.x = _x_tabla + _mirando * AVANCE_PASO_AGACHADO[AVANCE_PASO_AGACHADO.size() - 1]
			_cambiar(Estado.AGACHADO)
			_sprite.frame = AGACHADO_ANTES_DE_SUBIR
		Estado.PARADA_AGACHADO:
			position.x = _x_tabla + _mirando * AVANCE_PARADA_AGACHADO[AVANCE_PARADA_AGACHADO.size() - 1]
			_cambiar(Estado.AGACHADO)
			_sprite.frame = PARADA_AGACHADO_A_AGACHADO
		Estado.GIRO_AGACHADO:
			# El ultimo del giro es el agachado espejado: volteado, el bucle sigue
			# por ese mismo dibujo. Si se mantiene la direccion, AGACHADO arranca
			# a andar hacia el lado nuevo; sin la tecla abajo, se levanta.
			_mirar(_giro_destino)
			_cambiar(Estado.AGACHADO)
			_sprite.frame = AGACHADO_ANTES_DE_SUBIR
		Estado.INCORPORANDO:
			if _agachar_atras:
				# Deshecho hasta el principio: vuelta al bucle por el fotograma
				# que va justo antes del primero de levantarse.
				_cambiar(Estado.AGACHADO)
				_sprite.frame = AGACHADO_ANTES_DE_SUBIR
			else:
				_cambiar(Estado.REPOSO)
		Estado.SALTAR:
			# El salto corriendo acaba en la zancada de la toma de suelo, no de
			# pie: si se llega aqui es que se solto la direccion, y lo que sigue
			# es incorporarse. El de parado ya acaba de pie.
			if _sprite.animation == "salto_correr":
				_cambiar(Estado.ATERRIZAJE_CORRER)
			else:
				_cambiar(Estado.REPOSO)
		Estado.CAIDA:
			# Tumbado es un solo fotograma en bucle: no avisa de nada. La espera
			# la pone un temporizador, y se comprueba el estado al volver por si
			# algo lo hubiera sacado de ahi mientras tanto.
			_sprite.position.y = 0.0  # por si acaso: CAIDA_APOYO ya acaba en 0
			_cambiar(Estado.TUMBADO)
			get_tree().create_timer(tumbado_espera).timeout.connect(func() -> void:
				if _estado == Estado.TUMBADO:
					_cambiar(Estado.LEVANTARSE))
		Estado.LEVANTARSE:
			# Acaba de estamparse y de levantarse: llega al reposo sin aliento.
			_esfuerzo = 1.0
			_cambiar(Estado.REPOSO)
			cinematica_terminada.emit()
		Estado.GIRO:
			# Ahora si: el ultimo fotograma del giro es el perfil del otro lado,
			# que es exactamente el sprite de siempre volteado, asi que voltear
			# aqui no se nota.
			_mirar(_giro_destino)
			# Salto pedido durante el giro (guardado en _physics_process): sale
			# ahora, ya mirando al lado nuevo. Parado, asi que salto de parado;
			# si sigue con la tecla pulsada, al caer sale andando hacia alli.
			if _salto_en_espera():
				_saltar()
				return
			var sigue := 0.0 if _quiere_agacharse() else _eje()
			if is_zero_approx(sigue) or signf(sigue) != _mirando:
				_cambiar(Estado.REPOSO)
			else:
				_cambiar(Estado.ARRANQUE_CORRER if _giro_corriendo else Estado.ARRANQUE_ANDAR)
