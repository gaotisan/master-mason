"""Piernas y pies de los videos de flotar del color de las del salto (2026-10-12).

El usuario, tras probarlo: "cuando salta y va bajando flotando, en ese cambio de
direccion de arriba a abajo los pies/piernas se vuelven como muy verdosas; un
cambio de color demasiado grande, muy brusco". Medido: las piernas del salto de
parado (lo que se ve subiendo) son pardo-grisaceas, RGB ~(88, 73, 64), verde
-3 sobre la media de rojo y azul; las de la bajada (video aterrizar) y las del
giro, verde oliva y mas oscuras, ~(70, 65, 52), verde +3 a +7 (el croma les deja
verde y la IA las pinto asi). El cambio cae justo en el apogeo.

Lo mismo que magnus_secuencia_frontal/igualar_piernas.py (de ahi la mascara y
la transferencia): color en Lab (media y desviacion) de las piernas de cada
video a las del salto de parado en el aire (sus fotogramas 18-37), con las
estadisticas de todo el video (asi no parpadea). El tono entero; la luz casi
entera (PESO_L).

Va despues de igualar_tono.py y antes de retocar_giro.py y de hoja:
    python montar_flotar.py casillas
    python ../igualar_tono.py magnus_flotar "105-117"
    python igualar_piernas.py
    python retocar_giro.py
    python montar_flotar.py hoja
La primera vez guarda 04_limpios en 04_limpios_sin_piernas/ y sale siempre de
ahi (se puede repetir); tras otro `casillas`, borrar esa carpeta.
"""
import os
import sys
import json
import shutil

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
sys.path.insert(0, os.path.join(ANIM, 'magnus_secuencia_frontal'))
import igualar_piernas as ip   # noqa: E402  (mascara, estadisticas, transferir)

LIMPIOS = os.path.join(AQUI, '04_limpios')
ORIGINAL = os.path.join(AQUI, '04_limpios_sin_piernas')
SALTO = os.path.join(ANIM, 'magnus_salto_parado', '04_limpios')
REFERENCIA = range(18, 38)     # fotogramas del salto de parado en el aire
ip.PESO_L = 0.85


def transferir(a, m, fuente, destino):
    """La de magnus_secuencia_frontal, pero con la luz media del salto tambien
    cuando es mas clara: alli la referencia contaba pies mas claros y subirla
    volvia piel las piernas; aqui la referencia son las mismas piernas en el
    aire, y sin subirla la bajada seguia 8 niveles mas oscura que el salto."""
    (mu_s, sd_s), (mu_t, sd_t) = fuente, destino
    b = a.copy()
    X = ip.lab(a[m][:, :3])
    Y = (X - mu_s) * (sd_t / sd_s) + mu_t
    Y[:, 0] = X[:, 0] * (1 - ip.PESO_L) + Y[:, 0] * ip.PESO_L
    b[m, :3] = ip.rgb(Y)
    return b


def leer(ruta):
    return np.asarray(Image.open(ruta).convert('RGBA'))


def muestras(rutas):
    px = []
    for r in rutas:
        a = leer(r)
        px.append(a[ip.mascara(a) & (a[..., 3] > 200)][:, :3])
    return np.concatenate(px)


def main():
    if not os.path.isdir(ORIGINAL):
        shutil.copytree(LIMPIOS, ORIGINAL)
    destino = ip.estadisticas(muestras([os.path.join(SALTO, 'c_%02d.png' % (f + 1)) for f in REFERENCIA]))
    print('salto parado: L %.0f +- %.0f, a* %+.1f, b* %+.1f' % (
        destino[0][0], destino[1][0], destino[0][1] - 128, destino[0][2] - 128))
    casillas = json.load(open(os.path.join(AQUI, 'casillas.json')))['anims']
    # por video: sus casillas (las de cada video, con sus estadisticas)
    videos = {}
    import montar_flotar as mf
    for nombre, (c0, c1) in casillas.items():
        videos.setdefault(mf.ANIMS[nombre][0], []).extend(range(c0, c1 + 1))
    for video, cs in videos.items():
        rutas = [os.path.join(ORIGINAL, 'c_%03d.png' % c) for c in cs]
        fuente = ip.estadisticas(muestras(rutas[::2]))
        print('%-10s: L %.0f +- %.0f, a* %+.1f, b* %+.1f (%d fotogramas)' % (
            video, fuente[0][0], fuente[1][0], fuente[0][1] - 128, fuente[0][2] - 128, len(cs)))
        for c, r in zip(cs, rutas):
            a = leer(r)
            b = transferir(a, ip.mascara(a), fuente, destino)
            Image.fromarray(b).save(os.path.join(LIMPIOS, 'c_%03d.png' % c))


if __name__ == '__main__':
    main()
