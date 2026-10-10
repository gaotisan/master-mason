"""Seguimiento del baston a la espalda de Magnus.

Para cada fotograma de resources/characters/magnus_frames.tres saca donde va
el baston: un punto de su eje, su giro y si va detras o delante del cuerpo.
Todo en pixeles de la casilla a media escala (la de la hoja).

Como se mide:
  - hacia donde mira: por la barba (pixeles casi blancos). A la derecha del
    centro = perfil derecho, a la izquierda = perfil izquierdo, sin barba =
    de espaldas (los giros pasan por la espalda).
  - punto de espalda: el borde de atras de la silueta, BANDA px por debajo de
    la punta de la capucha.
  - inclinacion: recta ajustada al borde de atras en un tramo de TRAMO px. La
    capa ondea, asi que solo se le hace caso en parte (GANANCIA).
  - agachado: cuanto ha bajado la punta de la capucha sobre el suelo. Al
    agacharse el baston se tumba hacia delante con la espalda (AGACHADO_GIRO).

FUNDA DE CUERO, SOLO EN LOS GIROS (2026-10-08; el usuario: "la funda y el
cambio es solo para cuando da el giro"). En giro y giro_agachado el baston va
entero por FUERA de la tunica, en diagonal por la espalda (garra al hombro
derecho, pie a la cadera contraria) y metido en una funda de cuero cosida en el
omoplato, como en la vista de frente/espaldas (baston/frontal.py,
funda_cuero.py). Todo lo demas sigue como estaba (detras del cuerpo, sin funda).
  - De espaldas, la colocacion de frontal.py: bola BOLA_LADO hacia el hombro
    derecho desde el centro de la capucha, BOLA_BAJO bajo su punta, inclinado
    GIRO_ESPALDA (colocar_giro_funda).
  - En tres cuartos y de perfil la diagonal va en profundidad: la bola donde
    siempre (asomando tras la capucha) y el baston orientado de ella a la funda,
    pegada a la espalda (colocar_funda): a FUNDA_PROF px bajo el ancla de la
    capucha, a lo largo del tronco, y FUNDA_DENTRO por dentro del contorno de
    la espalda (ESPALDA_PIE / ESPALDA_AGACHADO, o el medido si queda mas
    dentro: que no sobresalga).
  - Para que la entrada y la salida del giro no peguen un salto, se pasa de la
    colocacion de antes (colocar_giro, sin funda) a la de la funda en
    RAMPA_FUNDA fotogramas desde el primero en que se ve algo de espalda (w >
    W_FUNDA), y al reves al acabar (b de 0 a 1); baston.gd funde la funda con
    b. Fuera de ese tramo el fotograma es el de antes, exacto. Por fotogramas
    y no por w: al final del giro de pie w se queda unos fotogramas quieto en
    0,07 y con b sacado de w la funda se quedaba a medio fundir.

Uso:  python seguir.py            -> escribe el JSON para Godot
JSON: por animacion y fotograma [x, y, giro, delante, parche] (el pivote, 40 px
bajo la punta del baston, respecto al centro de la casilla; giro en radianes de
Godot). En los giros, ademas, [..., w, funda_y, b, delante_funda]: cuanto se ve
la espalda (0 perfil, 1 espaldas), la y de la funda en el baston (px bajo el
pivote; si el baston sube por ella la funda se queda en el omoplato), cuanto
manda la colocacion con funda (0 = la de antes) y si con ella el baston entero
va delante del cuerpo.
"""
import json
import math
from pathlib import Path

import numpy as np
from scipy import ndimage as ndi
from scipy.ndimage import uniform_filter1d
from celdas import cargar, PROY

BANDA = 50               # fila del pivote: px bajo la punta de la capucha
REF_CAPUCHA = 39         # fila del borde de atras de la capucha que hace de ancla
GANANCIA = 0.8           # cuanto sigue el baston a la inclinacion del tronco
ANG_REPOSO = 10.0         # grados, punta hacia atras
AGACHADO_GIRO = -8.0      # grados extra con el agachado completo: paralelo al lomo
ALTO_REPOSO = 320         # punta de la capucha sobre el suelo, de pie
ALTO_AGACHADO = 248       # idem agachado del todo
SEPARACION = -15.0        # eje del baston respecto al borde de atras de la capucha (px)
# fila del suelo dentro de cada casilla: alto/2 - offset del sprite
SUELO = {"salto_correr": 200 + 185}
SUELO_COMUN = 180 + 165
SIN_BASTON = {"cayendo", "caida", "tumbado", "levantarse",
              # de frente/espaldas: las coloca baston/frontal.py (frontal.json)
              "andar_frente", "andar_espalda", "vuelta_frontal", "andar_frente_sin",
              "andar_espalda_sin", "vuelta_frontal_sin", "parada_frente_sin",
              "reposo_frente_sin", "reposo_espalda_sin",
              # sacar/guardar de frente (godot-a3, 2026-10-09): el baston va en
              # el dibujo; medidos aqui como de perfil, fallaban (sin barba)
              "sacar_baston_frente", "guardar_baston_frente"}
GIROS = {"giro", "giro_agachado"}
# Giros que pasan POR DELANTE (de cara a la camara; 2026-10-08; el de pie sale
# de magnus_giro_simetrico desde el 2026-10-10). Ahi la espalda no se ve nunca: el baston va siempre
# detras del cuerpo y pasa de su sitio en el reposo (perfil derecho) a ese
# mismo sitio espejado (perfil izquierdo) al ritmo del giro, medido por la
# barba. Sin funda ni parche: no se llega a ver la espalda.
GIROS_POR_DELANTE = {"giro"}
# px del pivote a la punta de abajo: alto del sprite que deja exportar.py menos el pivote
from PIL import Image as _Im
BAJO_PIVOTE = _Im.open(PROY / "assets/characters/baston/baston.png").height - 40
HOLGURA_SUELO = 24        # la punta no baja de aqui (por encima del bajo de la capa): si no, sube por la funda
# --- funda de cuero en los giros (ver arriba). Contorno de la espalda en ejes
# del tronco, a FUNDA_PROF bajo el ancla, medido en todas las animaciones
# (mediana): de pie 9-11 px por detras del borde de la capucha, agachado 26-29
FUNDA_PROF = 66.0
ESPALDA_PIE = 10.0
ESPALDA_AGACHADO = 27.0
FUNDA_DENTRO = 5.0        # el centro de la funda, por dentro del contorno (de canto mide ~12 px)
ORBE = (-0.6, -24.0)      # la bola respecto al pivote (baston.tscn)
FUNDA_X = 1.0             # la funda en el baston: x de su eje (baston.gd)
FUNDA_Y_ESPALDA = 56.0    # de espaldas: 80 bajo la bola, como en la vista frontal
# vista de espaldas (frontal.py, en px de master: aqui a la mitad): la bola hacia
# el hombro derecho del personaje y el baston inclinado con la garra hacia el
BOLA_LADO = 30.0
BOLA_BAJO = 19.5
GIRO_ESPALDA = 0.34       # radianes de Godot (horario +): garra a la derecha de la pantalla
W_DELANTE_IDA = 0.25      # w desde el que el baston entero va delante del cuerpo (ver colocar_giro_funda)
W_DELANTE_VUELTA = 0.6
W_FUNDA = 0.02            # la funda entra desde el primer fotograma con algo de espalda (w > esto)...
RAMPA_FUNDA = 4           # ...y se funde en estos fotogramas, al entrar y al salir del giro

SALIDA = PROY / "assets/characters/baston/baston_seguimiento.json"


def _barba(c, a):
    rgb = c[..., :3].astype(int)
    w = a & (rgb.min(2) > 175)
    n = int(w.sum())
    if n <= 20:
        return 0, 0.0
    xs = np.where(a)[1]
    return n, float(np.where(w)[1].mean() - (xs.min() + xs.max()) / 2)


def _capucha(c, a, top):
    """Pixeles grises de la capucha (los primeros 52 px desde la punta)."""
    rgb = c[..., :3].astype(int)
    mx, mn, me = rgb.max(2), rgb.min(2), rgb.mean(2)
    m = a & (mx - mn < 40) & (me > 95) & (me < 200) & (rgb[..., 2] >= rgb[..., 0] - 5)
    m[:top] = False
    m[top + 52:] = False
    return m


def medir(c, suelo):
    """Mide el fotograma como si mirase a la derecha. Devuelve dict o None.

    Ancla: el borde de atras de la capucha (gris, rigido, no lo tapan brazos
    ni capa). Inclinacion: recta del centro de la capucha al de la cadera
    (franja 110-160 px bajo la punta). Medido asi no se lo lleva el brazo
    estirado hacia atras en pleno salto, como pasaba con el borde de la
    espalda."""
    a = c[..., 3] > 128
    filas = np.where(a.any(1))[0]
    if len(filas) == 0:
        return None
    top = int(filas[0])
    n_barba, dx_barba = _barba(c, a)
    lado = (-1 if dx_barba < 0 else 1) if n_barba else 0
    W = c.shape[1]
    cc = c[:, ::-1] if lado == -1 else c
    aa = a[:, ::-1] if lado == -1 else a
    cap = _capucha(cc, aa, top)
    ys, xs = np.where(cap)
    hx, hy = float(xs.mean()), float(ys.mean())
    banda = aa[top + 110:top + 160]
    by_, bx_ = np.where(banda)
    px, py = float(bx_.mean()), float(by_.mean()) + top + 110
    incl = math.degrees(math.atan2(hx - px, py - hy))      # + = tronco hacia delante
    zona = cap[top + 28:top + 50]
    zx = np.where(zona.any(0))[0]
    atras = float(zx[0]) if len(zx) else hx
    fila = a[top + BANDA]
    fx = np.where(fila)[0]
    centro = float((fx[0] + fx[-1]) / 2) if len(fx) else W / 2
    agachado = float(np.clip((ALTO_REPOSO - (suelo - top)) / (ALTO_REPOSO - ALTO_AGACHADO), 0, 1))
    # bordes del tronco (sin voltear) en la franja de los omoplatos: los giros
    # colocan la columna entre los dos segun lo que haya girado
    izq, der = [], []
    for yy in range(top + 55, min(a.shape[0], top + 95)):
        fx = np.where(a[yy])[0]
        if len(fx):
            izq.append(fx[0]); der.append(fx[-1])
    borde_i = float(np.median(izq)) if izq else W / 2
    borde_d = float(np.median(der)) if der else W / 2
    return {"borde_i": borde_i, "borde_d": borde_d, "suelo": suelo, "top": top, "lado": lado, "barba": n_barba, "atras": atras,
            "espalda": _espalda(aa, atras, top, incl),
            "incl": incl, "centro": centro, "agachado": agachado, "ancho": W}


def _espalda(aa, atras, top, incl):
    """Contorno de la espalda donde va la funda (ya volteado a mirar a la
    derecha): en ejes del tronco, a FUNDA_PROF bajo el ancla de la capucha,
    cuantos px hacia atras desde el borde de la capucha queda el ultimo pixel
    de la silueta (mediana de 13 filas). None si no se encuentra."""
    ri = math.radians(incl)
    abajo = np.array([-math.sin(ri), math.cos(ri)])
    atras_v = np.array([-math.cos(ri), -math.sin(ri)])
    q = np.array([atras, top + REF_CAPUCHA]) + FUNDA_PROF * abajo
    H, W = aa.shape
    out = []
    for k in range(-6, 7):
        p0 = q + k * abajo
        ultimo = None
        for s in np.arange(-30, 90, 0.5):
            x, y = p0 + s * atras_v
            xi, yi = int(round(x)), int(round(y))
            if 0 <= yi < H and 0 <= xi < W and aa[yi, xi]:
                ultimo = s
        if ultimo is not None:
            out.append(ultimo)
    return float(np.median(out)) if out else None


def _bordes(a, y0, y1):
    izq, der = [], []
    for yy in range(max(0, y0), min(a.shape[0], y1)):
        fx = np.where(a[yy])[0]
        if len(fx):
            izq.append(fx[0]); der.append(fx[-1])
    if not izq:
        return a.shape[1] / 2, a.shape[1] / 2
    return float(np.median(izq)), float(np.median(der))


def medir_giro(c, m):
    """Lo que hace falta para seguir el cuerpo en los giros, SIN voltear (solo
    se mide en los giros, es lento; se anade a lo de medir()):
      - anchura y centro del tronco en los hombros (55-95 px bajo la punta)
        y en la cadera (110-160): de perfil el tronco es estrecho y de
        espaldas ancho, de ahi sale cuanto ha girado.
      - capucha (centro) e inclinacion en pantalla capucha -> cadera
        (+ = arriba hacia la izquierda, antihorario).
      - marcas de la columna, que solo se ven de espaldas: la costura oscura
        del centro de la espalda (giro de pie) y la muesca de arriba de la V
        gris de la capa (giro agachado, encorvado no se ve la costura)."""
    a = c[..., 3] > 128
    top = m["top"]
    hi, hd = _bordes(a, top + 55, top + 95)
    ci, cd = _bordes(a, top + 110, top + 160)
    cap = _capucha(c, a, top)
    ys, xs = np.where(cap)
    hx, hy = float(xs.mean()), float(ys.mean())
    cad_y = top + 135.0
    tilt = math.degrees(math.atan2((ci + cd) / 2 - hx, cad_y - hy))
    return {"hombro_w": hd - hi, "hombro_c": (hi + hd) / 2, "cadera_w": cd - ci, "cadera_c": (ci + cd) / 2,
            "cap_x": hx, "cap_y": hy, "tilt": tilt,
            "costura": _costura(c, a, top), "muesca": _muesca(c, a, top)}


def _costura(c, a, top):
    """Costura del centro de la espalda: linea oscura y fina casi vertical en
    la franja de los omoplatos (a la altura del pivote). Devuelve las lineas
    oscuras mas marcadas como [(x, fuerza), ...]: hay otras (bordes de las
    piezas de la capa, la barba) y se escoge despues la que siga al baston."""
    L = c[..., :3].astype(float).mean(2)
    hp = L - uniform_filter1d(L, 9, axis=1)          # oscuro y estrecho = negativo
    votos = np.zeros(c.shape[1])
    for yy in range(top + 45, min(a.shape[0], top + 95)):
        fx = np.where(a[yy])[0]
        if len(fx) < 20:
            continue
        r = hp[yy].copy()
        r[:fx[0] + 6] = 0
        r[fx[-1] - 5:] = 0
        r[r > -12] = 0
        votos -= r
    sm = np.convolve(votos, [1, 2, 3, 2, 1], "same")
    picos = [k for k in range(2, len(sm) - 2) if sm[k] > 0 and sm[k] == sm[k - 2:k + 3].max()]
    out = []
    for k in sorted(picos, key=lambda k: -sm[k])[:4]:
        w = sm[k - 2:k + 3]
        out.append((float((w * np.arange(k - 2, k + 3)).sum() / w.sum()), float(sm[k])))
    return out


def _muesca(c, a, top):
    """Punta de abajo de la V que forma por arriba el gris de la espalda de
    la capa (esta sobre la columna). Devuelve (x, profundidad en px)."""
    rgb = c[..., :3].astype(int)
    me = rgb.mean(2)
    g = a & (np.abs(rgb[..., 0] - rgb[..., 1]) < 12) & (rgb[..., 2] >= rgb[..., 0] - 4) & (me > 70) & (me < 135)
    g = ndi.binary_opening(g, iterations=1)
    lab, k = ndi.label(g)
    mejor = None
    for j in range(1, k + 1):
        ys, _ = np.where(lab == j)
        if len(ys) < 300 or ys.min() < top + 55:      # la capucha no
            continue
        if mejor is None or len(ys) > mejor[0]:
            mejor = (len(ys), j)
    if mejor is None:
        return 0.0, 0.0
    m = lab == mejor[1]
    cols = np.where(m.any(0))[0]
    tops = ndi.median_filter(np.array([np.argmax(m[:, x]) for x in cols], float), 5)
    prof, k2 = 0.0, 0
    for i in range(6, len(cols) - 6):
        p = min(tops[i] - tops[:i].min(), tops[i] - tops[i + 1:].min())
        if p > prof:
            prof, k2 = float(p), i
    sel = np.where(tops >= tops[k2] - 0.5)[0]
    sel = sel[np.abs(sel - k2) < 6]
    return float(cols[sel].mean()), prof


def colocar(m, m0):
    """Punto del eje del baston, giro en grados (+ = punta hacia atras con el
    personaje mirando a la derecha; en Godot se pasa a radianes con el signo
    cambiado) y si va delante del cuerpo."""
    fi = m["incl"] - m0["incl"]
    th = ANG_REPOSO - GANANCIA * fi + AGACHADO_GIRO * m["agachado"]
    # el pivote cuelga de la capucha y se va hacia atras al inclinarse el tronco
    r = math.radians(fi)
    dx, dy = SEPARACION, BANDA - REF_CAPUCHA
    x = m["atras"] + dx * math.cos(r) - dy * math.sin(r)
    y = m["top"] + REF_CAPUCHA + dx * math.sin(r) + dy * math.cos(r)
    # agachado la punta de abajo llegaria al suelo: en vez de tumbarlo (asomaba
    # por detras de la cadera y se veia la vara por fuera de la espalda) sube
    # por la funda; la garra asoma un poco mas por encima del lomo
    sobra = y + BAJO_PIVOTE * math.cos(math.radians(th)) - (m["suelo"] - HOLGURA_SUELO)
    if sobra > 0:
        y -= sobra
    x_lado = x if m["lado"] != -1 else m["ancho"] - 1 - x
    return x_lado, y, (-th if m["lado"] == -1 else th), False


def _suave3(v):
    """Solo quita el ruido de 1-2 px (media [1,2,1]); el movimiento se queda."""
    v = np.asarray(v, float)
    return np.convolve(np.pad(v, 1, mode="edge"), [0.25, 0.5, 0.25], mode="valid")


def _giro_medido(ms, f0, f1):
    """Cuanto ha girado el cuerpo (phi, 0 = perfil inicial, pi = el otro
    perfil) en cada fotograma, medido por lo ancho que se ve el tronco: visto
    como una elipse que gira, ancho^2 = fondo^2 cos^2 + ancho_espalda^2 sin^2.
    El fondo (perfil) sale de los fotogramas de perfil de cada lado y el ancho
    de espalda del fotograma mas ancho. Se promedian hombros y cadera (los
    hombros van algo por delante en el giro de pie y la cadera se queda en una
    meseta al empezar el agachado: juntas cuadran con la costura de la
    espalda, medida aparte, a 3-6 grados)."""
    n = len(ms)
    u = np.zeros(n)
    for clave in ("hombro_w", "cadera_w"):
        w = _suave3([m[clave] for m in ms])
        d0 = float(np.median(w[:f0 + 1]))
        d1 = float(np.median(w[f1:]))
        k = f0 + int(np.argmax(w[f0:f1 + 1]))
        W = max(float(w[k]), d0 + 1, d1 + 1)
        d = np.where(np.arange(n) <= k, d0, d1)
        u += np.clip((w ** 2 - d ** 2) / (W ** 2 - d ** 2), 0, 1)
    u[:f0 + 1] = 0
    u[f1:] = 0
    u /= max(u.max(), 1e-6)
    kp = int(np.argmax(u))
    phi = np.arcsin(np.sqrt(u))
    phi[kp + 1:] = math.pi - phi[kp + 1:]
    phi[f1:] = math.pi
    phi = _suave3(phi)
    phi[:f0 + 1] = 0
    phi[f1:] = math.pi
    return np.maximum.accumulate(phi)


def _correccion_columna(ms, phi, x_modelo, f0, f1):
    """Correccion de x con la columna, que se ve de espaldas.
      - costura (giro de pie): esta a la altura del pivote y de espaldas el
        baston va delante, con el parche cosido encima: se pone en la
        costura, del todo en cuanto se ve la espalda (sin phi > 0.5). De las
        lineas oscuras se coge la mas cercana al modelo (a menos de 12 px).
      - muesca de la V (agachado): esta mas abajo, en la joroba, mucho mas
        lejos del eje que el baston; de su diferencia con el modelo se quita
        la parte que va con cos(phi) (ajuste r = a + b cos phi) y se queda el
        resto (el descentrado y lo que se mueva la espalda), con peso
        sin^2(phi).
    Se usa la costura si se ve en 4 fotogramas o mas."""
    n = len(ms)
    sen = np.sin(phi)
    idx, r = [], []
    for i in range(f0 + 1, f1):
        if sen[i] < 0.35:
            continue
        cand = [(abs(xc - x_modelo[i]), xc) for xc, q in ms[i]["costura"] if q >= 500 and abs(xc - x_modelo[i]) < 12]
        if cand:
            idx.append(i); r.append(min(cand)[1] - x_modelo[i])
    if len(idx) >= 4:
        corr = _suave3(np.interp(np.arange(n), idx, r))
        t = np.clip((sen - 0.2) / 0.3, 0, 1)
        return corr * t * t * (3 - 2 * t)
    cs = np.cos(phi)
    idx, r = [], []
    for i in range(f0 + 1, f1):
        xm, q = ms[i]["muesca"]
        if q >= 5 and sen[i] > 0.5:
            idx.append(i); r.append(xm - x_modelo[i])
    if len(idx) < 4:
        return np.zeros(n)
    idx, r = np.array(idx), np.array(r)
    ok = np.abs(r - np.median(r)) < 10
    for _ in range(2):
        M = np.stack([np.ones(ok.sum()), cs[idx[ok]]], 1)
        (a, b), *_ = np.linalg.lstsq(M, r[ok], rcond=None)
        ok = np.abs(r - a - b * cs[idx]) < 6
    if ok.sum() < 4:
        return np.zeros(n)
    corr = _suave3(np.interp(np.arange(n), idx[ok], r[ok] - b * cs[idx[ok]]))
    return corr * sen ** 2


def colocar_giro(ms, base):
    """Giro de perfil derecho a perfil izquierdo pasando por la espalda (asi
    son giro y giro_agachado), como cuerpo rigido: el hombre gira sobre su eje
    vertical y el baston, cosido a la espalda, va con el. Todo sale de medir
    el cuerpo en cada fotograma, con un suavizado minimo (solo ruido):

      - phi (cuanto ha girado): por lo ancho que se ve el tronco
        (_giro_medido), no por el tiempo. Entre el ultimo fotograma de perfil
        y el primero del otro perfil (por la barba); fuera, la colocacion
        normal (base), asi que al entrar y salir no hay salto.
      - eje: centro del tronco de cada fotograma (hombros o cadera, ver abajo).
        El baston va a una distancia K detras: x = eje - K cos(phi). K sale
        de los dos fotogramas de perfil de los extremos para que cuadren
        exactos. De espaldas se corrige con la columna que se ve
        (_correccion_columna).
      - altura: la de los extremos interpolada con el giro, mas lo que suba o
        baje el cuerpo respecto a esa interpolacion (punta y centro de la
        capucha: van con los hombros).
      - inclinacion: la de perfil es hacia atras, en el plano del cuerpo, y
        se proyecta con cos(phi); encima, lo que se balancee el tronco en
        pantalla (capucha -> cadera) respecto a lo esperado, con GANANCIA como
        en las animaciones normales.
      - mientras se ve la espalda va por delante del cuerpo y METIDO BAJO LA
        TUNICA: solo asoma la garra por el cuello, con un parche de tela
        encima (corte en baston.gd). Ver la vara entera sobre una capa que
        ondea no queda bien por rigido que sea el baston."""
    f0, f1, phi, x, y, th = _modelo_giro(ms, base)
    out = []
    for i in range(len(ms)):
        if i <= f0 or i >= f1:
            xb, yb, tb, _ = base[i]
            out.append((xb, yb, tb, False, 0.0))
            continue
        yi = float(y[i])
        # la punta de abajo no baja del suelo (como en colocar)
        sobra = yi + BAJO_PIVOTE * math.cos(math.radians(th[i])) - (ms[i]["suelo"] - HOLGURA_SUELO)
        if sobra > 0:
            yi -= sobra
        vista = math.sin(phi[i])
        delante = vista > 0.4
        parche = float(np.clip((vista - 0.4) / 0.25, 0, 1)) if delante else 0.0
        out.append((float(x[i]), yi, float(th[i]), delante, parche))
    return out


def _modelo_giro(ms, base):
    """El modelo de colocar_giro: (f0, f1, phi, x, y, th) por fotograma. base:
    la colocacion de cada fotograma ((x, y, th, ...); solo cuentan los
    extremos f0 y f1)."""
    barba = np.array([m["barba"] for m in ms], float)
    llena = np.percentile(barba, 90)
    perfil = barba > 0.9 * llena
    n = len(ms)
    f0 = 0
    while f0 + 1 < n and perfil[f0 + 1]:
        f0 += 1
    f1 = n - 1
    while f1 - 1 > f0 and perfil[f1 - 1]:
        f1 -= 1
    phi = _giro_medido(ms, f0, f1)
    t = (1 - np.cos(phi)) / 2                      # 0 en un perfil, 1 en el otro

    def mezcla(a, b):
        return a * (1 - t) + b * t

    x0, y0, th0 = base[f0][:3]
    x1, y1, th1 = base[f1][:3]
    # centro del tronco: de la franja que menos se descentra de perfil (la que
    # menos cambia de un perfil al otro); el giro de pie, la cadera; el
    # agachado, los hombros (encorvado, la cadera de perfil se va muy atras)
    ejes = [_suave3([m[k] for m in ms]) for k in ("hombro_c", "cadera_c")]
    eje = min(ejes, key=lambda e: abs(e[f0] - e[f1]))
    K = mezcla(eje[f0] - x0, x1 - eje[f1])
    x = eje - K * np.cos(phi)
    x = x + _correccion_columna(ms, phi, x, f0, f1)
    alto = _suave3([(m["top"] + m["cap_y"]) / 2 for m in ms])
    y = mezcla(y0, y1) + (alto - mezcla(alto[f0], alto[f1]))
    tilt = _suave3([m["tilt"] for m in ms])
    th = mezcla(th0, th1) + GANANCIA * (tilt - mezcla(tilt[f0], tilt[f1]))
    return f0, f1, phi, x, y, th


# ------------------------------------------------------------ funda (giros)
def _rot(r, v):
    """Gira v el angulo r de Godot (horario +, y hacia abajo)."""
    c, s = math.cos(r), math.sin(r)
    return np.array([c * v[0] - s * v[1], s * v[0] + c * v[1]])


def _bola(x, y, th):
    """La bola de un pivote (x, y) y un giro th (grados de aqui)."""
    return np.array([x, y]) + _rot(-math.radians(th), ORBE)


def _pose(bola, r, fy):
    """De la bola, el giro (Godot) y la y de la funda a (pivote x, y, th, fy);
    th en grados del convenio de aqui (+ = punta hacia atras mirando a la
    derecha = -giro de Godot)."""
    p = np.asarray(bola, float) - _rot(r, ORBE)
    return float(p[0]), float(p[1]), -math.degrees(r), float(fy)


def _al_suelo(x, y, th, fy, suelo, w=1.0):
    """Si la punta de abajo llegaria al suelo, el baston sube por la funda a lo
    largo de su eje (la funda se queda donde esta: fy crece). Solo cuenta lo
    que se vea la parte de abajo (w): de perfil va detras del cuerpo, hacia la
    cadera contraria, y baston.gd no la dibuja por debajo de la funda."""
    r = -math.radians(th)
    sobra = y + BAJO_PIVOTE * math.cos(r) - (suelo - HOLGURA_SUELO)
    if sobra <= 0 or w <= 0:
        return x, y, th, fy
    k = w * sobra / max(math.cos(r), 0.3)
    return x + k * math.sin(r), y - k * math.cos(r), th, fy + k


def colocar_funda(m, m0):
    """Como colocar(), con la funda: la bola donde la pone colocar() (sin
    subirla por el suelo) y el baston orientado de la bola a la funda, pegada
    a la espalda. Devuelve (x, y, th, fy)."""
    fi = m["incl"] - m0["incl"]
    th = ANG_REPOSO - GANANCIA * fi + AGACHADO_GIRO * m["agachado"]
    r = math.radians(fi)
    dx, dy = SEPARACION, BANDA - REF_CAPUCHA
    piv = np.array([m["atras"] + dx * math.cos(r) - dy * math.sin(r),
                    m["top"] + REF_CAPUCHA + dx * math.sin(r) + dy * math.cos(r)])
    bola = piv + _rot(-math.radians(th), ORBE)
    # la funda: a lo largo del tronco (incl absoluta: + = hacia delante) bajo el
    # ancla y hacia la espalda hasta su contorno; el del cuerpo (sin la capa
    # que ondea) o, si la silueta se queda mas dentro, el medido
    ri = math.radians(m["incl"])
    abajo = np.array([-math.sin(ri), math.cos(ri)])
    atras = np.array([-math.cos(ri), -math.sin(ri)])
    hondo = ESPALDA_PIE + (ESPALDA_AGACHADO - ESPALDA_PIE) * m["agachado"]
    if m.get("espalda_s") is not None:
        hondo = min(hondo, m["espalda_s"])
    funda = np.array([m["atras"], m["top"] + REF_CAPUCHA]) + FUNDA_PROF * abajo + (hondo - FUNDA_DENTRO) * atras
    # giro que lleva la recta del baston de ORBE a (FUNDA_X, fy) sobre la de la
    # bola a la funda
    v = funda - bola
    largo = float(np.hypot(*v))
    fy = math.sqrt(max(largo ** 2 - (FUNDA_X - ORBE[0]) ** 2, 1.0)) + ORBE[1]
    giro = math.atan2(-v[0], v[1]) - math.atan2(-(FUNDA_X - ORBE[0]), fy - ORBE[1])
    x, y, th, fy = _pose(bola, giro, fy)
    x_lado = x if m["lado"] != -1 else m["ancho"] - 1 - x
    return x_lado, y, (-th if m["lado"] == -1 else th), fy


def _w_espalda(phi):
    """Cuanto se ve la espalda (0 de perfil, 1 de espaldas puras). sin^2: en
    tres cuartos aun manda el perfil."""
    return float(np.sin(phi) ** 2)


def colocar_giro_funda(ms, base, base_funda, lista):
    """El giro con la funda. lista: el de antes (colocar_giro). Devuelve por
    fotograma (x, y, th, w, fy, b, delante) con b = cuanto manda la funda."""
    f0, f1, phi, x, y, th = _modelo_giro(ms, base_funda)
    t = (1 - np.cos(phi)) / 2
    fy = base_funda[f0][3] * (1 - t) + base_funda[f1][3] * t
    ws = np.array([_w_espalda(p) if f0 < i < f1 else 0.0 for i, p in enumerate(phi)])
    con = np.nonzero(ws > W_FUNDA)[0]
    ia, iz = (int(con[0]), int(con[-1])) if len(con) else (len(ms), -1)
    out = []
    for i in range(len(ms)):
        xa, ya, ta = lista[i][:3]
        b = min(np.clip((i - ia + 1) / RAMPA_FUNDA, 0, 1), np.clip((iz - i + 1) / RAMPA_FUNDA, 0, 1))
        b = float(b * b * (3 - 2 * b))
        if i <= f0 or i >= f1 or b <= 0:
            out.append((xa, ya, ta, 0.0, fy[i], 0.0, False))
            continue
        # la bola del modelo de perfil y la de espaldas, mezcladas con w
        r_m = -math.radians(th[i])
        bola_m = np.array([x[i], y[i]]) + _rot(r_m, ORBE)
        m = ms[i]
        bola_e = np.array([m["cap_x"] + BOLA_LADO, m["top"] + BOLA_BAJO])
        w = _w_espalda(phi[i])
        bola = bola_m * (1 - w) + bola_e * w
        giro = r_m * (1 - w) + GIRO_ESPALDA * w
        f = fy[i] * (1 - w) + FUNDA_Y_ESPALDA * w
        # y de la colocacion de antes a esta (b): al entrar y salir del giro,
        # el fotograma de siempre
        bola = _bola(xa, ya, ta) * (1 - b) + bola * b
        giro = -math.radians(ta) * (1 - b) + giro * b
        xi, yi, ti, fi = _al_suelo(*_pose(bola, giro, f), m["suelo"], w)
        # la bola (y el baston entero) pasa por delante del cuerpo: al venir
        # hacia la camara el hombro derecho, pronto; al irse al otro lado,
        # tarde (asi se esconde tras la capucha en vez de pasarle por encima)
        delante = w >= (W_DELANTE_IDA if phi[i] < math.pi / 2 else W_DELANTE_VUELTA)
        out.append((xi, yi, ti, w, fi, b, bool(delante)))
    return out


def colocar_giro_rigido(ms, base, lista):
    """El giro con la funda como pieza RIGIDA (2026-10-08; el usuario: "se mueve
    demasiado y parece que atraviesa; algo simple, mas real, anclado y fijo:
    es el muneco el que gira"). El baston va cosido a la espalda y gira con el
    cuerpo sobre su eje vertical; en pantalla solo cambia la proyeccion:

      - phi (cuanto ha girado): el medido (_giro_medido), suavizado.
      - la bola, un punto fijo del cuerpo: detras del eje a la distancia D de
        perfil (sale de los dos perfiles de los extremos) y a un lado LAT de la
        columna (sale de donde va de espaldas):
            x = eje + LAT sin(phi) - D cos(phi)
        Altura: la de perfil, mas lo que suba o baje el cuerpo (capucha).
      - inclinacion: un vector fijo del cuerpo proyectado: la de perfil (hacia
        atras) con cos(phi) y la diagonal de espaldas (GIRO_ESPALDA) con
        sin(phi). Nada de mezclas de dos colocaciones distintas.
      - la funda, fija en el baston (FUNDA_Y_ESPALDA).
      - delante del cuerpo en cuanto la espalda mira a la camara (sin(phi) >
        0.25), igual a la ida que a la vuelta: el cambio pasa con el baston
        aun en el borde de la silueta, no encima del cuerpo.
    Los extremos son la colocacion de siempre (lista), asi que al entrar y
    salir del giro no hay salto. Devuelve por fotograma (x, y, th, w, fy, b,
    delante) como colocar_giro_funda."""
    f0, f1, _, *_ = _modelo_giro(ms, base)
    n = len(ms)
    # Cuanto ha girado, por la barba (lo que se ve de la cara): mientras se le
    # va la barba, de 0 a FASE; sin barba (de espaldas), de FASE a pi - FASE;
    # al volver la barba, hasta pi. Medido por el ancho del tronco iba con
    # retraso a la vuelta: con la barba ya fuera seguia "de espaldas" y el
    # baston, delante, se pintaba sobre el costado ("la funda atraviesa").
    FASE = math.radians(70)
    k5 = np.array([1, 2, 3, 2, 1], float) / 9
    q = _suave3(np.clip(np.array([m["barba"] for m in ms], float) / np.percentile([m["barba"] for m in ms], 90), 0, 1))
    sin_barba = [i for i in range(f0 + 1, f1) if ms[i]["barba"] == 0]
    k1, k2 = (sin_barba[0], sin_barba[-1]) if sin_barba else ((f0 + f1) // 2,) * 2
    phi = np.zeros(n)
    for i in range(n):
        if i <= f0:
            phi[i] = 0.0
        elif i >= f1:
            phi[i] = math.pi
        elif i < k1:
            phi[i] = FASE * (1 - q[i])
        elif i <= k2:
            phi[i] = FASE + (math.pi - 2 * FASE) * ((i - k1 + 0.5) / (k2 - k1 + 1))
        else:
            phi[i] = math.pi - FASE * (1 - q[i])
    phi = np.maximum.accumulate(phi)
    t = (1 - np.cos(phi)) / 2

    ejes = [np.convolve(np.pad([m[k] for m in ms], 3, mode="edge"), np.ones(7) / 7, mode="valid")
            for k in ("hombro_c", "cadera_c")]
    eje = min(ejes, key=lambda e: abs(e[f0] - e[f1]))

    # la bola de los dos perfiles (colocacion de siempre)
    b0 = _bola(*lista[f0][:3])
    b1 = _bola(*lista[f1][:3])
    D0 = eje[f0] - b0[0]
    D1 = b1[0] - eje[f1]
    th0, th1 = lista[f0][2], lista[f1][2]
    km = int(np.argmin(np.abs(phi - math.pi / 2)))
    LAT = float(ms[km]["cap_x"] + BOLA_LADO - eje[km])
    alto = np.convolve(np.pad([(m["top"] + m["cap_y"]) / 2 for m in ms], 2, mode="edge"), k5, mode="valid")

    out = []
    for i in range(n):
        xa, ya, ta = lista[i][:3]
        if i <= f0 or i >= f1:
            out.append((xa, ya, ta, 0.0, FUNDA_Y_ESPALDA, 0.0, False))
            continue
        s, c = math.sin(phi[i]), math.cos(phi[i])
        D = D0 + (D1 - D0) * t[i]
        bx = eje[i] + LAT * s - D * c
        by = b0[1] + (b1[1] - b0[1]) * t[i] + (alto[i] - (alto[f0] + (alto[f1] - alto[f0]) * t[i]))
        # el vector del baston: de perfil, hacia atras (tan de th, en grados de
        # aqui); de espaldas, la diagonal (GIRO_ESPALDA, radianes de Godot)
        atras = math.tan(math.radians(th0 if c > 0 else -th1))
        giro = math.atan(math.tan(GIRO_ESPALDA) * s - atras * c)
        w = s * s
        # delante (sobre la espalda) solo de espaldas de verdad: sin barba. La
        # funda se ve solo ahi, y entra y sale en 3 fotogramas DENTRO de ese
        # tramo: con la barba a la vista el baston va detras de la silueta.
        delante = k1 <= i <= k2
        b = float(np.clip(min(i - k1 + 1, k2 - i + 1) / 3, 0, 1)) if delante else 0.0
        b = b * b * (3 - 2 * b)
        xi, yi, ti, fi = _al_suelo(*_pose((bx, by), giro, FUNDA_Y_ESPALDA), ms[i]["suelo"], w if delante else 0.0)
        out.append((xi, yi, ti, w if delante else 0.0, fi, b, delante))
    return out


DESMARQUE = 0.30          # de espaldas, la garra asoma a este tanto del ancho de hombros de la nuca:
                          # con 0.15 la bola tapaba la capucha (parecia la cabeza)
INCL_ESPALDA = 0.0        # y vertical (radianes de Godot)
RAMPA_VERTICAL = 4        # fotogramas en que la funda y el baston entran/salen de la espalda


def colocar_giro_vertical(ms, base, lista):
    """El giro con el baston VERTICAL y quieto (2026-10-08; el usuario: "vuelve
    a la version vertical, a un 15 % desmarcado de la nuca, que no se mueva de
    ahi; con la funda, que cambie ligeramente de perspectiva y desaparezca
    bien"). Se ancla a la nuca (centro de los hombros) y no barre la espalda:

      - de espaldas (sin barba): x = nuca + DESMARQUE * ancho de hombros,
        vertical, por delante del cuerpo, con la funda.
      - con la barba a la vista (perfil y tres cuartos): detras de la silueta,
        con su colocacion de perfil; el paso a la de espaldas se reparte en el
        tramo en que la barba se va (o vuelve), siguiendo a la nuca.
      - la funda entra y sale en RAMPA_VERTICAL fotogramas: se funde y se
        estrecha (de canto a de frente) a la vez, sin aparecer de golpe.
    Devuelve por fotograma (x, y, th, w, fy, b, delante) como colocar_giro_funda."""
    f0, f1, *_ = _modelo_giro(ms, base)
    n = len(ms)
    k5 = np.array([1, 2, 3, 2, 1], float) / 9
    suave = lambda v: np.convolve(np.pad(np.asarray(v, float), 2, mode="edge"), k5, mode="valid")
    # la nuca: el centro de los hombros. De espaldas no se mueve (144-147 px en
    # el giro de pie); el de la capucha si (160 -> 130: la cabeza va adelantada
    # al cuello y al girar arrastra la medida), y el baston iba y volvia.
    nuca = suave([m["hombro_c"] for m in ms])
    alto = suave([(m["top"] + m["cap_y"]) / 2 for m in ms])
    sin_barba = [i for i in range(f0 + 1, f1) if ms[i]["barba"] == 0]
    k1, k2 = (sin_barba[0], sin_barba[-1]) if sin_barba else ((f0 + f1) // 2,) * 2
    km = (k1 + k2) // 2
    desm = DESMARQUE * float(ms[km]["hombro_w"])

    b0 = _bola(*lista[f0][:3])
    b1 = _bola(*lista[f1][:3])
    off0 = b0[0] - nuca[f0]                 # la bola respecto a la nuca, de perfil
    off1 = b1[0] - nuca[f1]
    g0 = -math.radians(lista[f0][2])        # giro de Godot de perfil
    g1 = -math.radians(lista[f1][2])

    def paso(i, a, z):                       # 0 en a, 1 en z, suave
        u = float(np.clip((i - a) / max(z - a, 1), 0, 1))
        return u * u * (3 - 2 * u)

    out = []
    for i in range(n):
        xa, ya, ta = lista[i][:3]
        if i <= f0 or i >= f1:
            out.append((xa, ya, ta, 0.0, FUNDA_Y_ESPALDA, 0.0, False))
            continue
        # de perfil a espaldas (ida) y de espaldas al otro perfil (vuelta)
        if i < k1:
            u = paso(i, f0, k1)
            off = off0 + (desm - off0) * u
            giro = g0 + (INCL_ESPALDA - g0) * u
        else:
            u = paso(i, k2, f1)
            off = desm + (off1 - desm) * u
            giro = INCL_ESPALDA + (g1 - INCL_ESPALDA) * u
        tt = (i - f0) / (f1 - f0)
        by = b0[1] + (b1[1] - b0[1]) * tt + (alto[i] - (alto[f0] + (alto[f1] - alto[f0]) * tt))
        bx = nuca[i] + off
        delante = k1 <= i <= k2
        b = float(np.clip(min(i - k1 + 1, k2 - i + 1) / RAMPA_VERTICAL, 0, 1)) if delante else 0.0
        b = b * b * (3 - 2 * b)
        w = b                                 # la funda se abre (perspectiva) a la vez que aparece
        xi, yi, ti, fi = _al_suelo(*_pose((bx, by), giro, FUNDA_Y_ESPALDA), ms[i]["suelo"], w)
        out.append((xi, yi, ti, w, fi, b, delante))
    return out


def colocar_giro_delante(celdas, base):
    """El baston en un giro por delante: de la colocacion del primer fotograma
    (perfil derecho, la del reposo) a la misma espejada (perfil izquierdo), con
    el avance del giro medido por la barba (de un lado de la silueta al otro;
    de frente queda en medio), suavizado y sin volver atras. Siempre detras."""
    off = []
    for c in celdas:
        a = c[..., 3] > 128
        n, o = _barba(c, a)
        off.append(o if n else np.nan)
    off = np.array(off, float)
    ok = np.isfinite(off)
    off = np.interp(np.arange(len(off)), np.where(ok)[0], off[ok])
    p = (off[0] - off) / max(off[0] - off[-1], 1e-6)
    p = np.maximum.accumulate(np.clip(p, 0, 1))
    p = np.convolve(np.pad(p, 2, mode="edge"), np.ones(5) / 5, mode="valid")
    p = p * p * (3 - 2 * p)
    W = celdas[0].shape[1]
    x0, y0, t0 = base[0][:3]
    out = []
    for pi in p:
        # espejo respecto al centro de la casilla y giro al reves
        out.append((x0 * (1 - pi) + (W - x0) * pi, y0, t0 * (1 - pi) - t0 * pi, False, 0.0))
    return out


def seguir_todo():
    A = cargar()
    m0 = medir(A["reposo"]["celdas"][0], SUELO_COMUN)
    datos = {}
    for nombre, an in A.items():
        if nombre in SIN_BASTON:
            datos[nombre] = None
            continue
        suelo = SUELO.get(nombre, SUELO_COMUN)
        ms = [medir(c, suelo) for c in an["celdas"]]
        base = [colocar(m, m0) for m in ms]
        if nombre in GIROS_POR_DELANTE:
            lista = colocar_giro_delante(an["celdas"], base)
        elif nombre in GIROS:
            for m, c in zip(ms, an["celdas"]):
                m.update(medir_giro(c, m))
            lista = colocar_giro(ms, base)
            # el contorno medido de la espalda, sin el ruido de un fotograma suelto
            esp = np.array([np.nan if m["espalda"] is None else m["espalda"] for m in ms])
            if np.isfinite(esp).any():
                esp = ndi.median_filter(np.where(np.isfinite(esp), esp, np.nanmedian(esp)), 5, mode="nearest")
                for m, e in zip(ms, esp):
                    m["espalda_s"] = float(e)
            # de espaldas, METIDO BAJO LA TUNICA (2026-10-08; el usuario: "antes
            # como quedaba debajo de la tunica no pasaba nada"): solo asoma la
            # garra por el cuello con el parche de tela (baston.gd corta la vara
            # con CORTE_ESPALDA), sin la funda de cuero ni la vara por fuera
            funda = colocar_giro_vertical(ms, base, lista)
            lista = [(x, y, th, bool(de), float(b)) for x, y, th, w, fy, b, de in funda]
        else:
            lista = [(x, y, th, False, 0.0) for x, y, th, _ in base]
        fr = []
        for c, fila in zip(an["celdas"], lista):
            x, y, th, delante, funda = fila[:5]
            H, W = c.shape[:2]
            f = {"x": round(x, 2), "y": round(y, 2), "th": round(th, 2),
                 "delante": delante, "funda": round(funda, 3), "W": W, "H": H}
            if len(fila) > 5:
                # giros: la colocacion con funda (con b = 0, la de antes) en
                # lugar de la de antes, sin parche
                xf, yf, thf, w, fy, bf, delf = fila[5]
                f.update({"x": round(xf, 2), "y": round(yf, 2), "th": round(thf, 2), "delante": False,
                          "funda": 0.0, "giro_funda": [round(w, 3), round(fy, 2), round(bf, 3), 1 if delf else 0]})
            fr.append(f)
        datos[nombre] = fr
    return datos


if __name__ == "__main__":
    d = seguir_todo()
    # Para Godot: posicion respecto al centro de la casilla (el sprite va
    # centrado) y giro en radianes en el sentido de Godot (horario +).
    salida = {}
    for n, fr in d.items():
        if fr is None:
            salida[n] = None
            continue
        salida[n] = [[round(f["x"] - f["W"] / 2, 2), round(f["y"] - f["H"] / 2, 2),
                      round(-math.radians(f["th"]), 4), 1 if f["delante"] else 0, f["funda"]]
                     + f.get("giro_funda", []) for f in fr]
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text(json.dumps(salida, separators=(",", ":")), encoding="utf-8")
    print("escrito", SALIDA, sum(len(v) for v in salida.values() if v), "fotogramas")
