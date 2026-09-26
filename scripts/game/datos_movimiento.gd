extends CanvasLayer
## Panel de estudio del movimiento de Magnus, solo para el escenario negro: un
## texto discreto en una esquina con el estado y la animacion, la velocidad, la
## carrerilla, la carga del salto de parado y lo que midio el ultimo salto
## (distancia del despegue al reposo y altura de los pies sobre el suelo). La
## tecla H lo oculta y lo vuelve a mostrar (se lee la tecla directamente: no
## hace falta una accion en project.godot para una ayuda de estudio).
##
## La altura de los pies no se puede leer del nodo: la subida esta cocida dentro
## de cada sprite del salto. PIES es, para cada fotograma de los tres saltos,
## cuantos px de hoja esta el pixel opaco mas bajo por encima de donde apoya de
## pie (medido sobre las hojas: fila del pie mas bajo contra la linea de suelo
## de la casilla, 338 en la comun y 377 en la del salto corriendo). A eso se le
## suma el arco que anade el nodo (la posicion y del sprite).

signal salto_medido(datos: Dictionary)

@export var magnus: NodePath = ^"../Magnus"
@export var visible_al_empezar: bool = true
## Gris apagado: por debajo del brillo de la tunica iluminada, que no compita
## con el personaje.
@export var tamano_letra: int = 26
@export var color: Color = Color(0.48, 0.48, 0.48, 0.8)
@export var margen: Vector2 = Vector2(48, 40)

const PIES := {
	"saltar": [3, 3, 3, 3, 3, 1, 0, 0, 0, 0, 0, 0, 0, 0, 5, 10, 16, 22, 32, 42, 53, 61, 67, 71, 76, 77, 77, 77, 77, 77, 77, 76, 75, 74, 73, 72, 71, 62, 51, 40, 29, 21, 13, 8, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	"salto_parado": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 3, 6, 11, 17, 23, 29, 37, 45, 52, 58, 62, 65, 65, 64, 63, 61, 58, 55, 50, 45, 38, 31, 23, 15, 7, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	"salto_correr": [3, 3, 3, 3, 8, 20, 27, 38, 47, 58, 69, 78, 82, 86, 90, 92, 95, 97, 97, 97, 94, 90, 85, 77, 67, 56, 43, 29, 17, 1, 0, 0, 0, 0, 0, 0, 0, 0],
}
## Px de pies sobre el suelo a partir de los cuales cuenta como en el aire
## (los primeros sprites del salto andando y del corriendo ya levantan 3).
const EN_EL_AIRE := 4.0
## Estados de la cinematica de entrada: ahi el texto no sale (se viene de la
## pantalla de titulo y la caida es una escena, no algo que medir).
const CINEMATICA := ["CAYENDO", "CAIDA", "TUMBADO", "LEVANTARSE"]

## Lo medido en el ultimo salto: distancia (px del despegue al reposo, o a la
## toma de suelo si sigue andando o corriendo), aire (despegue -> toca),
## altura (px de pies en el apogeo), reposo (si llego a pararse), animacion.
var ultimo := {}

var _texto: Label
var _personaje: Node2D
var _saltando := false
var _anim := ""
var _f_antes := -1
var _en_aire := false
var _x_despegue := NAN
var _x_toca := NAN
var _altura := 0.0

func _ready() -> void:
	layer = 50
	visible = visible_al_empezar
	_personaje = get_node_or_null(magnus)
	_texto = Label.new()
	_texto.position = margen
	_texto.add_theme_font_size_override("font_size", tamano_letra)
	_texto.add_theme_color_override("font_color", color)
	_texto.add_theme_constant_override("line_spacing", 2)
	add_child(_texto)

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo \
			and (evento as InputEventKey).keycode == KEY_H:
		visible = not visible
		get_viewport().set_input_as_handled()

## Va detras de Magnus en el arbol, asi que lee el tick ya resuelto.
func _physics_process(_delta: float) -> void:
	if _personaje == null or not _personaje.has_method("datos_movimiento"):
		return
	var d: Dictionary = _personaje.datos_movimiento()
	_medir(d)
	_texto.visible = not (d["estado"] in CINEMATICA)
	if visible and _texto.visible:
		_texto.text = _componer(d)

func _medir(d: Dictionary) -> void:
	var anim: String = d["animacion"]
	var f: int = d["fotograma"]
	var x := _personaje.position.x
	var en_salto: bool = d["estado"] == "SALTAR" and PIES.has(anim)
	# Salto nuevo: al entrar, o relanzado desde la cola de otro (vuelve al 0).
	if en_salto and (not _saltando or anim != _anim or f < _f_antes):
		_saltando = true
		_anim = anim
		_en_aire = false
		_x_despegue = NAN
		_x_toca = NAN
		_altura = 0.0
	_f_antes = f
	if not _saltando:
		return
	if en_salto:
		var tabla: Array = PIES[anim]
		var pies: float = float(tabla[clampi(f, 0, tabla.size() - 1)]) + float(d["arco"])
		_altura = maxf(_altura, pies)
		if not _en_aire and is_nan(_x_despegue) and pies > EN_EL_AIRE:
			_en_aire = true
			_x_despegue = x
		elif _en_aire and pies <= EN_EL_AIRE:
			_en_aire = false
			_x_toca = x
	if d["estado"] == "REPOSO":
		_cerrar(x, true)
	elif not en_salto and d["estado"] != "ATERRIZAJE_CORRER":
		_cerrar(x, false)

func _cerrar(x: float, reposo: bool) -> void:
	_saltando = false
	if is_nan(_x_despegue):
		return
	var toca := x if is_nan(_x_toca) else _x_toca
	ultimo = {
		"animacion": _anim,
		"distancia": absf((x if reposo else toca) - _x_despegue),
		"aire": absf(toca - _x_despegue),
		"altura": _altura,
		"reposo": reposo,
		"x_final": x,
	}
	salto_medido.emit(ultimo)

func _componer(d: Dictionary) -> String:
	var lineas := PackedStringArray()
	lineas.append("%s   %s  f%d" % [String(d["estado"]).to_lower(), d["animacion"], d["fotograma"]])
	lineas.append("velocidad   %d px/s" % roundi(d["velocidad"]))
	lineas.append("carrerilla   %d %%" % roundi(float(d["carrerilla"]) * 100.0))
	lineas.append("carga   %d %%%s" % [roundi(float(d["carga"]) * 100.0), "  (cargando)" if d["cargando"] else ""])
	if ultimo.is_empty():
		lineas.append("ultimo salto   -")
	else:
		lineas.append("ultimo salto   %d px %s (aire %d)   altura %d px" % [
			roundi(ultimo["distancia"]), "hasta reposo" if ultimo["reposo"] else "hasta tocar",
			roundi(ultimo["aire"]), roundi(ultimo["altura"])])
	lineas.append("H oculta")
	return "\n".join(lineas)
