"""Monta la parada y el reposo sin baston, de frente y de espaldas.

Videos (Veo, 1280x720, 24 fps, 240 f, croma; nombres originales con "..." en
medio, copiados con nombre limpio en _fuentes):
  frente  Pilgrim_breathing_front_20261008110622.mp4: viene dando unos pasos
          hacia la camara (crece de raiz 208 a 237, los pies bajan de 589 a 623),
          se asienta hacia el 75 y luego queda quieto respirando muy poco.
  espalda Pilgrim_breathing_back_20261008110942.mp4: de espaldas, quieto,
          respirando todo el video (tamano constante, pies en 589).

Frente: cada fotograma con SU tamano (raiz del area, mediana movil de 9 para
quitar el ruido de los brazos) llevado a OBJ y el suelo por la recta suelo ~
raiz (camara fija). Se guarda cuanto crece cada fotograma respecto al ultimo
(escala_relativa) para que la escena acerque al personaje igual que el video.
Espaldas: escala, suelo y eje fijos (medianas): lo que cambia es la respiracion.
OBJ como en los andares: capucha-pies 628 en el reposo.
Lee _sin_normalizar/ (croma.py sobre 03_seleccion = video 1-240) de cada job y
escribe su 04_limpios/c_###.png (los 240) y medidas.json.
    python montar.py
"""
import glob, json, os
import numpy as np
from PIL import Image
from scipy.ndimage import binary_opening, median_filter

ANIM = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAS = (584, 720); SUELO = 677; EJE = 292


def medir(job):
    raiz, pie, cx, alto = [], [], [], []
    for f in sorted(glob.glob(os.path.join(ANIM, job, '01_frames', 'f_*.png'))):
        a = np.asarray(Image.open(f).convert('RGB')).astype(np.int16)
        m = (a[..., 1] - np.maximum(a[..., 0], a[..., 2])) < 45
        ys = np.nonzero(m.any(1))[0]; y0, y1 = ys.min(), ys.max()
        raiz.append(np.sqrt(m.sum())); pie.append(y1)
        cx.append(float(np.median(np.nonzero(m[int(y0 + 0.35 * (y1 - y0)):int(y0 + 0.6 * (y1 - y0))])[1])))
        o = binary_opening(m, structure=np.ones((1, 17)))
        alto.append(y1 - np.nonzero(o.any(1))[0].min())
    return np.array(raiz), np.array(pie, float), np.array(cx), np.array(alto, float)


def escribir(job, esc, pie, cx):
    sal = os.path.join(ANIM, job, '04_limpios')
    for f in glob.glob(os.path.join(sal, '*.png')):
        os.remove(f)
    fs = sorted(glob.glob(os.path.join(ANIM, job, '_sin_normalizar', '*.png')))
    for k, f in enumerate(fs):
        im = Image.open(f).convert('RGBa')
        im = im.resize((round(im.width * esc[k]), round(im.height * esc[k])), Image.LANCZOS).convert('RGBA')
        c = Image.new('RGBA', CAS, (0, 0, 0, 0))
        c.paste(im, (round(EJE - cx[k] * esc[k]), round(SUELO - pie[k] * esc[k])))
        c.save(os.path.join(sal, 'c_%03d.png' % (k + 1)))


medidas = {}
# --- frente
J = 'magnus_reposo_frente_sin'
raiz, pie, cx, alto = medir(J)
rs = median_filter(raiz, 9, mode='nearest')
quieto = slice(100, 240)
obj = 628 / float(np.median(alto[quieto] / rs[quieto]))
q = np.polyfit(rs, pie, 1)
cxs = median_filter(cx, 9, mode='nearest')
escribir(J, obj / rs, np.polyval(q, rs), cxs)
medidas[J] = {'obj': obj, 'escala_relativa': [round(float(v), 4) for v in rs / rs[-1]],
              'suelo': [round(float(q[1]), 2), round(float(q[0]), 4)]}
print(J, 'OBJ %.1f, crece %.3f -> 1, suelo = %.1f + %.3f raiz' % (obj, rs[0] / rs[-1], q[1], q[0]))

# --- espaldas
J = 'magnus_reposo_espalda_sin'
raiz, pie, cx, alto = medir(J)
r = float(np.median(raiz))
obj = 628 / float(np.median(alto / raiz))
n = len(raiz)
escribir(J, np.full(n, obj / r), np.full(n, float(np.median(pie))), np.full(n, float(np.median(cx))))
medidas[J] = {'obj': obj}
print(J, 'OBJ %.1f, raiz %.1f, pies %.0f' % (obj, r, np.median(pie)))
json.dump(medidas, open(os.path.join(ANIM, 'magnus_reposo_frente_sin', 'medidas.json'), 'w'), indent=1)
