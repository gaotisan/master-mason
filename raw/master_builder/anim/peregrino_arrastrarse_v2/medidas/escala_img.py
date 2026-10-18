import sys, os, numpy as np, cv2
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import metrica as M
from juntas_util import old_raw
def new_raw(k): return cv2.imread(os.path.join(M.NEW, 'f_%04d.png' % k))
BGo, BGn = np.array([65, 208, 46]), np.array([67, 209, 50])
def bbox(img, bg):
    m = np.abs(img.astype(int) - bg).max(-1) > 60
    ys, xs = np.nonzero(m); return xs.min(), xs.max(), ys.min(), ys.max(), m
def stats(img, bg, name):
    x0, x1, y0, y1, m = bbox(img, bg)
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    cloak = m & (hsv[..., 1] > 60)
    c = img[cloak].mean(0)
    print('%-12s alto %3d ancho %3d (px de mitad; x2 = video, x3.02 = master)  manto medio BGR (%.0f, %.0f, %.0f)' % (name, y1 - y0 + 1, x1 - x0 + 1, *c))
    return x0, x1, y0, y1
items = [('viejo f003', old_raw(3), BGo), ('nuevo f001', new_raw(1), BGn), ('nuevo f190', new_raw(190), BGn),
         ('viejo f076', old_raw(76), BGo), ('viejo f100', old_raw(100), BGo), ('nuevo f093', new_raw(93), BGn), ('nuevo f120', new_raw(120), BGn)]
tiles = []
for name, img, bg in items:
    x0, x1, y0, y1 = stats(img, bg, name)
    cx = (x0 + x1) // 2
    w = 120 if name in ('viejo f003', 'nuevo f001', 'nuevo f190') else 340
    t = img[120:360, max(0, cx - w // 2):cx + w // 2].copy()
    cv2.line(t, (0, 346 - 120), (t.shape[1], 346 - 120), (0, 0, 0), 1)
    cv2.line(t, (0, 139 - 120), (t.shape[1], 139 - 120), (0, 0, 0), 1)
    cv2.putText(t, name, (3, 14), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 0, 255), 1)
    tiles.append(t)
H = max(t.shape[0] for t in tiles)
out = np.hstack([np.vstack([t, np.full((H - t.shape[0], t.shape[1], 3), 255, np.uint8)]) for t in tiles])
cv2.imwrite(sys.argv[1], out)
