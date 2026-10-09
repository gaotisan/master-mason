"""Bola (y garra) del baston en el andar de frente y de espaldas.

Como mano.py para el de perfil: la madera ya viene en el dibujo y la bola se
pone por codigo, por detras del sprite. Sale assets/characters/baston/
frontal.json: por animacion, la bola en cada fotograma (px de hoja respecto al
centro de la casilla, como mano.json) y su escala.

ESPALDAS: la garra de cuernos del video, como la del perfil. La bola en el
hueco, a 0,43 anchos de garra por debajo de las puntas (lo medido en
mano_andar) y centrada.

FRENTE: el baston de ese video NO tiene garra, acaba en un pincho (las raices
se cierran). Se le pone la garra:
  - garra_frente.png: la garra del baston original de Gemini
    (_fuentes/baston_solo_gemini_v1.jpeg, de donde sale el diseno del juego),
    abierta de frente y en alta resolucion (208 px de ancho). Escala 0,38 (su
    garra:tallo es 3:1 como la de nuestros sprites: 79 de garra en el de
    espaldas, ~26 de tallo en el de frente), guardada a 2x master (0,76) para
    que aguante el primer plano, y suavizada (BLANDURA) hasta la blandura del
    sprite, que viene de video: nitida se veia pegada.
    Color: las puntas igualadas (ganancia por canal, a la misma media) a la garra del de espaldas, el tallo al baston del de frente,
    fundiendo entre medias. Abajo, el tallo se desvanece para empalmar.
  - En 04_limpios de magnus_andar_frente se borra el pincho: lo que hay del
    baston por encima de CORTE px bajo la punta (el nudo donde se ensancha). La
    copia con pincho queda en _con_pincho/ (de ahi se mide), y un archivo
    .sin_pincho en 04_limpios dice que ya esta hecho (normalizar.py lo quita).
  - La garra va en la escena como capa encima del sprite, en el punto del eje
    del baston a CORTE bajo la punta y con su inclinacion (recta por los centros
    del baston entre la punta y la mano), suavizado en el tiempo. La bola,
    detras, en su hueco.
Tras correrlo, si cambio el borrado: hoja.ps1 -Job magnus_andar_frente y
tools/anim/_spriteframes.py.
    python frontal.py
"""
import glob, json, os, shutil
import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import label

AQUI = os.path.dirname(os.path.realpath(__file__))
PROY = os.path.abspath(os.path.join(AQUI, '..', '..', '..', '..'))
ANIM = os.path.join(PROY, 'raw', 'master_mason', 'anim')
BASTON = os.path.join(PROY, 'assets', 'characters', 'baston')
SALIDA = os.path.join(BASTON, 'frontal.json')
EJE = 292
GARRA_PERFIL = 36.0     # ancho de la garra en mano_andar (px de hoja)
BAJO_PUNTAS = 0.43      # bola: anchos de garra por debajo de las puntas

# --- frente
GEMINI = os.path.join(ANIM, '_fuentes', 'baston_solo_gemini_v1.jpeg')
ESC_GEMINI = 0.38       # gemini -> master
TEX = 2.0               # la textura va a 2x master
CORTE = 100             # master px bajo la punta del pincho: ahi se empalma
TALLO_G = 300           # fila (desde las puntas, en gemini) del tallo bajo el nudo: pivote
BAJO_G = 80             # tallo por debajo del pivote (gemini), desvaneciendose
BLANDURA = 1.6           # px de textura (2x master)
FRANJA_X = 205          # el baston de frente va a la izquierda de esta columna (master)


def suavizar(v, veces=1):
    for _ in range(veces):
        v = (np.roll(v, 1, 0) + 2 * v + np.roll(v, -1, 0)) / 4
    return v


def punta(a, lado):
    op = a[..., 3] > 100
    banda = op.copy()
    if lado < 0:
        banda[:, EJE - 70:] = False
    else:
        banda[:, :EJE + 70] = False
    banda[360:] = False                        # por encima de los hombros
    top = int(np.nonzero(banda.any(1))[0].min())
    xs = np.nonzero(banda[top:top + 30].any(0))[0]
    return top, float(xs.min()), float(xs.max())


def stats(px):
    return px.mean(0)


# ---------------------------------------------------------------- espaldas
datos = {}
fs = sorted(glob.glob(os.path.join(ANIM, 'magnus_andar_espalda', '04_limpios', 'c_*.png')))
tops, xs, anchos = [], [], []
for f in fs:
    top, x0, x1 = punta(np.asarray(Image.open(f).convert('RGBA')), +1)
    tops.append(top / 2); xs.append((x0 + x1) / 4); anchos.append((x1 - x0) / 2)
tops, xs, anchos = (suavizar(np.array(v)) for v in (tops, xs, anchos))
ancho_esp = float(np.median(anchos))
datos['andar_espalda'] = {
    'orbe': [[round(float(x) - 146, 2), round(float(t + BAJO_PUNTAS * w) - 180, 2)] for x, t, w in zip(xs, tops, anchos)],
    'escala_bola': round(ancho_esp / GARRA_PERFIL, 3)}
print('andar_espalda', len(fs), 'fotogramas; garra %.1f px de hoja (perfil %.0f)' % (ancho_esp, GARRA_PERFIL))

# color de la garra de espaldas (para las puntas de la de frente)
pix_garra = []
for f in fs:
    a = np.asarray(Image.open(f).convert('RGBA')).astype(float)
    top, x0, x1 = punta(a.astype(np.uint8), +1)
    r = a[top:top + 70, int(x0):int(x1) + 1]
    pix_garra.append(r[r[..., 3] > 250][:, :3])
obj_puntas = stats(np.concatenate(pix_garra))

# ---------------------------------------------------------------- frente
JF = os.path.join(ANIM, 'magnus_andar_frente')
LIMPIOS, CON = os.path.join(JF, '04_limpios'), os.path.join(JF, '_con_pincho')
MARCA = os.path.join(LIMPIOS, '.sin_pincho')
if not os.path.exists(MARCA):
    if os.path.isdir(CON):
        shutil.rmtree(CON)
    shutil.copytree(LIMPIOS, CON)
ff = sorted(glob.glob(os.path.join(CON, 'c_*.png')))
ims = [np.asarray(Image.open(f).convert('RGBA')) for f in ff]

# eje del baston en cada fotograma: punta, y recta x(y) por los centros de fila
# entre la punta+45 (debajo del pincho fino) y la punta+135 (encima de la mano)
P, ang, puntas_y = [], [], []
pix_tallo = []
for a in ims:
    op = a[..., 3] > 100
    b = op.copy(); b[:, FRANJA_X:] = False
    tip = int(np.nonzero(b.any(1))[0].min())
    filas = np.arange(tip + 45, tip + 136)
    cx = np.array([np.nonzero(b[y])[0].mean() for y in filas])
    k, c0 = np.polyfit(filas, cx, 1)                # x = k*y + c0
    P.append((k * (tip + CORTE) + c0, tip + CORTE))
    ang.append(-np.arctan(k))                        # giro de Godot (horario +)
    puntas_y.append(tip)
    t = a[tip + 105:tip + 136, :FRANJA_X].astype(float)   # solo el baston (no la capucha)
    pix_tallo.append(t[t[..., 3] > 250][:, :3])
P = suavizar(np.array(P), 2); ang = suavizar(np.array(ang), 2)
obj_tallo = stats(np.concatenate(pix_tallo))

# garra de gemini
g = np.asarray(Image.open(GEMINI).convert('RGB')).astype(float)
fondo = np.median(g[:50, :50].reshape(-1, 3), 0)
d = g[..., 1] - np.maximum(g[..., 0], g[..., 2])
m = d < 40
m[:, :int(g.shape[1] * 0.62)] = False
lab, n = label(m)
st = lab == (np.bincount(lab.ravel())[1:].argmax() + 1)
gy0 = int(np.nonzero(st.any(1))[0].min())
y0, y1 = gy0 - 8, gy0 + TALLO_G + BAJO_G
cols = np.nonzero(st[gy0:y1].any(0))[0]
x0, x1 = cols.min() - 8, cols.max() + 9
rec = g[y0:y1, x0:x1]; drec = d[y0:y1, x0:x1]; strec = st[y0:y1, x0:x1]
fuera = fondo[1] - max(fondo[0], fondo[2]) - 15
alfa = np.clip((fuera - drec) / (fuera - 5), 0, 1) * strec
# borde: color del solido mas cercano (sin verde)
from scipy.ndimage import distance_transform_edt
solido = alfa >= 0.95
_, (iy, ix) = distance_transform_edt(~solido, return_indices=True)
col = rec.copy()
borde = (alfa > 0) & ~solido
col[borde] = col[iy[borde], ix[borde]]
col[..., 1] = np.minimum(col[..., 1], np.maximum(col[..., 0], col[..., 2]))
# color: puntas -> garra de espaldas, tallo -> baston de frente, fundido por filas
filas = np.arange(rec.shape[0]) - 8                 # desde las puntas
src_p = stats(col[:200][alfa[:200] > 0.95])
# el tallo, con el nudo dentro: medido solo con lo oscuro de abajo, las vetas
# claras del nudo salian casi blancas
src_t = stats(col[220 + 8:][alfa[220 + 8:] > 0.95])
# ganancia por canal (cociente de medias): igualar media y desviacion por canal
# disparaba el azul (en Gemini casi no varia: vetas lilas en el nudo) y restar
# la media llevaba las sombras a azul oscuro
cp = col * (obj_puntas / src_p)
ct = col * (obj_tallo / src_t)
w = np.clip((filas - 220) / (TALLO_G - 220), 0, 1)[:, None, None]
col = np.clip(cp * (1 - w) + ct * w, 0, 255)
# el tallo se desvanece por abajo para empalmar con el baston del dibujo
fade = np.clip((y1 - y0 - 1 - np.arange(rec.shape[0])) / (BAJO_G * 0.75), 0, 1)
alfa = alfa * fade[:, None]
col[alfa == 0] = 0
tex = Image.fromarray(np.dstack([col, alfa * 255]).round().astype(np.uint8), 'RGBA').convert('RGBa')
s = ESC_GEMINI * TEX
tex = tex.resize((round(tex.width * s), round(tex.height * s)), Image.LANCZOS)
# la de Gemini es un dibujo nitido y el sprite viene de video (ampliado): sin
# suavizar se ve pegada. Desenfoque de ~1 px de master (BLANDURA en px de textura)
tex = tex.filter(ImageFilter.GaussianBlur(BLANDURA)).convert('RGBA')
tex.save(os.path.join(BASTON, 'garra_frente.png'))
# pivote (en la textura): eje del tallo en la fila TALLO_G
fila_p = gy0 + TALLO_G
pivote = ((np.nonzero(st[fila_p])[0].mean() - x0) * s, (fila_p - y0) * s)
# bola en la textura: centro de las puntas, BAJO_PUNTAS anchos bajo ellas
ancho_g = max(np.ptp(np.nonzero(st[gy0 + r])[0]) for r in range(0, 220, 4))
cx_g = np.mean([np.nonzero(st[gy0 + r])[0].mean() for r in range(60, 160, 4)])
bola_t = ((cx_g - x0) * s, (BAJO_PUNTAS * ancho_g + 8) * s)
ancho_frente = ancho_g * ESC_GEMINI / 2                 # px de hoja
print('garra_frente.png %dx%d (2x master), pivote %.1f,%.1f, garra %.1f px de hoja' % (
    tex.width, tex.height, pivote[0], pivote[1], ancho_frente))

# en el juego: textura -> hoja es 1 / (2 * TEX)
k = 1 / (2 * TEX)
garra, orbe = [], []
for (px, py), an in zip(P, ang):
    hx, hy = px / 2 - 146, py / 2 - 180
    garra.append([round(hx, 2), round(hy, 2), round(float(an), 4)])
    v = np.array([bola_t[0] - pivote[0], bola_t[1] - pivote[1]]) * k
    c, s_ = np.cos(an), np.sin(an)
    orbe.append([round(hx + c * v[0] - s_ * v[1], 2), round(hy + s_ * v[0] + c * v[1], 2)])
datos['andar_frente'] = {'orbe': orbe, 'escala_bola': round(ancho_frente / GARRA_PERFIL, 3),
                         'garra': garra, 'garra_textura': 'res://assets/characters/baston/garra_frente.png',
                         'garra_pivote': [round(pivote[0], 2), round(pivote[1], 2)], 'garra_escala': k}
print('andar_frente', len(ims), 'fotogramas; inclinacion %.1f..%.1f grados' % (
    np.degrees(ang.min()), np.degrees(ang.max())))

# borrar el pincho en 04_limpios (desde la copia con pincho)
for f, a, tip in zip(ff, ims, puntas_y):
    o = a.copy()
    corte = tip + CORTE - 6          # un poco por encima del pivote: la garra tapa la union
    o[:corte, :FRANJA_X, 3] = 0
    o[:corte, :FRANJA_X, :3] = 0
    Image.fromarray(o).save(os.path.join(LIMPIOS, os.path.basename(f)))
open(MARCA, 'w').write('pincho borrado por baston/frontal.py; la copia con pincho esta en _con_pincho/\n')

# ---------------------------------------------------------------- vuelta
# El giro de frente a espaldas (magnus_vuelta_frontal, casilla propia 584x800)
# trae la garra en el dibujo (el video se hizo con la garra puesta en la
# referencia). Se sigue por color: lo saturado y calido (madera y oro; la
# capucha es gris) mas alto por encima de los hombros; la bola centrada en los
# 40 px de arriba y a 0,43 anchos de garra (la de frente, 79 px de master) bajo
# las puntas. De canto, a mitad del giro, queda centrada en ella.
fv = sorted(glob.glob(os.path.join(ANIM, 'magnus_vuelta_frontal', '04_limpios', 'c_*.png')))
ALTO_V = 800
tops, xs = [], []
for f in fv:
    a = np.asarray(Image.open(f).convert('RGBA')).astype(float)
    rgb = a[..., :3] / 255
    mx, mn = rgb.max(2), rgb.min(2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    m = (a[..., 3] > 128) & (sat > 0.35) & (rgb[..., 0] >= rgb[..., 1])
    m[330:] = False
    top = int(np.nonzero(m.any(1))[0].min())
    cols = np.nonzero(m[top:top + 40])[1]
    tops.append(top); xs.append((cols.min() + cols.max()) / 2)
tops, xs = suavizar(np.array(tops, float)), suavizar(np.array(xs, float))
for v in (tops, xs):          # no es un bucle: los extremos sin suavizar ciclico
    v[0], v[-1] = v[1], v[-2]
ancho_m = ancho_frente * 2
datos['vuelta_frontal'] = {
    'orbe': [[round(x / 2 - 146, 2), round((t + BAJO_PUNTAS * ancho_m) / 2 - ALTO_V / 4, 2)] for t, x in zip(tops, xs)],
    'escala_bola': round(ancho_frente / GARRA_PERFIL, 3)}
print('vuelta_frontal', len(fv), 'fotogramas')

# ---------------------------------------------------------------- a la espalda
# Sin baston en la mano, el baston va a la espalda bajo la tunica, como en el
# perfil (baston_seguimiento.json): en el giro de pie, de espaldas puras, el
# pivote (el hombro, donde lo corta la funda) cae centrado bajo la capucha y 97
# px de master por debajo de su punta (medido en giro c_017-c_019). Aqui se pone
# igual: x = centro de la capucha (60 px de arriba del dibujo), y = su punta +
# 97. De espaldas va delante con el parche de tela (la funda); de frente,
# detras (lo tapa la cabeza y asoman la garra y la luz). En la vuelta, delante
# cuando ya no se ve la barba.
# En x, el baston va pegado a la espalda, no al centro de la capucha: en el giro
# de perfil el pivote, medido sobre el tronco (filas 130-170 bajo la punta de
# la capucha; p = (pivote - centro)/semiancho), sigue a lo que la cabeza se
# adelanta (g = (centro de la capucha - centro del tronco)/semiancho) con
# p = -2,28 g - 0,05 (ajuste en los 47 fotogramas): de frente y de espaldas
# g ~ 0 y va al centro; de perfil se va al borde de la espalda y asoma detras
# de la cabeza, como en el perfil.
# Y ladeado hacia su hombro derecho (lo pidio el usuario: recto por la columna,
# de frente la bola quedaba detras de la cabeza): pivote en el omoplato
# (LADO_X px de hoja hacia ese lado) e inclinado LADO_GIRO, para que la bola
# (radio ~11 px de hoja, 24 sobre el pivote) asome un poco por el lado de la
# capucha (semiancho ~21 a esa altura). Ese hombro, de frente, a la izquierda
# de la pantalla (donde lleva el baston en la mano) y de espaldas a la derecha;
# de perfil el ladeo va en profundidad y no se ve: en la vuelta se escala con
# 1 - |p| (p ~ +-1 de perfil).
K_ESPALDA = -2.28
# FUNDA DE CUERO (2026-10-08, reemplaza a lo de arriba de ladearlo y cortarlo en
# el hombro bajo la tunica): el baston va entero por FUERA de la tunica, en
# diagonal, metido en una funda de cuero en el omoplato (funda_cuero.py), como
# en el concepto de Gemini (_fuentes/baston_concepto_funda.jpeg). Medido en el
# concepto y llevado a capucha-pies 628: la bola a BOLA_LADO px de master hacia
# su hombro derecho del centro de la capucha y BOLA_BAJO por debajo de su punta,
# el baston inclinado GIRO (la garra hacia ese hombro; el pie hacia la cadera
# contraria, dentro de la silueta). De frente, el mismo hombro a la izquierda
# de la pantalla y el baston detras del cuerpo.
BOLA_LADO = 60.0
BOLA_BAJO = 39.0
GIRO = 0.34
ORBE_LOCAL = np.array([-0.6, -24.0]) * 2     # la bola respecto al pivote (master)
baston_espalda = {}
def _de(job, desde=0, hasta=None):
    return sorted(glob.glob(os.path.join(ANIM, job, '04_limpios', 'c_*.png')))[desde:hasta]


for anim, fs, alto in (('andar_frente_sin', _de('magnus_andar_frente_sin'), 720),
                       ('andar_espalda_sin', _de('magnus_andar_espalda_sin'), 720),
                       ('vuelta_frontal_sin', _de('magnus_vuelta_frontal_sin'), 720),
                       ('parada_frente_sin', _de('magnus_reposo_frente_sin', 0, 100), 720),
                       ('reposo_frente_sin', _de('magnus_reposo_frente_sin', 100), 720),
                       ('reposo_espalda_sin', _de('magnus_reposo_espalda_sin'), 720)):
    filas = []
    for f in fs:
        a = np.asarray(Image.open(f).convert('RGBA')).astype(float)
        op = a[..., 3] > 128
        top = int(np.nonzero(op.any(1))[0].min())
        hc = float(np.nonzero(op[top:top + 60])[1].mean())
        band = np.nonzero(op[top + 130:top + 170])[1]
        l, r = np.percentile(band, 3), np.percentile(band, 97)
        c, h = (l + r) / 2, (r - l) / 2
        pp = float(np.clip(K_ESPALDA * (hc - c) / h, -1.05, 1.05))
        barba = (op & (a[..., :3].min(2) > 175))[top:top + 300].sum()
        # en los andares el tronco baila con los brazos: ahi, centrado en la capucha
        filas.append([c + pp * h if anim.startswith('vuelta') else hc, top, barba, pp])
    v = np.array(filas, float)
    delante = [1 if ('espalda' in anim or (anim.startswith('vuelta') and b < 150)) else 0 for b in v[:, 2]]
    if anim.startswith('vuelta'):
        lado = np.array([(1 - min(abs(q), 1.0)) * (1 if dl else -1) for q, dl in zip(v[:, 3], delante)])
    else:
        lado = np.full(len(v), 1.0 if 'espalda' in anim else -1.0)
    bx = v[:, 0] + BOLA_LADO * lado; by = v[:, 1] + BOLA_BAJO; giro = GIRO * lado
    x, y, gg = suavizar(bx), suavizar(by), suavizar(giro)
    if anim.startswith('vuelta') or anim.startswith('parada'):
        for w, src in ((x, bx), (y, by), (gg, giro)):
            w[0], w[-1] = src[0], src[-1]
    filas_json = []
    for xx, yy, g_, dl in zip(x, y, gg, delante):
        c_, s_ = np.cos(g_), np.sin(g_)
        ox, oy = c_ * ORBE_LOCAL[0] - s_ * ORBE_LOCAL[1], s_ * ORBE_LOCAL[0] + c_ * ORBE_LOCAL[1]
        px, py = xx - ox, yy - oy                    # pivote = bola - R(giro) orbe
        # [x, y, giro, delante, parche]: parche 0, ya no se corta en el hombro
        filas_json.append([round(px / 2 - 146, 2), round(py / 2 - alto / 4, 2), round(float(g_), 4), dl, 0.0])
    baston_espalda[anim] = filas_json
    print(anim, 'baston a la espalda:', len(filas), 'fotogramas, delante en', sum(delante))
datos['baston_espalda'] = baston_espalda

# La parada de frente se acerca (da un par de pasitos): cuanto crece cada uno de
# sus fotogramas respecto al ultimo (video 3-102; magnus_reposo_frente_sin/
# medidas.json, de su montar.py). La escena escala al personaje con eso.
med = json.load(open(os.path.join(ANIM, 'magnus_reposo_frente_sin', 'medidas.json')))
datos['escala_relativa'] = {'parada_frente_sin': [round(v / med['magnus_reposo_frente_sin']['escala_relativa'][101], 4)
                                                  for v in med['magnus_reposo_frente_sin']['escala_relativa'][2:102]]}

# Los puentes entre andares y vuelta (magnus_puentes_frontal/puente.py): la bola
# interpolada entre la de sus extremos (bola.json).
_pb = os.path.join(ANIM, 'magnus_puentes_frontal', 'bola.json')
if os.path.exists(_pb):
    for nombre, filas in json.load(open(_pb)).items():
        datos[nombre] = {'orbe': [[f[0], f[1]] for f in filas], 'escala_bola': filas[0][2]}

_ps = os.path.join(ANIM, 'magnus_puentes_frontal_sin', 'baston.json')
if os.path.exists(_ps):
    datos['baston_espalda'].update(json.load(open(_ps)))

json.dump(datos, open(SALIDA, 'w'), separators=(',', ':'))
print('->', SALIDA)
