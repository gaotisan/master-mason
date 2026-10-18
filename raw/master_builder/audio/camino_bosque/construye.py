"""Musica de fondo de la escena del camino del bosque, en bucle sin costura.

Fuente: fuente.wav ("Extended Dark Ambient BGM", 179,6 s, 48 kHz estereo), la
pista que eligio el usuario. Es una pista extendida: respira (baja casi a
silencio hacia los 59 s y de 173,5 a 176,5 s) y en los ultimos 2,6 s arranca
otra cosa que queda cortada. Ademas empieza de golpe, sin fundido.

Bucle: se corta en el silencio de 176,5 s y los ultimos CRUCE segundos (que ya
se apagan solos) se funden con los primeros (fundido de igual potencia). La
salida empieza en CRUCE, asi al volver al principio sigue justo donde acaba el
fundido: no hay salto ni silencio.

Sale a assets/audio/musica_camino_bosque.ogg (Vorbis); el bucle lo activa
camino_bosque.gd.

Uso: python construye.py
"""
import os
import subprocess
import wave

import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, "..", "..", "..", ".."))
FFMPEG = os.path.join(PROYECTO, "tools", "ffmpeg", "bin", "ffmpeg.exe")
SALIDA = os.path.join(PROYECTO, "assets", "audio", "musica_camino_bosque.ogg")

CORTE = 176.5   # s: el silencio antes de lo que queda cortado
CRUCE = 5.0     # s de fundido cruzado entre el final y el principio


def main():
	w = wave.open(os.path.join(AQUI, "fuente.wav"))
	sr = w.getframerate()
	a = np.frombuffer(w.readframes(w.getnframes()), np.int16).reshape(-1, 2).astype(np.float32) / 32768.0
	fin = int(CORTE * sr)
	x = int(CRUCE * sr)
	t = np.linspace(0.0, 1.0, x, dtype=np.float32)[:, None]
	sale = np.cos(t * np.pi / 2.0)
	entra = np.sin(t * np.pi / 2.0)
	bucle = a[x:fin].copy()
	bucle[-x:] = a[fin - x:fin] * sale + a[:x] * entra
	print("bucle de %.1f s (cruce %.1f s)" % (len(bucle) / sr, CRUCE))

	tmp = os.path.join(AQUI, "_bucle.wav")
	with wave.open(tmp, "wb") as o:
		o.setnchannels(2)
		o.setsampwidth(2)
		o.setframerate(sr)
		o.writeframes((np.clip(bucle, -1.0, 1.0) * 32767.0).astype(np.int16).tobytes())
	subprocess.run([FFMPEG, "-loglevel", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "6", SALIDA], check=True)
	os.remove(tmp)
	print("->", SALIDA)


if __name__ == "__main__":
	main()
