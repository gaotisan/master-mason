"""Quita el paneo de camara y recorta al personaje.

Mide la silueta de cada fotograma (el fondo del video es liso y claro), calcula
el eje del cuerpo usando solo el tronco -- las piernas se mueven y desviarian el
centro -- y recorta una ventana del mismo tamano en todos, anclada a ese eje.
La altura NO se estabiliza: el bote de la carrera tiene que notarse.

Solo necesita ffmpeg: lee los pixeles como PGM por la tuberia, sin librerias.
"""
import argparse, os, subprocess
from collections import deque

UMBRAL = 40           # distancia de color a partir de la cual es personaje
ESCALA_ANALISIS = 320  # ancho al que se mide (rapido y suficiente)


def leer_ppm(datos):
    """Cabecera P6 sin expresiones regulares: P6, ancho, alto, maximo."""
    campos = []
    i = 0
    while len(campos) < 4:
        while i < len(datos) and datos[i:i + 1].isspace():
            i += 1
        if datos[i:i + 1] == b'#':
            while i < len(datos) and datos[i] != 10:
                i += 1
            continue
        j = i
        while j < len(datos) and not datos[j:j + 1].isspace():
            j += 1
        campos.append(datos[i:j])
        i = j
    i += 1
    return int(campos[1]), int(campos[2]), datos[i:]


def mayor_grupo(marca, w, h):
    """Se queda con la mancha mas grande y tira el resto.

    Los videos traen una marca de agua en una esquina. Si cuenta como personaje,
    ensancha la casilla y desvia el encuadre. El personaje siempre es la mancha
    mayor, asi que con quedarse con ella sobra.
    """
    visto = bytearray(w * h)
    mejor = []
    for semilla in range(w * h):
        if not marca[semilla] or visto[semilla]:
            continue
        cola = deque([semilla])
        visto[semilla] = 1
        grupo = []
        while cola:
            i = cola.popleft()
            grupo.append(i)
            x = i % w
            vecinos = ((i - 1, x > 0), (i + 1, x < w - 1),
                       (i - w, i >= w), (i + w, i < (h - 1) * w))
            for j, dentro in vecinos:
                if dentro and marca[j] and not visto[j]:
                    visto[j] = 1
                    cola.append(j)
        if len(grupo) > len(mejor):
            mejor = grupo
    limpio = bytearray(w * h)
    for i in mejor:
        limpio[i] = 1
    return limpio


def silueta(ffmpeg, ruta, ancho):
    """Separa personaje de fondo por distancia de color al fondo real.

    El fondo se mide en las esquinas, asi que da igual que sea gris claro o
    magenta chillon. Antes se suponia fondo claro y personaje oscuro, y con un
    croma de color eso no se sostiene.
    """
    sal = subprocess.run(
        [ffmpeg, '-hide_banner', '-loglevel', 'error', '-i', ruta,
         '-vf', 'scale=%d:-1' % ancho, '-f', 'image2pipe',
         '-vcodec', 'ppm', '-'],
        stdout=subprocess.PIPE, check=True).stdout
    w, h, px = leer_ppm(sal)

    muestra = 4
    ac = [0, 0, 0]
    n = 0
    for x0, y0 in ((0, 0), (w - muestra, 0), (0, h - muestra), (w - muestra, h - muestra)):
        for y in range(y0, y0 + muestra):
            for x in range(x0, x0 + muestra):
                k = (y * w + x) * 3
                ac[0] += px[k]; ac[1] += px[k + 1]; ac[2] += px[k + 2]
                n += 1
    fondo = tuple(v // n for v in ac)

    marca = bytearray(w * h)
    for i in range(w * h):
        k = i * 3
        d = max(abs(px[k] - fondo[0]), abs(px[k + 1] - fondo[1]), abs(px[k + 2] - fondo[2]))
        if d > UMBRAL:
            marca[i] = 1
    marca = mayor_grupo(marca, w, h)

    filas = []
    for y in range(h):
        base = y * w
        filas.append([x for x in range(w) if marca[base + x]])
    return w, h, filas, fondo


def suelo_exacto(ffmpeg, ruta, fondo_aprox, umbral):
    """Fila mas baja del personaje, medida en el PNG a tamano real.

    La medida general se hace sobre la imagen reducida a 320 px de ancho, que es
    rapida y sobra para el eje del cuerpo. Para el suelo no sobra: cada pixel de
    esa reduccion son cuatro de verdad, y el error se traduce en que una animacion
    apoya unos pixeles mas arriba que otra. Como el suelo es un unico numero por
    animacion, sale barato medirlo bien en el fotograma que lo marca.
    """
    sal = subprocess.run(
        [ffmpeg, '-hide_banner', '-loglevel', 'error', '-i', ruta,
         '-f', 'image2pipe', '-vcodec', 'ppm', '-'],
        stdout=subprocess.PIPE, check=True).stdout
    w, h, px = leer_ppm(sal)
    for y in range(h - 1, -1, -1):
        base = y * w
        for x in range(w):
            k = (base + x) * 3
            d = max(abs(px[k] - fondo_aprox[0]), abs(px[k + 1] - fondo_aprox[1]),
                    abs(px[k + 2] - fondo_aprox[2]))
            if d > umbral:
                return y
    return h - 1


def medidas(filas, h):
    ys = [y for y, xs in enumerate(filas) if xs]
    if not ys:
        return None
    arriba, abajo = ys[0], ys[-1]
    alto = abajo - arriba + 1
    # tronco: del 10% al 55% de la altura. Ni gorro ni piernas.
    y0 = arriba + int(alto * 0.10)
    y1 = arriba + int(alto * 0.55)
    xs = [x for y in range(y0, y1 + 1) for x in filas[y]]
    if not xs:
        xs = [x for y in ys for x in filas[y]]
    todos = [x for y in ys for x in filas[y]]
    return {
        'eje': (min(xs) + max(xs)) / 2.0,
        'arriba': arriba, 'abajo': abajo,
        'izq': min(todos), 'der': max(todos),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ffmpeg', required=True)
    ap.add_argument('--entrada', required=True)
    ap.add_argument('--salida', required=True)
    ap.add_argument('--margen', type=int, default=24, help='px de aire alrededor')
    ap.add_argument('--ancho', type=int, default=0, help='forzar ancho de casilla')
    ap.add_argument('--alto', type=int, default=0, help='forzar alto de casilla')
    ap.add_argument('--suelo-margen', type=int, default=-1, dest='suelo_margen',
                    help='px entre la linea de suelo y el borde inferior de la casilla')
    ap.add_argument('--eje', type=float, default=-1,
                    help='eje horizontal fijo, en px del video original (camara quieta)')
    ap.add_argument('--techo', type=int, default=-1,
                    help='fila superior fija de la casilla, en px del video original')
    a = ap.parse_args()

    ficheros = sorted(f for f in os.listdir(a.entrada) if f.lower().endswith('.png'))
    if not ficheros:
        raise SystemExit('No hay PNG en ' + a.entrada)

    print('Midiendo %d fotogramas...' % len(ficheros))
    datos = []
    for i, f in enumerate(ficheros, 1):
        ruta = os.path.join(a.entrada, f)
        w, h, filas, fondo = silueta(a.ffmpeg, ruta, ESCALA_ANALISIS)
        m = medidas(filas, h)
        if m is None:
            raise SystemExit('Fotograma vacio (todo fondo): ' + f)
        m['fichero'] = f
        m['escala'] = w
        m['fondo'] = fondo
        datos.append(m)

    # Tamano real de los PNG, para pasar de la medida a pixeles de verdad
    sal = subprocess.run(
        [a.ffmpeg.replace('ffmpeg.exe', 'ffprobe.exe'), '-v', 'error',
         '-select_streams', 'v:0', '-show_entries', 'stream=width,height',
         '-of', 'csv=p=0:s=x', os.path.join(a.entrada, ficheros[0])],
        stdout=subprocess.PIPE, check=True).stdout.decode().strip()
    W, H = (int(v) for v in sal.split('x'))
    k = W / float(ESCALA_ANALISIS)

    # La casilla tiene que dar cabida al fotograma mas ancho y al mas alto
    if a.eje >= 0:
        eje_fijo = a.eje / k
        necesita_ancho = max(max(d['der'] - eje_fijo, eje_fijo - d['izq']) for d in datos) * 2
    else:
        necesita_ancho = max(max(d['der'] - d['eje'], d['eje'] - d['izq']) for d in datos) * 2
    arriba = min(d['arriba'] for d in datos)
    abajo = max(d['abajo'] for d in datos)

    cw = a.ancho if a.ancho else int(necesita_ancho * k) + 2 * a.margen
    if a.alto:
        ch = a.alto
    elif a.techo >= 0:
        # con techo fijo la casilla no se encuadra: tiene que llegar desde el a lo
        # mas bajo que baje el personaje en toda la animacion
        ch = int(abajo * k) + a.margen - a.techo
    else:
        ch = int((abajo - arriba) * k) + 2 * a.margen
    cw += cw % 2
    ch += ch % 2
    if a.suelo_margen >= 0 and a.techo < 0:
        # El suelo lo marca el fotograma que baja mas; se remide a tamano real.
        peor = max(range(len(datos)), key=lambda i: datos[i]['abajo'])
        fondo_aprox = datos[peor]['fondo']
        abajo_real = suelo_exacto(a.ffmpeg, os.path.join(a.entrada, datos[peor]['fichero']),
                                  fondo_aprox, UMBRAL)
    if a.techo >= 0:
        # Ventana fija: la camara del video no se mueve, asi que el mismo recorte
        # en todas las animaciones ya las deja registradas entre si. Medir el
        # encuadre en cada una las descuadraria una respecto de otra.
        cy = a.techo
    elif a.suelo_margen >= 0:
        # Casilla comun para varias animaciones: la linea de suelo cae siempre a la
        # misma altura dentro de la casilla, medida desde abajo. Cada animacion mide
        # su propio suelo en su video, que no tiene por que estar en la misma fila.
        # Sin esto, cada animacion calcula su encuadre por su cuenta y el personaje
        # pega un salto en pantalla al cambiar de una a otra.
        cy = abajo_real - (ch - a.suelo_margen)
    else:
        cy = int(arriba * k) - a.margen

    if not os.path.isdir(a.salida):
        os.makedirs(a.salida)

    if a.techo >= 0:
        print('Ventana fija: techo en y=%d del original' % a.techo)
    elif a.suelo_margen >= 0:
        print('Suelo medido en y=%d del original (a tamano real), anclado a %d px del borde inferior'
              % (abajo_real, a.suelo_margen))
    if a.eje >= 0:
        print('Eje horizontal fijo en x=%.0f del original' % a.eje)
    print('Casilla %dx%d px, recortando...' % (cw, ch))
    for i, d in enumerate(datos, 1):
        eje = a.eje if a.eje >= 0 else d['eje'] * k
        cx = int(round(eje)) - cw // 2
        # sin salirse del fotograma original
        x = max(0, min(cx, W - cw))
        y = max(0, min(cy, H - ch))
        # Tantas cifras como hagan falta: c_100 detras de c_99, no de c_10.
        destino = os.path.join(a.salida, 'c_%0*d.png' % (max(2, len(str(len(datos)))), i))
        subprocess.run(
            [a.ffmpeg, '-hide_banner', '-loglevel', 'error', '-y',
             '-i', os.path.join(a.entrada, d['fichero']),
             '-vf', 'crop=%d:%d:%d:%d' % (cw, ch, x, y), destino], check=True)
        if cx != x:
            print('  aviso: %s tocaba el borde, se dejo en x=%d' % (d['fichero'], x))

    print('%d fotogramas centrados en %s' % (len(datos), a.salida))
    print('CASILLA=%dx%d' % (cw, ch))
    print('ALTO_PERSONAJE=%d' % int((abajo - arriba) * k))


if __name__ == '__main__':
    main()
