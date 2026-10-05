"""Efectos de Magnus sacados del audio de los videos de animacion.

Los videos de _fuentes traen audio sincronizado con la imagen (medido: el golpe
de cada paso cae medio fotograma despues del sprite en que el pie planta). Aqui
se extrae ese audio, se recortan los golpes sueltos y se montan los bucles con la
duracion exacta de cada ciclo del SpriteFrames.

    python construye.py

Escribe 01_extraido\\ (WAV mono del video entero) y 02_salida\\ (WAV, OGG, ficha y
grafica de comprobacion). Al repo va lo que dice la ficha, a assets\\audio\\.

Convenciones de tiempo: los fotogramas del video van a 24 fps y se numeran
desde 1 (el fotograma N empieza en (N-1)/24 s), igual que en anim\\<job>\\01_frames.
El sprite i (desde 0) de un ciclo ocupa [i/fps, (i+1)/fps) del bucle.
"""
import os, subprocess, numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfiltfilt, resample_poly, stft, istft
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", "..", "..", ".."))
FFMPEG = os.path.join(RAIZ, "tools", "ffmpeg", "bin", "ffmpeg.exe")
FUENTES = os.path.join(RAIZ, "raw", "master_mason", "anim", "_fuentes")
EXTRAIDO = os.path.join(AQUI, "01_extraido"); SALIDA = os.path.join(AQUI, "02_salida")
os.makedirs(EXTRAIDO, exist_ok=True); os.makedirs(SALIDA, exist_ok=True)
SR = 48000

VIDEOS = {"andando": "magnus_andando_con_parada a pose side.mp4",
          "corriendo": "magnus_corriendo.mp4",
          "respirando": "magnus_respirando.mp4"}

def ff(*args):
    subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-y", *args], check=True)

def extrae(clave):
    wav = os.path.join(EXTRAIDO, f"{clave}.wav")
    if not os.path.exists(wav):
        ff("-i", os.path.join(FUENTES, VIDEOS[clave]), "-vn", "-ac", "1", "-ar", str(SR), "-c:a", "pcm_s16le", wav)
    sr, x = wavfile.read(wav); assert sr == SR
    return x.astype(np.float64) / 32768

def s(t): return int(round(t * SR))
def hp(x, fc, orden=2): return sosfiltfilt(butter(orden, fc, btype="high", fs=SR, output="sos"), x)

def fade(x, fin, fout):
    x = x.copy(); a = s(fin); b = s(fout)
    if a: x[:a] *= np.linspace(0, 1, a)
    if b: x[-b:] *= np.linspace(1, 0, b) ** 2
    return x

def ataque(x, t_desde, t_hasta):
    """Primer instante en que la envolvente de 2 ms supera 6x el suelo de ruido previo."""
    seg = np.abs(x[s(t_desde):s(t_hasta)]); w = s(0.002)
    e = np.convolve(seg, np.ones(w) / w, "same")
    suelo = np.median(e[:s(0.03)])
    return t_desde + int(np.argmax(e > max(6 * suelo, 0.004))) / SR

def mezcla(bucle, p, t):
    """Suma p en el bucle a partir de t, dando la vuelta si se sale por el final."""
    n = len(bucle); idx = (np.arange(len(p)) + s(t)) % n; np.add.at(bucle, idx, p)

ficha = []
def guarda(nombre, x, ogg=False, nota=""):
    x = np.clip(x, -1, 1)
    wav = os.path.join(SALIDA, nombre + ".wav")
    wavfile.write(wav, SR, (x * 32767).astype(np.int16))
    if ogg: ff("-i", wav, "-c:a", "libvorbis", "-q:a", "6", os.path.join(SALIDA, nombre + ".ogg"))
    linea = f"{nombre + ('.ogg' if ogg else '.wav'):30s} {len(x)/SR:6.3f} s  pico {20*np.log10(np.abs(x).max()):5.1f} dBFS  {nota}"
    ficha.append(linea); print(linea)

PRE = 0.006       # colchon antes del ataque en cada golpe suelto
DESFASE = 0.5     # el golpe suena ~medio fotograma despues de entrar el sprite de contacto

# ============ ANDAR: ciclo video 53-86 -> 34 sprites a 24 fps = 1,4167 s
T0 = 52 / 24; N = 34
x = hp(extrae("andando"), 80)
tA = ataque(x, 2.10, 2.30); tB = ataque(x, 2.78, 3.00); tC = ataque(x, 3.48, 3.62)
print(f"andar: ataques en el video A={tA:.3f}s (sprite {(tA-T0)*24:+.2f}) B={tB:.3f}s (sprite {(tB-T0)*24:.2f}) "
      f"C={tC:.3f}s (sprite {(tC-T0)*24:.2f}; C es el A del ciclo siguiente, periodo {tC-tA:.3f}s)")
pasoA = fade(x[s(tA - PRE):s(tA + 0.50)], 0.002, 0.15)
pasoB = fade(x[s(tB - PRE):s(tB + 0.55)], 0.002, 0.15)
g = 0.5 / max(np.abs(pasoA).max(), np.abs(pasoB).max())      # la pareja a -6 dBFS, misma ganancia
pasoA *= g; pasoB *= g
guarda("magnus_paso_a", pasoA, nota="golpe suelto, pie que planta en el sprite 1 de andar")
guarda("magnus_paso_b", pasoB, nota="golpe suelto, pie que planta en el sprite 17 de andar")
# El bucle: los dos pasos en su instante original sobre silencio. El tercer ataque
# del corte literal ya es el paso A de la vuelta siguiente y se doblaria.
andar = np.zeros(N * SR // 24)
mezcla(andar, pasoA, max(tA - T0, 0.0) - PRE); mezcla(andar, pasoB, (tB - T0) - PRE)
guarda("magnus_andar_ciclo", andar, ogg=True, nota=f"bucle 34 sprites; pasos en t=0 y t={tB-T0:.3f}")

# ============ CORRER con los pasos de andar: ciclo video 68-91 -> 24 sprites = 1,000 s
# Medido en 04_limpios: el pie planta en los sprites 5 y 17 (idx 4 y 16).
FACTOR = 1.15; GANANCIA = 10 ** (3 / 20)     # mas corto y agudo, +3 dB: pisa mas fuerte
def acelera(p): return resample_poly(p, 1000, int(round(1000 * FACTOR)))
pcA = acelera(pasoA) * GANANCIA; pcB = acelera(pasoB) * GANANCIA
guarda("magnus_paso_correr_a", pcA, nota="paso_a x1,15 +3 dB; pie que planta en el sprite 5 de correr")
guarda("magnus_paso_correr_b", pcB, nota="paso_b x1,15 +3 dB; pie que planta en el sprite 17 de correr")
correr = np.zeros(SR)
for p, idx in ((pcA, 4), (pcB, 16)): mezcla(correr, p, (idx + DESFASE) / 24 - PRE)
guarda("magnus_correr_ciclo", correr, ogg=True, nota=f"bucle 24 sprites; pasos en t={(4+DESFASE)/24:.3f} y t={(16+DESFASE)/24:.3f}")

# ============ CORRER alternativo: el audio del propio video de correr
y = hp(extrae("corriendo"), 80); R0 = 67 / 24
alt = fade(y[s(R0):s(R0) + SR], 0.01, 0.01); alt *= 0.5 / np.abs(alt).max()
guarda("magnus_correr_ciclo_video", alt, ogg=True,
       nota=f"alternativa: corte literal del video de correr; ataques en sprite {(ataque(y,2.85,3.05)-R0)*24:.1f} y {(ataque(y,3.38,3.55)-R0)*24:.1f}")

# ============ RESPIRAR: ciclo video 115-173 (cada 2 fotogramas) -> 30 sprites a 12 fps = 2,5 s
# El video trae un zumbido continuo (lineas fijas en 300-600 Hz, 1 kHz y 1,8 kHz) que
# suena tambien en las pausas. Se le resta su espectro, medido en la pausa entre
# respiraciones, y lo que queda es el aliento: inhala en 5,6-6,1 s (el pecho crece
# hasta el sprite 19, en 6,25 s) y exhala en 6,3-6,9 s.
def quita_zumbido(x, pausas, exceso=2.5, piso=0.03):
    N_, H_ = 2048, 512
    f_, t_, Z = stft(x, SR, nperseg=N_, noverlap=N_ - H_)
    m = np.zeros(len(t_), bool)
    for a, b in pausas: m |= (t_ > a) & (t_ < b)
    zumbido = np.median(np.abs(Z[:, m]), axis=1, keepdims=True)
    ganancia = np.maximum(1 - exceso * zumbido / (np.abs(Z) + 1e-9), piso)
    _, y = istft(Z * ganancia, SR, nperseg=N_, noverlap=N_ - H_)
    return y[:len(x)]
B0 = 114 / 24; L = s(2.5); XF = s(0.25)
z = hp(quita_zumbido(extrae("respirando"), [(0.0, 0.4), (4.8, 5.5)]), 150)
resp = z[s(B0):s(B0) + L].copy()
previo = z[s(B0) - XF:s(B0)]                # lo que sonaba justo antes: cierra el bucle sin corte
w = np.linspace(0, 1, XF); resp[-XF:] = resp[-XF:] * np.cos(w * np.pi / 2) + previo * np.sin(w * np.pi / 2)
resp *= 0.5 / np.abs(resp).max()
guarda("magnus_respirar_ciclo_v1", resp, ogg=True, nota="ANTIGUO, del video de respirando: bucle 2,5 s; inhala ~0,85-1,35 s, exhala ~1,55-2,15 s")

# ============ RESPIRAR v2: video Elderly_mystic_breathing_calmly (efecto aislado)
# Sustituye al recorte del video de respirando, que llevaba zumbido y habia que
# restarselo. Este trae la respiracion sola y limpia, pero MUY baja (pico -40
# dBFS) y con tres respiraciones irregulares:
#   A  0,78-3,08 s   inspiracion fuerte (pico 1,52) + espiracion suave (pico 2,27)
#   B  3,08-4,80     igual, y luego un silencio de 1 s
#   C  5,86-8,00     igual, cortada por el final del video
# Se usa la A, que es la unica completa de valle a valle: 2,30 s. La animacion
# dura 2,50 (30 sprites a 12 fps), asi que se estira un 8,7 % con atempo (sin
# cambiar el tono) y se gira 0,40 s para que la inspiracion caiga donde el pecho
# crece (sprites 10-19, 0,85-1,58 s) y la espiracion donde baja (1,55-2,15):
# tras el giro, pico de inspiracion en ~1,2 s y de espiracion en ~2,0 s. La
# costura del bucle cae en el valle entre respiraciones, con el mismo fundido
# cruzado de 0,25 s que se usaba antes. Que la fuerte sea la inspiracion se
# decide por el espectro: es mas aguda (+2 dB agudo/grave frente a -8 la suave),
# como un resoplido por la nariz; la suave es el suspiro al soltar.
VIDEOS["respirar"] = "Elderly_mystic_breathing_calmly_20260924111539.mp4"
rv = hp(extrae("respirar"), 80)
RA, RB = 0.78, 3.08                       # ciclo A, de valle a valle
ciclo = rv[s(RA):s(RB)]
tmp_r1 = os.path.join(EXTRAIDO, "respirar_ciclo_2p30.wav"); tmp_r2 = os.path.join(EXTRAIDO, "respirar_ciclo_2p50.wav")
wavfile.write(tmp_r1, SR, (np.clip(ciclo / np.abs(ciclo).max() * 0.5, -1, 1) * 32767).astype(np.int16))
ff("-i", tmp_r1, "-filter:a", f"atempo={(RB - RA) / 2.5:.5f}", "-ar", str(SR), tmp_r2)
_, r25 = wavfile.read(tmp_r2); r25 = r25.astype(np.float64) / 32768
L = s(2.5)
if len(r25) < L: r25 = np.concatenate([r25, np.zeros(L - len(r25))])
r25 = r25[:L]
GIRO = 0.40                               # la inspiracion empieza en el bucle a los 0,40 s
resp2 = np.roll(r25, s(GIRO))
# costura: lo que suena justo antes del corte (final del ciclo) se funde con el principio
XF2 = s(0.25); w2 = np.linspace(0, 1, XF2)
corte = s(GIRO)                           # aqui esta la costura tras el giro
antes_c = resp2[corte - XF2:corte].copy(); despues_c = resp2[corte:corte + XF2].copy()
resp2[corte:corte + XF2] = despues_c * np.sin(w2 * np.pi / 2) + antes_c * np.cos(w2 * np.pi / 2)
resp2 *= 0.5 / np.abs(resp2).max()
tI = (1.52 - RA) * 2.5 / (RB - RA) + GIRO; tE = (2.27 - RA) * 2.5 / (RB - RA) + GIRO
guarda("magnus_respirar_ciclo", resp2, ogg=True,
       nota=f"bucle 2,5 s del video de respiracion aislada (ciclo A estirado x{2.5/(RB-RA):.3f}); inspira pico {tI:.2f} s, espira pico {tE:.2f} s")
resp = resp2                              # la grafica de comprobacion muestra el que va al juego

# ============ CAIDA (cinematica de entrada): video Character_falling_and_standing_up.mp4
# El audio del video trae tres cosas, y las tres se usan:
#   - un silbido de aire que sube mientras cae (0,3-1,5 s, de -45 a -35 dB)
#   - el golpe al estamparse (pico -6,8 dBFS en 1,71 s, con cola hasta 2,6 s)
#   - el roce de la ropa al levantarse (3,5-8,6 s, flojo, -50 a -60 dB)
# En el juego la caida la mueve el nodo (caida_duracion), no el video, asi que el
# aire se recorta de forma que TERMINE en el golpe y magnus.gd lo arranca
# caida_duracion antes del impacto. Levantarse va mas rapido que el video (63
# sprites a 20 fps = 3,15 s frente a 5,2 s): el roce se acelera con atempo, que
# conserva el tono, para que dure lo que dura la animacion.
VIDEOS["caida"] = "Character_falling_and_standing_up.mp4"
c = hp(extrae("caida"), 60)
F_CAIDA = 33                       # primer fotograma del video en la animacion "caida"
tG = ataque(c, 1.45, 1.75)         # golpe: primer ataque fuerte tras el descenso
spr_golpe = (tG - (F_CAIDA - 1) / 24) * 24
print(f"caida: golpe en el video en {tG:.3f}s = fotograma {tG*24+1:.1f}, sprite {spr_golpe:.2f} de la animacion caida (indice desde 0)")
golpe = fade(c[s(tG - PRE):s(2.65)], 0.002, 0.35)
golpe *= 0.7 / np.abs(golpe).max()                                # -3 dBFS: es el golpe de la escena
guarda("magnus_caida_golpe", golpe, nota=f"se estampa; disparar en el sprite {int(round(spr_golpe))} de caida (ataque en el video: {tG:.3f}s)")
aire = fade(c[s(0.25):s(tG - PRE)], 0.15, 0.02)                   # acaba justo donde empieza el golpe
aire *= 0.5 / np.abs(aire).max()
guarda("magnus_caida_aire", aire, ogg=True, nota=f"aire de la caida, {len(aire)/SR:.2f} s; magnus.gd lo arranca para que acabe en el impacto")
# Roce al levantarse: del video 82-206 (3,375-8,583 s) a 63 sprites a 20 fps.
L0, L1 = 81 / 24, 206 / 24; DUR_LEV = 63 / 20.0
factor = (L1 - L0) / DUR_LEV
tmp_in = os.path.join(EXTRAIDO, "levantarse_lento.wav"); tmp_out = os.path.join(EXTRAIDO, "levantarse_rapido.wav")
wavfile.write(tmp_in, SR, (np.clip(fade(c[s(L0):s(L1)], 0.05, 0.30), -1, 1) * 32767).astype(np.int16))
ff("-i", tmp_in, "-filter:a", f"atempo={factor:.4f}", "-ar", str(SR), tmp_out)
_, lev = wavfile.read(tmp_out); lev = lev.astype(np.float64) / 32768
lev = fade(lev[:s(DUR_LEV)], 0.02, 0.25); lev *= 0.5 / np.abs(lev).max()
guarda("magnus_levantarse", lev, ogg=True, nota=f"roce de la ropa al levantarse, video 82-206 acelerado x{factor:.2f} (atempo) a {DUR_LEV:.2f} s")
def envolvente_(x, ms=5):
    w = s(ms / 1000); n = len(x) // w; return np.sqrt((x[:n * w].reshape(n, w) ** 2).mean(1)), w / SR
fig2, ax2 = plt.subplots(3, 1, figsize=(14, 8))
for ax, (nombre, sig, marcas) in zip(ax2, [(f"aire de la caida ({len(aire)/SR:.2f} s, acaba en el golpe)", aire, []),
                                           (f"golpe (sprite {spr_golpe:.1f} de caida)", golpe, [PRE]),
                                           (f"levantarse x{factor:.2f} ({DUR_LEV:.2f} s = 63 sprites a 20 fps)", lev, [i / 20 for i in range(64)])]):
    e, dt = envolvente_(sig); t = np.arange(len(e)) * dt
    ax.fill_between(t, e, color="#c98a3a"); ax.set_title(nombre, loc="left"); ax.set_xlim(0, len(sig) / SR); ax.set_yticks([])
    for m in marcas: ax.axvline(m, color="#999", lw=0.4)
ax2[-1].set_xlabel("segundos"); plt.tight_layout(); plt.savefig(os.path.join(SALIDA, "comprobacion_caida.png"), dpi=90)

# ============ SALTOS: despegues y aterrizajes, del audio de sus propios videos
# Los dos saltos eran mudos: la unica pisada que sonaba era la del ciclo al que
# se volvia. Los videos traen el empujon al despegar y el golpe al caer, y van
# sincronizados con la imagen como las pisadas. Instantes medidos con el ataque
# de la envolvente (10 ms) y pasados a sprite de la animacion:
#   saltar (Elderly_mystic_character_walking, sprites = video 89-158):
#     despegue 4,19 s -> sprite 13 (despega en el 15, indice 14; el empujon suena un sprite antes): pico -11,5 dB, cae en 0,09 s
#     caida    5,66 s -> sprite 48 (toca en el 46; el golpe llega dos sprites despues,
#              cuando asienta el cuerpo): dos contactos a 0,12 s, -18 dB
#   salto_correr (nuevo salto de piedra, sprites = video 128-165):
#     despegue 5,46 s -> sprite 4  (despega en el 3): -12,9 dB
#     caida    6,68 s -> sprite 33 (toca en el 30; el golpe es el segundo pie y el
#              cuerpo, tres sprites despues): -12,5 dB con cola de polvo
# magnus.gd los dispara desde frame_changed (tabla GOLPES); cuando se sigue
# corriendo al tocar suelo el sprite 35 no llega a verse y el golpe se dispara
# en el propio corte al ciclo. Los sprites de arriba son los del ataque medido,
# redondeados: (t*24 + 1) - primer fotograma del video en la animacion.
VIDEOS["salto_andando"] = "Elderly_mystic_character_walking.mp4"
VIDEOS["salto_piedra"] = "nuevo salto de piedra.mp4"
sa = hp(extrae("salto_andando"), 60); sp = hp(extrae("salto_piedra"), 60)
def golpe_suelto(x, t_aprox, largo, nombre, nota, ganancia_pico=0.5):
    t0 = ataque(x, t_aprox - 0.08, t_aprox + 0.12)
    g = fade(x[s(t0 - PRE):s(t0 + largo)], 0.002, largo * 0.5)
    g *= ganancia_pico / np.abs(g).max()
    guarda(nombre, g, nota=nota + f" (ataque en el video: {t0:.3f}s)")
golpe_suelto(sa, 4.24, 0.30, "magnus_salto_despegue", "empujon al despegar; sprite 13 de saltar")
golpe_suelto(sa, 5.66, 0.45, "magnus_salto_caida", "golpe al caer; sprite 48 de saltar")
golpe_suelto(sp, 5.51, 0.30, "magnus_salto_correr_despegue", "empujon al despegar; sprite 4 de salto_correr")
golpe_suelto(sp, 6.76, 0.45, "magnus_salto_correr_caida", "golpe al caer; sprite 33 de salto_correr, o al cortar al ciclo")


# ============ SALTO DESDE PARADO: video salto_en_parado.mp4 (sprites = video 34-80 + 116-134)
# El video trae dos saltos seguidos. La animacion usa el primero y la
# recuperacion del segundo, y el audio se coge de donde mejor suena:
#   despegue: ataque 2,130 s = fotograma 52 -> sprite 18. No es un golpe sino un
#             impulso que crece 0,22 s hasta -13 dB: se corta 0,40 s.
#   caida:    la del primer salto (3,346 s, fotograma 81) es floja, -28 dB; la del
#             segundo (4,788 s, fotograma 116) es limpia y fuerte, -17 dB. Se usa
#             la segunda, colocada donde toca suelo el primero: toca en el sprite
#             46 y el golpe llega un fotograma despues, sprite 47.
VIDEOS["salto_parado"] = "salto_en_parado.mp4"
spp = hp(extrae("salto_parado"), 60)
golpe_suelto(spp, 2.13, 0.40, "magnus_salto_parado_despegue", "impulso al despegar; sprite 18 de salto_parado")
golpe_suelto(spp, 4.788, 0.45, "magnus_salto_parado_caida", "golpe al caer; sprite 47 de salto_parado")


# ============ AGACHARSE: roce de la ropa al bajar y al levantarse
# El video del agacharse (Pilgrim_squatting_animation) trae MUSICA de fondo, no
# efectos: armonicos de 293 Hz (586, 879, 1172) a -35 dB todo el rato y ningun
# evento. No se usa nada de el. El roce sale del audio
# del video de la caida, del tramo en que se levanta del suelo (3,4-8,6 s), que
# es ropa rozando sin golpes: dos trozos de 0,8 s con ataque suave, lejos del
# unico transitorio del tramo (5,58 s, la rodilla). Comprobado que no llevan musica:
# ningun pico tonal, planitud espectral 0,38-0,43 como las pisadas. Duran lo que las animaciones:
# bajar 0,70 s y levantarse 0,75 s a 60 fps.
def roce(t0, largo, nombre, nota):
    r = fade(c[s(t0):s(t0 + largo)], 0.03, largo * 0.4)
    r *= 0.5 / np.abs(r).max()
    guarda(nombre, r, nota=nota)
roce(3.60, 0.80, "magnus_agacharse", "roce de la ropa al agacharse (caida 3,60-4,40 s)")
roce(7.55, 0.80, "magnus_incorporarse", "roce de la ropa al levantarse de agachado (caida 7,55-8,35 s)")


# ============ ficha y grafica
with open(os.path.join(SALIDA, "ficha.txt"), "w", encoding="utf-8") as f:
    f.write("Efectos de Magnus. Generado por construye.py a partir de los videos de anim\\_fuentes.\n")
    f.write("Al repo (assets\\audio\\) van: los 4 magnus_paso_*.wav y magnus_respirar_ciclo.ogg.\n")
    f.write("magnus_respirar_ciclo.ogg es el del video de respiracion aislada; _v1 es el antiguo, de referencia.\n")
    f.write("Cinematica de entrada: magnus_caida_golpe.wav, magnus_caida_aire.ogg y magnus_levantarse.ogg.\n")
    f.write("Saltos: magnus_salto_despegue.wav, magnus_salto_caida.wav, magnus_salto_correr_despegue.wav, magnus_salto_correr_caida.wav, magnus_salto_parado_despegue.wav, magnus_salto_parado_caida.wav.\n")
    f.write("Agacharse: magnus_agacharse.wav y magnus_incorporarse.wav.\n")
    f.write("Los bucles de pasos son de referencia: en el juego cada golpe se dispara desde el sprite\n")
    f.write("de contacto (andar 1 y 17, correr 5 y 17), porque el ciclo va con la distancia y no con el reloj.\n\n")
    f.write("\n".join(ficha) + "\n")

def envolvente(x, ms=5):
    w = s(ms / 1000); n = len(x) // w; return np.sqrt((x[:n * w].reshape(n, w) ** 2).mean(1)), w / SR
fig, axs = plt.subplots(4, 1, figsize=(14, 11))
for ax, (nombre, sig, n, fps, marcas) in zip(axs, [
        ("andar: 34 sprites, 24 fps", andar, 34, 24, [0, 16]),
        ("correr con los pasos de andar: 24 sprites", correr, 24, 24, [4, 16]),
        ("correr, audio del propio video", alt, 24, 24, [4, 16]),
        ("respirar: 30 sprites, 12 fps (marcas: pecho minimo y maximo)", resp, 30, 12, [7, 18])]):
    e, dt = envolvente(sig); t = np.arange(len(e)) * dt
    ax.fill_between(t, e, color="#c98a3a"); ax.set_title(nombre, loc="left"); ax.set_xlim(0, len(sig) / SR); ax.set_yticks([])
    for i in range(n + 1): ax.axvline(i / fps, color="#999", lw=0.4)
    for m in marcas: ax.axvline(m / fps, color="#1c6fd6", lw=1.6, ls="--", label=f"sprite {m+1}")
    ax.legend(loc="upper right", fontsize=8)
axs[-1].set_xlabel("segundos desde el inicio del bucle"); plt.tight_layout()
plt.savefig(os.path.join(SALIDA, "comprobacion.png"), dpi=90)
print("ficha y grafica en", SALIDA)
