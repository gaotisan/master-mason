"""Donde va la bola en el sacar de espaldas (2026-10-12): la garra seguida en dos pasadas
COMPLETAS (desde el principio con la plantilla de la referencia sin baston y desde el
final con la de con baston), pasando poco a poco de una a otra a lo largo del gesto.

Antes (garra.py --espalda con [1, 66] y [192, 67]): con la casilla de 904 la garra se
salia por arriba al levantar el baston (se cortaba en el dibujo) y la busqueda no podia
subir de y = 54, asi que la bola se quedaba en el palo, por debajo de la garra (41-51 de
la animacion); y en el 66/67, donde se juntaban las dos pasadas, saltaba 38 px. Ahora:
casilla de 952 (montar.py --my 152), garra.py con borde en los mapas y este empalme.
    python seguir_garra.py      -> garra.json
"""
import importlib.util, json, math, os

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
JOB = os.path.basename(AQUI)
spec = importlib.util.spec_from_file_location('garra', os.path.join(ANIM, 'peregrino_sacar_baston_frente', 'garra.py'))
G = importlib.util.module_from_spec(spec); spec.loader.exec_module(G)
G.MY = 152                                   # la casilla de este job (montar.py --my 152)
G.REF_ORIGEN = (668 - G.MX, 286 - G.MY)
DESDE, HASTA = 19, 100                       # el tramo que usa animar.py

b_sin, b_con = G.bolas_de_referencia_espalda()
m_sin = G.madera(G.referencia('referencia_baston_espalda_espaldas.png'))
m_con = G.madera(G.referencia('referencia_baston_mano_espaldas.png'))
ida = G.seguir(JOB, list(range(1, 193)), m_sin, b_sin)
vuelta = G.seguir(JOB, list(range(192, 0, -1)), m_con, b_con)

dist = {k: math.hypot(ida[k][0] - vuelta[k][0], ida[k][1] - vuelta[k][1]) for k in range(1, 193)}
# Las dos pasadas van paralelas (8-12 px todo el tramo: donde cada referencia pone la
# bola en la garra), asi que no se cambia de una a otra en un fotograma (saltaria):
# se pasa poco a poco de la de ida (al principio, la referencia sin baston) a la de
# vuelta (al final, la de con baston) a lo largo de todo el tramo.
def peso(k):
    t = min(max((k - DESDE) / float(HASTA - DESDE), 0.0), 1.0)
    return t * t * (3 - 2 * t)


res = {}
for k in range(1, 193):
    w = peso(k)
    res[k] = tuple(ida[k][i] * (1 - w) + vuelta[k][i] * w for i in range(3)) + (min(ida[k][3], vuelta[k][3]),)
json.dump({str(k): v for k, v in sorted(res.items())}, open(os.path.join(AQUI, 'garra.json'), 'w'), indent=0)
flojos = [k for k in range(DESDE, HASTA + 1) if res[k][3] < 0.9]
print('por debajo de 0,90 en %d-%d: %s' % (DESDE, HASTA, flojos))
print('distancia entre pasadas, %d-%d: %s' % (DESDE, HASTA, ' '.join('%d:%.0f' % (k, dist[k]) for k in range(DESDE, HASTA + 1, 3))))
