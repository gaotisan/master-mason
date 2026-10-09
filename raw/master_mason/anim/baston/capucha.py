"""Le quita a la capucha la punta de sombrero de mago que le sale al andar en
magnus_andar_baston_v2 (Character_walking_on_green_screen_...). En el
fotograma 1 la capucha es la de siempre (la de baston_ref_en_mano); en cuanto
echa a andar, la IA le estira el vertice de atras en una punta hacia atras y
arriba.

Patron: la capucha del fotograma 1 (gris claro, por encima de los hombros).
En cada fotograma se encaja ese patron sobre su capucha (desplazamiento que
minimiza el XOR de las dos mascaras; la punta pesa igual en todos, asi que no
lo desvia) y se borra el gris que sobresale del patron engordado ENGORDE px,
solo en la zona de la punta: por encima del ojo y por detras del vertice. Lo
borrado era fondo (la punta se mete en el aire), asi que queda transparente,
con el borde suavizado un pixel.
Guarda los originales en <job>/_antes_de_capucha/ la primera vez.
  python capucha.py [job] [--ver]"""
import shutil, sys
import numpy as np
from PIL import Image
from scipy import ndimage
from celdas import PROY

JOB = next((a for a in sys.argv[1:] if not a.startswith("--")), "magnus_andar_baston_v2")
ENGORDE = 1


def gris(a):
    r, g, b, al = [a[..., i].astype(int) for i in range(4)]
    m = (al > 128) & (abs(r - g) < 16) & (abs(g - b) < 16) & (r > 95) & (r < 225)
    m[260:] = False            # solo cabeza
    # el grupo grande (la capucha), no brillos sueltos de la barba o el baston
    lab, n = ndimage.label(m)
    if n == 0:
        return m
    tam = ndimage.sum(m, lab, range(1, n + 1))
    return lab == (int(np.argmax(tam)) + 1)


def encajar(ref, m):
    """(dy, dx) que lleva ref sobre m."""
    ys, xs = np.where(ref)
    y0, y1, x0, x1 = max(ys.min() - 40, 0), ys.max() + 40, max(xs.min() - 60, 0), xs.max() + 40
    ref, m = ref[y0:y1, x0:x1], m[y0:y1, x0:x1]
    mejor = None
    for dy in range(-14, 15):
        for dx in range(-20, 21):
            r = np.roll(np.roll(ref, dy, 0), dx, 1)
            e = int((r ^ m).sum())
            if mejor is None or e < mejor[0]:
                mejor = (e, dy, dx)
    return mejor[1], mejor[2]


def main():
    carpeta = PROY / "raw/master_mason/anim" / JOB / "04_limpios"
    copia = carpeta.parent / "_antes_de_capucha"
    if not copia.exists():
        shutil.copytree(carpeta, copia)
    fs = sorted(copia.glob("c_*.png"))
    a0 = np.array(Image.open(fs[0]).convert("RGBA"))
    ref = gris(a0)
    # contorno de arriba del fotograma de referencia: fila del primer pixel
    # opaco de cada columna (sin nada, el fondo de la casilla)
    op0 = a0[..., 3] > 40
    techo = np.where(op0.any(0), op0.argmax(0), op0.shape[0])
    ys, xs = np.where(ref)
    vy = int(ys.min())                       # vertice (lo mas alto)
    vx = int(xs[ys == vy].mean())
    print("capucha de referencia: vertice en", vx, vy)
    total = []
    for f in fs:
        a = np.array(Image.open(f).convert("RGBA"))
        m = gris(a)
        dy, dx = encajar(ref, m)
        patron = ndimage.binary_dilation(np.roll(np.roll(ref, dy, 0), dx, 1), iterations=ENGORDE)
        zona = np.zeros_like(m)
        zona[max(0, vy + dy - 60):vy + dy + 70, :vx + dx + 12] = True
        # Vertice bueno: cruce de la recta del borde de arriba (del vertice a
        # la cara, a la derecha de donde nace la punta) con la del borde de
        # atras (por debajo de la punta). Fuera de esos dos semiplanos, en la
        # zona de la punta, sobra todo; con antialias de medio pixel.
        ax, ay = vx + dx, vy + dy
        cols = [x for x in range(ax + 10, ax + 55) if m[:, x].any()]
        tops = [int(np.argmax(m[:, x])) for x in cols]
        a_, b_ = np.polyfit(cols, tops, 1)                  # y = a x + b
        # borde de atras: solo el tramo de capucha bajo la punta (mas abajo
        # ya es barba), y fuera los puntos que se salen de la recta
        filas_ = np.array([y for y in range(ay + 26, ay + 66) if m[y].any()])
        izq = np.array([int(np.argmax(m[y])) for y in filas_])
        c_, d_ = np.polyfit(filas_, izq, 1)                 # x = c y + d
        bien = np.abs(izq - (c_ * filas_ + d_)) < 4
        c_, d_ = np.polyfit(filas_[bien], izq[bien], 1)
        yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
        # distancia (px, + = dentro) a cada recta
        d1 = (yy - (a_ * xx + b_)) / np.hypot(1, a_)
        d2 = (xx - (c_ * yy + d_)) / np.hypot(1, c_)
        dentro = np.clip(np.minimum(d1, d2) + 0.5, 0, 1)
        zona = np.zeros(a.shape[:2], bool)
        zona[max(0, ay - 60):ay + 55, :ax + 40] = True
        al = a[..., 3].astype(float)
        nueva = np.where(zona, al * dentro, al)
        sobra = (al > 0) & (nueva < al * 0.5)
        a[..., 3] = nueva.round().astype(np.uint8)
        Image.fromarray(a, "RGBA").save(carpeta / f.name)
        total.append(int(sobra.sum()))
    print(JOB, "px quitados por fotograma:", total[::8])



def por_patron(job):
    """Para videos cuyo primer fotograma ya tiene la capucha buena (el bucle,
    hecho desde baston_andar_bucle_ref.png): en cada fotograma se encaja el
    primero por la parte delantera de la capucha y la cara (donde la punta no
    llega) y, en la zona de la punta (detras y encima del vertice), la silueta
    pasa a ser la de la capucha buena encajada. Color: el del fotograma donde
    ya es capucha, el del primero donde falta. La punta de este video se curva
    hacia arriba como un gancho y las rectas de main() o dejaban un munon o
    se comian el vertice."""
    import cv2
    carpeta = PROY / "raw/master_mason/anim" / job / "04_limpios"
    copia = carpeta.parent / "_antes_de_capucha"
    if not copia.exists():
        shutil.copytree(carpeta, copia)
    fs = sorted(copia.glob("c_*.png"))
    r0 = np.array(Image.open(fs[0]).convert("RGBA"))
    ref = gris(r0)
    ys, xs = np.where(ref)
    vy = int(ys.min()); vx = int(xs[ys == vy].mean())
    plano = lambda a: (a[..., :3].astype(np.float32) * (a[..., 3:] / 255.0)).astype(np.float32)
    # patron: capucha delantera y cara
    py0, py1, px0, px1 = vy + 5, vy + 115, vx + 5, vx + 95
    tpl = plano(r0)[py0:py1, px0:px1]
    total = []
    for f in fs:
        a = np.array(Image.open(f).convert("RGBA"))
        R = 14
        zona_b = plano(a)[py0 - R:py1 + R, px0 - R:px1 + R]
        res = cv2.matchTemplate(zona_b, tpl, cv2.TM_SQDIFF)
        _, _, (lx, ly), _ = cv2.minMaxLoc(res)
        dx, dy = lx - R, ly - R
        # la capucha buena llevada a este fotograma
        rr = np.roll(np.roll(r0, dy, 0), dx, 1)
        z = np.zeros(a.shape[:2], bool)
        z[max(0, vy + dy - 45):vy + dy + 60, max(0, vx + dx - 90):vx + dx + 12] = True
        buena = rr[..., 3].astype(float)
        al = a[..., 3].astype(float)
        nueva = a.copy()
        # silueta de la buena en la zona
        nueva[..., 3] = np.where(z, buena, al).round().astype(np.uint8)
        # color: el propio donde ya era opaco, el de la buena donde no
        falta = z & (al < 128) & (buena >= 128)
        nueva[..., :3][falta] = rr[..., :3][falta]
        Image.fromarray(nueva, "RGBA").save(carpeta / f.name)
        total.append(int((z & (al >= 128) & (buena < 128)).sum()))
    print(job, "px de punta quitados por fotograma:", total[::8])


if __name__ == "__main__" and "--patron" in sys.argv:
    por_patron(JOB)
    sys.exit()


if __name__ == "__main__":
    main()
