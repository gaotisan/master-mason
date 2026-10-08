"""Quita el acercamiento (o alejamiento) del video y deja el andar en el sitio.

Los videos de frente y de espaldas (Flow, 1280x720, croma verde, camara FIJA)
no andan en el sitio: el de frente se acerca (el personaje pasa de ~430 a ~690
px de alto) y el de espaldas se aleja (de ~620 a ~440). Para hacer un ciclo hay
que deshacer eso en cada fotograma, y luego en el juego el tamano lo pone la
profundidad.

Con camara fija y velocidad constante, el alto en pantalla es h = f*H/(Z0-v*t),
o sea que 1/h es una RECTA en el tiempo. El tamano se mide con la raiz del area
de la silueta (el baston crece igual que el resto, y el area promedia el
balanceo de brazos y tunica mucho mejor que el borde de arriba o de abajo), en
TODOS los fotogramas del video en bruto (01_frames, mascara de croma sencilla:
la sombra queda fuera porque sigue siendo verde). Se ajusta la recta 1/raiz(t)
y cada fotograma se escala por OBJ/raiz(t). El suelo (fila del pie mas bajo) se
ajusta como recta contra raiz(t): con camara fija, suelo - horizonte es
proporcional al tamano. Y el eje x, recta en t.

Cada fotograma se pega en la casilla de Magnus (584x720) con ese punto de suelo
en la fila 677 (donde apoya el reposo) y el eje del tronco en la x 292.

    python normalizar.py <job> <ultimo fotograma util> <primer fotograma de _sin_normalizar> <OBJ> [primero del ajuste]

Lee _sin_normalizar/ (RGBA a tamano de video, sin fondo, p_###.png en orden) y
escribe 04_limpios/c_###.png. Deja la recta en ajuste.txt.
OBJ: raiz del area que tendra en la casilla (calibrada para que capucha-pies
mida 628, como el reposo).
"""
import glob, os, sys
import numpy as np
from PIL import Image

ANIM = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOB = sys.argv[1]; ULTIMO = int(sys.argv[2]); PRIMERO = int(sys.argv[3]); OBJ = float(sys.argv[4])
DESDE = int(sys.argv[5]) if len(sys.argv) > 5 else 1   # ajuste solo desde aqui (andar_frente_sin: crece a escalones)
D = os.path.join(ANIM, JOB)
ORIG = os.path.join(D, '_sin_normalizar'); SAL = os.path.join(D, '04_limpios')
CAS = (584, 720); SUELO = 677; EJE = 292

# --- ajuste sobre el video entero
raiz, pie, cx = [], [], []
for i in range(DESDE, ULTIMO + 1):
    a = np.asarray(Image.open(os.path.join(D, '01_frames', 'f_%04d.png' % i)).convert('RGB')).astype(np.int16)
    m = (a[..., 1] - np.maximum(a[..., 0], a[..., 2])) < 45
    raiz.append(np.sqrt(m.sum())); pie.append(np.nonzero(m.any(1))[0].max()); cx.append(np.nonzero(m)[1].mean())
raiz, pie, cx = map(np.array, (raiz, pie, cx))
t = np.arange(DESDE, ULTIMO + 1, dtype=float)
p = np.polyfit(t, 1 / raiz, 1); raiz_f = lambda x: 1 / np.polyval(p, x)
q = np.polyfit(raiz_f(t), pie, 1); pie_f = lambda x: np.polyval(q, raiz_f(x))
r = np.polyfit(t, cx, 1); cx_f = lambda x: np.polyval(r, x)

# --- los fotogramas del tramo
fs = sorted(glob.glob(os.path.join(ORIG, '*.png')))
ims = [np.asarray(Image.open(f).convert('RGBA')) for f in fs]
tv = np.arange(PRIMERO, PRIMERO + len(ims), dtype=float)
# eje del tronco: el centro de masas lo desvia el baston. Desvio medio del eje
# (mediana de x en la banda 35-60 % del alto) respecto al centro de masas, en
# unidades de raiz, como correccion fija.
desv = []
for a, x in zip(ims, tv):
    m = a[..., 3] > 127
    ys = np.nonzero(m.any(1))[0]; y0, y1 = ys.min(), ys.max()
    banda = np.nonzero(m[int(y0 + 0.35 * (y1 - y0)):int(y0 + 0.6 * (y1 - y0))])[1]
    desv.append((np.median(banda) - np.nonzero(m)[1].mean()) / raiz_f(x))
desv = float(np.median(desv))

os.makedirs(SAL, exist_ok=True)
for f in glob.glob(os.path.join(SAL, '*.png')):
    os.remove(f)
if os.path.exists(os.path.join(SAL, '.sin_pincho')):   # ver baston/frontal.py
    os.remove(os.path.join(SAL, '.sin_pincho'))
for k, (a, x) in enumerate(zip(ims, tv)):
    s = OBJ / raiz_f(x)
    # premultiplicado: si no, el color de los pixeles transparentes (basura, a
    # veces rojo puro) se mezcla en los bordes al escalar y deja ribete
    im = Image.fromarray(a).convert('RGBa').resize((round(a.shape[1] * s), round(a.shape[0] * s)), Image.LANCZOS).convert('RGBA')
    ex = (cx_f(x) + desv * raiz_f(x)) * s
    lienzo = Image.new('RGBA', CAS, (0, 0, 0, 0))
    lienzo.paste(im, (round(EJE - ex), round(SUELO - pie_f(x) * s)))   # sin mascara: con ella el alfa sale al cuadrado
    lienzo.save(os.path.join(SAL, 'c_%03d.png' % (k + 1)))

res = raiz / raiz_f(t) - 1
with open(os.path.join(D, 'ajuste.txt'), 'w', encoding='utf-8') as o:
    o.write('video 1-%d, tramo %d-%d, OBJ %.1f\n' % (ULTIMO, PRIMERO, PRIMERO + len(ims) - 1, OBJ))
    o.write('1/raiz = %.6g + %.6g*t   (paso por fotograma de 1/escala = %.6g)\n' % (p[1], p[0], p[0] * OBJ))
    o.write('raiz ajustada %.1f -> %.1f; residuo desv %.2f %%, max %.2f %%\n' % (raiz_f(DESDE), raiz_f(ULTIMO), 100 * res.std(), 100 * abs(res).max()))
    o.write('suelo = %.2f + %.4f*raiz (horizonte en la fila %.0f del video); en la casilla K = %.4f*OBJ = %.1f px por unidad de escala\n' % (q[1], q[0], q[1], q[0], q[0] * OBJ))
    medio = raiz_f(PRIMERO + len(ims) / 2)
    o.write('en el juego (escala 1 = el tamano del video a mitad del tramo, raiz %.1f): 1/escala cambia %.6g por fotograma; '
            'suelo baja %.1f px de pantalla por unidad de escala (hoja a 1/2)\n' % (medio, p[0] * medio, q[0] * OBJ / 2))
    o.write('residuo del pie: %.1f px de video\n' % (pie - pie_f(t)).std())
    o.write('eje x = %.2f + %.4f*t; desvio eje-centro %.4f raices\n' % (r[1], r[0], desv))
print(open(os.path.join(D, 'ajuste.txt'), encoding='utf-8').read())
