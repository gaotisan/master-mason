"""Las dos animaciones de espaldas (2026-10-11): sacar_baston_espalda y guardar_baston_espalda.

Como las de frente (../magnus_sacar_baston_frente/animar.py: puentes por flujo sin
emborronar, la bola, el giro):
  sacar   espalda nueva sin baston (base, con el baston en la correa como lo pone la
          escena) -> puente -> video 19..100 (este job,
          Pilgrim_drawing_staff_on_green_20261011153220) -> puente -> reposo_espalda_cb
          (base, con la correa vacia como la pone la escena)
  guardar reposo_espalda_cb (con la correa vacia) -> puente -> video 19..100
          (magnus_guardar_baston_espalda_b, Pilgrim_slinging_staff_on_back, con su
          arreglar.py: el baston por encima de la espalda) -> puente -> espalda nueva
          con el baston en la correa
Tramos: los dos empiezan a moverse hacia el 23-29 (en el 19, al 96 % de la silueta
del reposo de salida) y en el 100 estan al 95 % (sacar: luego solo se balancea) y al
98 % (guardar) del de llegada. Los dos videos calcan las referencias y no cambian de
tunica: la espalda del chevron en los dos modos (magnus_espalda_sin_baston).
La capucha, a la de los reposos de espaldas (no al estandar de perfil: asi no salta
en los puentes), medida en cada fotograma y suavizada en el tiempo.
La bola: la garra seguida (garra.py --espalda; solo lo que casa bien), suavizada; en
los puentes, de la del reposo a la del video. Filas [x, y, escala, giro] como las de
frente: px de hoja desde el centro de la casilla (332x452); escala 1 sin baston y
escala_bola con el; giro, el del baston en la correa (0,34 rad) sin baston y 0 en la
mano, segun lo recorrido por la garra.
Escribe <job>/04_limpios/<anim>_NNN.png, <job>/animaciones.json y
assets/characters/magnus/acciones_espalda.json.
    python animar.py
"""
import glob, importlib.util, json, os
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter1d

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
PROY = os.path.abspath(os.path.join(ANIM, '..', '..', '..'))
spec = importlib.util.spec_from_file_location('animar_frente', os.path.join(ANIM, 'magnus_sacar_baston_frente', 'animar.py'))
A = importlib.util.module_from_spec(spec); spec.loader.exec_module(A)
G, IC = A.G, A.IC
MX, MY, CAS, FPS = A.MX, A.MY, A.CAS, A.FPS
ESCALA_CON = A.ESCALA_CON
CB = json.load(open(os.path.join(PROY, 'assets', 'characters', 'magnus', 'secuencia_frontal.json')))
GIRO_CORREA = CB['funda_espalda']['reposo_espalda_cb'][0][2]     # el baston en la correa
NUEVA = os.path.join(ANIM, 'magnus_espalda_sin_baston')
CAPAS = os.path.join(ANIM, 'magnus_sacar_baston_frente')
CASA_GARRA = 0.90           # por debajo, la garra no se fia: se interpola


def reposo(modo):
    """El fotograma base del reposo de espaldas en la casilla grande, con lo que le
    pone la escena encima: sin baston, el baston en la correa (de espaldas va por
    delante del cuerpo); con baston, la correa vacia."""
    c = Image.new('RGBA', CAS, (0, 0, 0, 0))
    if modo == 'sin':
        c.alpha_composite(Image.open(os.path.join(NUEVA, 'espalda_sin_baston.png')).convert('RGBA'), (MX, MY))
        c.alpha_composite(Image.open(os.path.join(NUEVA, 'baston_en_correa.png')).convert('RGBA'))
    else:
        c.alpha_composite(Image.open(os.path.join(ANIM, 'magnus_secuencia_frontal', '04_limpios', 'reposo_espalda_cb_000.png')).convert('RGBA'), (MX, MY))
        c.alpha_composite(Image.open(os.path.join(CAPAS, 'funda_vacia_reposo_espalda.png')).convert('RGBA'))
    return c


OBJETIVO = IC.medir([reposo('con')])      # la capucha de los reposos de espaldas


def capucha(job, a, b):
    ims = {k: A.video(job, k) for k in range(a, b + 1)}
    med = np.array([np.concatenate(IC.medir([ims[k]])) for k in range(a, b + 1)])
    med = gaussian_filter1d(med, 4, axis=0, mode='nearest')
    return {k: IC.aplicar(ims[k], (med[i, :3], med[i, 3:]), OBJETIVO) for i, k in enumerate(range(a, b + 1))}


def bola_video(job, a, b):
    g = {int(k): v for k, v in json.load(open(os.path.join(ANIM, job, 'garra.json'))).items()}
    ks = list(range(a, b + 1))
    bien = [k for k in ks if k in g and g[k][3] >= CASA_GARRA]
    xs = np.interp(ks, bien, [g[k][0] for k in bien]); ys = np.interp(ks, bien, [g[k][1] for k in bien])
    return np.stack([A.suave(xs), A.suave(ys)], 1), len(ks) - len(bien)


b_sin, b_con = G.bolas_de_referencia_espalda()
ANIMS = {
    # nombre: job, tramo, (modo de entrada, bola, escala, giro), (de salida), de, a, puentes
    'sacar_baston_espalda': ('magnus_sacar_baston_espalda_v2', (19, 100),
                             ('sin', b_sin, 1.0, GIRO_CORREA), ('con', b_con, ESCALA_CON, 0.0),
                             'reposo_espalda_sb', 'reposo_espalda_cb', (3, 5)),
    'guardar_baston_espalda': ('magnus_guardar_baston_espalda_b', (19, 100),
                               ('con', b_con, ESCALA_CON, 0.0), ('sin', b_sin, 1.0, GIRO_CORREA),
                               'reposo_espalda_cb', 'reposo_espalda_sb', (3, 4)),
}
if __name__ == '__main__':
    escena = {'fps': FPS, 'casilla': [CAS[0] // 2, CAS[1] // 2]}
    for nombre, (job, (a, b), ent, sal, de, hacia, (n_ent, n_sal)) in ANIMS.items():
        R0, R1 = reposo(ent[0]), reposo(sal[0])
        V = capucha(job, a, b)
        frames = [A.mezcla(R0, V[a], k / (n_ent + 1)) for k in range(1, n_ent + 1)]
        frames += [V[k] for k in range(a, b + 1)]
        frames += [A.mezcla(V[b], R1, k / (n_sal + 1)) for k in range(1, n_sal + 1)]
        pv, sin_garra = bola_video(job, a, b)
        p_ent = [np.array(ent[1]) + (pv[0] - np.array(ent[1])) * k / (n_ent + 1) for k in range(1, n_ent + 1)]
        p_sal = [pv[-1] + (np.array(sal[1]) - pv[-1]) * k / (n_sal + 1) for k in range(1, n_sal + 1)]
        pos = np.array(p_ent + list(pv) + p_sal)
        esc = A.giro_mientras_se_mueve(pos, ent[2], sal[2]); gir = A.giro_mientras_se_mueve(pos, ent[3], sal[3])
        filas = [[round(float(x) / 2 - CAS[0] / 4, 2), round(float(y) / 2 - CAS[1] / 4, 2), round(float(e), 4), round(float(g), 4)]
                 for (x, y), e, g in zip(pos, esc, gir)]
        carpeta = os.path.join(ANIM, job, '04_limpios'); os.makedirs(carpeta, exist_ok=True)
        for f in glob.glob(os.path.join(carpeta, '*.png')):
            os.remove(f)
        for k, im in enumerate(frames):
            im.save(os.path.join(carpeta, '%s_%03d.png' % (nombre, k)))
        json.dump([[nombre, job, len(frames), FPS, False, list(range(len(frames)))]], open(os.path.join(ANIM, job, 'animaciones.json'), 'w'))
        escena[nombre] = {'de': de, 'a': hacia, 'orbe': filas}
        print(nombre, len(frames), 'fotogramas (%d de puente, video %d-%d, %d de puente); garra interpolada en %d' % (n_ent, a, b, n_sal, sin_garra))
    json.dump(escena, open(os.path.join(PROY, 'assets', 'characters', 'magnus', 'acciones_espalda.json'), 'w'), separators=(',', ':'))
