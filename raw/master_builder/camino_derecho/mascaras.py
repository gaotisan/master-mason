"""Mascaras del plano del CAMINO DERECHO del cruce (frontal: el camino en el eje
de la camara, como el camino del bosque). Fuente: fondo_suavizado.png (la de
Midjourney, fondo_midjourney.png, traia un relieve de grabado en todo: quitado
con un suavizado que respeta bordes, a la mitad y vuelta a subir; comparado con
el cruce a tamano de pantalla, casa). El color, al del camino del bosque.

  python mascaras.py   -> assets/world/camino_derecho/
"""
import importlib.util
import os

AQUI = os.path.dirname(os.path.realpath(__file__))
spec = importlib.util.spec_from_file_location("fondo_vivo", os.path.join(AQUI, "..", "fondo_vivo.py"))
fv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fv)

CFG = {
	# el resplandor: la luz del fondo del camino, entre las copas
	"fuente": (1500.0, 640.0),
	"copa_y": (560.0, 1080.0),
	# donde se pierde el suelo (el peregrino: peregrino_sendero.gd, horizonte)
	"horizonte": 1120.0,
	# el pie de los arboles y rocas a lo ancho (los grandes de los lados, cerca)
	"base": [(0, 1500), (500, 1350), (900, 1230), (1200, 1180), (1500, 1165), (1800, 1185), (2100, 1240),
			 (2500, 1330), (2912, 1480)],
	"hojas_x": (700, 2250),
	"hojas_y": 800,
}

if __name__ == "__main__":
	proyecto = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
	fv.generar(os.path.join(AQUI, "fondo_suavizado.png"), os.path.join(proyecto, "assets", "world", "camino_derecho"), CFG)
