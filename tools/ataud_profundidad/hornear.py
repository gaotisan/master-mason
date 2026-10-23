"""Mapas del ataud con profundidad (prueba 2026-10-22).

Del fondo del ataud (una sola imagen) saca lo que necesita el shader
ataud_profundidad.gdshader para mover la sala por detras del cristal:

  ataud_cristal.png      gris: lo que va pegado al cristal y no se mueve con la
                         sala (1 = el marco del ataud y las telaranas grandes
                         que cruzan la ventana). El color es el del fondo.
  ataud_sala.png         la sala sin marco ni telaranas: debajo, relleno
                         (inpaint de OpenCV) para cuando la sala se desplace y
                         asome lo que tapaban.
  ataud_profundidad.png  a media resolucion, gris: profundidad de la sala
                         (1 = cerca, 0 = la pared del fondo), suavizada y
                         prolongada por debajo del marco.

La profundidad sale de Depth Anything V2 small (profundidad.py, ONNX en CPU,
gratis y en local), en 16 bits:
    python -I profundidad.py model_fp16.onnx sarcophagus_base_16_9.png prof.png
    python -I hornear.py sarcophagus_base_16_9.png prof.png <carpeta de salida>
El modelo: huggingface.co/onnx-community/depth-anything-v2-small, onnx/model_fp16.onnx
"""
import sys
import numpy as np
import cv2

base_p, prof_p, salida = sys.argv[1:4]

base = cv2.imread(base_p, cv2.IMREAD_COLOR)
H, W = base.shape[:2]
d = cv2.imread(prof_p, cv2.IMREAD_UNCHANGED).astype(np.float32) / 65535.0
d = cv2.resize(d, (W, H), interpolation=cv2.INTER_CUBIC)

# --- La ventana: lo que el modelo ve lejos del marco, como poligono (los
# cantos del marco son rectos; el umbral solo da una mancha ondulada).
ventana = (d < 0.77).astype(np.uint8)
ventana = cv2.morphologyEx(ventana, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (41, 41)))
cs, _ = cv2.findContours(ventana, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
poligono = cv2.approxPolyDP(cv2.convexHull(max(cs, key=cv2.contourArea)), 30, True)
print("ventana", poligono.reshape(-1, 2).tolist())
dentro = np.zeros((H, W), np.uint8)
cv2.fillPoly(dentro, [poligono], 1)
# Canto del marco: 3 px de suavizado.
marco = 1.0 - cv2.GaussianBlur(dentro.astype(np.float32), (0, 0), 1.5)

# --- Telaranas grandes: crestas claras y finas (hessiano) que forman hilos
# largos; se crecen desde los tramos claros por los tenues que los continuan.
L = cv2.cvtColor(base, cv2.COLOR_BGR2LAB)[..., 0].astype(np.float32)
th = cv2.morphologyEx(L, cv2.MORPH_TOPHAT, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)))
g = cv2.GaussianBlur(L, (0, 0), 1.6)
dxx = cv2.Sobel(g, cv2.CV_32F, 2, 0, ksize=3)
dyy = cv2.Sobel(g, cv2.CV_32F, 0, 2, ksize=3)
dxy = cv2.Sobel(g, cv2.CV_32F, 1, 1, ksize=3)
raiz = np.sqrt((dxx - dyy) ** 2 + 4 * dxy ** 2)
l1 = 0.5 * (dxx + dyy - raiz)
l2 = 0.5 * (dxx + dyy + raiz)
cresta = np.where(l1 < 0, -l1, 0) * (np.abs(l2) < 0.5 * np.abs(l1))


def largos(m, lmin):
    n, lab, st, _ = cv2.connectedComponentsWithStats(m, 8)
    sigue = np.zeros(n, bool)
    for i in range(1, n):
        w, h, a = st[i, 2], st[i, 3], st[i, 4]
        sigue[i] = max(w, h) > lmin and a < 0.25 * w * h
    return sigue[lab].astype(np.uint8)


semilla = largos(((cresta > 24) & (th > 22)).astype(np.uint8), 60)
debil = ((cresta > 9) & (th > 14)).astype(np.uint8)
hilos = semilla.copy()
for _ in range(60):
    nuevo = cv2.dilate(hilos, np.ones((3, 3), np.uint8)) & debil | semilla
    if (nuevo != hilos).sum() == 0:
        break
    hilos = nuevo
hilos = largos(hilos, 120)
hilos = cv2.dilate(hilos, np.ones((3, 3), np.uint8))
hilos_f = cv2.GaussianBlur(hilos.astype(np.float32), (0, 0), 0.8)
hilos_f = np.clip(hilos_f * 1.4, 0, 1)

# --- Cristal: solo la mascara (el color lo pone el fondo original).
alfa = np.maximum(marco, hilos_f)
cv2.imwrite(f"{salida}/ataud_cristal.png", (alfa * 255).astype(np.uint8))

# --- Sala: rellena debajo del marco (a 1/4 y subido; ahi solo hay humo) y
# debajo de los hilos (a resolucion completa, son finos).
tapar = (1 - cv2.erode(dentro, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (17, 17)))).astype(np.uint8)
q = 4
peq = cv2.resize(base, (W // q, H // q), interpolation=cv2.INTER_AREA)
mpeq = cv2.resize(tapar, (W // q, H // q), interpolation=cv2.INTER_NEAREST)
relleno = cv2.inpaint(peq, mpeq, 6, cv2.INPAINT_TELEA)
relleno = cv2.GaussianBlur(cv2.resize(relleno, (W, H), interpolation=cv2.INTER_CUBIC), (0, 0), 2.0)
mezcla = cv2.GaussianBlur(tapar.astype(np.float32), (0, 0), 3.0)[..., None]
sala = (base * (1.0 - mezcla) + relleno * mezcla).astype(np.uint8)
sala = cv2.inpaint(sala, cv2.dilate(hilos, np.ones((3, 3), np.uint8)), 4, cv2.INPAINT_TELEA)
cv2.imwrite(f"{salida}/ataud_sala.png", sala)

# --- Profundidad de la sala: la del modelo dentro de la ventana, prolongada
# por debajo del marco y suavizada para que el desplazamiento no se doble
# sobre si mismo (gradiente * desplazamiento maximo < 1).
d8 = (np.clip(d, 0, 1) * 255).astype(np.uint8)
dpeq = cv2.resize(d8, (W // q, H // q), interpolation=cv2.INTER_AREA)
dsala = cv2.inpaint(dpeq, mpeq, 8, cv2.INPAINT_TELEA)
dsala = cv2.resize(dsala, (W // 2, H // 2), interpolation=cv2.INTER_CUBIC).astype(np.float32) / 255.0
dsala = cv2.GaussianBlur(dsala, (0, 0), 6.0)
cv2.imwrite(f"{salida}/ataud_profundidad.png", np.clip(dsala * 255, 0, 255).astype(np.uint8))

# Para revisar: lo del cristal en rojo encima de la sala.
ver = sala.copy()
ver[..., 2] = np.maximum(ver[..., 2], (alfa * 255).astype(np.uint8))
cv2.imwrite(f"{salida}/_revisar.jpg", cv2.resize(ver, (W // 2, H // 2), interpolation=cv2.INTER_AREA))
print("ok", W, H, "hilos", float(hilos.mean()))
