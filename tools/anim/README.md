# tools\anim — animacion frame a frame

Envoltorios sobre `tools\ffmpeg` para el flujo: video o imagenes sueltas ->
fotogramas -> elegir los del ciclo -> retocar -> spritesheet para Godot.

Es una de las **dos tecnicas** de animacion del proyecto. La otra (rig de huesos,
`Skeleton2D` + `Bone2D`) va por su lado y no usa nada de esto.

## Un "job" es una animacion

`dominus_run`, `dominus_idle`, `dominus_punch`... Cada uno vive en
`raw\master_mason\anim\<job>\` y tiene sus etapas numeradas:

```
01_frames      fotogramas en bruto (de video, o PNG tuyos / de IA)
02_contacto    mosaicos numerados para elegir de un vistazo
03_seleccion   los elegidos, renombrados en orden de reproduccion
04_limpios     recortados, centrados y sin fondo + tu retoque a mano
05_salida      spritesheet + ficha con los datos para Godot
_con_sombra\   copia intacta de antes de aplanar la sombra, para comparar
_con_fondo\    copia intacta de antes de quitar el fondo, para comparar
```

`raw\` y `tools\` estan dentro del proyecto (`projects\master_mason\`), con
`.gdignore` para que Godot no los importe. En el sitio de antes (`godot\raw`,
`godot\tools`) quedan enlaces a ellos, asi que las rutas viejas siguen valiendo.
Lo que se regenera solo (fotogramas, selecciones, copias intermedias) no va a git:
ver el `.gitignore` del proyecto.

## Uso

```powershell
cd C:\Users\santiago.ochoa\godot\projects\master_mason\tools\anim

# 0. (opcional) quedarte solo con el tramo bueno del video
.\recortar.ps1 -Fuente "$HOME\Downloads\mi_video.mp4" -Desde 7

# 1. crear el job (copia el video a raw\...\anim\_fuentes; -Mover para moverlo)
.\nuevo.ps1 -Job dominus_run -Fuente "$HOME\Downloads\mi_video.mp4"

# 2. sacar fotogramas   (-Desde/-Hasta en segundos, -Fps remuestrea, -Ancho escala)
.\frames.ps1 -Job dominus_run
.\frames.ps1 -Job dominus_run -Desde 2.0 -Hasta 4.0 -Fps 12

# 3. hoja de contactos: el numero amarillo de cada casilla es el que usas luego
.\contacto.ps1 -Job dominus_run -Cols 6 -Filas 5

# 4. elegir el ciclo (el orden que escribes es el orden de la animacion;
#    puedes repetir un numero o volver atras: "12,14,16,14")
.\elegir.ps1 -Job dominus_run -Frames "12,15,18,21,24" -Prefijo run

# 5. ver si engancha, antes de perder tiempo retocando
.\ciclo.ps1 -Job dominus_run -Fps 12 -Ancho 480

# 5b. SOLO si el personaje proyecta una sombra dura sobre el croma
.\sombra.ps1 -Job dominus_run

# 6. recortar al personaje y quitar el paneo de camara -> 04_limpios
#    (todas las casillas salen del mismo tamano, que es lo que pide Godot)
.\centrar.ps1 -Job dominus_run -Margen 30

# 7. quitar el fondo (deja copia automatica en _con_fondo\)
.\fondo.ps1 -Job dominus_run

# 8. verlo sobre el tono real de la escena, que es donde se notan los fallos
.\ciclo.ps1 -Job dominus_run -Desde 04_limpios -Fps 24 -Fondo 14100E

# 9. montar la hoja final
.\hoja.ps1 -Job dominus_run -Fps 24
```

`info.ps1 <archivo>` da resolucion / fps / duracion de cualquier video o imagen.

## Encontrar el ciclo

El ciclo de carrera va de una pose a la misma pose con las piernas cambiadas.
Si no lo ves a ojo en la hoja de contactos, la pista esta en la separacion de los
pies: crece hasta la zancada maxima, se desploma cuando el pie de atras despega,
y vuelve a crecer. Ese patron completo es el ciclo. En el video de partida de
`dominus_run` salieron **21 fotogramas** a 24 fps (0,87 s por ciclo).

## Si los fotogramas los haces tu con IA

Salta los pasos 2 y 3: mete los PNG directamente en `03_seleccion` con nombres
ordenables (`run_01.png`, `run_02.png`...) y sigue desde el paso 5.

## Quitar el fondo

`fondo.ps1` **no usa una clave de color**, y no es por gusto: en este material la
barba blanca esta a distancia 12-16 del gris del fondo, y el ruido de compresion
del propio fondo llega a 9. Cualquier umbral que se coma el fondo se come la barba.

Lo que hace es rellenar desde el **borde del cuadro** con tolerancia corta: el
fondo es lo que se alcanza desde fuera, y el personaje es todo lo que quede sin
alcanzar. La barba no tiene por donde ser alcanzada.

Luego, solo en la frontera, deshace la mezcla con el fondo
(`F = (C - (1-a)*Fondo) / a`) tomando la referencia de los pixeles macizos
vecinos. Sin ese paso, el borde conserva el tinte claro y sobre una escena oscura
aparece una linea luminosa recorriendo toda la silueta.

Quedaban dos restos que el relleno desde el borde no puede resolver solo:

- **Bolsas encerradas**: el hueco entre el abrigo y la pierna es fondo, pero esta
  rodeado de personaje y no se alcanza desde fuera. Se quedaba opaco y sobre una
  escena oscura salia una mancha clara.
- **Motas**: islas sueltas de 1-3 px que deja la descontaminacion del borde. A
  tamano real casi no se ven, pero en movimiento parpadean.

Las bolsas no se pueden separar por color (en un fotograma la bolsa esta a
distancia 15 del fondo y la barba a 16). Se reconocen por tres cosas a la vez:
casi no dan al exterior, tienen abrigo oscuro alrededor, y tienen panza -- la
orla de antialiasing tambien es clara y tambien tiene abrigo alrededor, pero es
una banda de 2-3 px sin ningun pixel de fondo.

Lo que separa una bolsa de la orla es **cuanto de su contorno da al exterior**:
las bolsas medidas rondan el 0-36 %, los trozos de orla el 50-63 %. El umbral
esta en 42 %, que es el hueco que hay entre ambos. Si algun dia una bolsa se
resiste, ese es el numero a mirar (`--abertura`), no el color.

Ajustables: `-Tolerancia`, `-Radio`, y en `_fondo.py` los umbrales `--hueco`,
`--hueco-min`, `--anillo`, `--abertura` y `--motas`.

## Si la sombra es dura, primero `sombra.ps1`

Todo lo de arriba da por hecho que el fondo es de un color y el personaje de
otro. Una sombra dura rompe eso, porque **esta tan lejos del croma como el
propio personaje**. Medido en el video del aracnobat, con fondo verde:

| | distancia al color de fondo |
|---|---|
| sombra sola | hasta **122** |
| pixel del personaje mas cercano al fondo | **46** |

Se solapan enteras: no hay tolerancia que se coma una sin comerse la otra. Con
`-Tolerancia 35` quedaba una mancha negra pegada al bicho; subiendola, se
empezaba a comer las patas.

Lo que si las separa es el **tono**. Una sombra es el croma con menos luz,
`(r,g,b) = k*(Rf,Gf,Bf)`, y el personaje no cae en esa recta por mucho que se
oscurezca. Con `k = g/Gf` (el verde manda, es el canal menos ruidoso del croma):

    residuo = max(|r - k*Rf|, |b - k*Bf|)

    fondo + sombra    residuo <= 24   (percentil 99,9)
    personaje macizo  residuo 58-74   (mediana)

`sombra.ps1` aplana a color de fondo todo lo que cae en esa recta, **antes** de
centrar. A partir de ahi el croma es plano y `centrar.ps1` y `fondo.ps1` no se
enteran de que hubo sombra. Tambien hace falta antes de centrar porque si no la
sombra entra en la silueta y desvia el eje y el tamano de la casilla.

Dos redes, porque el umbral solo no vale:

- **Solo se aplana lo que se alcanza desde el borde del cuadro**, igual que en
  `fondo.ps1`. Un trozo oscuro dentro del personaje no se alcanza.
- **Y solo por sitios anchos** (`-Radio`, 3 por defecto). Esta es la que de
  verdad importa: el negro esta cerca de todas las rectas, asi que una pata
  oscura y fina da residuo 17-19 y el aplanado se colaba por ella y la partia
  por la mitad. Con radio 3 solo pasa por conductos de mas de 7 px. Medido en
  `and_03`: sin radio el personaje quedaba en 58.462 px partido en 344 trozos;
  con radio 3, 79.015 px de una pieza.

El precio son los pelos de 1-2 px, que se van con la sombra. A tamano de juego
no se veian.

Si el video no tiene sombra, o es suave, **este paso no hace falta**: aplanar de
mas solo puede quitar detalle.

## Con fondo de croma es otra historia

Si el video viene con fondo saturado (magenta, verde...), todo lo de arriba sigue
valiendo y ademas funciona mucho mejor. Medido sobre el mismo personaje:

| | fondo gris | fondo magenta |
|---|---|---|
| distancia de la barba al fondo | 14-16 | **122** |
| lo mas parecido al fondo dentro del personaje | ~12 | **101** |
| motas por fotograma | ~45 | ~13 |
| mordiscos en la barba | si | **ninguno** |

Dos cosas cambian en los ajustes:

- **`-Radio 4`** en vez de 2. Con mas contraste, la banda de mezcla del borde se
  ve mas ancha (unos 7 px frente a 3,5), y con radio 2 queda un ribete del color
  del croma alrededor de toda la silueta.
- El **despill** se enciende solo. Las partes finas -- punta del pie, punta de la
  barba -- son todas borde, no tienen interior del que sacar referencia y se
  quedan tenidas. `_fondo.py` mira que canales tiene altos el fondo y les recorta
  lo que sobresalen del canal bajo. Solo actua si el fondo esta saturado: con gris
  se queda quieto, porque ahi desaturaria el marron del abrigo.

  Dos detalles que costaron encontrar, porque dejaban verde siempre en los mismos
  sitios (puntas de pies y de barba):

  1. **Detectar y corregir son numeros distintos.** Al principio se usaba el mismo
     para las dos cosas, asi que todo lo contaminado acababa clavado justo en el
     umbral en vez de limpio. Ahora `--derrame` detecta y `--derrame-objetivo`
     dice hasta donde se baja (3 por defecto).
  2. **En el borde se aprieta, en el interior no se toca.** El derrame es luz del
     croma rebotando en el personaje, y eso pasa en el borde; lo verdoso del
     interior es color propio del abrigo. Dentro de `RADIO_BORDE` px del alfa se
     usa `--derrame-borde` (8); mas adentro, `--derrame` (25).

  Medido sobre magnus_andando: pixeles con exceso de verde >= 20 por fotograma,
  de **264-379 a 0-24**, sin tocar el color del abrigo.

`centrar.ps1` tambien funciona con cualquier fondo: mide el color en las esquinas
en vez de suponer que el fondo es claro, y se queda con la mancha mas grande, asi
que la marca de agua de la esquina ya no ensancha la casilla.

## Lo que esto NO puede arreglar

El borde derecho de la barba. En el video el abrigo pasa de fondo a personaje en
2-3 pixeles; la barba lo hace en una **rampa de 10 pixeles** (38-30-20-14-11-5-3-2-1-0)
cuyo tramo final esta por debajo del ruido de compresion del fondo. Ahi no hay
borde que detectar: ni el ojo lo ve en el original. Queda un contorno algo
dentado, con mordiscos de 2-3 px.

Opciones, por orden de sensatez:

1. **Dejarlo.** A tamano de juego el personaje mide una fraccion de estos 680 px
   y esos mordiscos desaparecen.
2. **Repasar la barba a mano** en GIMP, dibujando su silueta.
3. **Volver a generar el video con fondo de color**, verde o magenta. Es el
   arreglo de verdad, y ademas hace innecesario casi todo lo de arriba.

Si algun dia el fondo no es liso, esto no sirve y toca recortar a mano.

## Varias animaciones del mismo personaje

Cada animacion se procesa por separado, pero **todas tienen que compartir casilla
y linea de suelo**. Si cada una calcula su encuadre por su cuenta, el personaje
pega un salto en pantalla al pasar de estar quieto a correr.

El problema no es el tamano de la casilla, es donde cae el suelo: cada video tiene
el suelo en una fila distinta del original. Por eso `centrar.ps1` tiene
`-MargenSuelo`, que mide el suelo de cada animacion en su propio video y lo ancla
siempre a la misma altura dentro de la casilla.

```powershell
.\centrar.ps1 -Job magnus_corriendo  -Ancho 584 -Alto 688 -MargenSuelo 30
.\centrar.ps1 -Job magnus_respirando -Ancho 584 -Alto 688 -MargenSuelo 30
```

La casilla se hace **simetrica** alrededor del eje del tronco a proposito: al
voltearla con `flip_h` para andar hacia el otro lado, el personaje no se desplaza.
Por eso el ancho sale del semiancho mayor por dos, aunque el abrigo ocupe mas por
detras que por delante.

### Si la camara del video no se mueve

Entonces no hay nada que anclar: el **mismo recorte** en todas las animaciones ya
las deja registradas fotograma a fotograma. Para eso estan `-Eje` (eje horizontal
fijo) y `-Techo` (fila superior fija), las dos en pixeles del video original:

```powershell
.\centrar.ps1 -Job aracnobat_andando -Ancho 1168 -Alto 704 -Eje 640 -Techo 16
.\centrar.ps1 -Job aracnobat_volando -Ancho 1168 -Alto 704 -Eje 640 -Techo 16
```

Ademas de ser mas simple, sale **mejor**: medir el eje en cada fotograma de un
bicho que esta quieto solo mete temblor (+-6 px de puro ruido de medida en el
aracnobat), y si la silueta cambia mucho de una animacion a otra -- una araña
que saca alas -- el "tronco" que mide `centrar.ps1` deja de ser lo mismo y el
cuerpo pega un salto lateral.

Los numeros de cada personaje se guardan en `raw/master_mason/anim/<personaje>_comun.txt`,
con el porque de cada uno. Para comprobar que dos animaciones quedan alineadas:
el pie mas bajo debe tocar la misma fila en ambas, y el eje del tronco quedar en
el centro de la casilla.

Si entra despues una animacion mas alta (un salto), no cabra y habra que subir el
alto y **re-procesar tambien las anteriores**. Son dos comandos por animacion.

## Retocar fotogramas sueltos

Se retoca en **`04_limpios`**, que es el master a 584x720 con alfa. No en la hoja
ni en `03_seleccion`.

**Primero: mira si el fallo se arregla con un parametro.** Parchear 39 fotogramas
es lento y ademas el parche muere en cuanto se reprocesa el job; cambiar un umbral
son dos minutos, lo arregla en todos a la vez y queda reproducible. Restos de
croma casi siempre se resuelven subiendo `-Tolerancia` o bajando `--derrame`; un
ribete de color, subiendo `-Radio`. El parche por fotograma es solo para lo que
ninguna regla pilla: arte mal generado, una sombra rara, un trozo que falta.

### Que hace falta para pedir un arreglo

El numero de fotograma de `05_salida/revision_sobre_oscuro.png` (esos numeros son
los nombres de archivo: el 12 es `c_12.png`), donde esta la zona (mano, pie,
barba, bajo del abrigo, entre las piernas) y que le pasa. Con eso la zona se
localiza midiendo, no hace falta dar coordenadas.

### Los parches tienen que quedar anotados

Un parche aplicado a mano sobre `04_limpios` **desaparece** si luego hay que
volver a pasar `centrar.ps1` o `fondo.ps1`. Asi que cada arreglo por fotograma se
apunta en `retoques.txt` dentro del job, con lo que se hizo y donde, para poder
reaplicarlo. Si son mas de dos o tres, mejor convertirlos en un script del job.

### Si alguna vez se toca en GIMP

Abrir `04_limpios/c_NN.png` (la capa ya tiene alfa), varita magica, difuminar la
seleccion 1 px antes de borrar, y guardar con **Archivo -> Sobrescribir**. Sin
aplanar (se pierde el alfa) y sin tocar el tamano del lienzo: tiene que seguir
siendo 584x720 en todas, y si una cambia `hoja.ps1` aborta y dice cual.

### Despues de cualquier retoque

Reexportar. No hay que volver a keyear ni a centrar:

```powershell
.\hoja.ps1  -Job <job> -Cols <n> -Fps <n> -Escala 2
.\ciclo.ps1 -Job <job> -Desde 04_limpios -Fps <n> -Fondo 14100E
```

### Las redes que hay

`fondo.ps1` se niega a procesar imagenes que ya tienen alfa y `centrar.ps1` se
niega si `04_limpios` no esta vacia. Ademas cada job guarda dos copias que ninguna
herramienta pisa:

  _con_fondo/04_limpios/   los sprites con el croma puesto
  _sin_fondo_auto/         los sprites keyeados, antes de cualquier retoque

**Retocar lo ultimo.** Si despues hay que cambiar la casilla comun -- por ejemplo
porque entre una animacion mas alta -- hay que volver a pasar `centrar.ps1` con
`-Sobrescribir` y los retoques se pierden. Conviene tener cerradas las medidas del
personaje antes de ponerse.

## Reducir para el juego

Los sprites de `04_limpios` son el **master**: se quedan a resolucion completa,
con el keyeado y el retoque a mano. La reduccion se hace **al exportar la hoja**,
con `-Escala`:

```powershell
.\hoja.ps1 -Job magnus_corriendo -Cols 6 -Fps 24 -Escala 2
```

Asi, si mas adelante hace falta otra escala, se reexporta en un comando sin
repetir keyeado ni alineacion.

Por que no se hace en Godot: poner `scale` al nodo **no ahorra memoria**, la
textura se carga entera igual. Y el PNG comprime pero la textura en VRAM no: son
ancho x alto x 4 bytes. Las tres animaciones de Magnus a resolucion completa eran
22 MB en disco y **218 MB en memoria de video**; a la mitad, 5,9 y 54,5.

Dos cuidados:

- **Premultiplicar antes de reducir.** Los pixeles transparentes conservan el
  color del croma en su RGB, y al interpolar se cuela en el borde. Medido sobre
  un fotograma: sin premultiplicar 238 px con tinte verde, con ello 102.
  `hoja.ps1` ya lo hace.
- **La casilla tiene que dividir exacta.** Si no, `hoja.ps1` aborta: redondear
  desplazaria el eje del personaje y se perderia la alineacion entre animaciones.
- **El margen transparente dentro de la casilla es lo que separa el atlas.** Las
  casillas se pegan sin hueco, y Godot promedia bloques de la hoja entera al
  generar mipmaps, asi que si el personaje llega al borde de la suya se mezcla
  con la vecina. El margen aguanta mientras el texel del mipmap mida menos que
  el: M px de margen dan atlas limpio hasta 1/M de escala. `hoja.ps1` lo mide al
  terminar (`_margenes.py`) y avisa si baja de 8 px. En magnus el mas justo son
  12 px, de sobra. Si salta el aviso: agrandar la casilla en `centrar.ps1`, o
  importar esa hoja sin mipmaps.

## Llevarlo a Godot

Para Magnus no se hace a mano: se anade la animacion a `ANIMACIONES` en
`_spriteframes.py` y se corre `python _spriteframes.py <destino.tres>`. Empaqueta
cada rejilla de `05_salida` en un atlas con los fotogramas recortados a su dibujo
(`empaquetar.py`), lo deja en el juego con el nombre de la hoja, pone el `.import`
con compresion BC7 y mipmaps, y escribe el `SpriteFrames` con el `margin` de cada
fotograma, que es lo que lo devuelve a su sitio dentro de la casilla. Cuesta un
10 % de lo que costaba la rejilla sin comprimir. Detalle en
`docs/sprites_magnus.md` (del proyecto), "Escala: memoria de video".

**Antes de darla por buena**, `python revisar.py`: recorre todas las animaciones
de `ANIMACIONES` como las dibuja el juego y avisa de fotogramas que no casan con
sus vecinos, cierres de bucle, pies que se hunden o flotan de golpe, temblor del
tronco, dibujo recortado en el borde, motas y restos de croma, y mide los enlaces
que encadena `magnus.gd` (pose, suelo, eje y color de la tunica). Si se anade un
enlace nuevo en el codigo, se anade tambien a `ENLACES` en `revisar.py`. Correr y
saltar dan avisos de suelo y de eje por su propio movimiento: lo que importa es
lo que cambia de golpe en una animacion que va lenta, y los enlaces marcados con
`<-`. `--tiras <carpeta>` deja una tira de fotogramas por animacion para mirarla.
Las motas sueltas se quitan con `python motas.py <job>/04_limpios` (copia en
`_sin_motas/`).

A mano, para otra cosa: `05_salida\<job>_sheet.txt` trae `hframes`, `vframes` y
el tamano de casilla. En el editor: `AnimatedSprite2D` -> `SpriteFrames` -> *Add
frames from sheet*, con esos valores, y coger solo los primeros N fotogramas.

## Reglas que muerden

- **Todas las casillas deben medir igual.** `hoja.ps1` aborta y dice cual se sale.
- El video de IA no mantiene al personaje consistente entre fotogramas: cuenta con
  repasar a mano en `04_limpios`, no es copiar y pegar.
- `frames.ps1` y `elegir.ps1` **vacian** su carpeta de destino antes de escribir
  (`frames.ps1 -Conservar` lo evita). No guardes trabajo a mano en `01_frames`
  ni en `03_seleccion`: el tuyo va en `04_limpios`.
- `centrar.ps1` tambien vacia `04_limpios`, pero se niega si ya hay algo dentro:
  para rehacerlo hay que pasarle `-Sobrescribir`. Asi no se lleva por delante
  un retoque tuyo sin avisar.
- `centrar.ps1` necesita **python** en el PATH (solo para medir la silueta;
  no usa ninguna libreria, los pixeles se los pide a ffmpeg).
- El centrado se ancla al **tronco**, no al conjunto: si se anclara al centro de
  todo, las piernas al abrirse desplazarian al personaje y bailaria.
- `fondo.ps1` guarda copia en `_con_fondo\` la primera vez y **no la pisa nunca**
  en ejecuciones posteriores. Tambien necesita python.
- `sombra.ps1` escribe **encima de `03_seleccion`** y guarda copia en
  `_con_sombra\`, que tampoco pisa nunca. Volver a pasarlo sobre lo ya aplanado
  quita mas detalle: para repetirlo con otros parametros, restaurar antes desde
  `_con_sombra\`. Necesita python.
- Para previsualizar sprites con alfa, `ciclo.ps1` necesita `-Fondo <hex>`: el GIF
  solo admite transparencia de un bit. Con `-Formato apng` se conserva el alfa.
