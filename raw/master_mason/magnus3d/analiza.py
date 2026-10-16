import numpy as np
from PIL import Image
from scipy import ndimage
im = np.asarray(Image.open('../anim/_fuentes/giro360.jpeg').convert('RGB')).astype(float)
r,g,b = im[...,0],im[...,1],im[...,2]
verde = (g > 120) & (g > r*1.35) & (g > b*1.35)
fig = ~verde
fig = ndimage.binary_opening(fig, iterations=2)
lab, n = ndimage.label(fig)
sizes = ndimage.sum(fig, lab, range(1,n+1))
keep = [i+1 for i,s in enumerate(sizes) if s > 20000]
print(im.shape, 'componentes grandes', len(keep))
for i in keep:
    ys,xs = np.nonzero(lab==i)
    print(i, 'x', xs.min(), xs.max(), 'y', ys.min(), ys.max(), 'area', len(xs))
mask = np.isin(lab, keep)
Image.fromarray((mask*255).astype(np.uint8)).save('mascara_giro.png')
