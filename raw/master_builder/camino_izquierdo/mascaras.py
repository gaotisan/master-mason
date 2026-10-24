"""Mascaras del plano del CAMINO IZQUIERDO del cruce (en TRES CUARTOS: el camino
cruza de abajo a la derecha hacia arriba a la izquierda y se pierde en la
niebla; el peregrino va en diagonal, peregrino_tres_cuartos.gd). La luz entra
por arriba a la derecha (la de la casa, desde este camino, queda a su derecha).
El color, al del camino del bosque.

  python mascaras.py   -> assets/world/camino_izquierdo/
"""
import importlib.util
import os

AQUI = os.path.dirname(os.path.realpath(__file__))
spec = importlib.util.spec_from_file_location("fondo_vivo", os.path.join(AQUI, "..", "fondo_vivo.py"))
fv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fv)

CFG = {
	"fuente": (2420.0, 520.0),
	"copa_y": (500.0, 1000.0),
	"horizonte": 1000.0,
	# el pie de lo que se levanta: los arboles de la izquierda tras el monte, la
	# niebla del fondo, el arbol fino, el gran tronco de la derecha
	"base": [(0, 1250), (400, 1120), (900, 1040), (1400, 1030), (1900, 1060), (2300, 1100), (2700, 1180),
			 (2912, 1300)],
	"hojas_x": (1700, 2800),
	"hojas_y": 900,
}

if __name__ == "__main__":
	proyecto = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
	fv.generar(os.path.join(AQUI, "fondo_midjourney.png"), os.path.join(proyecto, "assets", "world", "camino_izquierdo"), CFG)
