class_name Fuentes
## La letra de cada cosa del juego (decidido el 2026-10-18). Todo texto nuevo
## coge su fuente de aqui y no de un fichero suelto.
##  - TITULO: el titulo, los capitulos y los nombres de los mundos. Marcellus SC,
##    antigua y de piedra sin ser la de todos los juegos de fantasia. El titulo
##    del cristal la usa en MSDF (titulo_letras.gd); por eso su .import lleva
##    MSDF, y para los capitulos y mundos sirve igual a cualquier tamano.
##  - DIALOGO: lo que se dice en las conversaciones. Alegreya, humana y muy
##    legible (Regular; la variable llega a Medium con FontVariation, wght 500).
##  - PENSAMIENTO: lo que piensa Iram. La misma Alegreya en cursiva: la misma
##    voz, pero se ve que no lo dice.
##  - MENU / MENU_NOTA: menus, opciones y avisos de la pantalla (guardado...).
##    Alegreya Sans, de la misma familia pero limpia para la interfaz.
##  - LIBRO / LIBRO_CURSIVA: los libros del padre. IM Fell English, que parece
##    pagina antigua; solo ahi, para que esa letra signifique "el padre".
##  - Los dibujos y notas del hijo no llevan fuente: la letra va dibujada en la
##    imagen (una version por idioma).
## Los creditos de apertura siguen en Cinzel (title_credits.gd, no se tocan).
## Todas con licencia SIL OFL (assets/fonts/OFL_*.txt).

const TITULO := preload("res://assets/fonts/MarcellusSC-Regular.ttf")
const DIALOGO := preload("res://assets/fonts/Alegreya-Variable.ttf")
const PENSAMIENTO := preload("res://assets/fonts/Alegreya-Italic-Variable.ttf")
## Medium con 3 px de aire entre letras (AlegreyaSans-Menu.tres): las opciones
## van en mayusculas y sin aire se apretaban.
const MENU := preload("res://assets/fonts/AlegreyaSans-Menu.tres")
const MENU_NOTA := preload("res://assets/fonts/AlegreyaSans-Italic.ttf")
const MENU_TEXTO := preload("res://assets/fonts/AlegreyaSans-Regular.ttf")
const LIBRO := preload("res://assets/fonts/IMFellEnglish-Regular.ttf")
const LIBRO_CURSIVA := preload("res://assets/fonts/IMFellEnglish-Italic.ttf")
