extends Sprite2D
## Fondo del ataud con las velas encendidas solo donde llegan.
##
## El fondo es un sprite de pantalla completa, y un PointLight2D se aplica a todo
## el sprite que toque aunque solo alcance un trozo: la GPU recorria las cuatro
## velas en cada pixel de la pantalla, y eso era la mitad del fotograma en la
## Quadro P520. Aqui el fondo se pinta sin luces y encima van unos recortes del
## mismo fondo, iluminados, que cubren entero el alcance de cada vela (textura
## por texture_scale, mas lo que tiembla y un margen). Fuera de ese alcance una
## luz no suma nada, asi que se ve igual; solo cambia lo que cuesta.
##
## Los recortes salen de las luces al arrancar: si se mueve o se agranda una
## vela, se recalculan solos.

## Donde estan las luces de las velas.
@export var luces: NodePath = ^"../Lights"
## Colchon por fuera del alcance de cada luz, en px del fondo.
@export var margen: float = 12.0

func _ready() -> void:
	var mascara := light_mask
	var raiz := get_node_or_null(luces)
	if raiz == null or texture == null:
		return
	var tam := texture.get_size()
	var lienzo := Rect2(Vector2.ZERO, tam)
	var origen := -tam * 0.5 if centered else Vector2.ZERO
	origen += offset
	var rects: Array[Rect2] = []
	for l in raiz.find_children("*", "PointLight2D", true, false):
		var luz := l as PointLight2D
		if luz.texture == null or (luz.light_mask & mascara) == 0:
			continue
		var tiembla := 0.0
		if "position_vibration" in luz:
			tiembla = absf(float(luz.get("position_vibration")))
		var medio := luz.texture.get_size() * absf(luz.texture_scale) * 0.5
		medio += Vector2.ONE * (tiembla + margen)
		var centro := to_local(luz.global_position + luz.offset) - origen
		var r := Rect2(centro - medio, medio * 2.0).intersection(lienzo)
		if r.has_area():
			rects.append(r)
	if rects.is_empty():
		return
	# Recortes que se tocan se juntan en uno: menos piezas y nunca un pixel
	# pintado dos veces con luces distintas.
	var junto := true
	while junto:
		junto = false
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				if rects[i].intersects(rects[j], true):
					rects[i] = rects[i].merge(rects[j])
					rects.remove_at(j)
					junto = true
					break
			if junto:
				break
	light_mask = 0
	for r in rects:
		# Bordes en pixel entero: los recortes caen justo sobre los texeles del
		# fondo y no hay media fila de diferencia en los cantos.
		var p := r.position.floor()
		var e := r.end.ceil()
		var trozo := Sprite2D.new()
		trozo.texture = texture
		trozo.centered = false
		trozo.region_enabled = true
		trozo.region_rect = Rect2(p, e - p)
		trozo.position = origen + p
		trozo.light_mask = mascara
		trozo.texture_filter = texture_filter
		trozo.texture_repeat = texture_repeat
		add_child(trozo)
