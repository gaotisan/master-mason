# The Master Mason

Juego de terror en Godot 4 hecho con IA. Prototipo en desarrollo.

## Requisitos

- Godot 4.6.2. Este repo vive en `godot\projects\master_mason\` y espera el editor en
  `godot\engine\Godot_v4.6.2\` (dos niveles arriba). Se puede indicar otra ruta con la
  variable de entorno `GODOT`.
- Para exportar el `.exe`: plantillas de exportación 4.6.2 en
  `%APPDATA%\Godot\export_templates\4.6.2.stable\`.

## Ejecutar sin exportar

```
..\..\engine\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe --path .
```

Abrir en el editor:

```
..\..\engine\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe --path . --editor
```

## Exportar a Windows

```
build_windows.bat        # genera _builds\pc\master_mason.exe + .pck
build_windows.bat run    # exporta y lanza el juego
```

## Controles

- En el ataúd, `UP`: golpear con la mano.
- Con Magnus: flechas izquierda/derecha o `A`/`D` para andar, doble pulsación para
  correr, `UP` o espacio para saltar. Junto a la puerta de la casa, `UP` la empuja.
- En la conversación: `UP`, espacio o `Enter` para pasar de línea; izquierda y
  derecha para elegir.
- `ESC`: salir.

## Flujo actual

`main.tscn` → `scenes/intro/sarcophagus_intro.tscn` (ataúd, velas, moscas, cucaracha).
Al aplastar la cucaracha se lanza el desmayo (`blackout_controller.gd`) y se pasa a
`scenes/intro/title_screen.tscn`, que enciende la sala con luz hasta mostrar el título.
Pasados unos segundos las velas se apagan, la sala queda en penumbra y la cámara
entra por el cristal del ataúd hasta el negro: ahí se pasa al bosque,
`scenes/game/bosque.tscn`, y de él a la casa de Dóminus,
`scenes/game/casa_dominus.tscn`. Al acabar la conversación sale el cartel de fin
de la demo y cualquier tecla vuelve al principio.

`scenes/game/dark_stage.tscn` (el escenario negro) sigue ahí como banco de pruebas
de Magnus; los pilotos de `scenes/dev/` lo usan.

### El bosque

Sigue el principio del relato. Magnus cae al atardecer en un claro junto a un
valle con una ciudad a lo lejos (hacia allí no se puede ir: se para solo y sale
la frase de la intuición), se interna en el bosque, anochece mientras anda, y al
final ve la luz temblorosa de la casa. La hora no va con el reloj sino con lo
andado: `PALETAS` en `scripts/game/bosque.gd` da los colores de cada tramo y se
interpola por la x de Magnus. Las frases del cuento salen como leyendas al pasar
por cada sitio (`LEYENDAS`).

Todo el dibujo son siluetas blancas que el juego tinta según la hora y la
profundidad. Se generan por código, fuera del repo:

```powershell
cd C:\Users\santiago.ochoa\godot\tools\mundo
python bosque.py              # todas las hojas a assets/world/bosque/
python bosque.py capa2 suelo  # solo esas
```

Las capas de árboles se repiten (`Parallax2D`); sus bordes (el claro del
principio y el de la casa) los pone `scripts/game/capa_bosque.gdshader`, con el
paralaje de cada capa. Las capas grandes van importadas con compresión VRAM
(BPTC) y mipmaps.

### La casa de Dóminus

`scenes/game/casa_dominus.tscn` monta el decorado
(`casa_interior_decorado.tscn`), a Dóminus (`scenes/characters/dominus.tscn`) y
el diálogo (`scenes/ui/dialogo.tscn`), y lleva el guion de la primera
conversación en `scripts/game/casa_dominus.gd`: entrar, recorrer la sala (cada
artilugio tiene su frase), la pregunta del nombre con una elección, y la charla
del relato hasta «Iram» y el favor que Dóminus le reclama.

### La araña

La misma escena (`scenes/intro/web_spider.tscn`) sale en las dos pantallas, sólo
cambiando sus `@export`. En su sitio pivota y da paseos cortos sin salirse de su
trozo de telaraña; las patas se mueven con el movimiento, no a fps fijo.

- **En el ataúd**, esquina de arriba a la derecha, en penumbra, a 220 px de
  envergadura. Nunca vuela y **nunca sale a la luz**. Al dar el puñetazo sale
  corriendo al rincón oscuro de encima —oscureciéndose por el camino, porque ahí
  llega un 58 % de luz— y vuelve a su sitio a rastras, tardando unos 15 s. La
  cucaracha tiene esa esquina vetada (`zona_vetada`), destinos y trayectos
  incluidos, para no pisársela.
- **En el título**, esquina de abajo a la derecha del panel, a 140 px. Cuando la
  cámara empieza a moverse se asusta, abre las alas y sube en vertical a la
  telaraña de la esquina de arriba, donde se posa mientras nosotros ya estamos
  entrando por el cristal.

Para revisar esos tiempos sin estar delante:

```powershell
..\..\engine\Godot_v4.6.2\Godot_v4.6.2-stable_win64_console.exe --path . ^
    --fixed-fps 30 res://scenes/dev/piloto_titulo_arana.tscn
```

Guarda una captura en cada segundo que se le pida (`scripts/dev/piloto_capturas.gd`)
y sale. Las imágenes quedan en `%APPDATA%\Godot\app_userdata\Master Mason\`.

## Sprites de personajes

Igual que el audio: el material en bruto (vídeos, fotogramas, sprites sueltos a
resolución completa) está fuera del repo, en `godot\raw\master_mason\anim\`.
Aquí solo entran las hojas finales, en `assets/characters/`.

Antes de montar una animación en Godot, leer **[docs/sprites_magnus.md](docs/sprites_magnus.md)**:
casilla, línea de suelo, `offset` del nodo, ajustes de importación y los dos avisos
que hay sobre el material actual.

## Fuentes de audio

Los mp3 originales, wav intermedios y grabaciones están fuera del repo, en
`godot\raw\master_mason\audio\`. Aquí solo van los ogg/wav finales de `assets/audio/`.
