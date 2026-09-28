extends RefCounted
## Sonidos de la maqueta, generados al arrancar: no hay archivos de audio para
## ellos todavia. Son placeholders con timbre de cuenco (seno con parciales
## inarmonicos que se apagan antes que la fundamental), bajos y sin ataque, para
## que no suenen a "puzle resuelto".

const MEZCLA := 22050

## Generar cuesta casi un segundo en GDScript: se hace una vez por partida y se
## reutiliza al reiniciar la escena.
static var _cache := {}

## Nota de cuenco: ataque blando de 20 ms y caida exponencial.
static func cuenco(frecuencia: float, duracion: float, volumen: float = 0.45) -> AudioStreamWAV:
	var clave := str(["cuenco", frecuencia, duracion, volumen])
	if _cache.has(clave):
		return _cache[clave]
	var n := int(duracion * MEZCLA)
	var datos := PackedByteArray()
	datos.resize(n * 2)
	for i in n:
		var t := float(i) / MEZCLA
		var env := minf(t / 0.02, 1.0) * exp(-t * 3.2 / duracion)
		var s := sin(TAU * frecuencia * t) * 0.72 \
			+ sin(TAU * frecuencia * 2.76 * t) * 0.20 * exp(-t * 3.0) \
			+ sin(TAU * frecuencia * 5.40 * t) * 0.08 * exp(-t * 7.0)
		datos.encode_s16(i * 2, int(clampf(s * env * volumen, -1.0, 1.0) * 32767.0))
	_cache[clave] = _wav(datos, false, 0)
	return _cache[clave]

## Zumbido de fondo en bucle. Las frecuencias caben un numero entero de veces en
## el bucle, asi que no chasquea al dar la vuelta.
static func dron(frecuencias: Array, duracion: float = 4.0, volumen: float = 0.25) -> AudioStreamWAV:
	var clave := str(["dron", frecuencias, duracion, volumen])
	if _cache.has(clave):
		return _cache[clave]
	var n := int(duracion * MEZCLA)
	var datos := PackedByteArray()
	datos.resize(n * 2)
	for i in n:
		var t := float(i) / MEZCLA
		var s := 0.0
		for k in frecuencias.size():
			var f: float = round(frecuencias[k] * duracion) / duracion
			s += sin(TAU * f * t) / (1.0 + k)
		# Un vaiven lento de volumen, tambien cerrado en el bucle.
		s *= 0.8 + 0.2 * sin(TAU * t / duracion)
		datos.encode_s16(i * 2, int(clampf(s * volumen * 0.5, -1.0, 1.0) * 32767.0))
	_cache[clave] = _wav(datos, true, n)
	return _cache[clave]

## Acorde largo: varias notas de cuenco sumadas, con un leve arpegio.
static func acorde(frecuencias: Array, duracion: float = 7.0, volumen: float = 0.35) -> AudioStreamWAV:
	var clave := str(["acorde", frecuencias, duracion, volumen])
	if _cache.has(clave):
		return _cache[clave]
	var n := int(duracion * MEZCLA)
	var datos := PackedByteArray()
	datos.resize(n * 2)
	for i in n:
		var t := float(i) / MEZCLA
		var s := 0.0
		for k in frecuencias.size():
			var tk := t - k * 0.09
			if tk <= 0.0:
				continue
			var env := minf(tk / 0.05, 1.0) * exp(-tk * 2.2 / duracion)
			s += (sin(TAU * frecuencias[k] * tk) * 0.8 + sin(TAU * frecuencias[k] * 2.0 * tk) * 0.12) * env
		s /= maxf(1.0, frecuencias.size() * 0.6)
		datos.encode_s16(i * 2, int(clampf(s * volumen, -1.0, 1.0) * 32767.0))
	_cache[clave] = _wav(datos, false, 0)
	return _cache[clave]

## Golpe seco de piedra que asienta: ruido filtrado muy corto y un grave.
static func toc(volumen: float = 0.8) -> AudioStreamWAV:
	var clave := str(["toc", volumen])
	if _cache.has(clave):
		return _cache[clave]
	var n := int(0.35 * MEZCLA)
	var datos := PackedByteArray()
	datos.resize(n * 2)
	var semilla := RandomNumberGenerator.new()
	semilla.seed = 7
	var filtrado := 0.0
	for i in n:
		var t := float(i) / MEZCLA
		filtrado += (semilla.randf_range(-1.0, 1.0) - filtrado) * 0.18
		var s := filtrado * exp(-t * 38.0) * 1.6 + sin(TAU * 92.0 * t) * exp(-t * 14.0) * 0.7
		datos.encode_s16(i * 2, int(clampf(s * volumen, -1.0, 1.0) * 32767.0))
	_cache[clave] = _wav(datos, false, 0)
	return _cache[clave]

static func _wav(datos: PackedByteArray, bucle: bool, fin: int) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MEZCLA
	w.stereo = false
	w.data = datos
	if bucle:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = fin
	return w
