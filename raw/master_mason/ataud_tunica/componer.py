"""Tunica del peregrino sobre la mesa del ataud.

Saca la tunica del croma (tunica_chroma.jpg), la escala y la coloca sobre el
extremo derecho de la mesa del fondo del ataud, y la iguala al cuadro: color
apagado, niebla, la textura cuarteada del fondo, la luz de las velas y una
sombra de contacto. Sale un PNG con alfa (tunica + sombra) recortado a su caja
y la posicion de su esquina en el fondo, para un Sprite2D con centered=false.

    python componer.py            -> assets/intro/tunica_mesa.png + preview
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

AQUI = os.path.dirname(os.path.realpath(__file__))
PROY = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
FONDO = os.path.join(PROY, "assets", "intro", "sarcophagus_base_16_9.png")
SALIDA = os.path.join(PROY, "assets", "intro", "tunica_mesa.png")
PREVIEW = os.path.join(AQUI, "preview")

# --- colocacion -------------------------------------------------------------
ESCALA = 0.36            # px del croma -> px del fondo
# Punto del croma que va a un punto del fondo: el pliegue donde la tela cae
# por el borde de la mesa.
ANCLA_CROMA = (1600, 800)
ANCLA_FONDO = (1645, 1005)

# --- igualado -----------------------------------------------------------------
SATURACION = 0.50        # cuanto color propio conserva
NIEBLA_ARRIBA = 0.12     # mezcla con el fondo desenfocado en lo alto
NIEBLA_ABAJO = 0.30      # y en el suelo
TEXTURA = 1.0            # cuarteado del fondo encima de la tela
NEGRO = 0.10             # los negros del fondo nunca son negros
# solo el resplandor pintado en el fondo; las PointLight2D del juego suman
# encima igual que sobre el fondo
VELAS = [((706, 710), 520), ((930, 675), 480)]
SOMBRA = 0.45
CONTACTO = 0.35          # sombra pegada donde la tela toca mesa y suelo
MESA_Y = 1005            # altura del tablero: lo que cuelga por debajo, en sombra
VELA_DETRAS = ((1535, 800), 230)   # contraluz suave en el borde de arriba
CONTRALUZ = 0.14
CAPUCHA = 0.80           # cuanto conserva la capucha de su luz


def cargar_croma():
    im = np.asarray(Image.open(os.path.join(AQUI, "tunica_chroma.jpg"))
                    .convert("RGB")).astype(np.float32)
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    verde = g - np.maximum(r, b)
    a = 1.0 - np.clip((verde - 18.0) / (45.0 - 18.0), 0.0, 1.0)
    # quitar motas sueltas del croma, sin tocar los flecos finos
    lab, n = ndi.label(a > 0.05)
    if n > 1:
        tam = ndi.sum(np.ones_like(a), lab, range(1, n + 1))
        a = a * np.isin(lab, 1 + np.nonzero(tam >= 400)[0])
    # sin derrame verde
    im[..., 1] = np.minimum(g, np.maximum(r, b) * 1.02 + 4)
    return im / 255.0, a


def main():
    fondo = np.asarray(Image.open(FONDO).convert("RGB")).astype(np.float32) / 255.0
    H, W, _ = fondo.shape
    col, a = cargar_croma()

    ys, xs = np.nonzero(a > 0.01)
    y0, y1, x0, x1 = ys.min() - 4, ys.max() + 5, xs.min() - 4, xs.max() + 5
    col, a = col[y0:y1, x0:x1], a[y0:y1, x0:x1]
    ancla = (ANCLA_CROMA[0] - x0, ANCLA_CROMA[1] - y0)

    h, w = a.shape
    nw, nh = int(round(w * ESCALA)), int(round(h * ESCALA))
    rgba = np.dstack([col * a[..., None], a])  # premultiplicado para escalar
    img = Image.fromarray((rgba * 255).astype(np.uint8), "RGBA")
    chans = [np.asarray(c.resize((nw, nh), Image.LANCZOS)).astype(np.float32) / 255
             for c in img.split()]
    a = np.clip(chans[3], 0, 1)
    col = np.dstack(chans[:3]) / np.maximum(a, 1e-4)[..., None]
    col = np.clip(col, 0, 1)

    ox = int(round(ANCLA_FONDO[0] - ancla[0] * ESCALA))
    oy = int(round(ANCLA_FONDO[1] - ancla[1] * ESCALA))
    # margen para la sombra
    M = 40
    X0, Y0 = max(ox - M, 0), max(oy - M, 0)
    X1, Y1 = min(ox + nw + M, W), min(oy + nh + M, H)
    cw, ch = X1 - X0, Y1 - Y0
    A = np.zeros((ch, cw), np.float32)
    C = np.zeros((ch, cw, 3), np.float32)
    A[oy - Y0:oy - Y0 + nh, ox - X0:ox - X0 + nw] = a
    C[oy - Y0:oy - Y0 + nh, ox - X0:ox - X0 + nw] = col
    bg = fondo[Y0:Y1, X0:X1]

    # la capucha gris es lo mas claro y plano: se apaga aparte
    gris = ((C.max(2) - C.min(2)) < 0.09) & (C.mean(2) > 0.3)
    capucha = ndi.gaussian_filter(gris.astype(np.float32), 3) * A

    # 1) color: menos saturado, valores y tinte de la zona
    lum = C @ np.array([0.299, 0.587, 0.114], np.float32)
    C = lum[..., None] + (C - lum[..., None]) * SATURACION
    m = A > 0.5
    bgl = bg @ np.array([0.299, 0.587, 0.114], np.float32)
    zona = ndi.binary_dilation(m, iterations=30)
    # la tela algo mas oscura que la niebla que la rodea, sin estirar contraste
    t_mean = lum[m].mean()
    b_mean = bgl[zona].mean()
    lum2 = C @ np.array([0.299, 0.587, 0.114], np.float32)
    nueva = (lum2 - t_mean) * 0.85 + b_mean * 0.68
    C = C * (nueva / np.maximum(lum2, 1e-3))[..., None]
    tinte = bg[zona].mean(0)
    tinte = tinte / tinte.mean()
    C = C * (0.55 + 0.45 * tinte)
    C = NEGRO + (1 - NEGRO) * np.clip(C, 0, 1)
    C = C * (1 - capucha[..., None] * (1 - CAPUCHA * np.array([1.0, 0.96, 0.9], np.float32)))

    # 2) luz de las velas (las de la izquierda tocan la cara que mira a ellas)
    yy, xx = np.mgrid[Y0:Y1, X0:X1].astype(np.float32)
    luz = np.zeros_like(A)
    for (vx, vy), rad in VELAS:
        d = np.hypot(xx - vx, (yy - vy) * 1.2)
        luz += np.clip(1 - d / (rad * 2.2), 0, 1) ** 2
    luz = np.clip(luz, 0, 1)
    calido = np.array([1.0, 0.78, 0.52], np.float32)
    C = C * (0.80 + 0.35 * luz[..., None] * calido)
    # mas oscuro abajo: el suelo y la tela que cuelga reciben menos
    alto = np.clip((yy - oy) / nh, 0, 1)
    C = C * (1.0 - 0.22 * alto[..., None] ** 1.5)

    # lo que cuelga por debajo del tablero queda a la sombra de la mesa
    bajo = np.clip((yy - MESA_Y) / 120.0, 0, 1)
    C = C * (1.0 - 0.15 * bajo[..., None])
    # contraluz: la vela de detras dora un poco el canto de arriba
    (vx, vy), rad = VELA_DETRAS
    canto = np.clip(A - ndi.shift(A, (7, 0), order=1), 0, 1)
    canto = ndi.gaussian_filter(canto, 2.0)
    cerca = np.clip(1 - np.hypot(xx - vx, yy - vy) / rad, 0, 1)
    C = C + (canto * cerca * CONTRALUZ)[..., None] * calido

    # 3) niebla: se mezcla con el fondo desenfocado, mas en el suelo
    bgb = ndi.gaussian_filter(bg, (25, 25, 0))
    f = NIEBLA_ARRIBA + (NIEBLA_ABAJO - NIEBLA_ARRIBA) * alto
    C = C * (1 - f[..., None]) + bgb * f[..., None]

    # balance de color igual al del fondo (malva): sin esto la tela, mas
    # amarilla, se lee oliva al lado
    mt = C[m].mean(0)
    mb = bg[zona].mean(0)
    C = C * ((mb / mb.mean()) / (mt / mt.mean()))

    # 4) cuarteado del fondo por encima, para que comparta el papel
    # recortado: el grano y las grietas si, los cantos fuertes de la mesa no
    hp = bg - ndi.gaussian_filter(bg, (2.5, 2.5, 0))
    hp = np.clip(hp, -0.035, 0.035)
    C = C + hp * TEXTURA
    C = np.clip(C, 0, 1)

    # 5) sombra de contacto: solo sobre las superficies, por debajo de la tela
    # (nunca un halo por encima contra la pared del fondo)
    s = ndi.gaussian_filter(ndi.shift(A, (10, 6), order=1), 7)
    debajo = ndi.gaussian_filter(np.maximum.accumulate(A, axis=0), 3)
    s = np.clip(s * debajo * SOMBRA, 0, SOMBRA)
    pegada = ndi.gaussian_filter(ndi.shift(A, (3, 2), order=1), 2.5) * debajo
    s = np.maximum(s, np.clip(pegada * CONTACTO, 0, CONTACTO))
    # union: tunica encima de su sombra
    a_out = A + s * (1 - A)
    c_out = (C * A[..., None]) / np.maximum(a_out, 1e-4)[..., None]
    a_out = np.clip(a_out, 0, 1)

    # canto un pelin blando, como el dibujo del fondo
    a_out = ndi.gaussian_filter(a_out, 0.5)
    out = np.dstack([np.clip(c_out, 0, 1), a_out])
    Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA").save(SALIDA)
    print("tunica", SALIDA, "pos", (X0, Y0), "tam", (cw, ch))

    # previews
    os.makedirs(PREVIEW, exist_ok=True)
    comp = fondo.copy()
    reg = comp[Y0:Y1, X0:X1]
    comp[Y0:Y1, X0:X1] = reg * (1 - a_out[..., None]) + c_out * a_out[..., None]
    Image.fromarray((comp * 255).astype(np.uint8)).save(os.path.join(PREVIEW, "completo.png"))
    Image.fromarray((comp[700:1450, 900:2100] * 255).astype(np.uint8)).save(
        os.path.join(PREVIEW, "detalle.png"))
    return X0, Y0


if __name__ == "__main__":
    main()
