"""Musica de fondo de la hojarasca en bucle sin costura (2026-10-14).

Fuente: "The Pilgrim's Light.wav" (Flow Music, del usuario; en Descargas, no se
copia aqui por espacio): 174 s, 48 kHz estereo, empieza ya sonando y acaba con
un fundido desde ~168 s. El bucle corta antes de ese fundido (FIN) y funde los
ultimos CRUCE s con los primeros (potencia constante), de modo que al volver al
principio la pista sigue sin salto:

  bucle = pista[CRUCE:FIN], con sus ultimos CRUCE s = pista[FIN-CRUCE:FIN]
          (saliendo) + pista[0:CRUCE] (entrando)

  assets/audio/musica_hojarasca.ogg   Vorbis, en bucle en el import

Uso: python bucle.py "ruta/The Pilgrim's Light.wav"
"""
import os
import sys

import numpy as np
import soundfile as sf

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, "..", "..", "..", ".."))
SALIDA = os.path.join(PROYECTO, "assets", "audio", "musica_hojarasca.ogg")

FIN = 166.0      # s: antes del fundido final de la pista
CRUCE = 6.0      # s de fundido cruzado entre el final y el principio


def main():
	a, sr = sf.read(sys.argv[1], always_2d=True, dtype="float32")
	fin = int(FIN * sr)
	n = int(CRUCE * sr)
	t = np.linspace(0.0, 1.0, n, dtype=np.float32)[:, None]
	entra = np.sin(t * np.pi / 2.0)
	sale = np.cos(t * np.pi / 2.0)
	bucle = a[n:fin].copy()
	bucle[-n:] = a[fin - n:fin] * sale + a[:n] * entra
	pico = np.abs(bucle).max()
	if pico > 0.98:
		bucle *= 0.98 / pico
	# Por bloques: de una vez, el codificador Vorbis de libsndfile revienta la
	# pila con una pista tan larga.
	with sf.SoundFile(SALIDA, "w", sr, bucle.shape[1], format="OGG", subtype="VORBIS") as f:
		for i in range(0, len(bucle), 8192):
			f.write(bucle[i:i + 8192])
	print("musica_hojarasca.ogg %.1f s (de %.1f), pico %.1f dBFS" % (
		len(bucle) / sr, len(a) / sr, 20 * np.log10(np.abs(bucle).max())))


if __name__ == "__main__":
	main()
