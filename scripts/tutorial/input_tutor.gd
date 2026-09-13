class_name InputTutor
extends Node2D
## Director de ayudas de teclado. Tras un tiempo sin que el jugador toque nada
## muestra la secuencia de teclas, escucha la entrada, valida orden y tiempo y
## avisa con senales. Se detiene con stop() cuando el objetivo se ha cumplido
## (por ejemplo, la cucaracha ha muerto). Caso base: una tecla, sin orden ni ritmo.

signal shown
signal step_ok(index: int)
signal step_failed(index: int)
signal sequence_completed

@export var sequence: InputSequence
@export var key_prompt_scene: PackedScene
## Segundos sin entrada antes de mostrar la ayuda la primera vez. Generoso, para
## dejar que el jugador mire la escena y lo deduzca por su cuenta.
@export var idle_delay: float = 18.0
## Segundos sin entrada antes de volver a mostrarla si el jugador sigue sin pulsar.
@export var retry_delay: float = 12.0
## Segundos que permanece visible cada vez antes de retirarse sola. 0 = hasta que se pulse.
@export var show_duration: float = 5.0
## Si es verdadero, la ayuda sigue saliendo hasta stop() aunque el jugador ya haya
## pulsado bien. Si es falso, en cuanto el jugador pulsa la tecla (con la ayuda a la
## vista o antes de que salga) se da por aprendida y no vuelve a aparecer.
@export var repeat_until_stopped: bool = false
## Separacion entre teclas de la fila, relativa a su anchura.
@export var spacing_factor: float = 1.35
@export var key_size_px: float = 220.0
@export var start_enabled: bool = true

var idle_time := 0.0
var showing := false
var stopped := false
var shown_once := false
var prompts: Array = []
var step_idx := 0
var step_time := 0.0
var show_time := 0.0

func _ready() -> void:
	stopped = not start_enabled
	set_process_input(true)

func start() -> void:
	stopped = false
	idle_time = 0.0

## Termina la ayuda: oculta lo que haya y no vuelve a mostrarse.
func stop() -> void:
	stopped = true
	if showing:
		_hide_prompts()

func _process(delta: float) -> void:
	if stopped or sequence == null or sequence.steps.is_empty():
		return
	if showing:
		var step: InputStep = sequence.steps[step_idx]
		if step.time_window > 0.0:
			step_time += delta
			if step_time > step.time_window:
				_fail_step()
		# Se retira sola tras un rato y volvera a salir pasado retry_delay.
		show_time += delta
		if show_duration > 0.0 and show_time >= show_duration:
			_hide_prompts()
			idle_time = 0.0
		return
	idle_time += delta
	var threshold := idle_delay if not shown_once else retry_delay
	if idle_time >= threshold:
		_show()

func _input(event: InputEvent) -> void:
	if stopped:
		return
	var is_press := (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed() and not event.is_echo()
	if not is_press:
		return
	idle_time = 0.0
	if not showing:
		# El jugador la pulsa por su cuenta antes de que salga la ayuda: ya la conoce.
		if not repeat_until_stopped and sequence.steps.size() == 1:
			for a in sequence.steps[0].actions:
				if InputMap.has_action(a) and event.is_action_pressed(a):
					stopped = true
					return
		return
	var step: InputStep = sequence.steps[step_idx]
	for a in step.actions:
		if InputMap.has_action(a) and event.is_action_pressed(a):
			_complete_step()
			return
	# Una tecla de la secuencia pero fuera de orden: fallo. Otras teclas se ignoran.
	for other in sequence.steps:
		for a in other.actions:
			if InputMap.has_action(a) and event.is_action_pressed(a):
				_fail_step()
				return

func _show() -> void:
	showing = true
	shown_once = true
	step_idx = 0
	step_time = 0.0
	show_time = 0.0
	prompts.clear()
	var n := sequence.steps.size()
	var spacing := key_size_px * spacing_factor
	for i in range(n):
		var step: InputStep = sequence.steps[i]
		var kp: KeyPrompt = key_prompt_scene.instantiate()
		kp.key_size_px = key_size_px
		if sequence.beat_interval > 0.0:
			kp.press_period = sequence.beat_interval
		kp.setup(step.actions[0] if not step.actions.is_empty() else &"")
		kp.position = Vector2((i - (n - 1) / 2.0) * spacing, 0)
		add_child(kp)
		kp.appear(i == 0)
		prompts.append(kp)
	shown.emit()

func _complete_step() -> void:
	var last := step_idx >= sequence.steps.size() - 1
	var kp: KeyPrompt = prompts[step_idx]
	kp.succeed(last)
	step_ok.emit(step_idx)
	if last:
		showing = false
		idle_time = 0.0
		sequence_completed.emit()
		var to_fade := prompts.duplicate()
		for other in to_fade:
			if other != kp:
				other.disappear()
		kp.finished.connect(func(): _free_prompts(to_fade), CONNECT_ONE_SHOT)
		if not repeat_until_stopped:
			stopped = true
	else:
		step_idx += 1
		step_time = 0.0
		prompts[step_idx].set_active(true)

func _fail_step() -> void:
	step_failed.emit(step_idx)
	for kp in prompts:
		kp.fail()
		kp.set_active(false)
	step_idx = 0
	step_time = 0.0
	if not prompts.is_empty():
		prompts[0].set_active(true)

func _hide_prompts() -> void:
	showing = false
	var to_free := prompts.duplicate()
	prompts.clear()
	for kp in to_free:
		kp.disappear()
	if not to_free.is_empty():
		to_free[0].finished.connect(func(): _free_prompts(to_free), CONNECT_ONE_SHOT)

func _free_prompts(list: Array) -> void:
	for kp in list:
		if is_instance_valid(kp):
			kp.queue_free()
	if prompts == list:
		prompts.clear()
