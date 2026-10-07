"""Atlas de las hojas sueltas del titulo (las que se lleva cada racha).

Sale del atlas de la hojarasca (assets/world/hojarasca/hojas.png, la escena
siguiente), que no se toca:
  - a media resolucion, reducido con Lanczos: en el titulo las hojas miden
    40-60 px y reducir 64x128 al vuelo, sin mipmaps, dejaba dientes y rayas
    punteadas cuando la hoja va casi de canto;
  - cada hoja acercada al brillo medio (las marrones oscuras se leian como
    palitos contra la pared clara);
  - con el tono igualado, canal a canal, al de las hojas iluminadas de los
    arbustos del fondo, conservando su luz (las del atlas tiraban a verdoso al
    lado de las del fondo).

Uso: python hojas_sueltas.py   (despues de componer.py, que hace la mascara)
"""
import os

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
ATLAS = os.path.join(PROYECTO, "assets", "world", "hojarasca", "hojas.png")
FONDO = os.path.join(PROYECTO, "assets", "intro", "title_background_hojas.png")
MASCARA = os.path.join(PROYECTO, "assets", "intro", "title_hojas_mascara.png")
SALIDA = os.path.join(PROYECTO, "assets", "intro", "title_hojas_sueltas.png")


def main():
    atlas = cv2.imread(ATLAS, cv2.IMREAD_UNCHANGED).astype(np.float32) / 255.0
    fondo = cv2.imread(FONDO).astype(np.float32) / 255.0
    mascara = cv2.imread(MASCARA, 0).astype(np.float32) / 255.0
    mascara = cv2.resize(mascara, (fondo.shape[1], fondo.shape[0]))

    # Hojas iluminadas del fondo: donde hay follaje y le da la luz de lleno (en
    # la mascara hay mucha hoja en sombra; esas no son la referencia).
    lum_f = cv2.cvtColor(fondo, cv2.COLOR_BGR2GRAY)
    sel = (mascara > 0.6) & (lum_f > np.percentile(lum_f[mascara > 0.6], 93))
    ref = np.median(fondo[sel], axis=0)

    # Lo mismo en el atlas: la parte con luz de las hojas, sin el borde.
    a = atlas[..., 3]
    lum_a = cv2.cvtColor(atlas[..., :3], cv2.COLOR_BGR2GRAY)
    sel_a = (a > 0.95) & (lum_a > np.percentile(lum_a[a > 0.95], 50))
    org = np.median(atlas[..., :3][sel_a], axis=0)

    # Del fondo se toma el tono (la proporcion entre canales), no la luz: la
    # hoja que vuela va en el aire y le da de lleno, como a las mas claras.
    gan = ref / np.maximum(org, 1e-3)
    lumw = np.array([0.11, 0.59, 0.3])  # BGR
    gan = gan * np.dot(lumw, org) / np.dot(lumw, org * gan)
    print("color fondo (BGR)", np.round(ref * 255), "atlas", np.round(org * 255), "ganancia", np.round(gan, 3))

    # Las hojas del atlas van de marron oscuro a dorado claro: en el suelo de la
    # hojarasca queda bien, pero en el aire, contra la pared clara, las oscuras
    # se leian como palitos. Cada hoja se acerca al brillo medio (sus manchas y
    # su nervio se quedan).
    cw, ch = atlas.shape[1] // 8, atlas.shape[0] // 4
    medias = []
    for f in range(4):
        for c in range(8):
            celda = (slice(f * ch, (f + 1) * ch), slice(c * cw, (c + 1) * cw))
            m = a[celda] > 0.95
            medias.append(lum_a[celda][m].mean())
    objetivo = float(np.median(medias))
    gan_celda = np.ones_like(a)
    for i, med in enumerate(medias):
        f, c = divmod(i, 8)
        gan_celda[f * ch:(f + 1) * ch, c * cw:(c + 1) * cw] = np.clip(objetivo / med, 0.9, 1.45)

    # Ganancia en premultiplicado, para que el borde no saque halo.
    rgb = atlas[..., :3] * a[..., None]
    rgb = np.clip(rgb * gan[None, None, :] * gan_celda[..., None], 0, 1)
    pre = np.dstack([rgb, a])
    h, w = pre.shape[:2]
    pre = cv2.resize(pre, (w // 2, h // 2), interpolation=cv2.INTER_AREA)
    a2 = np.clip(pre[..., 3], 0, 1)
    rgb2 = np.where(a2[..., None] > 1e-4, pre[..., :3] / np.maximum(a2[..., None], 1e-4), 0)
    out = np.dstack([np.clip(rgb2, 0, 1), a2])
    cv2.imwrite(SALIDA, np.round(out * 255).astype(np.uint8))
    print("escrito", SALIDA, out.shape[1], "x", out.shape[0])


if __name__ == "__main__":
    main()
