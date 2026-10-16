# Could the old tumbarse hand over to the new video's get-up played backwards (or the new get-up to the old levantarse)?
import sys, os, json, numpy as np, cv2
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import metrica as M
from juntas_util import hood_x, old_raw
crop = (120, 365, 60, 600)
R = {r['i']: r['hood'][0] for r in json.load(open(sys.argv[2]))}
olds = list(range(20, 77, 2)) + list(range(126, 183, 2))
O = {k: M.old(k, crop) for k in olds}
HO = {k: hood_x(old_raw(k), M.BGO) for k in olds}
news = list(range(140, 192, 2))
N = {k: M.new(k, crop) for k in news}
Nall = {k: M.new(k, crop) for k in range(140, 192)}
med = float(np.median([M.dist(Nall[k], Nall[k + 1]) for k in range(140, 190)]))
print('paso mediano del levantarse nuevo (140..190): %.3f' % med)
rows = []
for a in olds:
    for b in news:
        d0 = int(round(R[b] - HO[a]))
        d, dx, dy = M.best(O[a], N[b], range(d0 - 21, d0 + 22, 3), (-3, 0, 3))
        d, dx, dy = M.best(O[a], N[b], range(dx - 2, dx + 3), range(dy - 2, dy + 3))
        rows.append((d / med, a, b, dx, dy))
json.dump(rows, open(sys.argv[1], 'w'))
for tramo, rng in (('tumbarse viejo (f020..f076)', range(20, 77)), ('levantarse viejo (f126..f182)', range(126, 183))):
    rs = sorted(r for r in rows if r[1] in rng)
    print(tramo, 'contra el levantarse nuevo (f140..f190): mejores')
    for r in rs[:10]:
        print('   %.2f pasos  viejo f%03d  nuevo f%03d  dx %d dy %d' % r)
