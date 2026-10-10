"""Animaciones con el baston EN LA MANO (prueba): de magnus_andar_baston/04_limpios
saca las cuatro que cambia el piloto (reposo, arranque_andar, andar,
parada_andar), las monta en hojas a media escala y apunta en cada fotograma
donde esta la garra, para poner encima la bola por codigo.
  python mano.py"""
import json
import numpy as np
from PIL import Image
from celdas import PROY

ANIM = PROY / "raw/master_mason/anim"
ORIGEN = ANIM / "magnus_andar_baston_v2/04_limpios"
DESTINO = PROY / "assets/characters/baston"
COLS = 8
# Andar con el baston: video Character_walking_on_green_screen_20261007224913
# (magnus_andar_baston_v2, c_NNN = fotograma NNN del video; empieza y acaba en
# el reposo con el baston, que es baston_ref_en_mano). Los tramos salen de
# medir (paso.py -> paso_medido.json y andar_v2() aqui abajo):
#   reposo c_001-c_020 (quieto), arranque c_021 -> c_070 y al ciclo (BUCLE,
#   abajo), parada c_137 -> quieto (c_136 es la imagen del bucle). Antes (magnus_andar_baston, otro video): el baston iba a
#   su aire, se arrastraba, y la tunica cambiaba de dibujo entre el principio
#   y el final.
# Ciclo: video aparte hecho bucle (Old_master_builder_walking_cycle_
# 20261008085011, job magnus_andar_baston_bucle; prompt_baston_andar_bucle.txt):
# Flow con la misma imagen de inicio y de fin, el c_136 de v2 con la capucha
# recortada. Cierra 192 -> 1 con silueta 0,35 y color 0,54 pasos normales.
# El de v2 no se repetia exacto: cada vuelta cambia el brazo del baston, la
# mano que cuelga y la tunica, y ningun empalme casaba a la vez piernas y
# brazos (por color "cambia el paso", por silueta "fluctua el brazo"); un
# fundido por flujo optico entre vueltas dejaba manos y pies dobles.
BUCLE = "magnus_andar_baston_bucle"
# Del bucle se usa un tramo: 192 fotogramas enteros llevaban el baston a su
# aire (el video lo balancea cada ~55 fotogramas y los pasos van cada ~41: unas
# veces lo adelanta poco y una vez mucho, fotogramas 28-48; el usuario: "primero
# lanza el baston poquito y luego mas").
# Ciclo de UNA zancada del final del video (2026-10-10): c_153 -> c_191, c_001,
# c_002 (41 fotogramas, 1,37 s a 30). El de antes, c_090 -> c_199 (110), cerraba
# bien (0,57) pero por dentro llevaba un tropiezo, c_126-c_146 ("al principio un
# bucle que no encaja, y luego ya anda normal"): el pie claro (el de cerca) se
# planta delante en el 126 y, en vez de quedarse atras como en todas las demas
# zancadas (x 175-181 de la casilla master), se levanta a medio camino (x 285, el
# 139) y vuelve a plantarse delante en el 146; el oscuro da un paso corto (aterriza
# en x 310 en vez de 370) y se queda atras otra vez. Dos pasos en 20 fotogramas
# (13 y 7) donde los demas van cada 19-26: los pies van y vuelven. En el 140-142
# las piernas tienen ademas huecos de la limpieza. De c_147 al final del video y
# seguido por el 192 -> 1 anda normal; una zancada (pie claro aterriza en el
# 146, 187...) mide 41-42. El corte se eligio con la matriz de parecido
# (silueta, piernas, baston+garra y color) de todos los pares con 34-59 de
# separacion en c_147 -> c_027 (sin el tropiezo ni el lanzamiento grande del
# 28-48): el corte c_002 -> c_153 casa el c_153 con el c_003 que tocaria tras
# el c_002 a 0,44 pasos normales (silueta 0,40, piernas 0,23, baston 0,62, color 0,50;
# garra a 2,5 px master; los pies a 0-5 px), menos que un paso normal; +-2
# fotogramas alrededor del corte, 0,81. Todos los fotogramas seguidos menos el
# c_192: el 192 y el 1 son la misma imagen (Flow con inicio = fin), y con los
# dos el pie plantado volvia atras 2 px en el 1 (335 -> 337 -> 329) mientras
# el cuerpo seguia: patinaba ~4 px una vez por vuelta (0,4 pasos de cambio,
# medio fotograma parado). Al dar la vuelta el video sigue del 191 al 1 (0,58,
# como los de al lado: 0,76 y 0,63).
N_BUCLE = 192
CICLO = (153, 41)         # primer fotograma, largo (del job BUCLE, dando la vuelta)
vuelta = lambda k: (k - 1) % (N_BUCLE - 1) + 1     # ... 190, 191, 1, 2 ... (el 192 = el 1)
REPOSO = (1, 20)          # el reposo quieto de v2: ancla de los pies y pose de referencia
# Reposo respirando con el baston en la mano (Pilgrim_standing_breathing_calmly_
# 20261008122010): bucle c_002-c_076, dos respiraciones; empieza en la pose de
# baston_ref_en_mano (la de v2 c_001) y cierra 76 -> 2 a 0,71 pasos de silueta
# y 1,22 de color. A 30 fps dura 2,5 s, como el respirar sin baston (2,46).
REPOSO_JOB = "magnus_reposo_baston"
REPOSO_BUCLE = (2, 76)
ARRANQUE_DESDE = 21
# Largo maximo del arranque (fotogramas de v2): el que ya tenia, 49-50 (1,65 s).
# Se juega entero (soltar a medias sigue hasta el ciclo), asi que no se alarga.
ARRANQUE_MAX = 50
# Arranque SIN el video v2 (2026-10-10; el usuario: "el arrancar ese no cuadra
# con el andar ... pon solo el andar y hazlo cuadrar"): v2 es otro video (otro
# angulo del baston, otra postura) y al entrar al ciclo saltaba ~1,4 pasos, con
# el baston cambiando de golpe. Ahora del reposo se pasa directamente al ciclo:
# ARRANQUE_FUNDIDO fotogramas que llevan el reposo hasta el fotograma
# ENTRADA_FUNDIDO del ciclo moviendo pixeles (transicion()), en el sitio, y de
# ahi sigue el ciclo. El 26 es el del ciclo que mas se parece al reposo: el paso
# de los pies (juntos, a 10 px de los del reposo: se van atras mientras el
# cuerpo avanza esos 10 px, sin patinar: como cargar el peso antes del primer
# paso) y la bola a menos de 1 px de la del reposo. ARRANQUE_VIDEO = True
# vuelve al arranque de v2.
ARRANQUE_VIDEO = False
ARRANQUE_FUNDIDO = 8      # 0,27 s a 30 fps
ENTRADA_FUNDIDO = 26
# La transicion acelera (t = (j/(n-1))^CURVA_FUNDIDO): cada fotograma cambia y
# avanza mas que el anterior y el ultimo ya casi como un paso del ciclo. Con una
# curva suave (que frena al final) el cuerpo bajaba a 10 px/s justo antes de
# echar a andar a 122: se paraba y arrancaba de golpe.
CURVA_FUNDIDO = 2.0
PARADA_DESDE = 137        # lo que sigue al ciclo en el video
# Golpes del audio de los propios videos (pies y baston)
GOLPES_VIDEO = [43, 62, 79, 97, 115, 132, 156]
# En el bucle el audio no sigue a los pies (golpes en 62, 79, 110, 171...): las
# pisadas van donde aterriza un pie (salto en la franja del suelo: 22, 63, 109,
# 146, 187, cada ~41) y a mitad de zancada, el otro.
GOLPES_BUCLE = [22, 43, 63, 86, 109, 127, 146, 166, 187]
ANIMS = {
    # transiciones (videos de Flow): a velocidad del video, sin bola (la garra
    # va moviendose por todos lados; la bola se esconde mientras duran)
    # sacar: video nuevo del 2026-10-07 (Character_drawing_staff_for_game_...),
    # entero del reposo al quedarse quieto con el en la mano: f5-f184. El de
    # antes era magnus_sacar_baston, 1-123 (video f56-f178), garra "sacar".
    "sacar_baston":   {"desde": 1, "hasta": 180, "fps": 24.0, "bucle": False,
                       "job": "magnus_sacar_baston_v3", "sin_orbe": True, "garra": "sacar_v3"},
    # guardar empieza en el 17: los 16 primeros son el reposo casi quieto (0,7 s
    # de espera tras pulsar)
    "guardar_baston": {"desde": 17, "hasta": 93, "fps": 24.0, "bucle": False,
                       "job": "magnus_guardar_baston", "sin_orbe": True},  # video f1-f93
}

def andar_v2():
    """Tramos y paso del andar con el baston. Reposo, arranque y parada de
    magnus_andar_baston_v2; el ciclo, de BUCLE. Devuelve (anims, paso): anims
    con desde/hasta (y job y dx_fijo para el ciclo); paso con lo que baston.gd
    le pone a magnus.gd.
      - avance de cada fotograma = lo que se mueve el pie plantado (paso.py),
        limpio de los fotogramas en que la franja del suelo engana (un pie que
        se levanta: saltos de +4/+6 en medio de -7/-8);
      - el ciclo va desplazado OFF px para que su primer fotograma caiga donde
        el c_136 de v2 (son la misma imagen);
      - el arranque acaba en el fotograma de v2 cuyo siguiente mejor se
        parece a uno del ciclo, sin pasar de ARRANQUE_MAX (y se entra por ese);
      - la parada empieza en c_137 de v2 y llega al quieto mas parecido al
        reposo; desde el fotograma i del ciclo se entra por el de la parada
        mas parecido al que tocaria (el i+1 del ciclo).
    Las comparaciones van por silueta: lo que se nota al empalmar es el paso,
    no el dibujo de la tunica."""
    from scipy.ndimage import median_filter

    def limpio(nombre):
        m = json.loads((PROY / f"raw/master_mason/anim/baston/paso_medido_{nombre}.json").read_text())
        dx = np.array(m["dx"], float)
        med = median_filter(dx, size=7, mode="wrap" if nombre == BUCLE else "nearest")
        malo = np.abs(dx - med) > 1.5
        if nombre == BUCLE:
            # siempre andando: lo que no sea un avance normal (-5 o menos en
            # master) es la franja del suelo enganada al aterrizar un pie. Un 0
            # en la tabla dejaba el ciclo clavado en ese fotograma (con
            # avance 0 la distancia no llega nunca al siguiente).
            malo |= dx > -5
            i = np.arange(len(dx)); ok = ~malo
            dxc = np.interp(i, np.concatenate([i[ok] - len(dx), i[ok], i[ok] + len(dx)]),
                            np.tile(dx[ok], 3))
        else:
            dxc = np.where(malo, med, dx)
        return -dxc / 2                # px de hoja que avanza cada fotograma (c_k -> c_k+1)
    v2, vb = limpio("magnus_andar_baston_v2"), limpio(BUCLE)
    V = lambda k: max(0.0, float(v2[k - 1]))
    VB = lambda k: max(0.0, float(vb[k - 1]))
    s, L = CICLO
    cache = {}

    def P(k, job=None, off=0):
        if (k, job, off) not in cache:
            a = np.asarray(Image.fromarray(cargar(k, job)).reduce(2)).astype(np.float32)[..., 3] / 255
            cache[(k, job, off)] = np.roll(a, off, 1)
        return cache[(k, job, off)]
    # desplazamiento del bucle respecto a v2 (a media resolucion; en master, el doble)
    off2 = min(range(-30, 31), key=lambda o: float(np.abs(P(1, BUCLE, o) - P(136)).mean()))
    OFF = 2 * off2
    offr = min(range(-30, 31), key=lambda o: float(np.abs(P(REPOSO_BUCLE[0], REPOSO_JOB, o) - P(REPOSO[0])).mean()))
    OFF_R = 2 * offr
    print("reposo respirando desplazado", OFF_R, "px (master) para casar con el de v2")
    print("bucle desplazado", OFF, "px (master) para casar con c_136")
    C = lambda i: P(vuelta(s + (i % L)), BUCLE, off2)  # fotograma i del ciclo
    D = lambda a, b: float(np.abs(a - b).mean())
    paso = float(np.median([D(C(i), C(i + 1)) for i in range(L)]))

    # arranque: el mejor empalme sin alargarlo (ARRANQUE_MAX): se juega entero
    # (soltar a medias sigue hasta el ciclo). Son videos distintos y nunca casan
    # tan bien como dentro de uno: el de verdad bueno, c_135 -> c_192 (0,3
    # pasos), alarga el arranque a 3,8 s; con 1,25 el primero era c_080 y el
    # arranque duraba 2 s (y ese pone el pie claro donde iba el oscuro). Antes
    # se cogia el primero <= 1,8: con el ciclo de una zancada salia c_061 ->
    # c_190 (1,79), con el baston girando de golpe y sin la pisada del c_062;
    # el mejor hasta el c_070 es c_070 -> c_158 (1,39), como el de antes
    # (c_069 -> c_158, 1,78 con el ciclo viejo) un fotograma mas tarde.
    d_arr, entrada, kf = min(min((D(P(kf + 1), C(e)) / paso, e) for e in range(L)) + (kf,)
                             for kf in range(44, ARRANQUE_DESDE + ARRANQUE_MAX))
    print("arranque c_%03d-c_%03d, al ciclo por %d (salto %.2f pasos)" % (ARRANQUE_DESDE, kf, entrada, d_arr))
    cand = range(168, 193)
    p1 = min(cand, key=lambda k: D(P(k), P(REPOSO[0])))
    print("parada c_%03d-c_%03d (a %.2f pasos del reposo)" % (PARADA_DESDE, p1, D(P(p1), P(REPOSO[0])) / paso))
    dist, pose = [], []
    for i in range(L):
        r = min((D(P(PARADA_DESDE + j), C(i + 1)) / paso, j) for j in range(31))
        dist.append(round(r[0], 2))
        pose.append(r[1])
    # con 1,6 solo casaban 19 fotogramas del ciclo (hasta 2,6 s esperando a
    # poder parar); con 2,0, 38 y como mucho 1,3 s
    print("cierre del ciclo %.2f; entradas a la parada <= 2,0: %s" % (
        D(C(L - 1), C(L)) / paso, [i for i, x in enumerate(dist) if x <= 2.0]))
    arr = list(range(ARRANQUE_DESDE, kf + 1))
    par = list(range(PARADA_DESDE, p1 + 1))
    ciclo = [vuelta(s + i) for i in range(L)]
    # suavizado (media de 7, en circulo): la medida del pie va a saltos de
    # medio px y el cuerpo avanzaba a golpecitos de +-10 % de un fotograma al
    # siguiente ("va un poco a tirones"); la suma, lo que anda en una vuelta,
    # no cambia
    crudo = np.array([VB(k) for k in ciclo])
    avance_ciclo = [round(float(x), 3) for x in
                    np.convolve(np.concatenate([crudo[-3:], crudo, crudo[:3]]), np.ones(7) / 7, mode="valid")]
    recorrido = 0.0
    de_pie = 0
    for i, k in enumerate(arr):
        recorrido += V(k)
        if recorrido < 2.0:
            de_pie = i
    golpes = lambda tramo, lista: {str(i): ("a" if n % 2 == 0 else "b")
                                   for n, (i, k) in enumerate((i, k) for i, k in enumerate(tramo) if k in lista)}
    media = float(np.mean(avance_ciclo))

    def suave(v):                       # media de 5 sin salirse del tramo
        v = np.array(v, float)
        r = np.convolve(np.pad(v, 2, mode="edge"), np.ones(5) / 5, mode="valid")
        r[0], r[-1] = v[0], v[-1]       # empieza parado y acaba parado
        return [round(float(x), 2) for x in r]
    paso_juego = {
        "avance_andar": round(media, 3), "velocidad_andar": round(media * 30, 2),
        "avance_ciclo_andar": avance_ciclo, "ritmo_ciclo_andar": 30.0,
        "avance_arranque_andar": suave([V(k) * 30 for k in arr]),
        "corte_arranque_andar": len(arr) - 1, "entrada_andar": entrada,
        "arranque_andar_de_pie": de_pie,
        "velocidad_parada_andar": suave([V(k) * 30 for k in par]),
        "dist_parada_andar": dist, "pose_andar_a_parada": pose,
        "espera_parada_andar": L, "tolerancia_parada_andar": 2.0,
        "pisadas": golpes(ciclo, GOLPES_BUCLE),
        "golpes": {"arranque_andar": golpes(arr, GOLPES_VIDEO), "parada_andar": golpes(par, GOLPES_VIDEO)},
    }
    anims = {
        "andar":          {"desde": s, "hasta": s + L - 1, "frames": ciclo, "fps": 30.0, "bucle": True,
                           "job": BUCLE, "dx_fijo": OFF},
        "arranque_andar": {"desde": arr[0], "hasta": arr[-1], "fps": 30.0, "bucle": False},
        "parada_andar":   {"desde": par[0], "hasta": par[-1], "fps": 30.0, "bucle": False},
        "reposo":         {"desde": REPOSO_BUCLE[0], "hasta": REPOSO_BUCLE[1], "fps": 30.0, "bucle": True,
                           "job": REPOSO_JOB, "dx_fijo": OFF_R},
    }
    if not ARRANQUE_VIDEO:
        # del reposo al ENTRADA_FUNDIDO del ciclo, en el sitio (ver arriba); el
        # ultimo de la transicion ES ese del ciclo, y se sigue por el siguiente
        anims["arranque_andar"] = {"fundido": ENTRADA_FUNDIDO, "n": ARRANQUE_FUNDIDO,
                                   "fps": 30.0, "bucle": False}
        paso_juego.update({"corte_arranque_andar": ARRANQUE_FUNDIDO - 1,
                           "entrada_andar": (ENTRADA_FUNDIDO + 1) % L,
                           "arranque_andar_de_pie": ARRANQUE_FUNDIDO - 1})
        paso_juego["golpes"]["arranque_andar"] = {}
        print("arranque: transicion de %d fotogramas del reposo al %d del ciclo; se sigue por el %d"
              % (ARRANQUE_FUNDIDO, ENTRADA_FUNDIDO, (ENTRADA_FUNDIDO + 1) % L))
    return anims, paso_juego


def transicion(a, b, n):
    """n fotogramas de a a b (los dos incluidos, tal cual) moviendo pixeles: a
    llevado una fraccion t hacia b y b una (1 - t) hacia a por el flujo optico,
    mezclados (alfa premultiplicado) con t acelerando (CURVA_FUNDIDO). Para pasar entre dos poses
    casi quietas: el reposo y el paso del ciclo que mas se le parece."""
    import cv2

    def gris(x):
        x = x.astype(np.float32)
        al = x[..., 3:4] / 255
        return cv2.cvtColor((x[..., :3] * al + 30 * (1 - al)).astype(np.uint8), cv2.COLOR_RGB2GRAY)
    dis = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    fab = cv2.GaussianBlur(dis.calc(gris(a), gris(b), None), (0, 0), 3)    # a(x) ~ b(x + fab(x))
    fba = cv2.GaussianBlur(dis.calc(gris(b), gris(a), None), (0, 0), 3)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    out = []
    for j in range(n):
        t = (j / (n - 1)) ** CURVA_FUNDIDO
        at = cv2.remap(a, xx - t * fab[..., 0], yy - t * fab[..., 1], cv2.INTER_LINEAR, borderValue=0)
        bt = cv2.remap(b, xx - (1 - t) * fba[..., 0], yy - (1 - t) * fba[..., 1], cv2.INTER_LINEAR, borderValue=0)
        out.append(fundir(at, bt, t))
    out[0], out[-1] = a, b
    return out


def avance_en_hoja(nombre, bucle, sigue=False):
    """Lo que avanza el pie plantado de cada fotograma al siguiente, medido en
    la hoja que acaba de salir (media escala: lo que dibuja el juego), al
    octavo de px. Medido en el video a tamano completo y dividido entre dos,
    la tabla salia ~0,3 px por fotograma alta y en cada apoyo el pie patinaba
    hacia delante ~6 px. Los fotogramas en que la franja del suelo engana (un
    pie que aterriza: negativos o muy bajos) se rellenan de los vecinos, y
    luego media de 5. El ultimo fotograma de un tramo suelto no tiene
    siguiente y vale 0 (la parada acaba quieta); con sigue (el arranque, que
    sigue en el ciclo) vale lo del anterior: con el 0, la media de 5 bajaba
    los tres ultimos del arranque a 90, 68 y 46 px/s y el cuerpo se frenaba
    justo antes de entrar al ciclo a ~125."""
    hoja = np.array(Image.open(DESTINO / f"mano_{nombre}.png").convert("RGBA"))[..., 3].astype(np.float32) / 255
    n = _HOJAS[nombre]
    F = [hoja[(i // COLS) * 360:(i // COLS + 1) * 360, (i % COLS) * 292:(i % COLS + 1) * 292] for i in range(n)]
    suelo = int(np.median([np.where((f > 0.5).any(1))[0].max() for f in F]))
    xs = np.arange(292, dtype=float)

    def paso(a, b):
        A, B = a[suelo - 5:suelo + 1], b[suelo - 5:suelo + 1]
        return -min((float(np.abs(np.stack([np.interp(xs - d, xs, r, left=0, right=0) for r in A]) - B).sum()), d)
                    for d in np.arange(-8, 3.01, 0.125))[1]
    pares = range(n) if bucle else range(n - 1)
    v = np.array([paso(F[i], F[(i + 1) % n]) for i in pares] + ([] if bucle else [0.0]))
    if sigue:
        v[-1] = v[-2]
    from scipy.ndimage import median_filter
    med = median_filter(v, size=7, mode="wrap" if bucle else "nearest")
    malo = (np.abs(v - med) > 0.8) | (v < 0)
    i = np.arange(len(v)); ok = ~malo
    if bucle:
        v = np.interp(i, np.concatenate([i[ok] - len(v), i[ok], i[ok] + len(v)]), np.tile(v[ok], 3))
        v = np.convolve(np.concatenate([v[-2:], v, v[:2]]), np.ones(5) / 5, mode="valid")
    else:
        v = np.interp(i, i[ok], v[ok])
        v = np.convolve(np.pad(v, 2, mode="edge"), np.ones(5) / 5, mode="valid")
    return np.maximum(v, 0.0)


_HOJAS = {}


def avance_transicion(nombre, n):
    """Lo que avanza el cuerpo en cada fotograma de una transicion (transicion())
    para que los pies no patinen: los pies del primero y del ultimo, comparados
    en la hoja (franja del suelo, como en avance_en_hoja), dan cuanto se van
    atras en el dibujo; se reparte con el mismo t de la transicion. El
    ultimo vale lo del anterior (se sigue en el ciclo)."""
    hoja = np.array(Image.open(DESTINO / f"mano_{nombre}.png").convert("RGBA"))[..., 3].astype(np.float32) / 255
    F = [hoja[(i // COLS) * 360:(i // COLS + 1) * 360, (i % COLS) * 292:(i % COLS + 1) * 292] for i in (0, n - 1)]
    suelo = int(np.median([np.where((f > 0.5).any(1))[0].max() for f in F]))
    xs = np.arange(292, dtype=float)
    A, B = F[0][suelo - 5:suelo + 1], F[1][suelo - 5:suelo + 1]
    total = -min((float(np.abs(np.stack([np.interp(xs - d, xs, r, left=0, right=0) for r in A]) - B).sum()), d)
                 for d in np.arange(-20, 8.01, 0.125))[1]
    ts = np.array([(j / (n - 1)) ** CURVA_FUNDIDO for j in range(n)])
    v = np.maximum(np.diff(ts) * total, 0.0)
    print("transicion %s: los pies se van %.2f px atras en el dibujo" % (nombre, total))
    return np.append(v, v[-1])


def garra(a):
    """Centro del hueco de la garra (casilla master 584x720) o None."""
    rgb = a[..., :3].astype(int)
    op = a[..., 3] > 128
    barba = op & (rgb.min(2) > 175)
    if not barba.any():
        return None
    xb = int(np.where(barba.any(0))[0].max())
    zona = op.copy()
    zona[:, :xb + 8] = False
    ys = np.where(zona.any(1))[0]
    if len(ys) == 0:
        return None
    top = int(ys[0])
    trozo = zona[top:top + 70]
    yy, xx = np.where(trozo)
    return float(xx.mean()), float(top + 31)


def garra_patron(frames, ref, bucle=False):
    """Centro del hueco de la garra en cada fotograma, por patron: se recorta la
    garra del fotograma ref (reposo, donde garra() acierta), y en cada uno se
    busca donde encaja, girada +-12 grados, cerca de donde estaba en el
    anterior; al subpixel con una parabola sobre el maximo. Suavizado [1,2,1]
    (en bucle, dando la vuelta). Con garra() la bola bailaba 1-2 px de un
    fotograma a otro: cogia el borde de la barba y la punta mas alta."""
    import cv2
    fondo = np.array([60, 56, 54], np.float32)

    def plano(a):
        al = a[..., 3:4].astype(np.float32) / 255
        return (a[..., :3] * al + fondo * (1 - al)).astype(np.float32)

    cx, cy = garra(ref)
    R = 42
    x0, y0 = int(cx) - R, int(cy) - R
    tpl = plano(ref)[y0:y0 + 2 * R, x0:x0 + 2 * R]
    msk = (ref[y0:y0 + 2 * R, x0:x0 + 2 * R, 3] > 128).astype(np.float32)
    centro = (cx - x0, cy - y0)
    pts = []
    pos = (cx, cy)
    for a in frames:
        img = plano(a)
        mejor = None
        for ang in range(-12, 13, 2):
            M = cv2.getRotationMatrix2D(centro, ang, 1.0)
            t = cv2.warpAffine(tpl, M, (2 * R, 2 * R), borderValue=tuple(float(v) for v in fondo))
            m = cv2.warpAffine(msk, M, (2 * R, 2 * R))
            B = 30
            sx, sy = int(pos[0] - centro[0]) - B, int(pos[1] - centro[1]) - B
            zona = img[max(sy, 0):sy + 2 * R + 2 * B, max(sx, 0):sx + 2 * R + 2 * B]
            r = cv2.matchTemplate(zona, t, cv2.TM_CCORR_NORMED, mask=np.dstack([m] * 3))
            r = np.nan_to_num(r, nan=0, posinf=0, neginf=0)
            _, sc, _, (lx, ly) = cv2.minMaxLoc(r)
            if mejor is None or sc > mejor[0]:
                # subpixel: parabola en x y en y alrededor del maximo
                def sub(v0, v1, v2):
                    d = v0 - 2 * v1 + v2
                    return 0.0 if abs(d) < 1e-9 else 0.5 * (v0 - v2) / d
                fx = sub(r[ly, lx - 1], r[ly, lx], r[ly, lx + 1]) if 0 < lx < r.shape[1] - 1 else 0.0
                fy = sub(r[ly - 1, lx], r[ly, lx], r[ly + 1, lx]) if 0 < ly < r.shape[0] - 1 else 0.0
                mejor = (sc, (max(sx, 0) + lx + fx + centro[0], max(sy, 0) + ly + fy + centro[1]))
        pos = mejor[1]
        pts.append(pos)
    xs = np.array([p[0] for p in pts]); ys = np.array([p[1] for p in pts])
    k = np.array([1, 2, 1], float) / 4
    modo = "wrap" if bucle else "edge"
    xs = np.convolve(np.pad(xs, 1, mode=modo), k, mode="valid")
    ys = np.convolve(np.pad(ys, 1, mode=modo), k, mode="valid")
    return list(zip(xs, ys))


def garra_por_color(a, cerca=None):
    """Garra en cualquier postura (transiciones: el baston va por encima de la
    cabeza, en horizontal...): los brillos ocre-naranja de las raices (H 0.06-0.13,
    S > 0.5, V > 0.5) no salen en la capa ni en la cara. Se toma el grupo mas
    grande, o el mas cercano a la garra del fotograma anterior. None si apenas
    se ve (tapada por la cabeza o el cuerpo)."""
    from scipy import ndimage
    rgb = a[..., :3].astype(float) / 255
    op = a[..., 3] > 128
    mx, mn = rgb.max(2), rgb.min(2)
    v = mx
    s_ = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, ((g - b) / np.maximum(mx - mn, 1e-6)) % 6, 0) / 6
    m = op & (h > 0.06) & (h < 0.13) & (s_ > 0.5) & (v > 0.5) & (mx == r)
    m = ndimage.binary_dilation(m, iterations=6)
    lab, n = ndimage.label(m)
    if n == 0:
        return None
    grupos = []
    for i in range(1, n + 1):
        ys, xs = np.where(lab == i)
        if len(ys) < 120:
            continue
        grupos.append((len(ys), float(xs.mean()), float(ys.mean())))
    if not grupos:
        return None
    if cerca is not None:
        grupos.sort(key=lambda g_: (g_[1] - cerca[0]) ** 2 + (g_[2] - cerca[1]) ** 2)
        g_ = grupos[0]
        if (g_[1] - cerca[0]) ** 2 + (g_[2] - cerca[1]) ** 2 > 90 ** 2:
            return None
    else:
        g_ = max(grupos)
    # los brillos se juntan en el nudo, abajo: el hueco queda ~17 px mas arriba
    return g_[1], g_[2] - 17


def seguir_garra(frames, inicio, fin):
    """Garra en toda una transicion, con continuidad: arranca en la posicion
    conocida (la del reposo de la que sale), sigue al grupo mas cercano y los
    huecos (tapada) se rellenan interpolando; al final converge a la del
    reposo en el que acaba. Suavizado ligero."""
    pts = []
    prev = inicio
    for a in frames:
        g = garra_por_color(a, prev)
        pts.append(g)
        if g is not None:
            prev = g
    pts[0] = pts[0] or inicio
    pts[-1] = pts[-1] or fin
    xs = np.array([p[0] if p else np.nan for p in pts])
    ys = np.array([p[1] if p else np.nan for p in pts])
    idx = np.arange(len(pts))
    for v in (xs, ys):
        ok = ~np.isnan(v)
        v[~ok] = np.interp(idx[~ok], idx[ok], v[ok])
    k = np.array([1, 2, 1], float) / 4
    xs = np.convolve(np.pad(xs, 1, mode="edge"), k, mode="valid")
    ys = np.convolve(np.pad(ys, 1, mode="edge"), k, mode="valid")
    return list(zip(xs, ys))


def garra_espalda():
    """Donde queda la garra con el baston a la espalda en el reposo (casilla
    master), con la colocacion del juego: la del primer fotograma de reposo."""
    import math, json
    from celdas import PROY as _P
    seg = json.loads((_P / "assets/characters/baston/baston_seguimiento.json").read_text())
    x, y, giro = seg["reposo"][0][:3]
    # la bola esta 24 px (media escala) por encima del pivote, a lo largo del eje
    gx = x + 24 * math.sin(giro)
    gy = y - 24 * math.cos(giro)
    return (gx + 146) * 2, (gy + 180) * 2


# Los pies tienen que caer en el mismo sitio de la casilla en TODAS las
# animaciones de Magnus, o al pasar de una a otra pega un salto. El reposo
# normal (magnus_respirando c_01) los tiene con el borde izquierdo en x=285.
# Los videos del baston son de camara quieta y el personaje no da un paso al
# sacar o guardar, pero centrar.ps1 ancla al tronco y el brazo con el baston
# lo desplazaba: se ancla por los pies, fotograma a fotograma.
PIES_X = 285


def pies_izq(a):
    op = a[..., 3] > 128
    ys = np.where(op.any(1))[0]
    bot = ys.max()
    xs = np.where(op[bot - 20:bot + 1].any(0))[0]
    return int(np.split(xs, np.where(np.diff(xs) > 3)[0] + 1)[0][0])


def desplazar(a, dx):
    out = np.zeros_like(a)
    if dx >= 0:
        out[:, dx:] = a[:, :a.shape[1] - dx]
    else:
        out[:, :dx] = a[:, -dx:]
    return out


def desplazamientos(frames):
    """dx de cada fotograma para llevar los pies a PIES_X (mediana de 5: el
    borde del pie baila 1 px por el antialias)."""
    from scipy.ndimage import median_filter
    v = np.array([PIES_X - pies_izq(a) for a in frames], float)
    return [int(round(x)) for x in median_filter(v, size=5, mode="nearest")]


# Empalme de las transiciones con lo que el juego pone justo antes o despues.
# El baston a la espalda de los videos de Flow no es el sprite (baston.png):
# sale mas apagado y verdoso (Lab medio 39/2/21 frente a 36/7/24 del sprite) y
# en el ultimo de guardar queda 2,5 px (media escala) mas adelante y 1 grado
# menos inclinado; en el primero de sacar, 5 px y 4 grados. El cuerpo difiere
# como de un fotograma de respirar a otro. Al cambiar de golpe se notaba el
# salto. Los ultimos (o primeros) FUNDIDO fotogramas acaban en el fotograma
# exacto que sigue (o precede): el primero del juego normal es identico al
# ultimo de la transicion. Con el baston a la espalda va en dos tiempos para
# que no se vean dos garras: primero el color (el sprite puesto ENCIMA del
# baston del video, en su misma postura, medida fotograma a fotograma) y luego
# el sprite se asienta hasta su sitio de reposo. El sprite no se recolorea:
# casa con el baston en la mano del video de andar (Lab 41/9/25 en la garra);
# lo que se va de tono es solo el baston a la espalda de los videos de Flow.
#   "espalda": reposo normal (fotograma 0) con el baston a la espalda, tal cual
#              lo coloca baston.gd con baston_seguimiento.json
#   "mano":    reposo con el baston en la mano (fotograma 0)
FUNDIDO = 10
COLOR_HASTA = 0.6          # fraccion del fundido en la que se cambia el color
EMPALMES = {"sacar_baston": ("espalda", "mano"), "guardar_baston": ("mano", "espalda")}
_ESPALDA = {}


def _datos_espalda():
    if not _ESPALDA:
        from celdas import cargar as celdas
        from hoja_prueba import SPR, PIVOTE
        _ESPALDA["cuerpo"] = Image.fromarray(celdas()["reposo"]["celdas"][0])
        _ESPALDA["spr"] = SPR.convert("RGBa")
        _ESPALDA["pivote"] = PIVOTE
        _ESPALDA["pose"] = json.loads((DESTINO / "baston_seguimiento.json").read_text())["reposo"][0][:3]
    return _ESPALDA


def madera_espalda(dx=0.0, dy=0.0, dgiro=0.0):
    """Solo la madera a la espalda (RGBA, media escala, fondo transparente) en
    la postura del json mas (dx, dy) px y dgiro grados (giro de Godot)."""
    import math
    e = _datos_espalda()
    x, y, giro = e["pose"]
    x, y, giro = x + 146 + dx, y + 180 + dy, giro + math.radians(dgiro)   # a la esquina de la casilla
    c, s = math.cos(giro), math.sin(giro)
    # casilla -> textura: giro inverso alrededor del pivote (PIL pide la inversa)
    m = (c, s, e["spr"].width / 2 - (c * x + s * y), -s, c, e["pivote"] - (-s * x + c * y))
    return e["spr"].transform(e["cuerpo"].size, Image.AFFINE, m, resample=Image.BICUBIC).convert("RGBA")


def reposo_espalda(dx=0.0, dy=0.0, dgiro=0.0):
    """Fotograma 0 del reposo normal con la madera por detras del cuerpo (como
    el nodo Madera: pivote a 40 px de la punta)."""
    madera = madera_espalda(dx, dy, dgiro)
    madera.alpha_composite(_datos_espalda()["cuerpo"])
    return np.array(madera)


def postura_video(celda):
    """(dx, dy, dgiro) que lleva el sprite encima del baston a la espalda que
    trae el video en esa casilla: minimos cuadrados de la silueta por encima
    de los hombros y fuera del cuerpo, de grueso a fino."""
    from scipy import ndimage
    e = _datos_espalda()
    zona = ~ndimage.binary_dilation(np.array(e["cuerpo"])[..., 3] > 128, iterations=1)
    zona[100:] = False
    v = celda[..., 3] / 255.0 * zona
    err = lambda p: (((np.array(madera_espalda(*p))[..., 3] / 255.0) * zona - v) ** 2).sum()
    mejor = min(((dx, dy, dg) for dx in range(-2, 11) for dy in range(-5, 3) for dg in range(-3, 8)), key=err)
    for paso in (0.5, 0.25):
        mejor = min(((mejor[0] + i * paso, mejor[1] + j * paso, mejor[2] + k * paso * 2)
                     for i in (-1, 0, 1) for j in (-1, 0, 1) for k in (-1, 0, 1)), key=err)
    return mejor


def empalmar(p, destino, t):
    """Casilla p del video llevada hacia la del reposo (t de 0 a 1)."""
    t = t * t * (3 - 2 * t)
    if destino != "espalda":
        return fundir(p, EMPALMES_IMG[destino], t)
    pv = np.array(postura_video(p))
    tc = min(1.0, t / COLOR_HASTA)
    ts = max(0.0, (t - COLOR_HASTA) / (1 - COLOR_HASTA))
    ts = ts * ts * (3 - 2 * ts)
    return fundir(p, reposo_espalda(*(pv * (1 - ts))), tc * tc * (3 - 2 * tc))


EMPALMES_IMG = {}


def fundir(a, b, t):
    """Mezcla RGBA con alfa premultiplicado (sin halos oscuros en los bordes)."""
    a = a.astype(float); b = b.astype(float)
    pa, pb = a[..., :3] * a[..., 3:] / 255, b[..., :3] * b[..., 3:] / 255
    al = a[..., 3:] + (b[..., 3:] - a[..., 3:]) * t
    rgb = (pa + (pb - pa) * t) * 255 / np.maximum(al, 1e-6)
    return np.dstack([rgb, al]).clip(0, 255).round().astype(np.uint8)


def cargar(k, job=None):
    carpeta = ANIM / job / "04_limpios" if job else ORIGEN
    ruta = carpeta / f"c_{k:03d}.png"
    if not ruta.exists():                     # con menos de 100 fotogramas van con dos cifras
        ruta = carpeta / f"c_{k:02d}.png"
    return np.array(Image.open(ruta).convert("RGBA"))


if __name__ == "__main__":
    import sys
    ANDAR, PASO = andar_v2()
    ANIMS = {**ANDAR, **ANIMS}
    solo_andar = "andar" in sys.argv[1:]       # python mano.py andar: solo las cuatro del andar
    if solo_andar:
        ANIMS = {k: v for k, v in ANIMS.items() if k in ANDAR}
    GARRA_ANDAR = {}
    ref_garra = cargar(REPOSO[0])
    for nombre in ANDAR:
        d = ANDAR[nombre]
        if d.get("fundido") is not None:       # la transicion: mas abajo, con el reposo y el ciclo
            continue
        if d.get("job") == BUCLE:
            # el bucle entero, en orden, y luego el tramo: empezando el
            # seguimiento en el c_090 (baston inclinado, lejos de la pose del
            # patron) se perdia y la bola saltaba hasta 18 px
            todo = garra_patron([cargar(k, BUCLE) for k in range(1, N_BUCLE + 1)], ref_garra, bucle=True)
            GARRA_ANDAR[nombre] = [todo[k - 1] for k in d["frames"]]
            continue
        fr = [cargar(k, d.get("job")) for k in d.get("frames", range(d["desde"], d["hasta"] + 1))]
        GARRA_ANDAR[nombre] = garra_patron(fr, ref_garra, bucle=d["bucle"])
    DX_MANO = PIES_X - pies_izq(cargar(REPOSO[0]))      # los pies, anclados al reposo de v2
    print("andar con baston: pies movidos", DX_MANO, "px (master)")
    # lo que se ve justo al acabar de sacar (y justo antes de guardar): el
    # primer fotograma del reposo respirando, en su sitio
    DX_REPOSO = DX_MANO + ANDAR["reposo"]["dx_fijo"]
    REPOSO_0 = cargar(ANDAR["reposo"]["desde"], REPOSO_JOB)
    EMPALMES_IMG["mano"] = np.array(Image.fromarray(desplazar(REPOSO_0, DX_REPOSO))
                                    .resize((292, 360), Image.LANCZOS))
    G_REPOSO_0 = (GARRA_ANDAR["reposo"][0][0] + DX_REPOSO, GARRA_ANDAR["reposo"][0][1])
    TRANSICION = None
    if ANDAR["arranque_andar"].get("fundido") is not None:
        # arranque = del primer fotograma del reposo (en su sitio) al ENTRADA_FUNDIDO
        # del ciclo (en el suyo), moviendo pixeles; la bola, de la una a la otra
        d = ANDAR["arranque_andar"]
        e = d["fundido"]
        dx_c = DX_MANO + ANDAR["andar"]["dx_fijo"]
        TRANSICION = transicion(desplazar(REPOSO_0, DX_REPOSO),
                                desplazar(cargar(ANDAR["andar"]["frames"][e], BUCLE), dx_c), d["n"])
        g_e = (GARRA_ANDAR["andar"][e][0] + dx_c, GARRA_ANDAR["andar"][e][1])
        ts = [(j / (d["n"] - 1)) ** CURVA_FUNDIDO for j in range(d["n"])]
        GARRA_ANDAR["arranque_andar"] = [(G_REPOSO_0[0] + (g_e[0] - G_REPOSO_0[0]) * t,
                                          G_REPOSO_0[1] + (g_e[1] - G_REPOSO_0[1]) * t) for t in ts]
    info = {}
    for nombre, d in ANIMS.items():
        if d.get("fundido") is not None:
            ks = list(range(d["n"]))
            frames0 = TRANSICION
        else:
            ks = list(d.get("frames", range(d["desde"], d["hasta"] + 1)))
            frames0 = [cargar(k, d.get("job")) for k in ks]
        n = len(ks)
        filas = (n + COLS - 1) // COLS
        hoja = Image.new("RGBA", (292 * COLS, 360 * filas), (0, 0, 0, 0))
        orbe = []
        if d.get("fundido") is not None:       # ya en su sitio (y la bola tambien)
            dxs = [0] * n
        elif d.get("dx_fijo") is not None:     # el ciclo del bucle: un dx, el que casa con v2
            dxs = [DX_MANO + d["dx_fijo"]] * n
        elif d.get("job"):
            dxs = desplazamientos(frames0)
        else:                                  # andar con baston: un solo dx, el de su reposo
            dxs = [DX_MANO] * n
        afinada = PROY / f"raw/master_mason/anim/baston/garra_{d.get('garra', nombre.split('_')[0])}.json"
        if d.get("sin_orbe") and afinada.exists():
            # marcada a mano y afinada con patron (garra_patron.py); None = fuera de imagen
            crudo = json.loads(afinada.read_text())[d["desde"] - 1:d["hasta"]]   # medida desde el fotograma 1
            xs = np.array([e["x"] if e else np.nan for e in crudo]); ys = np.array([e["y"] if e else np.nan for e in crudo])
            for v in (xs, ys):                       # suavizado ligero dentro de cada tramo visible
                w = v.copy()
                for i in range(1, len(v) - 1):
                    if not np.isnan(v[i - 1:i + 2]).any():
                        w[i] = (v[i - 1] + 2 * v[i] + v[i + 1]) / 4
                v[:] = w
            xs = xs + np.array(dxs, float)
            # los ultimos 8 fotogramas llegan justo a donde la pone la animacion
            # siguiente (reposo a la espalda o en la mano): sin salto al acabar
            destino = garra_espalda() if nombre == "guardar_baston" else G_REPOSO_0
            for j in range(8):
                i = len(xs) - 8 + j
                t = (j + 1) / 8
                xs[i] += (destino[0] - xs[i]) * t
                ys[i] += (destino[1] - ys[i]) * t
            seguida = [None if np.isnan(x) else (x, y) for x, y in zip(xs, ys)]
        elif d.get("sin_orbe"):
            frames = [cargar(k, d["job"]) for k in ks]
            g_espalda, g_mano = garra_espalda(), G_REPOSO_0
            ini, fin = (g_espalda, g_mano) if nombre == "sacar_baston" else (g_mano, g_espalda)
            seguida = seguir_garra(frames, ini, fin)
        for i, k in enumerate(ks):
            a = frames0[i]
            g = seguida[i] if d.get("sin_orbe") else GARRA_ANDAR[nombre][i]
            if g is not None and not d.get("sin_orbe"):
                g = (g[0] + dxs[i], g[1])
            a = desplazar(a, dxs[i])
            # media escala y respecto al centro de la casilla (el sprite va centrado)
            orbe.append([round(float(g[0]) / 2 - 146, 2), round(float(g[1]) / 2 - 180, 2)] if g else None)
            peq = Image.fromarray(a).resize((292, 360), Image.LANCZOS)
            if nombre in EMPALMES:
                # fundido con el reposo de antes (primeros) y el de despues (ultimos)
                antes, despues = EMPALMES[nombre]
                t_ini = 1 - i / FUNDIDO if i < FUNDIDO else 0.0
                t_fin = (i - (n - 1 - FUNDIDO)) / FUNDIDO if i > n - 1 - FUNDIDO else 0.0
                p = np.array(peq)
                if t_ini > 0:
                    p = empalmar(p, antes, t_ini)
                if t_fin > 0:
                    p = empalmar(p, despues, t_fin)
                peq = Image.fromarray(p)
            hoja.paste(peq, ((i % COLS) * 292, (i // COLS) * 360))
        hoja.save(DESTINO / f"mano_{nombre}.png")
        _HOJAS[nombre] = n
        # Duracion de cada fotograma (SpriteFrames la admite por fotograma). Los
        # videos de IA tienen cadencia irregular: un paso grande, uno pequeno,
        # otro grande; se ve como tirones. Cada fotograma dura en proporcion a
        # lo que se mueve hasta el siguiente, respecto a la media de su entorno:
        # misma velocidad aparente, sin quitar ni inventar fotogramas.
        duraciones = [1.0] * n
        if d.get("job") and d.get("dx_fijo") is None:
            comp = [desplazar(f, dx)[..., :3] * (desplazar(f, dx)[..., 3:] / 255.0)
                    for f, dx in zip(frames0, dxs)]
            mov = np.array([np.abs(comp[i + 1] - comp[i]).mean() for i in range(n - 1)] + [0.0])
            mov[-1] = mov[-2]
            entorno = np.convolve(np.pad(mov, 3, mode="edge"), np.ones(7) / 7, mode="valid")
            rel = np.where(entorno > 0.4, mov / np.maximum(entorno, 1e-6), 1.0)
            duraciones = [round(float(np.clip(r, 0.6, 1.5)), 3) for r in rel]
        info[nombre] = {"hoja": f"res://assets/characters/baston/mano_{nombre}.png", "n": n,
                        "cols": COLS, "fps": d["fps"], "bucle": d["bucle"], "orbe": orbe,
                        "duraciones": duraciones}
        print(nombre, n, "fotogramas; sin bola en", sum(o is None for o in orbe))
    # el avance, medido en las hojas que acaban de salir (ver avance_en_hoja)
    PASO["avance_ciclo_andar"] = [round(float(x), 3) for x in avance_en_hoja("andar", True)]
    media = float(np.mean(PASO["avance_ciclo_andar"]))
    PASO["avance_andar"], PASO["velocidad_andar"] = round(media, 3), round(media * 30, 2)
    if ANDAR["arranque_andar"].get("fundido") is not None:
        arr_v = avance_transicion("arranque_andar", ANDAR["arranque_andar"]["n"]) * 30
    else:
        arr_v = avance_en_hoja("arranque_andar", False, sigue=True) * 30
        arr_v[0] = 0.0
    PASO["avance_arranque_andar"] = [round(float(x), 2) for x in arr_v]
    par_v = avance_en_hoja("parada_andar", False) * 30
    PASO["velocidad_parada_andar"] = [round(float(x), 2) for x in par_v]
    print("avance medido en la hoja: ciclo media %.3f px/fotograma" % media)
    info["paso"] = PASO
    # Lo que no sale de aqui se conserva tal cual: con "andar", las demas
    # animaciones de este script; siempre, las entradas de otros scripts (la
    # "giro" de giro_mano.py). Antes se reescribia el fichero entero y se perdia.
    viejo = json.loads((DESTINO / "mano.json").read_text()) if (DESTINO / "mano.json").exists() else {}
    propias = set(ANIMS) | {"paso", "entrada_andar"}
    info = {**{k: v for k, v in viejo.items()
               if k not in info and k != "entrada_andar" and (solo_andar or k not in propias)}, **info}
    (DESTINO / "mano.json").write_text(json.dumps(info, separators=(",", ":")), encoding="utf-8")
