# Sprites de Magnus

Todo lo que hay que tener delante al montar las animaciones del personaje en
Godot. Los numeros no son negociables entre animaciones: si se cambia uno, hay
que rehacer las tres.

## Ya esta montado

| archivo | que es |
|---|---|
| `assets/characters/magnus/*.png` | las 14 hojas, 292x360 por casilla (340x400 el salto corriendo, 380x360 las cuatro de la caida) |
| `resources/characters/magnus_frames.tres` | el `SpriteFrames` con las 14 animaciones |
| `scenes/characters/magnus.tscn` | el personaje |
| `scripts/characters/magnus.gd` | la maquina de estados, y desde ella el sonido |
| `assets/audio/magnus_paso_*.wav` | las pisadas: `a`/`b` al andar, `correr_a`/`correr_b` al correr |
| `assets/audio/magnus_respirar_ciclo.ogg` | la respiracion en bucle del reposo (2,5 s, igual que la animacion) |
| `scenes/game/dark_stage.tscn` | la escena negra, con Magnus instanciado |

**Sonido.** Los videos de `raw\master_mason\anim\_fuentes` traen audio, y va
sincronizado con la imagen: medido, cada golpe de pie cae medio fotograma
despues del sprite en que el pie planta. De ahi salen los efectos, con
`raw\master_mason\audio\magnus\construye.py` (la ficha de que es cada archivo
esta al lado, en `02_salida\ficha.txt`). Las pisadas no van en bucle: andar y
correr avanzan con la distancia, no con el reloj, asi que `magnus.gd` dispara
cada golpe al pasar por el sprite de contacto (andar: 1 y 17; correr: 5 y 17).
Los de correr son los mismos de andar acelerados un 15 % y 3 dB mas fuertes. La
respiracion si es un bucle de 2,5 s recortado del mismo tramo del video que los
30 sprites de `respirando`, con el zumbido de fondo del video restado; entra y
sale con un fundido corto al cambiar de reposo. Niveles en `pasos_db` y
`respiracion_db`, exportados en el nodo.

Controles (definidos en `project.godot`): flechas izquierda/derecha o A/D para
andar, **doble pulsacion** de la misma flecha para correr, flecha arriba o espacio
para saltar. Al soltar, entra la frenada y vuelve a reposo.

**Cambiar de sentido** no voltea en seco: pasa por la frenada, voltea cuando la
velocidad ya es cero y arranca al otro lado. Tarda 0,18 s y frena 44 px. No hay
animacion de giro, asi que es lo mas parecido que se puede montar con lo que hay;
si algun dia aparece una, sustituye a este apaño.

El salto conserva el impulso que llevaba: saltar corriendo avanza en el aire, y al
caer recupera el modo que llevaba (andar o correr) si la tecla sigue pulsada. El
salto de parado/andando (`saltar`) se puede cortar a partir del 85,5 % de la
animacion (sprite 60 de 70, 0,23 s despues de tocar el suelo), y entra en el
arranque de andar por el fotograma que mas se parece a la pose en la que se
corta (`POSE_DESDE_SALTO` en `magnus.gd`); el salto corriendo, a partir del 85 %.

El `.tres` se genera por script, no a mano: son 295 `AtlasTexture`, uno por
fotograma, recortados de las hojas. El generador es
`godot/tools/anim/_spriteframes.py`, y ahi estan tambien los **fps de cada
animacion**, que no tienen por que ser los del video:

```powershell
cd C:\Users\santiago.ochoa\godot\tools\anim
python _spriteframes.py "..\..\projects\master_mason\resources\characters\magnus_frames.tres"
```

Los saltos son el caso claro: los videos vienen a camara lenta (31 fotogramas de
vuelo a 24 fps son 1,3 s). Se reproducen a **60 fps**, con lo que `saltar` dura
**1,17 s** (0,52 de vuelo), y ademas en una pantalla de 60 Hz se ve cada
fotograma exactamente una vez.

Verificado corriendo el juego: el personaje ocupa el **19,4 %** del alto de
pantalla, que es lo que se diseno (20,2 % teorico).

## Donde esta cada cosa

Las hojas y los sprites **no estan en el repo**. Viven fuera, igual que las
fuentes de audio:

```
godot\raw\master_mason\anim\magnus_<accion>\   una carpeta por animacion
    04_limpios\   sprites sueltos a 584x720  <- MASTER, no se importa
    05_salida\    magnus_<accion>_sheet.png  <- esto es lo que se copia aqui
```

Al repo solo sube la hoja de `05_salida`, a `assets/characters/magnus/`.

Los parametros del personaje y el porque de cada numero estan en
`godot\raw\master_mason\anim\magnus_comun.txt`.

## Las animaciones

| animacion | fotogramas | hframes | vframes | fps | tipo |
|---|---|---|---|---|---|
| `respirando` | 30 | 6 | 5 | 12 | bucle |
| `arranque_andar` | 34 | 6 | 6 | 24 | una pasada |
| `andando` | 34 | 6 | 6 | 24 | bucle |
| `parada_andar` | 21 | 7 | 3 | 24 | una pasada |
| `arranque_correr` | 38 | 7 | 6 | 24 | una pasada |
| `corriendo` | 24 | 6 | 4 | 24 | bucle |
| `parada_correr` | 39 | 7 | 6 | 24 | una pasada |
| `salto_andando` | 70 | 10 | 7 | 60 | una pasada |
| `salto_corriendo` | 38 | 8 | 5 | 60 | una pasada, casilla 340x400 |
| `giro` | 5 | 5 | 1 | 20 | una pasada |
| `cayendo` | 14 | 7 | 2 | 24 | bucle, casilla 380x360 |
| `caida` | 21 | 7 | 3 | 24 | una pasada, casilla 380x360 |
| `tumbado` | 1 | 1 | 1 | - | quieto, casilla 380x360 |
| `levantarse` | 63 | 8 | 8 | 24 | una pasada, casilla 380x360 |


Todas comparten **casilla de 292 x 360 px** salvo el salto corriendo y las cuatro
de la caida. Ojo: algunas hojas tienen casillas de sobra al final (2 en andando y
arranque_andar, 4 en arranque_correr, 3 en parada_correr, 2 en salto_corriendo,
1 en levantarse). Al crear el `SpriteFrames` hay que quedarse solo con los
primeros N.

Las cuatro de la caida salen de un solo video y comparten casilla propia porque
tumbado mide 678 px de master de ancho. La casilla es mas ancha pero **igual de
alta y con el suelo en la misma fila** que la comun (pies en 677 de 720), asi que
usan `offset_comun`, sin offset propio. Todo el detalle, fotogramas y medidas en
`raw/master_mason/anim/magnus_caida/como_se_hizo.txt`.

## Como encadenan

En el juego: andar con la flecha, correr con doble pulsacion.

```
respirando -> arranque_andar  -> andando      -> parada_andar  -> respirando
respirando -> arranque_correr -> corriendo    -> parada_correr -> respirando
(entrada)  -> cayendo -> caida -> tumbado -> levantarse -> respirando
```

**La entrada es una cinematica.** `dark_stage` arranca con Magnus 1200 px por
encima de su marca de suelo y `caer_desde_arriba()` lo deja caer con aceleracion
cuadratica en 1,1 s (unos 2200 px/s al llegar) con el bucle `cayendo`; al tocar
el suelo entra `caida`, se queda `tumbado` 1,2 s (temporizador, no animacion) y
`levantarse` termina en la pose de reposo: su ultimo fotograma esta a 0,13 del
primero de `respirando`, un paso normal de la propia animacion. Mientras dura no
se acepta entrada (`Estado.CAYENDO..LEVANTARSE`, ver `CINEMATICA`); al acabar se
emite `cinematica_terminada`. El bucle en el aire tiene la cabeza fijada -- el
descenso lo pone el nodo -- y se arranca por el fotograma que deja el impacto
justo en el que enlaza con `caida` (el 7, fotograma 32 del video), calculado a
partir de la duracion. Tiempos en `caida_altura`, `caida_duracion` y
`tumbado_espera`; `caida_al_empezar = false` en la escena la desactiva.

En **andar** el enlace es exacto: `arranque_andar` acaba en el fotograma
inmediatamente anterior al que abre `andando` en el video original (52 -> 53).

En **correr** no, porque el ciclo bueno viene de otro video. El desajuste medido
al entrar es 0,172 y al salir 0,274; como el paso normal entre dos fotogramas de
una carrera a 24 fps ya vale ~0,19, la entrada queda por debajo del ruido. Si se
quiere afinar, los mejores puntos son entrar por el fotograma 13 y salir por el 22.

Las paradas enganchan con el primer fotograma del bucle de respirar con una
diferencia de 0,046 y 0,051 (entre fotogramas seguidos de una animacion quieta el
ruido es 0,013).

**El ciclo de correr es `corriendo`.** Hubo un `corriendo_v2` sacado del mismo
video que las transiciones: enlazaba en fotogramas consecutivos, pero su bucle
cerraba tres veces peor (0,070 frente a 0,021). Como en una carrera a 24 fps el
paso normal entre fotogramas ya vale ~0,19, la ventaja del enlace quedaba por
debajo del ruido, mientras que el cierre del bucle se ve una vez por segundo.
Esta guardado en `raw/master_mason/anim/_archivo/` por si se prefiere lo otro.

## Velocidad, para que los pies no patinen

El numero que importa es **cuanto avanza el cuerpo por fotograma de animacion**.
La primera vez se dedujo de la zancada (separacion maxima entre los dos pies) y
salio mal: esa separacion va del talon de atras a la punta de delante, o sea
incluye un pie de mas, y sobrestima el paso. Con eso el cuerpo recorria un 48%
mas de lo que decian las piernas y el personaje se deslizaba.

La medida buena se saca siguiendo, fotograma a fotograma, **el pie que esta
plantado** respecto al eje del tronco: lo que ese pie retrocede en la imagen es
exactamente lo que avanza el cuerpo. Sobre las mascaras de `04_limpios`
(584x720), quedandose con el pie que mas pixeles tiene tocando la linea de suelo:

| | por fotograma (master) | por fotograma (hoja 1/2) | ciclo | velocidad nativa a 24 fps |
|---|---|---|---|---|
| andando | 12,8 px | **6,4 px** | 34 fotogramas | 154 px/s |
| corriendo | 28,9 px | **14,5 px** | 24 fotogramas | 347 px/s |

Esos son los valores de `avance_andar` / `avance_correr` en `magnus.gd`. Los
antiguos (9,5 y 17,3) estaban sacados de la zancada y son los que patinaban.

La velocidad nativa es a lo que anda el personaje si la animacion va a sus 24 fps
de origen. En el juego van mas rapido, y la animacion se acelera sola para
compensar. No patina igualmente: si la cadencia de piernas se ve nerviosa, lo
que hay que bajar es la **velocidad**, nunca el avance.

### La velocidad no es libre: tiene que dar ticks enteros

El fotograma solo cambia en un tick de fisica, asi que su duracion en pantalla es
por fuerza un numero entero de ticks. Si `velocidad / avance` no divide a los 60
Hz de la fisica, unos fotogramas duran un tick mas que otros y la cadencia va a
tirones. No es problema de los sprites: es aliasing entre dos relojes.

Estaba pasando. Con 229 y 416 salian 1,677 y 2,091 ticks por fotograma, o sea
que andando unos fotogramas duraban 17 ms y otros 33, una variacion de 2 a 1.

| | velocidad | fotogramas/s | ticks por fotograma |
|---|---|---|---|
| andando | **192 px/s** | 30 | 2 justos |
| corriendo | **435 px/s** | 30 | 2 justos |

La regla para cambiarlas: `velocidad = 30 * avance` (2 ticks) o `20 * avance`
(3 ticks, mas lento pero igual de regular). Cualquier otro numero devuelve el
tiron.

Queda un detalle de coma flotante: 192/60 da 3,2 px por tick y el avance es 6,4,
pero ninguno de los dos es exacto en binario y la suma se queda en 6,3999..., asi
que sin margen un fotograma de cada veintitantos duraba un tick de mas. Por eso
el calculo del fotograma en `magnus.gd` lleva un epsilon. Corriendo no pasaba,
porque 435/60 = 7,25 y 14,5 si son exactos.

Pero lo mejor no es fijar la velocidad, sino **mover la animacion con la
distancia**: en vez de reproducirla a fps constante, avanzar el fotograma segun lo
recorrido. Asi no patina a ninguna velocidad y la aceleracion sale gratis.

```gdscript
const AVANCE := 14.5          # px recorridos por fotograma de animacion
var recorrido := 0.0

func _physics_process(delta):
    recorrido += absf(velocity.x) * delta
    var n := sprite.sprite_frames.get_frame_count("correr")
    sprite.frame = int(recorrido / AVANCE) % n
```

Si el nodo lleva `scale` distinto de 1, hay que multiplicar `AVANCE` por ese factor.

## El encuadre, que es lo que las mantiene alineadas

Dentro de cada casilla de 292 x 360:

- **linea de suelo**: a 15 px del borde inferior, es decir la **fila 345**.
- **eje del personaje**: centrado, **columna 146**.

Las tres animaciones se procesaron ancladas a esos dos valores, por eso el
personaje no pega un salto al cambiar de una a otra.

Para que el nodo se apoye en el suelo, el origen tiene que caer en la fila 345 y
no en el centro de la casilla:

```gdscript
# Sprite2D / AnimatedSprite2D con centered = true
offset = Vector2(0, -165)   # 180 (centro) - 345 (suelo)
```

Asi la posicion del nodo **es** el punto donde pisa, que es lo comodo para
colocarlo sobre el terreno y para la fisica.

## Voltear para el otro lado

Los sprites miran a la **derecha**. Para ir a la izquierda, `flip_h = true`.

La casilla se hizo simetrica a proposito (292 de ancho para un personaje que
ocupa como mucho 262 hacia un lado): al voltearla, el personaje **no se
desplaza**. Si algun dia se recorta la casilla para ahorrar, esto se rompe.

### La animacion de giro

Las ocho animaciones de movimiento son **perfil puro**, asi que cambiar de
sentido saltaba de un perfil al otro sin nada en medio y cantaba. Disimularlo
deformando el sprite se probo y no colaba: con una silueta tan marcada -- capucha,
barba, capa -- se lee como un fallo de dibujo, no como un giro.

La solucion son fotogramas de verdad, y **no salen de un video**: son una hoja de
rotacion pedida a una IA de imagen (`_fuentes/giro360.jpeg`), con el prompt en
`_fuentes/prompt_giro.txt` y `referencia_magnus_perfil.png` como referencia.

**La hoja no venia ordenada, y hay que comprobarlo siempre.** Se pidieron 0, 22,
45, 67 y 90 grados y llegaron **0, 22, 45, 135 y 90**: la cuarta pose se paso de
largo del frontal en vez de quedarse antes. Montada en el orden en que venia, el
personaje giraba, saltaba al otro lado y volvia.

Como se detecta sin ojo clinico, con dos medidas sobre las siluetas:

- **Simetria de cada pose**, o sea su distancia consigo misma volteada. Tiene que
  bajar sin parar hasta el frontal y volver a subir. Salia 17, 16, 12, **15**, 3:
  la cuarta rompia la progresion.
- **Cada pose contra el espejo de las demas.** La cuarta contra el espejo de la
  tercera daba 7, el valor mas bajo de toda la matriz, por debajo incluso de la
  simetria propia de la tercera (12). Era la tercera espejada.

De ahi sale la animacion: **pasos de 45 grados clavados**, quedandose con 0, 45,
90, 135 y 180. El de 180 es el de 0 **volteado contra el centro de la casilla**,
que es exactamente lo que hace `flip_h`, asi que el ultimo fotograma encaja al
pixel con los sprites de siempre del otro lado, y la misma animacion vale para
los dos sentidos: reproducida volteada se lee de izquierda a derecha.

Las poses de 22 grados se descartan. Metiendolas, los pasos quedaban en 15, 8,
17, 17, 10, 15 -- una razon de 2,1 entre el mayor y el menor, porque falta la de
67 grados -- y se veia acelerar al pasar por delante. Con solo las de 45 los
pasos son **17, 17, 17, 18**, razon 1,06.

Total: **5 fotogramas a 20 fps, 0,25 s**, que ademas son 3 ticks de fisica justos
por fotograma.

Si algun dia se consigue la pose de **67 grados** que falta, con ella y su espejo
salen 9 fotogramas a 22,5 grados de paso, igual de uniformes y mas suaves.

Hubo que ajustar tres cosas a mano, y las tres se notaban como **"los pies
centellean"** o como un salto al entrar y salir del giro:

- **La escala.** `centrar.ps1` alinea pero no reescala. Las poses venian a 1470
  px de alto y se redujeron a **628**, que es lo que mide el personaje en el
  reposo.
- **El color de los pies.** La IA los ilumino distinto en cada pose: medidos
  sobre la piel del pie (calida, r-g > 15, lo que la separa de la pierna, que es
  gris neutro) la luminancia iba 70, 89, 68, 92, 70 -- **34% alternando
  oscuro-dorado**, mientras el cuerpo entero solo variaba un 3%. Se corrige con
  una ganancia por canal que lleva cada pose a la media de los pies del reposo.
  Despues: 0,4%.
- **La linea de suelo.** `centrar.ps1` ancla el suelo *medido* al margen pedido,
  y en un video ese suelo lo marca el pie de apoyo, que cae por debajo del pixel
  mas bajo de un fotograma de pie; con cinco poses quietas coinciden. El giro
  salia en y=690 y el reposo esta en y=677 clavado en sus 30 fotogramas, o sea
  que el personaje **bajaba 13 px** al entrar en el giro. Se corrige subiendo los
  cinco fotogramas hasta 677.

El resto lo hizo el flujo de siempre.

El volteo del sprite se hace al **terminar** la animacion, no al empezar
(`_al_terminar` en `magnus.gd`): durante el giro se conserva el `flip_h` que
hubiera.

### Arrancar y parar de correr

**El arranque de correr alcanzaba el crucero en el fotograma 8, no en el 28.**
Midiendo el pie plantado: 6 fotogramas quieto, el 6 avanza 5,4 px master, el 7
dieciseis, y del 8 en adelante ya va a 29-33, que es el crucero del ciclo (28,9).
La rampa recta daba 5,7 en el fotograma 8: las piernas a tope con el cuerpo al
20 %, el pie resbalando hacia atras todo el arranque. Ahora la velocidad sale de
`AVANCE_ARRANQUE_CORRER` (0 x6, 81, 240, 435...) y el corte baja del 28 al **22**,
entrando al ciclo por el **f9** (0,72 pasos, mejor que el 0,76 de antes y seis
fotogramas mas corto).

**Y `arranque_correr` y `parada_correr` iban a 24 fps con el ciclo a 30** (435
px/s son 30 fotogramas/s de 14,5 px). Las dos a 30.

**La parada de correr solo casa con una fase.** A diferencia de la de andar,
entrar por el fotograma mas parecido no sirve: el mejor es siempre el 0. La
distancia desde el ciclo va de 1,2 (f22) a 2,1 (f12-f15). Asi que se espera a una
fase que case, igual que al andar.

### El dial: tolerancia_parada_*

Cuanto salto de pose se acepta al entrar en la parada, en pasos normales del
ciclo. Se espera a un fotograma del ciclo que baje de eso. Es el unico numero que
hay que tocar para elegir entre que se vea bien y que responda:

| | tolerancia | fases que valen | espera maxima | medido |
|---|---|---|---|---|
| correr | 1,25 | solo f22 | 23 fotogramas | 0-46 ticks, hasta **341 px** |
| correr | 1,60 | once fases | 9 fotogramas | 0-6 ticks, hasta **51 px** |
| andar | 1,30 | f2-f3, f24-f30 | 20 fotogramas | 0-40 ticks, hasta **131 px** |

Puesto en 1,25 y 1,30, que es lo pedido: que se vea bien aunque cueste
responsividad. El personaje no se queda quieto esperando, **termina el paso**,
que es lo que hace una persona al soltar. Las distancias medidas estan en
`DIST_PARADA_ANDAR` y `DIST_PARADA_CORRER`.

### Parar de andar: terminar el paso y frenar como los pies

La parada de andar esta grabada desde **una sola fase** de la zancada: sus 21
fotogramas casan con el ciclo alrededor de f26-f29 (y f3), siempre a >= 1,1
pasos, y la otra mitad del ciclo no tiene equivalente. Entrando siempre por su
fotograma 0, el salto de pose al soltar iba de 1,1 a **3,8 pasos** segun donde
soltaras (media 2,4): el efecto raro al pararse. Y ademas la parada iba a 24 fps
con el ciclo a 30: cambio de cadencia en seco.

Segundo problema, medido siguiendo el pie plantado: en la parada el pie sigue
avanzando 3-6 px master por fotograma durante 14 fotogramas antes de plantarse,
mientras la frenada del nodo cortaba en ~5. Los pies seguian andando con el nodo
ya parado.

Lo montado, que es lo que hacen los juegos con una sola animacion de parada:

- La parada a **30 fps**, como el ciclo.
- Al soltar, el personaje **termina el paso**: se espera a un fotograma del ciclo
  desde el que la entrada queda a <= 1,3 pasos (`PARADA_ANDAR_BUENOS`: f2-f3 y
  f24-f30), como mucho `espera_parada_andar` = 10 fotogramas (0,33 s). Medido:
  de 0 a 20 ticks de espera, 3-67 px de mas.
- Se entra por el fotograma de la parada mas parecido a la pose actual
  (`POSE_ANDAR_A_PARADA`).
- El nodo frena siguiendo el **perfil medido** de los pies
  (`FRENADA_ANDAR_PERFIL`), escalado para arrancar exacto en la velocidad que
  traia: entra a 192 px/s en todos los casos, sin bajon, y para en 50-56 px.

Queda un caso peor: soltando entre f4 y f12 la ventana buena esta a 12-20
fotogramas, la espera se corta a 10 y se entra con salto de pose. Esperar mas
seria 0,67 s andando solo. Lo que lo arreglaria del todo es una **segunda
parada** grabada desde la otra fase de la zancada (el otro pie delante).

### El arranque de andar: velocidad medida, no una rampa recta

La rampa de subida del arranque de andar era una recta de 0 a la velocidad de
crucero repartida en los 32 fotogramas tras la zona muerta. El video no hace
eso. Midiendo el avance real del pie plantado respecto al eje del tronco
(master px por fotograma): 0, 0.7, 2.2, 2.6, 4.6, 6.3, 7.1, 8.2, 8.3, 9.9,
10.3, 12.1, 11.3, 11.0, 11.7, 11.7, 13.5, 12.6, 12.6... y luego, del 26 al 33,
**afloja a 10, 8.6, 8.7, 12.8, 12.2, 9.6, 6, 1.3** mientras la recta seguia
subiendo hasta 16. En esa cola el nodo iba de +2 a +15 px master por fotograma
por delante de los pies: el deslizamiento "sutil pero se nota" de los primeros
segundos de andar.

Dos cosas mas salieron de la medida. Comparando cada fotograma del arranque con
el ciclo, del 18 en adelante **el arranque ya es el ciclo**: el 18 casa con el
f19 del ciclo (0,54 pasos), el 22 con el f22 (0,40), el 25 con el f25 (0,40)...
Y el arranque iba a 24 fps mientras el ciclo, en el juego, va a 30 (192 px/s
son 30 fotogramas/s de 6,4 px): los pies del arranque iban un 25 % mas lentos
que los del ciclo.

Lo montado ahora:

- `arranque_andar` a **30 fps**, misma cadencia que el ciclo.
- Su velocidad sale de `AVANCE_ARRANQUE_ANDAR`, la tabla medida a media escala
  y a 30 fps (v = master/2 * 30), fotograma a fotograma. Los dos primeros son 0:
  la zona muerta ya no hace falta como fraccion.
- Se **corta en el 18** (`corte_arranque_andar`) y el ciclo entra por el **19**
  (`entrada_andar`). Al empalme llega a 189 px/s contra 192 del ciclo.

Comprobado: en el arranque el nodo recorre **72,1 px** y los pies, por la tabla,
72. Antes el nodo hacia 128 (256 master) frente a 146 (292) de los pies, y ademas
mal repartidos: corto al principio y largo al final.

### Pedir correr cuando ya se anda: entrar por la pose, no por la velocidad

La primera pulsacion de un doble arranca a andar sin remedio -- no se sabe que
era doble hasta que llega la segunda -- y si la segunda llega tarde, uno ya esta
andando y pide correr desde el ciclo de andar. Entrar en el arranque de correr
por el fotograma que da la velocidad que se lleva (el 14 a 192 px/s) dejaba la
pose a **2,2-2,8 pasos** de cualquier fotograma de andar: mas que el rebote del
brazo que se quito (1,8). Se veia como que "detecta que anda y luego pasa a
correr".

Ahora se entra por el fotograma del arranque de correr que **mas se parece** a la
pose que se trae (tablas `POSE_DESDE_ARRANQUE_ANDAR` y `POSE_DESDE_ANDAR` en
`magnus.gd`, medidas por silueta y color): media 1,05 y 1,34 pasos, peor caso
1,87. Como esos fotogramas (4-8) tienen la rampa de velocidad aun baja, la
velocidad que se traia se sostiene aparte (`_velocidad_suelo`) hasta que la rampa
la alcanza: sin bajon, comprobado (minimo 192 px/s viniendo de andar). El cambio
andar->correr en si, con la segunda pulsacion a tiempo, ya era pequeno:
0,23-0,68 pasos.

### Soltar en la zona muerta del arranque vuelve a reposo, no a la parada

Un doble toque real es pulsar-**soltar**-pulsar. Al soltar en pleno arranque de
andar el script entraba en la parada, y la parada empieza **a media zancada**
(esta hecha para venir del ciclo). Con la segunda pulsacion se encadenaban tres
animaciones en 0,25 s -- arranque f0, parada f0-4, arranque de correr f0 -- con
dos saltos de pose de 0,97 y 1,25 pasos. Se veia como un sprite que se pone
encima de otro sin coincidir.

Si la velocidad es cero al soltar, los pies no se han movido y no hay nada que
frenar: se vuelve a `reposo`, que es la misma pose de pie (de arranque f0 a
arranque de correr f0 hay 0,23 pasos). Si ya se movia, la parada sigue igual.
Efecto colateral: un toque muy corto (menos de ~5 ticks) ya no reproduce la
parada, vuelve a reposo directamente.

### El salto corriendo, y por que tiene casilla propia

`salto_correr` sale de un video en el que el personaje corre, salta una piedra y
se para; se usan solo los 38 fotogramas del salto (128-165). El detalle
completo, con la piedra, las sombras y el polvo, esta en
`raw/.../magnus_salto_corriendo/como_se_hizo.txt`. Dos cosas afectan al juego:

**No cabe en la casilla comun.** En el apogeo llega a 313 px a la izquierda del
eje y 691 por encima del suelo, y la casilla de 584x720 se queda corta por arriba
y por la izquierda. Lo detecto el chequeo de margen de `hoja.ps1` (0 px). En vez
de agrandar las nueve animaciones -- un 22 % mas de VRAM para ocho que no lo
necesitan -- este salto va en su propia hoja de **340x400** por casilla, y
`magnus.gd` cambia `_sprite.offset` al entrar y salir de la animacion
(`offset_comun` -165, `offset_salto_correr` -185: alto/2 menos los 15 px de
margen de suelo). Si algun dia otra animacion se sale, es el mismo mecanismo.

**Entra desde cualquier fotograma de la carrera.** Se midio el primer fotograma
del salto contra los 24 del ciclo: 2,75 pasos normales en el mejor caso, 3,86 en
el peor, 3,41 de media. Elegir el momento perfecto ahorraria un 30 % a cambio de
hasta 0,8 s de latencia al pulsar, asi que no se espera a nada. El desajuste no
lo domina la zancada sino que la pose de despegue es un agachado que no existe en
el ciclo, y el propio salto avanza 2,08 pasos de correr por fotograma: entrar con
2,75 equivale a 1,3 fotogramas del salto, que es lo que un corte seco absorbe.

El video viene a camara lenta (1,1 s de vuelo); a 60 fps queda en 0,45 s. Y el
video recorta la punta de la capucha en el apogeo, que se reconstruye
geometricamente: es la punta, no la cabeza.

### Repaso de las catorce animaciones

Hay dos cosas que comprobar, y **no aplican a todas por igual**.

La regla de los **ticks enteros** -- que 60/fps sea entero -- solo vale para
`andar` y `correr`, que son las unicas cuyo fotograma pone el script desde
`_physics_process`: ahi la duracion se cuantiza a ticks y si no es entera, unos
fotogramas duran 17 ms y otros 33. Las demas las reproduce el `AnimatedSprite2D`
en `_process`, con duracion de reloj, y su fps es una eleccion libre de ritmo.

Lo que si aplica a los arranques y paradas es **igualar la cadencia del ciclo con
el que empalman**: a 24 fps las piernas cambiarian de ritmo un 25 % al cruzar la
costura hacia un ciclo que va a 30. Por eso estan a 30, no por los ticks.

Y la linea de suelo tiene que caer donde el `offset` del sprite la espera.

| animacion | fps | cuantizacion | casilla |
|---|---|---|---|
| reposo | 12 | (de reloj) | 292x360 |
| arranque_andar, parada_andar | 30 | (de reloj) | 292x360 |
| **andar** | 30 | **2** | 292x360 |
| arranque_correr, parada_correr | 30 | (de reloj) | 292x360 |
| **correr** | 30 | **2** | 292x360 |
| giro | 20 | (de reloj) | 292x360 |
| saltar | 60 | (de reloj) | 292x360 |
| salto_correr | 60 | (de reloj) | **340x400** |
| cayendo, caida, levantarse | 24 | (de reloj) | **380x360** |
| tumbado | 1 | (un fotograma) | 380x360 |

`andar` y `correr` los mueve el script por distancia -- el nodo esta parado --
asi que su fps del .tres no se usa; se deja en 30 para no despistar.

Las de caida se quedan a 24: no las mueve el script ni empalman con ningun ciclo
movido por distancia, asi que su ritmo es una decision de animacion y no hay nada
que igualar. (`caer_desde_arriba()` calcula el fotograma de entrada del bucle con
`get_animation_speed`, asi que aguanta cualquier fps que se les ponga.)

Alineacion comprobada sobre los sprites: el suelo de las animaciones de la
casilla comun cae entre 675 y 683 (master), y el de `tumbado`/`levantarse` en
672, cinco pixeles = 1,3 en pantalla. Dentro del ruido.

### Lo que no tiene arreglo sin material nuevo

- **El salto en carrera entra y sale con 2,8-3,9 pasos de salto de pose.** Viene
  de otro video, y el despegue y el aterrizaje son agachados que no existen en el
  ciclo. Se compensa con que va a 60 fps: ese salto equivale a 1,4 fotogramas del
  propio salto, o sea un parpadeo de 16 ms.
- **Solo hay una parada por accion,** grabada desde una fase de la zancada. De ahi
  la espera de `tolerancia_parada_*`. Una segunda parada con el otro pie delante
  lo cerraria, pero los modelos de IA no la dan consistente.

## Importacion en Godot

Tres ajustes que importan, sobre todo si la camara va a cambiar de zoom:

- **Mipmaps activadas.** Sin ellas, el personaje pequeno con bordes facetados
  centellea al moverse. Cuestan un 33% mas de memoria y los valen. Con una
  condicion, que ahora mismo se cumple: ver el margen entre casillas aqui abajo.
- **Filtro lineal**, no nearest. Esto es pintado, no pixel art.
- El zoom se hace en la **`Camera2D`**, no escalando el nodo del personaje: asi
  escala toda la escena a la vez y el personaje no se despega del fondo.

Coste de las siete hojas: 10,8 MB en disco, **104,7 MB de memoria de video** (139
con mipmaps). Descontando el ciclo de correr que se descarte, unos 95. Si algun dia aprieta, activar compresion VRAM en la importacion antes
que volver a reducir la resolucion.

### El margen entre casillas, que es lo que hace seguras las mipmaps

La hoja es un **atlas**: Godot la muestrea con filtrado bilineal y cada nivel de
mipmap promedia bloques de la hoja entera, sin saber donde acaba una casilla y
empieza la siguiente. Si el personaje llegara al borde de su casilla, el vecino
se colaria por ahi y se verian fotogramas mezclados.

Lo que lo impide es el **margen transparente** que el personaje deja dentro de su
casilla. Un margen de M px aguanta mientras el texel del mipmap mida menos que M:
el nivel L usa texels de 2^L px y se emplea a escala 1/2^L.

Medido sobre las ocho hojas actuales, casilla a casilla, el margen mas justo es
de **12 px** (izq 15, der 28, arr 12, abj 16), asi que el atlas esta limpio hasta
**1/8 de escala**. El juego dibuja a 0,527 -- viewport 2912x1632 sobre una
pantalla de 1536x864 -- o sea muy lejos del limite, y cualquier alejamiento de
camara razonable tambien.

Ese margen no es intencionado: sale de que la casilla se dimensiono a 292 de
ancho para un personaje que ocupa como mucho 262. Por eso `hoja.ps1` lo mide al
terminar y avisa si baja de 8 px, que es lo que pasaria con una animacion en la
que el personaje llenase mas la casilla. Si algun dia salta ese aviso, las
salidas son agrandar la casilla en `centrar.ps1` o importar esa hoja sin mipmaps.

## Tamano en pantalla

El personaje mide **330 px** de alto en la casilla. Con el viewport de 1632 de
alto:

- plano abierto, personaje a ~200 px (12% de la pantalla): se reduce, nitido.
- plano normal, ~330 px: 1 a 1.
- camara cerca, ~440 px: se estira 1,3x y queda algo blando, lo que de paso
  suaviza las facetas del modelo.

Esta dimensionado para el **zoom maximo**, no para el tamano habitual: a una
textura le sienta bien que la achiques y mal que la estires.

## Avisos sobre el material

**El salto viejo giraba.** El primer `magnus_saltando` rotaba 30-45 grados hacia
camara en pleno vuelo; venia asi del video. Se sustituyo por `magnus_salto_andando`,
sacado de un video en el que el personaje anda, se agacha, salta y aterriza sin
girar (fotogramas 89-158; detalle en su `como_se_hizo.txt`). Es un solo salto
para parado y andando: el centrado va anclado al tronco, asi que el sprite no
lleva desplazamiento cocido y el movimiento horizontal lo pone el nodo. Medido
contra el resto: desde reposo entra a 0,052 (como las paradas), desde el ciclo
de andar a 0,037 (~3 pasos) y acaba a 0,024 del reposo. El job viejo sigue en
`raw/master_mason/anim/magnus_saltando/` por si hace falta.

Dos cosas de este salto que afectan al encuadre: en el apogeo llega a 671 px
sobre el suelo, 19 px por debajo del techo de la casilla comun (hubo que anadir
40 px de verde arriba al video para poder recortar), y `centrar.ps1` le mide el
suelo 4 px bajo porque en la cuclilla el pie aplasta mas que de pie: apoya en la
fila 686 de la casilla en vez de en la 690, dentro del rango de las demas.

**El brazo de la carrera va al doble de frecuencia.** Las piernas hacen su ciclo
en 24 fotogramas, dos pasos. El brazo deberia hacer una sola oscilacion completa
en esos 24 -- cada brazo va en oposicion a su pierna -- y hace dos. Medido
rastreando la mano cercana en los 192 fotogramas del video y autocorrelando su
altura: el minimo cae en periodo 12, cuando para un brazo correcto el 12 tendria
que ser un maximo, porque a media zancada el brazo esta en el extremo contrario
de su recorrido.

Pasa en el video entero, no en un tramo: no es una ventana mal elegida ni unos
fotogramas rotos, es como el modelo entendio la carrera, asi que **ninguna
seleccion lo arregla**. El sintoma es que el codo hace algo que no cuadra al
volver a subir.

Si se vuelve a pedir el video, hay que decirlo explicito, que es justo lo que los
modelos se inventan cuando no se les dice:

> The arms swing in opposition to the legs: when the left leg is forward the
> right arm is forward. Each arm completes exactly ONE full forward-and-back
> swing per full stride cycle (two steps), not one per step. Elbows stay bent at
> roughly 90 degrees throughout, the forearms never straighten.

La alternativa sin pedir nada es retocar los 24 limpios para que la capa tape el
brazo siempre -- ya lo tapa en buena parte del ciclo -- a cambio de perder el
gesto de los brazos al correr.

## Regenerar o anadir una animacion

**Al importar una hoja nueva, Godot apaga los mipmaps.** El `.import` que genera
`godot --headless --import` trae `mipmaps/generate=false` por defecto, mientras
que las hojas de siempre los llevan encendidos: la animacion nueva se veria con
otro filtrado al reducirse. Hay que poner `mipmaps/generate=true` en su
`.import` y volver a importar. Paso dos veces (giro y salto corriendo) antes de
apuntarlo aqui.

Las herramientas estan en `godot\tools\anim\` (ver su README). Para una accion
nueva de Magnus, con los mismos numeros:

```powershell
cd C:\Users\santiago.ochoa\godot\tools\anim
.\nuevo.ps1    -Job magnus_<accion> -Fuente <video.mp4>
.\frames.ps1   -Job magnus_<accion>
.\contacto.ps1 -Job magnus_<accion>
.\elegir.ps1   -Job magnus_<accion> -Frames "<rango>"
.\centrar.ps1  -Job magnus_<accion> -Ancho 584 -Alto 720 -MargenSuelo 30
.\fondo.ps1    -Job magnus_<accion> -Tolerancia 35 -Radio 4
.\hoja.ps1     -Job magnus_<accion> -Cols <n> -Fps <n> -Escala 2
```

Si la animacion nueva sube mas alto que el salto no cabra en los 720, habra que
subir el alto y **reprocesar tambien las tres anteriores** con el valor nuevo.
