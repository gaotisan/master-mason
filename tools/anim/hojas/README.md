# tools\anim\hojas — revisar, limpiar y escalar hojas de sprites YA MONTADAS

Trabaja sobre el resultado final (un `SpriteFrames` `.tres` y sus texturas), no
sobre los videos ni sobre las etapas de cada animacion. Por eso vale igual para
el perfil, el frontal (muy retocado a mano), el diagonal y los personajes que
vengan, y no hace falta volver a Flow.

**Nunca toca la hoja del juego.** Escribe una GEMELA: mismas casillas en el
mismo sitio, texturas nuevas en otra carpeta, otro `.tres`. Se compara en el
juego con una tecla (H) y solo se cambia cuando se aprueba.

## Una ficha por personaje (o vista)

`personajes/<ficha>.json`: que hoja, donde va la gemela, que pasadas y sus datos.
Ejemplo completo: `personajes/peregrino_perfil.json`.

```
python tools/anim/hojas/procesar.py tools/anim/hojas/personajes/peregrino_perfil.json --informe <carpeta>
    --reusar <fichero.npz>   guarda / reutiliza la limpieza (5 min) mientras se ajusta lo demas
```

## Las pasadas (en este orden)

| pasada | script | que hace | que NO toca |
|---|---|---|---|
| limpieza | `limpiar.py` | verde del croma (todo el dibujo), magenta / halo / raya del contorno (2 px), motas sueltas (<= 20 px), agujeritos (<= 6 px), interior semitransparente (piernas, barba) a opaco | el alfa del contorno; objetos sueltos grandes (el palo, lo que coge); dentro del personaje solo cambia el verde |
| tono | `tono.py` | que el tono de la tunica no SALTE en los enganches del juego (lista `enlaces` en la ficha); minimos cuadrados con el reposo de ancla | la postura (andando o tumbado se ven otros parches: no se iguala al reposo, se igualan los enganches) |
| pies | `pies.py` | piernas y pies (lo fino y oscuro bajo la tunica + lo rosado pegado) al color de calzas y calzado, con su sombreado | manos y cara (salen de la manga o la capucha, que son gruesas) |

Despues, si se quiere mas resolucion: `..\escalar_hoja.py` (Real-ESRGAN x4plus-anime,
por casilla, comprobando cada una) y `..\montar_hoja_escalada.py` (hojas y `.tres`
a 1,5x). Primero limpiar y luego escalar: escalar agranda tambien la suciedad.

## El bloque de correr nuevo del perfil

La gemela del perfil lleva ademas el bloque de correr de un solo video
(raw/master_builder/anim/peregrino_correr_v2, como_se_hizo.txt): tras cada
`procesar.py` del perfil hay que volver a pasar su `integrar.py`.

## En el juego (2026-10-22)

El perfil limpio ya es la hoja del juego: `peregrino.tscn` y `precarga.gd` cargan
`peregrino_frames_limpio.tres`, `peregrino.gd` pone el correr nuevo
(`correr_ficha`) y el flotar limpio (`flotar_ficha`). `peregrino_frames.tres` queda
como ORIGEN: al meter o cambiar animaciones alli, volver a pasar `procesar.py`
(sin `--reusar` si hay casillas nuevas) y el `integrar.py` del correr.

No se escala nada hasta el final del juego: primero se ajustan mundos y disenos, y
cada animacion se repasa cuando se use. El frontal sigue con su hoja de siempre
(`peregrino_frontal_hd.tres`): su version limpia con capucha y garra arregladas
solo existe escalada (`peregrino_frontal_hd15_limpio.tres`).

## Comprobar en el juego

- Perfil: `prueba_perfil_limpio.bat` (dark_stage; H hoja del juego (limpia) / la
  ANTERIOR, con su correr y su flotar; K fondo claro detras, donde mas se ven bordes). Script generico: `scripts/dev/hoja_alterna.gd`.
- Frontal: `prueba_frontal` (H: hoja actual / escalada 1,5x).

## Lo que se aprendio (2026-10-21, peregrino de perfil)

- El croma deja: verde en barba y capucha (familia agachado), una raya magenta por
  todo el contorno (agacharse, paso agachado: videos sobre magenta), una raya
  oliva casi opaca alrededor (por eso la regla del anillo de 1 px), restos sueltos
  alrededor de la mano (tirar: 1.078 motas) y piernas semitransparentes (giro,
  trepar mediano: sobre fondo claro se veia el fondo a traves).
- La paleta de la tunica ya era coherente (croma, contraste y tono a +-8 %; lo que
  se sale es la postura). Lo que cambia de un video a otro es el DIBUJO de los
  parches; eso no se arregla sin rehacer el video. Donde mas se nota: correr ->
  salto_correr (misma pose, otra tunica).
- Para medir "salto" en un enganche hay que voltear el destino cuando el juego lo
  voltea (giro, giro agachado) y tener en cuenta que bajar / trepar van en casillas
  mas altas.
- Escalar en la P520: la Quadro se cuelga por calor (vkQueueSubmit -4) y escribe
  casillas en negro sin error; la Intel integrada (gpu 0) es 4 veces mas lenta
  pero no falla. Las dos a la vez, una por cada punta, y solo se guarda lo que sale
  bien.
- Agachado (2026-10-22): la piel de la pierna y los paneles claros de la tunica no
  se separan pixel a pixel (salian motas y parches cuadrados). Lo que funciona: no
  crecer nunca dentro de la masa de la tunica, y decidir por CARAS del dibujo
  (`pies.facetas`: el low poly son caras de color plano): cara medio pintada, entera;
  pocos pixeles sueltos, fuera; la piel se distingue por el tono (naranja, 30-50;
  la tunica clara es malva, -15 a 5). Caras de mas de 600 px son pierna unida a la
  tunica: no se tocan.
- Marcas del usuario (`marcas.py`): cuadros rojos sobre las hojas de hojas_marcar.py,
  guardadas como fichero (no pegadas). Dentro de la caja se pinta lo fino y las caras
  que caen casi enteras en ella y no son malva.
- Pendiente: las hojas de flotar (`flotar.json`, en rejilla, fuera del `.tres`).
