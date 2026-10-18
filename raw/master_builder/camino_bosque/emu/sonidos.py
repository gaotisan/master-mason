"""Sonidos de la embestida del emu (2026-10-17): lo que le falta al del video.

El sonido del video (emu_camino.ogg) ya trae las pisadas de la carrera, pero
flojas (rms 0,03-0,05 contra 0,12 del graznido) y sin crecer: no se le oia
venir. Aqui se hacen, para ponerlas encima en la escena (emu_camino.gd):

  emu_pisada_1..4.wav  pisada pesada en la hojarasca: una pisada de la
                       hojarasca (hojarasca_paso_N) mas grave y un golpe sordo
                       de pata grande debajo.
  emu_paso_aire.wav    el aire que mueve al pasar rozando: ruido con un filtro
                       que sube y baja (como el efecto Doppler), con el pico en
                       PICO_AIRE s.
  emu_golpe.wav        golpe grave cuando pasa (con la sacudida de camara).

Uso: python sonidos.py
"""
import os
import wave

import numpy as np
from scipy import signal

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, "..", "..", "..", ".."))
AUDIO = os.path.join(PROYECTO, "assets", "audio")
SR = 48000
PISADAS = (2, 5, 8, 11)        # de que hojarasca_paso_N sale cada una
GRAVE = 0.78                   # la pisada de hojas, mas lenta y grave
PICO_AIRE = 0.28
rng = np.random.default_rng(7)


def leer(nombre):
	with wave.open(os.path.join(AUDIO, nombre)) as w:
		x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768.0
		if w.getnchannels() == 2:
			x = x.reshape(-1, 2).mean(1)
	return x


def guardar(nombre, x, pico_db=-3.0):
	x = x / max(np.abs(x).max(), 1e-6) * 10 ** (pico_db / 20.0)
	with wave.open(os.path.join(AUDIO, nombre), "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
	print("  ", nombre, round(len(x) / SR, 2), "s")


def t(seg):
	return np.arange(int(seg * SR)) / SR


def golpe_sordo(dur, f0, f1, tau):
	"""Seno que cae de f0 a f1 con ataque corto y caida exponencial."""
	tt = t(dur)
	f = f1 + (f0 - f1) * np.exp(-tt / (tau * 0.6))
	fase = 2 * np.pi * np.cumsum(f) / SR
	env = (1 - np.exp(-tt / 0.003)) * np.exp(-tt / tau)
	return np.sin(fase) * env


def paso_bajo(x, hz, orden=4):
	return signal.sosfilt(signal.butter(orden, hz, "low", fs=SR, output="sos"), x)


def pisada(n):
	hojas = leer("hojarasca_paso_%d.wav" % n)
	hojas = signal.resample(hojas, int(len(hojas) / GRAVE))
	# donde pisa: el primer golpe de las hojas
	ini = int(np.argmax(np.abs(hojas) > 0.3 * np.abs(hojas).max()))
	pata = golpe_sordo(0.35, 95.0, 48.0, 0.07)
	# el roce de la pata al entrar (ruido sordo, muy corto)
	roce = paso_bajo(rng.standard_normal(int(0.04 * SR)), 900.0) * np.exp(-t(0.04) / 0.008)
	x = hojas.copy()
	x = np.pad(x, (0, max(0, ini + len(pata) - len(x))))
	x[ini:ini + len(pata)] += pata * 0.55 * np.abs(hojas).max() / 0.3
	x[ini:ini + len(roce)] += roce * 0.25
	x = x[:int(0.6 * SR)]
	cola = np.minimum(1.0, (len(x) / SR - np.arange(len(x)) / SR) / 0.08)
	return x * cola


def aire():
	dur = 1.0
	tt = t(dur)
	ruido = rng.standard_normal(len(tt))
	# filtro de banda que sube hasta el pico y cae (Doppler), por tramos con
	# solapamiento
	centro = np.where(tt < PICO_AIRE, 350 + 1500 * (tt / PICO_AIRE) ** 2,
					  250 + 1600 * np.exp(-(tt - PICO_AIRE) / 0.12))
	salida = np.zeros_like(ruido)
	tramo, paso = 2048, 512
	ventana = np.hanning(tramo)
	for i in range(0, len(ruido) - tramo, paso):
		c = centro[i + tramo // 2]
		sos = signal.butter(2, [c * 0.55, c * 1.6], "band", fs=SR, output="sos")
		salida[i:i + tramo] += signal.sosfilt(sos, ruido[i:i + tramo]) * ventana
	env = np.where(tt < PICO_AIRE, (tt / PICO_AIRE) ** 3, np.exp(-(tt - PICO_AIRE) / 0.16))
	cuerpo = paso_bajo(ruido, 220.0) * env * 0.6
	return salida * env + cuerpo


def golpe():
	sub = golpe_sordo(0.9, 58.0, 33.0, 0.28)
	rumor = paso_bajo(rng.standard_normal(int(0.9 * SR)), 140.0) * np.exp(-t(0.9) / 0.3) * 0.5
	return sub + rumor


def main():
	for i, n in enumerate(PISADAS):
		guardar("emu_pisada_%d.wav" % (i + 1), pisada(n))
	guardar("emu_paso_aire.wav", aire())
	guardar("emu_golpe.wav", golpe())


if __name__ == "__main__":
	main()
