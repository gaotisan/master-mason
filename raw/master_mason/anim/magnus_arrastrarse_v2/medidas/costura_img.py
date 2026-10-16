# Seam image: rows = [j-2, j-1, i(shifted by advance), i+1(shifted)] and a diff of (j vs i shifted)
import sys, os, cv2, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import metrica as M
def raw_new(k): return cv2.imread(os.path.join(M.NEW, 'f_%04d.png' % k))[190:365, 60:540]
def raw_old(k): return cv2.resize(cv2.imread(os.path.join(M.OLD, 'f_%04d.png' % k)), (640, 360), interpolation=cv2.INTER_AREA)[190:365, 60:540]
def fila(raw, load, i, j, dxs, titulo):
    d, dx, dy = M.best(load(i), load(j), dxs)
    def lab(img, t):
        img = img.copy(); cv2.putText(img, t, (5, 18), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 2); return img
    sj = lambda k: np.roll(np.roll(raw(k), dy, 0), dx, 1)
    a = lab(raw(j - 2), '%d' % (j - 2)); b = lab(raw(j - 1), '%d (ultimo)' % (j - 1))
    c = lab(sj(i), '%d (vuelve) +%dpx' % (i, dx)); e = lab(sj(i + 1), '%d' % (i + 1))
    # overlay: j-1 in red, i shifted in cyan
    m1 = (np.abs(raw(j - 1).astype(int) - [67, 209, 50]).max(-1) > 60)
    m2 = (np.abs(sj(i).astype(int) - [67, 209, 50]).max(-1) > 60)
    ov = np.full_like(a, 255); ov[m1 & ~m2] = (0, 0, 255); ov[m2 & ~m1] = (255, 160, 0); ov[m1 & m2] = (120, 120, 120)
    ov = lab(ov, 'rojo=%d cian=%d' % (j - 1, i))
    t = np.full((22, a.shape[1] * 5, 3), 255, np.uint8)
    cv2.putText(t, titulo, (5, 16), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 1)
    return np.vstack([t, np.hstack([a, b, c, e, ov])])
rows = [fila(raw_old, M.old, 77, 126, range(25, 42), 'ACTUAL (video viejo f077..f125, vuelve al f077 = c75..c123): costura 1.99 pasos medianos, 1.6 locales'),
        fila(raw_new, M.new, 93, 144, range(15, 32), 'NUEVO ciclo 93..143 (51 fot): costura 2.72 pasos medianos, 3.0 locales'),
        fila(raw_new, M.new, 55, 118, range(15, 32), 'NUEVO ciclo 55..117 (63 fot): costura 2.90 pasos medianos, 2.2 locales')]
out = np.vstack(rows)
cv2.imwrite(sys.argv[1], out)
