"""Las dos animaciones de frente: sacar_baston_frente y guardar_baston_frente.

  sacar   reposo_frente_sb (fotograma base) -> 3 de puente -> video 20..146 -> 4 de
          puente -> reposo_frente_cb (base)
  guardar reposo_frente_cb (base) -> 3 de puente -> video 9..135 -> 4 de puente ->
          reposo_frente_sb (base)
Tramos: el video empieza a moverse en el 21 (sacar) y en el 9 (guardar: antes
esta quieto); acaba de asentarse en el 146 (sacar: tras plantar el baston se
balancea y vuelve, al 96 % de la silueta del reposo con baston) y en el 135
(guardar, al 97 % del reposo sin baston). Los puentes, por flujo optico como en
la secuencia (secuencia.py, mezcla): sin fundidos ni doble imagen.

La bola (la garra del video va vacia): garra.json (garra.py) con los huecos donde
la garra pasa por detras de la capucha interpolados, suavizada, y en los
puentes de la bola del reposo a la del video. Filas [x, y, escala, giro]: px de
hoja desde el centro de la casilla (332x452), escala relativa a la de la escena
(sin baston la bola va a 1, con baston a escala_bola = 1,092) y giro del nodo
(a la espalda va girada como el baston, -0,34 rad; en la mano, 0): se pasa de uno
a otro mientras la garra se mueve.
La capucha, al color estandar (../igualar_capucha.py; ver capucha_estandar).
Escribe <job>/04_limpios/<anim>_NNN.png, <job>/animaciones.json y
assets/characters/magnus/baston_frente.json.
    python animar.py
"""
import glob, importlib.util, json, os
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
PROY = os.path.abspath(os.path.join(ANIM, '..', '..', '..'))
spec = importlib.util.spec_from_file_location('puente', os.path.join(ANIM, 'magnus_puentes_frontal', 'puente.py'))
P = importlib.util.module_from_spec(spec); spec.loader.exec_module(P)
spec = importlib.util.spec_from_file_location('garra', os.path.join(AQUI, 'garra.py'))
G = importlib.util.module_from_spec(spec); spec.loader.exec_module(G)
spec = importlib.util.spec_from_file_location('igualar_capucha', os.path.join(ANIM, 'igualar_capucha.py'))
IC = importlib.util.module_from_spec(spec); spec.loader.exec_module(IC)
ESTANDAR = IC.medir(IC.estandar())
MX, MY = 40, 104
CAS = (584 + 2 * MX, 800 + MY)
FPS = 24.0
ESCALA_CON = json.load(open(os.path.join(PROY, 'assets', 'characters', 'magnus', 'secuencia_frontal.json')))['escala_bola']
SB = json.load(open(os.path.join(PROY, 'assets', 'characters', 'magnus', 'secuencia_frontal_sin.json')))
GIRO_SIN = SB['baston_espalda']['reposo_frente_sb'][0][2]


def mezcla(A, B, t):
    """A llevado hacia B una fraccion t por flujo, mezclado con B traido desde A."""
    a, b = P.premul(A), P.premul(B)
    a8 = (a[..., :3] * 255).astype(np.uint8); b8 = (b[..., :3] * 255).astype(np.uint8)
    fab, fba = P.flujo(a8, b8), P.flujo(b8, a8)
    m = (1 - t) * P.deformar(a, fab, t) + t * P.deformar(b, fba, 1 - t)
    al = np.clip(m[..., 3:], 1e-4, 1)
    rgb = np.where(m[..., 3:] > 1e-4, m[..., :3] / al, 0)
    return Image.fromarray((np.dstack([rgb, m[..., 3]]) * 255).round().clip(0, 255).astype(np.uint8), 'RGBA')


def reposo(job, nombre):
    """El fotograma base del reposo en la casilla grande. El de sin baston, con el
    baston que le pone la escena por detras (baston_espalda_reposo.png, de
    capa_espalda.gd: de frente solo asoma la garra): el video lo lleva dibujado y
    sin el, en el puente la garra se desvanecia y volvia a aparecer al llegar al
    reposo."""
    c = Image.new('RGBA', CAS, (0, 0, 0, 0))
    if job.endswith('_sin'):
        c.alpha_composite(Image.open(os.path.join(AQUI, 'baston_espalda_reposo.png')).convert('RGBA'))
    c.alpha_composite(Image.open(os.path.join(ANIM, job, '04_limpios', nombre)).convert('RGBA'), (MX, MY))
    return c


def video(job, k):
    return Image.open(os.path.join(ANIM, job, '_todos', 'c_%03d.png' % k)).convert('RGBA')


def capucha_estandar(job, a, b):
    """Los fotogramas a..b del video con la capucha al color estandar (igualar_capucha.py,
    como las secuencias: los reposos de las puntas ya lo llevan). Veo la va
    cambiando un poco por el camino (al guardar, de gris a algo azulada): se mide
    en cada fotograma y se suaviza en el tiempo (sin parpadeo)."""
    ims = {k: video(job, k) for k in range(a, b + 1)}
    med = np.array([np.concatenate(IC.medir([ims[k]])) for k in range(a, b + 1)])
    from scipy.ndimage import gaussian_filter1d
    med = gaussian_filter1d(med, 4, axis=0, mode='nearest')
    return {k: IC.aplicar(ims[k], (med[i, :3], med[i, 3:]), ESTANDAR) for i, k in enumerate(range(a, b + 1))}


def suave(v, veces=2):
    v = np.array(v, float)
    for _ in range(veces):
        v[1:-1] = (v[:-2] + 2 * v[1:-1] + v[2:]) / 4
    return v


def bola_video(job, a, b):
    """Posicion de la bola en los fotogramas a..b del video (px de master de la casilla)."""
    g = {int(k): v for k, v in json.load(open(os.path.join(ANIM, job, 'garra.json'))).items()}
    ks = list(range(a, b + 1))
    con = [k for k in ks if k in g]
    xs = np.interp(ks, con, [g[k][0] for k in con]); ys = np.interp(ks, con, [g[k][1] for k in con])
    return np.stack([suave(xs), suave(ys)], 1)


def giro_mientras_se_mueve(pos, desde, hasta):
    """De desde a hasta segun lo recorrido por la garra (no por el tiempo)."""
    d = np.r_[0, np.cumsum(np.hypot(*np.diff(pos, axis=0).T))]
    t = d / max(d[-1], 1e-6); t = t * t * (3 - 2 * t)
    return desde + (hasta - desde) * t


b_sin, b_con = G.bolas_de_referencia()
ANIMS = {
    # nombre: job, tramo del video, (reposo de entrada), (reposo de salida), de, a
    'sacar_baston_frente': ('magnus_sacar_baston_frente', (20, 146),
                            ('magnus_secuencia_frontal_sin', 'reposo_frente_sb_000.png', b_sin, 1.0, GIRO_SIN),
                            ('magnus_secuencia_frontal', 'reposo_frente_cb_000.png', b_con, ESCALA_CON, 0.0),
                            'reposo_frente_sb', 'reposo_frente_cb'),
    'guardar_baston_frente': ('magnus_guardar_baston_frente', (9, 135),
                              ('magnus_secuencia_frontal', 'reposo_frente_cb_000.png', b_con, ESCALA_CON, 0.0),
                              ('magnus_secuencia_frontal_sin', 'reposo_frente_sb_000.png', b_sin, 1.0, GIRO_SIN),
                              'reposo_frente_cb', 'reposo_frente_sb'),
}
N_ENTRA, N_SALE = 3, 4
escena = {'fps': FPS, 'casilla': [CAS[0] // 2, CAS[1] // 2]}
for nombre, (job, (a, b), ent, sal, de, hacia) in ANIMS.items():
    R0, R1 = reposo(ent[0], ent[1]), reposo(sal[0], sal[1])
    V = capucha_estandar(job, a, b)
    V0, V1 = V[a], V[b]
    frames = [mezcla(R0, V0, k / (N_ENTRA + 1)) for k in range(1, N_ENTRA + 1)]
    frames += [V[k] for k in range(a, b + 1)]
    frames += [mezcla(V1, R1, k / (N_SALE + 1)) for k in range(1, N_SALE + 1)]
    pv = bola_video(job, a, b)
    p_ent = [np.array(ent[2]) + (pv[0] - np.array(ent[2])) * k / (N_ENTRA + 1) for k in range(1, N_ENTRA + 1)]
    p_sal = [pv[-1] + (np.array(sal[2]) - pv[-1]) * k / (N_SALE + 1) for k in range(1, N_SALE + 1)]
    pos = np.array(p_ent + list(pv) + p_sal)
    esc = giro_mientras_se_mueve(pos, ent[3], sal[3]); gir = giro_mientras_se_mueve(pos, ent[4], sal[4])
    filas = [[round(float(x) / 2 - CAS[0] / 4, 2), round(float(y) / 2 - CAS[1] / 4, 2), round(float(e), 4), round(float(g), 4)]
             for (x, y), e, g in zip(pos, esc, gir)]
    carpeta = os.path.join(ANIM, job, '04_limpios'); os.makedirs(carpeta, exist_ok=True)
    for f in glob.glob(os.path.join(carpeta, '*.png')):
        os.remove(f)
    for k, im in enumerate(frames):
        im.save(os.path.join(carpeta, '%s_%03d.png' % (nombre, k)))
    json.dump([[nombre, job, len(frames), FPS, False, list(range(len(frames)))]], open(os.path.join(ANIM, job, 'animaciones.json'), 'w'))
    escena[nombre] = {'de': de, 'a': hacia, 'orbe': filas}
    print(nombre, len(frames), 'fotogramas (%d de puente, video %d-%d, %d de puente)' % (N_ENTRA, a, b, N_SALE))
json.dump(escena, open(os.path.join(PROY, 'assets', 'characters', 'magnus', 'baston_frente.json'), 'w'), separators=(',', ':'))
