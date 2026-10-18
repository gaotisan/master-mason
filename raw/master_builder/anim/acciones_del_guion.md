# Acciones del peregrino que pide el guion (v4)

**Dinámicas del usuario (2026-10-11), que mandan:**
- **Base**, con el báculo a la espalda o sin él: andar, correr, saltar (andando y corriendo), **trepar / escalar / subir**, agacharse, andar agachado, **empujar**.
- **Báculo en la mano:** andar y usar la esfera elegida. **Clavado:** el poder sigue gastando su carga en ese punto y el cuerpo queda libre (solo algunas esferas).
- **Especiales:** **tumbarse** (las posesiones) y **arrastrarse** (el final).
- **De frente:** solo andar (báculo guardado o en la mano) y correr hacia cámara (báculo guardado). Todo lo demás, de perfil. La diagonal no se juega: solo planos de situación.

Reglas para cada vídeo nuevo: pedirlo a la velocidad del juego y usarlo entero (sin
acelerar, ralentizar, diezmar ni empalmar); que empiece y acabe en un fotograma nuestro;
un solo vídeo con toda la secuencia cuando haya arranque, ciclo y parada; casilla y suelo
de `peregrino_comun.txt`.

---

## 1. Lo que hay hoy

| Vista | Acciones | Estado |
|---|---|---|
| **Perfil, sin báculo en la mano** | reposo que respira; arrancar / andar / parar; arrancar / correr / parar (con carrerilla); salto parado, salto andando, salto corriendo (altura variable) y aterrizaje; agacharse / agachado / incorporarse; andar agachado; giro de pie y agachado; caída del cielo (cayendo → caída → tumbado → levantarse); respiración por esfuerzo; **flotar en el haz** (por código: los saltos de siempre con gravedad 0,30) | En el juego (flotar, sin commitear) |
| **Perfil, báculo a la espalda** | todo lo anterior con el báculo en la funda | Piloto; falta pasarlo al juego |
| **Perfil, báculo en la mano** | sacar, guardar, reposo, arrancar / andar / parar; usar poder = efectos de la esfera | Piloto; **giro con báculo en curso** (otra sesión) |
| **De frente y de espaldas** | reposo, andar hacia cámara y alejándose, darse la vuelta, con el báculo en la funda y en la mano | Prueba frontal; falta pasarlo al juego |
| **Diagonal** | un ciclo de andar | Solo planos de situación |
| **Perfil, acciones que lo mueven o usan objetos** (2026-10-12) | trepar el muro alto y el sillar mediano, bajar de un saltito, empujar (v1 y v2, una pasada), tirar, coger del suelo y de una mesa, lanzar el palo, arrancar y clavar el báculo, tumbarse / arrastrarse / levantarse, golpe, derribo | Escena de prueba de perfil (`scenes/dev/piloto_baston.tscn`, `scripts/characters/acciones_perfil.gd`); cómo se hacen: `acciones_perfil.txt` |

---

## 2. Lo que hace falta

### Nuevas imprescindibles

| # | Acción | Vista | Dónde la pide el guion v4 | Notas |
|---|---|---|---|---|
| 1 | **Trepar / escalar** | Perfil | 1.9 el talud (verbo base desde el cap. 1), 2.5 la peña, todo Medida (más lento, con aliento), 9.4-9.5 los escalones altos del torreón, uno a uno | Con el báculo en la mano no se trepa: el pie del báculo golpea la tierra. **Vídeos pedidos 2026-10-12** (en vertical 9:16, del reposo al reposo, sin báculo): `_fuentes/prompt_trepar.txt` (pegado a un muro de 1,15 de su alto: manos al filo, se aúpa, rodilla, de pie arriba) y `_fuentes/prompt_bajar_saltando.txt` (saltito desde el borde, aterriza con las rodillas y una mano al suelo); referencias `referencia_trepar_*` y `referencia_bajar_*`. Y `_fuentes/prompt_trepar_mediano.txt` (16:9) para subirse al sillar mediano del empuje v1 (0,55 de su alto): dos alturas de subida, mediana y alta; los bloques grandes que se empujen, a la altura del muro (el empuje v2 vale para cualquier alto) **Montado 2026-10-12** (escena de prueba de perfil): trepar el muro (1,15) y subirse al sillar mediano (0,55), la altura de la subida ajustable en el juego; bajar de un saltito (Pilgrim_hopping_off..., el prompt v2 pasó el filtro), con la caída ajustable. |
| 2 | **Clavar / arrancar el báculo** | Perfil | 2.5 la peña (primera vez), 3.5 piedras que suben, 4.9 barranca, 9.3 desfiladero y **todas las posesiones** | Un vídeo: del reposo con báculo al reposo normal (el báculo se queda clavado) y, al revés, agarrarlo y arrancarlo. *Llamar* el báculo no necesita animación. **Vídeos pedidos 2026-10-12:** `prompt_clavar.txt` y `prompt_arrancar.txt` (el bastón clavado sale del propio reposo con bastón; Descargas/referencias_peregrino_baculo_clavar) |
| 3 | **Tumbarse** (de pie a tumbado) | Perfil | Todas las posesiones (3.7, 3.9, 4.4, 5.4, 5.6, 5.9, 6.4, 8.3, 8.10, 9.8): clavar y tumbarse; Argos se tumba a su lado | Debe acabar en el fotograma de `tumbado`. Despertar = `levantarse` (existe). **OJO (2026-10-12): `tumbado` y `levantarse` son de frente (de la caída del cielo) y no valen de perfil.** Vídeo pedido: `_fuentes/prompt_tumbarse_arrastrarse.txt` (de pie se tumba, se arrastra, para y se levanta, todo de perfil, del reposo al reposo) **Montado 2026-10-12** (Character_animation_sprite_extra...: se tumba, se arrastra y se levanta, de perfil). |
| 4 | **Empujar** (entrada, ciclo y salida) | Perfil | 5.6 piedras con el niño, 5.8 el péndulo, 7.5 troncos, 7.6 bajío, 8.3 sillares, 8.12 nivelar, 9.2 sillares, 9.3 carretilla, 10.1 sillar torcido | Colocar sillar = empujar hasta la marca. **Vídeo pedido 2026-10-11:** `_fuentes/prompt_empujar.txt` + `referencia_empujar_inicio/fin.png` (un vídeo con entrada, ciclo y salida, del reposo al reposo; sin báculo, el guardado lo pinta el juego; sillar de relleno que se quita al montar). **v2** (`prompt_empujar_v2.txt`, `referencia_empujar_v2_*`): manos enteras planas en vertical, como una puerta, a media altura de un sillar alto (~0,45 del alto: vale para el sillar bajo y para todo lo más alto) **Montado 2026-10-12, una pasada entera:** ni v1 ni v2 traen ciclo que cierre (mejor costura a más de 2 pasos) y sus pies resbalaban (corregido con la raíz por los pies). El v2 no calca sus referencias (empieza a 183 px del sillar en vez de 110 y las manos van al pecho). Para empujar lo que se quiera: pedir un vídeo de ciclo (inicio = fin = un fotograma del empuje). |
| 5 | **Arrastrarse** (derrumbarse + ciclo) | Perfil | 10.6-10.7 (fallan las piernas; llega arrastrándose a la hojarasca) | Acaba tumbado boca abajo. Vídeo pedido 2026-10-12: `prompt_derrumbarse.txt` (solo fotograma inicial; el ciclo de arrastrarse, también en el de tumbarse) **2026-10-12:** el arrastre del vídeo de tumbarse se repite desde su fotograma más parecido (costura a 1,8 pasos, se nota algo): para un arrastre largo, mejor un vídeo de ciclo. |
| 6 | **Correr hacia cámara** (arrancar, ciclo, parar) con el báculo guardado | Frente | 6.4 tramo de carrera, 6.5 rectas de la tormenta, 10.6 rectas de la huida | Un solo vídeo; pedir cámara que retrocede con él. Correr alejándose no hace falta |

### Recomendable

| # | Acción | Dónde | Si no se hace |
|---|---|---|---|
| 7 | **Lanzar el palo** | 2.4, 3.2, 9.2, 9.9 (el último lanzamiento antes de fijar a Argos) | Argos trae el palo y lo deja a sus pies; se pierde el único juego del juego. Vídeo pedido 2026-10-12: `prompt_lanzar_palo.txt` (lo coge del suelo y lo lanza fuera del cuadro) **Montado 2026-10-12** (Pilgrim_picks_up_and_throws; el vuelo del palo lo hace el juego). |

### Opcional

| # | Acción | Dónde | Alternativa sin vídeo |
|---|---|---|---|
| 8 | Andar de viejo con bastón | Bronce (caps. 9-10) | El andar con báculo que ya existe, con respiración y pausas |

**En curso:** el giro con el báculo en la mano (otra sesión).

---

## 3. Lo que se resuelve sin animación nueva

| Lo que pedía el guion | Cómo queda |
|---|---|
| Flotar en el haz (cap. 1) y en el cono rojo (caps. 2-4) | Por código, con los saltos de siempre (gravedad 0,30 en la luz, rebote en las hojas de la escalera, dirigir en el aire). Para jugarlo bien (girarse en el aire, ir de hoja en hoja) se piden vídeos (2026-10-12): `prompt_flotar.txt` (bucle), `prompt_flotar_girar.txt`, `prompt_flotar_rebote.txt`, `prompt_flotar_aterrizar.txt`, `prompt_flotar_avanzar.txt`; todos desde la pose c_38 del salto parado (referencias_flotar.py) |
| Saltar con el báculo en la mano | No despega: el pie del báculo golpea el suelo, sonido seco y polvo (1.8) |
| Sentarse o arrodillarse (Iram) | Agachado (6.7, 7.7, 8.7, 9.2, 9.11, 10.5) |
| Mirar arriba (1.3, 2.7, 6.4) | La cámara sube |
| La mesa | Toda en 1ª persona: Iram no se ve sentado |
| Golpes (bufón, mordiscos, caídas en Medida) | ~~Un pequeño impulso hacia arriba y la caída que ya existe → tumbado → levantarse~~ La caída que existe es de frente y no vale (2026-10-12). Vídeos pedidos: `prompt_golpe.txt` (empujón sin caerse), `prompt_derribo.txt` (lo tira de espaldas y se levanta) y `prompt_caer.txt` (de algo alto, en vertical) **Montados 2026-10-12** golpe (recula 38 px) y derribo (OJO: cae de espaldas pero acaba 222 px por delante; el vídeo traía un proyectil en el golpe, borrado). Caer de alto: sin vídeo aún. |
| Coger del suelo, esconderse, colocar sillar, cavar, tallar, marcar | Agacharse, agachado, empujar, un segundo a negro con sonido, manos en 1ª persona. Coger y tirar sí llevan vídeo (2026-10-12, el usuario): `prompt_coger_suelo.txt`, `prompt_coger_mesa.txt`, `prompt_tirar.txt` (agarrar con acción: hacia el bloque empuja, al revés tira; el bloque lleva argolla) **Montados 2026-10-12** coger del suelo, de la mesa y tirar (el sillar del vídeo se ladeaba: quitado por color; retrocede 226 px con él). |
| Cojera, andar cansado | Fuera: levantarse con esfuerzo y la respiración |
| Correr alejándose, girar de perfil a frente | No hacen falta: el paso de perfil a frente es un corte de cámara |
| Torreón y arco en diagonal | De perfil, con la torre en corte |

---

## 4. Orden de trabajo

0. **Pasar al juego lo que ya funciona en los pilotos:** el báculo (funda y mano) y la vista frontal, con el corte de cámara en umbrales.
1. **Trepar** → el talud (1.9) y la peña (2.5).
2. **Clavar / arrancar** → la peña (2.5), piedras que suben (3.5), barranca (4.9).
3. **Tumbarse** → las posesiones (la hoja, 3.7, la primera).
4. **Empujar** → el péndulo (5.8), el oso (5.9), el arco (8.3), el torreón.
5. **Correr hacia cámara** → 6.4, 6.5, 10.6.
6. **Lanzar el palo** → Argos.
7. **Arrastrarse** → el final.
8. Si sobra tiempo: andar de viejo.

**Argos**, aparte: cinco vídeos (reposo, andar, trotar y parar; correr; sentarse y tumbarse; olfatear; ladrar y escarbar). Todo lo demás por código (guion §7).
