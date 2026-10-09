"""La secuencia completa con baston de un solo video (coherencia de capucha y tunica).

Video: _fuentes/Pilgrim_walking_turning_full_20261008161217.mp4 (Veo, 1280x720,
24 fps, 240 f; nombre original con "..." en Descargas). El usuario lo pidio
porque la vuelta y los andares salian de videos distintos (la capucha cambiaba
de ancho). Trae todo seguido:
    1-28   quieto de frente, los dos pies en el suelo
   29-50   arranca hacia la camara
   50-105  anda hacia la camara (crece: capucha-pies 431 -> 493 px)
  105-121  se para
  121-153  la vuelta, en el sitio
  153-165  arranca alejandose
  165-212  se aleja (493 -> 411)
  213-240  se para y queda quieto de espaldas

Montaje: cada fotograma a la casilla de Magnus (584x720) con capucha-pies =
628 (como el reposo de perfil). Capucha-pies medido sin el baston (apertura
horizontal de 15 px) y suavizado (mediana 11 + gaussiana 3) para no meter el
bote del paso en el tamano; suelo por la recta suelo ~ altura (camara fija:
suelo = 324,2 + 0,622 h); eje del tronco suavizado (gaussiana 2).
Escribe _todos/c_001..c_240 y medidas.json (h suavizada por fotograma:
la escena la usa para escalar al personaje igual que el video).
    python montar.py
"""
import glob, json, os, sys
import numpy as np
from PIL import Image
from scipy.ndimage import median_filter, gaussian_filter1d

# job (por defecto, este): python montar.py magnus_secuencia_frontal_sin
_JOB = sys.argv[1] if len(sys.argv) > 1 else None
AQUI = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), _JOB) if _JOB else os.path.dirname(os.path.abspath(__file__))
CAS = (584, 800); SUELO = 757; EJE = 292; ALTO = 628.0   # casilla alta como la vuelta: la garra subia por encima de la de 720

r = np.array(json.load(open(os.path.join(AQUI, 'medidas_crudas.json'))), float)   # i, top, pie, h, cx, barba
h = r[:, 3]; pie = r[:, 2]; cx = r[:, 4]
hs = gaussian_filter1d(median_filter(h, 11, mode='nearest'), 3, mode='nearest')
q = np.polyfit(hs, pie, 1)
cxs = gaussian_filter1d(cx, 2, mode='nearest')
SAL = os.path.join(AQUI, '_todos')       # los 240; secuencia.py saca de aqui los que se usan a 04_limpios
os.makedirs(SAL, exist_ok=True)
for f in glob.glob(os.path.join(SAL, '*.png')):
    os.remove(f)
for k in range(len(r)):
    im = Image.open(os.path.join(AQUI, '_sin_normalizar', 'p_%03d.png' % (k + 1))).convert('RGBa')
    s = ALTO / hs[k]
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS).convert('RGBA')
    c = Image.new('RGBA', CAS, (0, 0, 0, 0))
    c.paste(im, (round(EJE - cxs[k] * s), round(SUELO - np.polyval(q, hs[k]) * s)))
    c.save(os.path.join(SAL, 'c_%03d.png' % (k + 1)))
json.dump({'h': [round(float(v), 3) for v in hs], 'suelo': [round(float(q[1]), 3), round(float(q[0]), 5)]},
          open(os.path.join(AQUI, 'medidas.json'), 'w'))
print('%d sprites; suelo = %.1f + %.3f h; h %.0f..%.0f' % (len(r), q[1], q[0], hs.min(), hs.max()))
