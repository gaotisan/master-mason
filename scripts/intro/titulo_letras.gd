extends Node2D
## El titulo del juego sobre la placa del cristal, escrito por codigo. Va solo
## en ingles (no se traduce). Antes iba pintado en la imagen del fondo; de
## aquellas letras sale todo lo de aqui
## (raw/master_builder/titulo_hojas/titulo_sin_letras.py, titulo_metricas.json):
##  - la forma: Marcellus SC desde el 2026-10-18 (la letra del titulo, ver
##    fuentes.gd; antes Cinzel 650 condensada, TituloMB-Cinzel650.ttf de
##    fuente_titulo.py, que era la de las letras pintadas), con el espaciado
##    natural de la fuente sin kerning;
##  - el tamano, la base y el centro de cada linea;
##  - el material (titulo_letras.gdshader): dorado con su bisel y su grano;
##  - la sombra, que cae de los pies (titulo_sombra.gdshader).
## Va por debajo de la mascara de oscuridad, asi que le llega la misma luz que
## al fondo. El controlador del titulo lo funde (fundido) y le pasa el destello
## (glint). Las coordenadas son las de la imagen del fondo (2912x1632).

const FUENTE := "res://assets/fonts/MarcellusSC-Regular.ttf"
const MATERIAL := "res://assets/intro/titulo_material.png"
const GRANO := "res://assets/intro/titulo_grano.png"
const SHADER_LETRAS := "res://scripts/intro/titulo_letras.gdshader"
const SHADER_SOMBRA := "res://scripts/intro/titulo_sombra.gdshader"
## Alto de la M respecto al tamano de la fuente.
const CAP_EM := 0.700
## El MSDF de la fuente (en su .import): rango en texeles y tamano del em.
const MSDF_RANGO := 32.0
const MSDF_TAM := 64.0
## Cada linea: texto, alto de las mayusculas, linea base y centro, en px de la
## imagen, medidos sobre las letras que iban pintadas.
const LINEAS := [
	{"texto": "THE", "cap": 57.0, "base": 648.0, "centro": 1353.0},
	{"texto": "MASTER", "cap": 95.0, "base": 805.0, "centro": 1364.0},
	{"texto": "BUILDER", "cap": 93.0, "base": 944.0, "centro": 1369.0},
]
## Una linea mas ancha que esto (px) se achica entera para caber en la placa.
const ANCHO_MAX := 640.0
## Lo que se abre cada hueco respecto al avance de la fuente (em): casi nada.
const ESPACIADO_EM := 0.0036
const ESPACIO_EM := 0.300
## Tinta de cada letra a 1 em (Marcellus SC): izquierda, derecha y avance.
## Fuera de la tabla se usa el avance de la fuente y un margen tipico.
const TINTA := {
	"A": Vector3(-0.0098, 0.6880, 0.6782),
	"B": Vector3(0.0698, 0.5210, 0.5610),
	"C": Vector3(0.0400, 0.6572, 0.6768),
	"D": Vector3(0.0698, 0.6689, 0.7139),
	"E": Vector3(0.0698, 0.4399, 0.4902),
	"F": Vector3(0.0698, 0.4458, 0.4658),
	"G": Vector3(0.0400, 0.7002, 0.7422),
	"H": Vector3(0.0698, 0.6572, 0.7271),
	"I": Vector3(0.0742, 0.1909, 0.2651),
	"J": Vector3(-0.0200, 0.1831, 0.2490),
	"K": Vector3(0.0698, 0.6660, 0.6460),
	"L": Vector3(0.0698, 0.4399, 0.4600),
	"M": Vector3(0.0352, 0.9780, 1.0181),
	"N": Vector3(0.0659, 0.6729, 0.7388),
	"O": Vector3(0.0400, 0.7661, 0.8062),
	"P": Vector3(0.0698, 0.4868, 0.5122),
	"Q": Vector3(0.0400, 0.8862, 0.8062),
	"R": Vector3(0.0698, 0.6162, 0.5908),
	"S": Vector3(0.0498, 0.4048, 0.4551),
	"T": Vector3(0.0000, 0.5972, 0.5972),
	"U": Vector3(0.0659, 0.6440, 0.7100),
	"V": Vector3(-0.0200, 0.6782, 0.6582),
	"W": Vector3(-0.0151, 1.0288, 1.0142),
	"X": Vector3(0.0112, 0.6870, 0.6982),
	"Y": Vector3(-0.0249, 0.6260, 0.6211),
	"Z": Vector3(0.0112, 0.6211, 0.6421),
	"Á": Vector3(-0.0098, 0.6880, 0.6782),
	"É": Vector3(0.0698, 0.4399, 0.4902),
	"Í": Vector3(0.0405, 0.2651, 0.2651),
	"Ó": Vector3(0.0400, 0.7661, 0.8062),
	"Ú": Vector3(0.0659, 0.6440, 0.7100),
	"Ü": Vector3(0.0659, 0.6440, 0.7100),
	"Ñ": Vector3(0.0659, 0.6729, 0.7388),
	"Ç": Vector3(0.0400, 0.6572, 0.6768),
}
## La sombra (titulo_metricas.json): cuanto baja, difuminado, fuerza y desde
## que altura de la letra cuentan los pies.
const SOMBRA_DY := 23.0
const SOMBRA_SIGMA := 10.0
const SOMBRA_FUERZA := 0.944
const SOMBRA_PIES := 0.6

## 1 se ven las letras, 0 no (la salida del titulo y el menu del cristal).
var fundido := 1.0:
	set(v):
		fundido = v
		for m in _mats:
			m.set_shader_parameter("fundido", v)
## Posicion del destello (como glint en title_reveal); -1 fuera.
var glint := -1.0:
	set(v):
		glint = v
		for m in _mats_letras:
			m.set_shader_parameter("glint", v)

var _fuente: Font
var _mats: Array[ShaderMaterial] = []
var _mats_letras: Array[ShaderMaterial] = []


## Un trazo: unas letras dibujadas con una fuente y un material.
class Trazo extends Node2D:
	var fuente: Font
	var tam := 16
	var letras: Array = []      # [letra, posicion de su origen]

	func _draw() -> void:
		for l in letras:
			draw_char(fuente, l[1], l[0], tam)


func _ready() -> void:
	_fuente = load(FUENTE)
	_montar()


func _montar() -> void:
	for h in get_children():
		h.queue_free()
	_mats.clear()
	_mats_letras.clear()
	var sombras: Array[Node] = []
	var caras: Array[Node] = []
	for linea in LINEAS:
		var texto: String = linea.texto
		var tam := roundi(linea.cap / CAP_EM)
		var medida := _medir(texto, tam)
		if medida.ancho > ANCHO_MAX:
			tam = floori(tam * ANCHO_MAX / medida.ancho)
			medida = _medir(texto, tam)
		var cap := CAP_EM * tam
		var dx: float = linea.centro - medida.centro
		var letras: Array = []
		for i in texto.length():
			letras.append([texto[i], Vector2(dx + medida.xs[i], linea.base)])
		var px_range := MSDF_RANGO * tam / MSDF_TAM

		var sombra := _trazo(letras, tam, SHADER_SOMBRA)
		sombra.position.y = SOMBRA_DY
		var ms := sombra.material as ShaderMaterial
		ms.set_shader_parameter("px_range", px_range)
		ms.set_shader_parameter("base_y", linea.base + SOMBRA_DY)
		ms.set_shader_parameter("cap", cap)
		ms.set_shader_parameter("sigma", SOMBRA_SIGMA)
		ms.set_shader_parameter("fuerza", SOMBRA_FUERZA)
		ms.set_shader_parameter("pies", SOMBRA_PIES)
		sombras.append(sombra)

		var cara := _trazo(letras, tam, SHADER_LETRAS)
		var mc := cara.material as ShaderMaterial
		mc.set_shader_parameter("material_tex", load(MATERIAL))
		mc.set_shader_parameter("grano", load(GRANO))
		mc.set_shader_parameter("px_range", px_range)
		mc.set_shader_parameter("base_y", linea.base)
		mc.set_shader_parameter("cap", cap)
		mc.set_shader_parameter("centro_x", linea.centro)
		mc.set_shader_parameter("medio_ancho", medida.ancho * 0.5)
		mc.set_shader_parameter("glint", glint)
		_mats_letras.append(mc)
		caras.append(cara)
	# Todas las sombras por debajo de todas las letras.
	for n in sombras + caras:
		add_child(n)
	fundido = fundido


## Origen de cada letra (x, con la primera en 0), ancho de la tinta y su centro.
func _medir(texto: String, tam: int) -> Dictionary:
	var xs: Array[float] = []
	var x := 0.0
	var izq := INF
	var der := -INF
	for i in texto.length():
		var ch := texto[i]
		xs.append(x)
		if ch == " ":
			x += ESPACIO_EM * tam
			continue
		var t: Vector3 = TINTA.get(ch, Vector3(0.045, 0.0, 0.0))
		if not TINTA.has(ch):
			var avance := _fuente.get_char_size(ch.unicode_at(0), tam).x / tam
			t = Vector3(0.045, avance - 0.045, avance)
		izq = minf(izq, x + t.x * tam)
		der = maxf(der, x + t.y * tam)
		x += t.z * tam + ESPACIADO_EM * tam
	return {"xs": xs, "ancho": der - izq, "centro": (izq + der) * 0.5}


func _trazo(letras: Array, tam: int, shader: String) -> Trazo:
	var t := Trazo.new()
	t.fuente = _fuente
	t.tam = tam
	t.letras = letras
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := ShaderMaterial.new()
	m.shader = load(shader)
	t.material = m
	_mats.append(m)
	return t
