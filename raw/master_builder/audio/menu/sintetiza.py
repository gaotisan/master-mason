"""Sonidos de los menus (2026-10-18), sintetizados: moverse, elegir y volver.

Discretos y calidos, a juego con la bola del baculo que marca la opcion: un toque
de cristal grave (parciales de campana, ataque corto y caida exponencial) con una
cola de sala corta. El cuerpo va por debajo de ~900 Hz porque en la pausa todo
pasa por un paso bajo a 900 Hz (menu_pausa.gd, "oido de lejos") y lo agudo se
perderia.

  menu_mover.wav   al cambiar de opcion (y de valor): un toque suave y redondo,
                   como una baqueta de fieltro sobre madera (marimba apagada)
  menu_elegir.wav  la misma madera en un solo golpe con dos notas a la vez,
                   Sol4 y Re5 (una quinta): mas lleno que el de moverse
  menu_volver.wav  el cristal grave en Do5 (Esc y la opcion Volver): suena mas
                   a "atras" que a elegir
(Probados y descartados: un toque de volver que bajaba de tono, "raro"; el
cristal para elegir, "suena a no poder, a back"; elegir en dos toques seguidos,
"como dos sonidos".)

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


def madera(f0, dur, rng):
    """Marimba apagada: fundamental y los parciales de la marimba (4 y 9,9),
    que se apagan muy deprisa, mas el golpe blando de la baqueta (ruido grave
    de unos ms)."""
    t = np.arange(int(SR * dur)) / SR
    s = np.sin(2 * np.pi * f0 * t) * np.exp(-t / 0.085)
    s += 0.12 * np.sin(2 * np.pi * f0 * 4.0 * t) * np.exp(-t / 0.018)
    s += 0.03 * np.sin(2 * np.pi * f0 * 9.9 * t) * np.exp(-t / 0.008)
    golpe = rng.standard_normal(len(t)) * np.exp(-t / 0.004)
    golpe = np.convolve(golpe, np.ones(24) / 24, mode="same")      # sin agudos
    s += 0.25 * golpe
    ataque = np.clip(t / 0.003, 0, 1)
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
    # parciales de campana de cristal (razones casi armonicas, la 2.76 da el
    # cristal), con lo de arriba apagado
    # pulsar: cristal en Do5, apagado arriba (en Fa5 era algo agudo)
    suave = [(1.0, 1.0, 1.0), (2.0, 0.28, 0.6), (2.76, 0.1, 0.45), (4.07, 0.03, 0.3)]
    cristal_c5 = toque(523.3, 0.45, 0.11, suave, rng=rng)               # C5
    escribir("menu_volver.wav", sala(cristal_c5, 0.35, 0.12), -23.0)
    madera_g4 = madera(392.0, 0.3, rng)                                  # G4
    escribir("menu_mover.wav", sala(madera_g4, 0.3, 0.1), -24.0)
    # elegir: Sol4 y Re5 a la vez, la quinta algo mas suave
    elegir = madera(392.0, 0.36, rng) + 0.7 * madera(587.3, 0.36, rng)
    escribir("menu_elegir.wav", sala(elegir, 0.3, 0.1), -23.0)


if __name__ == "__main__":
    main()
