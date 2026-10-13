# Crítica de producción de `guion_v1.md`

*Mirada de productor técnico: 1 persona + IA, Godot 4 en 2D, animaciones sacadas de vídeo de IA, GPU justa (el bosque congelado va a 23-43 FPS). No se quita ambición: se busca dónde cuesta y cómo pagarlo.*

## 0. Diagnóstico

1. El guion pide unas **6 h 20 min**, **12 posesiones**, unos **35 escenarios**, **15 animaciones nuevas del peregrino** y **6 personajes animados**. El objetivo realista es **3,5-4 h** con la misma historia.
2. Lo más caro son las **cámaras**: en 2D, «rotar 90°» obliga a pintar el mismo sitio otra vez. Cada lugar visto en lateral y en frontal cuesta el doble.
3. El mundo del guion **se abarata solo**: el bosque se repite (es un azulejo), el hijo «se mueve como marioneta» (recortable por código), el bufón solo se mueve cuando no se le mira (poses fijas), la ciudad «está pintada» y la geometría imposible sale gratis con un corte en 2D.
4. **Argos es la gran inversión.** Con 5 vídeos y capas por código tiene alma (§3).
5. **Dóminus ya existe como NPC facetado hecho por código.** Mantenerlo como títere de código es más barato y más coherente que pedirle vídeos.

## 1. Activos por capítulo

Coste: **B** = código, reutilización o una ilustración · **M** = 1-2 vídeos, un escenario con capas o un sistema pequeño · **A** = varios vídeos, escenario grande, sistema nuevo o cinemática compleja.

| Cap. | Peregrino (nuevo) | Otros personajes | Escenarios | 1ª persona / posesión | Sistemas que estrena | Coste |
|---|---|---|---|---|---|---|
| 1 | **Clavar/arrancar (A)**; flotar (en curso); coger en el aire (truco) | **Argos: presentación (A)** | Claro (existe), raíz en el haz (B), talud (M), sendero (M); bosque y casa (congelados) | — | RealityState, báculo, cono rojo con gravedad, hojas-plataforma, Argos que sigue | **A** |
| 2 | Cojear (truco) | Hijo títere (M), arpía (M), bufón en poses (B), gárgola (B) | Cuarto (M), **riachuelo único** (M), calvero de estrellas (M) | — | Elección de diálogo (existe), llamar y eco, unir estrellas, **blanco**, guardado en marcas | **M** |
| 3 | — | Quimeras en bucle corto (M), bufón abre la cola (M) | Linde (M), pasillo de robles (M), roble (M), ciénaga (M) | **Balanza (M)**, hoja (B), gárgola (B), sapo (M) | **Mesa, posesión, 3ª tensa, «lo iluminado se para»**, elección de la vara | **A** |
| 4 | Esconderse (existe) | Dóminus sonámbulo (títere, M) | Pasillos ×2 (M), cuarto de Dóminus (M), sótanos (M), barranca (M) | Polilla (M), **rana (A)** | **Verde**, velas como recarga | **A** |
| 5 | **Empujar (A)** | Oso (M), Dóminus y el péndulo (B) | Mesa (existe), río (reutilizado), claro del barro (B) | Pez y Eco (M), **Argos con olfato (M)**, oso (B) | **Transición a Peso en vivo**, reflejo de Eco, tallar | **A** |
| 6 | Mirar al sol (truco); correr de frente (ojo, §2) | Arpía cazando (M) | Bosque anacrónico (M), nido (M), tormenta (M) | **Carboncillo (A)**, cigüeña (M), arpía (M) | **Dorado** (capa de costuras), persecución | **A** |
| 7 | Arrodillarse (M); **trepar (A)** | Mujer (fija, B), planta-león (M) | Cruces (reutilizado), **río en balsa (A)**, cauce seco (M) | Manos (M), cigüeña (B) | Balsa, sequía que persigue, frases de Eco | **A** |
| 8 | Cavar y verter (trucos) | Hijo (títere, M), Dóminus en la cena (M) | Fosa (B), setas (M), cocina (M), cuarto del niño (B), túmulo (B) | Topo (B) | **Construir el arco**, bucle de la noche | **M-A** |
| 9 | Bastón (reutilizado) | **Argos tricéfalo (A)**, carnaval (M) | Desfiladero (M), **torreón construible (A)**, sótanos retocados (B) | Argos en tres franjas (M) | **Construcción por hiladas**, aliados, negro | **A** |
| 10 | **Arrastrarse (A)**; perder los brazos (máscara, B) | Desapariciones (M) | Ruinas (M); claro, torreón y ataúd (existen) | Pliego (B), ataúd (existe) | Pérdida de controles, dos finales | **M-A** |

## 2. Lo caro y su truco

### 2.1 Peregrino: de 15 vídeos a 6

**Seis vídeos imprescindibles:**
- **Clavar/arrancar.** Un solo vídeo «sacar, clavar, soltar, volver, arrancar», que empiece y acabe en el reposo con báculo. Arrancar no puede ser el mismo vídeo al revés: se notaría.
- **Empujar.** Ciclo cerrado (inicio = fin). Sirve para el péndulo, los troncos, la balsa, los sillares y el oso.
- **Trepar un borde.**
- **Arrastrarse.** Es el último plano del juego y no admite trampas.
- **Arrodillarse** (entrada y reposo). Se usa en cinco escenas.
- *(Opcional C)* **Taparse del sol.**

**Lo demás, con trucos:**

| Lo que pide el guion | Truco |
|---|---|
| Canalizar | Reposo con báculo, el báculo (que es un sprite aparte) inclinado por código y brillo del orbe por shader. |
| Coger el báculo en el aire | En el pico del salto el báculo **vuela solo a la funda**, como bajó, como una pluma. Más poético y sin vídeo. |
| Coger del suelo | Agacharse y el objeto vuela a la mano. |
| Colocar sillar | Empujar hasta la marca; encaja con un golpe y polvo. |
| Jadear de pie | Reposo con la respiración por esfuerzo que ya existe. |
| Caer al agua | Salpicadura, tumbado y un shader que oscurece la túnica mojada. |
| Cavar, tallar | Elipsis: 1 s a negro con el sonido. Tallar en 1ª persona con las manos del ataúd. |
| Andar con bastón (Bronce) | El andar con báculo v2 ya apoya el báculo al paso. Ralentizado a 0,8 (ralentizar no salta). |
| Andar con báculo de frente y de espaldas | **Ya existe** (secuencia frontal del 2026-10-08). Se quita de la lista. |

### 2.2 Escenarios

- **El bosque es un módulo** de 3 pantallas con tinte por hora (el bosque congelado ya lo hace). Sirve para los caps. 2, 3, 6 y 7, y las «heridas iguales» salen gratis.
- **El riachuelo con la piedra-corazón es una sola escena con parámetros** (hora, caudal, voz, seco, mudo, arco). Siete usos.
- **Los sótanos del 4 se reutilizan en el 9** cambiando una capa de dibujos. Los pasillos imposibles (4.2) son un corte a otra composición, sin rotar nada.
- **Midjourney para lo que se ve una vez** (nido, ciudad, carboncillo, cara) y **código para lo que se pisa**.

### 2.3 Primera persona: la fórmula del ataúd

Ilustración grande, marco propio, uno o dos ejes de movimiento y un shader. Sin animar personajes.
- **Hoja:** ilustración cenital que gira y se acerca.
- **Gárgola:** panorámica sobre una pintura y luciérnagas de partículas.
- **Sapo:** capas bajo el agua con tinte verde.
- **Polilla:** shader de ojo compuesto y una fuerza que tira hacia la vela.
- **Rana:** solo bajo el agua, de lado y de sombra en sombra. Sin planeo.
- **Pez y Eco:** cáusticas y la cara de Eco como textura deformada. Es la escena más bella: merece el gasto.
- **Argos:** cámara baja, mundo desaturado y hilos de olor hechos con Line2D.
- **Oso:** marco de musgo y la pantalla tiembla al empujar.
- **Cigüeña:** el azulejo es literalmente una textura repetida en perspectiva por shader. Un activo para el 6 y el 7.
- **Arpía:** reutiliza esa textura y la imagen de la ventanita de la intro.
- **Topo:** pantalla negra y anillos blancos por shader. Es la más barata.
- **Argos tricéfalo:** **una sola vista** que un shader parte en tres franjas. Tres viewports no los aguanta la GPU.

### 2.4 Cinemáticas

- **Carboncillo (6.2):** teatro de papel. Cuatro o cinco láminas con parallax y el niño como **recortable** jugable; el fuego, por shader y del rojo del orbe. Escalar el sprite del peregrino a niño no sirve: anda como un viejo.
- **Derrumbe (10.4):** si la casa del generador es de piezas, se cae con tweens hacia el centro y polvo. Si es una sola imagen, se trocea con polígonos.
- **La cara (10.5):** dos ilustraciones con el mismo encuadre (Iram y el niño), y el paso de una a otra por desplazamiento, **no por fundido**: el usuario rechaza las imágenes dobles.
- **Borrado del mundo (10.6):** disolución por capa y árboles que «caen» escalando en Y, con el revés de tela.

## 3. Argos: alma con 5 vídeos

**Principio.** Argos se ve **de perfil, en lateral**. En los planos frontales o tensos va pequeño, al fondo o fuera de plano (jadeo, uñas). Sus dos escenas cumbre (5.5 y 9.6) son desde dentro, en 1ª persona, y no necesitan animación.

**Cinco vídeos de pantalla verde**, todos empezando y acabando en el mismo fotograma de referencia, como ya funcionó con la túnica:
1. Reposo, andar, trotar y parar.
2. Correr en ciclo. Con un arco por código sirve también para el salto bajo.
3. De pie, sentarse, tumbarse y reposo tumbado respirando.
4. Olfatear andando con la cabeza baja.
5. Ladrar y escarbar.

Salen unas 11 animaciones.

**Por código:**
- **La cola como capa aparte**, como el báculo: el meneo, la cola baja y **el golpe único de 9.7**. La cola es su cara.
- **El envejecimiento** (shader de canas que sube desde el hocico, ojos nublados) y el pelo blanco del cap. 5.
- **Apoyarse en Iram:** colocar el reposo pegado a él.
- **Tricéfalo:** dos cabezas de cachorro recortables, ancladas al cuello y seguidas como el báculo, con 3-4 fotogramas de mordisco y un shader violeta en las costuras.

**Inteligencia artificial.** Sigue con retraso y espera en los bordes que no puede saltar. Si se queda fuera de cámara más de 2 s, reaparece entrando por el borde.

**Los demás personajes, sin vídeo:**
- **Dóminus y el hijo:** títeres de código.
- **Bufón:** cinco poses fijas y un bucle de cola.
- **Arpía:** recortable con alas torpes.
- **Cigüeña:** silueta en vuelo cíclico.
- **Mujer, carnaval y planta-león:** poses fijas con un shader de respiración.

## 4. Sistemas y orden de construcción

1. **`RealityState`.** Presets de gravedad, salto, carrerilla, aliento, daño por caída y sostén de las hojas, con transición interpolada. Magnus ya expone casi todo como variables. Va primero porque es la tesis del juego.
2. **Estado y guardado.** Flags de las elecciones, afecto, orbes y capítulo; las marcas blancas son los puntos de guardado. Cuanto antes exista, menos se rehace.
3. **Báculo** (el prototipo ya tiene los estados NINGUNO, ESPALDA y MANO), la **rueda de orbes** y **clavar** (un nodo de efecto en un radio).
4. **Cono rojo:** shader, un `Area2D` de gravedad y el grupo `se_para_con_luz`.
5. **Pensamientos y diálogo** (existen), más llamar y la respuesta de Eco.
6. **Director de cámaras.** En 2D, «rotar» es cortar a otra composición con un barrido.
7. **Argos compañero.**
8. **Posesión:** un anfitrión que tumba el cuerpo, pone a Argos de guardia, hace zoom, carga la escena del recipiente encima y devuelve el control con su coste. Se empieza por la hoja.
9. **Mesa-balanza:** interfaz de cartas, dosis y ventanas de lección.
10. **Efectos de los orbes:** blanco, verde, dorado y negro.
11. **Construcción por rejilla** (el arco y el torreón).
12. **Final:** pérdida de controles y un **modo nuevo de la cucaracha**, sin tocar el de la intro.

Todos los shaders de pantalla van en un `SubViewport` a 1/2 o 1/4, como el fondo de la hojarasca.

## 5. Orden de producción

**Fase 0 — Cerrar el cap. 1.** Ya va por la mitad. Faltan el flotar, las hojas-plataforma, el báculo, clavar y la presentación de Argos, y enlazarlo con el bosque congelado. Al terminar, **se juega del ataúd a la puerta de la casa**.

**Fase 1 — Rebanada vertical: el cap. 3, recortado a unos 25 min.** Es el que más prueba con menos dependencias:
- la mesa-balanza y una transición de estado;
- la 3ª persona tensa con «lo iluminado se para»;
- tres posesiones de dificultad creciente (hoja, gárgola, sapo);
- Argos guardando el cuerpo, el hijo títere y el bufón en poses;
- el río repetido con Eco, una elección guardada (la vara) y el parpadeo del bronce.

Para el paso a Peso, que el cap. 3 no tiene, se mete un **interruptor de depuración Fábula ↔ Peso** en el río. Así el salto testigo se ajusta desde el principio.

**Fase 2 — La subida:** caps. 2, 5 y 4. **Fase 3 — El centro:** cap. 6. **Fase 4 — La bajada:** caps. 7 a 10. La estructura en anillo reutiliza los lugares, así que **el anillo es también un plan de producción**.

Cada fase se graba con el movie writer y la ve el usuario antes de seguir.

## 6. Si falta tiempo: qué cortar

En orden:
1. **Polilla (4.3).** El dibujo de Argos ya sale en el sótano 1.
2. **Rana (4.4).** La argolla la saca el hijo.
3. **Posesión de la arpía (6.6).** Solo se la deslumbra, y desaparecen sus ramas en los caps. 7, 8 y 10.
4. **Segunda cigüeña (7.8).** La ciudad pintada se ve con el dorado desde el suelo.
5. **La mujer y la capa (7.4).** Se queda una sola versión del último charco.
6. **Oso (5.8).** El tronco lo empujan Iram y Argos.
7. **Carboncillo no jugable (6.2):** láminas y voz en off. La ventanita se mantiene.
8. **Balsa (7.6):** un tramo de 2 minutos que avanza solo.
9. **Torreón (9.3):** dos días en vez de tres.
10. **Carnaval (9.2):** un solo desfiladero.
11. **Lecciones en orden fijo** (5.1 y 7.2).
12. **El caballito y los rasgos de la cara del hijo.**

**No se cortan nunca:** el claro y el báculo, la mesa, Eco (5.3, 6.8, 7.7), la sopa, Argos (9.5-9.7), el derrumbe, la cara, el ataúd y los dos finales. Con los recortes 1 a 8, el juego queda en **unas 4 h** y con la historia entera.

## 7. Contradicciones con lo que existe o está congelado

1. **El claro no hace fundido (1.2).** Lo que existe es un **mundo que da la vuelta**, con una copia de Magnus junto al borde.
2. **Árboles en el claro (1.1, 1.4).** El usuario **rechazó** los árboles de las esquinas, el primer plano y la franja delantera fija. El «tronco caído» debería ser una raíz o un montículo de hojarasca a ras de suelo.
3. **La salida del claro.** El pendiente del usuario era un **torbellino que se lleva las hojas y descubre el camino**, y el guion lo cambia por «el haz se abre». Conviene quedarse con su torbellino.
4. **Doble caída (1.11).** `bosque.tscn` **empieza con Magnus cayendo del cielo**. Enlazarlo obliga a tocar la escena congelada (quitar la caída y el cartel «Fin de la demo»). Hay que **pedir permiso**, o cargarla desde una escena envoltorio que se salte la caída.
5. **La casa congelada (1.12, 2.1).** Ya tiene su cámara, su recorrido, **su elección de nombre** y el diálogo hasta «Iram». El guion redefine el plano y **añade a Argos y el humo del péndulo**. Propuesta: el encuadre del cap. 8 es el que ya existe, y Argos y el humo van en capas de un envoltorio.
6. **La sombra.** El guion dice «sin sombra hasta el nombre», pero la hojarasca ya tiene **sombra de contacto**. Propuesta: lo que nace en 2.3 es la sombra en la pared. En 10.6 se quitan las dos.
7. **Respiración constante en Bronce.** Va contra lo que pidió el usuario. Mejor un umbral casi nulo, pero que se vaya en reposo.
8. **Trucos del §5.1 del guion.** «Andar de frente acelerado» y «agacharse en bucle» rompen la regla de las animaciones (no acelerar más de 1,25× y no hacer bucles con lo que no es cíclico).
9. **Flotar.** Que mantener el botón suba más vale solo si se escala el arco por código. Nada de congelar fotogramas ni de cargar el salto de parado, que se rechazó.
10. **Báculo al tumbarse (1.7).** El sistema de la espalda no está probado sobre tumbado. El báculo que vuela a la funda **después** de levantarse lo evita.
11. **La araña que baja por su hilo (10.8).** El usuario recortó tres veces su movimiento. Propuesta mínima: el hilo que brilla y la araña bajando un palmo. Enseñárselo antes de darlo por bueno.
12. **La cucaracha que se va (final B).** El controlador de la intro está hecho para volver al puño. El final necesita un modo nuevo.
13. **Cicatriz en la ceja (§6.11 del guion).** A tamaño de sprite no se ve, y pedirla ahora haría incoherentes los vídeos anteriores. Basta con la capucha y la barba; la cara de 10.5 es una ilustración nueva.
14. **Volumen de texto.** Hay bastantes diálogos de Dóminus (2.1, 5.9, 6.3, 6.7, 7.2). Conviene repasarlos con el usuario: su norma es «muy pocos textos».
