"""Color ESTANDAR de la capucha de Magnus (2026-10-09), como igualar_tono.py hace con
lo calido de la tunica.

El usuario: al guardar el baston de frente, al acabar en el reposo sin baston la
capucha es "bastante mas azul". Medido (gris azulado de la capucha, media):
  perfil (magnus_respirando, el estandar)   RGB (121, 131, 135)  tono 199  sat 0,11  luz 0,53
  de frente con baston (secuencia)          RGB (131, 135, 141)  tono 218  sat 0,07  luz 0,55
  de frente sin baston (secuencia_sin)      RGB (108, 122, 128)  tono 198  sat 0,16  luz 0,50
  sacar / guardar (Veo)                     de gris a algo azulada y mas oscura al final
Cada video pinta la capucha a su manera; los grises de la tunica, la barba y lo
demas casan. El usuario eligio llevarlas todas a la del perfil.

Que se toca: la FRANJA de la capucha (de su punta al 27 % del alto de la figura,
apagandose hasta el 32 %: debajo estan los parches grises de la tunica, que no
se tocan) y en ella lo gris azulado (tono 165-250, algo de color). La barba cae
dentro y sus sombras son gris azuladas: por eso el color se iguala en Lab con
media y desviacion de los dos ejes de color (lo casi neutro, como la barba,
apenas se mueve) y la luz solo se desplaza (sin comprimir: la barba no se
oscurece). Las medidas, con lo que es capucha sin lo muy claro (la barba).
Medir cada video en su reposo DE FRENTE y aplicar ese ajuste a todo el video: de
espaldas la capucha va mas en sombra y, medidas juntas, la de frente quedaba
corta (con y sin baston seguian a 3 de distancia).
    import igualar_capucha as IC
    fuente = IC.medir([im, ...]); destino = IC.medir(IC.estandar())
    im2 = IC.aplicar(im, fuente, destino)
"""
import glob, os
import numpy as np, cv2
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
BANDA, BANDA_FIN = 0.27, 0.32


def _rgba(im):
    a = np.asarray(im.convert('RGBA')).astype(np.float32) / 255
    return np.ascontiguousarray(a[..., :3]), a[..., 3]


def _hsv(rgb):
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)      # H en grados (float32)
    return hsv[..., 0], hsv[..., 1], hsv[..., 2]


def franja(rgb, al):
    """Peso por fila: 1 de la punta de la capucha al 27 % del alto, 0 desde el 32 %."""
    h, s, v = _hsv(rgb)
    op = al > 0.5
    azul = op & (h > 170) & (h < 245) & (s > 0.04) & (v > 0.15) & (v < 0.85)
    filas = np.nonzero(azul.sum(1) >= 15)[0]
    ys = np.nonzero(op.any(1))[0]
    if len(filas) == 0 or len(ys) == 0:
        return np.zeros(rgb.shape[0], np.float32)
    top, pie = filas.min(), ys.max()
    y = (np.arange(rgb.shape[0]) - top) / max(pie - top, 1)
    return np.clip((BANDA_FIN - y) / (BANDA_FIN - BANDA), 0, 1) * (y > -0.03)


def peso(rgb, al):
    """0..1: cuanto se iguala (gris azulado dentro de la franja de la capucha)."""
    h, s, v = _hsv(rgb)
    tono = np.clip(1 - (np.abs(h - 207) - 30) / 15, 0, 1)
    sat = np.clip((s - 0.015) / 0.025, 0, 1) * np.clip((0.5 - s) / 0.1, 0, 1)
    luz = np.clip((v - 0.08) / 0.07, 0, 1)
    return tono * sat * luz * franja(rgb, al)[:, None] * (al > 0.02)


def medir(ims):
    """Media y desviacion en Lab de lo que es claramente capucha."""
    px = []
    for im in ims:
        rgb, al = _rgba(im)
        h, s, v = _hsv(rgb)
        m = (peso(rgb, al) > 0.5) & (al > 0.9) & (v < 0.7)
        px.append(cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB)[m])
    px = np.concatenate(px)
    return px.mean(0), px.std(0)


def aplicar(im, fuente, destino):
    rgb, al = _rgba(im)
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB)
    (mf, sf), (md, sd) = fuente, destino
    t = lab.copy()
    t[..., 0] = lab[..., 0] + (md[0] - mf[0])                                  # la luz, solo desplazada
    t[..., 1:] = md[1:] + (lab[..., 1:] - mf[1:]) * (sd[1:] / np.maximum(sf[1:], 1e-3))
    w = peso(rgb, al)[..., None]
    nuevo = cv2.cvtColor((lab + w * (t - lab)).astype(np.float32), cv2.COLOR_LAB2RGB)
    out = np.dstack([np.clip(nuevo, 0, 1), al])
    return Image.fromarray((out * 255).round().astype(np.uint8), 'RGBA')


def estandar():
    """Los tres primeros sprites del reposo de perfil (como igualar_tono.py)."""
    fs = sorted(glob.glob(os.path.join(AQUI, 'magnus_respirando', '04_limpios', '*.png')))[:3]
    return [Image.open(f) for f in fs]
