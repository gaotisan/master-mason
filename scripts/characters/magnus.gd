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
## La animacion son 5 fotogramas a 20 fps (0,25 s): perfil, 45, 90 (frontal),
## 135 y el perfil del otro lado. Salen de una hoja de rotacion dibujada aparte,
## no de un video. El volteo del sprite se hace al TERMINAR, no al empezar: durante el
## giro se conserva el flip_h que hubiera, y por eso la misma animacion sirve
## para los dos sentidos -- volteada se lee de izquierda a derecha.
##
## A false vuelve al flip_h instantaneo de antes.
@export var giro_activo: bool = true
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
## SALTO CARGADO desde parado: con la tecla mantenida, salto_parado se queda
## quieto en la cuclilla (carga_fotograma: la cabeza mas baja, medida sobre la
## hoja; el despegue suena en el 18) mientras carga, y al soltar (o al
## llenarse) sigue el salto con un arco anadido proporcional a la carga: 0 ->
## nada, llena -> salto_cargado_altura px, con la animacion del aire frenada
## hasta salto_cargado_vuelo para que tanta altura no suba de golpe. El arco
## anadido sigue la curva de los pies dibujados (PIES_SALTO_PARADO) escalada,
## asi que despega y apoya justo cuando despegan y apoyan los pies del sprite,
## sin tiron. La carga cuenta con el reloj de fisica desde el momento en que el
## salto llega a la cuclilla (carga_fotograma a los fps de la animacion), no
## desde que el sprite lo vio: asi no depende de los fps de pantalla. Los
## primeros carga_umbral segundos no cuentan: una pulsacion algo larga es el
## salto de siempre. Llena a carga_umbral + carga_max. Un toque que se suelta
## antes de llegar a la cuclilla (0,27 s) es el salto de siempre, sin pausa.
## Cargando no se gira ni se arranca: es parte del salto. A false, el salto de
## parado de siempre.
@export var salto_cargado_activo: bool = true
@export var carga_max: float = 0.6
@export var carga_umbral: float = 0.05
@export var carga_fotograma: int = 16
@export var salto_cargado_altura: float = 120.0
@export var salto_cargado_vuelo: float = 0.75
## Despegue y toma de suelo del salto de parado (pie mas bajo sobre la hoja:
## sube desde el 18 y apoya en el 45). Entre los dos va el arco de la carga.
@export var salto_parado_despegue: int = 18
@export var salto_parado_toca: int = 45
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

## Se emite cuando la cinematica de entrada deja al personaje en reposo y con
## el control devuelto.
signal cinematica_terminada
## Se emite en el sprite en que el cuerpo da contra el suelo en la caida de
## entrada (el mismo del golpe de sonido): el nivel levanta ahi la hojarasca.
signal impacto
## Se emite cuando andar_hasta() ha llevado al personaje a su sitio y ya esta
## en reposo.
signal llegado

## CONTROL DESDE FUERA. Los niveles y los dialogos necesitan quitarle las teclas
## al jugador sin romper la maquina de estados: con control_bloqueado las
## pulsaciones se ignoran y el eje deja de venir del teclado. Si el personaje
## iba andando, se para como si hubiera soltado la tecla (termina el paso y
## frena); no hay ningun corte en seco.
var control_bloqueado := false
## Deja andar pero no saltar: junto a una puerta, arriba es "empujar".
var salto_bloqueado := false
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
}

enum Estado { REPOSO, ARRANQUE_ANDAR, ANDAR, PARADA_ANDAR,
			  ARRANQUE_CORRER, CORRER, PARADA_CORRER, SALTAR, GIRO,
			  CAYENDO, CAIDA, TUMBADO, LEVANTARSE, ATERRIZAJE_CORRER }

## Estados de la cinematica de entrada: sin control del jugador.
const CINEMATICA := [Estado.CAYENDO, Estado.CAIDA, Estado.TUMBADO, Estado.LEVANTARSE]

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
var _carga := 0.0            # 0..1, carga del salto de parado en curso
var _cargando := false       # quieto en la cuclilla, cargando
var _carga_hecha := false    # ya paso por la cuclilla en este salto (no vuelve a cargar)
var _salto_desde := 0.0      # instante (de _reloj) en que empezo el salto en curso

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _pasos: AudioStreamPlayer = $Pasos
@onready var _respiracion: AudioStreamPlayer = $Respiracion

func _ready() -> void:
	_sprite.animation_finished.connect(_al_terminar)
	_sprite.frame_changed.connect(_al_cambiar_fotograma)
	_sprite.animation_looped.connect(_al_dar_vuelta)
	_poner("reposo")

func _unhandled_input(evento: InputEvent) -> void:
	if _en_cinematica() or control_bloqueado:
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
				_giro_corriendo = true
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
	_actualizar_carga()
	_apagar_sobrante(delta)
	var direccion := _eje()
	_actualizar_carrerilla(delta, direccion)
	_avisar_llegada()

	# Girando no se acepta nada: son 0,25 s, y cortarlo a medias deja al
	# personaje mirando a un sitio con el sprite de otro. Un salto pedido
	# mientras tanto se guarda vivo y sale al terminar el giro (_al_terminar).
	if _estado == Estado.GIRO:
		if _salto_en_espera():
			_salto_pedido = _reloj
		return

	# Soltar la tecla lanza la frenada. Tambien durante el arranque: si no, un
	# toque corto dejaria al personaje 1,4 s andando solo antes de hacer caso.
	if is_zero_approx(direccion):
		_giro_pendiente = 0.0   # soltar cancela el cambio de sentido
		var arrancando := _estado == Estado.ARRANQUE_ANDAR or _estado == Estado.ARRANQUE_CORRER
		if arrancando and (_velocidad() <= 0.0 \
				or (_estado == Estado.ARRANQUE_ANDAR and _sprite.frame <= ARRANQUE_ANDAR_DE_PIE)):
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
			_cambiar(Estado.PARADA_ANDAR)
		elif _estado == Estado.CORRER:
			_pedir_parada_correr()
		elif _estado == Estado.ARRANQUE_CORRER:
			_cambiar(Estado.PARADA_CORRER)
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
				var entrada: int = POSE_ANDAR_A_PARADA[clampi(_sprite.frame, 0, POSE_ANDAR_A_PARADA.size() - 1)]
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
			_sprite.frame = fotograma
			_pisar(fotograma, n)

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
			return velocidad_andar
		Estado.CORRER:
			return velocidad_correr + _sobrante
		Estado.ARRANQUE_ANDAR:
			if corte_arranque_andar > 0:
				var k := clampi(_sprite.frame, 0, AVANCE_ARRANQUE_ANDAR.size() - 1)
				return maxf(AVANCE_ARRANQUE_ANDAR[k], _velocidad_suelo)
			return maxf(velocidad_andar * _rampa_subida(quieto_al_arrancar_andar), _velocidad_suelo)
		Estado.ARRANQUE_CORRER:
			if corte_arranque_correr > 0:
				var kc := clampi(_sprite.frame, 0, AVANCE_ARRANQUE_CORRER.size() - 1)
				return maxf(AVANCE_ARRANQUE_CORRER[kc], _velocidad_suelo)
			return maxf(velocidad_correr * _rampa_subida(quieto_al_arrancar_correr), _velocidad_suelo)
		Estado.PARADA_ANDAR:
			var k := clampi(_sprite.frame, 0, FRENADA_ANDAR_PERFIL.size() - 1)
			var base: float = FRENADA_ANDAR_PERFIL[clampi(_parada_entrada, 0, FRENADA_ANDAR_PERFIL.size() - 1)]
			return _frenando_desde * FRENADA_ANDAR_PERFIL[k] / maxf(base, 0.05)
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
	var casa: bool = DIST_PARADA_ANDAR[clampi(f, 0, DIST_PARADA_ANDAR.size() - 1)] <= tolerancia_parada_andar
	if casa or _parada_espera >= espera_parada_andar * 2 or espera_parada_andar <= 0:
		_parada_espera = 0
		var entrada: int = POSE_ANDAR_A_PARADA[clampi(f, 0, POSE_ANDAR_A_PARADA.size() - 1)]
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
				_recorrido = float(k) * avance_andar
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
		for k in range(AVANCE_ARRANQUE_ANDAR.size()):
			if AVANCE_ARRANQUE_ANDAR[k] >= llevaba:
				_sprite.frame = k
				return
		_sprite.frame = AVANCE_ARRANQUE_ANDAR.size() - 1
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
func _fuera_de_limite(hacia: float) -> bool:
	var m := frenada_limite_correr if _corriendo() else frenada_limite_andar
	return (hacia < 0.0 and position.x <= limite_izquierdo + m) or (hacia > 0.0 and position.x >= limite_derecho - m)

## Un salto hacia un limite no puede llevarle mas alla: se recorta el impulso
## para que el recorrido del salto (vuelo y toma de suelo, ver
## RECORRIDO_SALTO_*) quepa en lo que queda hasta el limite.
func _impulso_hasta_limite(impulso: float, a_la_carrera: bool) -> float:
	var limite := limite_derecho if _mirando > 0.0 else limite_izquierdo
	if is_inf(limite) or impulso <= 0.0:
		return impulso
	var queda := maxf((limite - position.x) * _mirando, 0.0)
	if a_la_carrera:
		return minf(impulso, maxf(queda - RESBALE_SALTO_CORRER, 0.0) / _recorrido_salto_correr())
	return minf(impulso, queda / RECORRIDO_SALTO)

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
			or _arrancando_a_correr_quieto():
		return false
	return _estado != Estado.SALTAR or not _salto_bloquea()

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
	var de_pie := _estado == Estado.ARRANQUE_ANDAR and _sprite.frame <= ARRANQUE_ANDAR_DE_PIE
	if de_pie:
		_impulso = 0.0
	_saltaba_parado = not _corria_al_saltar and _impulso <= 0.0 \
		and (not _en_movimiento() or _estado == Estado.ARRANQUE_CORRER or de_pie)
	# Lo que pone el nodo al salto corriendo, segun la carrerilla que lleve (a 0,
	# los valores de siempre, exactos). Antes del recorte junto al limite, que
	# depende de ellos. Y el estado de la altura variable y de la carga, de cero.
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
	_carga = 0.0
	_cargando = false
	_carga_hecha = false
	_salto_desde = _reloj
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
	return aterrizaje

func _interrumpible() -> float:
	match String(_sprite.animation):
		"salto_correr": return salto_correr_interrumpible
		"salto_parado": return salto_parado_interrumpible
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
	# La frenada tiene que partir de la velocidad que llevaba de verdad, no de
	# la de crucero. Si no, un toque corto -- en el que apenas ha acelerado --
	# entra a frenar a toda velocidad y el personaje pega un tiron hacia
	# delante en vez de quedarse casi donde estaba.
	if nuevo == Estado.PARADA_ANDAR or nuevo == Estado.PARADA_CORRER:
		_frenando_desde = _velocidad()
	if nuevo != Estado.CORRER:
		_sobrante = 0.0
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

func _en_cinematica() -> bool:
	return _estado in CINEMATICA

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

## Arco y ritmo de los saltos. El sprite trae el salto cocido; el arco del nodo
## se le suma durante el vuelo, atado al fotograma (con la fraccion de
## fotograma, para que no vaya a escalones) y no al reloj, asi que sigue
## cuadrando aunque cambie el ritmo. Fuera del vuelo lo deja todo a cero: se
## llama cada tick.
##   salto corriendo: parabola de _arco_amp (la carrerilla y la altura
##                    variable) a _ritmo_vuelo(_arco_amp)
##   salto de parado: quieto en la cuclilla mientras carga, y luego la curva de
##                    los pies dibujados escalada a salto_cargado_altura * carga
func _actualizar_saltos() -> void:
	var f := _sprite.frame
	var en_salto := _estado == Estado.SALTAR
	var velocidad := 1.0
	var arco := 0.0
	if en_salto and _sprite.animation == &"salto_correr" \
			and f >= salto_correr_despegue and f < salto_correr_toca:
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
	elif en_salto and _sprite.animation == &"salto_parado":
		if _cargando:
			velocidad = 0.0
		elif _carga > 0.0 and f >= salto_parado_despegue and f < salto_parado_toca:
			velocidad = lerpf(1.0, maxf(salto_cargado_vuelo, VUELO_MIN), _carga)
			arco = salto_cargado_altura * _carga * _pies_salto_parado()
	_sprite.speed_scale = velocidad
	_sprite.position.y = -arco

## Altura de los pies dibujados en salto_parado ahora, de 0 a 1 (1 = apogeo
## cocido, 65 px), interpolada con la fraccion de fotograma. El fotograma que
## se ve es el f con frame_progress llegando a 1 (a ritmo 1 la fisica siempre
## lo lee a 1), asi que se interpola entre el anterior y el: a ritmo 1 da
## exactamente la curva del dibujo.
func _pies_salto_parado() -> float:
	var n := PIES_SALTO_PARADO.size()
	var x := float(_sprite.frame) - 1.0 + _sprite.frame_progress
	var i := clampi(floori(x), 0, n - 1)
	var a: float = PIES_SALTO_PARADO[i]
	var b: float = PIES_SALTO_PARADO[mini(i + 1, n - 1)]
	return lerpf(a, b, clampf(x - float(i), 0.0, 1.0)) / PIES_SALTO_PARADO_APOGEO

## La tecla de salto sigue pulsada (y el jugador tiene el control y puede
## saltar: con salto_bloqueado, arriba es otra cosa y la carga se suelta).
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

## Salto cargado: mientras esta quieto en la cuclilla la carga sube; soltar la
## tecla, llenarla o perder el control lo suelta y el salto sigue por donde iba.
## La pausa la pone _al_cambiar_fotograma al llegar a carga_fotograma. La carga
## sale del reloj de fisica contado desde que el salto llega a la cuclilla (a
## los fps de la animacion desde que empezo), no desde que el sprite lo noto en
## _process: si no, la misma pulsacion daba mas o menos carga segun los fps de
## pantalla (122 a 132 px de altura entre 30 y 144 fps).
func _actualizar_carga() -> void:
	if not _cargando:
		return
	if _estado != Estado.SALTAR or _sprite.animation != &"salto_parado":
		_cargando = false
		return
	var fps := _sprite.sprite_frames.get_animation_speed("salto_parado")
	var cuclilla := _salto_desde + float(carga_fotograma) / maxf(fps, 1.0)
	_carga = clampf((_reloj - cuclilla - carga_umbral) / maxf(carga_max, 0.01), 0.0, 1.0)
	if _carga >= 1.0 or not _salto_mantenido():
		_cargando = false

## Datos para el panel de estudio del movimiento (datos_movimiento.gd). Solo
## lectura.
func datos_movimiento() -> Dictionary:
	return {
		"estado": Estado.keys()[_estado],
		"animacion": String(_sprite.animation),
		"fotograma": _sprite.frame,
		"velocidad": _velocidad(),
		"carrerilla": _carrerilla,
		"carga": _carga if _estado == Estado.SALTAR and _sprite.animation == &"salto_parado" else 0.0,
		"cargando": _cargando,
		"arco": -_sprite.position.y,
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
	# Salto cargado: llega a la cuclilla con la tecla aun pulsada y se queda ahi.
	# Aqui y no en _physics_process para no pasarse: frame_changed sale dentro
	# del paso del sprite que cambia el fotograma. Ese mismo paso aun termina de
	# llenar frame_progress con la velocidad que habia leido antes de la senal,
	# y la vuelta siguiente de su bucle ya lee speed_scale 0 y se para. Se queda
	# en el 16 con el progreso lleno, asi que al soltar el 17 sale en el paso
	# siguiente.
	if salto_cargado_activo and not _carga_hecha and _estado == Estado.SALTAR \
			and _sprite.animation == &"salto_parado" and _sprite.frame == carga_fotograma:
		_carga_hecha = true
		if _salto_mantenido():
			_cargando = true
			_sprite.speed_scale = 0.0
	var golpes: Dictionary = GOLPES.get(String(_sprite.animation), {})
	if golpes.has(_sprite.frame):
		_sonar(golpes[_sprite.frame], pasos_db, 0.0, true)

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
	# hubiera dejado un salto (la pausa de la carga a speed_scale 0, un arco) se
	# quedaria puesto y las animaciones de la caida no avanzarian nunca.
	_cargando = false
	_carga = 0.0
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
const MANUALES := ["andar", "correr"]

## Pies del salto de parado sobre la linea de suelo, en px de hoja por
## fotograma (fila del pixel opaco mas bajo de cada casilla contra la de pie, la
## misma medida que la tabla del panel, scripts/game/datos_movimiento.gd).
## Despegan en el 18, apogeo en el 30-31 y apoyan en el 45. El arco del salto
## cargado es esta curva escalada.
const PIES_SALTO_PARADO := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 3, 6, 11, 17, 23, 29, 37, 45, 52, 58, 62, 65, 65, 64, 63, 61, 58, 55, 50, 45, 38, 31, 23, 15, 7, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
const PIES_SALTO_PARADO_APOGEO := 65.0

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
const SALTO_CORTE_DESDE := 59
const POSE_DESDE_SALTO := [21, 20, 21, 23, 24, 5, 5, 5, 5, 4, 4]

func _poner(nombre: String) -> void:
	_recorrido = 0.0
	_ultimo_fotograma = -1
	_velocidad_suelo = 0.0
	_parada_entrada = 0
	if nombre in MANUALES:
		var andando := nombre == "andar"
		var entrada := entrada_andar if andando else entrada_correr
		# El recorrido arranca ya colocado en esa entrada, no a cero: es lo que
		# mantiene la cuenta de distancia y el fotograma diciendo lo mismo.
		_recorrido = float(entrada) * (avance_andar if andando else avance_correr)
		_sprite.animation = nombre
		_sprite.stop()
		_sprite.frame = entrada
		# Y la pisada se da por vista, o al entrar sonarian de golpe todos los
		# contactos entre el fotograma 0 y la entrada.
		_ultimo_fotograma = entrada
	else:
		_sprite.play(nombre)
	_sprite.offset = offset_salto_correr if nombre == "salto_correr" else offset_comun
	_respirar(nombre == "reposo")

## Suena la pisada si entre el ultimo fotograma puesto y este se ha pasado por un
## sprite de contacto. Se mira el tramo entero, no solo el fotograma actual, por
## si un tick de fisica salta mas de un sprite, que pasa en cuanto se corre
## rapido: a 435 px/s y 14,5 px por fotograma toca cambiar 30 veces por
## segundo, y basta una bajada de framerate para saltarse un contacto.
func _pisar(fotograma: int, n: int) -> void:
	if fotograma == _ultimo_fotograma:
		return
	var golpes: Dictionary = PISADAS.get(String(_sprite.animation), {})
	var avanzados := (fotograma - _ultimo_fotograma + n) % n
	for k in range(1, avanzados + 1):
		var i := (_ultimo_fotograma + k) % n
		if golpes.has(i):
			_pasos.stream = golpes[i]
			_pasos.volume_db = pasos_db
			_pasos.pitch_scale = randf_range(1.0 - pasos_variacion, 1.0 + pasos_variacion)
			_pasos.play()
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
		Estado.ANDAR, Estado.ARRANQUE_ANDAR:
			_esfuerzo = minf(_esfuerzo + delta / maxf(esfuerzo_andar, 0.1), 1.0)
		Estado.REPOSO:
			_esfuerzo = maxf(_esfuerzo - delta / maxf(respiracion_recuperacion, 0.1), 0.0)
	if _estado != Estado.REPOSO or not _respiracion.playing or (_fundido and _fundido.is_running()):
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
			var sigue := _eje()
			if is_zero_approx(sigue) or signf(sigue) != _mirando:
				_cambiar(Estado.REPOSO)
			else:
				_cambiar(Estado.ARRANQUE_CORRER if _giro_corriendo else Estado.ARRANQUE_ANDAR)
