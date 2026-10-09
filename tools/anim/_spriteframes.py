"""Genera el SpriteFrames de Godot a partir de las hojas de 05_salida.

Godot guarda cada fotograma como un AtlasTexture: un recorte de la hoja. Son
varios cientos, asi que el .tres no se escribe a mano.

Las velocidades no son las del video. Un video generado por IA puede venir a
camara lenta, y entonces hay que subir los fps para que la accion dure lo que
tiene que durar en el juego. Aqui es donde se decide eso.

Tambien deja las hojas en el juego: cada una se empaqueta (empaquetar.py) a
partir de su rejilla de 05_salida, con los fotogramas recortados a su dibujo, y
se escribe en assets/characters/magnus/ con el nombre de siempre. Asi que la
hoja NO se copia a mano al juego: se exporta con hoja.ps1 y se corre esto.

    python _spriteframes.py <destino.tres> [--rejilla]
      --rejilla: sin empaquetar, las rejillas tal cual (como era antes).
"""
import io, os, sys

import empaquetar as _emp

# tools/anim esta dentro del proyecto. realpath, para que de lo mismo llamarlo por
# godot/tools (el enlace que quedo en el sitio de antes) que por el proyecto.
AQUI = os.path.dirname(os.path.realpath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, '..', '..'))          # el proyecto
ANIM_RAW = os.path.join(RAIZ, 'raw', 'master_mason', 'anim')
ASSETS = os.path.join(RAIZ, 'assets', 'characters', 'magnus')

CASILLA = (292, 360)
# El salto corriendo no cabe en la casilla comun: en el apogeo el personaje se
# sale por arriba y por la izquierda (necesita 674x745 en master). Lleva su
# propia casilla, y el script compensa el offset al cambiar de animacion.
CASILLA_SALTO_CORRER = (340, 400)
# La caida (cayendo, caida, tumbado, levantarse) tampoco: tumbado ocupa 678 px
# de master de ancho. Misma altura que la comun y mismo suelo, solo mas ancha.
CASILLA_CAIDA = (380, 360)

# nombre en Godot, hoja, fotogramas, columnas, fps, bucle[, casilla]
ANIMACIONES = [
    # 29 de los 30 sprites: el cierre c_30 -> c_01 estaba a 0,058 (dos pasos
    # normales de esta animacion, 0,030) y c_29 -> c_01 a 0,034. Se quita el
    # ultimo y se ajusta el fps para que el bucle siga durando 2,50 s, que es lo
    # que dura el audio de la respiracion y a lo que estan medidas sus fases.
    ('reposo',          'magnus_respirando',      29,  6, 11.6, True),
    # A 30 fps, como el ciclo de andar en el juego (192 px/s son 30 fotogramas/s
    # de 6,4 px): asi los pies del arranque van al mismo ritmo que los del ciclo
    # y el empalme en el fotograma 18 -> ciclo f19 no cambia de cadencia.
    ('arranque_andar',  'magnus_arranque_andar',  34,  6, 30.0, False),
    # Este fps no se usa: el script para el nodo y pone el fotograma por
    # distancia. Se deja en 30, que es a lo que va el ciclo en el juego.
    ('andar',           'magnus_andando',         34,  6, 30.0, True),
    # A 30 fps como el ciclo. No es por los ticks de fisica -- estas las reproduce
    # el nodo en _process y su duracion es de reloj -- sino porque empalman con un
    # ciclo movido por distancia: a 24 las piernas cambiarian de ritmo un 25 % al
    # cruzar la costura.
    ('parada_andar',    'magnus_parada_andar',    21,  7, 30.0, False),
    # A 30 fps como el ciclo de correr (435 px/s son 30 fotogramas/s de 14,5 px):
    # el arranque y la parada se empalman con el ciclo y no pueden cambiar de
    # cadencia en la costura.
    ('arranque_correr', 'magnus_arranque_correr', 38,  7, 30.0, False),
    ('correr',          'magnus_corriendo',       24,  6, 30.0, True),
    ('parada_correr',   'magnus_parada_correr',   39,  7, 30.0, False),
    # Salto en parado y andando: el mismo, porque el centrado va anclado al
    # tronco y no lleva desplazamiento cocido. Sale de un video en el que anda,
    # se agacha, salta y aterriza (fotogramas 89-158): anticipacion c_01-14,
    # vuelo c_15-45 (despega en el 15, toca en el 46), aterrizaje c_46-62 e
    # incorporacion c_63-70. No gira en el aire, a diferencia del
    # magnus_saltando anterior, al que sustituye. El video viene a camara lenta
    # (31 fotogramas de vuelo a 24 fps, 1,3 s): a 60 fps el vuelo dura 0,52 s
    # y el salto entero 1,17 s, un tick de fisica por fotograma.
    ('saltar',          'magnus_salto_andando',   70, 10, 60.0, False),
    # Salto desde parado: video propio (salto_en_parado.mp4) en el que esta
    # quieto en la pose de reposo, se agacha, salta vertical y vuelve a quedarse
    # quieto. El video trae dos saltos seguidos sin incorporarse entre medias:
    # se usa el primero (34-80: anticipacion 34-53, vuelo 54-79, toca en el 80)
    # y la recuperacion del segundo (116-134), que empalma con el 80 a 0,097
    # (paso normal 0,04). Sustituye a "saltar" cuando se salta desde el reposo:
    # aquel empieza andando y su primer sprite estaba a 0,38 del reposo. Este
    # empieza a 0,05 y acaba a 0,05. A 60 fps: 0,33 s de anticipacion, 0,43 de
    # vuelo, 1,10 s en total.
    ('salto_parado',    'magnus_salto_parado',    66,  9, 60.0, False),
    # El giro no sale de un video: son 5 poses de una hoja de rotacion generada
    # aparte. Cuidado con el orden: la hoja NO venia ordenada. Midiendo la
    # simetria de cada pose (distancia consigo misma volteada) y cruzando cada
    # una con el espejo de las demas, la cuarta resulto ser la tercera espejada
    # -- se paso de largo del frontal -- y la quinta, el frontal. Los angulos
    # reales entregados fueron 0, 22, 45, 135 y 90.
    #
    # De ahi salen pasos de 45 grados clavados quedandose con 0, 45, 90, 135 y
    # 180, siendo el de 180 el de 0 volteado contra el centro de la casilla, que
    # es lo mismo que hace flip_h: asi el ultimo fotograma encaja al pixel con
    # los sprites de siempre del otro lado, y la misma animacion vale para los
    # dos sentidos. Las poses de 22 grados se descartan: con ellas los pasos
    # quedaban en 15, 8, 17, 17, 10, 15 y se veia acelerar al pasar por delante.
    #
    # A 20 fps son 3 ticks de fisica por fotograma y el giro dura 0,25 s.
    # Giro de pie, de un video de Flow hecho con el reposo del juego: del perfil
    # al frente y al otro perfil, siempre hacia la camara, espejado (el video va
    # de izquierda a derecha), con TODOS sus fotogramas y sin el rato que se
    # queda de frente; empieza y acaba en el reposo, con fundidos. 60 fps, 2 s:
    # cada fotograma cambia como andar a 30 fps. magnus.gd voltea al terminar.
    # (Antes: 5 vistas de una hoja de IA a 20 fps, 0,25 s: se veia brusco.) Ver
    # raw/master_mason/anim/magnus_giro_pie_video/como_se_hizo.txt.
    # Giro de pie POR DELANTE (de cara a la camara; 2026-10-08/09), de un video
    # de un giro de 360 sin baston (Wizard_performing_360-degree_rot..._
    # 20261008170411, job magnus_giro_frente). Por delante el baston a la
    # espalda queda detras del cuerpo (por la espalda se veia girar y quedaba
    # muy raro). Solo la PRIMERA mitad del video (del perfil al frente, c_007-
    # c_052) y luego ella misma espejada y al reves: los sprites mirando a la
    # izquierda son los de la derecha volteados, asi que la segunda mitad del
    # video (el otro costado, otro brazo y otro dibujo de la tunica) no podia
    # acabar en el reposo espejado ("pega un saltazo"). Asi empieza en el
    # reposo y acaba exactamente en el reposo espejado; en el frente, el dibujo
    # de la tunica se invierte fundido en 6 fotogramas con manos y mangas
    # encajadas. 92 fotogramas a 60 fps, 1,53 s; tono estandar. Ver
    # raw/master_mason/anim/magnus_giro_frente/espejo.py. El de antes (por la
    # espalda): magnus_giro_pie_rapido, 47 a 30 fps.
    ('giro',            'magnus_giro_frente',      92, 10, 60.0, False),
    # Salto corriendo: sale de un video en el que corre, salta una piedra y se
    # para. Se usan solo los fotogramas 128-165: despegue, vuelo y aterrizaje.
    # El video viene a camara lenta, como el del salto de parado: 27 fotogramas
    # de vuelo a 24 fps serian 1,1 s, y un salto corriendo real son ~0,6 s. A
    # 60 fps (1 tick de fisica por fotograma) el vuelo dura 0,45 s y el salto
    # entero 0,63 s. Si se ve seco, 30 fps lo deja en 0,9 s de vuelo.
    ('salto_correr',    'magnus_salto_corriendo', 38,  8, 60.0, False, CASILLA_SALTO_CORRER),
    # Cola del salto corriendo, del mismo video (166-199, sigue al 165 con que
    # acaba salto_correr): se incorpora de la zancada de la toma de suelo y da
    # dos pasos cortos hasta quedarse de pie. Solo se ve si se suelta la
    # direccion en el aire; con ella pulsada, al tocar suelo se pasa directo al
    # ciclo de correr. A 60 fps como el salto, 0,57 s. Casilla comun.
    ('aterrizaje_correr', 'magnus_aterrizaje_correr', 34, 7, 60.0, False),
    # Caida (cinematica de entrada): un solo video partido en cuatro estados,
    # ver raw/master_mason/anim/magnus_caida/como_se_hizo.txt. Tumbado mide 678
    # px de master de ancho y no cabe en la comun, asi que los cuatro comparten
    # casilla propia. La linea de suelo esta en la MISMA fila que en la comun
    # (pies en 677 de 720, como respirando) y la casilla mide lo mismo de alto,
    # asi que el offset del sprite es el comun: no hace falta otro.
    #   cayendo     bucle en el aire, 25-32 del video ida y vuelta (la pose no
    #               es ciclica), cabeza fijada: el descenso lo pone el nodo
    #   caida       impacto y desplome, 33-53, sigue al fotograma 32 sin salto
    #   tumbado     un fotograma quieto; cuanto se aguanta lo decide magnus.gd
    #   levantarse  82-206 de dos en dos: a 20 fps dura 3,15 s (el video, 5,2)
    #               y su ultimo fotograma es la pose de reposo (0,13, un paso)
    # Estas van a 24 y se quedan a 24. El AnimatedSprite2D avanza el fotograma en
    # _process, no en los ticks de fisica, asi que su duracion es de reloj y no se
    # cuantiza: la regla de "60/fps entero" solo aplica a andar y correr, que son
    # las que mueve el script desde _physics_process. Y estas no empalman con
    # ningun ciclo movido por distancia, asi que tampoco hay cadencia que igualar.
    ('cayendo',         'magnus_cayendo',         14,  7, 24.0, True,  CASILLA_CAIDA),
    ('caida',           'magnus_caida',           21,  7, 24.0, False, CASILLA_CAIDA),
    ('tumbado',         'magnus_tumbado',          1,  1,  1.0, True,  CASILLA_CAIDA),
    # Levantarse a 20 fps (3,15 s): a 24 (2,6 s) se veia un pelin rapido.
    ('levantarse',      'magnus_levantarse',      63,  8, 20.0, False, CASILLA_CAIDA),
    # Agacharse (tecla abajo), de Pilgrim_squatting_animation: de pie, se agacha,
    # se queda y se levanta. Las tres salen de la misma hoja, que guarda en orden
    # la bajada (casillas 0-41, video 32-73), el asentarse (42-60, video 75-111
    # de dos en dos: el cuerpo rebota 16 px y se queda), el agachado (61-88,
    # video 112-139) y el levantarse (89-126, video 140-177). Ver
    # raw/master_mason/anim/magnus_agacharse/como_se_hizo.txt.
    #   agacharse     de OTRO video (magnus_agacharse_flow, 2026-10-06), pedido de
    #                 nuestro reposo a nuestro agachado: reposo, fundido, video
    #                 44-110 enteros, fundido y el c_089 de esta hoja. Baja de un
    #                 tiron, se pasa un poco y sube despacio (un sentido, sin el
    #                 baja-sube-cae del video viejo). La bajada a 60 fps y el
    #                 asentarse (desde el sprite 43, el punto mas bajo) a 1,5
    #                 refrescos por sprite: 1,4 s. Antes era puente + bajada +
    #                 levantarse al reves de esta hoja, y los empalmes se notaban
    #                 ("un click de la cabeza al final de agacharse").
    #   agachado      ida y vuelta sobre 76-88 (c_077-c_089), a 12 fps: 2 s.
    #                 Casi quieto, respira. Antes era 61-88 a 24 fps, y la
    #                 cabeza daba saltitos de 1 px (en 62-66 subia 1,5 px y
    #                 volvia, y entre la 75 y la 76 habia un escalon): en
    #                 76-88 esta a la misma altura (+-0,4 px de la hoja), y es
    #                 el tramo que enlaza con el agacharse y el levantarse.
    #   incorporarse  89-126 a 60 fps, 0,63 s. Acaba a 0,072 del reposo.
    ('agacharse',       'magnus_agacharse_flow',  71,  9, 60.0, False, None, None,
     [1.0] * 43 + [1.5] * 27 + [1.0]),
    ('agachado',        'magnus_agacharse',       24, 12, 12.0, True,  None,
     list(range(76, 89)) + list(range(87, 76, -1))),
    ('incorporarse',    'magnus_agacharse',       38, 12, 60.0, False, None,
     list(range(89, 127))),
    # Andar agachado, de Hooded_figure_crouching_and_walking: arranca desde el
    # agachado (video 20-46, con el zoom de la camara corregido), un ciclo de
    # dos pasos (143-184) y se para hasta el agachado (185-215). A 20 fps: el
    # ciclo va por distancia (velocidad = 20 * avance) y el arranque y la parada
    # llevan al nodo con sus tablas de avance. Ver
    # raw/master_mason/anim/magnus_andar_agachado/como_se_hizo.txt.
    ('arranque_agachado', 'magnus_arranque_agachado', 27, 7, 20.0, False),
    ('andar_agachado',    'magnus_andar_agachado',    42, 7, 20.0, True),
    ('parada_agachado',   'magnus_parada_agachado',   31, 8, 20.0, False),
    # Giro agachado, de un video de Flow hecho con el agachado del juego como
    # primer y ultimo fotograma: el giro entero por detras, con TODOS sus
    # fotogramas y a su ritmo (24 fps), entre el agachado y el agachado
    # espejado, con fundidos en los enlaces. Arranca suave: en el video ya viene
    # girando, asi que los primeros fotogramas duran algo mas. 2,7 s; magnus.gd
    # voltea al terminar. (Antes: 5 vistas de Gemini; el mismo giro de dos en dos
    # a 60 fps; y por delante con espejo. Las tres se veian a saltitos.) Los
    # fundidos duran un refresco cada uno (0,4 a 24 fps): mas largos (antes 1,6 y
    # 1,4) se veian como "un mini blur al principio". Ver
    # raw/master_mason/anim/magnus_giro_agachado_video/como_se_hizo.txt.
    ('giro_agachado',     'magnus_giro_agachado_video', 65, 10, 24.0, False, None, None,
     [1.0, 0.4, 0.4, 1.6, 1.4, 1.25, 1.15, 1.05] + [1.0] * 55 + [0.4, 1.0]),
    # Andar en diagonal (tres cuartos, de cara a la derecha y hacia la camara), de
    # Cloaked_figure_walking_diagonally (job magnus_andar_diagonal): el ciclo de dos
    # pasos del video, 81-122, en bucle. A 30 fps (el video va a 24 y anda mas
    # despacio que el andar de perfil). PRUEBA: magnus.gd aun no la usa.
    ('andar_diagonal',    'magnus_andar_diagonal',    42, 7, 30.0, True),
    # Andar de frente (hacia la camara) y de espaldas (alejandose), con el baston
    # en la mano. Los videos se acercan y se alejan de verdad: cada fotograma va
    # con el tamano normalizado (normalizar.py en magnus_andar_frente) y el
    # tamano lo pone la profundidad en la escena. Ciclos de dos pasos: frente
    # 88-128 (41), espaldas 136-164 (29, Hooded_figure_walking_forward: anda mas
    # deprisa). Parejos: los dos ciclos duran 1,37 s (30 y 21,2 fps). PRUEBA:
    # solo los usa scenes/dev/prueba_frontal.tscn.
    ('andar_frente',      'magnus_andar_frente',      41, 7, 30.0, True),
    ('andar_espalda',     'magnus_andar_espalda',     29, 6, 21.2, True),
    # La vuelta de frente a espaldas con el baston (Old_pilgrim_turning_around,
    # video 42-90, todos): hecha con un fotograma de cada andar de inicio y fin;
    # registrada contra andar_frente c_005 y andar_espalda c_005, por los que se
    # entra y se sale. Casilla propia mas alta (la garra sube por encima de la
    # comun al empezar), mismo suelo. Hacia atras, de espaldas a frente.
    ('vuelta_frontal',    'magnus_vuelta_frontal',    49, 7, 30.0, False, (292, 400)),
    # Sin baston: los mismos andares, parejos (ciclo de 1,37 s, 34 y 29 f).
    ('andar_frente_sin',  'magnus_andar_frente_sin',  34, 6, 24.8, True),
    ('andar_espalda_sin', 'magnus_andar_espalda_sin', 29, 6, 21.2, True),
    # La vuelta sin baston (Pilgrim_turns_around_on_green, video 50-104, todos),
    # hecha con referencias de los andares sin baston; registrada contra
    # andar_frente_sin c_015 (0,10) y andar_espalda_sin c_004 (0,16).
    ('vuelta_frontal_sin', 'magnus_vuelta_frontal_sin', 55, 7, 30.0, False),
    # Puentes por flujo optico entre los andares con baston y la vuelta (sin
    # fundido: el fundido de opacidad dejaba dos dibujos superpuestos). 4
    # intermedios cada uno, casilla de la vuelta. Ver
    # raw/master_mason/anim/magnus_puentes_frontal/puente.py.
    ('puente_espalda',   'magnus_puentes_frontal', 4, 8, 30.0, False, (292, 400), [0, 1, 2, 3]),
    ('puente_espalda_b', 'magnus_puentes_frontal', 4, 8, 30.0, False, (292, 400), [4, 5, 6, 7]),
    ('puente_frente',    'magnus_puentes_frontal', 4, 8, 30.0, False, (292, 400), [8, 9, 10, 11]),
    ('puente_frente_b',  'magnus_puentes_frontal', 4, 8, 30.0, False, (292, 400), [12, 13, 14, 15]),
    # Los de la vuelta sin baston (magnus_puentes_frontal_sin/puente_sin.py).
    ('puente_espalda_sin',        'magnus_puentes_frontal_sin', 4, 8, 30.0, False, None, [0, 1, 2, 3]),
    ('puente_espalda_sin_b',      'magnus_puentes_frontal_sin', 4, 8, 30.0, False, None, [4, 5, 6, 7]),
    ('puente_frente_sin',         'magnus_puentes_frontal_sin', 4, 8, 30.0, False, None, [8, 9, 10, 11]),
    ('puente_frente_sin_b',       'magnus_puentes_frontal_sin', 4, 8, 30.0, False, None, [12, 13, 14, 15]),
    ('puente_reposo_espalda_sin', 'magnus_puentes_frontal_sin', 4, 8, 30.0, False, None, [16, 17, 18, 19]),
    ('puente_reposo_frente_sin',  'magnus_puentes_frontal_sin', 4, 8, 30.0, False, None, [20, 21, 22, 23]),
    # Parada y reposo sin baston, de frente y de espaldas (videos de Veo,
    # raw/.../magnus_reposo_frente_sin/montar.py y enganches.py), a la velocidad
    # del video (24 fps):
    #   parada_frente_sin  video 3-102: entra desde andar_frente_sin c_024 (0,16),
    #                      da un par de pasitos acercandose (crece un 11 %) y se
    #                      asienta; casa con el reposo en su c_173 (0,022).
    #   reposo_frente_sin  bucle 160-227 (cierre 0,019).
    #   reposo_espalda_sin bucle 136-211 (cierre 0,016); se entra desde los pies
    #                      juntos del andar_espalda_sin (c_009 -> 186, c_024 -> 156).
    ('parada_frente_sin', 'magnus_reposo_frente_sin', 100, 12, 24.0, False, None, list(range(0, 100))),
    ('reposo_frente_sin', 'magnus_reposo_frente_sin', 68, 12, 24.0, True, None, list(range(100, 168))),
    ('reposo_espalda_sin', 'magnus_reposo_espalda_sin', 76, 10, 24.0, True),
    # Un paso agachado (de agachado a agachado, 39 px mas alla): dos videos de
    # Flow seguidos (el pie de delante sale; el cuerpo avanza y el de atras se
    # junta), con el nodo por AVANCE_PASO_AGACHADO. Un toque agachado lo da;
    # ver raw/master_mason/anim/magnus_paso_agachado/como_se_hizo.txt.
    ('paso_agachado',     'magnus_paso_agachado',     95, 10, 60.0, False),   # apagado en magnus.gd
]


# La secuencia con baston de frente / espaldas de un solo video (reposo, arranque,
# andar, vuelta y los puentes entre ellos, en dos hojas): la lista la escribe
# raw/master_mason/anim/magnus_secuencia_frontal/secuencia.py.
# Lo mismo sin baston: magnus_secuencia_frontal_sin (secuencia.py magnus_secuencia_frontal_sin).
import json as _json
for _d in ('magnus_secuencia_frontal', 'magnus_secuencia_frontal_sin'):
    _SEC = os.path.join(ANIM_RAW, _d, 'animaciones.json')
    if os.path.exists(_SEC):
        for _n, _job, _cnt, _fps, _bucle, _idx in _json.load(open(_SEC)):
            ANIMACIONES.append((_n, _job, _cnt, 16, _fps, _bucle, (292, 400), _idx))


def _usos():
    """hoja -> (casilla, columnas, casillas usadas por alguna animacion)."""
    usos = {}
    for anim in ANIMACIONES:
        nombre, hoja, n, cols = anim[:4]
        casilla = tuple(anim[6]) if len(anim) > 6 and anim[6] else CASILLA
        indices = list(anim[7]) if len(anim) > 7 and anim[7] else list(range(n))
        if hoja in usos:
            assert usos[hoja][0] == casilla and usos[hoja][1] == cols, \
                '%s: las animaciones de la hoja %s no coinciden en casilla o columnas' % (nombre, hoja)
            usos[hoja][2].update(indices)
        else:
            usos[hoja] = (casilla, cols, set(indices))
    return usos


def _rejilla(hoja):
    return os.path.join(ANIM_RAW, hoja, '05_salida', hoja + '_sheet.png')


## Como tiene que importar Godot cada hoja: comprimida en la GPU (BC7 en
## escritorio con high_quality; 1 byte por pixel en vez de 4, medido sin
## diferencia visible: PSNR 47 dB, ningun pixel cambia mas de 21/255) y con
## mipmaps (sin ellas centellea al alejar la camara). Godot crea el .import de
## una hoja nueva sin compresion y sin mipmaps; esto lo deja bien siempre.
IMPORT_HOJA = {'compress/mode': '2', 'compress/high_quality': 'true', 'mipmaps/generate': 'true'}


def asegurar_import(hoja):
    """Deja el .import de la hoja con IMPORT_HOJA. Si no existe (hoja nueva), lo
    crea con lo minimo; Godot completa el resto (uid, rutas) al importar."""
    ruta = os.path.join(ASSETS, hoja + '.png.import')
    if not os.path.exists(ruta):
        lineas = ['[remap]', '', 'importer="texture"', 'type="CompressedTexture2D"', '', '[deps]', '',
                  'source_file="res://assets/characters/magnus/%s.png"' % hoja, '', '[params]', '']
        lineas += ['%s=%s' % kv for kv in IMPORT_HOJA.items()]
        io.open(ruta, 'w', encoding='utf-8', newline='\n').write('\n'.join(lineas) + '\n')
        return 'creado'
    txt = io.open(ruta, encoding='utf-8').read()
    nuevo = txt
    for clave, valor in IMPORT_HOJA.items():
        lineas = nuevo.split('\n')
        hay = [i for i, l in enumerate(lineas) if l.startswith(clave + '=')]
        if hay:
            lineas[hay[0]] = '%s=%s' % (clave, valor)
        else:
            lineas.insert(lineas.index('[params]') + 2, '%s=%s' % (clave, valor))
        nuevo = '\n'.join(lineas)
    if nuevo != txt:
        io.open(ruta, 'w', encoding='utf-8', newline='\n').write(nuevo)
        return 'corregido'
    return ''


def empaquetar_hojas(usos):
    """Empaqueta cada rejilla de 05_salida y deja el atlas en el juego con el
    nombre de siempre: asi el .import, sus ajustes (compresion, mipmaps) y su
    uid no cambian. Devuelve hoja -> datos del atlas (el .json de al lado)."""
    atlas = {}
    for hoja, (casilla, cols, usadas) in sorted(usos.items()):
        atlas[hoja] = _emp.empaquetar(
            _rejilla(hoja), casilla[0], casilla[1], cols, usadas,
            os.path.join(ASSETS, hoja + '.png'),
            os.path.join(ANIM_RAW, hoja, '05_salida', hoja + '_atlas.json'))
    return atlas


def generar(destino, ruta_hojas='res://assets/characters/magnus', rejilla=False):
    """Una entrada de ANIMACIONES es (nombre, hoja, n, cols, fps, bucle[, casilla[, indices[, duraciones]]]).

    duraciones, si se da, es lo que dura cada fotograma en fotogramas de fps (1.0
    el normal): para arrancar o frenar suave sin repetir sprites.

    indices, si se da, es la lista de casillas de la hoja que forman la animacion,
    en orden (n debe ser su longitud): asi varias animaciones salen de la misma
    hoja, y una ida y vuelta repite casillas sin duplicarlas en el PNG. Cada hoja
    se declara una sola vez y cada casilla un solo AtlasTexture.

    Salvo con rejilla=True, antes empaqueta las hojas: el AtlasTexture lleva
    region = el recorte en el atlas y margin = (dx, dy, casilla - recorte), que es
    lo que hace que Godot lo dibuje con el tamano de la casilla entera y el dibujo
    en su sitio. Con rejilla=True copia las rejillas al juego tal cual.
    """
    usos = _usos()
    if rejilla:
        import shutil
        for hoja in usos:
            shutil.copyfile(_rejilla(hoja), os.path.join(ASSETS, hoja + '.png'))
        atlas = {}
    else:
        atlas = empaquetar_hojas(usos)
    for hoja in usos:
        cambio = asegurar_import(hoja)
        if cambio:
            print('   %s.png.import %s (compresion BC7 y mipmaps)' % (hoja, cambio))
    ext, sub, bloques = [], [], []
    tex_de = {}      # hoja -> id del ext_resource
    atlas_de = {}    # (hoja, casilla) -> id del AtlasTexture
    for anim in ANIMACIONES:
        nombre, hoja, n, cols, fps, bucle = anim[:6]
        cw, ch = anim[6] if len(anim) > 6 and anim[6] else CASILLA
        indices = list(anim[7]) if len(anim) > 7 and anim[7] else list(range(n))
        assert len(indices) == n, '%s: %d indices para %d fotogramas' % (nombre, len(indices), n)
        duraciones = list(anim[8]) if len(anim) > 8 and anim[8] else [1.0] * n
        assert len(duraciones) == n, '%s: %d duraciones para %d fotogramas' % (nombre, len(duraciones), n)
        if hoja not in tex_de:
            tex_de[hoja] = 'tex_%d' % (len(tex_de) + 1)
            ext.append('[ext_resource type="Texture2D" path="%s/%s.png" id="%s"]'
                       % (ruta_hojas, hoja, tex_de[hoja]))
        refs = []
        for k, dur in zip(indices, duraciones):
            clave = (hoja, k)
            if clave not in atlas_de:
                atlas_de[clave] = 'atlas_%d' % (len(atlas_de) + 1)
                if hoja in atlas:
                    assert atlas[hoja]['casilla'] == [cw, ch]
                    x, y, w, h, dx, dy = atlas[hoja]['fotogramas'][str(k)]
                    margen = 'margin = Rect2(%d, %d, %d, %d)\n' % (dx, dy, cw - w, ch - h)
                else:
                    x, y, w, h = (k % cols) * cw, (k // cols) * ch, cw, ch
                    margen = ''
                sub.append('[sub_resource type="AtlasTexture" id="%s"]\n'
                           'atlas = ExtResource("%s")\n'
                           'region = Rect2(%d, %d, %d, %d)\n%s' % (atlas_de[clave], tex_de[hoja], x, y, w, h, margen))
            refs.append('{\n"duration": %s,\n"texture": SubResource("%s")\n}' % (repr(float(dur)), atlas_de[clave]))
        bloques.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
                       % (', '.join(refs), 'true' if bucle else 'false', nombre, fps))

    pasos = len(ext) + len(sub)
    txt = ('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (pasos + 1)
           + '\n'.join(ext) + '\n\n' + '\n'.join(sub)
           + '\n[resource]\nanimations = [' + ', '.join(bloques) + ']\n')
    carpeta = os.path.dirname(destino)
    if carpeta and not os.path.isdir(carpeta):
        os.makedirs(carpeta)
    io.open(destino, 'w', encoding='utf-8', newline='\n').write(txt)
    return sum(a[2] for a in ANIMACIONES), len(ANIMACIONES), atlas


def memoria(hojas_px):
    """MiB de memoria de video de unas hojas (lista de ancho*alto), con mipmaps,
    sin comprimir (4 bytes/px) y con la compresion de GPU (BC7/ASTC 4x4, 1 byte/px)."""
    px = sum(hojas_px) * 4.0 / 3.0
    return px * 4 / 1048576.0, px / 1048576.0


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    salida = args[0] if args else 'magnus_frames.tres'
    n, m, atlas = generar(salida, rejilla='--rejilla' in sys.argv)
    print('%d fotogramas en %d animaciones -> %s' % (n, m, salida))
    for anim in ANIMACIONES:
        nombre, _, cnt, _, fps, bucle = anim[:6]
        durs = anim[8] if len(anim) > 8 and anim[8] else [1.0] * cnt
        print('   %-18s %2d fotogramas  %4.0f fps  %5.2f s  %s'
              % (nombre, cnt, fps, sum(durs) / fps, 'bucle' if bucle else 'una pasada'))
    # Lo que cuesta, para que el aviso salga solo al exportar (ver
    # docs/sprites_magnus.md, "Tamano en pantalla"): memoria de video con mipmaps.
    from PIL import Image
    rejillas = {h: Image.open(_rejilla(h)).size for h in _usos()}
    antes = memoria([w * h for w, h in rejillas.values()])
    if atlas:
        ahora = memoria([d['atlas'][0] * d['atlas'][1] for d in atlas.values()])
        print('memoria de video (con mipmaps): rejillas %.0f MiB sin comprimir; atlas %.0f MiB sin comprimir, %.0f comprimido'
              % (antes[0], ahora[0], ahora[1]))
        for h in sorted(atlas, key=lambda h: -atlas[h]['atlas'][0] * atlas[h]['atlas'][1]):
            d = atlas[h]
            print('   %-26s %4dx%-4d  %5.1f MiB comprimido  (%.0f %% de su rejilla)' % (
                h, d['atlas'][0], d['atlas'][1], memoria([d['atlas'][0] * d['atlas'][1]])[1],
                100.0 * d['atlas'][0] * d['atlas'][1] / d['superficie_rejilla']))
    else:
        print('memoria de video (con mipmaps): %.0f MiB sin comprimir, %.0f comprimido' % antes)
