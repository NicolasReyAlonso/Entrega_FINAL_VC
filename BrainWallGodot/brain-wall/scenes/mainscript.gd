
# PoseReceiver.gd
extends Node3D

@export var marker_scene: PackedScene # escena (esfera) para articulaciones
var socket := WebSocketPeer.new()

var pose: Array = []       # lista de puntos recibidos (solo los KEYPOINTS)
var markers: Array = []    # nodos para mostrar los puntos

const KEYPOINTS = [0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26]  # 11 puntos

func _ready():
	var err = socket.connect_to_url("ws://localhost:8765")
	if err != OK:
		push_error("Error al conectar WebSocket: %s" % err)

	# crear los marcadores (uno por punto)
	for i in range(KEYPOINTS.size()):
		var m = marker_scene.instantiate()
		add_child(m)
		markers.append(m)

	set_process(true)

func _process(delta):
	socket.poll()

	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var data = socket.get_packet().get_string_from_utf8()
			var parsed = JSON.parse_string(data)
			if parsed == null:
				push_warning("JSON inválido: %s" % data)
				continue
			pose = parsed
			# Actualizar inmediatamente (sin chequear 10)
			update_markers()

# Convertir puntos 2D normalizados (0..1) a coordenadas 3D centradas en [-1..1]
func update_markers():
	if pose.size() != KEYPOINTS.size():
		# Evita mover marcadores con paquetes incompletos
		return

	for i in range(KEYPOINTS.size()):
		var lm = pose[i]  # lm es {"x":..., "y":...}
		var x = (lm["x"] - 0.5) * 2.0
		var y = (0.5 - lm["y"]) * 2.0
		var z = 0.0
		markers[i].position = Vector3(x, y, z)

		# Tamaño y color: cabeza (índice 0 en la lista)
		if i == 0:
			markers[i].scale = Vector3(0.1, 0.1, 0.1)
			# Opción A (si el nodo soporta modulate, p.ej. Sprite3D):
			if markers[i].has_method("set"):
				# Intento seguro: solo si existe 'modulate'
				if "modulate" in markers[i].get_property_list().map(func(p): return p.name):
					markers[i].modulate = Color(1, 0, 0)
			# Opción B (MeshInstance3D): usar material rojo
			if markers[i] is MeshInstance3D:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(1, 0, 0)
				markers[i].material_override = mat
		else:
			markers[i].scale = Vector3(0.05, 0.05, 0.05)
			# Opción A: modulate (si existe)
			if markers[i].has_method("set"):
				if "modulate" in markers[i].get_property_list().map(func(p): return p.name):
					markers[i].modulate = Color(0, 1, 0)
			# Opción B (MeshInstance3D): verde
			if markers[i] is MeshInstance3D:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0, 1, 0)
				markers[i].material_override = mat
