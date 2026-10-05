"""Mide los enlaces del andar agachado y saca las tablas de magnus.gd.

Distancia entre dos sprites: 10 x la media de |A - B| en RGB premultiplicado
(0-1), sobre la caja que ocupan los dos. Es la de siempre en este proyecto (el
paso del agachado quieto da 0,033 con esta, el del ciclo 0,170).

  ciclo -> agachado quieto        no casa desde ningun fotograma (por eso hay
                                  arranque y parada)
  PARADA_AGACHADO_DESDE           fotograma del ciclo -> fotograma de la parada
                                  por el que entrar, los que quedan a 1,3 pasos
                                  o menos
  PARADA_AGACHADO_A_AGACHADO      fotograma del bucle agachado (la ida y vuelta
                                  76..88, 87..77, 24) que mas se parece al final
                                  de la parada
  arranque                        su principio contra el bucle y su final contra
                                  el ciclo (ENTRADA_AGACHADO es el siguiente)

Se corre desde este job, con los tres (ciclo, arranque, parada) ya en
04_limpios y movidos (mover.py).
    python tablas.py
"""
import glob, os
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
BUCLE = list(range(76, 89)) + list(range(87, 76, -1))            # casillas de la hoja de agacharse (como en _spriteframes.py)
TOLERANCIA = 1.3                                                  # pasos del ciclo


def leer(f):
    im = np.asarray(Image.open(f).convert('RGBA')).astype(float) / 255
    return np.concatenate([im[..., :3] * im[..., 3:], im[..., 3:]], 2)


def carpeta(job):
    return [leer(f) for f in sorted(glob.glob(os.path.join(ANIM, job, '04_limpios', 'c_*.png')))]


def d(a, b):
    m = (a[..., 3] > 0) | (b[..., 3] > 0)
    ys, xs = np.where(m)
    c = (slice(ys.min(), ys.max() + 1), slice(xs.min(), xs.max() + 1))
    return 10 * np.abs(a[c][..., :3] - b[c][..., :3]).mean()


ciclo = carpeta('magnus_andar_agachado')
arranque = carpeta('magnus_arranque_agachado')
parada = carpeta('magnus_parada_agachado')
agachado = [leer(os.path.join(ANIM, 'magnus_agacharse', '04_limpios', 'c_%03d.png' % (k + 1))) for k in BUCLE]
paso = float(np.median([d(ciclo[i], ciclo[i + 1]) for i in range(len(ciclo) - 1)]))
print('paso del ciclo %.3f; cierre c_%02d -> c_01 %.3f' % (paso, len(ciclo), d(ciclo[-1], ciclo[0])))
al_agachado = [min(d(c, a) for a in agachado[::4]) for c in ciclo]
print('ciclo -> agachado: de %.2f a %.2f pasos' % (min(al_agachado) / paso, max(al_agachado) / paso))

desde = {}
for j, c in enumerate(ciclo):
    ds = [d(c, p) for p in parada[:12]]
    k = int(np.argmin(ds))
    if ds[k] <= TOLERANCIA * paso:
        desde[j] = k
    print('c_%02d -> parada p_%02d  %.2f pasos%s' % (j + 1, k + 1, ds[k] / paso, '  <-' if j in desde else ''))
fin = [d(parada[-1], a) for a in agachado]
ini = [d(arranque[0], a) for a in agachado]
entra = [d(arranque[-1], c) for c in ciclo]
e = int(np.argmin(entra))
print('parada -> agachado: %.2f pasos por el %d' % (min(fin) / paso, int(np.argmin(fin))))
print('agachado -> arranque: %.2f-%.2f pasos' % (min(ini) / paso, max(ini) / paso))
print('arranque -> ciclo: su final ~ c_%02d a %.2f pasos' % (e + 1, entra[e] / paso))
print()
print('const ENTRADA_AGACHADO := %d' % ((e + 1) % len(ciclo)))
print('const PARADA_AGACHADO_DESDE := {%s}' % ', '.join('%d: %d' % kv for kv in sorted(desde.items(), key=lambda kv: (kv[0] < 20, kv[0]))))
print('const PARADA_AGACHADO_A_AGACHADO := %d' % int(np.argmin(fin)))
