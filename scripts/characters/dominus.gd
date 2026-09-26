class_name Dominus
extends Node2D
## Dominus, sentado a su mesa, mirando a la izquierda (hacia la puerta por la
## que entra el invitado). Recorte facetado del mismo estilo que Magnus, animado
## entero por codigo. El origen del nodo es el punto del suelo bajo el centro del
## asiento; el canto delantero de la mesa queda a 150 px por encima.
##
## Las piezas salen de tools/mundo/dominus.py, que tambien escribe el .tscn: los
## pivotes (hombro, codo, muneca, cuello, mandibula, cadera) son nodos Node2D y
## cada Sprite2D va colgado con el offset que lo deja en su sitio. Rotacion 0 en
## todos = la pose de reposo, con la cuchara metida en el cuenco.
##
## DIBUJO POR CAPAS. El antebrazo y la mano cercanos tienen que pintarse DELANTE
## de la mesa (el codo se apoya en ella y la mano esta sobre el cuenco), pero el
## resto del cuerpo va DETRAS. Por eso los huesos del brazo viven dentro de
## Cuerpo -- se inclinan y respiran con el -- y sus Sprites viven en BrazoCerca,
## despues de la Mesa, movidos con RemoteTransform2D. No se usa z_index a
## proposito: sacaria piezas por delante de lo que ponga la escena de la casa.
##
## EL BRAZO VA POR IK. Los gestos no giran articulaciones: mueven un objetivo
## (donde esta la muneca y como gira la mano) y _resolver_brazo() saca hombro y
## codo con dos huesos. Asi la mano sigue al cuenco cuando se empuja, llega a la
## boca aunque la cabeza se agache, y no se mueve de la mesa cuando el cuerpo
## respira o se inclina.
##
## LA CUCHARA SE DA LA VUELTA. En reposo apunta abajo a la izquierda, al caldo;
## en la boca apunta arriba a la derecha, a los labios. De perfil ese giro se ve
## como un escorzo: la cuchara se acorta hasta un punto y sale por el otro lado.
## Eso es EjeCuchara.scale.x pasando de 1 a -1 mientras sube.
##
## Da miedo por quieto, no por nervioso: todo es lento y pequeno. Lo unico que
## se mueve a menudo es el brillo de los ojos ("vivida e inquieta").

## Termina un gesto con final: "labio" (morderse_labio) y "sopa" (ofrecer_sopa).
signal gesto_terminado(nombre: String)
## La cuchara ha llegado a la boca: para colgar el sonido del sorbo.
signal sorbo

## Si arranca comiendo. Si no, arranca quieto() y hay que llamar a sorber_sopa().
@export var sopa_al_empezar: bool = true

@export_group("Sopa")
## Pausa entre cucharadas, en segundos. Un rango para que no se note el compas.
@export var espera_min: float = 3.5
@export var espera_max: float = 5.0
## Lo que tarda la cuchara en subir y en bajar. Subir es algo mas lento: se
## acerca con cuidado, baja con prisa.
@export var subida: float = 1.0
@export var bajada: float = 0.8
## Cuanto baja la cabeza al encuentro de la cuchara, y cuanto se echa el tronco.
@export var agacharse_grados: float = 2.6
@export var inclinarse_sorbo_grados: float = 1.8
## Giro de la mano (sobre el de reposo) con la cuchara en la boca. Con 0 la
## cuchara, ya dada la vuelta, entra por abajo y por delante de los labios.
@export var mano_en_boca_grados: float = -6.0
## Cuanto empuja el cuenco hacia la izquierda en ofrecer_sopa(). Mas de ~34 px
## no llega con el brazo ni inclinandose.
@export var empuje_cuenco: float = 30.0

@export_group("Cuerpo")
## Respiracion: el tronco se estira un 0,6 % cada 4,6 s. Apenas se ve, y ahi
## esta la gracia: parece una estatua hasta que te fijas.
@export var respiracion_periodo: float = 4.6
@export var respiracion_amplitud: float = 0.006
## Inclinacion hacia la mesa de inclinarse(true), en grados (negativo = hacia la
## izquierda, sobre la mesa).
@export var inclinacion_grados: float = -7.0
## Parpadeo: cada cuanto, en segundos. Pocos y lentos: es una mirada fija.
@export var parpadeo_min: float = 4.0
@export var parpadeo_max: float = 9.0

@onready var _cuerpo: Node2D = $Cuerpo
@onready var _cabeza: Node2D = $Cuerpo/Cabeza
@onready var _mandibula: Node2D = $Cuerpo/Cabeza/Mandibula
@onready var _parpado: Sprite2D = $Cuerpo/Cabeza/Parpado
@onready var _brillo: Sprite2D = $Cuerpo/Cabeza/Brillo
@onready var _labios: Marker2D = $Cuerpo/Cabeza/Labios
@onready var _coronilla: Marker2D = $Cuerpo/Cabeza/Coronilla
@onready var _pelo_espalda: Node2D = $Cuerpo/PeloEspalda
@onready var _brazo_lejano: Node2D = $Cuerpo/BrazoLejano
@onready var _mano_lejana: Marker2D = $Cuerpo/BrazoLejano/ManoLejana
@onready var _hombro: Node2D = $Cuerpo/Hombro
@onready var _codo: Node2D = $Cuerpo/Hombro/Codo
@onready var _muneca: Node2D = $Cuerpo/Hombro/Codo/Muneca
@onready var _punta: Marker2D = $Cuerpo/Hombro/Codo/Muneca/Punta
@onready var _cuenco: Node2D = $Cuenco
@onready var _cuenco_frente: Node2D = $CuencoFrente
@onready var _mano: Node2D = $BrazoCerca/Mano
@onready var _eje_cuchara: Node2D = $BrazoCerca/Mano/EjeCuchara
@onready var _llama: Node2D = $Vela/Llama

# --- geometria de reposo, leida de la escena en _ready
var _l1: float                 # hombro -> codo
var _l2: float                 # codo -> muneca
var _a1: float                 # angulo de reposo de cada hueso
var _a2: float
var _cuenco0: Vector2
var _muneca_en_cuenco: Vector2 # muneca de reposo, relativa al cuenco
var _mano_lejana_reposo: Vector2
var _cabeza0: Vector2
var _brillo0: Vector2
var _eje0: Transform2D         # la cuchara en la mano, tal cual viene
var _agarre: Vector2           # agarre y punta de la cuchara respecto a la muneca
var _punta0: Vector2

# --- estado que animan los tweens (por nombre, con tween_property)
var _f_boca := 0.0             # 0 cuchara en el cuenco, 1 en la boca
var _f_empuje := 0.0           # 0 mano en su sitio, 1 apoyada en el costado del cuenco
var _remover := 0.0            # amplitud del removido antes de cada cucharada
var _agachar := 0.0            # grados extra de cabeza (sorbo)
var _inclinar_sorbo := 0.0     # grados extra de tronco (sorbo)
var _inclinacion := 0.0        # grados de inclinarse()
var _inclinar_ofrecer := 0.0   # grados extra al empujar el cuenco
var _mirar := 0.0              # grados de mirar_a()
var _labio := 0.0              # grados de morderse_labio()
var _labio_baja := 0.0         # px que baja la cabeza al morderse el labio
var _temblor := 0.0            # amplitud del temblor al morderse el labio
var _mordida := 0.0            # grados de cierre extra de la mandibula (mordida)
var _desplaz_cuenco := 0.0     # px que se ha movido el cuenco (negativo = izquierda)

# --- estado interno
var _t := 0.0
var _en_sopa := false
var _espera := 0.0
var _ocupado := false          # hay una cucharada, empuje o recogida en marcha
var _hablando := false
var _habla_cambio := 0.0
var _mandibula_obj := 0.0
var _mandibula_act := 0.0
var _asentir_obj := 0.0
var _asentir_act := 0.0
var _cuchara_suelta := false   # la cuchara esta en el cuenco, no en la mano
var _parpadeo := 0.0
var _parpadeo_fin := -1.0
var _mirada_cambio := 0.0
var _mirada_lado := -1.0       # hacia donde tira el brillo: -1 izquierda, 1 derecha
var _fase_remover := 0.0
var _tw_brazo: Tween
var _tw_cabeza: Tween
var _tw_cuerpo: Tween
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_l1 = _codo.position.length()
	_a1 = _codo.position.angle()
	_l2 = _muneca.position.length()
	_a2 = _muneca.position.angle()
	_cuenco0 = _cuenco.position
	_muneca_en_cuenco = _muneca_reposo() - _cuenco0
	_mano_lejana_reposo = _cuerpo.position + _brazo_lejano.position + _mano_lejana.position
	_cabeza0 = _cabeza.position
	_brillo0 = _brillo.position
	_eje0 = _eje_cuchara.transform
	_agarre = _eje_cuchara.position
	_punta0 = _punta.position
	_parpadeo = _rng.randf_range(parpadeo_min, parpadeo_max) * 0.5
	if sopa_al_empezar:
		sorber_sopa()
	else:
		quieto()


# ==========================================================================
# API
# ==========================================================================

## Empieza a comer: cada 3,5-5 s remueve un poco, sube la cuchara a la boca,
## agacha la cabeza al encuentro, sorbe (senal sorbo) y la baja. Si la cuchara
## se habia quedado en el cuenco tras ofrecer_sopa(), primero recoge el cuenco.
func sorber_sopa() -> void:
	_en_sopa = true
	_espera = _rng.randf_range(espera_min, espera_max) * 0.5
	if _cuchara_suelta and not _ocupado:
		_recoger_cuenco()


## Deja de comer y se queda quieto, solo respirando. Si tenia la cuchara en el
## aire, la baja al cuenco.
func quieto() -> void:
	_en_sopa = false
	if _ocupado and not _cuchara_suelta and _f_empuje < 0.01:
		_bajar_cuchara()


## Gira un poco la cabeza hacia un punto (x en coordenadas globales). Siempre
## mira a la izquierda: no se voltea, solo inclina. Si el punto esta delante
## levanta la barbilla (el invitado de pie le saca la cabeza), mas cuanto mas
## cerca; si esta detras, agacha un pelo la cabeza, como quien escucha por
## encima del hombro, y el brillo de los ojos se va hacia atras.
func mirar_a(x_global: float) -> void:
	var escala: float = maxf(absf(global_scale.x), 0.001)
	var dx: float = (x_global - _brillo.global_position.x) / escala
	var obj: float
	if dx <= 0.0:
		obj = clampf(rad_to_deg(atan2(45.0, -dx)) * 0.5, 0.0, 6.0)
		_mirada_lado = -1.0
	else:
		obj = -2.0
		_mirada_lado = 1.0
	_matar(_tw_cabeza)
	_tw_cabeza = create_tween()
	_tw_cabeza.tween_property(self, "_mirar", obj, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_mirada_cambio = 0.0


## Mientras este activo, habla: cabezadas pequenas y la mandibula que se abre un
## pelin, a golpes irregulares de 0,25-0,4 s. Si tenia la cuchara en el aire la
## baja; mientras habla no empieza cucharadas nuevas.
func hablar(activo: bool) -> void:
	_hablando = activo
	_habla_cambio = 0.0
	if activo and _ocupado and _f_boca > 0.02 and not _cuchara_suelta and _f_empuje < 0.01:
		_bajar_cuchara()
	if not activo:
		_mandibula_obj = 0.0
		_asentir_obj = 0.0
		_espera = maxf(_espera, 1.5)


## Se muerde el labio: baja la cabeza, tiembla un instante y vuelve. ~1,6 s.
func morderse_labio() -> void:
	_matar(_tw_cabeza)
	_tw_cabeza = create_tween()
	var tw := _tw_cabeza
	tw.tween_property(self, "_labio", -3.2, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "_labio_baja", 1.5, 0.35).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "_mordida", 1.2, 0.3)
	tw.tween_property(self, "_temblor", 0.35, 0.12)
	tw.tween_interval(0.6)
	tw.tween_property(self, "_temblor", 0.0, 0.15)
	tw.tween_property(self, "_labio", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "_labio_baja", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "_mordida", 0.0, 0.35)
	tw.tween_callback(gesto_terminado.emit.bind("labio"))


## Se echa sobre la mesa, escuchando con avidez (true), o vuelve a erguirse.
func inclinarse(activo: bool) -> void:
	_matar(_tw_cuerpo)
	_tw_cuerpo = create_tween()
	_tw_cuerpo.tween_property(self, "_inclinacion", inclinacion_grados if activo else 0.0, 1.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Empuja el cuenco un poco hacia la izquierda, hacia el invitado, y deja la
## cuchara dentro. Deja de comer. Al acabar emite gesto_terminado("sopa").
func ofrecer_sopa() -> void:
	if _cuchara_suelta:
		gesto_terminado.emit("sopa")
		return
	_en_sopa = false
	_matar(_tw_brazo)
	_ocupado = true
	_tw_brazo = create_tween()
	var tw := _tw_brazo
	var t_bajar: float = 0.5 if _f_boca > 0.01 else 0.01
	tw.tween_property(self, "_f_boca", 0.0, t_bajar).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "_agachar", 0.0, t_bajar)
	tw.parallel().tween_property(self, "_inclinar_sorbo", 0.0, t_bajar)
	tw.parallel().tween_property(self, "_remover", 0.0, t_bajar)
	tw.tween_property(self, "_f_empuje", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "_inclinar_ofrecer", -5.0, 1.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_desplaz_cuenco", -empuje_cuenco, 1.3).set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "_inclinar_ofrecer", -7.0, 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.25)
	tw.tween_callback(_soltar_cuchara)
	tw.tween_property(self, "_f_empuje", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "_inclinar_ofrecer", 0.0, 1.2).set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_fin_ofrecer)


## Punto global unos 40 px por encima de la coronilla, para anclar los dialogos.
## Sigue a la cabeza cuando se inclina.
func punto_cabeza() -> Vector2:
	return _coronilla.global_position + Vector2(0.0, -40.0 * global_scale.y)


# ==========================================================================
# Gestos internos
# ==========================================================================

func _cucharada() -> void:
	_ocupado = true
	_matar(_tw_brazo)
	_tw_brazo = create_tween()
	var tw := _tw_brazo
	# Remueve un momento antes de cargar la cuchara.
	tw.tween_property(self, "_remover", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_remover", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	# Sube; la cabeza baja a su encuentro y el tronco se echa un pelo.
	tw.tween_property(self, "_f_boca", 1.0, subida).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "_agachar", -agacharse_grados, subida).set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "_inclinar_sorbo", -inclinarse_sorbo_grados, subida) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(sorbo.emit)
	# El sorbo: la cabeza se hunde un poco mas y recupera, como quien chupa.
	tw.tween_property(self, "_agachar", -agacharse_grados - 0.9, 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_agachar", -agacharse_grados, 0.28).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.15)
	tw.tween_property(self, "_f_boca", 0.0, bajada).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "_agachar", 0.0, bajada + 0.1).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "_inclinar_sorbo", 0.0, bajada + 0.1).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_fin_brazo)


func _bajar_cuchara() -> void:
	_matar(_tw_brazo)
	_ocupado = true
	_tw_brazo = create_tween()
	var tw := _tw_brazo
	tw.tween_property(self, "_f_boca", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "_agachar", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "_inclinar_sorbo", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "_remover", 0.0, 0.3)
	tw.tween_callback(_fin_brazo)


## Tras ofrecer_sopa(): alarga la mano al cuenco, coge la cuchara y lo trae de
## vuelta a su sitio. Luego sigue comiendo.
func _recoger_cuenco() -> void:
	_matar(_tw_brazo)
	_ocupado = true
	_tw_brazo = create_tween()
	var tw := _tw_brazo
	tw.tween_property(self, "_f_empuje", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "_inclinar_ofrecer", -7.0, 1.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_coger_cuchara)
	tw.tween_interval(0.2)
	tw.tween_property(self, "_desplaz_cuenco", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "_inclinar_ofrecer", 0.0, 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_f_empuje", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_fin_brazo)


func _fin_brazo() -> void:
	_ocupado = false
	_espera = _rng.randf_range(espera_min, espera_max)


func _fin_ofrecer() -> void:
	_ocupado = false
	gesto_terminado.emit("sopa")


## La cuchara pasa de la mano al cuenco sin moverse de donde esta. Dentro del
## cuenco se pinta despues del cuenco y antes de su pared delantera, asi que
## queda metida en el caldo; por eso ya no puede ir "detras del padre".
func _soltar_cuchara() -> void:
	_eje_cuchara.reparent(_cuenco, true)
	_eje_cuchara.show_behind_parent = false
	_eje_cuchara.scale = Vector2(absf(_eje_cuchara.scale.x), _eje_cuchara.scale.y)
	_cuchara_suelta = true


func _coger_cuchara() -> void:
	_eje_cuchara.reparent(_mano, true)
	_eje_cuchara.show_behind_parent = true
	# Lo que se haya desviado (la mano no vuelve exacta) se corrige en un
	# momento, sin salto.
	var tw := create_tween()
	tw.tween_property(_eje_cuchara, "transform", _eje0, 0.25).set_trans(Tween.TRANS_SINE)
	_cuchara_suelta = false


# ==========================================================================
# Cada fotograma
# ==========================================================================

func _process(delta: float) -> void:
	_t += delta
	_programar_sopa(delta)
	_programar_habla(delta)
	_programar_ojos(delta)
	_posar_cuerpo()
	_posar_cabeza()
	_posar_brazo(delta)
	_posar_llama()


func _programar_sopa(delta: float) -> void:
	if not _en_sopa or _ocupado or _hablando:
		return
	if _cuchara_suelta:
		_recoger_cuenco()
		return
	_espera -= delta
	if _espera <= 0.0:
		_cucharada()


func _programar_habla(delta: float) -> void:
	if _hablando:
		_habla_cambio -= delta
		if _habla_cambio <= 0.0:
			_habla_cambio = _rng.randf_range(0.25, 0.4)
			# Una de cada cuatro, la boca se cierra: son palabras, no un motor.
			_mandibula_obj = 0.0 if _rng.randf() < 0.25 else _rng.randf_range(0.8, 3.4)
			_asentir_obj = _rng.randf_range(-1.1, 0.7)
	# Suavizado exponencial: igual a 30 que a 144 fps.
	_mandibula_act = lerpf(_mandibula_act, _mandibula_obj, 1.0 - exp(-18.0 * delta))
	_asentir_act = lerpf(_asentir_act, _asentir_obj, 1.0 - exp(-6.0 * delta))


func _programar_ojos(delta: float) -> void:
	_parpadeo -= delta
	if _parpadeo <= 0.0:
		_parpadeo = _rng.randf_range(parpadeo_min, parpadeo_max)
		_parpadeo_fin = _t + 0.13
	var cerrado: bool = _t < _parpadeo_fin
	_parpado.visible = cerrado
	_brillo.visible = not cerrado
	# El brillo salta de vez en cuando un pelo: la mirada inquieta del relato.
	_mirada_cambio -= delta
	if _mirada_cambio <= 0.0:
		_mirada_cambio = _rng.randf_range(0.7, 2.6)
		_brillo.position = _brillo0 + Vector2(_mirada_lado * _rng.randf_range(0.0, 0.7),
				_rng.randf_range(-0.4, 0.3))


func _posar_cuerpo() -> void:
	var resp: float = sin(_t * TAU / respiracion_periodo)
	_cuerpo.scale = Vector2(1.0, 1.0 + resp * respiracion_amplitud)
	_cuerpo.rotation = deg_to_rad(_inclinacion + _inclinar_sorbo + _inclinar_ofrecer)
	# La mano lejana se queda apoyada donde estaba: el brazo gira sobre el hombro
	# para seguir apuntando a ella cuando el tronco se mueve.
	var hombro_l: Vector2 = _cuerpo.transform * _brazo_lejano.position
	var quiere: float = (_mano_lejana_reposo - hombro_l).angle()
	var reposo: float = _mano_lejana.position.angle()
	_brazo_lejano.rotation = wrapf(quiere - reposo - _cuerpo.rotation, -PI, PI)


func _posar_cabeza() -> void:
	var temblor: float = 0.0
	if _temblor > 0.0:
		temblor = (sin(_t * 57.0) * 0.6 + sin(_t * 83.0) * 0.4) * _temblor
	var grados: float = _mirar + _agachar + _asentir_act + _labio + temblor
	_cabeza.rotation = deg_to_rad(grados)
	_cabeza.position = _cabeza0 + Vector2(0.0, _labio_baja)
	# El pelo de la espalda cae sobre los hombros: sigue a la cabeza a medias.
	_pelo_espalda.rotation = _cabeza.rotation * 0.55
	# Mandibula: abrir es girar en negativo (la barbilla baja hacia delante).
	_mandibula.rotation = deg_to_rad(-_mandibula_act + _mordida)


func _posar_brazo(delta: float) -> void:
	_cuenco.position = _cuenco0 + Vector2(_desplaz_cuenco, 0.0)
	_cuenco_frente.position = _cuenco.position
	# Pose de reposo: sobre el cuenco con la cuchara dentro (removiendo si toca),
	# o apoyada en la mesa si la cuchara se quedo en el cuenco.
	var w_reposo: Vector2
	var giro_reposo: float
	if _cuchara_suelta:
		w_reposo = _cuenco0 + _muneca_en_cuenco + Vector2(14.0, 9.0)
		giro_reposo = deg_to_rad(8.0)
	else:
		_fase_remover += delta * TAU / 1.1
		var r: Vector2 = Vector2(cos(_fase_remover), sin(_fase_remover) * 0.45) * 2.4 * _remover
		w_reposo = _cuenco.position + _muneca_en_cuenco + r
		giro_reposo = deg_to_rad(sin(_fase_remover) * 3.0 * _remover)
	# Pose de boca: la punta de la cuchara (ya dada la vuelta) en los labios.
	var giro_boca: float = deg_to_rad(mano_en_boca_grados)
	var labios: Vector2 = to_local(_labios.global_position)
	var w_boca: Vector2 = labios + Vector2(-0.8, 0.6) - _punta_cuchara(-1.0).rotated(giro_boca)
	# Mezcla. La mano hace un pequeno arco hacia delante al subir, para no pasar
	# rozando el pecho.
	var f: float = _f_boca
	var w: Vector2 = w_reposo.lerp(w_boca, f) + Vector2(-7.0, 2.0) * sin(PI * f)
	var giro: float = lerpf(giro_reposo, giro_boca, f)
	var vuelta: float = cos(PI * smoothstep(0.15, 0.85, f))
	# Empuje: el puno apoyado en el costado derecho del cuenco.
	if _f_empuje > 0.0:
		var w_empuje: Vector2 = _cuenco.position + _muneca_en_cuenco + Vector2(3.0, 8.0)
		w = w.lerp(w_empuje, _f_empuje)
		giro = lerpf(giro, deg_to_rad(12.0), _f_empuje)
		vuelta = lerpf(vuelta, 1.0, _f_empuje)
	_resolver_brazo(w, giro)
	if not _cuchara_suelta:
		# Nunca exactamente 0: un Transform2D con escala 0 no se puede invertir.
		var sx: float = vuelta if absf(vuelta) > 0.02 else 0.02 * signf(vuelta + 0.0001)
		_eje_cuchara.scale = Vector2(sx, 1.0)


func _posar_llama() -> void:
	var n1: float = sin(_t * 7.3) * 0.6 + sin(_t * 13.1 + 1.7) * 0.4
	var n2: float = sin(_t * 5.1 + 0.4) * 0.5 + sin(_t * 17.3) * 0.5
	_llama.scale = Vector2(1.0 + n1 * 0.04, 1.0 + n2 * 0.09)
	_llama.rotation = sin(_t * 2.3) * 0.03 + sin(_t * 9.7) * 0.02


## Dos huesos: coloca la muneca en `w` (espacio de Dominus) y gira la mano
## `giro` radianes respecto a su orientacion de reposo. El codo sale siempre por
## abajo (en reposo esta apoyado en la mesa).
func _resolver_brazo(w: Vector2, giro: float) -> void:
	var w_c: Vector2 = _cuerpo.transform.affine_inverse() * w - _hombro.position
	var d: float = clampf(w_c.length(), absf(_l1 - _l2) + 0.5, _l1 + _l2 - 0.05)
	var base: float = w_c.angle()
	var cos_a: float = clampf((_l1 * _l1 + d * d - _l2 * _l2) / (2.0 * _l1 * d), -1.0, 1.0)
	var th1: float = base - acos(cos_a)
	var codo: Vector2 = Vector2.from_angle(th1) * _l1
	var th2: float = (w_c.normalized() * d - codo).angle()
	_hombro.rotation = wrapf(th1 - _a1, -PI, PI)
	_codo.rotation = wrapf(th2 - _a2 - _hombro.rotation, -PI, PI)
	_muneca.rotation = wrapf(giro - _cuerpo.rotation - (th2 - _a2), -PI, PI)


## Punta de la cuchara respecto a la muneca, con la mano en reposo. `vuelta` es
## la escala a lo largo del mango: 1 como esta dibujada, -1 dada la vuelta.
func _punta_cuchara(vuelta: float) -> Vector2:
	return _agarre + (_punta0 - _agarre) * vuelta


func _muneca_reposo() -> Vector2:
	return _cuerpo.transform * (_hombro.transform * (_codo.transform * _muneca.position))


func _matar(tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()
