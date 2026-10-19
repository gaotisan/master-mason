extends RefCounted
## Las Image de las texturas que se leen por pixel (las mascaras del camino del
## bosque). get_image() las lee de la GPU y cuesta de 1 a 17 ms cada vez, y
## varias piezas de la escena leen la misma (medio.png, cinco): al entrar en la
## escena eso se sumaba a un tiron de ~0,35 s (con el corte de camara desde la
## hojarasca se veia el ultimo fotograma congelado). Las mascaras del camino ya
## vienen como Image (assets/world/camino_bosque/pixeles/, importadas como
## Image: se cargan con la escena, en segundo plano; las escribe mascaras.py);
## cualquier otra, get_image() una sola vez.
##     const Imagenes := preload("res://scripts/game/imagenes_cache.gd")
##     var img := Imagenes.de(textura)   # solo para leer: no la cambies

const PIXELES := {
	"res://assets/world/camino_bosque/medio.png": preload("res://assets/world/camino_bosque/pixeles/medio.png"),
	"res://assets/world/camino_bosque/viento.png": preload("res://assets/world/camino_bosque/pixeles/viento.png"),
	"res://assets/world/camino_bosque/profundidad.png": preload("res://assets/world/camino_bosque/pixeles/profundidad.png"),
	"res://assets/world/camino_bosque/aire.png": preload("res://assets/world/camino_bosque/pixeles/aire.png"),
	"res://assets/world/camino_bosque/ruido.png": preload("res://assets/world/camino_bosque/pixeles/ruido.png"),
}

static var _cache := {}


static func de(tex: Texture2D) -> Image:
	var clave := tex.resource_path if tex.resource_path != "" else str(tex.get_rid())
	if PIXELES.has(clave):
		return PIXELES[clave]
	# las de otras escenas con el mismo arreglo (el cruce del bosque): la copia en
	# pixeles/ junto a la textura, si la hay
	var copia := clave.get_base_dir() + "/pixeles/" + clave.get_file()
	if not _cache.has(clave) and clave.begins_with("res://") and ResourceLoader.exists(copia):
		_cache[clave] = load(copia)
	if not _cache.has(clave):
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		_cache[clave] = img
	return _cache[clave]
