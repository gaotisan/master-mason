"""Paredes del sarcofago a los lados de la ventana (prueba 2026-10-22).

El usuario amplio el fondo del ataud con Midjourney a la izquierda y a la
derecha (dos imagenes de 2912x1632 que repiten la mitad de la original). Aqui
se alinean con la original (SIFT, escala + giro + desplazamiento) y se guarda
de cada una solo lo nuevo, con una franja de fundido que entra en el borde
oscuro de la original:

  ataud_lado_izq.png   RGBA; su borde derecho cae en x = ANCHO_FUNDIDO de la original
  ataud_lado_der.png   RGBA; su borde izquierdo cae en x = 2912 - ANCHO_FUNDIDO

Se oscurecen hacia fuera: la unica luz es la que entra por la ventana.

    python -I lados.py sarcophagus_base_16_9.png ampliada_izq.png ampliada_der.png <salida>
"""
import sys
import numpy as np
import cv2

base_p, izq_p, der_p, salida = sys.argv[1:5]
O = cv2.imread(base_p)
H, W = O.shape[:2]
FUNDIDO = 130  # px de la original que tapa la franja de fundido
sift = cv2.SIFT_create(6000)


def alinear(X, lado):
    """Matriz que lleva X a coordenadas de la original."""
    g1 = cv2.cvtColor(X, cv2.COLOR_BGR2GRAY)
    g2 = cv2.cvtColor(O, cv2.COLOR_BGR2GRAY)
    m1 = np.zeros_like(g1)
    m2 = np.zeros_like(g2)
    if lado == "izq":
        m1[:, W // 2:] = 255
        m2[:, :W // 2 + 150] = 255
    else:
        m1[:, :W // 2] = 255
        m2[:, W // 2 - 150:] = 255
    k1, d1 = sift.detectAndCompute(g1, m1)
    k2, d2 = sift.detectAndCompute(g2, m2)
    pares = [m for m, n in cv2.BFMatcher().knnMatch(d1, d2, k=2) if m.distance < 0.7 * n.distance]
    p1 = np.float32([k1[m.queryIdx].pt for m in pares])
    p2 = np.float32([k2[m.trainIdx].pt for m in pares])
    M, ok = cv2.estimateAffinePartial2D(p1, p2, method=cv2.RANSAC, ransacReprojThreshold=3.0)
    print(lado, "puntos", int(ok.sum()), "desplazamiento", M[:, 2].round(1).tolist())
    return M


for lado, ruta in (("izq", izq_p), ("der", der_p)):
    X = cv2.imread(ruta)
    M = alinear(X, lado)
    # Ancho nuevo: lo que queda fuera de la original.
    nuevo = int(round(-M[0, 2])) if lado == "izq" else int(round(M[0, 2] + W * M[0, 0] - W))
    nuevo -= 4  # el canto del lienzo de Midjourney puede venir sucio
    ancho = nuevo + FUNDIDO
    T = M.copy()
    # Origen del recorte en coordenadas de la original.
    x0 = -nuevo if lado == "izq" else W - FUNDIDO
    T[0, 2] -= x0
    img = cv2.warpAffine(X, T, (ancho, H), flags=cv2.INTER_LANCZOS4, borderMode=cv2.BORDER_REPLICATE)
    x = np.arange(ancho, dtype=np.float32)
    # Distancia a la ventana (0 en la junta con la original, 1 en el borde de fuera).
    lejos = (nuevo - x) / nuevo if lado == "izq" else (x - FUNDIDO) / nuevo
    lejos = np.clip(lejos, 0, 1)
    luz = 0.9 - 0.55 * lejos ** 0.8
    img = (img.astype(np.float32) * luz[None, :, None]).clip(0, 255).astype(np.uint8)
    # Alfa: opaco en lo nuevo, se funde dentro del borde de la original.
    if lado == "izq":
        a = np.clip((ancho - 20 - x) / (FUNDIDO - 20), 0, 1)
    else:
        a = np.clip((x - 20) / (FUNDIDO - 20), 0, 1)
    a = a * a * (3 - 2 * a)
    rgba = np.dstack([img, np.repeat((a * 255).astype(np.uint8)[None, :], H, axis=0)])
    cv2.imwrite(f"{salida}/ataud_lado_{lado}.png", rgba)
    print(lado, "ancho", ancho, "nuevo", nuevo)
