"""Sonidos de los menus (2026-10-18), sintetizados: moverse, elegir y volver.

Discretos y calidos, a juego con la bola del baculo que marca la opcion: un toque
de cristal grave (parciales de campana, ataque corto y caida exponencial) con una
cola de sala corta. El cuerpo va por debajo de ~900 Hz porque en la pausa todo
pasa por un paso bajo a 900 Hz (menu_pausa.gd, "oido de lejos") y lo agudo se
perderia.

  menu_mover.wav   corto y suave, al cambiar de opcion (y al cambiar un valor)
  menu_elegir.wav  algo mas grave y lleno, al elegir
  menu_volver.wav  el toque que baja de tono, mas apagado, al volver (Esc/Volver)

Uso: python sintetiza.py   (escribe en assets/audio/ui/)
"""
import os
import wave

import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, "..", "..", "..", ".."))
SALIDA = os.path.join(PROYECTO, "assets", "audio", "ui")
SR = 44100


def toque(f0, dur, caida, parciales, glide=1.0, glide_t=0.0, rng=None):
    """Campana: parciales (razon, nivel, caida relativa) sobre f0, que puede
    deslizarse de f0 a f0*glide en glide_t s."""
    t = np.arange(int(SR * dur)) / SR
    if glide != 1.0 and glide_t > 0:
        k = np.clip(t / glide_t, 0, 1)
        k = k * k * (3 - 2 * k)
        f = f0 * (1 + (glide - 1) * k)
    else:
        f = np.full_like(t, f0)
    fase = 2 * np.pi * np.cumsum(f) / SR
    s = np.zeros_like(t)
    for razon, nivel, rel in parciales:
        # un hilo de batido entre dos copias apenas desafinadas (vida)
        d = 1.0 + 0.0015 * (rng.random() - 0.5) if rng is not None else 1.0
        s += nivel * np.exp(-t / (caida * rel)) * 0.5 * (np.sin(fase * razon) + np.sin(fase * razon * d))
    ataque = np.clip(t / 0.004, 0, 1)
    return s * ataque


def sala(x, dur=0.5, mezcla=0.14, semilla=3):
    """Cola de sala corta: convolucion con ruido que cae, filtrado suave."""
    rng = np.random.default_rng(semilla)
    n = int(SR * dur)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (SR * dur / 5))
    # quitarle agudos al ruido (media movil corta)
    ir = np.convolve(ir, np.ones(6) / 6, mode="same")
    ir /= np.sqrt(np.sum(ir ** 2))
    cola = np.convolve(x, ir)                      # len(x) + n - 1
    seco = np.concatenate([x, np.zeros(n - 1)])
    return seco * (1 - mezcla) + cola * mezcla


def escribir(nombre, x, pico_db):
    x = x / np.max(np.abs(x)) * 10 ** (pico_db / 20)
    # fundido al final para no cortar
    f = int(SR * 0.03)
    x[-f:] *= np.linspace(1, 0, f)
    os.makedirs(SALIDA, exist_ok=True)
    ruta = os.path.join(SALIDA, nombre)
    with wave.open(ruta, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    print("escrito", ruta, f"{len(x) / SR:.2f} s")


def main():
    rng = np.random.default_rng(7)
    # parciales de campana de cristal (razones casi armonicas, la 2.76 da el cristal)
    cristal = [(1.0, 1.0, 1.0), (2.0, 0.35, 0.6), (2.76, 0.22, 0.45), (4.07, 0.08, 0.3)]
    mover = toque(698.5, 0.45, 0.11, cristal, rng=rng)                  # F5
    escribir("menu_mover.wav", sala(mover, 0.35, 0.12), -17.0)
    elegir = toque(523.3, 0.9, 0.24, cristal, rng=rng)                  # C5
    elegir += 0.5 * toque(784.0, 0.9, 0.2, cristal, rng=rng)            # G5, quinta
    elegir += 0.25 * toque(261.6, 0.9, 0.12, [(1.0, 1.0, 1.0), (2.0, 0.3, 0.6)], rng=rng)  # cuerpo
    escribir("menu_elegir.wav", sala(elegir, 0.6, 0.16), -14.5)
    volver = toque(659.3, 0.55, 0.13, cristal, glide=0.75, glide_t=0.09, rng=rng)  # E5 -> B4
    escribir("menu_volver.wav", sala(volver, 0.4, 0.12), -18.5)


if __name__ == "__main__":
    main()
