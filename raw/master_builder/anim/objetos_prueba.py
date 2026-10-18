"""Texturas del muro y los sillares de la escena de prueba de perfil
(scenes/dev/piloto_baston.tscn, nodo Acciones): las mismas piedras low-poly de
las referencias de los videos (muro() de referencias_trepar_bajar.py, sillar()
de referencias_empujar.py), dibujadas a escala de master y reducidas a la mitad,
como las hojas del peregrino. Las medidas son las de los videos, en px de juego:

  muro            400 x 362  el de trepar y bajar (sube 724 px de master)
  sillar_mediano  196 x 172  el del empuje v1 y el de subirse (sube 344)
  sillar_alto     218 x 362  el del empuje v2 (217 de ancho en su video), con el
                             alto del muro para que se suba con el trepar alto

  python objetos_prueba.py   -> assets/pruebas_acciones/*.png
"""
import os, sys
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
FUENTES = os.path.join(AQUI, '_fuentes')
SALIDA = os.path.abspath(os.path.join(AQUI, '..', '..', '..', 'assets', 'pruebas_acciones'))
sys.path.insert(0, FUENTES)
sys.argv = [sys.argv[0], os.path.join(AQUI, '_tmp_referencias')]   # referencias_trepar_bajar escribe al importarse
os.makedirs(sys.argv[1], exist_ok=True)
import referencias_empujar as RE          # noqa: E402
import referencias_trepar_bajar as RT     # noqa: E402

OBJETOS = {
    'muro': ('muro', 800, 724, 11),
    'sillar_mediano': ('sillar', 392, 344, 7),
    'sillar_alto': ('sillar_recto', 436, 724, 9),
}


def objetos_sueltos():
    """Lo de coger, lanzar, tirar y clavar, con el dibujo de sus referencias
    (referencias_coger_tirar_tumbarse.py, referencias_clavar.py): la piedrecita,
    el palo de Argos, la argolla del sillar que se tira, la mesa a la cintura y
    el baculo clavado (sacado del reposo con el baston en la mano, como en la
    referencia de clavar). Devuelve {nombre: imagen de master}."""
    sys.argv = [sys.argv[0], os.path.join(AQUI, '_tmp_referencias')]
    import referencias_coger_tirar_tumbarse as RC          # noqa: E402 (escribe sus referencias en _tmp)
    out = {'guijarro': RC.guijarro(), 'palo': RC.palo(), 'argolla': RC.argolla()[0]}
    H = RC.H
    hm, wm = round(0.40 * H), round(0.34 * H)
    hl, wl = round(0.06 * H), round(0.44 * H)
    mesa = Image.new('RGBA', (wl, hm + hl), (0, 0, 0, 0))
    mesa.alpha_composite(RE.sillar(wm, hm, puntos=18, semilla=21), ((wl - wm) // 2, hl - 1))
    mesa.alpha_composite(RE.sillar(wl, hl, puntos=8, semilla=22), (0, 0))
    out['mesa'] = mesa
    # el baculo clavado: el de la referencia de arrancar (casilla de 584x720, la
    # raiz en 292, 690); se guarda recortado y donde va respecto a la raiz
    sys.argv = [sys.argv[0], os.path.join(AQUI, '_tmp_referencias')]
    cwd = os.getcwd()
    import referencias_clavar as RCl                     # noqa: E402 (cambia de carpeta)
    os.chdir(cwd)
    cl = np.asarray(Image.fromarray(RCl.clavada).convert('RGBA'))
    ys, xs = np.where(cl[..., 3] > 0)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    out['baculo_clavado'] = Image.fromarray(cl[y0:y1, x0:x1])
    print('baculo clavado: respecto a la raiz, x %+.1f y %+.1f (px de juego)' % ((x0 - 292) / 2, (y0 - 690) / 2))
    return out


def main():
    os.makedirs(SALIDA, exist_ok=True)
    for nombre, (tipo, w, h, semilla) in OBJETOS.items():
        if tipo == 'muro':
            img = RT.muro(w, h, semilla)
        else:
            img = RE.sillar(w, h, recta=(tipo == 'sillar_recto'), puntos=46 if tipo == 'sillar_recto' else 26, semilla=semilla)
        img = img.convert('RGBA').resize((w // 2, h // 2), Image.LANCZOS)
        img.save(os.path.join(SALIDA, nombre + '.png'))
        print(nombre, img.size)
    for nombre, img in objetos_sueltos().items():
        w, h = img.size
        img = img.convert('RGBA').resize((max(1, round(w / 2)), max(1, round(h / 2))), Image.LANCZOS)
        img.save(os.path.join(SALIDA, nombre + '.png'))
        print(nombre, img.size)
    import shutil
    shutil.rmtree(os.path.join(AQUI, '_tmp_referencias'), ignore_errors=True)


if __name__ == '__main__':
    main()
