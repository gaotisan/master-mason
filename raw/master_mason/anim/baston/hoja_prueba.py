"""Hoja de contacto: baston colocado con seguir.py sobre fotogramas de Magnus.
  python hoja_prueba.py reposo,correr salida.png [paso] [x0,y0,x1,y1] [escala]
Con recorte y escala (para ver de cerca hombros y capucha) sale en filas de 8
con el numero de fotograma; p. ej. los giros enteros, de cerca:
  python hoja_prueba.py giro giro.png 1 70,0,230,200 1.5"""
import math, sys
from PIL import Image, ImageDraw
from celdas import cargar
import seguir

from celdas import PROY
SPR = Image.open(PROY / "assets/characters/baston/baston.png")   # el mismo que usa Godot
L = SPR.height
PIVOTE = 40          # px desde la punta de arriba hasta el punto que se coloca
FUNDA = Image.open(PROY / "assets/characters/baston/funda.png")
FUNDA_DESDE = 0      # px bajo el pivote donde empieza el parche (baston.tscn: centro en 9, alto 18)
CORTE = 48           # de espaldas la madera se corta aqui (baston.gd: CORTE_ESPALDA)


def render(c, x, y, th, delante, funda=0.0):
    H, W = c.shape[:2]
    spr = SPR
    if delante:
        alfa = SPR.getchannel("A").copy()
        alfa.paste(0, (0, CORTE, SPR.width, SPR.height))
        spr = Image.merge("RGBA", (*SPR.split()[:3], alfa))
    if funda > 0:
        spr = spr.copy()
        f = FUNDA.copy()
        f.putalpha(f.getchannel("A").point(lambda v: int(v * funda)))
        spr.alpha_composite(f, (round(SPR.width / 2 - FUNDA.width / 2 - 0.5), PIVOTE + FUNDA_DESDE))
    st = spr.rotate(th, expand=True, resample=Image.BICUBIC)
    v = PIVOTE - L / 2                     # del centro al pivote, a lo largo del eje (arriba = -)
    r = math.radians(th)
    px = st.width / 2 + v * math.sin(r)
    py = st.height / 2 + v * math.cos(r)
    base = Image.new("RGBA", (W, H), (20, 16, 14, 255))
    capa = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    capa.alpha_composite(st, (int(round(x - px)), int(round(y - py)))) if 0 <= int(round(x - px)) else capa.paste(st, (int(round(x - px)), int(round(y - py))), st)
    cuerpo = Image.fromarray(c)
    if delante:
        base.alpha_composite(cuerpo); base.alpha_composite(capa)
    else:
        base.alpha_composite(capa); base.alpha_composite(cuerpo)
    return base


if __name__ == "__main__":
    A = cargar()
    d = seguir.seguir_todo()
    paso_fijo = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    caja = tuple(int(v) for v in sys.argv[4].split(",")) if len(sys.argv) > 4 else None
    escala = float(sys.argv[5]) if len(sys.argv) > 5 else 1.0
    filas = []
    for n in sys.argv[1].split(","):
        cs = A[n]["celdas"]; paso = paso_fijo or max(1, len(cs) // 11)
        fila = []
        for i in range(0, len(cs), paso):
            im = render(cs[i], d[n][i]["x"], d[n][i]["y"], d[n][i]["th"], d[n][i]["delante"], d[n][i]["funda"])
            if caja:
                im = im.crop(caja)
                im = im.resize((round(im.width * escala), round(im.height * escala)), Image.LANCZOS)
                ImageDraw.Draw(im).text((3, 3), str(i), fill=(255, 230, 0, 255))
            fila.append(im)
        if caja:      # de cerca: en filas de 8
            filas += [fila[k:k + 8] for k in range(0, len(fila), 8)]
        else:
            filas.append(fila)
    W = max(sum(i.width for i in f) for f in filas); H = sum(f[0].height for f in filas)
    out = Image.new("RGB", (W, H)); y = 0
    for f in filas:
        x = 0
        for i in f:
            out.paste(i.convert("RGB"), (x, y)); x += i.width
        y += f[0].height
    out.save(sys.argv[2]); print(out.size)
