# PoseReceiver.gd
extends Node3D

@export var player_scene: PackedScene  # Escena del personaje Eleven
@export var offset: Vector3 = Vector3.ZERO
@export var player_scale: float = 0.1  # Escala del modelo
@export var depth_scale: float = 1.0
@export var movement_smoothing: float = 0.2  # Suavizado del movimiento
@export var rotation_smoothing: float = 0.08  # Suavizado de rotación (más bajo = más suave)
@export var audioStreamPlayer: AudioStreamPlayer3D

var socket := WebSocketPeer.new()
var players_data: Array = []
var players: Array = []  # Instancias de los personajes
var wall_generator: Node3D
var pose_evaluator: Node3D
var score: int = 0
var lives: int = 3
var current_target_pose: int = 0

# Almacenar últimas rotaciones válidas para evitar espasmos
var last_valid_rotations: Dictionary = {}

# Índices de KEYPOINTS enviados por MediaPipe:
# 0: nariz, 1: hombro_izq, 2: hombro_der, 3: codo_izq, 4: codo_der
# 5: muñeca_izq, 6: muñeca_der, 7: cadera_izq, 8: cadera_der
# 9: rodilla_izq, 10: rodilla_der, 11: tobillo_izq, 12: tobillo_der
const KEYPOINTS = [0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]

# Colores para diferentes jugadores
const PLAYER_COLORS = [
	Color(0, 1, 0),      # Verde - Jugador 1
	Color(1, 0, 1)       # Magenta - Jugador 2
]

func _ready():
	var character1 = "eleven"
	var character2 = "eleven"
	
	if get_tree().root.has_meta("personaje1"):
		character1 = get_tree().root.get_meta("personaje1")
	if get_tree().root.has_meta("personaje2"):
		character2 = get_tree().root.get_meta("personaje2")
	
	print("Jugador 1: ", character1)
	print("Jugador 2: ", character2)
	
	# ===== CREAR PLATAFORMA =====
	create_platform()
	
	# ===== CREAR CÁMARA =====
	create_camera()
	
	# ===== CREAR ILUMINACIÓN =====
	create_lighting()
	
	# ===== CARGAR PERSONAJES =====
	load_character(character1)
	if player_scene:
		var player1 = player_scene.instantiate()
		player1.scale = Vector3.ONE * player_scale
		player1.position = Vector3(-2, 1, 0)
		add_child(player1)
		players.append(player1)
		apply_color_to_player(player1, PLAYER_COLORS[0])
		print("Jugador 1 instanciado: ", character1)
	
	load_character(character2)
	if player_scene:
		var player2 = player_scene.instantiate()
		player2.scale = Vector3.ONE * player_scale
		player2.position = Vector3(2, 1, 0)
		add_child(player2)
		players.append(player2)
		apply_color_to_player(player2, PLAYER_COLORS[1])
		print("Jugador 2 instanciado: ", character2)
	
	# ===== INICIAR GENERADOR DE PAREDES =====
	wall_generator = Node3D.new()
	wall_generator.name = "WallGenerator"
	add_child(wall_generator)
	
	# Script de generación de paredes
	var wall_gen_script = load("res://scenes/WallGenerator.gd")
	if wall_gen_script:
		wall_generator.set_script(wall_gen_script)
	
	# ===== CREAR HUD =====
	var hud = CanvasLayer.new()
	var hud_script = load("res://scenes/GameHUD.gd")
	if hud_script:
		hud.set_script(hud_script)
	add_child(hud)
	
	var err = socket.connect_to_url("ws://localhost:8765")
	if err != OK:
		push_error("Error al conectar WebSocket: %s" % err)
	
	if audioStreamPlayer:
		audioStreamPlayer.play()
	
	set_process(true)

func create_platform():
	"""Crea la plataforma donde están los jugadores"""
	var platform = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(10, 0.5, 5)
	platform.mesh = mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.DARK_GRAY
	platform.set_surface_override_material(0, material)
	
	platform.position = Vector3(0, 0, 0)
	add_child(platform)
	
	# Colisión de la plataforma
	var platform_collision = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(10, 0.5, 5)
	shape.shape = box_shape
	platform_collision.add_child(shape)
	platform_collision.position = Vector3(0, 0, 0)
	add_child(platform_collision)

func create_camera():
	"""Crea la cámara del juego"""
	var camera = Camera3D.new()
	camera.position = Vector3(0, 2, 8)
	camera.look_at(Vector3(0, 1, 0), Vector3.UP)
	add_child(camera)

func create_lighting():
	"""Crea la iluminación"""
	var light = DirectionalLight3D.new()
	light.position = Vector3(5, 10, 5)
	light.shadow_enabled = true
	add_child(light)

func playBasicMusic():
	var music_player = audioStreamPlayer
	music_player.play()  # Comienza la música

func load_character(char: String):
	match char:
		"saw":
			print("Cargando Saw...")
			if ResourceLoader.exists("res://assets/Characters/saw.tscn"):
				var scene = load("res://assets/Characters/saw.tscn")
				player_scene = scene
		"et":
			print("Cargando ET...")
			if ResourceLoader.exists("res://assets/Characters/et.tscn"):
				var scene = load("res://assets/Characters/et.tscn")
				player_scene = scene
		"eleven":
			print("Cargando Eleven...")
			if ResourceLoader.exists("res://assets/Characters/eleven.tscn"):
				var scene = load("res://assets/Characters/eleven.tscn")
				player_scene = scene
		"homer":
			print("Cargando Homer...")
			if ResourceLoader.exists("res://assets/Characters/homer.tscn"):
				var scene = load("res://assets/Characters/homer.tscn")
				player_scene = scene
		_:
			print("Personaje no reconocido: ", char)

func _process(delta):
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var data = socket.get_packet().get_string_from_utf8()
			var parsed = JSON.parse_string(data)
			
			if parsed == null:
				continue
			
			if "poses" in parsed:
				players_data = parsed["poses"]
				update_all_players()
	
	# Actualizar la generación de paredes
	update_wall_system(delta)

func update_wall_system(delta: float):
	"""Actualiza el sistema de paredes y colisiones"""
	if not wall_generator:
		return
	
	# Verificar colisiones con las paredes
	var walls = wall_generator.get_children()
	for wall in walls:
		# Detectar colisión cuando la pared está cerca de los jugadores (posición Z)
		if wall.position.z < 1.0 and wall.position.z > -1.0:
			check_wall_collision(wall)

func check_wall_collision(wall: Node3D):
	"""Verifica si los jugadores colisionan con la pared"""
	var wall_passed = false
	
	for i in range(players.size()):
		var player = players[i]
		var player_pos = player.global_position
		
		# Distancia horizontal del jugador
		var dist_x = abs(player_pos.x)
		var dist_y = player_pos.y
		
		# Agujeros de la pared (aproximado basado en postura)
		var hole_left = -2.5
		var hole_right = 2.5
		var hole_top = 3.5
		var hole_bottom = 0.5
		
		# Verificar si el jugador está dentro del agujero
		var in_hole = (player_pos.x >= hole_left and player_pos.x <= hole_right and
					   player_pos.y >= hole_bottom and player_pos.y <= hole_top)
		
		if not in_hole:
			lives -= 1
			print("¡Choque! Vidas restantes: ", lives)
			if lives <= 0:
				game_over()
		else:
			wall_passed = true
			score += 10
			print("¡Pasaste! Puntuación: ", score)
	
	wall.queue_free()


func game_over():
	"""Final del juego"""
	print("GAME OVER! Puntuación final: ", score)
	var scene_name = get_scene_file_path()
	get_tree().reload_current_scene()

func update_all_players():
	"""Actualiza poses de todos los jugadores desde players_data"""
	while players.size() < players_data.size():
		add_player()
	
	while players.size() > players_data.size():
		remove_player()
	
	for i in range(players_data.size()):
		update_player(i, players_data[i])

func add_player():
	var player_instance = player_scene.instantiate()
	player_instance.scale = Vector3.ONE * player_scale
	add_child(player_instance)
	players.append(player_instance)
	
	var player_idx = players.size() - 1
	apply_color_to_player(player_instance, PLAYER_COLORS[player_idx % PLAYER_COLORS.size()])

func remove_player():
	if players.is_empty():
		return
	var player = players.pop_back()
	player.queue_free()

func update_player(player_idx: int, pose: Array):
	if pose.size() != KEYPOINTS.size() or player_idx >= players.size():
		return
	
	var player = players[player_idx]
	
	# Calcular posición central (promedio de caderas)
	var hip_left = pose[7]
	var hip_right = pose[8]
	
	var center_x = (hip_left["x"] + hip_right["x"]) / 2.0
	var center_y = (hip_left["y"] + hip_right["y"]) / 2.0
	var center_z = (hip_left.get("z", 0) + hip_right.get("z", 0)) / 2.0
	
	# Convertir coordenadas - efecto espejo (invertir X)
	var world_x = -(center_x - 0.5) * 4.0
	var world_y = (1.0 - center_y) * 3.0 - 1.5
	var world_z = -center_z * depth_scale
	
	var target_pos = Vector3(world_x, world_y, world_z) + offset
	player.global_position = player.global_position.lerp(target_pos, movement_smoothing)
	
	var skeleton = find_skeleton(player)
	if not skeleton:
		return
	
	update_skeleton_pose(skeleton, pose, player_idx)

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = find_skeleton(child)
		if result:
			return result
	return null

func update_skeleton_pose(skeleton: Skeleton3D, pose: Array, player_idx: int):
	# Convertir pose a vectores 3D
	var points: Array[Vector3] = []
	for p in pose:
		var px = -(p["x"] - 0.5)  # Invertir X para espejo
		var py = -(p["y"] - 0.5)  # Invertir Y
		var pz = p.get("z", 0) * depth_scale
		points.append(Vector3(px, py, pz))
	
	# Inicializar diccionario de rotaciones para este jugador si no existe
	var player_key = str(player_idx)
	if not last_valid_rotations.has(player_key):
		last_valid_rotations[player_key] = {}
	
	# ===== BRAZOS =====
	# Brazo.L = brazo superior izquierdo (hombro a codo)
	# Mano.L = antebrazo izquierdo (codo a muñeca)
	
	# Brazo izquierdo: hombro(1) -> codo(3)
	apply_bone_rotation(skeleton, "Brazo.L", points[1], points[3], Vector3.RIGHT, player_key)
	# Brazo derecho: hombro(2) -> codo(4)  
	apply_bone_rotation(skeleton, "Brazo.R", points[2], points[4], Vector3.LEFT, player_key)
	
	# Antebrazo izquierdo: codo(3) -> muñeca(5)
	apply_bone_rotation(skeleton, "Mano.L", points[3], points[5], Vector3.RIGHT, player_key)
	# Antebrazo derecho: codo(4) -> muñeca(6)
	apply_bone_rotation(skeleton, "Mano.R", points[4], points[6], Vector3.LEFT, player_key)
	
	# ===== PIERNAS =====
	# Pierna.L = muslo izquierdo (cadera a rodilla)
	# Pie.L = espinilla izquierda (rodilla a tobillo)
	
	# Muslo izquierdo: cadera(7) -> rodilla(9)
	apply_bone_rotation(skeleton, "Pierna.L", points[7], points[9], Vector3.DOWN, player_key)
	# Muslo derecho: cadera(8) -> rodilla(10)
	apply_bone_rotation(skeleton, "Pierna.R", points[8], points[10], Vector3.DOWN, player_key)
	
	# Espinilla izquierda: rodilla(9) -> tobillo(11)
	apply_bone_rotation(skeleton, "Pie.L", points[9], points[11], Vector3.DOWN, player_key)
	# Espinilla derecha: rodilla(10) -> tobillo(12)
	apply_bone_rotation(skeleton, "Pie.R", points[10], points[12], Vector3.DOWN, player_key)

func apply_bone_rotation(skeleton: Skeleton3D, bone_name: String, start: Vector3, end: Vector3, rest_dir: Vector3, player_key: String):
	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		return
	
	# Calcular dirección del hueso
	var bone_vec = end - start
	
	# Verificar que el vector es válido (longitud mínima)
	if bone_vec.length() < 0.01:
		# Usar última rotación válida si existe
		if last_valid_rotations[player_key].has(bone_name):
			skeleton.set_bone_pose_rotation(bone_idx, last_valid_rotations[player_key][bone_name])
		return
	
	var direction = bone_vec.normalized()
	
	# Verificar que no hay NaN
	if is_nan(direction.x) or is_nan(direction.y) or is_nan(direction.z):
		if last_valid_rotations[player_key].has(bone_name):
			skeleton.set_bone_pose_rotation(bone_idx, last_valid_rotations[player_key][bone_name])
		return
	
	# Calcular rotación desde la pose de reposo
	var target_quat = quat_from_to(rest_dir, direction)
	
	# Verificar quaternion válido
	if is_nan(target_quat.x) or is_nan(target_quat.y) or is_nan(target_quat.z) or is_nan(target_quat.w):
		if last_valid_rotations[player_key].has(bone_name):
			skeleton.set_bone_pose_rotation(bone_idx, last_valid_rotations[player_key][bone_name])
		return
	
	# Obtener rotación actual
	var current_quat = skeleton.get_bone_pose_rotation(bone_idx)
	
	# Verificar que la rotación actual es válida
	if is_nan(current_quat.x) or is_nan(current_quat.y) or is_nan(current_quat.z) or is_nan(current_quat.w):
		current_quat = Quaternion.IDENTITY
	
	# Aplicar suavizado
	var smoothed = current_quat.slerp(target_quat, rotation_smoothing)
	
	# Guardar como última rotación válida
	last_valid_rotations[player_key][bone_name] = smoothed
	
	skeleton.set_bone_pose_rotation(bone_idx, smoothed)

func quat_from_to(from: Vector3, to: Vector3) -> Quaternion:
	"""Calcula quaternion para rotar 'from' hacia 'to' de forma segura"""
	from = from.normalized()
	to = to.normalized()
	
	var dot = from.dot(to)
	dot = clamp(dot, -1.0, 1.0)
	
	# Vectores casi iguales
	if dot > 0.9999:
		return Quaternion.IDENTITY
	
	# Vectores opuestos - rotar 180° alrededor de un eje perpendicular
	if dot < -0.9999:
		var axis = Vector3.FORWARD.cross(from)
		if axis.length_squared() < 0.0001:
			axis = Vector3.UP.cross(from)
		return Quaternion(axis.normalized(), PI)
	
	# Caso normal
	var axis = from.cross(to)
	if axis.length_squared() < 0.0001:
		return Quaternion.IDENTITY
	
	axis = axis.normalized()
	var angle = acos(dot)
	
	return Quaternion(axis, angle)

func apply_color_to_player(player: Node, color: Color):
	apply_color_recursive(player, color)

func apply_color_recursive(node: Node, color: Color):
	if node is MeshInstance3D:
		var material = node.get_surface_override_material(0)
		if material and material is ShaderMaterial:
			if material.shader:
				material.set_shader_parameter("base_color", color)
	
	for child in node.get_children():
		apply_color_recursive(child, color)
