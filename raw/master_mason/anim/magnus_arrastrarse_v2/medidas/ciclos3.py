# Finer cycle search at half res, crop around the body; seam normalised per cycle and locally.
import sys, os, json, cv2, numpy as np
D = sys.argv[1]; OUT = sys.argv[2]
HOOD = {r['i']: r['hood'][0] for r in json.load(open(sys.argv[3]))}
BG = np.array([67, 209, 50], np.float32)
def load(i):
    f = cv2.imread(os.path.join(D, 'f_%04d.png' % i))[190:365, 60:540].astype(np.float32)
    d = np.abs(f - BG).max(-1)
    a = np.clip((d - 40) / 50.0, 0, 1)
    P = np.dstack([f * a[..., None], a * 255])
    return cv2.GaussianBlur(P, (0, 0), 1.0)
A, B = 30, 150
P = {i: load(i) for i in range(A - 3, B + 4)}
def dist(x, y): return float(np.abs(x - y).mean())
def sh(x, dx, dy): return np.roll(np.roll(x, dy, 0), dx, 1)
steps = {i: dist(P[i], P[i + 1]) for i in range(A - 3, B + 3)}
def best(i, j, dys=(-1, 0, 1)):
    b = (1e9, 0, 0)
    d0 = int(round(HOOD[j] - HOOD[i]))
    dxs = range(d0 - 4, d0 + 5)
    for dy in dys:
        Ay = np.roll(P[i], dy, 0)
        for dx in dxs:
            v = dist(np.roll(Ay, dx, 1), P[j])
            if v < b[0]: b = (v, dx, dy)
    return b
res = []
for i in range(40, 121):
    for j in range(i + 20, min(B, i + 75) + 1):
        d, dx, dy = best(i, j)
        seam = dist(P[j - 1], sh(P[i], dx, dy))
        cyc = [steps[k] for k in range(i, j - 1)]
        med = float(np.median(cyc))
        loc = (steps[j - 2] + steps[i]) / 2
        nb = float(np.mean([dist(sh(P[i + k], dx, dy), P[j + k]) for k in (-2, -1, 1, 2)]))
        res.append(dict(i=i, j=j, n=j - i, seam=seam, d=d, med=med, loc=loc, maxc=max(cyc), nb=nb, dx=dx, dy=dy))
json.dump(dict(steps={str(k): v for k, v in steps.items()}, res=res), open(OUT, 'w'))
for r in res: r['sm'] = r['seam'] / r['med']; r['sl'] = r['seam'] / r['loc']; r['smax'] = r['seam'] / r['maxc']
res.sort(key=lambda r: r['sm'])
print('top por costura / paso mediano del ciclo:')
for r in res[:30]:
    print('  %3d..%3d (%2d fot) costura %.2f med | %.2f locales | %.2f del mayor paso del ciclo | d(i,j) %.2f | vecinos %.2f | avance %d px mitad, dy %d' % (r['i'], r['j'] - 1, r['n'], r['sm'], r['sl'], r['smax'], r['d'] / r['med'], r['nb'] / r['med'], r['dx'], r['dy']))
