# Sprites de Magnus

Todo lo que hay que tener delante al montar las animaciones del personaje en
Godot. Los numeros no son negociables entre animaciones: si se cambia uno, hay
que rehacer las tres.

## Ya esta montado

| archivo | que es |
|---|---|
| `assets/characters/magnus/*.png` | las 8 hojas, 292x360 por casilla |
| `resources/characters/magnus_frames.tres` | el `SpriteFrames` con las 8 animaciones |
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
caer recupera el modo que llevaba (andar o correr) si la tecla sigue pulsada. Se
puede cortar a partir del 72 % de la animacion, que es cuando ya ha aterrizado.

El `.tres` se genera por script, no a mano: son 295 `AtlasTexture`, uno por
fotograma, recortados de las hojas. El generador es
`godot/tools/anim/_spriteframes.py`, y ahi estan tambien los **fps de cada
animacion**, que no tienen por que ser los del video:

```powershell
cd C:\Users\santiago.ochoa\godot\tools\anim
python _spriteframes.py "..\..\projects\master_mason\resources\characters\magnus_frames.tres"
```

El salto es el caso claro: el video venia a camara lenta y a 12 fps duraba
**6,25 s**. Se reproduce a **60 fps**, con lo que dura **1,25 s**, y ademas en una
pantalla de 60 Hz se ve cada fotograma exactamente una vez.

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
| `saltando` | 75 | 10 | 8 | 12 | una pasada |


Todas comparten **casilla de 292 x 360 px**. Ojo: algunas hojas tienen casillas de
sobra al final (2 en andando y arranque_andar, 4 en arranque_correr, 3 en
parada_correr, 5 en saltando). Al crear el `SpriteFrames` hay que quedarse solo
con los primeros N.

## Como encadenan

En el juego: andar con la flecha, correr con doble pulsacion.

```
respirando -> arranque_andar  -> andando      -> parada_andar  -> respirando
respirando -> arranque_correr -> corriendo    -> parada_correr -> respirando
```

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
de origen. En el juego estan puestas a 229 y 416, o sea un 49% y un 20% mas
rapido, y la animacion se acelera sola para compensar (unos 36 y 29 fps
efectivos). No patina igualmente, pero si la cadencia de piernas se ve nerviosa,
lo que hay que bajar es la **velocidad**, nunca el avance.

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

### Pendiente: la animacion de giro

Las ocho animaciones son **perfil puro**. No hay ni un fotograma frontal ni de
tres cuartos, asi que cambiar de sentido salta de un perfil al otro sin nada en
medio y canta. Ahora mismo el volteo se hace en el instante en que la frenada
deja el cuerpo quieto, que es donde menos se nota, pero se nota.

Disimularlo deformando el sprite (estrecharlo hasta casi nada y devolverlo ya
volteado, como un pivote) **se probo y no vale**: con una silueta tan marcada
-- capucha, barba, capa -- se lee como un fallo de dibujo, no como un giro.
Tampoco vale fundir una imagen con su espejo: salen dos personajes solapados.

Hacen falta fotogramas. Lo que hay que pedir:

- Vídeo aparte, **mismo croma verde, 720p, mismo encuadre y misma distancia de
  camara** que los otros. Si la camara cambia, la casilla y la linea de suelo
  no cuadran con el resto y hay que recentrar todo.
- El personaje **gira 180 grados sobre si mismo, sin desplazarse**, de perfil a
  perfil.
- Que gire **por delante**, enseñando cara y barba, no por la espalda: se lee
  mucho mejor y evita tener que inventar como es la capucha por detras.
- Despacio y entero mejor que rapido: sobra quitar fotogramas, no se pueden
  inventar. Y que se quede **quieto un momento al principio y al final**, para
  tener los extremos limpios con los que empalmar con reposo.

Solo hace falta **media vuelta**: de perfil a frontal. La otra mitad sale
volteando esos mismos fotogramas, y asi el giro a un lado y al otro son
identicos y el final encaja exacto con el perfil espejado. O sea que de un giro
de ~0,25 s se aprovechan unos 4-5 fotogramas reales.

En Godot entra como una animacion `giro` de una pasada, a fps fijo (no con la
distancia: en el giro el cuerpo no avanza). Se dispara en `_mirar()` de
`magnus.gd`, en el mismo punto donde hoy se hace el `flip_h`, y se reproduce mas
rapida si venia corriendo.

## Importacion en Godot

Tres ajustes que importan, sobre todo si la camara va a cambiar de zoom:

- **Mipmaps activadas.** Sin ellas, el personaje pequeno con bordes facetados
  centellea al moverse. Cuestan un 33% mas de memoria y los valen.
- **Filtro lineal**, no nearest. Esto es pintado, no pixel art.
- El zoom se hace en la **`Camera2D`**, no escalando el nodo del personaje: asi
  escala toda la escena a la vez y el personaje no se despega del fondo.

Coste de las siete hojas: 10,8 MB en disco, **104,7 MB de memoria de video** (139
con mipmaps). Descontando el ciclo de correr que se descarte, unos 95. Si algun dia aprieta, activar compresion VRAM en la importacion antes
que volver a reducir la resolucion.

## Tamano en pantalla

El personaje mide **330 px** de alto en la casilla. Con el viewport de 1632 de
alto:

- plano abierto, personaje a ~200 px (12% de la pantalla): se reduce, nitido.
- plano normal, ~330 px: 1 a 1.
- camara cerca, ~440 px: se estira 1,3x y queda algo blando, lo que de paso
  suaviza las facetas del modelo.

Esta dimensionado para el **zoom maximo**, no para el tamano habitual: a una
textura le sienta bien que la achiques y mal que la estires.

## Dos avisos

**El salto gira.** Empieza y acaba de perfil, pero en los fotogramas 21-50 de la
seleccion el personaje rota 30-45 grados hacia camara y se le ven los dos brazos.
No es un fallo del recorte, viene asi del video. A tamano pequeno puede colar;
si no cuela, hay que pedir el video otra vez diciendo explicitamente que no rote
en ningun momento.

**Los pies van a patinar.** El ciclo de carrera son 24 fotogramas a 24 fps, o sea
1,00 s para dos zancadas. La velocidad de desplazamiento hay que ajustarla a ojo
hasta que el pie de apoyo no resbale: en el video el personaje corre en el sitio,
asi que no se pudo medir cuanto avanza por zancada.

## Regenerar o anadir una animacion

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
