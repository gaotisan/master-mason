"""Mide el margen transparente que queda dentro de cada casilla.

Una hoja de sprites es un atlas: Godot muestrea con filtrado bilineal y, si
genera mipmaps, cada nivel promedia bloques de la hoja ENTERA, sin saber donde
acaba una casilla y empieza la siguiente. Si el personaje llega al borde de su
casilla, el vecino se cuela por ese borde.

El margen transparente que queda alrededor del personaje hace de separacion. Un
margen de M pixeles aguanta mientras el texel del mipmap mida menos que M: el
nivel L usa texels de 2^L pixeles y se emplea a escala 1/2^L, asi que el atlas
esta limpio hasta una escala de 1/M mas o menos.

Se mide sobre el master de 04_limpios y se convierte a pixeles de la hoja final
dividiendo por la escala, que es donde pasa el muestreo.
"""
import argparse, glob, os, struct, sys, zlib


def alfa(ruta):
    d = open(ruta, 'rb').read()
    i, idat, ct = 8, b'', None
    while i < len(d):
        ln = struct.unpack('>I', d[i:i + 4])[0]
        tipo = d[i + 4:i + 8]
        if tipo == b'IHDR':
            w, h, prof, ct = struct.unpack('>IIBB', d[i + 8:i + 18])
        elif tipo == b'IDAT':
            idat += d[i + 8:i + 8 + ln]
        elif tipo == b'IEND':
            break
        i += 12 + ln
    if ct != 6:
        return None                      # sin canal alfa: no hay margen que medir
    raw = zlib.decompress(idat)
    bpp, stride = 4, w * 4
    prev, o, filas = bytearray(stride), 0, []
    for _ in range(h):
        f = raw[o]; o += 1
        lin = bytearray(raw[o:o + stride]); o += stride
        if f == 1:
            for x in range(bpp, stride):
                lin[x] = (lin[x] + lin[x - bpp]) & 255
        elif f == 2:
            for x in range(stride):
                lin[x] = (lin[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride):
                a = lin[x - bpp] if x >= bpp else 0
                lin[x] = (lin[x] + ((a + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(stride):
                a = lin[x - bpp] if x >= bpp else 0
                c = prev[x - bpp] if x >= bpp else 0
                b = prev[x]
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                lin[x] = (lin[x] + (a if (pa <= pb and pa <= pc) else (b if pb <= pc else c))) & 255
        filas.append(lin[3::4])
        prev = lin
    return w, h, filas


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('carpeta')
    ap.add_argument('--escala', type=int, default=1)
    ap.add_argument('--minimo', type=int, default=8,
                    help='margen minimo en pixeles de la hoja final')
    ap.add_argument('--umbral', type=int, default=8, help='alfa a partir del cual cuenta')
    a = ap.parse_args()

    peor = [10 ** 9] * 4
    donde = ''
    for p in sorted(glob.glob(os.path.join(a.carpeta, '*.png'))):
        r = alfa(p)
        if r is None:
            print('  (%s no tiene canal alfa; sin fondo transparente no hay atlas que proteger)'
                  % os.path.basename(p))
            return 0
        w, h, filas = r
        xs, ys = [], []
        for y in range(h):
            fila = filas[y]
            v = [x for x in range(w) if fila[x] > a.umbral]
            if v:
                ys.append(y); xs.append((v[0], v[-1]))
        if not xs:
            continue
        m = [min(v[0] for v in xs), w - 1 - max(v[1] for v in xs),
             ys[0], h - 1 - ys[-1]]
        for k in range(4):
            if m[k] < peor[k]:
                peor[k] = m[k]
                donde = os.path.basename(p)

    if peor[0] > 10 ** 8:
        return 0
    final = [v // a.escala for v in peor]
    m = min(final)
    print('  margen en la casilla: izq %d  der %d  arr %d  abj %d px de hoja (el mas justo, %s)'
          % (final[0], final[1], final[2], final[3], donde))
    if m < a.minimo:
        print('  AVISO: solo %d px de margen. El atlas empieza a mezclar casillas vecinas' % m)
        print('         en cuanto Godot use un nivel de mipmap con texels mayores que eso,')
        print('         o sea por debajo de 1/%d de escala en pantalla. Opciones: agrandar la' % max(1, m))
        print('         casilla en centrar.ps1, o importar la hoja sin mipmaps.')
        return 1
    print('  margen suficiente: el atlas aguanta hasta 1/%d de escala sin mezclar casillas.' % m)
    return 0


if __name__ == '__main__':
    sys.exit(main())
