"""Parche cosido en la espalda, a la altura del cuello, por donde el baston se
mete bajo la tunica (solo se ve de espaldas, en los giros). Misma tela
facetada de la tunica. Los dos tonos salen de la propia capa
(medianas de los marrones de la espalda en el fotograma de espaldas del giro).
  python funda.py"""
import numpy as np
from PIL import Image
from celdas import cargar, PROY

H, W = 18, 16          # parche del cuello por donde entra el baston bajo la tunica

if __name__ == "__main__":
    c = cargar()["giro"]["celdas"][18].astype(float)
    a = c[..., 3] > 128
    rgb = c[..., :3]
    marron = a & (rgb[..., 0] > rgb[..., 2] + 15) & (rgb.mean(2) > 50) & (rgb.mean(2) < 150)
    tonos = rgb[marron]
    lum = tonos.mean(1)
    claro = np.median(tonos[lum > np.percentile(lum, 60)], axis=0)
    oscuro = np.median(tonos[lum < np.percentile(lum, 40)], axis=0)
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    # dos facetas partidas en diagonal, como los triangulos de la capa
    corte = (xx - W / 2) * 3.0 + (yy - H * 0.55)
    col = np.where((corte > 0)[..., None], claro, oscuro)
    col = col * (1.0 + 0.04 * np.sin(yy * 0.7 + xx))[..., None]       # algo de textura
    ancho = np.where(yy < 3, W / 2, W / 2 - 0.5 - 2.0 * (yy / H))
    dist = np.abs(xx - (W - 1) / 2)
    alfa = np.clip(ancho - dist + 0.5, 0, 1) * np.clip((H - 1 - yy) / 2, 0, 1)
    costura = (np.abs(ancho - dist) < 1.1) | (yy < 2) | (yy > H - 3)
    col = np.where(costura[..., None], col * 0.62, col)
    col = col * (1.06 - 0.16 * (dist / (W / 2)))[..., None]
    out = np.dstack([np.clip(col, 0, 255), alfa * 255]).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(PROY / "assets/characters/baston/funda.png")
    print("claro", claro.round(), "oscuro", oscuro.round())
