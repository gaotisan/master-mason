"""Quita el fondo liso de una secuencia y deja alfa limpio.

Por que no vale una clave de color: en este material la barba blanca esta a
distancia 12-16 del gris del fondo, y el ruido de compresion del propio fondo
llega a 9. Cualquier umbral global que se coma el fondo se come la barba.

Lo que si funciona: el fondo es lo que se alcanza **desde el borde del cuadro**.
Se rellena desde fuera con tolerancia corta, que no tiene por donde entrar en la
barba, y el personaje es todo lo que quede sin alcanzar.

Despues, solo en la frontera, se calcula cuanta mezcla con el fondo hay (alfa) y
se deshace, para que el borde no arrastre el tinte claro:

    C_observado = a * F + (1-a) * Fondo   ->   F = (C - (1-a)*Fondo) / a

La referencia del alfa se toma de los pixeles opacos vecinos: junto a la barba la
referencia es la barba, junto al abrigo es el abrigo. Por eso la barba sobrevive.

Solo necesita ffmpeg: los pixeles entran y salen por tuberia, sin librerias.
"""
import argparse, os, re, subprocess
from collections import deque

ANILLO_RADIO = 3
PANZA = 2
RADIO_BORDE = 6
MARGEN_COLOR = 12


def tiene_panza(es_fondo, i, w, h, radio):
    """Cierto si ningun pixel de fondo cae dentro del cuadrado de lado 2*radio."""
    x, y = i % w, i // w
    if x < radio or y < radio or x >= w - radio or y >= h - radio:
        return False
    for dy in range(-radio, radio + 1):
        base = (y + dy) * w
        for dx in range(-radio, radio + 1):
            if es_fondo[base + x + dx]:
                return False
    return True


def leer_rgb(ffmpeg, ruta):
    d = subprocess.run(
        [ffmpeg, '-hide_banner', '-loglevel', 'error', '-i', ruta,
         '-f', 'image2pipe', '-pix_fmt', 'rgb24', '-vcodec', 'ppm', '-'],
        stdout=subprocess.PIPE, check=True).stdout
    m = re.match(rb'P6\s+(\d+)\s+(\d+)\s+(\d+)\s', d)
    if not m:
        raise SystemExit('ffmpeg no devolvio un PPM valido para ' + ruta)
    return int(m.group(1)), int(m.group(2)), d[m.end():]


def escribir_rgba(ffmpeg, destino, w, h, datos):
    subprocess.run(
        [ffmpeg, '-hide_banner', '-loglevel', 'error', '-y',
         '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', '%dx%d' % (w, h), '-i', '-',
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


def marcar_bolsas(dist, es_fondo, w, h, tol, minimo, anillo_min, abertura):
    """Fondo encerrado por el personaje: el hueco entre el abrigo y la pierna.

    El relleno desde el borde no puede entrar ahi, asi que queda opaco y sobre una
    escena oscura se ve una mancha clara.

    No vale separarlo por color: en algun fotograma la bolsa esta a distancia 15
    del fondo y la barba a 16. Tampoco basta con exigir que no toque el fondo
    exterior: trozos altos de la barba quedan encerrados entre gorro, cara y
    abrigo, y se perderian.

    Lo que si los separa es **que tienen alrededor**. Una bolsa de fondo esta
    rodeada de abrigo o pierna, que son oscuros y quedan muy lejos del color del
    fondo. Un trozo de barba esta rodeado de mas barba, que queda cerca. Asi que
    se exige, ademas del encierro, que el anillo que rodea al grupo sea oscuro.
    """
    candidato = bytearray(w * h)
    for i in range(w * h):
        if not es_fondo[i] and dist[i] <= tol:
            candidato[i] = 1

    visto = bytearray(w * h)
    bolsas = 0
    pixeles = 0
    for semilla in range(w * h):
        if not candidato[semilla] or visto[semilla]:
            continue
        cola = deque([semilla])
        visto[semilla] = 1
        grupo = []
        contacto = 0   # cuanto del contorno da al fondo exterior
        macizo = 0     # cuanto da al personaje
        while cola:
            i = cola.popleft()
            grupo.append(i)
            x = i % w
            vecinos = ((i - 1, x > 0), (i + 1, x < w - 1),
                       (i - w, i >= w), (i + w, i < (h - 1) * w))
            for j, dentro in vecinos:
                if not dentro:
                    continue
                if es_fondo[j]:
                    contacto += 1
                elif candidato[j]:
                    if not visto[j]:
                        visto[j] = 1
                        cola.append(j)
                else:
                    macizo += 1
        if len(grupo) < minimo:
            continue
        contorno = contacto + macizo
        if contorno == 0 or contacto > contorno * abertura:
            continue
        # La orla de antialiasing que rodea al personaje entero tambien es clara y
        # tambien tiene abrigo alrededor. Lo que la delata es que es una **banda
        # fina**: ninguno de sus pixeles esta a mas de dos de distancia del fondo.
        # Una bolsa de verdad tiene panza. Se exige al menos un pixel con fondo.
        if not any(tiene_panza(es_fondo, i, w, h, PANZA) for i in grupo):
            continue

        # El anillo se mide unos pixeles mas afuera: pegado al grupo solo hay
        # antialiasing, que no es ni fondo ni abrigo y falsearia la medida.
        dentro_grupo = set(grupo)
        anillo = []
        for i in grupo:
            x, y = i % w, i // w
            for dy in range(-ANILLO_RADIO, ANILLO_RADIO + 1):
                yy = y + dy
                if yy < 0 or yy >= h:
                    continue
                base = yy * w
                for dx in range(-ANILLO_RADIO, ANILLO_RADIO + 1):
                    xx = x + dx
                    if 0 <= xx < w:
                        j = base + xx
                        if j not in dentro_grupo and not candidato[j] and not es_fondo[j]:
                            anillo.append(dist[j])
        if not anillo:
            continue
        anillo.sort()
        if anillo[len(anillo) // 2] < anillo_min:
            continue
        for i in grupo:
            es_fondo[i] = 1
        bolsas += 1
        pixeles += len(grupo)
    return bolsas, pixeles


def relleno_desde_borde(dist, w, h, tol):
    """Marca como fondo solo lo que se alcanza desde el borde del cuadro."""
    fondo = bytearray(w * h)
    q = deque()
    def sembrar(i):
        if not fondo[i] and dist[i] <= tol:
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


def quitar_motas(alfa, salida, w, h, minimo):
    """Borra islas sueltas de 1-3 pixeles que deja la descontaminacion del borde.

    Son pixeles claros con alfa bajo, desconectados del personaje. A tamano real
    apenas se ven, pero en movimiento parpadean. El cuerpo nunca se toca: se
    conserva siempre el grupo mas grande.
    """
    visto = bytearray(w * h)
    grupos = []
    for semilla in range(w * h):
        if not alfa[semilla] or visto[semilla]:
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
                if dentro and not visto[j] and alfa[j]:
                    visto[j] = 1
                    cola.append(j)
        grupos.append(grupo)
    if not grupos:
        return 0
    mayor = max(range(len(grupos)), key=lambda k: len(grupos[k]))
    borradas = 0
    for k, grupo in enumerate(grupos):
        if k == mayor or len(grupo) >= minimo:
            continue
        for i in grupo:
            alfa[i] = 0
            salida[i * 4:i * 4 + 3] = bytes(3)
        borradas += 1
    return borradas


def quitar_derrame(salida, alfa, w, h, fondo_col, umbral, umbral_borde, objetivo):
    """Le quita al personaje el tinte del croma que se le queda pegado.

    Con un fondo saturado, las partes finas -- punta del pie, punta de la barba --
    son todas borde: no tienen interior del que sacar referencia y se quedan
    tenidas del color del fondo. Esto lo corrige por color, sin tocar geometria.

    Se miran los canales que el fondo tiene altos (en magenta, rojo y azul) y se
    les recorta lo que sobresalen del canal bajo. Las zonas reales del personaje
    no cumplen la condicion: el abrigo tiene R-G=25 pero B-G=-1, el gorro tiene
    R-G=-10, la barba es neutra. Solo el tinte tiene los dos altos a la vez.

    Con un fondo gris esto no se aplica: no hay canal dominante que recortar, y
    si se forzara desaturaria el marron del abrigo.
    """
    if max(fondo_col) - min(fondo_col) < 60:
        return 0
    medio = (max(fondo_col) + min(fondo_col)) / 2.0
    altos = [c for c in range(3) if fondo_col[c] > medio]
    bajos = [c for c in range(3) if fondo_col[c] <= medio]
    if not altos or not bajos:
        return 0

    # El derrame del croma ocurre en el BORDE: es luz del fondo rebotando en el
    # personaje. En el interior, lo que se parece al croma es color propio del
    # abrigo. Asi que cerca del borde se aprieta y en el interior no se toca.
    cerca = bytearray(w * h)
    frontera_alfa = []
    for i in range(w * h):
        if alfa[i]:
            continue
        x, y = i % w, i // w
        vecinos = ((i - 1, x > 0), (i + 1, x < w - 1),
                   (i - w, i >= w), (i + w, i < (h - 1) * w))
        if any(dentro and alfa[j] for j, dentro in vecinos):
            frontera_alfa.append(i)
    for i in frontera_alfa:
        x, y = i % w, i // w
        for dy in range(-RADIO_BORDE, RADIO_BORDE + 1):
            yy = y + dy
            if yy < 0 or yy >= h:
                continue
            base_y = yy * w
            for dx in range(-RADIO_BORDE, RADIO_BORDE + 1):
                xx = x + dx
                if 0 <= xx < w:
                    cerca[base_y + xx] = 1

    tocados = 0
    for i in range(w * h):
        if not alfa[i]:
            continue
        j = i * 4
        base = max(salida[j + c] for c in bajos)
        exceso = min(salida[j + c] - base for c in altos)
        limite = umbral_borde if cerca[i] else umbral
        if exceso <= limite:
            continue
        # Se detecta con 'umbral' pero se corrige hasta 'objetivo'. Usar el mismo
        # numero para las dos cosas dejaba todo el pixel contaminado clavado justo
        # en el umbral, que es lo que se veia de verde en las puntas de los pies y
        # de la barba: ahi la estructura es tan fina que es toda borde y no hay
        # interior del que sacar el color bueno.
        recorte = exceso - objetivo
        for c in altos:
            v = salida[j + c] - recorte
            salida[j + c] = 0 if v < 0 else v
        tocados += 1
    return tocados


def procesar(ffmpeg, origen, destino, tol, radio, tol_hueco, min_hueco, anillo_min,
             abertura, min_mota, umbral_derrame, umbral_borde, objetivo_derrame,
             fondo_fijo=None):
    w, h, px = leer_rgb(ffmpeg, origen)
    fondo_col = fondo_fijo or color_fondo(px, w, h)

    canales = []
    for c in range(3):
        tabla = bytes(min(255, abs(v - fondo_col[c])) for v in range(256))
        canales.append(px[c::3].translate(tabla))
    dist = bytes(map(max, canales[0], canales[1], canales[2]))

    es_fondo = relleno_desde_borde(dist, w, h, tol)
    bolsas, px_bolsas = marcar_bolsas(dist, es_fondo, w, h, tol_hueco, min_hueco, anillo_min, abertura)

    # Frontera: pixeles del personaje que tocan el fondo en un radio corto.
    # Solo estos llevan alfa parcial; el resto queda opaco y sin tocar.
    frontera = bytearray(w * h)
    for i in range(w * h):
        if es_fondo[i]:
            continue
        x, y = i % w, i // w
        tocado = False
        for dy in range(-radio, radio + 1):
            yy = y + dy
            if yy < 0 or yy >= h:
                continue
            base = yy * w
            for dx in range(-radio, radio + 1):
                xx = x + dx
                if 0 <= xx < w and es_fondo[base + xx]:
                    tocado = True
                    break
            if tocado:
                break
        if tocado:
            frontera[i] = 1

    alfa = bytearray(w * h)
    salida = bytearray(w * h * 4)
    salida[0::4] = px[0::3]
    salida[1::4] = px[1::3]
    salida[2::4] = px[2::3]

    nucleo = radio * 2
    tocados = 0
    for i in range(w * h):
        if es_fondo[i]:
            continue
        if not frontera[i]:
            alfa[i] = 255
            continue
        x, y = i % w, i // w
        # Hacia que color mezcla este pixel. Se busca anillo a anillo y se para en
        # el primero que traiga pixeles macizos: promediar una caja entera mete el
        # abrigo oscuro en la cuenta de una mano palida, la referencia se dispara,
        # el alfa sale demasiado bajo y la descontaminacion revienta el color a
        # blanco. Es lo que dejaba motas claras junto a manos, pies y barba.
        refs = []
        cmin = [255, 255, 255]
        cmax = [0, 0, 0]
        for r in range(1, nucleo + 1):
            for dy in range(-r, r + 1):
                yy = y + dy
                if yy < 0 or yy >= h:
                    continue
                base = yy * w
                borde_y = abs(dy) == r
                for dx in range(-r, r + 1):
                    if not borde_y and abs(dx) != r:
                        continue
                    xx = x + dx
                    if not (0 <= xx < w):
                        continue
                    j = base + xx
                    if not es_fondo[j] and not frontera[j]:
                        refs.append(dist[j])
                        for c in range(3):
                            v = px[j * 3 + c]
                            if v < cmin[c]:
                                cmin[c] = v
                            if v > cmax[c]:
                                cmax[c] = v
            if len(refs) >= 3:
                break
        if not refs:
            alfa[i] = 255
            continue
        refs.sort()
        ref = refs[len(refs) // 2]
        if ref <= 0:
            alfa[i] = 255
            continue
        a = dist[i] / float(ref)
        if a >= 1.0:
            alfa[i] = 255
            continue
        alfa[i] = max(1, int(round(a * 255)))
        j = i * 4
        for c in range(3):
            v = (px[i * 3 + c] - (1.0 - a) * fondo_col[c]) / a
            # y ademas no puede acabar mas claro ni mas oscuro que sus vecinos
            bajo = cmin[c] - MARGEN_COLOR
            alto = cmax[c] + MARGEN_COLOR
            if v < bajo:
                v = bajo
            elif v > alto:
                v = alto
            salida[j + c] = 0 if v < 0 else (255 if v > 255 else int(round(v)))
        tocados += 1

    derrame = quitar_derrame(salida, alfa, w, h, fondo_col, umbral_derrame,
                             umbral_borde, objetivo_derrame)
    motas = quitar_motas(alfa, salida, w, h, min_mota)
    salida[3::4] = alfa
    escribir_rgba(ffmpeg, destino, w, h, salida)
    opacos = sum(1 for v in alfa if v == 255)
    return (fondo_col, sum(es_fondo), tocados, opacos, w * h, bolsas, px_bolsas,
            motas, derrame)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ffmpeg', required=True)
    ap.add_argument('--entrada', required=True)
    ap.add_argument('--salida', required=True)
    ap.add_argument('--tolerancia', type=int, default=10,
                    help='cuanto puede alejarse del fondo y seguir siendo fondo')
    ap.add_argument('--radio', type=int, default=2, help='grosor de la frontera')
    ap.add_argument('--hueco', type=int, default=28,
                    help='hasta aqui una bolsa encerrada se considera fondo')
    ap.add_argument('--hueco-min', type=int, default=10, dest='hueco_min',
                    help='tamano minimo de bolsa')
    ap.add_argument('--anillo', type=int, default=60, dest='anillo',
                    help='cuanto de oscuro debe ser lo que rodea a una bolsa')
    ap.add_argument('--abertura', type=float, default=0.42,
                    help='fraccion del contorno de una bolsa que puede dar al exterior')
    ap.add_argument('--motas', type=int, default=16,
                    help='islas sueltas menores que esto se borran')
    ap.add_argument('--derrame', type=int, default=25,
                    help='cuanto tinte del croma se tolera antes de recortarlo')
    ap.add_argument('--derrame-borde', type=int, default=8, dest='derrame_borde',
                    help='umbral de deteccion cerca del borde, donde si hay derrame')
    ap.add_argument('--derrame-objetivo', type=int, default=3, dest='derrame_objetivo',
                    help='cuanto tinte se deja tras corregir (no el umbral de deteccion)')
    ap.add_argument('--fondo', default='')
    a = ap.parse_args()

    fijo = tuple(int(v) for v in a.fondo.split(',')) if a.fondo else None

    ficheros = sorted(f for f in os.listdir(a.entrada) if f.lower().endswith('.png'))
    if not ficheros:
        raise SystemExit('No hay PNG en ' + a.entrada)
    if not os.path.isdir(a.salida):
        os.makedirs(a.salida)

    print('Quitando el fondo de %d imagenes (tolerancia %d, radio %d)...'
          % (len(ficheros), a.tolerancia, a.radio))
    for f in ficheros:
        (col, nfondo, tocados, opacos, total, bolsas, px_bolsas,
         motas, derrame) = procesar(
            a.ffmpeg, os.path.join(a.entrada, f), os.path.join(a.salida, f),
            a.tolerancia, a.radio, a.hueco, a.hueco_min, a.anillo, a.abertura,
            a.motas, a.derrame, a.derrame_borde, a.derrame_objetivo, fijo)
        aviso = ('  bolsas=%d (%d px)' % (bolsas, px_bolsas)) if bolsas else ''
        if motas:
            aviso += '  motas=%d' % motas
        if derrame:
            aviso += '  derrame=%d px' % derrame
        print('  %-12s fondo=%s  transparente=%5.1f%%  opaco=%5.1f%%  frontera=%5d px%s'
              % (f, str(col), 100.0 * nfondo / total, 100.0 * opacos / total, tocados, aviso))
    print('Listo: %s' % a.salida)


if __name__ == '__main__':
    main()
