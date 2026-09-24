extends Node
## Piloto de capturas: guarda una imagen de la pantalla en los segundos que se le
## pidan, y sale. Para revisar una escena que va por tiempos -- el titulo, la
## intro del ataud -- sin grabar el video entero ni estar delante.
##
##   ..\..\engine\Godot_v4.6.2\Godot_v4.6.2-stable_win64_console.exe --path . ^
##       --fixed-fps 30 --resolution 1456x816 res://scenes/dev/<piloto>.tscn
##
## Con --fixed-fps el reloj no depende de lo que tarde en pintar, asi que la
## misma llamada da siempre las mismas imagenes.

## Segundos en los que capturar, contados desde que arranca la escena.
@export var momentos: PackedFloat32Array = PackedFloat32Array([1.0, 5.0])
## Carpeta donde dejarlas. Admite ruta absoluta del sistema.
@export var carpeta: String = "user://capturas"
@export var prefijo: String = "cap"
## Segundos de margen antes de cerrar, tras la ultima captura.
@export var cola: float = 0.2

var _t := 0.0
var _i := 0
var _guardando := false

func _ready() -> void:
	if not carpeta.is_absolute_path() or carpeta.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(carpeta)
	else:
		DirAccess.make_dir_recursive_absolute(carpeta)

func _process(delta: float) -> void:
	_t += delta
	if _guardando:
		return
	if _i < momentos.size() and _t >= momentos[_i]:
		_guardando = true
		_capturar(_i)
		_i += 1
		_guardando = false
		return
	if _i >= momentos.size() and _t >= momentos[momentos.size() - 1] + cola:
		get_tree().quit()

func _capturar(n: int) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var ruta := "%s/%s_%02d_%05.1fs.png" % [carpeta, prefijo, n, momentos[n]]
	var err := img.save_png(ruta)
	print("captura %.2f s -> %s (%d)" % [momentos[n], ruta, err])
