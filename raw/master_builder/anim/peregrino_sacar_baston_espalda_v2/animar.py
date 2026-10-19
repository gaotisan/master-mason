"""Las dos animaciones de espaldas (2026-10-11): sacar_baston_espalda y guardar_baston_espalda.

Como las de frente (../peregrino_sacar_baston_frente/animar.py: puentes por flujo sin
emborronar, la bola, el giro):
  sacar   espalda nueva sin baston (base, con el baston en la correa como lo pone la
          escena) -> puente -> video 19..100 (este job,
          Pilgrim_drawing_staff_on_green_20261011153220) -> puente -> reposo_espalda_cb
          (base, con la correa vacia como la pone la escena)
  guardar reposo_espalda_cb (con la correa vacia) -> puente -> video 19..106
          (peregrino_guardar_baston_espalda_a, Character_slinging_staff_animation, con
          su arreglar.py: nuestro baston, siempre con la garra arriba, lo sube, gira
          por detras de la espalda y cae a la correa; hasta el 2026-10-12 era el video
          B, peregrino_guardar_baston_espalda_b, que atravesaba el cuerpo) -> puente ->
          espalda nueva con el baston en la correa
Tramos: los dos empiezan a moverse hacia el 23-29 (en el 19, al 96 % de la silueta
del reposo de salida) y en el 100 estan al 95 % (sacar: luego solo se balancea) y al
98 % (guardar) del de llegada. Los dos videos calcan las referencias y no cambian de
tunica: la espalda del chevron en los dos modos (peregrino_espalda_sin_baston).
La capucha, a la de los reposos de espaldas (no al estandar de perfil: asi no salta
en los puentes), medida en cada fotograma y suavizada en el tiempo.
La bola: la garra seguida (garra.py --espalda; solo lo que casa bien), suavizada; en
los puentes, de la del reposo a la del video. Filas [x, y, escala, giro] como las de
frente: px de hoja desde el centro de la casilla (332x452); escala 1 sin baston y
escala_bola con el; giro, el del baston en la correa (0,34 rad) sin baston y 0 en la
mano, segun lo recorrido por la garra.
Escribe <job>/04_limpios/<anim>_NNN.png, <job>/animaciones.json y
assets/characters/peregrino/acciones_espalda.json.
    python animar.py
    (2026-10-18/19) Sin la garra doble a la espalda ni restos de la de Veo (limpiar_doble,
    sin_motas). Hasta el 2026-10-19 era la opcion --gu (<anim>_gu en <job>_gu); ahora es
    lo unico.
"""
import glob, importlib.util, json, os, sys
import cv2
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter1d

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
PROY = os.path.abspath(os.path.join(ANIM, '..', '..', '..'))
spec = importlib.util.spec_from_file_location('animar_frente', os.path.join(ANIM, 'peregrino_sacar_baston_frente', 'animar.py'))
A = importlib.util.module_from_spec(spec); spec.loader.exec_module(A)
G, IC = A.G, A.IC
MX, MY, CAS, FPS = A.MX, A.MY, A.CAS, A.FPS
ESCALA_CON = A.ESCALA_CON
CB = json.load(open(os.path.join(PROY, 'assets', 'characters', 'peregrino', 'secuencia_frontal.json')))
GIRO_CORREA = CB['funda_espalda']['reposo_espalda_cb'][0][2]     # el baston en la correa
NUEVA = os.path.join(ANIM, 'peregrino_espalda_sin_baston')
CAPAS = os.path.join(ANIM, 'peregrino_sacar_baston_frente')
CASA_GARRA = 0.90           # por debajo, la garra no se fia: se interpola
# (2026-10-12) Lo que se agranda la casilla por arriba, por animacion: el sacar sube la
# garra 29 px por encima de la de 904 (se cortaba): su video va montado con
# montar.py --my 152 (casilla 664x952, hoja 332x476) y su garra.json sale de
# seguir_garra.py. El guardar sigue en 904.
MY_ANIM = {'sacar_baston_espalda': 152, 'guardar_baston_espalda': MY}
GU = True       # la limpieza (antes, opcion --gu): siempre
# (--gu) Con el baston a la espalda, por encima del hombro arreglar.py no repone la
# espalda limpia (Veo gira la cabeza) y la garra de Veo, algo mas pequena y movida,
# asomaba debajo de la nuestra: salia doble (con la bola casi no se veia; sin bola, si).
# Tramos del video con nuestra garra a la espalda (en la correa o pivotando sobre el pie).
DOBLE = {'sacar_baston_espalda': (19, 68), 'guardar_baston_espalda': (62, 106)}
# (al sacar, desde el 69 el baston va por detras del cuerpo: ahi lo gordo de la garra de
# Veo, que quedaba encima de la nuestra como discos, lo quita ya arreglar.py; repintar
# aqui la garra de la correa dejaba una costura con su vara, que va al largo de la mano)
B_CORREA = (395.28, 261.50)     # nuestra bola en la correa (casilla de 904; la de arreglar.py)
R_DOBLE = 78                    # px de master alrededor de nuestra bola donde se limpia
BAJO_BOLA = 58                  # y hasta tantos px por debajo de ella (la garra y su tramo)
SOBRE_BOLA = 44                 # por encima de esta fila (bola + esto), la zona entera (los cuernos);
FRANJA = 16                     # por debajo, solo a tantos px de la vara (el hombro y la manga, no)


def reposo(modo, my=MY):
    """El fotograma base del reposo de espaldas en la casilla grande, con lo que le
    pone la escena encima: sin baston, el baston en la correa (de espaldas va por
    delante del cuerpo); con baston, la correa vacia. Las capas (664x904) se hicieron
    para MY: con otra altura, mas abajo."""
    c = Image.new('RGBA', (CAS[0], CAS[1] - MY + my), (0, 0, 0, 0))
    if modo == 'sin':
        c.alpha_composite(Image.open(os.path.join(NUEVA, 'espalda_sin_baston.png')).convert('RGBA'), (MX, my))
        c.alpha_composite(Image.open(os.path.join(NUEVA, 'baston_en_correa.png')).convert('RGBA'), (0, my - MY))
    else:
        c.alpha_composite(Image.open(os.path.join(ANIM, 'peregrino_secuencia_frontal', '04_limpios', 'reposo_espalda_cb_000.png')).convert('RGBA'), (MX, my))
        c.alpha_composite(Image.open(os.path.join(CAPAS, 'funda_vacia_reposo_espalda.png')).convert('RGBA'), (0, my - MY))
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


def anclar_final(frames, pos, ref_img, ref_bola, umbral=0.93, mezcla=6):
    """(2026-10-12) Al final, la bola anclada a la garra del reposo de llegada: el
    seguimiento de garra.py se iba desviando con el baston ya quieto (4-5 px a la
    izquierda en 69-84) y el puente final la llevaba a su sitio: "se rectifica al final".
    Desde el final hacia atras, mientras la garra case con la del reposo (>= umbral), la
    bola va donde la plantilla del reposo (con su bola) cae en el fotograma; se entra en
    mezcla fotogramas."""
    m_ref = G.con_borde(G.madera(np.asarray(ref_img)))
    t, piv = G.plantilla(m_ref, (ref_bola[0] + G.BORDE, ref_bola[1] + G.BORDE))
    nuevos = {}
    for k in range(len(frames) - 1, -1, -1):
        m = G.con_borde(G.madera(np.asarray(frames[k])))
        r = G.buscar(m, t, piv, (pos[k][0] + G.BORDE, pos[k][1] + G.BORDE), 0.0, radio=24, angs=range(-6, 7, 2))
        if r is None or r[2] < umbral:
            break
        nuevos[k] = (r[0][0] - G.BORDE, r[0][1] - G.BORDE)
    if len(nuevos) < mezcla + 2:
        return pos, 0
    ks = sorted(nuevos)
    xy = gaussian_filter1d(np.array([nuevos[k] for k in ks], float), 1.0, axis=0, mode='nearest')
    pos = np.array(pos, float)
    for i, k in enumerate(ks):
        w = min(max((k - ks[0]) / float(mezcla), 0.0), 1.0)
        w = w * w * (3 - 2 * w)
        pos[k] = pos[k] * (1 - w) + xy[i] * w
    return pos, ks[0]


def limpiar_doble(V, a, b, my, job=None):
    """Quita la garra de Veo que asoma junto a la nuestra en los fotogramas a..b.

    Nuestra garra se busca por su forma (la de la capa de la escena, baston_en_correa.png,
    girada y movida: garra.buscar, giro de grado en grado). Alrededor de ella y por encima
    de su tramo, todo lo que no es capucha (gris) ni la mano (piel en manchas grandes)
    fuera, tambien dentro de nuestra garra (ahi se mezclaba la de Veo: dejar lo de dentro
    de su silueta no bastaba), rellenado con lo de alrededor (opaco dentro de la silueta
    cerrada del cuerpo), con el borde suave. La zona: el disco por encima de la base de la
    garra y, por debajo, una franja a lo largo de la vara (la tunica y la manga son del
    mismo pardo que la madera: no se tocan). Encima, nuestra garra repintada de la capa en su sitio y giro, con el
    borde de la zona fundido con lo de abajo (su vara sigue por la espalda), y la mano
    delante."""
    baja = my - MY
    capa = np.zeros((CAS[1] + baja, CAS[0], 4), np.uint8)
    capa[baja:] = np.asarray(Image.open(os.path.join(NUEVA, 'baston_en_correa.png')).convert('RGBA'))
    limpia = Image.new('RGBA', (CAS[0], CAS[1] + baja), (0, 0, 0, 0))
    limpia.alpha_composite(Image.open(os.path.join(NUEVA, 'espalda_sin_baston.png')).convert('RGBA'), (MX, my))
    rl = np.asarray(limpia).astype(np.float32)
    b0 = (B_CORREA[0], B_CORREA[1] + baja)
    t, piv = G.plantilla(G.con_borde(G.madera(capa)), (b0[0] + G.BORDE, b0[1] + G.BORDE))
    hs = lambda im: cv2.cvtColor(np.ascontiguousarray(im[..., :3]).astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.int32)
    hsr = hs(rl)
    sil_r = ((hsr[..., 1] < 70) & (hsr[..., 2] > 100) & (rl[..., 3] > 128)).astype(np.float32)
    ys, xs = np.mgrid[0:capa.shape[0], 0:capa.shape[1]]
    pos, ang = (b0[0] + G.BORDE, b0[1] + G.BORDE), 0.0
    # donde la garra de Veo (garra.json): de ahi se busca la nuestra (al subir deprisa,
    # desde la del fotograma anterior se perdia)
    gj = {int(kk): v for kk, v in json.load(open(os.path.join(ANIM, job, 'garra.json'))).items()} if job else {}
    for k in range(a, b + 1):
        fr = np.asarray(V[k].convert('RGBA')).copy()
        if k in gj and gj[k][3] >= CASA_GARRA:
            pos = (gj[k][0] + G.BORDE, gj[k][1] + G.BORDE)
        r = G.buscar(G.con_borde(G.madera(fr)), t, piv, pos, ang, radio=30, angs=range(-10, 11, 1))
        if r is None or r[2] < 0.75:
            print('   %d: nuestra garra no se encuentra (%s): sin limpiar' % (k, None if r is None else round(r[2], 2)))
            continue
        pos, ang = r[0], r[1]
        bx, by = pos[0] - G.BORDE, pos[1] - G.BORDE
        M = cv2.getRotationMatrix2D((float(b0[0]), float(b0[1])), float(ang), 1.0)
        M[:, 2] += (bx - b0[0], by - b0[1])
        cp = capa.astype(np.float32)
        cp = np.dstack([cp[..., :3] * cp[..., 3:] / 255, cp[..., 3:]])
        cw = cv2.warpAffine(cp, M, (capa.shape[1], capa.shape[0]), flags=cv2.INTER_CUBIC, borderValue=0).clip(0, 255)
        nuestra = cv2.dilate((cw[..., 3] > 20).astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
        h = hs(fr)
        gris = (h[..., 1] < 60) & (h[..., 2] > 100)
        # (los dedos en sombra son mas oscuros: la mano, desde lo claro y crecida hacia lo
        # rosado mas oscuro de alrededor)
        piel = ((h[..., 0] < 9) | (h[..., 0] > 170)) & (h[..., 2] > 140) & (h[..., 1] > 40) & (fr[..., 3] > 0)
        n, et, st, _ = cv2.connectedComponentsWithStats(piel.astype(np.uint8), 8)
        piel = np.isin(et, [j for j in range(1, n) if st[j, cv2.CC_STAT_AREA] >= 150])
        rosado = ((h[..., 0] < 10) | (h[..., 0] > 168)) & (h[..., 2] > 90) & (h[..., 1] > 30) & (fr[..., 3] > 0)
        for _ in range(4):
            piel = (cv2.dilate(piel.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0) & (rosado | piel)
        piel = cv2.morphologyEx(piel.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (13, 13))) > 0
        from scipy.ndimage import binary_fill_holes as _llenar
        piel = _llenar(piel) & (fr[..., 3] > 0)
        piel = cv2.dilate(piel.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
        # la zona: por encima de la bola, el disco (los cuernos); por debajo, una franja a
        # lo largo de nuestra vara (el pardo de la tunica y de la manga casa con el de la
        # madera: quitar todo lo no gris se llevaba el hombro)
        filas = [(y, np.mean(np.where(cw[y, :, 3] > 128)[0])) for y in range(int(by) + 15, int(by) + BAJO_BOLA)
                 if 0 <= y < cw.shape[0] and (cw[y, :, 3] > 128).any()]
        if len(filas) >= 5:
            fy, fx = np.array(filas).T
            pend, orig = np.polyfit(fy, fx, 1)
            junto_vara = np.abs(xs - (pend * ys + orig)) < FRANJA
        else:
            junto_vara = np.zeros(xs.shape, bool)
        disco = np.hypot(xs - bx, ys - by) < R_DOBLE
        zona = disco & ((ys < by + SOBRE_BOLA) | (junto_vara & (ys < by + BAJO_BOLA)))
        # lo de Veo: lo pegado a nuestra garra o con la saturacion de la madera (la tunica,
        # del mismo tono pero menos saturada, no: quitarla dejaba costuras)
        cerca_nuestra = cv2.dilate(nuestra.astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (31, 31))) > 0
        madera_v = (h[..., 0] >= 9) & (h[..., 0] <= 28) & (h[..., 1] >= 100)
        veo = zona & (fr[..., 3] > 0) & ~gris & ~piel & (cerca_nuestra | madera_v)
        # el borde suavizado de la capucha (gris mezclado con el fondo: oscuro y poco
        # saturado, pegado al fondo) es capucha, no Veo: con el de la limpia (duro y con
        # ribete claro) salia un doble contorno en su lado derecho
        borde = (h[..., 1] < 45) & (cv2.dilate((fr[..., 3] < 10).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0)
        veo &= ~borde
        gris_cap = (gris & (fr[..., 3] > 128)).astype(np.uint8)
        nc, ec, sc, _ = cv2.connectedComponentsWithStats(gris_cap, 8)
        envolvente = np.zeros(gris_cap.shape, np.uint8)
        if nc > 1:
            j = 1 + int(np.argmax(sc[1:, cv2.CC_STAT_AREA]))
            pts = np.column_stack(np.where(ec == j)[::-1]).astype(np.int32)
            cv2.fillConvexPoly(envolvente, cv2.convexHull(pts), 1)
        envolvente = envolvente > 0
        oscuro = (h[..., 2] < 100) & (fr[..., 3] > 0) & ~envolvente & ~piel & (ys < by + SOBRE_BOLA) & disco
        veo |= oscuro
        if not veo.any():
            continue
        # el relleno de lo de Veo, del propio fotograma (la espalda limpia no: su capucha
        # tiene el borde duro y con ribete claro, y con un cierre grande la capucha crecia
        # hacia la garra; salia un doble contorno en su lado derecho):
        #   la capucha: la visible con un cierre pequeno (solo las muescas), rellenada con
        #     su propio gris (lo que no es capucha, a su color medio, no cuenta);
        #   el resto del cuerpo: lo de alrededor, opaco con un cierre pequeno;
        #   el fondo, transparente.
        # Al sacar (44-52) Veo deja ademas sombras grises de su baston sobre la capucha:
        # tambien son "no gris claro" y van con la capucha.
        gris_v = (gris & (fr[..., 3] > 128)).astype(np.uint8)
        capucha_reg = cv2.morphologyEx(gris_v, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11))) > 0
        cuerpo_reg = cv2.morphologyEx(((fr[..., 3] > 128) & ~veo).astype(np.uint8), cv2.MORPH_CLOSE,
                                      cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))) > 0
        rgb = cv2.inpaint(np.ascontiguousarray(fr[..., :3]), (veo | nuestra).astype(np.uint8), 5, cv2.INPAINT_TELEA)
        if gris_v.any():
            medio = np.median(fr[..., :3][gris_v > 0], 0)
            solo_gris = fr[..., :3].copy()
            solo_gris[~(gris_v > 0)] = medio.astype(np.uint8)
            rgb_cap = cv2.inpaint(np.ascontiguousarray(solo_gris), (veo & capucha_reg).astype(np.uint8), 5, cv2.INPAINT_TELEA)
            rgb = np.where((veo & capucha_reg)[..., None], rgb_cap, rgb)
        # y lo que quede rodeado de cuerpo y garra (en la union de la capucha con el hombro)
        # no es fondo: opaco
        from scipy.ndimage import binary_fill_holes
        opaco = capucha_reg | cuerpo_reg | ((fr[..., 3] > 128) & ~veo) | nuestra
        opaco = binary_fill_holes(opaco) & ~(nuestra & ~(capucha_reg | cuerpo_reg | binary_fill_holes(capucha_reg | cuerpo_reg | ((fr[..., 3] > 128) & ~veo))))
        # la capucha donde estaba lo de Veo: hasta su envolvente (la espalda limpia, aun
        # alineada, se salia del borde real y quedaba una franja palida; sin ella, huecos)
        env_suave = cv2.GaussianBlur(envolvente.astype(np.float32), (0, 0), 0.8)
        donde = veo & (env_suave > 0.02) & ~cuerpo_reg
        alfa = np.where(opaco, 255.0, 0.0)
        alfa = np.where(donde, env_suave * 255.0, alfa)
        if gris_v.any():
            rgb_cap2 = cv2.inpaint(np.ascontiguousarray(solo_gris), veo.astype(np.uint8), 5, cv2.INPAINT_TELEA)
            rgb = np.where(donde[..., None], rgb_cap2, rgb)
        rk = np.dstack([rgb, alfa]).astype(np.float32)
        z = cv2.GaussianBlur(cv2.dilate(veo.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(np.float32), (0, 0), 1.0)
        z = np.clip(np.maximum(z * 1.6, veo), 0, 1) * (fr[..., 3] > 0)
        # en el borde de la zona, lo de debajo se quita tan poco a poco como entra nuestra
        # garra (si no, una raya de fondo siguiendo el borde)
        dz = np.clip(cv2.GaussianBlur(zona.astype(np.float32), (0, 0), 2.5) * 1.4, 0, 1) * zona
        z = z * dz[..., None] if z.ndim == 3 else z * dz
        z = np.where(piel, 0, z)
        z = z[..., None] if z.ndim == 2 else z
        f0 = fr.astype(np.float32)
        pf = np.dstack([f0[..., :3] * f0[..., 3:] / 255, f0[..., 3:]])
        pr = np.dstack([rk[..., :3] * rk[..., 3:] / 255, rk[..., 3:]])
        m = pf * (1 - z) + pr * z
        # nuestra garra encima (de espaldas va por delante de la capucha), entera dentro
        # de la zona y fundida en su borde con la de abajo; la mano, delante de todo
        g = cw * dz[..., None]
        m = g + m * (1 - g[..., 3:] / 255)
        mano = np.where(piel, 1.0, 0.0)[..., None]
        m = pf * mano + m * (1 - mano)
        al = m[..., 3:]
        out = np.dstack([np.where(al > 1e-3, m[..., :3] * 255 / np.maximum(al, 1e-3), 0), al]).round().clip(0, 255).astype(np.uint8)
        V[k] = Image.fromarray(out, 'RGBA')
    print('   garra doble limpia %d-%d' % (a, b))


def sin_motas(im, minimo=30):
    """Fuera las motas sueltas (piezas de menos de 'minimo' px sin tocar el cuerpo): restos
    del croma alrededor de la garra (los reposos de espaldas con baston traen ~60; en los
    puentes del guardar el contorno se veia punteado)."""
    a = np.asarray(im.convert('RGBA')).copy()
    n, et, st, _ = cv2.connectedComponentsWithStats((a[..., 3] > 0).astype(np.uint8), 8)
    malas = [j for j in range(1, n) if st[j, cv2.CC_STAT_AREA] < minimo]
    if malas:
        a[np.isin(et, malas)] = 0
    return Image.fromarray(a, 'RGBA')


b_sin, b_con = G.bolas_de_referencia_espalda()
ANIMS = {
    # nombre: job, tramo, (modo de entrada, bola, escala, giro), (de salida), de, a, puentes
    'sacar_baston_espalda': ('peregrino_sacar_baston_espalda_v2', (19, 100),
                             ('sin', b_sin, 1.0, GIRO_CORREA), ('con', b_con, ESCALA_CON, 0.0),
                             'reposo_espalda_sb', 'reposo_espalda_cb', (3, 5)),
    # (2026-10-12) el guardar, del video A (el de B atravesaba el cuerpo): ver
    # ../peregrino_guardar_baston_espalda_a/arreglar.py (la garra siempre arriba)
    'guardar_baston_espalda': ('peregrino_guardar_baston_espalda_a', (19, 106),
                               ('con', b_con, ESCALA_CON, 0.0), ('sin', b_sin, 1.0, GIRO_CORREA),
                               'reposo_espalda_cb', 'reposo_espalda_sb', (3, 4)),
}
if __name__ == '__main__':
    escena = {'fps': FPS, 'casilla': [CAS[0] // 2, CAS[1] // 2]}
    for nombre, (job, (a, b), ent, sal, de, hacia, (n_ent, n_sal)) in ANIMS.items():
        my = MY_ANIM[nombre]
        cas = (CAS[0], CAS[1] - MY + my)
        baja = np.array([0.0, my - MY])               # las bolas de los reposos, en esta casilla
        R0, R1 = reposo(ent[0], my), reposo(sal[0], my)
        V = capucha(job, a, b)
        if GU:
            limpiar_doble(V, DOBLE[nombre][0], DOBLE[nombre][1], my, job)
        frames = [A.mezcla(R0, V[a], k / (n_ent + 1)) for k in range(1, n_ent + 1)]
        frames += [V[k] for k in range(a, b + 1)]
        frames += [A.mezcla(V[b], R1, k / (n_sal + 1)) for k in range(1, n_sal + 1)]
        pv, sin_garra = bola_video(job, a, b)
        b_ent, b_sal = np.array(ent[1]) + baja, np.array(sal[1]) + baja
        p_ent = [b_ent + (pv[0] - b_ent) * k / (n_ent + 1) for k in range(1, n_ent + 1)]
        p_sal = [pv[-1] + (b_sal - pv[-1]) * k / (n_sal + 1) for k in range(1, n_sal + 1)]
        pos = np.array(p_ent + list(pv) + p_sal)
        pos, desde_anclada = anclar_final(frames, pos, R1, b_sal)
        print('%s: la bola, anclada a la garra del reposo desde el %d' % (nombre, desde_anclada))
        esc = A.giro_mientras_se_mueve(pos, ent[2], sal[2]); gir = A.giro_mientras_se_mueve(pos, ent[3], sal[3])
        filas = [[round(float(x) / 2 - cas[0] / 4, 2), round(float(y) / 2 - cas[1] / 4, 2), round(float(e), 4), round(float(g), 4)]
                 for (x, y), e, g in zip(pos, esc, gir)]
        salida = job
        nombre_gu = nombre
        carpeta = os.path.join(ANIM, salida, '04_limpios'); os.makedirs(carpeta, exist_ok=True)
        for f in glob.glob(os.path.join(carpeta, '*.png')):
            os.remove(f)
        for k, im in enumerate(frames):
            if GU:
                im = sin_motas(im)
            A.con_botas(im).save(os.path.join(carpeta, '%s_%03d.png' % (nombre_gu, k)))     # botas.py
        json.dump([[nombre_gu, salida, len(frames), FPS, False, list(range(len(frames)))]], open(os.path.join(ANIM, salida, 'animaciones.json'), 'w'))
        escena[nombre_gu] = {'de': de, 'a': hacia, 'casilla': [cas[0] // 2, cas[1] // 2], 'orbe': filas}
        print(nombre, len(frames), 'fotogramas (%d de puente, video %d-%d, %d de puente); garra interpolada en %d' % (n_ent, a, b, n_sal, sin_garra))
    json.dump(escena, open(os.path.join(PROY, 'assets', 'characters', 'peregrino', 'acciones_espalda.json'), 'w'),
              separators=(',', ':'))
