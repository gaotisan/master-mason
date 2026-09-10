extends AudioStreamPlayer

func _ready():
	# Esperar un segundo para que el sistema de audio de Linux enganche
	await get_tree().create_timer(1.0).timeout
	
	var sfx = load("res://assets/audio/second_rapid_breathing.wav")
	if sfx:
		self.stream = sfx
		self.volume_db = 5.0 # Fuerte para que lo oigas sí o sí
		
		# Forzamos loop si es WAV
		if self.stream is AudioStreamWAV:
			self.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		
		self.play()
		print("--- AUDIO LOG ---")
		print("Reproduciendo: ", self.stream.resource_path)
		print("Estado playing: ", self.playing)
	else:
		print("--- ERROR: No se encuentra el archivo WAV ---")

func _process(_delta):
	# Si se para por cualquier error del motor, lo reiniciamos
	if not self.playing:
		self.play()
