import os, numpy as np, cv2
from scipy import ndimage as ndi
import metrica as M
def hood_x(img_bgr, bg):
    di = np.abs(img_bgr.astype(np.int16) - bg.astype(np.int16)).max(-1)
    m = di > 60
    hsv = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2HSV)
    g = m & (hsv[..., 1] < 40) & (hsv[..., 2] > 110)
    lab, n = ndi.label(ndi.binary_closing(g, iterations=2))
    s = ndi.sum(g, lab, range(1, n + 1)); h = lab == (np.argmax(s) + 1)
    return float(np.nonzero(h)[1].mean())
def old_raw(k): return cv2.resize(cv2.imread(os.path.join(M.OLD, 'f_%04d.png' % k)), (640, 360), interpolation=cv2.INTER_AREA)
