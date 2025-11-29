# PoseReceiver.gd
extends Node3D

@export var marker_scene: PackedScene  # Escena de esfera para articulaciones
@export var line_width: float = 0.02   # Grosor de las líneas

var socket := WebSocketPeer.new()
var players_data: Array = []           # Datos de poses de todos los jugadores
var players_markers: Array = []        # Marcadores por jugador
var players_lines: Array = []          # MeshInstances para líneas por jugador

const KEYPOINTS = [0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]  # 13 puntos

# Conexiones del esqueleto (índices en el array KEYPOINTS)
const SKELETON_CONNECTIONS = [
	[1, 3], [3, 5],      # brazo izquierdo (11->13->15)
	[2, 4], [4, 6],      # brazo derecho (12->14->16)
	[1, 2],              # hombros (11-12)
	[7, 8],              # caderas (23-24)
	[1, 7], [2, 8],      # torso (11->23, 12->24)
	[7, 9], [9, 11],     # pierna izquierda (23->25->27)
	[8, 10], [10, 12]    # pierna derecha (24->26->28)
]

# Colores para diferentes jugadores
const PLAYER_COLORS = [
	Color(0, 1, 0),      # Verde - Jugador 1
	Color(1, 0, 1)       # Magenta - Jugador 2
]

func _ready():
	var err = socket.connect_to_url("ws://localhost:8765")
	if err != OK:
		push_error("Error al conectar WebSocket: %s" % err)
	
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
			
			# El servidor envía: {"poses": [[{x,y}, ...], [{x,y}, ...]]}
			if "poses" in parsed:
				players_data = parsed["poses"]
				update_all_players()

func update_all_players():
	# Ajustar número de jugadores
	while players_markers.size() < players_data.size():
		add_player()
	
	while players_markers.size() > players_data.size():
		remove_player()
	
	# Actualizar cada jugador
	for i in range(players_data.size()):
		update_player(i, players_data[i])

func add_player():
	"""Crea marcadores y líneas para un nuevo jugador"""
	var player_idx = players_markers.size()
	var markers = []
	
	# Crear marcadores
	for j in range(KEYPOINTS.size()):
		var m = marker_scene.instantiate()
		add_child(m)
		markers.append(m)
	
	players_markers.append(markers)
	
	# Crear líneas (una MeshInstance por conexión)
	var lines = []
	for connection in SKELETON_CONNECTIONS:
		var mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)
		lines.append(mesh_instance)
	
	players_lines.append(lines)

func remove_player():
	"""Elimina el último jugador"""
	if players_markers.is_empty():
		return
	
	# Eliminar marcadores
	var markers = players_markers.pop_back()
	for m in markers:
		m.queue_free()
	
	# Eliminar líneas
	var lines = players_lines.pop_back()
	for l in lines:
		l.queue_free()

func update_player(player_idx: int, pose: Array):
	"""Actualiza la visualización de un jugador específico"""
	if pose.size() != KEYPOINTS.size():
		return
	
	var markers = players_markers[player_idx]
	var lines = players_lines[player_idx]
	var color = PLAYER_COLORS[player_idx % PLAYER_COLORS.size()]
	
	# Actualizar posiciones de marcadores
	var positions = []
	for i in range(KEYPOINTS.size()):
		var lm = pose[i]
		var x = (lm["x"] - 0.5) * 2.0
		var y = (0.5 - lm["y"]) * 2.0
		var z = 0.0
		var pos = Vector3(x, y, z)
		positions.append(pos)
		
		markers[i].position = pos
		
		# Tamaño y color: cabeza más grande y roja
		if i == 0:
			markers[i].scale = Vector3(0.12, 0.12, 0.12)
			set_marker_color(markers[i], Color(1, 0, 0))
		else:
			markers[i].scale = Vector3(0.06, 0.06, 0.06)
			set_marker_color(markers[i], color)
	
	# Actualizar líneas de conexión
	for i in range(SKELETON_CONNECTIONS.size()):
		var connection = SKELETON_CONNECTIONS[i]
		var start_idx = connection[0]
		var end_idx = connection[1]
		
		var start_pos = positions[start_idx]
		var end_pos = positions[end_idx]
		
		create_line_between_points(lines[i], start_pos, end_pos, color)

func create_line_between_points(mesh_instance: MeshInstance3D, start: Vector3, end: Vector3, color: Color):
	"""Crea una línea (cilindro) entre dos puntos"""
	var distance = start.distance_to(end)
	var midpoint = (start + end) / 2.0
	
	# Crear cilindro
	var cylinder = CylinderMesh.new()
	cylinder.height = distance
	cylinder.top_radius = line_width
	cylinder.bottom_radius = line_width
	
	mesh_instance.mesh = cylinder
	mesh_instance.position = midpoint
	
	# RESETEAR la rotación antes de aplicar la nueva
	mesh_instance.rotation = Vector3.ZERO
	
	# Rotar el cilindro para que apunte de start a end
	var direction = (end - start).normalized()
	if direction.length() > 0.001:
		# El cilindro por defecto apunta hacia arriba (0,1,0)
		var up = Vector3(0, 1, 0)
		
		# Usar look_at para orientar correctamente
		mesh_instance.look_at(end, up)
		# Rotar 90 grados porque el cilindro está orientado en Y
		mesh_instance.rotate_object_local(Vector3(1, 0, 0), PI / 2.0)
	
	# Material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = mat

func set_marker_color(marker: Node3D, color: Color):
	"""Establece el color de un marcador"""
	if marker is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.material_override = mat
