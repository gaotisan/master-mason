"""Aplana la sombra que el personaje proyecta sobre el croma.

Por que hace falta: _fondo.py decide que es fondo por DISTANCIA DE COLOR (maximo
de los tres canales) y con una sombra dura eso no separa nada. Medido en el video
del aracnobat, con fondo verde (24,183,50): la sombra sola llega a distancia 122
y el pixel mas cercano de la criatura esta a 46. No hay umbral posible.

Lo que si separa es el TONO, no el brillo. Una sombra sobre el croma sigue siendo
croma con menos luz: (r,g,b) = k*(Rf,Gf,Bf). La criatura es gris azulado y no cae
en esa recta por mucho que se oscurezca. Asi que:

    k = g / Gf                 (cuanta luz le llega, medida en el canal dominante)
    residuo = max(|r - k*Rf|, |b - k*Bf|)

Sobre el mismo video: fondo y sombra dan residuo <= 24 (percentil 99,9) y la
criatura maciza da 58-74 de mediana. Con umbral 25 la sombra desaparece entera.

Dos redes, porque el umbral solo NO vale:

1. Solo se aplana lo que se alcanza **desde el borde del cuadro**, igual que en
   _fondo.py. Un trozo oscuro dentro del bicho no se alcanza y no se toca.

2. Y ademas solo por sitios ANCHOS (`--radio`). Esta es la que de verdad importa
   aqui: el negro esta cerca de todas las rectas, asi que las patas oscuras y
   finas de la araña dan residuo 17-19 y el relleno se colaba por ellas y las
   partia por la mitad. Con radio 3 el relleno solo pasa por conductos de mas de
   7 px: la sombra, que es una mancha ancha, entra entera; una pata, no.
   Medido en and_03: sin radio la criatura quedaba en 58.462 px partida en 344
   trozos; con radio 3, 79.015 px de una pieza.

   El precio son los pelos de las patas, de 1-2 px: se van con la sombra. A
   tamano de juego no se veian de todas formas.

Sale de aqui la misma imagen, con la sombra sustituida por el color de fondo, y
ya se la puede pasar a centrar.ps1 y fondo.ps1 como si el croma fuese plano.

Solo necesita ffmpeg: los pixeles entran y salen por tuberia, sin librerias.
"""
import argparse, os, re, subprocess
from collections import deque


def leer_rgb(ffmpeg, ruta):
    d = subprocess.run(
        [ffmpeg, '-hide_banner', '-loglevel', 'error', '-i', ruta,
         '-f', 'image2pipe', '-pix_fmt', 'rgb24', '-vcodec', 'ppm', '-'],
        stdout=subprocess.PIPE, check=True).stdout
    m = re.match(rb'P6\s+(\d+)\s+(\d+)\s+(\d+)\s', d)
    if not m:
        raise SystemExit('ffmpeg no devolvio un PPM valido para ' + ruta)
    return int(m.group(1)), int(m.group(2)), d[m.end():]


def escribir_rgb(ffmpeg, destino, w, h, datos):
    subprocess.run(
        [ffmpeg, '-hide_banner', '-loglevel', 'error', '-y',
         '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '%dx%d' % (w, h), '-i', '-',
         '-frames:v', '1', '-update', '1', destino],
        input=bytes(datos), check=True)


def color_fondo(px, w, h, m=6):
    ac = [0, 0, 0]
    n = 0
    for x0, y0 in ((0, 0), (w - m, 0), (0, h - m), (w - m, h - m)):
        for y in range(y0, y0 + m):
            for x in range(x0, x0 + m):
                i = (y * w + x) * 3
                ac[0] += px[i]; ac[1] += px[i + 1]; ac[2] += px[i + 2]
                n += 1
    return tuple(v // n for v in ac)


def en_la_recta(px, fondo, tol, holgura):
    """1 donde el pixel es el croma con menos luz; 0 donde es otra cosa.

    El canal verde da la escala (es el dominante del croma, y por tanto el menos
    ruidoso) y los otros dos se comparan con lo que deberian valer a esa escala.
    Las dos tablas evitan una division por pixel: solo dependen del verde.
    La holgura impide aplanar lo que es MAS claro que el fondo: una sombra solo
    puede quitar luz, asi que un reflejo verdoso sobre la criatura no entra.
    """
    rf, gf, bf = fondo
    gf = max(1, gf)
    tabla_r = bytes(min(255, round(v * rf / gf)) for v in range(256))
    tabla_b = bytes(min(255, round(v * bf / gf)) for v in range(256))
    tabla_techo = bytes(1 if v <= gf + holgura else 0 for v in range(256))
    verde = px[1::3]
    dif_r = bytes(map(lambda a, b: abs(a - b), px[0::3], verde.translate(tabla_r)))
    dif_b = bytes(map(lambda a, b: abs(a - b), px[2::3], verde.translate(tabla_b)))
    tabla_ok = bytes(1 if v <= tol else 0 for v in range(256))
    dentro = bytes(map(max, dif_r, dif_b)).translate(tabla_ok)
    return bytes(map(min, dentro, verde.translate(tabla_techo)))


def _pasada(m, w, h, r, fuera, junta):
    """Erosion (junta=min) o dilatacion (junta=max) con ventana cuadrada.

    Una ventana cuadrada se separa en dos pasadas de una dimension, que es lo que
    hace que esto sea viable sin librerias: 2*(2r+1) recorridos de la imagen en
    vez de (2r+1)^2 por pixel.
    """
    relleno = bytes([fuera]) * r
    filas = []
    for y in range(h):
        fila = relleno + m[y * w:(y + 1) * w] + relleno
        filas.append(bytes(map(junta, *(fila[j:j + w] for j in range(2 * r + 1)))))
    plano = b''.join(filas)
    borde = bytes([fuera]) * (w * r)
    alto = borde + plano + borde
    return bytes(map(junta, *(alto[j * w:j * w + w * h] for j in range(2 * r + 1))))


def alcanzable_desde_el_borde(dentro, w, h):
    fondo = bytearray(w * h)
    q = deque()

    def sembrar(i):
        if not fondo[i] and dentro[i]:
            fondo[i] = 1
            q.append(i)

    for x in range(w):
        sembrar(x)
        sembrar((h - 1) * w + x)
    for y in range(h):
        sembrar(y * w)
        sembrar(y * w + w - 1)
    while q:
        i = q.popleft()
        x = i % w
        if x > 0:     sembrar(i - 1)
        if x < w - 1: sembrar(i + 1)
        if i >= w:    sembrar(i - w)
        if i < (h - 1) * w: sembrar(i + w)
    return fondo


def cerrar_islotes(fondo, w, h, minimo):
    """Mete en el fondo los islotes que la sombra deja sin aplanar.

    Son pixeles sueltos de la sombra que se pasan del umbral por ruido de
    compresion. Quedan rodeados de fondo por todos lados, asi que no se les puede
    confundir con la criatura: esa siempre es un grupo grande.
    """
    visto = bytearray(w * h)
    cerrados = 0
    for semilla in range(w * h):
        if fondo[semilla] or visto[semilla]:
            continue
        cola = deque([semilla])
        visto[semilla] = 1
        grupo = []
        while cola:
            i = cola.popleft()
            if len(grupo) <= minimo:
                grupo.append(i)
            x = i % w
            vecinos = ((i - 1, x > 0), (i + 1, x < w - 1),
                       (i - w, i >= w), (i + w, i < (h - 1) * w))
            for j, dentro in vecinos:
                if dentro and not fondo[j] and not visto[j]:
                    visto[j] = 1
                    cola.append(j)
        if len(grupo) <= minimo:
            for i in grupo:
                fondo[i] = 1
            cerrados += 1
    return cerrados


def procesar(ffmpeg, origen, destino, tol, holgura, radio, min_islote, fondo_fijo=None):
    w, h, px = leer_rgb(ffmpeg, origen)
    fondo_col = fondo_fijo or color_fondo(px, w, h)
    dentro = en_la_recta(px, fondo_col, tol, holgura)
    if radio > 0:
        # Fuera del cuadro cuenta como fondo, si no la erosion se comeria el marco
        # y el relleno no tendria por donde empezar.
        semilla = alcanzable_desde_el_borde(_pasada(dentro, w, h, radio, 1, min), w, h)
        es_fondo = bytes(map(min, _pasada(semilla, w, h, radio, 0, max), dentro))
    else:
        es_fondo = alcanzable_desde_el_borde(dentro, w, h)
    es_fondo = bytearray(es_fondo)
    islotes = cerrar_islotes(es_fondo, w, h, min_islote) if min_islote > 0 else 0

    salida = bytearray(px)
    for i in range(w * h):
        if es_fondo[i]:
            j = i * 3
            salida[j] = fondo_col[0]
            salida[j + 1] = fondo_col[1]
            salida[j + 2] = fondo_col[2]
    escribir_rgb(ffmpeg, destino, w, h, salida)
    return fondo_col, sum(es_fondo), islotes, w * h


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ffmpeg', required=True)
    ap.add_argument('--entrada', required=True)
    ap.add_argument('--salida', required=True)
    ap.add_argument('--tolerancia', type=int, default=25,
                    help='cuanto puede salirse de la recta del croma y seguir siendo sombra')
    ap.add_argument('--holgura', type=int, default=12,
                    help='cuanto puede pasarse de claro respecto al fondo')
    ap.add_argument('--radio', type=int, default=3,
                    help='ancho minimo por el que el aplanado puede colarse (0 lo apaga)')
    ap.add_argument('--islotes', type=int, default=24,
                    help='trozos sin aplanar menores que esto se meten en el fondo')
    ap.add_argument('--fondo', default='')
    a = ap.parse_args()

    fijo = tuple(int(v) for v in a.fondo.split(',')) if a.fondo else None
    ficheros = sorted(f for f in os.listdir(a.entrada) if f.lower().endswith('.png'))
    if not ficheros:
        raise SystemExit('No hay PNG en ' + a.entrada)
    if not os.path.isdir(a.salida):
        os.makedirs(a.salida)

    print('Aplanando la sombra de %d imagenes (tolerancia %d, radio %d)...'
          % (len(ficheros), a.tolerancia, a.radio))
    for f in ficheros:
        col, nfondo, islotes, total = procesar(
            a.ffmpeg, os.path.join(a.entrada, f), os.path.join(a.salida, f),
            a.tolerancia, a.holgura, a.radio, a.islotes, fijo)
        aviso = ('  islotes=%d' % islotes) if islotes else ''
        print('  %-12s fondo=%s  aplanado=%5.1f%%  queda=%6d px%s'
              % (f, str(col), 100.0 * nfondo / total, total - nfondo, aviso))
    print('Listo: %s' % a.salida)


if __name__ == '__main__':
    main()
