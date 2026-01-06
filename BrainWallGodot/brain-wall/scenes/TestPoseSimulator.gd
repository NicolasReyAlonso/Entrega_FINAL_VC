extends Node3D

# Script para simular poses MediaPipe sin servidor WebSocket
# Útil para debugging y testing

var test_poses: Array = [
	[
		{"x": 0.5, "y": 0.3, "z": 0.0},  # Nariz
		{"x": 0.3, "y": 0.2, "z": 0.0},  # Hombro izq
		{"x": 0.7, "y": 0.2, "z": 0.0},  # Hombro der
		{"x": 0.2, "y": 0.4, "z": 0.0},  # Codo izq
		{"x": 0.8, "y": 0.4, "z": 0.0},  # Codo der
		{"x": 0.1, "y": 0.5, "z": 0.0},  # Muñeca izq
		{"x": 0.9, "y": 0.5, "z": 0.0},  # Muñeca der
		{"x": 0.4, "y": 0.6, "z": 0.0},  # Cadera izq
		{"x": 0.6, "y": 0.6, "z": 0.0},  # Cadera der
		{"x": 0.4, "y": 0.8, "z": 0.0},  # Rodilla izq
		{"x": 0.6, "y": 0.8, "z": 0.0},  # Rodilla der
		{"x": 0.4, "y": 1.0, "z": 0.0},  # Tobillo izq
		{"x": 0.6, "y": 1.0, "z": 0.0},  # Tobillo der
	],
	# Agregar más posturas de prueba según sea necesario
]

var current_pose_idx: int = 0
var pose_timer: float = 2.0
var pose_cycle_time: float = 2.0

func _ready():
	# Este script puede usarse para enviar poses simuladas
	set_process(true)

func _process(delta):
	# Simular ciclo de poses (opcional)
	pose_timer -= delta
	if pose_timer <= 0:
		current_pose_idx = (current_pose_idx + 1) % test_poses.size()
		pose_timer = pose_cycle_time

func get_test_pose() -> Array:
	"""Retorna una pose de prueba"""
	if current_pose_idx < test_poses.size():
		return test_poses[current_pose_idx]
	return test_poses[0]

func send_test_pose_to_game():
	"""Envía una pose de prueba al script principal (llamar desde mainscript.gd)"""
	var pose = get_test_pose()
	# Aquí se llamaría a mainscript.update_player() con la pose
