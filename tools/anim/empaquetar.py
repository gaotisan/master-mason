"""Empaqueta una hoja en rejilla en un atlas con cada fotograma recortado a su silueta.

En la rejilla cada casilla ocupa lo mismo aunque el personaje solo llene entre
un 21 % y un 52 % de ella: el resto es transparente pero cuesta memoria de video
igual. Aqui cada casilla usada se recorta a lo que tiene dibujado y se colocan
juntas en un atlas mas pequeno. Lo que se quito no se pierde: el generador del
SpriteFrames (_spriteframes.py) pone en el AtlasTexture margin = (dx, dy,
casilla - recorte), y Godot dibuja el fotograma con el tamano de la casilla
entera y el dibujo en su sitio. Ni el tamano, ni el centrado, ni el flip_h, ni
el offset del sprite cambian.

Parte de la hoja ya exportada (hoja.ps1, 05_salida/<hoja>_sheet.png), no de
04_limpios: los pixeles son los mismos que se veian, sin volver a reducir nada.

Cuidados, que son los de siempre del atlas:
  - cada recorte se alinea a multiplos de 4 (bloques de la compresion BC7/ASTC):
    dos fotogramas nunca comparten bloque, y como las casillas miden multiplos
    de 4 cada pixel cae en la misma posicion dentro de su bloque que en la
    rejilla, asi que la compresion le hace exactamente lo mismo;
  - entre recortes quedan SEPARACION px transparentes: el filtrado bilineal y
    las mipmaps no mezclan fotogramas vecinos hasta 1/8 de escala (antes, el
    margen mas justo, el del salto de parado, era de 3 px);
  - alinear el recorte nunca lo saca de su casilla.

Lo normal es no llamarlo a mano: lo hace _spriteframes.py con todas las hojas.
    python empaquetar.py <hoja.png> <ancho_casilla> <alto_casilla> <columnas> <casillas> <salida_png>
      <casillas>: indices usados ("0-84" o "0,1,5-9"); al lado de la salida deja
      un .json con {casilla, atlas, fotogramas: {indice: [x, y, w, h, dx, dy]}}.
"""
import json, os, sys
import numpy as np
from PIL import Image

SEPARACION = 8
BLOQUE = 4
ANCHO_MAX = 4096


def rangos(texto):
    out = []
    for t in texto.split(','):
        t = t.strip()
        if '-' in t:
            a, b = t.split('-')
            out += list(range(int(a), int(b) + 1))
        elif t:
            out.append(int(t))
    return sorted(set(out))


def recorte(celda):
    """Caja (dx, dy, w, h) del dibujo dentro de la casilla, alineada a BLOQUE.
    Una casilla vacia se queda en un bloque."""
    a = celda[..., 3] > 0
    ys, xs = np.where(a)
    h, w = a.shape
    if len(ys) == 0:
        return 0, 0, BLOQUE, BLOQUE
    x0 = (int(xs.min()) // BLOQUE) * BLOQUE
    y0 = (int(ys.min()) // BLOQUE) * BLOQUE
    x1 = min(w, -(-(int(xs.max()) + 1) // BLOQUE) * BLOQUE)
    y1 = min(h, -(-(int(ys.max()) + 1) // BLOQUE) * BLOQUE)
    return x0, y0, x1 - x0, y1 - y0


def estanterias(cajas, ancho):
    """Colocacion por baldas: de la mas alta a la mas baja, de izquierda a derecha."""
    orden = sorted(cajas, key=lambda k: (-cajas[k][3], k))
    x = y = alto_balda = 0
    sitio = {}
    for k in orden:
        w, h = cajas[k][2], cajas[k][3]
        if x > 0 and x + w > ancho:
            x = 0
            y += alto_balda + SEPARACION
            alto_balda = 0
        sitio[k] = (x, y)
        x += w + SEPARACION
        alto_balda = max(alto_balda, h)
    return sitio, y + alto_balda


def empaquetar(hoja, cw, ch, cols, usadas, salida_png, salida_json):
    """Empaqueta las casillas `usadas` de la rejilla `hoja`. Devuelve los datos del .json."""
    assert cw % BLOQUE == 0 and ch % BLOQUE == 0, 'la casilla tiene que medir multiplos de %d' % BLOQUE
    im = np.asarray(Image.open(hoja).convert('RGBA'))
    usadas = sorted(set(usadas))
    cajas, celdas = {}, {}
    for k in usadas:
        cx, cy = (k % cols) * cw, (k // cols) * ch
        celda = im[cy:cy + ch, cx:cx + cw]
        assert celda.shape[:2] == (ch, cw), '%s: la casilla %d se sale de la hoja' % (hoja, k)
        celdas[k] = celda
        cajas[k] = recorte(celda)
    area = sum((c[2] + SEPARACION) * (c[3] + SEPARACION) for c in cajas.values())
    mejor = None
    for ancho in range(256, ANCHO_MAX + 1, 64):
        if ancho < max(c[2] for c in cajas.values()):
            continue
        sitio, alto = estanterias(cajas, ancho)
        alto = -(-alto // BLOQUE) * BLOQUE
        if alto > ANCHO_MAX:
            continue
        # La de menos superficie; a igualdad, la mas cuadrada.
        clave = (ancho * alto, abs(ancho - alto))
        if mejor is None or clave < mejor[0]:
            mejor = (clave, ancho, alto, sitio)
    assert mejor, '%s: no cabe en %dx%d' % (hoja, ANCHO_MAX, ANCHO_MAX)
    _, ancho, alto, sitio = mejor
    atlas = np.zeros((alto, ancho, 4), np.uint8)
    fotogramas = {}
    for k in usadas:
        dx, dy, w, h = cajas[k]
        x, y = sitio[k]
        atlas[y:y + h, x:x + w] = celdas[k][dy:dy + h, dx:dx + w]
        fotogramas[str(k)] = [x, y, w, h, dx, dy]
    Image.fromarray(atlas).save(salida_png, optimize=True)
    datos = {'hoja': os.path.basename(hoja), 'casilla': [cw, ch], 'atlas': [ancho, alto],
             'separacion': SEPARACION, 'fotogramas': fotogramas,
             'superficie_rejilla': int(im.shape[0] * im.shape[1]),
             'relleno': round(area / float(ancho * alto), 3)}
    with open(salida_json, 'w', encoding='utf-8') as f:
        json.dump(datos, f, indent=1)
    return datos


def main():
    hoja, cw, ch, cols, lista, salida = (sys.argv[1], int(sys.argv[2]), int(sys.argv[3]),
                                         int(sys.argv[4]), sys.argv[5], sys.argv[6])
    d = empaquetar(hoja, cw, ch, cols, rangos(lista), salida, os.path.splitext(salida)[0] + '.json')
    print('%s: %d casillas -> %dx%d (%.0f %% de la superficie de la rejilla)' % (
        os.path.basename(hoja), len(d['fotogramas']), d['atlas'][0], d['atlas'][1],
        100.0 * d['atlas'][0] * d['atlas'][1] / d['superficie_rejilla']))


if __name__ == '__main__':
    main()
