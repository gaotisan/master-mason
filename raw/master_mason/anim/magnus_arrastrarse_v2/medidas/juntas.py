import sys, os, json, numpy as np, cv2
from scipy import ndimage as ndi
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import metrica as M
crop = (200, 365, 40, 600)
def hood_x(img_bgr, bg):
    di = np.abs(img_bgr.astype(np.int16) - bg.astype(np.int16)).max(-1)
    m = di > 60
    hsv = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2HSV)
    g = m & (hsv[..., 1] < 40) & (hsv[..., 2] > 110)
    lab, n = ndi.label(ndi.binary_closing(g, iterations=2))
    s = ndi.sum(g, lab, range(1, n + 1)); h = lab == (np.argmax(s) + 1)
    return float(np.nonzero(h)[1].mean())
def old_raw(k): return cv2.resize(cv2.imread(os.path.join(M.OLD, 'f_%04d.png' % k)), (640, 360), interpolation=cv2.INTER_AREA)
R = {r['i']: r['hood'][0] for r in json.load(open(sys.argv[2]))}
O = {k: M.old(k, crop) for k in (75, 76, 77, 125, 126, 127)}
HO = {k: hood_x(old_raw(k), M.BGO) for k in O}
N = {k: M.new(k, crop) for k in range(14, 176)}
med_new = float(np.median([M.dist(N[k], N[k + 1]) for k in range(86, 143)]))
print('paso mediano del nuevo (86..142) %.3f; capucha vieja f076 x=%.1f f126 x=%.1f (px mitad)' % (med_new, HO[76], HO[126]))
out = {}
for ref in (76, 126):
    rows = []
    for k in range(14, 176):
        d0 = int(round(R[k] - HO[ref]))
        d, dx, dy = M.best(O[ref], N[k], range(d0 - 24, d0 + 25, 3), (-2, 0, 2))
        d, dx, dy = M.best(O[ref], N[k], range(dx - 2, dx + 3), range(dy - 1, dy + 2))
        ds = M.dist(np.roll(np.roll(O[ref][..., 3], dy, 0), dx, 1), N[k][..., 3])
        rows.append((d / med_new, k, dx, dy, ds / med_new, dx - d0))
    out[str(ref)] = rows
    rs = sorted(rows)
    print('viejo f%03d contra el nuevo: mejores (pasos; k; dx dy; solo silueta; desfase capucha):' % ref)
    for r in rs[:8]:
        print('   %.2f  f%03d  dx %d dy %d  silueta %.2f  capucha %+d' % r)
json.dump(out, open(sys.argv[1], 'w'))
print('referencia, saltos de hoy en px: viejo f076->f077 %.2f  f125->f126 %.2f (pasos del nuevo)' % (M.dist(O[76], O[77]) / med_new, M.dist(O[125], O[126]) / med_new))
