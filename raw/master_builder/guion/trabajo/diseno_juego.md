# Master Mason: sistema de juego y banco de puzles

> Propuesta de diseño. La historia la escribe otro agente; aquí van las mecánicas al servicio de un tema: **el conocimiento vuelve real el mundo y destruye la inocencia**. Al principio el jugador lo puede todo y no sabe nada; al final lo sabe todo y casi no puede moverse. Esa curva tiene que notarse en las manos antes que en los textos.

---

## 0. Tres principios que mandan sobre todo lo demás

1. **Lo que el peregrino aprende, el mando lo pierde.** Cada lección importante cambia los números del control: gravedad, altura del salto, carrerilla, aguante, daño por caída. No se avisa con texto: se nota en el siguiente salto.
2. **Báculo en mano: magia o cuerpo, nunca los dos.** Con el báculo en la mano el peregrino solo anda y usa poderes. Para saltar o correr tiene que guardarlo, o **clavarlo** en el suelo y dejar allí su efecto. Casi todos los puzles giran alrededor de esa decisión: ¿dónde dejo la magia mientras mi cuerpo hace lo demás?
3. **Nada surge de la nada.** Los poderes no crean, transforman lo que ya hay: hojas, piedras, animales, luz. Si en una sala no hay materia, no hay solución mágica. Es la frase del padre de Dóminus convertida en regla de diseño, y sirve de pista silenciosa: si un objeto aparece en escena, sirve para algo.

---

## 1. Verbos del jugador

### 1.1 Verbos que ya existen (animaciones hechas)

| Verbo | Sin báculo / báculo a la espalda | Báculo en la mano |
|---|---|---|
| Andar, arrancar, parar | sí | sí (más despacio; en los estados IV-V se lee como bastón de viejo) |
| Correr (con carrerilla que alarga el salto) | sí | **no** |
| Salto parado / andando / corriendo, altura variable | sí | **no** |
| Agacharse, andar agachado | sí | no (hay que guardarlo para pasar por huecos bajos) |
| Girar de pie y agachado | sí | sí (giro con báculo) |
| Andar de frente / de espaldas / en diagonal | sí | sí, con andar con báculo en esas cámaras si hay vídeo; si no, se evita |
| Tumbarse / levantarse | sí | se suelta el báculo |
| Sacar / guardar báculo | — | — |

### 1.2 Verbos derivados, sin animación nueva o casi

- **Coger / dejar objeto pequeño:** agacharse + un fotograma de mano; el objeto se pega a la mano o a la funda. Sirve para piedras-llave, frambuesas, legajos.
- **Dormir / entrar en trance (posesión):** clavar báculo + **tumbarse**. El cuerpo queda en el suelo, que es justo lo que pide la vulnerabilidad.
- **Caer y hacerse daño:** tumbado + levantarse más lento (con respiración fuerte). En el estado IV el levantarse se ralentiza y se le suma una cojera de unos segundos (andar con báculo como bastón).
- **Esconderse:** agacharse detrás de un objeto en primer plano en las escenas tensas. El orbe se apaga solo al agacharse, y eso enseña el sigilo.
- **Mirar:** en lateral, mantener arriba = el peregrino se para y la cámara se desliza hacia donde mira. En 3ª persona, apuntar con el orbe.

### 1.3 Verbos nuevos imprescindibles (ver Producción)

- **Clavar el báculo / arrancarlo.** Es el verbo central del juego: deja el orbe activo en un sitio y libera el cuerpo. Una vez clavado, el poder sigue funcionando en un radio y el peregrino puede guardar las manos y saltar. Arrancarlo exige volver hasta él. Se enlaza con la maqueta anterior (tirar del báculo clavado → nace el sol).
- **Agarrarse a un borde y subir.** Hace falta en cuanto el salto encoge (estado III). Es el verbo de la vejez: donde antes se volaba, ahora se trepa con esfuerzo.
- **Empujar / arrastrar piedra.** Es el verbo del cantero, para los puzles de construcción.
- **Alzar el báculo (canalizar).** Es el gesto de usar el poder. Se puede abaratar con el reposo con báculo más un brillo del orbe, pero un gesto propio vende muchísimo.

### 1.4 La decisión báculo/cuerpo como sistema

Alternativas que he considerado:
- (a) Que el báculo se lleve siempre en la mano y los poderes no tengan coste: se pierde la tensión.
- (b) Que los poderes gasten maná: es un HUD, y no encaja con el tono.
- (c) **Elegida:** el coste es el **cuerpo**. Mientras haces magia no te mueves bien, y si clavas el báculo para moverte la magia queda atada a un punto. A eso se suman dos costes que crecen con la realidad: el **aliento** (la respiración por esfuerzo que ya existe se dispara al usar orbes desde el estado III) y la **vulnerabilidad** (en una posesión el cuerpo duerme).

El juego enseña esto en el capítulo 1 sin palabras: la luz baja ligera, y con el báculo en la mano el jugador pulsa saltar y no pasa nada; el peregrino solo mira arriba. Guarda el báculo y salta.

---

## 2. La física que cambia: cinco estados de realidad

La idea es que el mundo de Dóminus es un sueño que se va llenando de leyes. Cada estado se activa con una **lección** que el jugador da en la mesa (ver puzles de lecciones), así que es el propio jugador quien, con su mano, se quita los poderes. Esa es la culpa mecánica.

He tanteado varias formas de medir la realidad: una barra visible (rechazada, sobra), solo narrativa (rechazada, no se siente), y la **elegida**: los números del controlador cambian por estados y además hay **señales ambientales** que marcan cada estado (el péndulo, el color de la luz, el sonido de las pisadas, las sombras).

| Estado | Nombre | Capítulos | Lo activa | Gravedad / salto | Cuerpo | Señal en el mundo |
|---|---|---|---|---|---|---|
| I | **Pluma** | 1-2 | (inicio) | Dentro de la luz, gravedad lunar (0,35 g): el salto dura el triple y se puede encadenar en hojas. Fuera de la luz, gravedad normal amable. | Sin daño por caída, sin cansancio. Las hojas que caen sostienen. | Sin sombras propias; las pisadas suenan amortiguadas; el péndulo de la casa va solo. |
| II | **Fábula** | 3-4 | Primera lección (los animales inventados, las quimeras) | La luz lunar solo existe en "manchas de luz" concretas. Salto amplio de plataformas clásico (como Ori). | Caer de muy alto: tumbado + levantarse, sin daño. Solo las hojas doradas sostienen. | Aparecen las criaturas; las sombras son blandas y se mueven un poco tarde. |
| III | **Peso** | 5-6 | Lección de Newton (el péndulo se para) | Gravedad real. El salto se queda en un 75 %; sin carrerilla no se llega. Ya no hay luz lunar: la luz solo ilumina. | **Aparece la respiración por esfuerzo** como recurso: después de dos carreras seguidas el peregrino frena. Caída alta = 2 s de cojera. | Al péndulo hay que empujarlo cada mañana (es una acción del jugador). Las hojas caen a plomo. |
| IV | **Medida** | 7-8 | Lección de Euclides (la casa cruje) | El salto se queda en un 55 %; la altura variable casi no se nota. Los bordes hay que trepar. | Caída alta = daño real: si caes dos veces seguidas, tumbado largo y fundido (muerte suave, se vuelve al último apoyo). Correr se acaba en 3 s. | La geometría imposible se cierra: los pasillos paralelos ya no convergen, las escaleras acaban donde deben. Las sombras son duras. |
| V | **Bronce** | 9-10 | La casa cae / el despertar | No se puede saltar. Solo se anda, y al final ni eso: desaparecen partes del cuerpo y del mundo. | Andar con báculo es andar con bastón. Respiración constante. | Las estrellas se apagan una a una; el sonido se vuelve metálico, el bronce del sarcófago. |

### 2.1 Que la pérdida se sienta en las manos: el "salto testigo"

Hay **un mismo hueco** que el jugador cruza en tres momentos del juego: el **riachuelo de la piedra-corazón**. Mide siempre lo mismo (unos 4 cuerpos de ancho, con la piedra en medio).
- **Cap. 1-2 (Pluma):** lo cruza de un brinco sin pensar, incluso de parado, y aterriza flotando.
- **Cap. 5 (Peso):** necesita carrerilla y pisar la piedra-corazón. Lo consigue jadeando.
- **Cap. 8 (Medida):** es imposible. Si lo intenta, cae al agua: tumbado, empapado, sonido real de agua fría. Para cruzarlo tiene que **construir**: colocar dos piedras y una losa, o un arco (ver puzle 24).

Más señales de la misma idea:
- La **primera hoja-plataforma** del cap. 1 reaparece en el cap. 7: una hoja dorada que el jugador intenta pisar por reflejo y que se le dobla bajo el pie.
- El **báculo**: en el cap. 1 baja por la luz como una pluma. En el cap. 9 el peregrino se apoya en él para andar.
- El **sonido**: las pisadas suenan más fuertes en cada estado (hay que tocar las capas de audio, no hacen falta animaciones).

### 2.2 Ajuste técnico (para programar)

Hay un único recurso `RealityState` con los parámetros: gravedad dentro y fuera de la luz, velocidad inicial del salto, multiplicador de carrerilla, segundos de carrera hasta jadear, altura de caída con daño, si las hojas son sólidas y el tiempo de coyote. Así cada estado es un preset y se puede afinar con calma. También conviene un "estado mixto" para las transiciones dentro de un capítulo: justo después de la lección de Newton, la gravedad sube durante unos 30 s mientras el péndulo frena.

---

## 3. Los orbes del báculo

El báculo tiene una garra que sujeta un orbe, y el orbe se cambia con una rueda (hasta 6 colores). Cada orbe nace de un **conocimiento** o de un **ser**: no se encuentra en un cofre, sino que se **gana con un acontecimiento de la historia**. Esa es la regla.

He descartado algunas ideas: el fuego (es demasiado de RPG y además tiene un eco feo con el padre quemado; mejor guardarlo para el final como horror, no como poder), el teletransporte (rompe los puzles de bosque infinito) y el tiempo hacia atrás completo (es demasiado Braid y demasiado caro).

### 3.1 Rojo, el Ánima (posesión). Primer orbe, cap. 1-2

- **Qué hace:** apunta a un ser vivo dentro del haz del orbe y mantén la acción. El peregrino clava el báculo y se tumba, y la cámara entra en **primera persona** dentro del ser.
- **Coste:** el cuerpo duerme junto al báculo clavado, que proyecta un pequeño círculo rojo. En los estados I y II el círculo protege. Desde el III solo **avisa**: si algo entra en él, el latido se acelera y se oye a lo lejos, y el jugador tiene que decidir si vuelve. Una posesión tiene un **límite de latidos** (unos 60-120 s, con un pulso de audio que se acelera al final). Si se agota, el peregrino despierta mareado (tumbado largo) y el animal queda asustado, y no se le puede volver a poseer en un rato.
- **Pérdida progresiva:** en el estado IV cada posesión le cuesta aliento al despertar (respiración fuerte de unos 5 s), y en el estado V ya no se puede usar porque "el mundo ya no le deja entrar". Esa es la última pérdida antes del final.
- **Volver:** se suelta la acción, o el ser se acerca a su cuerpo y sale. **Trae cosas de vuelta**: un objeto que el ser lleve (la rana trae una llave), un dato (lo que vio el pájaro queda marcado en el mapa mental como una marca de cantero luminosa) o un cambio físico (el oso movió la roca).
- **Por qué rojo:** sangre, vida, el ataúd (el puño contra el bronce). En la intro el jugador ya ha estado en primera persona y ha aplastado algo vivo. Ahora entra en lo vivo en vez de destruirlo, y es el arco moral del juego.

### 3.2 Ámbar, la Luz (linterna y gravedad lunar). Cap. 1 (implícito) y 3

- **Qué hace:** el orbe ilumina con un cono que se apunta con el stick. En el **estado I** el cono **lleva la gravedad lunar consigo**: donde da la luz, se flota. Ahí está el dilema de base. Para flotar hace falta la luz, pero con el báculo en la mano no se salta. La solución es **clavar el báculo apuntando** y saltar dentro del cono que se queda proyectado.
- **Escenas tensas (Alan Wake):** la luz hace que las criaturas "tímidas" se queden quietas, como el bufón-pavo real del relato, que se esconde cuando lo miras. La regla es la del relato al revés: **lo que miras se paraliza y lo que no miras se acerca**. Las sombras grandes retroceden ante la luz.
- **Coste:** en el estado I no tiene. Desde el III, el haz parpadea al correr la respiración (al guardar el báculo para correr, la luz se va) y hay que **recargarlo** ante una fuente de luz real (vela, chimenea, ventana). Esto enlaza con la intro: la luz por la ventanita del ataúd.
- **Pérdida:** en el estado III la luz pierde la gravedad lunar (Newton) y se queda en linterna. El jugador siente que la luz "ya no hace nada mágico".

### 3.3 Verde, la Semilla (crecer). Cap. 4, tras la lección de botánica / polinización

- **Qué hace:** acelera el crecimiento de lo que ya es planta: una raíz se vuelve rampa, una enredadera se vuelve cuerda (con el agarre a borde) y una semilla se vuelve tronco-puente. Se apunta a algo vegetal y se mantiene la acción: crece mientras se mantiene, y al soltar se queda así.
- **Combinación con plataformas:** se hace crecer una rama, se guarda el báculo, se salta encima. Con el báculo clavado, la planta sigue creciendo despacio y hay que darse prisa antes de que tape el paso.
- **Coste:** todo lo que creces **queda en el mundo**, y Dóminus lo ve. Si el jugador usa mucho el verde, aparecen variaciones monstruosas, como la planta-león. Es un coste narrativo y no punitivo: el mundo responde a lo que haces.
- **Eco con el hijo:** el niño tiene raíces en el pelo. En el cap. 6 el verde sirve para algo terrible: el entierro del hijo (ver puzle 17).

### 3.4 Azul, el Eco (memoria del lugar). Cap. 5, tras bajar al sótano y abrir el baúl

- **Qué hace:** muestra durante unos segundos lo que pasó en ese sitio, con siluetas azules: quién pasó, por dónde, qué movió. También **recompone por un momento** un objeto roto (un puente caído vuelve a estar, como un fantasma sólido, mientras el báculo esté clavado).
- **Uso principal:** el **bosque infinito**. Todos los claros son iguales, pero el eco no: en el claro verdadero se ve al peregrino de antes dejando una marca, al hijo, a Argos, a la arpía. El eco distingue lugares que la vista no distingue.
- **Coste:** cada eco devuelve **un recuerdo que no es suyo**: dibujos a carboncillo, la mano de un padre, una hoguera. Son fragmentos de Dóminus niño (del sótano 1 del relato). Con eso el orbe azul va contando a escondidas que el peregrino es Dóminus. Mecánicamente no cuesta nada; narrativamente lo envenena todo.

### 3.5 Blanco, la Plomada (fijar, medir, volver real). Cap. 7, tras aceptar ser cantero de Dóminus

- **Qué hace:** es el orbe del conocimiento. Traza con el báculo una línea (plomada, escuadra o compás, según la herramienta seleccionada) y lo que queda dentro de la medida **se vuelve real**: una hoja flotante se vuelve losa de piedra y cae, una escalera imposible se vuelve escalera de verdad (y desaparece el tramo que no cumple Euclides), un muro dibujado se vuelve muro.
- **Doble filo:** fijar soluciona puzles y **rompe cosas bonitas**. Una nube-puente se vuelve piedra y cae, una criatura mágica se vuelve animal común. En el cap. 9 este orbe es el que permite acabar con Argos-quimera (ver 3.8).
- **Coste:** físico. Cada fijación hace subir un poco el estado local: en una zona fijada el salto es del estado IV aunque el mundo esté en el III. El jugador **ve** que su herramienta pesa.

### 3.6 Violeta, el Injerto (combinar dos cosas). Cap. 6, opcional y potente

- **Qué hace:** se marca un objeto o ser A, luego un B, y el resultado tiene una propiedad de cada uno. Es "nada surge de la nada" hecho poder: con piedra y pluma sale una piedra que flota (un ascensor), con rana y llave una llave que nada hacia ti, con raíz y cuerda una cuerda que trepa sola.
- **Coste:** cada injerto **crea una quimera que se queda en el bosque**, vagando. A partir de cierto número, el bosque se vuelve "carnaval de pesadillas" (como en el relato) y aparecen enemigos menores en la zona. Es el poder de Dóminus en manos del jugador, y por eso Dóminus lo regala: le divierte.
- **Para producción:** es caro de arte. Puede quedarse en 5 o 6 injertos guionizados.

### 3.7 Gris, el Bronce (no es un poder). Cap. 10

El último orbe no se elige: el báculo se oscurece y el orbe se vuelve metal opaco. Al alzarlo solo se oye un golpe sordo contra algo, el puño contra el bronce. Es el puente mecánico con la intro.

### 3.8 Tabla de orbes

| Orbe | Capítulo | Nace de | Clavado deja… | Combina con plataformas | Coste |
|---|---|---|---|---|---|
| Rojo Ánima | 1-2 | El primer ser vivo que ama (Argos o el ave) | El cuerpo dormido | El ser hace lo que tu cuerpo no puede | Cuerpo vulnerable, límite de latidos |
| Ámbar Luz | 1 / 3 | El haz del claro | Un cono de luz fijo (lunar en el estado I) | Flotar en el cono; paralizar criaturas | Recargar en luz real desde el III |
| Verde Semilla | 4 | Lección de botánica | La planta sigue creciendo | Rampas, cuerdas, puentes | Lo que crece se queda y se pervierte |
| Azul Eco | 5 | El baúl del padre | Un fantasma sólido temporal | Puentes de memoria, rutas del bosque | Recuerdos ajenos (verdad envenenada) |
| Violeta Injerto | 6 | Regalo de Dóminus | — | Objetos con propiedades cruzadas | Quimeras en el bosque |
| Blanco Plomada | 7 | Oficio aceptado | La medida fijada | Vuelve sólido lo irreal | El mundo pesa más alrededor |
| Gris Bronce | 10 | El despertar | — | — | Es el fin |

---

## 4. Las posesiones (orbe rojo) en detalle

**Reglas comunes:**
- Cámara en primera persona con un viñeteado orgánico distinto por ser (plumas en el borde, ojos de rana con doble párpado, el compuesto de la polilla). Es la misma gramática que el ataúd: hay un marco y se ve el mundo a través de él.
- Controles mínimos de 2 o 3 acciones por ser, para que cada posesión se aprenda en 5 segundos.
- El **latido** marca la duración con un pulso de audio. No hay barra.
- Al salir hay un corte de 1 s a negro y se vuelve al cuerpo en lateral. Lo que se ha visto queda como **marca de cantero luminosa** en el escenario (un símbolo grabado que el peregrino sabe seguir).
- El cuerpo dormido está en peligro. Argos lo guarda mientras vive: es un compañero con función mecánica, y por eso su pérdida se nota en el juego.

### 4.1 La hoja que cae (cap. 1, tutorial de posesión)
- **Controles:** solo inclinarse a izquierda o derecha. No hay más.
- **Cámara:** la primera persona gira con la hoja; el mundo da vueltas despacio, como en la caída de hojarasca ya hecha.
- **Peligro:** ninguno. Dura lo que dura caer.
- **Qué ve:** el claro desde arriba y, por primera vez, que la luz es una columna y que fuera de ella hay bosque.
- **Qué trae:** sirve de enseñanza. Al aterrizar sobre el báculo, la hoja lo "señala", y el jugador aprende que poseer es mirar desde otro sitio. También es el primer momento en que siente **no tener control**: la inocencia.

### 4.2 El ave gigante del claro (cap. 2 y 7)
- **Controles:** batir (ganar altura), planear inclinándose y picado. Hay corrientes de aire visibles como hojas en espiral.
- **Cámara:** primera persona amplia, con las puntas de las alas en los bordes.
- **Peligro:** si sube por encima del techo del sueño, el cielo **se ve pintado** (se notan pinceladas) y el ave entra en pánico; la posesión se rompe.
- **Qué ve:** en el cap. 2, el bosque infinito desde arriba, **simétrico como un azulejo**, y la casa justo en el centro. En el cap. 7, al volar hacia la ciudad, descubre que es una mancha plana pintada sobre el valle (el relato: "no es más que una mancha en el paisaje").
- **Qué trae:** la ruta a la casa (cap. 2) y la certeza de que no hay salida (cap. 7). Es la misma posesión con dos verdades: la primera vez maravilla y la segunda desespera.

### 4.3 La rana alada que bucea (cap. 4)
- **Controles:** en superficie, saltitos y planeo corto con las alas. Bajo el agua, impulsos (se pulsa con ritmo de patada) y se abre la boca para coger algo.
- **Cámara:** al sumergirse, el sonido se apaga y la luz se vuelve verde. Los ojos de la rana dejan un doble párpado que parpadea.
- **Peligro:** el aire. La rana tiene que volver a salir, y los peces-buitre (buitrepeces) la rondan.
- **Qué trae:** la llave del sótano, o la argolla oxidada, del fondo de la ciénaga.

### 4.4 El sapo con antiparras (cap. 6, regalo del hijo)
- **Controles:** andar a saltitos y "ajustar antiparras": se ve en la oscuridad con una visión verdosa.
- **Peligro:** que lo pisen (pasos de Dóminus).
- **Qué ve:** el sótano 2 a oscuras y las marcas de la sopa (las setas) en la cocina. Es la posesión de la culpa: con ella el jugador descubre que la sopa estaba envenenada antes de que la beba el niño, o la ve después.
- **Qué trae:** información. Es lo que regala el hijo, y lo poseemos poco antes de perderlo.

### 4.5 El oso de musgo (animal grande, cap. 3)
- **Controles:** andar pesado, empujar (mantener contra el obstáculo) y rugir (las criaturas pequeñas huyen).
- **Cámara:** primera persona baja, con el hocico abajo y respiración pesada. El mundo tiembla un poco a cada paso.
- **Peligro:** es lento, y el latido corre.
- **Qué trae:** cambio físico: aparta el tronco caído que cierra el camino o tumba un árbol que hace de puente.

### 4.6 El pez del riachuelo (cap. 3, bosque infinito)
- **Controles:** solo dirección. La corriente arrastra.
- **Qué ve:** que **todos los riachuelos son el mismo riachuelo**. Al dejarse llevar, el pez sale por un riachuelo "distinto", que es el mismo con la piedra-corazón. Es la revelación del bucle desde dentro.
- **Qué trae:** la regla del bosque infinito: el agua da la vuelta, así que el camino no es seguir el agua.

### 4.7 El topo / gusano (cap. 5)
- **Controles:** cavar adelante y girar. La pantalla es casi negra, se oye la tierra y se "ve" con vibraciones (ondas blancas).
- **Peligro:** las raíces. Si toca una raíz del hijo, la oye canturrear.
- **Qué ve:** debajo de la casa, el sótano 2 desde fuera, y que la casa **no tiene cimientos**: flota sobre la tierra. Esa es la clave para entender que la casa no debería sostenerse, y le da al jugador la idea del torreón.
- **Qué trae:** un túnel por donde luego cabe Argos y una pista estructural.

### 4.8 La polilla y la vela (cap. 4, noche)
- **Controles:** revolotear en 3 ejes simplificados. La luz **atrae**: cuanto más cerca de una vela, más cuesta apartarse.
- **Peligro:** quemarse. Si toca la llama, la posesión acaba con un fogonazo y, por un fotograma, una imagen del padre en la hoguera. Es el primer destello del trauma.
- **Qué trae:** entra por la cerradura de la habitación de Dóminus y ve lo que hay en su mesa. Es un puzle de resistir la tentación: llegar sin tocar la luz.

### 4.9 Argos (cap. 5 en adelante)
- **Controles:** correr, saltar bajo, **olfatear** (las huellas olorosas se ven como hilos de color en el aire), escarbar y ladrar (para avisar y distraer).
- **Cámara:** primera persona baja, a la altura del perro. Los colores se apagan (visión canina) y los olores se ven brillantes.
- **Peligro:** su cuerpo duerme y no hay quien lo guarde.
- **Qué trae:** objetos de huecos donde el peregrino no cabe y rastros (encuentra al hijo, la ruta de la arpía, la tumba).
- **Última posesión (cap. 9):** ver puzle 27.

### 4.10 La arpía (cap. 7, posesión que se gana)
- **Controles:** vuelo torpe (no levanta bien, como la mujer-avestruz) y graznar.
- **Qué ve:** sus recuerdos. Mientras se la posee se oye una nana sin letra. Esto permite al jugador intuir que es la madre de Dóminus, y que él (por ser proyección de Dóminus) también es su hijo.
- **Qué trae:** paz con ella y la vía para que deje de cazarte. Es una alternativa a matarla, y se elige.

### 4.11 La gárgola del roble (cap. 3, posesión inmóvil)
- **Controles:** solo girar la cabeza.
- **Qué ve:** el camino entero desde arriba, en un solo ángulo. Es para un puzle de memorizar la ruta del bufón-pavo real.
- **Interés:** es la posesión de no poder moverse y prefigura el ataúd.

### 4.12 El hijo (cap. 6, se intenta y no se puede)
Cuando el jugador apunta al hijo con el orbe rojo, la pantalla se llena de **una cara sin terminar**, como si hubiera que dibujarla, y el orbe rebota. No hay nadie dentro: es un retrato sin terminar. Así se enseña sin texto que el niño no es una persona, y por eso duele más cuando muere.

---

## 5. Cámaras

### 5.1 Reglas

| Cámara | Cuándo | Por qué |
|---|---|---|
| **Lateral** | Moverse, saltar, puzles de física, viajes por el bosque | Es donde se lee la física; los estados de realidad se juzgan aquí. |
| **Frontal hacia cámara** (el peregrino viene hacia nosotros) | Soledad, descubrimiento (algo enorme detrás de él que él aún no ha visto), **persecuciones** (lo que huye viene hacia el jugador y lo que persigue está al fondo) | El jugador ve antes que el peregrino. Es la cámara de la ironía dramática. |
| **Frontal de espaldas** (el peregrino se aleja) | Entrar en lo desconocido: la casa, el sótano, el bosque a la salida del claro | El jugador acompaña: se hunde con él. |
| **Diagonal / isométrica** | Explorar la casa, los claros con varias salidas, construir el torreón, la mesa de lecciones vista desde lo alto | Muestra la geometría y deja ver la casa imposible como una maqueta. |
| **Tercera persona tensa** (de espaldas, cercana, con el cono del orbe) | Escenas tipo Alan Wake: de noche, sótanos, sombras, criaturas que se esconden | Reutiliza "andar de espaldas" y el orbe ámbar como linterna. Campo de visión estrecho y lo que hay detrás no se ve. |
| **Primera persona** | Posesiones, el ataúd, las lecciones en la mesa (Dóminus frente al jugador) y el final | La mesa en primera persona es un eco directo del ataúd: hay una mirada perversa delante y no puedes huir. |

### 5.2 Transiciones, que también son juego

- **El giro como cambio de cámara:** cuando el peregrino gira (animación existente) en ciertos puntos marcados (umbrales, esquinas), la cámara rota 90° con él y se pasa de lateral a frontal o a diagonal. El jugador aprende que el giro "dobla el mundo".
- **Pasillos paralelos que convergen (casa, cap. 4):** en diagonal, dos pasillos paralelos. Al andar por uno, la cámara gira despacio hasta que los dos pasillos se tocan en el centro de la pantalla sin llegar al infinito. Es el puzle 12.
- **La caída como transición vertical:** de lateral a cenital (primera persona de la hoja), y de vuelta.
- **Entrar en posesión:** el orbe rojo hace un zoom al ojo del ser y se pasa a su primera persona. Para volver, zoom out desde el ojo del peregrino dormido. Siempre por los **ojos**.
- **Regla de tranquilidad:** nunca se cambia la cámara durante un salto. Los cambios se hacen en suelo firme o en umbrales.
- **Regla de pérdida:** a medida que avanza la realidad, **se usan menos cámaras**. En los caps. 9-10 las rotaciones mágicas desaparecen: la casa ya no gira porque cumple Euclides. Solo quedan lateral, tercera persona y, al final, la primera persona del bronce.

---

## 6. Escenas tipo Alan Wake

Reglas comunes: es de noche o bajo tierra, la cámara es la tercera persona de espaldas y el orbe ámbar hace de linterna. Las sombras y criaturas siguen la regla del bufón: **si la luz las toca, se paran o se esconden; si no, avanzan**. La recarga se hace en fuentes de luz reales. Correr exige guardar el báculo, y con él se va la luz. Esa es la decisión que da tensión.

### 6.1 El bosque que te sigue (cap. 3, atardecer → noche)
- Es la huida al oeste. El bufón-pavo real se esconde tras los árboles cuando lo enfocas. Al girar la cámara (giro del peregrino), aparece más cerca.
- **Mecánica:** "juego de las estatuas". Se avanza de espaldas a él y hay que girarse con la luz para pararlo. Las plumas del pavo real reflejan la luz y deslumbran (la luz rebota y el jugador pierde el foco 1 s).
- **Final:** la gárgola del roble que sigue con la mirada. Si se posee (4.11), se ve dónde espera el bufón y se le esquiva.
- **No hay muerte:** si te alcanza, te tira a la hojarasca y se ríe. Despiertas más atrás. El miedo es de humillación, no de daño (estado II).

### 6.2 La casa de noche (cap. 4)
- Insomnio. Se recorren los pisos superiores en tercera persona. La geometría imposible está activa: los pasillos convergen y las puertas dan a la misma habitación.
- **Amenaza:** Dóminus, que **camina dormido**, y el hijo, que aparece quieto al fondo de los pasillos. La regla es inversa: el hijo **solo se mueve cuando lo iluminas** (se acerca a la luz como una polilla). Hay que apagar el orbe (guardar el báculo) y andar a oscuras, agachado.
- **Objetivo:** la trampilla bajo la mesa del salón (con la argolla). El péndulo imparable pasa por la sala como una guillotina lenta de humo, y hay que cruzar entre sus pasadas.

### 6.3 Los sótanos (cap. 5)
- Sótano 1: juguetes, caballitos, marionetas, dibujos a carboncillo. Las marionetas se giran hacia la luz. Usar el **eco azul** revela a un niño jugando con sus padres: el primer recuerdo ajeno.
- Sótano 2: polvo, se ahoga. La respiración por esfuerzo se activa **sin correr**: el polvo cuesta aliento. Es la primera vez que el cuerpo protesta en reposo, y anuncia el estado III.
- El baúl cerrado se rompe con una piedra de escombros (se coge del suelo y se usa). Es el gesto de cantero.
- **Salida tensa:** al subir con los legajos, la trampilla de arriba se cierra. Se oyen pasos de Dóminus sobre la mesa. Hay que esperar agachado con la luz apagada a que se aleje (sigilo), o salir por el túnel del topo si se ha hecho (4.7).

### 6.4 La persecución de la arpía (cap. 7)
- Bosque de noche, tormenta. La arpía caza desde arriba; su sombra cruza la luna.
- **Cámara frontal hacia el jugador:** el peregrino corre hacia la cámara y la arpía viene detrás, al fondo, creciendo. Para correr hay que llevar el báculo guardado, así que no hay luz.
- **Mecánica:** los claros con luz de luna son refugios donde no baja. Se corre de claro en claro (lateral ↔ frontal en cada umbral). En el último claro se elige: ámbar (deslumbrarla y huir) o **rojo** (poseerla, 4.10). Si se posee, hay que dejar el cuerpo tumbado en mitad del claro, a la vista, sin Argos que lo guarde si ha ido a buscar ayuda. Es la apuesta más arriesgada del juego.
- El estado IV está recién estrenado: el jugador **se cansa** corriendo, la respiración lo frena y hay que pararse a jadear entre claros. El terror es físico.

### 6.5 La casa que cruje (cap. 8)
- Tras la lección de Euclides, la casa se corrige sola: los pasillos que convergían se separan, las habitaciones imposibles se aplastan. Hay que **salir** antes de quedar atrapado en un espacio que deja de existir.
- **Cámara:** tercera persona. Las paredes se juntan (Inside/Limbo). Los crujidos anuncian por audio qué pasillo se va a cerrar.
- **Mecánica:** la **plomada blanca** detiene un pasillo un momento (lo vuelve recto y estable), pero la geometría cerca de la zona fijada se vuelve real y pesada. Es la ironía de salvarse acelerando el derrumbe.

### 6.6 El canturreo (cap. 6, noche del entierro)
- Después de la muerte del hijo, su melodía sigue sonando en el bosque. Es una escena de sonido: se sigue la canción en tercera persona y, al encontrar el punto, se excava (o Argos escarba). Allí hay un brote de raíces con forma de cara sin terminar. No hay amenaza: es tensión de duelo.

---

## 7. Lecciones: la mecánica de "dar conocimiento"

Es el corazón del tema, así que necesita una mecánica propia y no una cinemática.

- **Los legajos** del baúl son **cartas de conocimiento** (unas 14 en total): Aritmética, Polinización, Botánica tropical (plantas carnívoras), Zoología, Bestiario (Physiologus), Anatomía, Alquimia, Astronomía, Leyes del movimiento (Newton), Geometría euclídea (en dos partes), Venenos (manual de brujería), Arquitectura (Vitruvio) y Música.
- **La mesa** se ve en primera persona, con Dóminus enfrente y una **balanza de cantero** en medio. El jugador pone legajos en un platillo y Dóminus pone en el otro **respuestas** (fragmentos de quién es Iram). Así se ve que Dóminus siempre da lo justo para equilibrar, que es su misma estrategia.
- **Dosis:** se pueden dar uno o dos legajos por lección. Darlos todos a la vez es posible y lleva a la escena del relato: "Eres un idiota. Ya te advertí que esta clase de conocimientos es necesario recibirlos en pequeñas dosis." Es un final parcial: el mundo pasa de golpe a un estado de realidad más y el peregrino sufre una "locura" jugable (cámara inestable durante un tramo).
- **Cada legajo que se da cambia el mundo.** Polinización trae flores que se abren al paso y el orbe verde. Plantas carnívoras traen la planta-león, que le arranca un dedo al hijo. Bestiario trae más criaturas para poseer, y también los perros tricéfalos que luego afectan a Argos. Newton lleva al estado III. Euclides, al estado IV y a que la casa cruja. Anatomía hace que las caídas hagan daño un estado antes.
- **Mentir:** se puede inventar (combinar dos cartas en una quimera, como cabracerdo o buitrepez). Si Dóminus lo detecta, se enfada y no responde, pero en el bosque aparece esa quimera, que es poseíble y graciosa. Es la forma de jugar con la inocencia: mentir es más bonito que la verdad, pero no da respuestas.
- **Estrategia del jugador:** hay que administrar. Cuanto más real hacemos el mundo, más respuestas nos da y peor nos movemos. Los legajos de Newton y Euclides son obligatorios en la historia, pero el jugador **elige cuándo** dentro de una ventana de 1 o 2 lecciones. Se puede retrasar la pérdida, nunca evitarla.

---

## 8. Banco de puzles (32)

Formato: **cámara · verbos/orbes** · solución · cómo se enseña · significado.

### Capítulo 1: la luz (estado I, Pluma)

**P1. Las hojas en la luz (coger el báculo)**, la idea del usuario desarrollada.
*Cámara lateral con un instante cenital. Verbos: andar, saltar con altura variable, carrerilla. Sin orbe: el báculo aún no es suyo.*

- **Fase 0, no saber (30-60 s).** El peregrino se levanta en la hojarasca, bajo el haz. Las hojas se apartan al andar, como en la escena actual. Si sale por un borde, vuelve al mismo sitio ("¿Es la luz de antes?"). El báculo baja muy despacio por la luz como una pluma y se queda **suspendido a unos 5 cuerpos de altura**, girando, sin llegar al suelo. Si el jugador salta normal (aún no lo sabe), sube un poco más de lo debido, pero no llega. Pensamiento: *"Lo conozco. ¿Ha venido a buscarme?"*
- **Fase 1, descubrimiento: el primer salto flota.** Hay que salir de la luz. Fuera, el salto es normal y corto. Al volver a saltar **dentro de la columna de luz**, el salto se estira: se cae despacio y las hojas caídas del suelo se levantan con el aterrizaje. Esto se enseña por **contraste**: los bordes del claro tienen un tronco caído que se salta fuera y dentro de la luz, y la diferencia se ve. Hay una **hoja grande** que cae siempre por el mismo carril, lenta, con brillo cálido. Si el jugador la toca en el aire, **se posa en ella**: se dobla un poco y se le hunde el pie. Es el primer "¡oh!".
- **Fase 2, dominio: encadenar hojas.** Del cielo caen hojas en tres carriles a ritmos distintos (las caídas son cíclicas y legibles, unos 4 s cada una). Cada hoja aguanta 1 s antes de doblarse y caer. Hay que saltar de hoja en hoja subiendo: la altura variable importa (un toque, brinco corto a la hoja cercana; mantener, salto largo a la del otro carril). La carrerilla en el suelo da el primer impulso largo. Si cae, no hay daño: aterriza flotando en la hojarasca y las hojas se apartan. Se reintenta al momento.
  - Sub-capa opcional: las hojas doradas aguantan el doble y las rojizas la mitad. El jugador aprende a leer colores sin texto, y eso prepara la regla de los orbes.
  - Ritmo: la secuencia ideal son 4 hojas, y después de 3 fallos cae una **hoja enorme** más lenta que lo facilita (ayuda invisible).
- **Recompensa.** En la última hoja, el peregrino alarga la mano y **coge el báculo en el aire**. En ese momento la gravedad lunar se apaga un instante: cae con el báculo, pesado, al suelo (tumbado → levantarse). Es la primera pista de que **el báculo trae peso**. Luego el orbe se enciende rojo y la luz del claro deja de ser una columna cerrada: se abre una salida. Pensamiento: *"No puedo quedarme aquí. Algo habrá más allá de la luz."*
- **Significado:** al principio se vuela por no saber nada. El primer objeto de poder que obtiene ya trae el primer gramo de realidad.

**P2. El báculo no salta**
*Lateral · sacar/guardar báculo, saltar · rojo (inerte)*
Nada más cogerlo, el peregrino lo lleva en la mano. Sigue habiendo hojas cayendo hacia la salida, y el jugador pulsa saltar. El peregrino mira arriba, pero no salta. Hay que guardar el báculo (sale el icono del botón una sola vez, sin texto, solo el glifo) y entonces sí. **Enseña** la regla base de forma pura. **Significado:** el poder y la libertad del cuerpo no van juntos.

**P3. La hoja que cae (primera posesión)**
*Lateral → primera persona · rojo*
A la salida del claro hay un barranco sin fondo visible y el bosque lejano se ve borroso. Una hoja suelta cae por el borde. El orbe rojo late cuando la luz del báculo toca la hoja. Se apunta, se mantiene, y el peregrino clava el báculo y se tumba. Ya en la hoja, el jugador se inclina y ve que el barranco es poco profundo y que hay una cornisa oculta debajo. Al despertar, en esa cornisa aparece una marca de cantero luminosa y el jugador sabe dónde saltar. **Enseña:** el orbe late cerca de lo poseíble. **Significado:** ver desde otro es saber más.

**P4. El cono que se queda (clavar)**
*Lateral · ámbar (latente en el orbe rojo durante el cap. 1: el orbe ilumina), clavar báculo, saltar*
Hay una pared alta fuera de la luz natural. Si se proyecta la luz del orbe hacia arriba, dentro del cono se flota, pero con el báculo en la mano no se salta. El báculo se puede clavar en una grieta marcada (el suelo brilla un poco), y entonces el cono queda fijo. Se guardan las manos, se salta dentro del cono, se sube y, desde arriba, se tira de una raíz que inclina el báculo (no hace falta volver). **Enseña:** el gesto central del juego. **Significado:** para usar la magia hay que soltarla.

### Capítulo 2: el bosque y la casa (estado I, final; llega Argos)

**P5. El perro que no se deja coger (encuentro con Argos)**
*Lateral y frontal · andar agachado, ofrecer comida (frambuesas)*
Un perro flaco huye si el peregrino corre o se acerca de pie. Hay que agacharse, dejar frambuesas en el suelo, alejarse y esperar. El perro se acerca, come y sigue al peregrino. **Enseña:** el lenguaje corporal como verbo (agacharse = no amenazar). **Significado:** la primera relación del juego se gana con humildad. Es Argos (el nombre lo pone Dóminus después, y duele: "Ese perro es mío").

**P6. Órdenes básicas: "busca"**
*Lateral · Argos*
Hay un único botón contextual de **llamar o señalar**. Si se señala algo con el báculo (sin poder), Argos va y olfatea. Puzle: en una madriguera hay un tejón-quimera que guarda una piedra-llave, y Argos cabe por el agujero mientras el peregrino no. **Enseña:** que Argos va donde tú no cabes. **Significado:** dependencia mutua.

**P7. El ave gigante (el mapa del bosque)**
*Lateral → primera persona · rojo*
Un ave enorme duerme en un árbol muerto. Hay que poseerla (el cuerpo queda dormido y Argos se tumba a su lado: primera vez que guarda el cuerpo, se ve y se aprende). Se vuela, y desde arriba el bosque es un mosaico simétrico perfecto con la casa en el centro y una luz temblorosa. **Significado:** belleza y aviso a la vez: es demasiado perfecto para ser real.

**P8. La puerta entornada**
*Frontal de espaldas → diagonal · andar*
No es un puzle, es un umbral. Al llegar a la casa (secuencia congelada del usuario), la cámara pasa a frontal de espaldas, y al empujar la puerta, a diagonal. La casa se presenta como un juguete. La sala tiene el péndulo, el órgano, el potro y el alambique. **Significado:** aquí empieza la otra mitad del juego, la casa.

### Capítulo 3: la huida al oeste (estado II, Fábula)

**P9. Riachuelos que se repiten (bosque infinito I)**
*Lateral · andar, saltar · Argos*
Se avanza hacia el oeste y aparece un riachuelo con frambuesas. Luego otro idéntico, y en el tercero la piedra-corazón (es el **salto testigo**, fácil en el estado II). Si se sigue andando, se repite. La solución es darse cuenta del bucle: Argos se niega a seguir en el tercer riachuelo (se sienta y gime). Si se posee el pez (4.6), se ve que el agua da la vuelta. La salida es **no avanzar**: volver atrás, a contracorriente. **Enseña:** desconfiar de la repetición. **Significado:** el mundo de Dóminus no tiene fuera.

**P10. El juego de las estatuas (bufón-pavo real)**
*Tercera persona · ámbar, giro*
Ver escena 6.1. Hay que cruzar un pasillo de árboles de espaldas a la criatura e iluminarla al girarse para que se pare. Las plumas deslumbran si se la ilumina de frente demasiado rato, así que hay que darle a la cola, no a la cara. **Significado:** mirar fijamente lo que asusta lo detiene, pero no lo hace desaparecer.

**P11. El tronco del oso**
*Lateral → primera persona · rojo*
Un tronco caído cierra el camino de vuelta a la casa. Hay un oso de musgo dormido en una charca de sol, y para poseerlo hay que despertarlo con cuidado: Argos ladra y el oso se levanta. Desde dentro, se empuja el tronco hasta el riachuelo, donde queda como puente. **Enseña:** que la posesión es fuerza prestada. **Significado:** el mundo es mayor que tú y lo puedes habitar.

### Capítulo 4: lecciones y la casa de noche (estado II)

**P12. Los pasillos que convergen**
*Diagonal / tercera persona · andar, giro*
Hay dos pasillos paralelos, cada uno con una puerta al final que no se abre. Andando por el izquierdo, en el umbral marcado se **gira**: la cámara rota y el pasillo izquierdo ahora es el derecho y está unido al otro. Se ha llegado a la puerta del otro lado sin cruzar. Variante: si se lleva un objeto (una vela) por un pasillo, aparece en el otro. **Enseña:** que el giro dobla el espacio. **Significado:** la casa obedece a la mente de un niño, no a Euclides (todavía).

**P13. La polilla y la cerradura**
*Primera persona · rojo*
Ver 4.8. La puerta de Dóminus está cerrada y por la cerradura entra una polilla. Hay que poseerla y cruzar el cuarto sin ir hacia la vela; la atracción se nota en el stick. Sobre la mesa hay dibujos de un niño con un perro, y el perro es Argos. **Significado:** primera pista de que Argos no es del peregrino.

**P14. La rana del fondo (la argolla)**
*Primera persona · rojo · Argos guarda*
La trampilla bajo la mesa tiene la argolla rota. Un trozo cayó a la ciénaga (lo dice el hijo con gestos: mete los brazos en el agua, igual que en el relato). Se posee la rana alada, se bucea entre buitrepeces y se trae la argolla. **Significado:** el hijo ayuda; es el único que da sin pedir.

**P15. La primera lección (animales)**
*Primera persona en la mesa · cartas*
Aún no hay legajos. El jugador solo tiene cartas de animales comunes (salamandra, tejón…), y si las pone, Dóminus se aburre y golpea la mesa. La solución es **combinarlas**: dos animales en una quimera (cabracerdo, buitrepez). A Dóminus le divierte un rato, y al salir esa quimera aparece en el bosque y es poseíble. **Enseña:** la balanza y la combinación (que luego da el violeta). **Significado:** el mundo nuevo nace de nuestras mentiras.

### Capítulo 5: el baúl y Newton (estado II → III, Peso)

**P16. El baúl del sótano 2**
*Tercera persona · coger piedra, golpear · azul (obtención)*
Ver 6.3. Se rompe el cierre con una piedra de escombros, el baúl se abre y el orbe del báculo **bebe** la tinta de un legajo y se vuelve azul. Al usarlo por primera vez se ve al niño Dóminus guardando el baúl. **Significado:** el conocimiento llega en forma de memoria robada.

**P17. El péndulo que se para**
*Diagonal / primera persona · lección · consecuencia física*
El jugador da el legajo de Newton (puede retrasarlo una lección). Dóminus abre la boca y el péndulo frena hasta pararse. La gravedad sube mientras tanto, en tiempo real, en la misma sala: las cosas que flotaban (velas, motas de polvo luminosas) caen. Al día siguiente, el puzle es **empujar el péndulo** (empujar es nuevo) para poner en marcha la casa: su vaivén abre y cierra una trampilla. **Significado:** lo enseñado no se desenseña.

**P18. El salto testigo II**
*Lateral · carrerilla, respiración*
Se vuelve al riachuelo de la piedra-corazón y el salto es justo. Hace falta carrerilla y pisar la piedra, y al llegar el peregrino jadea (es la primera vez que la respiración aparece en un salto normal). **Enseña:** la pérdida, comparándola con la memoria del jugador. **Significado:** pesas lo que sabes.

**P19. El túnel del topo**
*Primera persona · rojo*
Ver 4.7. Se posee al topo para ver los cimientos (no hay) y abrir un túnel desde el bosque al sótano 2, que es la ruta de huida en 6.3. Argos cabe por él; el peregrino, agachado, a duras penas. **Significado:** la casa flota sobre la nada, y eso es un aviso para un constructor.

### Capítulo 6: el hijo (estado III)

**P20. La planta-león (lección consecuente)**
*Lateral · verde, Argos*
Si se enseñó la botánica tropical, ha nacido la planta-león y ha arrancado un dedo al hijo. Hay que acercarse a la planta, que muerde lo que se mueve en su radio. Solución: hacer crecer con el verde una enredadera que la ate (se gasta tiempo con el báculo en la mano dentro de su radio). Luego Argos ladra para distraerla mientras el peregrino entra agachado por el otro lado a recoger el dedo (un brote). **Significado:** cada lección tiene una víctima, y no siempre es uno mismo.

**P21. El sapo de antiparras (la sopa)**
*Primera persona · rojo*
Ver 4.4. El hijo te regala el sapo, y al poseerlo, en la oscuridad de la cocina se ven las setas que el propio jugador recogió (el guion decide si el veneno lo pone el jugador; mecánicamente propongo que **el jugador recoge las setas en un puzle previo de botánica creyendo que son ingredientes de sopa** y que el sapo le revela lo que ha hecho). Hay una oportunidad de tirar la sopa, pero el sapo es pequeño y lento. Es un puzle diseñado para que **casi** se consiga: el sapo llega justo cuando el plato pasa al niño. **Significado:** el conocimiento llega siempre un instante tarde.

**P22. Plantar al hijo (el entierro)**
*Lateral · verde, cavar (Argos escarba)*
Argos escarba la fosa y el peregrino deposita el cuerpo; el verde lo hace germinar. No hay fallo posible, solo hay que mantener el botón mientras crece, y si se suelta, se detiene: el jugador decide cuándo basta. Sale una mata con la forma vaga de un niño que canturrea. **Significado:** "tener un hijo es como plantar el grano en la tierra". El jugador repite con sus manos el gesto de Dóminus.

**P23. Injertos (el regalo)**
*Lateral · violeta*
Para consolar (o burlarse), Dóminus regala el orbe violeta. Hay un acantilado de piedras sueltas y plumas del ave, y la solución es injertar piedra y pluma para obtener una piedra que flota y subir en ella. Así se compensa la pérdida de salto del estado III con magia. Al bajar, la quimera piedra-pluma flota sola por el bosque para siempre. **Significado:** la magia compensa al cuerpo, pero llena el mundo de errores.

### Capítulo 7: la verdad, la arpía, las marcas (estado III → IV, Medida)

**P24. Las marcas de cantero (bosque infinito II)**
*Lateral / diagonal · coger piedra afilada, grabar (nuevo gesto o reutilizar "agacharse" + chispa)*
Se busca salir hacia la ciudad. Todos los árboles son idénticos "hasta en sus más minúsculas imperfecciones". Solución: grabar marcas de cantero (cada una es un glifo distinto que el jugador elige en un pequeño menú circular: compás, escuadra, nivel, estrella…) en los árboles de cada cruce. Al volver a un cruce se reconoce la marca. Pero el bosque **copia** las marcas: en el siguiente cruce aparece la misma marca grabada por nadie. Lo que funciona es el **eco azul**, que distingue la marca hecha por el peregrino (se le ve grabándola) de la copia. Así se llega al linde del bosque. **Significado:** ni siquiera tu firma es tuya en el sueño de otro.

**P25. La ciudad es una mancha**
*Primera persona · rojo (ave)*
Ver 4.2, segunda vez. Al linde no hay camino. Se posee al ave, se vuela hacia la ciudad, y se ve que es plana, pintada, y que el humo es una pincelada que no se mueve. El ave choca contra ella como contra un lienzo y la posesión se rompe. **Significado:** se acaba la esperanza de fuera, y desde aquí el juego mira hacia dentro.

**P26. Huir de la arpía**
*Frontal ↔ lateral · correr, aliento · ámbar o rojo*
Ver 6.4. Es la primera escena en el estado IV (se ha dado Euclides antes de salir, o se da justo después; a gusto del guion, y en todo caso aquí el aliento ya es un muro). Hay que correr de claro en claro. Si se posee a la arpía, se ve su nana y la arpía deja de cazar. Si se la deslumbra, sigue cazando el resto del juego en escenas sueltas. **Significado:** el monstruo es la madre que alguien no supo imaginar.

**P27. La hoja que ya no sostiene**
*Lateral · saltar*
Es una réplica exacta del P1, a menor escala: un claro con luz y hojas cayendo, y al otro lado una frambuesa dorada. El jugador salta a la primera hoja y la atraviesa; cae, se hace daño y cojea. La solución real es **fijar** con la plomada blanca (que se obtiene aquí): una hoja se vuelve losa de piedra, cae al suelo y sirve de escalón (para dos escalones hacen falta dos hojas fijadas). **Enseña:** el blanco por contraste con el recuerdo del P1. **Significado:** para subir, ahora hay que matar la magia.

### Capítulo 8: Euclides y el torreón (estado IV)

**P28. La casa que se corrige (salir a tiempo)**
*Tercera persona · andar, agacharse, blanco*
Ver 6.5. Los pasillos se cierran y hay que salir. El blanco estabiliza un tramo y endurece la gravedad local, así que justo después de usarlo hay un borde que ya no se alcanza y hay que trepar (agarre a borde). **Significado:** la verdad derriba la casa, y tú dentro.

**P29. El salto testigo III (el arco)**
*Lateral · empujar piedra, colocar, blanco*
El riachuelo de la piedra-corazón ya no se puede saltar. Hay sillares en la orilla. Se construye un **arco**: se trazan con el compás (blanco) dos puntos de apoyo y la curva, se empujan los sillares a las marcas y se coloca la clave (la piedra-corazón, sacada del agua por Argos). El arco se sostiene cuando la clave entra. **Enseña:** el compás convierte un trazo en una guía para colocar piedra. **Significado:** el viejo cantero recupera el oficio cuando pierde la juventud. Construir sustituye a saltar.

**P30. El torreón**
*Diagonal / isométrica · empujar, colocar, plomada, escuadra*
Es un puzle de construcción por capas, en 3 niveles:
1. **Cimientos:** la plomada (la línea blanca cae recta y marca dónde) y nivelar con piedras de distinto grosor hasta que una burbuja de agua (el nivel de agua del cantero) quede en el centro.
2. **Muros a escuadra:** colocar sillares en un ángulo recto. Si el ángulo está mal, el muro cruje (sonido de la casa de Dóminus) y se cae al día siguiente.
3. **Bóveda o arco** de la puerta, como en el P29, pero con más piezas.
Cada noche (elipsis), la casa de Dóminus, vista al fondo, cruje más. **Significado:** construir bien es la venganza. El jugador hace con las manos lo que hace un buen constructor, y eso mata.

### Capítulo 9: Argos (estado IV → V)

**P31. Argos de tres cabezas**
*Tercera persona / frontal · rojo, blanco*
(Propuesta mecánica para el guion: Dóminus, con el bestiario, "mejora" a Argos para que guarde su casa, que se derrumba, y le hace tres cabezas: es el perro tricéfalo del relato. La culpa es de Dóminus, pero también de la lección que dio el jugador.)
- **Persecución frontal:** Argos-quimera corre hacia la cámara, persiguiendo al peregrino. No se puede correr mucho (estado IV), así que hay que esconderse en el túnel del topo (P19), donde Argos cabía y ahora no.
- **Posesión final:** se posee a Argos (el cuerpo queda tumbado y nadie lo guarda: Argos *era* el que guardaba). Dentro hay tres visiones a la vez, en pantalla partida en tres, y solo una de las cabezas, la izquierda, **ve en color** y reconoce al peregrino dormido. El jugador controla a Argos y tiene que llevarlo, con dificultad (las otras cabezas tiran), hasta tumbarse junto al cuerpo del peregrino. Es el Argos homérico: reconoce a su amo y se tumba.
- **El final del puzle:** al despertar, Argos está a su lado, tranquilo pero sufriendo. El único orbe que deshace una quimera es el **blanco**: fijar lo vuelve real, y un perro real con tres cabezas no puede vivir. Se traza la plomada sobre él y Argos se vuelve un perro normal, viejo, que respira dos veces y muere. No hay opción de no hacerlo: la escena no avanza y Argos aúlla de dolor si se espera. **Significado:** el conocimiento como piedad que mata. El jugador lo hace con la misma herramienta que usó para salvarse.

**P32. La casa cae**
*Lateral / diagonal · andar (sin salto: estado V comienza)*
Desde el torreón se oye el estrépito. Se anda hasta los escombros (no se puede correr: respiración constante). Se buscan entre los escombros (agacharse, apartar piedras) el rostro de Dóminus y la última lección traducida. **Significado:** la recompensa del plan es ver la propia cara.

### Capítulo 10: el bronce (estado V)

**P33. Huir mientras el mundo se apaga**
*Frontal hacia cámara → primera persona · andar*
Es la huida del final del relato. El peregrino viene hacia la cámara. Al pulsar **saltar** no pasa nada (ya no hay salto). Correr sale solo dos pasos. Las estrellas se apagan por detrás, después los árboles, después su sombra y por último sus brazos: el sprite pierde capas y el báculo cae al suelo. El orbe es gris. Al intentar alzar el báculo, se oye un golpe de bronce. La cámara entra en primera persona y se está **en el ataúd**: ventanita, velas, olor (se representa con un temblor de imagen), risas a través del metal. Los controles son los de la intro, dar puñetazos. Alguien se asoma a la ventana. **Significado:** se cierra el círculo. Todo el poder y toda la física eran del niño, y ahora solo queda el puño.

---

## 9. Ritmo

Duración objetivo de unas 5-6 h. Leyenda: **P** plataformas o puzle físico · **N** calma narrativa · **T** tensión (Alan Wake) · **X** posesión · **D** diálogo o lección.

| Cap. | Título de trabajo | Estado | Duración | Secuencia de ritmo |
|---|---|---|---|---|
| 1 | La luz | I | 25 min | N (despertar) → P (hojas, P1-P2) → X (hoja, P3) → P (cono, P4) → N (salida de la luz) |
| 2 | El bosque y la casa | I | 30 min | N (atardecer) → P (Argos, P5-P6) → X (ave, P7) → N (puerta, P8) → D (el nombre, Iram) |
| 3 | El oeste | II | 40 min | P (riachuelos, P9) → T (bufón, P10) → X (oso, P11) → T (gárgola, noche) → N (regreso) → D (primera lección, P15 se hace aquí o en el 4) |
| 4 | La casa de noche | II | 35 min | D (lección) → T (casa de noche, P12) → X (polilla, P13) → X (rana, P14) → N (trampilla abierta) |
| 5 | El baúl | II→III | 40 min | T (sótanos, P16) → D (polinización, Newton, P17) → P (salto testigo II, P18) → X (topo, P19) → N (la verdad de Dóminus) |
| 6 | El hijo | III | 35 min | N (el sapo regalado) → P (planta-león, P20) → X (sapo, P21) → D (la cena) → N/T (canturreo, P22) → P (injerto, P23) |
| 7 | La mancha | III→IV | 40 min | P (marcas, P24) → X (ave, P25) → T (arpía, P26) → P (hoja que no sostiene, P27) → D (el trato del traductor) |
| 8 | Euclides | IV | 40 min | D (geometría) → T (casa que cruje, P28) → P (arco, P29) → P/N (torreón por días, P30) |
| 9 | Argos | IV→V | 30 min | N (paseo con Argos, el último bonito) → T (persecución) → X (Argos, P31) → N (muerte) → N (la casa cae, P32) |
| 10 | El bronce | V | 15 min | N (escombros, la cara) → T/N (huida que se apaga, P33) → primera persona (ataúd) |

**Reglas de ritmo:**
- Nunca dos T seguidas sin una N en medio.
- Toda posesión va **después** de un tramo de cuerpo, para que se note el alivio.
- La primera mitad del juego (caps. 1-5) tiene más P que D. La segunda mitad invierte la proporción, igual que la física: menos cuerpo y más palabras.
- Cada capítulo empieza en N (un plano frontal del peregrino solo), para que el jugador vea al viejo antes de controlarlo y note cómo cambia su postura de un capítulo a otro.

---

## 10. Producción

### 10.1 Lo que se resuelve con lo existente

| Necesidad | Se resuelve con |
|---|---|
| Trance de la posesión | Sacar báculo + tumbado (el báculo clavado es un sprite aparte) |
| Despertar | Levantarse |
| Caer y hacerse daño | Tumbado + levantarse lento + respiración |
| Cojera / vejez | Andar con báculo a menor velocidad (bastón) |
| Esconderse, sigilo | Agacharse, andar agachado |
| Tercera persona tensa | Andar de espaldas + cono de luz en shader |
| Persecuciones hacia cámara | Andar de frente (y correr frontal si se pide) |
| Coger objeto pequeño | Agacharse + fotograma de mano (o mano oculta tras el cuerpo) |
| Primera persona | Escenario + manos o picos superpuestos (como los puños del ataúd), sin peregrino |
| Huida que se apaga | Andar de frente + máscaras por shader (borrar brazos, sombra) |
| Respiración, cansancio | Sistema de respiración ya hecho, con nuevos disparadores |
| Luz lunar, hojas | Física y partículas (la hojarasca ya existe) |

### 10.2 Animaciones nuevas del peregrino (vídeo IA), priorizadas

**Prioridad A (sin ellas no hay juego):**
1. **Clavar el báculo y arrancarlo**: un vídeo; arrancar es el mismo al revés si se graba con cuidado. Es el verbo central.
2. **Alzar el báculo / canalizar**: el gesto de usar orbe, con un bucle para mantenerlo.
3. **Agarrarse a un borde y subir**: imprescindible desde el estado III.
4. **Empujar o arrastrar piedra** (andar empujando en bucle): construcción, el péndulo, el oso no (el oso va en primera persona).

**Prioridad B (mejoran mucho):**
5. **Correr de frente** hacia cámara, para las persecuciones (en su defecto, andar de frente acelerado con cámara más cerca).
6. **Colocar sillar / alzar piedra a la altura del pecho** para los arcos y el torreón.
7. **Coger del suelo** (agacharse, coger y levantarse) como gesto propio.
8. **Jadear de pie** (manos en las rodillas): es la pausa de cansancio de los estados III-V y vende la vejez.

**Prioridad C (deseables):**
9. Grabar en un árbol (puede ser el bucle de canalizar con chispas).
10. Andar con báculo de frente y de espaldas, si no existen ya en esas vistas.
11. Caer al agua y salir empapado (salto testigo III).
12. Arrodillarse junto a Argos (cap. 9; se puede sustituir por agacharse).

### 10.3 Personajes nuevos (en orden)

1. **Argos**: el set mínimo es andar, correr, sentarse, olfatear, escarbar, tumbarse y saltar bajo. Es la inversión más grande y la que más juego da (compañero, guardián del cuerpo, posesión, final).
2. **Criaturas que solo existen en primera persona** (ave, rana, polilla, topo, pez, sapo, gárgola): no necesitan animación de cuerpo completo, solo un marco y su ilustración en el mundo (estática o con un bucle corto). Son baratas y hacen que la posesión sea la mecánica estrella con un coste razonable.
3. **Bufón-pavo real, arpía, Argos tricéfalo**: bucles cortos de aparecer y esconderse, y vuelo. El bufón casi no necesita animación porque solo aparece cuando no lo miras: con poses estáticas basta, y da más miedo.
4. **Dóminus y el hijo**: andar básico y poses de mesa. La mesa en primera persona necesita pocas poses de Dóminus: reposo, inclinarse, golpear la mesa y sonreír.

### 10.4 Lo que hay que programar (no vídeo)

`RealityState` con presets, gravedad por zonas de luz, hojas-plataforma con temporizador, el báculo clavado como entidad con radio de efecto, el sistema de posesión (cambio de controlador y de cámara, latido, cuerpo vulnerable), el cono de luz y las criaturas tímidas (comprobar si un punto está dentro del cono), las cartas de lección con la balanza, el sistema de marcas de cantero y de ecos (repetición de trayectorias grabadas), el constructor por rejilla (sillares, plomada, escuadra y compás), y las máscaras de desaparición del final.

---

## 11. Decisiones resumidas (para revisar con el usuario)

- El báculo en la mano bloquea saltar y correr; **clavarlo** deja su efecto en un punto. Es el verbo nuevo central.
- Cinco estados de realidad (Pluma, Fábula, Peso, Medida, Bronce), activados por lecciones que **da el propio jugador**.
- El **salto testigo** del riachuelo de la piedra-corazón se cruza en los caps. 1-3, 5 y 8 para que la pérdida se sienta.
- Siete orbes: rojo Ánima (posesión, el primero y el estrella), ámbar Luz, verde Semilla, azul Eco, violeta Injerto, blanco Plomada y gris Bronce (el final).
- Las posesiones van en primera persona con dos o tres acciones por ser. Argos guarda el cuerpo dormido mientras vive.
- Argos muere por el blanco: fijar lo vuelve real, y un perro tricéfalo real no puede vivir. La culpa es de Dóminus, que lo hizo quimera con la lección del bestiario.
- Cada vez hay menos cámaras: al final solo quedan la tercera persona y la primera persona del bronce.
