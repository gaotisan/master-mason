# per-frame features of the new video (half res): feet x (leftmost), hand x (rightmost),
# hood: grey low-saturation pixels -> centroid; top y; ground y
import sys, os, json, cv2, numpy as np
from scipy import ndimage as ndi
d = sys.argv[1]
BG = np.array([67, 209, 50], np.int16)
out = []
for i in range(1, 193):
    f = cv2.imread(os.path.join(d, 'f_%04d.png' % i))
    di = np.abs(f.astype(np.int16) - BG).max(-1)
    m = di > 60
    lab, n = ndi.label(m)
    sz = ndi.sum(m, lab, range(1, n+1)); g = np.argmax(sz)+1
    m = ndi.binary_dilation(lab == g, iterations=3) & m
    hsv = cv2.cvtColor(f, cv2.COLOR_BGR2HSV)
    grey = m & (hsv[..., 1] < 40) & (hsv[..., 2] > 110)
    # hood = grey pixels in upper part of body
    ys, xs = np.nonzero(m)
    gy, gx = np.nonzero(grey)
    # restrict hood to largest grey blob
    lab2, n2 = ndi.label(ndi.binary_closing(grey, iterations=2))
    if n2:
        s2 = ndi.sum(grey, lab2, range(1, n2+1)); h = lab2 == (np.argmax(s2)+1)
        hy, hx = np.nonzero(h)
        hood = (float(hx.mean()), float(hy.mean()), int(h.sum()), int(hx.max()-hx.min()+1), int(hy.max()-hy.min()+1))
    else:
        hood = (0, 0, 0, 0, 0)
    out.append(dict(i=i, x0=int(xs.min()), x1=int(xs.max()), y0=int(ys.min()), y1=int(ys.max()),
                    cx=float(xs.mean()), cy=float(ys.mean()), area=int(m.sum()), hood=hood))
json.dump(out, open(sys.argv[2], 'w'))
for r in out:
    if r['i'] % 2 == 0 and 14 <= r['i'] <= 170:
        print(r['i'], 'pies', r['x0'], 'mano', r['x1'], 'top', r['y0'], 'suelo', r['y1'], 'cx %.1f' % r['cx'], 'capucha x %.1f y %.1f n %d w %d h %d' % r['hood'])
