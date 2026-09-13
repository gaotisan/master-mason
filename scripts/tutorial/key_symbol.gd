extends Node2D
## Dibuja el simbolo de una tecla sobre la cara de la tecla: flecha para los
## cursores, texto para el resto. Grabado: sombra oscura debajo y dorado encima.

var kind: String = "text"
var direction: Vector2 = Vector2.UP
var text: String = ""
var color: Color = Color(0.92, 0.78, 0.5)
var shadow_color: Color = Color(0.08, 0.05, 0.02, 0.9)
## Tamano del simbolo en unidades locales (la tecla escala este nodo).
var size: float = 100.0

func set_from_action(action: StringName) -> void:
	var info = describe_action(action)
	kind = info.get("kind", "text")
	direction = info.get("dir", Vector2.UP)
	text = info.get("text", "")
	queue_redraw()

## Traduce una accion del InputMap al simbolo de la primera tecla asignada.
static func describe_action(action: StringName) -> Dictionary:
	if not InputMap.has_action(action):
		return {"kind": "text", "text": String(action)}
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var kc: Key = ev.keycode if ev.keycode != KEY_NONE else ev.physical_keycode
			match kc:
				KEY_UP: return {"kind": "arrow", "dir": Vector2.UP}
				KEY_DOWN: return {"kind": "arrow", "dir": Vector2.DOWN}
				KEY_LEFT: return {"kind": "arrow", "dir": Vector2.LEFT}
				KEY_RIGHT: return {"kind": "arrow", "dir": Vector2.RIGHT}
				KEY_SPACE: return {"kind": "text", "text": "SPACE"}
				KEY_ENTER: return {"kind": "text", "text": "ENTER"}
				KEY_ESCAPE: return {"kind": "text", "text": "ESC"}
				_: return {"kind": "text", "text": OS.get_keycode_string(kc)}
	return {"kind": "text", "text": String(action)}

func _draw() -> void:
	if kind == "arrow":
		_draw_arrow(Vector2(0, 3), shadow_color)
		_draw_arrow(Vector2.ZERO, color)
	else:
		var font: Font = ThemeDB.fallback_font
		var font_size := int(size * (0.55 if text.length() <= 2 else 0.32))
		var w := size * 1.6
		var pos := Vector2(-w / 2.0, font_size * 0.36)
		draw_string(font, pos + Vector2(0, 3), text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, shadow_color)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, color)

func _draw_arrow(offset: Vector2, col: Color) -> void:
	var s := size * 0.5
	# Flecha apuntando arriba, luego se rota hacia la direccion pedida.
	var pts := PackedVector2Array([
		Vector2(0, -s), Vector2(s * 0.75, -s * 0.1), Vector2(s * 0.3, -s * 0.1),
		Vector2(s * 0.3, s), Vector2(-s * 0.3, s), Vector2(-s * 0.3, -s * 0.1),
		Vector2(-s * 0.75, -s * 0.1)
	])
	var ang := direction.angle() + PI / 2.0
	for i in range(pts.size()):
		pts[i] = pts[i].rotated(ang) + offset
	draw_colored_polygon(pts, col)
