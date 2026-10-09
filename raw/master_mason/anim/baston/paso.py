"""Mide el andar con el baston en la mano (magnus_andar_baston/04_limpios) para
que en el juego no patine ni vaya a tirones. Escribe paso_medido_<job>.json, que
lee mano.py:

  - dx: lo que se mueve el pie plantado de cada fotograma al siguiente (px
    master, negativo = hacia atras). Es lo que tiene que avanzar el nodo para
    que el pie se quede clavado en el suelo. El viejo cojea con el baston: un
    paso va a ~4 px por fotograma y el otro a ~6, asi que no vale un avance
    unico (con 3 px de hoja = 6 master todo el ciclo, en el paso corto el pie
    resbalaba hacia delante).
  - ciclo: primer fotograma y largo del bucle (el que mejor cierra).
  - arranque: desde que fotograma del principio del video (ya con el baston
    cogido, quieto) se parece mas al reposo con el baston.
  - parada: donde empieza a frenar y en que fotograma queda quieto y casa con
    el reposo (el reposo sale del final del mismo video).
  - pisadas: fotogramas en que un pie toca el suelo.
  - dist: distancia de pose (en pasos normales del ciclo) de cada fotograma
    del ciclo a los primeros de la parada, para entrar en ella sin salto.

Hace falta que 04_limpios este centrado con ventana FIJA (camara del video):
centrado por el tronco, la ventana bailaba +-10 px y era el traqueteo.
  python paso.py [job]   (por defecto magnus_andar_baston_v2)"""
import json
import numpy as np
from PIL import Image
from celdas import PROY

import sys
NOMBRE = sys.argv[1] if len(sys.argv) > 1 else "magnus_andar_baston_v2"
JOB = PROY / "raw/master_mason/anim" / NOMBRE / "04_limpios"
SALIDA = PROY / "raw/master_mason/anim/baston" / f"paso_medido_{NOMBRE}.json"

VIDEO_0 = 12 if NOMBRE == "magnus_andar_baston" else 1   # c_001 = ese fotograma del video


def cargar_todo():
    fs = sorted(JOB.glob("c_*.png"))
    return [np.array(Image.open(f).convert("RGBA")) for f in fs]


def mascara(a):
    return a[..., 3] > 128


def pequeno(a):
    """Color premultiplicado a un cuarto, para comparar poses."""
    im = Image.fromarray(a).reduce(4)
    b = np.asarray(im).astype(np.float32)
    return b[..., :3] * (b[..., 3:] / 255.0)


def dist(p, q):
    return float(np.abs(p - q).mean())


def desplazamiento_pie(m0, m1, suelo):
    """Cuanto se mueve lo que toca el suelo (pie plantado y punta del baston)
    de un fotograma al siguiente: el desplazamiento horizontal que mejor
    superpone la franja de 10 filas sobre el suelo. Al cuarto de pixel."""
    y0, y1 = suelo - 9, suelo + 1
    a = m0[y0:y1].astype(np.float32)
    b = m1[y0:y1].astype(np.float32)
    xs = np.arange(a.shape[1], dtype=np.float32)
    mejor = None
    for dx in np.arange(-16, 6.01, 0.25):
        sh = np.stack([np.interp(xs - dx, xs, fila, left=0, right=0) for fila in a])
        e = float(np.abs(sh - b).sum())
        if mejor is None or e < mejor[0]:
            mejor = (e, float(dx))
    return mejor[1]


def contactos(m, suelo):
    """Trozos que tocan el suelo (3 filas), como (x0, x1)."""
    banda = m[suelo - 2:suelo + 1].any(0)
    xs = np.where(banda)[0]
    if len(xs) == 0:
        return []
    partes = np.split(xs, np.where(np.diff(xs) > 3)[0] + 1)
    return [(int(p[0]), int(p[-1])) for p in partes]


def main():
    A = cargar_todo()
    n = len(A)
    M = [mascara(a) for a in A]
    bajos = [int(np.where(m.any(1))[0].max()) for m in M]
    suelo = int(np.median(bajos))
    print(n, "fotogramas; suelo en la fila", suelo)
    P = [pequeno(a) for a in A]
    dx = [desplazamiento_pie(M[k], M[k + 1], suelo) for k in range(n - 1)] + [0.0]
    if NOMBRE.endswith("_bucle"):
        # video hecho bucle (inicio = fin): solo hace falta lo que avanza cada
        # fotograma, y el ultimo vuelve al primero
        dx[-1] = desplazamiento_pie(M[-1], M[0], suelo)
        SALIDA.write_text(json.dumps({"video_0": VIDEO_0, "suelo": suelo,
                                      "dx": [round(x, 2) for x in dx]}, indent=1), encoding="utf-8")
        print("dx", [round(x, 1) for x in dx])
        return
    v = -np.array(dx)

    # Tramo de crucero: velocidad del pie por encima del 70 % de la mediana
    # de la zona alta.
    alta = np.median(v[v > 2])
    crucero = np.where(v > 0.7 * alta)[0]
    c0, c1 = int(crucero[0]), int(crucero[-1])
    print("crucero aprox", c0 + 1, "-", c1 + 1, "(c_), velocidad mediana", round(float(alta), 2))

    # Ciclo: el par (s, s+L) que mejor cierra dentro del crucero.
    paso = np.median([dist(P[k], P[k + 1]) for k in range(c0, c1)])
    mejor = None
    for L in range(40, 57):
        for s in range(c0 + 4, c1 - L - 4):
            d = dist(P[s], P[s + L]) / paso
            if mejor is None or d < mejor[0]:
                mejor = (d, s, L)
    d_ciclo, s, L = mejor
    print("ciclo c_%03d-c_%03d (%d), cierra a %.2f pasos" % (s + 1, s + L, L, d_ciclo))

    # Reposo: el final del video, quieto (velocidad 0 y casi sin cambio).
    quieto = [k for k in range(n - 1) if abs(v[k]) < 0.1 and dist(P[k], P[k + 1]) / paso < 0.5]
    r0 = next(k for k in quieto if all(q in quieto for q in range(k, min(k + 15, n - 1))))
    print("reposo desde c_%03d" % (r0 + 1))

    # Arranque: entre los primeros (quieto, baston ya en la mano) el que mas se
    # parece al reposo; de ahi en adelante hasta el ciclo.
    cand = range(0, 12)
    da = [dist(P[k], P[r0]) / paso for k in cand]
    a0 = int(cand[int(np.argmin(da))])
    print("arranque desde c_%03d (a %.2f pasos del reposo)" % (a0 + 1, min(da)), [round(x, 2) for x in da])

    # Parada: empieza donde la velocidad cae por debajo del crucero y acaba en
    # el reposo. Su final: el primer fotograma, ya quieto, que casa con r0.
    p0 = c1 + 1
    while p0 > s + L and v[p0 - 1] < 0.8 * alta:
        p0 -= 1
    fin = [k for k in range(p0, r0 + 1) if dist(P[k], P[r0]) / paso < 0.7 and abs(v[k]) < 0.1]
    p1 = fin[0] if fin else r0
    print("parada c_%03d-c_%03d" % (p0 + 1, p1 + 1))

    # Entrada en la parada desde cada fotograma del ciclo: el de la parada mas
    # parecido entre sus primeros 8 (y por cual entrar).
    dist_parada, pose = [], []
    for i in range(L):
        ds = [dist(P[s + i], P[p0 + j]) / paso for j in range(8)]
        j = int(np.argmin(ds))
        dist_parada.append(round(ds[j], 2))
        pose.append(j)
    print("dist parada", dist_parada)

    # Pisadas: un contacto ancho (pie, no la punta del baston) que no estaba
    # en el fotograma anterior (llevado con el desplazamiento del suelo).
    pisa = []
    for k in range(1, n):
        prev = [(x0 + dx[k - 1], x1 + dx[k - 1]) for x0, x1 in contactos(M[k - 1], suelo) if x1 - x0 >= 18]
        for x0, x1 in contactos(M[k], suelo):
            if x1 - x0 < 18:
                continue
            if not any(x0 <= b1 + 4 and x1 >= b0 - 4 for b0, b1 in prev):
                pisa.append(k)
                break
    print("pisadas", [p + 1 for p in pisa])

    SALIDA.write_text(json.dumps({
        "video_0": VIDEO_0, "suelo": suelo, "dx": [round(x, 2) for x in dx],
        "ciclo": [s, L], "cierre": round(d_ciclo, 2), "arranque": a0,
        "parada": [p0, p1], "reposo": r0, "dist_parada": dist_parada,
        "pose_parada": pose, "pisadas": pisa, "paso_normal": round(float(paso), 3),
    }, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
