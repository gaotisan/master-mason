import sys, os, json, numpy as np, cv2
from scipy import ndimage as ndi
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import metrica as M
from juntas_util import old_raw
def new_raw(k): return cv2.imread(os.path.join(M.NEW, 'f_%04d.png' % k))
BGo, BGn = np.array([65, 208, 46]), np.array([67, 209, 50])
def mask(img, bg): return np.abs(img.astype(int) - bg).max(-1) > 60
def lab(img, t, c=(0, 0, 255)):
    img = img.copy(); cv2.putText(img, t, (6, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.55, c, 2); return img
def sh(img, dx, dy): return np.roll(np.roll(img, dy, 0), dx, 1)
def ov(a, abg, b, bbg, ta, tb):
    m1, m2 = mask(a, abg), mask(b, bbg)
    o = np.full_like(a, 255); o[m1 & ~m2] = (0, 0, 255); o[m2 & ~m1] = (255, 160, 0); o[m1 & m2] = (130, 130, 130)
    return lab(o, 'rojo=%s  cian=%s' % (ta, tb), (0, 0, 0))
Y0, Y1 = 200, 365
rows = []
def row(oldk, newk, dx, dy, title):
    a = old_raw(oldk); b = sh(new_raw(newk), -dx, -dy)
    t = np.full((24, 640 * 3, 3), 255, np.uint8); cv2.putText(t, title, (5, 17), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 1)
    rows.append(np.vstack([t, np.hstack([lab(a, 'viejo f%03d' % oldk)[Y0:Y1], lab(b, 'nuevo f%03d' % newk)[Y0:Y1], ov(a, BGo, b, BGn, 'viejo f%03d' % oldk, 'nuevo f%03d' % newk)[Y0:Y1]])]))
J = json.load(open(sys.argv[2]))
best76 = sorted(J['76'])[0]; best126 = sorted(J['126'])[0]
r93 = [r for r in J['76'] if r[1] == 93][0]; r143 = [r for r in J['126'] if r[1] == 143][0]
row(76, best76[1], best76[2], best76[3], 'JUNTA a) fin de tumbarse (hoja 73 = viejo f076) contra el MAS parecido del nuevo (f%03d): %.1f pasos normales' % (best76[1], best76[0]))
row(76, 93, r93[2], r93[3], 'JUNTA a) fin de tumbarse contra el inicio del ciclo propuesto (f093): %.1f pasos normales' % r93[0])
row(126, best126[1], best126[2], best126[3], 'JUNTA b) inicio de levantarse_tumbado (hoja 123 = viejo f126) contra el MAS parecido del nuevo (f%03d): %.1f pasos' % (best126[1], best126[0]))
row(126, 143, r143[2], r143[3], 'JUNTA b) inicio de levantarse_tumbado contra el fin del ciclo propuesto (f143): %.1f pasos' % r143[0])
cv2.imwrite(sys.argv[1], np.vstack(rows))
