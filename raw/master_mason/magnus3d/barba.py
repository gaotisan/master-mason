import numpy as np
from PIL import Image
im = np.asarray(Image.open('../anim/_fuentes/giro360.jpeg').convert('RGB')).astype(float)
M = np.asarray(Image.open('mascara_giro.png')) > 0
blanco = (im.min(2) > 185) & M
cajas = [(42,479),(504,933),(951,1412),(1425,1887),(1903,2487)]
for k,(a,b) in enumerate(cajas):
    sub = blanco[:, a:b]
    yy,xx = np.nonzero(sub[250:700]); xx = xx + a
    # centro del cuerpo: punto medio de la silueta en filas 1000-1400 (media de centros)
    cen = np.mean([ (np.nonzero(M[y,a:b])[0].min()+np.nonzero(M[y,a:b])[0].max())/2 + a for y in range(1000,1400,20)])
    # tope de la capucha
    top = [y for y in range(130,400) if M[y,a:b].any()][0]
    xt = np.nonzero(M[top+3,a:b])[0].mean()+a
    print(k, 'barba x %.0f (n=%d) centro cuerpo %.0f  dif %.0f  apice capucha x %.0f' % (xx.mean(), len(xx), cen, xx.mean()-cen, xt))
