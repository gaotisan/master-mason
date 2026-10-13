"""La nota del hilo: lo que suena mientras baja el baculo por la luz (2026-10-14).

Guion 1.3: "una nota aguda sostenida, como un hilo que vibra". Los criticos
propusieron que el peregrino no dijera nada mientras baja ("que hablen imagen,
hojas y sonido"); sin sonido, la frase era lo unico que hacia mirar arriba (el
jugador acaba de salir por un borde y el baculo asoma arriba, en el centro).
Con esta nota la bajada va en silencio.

Un mi agudo (E6) con su gemelo un pelin desafinado (el batido lento de un
cristal o una cuerda que vibra), un vaiven de afinacion que crece, un soplo de
ruido estrecho alrededor de la nota (el roce del hilo) y una cola de sala.
Entra en ENTRADA s, se sostiene mientras baja (bajada de baculo.gd, 6,5 s) y se
apaga cuando se queda flotando. Sin bucle.

  assets/audio/baculo_hilo.wav   48 kHz, estereo, sostenido a RMS_DB dBFS

Uso: python hilo.py
"""
import os
import wave

import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, "..", "..", "..", ".."))
SALIDA = os.path.join(PROYECTO, "assets", "audio", "baculo_hilo.wav")

SR = 48000
DURA = 10.0
F0 = 1318.5          # mi 6
GEMELO = 1.0012      # el otro, desafinado: batido de ~1,6 Hz
ENTRADA = 2.2        # s hasta arriba
SOSTIENE = 5.8       # s desde el principio hasta que empieza a irse
RMS_DB = -18.0       # nivel del sostenido en el fichero
SEMILLA = 7


def banda(ruido, centro, ancho):
	"""Ruido filtrado a una banda estrecha (gaussiana en frecuencia)."""
	f = np.fft.rfftfreq(len(ruido), 1.0 / SR)
	esp = np.fft.rfft(ruido) * np.exp(-0.5 * ((f - centro) / ancho) ** 2)
	return np.fft.irfft(esp, len(ruido))


def sala(x, rng, dura=2.8, caida=0.85):
	"""Cola de sala: convolucion con ruido que se apaga, sin agudos."""
	n = int(dura * SR)
	t = np.arange(n) / SR
	ir = rng.standard_normal(n) * np.exp(-t / caida)
	f = np.fft.rfftfreq(n, 1.0 / SR)
	ir = np.fft.irfft(np.fft.rfft(ir) * np.exp(-(f / 5500.0) ** 2), n)
	ir /= np.sqrt((ir ** 2).sum())
	m = len(x) + n - 1
	k = 1 << (m - 1).bit_length()
	y = np.fft.irfft(np.fft.rfft(x, k) * np.fft.rfft(ir, k), k)[:len(x)]
	return y


def canal(rng, t, desfase):
	# Vaiven de afinacion: crece de 0 a 4 centesimas en 3 s, a ~4,8 Hz, con
	# algo de deriva lenta para que no suene a maquina.
	deriva = np.cumsum(rng.standard_normal(len(t))) / SR
	deriva = (deriva - np.linspace(deriva[0], deriva[-1], len(t))) * 0.6
	vib = np.minimum(t / 3.0, 1.0) * 4.0 * np.sin(2 * np.pi * (4.8 * t + 0.15 * deriva) + desfase)
	cents = vib / 1200.0
	fase = 2 * np.pi * np.cumsum(F0 * 2.0 ** cents) / SR
	fase2 = 2 * np.pi * np.cumsum(F0 * GEMELO * 2.0 ** (cents * 0.8)) / SR
	x = np.sin(fase + desfase) + 0.5 * np.sin(fase2 + 2 * desfase)
	# Octava muy baja, con su propio respirar.
	x += 0.07 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.37 * t + desfase)) * np.sin(2 * fase)
	# El roce del hilo: ruido estrecho alrededor de la nota.
	roce = banda(rng.standard_normal(len(t)), F0, 18.0)
	x += 0.18 * roce / (np.sqrt((roce ** 2).mean()) + 1e-9) * np.sqrt(0.5)
	return x


def envolvente(t):
	sube = np.clip(t / ENTRADA, 0.0, 1.0)
	sube = sube * sube * (3 - 2 * sube)
	baja = np.where(t < SOSTIENE, 1.0, np.exp(-(t - SOSTIENE) / 0.9))
	# un pelin de hinchado en mitad del sostenido
	hincha = 1.0 + 0.08 * np.sin(np.pi * np.clip((t - ENTRADA) / (SOSTIENE - ENTRADA), 0.0, 1.0))
	return sube * baja * hincha


def main():
	rng = np.random.default_rng(SEMILLA)
	t = np.arange(int(DURA * SR)) / SR
	env = envolvente(t)
	izq = canal(rng, t, 0.0) * env
	der = canal(rng, t, 1.3) * env
	izq = 0.65 * izq + 0.35 * sala(izq, rng)
	der = 0.65 * der + 0.35 * sala(der, rng)
	est = np.stack([izq, der], 1)
	# Nivel: RMS del sostenido a RMS_DB; el pico, por debajo de -1 dBFS.
	trozo = est[int(ENTRADA * SR):int(SOSTIENE * SR)]
	est *= 10 ** (RMS_DB / 20) / np.sqrt((trozo ** 2).mean())
	pico = np.abs(est).max()
	if pico > 10 ** (-1 / 20):
		est *= 10 ** (-1 / 20) / pico
	# Fundidos de 5 ms en las puntas.
	f = int(0.005 * SR)
	est[:f] *= np.linspace(0, 1, f)[:, None]
	est[-f:] *= np.linspace(1, 0, f)[:, None]
	datos = (np.clip(est, -1, 1) * 32767).astype(np.int16)
	with wave.open(SALIDA, "wb") as w:
		w.setnchannels(2)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes(datos.tobytes())
	print("baculo_hilo.wav %.1f s, pico %.1f dBFS" % (DURA, 20 * np.log10(np.abs(est).max())))


if __name__ == "__main__":
	main()
