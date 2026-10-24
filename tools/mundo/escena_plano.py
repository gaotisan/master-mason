"""Escribe la escena (.tscn) de un plano del bosque detras del camino: la misma
estructura que el camino del bosque (Fondo con camino_fondo.gdshader, AireVista
con camino_aire.gdshader, HojasCopa, Peregrino, Hojas, Motas) con las mascaras
de assets/world/<plano>/ (raw/master_builder/<plano>/mascaras.py).

  python tools/mundo/escena_plano.py   (todos los planos de PLANOS)
"""
import os

PROYECTO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def v2(p):
	return "Vector2(%g, %g)" % tuple(p)


def valor(v):
	if isinstance(v, str):
		return v if v.startswith(("Vector", "Packed", "ExtResource", "&")) else '"%s"' % v
	if isinstance(v, bool):
		return "true" if v else "false"
	if isinstance(v, float):
		return "%g" % v if "e" not in "%g" % v and "." in "%g" % v else "%.1f" % v
	return str(v)


def escena(plano, raiz, script_raiz, script_peregrino, props_raiz, props_peregrino, foco, fuga, fuente, suelo_y):
	w = "res://assets/world/%s/" % plano
	lin = ['[gd_scene load_steps=16 format=3]', '',
		   '[ext_resource type="Script" path="%s" id="1"]' % script_raiz,
		   '[ext_resource type="Texture2D" path="%sfondo.png" id="2"]' % w,
		   '[ext_resource type="Shader" path="res://scripts/game/camino_fondo.gdshader" id="3"]',
		   '[ext_resource type="Shader" path="res://scripts/game/camino_aire.gdshader" id="4"]',
		   '[ext_resource type="Texture2D" path="%sviento.png" id="5"]' % w,
		   '[ext_resource type="Texture2D" path="%smedio.png" id="6"]' % w,
		   '[ext_resource type="Texture2D" path="%saire.png" id="7"]' % w,
		   '[ext_resource type="Texture2D" path="res://assets/world/camino_bosque/ruido.png" id="8"]',
		   '[ext_resource type="Script" path="res://scripts/game/hojas_otono.gd" id="9"]',
		   '[ext_resource type="Script" path="res://scripts/game/motas_luz.gd" id="10"]',
		   '[ext_resource type="Script" path="res://scripts/game/hojas_copa.gd" id="12"]',
		   '[ext_resource type="Texture2D" path="%sprofundidad.png" id="17"]' % w,
		   '[ext_resource type="Texture2D" path="%sdetras.png" id="18"]' % w,
		   '[ext_resource type="Script" path="%s" id="19"]' % script_peregrino, '',
		   '[sub_resource type="ShaderMaterial" id="fondo"]', 'shader = ExtResource("3")',
		   'shader_parameter/viento_m = ExtResource("5")', 'shader_parameter/prof = ExtResource("17")',
		   'shader_parameter/detras = ExtResource("18")', 'shader_parameter/medio = ExtResource("6")',
		   'shader_parameter/ruido = ExtResource("8")', 'shader_parameter/foco = %s' % v2(foco),
		   'shader_parameter/suelo_y = %s' % valor(float(suelo_y)), '',
		   '[sub_resource type="ShaderMaterial" id="aire"]', 'shader = ExtResource("4")',
		   'shader_parameter/ruido = ExtResource("8")', 'shader_parameter/mascara = ExtResource("7")',
		   'shader_parameter/profundidad = ExtResource("5")', 'shader_parameter/fuga = %s' % v2(fuga),
		   'shader_parameter/fuente = %s' % v2(fuente), '',
		   '[node name="%s" type="Node2D"]' % raiz, 'script = ExtResource("1")']
	lin += ['%s = %s' % (k, valor(v)) for k, v in props_raiz.items()]
	lin += ['', '[node name="Fondo" type="Sprite2D" parent="."]', 'z_index = -10', 'texture_filter = 2',
			'material = SubResource("fondo")', 'texture = ExtResource("2")', 'centered = false', '',
			'[node name="AireVista" type="SubViewport" parent="."]', 'disable_3d = true', 'size = Vector2i(728, 408)',
			'render_target_update_mode = 4', '',
			'[node name="Aire" type="ColorRect" parent="AireVista"]', 'material = SubResource("aire")',
			'offset_right = 728.0', 'offset_bottom = 408.0', 'mouse_filter = 2', '',
			'[node name="HojasCopa" type="Node2D" parent="."]', 'script = ExtResource("12")',
			'puntos = "%shojas_copa.json"' % w, 'medio = ExtResource("6")', 'profundidad = ExtResource("5")', '',
			'[node name="Peregrino" type="Node2D" parent="."]', 'script = ExtResource("19")',
			'medio = ExtResource("6")', 'profundidad = ExtResource("17")']
	lin += ['%s = %s' % (k, valor(v)) for k, v in props_peregrino.items()]
	lin += ['', '[node name="Hojas" type="Node2D" parent="."]', 'z_index = 6', 'script = ExtResource("9")',
			'medio = ExtResource("6")', 'ramas = ExtResource("5")', 'fuga = %s' % v2(fuga), '',
			'[node name="Motas" type="Node2D" parent="."]', 'z_index = 6', 'script = ExtResource("10")',
			'mascara = ExtResource("7")', '']
	ruta = os.path.join(PROYECTO, "scenes", "game", plano + ".tscn")
	open(ruta, "w", encoding="utf-8", newline="\n").write("\n".join(lin))
	print("->", ruta)


def camino(puntos):
	return "PackedVector3Array(%s)" % ", ".join("%g, %g, %g" % p for p in puntos)


PLANOS = [
	dict(plano="cruce_bosque", raiz="CruceBosque", script_raiz="res://scripts/game/cruce_bosque.gd",
		 script_peregrino="res://scripts/game/peregrino_cruce.gd",
		 props_raiz={"escena_anterior": "res://scenes/game/camino_bosque.tscn", "escena_siguiente": "",
					 "nombre_escena": "cruce_bosque", "corte_musica_s": 0.12, "tension_hacia": "Vector2(1500, 1100)"},
		 props_peregrino={"horizonte": 1000.0, "pies_tope": 1560.0, "exposicion": 1.0, "saturacion": 0.65,
						  "camino": camino([(1480, 1490, 1490), (1470, 1400, 1400), (1478, 1290, 1290), (1490, 1190, 1190),
											(1497, 1120, 1120), (1500, 1062, 1062)]),
						  "pies_inicio": 1490.0, "pies_corte_vuelta": 1522.0, "z_salida": 1080.0,
						  "nombre_salida": "casa", "z_niebla": "Vector2(1135, 1068)", "resplandor": "Vector2(1630, 560)",
						  "entra_de": "camino_bosque"},
		 foco=(1500, 1000), fuga=(1500, 1040), fuente=(1630, 560), suelo_y=1080),
	dict(plano="camino_derecho", raiz="CaminoDerecho", script_raiz="res://scripts/game/plano_bosque.gd",
		 script_peregrino="res://scripts/game/peregrino_sendero.gd",
		 props_raiz={"escena_anterior": "res://scenes/game/cruce_bosque.tscn", "escena_siguiente": "",
					 "nombre_escena": "camino_derecho", "corte_musica_s": 0.12, "tension_hacia": "Vector2(1490, 1300)"},
		 # el camino sube despacio entre las rocas: y algo por encima de z al fondo
		 props_peregrino={"horizonte": 1120.0, "pies_tope": 1620.0, "exposicion": 1.0, "saturacion": 0.65,
						  "camino": camino([(1490, 1560, 1560), (1490, 1450, 1455), (1495, 1350, 1360), (1500, 1270, 1285),
											(1495, 1210, 1232), (1490, 1170, 1200), (1490, 1150, 1180)]),
						  "pies_inicio": 1540.0, "pies_corte_vuelta": 1585.0, "z_salida": 1205.0,
						  "nombre_salida": "fondo", "z_niebla": "Vector2(1250, 1195)", "resplandor": "Vector2(1500, 640)",
						  "entra_de": "cruce_bosque"},
		 foco=(1490, 1150), fuga=(1490, 1150), fuente=(1500, 640), suelo_y=1180),
	# en tres cuartos: el camino cruza en diagonal; el peregrino, el de tres cuartos
	dict(plano="camino_izquierdo", raiz="CaminoIzquierdo", script_raiz="res://scripts/game/plano_bosque.gd",
		 script_peregrino="res://scripts/characters/peregrino_tres_cuartos.gd",
		 props_raiz={"escena_anterior": "res://scenes/game/cruce_bosque.tscn", "escena_siguiente": "",
					 "nombre_escena": "camino_izquierdo", "corte_musica_s": 0.12, "tension_hacia": "Vector2(1600, 1300)"},
		 props_peregrino={},
		 foco=(1221, 1050), fuga=(1221, 1050), fuente=(2420, 520), suelo_y=1060),
]

if __name__ == "__main__":
	for p in PLANOS:
		escena(**p)
