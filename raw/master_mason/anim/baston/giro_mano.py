"""Giro con el baston EN LA MANO, por delante (hacia la camara), del video
Master_builder_walking_animation..._20261008163432 (job
magnus_andar_giro_baston, c_NNN = fotograma NNN del video).

El video gira de perfil derecho a casi perfil izquierdo (c_116 -> c_148): se
queda a unos 10-15 grados del perfil, con el baston ya cambiado de mano. Lo
que falta se completa con el principio del mismo giro espejado: c_123 -> c_116
volteados (el c_123 espejado es el que mas se parece al c_148, y el c_116
espejado es el reposo con baston mirando a la izquierda, que es como acaba
cualquier giro en magnus.gd: el ultimo fotograma es el de siempre volteado).

Posicion: centrar.ps1 centra cada fotograma por el tronco, y al girar la
cabeza pasa de un lado del eje al otro: el giro se iba 80 px a la derecha. Se
coloca cada fotograma donde estaba en el video (OFF: el desplazamiento de la
casilla limpia dentro del fotograma del video, por correlacion de columnas) y
los pies del c_116 donde el reposo con baston del juego (PIES_X). El remate
espejado casa con el c_148 a 6 px: se reparten a lo largo del giro.

La garra: c_116-c_128 y el remate, por patron (mano.garra_patron); de frente
(c_129-c_148) el baston cambia de mano y el patron se pierde: marcas a mano
sobre rejilla (MARCAS), interpoladas.
  python giro_mano.py   -> mano_giro.png y la entrada "giro" de mano.json"""
import json
import numpy as np
from PIL import Image
from celdas import PROY
import mano

JOB = "magnus_andar_giro_baston"
IDA = list(range(116, 149))             # c_116 .. c_148
VUELTA = list(range(123, 115, -1))      # c_123 .. c_116 espejados
PIES_X = 285
FPS = 24.0
OFF = {116: 388, 117: 388, 118: 390, 119: 390, 120: 392, 121: 390, 122: 388, 123: 388, 124: 386,
       125: 382, 126: 378, 127: 374, 128: 368, 129: 360, 130: 348, 131: 342, 132: 336, 133: 338,
       134: 338, 135: 338, 136: 338, 137: 336, 138: 332, 139: 330, 140: 320, 141: 312, 142: 310,
       143: 308, 144: 308, 145: 308, 146: 308, 147: 310, 148: 310}
EMPALME = -6                            # px que se le quitan al c_148 para casar con el remate
# centro del hueco de la garra, en la casilla limpia sin desplazar (indice de IDA: x, y)
MARCAS = {14: (385, 100), 16: (372, 105), 18: (275, 140), 20: (262, 110), 22: (228, 105),
          24: (200, 100), 26: (190, 100), 28: (192, 100), 30: (193, 100), 32: (190, 100)}
PATRON_HASTA = 12                       # IDA[0..12] por patron
# El final del video (c_148) y el primero del remate (c_123 espejado) no casan
# en la tunica: el video la acaba mas clara y con otras facetas (diferencia
# 7,3 frente a 1,5-3,5 entre fotogramas seguidos) y se veia el salto. Dos
# arreglos:
#   - COLOR: el tono medio de la tunica (Lab) de cada fotograma se lleva al del
#     reposo con baston (mano_reposo, el que se ve antes y despues del giro);
#   - FUNDIDO_UNION: los ultimos fotogramas del video se funden con su pareja
#     espejada (c_148-j con c_123+j espejado, que es el mismo momento del giro
#     visto del otro lado), de 0 a casi 1: la tunica cambia de dibujo en ese
#     tramo en vez de en un fotograma.
FUNDIDO_UNION = 6


def cargar(k):
    return np.array(Image.open(PROY / "raw/master_mason/anim" / JOB / "04_limpios" / f"c_{k:03d}.png").convert("RGBA"))


def pies_izq(a):
    op = a[..., 3] > 128
    bot = np.where(op.any(1))[0].max()
    xs = np.where(op[bot - 20:bot + 1].any(0))[0]
    return int(np.split(xs, np.where(np.diff(xs) > 3)[0] + 1)[0][0])


def desplazar(a, s):
    s = int(round(s))
    o = np.zeros_like(a)
    if s >= 0:
        o[:, s:] = a[:, :a.shape[1] - s]
    else:
        o[:, :s] = a[:, -s:]
    return o


def lab(c):
    import cv2
    return cv2.cvtColor(np.ascontiguousarray(c[..., :3]), cv2.COLOR_RGB2LAB).astype(float)


def tunica(c):
    """Pixeles de la tunica (marrones: a de Lab > 134) opacos."""
    return (c[..., 3] > 250) & (lab(c)[..., 1] > 134)


def igualar_color(c, objetivo):
    """Lleva el tono medio de la tunica de c al objetivo (L, a, b): un
    desplazamiento en Lab para todo el personaje (la barba y la capucha,
    grises, apenas se mueven en a y b)."""
    import cv2
    m = tunica(c)
    if m.sum() < 200:
        return c
    L = lab(c)
    d = np.array(objetivo) - L[m].mean(0)
    L = np.clip(L + d, 0, 255).astype(np.uint8)
    out = c.copy()
    out[..., :3] = cv2.cvtColor(L, cv2.COLOR_LAB2RGB)
    return out


if __name__ == "__main__":
    reposo = np.array(Image.open(mano.DESTINO / "mano_reposo.png").convert("RGBA"))[:360, :292]
    reposo = np.array(Image.fromarray(reposo).resize((584, 720), Image.LANCZOS))
    OBJ = lab(reposo)[tunica(reposo)].mean(0)
    print("tunica del reposo (Lab):", OBJ.round(1))
    dx = PIES_X - pies_izq(cargar(IDA[0]))
    ida = [cargar(k) for k in IDA]
    vuelta = [cargar(k) for k in VUELTA]
    n_ida = len(IDA)
    s_ida = [dx + OFF[k] - OFF[IDA[0]] + EMPALME * i / (n_ida - 1) for i, k in enumerate(IDA)]
    s_vuelta = [dx + OFF[k] - OFF[IDA[0]] for k in VUELTA]
    # garra: patron al principio y en el remate; marcas a mano de frente
    g_pat = mano.garra_patron(ida[:PATRON_HASTA + 1], ida[0])
    g_v = mano.garra_patron(vuelta[::-1], ida[0])[::-1]
    claves = {i: g_pat[i] for i in range(PATRON_HASTA + 1)}
    claves.update(MARCAS)
    ks = sorted(claves)
    gx = np.interp(range(n_ida), ks, [claves[k][0] for k in ks])
    gy = np.interp(range(n_ida), ks, [claves[k][1] for k in ks])
    celdas, garras = [], []
    for i, a in enumerate(ida):
        celdas.append(igualar_color(desplazar(a, s_ida[i]), OBJ))
        garras.append((gx[i] + round(s_ida[i]), gy[i]))
    for j, a in enumerate(vuelta):
        celdas.append(igualar_color(desplazar(a, s_vuelta[j])[:, ::-1], OBJ))
        garras.append((a.shape[1] - 1 - (g_v[j][0] + round(s_vuelta[j])), g_v[j][1]))
    # la union: los ultimos FUNDIDO_UNION del video, fundidos con su pareja espejada
    pareja = [VUELTA[0] + j for j in range(FUNDIDO_UNION)]          # c_123, c_124, ...
    pc = [cargar(k) for k in pareja]
    pg = mano.garra_patron(pc, ida[0])
    for j in range(FUNDIDO_UNION):
        i = n_ida - 1 - j                                       # c_148, c_147, ...
        w = (FUNDIDO_UNION - j) / (FUNDIDO_UNION + 1)            # casi 1 en la union
        s = dx + OFF.get(pareja[j], OFF[IDA[0]]) - OFF[IDA[0]]
        b = igualar_color(desplazar(pc[j], s)[:, ::-1], OBJ)
        a = celdas[i].astype(float)
        bf = b.astype(float)
        # mezcla con alfa premultiplicado
        al = a[..., 3:] / 255 * (1 - w) + bf[..., 3:] / 255 * w
        rgb = (a[..., :3] * a[..., 3:] / 255 * (1 - w) + bf[..., :3] * bf[..., 3:] / 255 * w) / np.maximum(al, 1e-6)
        celdas[i] = np.dstack([np.clip(rgb, 0, 255), al * 255]).astype(np.uint8)
        gb = (a.shape[1] - 1 - (pg[j][0] + round(s)), pg[j][1])
        garras[i] = (garras[i][0] * (1 - w) + gb[0] * w, garras[i][1] * (1 - w) + gb[1] * w)
    n = len(celdas)
    filas = (n + mano.COLS - 1) // mano.COLS
    hoja = Image.new("RGBA", (292 * mano.COLS, 360 * filas), (0, 0, 0, 0))
    orbe = []
    for i, (c, g) in enumerate(zip(celdas, garras)):
        hoja.paste(Image.fromarray(c).resize((292, 360), Image.LANCZOS), ((i % mano.COLS) * 292, (i // mano.COLS) * 360))
        orbe.append([round(float(g[0]) / 2 - 146, 2), round(float(g[1]) / 2 - 180, 2)])
    hoja.save(mano.DESTINO / "mano_giro.png")
    # duracion de cada fotograma, como en mano.py: en proporcion a lo que se mueve
    comp = [c[..., :3] * (c[..., 3:] / 255.0) for c in celdas]
    mov = np.array([np.abs(comp[i + 1] - comp[i]).mean() for i in range(n - 1)] + [0.0])
    mov[-1] = mov[-2]
    entorno = np.convolve(np.pad(mov, 3, mode="edge"), np.ones(7) / 7, mode="valid")
    rel = np.where(entorno > 0.4, mov / np.maximum(entorno, 1e-6), 1.0)
    dur = [round(float(np.clip(r, 0.6, 1.5)), 3) for r in rel]
    info = json.loads((mano.DESTINO / "mano.json").read_text())
    info["giro"] = {"hoja": "res://assets/characters/baston/mano_giro.png", "n": n, "cols": mano.COLS,
                    "fps": FPS, "bucle": False, "orbe": orbe, "duraciones": dur}
    (mano.DESTINO / "mano.json").write_text(json.dumps(info, separators=(",", ":")), encoding="utf-8")
    print("giro con baston:", n, "fotogramas, dx", dx, "->", mano.DESTINO / "mano_giro.png")
