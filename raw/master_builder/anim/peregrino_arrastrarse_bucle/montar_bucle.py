"""Monta el BUCLE DEL ARRASTRE (2026-10-15; ver raiz_bucle.py) para el juego.

  - Tono: el del arrastre viejo (peregrino_tumbarse/04_acciones c075-c123, que ya
    lleva el estandar de la tunica), medido en la tunica de todo el bucle.
  - Restos de croma (quitar_verde, como montar_accion.py).
  - 04_acciones/c_001..c_060 = f133..f192 (el bucle) y la tabla del juego en
    accion.json y en assets/characters/peregrino/acciones_perfil.json:
      arrastre_entrada  c075-c096 del arrastre viejo (de tumbado, arranca la brazada)
      arrastrarse_bucle f133-f192 de este video (bucle: tras el f192, el f133)
      arrastre_salida   c097-c123 del arrastre viejo (termina la brazada y se tumba)
    El f192 calca al c096 (raiz_bucle.py), asi que entrada -> bucle y bucle ->
    salida son, al pixel, los empalmes del propio video viejo.
  - SALIDAS: fotogramas del bucle que calcan al f192 (desplazados): soltando la
    direccion se pasa ahi a la salida, sin esperar a acabar la vuelta. Por
    cada uno, lo que avanza el nodo hasta el c097 (px de juego).
  python montar_bucle.py
"""
import json, os, shutil, sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
sys.path.insert(0, os.path.join(ANIM, 'peregrino_giro_frente'))
import espejo as E                      # noqa: E402
tono = E.tono
JUEGO = os.path.abspath(os.path.join(ANIM, '..', '..', '..', 'assets', 'characters', 'peregrino', 'acciones_perfil.json'))
VIEJO = os.path.join(ANIM, 'peregrino_tumbarse', '04_acciones')
FPS = 24.0
UMBRAL_SALIDA = 1.5          # pasos normales del bucle: lo que puede saltar al salir


def leer(carpeta, k):
    return np.asarray(Image.open(os.path.join(carpeta, 'c_%03d.png' % k)).convert('RGBA'))


def pm(x):
    x = x.astype(np.float32)
    return np.dstack([x[..., :3] * x[..., 3:] / 255, x[..., 3:]])


def main():
    rz = json.load(open(os.path.join(AQUI, 'raiz.json')))
    CW, CH = rz['casilla']
    RY = rz['raiz_fila']
    raiz = np.array(rz['raiz'], float)          # f132..f192, px de master
    n = len(raiz) - 1                           # el bucle: f133..f192
    limpios = os.path.join(AQUI, '04_limpios')
    X = [leer(limpios, k) for k in range(2, n + 2)]
    # tono del arrastre viejo
    objetivo = tono.media([leer(VIEJO, k).astype(float) / 255 for k in range(75, 124, 4)])
    muestra = [x.astype(float) / 255 for x in X[::4]]
    g = np.ones(3)
    for _ in range(6):
        g = g * objetivo / tono.media([tono.aplicar(im, g) for im in muestra])
    print('ganancia de tono (%.3f, %.3f, %.3f)' % tuple(g))
    Y = [E.quitar_verde((tono.aplicar(x.astype(float) / 255, g) * 255).round().astype(np.uint8)) for x in X]
    dest = os.path.join(AQUI, '04_acciones')
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest)
    for i, y in enumerate(Y):
        Image.fromarray(y, 'RGBA').save(os.path.join(dest, 'c_%03d.png' % (i + 1)))

    # pasos y salidas: cada fotograma frente al ultimo (el f192 = c096), encajado en x
    P = [ndi.gaussian_filter(pm(y)[::2, ::2], (1, 1, 0)) for y in Y]
    pasos = np.array([np.abs(P[i + 1] - P[i]).mean() for i in range(n - 1)])
    med = float(np.median(pasos))
    # la costura: tras el f192 (casilla en raiz[n]) va el f133 (casilla en raiz[1] + vuelta)
    corr = int(round((raiz[1, 0] + rz['vuelta'] - raiz[n, 0]) / 2))
    costura = float(np.abs(np.roll(P[0], corr, 1) - P[n - 1]).mean()) / med
    print('pasos del bucle: mediana %.3f, max %.2f; costura f192 -> f133: %.2f pasos (encajada: casillas %+d px de master)'
          % (med, pasos.max() / med, costura, corr * 2))
    ult = P[n - 1]
    calca = []
    for e in range(n):
        # en el video, la casilla del e esta (raiz[e] - raiz[192]) a la derecha de la del ultimo
        base = int(round((raiz[e + 1, 0] - raiz[n, 0]) / 2))     # a la mitad
        mejor = (1e9, 0)
        for dx in range(base - 12, base + 13):
            v = float(np.abs(np.roll(P[e], dx, 1) - ult).mean())
            if v < mejor[0]:
                mejor = (v, dx)
        calca.append((mejor[0] / med, mejor[1] * 2))   # desplazamiento de casilla a casilla, en master
    viejo = json.load(open(JUEGO))['arrastrarse']
    r_viejo = np.array(viejo['raiz'], float)            # c075..c123, px de juego desde el c075
    paso_viejo = r_viejo[22] - r_viejo[21]              # c096 -> c097
    # Salir en e: el e, encajado, es el f192 con su casilla corrida dx; en el video
    # la casilla del e esta (raiz[e] - raiz[192]) a la derecha de la del f192, asi
    # que su "c096" tiene la raiz raiz[e] - dx (dibujo de casilla a casilla). De la
    # raiz del primero del bucle a la del c097 que sigue: eso + c096 -> c097.
    tabla_salidas = {}
    for e, (d, dx) in enumerate(calca):
        if d > UMBRAL_SALIDA or (e != n - 1 and e >= n - 6):
            continue
        r96 = raiz[e + 1, 0] - dx
        tabla_salidas[str(e)] = round(float((r96 - raiz[1, 0]) / 2.0 + paso_viejo[0]), 2)
        print('  salida tras el %2d (f%d): calca al f192 a %.2f pasos; el nodo avanza %.1f px de juego'
              % (e, e + 133, d, tabla_salidas[str(e)]))
    oy = (CH / 2.0 - RY) / 2.0
    r = (raiz[1:] - raiz[1]) / 2.0
    vuelta = rz['vuelta'] / 2.0
    s = np.linspace(0, 1, n)
    bucle = {'hoja': 'peregrino_arrastrarse_bucle', 'desde': 0, 'n': n, 'fps': FPS,
             'casilla': [CW // 2, CH // 2], 'offset': [0.0, oy],
             'raiz': [[round(float(u), 2), round(float(v), 2)] for u, v in r],
             'viaje': [round(float(r[-1, 0]), 2), 0.0], 'siguiente': [round(vuelta, 2), 0.0],
             's': [[round(float(u), 4), 0.0] for u in s], 'bucle': True, 'vuelta': [round(vuelta, 2), 0.0],
             'salidas': tabla_salidas, 'objetos_ini': [], 'objetos_fin': []}

    # entrada y salida: el arrastre viejo partido en el c096
    def tramo(i0, i1, siguiente):
        rr = r_viejo[i0:i1 + 1] - r_viejo[i0]
        return {'hoja': 'peregrino_tumbarse', 'desde': 74 + i0, 'n': i1 - i0 + 1, 'fps': FPS,
                'casilla': viejo['casilla'], 'offset': viejo['offset'],
                'raiz': [[round(float(u), 2), round(float(v), 2)] for u, v in rr],
                'viaje': [round(float(v), 2) for v in rr[-1]],
                'siguiente': [round(float(v), 2) for v in siguiente],
                's': viejo['s'][i0:i1 + 1], 'objetos_ini': [], 'objetos_fin': []}
    # entrada -> bucle: el f133 sigue al f132, que es el c096 una vuelta antes
    paso_nuevo = (raiz[1] - raiz[0]) / 2.0
    entrada = tramo(0, 21, (r_viejo[21] - r_viejo[0]) + paso_nuevo)
    # sin la direccion pulsada al acabar la entrada (un toque) se salta el bucle:
    # c096 -> c097, la brazada de siempre
    entrada['sin_bucle'] = [round(float(v), 2) for v in r_viejo[22] - r_viejo[0]]
    salida = tramo(22, 48, np.array(viejo['siguiente'], float) - r_viejo[22])
    datos = {'arrastre_entrada': entrada, 'arrastrarse_bucle': bucle, 'arrastre_salida': salida}
    json.dump(datos, open(os.path.join(AQUI, 'accion.json'), 'w'), indent=1)
    todo = json.load(open(JUEGO))
    todo.update(datos)
    json.dump(todo, open(JUEGO, 'w'), separators=(',', ':'))
    print('vuelta %.1f px de juego en %d fotogramas (%.1f px/s); entrada siguiente %s'
          % (vuelta, n, vuelta / n * FPS, entrada['siguiente']))
    print('escrito 04_acciones (%d), accion.json y acciones_perfil.json' % n)
    print('hoja:  .\\hoja.ps1 -Job peregrino_arrastrarse_bucle -Desde 04_acciones -Fps 24 -Escala 2 -Cols 10')


if __name__ == '__main__':
    main()
