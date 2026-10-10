extends Node2D
## Baston a la espalda de Magnus (PRUEBA, scenes/dev/piloto_baston.tscn).
##
## Se cuelga como hijo de Magnus, al lado de su Sprite, y en cada fotograma se
## coloca con lo que dice baston_seguimiento.json para esa animacion y ese
## fotograma: posicion respecto al centro de la casilla, giro y si va delante
## del cuerpo (de espaldas, en los giros) o detras (siempre lo demas). Con
## flip_h se refleja. Las animaciones que no estan (la caida del cielo) lo
## esconden. En los giros, mientras se ve la espalda, aparece encima la funda
## (funda.png, tela de la tunica) que lo sujeta. El json sale de raw/master_mason/anim/baston/exportar.py.
##
## FUNDA DE CUERO EN LOS GIROS (2026-10-08; el usuario: "la funda y el cambio
## es solo para cuando da el giro"). En giro y giro_agachado el baston va
## entero por fuera de la tunica, en diagonal por la espalda y metido en la
## funda de cuero de la vista de frente/espaldas (funda_cuero.py; FundaAtras
## detras de la madera, FundaDelante delante), sin corte ni parche. Sus filas
## del json traen ademas [w, funda_y, b, delante] (seguir.py): cuanto se ve la
## espalda, donde va la funda en el baston, cuanto manda esta colocacion (al
## entrar y salir del giro se funde en unos fotogramas con la de siempre, b de
## 0 a 1) y si el baston entero va delante del cuerpo. En tres cuartos la
## diagonal va en profundidad: Madera (con la bola) detras del cuerpo, la garra
## asomando tras la capucha, y MaderaDelante pone delante el tramo del hombro a
## la funda; por debajo de la funda no se dibuja (va hacia la cadera contraria).
## Con el baston en la mano, en los giros se ve solo la funda VACIA.
## Lo demas (reposo, andar, correr, saltos, agacharse...) sigue como estaba.
##
## La magia tambien vive aqui de momento: se gasta con gastar(), se recarga
## sola y la bola enseña lo que queda, llegando al valor nuevo poco a poco.
## Para que se lea el poder: al gastar, destello y estallido de chispas; al
## recargarse, motas de luz que entran en la bola; llena, chispas que suben
## despacio. El resto (brillo, espiral, halo, latido) lo hace orbe.gdshader.
##
## EN LA MANO (en_mano = true): a Magnus se le pone una copia de sus
## SpriteFrames con reposo, arranque_andar, andar y parada_andar cambiadas por
## las del video del baston (mano.json, de raw/.../baston/mano.py), y se le
## ajusta el paso (mas lento: 90 px/s, 3 px por fotograma). En esas cuatro la
## madera ya viene en el dibujo y aqui solo se pone la bola en la garra; en las
## demas (correr, saltar, agacharse...) no hay version con baston y se ve a la
## espalda, como sin el; en los giros, la funda vacia (ver arriba).
##
## Sacar y guardar (alternar_mano) van con su animacion (sacar_baston,
## guardar_baston, de los videos de Flow) cuando Magnus esta en reposo: se le
## bloquea el control mientras dura (control_bloqueado, lo que usan los
## niveles) y al acabar queda en el reposo del otro modo. En marcha, o con
## la animacion sin hacer, cambia en el sitio como antes. Mientras dura, el
## baston ya va en el dibujo y la bola va en la garra, por detras del sprite
## (cuando la garra pasa por detras de la cabeza, la tapa la cabeza).

const SEGUIMIENTO := "res://assets/characters/baston/baston_seguimiento.json"
const MANO := "res://assets/characters/baston/mano.json"
const ORBE_EN_MADERA := Vector2(-0.6, -24)   # posicion del Orbe dentro de Madera
## De espaldas se corta la madera 8 px bajo el pivote (el hombro): por ahi entra
## bajo la tunica, y el parche (nodo Funda, de 2 a 20 px) tapa el corte.
const CORTE_ESPALDA := 40.0 + 8.0
## Funda de cuero de los giros: su textura (eje del tubo y escala, funda_cuero.json),
## la x de su eje en el baston (la y va por fotograma: si el baston sube por
## ella, la funda se queda en el omoplato) y lo ancha que se ve de canto (de
## perfil) respecto a la de espaldas.
const FUNDA_CUERO := "res://assets/characters/baston/funda_cuero.json"
const FUNDA_X := 1.0
const FUNDA_CANTO := 0.6
## Pivote: px desde la punta de arriba de la madera (exportar.py). En tres
## cuartos MaderaDelante empieza ahi (la garra va tras la capucha) y las dos
## acaban HASTA_FUNDA px bajo el centro de la funda (dentro del tubo).
const PIVOTE := 40.0
const HASTA_FUNDA := 12.0
## Con el en la mano solo se anda: ni correr, ni agacharse, ni saltar (por
## ahora). El paso en si (lo que avanza cada fotograma del ciclo, el arranque,
## la parada y sus entradas, las pisadas) va medido sobre el video en
## mano.json["paso"] (raw/.../baston/paso.py y mano.py). Todo se le pone a
## Magnus al sacarlo y se le devuelve como estaba al guardarlo.
const PASO_MANO := {"correr_bloqueado": true, "agacharse_activo": false, "salto_bloqueado": true}
const PISADA_A := preload("res://assets/audio/magnus_paso_a.wav")
const PISADA_B := preload("res://assets/audio/magnus_paso_b.wav")
const MANO_ANIMS := ["andar", "arranque_andar", "parada_andar", "reposo"]
## Con el baston en la mano tambien cambia el giro (de pie): por delante,
## cambiando el baston de mano, del video del job magnus_giro_baston_mano
## (giro_mano.py). No esta en MANO_ANIMS para que no se pueda sacar ni guardar
## el baston a mitad de giro.
const MANO_GIRO := ["giro"]
const TRANSICIONES := ["sacar_baston", "guardar_baston"]

## Puesto a la espalda o guardado (escondido). Cambia con un fundido corto.
@export var puesto := true
@export var fundido := 0.15
@export var magia_recarga := 0.05     # por segundo (0..1): vacia a llena en 20 s
@export var magia_suavizado := 4.0    # cuanto tarda la bola en alcanzar el valor real
@export var destello_caida := 3.5     # por segundo: el destello de gastar dura ~0,3 s
## Particulas de la bola (Recarga, Chispas y Estallido). Apagadas (2026-10-10):
## el usuario quiere la bola y su brillo tal cual, sin los pixeles que salian
## de ella ("humillo"); esos efectos se trabajaran aparte.
@export var particulas := false
@export var colores: Array[Color] = [
	Color(1.0, 0.62, 0.18), Color(0.35, 0.75, 1.0), Color(0.55, 1.0, 0.45),
	Color(0.85, 0.45, 1.0), Color(1.0, 0.3, 0.25)]

var magia := 1.0
var _mostrada := 1.0
var _color := 0
var _datos: Dictionary = {}
var _sprite: AnimatedSprite2D
var _visible_anim := true
var _alfa := 1.0
var _destello := 0.0
var en_mano := false
var _mano: Dictionary = {}
var _frames_espalda: SpriteFrames
var _frames_mano: SpriteFrames
var _paso_espalda := {}
var _en_transicion := false

@onready var _orbe: Sprite2D = $Madera/Orbe
@onready var _luz: Sprite2D = $Madera/Luz
@onready var _recarga: CPUParticles2D = $Madera/Recarga
@onready var _estallido: CPUParticles2D = $Madera/Estallido
@onready var _chispas: CPUParticles2D = $Madera/Chispas
@onready var _madera: Sprite2D = $Madera
@onready var _madera_delante: Sprite2D = $MaderaDelante
@onready var _funda_atras: Sprite2D = $FundaAtras
@onready var _funda_delante: Sprite2D = $FundaDelante

func _ready() -> void:
	var f := FileAccess.open(SEGUIMIENTO, FileAccess.READ)
	_datos = JSON.parse_string(f.get_as_text())
	_sprite = get_parent().get_node("Sprite")
	_sprite.frame_changed.connect(_colocar)
	_sprite.animation_changed.connect(_colocar)
	_mano = JSON.parse_string(FileAccess.open(MANO, FileAccess.READ).get_as_text())
	if not particulas:
		for p in [_recarga, _estallido, _chispas]:
			p.emitting = false
	var fj: Dictionary = JSON.parse_string(FileAccess.open(FUNDA_CUERO, FileAccess.READ).get_as_text())
	for capa in [_funda_atras, _funda_delante]:
		capa.offset = -Vector2(fj["eje"][0], fj["eje"][1])
		capa.set_meta("escala", float(fj["escala"]))
	# las transiciones van en los dos juegos de SpriteFrames: se cambia de uno a
	# otro al acabar sin que se note
	_frames_espalda = _sprite.sprite_frames.duplicate() as SpriteFrames
	_anadir(_frames_espalda, TRANSICIONES)
	_sprite.sprite_frames = _frames_espalda
	_frames_mano = _construir_frames_mano()
	_sprite.animation_finished.connect(_al_acabar_transicion)
	_alfa = 1.0 if puesto else 0.0
	_aplicar_color()
	_colocar()

func poner(si: bool) -> void:
	puesto = si

func alternar() -> void:
	puesto = not puesto

## De la espalda a la mano y al reves. Desde el reposo, con la animacion de
## sacar o guardar; si no, en el sitio.
func alternar_mano() -> void:
	if _en_transicion:
		return
	var magnus := get_parent()
	var anim := "guardar_baston" if en_mano else "sacar_baston"
	if _sprite.animation == &"reposo" and _sprite.sprite_frames.has_animation(anim) 			and not magnus.control_bloqueado:
		_en_transicion = true
		puesto = true
		magnus.control_bloqueado = true
		_sprite.play(anim)
		_colocar()
		return
	# En marcha cambia en el sitio, pero solo andando: corriendo, saltando o
	# agachado no hay version con baston y quedaria a medias.
	if String(_sprite.animation) in MANO_ANIMS:
		poner_en_mano(not en_mano)

func _al_acabar_transicion() -> void:
	if not _en_transicion or not String(_sprite.animation) in TRANSICIONES:
		return
	var sacando := _sprite.animation == &"sacar_baston"
	_en_transicion = false
	poner_en_mano(sacando)
	_sprite.play("reposo")
	get_parent().control_bloqueado = false
	_colocar()

func poner_en_mano(si: bool) -> void:
	if si == en_mano:
		return
	en_mano = si
	puesto = true
	var magnus := get_parent()
	if si:
		var paso := _paso_mano(magnus)
		for k in paso:
			_paso_espalda[k] = magnus.get(k)
			magnus.set(k, paso[k])
	else:
		for k in _paso_espalda:
			magnus.set(k, _paso_espalda[k])
	_cambiar_frames(_frames_mano if si else _frames_espalda)

## Lo que se le cambia a Magnus con el baston en la mano: los bloqueos y el
## paso medido de mano.json. Las pisadas van como "a"/"b" por fotograma y aqui
## se cambian por los sonidos; las de arranque y parada van en golpes_anim.
func _paso_mano(magnus: Node) -> Dictionary:
	var paso := PASO_MANO.duplicate()
	var medido: Dictionary = _mano.get("paso", {})
	for k in medido:
		if k in ["pisadas", "golpes"]:
			continue
		# el JSON da todos los numeros como float
		paso[k] = int(medido[k]) if typeof(magnus.get(k)) == TYPE_INT else medido[k]
	var sonido := func(d: Dictionary) -> Dictionary:
		var r := {}
		for f in d:
			r[int(f)] = PISADA_A if d[f] == "a" else PISADA_B
		return r
	if medido.has("pisadas"):
		var p: Dictionary = magnus.pisadas.duplicate()
		p["andar"] = sonido.call(medido["pisadas"])
		paso["pisadas"] = p
	if medido.has("golpes"):
		var g: Dictionary = magnus.golpes_anim.duplicate()
		for anim in medido["golpes"]:
			g[anim] = sonido.call(medido["golpes"][anim])
		paso["golpes_anim"] = g
	return paso

## Cambia las SpriteFrames sin que se note: misma animacion, mismo punto.
func _cambiar_frames(sf: SpriteFrames) -> void:
	var anim := _sprite.animation
	var progreso := float(_sprite.frame) / maxf(1.0, _sprite.sprite_frames.get_frame_count(anim))
	var sonando := _sprite.is_playing()
	_sprite.sprite_frames = sf
	_sprite.animation = anim
	_sprite.frame = clampi(int(progreso * sf.get_frame_count(anim)), 0, sf.get_frame_count(anim) - 1)
	if sonando:
		_sprite.play(anim)
	_colocar()

func _construir_frames_mano() -> SpriteFrames:
	var sf := _frames_espalda.duplicate() as SpriteFrames
	_anadir(sf, MANO_ANIMS + MANO_GIRO)
	return sf

## Pone (o cambia) esas animaciones en sf con las hojas de mano.json.
func _anadir(sf: SpriteFrames, nombres: Array) -> void:
	for nombre in nombres:
		if not _mano.has(nombre):
			continue
		var d: Dictionary = _mano[nombre]
		if not sf.has_animation(nombre):
			sf.add_animation(nombre)
		var hoja: Texture2D = load(d["hoja"])
		sf.clear(nombre)
		sf.set_animation_speed(nombre, d["fps"])
		sf.set_animation_loop(nombre, d["bucle"])
		var dur: Array = d.get("duraciones", [])
		for i in int(d["n"]):
			var t := AtlasTexture.new()
			t.atlas = hoja
			t.region = Rect2((i % int(d["cols"])) * 292, (i / int(d["cols"])) * 360, 292, 360)
			sf.add_frame(nombre, t, dur[i] if i < dur.size() else 1.0)

func gastar(cuanto: float) -> bool:
	if magia < cuanto:
		_destello = 0.25      # no llega: un amago y nada mas
		return false
	magia -= cuanto
	_destello = 1.0
	if particulas:
		_estallido.restart()
	return true

func siguiente_color() -> void:
	_color = (_color + 1) % colores.size()
	_aplicar_color()

func _aplicar_color() -> void:
	var c: Color = colores[_color]
	var v := Vector3(c.r, c.g, c.b)
	(_orbe.material as ShaderMaterial).set_shader_parameter("color", v)
	(_luz.material as ShaderMaterial).set_shader_parameter("color", v)
	for p in [_recarga, _estallido, _chispas]:
		p.color = c.lightened(0.25)

func _process(delta: float) -> void:
	magia = minf(1.0, magia + magia_recarga * delta)
	_mostrada = lerpf(_mostrada, magia, 1.0 - exp(-magia_suavizado * delta))
	_destello = move_toward(_destello, 0.0, destello_caida * delta)
	for m in [_orbe.material, _luz.material]:
		(m as ShaderMaterial).set_shader_parameter("carga", _mostrada)
		(m as ShaderMaterial).set_shader_parameter("destello", _destello)
	_recarga.emitting = particulas and puesto and magia < 0.999
	_chispas.emitting = particulas and puesto and _mostrada > 0.97
	var objetivo := 1.0 if puesto else 0.0
	_alfa = move_toward(_alfa, objetivo, delta / maxf(fundido, 0.001))
	modulate.a = _alfa
	visible = _visible_anim and _alfa > 0.0
	_colocar()

func _colocar() -> void:
	# transiciones: el baston va en el dibujo y la bola sigue a la garra (mano.py
	# la busca por color fotograma a fotograma), igual que andando con el en la mano
	if String(_sprite.animation) in TRANSICIONES or (en_mano and _mano.has(String(_sprite.animation))):
		_colocar_en_mano()
		return
	_sin_funda()
	$Madera.self_modulate.a = 1.0
	$Madera/Funda.modulate.a = 0.0
	_cortar(1.0)
	var lista = _datos.get(String(_sprite.animation))
	if lista == null:
		_visible_anim = false
		visible = false
		return
	# Con el baston en la mano no hay giro con baston (2026-10-08): mejor que no
	# se vea durante el giro que verlo saltar a la espalda y volver a la mano.
	if en_mano and String(_sprite.animation) == "giro":
		_visible_anim = false
		visible = false
		return
	_visible_anim = true
	var f: Array = lista[mini(_sprite.frame, lista.size() - 1)]
	var x: float = f[0]
	var giro: float = f[2]
	if _sprite.flip_h:
		x = -x
		giro = -giro
	position = _sprite.position + _sprite.offset + Vector2(x, f[1])
	rotation = giro
	if f.size() > 5:
		_colocar_con_funda(f)
		return
	z_index = 1 if f[3] == 1 else -1
	# giros con el baston detras (escondido tras la capucha): el resplandor de
	# la bola tambien detras del cuerpo, que si no se ve la luz a traves de la
	# cabeza. Fuera de los giros sigue encima (asoma tras la capucha).
	var en_giro := String(_sprite.animation) in ["giro", "giro_agachado"]
	_luz.z_index = 0 if en_giro and f[3] != 1 else 2
	# de espaldas (giros): metido bajo la tunica, con el parche del cuello
	var parche: float = f[4] if f.size() > 4 else 0.0
	$Madera/Funda.modulate.a = parche
	_cortar(CORTE_ESPALDA / $Madera.texture.get_height() if f[3] == 1 else 1.0)

func _cortar(fraccion: float) -> void:
	($Madera.material as ShaderMaterial).set_shader_parameter("corte", fraccion)


## Giros: el baston en la funda de cuero (o la funda vacia, con el en la mano).
## f = [x, y, giro, -, -, w, funda_y, b, delante]; posicion y giro ya puestos.
func _colocar_con_funda(f: Array) -> void:
	var w: float = f[5]
	var fy: float = f[6]
	var b: float = f[7]
	var delante: bool = f[8] == 1
	# el nodo al nivel del sprite; cada capa con su z: Madera -1 (detras del
	# cuerpo) o 2 (delante), fundas 1 y 3, MaderaDelante 2
	z_index = 0
	var lado := -1.0 if _sprite.flip_h else 1.0
	var ancho := lerpf(FUNDA_CANTO, 1.0, w)
	for capa in [_funda_atras, _funda_delante]:
		capa.visible = b > 0.0
		capa.modulate.a = b
		capa.position = Vector2(FUNDA_X * lado, fy)
		capa.scale = Vector2(ancho, 1.0) * float(capa.get_meta("escala"))
	if en_mano:
		# sin version del giro con el baston en la mano: solo la funda, vacia
		_madera.visible = false
		_madera_delante.visible = false
		return
	var alto := float(_madera.texture.get_height())
	# por debajo de la funda solo se ve lo que se vea la espalda; con b = 0,
	# entero, como siempre
	var hasta := lerpf(1.0, lerpf((PIVOTE + fy + HASTA_FUNDA) / alto, 1.0, w), b)
	_madera.z_index = 2 if delante else -1
	_cortar(hasta)
	_madera_delante.visible = not delante and b > 0.0
	_madera_delante.modulate.a = b
	var m := _madera_delante.material as ShaderMaterial
	m.set_shader_parameter("desde", PIVOTE / alto * (1.0 - w))
	m.set_shader_parameter("corte", hasta)


## Fuera de los giros, todo como antes de la funda de cuero.
func _sin_funda() -> void:
	_madera.visible = true
	_madera.z_index = 0
	_madera_delante.visible = false
	_funda_atras.visible = false
	_funda_delante.visible = false

## La madera ya va en el dibujo: solo la bola, en la garra, detras del sprite
## (los dedos de la garra le quedan por delante).
func _colocar_en_mano() -> void:
	_sin_funda()
	var d: Dictionary = _mano[String(_sprite.animation)]
	var o = d["orbe"][mini(_sprite.frame, int(d["n"]) - 1)]
	if o == null:
		# la garra se sale de la imagen (el video corta el baston por arriba):
		# la bola sigue su ultimo rumbo hacia arriba y se va con ella
		position.y -= 6.0
		return
	_visible_anim = true
	$Madera.self_modulate.a = 0.0
	$Madera/Funda.modulate.a = 0.0
	var x: float = o[0]
	if _sprite.flip_h:
		x = -x
	position = _sprite.position + _sprite.offset + Vector2(x, o[1]) - ORBE_EN_MADERA
	rotation = 0.0
	z_index = -1
