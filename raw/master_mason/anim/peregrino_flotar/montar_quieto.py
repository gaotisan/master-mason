"""FLOTAR QUIETO (2026-10-15): mete el video de flotar en la pose detras de las
casillas que ya hay (sin rehacer las demas, que llevan su tono, sus piernas y
el giro retocado) y lo deja como ellas:

  1. casillas: los 192 fotogramas, sin el croma y encajados sobre la pose de
     flotar (montar_flotar.registrar), detras de las de 04_limpios (casillas.json)
  2. tono de la tunica: la ganancia que lo lleva a la media de flotar_bajar 1-11
     (que ya esta igualada: es donde empalma)
  3. el pico de la capucha (recortar_capucha.py: el usuario, "el problema es el
     pico del gorro, tendrias que cortarlo e igualarlo a otros")
  4. piernas al color de las del salto (igualar_piernas.py; lo de antes de este
     paso se guarda en 04_limpios_sin_piernas, como las demas, por si se repite)

Luego `python montar_flotar.py hoja`.
  python montar_quieto.py
"""
import glob, json, os, sys
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
sys.path.insert(0, AQUI)
sys.path.insert(0, ANIM)
import montar_flotar as M      # noqa: E402
import igualar_tono as T       # noqa: E402
import recortar_capucha as RC  # noqa: E402
# el igualar_piernas de aqui con otro nombre: dentro importa el de
# peregrino_secuencia_frontal, que se llama igual
import importlib.util as _iu   # noqa: E402
_spec = _iu.spec_from_file_location('flotar_piernas', os.path.join(AQUI, 'igualar_piernas.py'))
IP = _iu.module_from_spec(_spec)
_spec.loader.exec_module(IP)

NOMBRE = 'flotar_quieto'


def main():
    ruta_cas = os.path.join(AQUI, 'casillas.json')
    cas = json.load(open(ruta_cas))
    if NOMBRE in cas['anims']:
        c0 = cas['anims'][NOMBRE][0]
    else:
        c0 = max(c1 for _, c1 in cas['anims'].values()) + 1
    video, desde, hasta, fps, bucle = M.ANIMS[NOMBRE]
    ruta = glob.glob(os.path.join(M.FUENTES, 'flotar_%s_*.mp4' % video))
    assert len(ruta) == 1, ruta
    ruta = ruta[0]
    # 1. casillas
    for i, f in M.fotogramas(ruta, 0, 0):
        s, dx, dy = M.registrar(M.sin_croma(f))
    ims = []
    for i, f in M.fotogramas(ruta, desde, hasta):
        rgba = M.sin_croma(f)
        im = Image.fromarray(rgba).resize((round(M.VW * s), round(M.VH * s)), Image.LANCZOS)
        lien = Image.new('RGBA', (M.CASILLA_W, M.CASILLA_H), (0, 0, 0, 0))
        lien.alpha_composite(im, (dx, dy + M.ARRIBA))
        ims.append(np.asarray(lien))
    c1 = c0 + len(ims) - 1
    # 2. tono: a la media de flotar_bajar 1-11 (ya igualada)
    ref = T.media([T.leer(os.path.join(M.LIMPIOS, 'c_%03d.png' % k)) for k in range(1, 12)])
    muestra = [im.astype(float) / 255 for im in ims[::8]]
    g = np.ones(3)
    for _ in range(6):
        g = g * ref / T.media([T.aplicar(im, g) for im in muestra])
    print('tono: ganancia (%.3f, %.3f, %.3f)' % tuple(g))
    ims = [(T.aplicar(im.astype(float) / 255, g) * 255).round().astype(np.uint8) for im in ims]
    # 3. el pico de la capucha
    pose = RC.pose_en_casilla()
    quitado = 0
    for j, im in enumerate(ims):
        out, iou, ang, ddx, ddy, q = RC.recortar(im, pose)
        ims[j] = out
        quitado += q
    print('capucha: %d px quitados en %d fotogramas' % (quitado, len(ims)))
    # 4. piernas: lo de antes, a 04_limpios_sin_piernas (de ahi sale igualar_piernas)
    os.makedirs(IP.ORIGINAL, exist_ok=True)
    for j, im in enumerate(ims):
        Image.fromarray(im).save(os.path.join(IP.ORIGINAL, 'c_%03d.png' % (c0 + j)))
    destino = IP.ip.estadisticas(IP.muestras([os.path.join(IP.SALTO, 'c_%02d.png' % (f + 1)) for f in IP.REFERENCIA]))
    fuente = IP.ip.estadisticas(IP.muestras([os.path.join(IP.ORIGINAL, 'c_%03d.png' % c) for c in range(c0, c1 + 1, 2)]))
    print('piernas: L %.0f -> %.0f, a* %+.1f -> %+.1f, b* %+.1f -> %+.1f' % (
        fuente[0][0], destino[0][0], fuente[0][1] - 128, destino[0][1] - 128, fuente[0][2] - 128, destino[0][2] - 128))
    for j, im in enumerate(ims):
        b = IP.transferir(im, IP.ip.mascara(im), fuente, destino)
        Image.fromarray(b).save(os.path.join(M.LIMPIOS, 'c_%03d.png' % (c0 + j)))
    cas['anims'][NOMBRE] = [c0, c1]
    cas.setdefault('registros', {})[video] = [s, dx, dy]
    json.dump(cas, open(ruta_cas, 'w'), indent=1)
    print('%s: video %s %d-%d -> c_%03d-c_%03d' % (NOMBRE, video, desde, hasta, c0, c1))


if __name__ == '__main__':
    main()
