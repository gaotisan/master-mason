"""El peregrino de frente / espaldas a la resolucion de los masters (EN PRUEBA, 2026-10-18).

Las hojas del juego (hoja.ps1 -Escala 2) van a la mitad de los masters de 04_limpios;
de cerca se ven blandas (el camino lo pinta hasta x2,6). Aqui, las mismas animaciones
del peregrino de frente (las que _spriteframes.py lee de los animaciones.json de las
secuencias y de sacar / guardar) sacadas de los masters SIN reducir, recortadas y
empaquetadas como empaquetar.py (bloques de 4, separacion de 8), en paginas de hasta
PAGINA px de lado, a un SpriteFrames aparte:

    assets/characters/peregrino_hd/<hoja>_<n>.png
    resources/characters/peregrino_frontal_hd.tres

Mismos nombres, fps, bucles y duraciones que en peregrino_frames.tres; las casillas, el
doble. PeregrinoFrontal lo usa con alta_resolucion (sprite a media escala: lo demas de
la escena sigue en px de hoja). peregrino_frames.tres no se toca.
    python frontal_hd.py
"""
import io, json, os

import cv2
import numpy as np
from PIL import Image

import empaquetar as E
import _spriteframes as SF

PAGINA = 8192
JOBS = ('peregrino_secuencia_frontal', 'peregrino_secuencia_frontal_sin',
        'peregrino_sacar_baston_frente', 'peregrino_guardar_baston_frente',
        'peregrino_sacar_baston_espalda_v2', 'peregrino_guardar_baston_espalda_a',
        'peregrino_sacar_baston_frente_gu', 'peregrino_guardar_baston_frente_gu',
        'peregrino_sacar_baston_espalda_v2_gu', 'peregrino_guardar_baston_espalda_a_gu')
SALIDA = os.path.join(SF.RAIZ, 'assets', 'characters', 'peregrino_hd')
TRES = os.path.join(SF.RAIZ, 'resources', 'characters', 'peregrino_frontal_hd.tres')


def animaciones():
    """Las de frente, como las declara _spriteframes.py (de los animaciones.json)."""
    out = []
    for job in JOBS:
        ruta = os.path.join(SF.ANIM_RAW, job, 'animaciones.json')
        if not os.path.exists(ruta):
            continue
        nombres = {a[0] for a in json.load(open(ruta))}
        out += [a for a in SF.ANIMACIONES if a[0] in nombres]
    return out


def limpiar_borde(a, lo=70, hi=210, ancho=3):
    """(2026-10-19) Borde del recorte, en todas las HD por igual (sin saltos entre
    animaciones; las del juego, las de siempre). El reposo de espaldas con baston trae el
    borde borroso, con un halo tenue ancho y ribete verdoso del croma: sobre fondo oscuro
    el contorno se veia sucio (el usuario, al final del sacar de espaldas). Borde: el color de la orla (ancho px hacia dentro desde lo transparente),
    el del interior de al lado (sin el ribete verdoso/oscuro del croma), y el alfa con la
    rampa mas corta (el halo tenue fuera)."""
    a = a.astype(np.float32).copy()
    al = a[..., 3]
    fondo = (al < 250).astype(np.uint8)
    orla = (cv2.dilate(fondo, np.ones((2 * ancho + 1, 2 * ancho + 1), np.uint8)) > 0) & (al > 0)
    dentro = ((al >= 250) & ~orla).astype(np.float32)
    rgb = a[..., :3]
    s = 2.5
    num = cv2.GaussianBlur(rgb * dentro[..., None], (0, 0), s)
    den = cv2.GaussianBlur(dentro, (0, 0), s)[..., None]
    for _ in range(3):
        ok = den[..., 0] > 0.02
        if ok[orla].all():
            break
        s *= 2
        num = cv2.GaussianBlur(rgb * dentro[..., None], (0, 0), s)
        den = cv2.GaussianBlur(dentro, (0, 0), s)[..., None]
    vecino = num / np.maximum(den, 1e-4)
    # solo lo contaminado (verdoso: G por encima de R y B); lo fino que es todo orla (las
    # piernas, la vara) conserva su color
    verdoso = rgb[..., 1] >= np.maximum(rgb[..., 0], rgb[..., 2]) - 2
    usar = orla & verdoso & (den[..., 0] > 0.02)
    rgb2 = rgb.copy()
    rgb2[..., 1] = np.where(orla, np.minimum(rgb[..., 1], np.maximum(rgb[..., 0], rgb[..., 2])), rgb[..., 1])
    rgb = rgb2
    a[..., :3] = np.where(usar[..., None], vecino, rgb)
    a[..., 3] = np.clip((al - lo) * 255.0 / (hi - lo), 0, 255)
    a[a[..., 3] <= 0] = 0
    return a.round().clip(0, 255).astype(np.uint8)


def celdas(hoja, usadas, casilla):
    """Los masters de la hoja (04_limpios por nombre, como hoja.ps1), por indice."""
    lista = sorted(f for f in os.listdir(os.path.join(SF.ANIM_RAW, hoja, '04_limpios')) if f.endswith('.png'))
    out = {}
    for k in usadas:
        im = np.asarray(Image.open(os.path.join(SF.ANIM_RAW, hoja, '04_limpios', lista[k])).convert('RGBA'))
        assert im.shape[1] == casilla[0] and im.shape[0] == casilla[1], \
            '%s: %s mide %dx%d, no %dx%d' % (hoja, lista[k], im.shape[1], im.shape[0], casilla[0], casilla[1])
        out[k] = limpiar_borde(im)
    return out


def paginar(cajas):
    """Baldas como empaquetar.estanterias, en paginas de PAGINA de ancho y alto."""
    orden = sorted(cajas, key=lambda k: (-cajas[k][3], k))
    paginas, sitio = [], {}
    x = y = alto_balda = 0
    actual = []
    for k in orden:
        w, h = cajas[k][2], cajas[k][3]
        if x > 0 and x + w > PAGINA:
            x = 0
            y += alto_balda + E.SEPARACION
            alto_balda = 0
        if y + h > PAGINA:
            paginas.append(actual)
            actual, x, y, alto_balda = [], 0, 0, 0
        sitio[k] = (len(paginas), x, y)
        actual.append(k)
        x += w + E.SEPARACION
        alto_balda = max(alto_balda, h)
    paginas.append(actual)
    return paginas, sitio


def asegurar_import(nombre):
    ruta = os.path.join(SALIDA, nombre + '.png.import')
    if os.path.exists(ruta):
        return
    lineas = ['[remap]', '', 'importer="texture"', 'type="CompressedTexture2D"', '', '[deps]', '',
              'source_file="res://assets/characters/peregrino_hd/%s.png"' % nombre, '', '[params]', '']
    lineas += ['%s=%s' % kv for kv in SF.IMPORT_HOJA.items()]
    io.open(ruta, 'w', encoding='utf-8', newline='\n').write('\n'.join(lineas) + '\n')


def main():
    os.makedirs(SALIDA, exist_ok=True)
    anims = animaciones()
    usos = {}
    for a in anims:
        nombre, hoja, n = a[:3]
        cas = tuple(2 * c for c in (a[6] if len(a) > 6 and a[6] else SF.CASILLA))
        idx = list(a[7]) if len(a) > 7 and a[7] else list(range(n))
        if hoja in usos:
            assert usos[hoja][0] == cas
            usos[hoja][1].update(idx)
        else:
            usos[hoja] = (cas, set(idx))
    donde = {}       # (hoja, k) -> (png, x, y, w, h, dx, dy)
    px = 0
    for hoja, (cas, usadas) in sorted(usos.items()):
        cs = celdas(hoja, sorted(usadas), cas)
        cajas = {k: E.recorte(c) for k, c in cs.items()}
        paginas, sitio = paginar(cajas)
        for p, ks in enumerate(paginas):
            ancho = max(sitio[k][1] + cajas[k][2] for k in ks)
            alto = max(sitio[k][2] + cajas[k][3] for k in ks)
            ancho, alto = -(-ancho // E.BLOQUE) * E.BLOQUE, -(-alto // E.BLOQUE) * E.BLOQUE
            atlas = np.zeros((alto, ancho, 4), np.uint8)
            nombre = '%s_%d' % (hoja, p)
            for k in ks:
                dx, dy, w, h = cajas[k]
                _, x, y = sitio[k]
                atlas[y:y + h, x:x + w] = cs[k][dy:dy + h, dx:dx + w]
                donde[(hoja, k)] = (nombre, x, y, w, h, dx, dy)
            Image.fromarray(atlas).save(os.path.join(SALIDA, nombre + '.png'), optimize=True)
            asegurar_import(nombre)
            px += ancho * alto
            print('   %-40s %5dx%-5d %3d fotogramas' % (nombre, ancho, alto, len(ks)))
    ext, sub, bloques = [], [], []
    tex_de, atlas_de = {}, {}
    for a in anims:
        nombre, hoja, n, cols, fps, bucle = a[:6]
        cw, ch = (2 * c for c in (a[6] if len(a) > 6 and a[6] else SF.CASILLA))
        idx = list(a[7]) if len(a) > 7 and a[7] else list(range(n))
        durs = list(a[8]) if len(a) > 8 and a[8] else [1.0] * n
        refs = []
        for k, dur in zip(idx, durs):
            png, x, y, w, h, dx, dy = donde[(hoja, k)]
            if png not in tex_de:
                tex_de[png] = 'tex_%d' % (len(tex_de) + 1)
                ext.append('[ext_resource type="Texture2D" path="res://assets/characters/peregrino_hd/%s.png" id="%s"]'
                           % (png, tex_de[png]))
            if (hoja, k) not in atlas_de:
                atlas_de[(hoja, k)] = 'atlas_%d' % (len(atlas_de) + 1)
                sub.append('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("%s")\n'
                           'region = Rect2(%d, %d, %d, %d)\nmargin = Rect2(%d, %d, %d, %d)\n'
                           % (atlas_de[(hoja, k)], tex_de[png], x, y, w, h, dx, dy, cw - w, ch - h))
            refs.append('{\n"duration": %s,\n"texture": SubResource("%s")\n}' % (repr(float(dur)), atlas_de[(hoja, k)]))
        bloques.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
                       % (', '.join(refs), 'true' if bucle else 'false', nombre, fps))
    txt = ('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (len(ext) + len(sub) + 1)
           + '\n'.join(ext) + '\n\n' + '\n'.join(sub)
           + '\n[resource]\nanimations = [' + ', '.join(bloques) + ']\n')
    io.open(TRES, 'w', encoding='utf-8', newline='\n').write(txt)
    print('%d animaciones, %d fotogramas -> %s; memoria de video ~%.0f MiB (BC7, sin mipmaps)'
          % (len(anims), len(atlas_de), TRES, px / 1048576.0))


if __name__ == '__main__':
    main()
