# Textos de The Master Builder

Todos los textos del juego, en todos sus idiomas. Cada fichero es una tabla: una fila por frase y una columna por idioma, así que la misma frase en español y en inglés queda una al lado de la otra.

| Fichero | Qué tiene |
|---|---|
| `pensamientos.csv` | Lo que piensa el peregrino, en el orden en que sale en la historia. |
| `interfaz.csv` | Menús, opciones, controles, marca de guardado y nombres de las escenas. |

Los créditos de apertura van en inglés en todos los idiomas y no están aquí.

## Para quien revise

- Se abre con Google Sheets, LibreOffice o Excel (en Excel: *Datos > Desde texto/CSV*, codificación **UTF-8**, separador **coma**). Al guardar, que siga siendo CSV en UTF-8 con comas.
- **No tocar la columna `keys`** ni la primera fila: es como el juego encuentra cada frase.
- Columnas: `es` español, `en` inglés.
- Los saltos de línea dentro de una celda son saltos de línea en pantalla: respetarlos o proponer otros.
- `%s` y `%d` se cambian por un dato al jugar (un nombre de escena, un número). Tienen que seguir estando, una vez cada uno. `%%` es el signo de porcentaje.
- En `pie.*` los espacios largos separan las indicaciones de teclas; las teclas van en mayúsculas.
- Los pensamientos son primera persona, pocos y contenidos: literario sin pasarse. Los puntos suspensivos son el carácter `…`, no tres puntos.

## Para añadir un idioma

Una columna nueva con el código del idioma (`fr`, `de`, `it`…) en los dos ficheros, y añadirlo a `IDIOMAS` en `scripts/ui/ajustes.gd`.

## Para añadir frases

- Una fila nueva con su clave y todos los idiomas.
- Pensamientos: `pensamiento.<clave>.<parte>`, con las partes desde 1. Las partes salen una tras otra en el mismo sitio. La clave es la que usa la escena (`_pensar.decir("camino")`).
- Al guardar el CSV, Godot lo importa solo. Fuera del editor: `Godot --headless --path projects/master_builder --import`.
- `python textos/comprobar.py` avisa si a alguna frase le falta un idioma o le sobra o falta algún `%s`.
