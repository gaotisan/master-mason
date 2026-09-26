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
  correr, `UP` o espacio para saltar.
- `ESC`: salir.

## Flujo actual

`main.tscn` → `scenes/intro/sarcophagus_intro.tscn` (ataúd, velas, moscas, cucaracha).
Al aplastar la cucaracha se lanza el desmayo (`blackout_controller.gd`) y se pasa a
`scenes/intro/title_screen.tscn`, que enciende la sala con luz hasta mostrar el título.
Pasados unos segundos las velas se apagan, la sala queda en penumbra y la cámara
entra por el cristal del ataúd hasta el negro: ahí se pasa a
`scenes/game/dark_stage.tscn`, el escenario negro donde cae Magnus, se levanta y
se le puede mover (andar, correr, saltar, girarse). Es también el banco de
pruebas de los pilotos de `scenes/dev/`.

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
