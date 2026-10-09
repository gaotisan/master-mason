"""Mide cada fotograma de _sin_normalizar/ (croma.py): punta de la capucha y pies
sin el baston (apertura horizontal de 15 px y, para los pies, 3x7 en una franja
de +-70 px del eje), eje del tronco y pixeles de barba. -> medidas_crudas.json
    python medir.py <job>
"""
import glob, json, os, sys
import numpy as np
from PIL import Image
from scipy.ndimage import binary_opening, label

D = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), sys.argv[1])
res = []
for i, f in enumerate(sorted(glob.glob(os.path.join(D, '_sin_normalizar', '*.png'))), 1):
    a = np.asarray(Image.open(f))
    m = a[..., 3] > 128
    o = binary_opening(m, structure=np.ones((1, 15)))
    lab, n = label(o); o = lab == (np.bincount(lab.ravel())[1:].argmax() + 1)
    ys = np.nonzero(o.any(1))[0]; top = int(ys.min())
    cx = float(np.median(np.nonzero(o[top + int(0.35 * (ys.max() - top)):top + int(0.6 * (ys.max() - top))])[1]))
    ob = binary_opening(m[:, int(cx) - 70:int(cx) + 70], structure=np.ones((3, 7)))
    pie = int(np.nonzero(ob.any(1))[0].max())
    res.append((i, top, pie, pie - top, cx, int((m & (a[..., :3].min(2) > 175)).sum())))
json.dump(res, open(os.path.join(D, 'medidas_crudas.json'), 'w'))
print(len(res), 'medidos')
