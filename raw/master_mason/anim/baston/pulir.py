"""Quita los restos de croma que deja fondo.ps1 en los videos del baston:
  - bolsas de croma en sombra (verde azulado oscuro, p. ej. entre la barba y
    el baston al guardarlo): grupos grandes -> transparentes
  - tinte verde en bordes y puntos sueltos: se le quita el verde de mas
    (g = max(r, b)), sin tocar la forma
Guarda los originales en <job>/_antes_de_pulir/ la primera vez.
  python pulir.py magnus_guardar_baston [magnus_sacar_baston ...]
  python pulir.py --oscuras magnus_sacar_baston_v3
    (solo bolsas oscuras, todo por debajo de OSCURA: en ese video la capucha
    es gris verdosa clara, ~(125,140,143), y se la comia; la bolsa entre la
    barba y el baston es croma en sombra, por debajo de 100)"""
import shutil, sys
import numpy as np
from PIL import Image
from scipy import ndimage
from celdas import PROY

BOLSA_MIN = 150     # px: un grupo mayor es croma, no detalle
OSCURA = 100        # con --oscuras: tope del canal mas alto de la bolsa


def pulir(a, oscuras=False):
    a = a.astype(int)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    op = al > 128
    teal = op & (g - r > 14) & (g >= b - 6) & (g < 170)
    if oscuras:
        teal &= np.maximum(np.maximum(r, g), b) < OSCURA
    lab, n = ndimage.label(teal)
    bolsas = np.zeros_like(teal)
    if n:
        tam = ndimage.sum(teal, lab, range(1, n + 1))
        grandes = np.where(tam >= BOLSA_MIN)[0] + 1
        bolsas = np.isin(lab, grandes)
        bolsas = ndimage.binary_dilation(bolsas, iterations=2) & (g > r)   # su orla tambien
    a[..., 3] = np.where(bolsas, 0, al)
    # despill: cualquier pixel con mas verde que rojo y azul
    tope = np.maximum(r, b)
    a[..., 1] = np.where((g > tope) & (a[..., 3] > 0), tope, g)
    return a.astype(np.uint8), int(bolsas.sum())


def bolsas_verdes(job):
    """Bolsas de croma encerradas que fondo.ps1 no alcanza desde el borde y que
    pulir() ya ha dejado grises (el despill les quita el verde): p. ej. la cuna
    entre la manga y el baston bajo la mano en el andar con baston. Se buscan en
    la copia con fondo (_con_fondo): lo que alli era claramente verde (el verde
    pasa en 35 al rojo y al azul) y aqui sigue opaco, solo si tiene grosor (una
    apertura de 3x3 quita la orla de 1-2 px del contorno, que es antialias y se
    queda). Lo de la bolsa pasa a transparente y su borde, a media opacidad.
      python pulir.py --bolsas-verdes magnus_andar_baston_bucle"""
    carpeta = PROY / "raw/master_mason/anim" / job / "04_limpios"
    origen = carpeta.parent / "_con_fondo" / "04_limpios"
    total = []
    for f in sorted(carpeta.glob("c_*.png")):
        a = np.array(Image.open(f).convert("RGBA"))
        o = np.array(Image.open(origen / f.name).convert("RGB")).astype(int)
        verde = (o[..., 1] - np.maximum(o[..., 0], o[..., 2]) > 35) & (a[..., 3] > 0)
        bolsa = ndimage.binary_opening(verde, structure=np.ones((3, 3)))
        bolsa = ndimage.binary_dilation(bolsa, iterations=1) & verde
        al = a[..., 3].astype(float)
        al[bolsa] = 0
        borde = ndimage.binary_dilation(bolsa, iterations=1) & ~bolsa & (al > 0)
        al[borde] *= 0.5
        a[..., 3] = al.round().astype(np.uint8)
        Image.fromarray(a, "RGBA").save(f)
        total.append(int(bolsa.sum()))
    print(job, "px de bolsa verde quitados (cada 8):", total[::8])


if __name__ == "__main__" and "--bolsas-verdes" in sys.argv:
    for job in [j for j in sys.argv[1:] if not j.startswith("--")]:
        bolsas_verdes(job)
    sys.exit()


if __name__ == "__main__":
    oscuras = "--oscuras" in sys.argv
    for job in [j for j in sys.argv[1:] if not j.startswith("--")]:
        carpeta = PROY / "raw/master_mason/anim" / job / "04_limpios"
        copia = carpeta.parent / "_antes_de_pulir"
        if not copia.exists():
            shutil.copytree(carpeta, copia)
        total = 0
        for f in sorted(copia.glob("c_*.png")):
            a, n = pulir(np.array(Image.open(f).convert("RGBA")), oscuras)
            Image.fromarray(a, "RGBA").save(carpeta / f.name)
            total += n
        print(job, "bolsas quitadas:", total, "px")
