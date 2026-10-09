"""Puentes por flujo optico de la vuelta SIN baston (el baston va a la espalda).

Como magnus_puentes_frontal/puente.py (de ahi se cogen el flujo y la mezcla),
para vuelta_frontal_sin: el usuario veia un emborronado al inicio y al final de
la vuelta con el baston a la espalda (eran fundidos de opacidad entre dibujos
de videos distintos). Casilla comun 584x720. Sin baston tambien se gira desde
la parada y el reposo, asi que hay puentes con ellos:
  puente_frente_sin         andar_frente_sin c_024 -> vuelta_sin c_001
  puente_frente_sin_b       andar_frente_sin c_001 -> vuelta_sin c_001
  puente_reposo_frente_sin  reposo_frente_sin fotograma 13 (c_173) -> vuelta_sin c_001
  puente_espalda_sin        vuelta_sin c_055 -> andar_espalda_sin c_009
  puente_espalda_sin_b      andar_espalda_sin c_024 -> vuelta_sin c_055
  puente_reposo_espalda_sin vuelta_sin c_055 -> reposo_espalda_sin fotograma 20 (c_156)
(cada uno, al reves, sirve para el otro sentido). El reposo respira muy poco
(0,018 por fotograma): desde cualquier fotograma del reposo se entra al puente
por su primer intermedio sin que se note.
El baston de la espalda (frontal.json "baston_espalda") se interpola entre el
de los extremos: escribe baston.json.
    python puente_sin.py
"""
import glob, importlib.util, json, os
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
spec = importlib.util.spec_from_file_location('puente', os.path.join(ANIM, 'magnus_puentes_frontal', 'puente.py'))
P = importlib.util.module_from_spec(spec); spec.loader.exec_module(P)
P.ALTO = 720; P.SUBE = 0


def sp(job, k):
    return Image.open(os.path.join(ANIM, job, '04_limpios', 'c_%03d.png' % k)).convert('RGBA')


# nombre: (imagen A, (anim, fotograma) en baston_espalda, imagen B, idem)
PUENTES = {
    'puente_frente_sin':         (('magnus_andar_frente_sin', 24), ('andar_frente_sin', 23),
                                  ('magnus_vuelta_frontal_sin', 1), ('vuelta_frontal_sin', 0)),
    'puente_frente_sin_b':       (('magnus_andar_frente_sin', 1), ('andar_frente_sin', 0),
                                  ('magnus_vuelta_frontal_sin', 1), ('vuelta_frontal_sin', 0)),
    'puente_reposo_frente_sin':  (('magnus_reposo_frente_sin', 173), ('reposo_frente_sin', 13),
                                  ('magnus_vuelta_frontal_sin', 1), ('vuelta_frontal_sin', 0)),
    'puente_espalda_sin':        (('magnus_vuelta_frontal_sin', 55), ('vuelta_frontal_sin', 54),
                                  ('magnus_andar_espalda_sin', 9), ('andar_espalda_sin', 8)),
    'puente_espalda_sin_b':      (('magnus_andar_espalda_sin', 24), ('andar_espalda_sin', 23),
                                  ('magnus_vuelta_frontal_sin', 55), ('vuelta_frontal_sin', 54)),
    'puente_reposo_espalda_sin': (('magnus_vuelta_frontal_sin', 55), ('vuelta_frontal_sin', 54),
                                  ('magnus_reposo_espalda_sin', 156), ('reposo_espalda_sin', 20)),
}
ESPALDA = json.load(open(os.path.join(P.BASTON, 'frontal.json')))['baston_espalda']
SAL = os.path.join(AQUI, '04_limpios'); os.makedirs(SAL, exist_ok=True)
for f in glob.glob(os.path.join(SAL, '*.png')):
    os.remove(f)
baston = {}
for nombre, (ia, ba, ib, bb) in PUENTES.items():
    frames = P.puente(sp(*ia), sp(*ib))
    ra, rb = ESPALDA[ba[0]][ba[1]], ESPALDA[bb[0]][bb[1]]
    baston[nombre] = []
    for k, im in enumerate(frames, 1):
        im.save(os.path.join(SAL, '%s_%d.png' % (nombre, k)))
        t = k / (P.N + 1)
        fila = [round(ra[i] * (1 - t) + rb[i] * t, 4) for i in range(3)] + [ra[3], ra[4]]
        baston[nombre].append(fila)
    print(nombre, len(frames), 'intermedios; baston', 'delante' if ra[3] else 'detras')
json.dump(baston, open(os.path.join(AQUI, 'baston.json'), 'w'), indent=1)
