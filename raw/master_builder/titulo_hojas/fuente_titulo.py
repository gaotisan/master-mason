"""Fuente del titulo: Cinzel fija a peso 650, sin solapes y estrechada al 96,8 %.

Las letras del titulo se pintan en el juego con la fuente en MSDF (el shader
saca de ahi la distancia al borde para el bisel y la sombra), y el MSDF dibuja
mal los contornos que se solapan, que una fuente variable como Cinzel tiene. Se
saca una instancia fija con los solapes quitados (fontTools + skia-pathops) y
con el estrechado ya puesto en los contornos y los avances (titulo_sin_letras.py
midio Cinzel 650 al 96,8 % sobre las letras que iban pintadas).

Cinzel va con la licencia SIL OFL: la derivada lleva otro nombre de familia.

Uso: python fuente_titulo.py
"""
import os

from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import OverlapMode, instantiateVariableFont

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
ORIGEN = os.path.join(PROYECTO, "assets", "fonts", "Cinzel-Variable.ttf")
SALIDA = os.path.join(PROYECTO, "assets", "fonts", "TituloMB-Cinzel650.ttf")
PESO = 650
ESTRECHO = 0.968
FAMILIA = "Titulo MB"


def main():
    f = TTFont(ORIGEN)
    f = instantiateVariableFont(f, {"wght": PESO}, overlap=OverlapMode.REMOVE)
    glyf = f["glyf"]
    hmtx = f["hmtx"]
    gs = f.getGlyphSet()
    nuevos = {}
    for nombre in f.getGlyphOrder():
        # descompuesto: si no, los compuestos (A + tilde) se estrecharian dos
        # veces, la suya y la de la letra a la que apuntan
        rec = DecomposingRecordingPen(gs)
        gs[nombre].draw(rec)
        pen = TTGlyphPen(None)
        rec.replay(TransformPen(pen, (ESTRECHO, 0, 0, 1, 0, 0)))
        nuevos[nombre] = pen.glyph()
    for nombre, g in nuevos.items():
        glyf[nombre] = g
        g.recalcBounds(glyf)
        avance, _ = hmtx[nombre]
        hmtx[nombre] = (round(avance * ESTRECHO), getattr(g, "xMin", 0))
    # Familia propia (la derivada no se llama Cinzel)
    for rec in f["name"].names:
        if rec.nameID in (1, 4, 16):
            rec.string = FAMILIA
        elif rec.nameID == 6:
            rec.string = FAMILIA.replace(" ", "")
    f.save(SALIDA)
    print("escrito", SALIDA)


if __name__ == "__main__":
    main()
