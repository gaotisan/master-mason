import numpy as np
from PIL import Image
from scipy import ndimage
im = np.asarray(Image.open('../anim/_fuentes/giro360.jpeg').convert('RGB'))
m = np.asarray(Image.open('mascara_giro.png')) > 0
cajas = [(42,479),(504,933),(951,1412),(1425,1887),(1903,2487)]
# orden: perfil ... frente
for k,(a,b) in enumerate(cajas):
    sub = m[:, a-10:b+10]
    filas = {}
    for y in [1300,1400,1500,1560,1600]:
        xs = np.nonzero(sub[y])[0] + a-10
        filas[y] = (xs.min(), xs.max(), len(xs)) if len(xs) else None
    # bajo del dobladillo: fila mas alta en que el ancho cae por debajo de 150 px
    w = sub.sum(1)
    dob = [y for y in range(900,1619) if 0 < w[y] < 160]
    print(k, 'dobladillo', dob[0] if dob else None, filas)
