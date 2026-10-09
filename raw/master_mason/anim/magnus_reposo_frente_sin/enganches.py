"""Busca los enganches del andar sin baston con la parada / el reposo y los bucles.

Distancia de siempre: 10 x media |A - B| en RGB premultiplicado, a media
resolucion, de la cintura para abajo NO (aqui cuenta todo el cuerpo: lo que
salta en un enganche es la tunica entera).
  - frente: que fotograma del andar_frente_sin se parece mas a cada uno de los
    primeros de la parada (el video entra andando): por ahi se pasa del andar
    a la parada. Y el bucle del reposo en lo quieto (100-240): el par (a, b)
    con b - a de 40 a 110 que mejor cierra.
  - espaldas: el bucle de respiracion y por que fotograma del andar_espalda_sin
    se entra a el (el mas parecido a algun fotograma del bucle).
    python enganches.py
"""
import glob, os
import numpy as np
from PIL import Image

ANIM = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def cargar(job):
    out = []
    for f in sorted(glob.glob(os.path.join(ANIM, job, '04_limpios', 'c_*.png'))):
        a = np.asarray(Image.open(f).convert('RGBa').resize((292, 360), Image.BILINEAR)).astype(np.float32) / 255
        out.append(a)
    return np.array(out)


def d(a, b):
    return float(10 * np.abs(a - b).mean())


def bucle(V, a0, a1, pmin, pmax):
    paso = np.median([d(V[i], V[i + 1]) for i in range(a0, a1 - 1)])
    mejor = min((d(V[a], V[b]), a, b) for a in range(a0, a1) for b in range(a + pmin, min(a + pmax, a1))
                if True)
    return mejor, paso


FS = cargar('magnus_reposo_frente_sin')
AF = cargar('magnus_andar_frente_sin')
print('FRENTE: entrada andar -> parada')
for k in range(0, 24, 2):
    ds = [d(FS[k], x) for x in AF]
    j = int(np.argmin(ds)); print('  parada c_%03d ~ andar c_%03d a %.3f' % (k + 1, j + 1, ds[j]))
(m, a, b), paso = bucle(FS, 99, 240, 40, 110)
print('FRENTE reposo: bucle c_%03d -> c_%03d (cierre %.3f, paso medio %.3f, %d f)' % (a + 1, b + 1, m, paso, b - a))
print('  cambio por fotograma 60-110:', ' '.join('%d:%.3f' % (i + 1, d(FS[i], FS[i + 1])) for i in range(60, 110, 3)))

ES = cargar('magnus_reposo_espalda_sin')
AE = cargar('magnus_andar_espalda_sin')
(m, a, b), paso = bucle(ES, 0, 220, 40, 110)
print('ESPALDA reposo: bucle c_%03d -> c_%03d (cierre %.3f, paso medio %.3f, %d f)' % (a + 1, b + 1, m, paso, b - a))
mejor = min((d(AE[j], ES[k]), j, k) for j in range(len(AE)) for k in range(a, b))
print('  entrada: andar_espalda_sin c_%03d ~ reposo c_%03d a %.3f' % (mejor[1] + 1, mejor[2] + 1, mejor[0]))
for j in (7, 22):
    k = min(range(a, b), key=lambda k: d(AE[j], ES[k]))
    print('  pies juntos andar c_%03d ~ reposo c_%03d a %.3f' % (j + 1, k + 1, d(AE[j], ES[k])))
