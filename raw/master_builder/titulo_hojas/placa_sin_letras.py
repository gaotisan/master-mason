"""Placa del panel del titulo SIN las letras, para que en la salida las letras
se fundan con ella.

Antes el shader las "aplanaba" contra el panel con cuentas de brillo, y no
salia limpio: el relieve se quedaba como un fantasma oliva en negativo y el
rectangulo del efecto se veia (dentro el panel perdia las grietas).

Aqui se hace de verdad:
  1. Mascara de las letras con su relieve y su sombra: lo que se aparta del
     panel de alrededor (mediana grande), solo dentro del bloque del titulo.
  2. Luz de baja frecuencia: media ponderada del panel de alrededor, que no
     guarda forma de letra (con inpaint quedaban sombras con forma de texto).
  3. Encima, el grano fino del panel, tomado de alrededor de las letras,
     para que no quede una mancha lisa con forma de letra (las grietas no:
     trasplantarlas dejaba parches).

Sale el recorte del bloque del titulo (title_placa_sin_letras.png) y su
rectangulo, que va en PLACA_RECT de title_hojas_viento.gdshader.

Uso: python placa_sin_letras.py   (despues de componer.py)
"""
import os

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
FONDO = os.path.join(PROYECTO, "assets", "intro", "title_background_hojas.png")
SALIDA = os.path.join(PROYECTO, "assets", "intro", "title_placa_sin_letras.png")

# Bloque del titulo (px de la imagen) y margen de fundido alrededor.
# Hasta x 1740: a la derecha estan la vela y la telarana, que no se tocan.
X0, Y0, X1, Y1 = 1000, 540, 1740, 1060
SEMILLA = 3


def mascara_letras(gris):
    """Letras, su bisel y su sombra: lo que se aparta del panel de alrededor."""
    fondo = cv2.medianBlur(gris, 61)
    dif = np.abs(gris.astype(np.float32) - fondo.astype(np.float32))
    m = (cv2.GaussianBlur(dif, (0, 0), 2) > 16).astype(np.uint8)
    # Solo trazos grandes: fuera las grietas sueltas, que son del panel.
    n, lab, st, _ = cv2.connectedComponentsWithStats(m)
    keep = np.zeros_like(m)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] > 900:
            keep[lab == i] = 1
    keep = cv2.morphologyEx(keep, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    # Hacia abajo y a la derecha, un poco mas: ahi cae la sombra de las letras.
    keep = cv2.dilate(keep, np.ones((15, 15), np.uint8))
    sombra = np.zeros_like(keep)
    sombra[10:, 8:] = keep[:-10, :-8]
    return np.maximum(keep, sombra)


def main():
    im = cv2.imread(FONDO)
    blq = im[Y0:Y1, X0:X1].copy()
    gris = cv2.cvtColor(blq, cv2.COLOR_BGR2GRAY)
    m = mascara_letras(gris)
    # Fuera del margen del bloque no se toca nada.
    m[:20], m[-20:], m[:, :20], m[:, -20:] = 0, 0, 0, 0

    # 1. Luz de baja frecuencia: media ponderada del panel de alrededor (sin
    # las letras), que no guarda ninguna forma de letra. Con inpaint quedaban
    # sombras borrosas con la forma del texto.
    f = blq.astype(np.float32)
    libre = (1 - m).astype(np.float32)
    base = cv2.GaussianBlur(f * libre[..., None], (0, 0), 28) / np.maximum(cv2.GaussianBlur(libre, (0, 0), 28), 1e-3)[..., None]

    # 2. Detalle: solo el grano fino del panel (sigma 1.5), llevado dentro de
    # las letras desde sitios cercanos que no sean letra ni moldura. El grano es
    # homogeneo y no deja costuras; trasplantar tambien las grietas dejaba
    # parches rectangulares. Al fundirse, el cristal ya se esta oscureciendo y
    # las grietas que faltan no se ven.
    alta = f - cv2.GaussianBlur(f, (0, 0), 1.5)
    prohibido = m.astype(bool).copy()
    prohibido[:60], prohibido[-40:] = True, True
    rng = np.random.default_rng(SEMILLA)
    h, w = m.shape
    det = np.zeros_like(alta)
    falta = m.astype(bool).copy()
    for _ in range(60):
        dy, dx = rng.integers(-140, 141, 2)
        src = np.roll(np.roll(alta, dy, 0), dx, 1)
        src_ok = ~np.roll(np.roll(prohibido, dy, 0), dx, 1)
        usa = falta & src_ok
        det[usa] = src[usa]
        falta &= ~usa
        if not falta.any():
            break
    placa = base + det * m[..., None]

    # 3. Fundido suave entre placa y original en el borde de la mascara.
    suave = cv2.GaussianBlur(m.astype(np.float32), (0, 0), 3)
    out = placa * suave[..., None] + f * (1 - suave[..., None])
    cv2.imwrite(SALIDA, np.clip(np.round(out), 0, 255).astype(np.uint8))
    cv2.imwrite(os.path.join(AQUI, "salida", "placa_mascara.png"), m * 255)
    print("escrito", SALIDA, "rect", (X0, Y0, X1, Y1))


if __name__ == "__main__":
    main()
