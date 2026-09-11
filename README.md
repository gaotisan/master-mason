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

- `UP`: golpear con la mano.
- `ESC`: salir.

## Flujo actual

`main.tscn` → `scenes/intro/sarcophagus_intro.tscn` (ataúd, velas, moscas, cucaracha).
Al aplastar la cucaracha se lanza el desmayo (`blackout_controller.gd`) y se pasa a
`scenes/intro/title_screen.tscn`, que por ahora solo muestra la imagen del título.

## Fuentes de audio

Los mp3 originales, wav intermedios y grabaciones están fuera del repo, en
`godot\raw\master_mason\audio\`. Aquí solo van los ogg/wav finales de `assets/audio/`.
