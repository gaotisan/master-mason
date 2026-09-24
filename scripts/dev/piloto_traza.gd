extends "res://scripts/dev/piloto.gd"
## Piloto que ademas imprime, cada tick, el estado interno del personaje en la
## ventana de tiempo pedida. Para ver que hace el script sin grabar video:
##   godot --headless --path . --quit-after 240 res://scenes/dev/piloto_traza.tscn

@export var desde: float = 2.4
@export var hasta: float = 3.7

func _physics_process(delta: float) -> void:
	super(delta)
	var p := get_node_or_null(personaje)
	if p == null or _t < desde or _t > hasta:
		return
	var s: AnimatedSprite2D = p.get_node("Sprite")
	print("traza %.3f estado=%d anim=%s f=%d prog=%.2f x=%.1f spr_y=%.1f vel=%.1f speed=%.2f" % [
		_t, p._estado, s.animation, s.frame, s.frame_progress, p.position.x, s.position.y, p._velocidad(), s.speed_scale])
