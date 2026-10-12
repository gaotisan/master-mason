"""La espalda "oficial" para el modo sin baston (2026-10-11).

La espalda del reposo sin baston (secuencia_frontal_sin) salio de su video con otra
tunica: sin el chevron gris de la de con baston y del giro de pie de perfil. Al sacar
el baston de espaldas se veia el cambio de tunica (magnus_sacar_baston_espalda).
Esta es la de con baston (reposo_espalda_cb_000) sin el baston: la garra y el palo
fuera, y la manga derecha (su mano cogia el baston a la altura del pecho) cambiada por
la izquierda espejada en la columna (EJE: el tronco casa con su espejo), cosida por el
borde de dentro de la manga (COSTURA), que es una costura del dibujo. Las manos asoman
oscuras bajo las mangas, como en el giro de pie.
Misma casilla que los reposos (584x800) y en el mismo sitio que la de con baston: pies
centrados en x = 280 (el reposo de frente sin baston los tiene en 291: lo absorbe la
vuelta, que da dos pasitos).
Escribe espalda_sin_baston.png y, en _fuentes, las referencias de Flow (1920x1080,
croma #24D732, la casilla en (668, 286) como las demas): referencia_espalda_sin_baston.png
y referencia_frente_sin_baston.png (reposo_frente_sb_000, el de ahora).
    python hacer_espalda.py
"""
import os
import numpy as np, cv2
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
EJE = 287.5           # la x en la que el tronco (filas 200-330) mejor casa con su espejo
COSTURA = 370.0       # borde de dentro de la manga derecha (el de la izquierda, 205, espejado)
HOMBRO = 245          # por encima el espejo manda desde x = 345: fuera del hombro solo hay garra
FIN_MANGA = 540.0     # por debajo, la tunica de siempre, sin el palo
VERDE = (36, 215, 50)


def pm(a):
    b = a.copy(); b[..., :3] *= b[..., 3:] / 255
    return b


con = np.asarray(Image.open(os.path.join(ANIM, 'magnus_secuencia_frontal', '04_limpios', 'reposo_espalda_cb_000.png')).convert('RGBA')).astype(np.float32)
H, W = con.shape[:2]
ys, xs = np.mgrid[0:H, 0:W]
esp = con[:, np.clip(np.round(2 * EJE - np.arange(W)).astype(int), 0, W - 1)]
desde = np.where(ys < HOMBRO, 345.0, COSTURA)
w = np.clip((xs - desde) / 3.0 + 0.5, 0, 1) * np.clip((FIN_MANGA - ys) / 6.0 + 0.5, 0, 1)
w = cv2.GaussianBlur(w.astype(np.float32), (0, 0), 1.0)[..., None]
m = pm(con) * (1 - w) + pm(esp) * w                       # premultiplicado: sin orlas en la costura
m[(ys >= FIN_MANGA - 6) & (xs >= 395)] = 0                # el palo, por debajo de la manga
al = np.clip(m[..., 3:], 1e-3, 255)
rgb = np.where(m[..., 3:] > 0.5, m[..., :3] * 255 / al, 0)
nueva = np.dstack([rgb, m[..., 3]]).round().clip(0, 255).astype(np.uint8)
n, lab, st, _ = cv2.connectedComponentsWithStats((nueva[..., 3] > 20).astype(np.uint8))
quedan = np.zeros(n, bool); quedan[1 + np.argmax(st[1:, cv2.CC_STAT_AREA])] = True
quedan[1:] |= st[1:, cv2.CC_STAT_AREA] > 400              # las piernas, si salieran sueltas
nueva[~quedan[lab]] = 0                                   # restos del baston
Image.fromarray(nueva, 'RGBA').save(os.path.join(AQUI, 'espalda_sin_baston.png'))


def referencia(sprite, ruta):
    r = Image.new('RGBA', (1920, 1080), VERDE + (255,))
    r.alpha_composite(sprite, (668, 286))
    r.convert('RGB').save(ruta)


referencia(Image.fromarray(nueva, 'RGBA'), os.path.join(ANIM, '_fuentes', 'referencia_espalda_sin_baston.png'))
referencia(Image.open(os.path.join(ANIM, 'magnus_secuencia_frontal_sin', '04_limpios', 'reposo_frente_sb_000.png')).convert('RGBA'),
           os.path.join(ANIM, '_fuentes', 'referencia_frente_sin_baston.png'))
print('hecho')

# La referencia del sacar / guardar de espaldas con la espalda nueva: el baston en la
# correa, en la fila de la correa vacia del reposo con baston (la correa en el mismo
# sitio en los dos modos). La capa la pinta la escena:
#   CAPTURA_DIR=<este job> CAPTURA_ANIM=reposo_espalda_sb CAPTURA_CON=0
#   CAPTURA_NOMBRE=baston_en_correa.png CAPTURA_FILA_DE=reposo_espalda_cb
#   godot --path <proyecto> --script magnus_sacar_baston_frente/capa_espalda.gd
CAPA = os.path.join(AQUI, 'baston_en_correa.png')
if os.path.exists(CAPA):
    c = Image.new('RGBA', (664, 904), (0, 0, 0, 0))       # la casilla de sacar / guardar
    c.alpha_composite(Image.fromarray(nueva, 'RGBA'), (40, 104))
    c.alpha_composite(Image.open(CAPA).convert('RGBA'))
    r = Image.new('RGBA', (1920, 1080), VERDE + (255,))
    r.alpha_composite(c, (628, 182))
    r.convert('RGB').save(os.path.join(ANIM, '_fuentes', 'referencia_baston_espalda_espaldas.png'))
    print('referencia del sacar / guardar de espaldas, con la espalda nueva')
