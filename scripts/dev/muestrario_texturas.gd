extends Node2D
## Desechable: pinta fotogramas sueltos de varias animaciones de Magnus en
## rejilla, a escala 1 (la del viewport) y a 0,527 (la de una pantalla de
## 1536x864), para comparar la importacion de las hojas grabando un fotograma.

const MUESTRAS := [["reposo", 0], ["andar", 10], ["correr", 5], ["saltar", 30],
	["salto_parado", 50], ["salto_correr", 18], ["giro", 2], ["caida", 12],
	["levantarse", 40], ["agacharse", 60], ["incorporarse", 20], ["parada_correr", 10]]

func _ready() -> void:
	var frames: SpriteFrames = load("res://resources/characters/magnus_frames.tres")
	var voltear := "voltear" in OS.get_cmdline_user_args()
	for i in MUESTRAS.size():
		for escala in [1.0, 0.527]:
			var s := Sprite2D.new()
			s.texture = frames.get_frame_texture(MUESTRAS[i][0], MUESTRAS[i][1])
			s.scale = Vector2(escala, escala)
			s.flip_h = voltear
			var col := i % 6
			var fila := i / 6
			if escala == 1.0:
				s.position = Vector2(200 + col * 400, 220 + fila * 380)
			else:
				s.position = Vector2(140 + col * 230, 1050 + fila * 230)
			add_child(s)
