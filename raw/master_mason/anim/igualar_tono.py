"""Tono ESTANDAR de la tunica de Magnus para todas sus animaciones (2026-10-09).

El usuario: "necesito un tono estandar" para la tunica en todas las animaciones;
la luz de cada escena se retoca luego encima. Cada video de IA trae la tunica
con su propio tono, y al empalmar animaciones se nota el cambio (el giro por
delante, magnus_giro_frente, venia con un 3,5-4,7 % menos de rojo y algo mas de
verde: "mas apagado"; al volver a andar cambiaba de color).

El estandar es el del REPOSO (magnus_respirando, los tres primeros sprites):
la animacion que mas se ve, la referencia que ya se uso al igualar el giro de
poses y el agachado, y con la que casi todo el resto ya va a menos del 2 %.

Lo que hace, por job: una ganancia por canal COMUN a todo el job, que lleva la
media de lo calido de la tunica, medida en los fotogramas de empalme que se le
digan, a la del reposo (o a la de otro job ya igualado, si el empalme es con
el). Se aplica en proporcion a la saturacion (solo lo calido, sin borde entre
paneles), asi que capucha, barba, pies, piel y madera del baston casi no se
tocan. Parte siempre de una copia sin igualar (<job>/_sin_igualar_tono/), asi
que se puede repetir. Copiado de magnus_andar_agachado/igualar_color.py.

  python igualar_tono.py <job> <fotogramas> [<job_ref> <fotogramas_ref>]
     fotogramas: "1,2,84,85" o "1-5" (numeros c_NNN de 04_limpios)
  sin referencia: el reposo estandar.
"""
import glob, os, shutil, sys
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))


def tunica(rgb):
    mx = rgb.max(-1); mn = rgb.min(-1); s = (mx - mn) / np.maximum(mx, 1e-6)
    return (rgb[..., 0] > rgb[..., 1]) & (rgb[..., 1] >= rgb[..., 2] - 0.02) & (s > 0.12) & (mx > 0.15) & (mx < 0.85)


def leer(f):
    return np.asarray(Image.open(f).convert('RGBA')).astype(float) / 255


def media(ims):
    px = [im[..., :3][(im[..., 3] > 0.8) & tunica(im[..., :3])] for im in ims]
    return np.concatenate(px).mean(0)


def aplicar(im, g):
    rgb = im[..., :3]; mx = rgb.max(-1); mn = rgb.min(-1); s = (mx - mn) / np.maximum(mx, 1e-6)
    peso = np.clip((s - 0.08) / 0.12, 0, 1) * (rgb[..., 0] > rgb[..., 2])
    out = im.copy(); out[..., :3] = np.clip(rgb * (1 + peso[..., None] * (g - 1)), 0, 1)
    return out


def rango(txt):
    out = []
    for parte in txt.split(','):
        if '-' in parte:
            a, b = parte.split('-'); out += list(range(int(a), int(b) + 1))
        else:
            out.append(int(parte))
    return out


def fichero(carpeta, k):
    for patron in ('c_%03d.png', 'c_%02d.png'):
        f = os.path.join(carpeta, patron % k)
        if os.path.exists(f):
            return f
    raise FileNotFoundError(os.path.join(carpeta, 'c_%d' % k))


def tono_reposo():
    return media([leer(fichero(os.path.join(AQUI, 'magnus_respirando', '04_limpios'), k)) for k in (1, 2, 3)])


def igualar(job, fotos, ref):
    carpeta = os.path.join(AQUI, job, '04_limpios')
    copia = os.path.join(AQUI, job, '_sin_igualar_tono')
    if not os.path.isdir(copia):
        shutil.copytree(carpeta, copia)
    muestra = [leer(fichero(copia, k)) for k in fotos]
    antes = media(muestra)
    g = np.ones(3)
    for _ in range(5):   # el peso no es 1 en toda la tunica: se afina hasta caer en la media
        g = g * ref / media([aplicar(im, g) for im in muestra])
    for f in sorted(glob.glob(os.path.join(copia, '*.png'))):
        Image.fromarray((aplicar(leer(f), g) * 255).round().astype(np.uint8)).save(
            os.path.join(carpeta, os.path.basename(f)))
    despues = media([leer(fichero(carpeta, k)) for k in fotos])
    print('%s: ganancia (%.3f, %.3f, %.3f); empalme antes %s, ahora %s, objetivo %s' % (
        job, *g, tuple(int(v) for v in (antes * 255).round()), tuple(int(v) for v in (despues * 255).round()),
        tuple(int(v) for v in (ref * 255).round())))
    return g


if __name__ == '__main__':
    job, fotos = sys.argv[1], rango(sys.argv[2])
    if len(sys.argv) > 4:
        ref = media([leer(fichero(os.path.join(AQUI, sys.argv[3], '04_limpios'), k)) for k in rango(sys.argv[4])])
    else:
        ref = tono_reposo()
    igualar(job, fotos, ref)
