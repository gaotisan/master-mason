"""Quita el "repujado" que deja Midjourney (el rugoso de grabado en suelos y
matas) redibujando la imagen con Real-ESRGAN: se reduce a la mitad y el modelo
general (realesrgan-x4plus) la vuelve a ampliar limpia; luego, a su tamano. Los
filtros normales no lo separan del detalle bueno (2026-10-21: o no lo quitaban o
se llevaban la hierba y adelgazaban la verja); el modelo de video (animevideov3)
lo dejaba de plastico. Escribe <carpeta>/fondo_ia.png junto a la fuente, que no
se toca; los generadores de cada escena la usan si existe.

  python limpiar_fondo_ia.py <fuente.png> [<salida.png>]   (salida: fondo_ia.png al lado)
  REALESRGAN: ruta del realesrgan-ncnn-vulkan.exe; GPU: dispositivo (0 = la Intel
  integrada de la P520, la Quadro se cuelga por calor con este modelo).
"""
import os
import subprocess
import sys
import tempfile

import cv2


def main():
	fuente = sys.argv[1]
	salida = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(fuente)), 'fondo_ia.png')
	exe = os.environ['REALESRGAN']
	gpu = os.environ.get('GPU', '0')
	im = cv2.imread(fuente, cv2.IMREAD_COLOR)
	h, w = im.shape[:2]
	with tempfile.TemporaryDirectory() as t:
		a, b = os.path.join(t, 'mitad.png'), os.path.join(t, 'x4.png')
		cv2.imwrite(a, cv2.resize(im, (w // 2, h // 2), interpolation=cv2.INTER_AREA))
		subprocess.run([exe, '-i', a, '-o', b, '-n', 'realesrgan-x4plus', '-s', '4', '-t', '200', '-g', gpu,
			'-m', os.path.join(os.path.dirname(exe), 'models')], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
		x4 = cv2.imread(b, cv2.IMREAD_COLOR)
	out = cv2.resize(x4, (w, h), interpolation=cv2.INTER_AREA)
	# comprobacion: el mismo dibujo (si el envio se colgo sale negro o distinto)
	d = float(abs(cv2.GaussianBlur(out, (0, 0), 6).astype(float) - cv2.GaussianBlur(im, (0, 0), 6).astype(float)).mean())
	assert d < 8, 'la imagen limpia no se parece a la fuente (%.1f): envio colgado?' % d
	cv2.imwrite(salida, out)
	print(salida, 'diferencia de fondo %.1f' % d)


if __name__ == '__main__':
	main()
