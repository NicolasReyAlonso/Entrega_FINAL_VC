extends Node3D

# Posturas objetivo disponibles
enum PoseType {
	T_POSE,           # Brazos extendidos
	ARMS_UP,          # Brazos arriba
	ARMS_DOWN,        # Brazos abajo
	LEFT_ARM_UP,      # Brazo izq arriba
	RIGHT_ARM_UP,     # Brazo der arriba
	SQUAT,            # En cuclillas
	JUMP              # Saltando
}

@export var current_pose: PoseType = PoseType.T_POSE
@export var tolerance: float = 0.3  # Tolerancia para detectar pose (0-1)
@export var points_per_success: int = 100

var pose_name_dict = {
	PoseType.T_POSE: "T-Pose",
	PoseType.ARMS_UP: "Brazos Arriba",
	PoseType.ARMS_DOWN: "Brazos Abajo",
	PoseType.LEFT_ARM_UP: "Brazo Izq Arriba",
	PoseType.RIGHT_ARM_UP: "Brazo Der Arriba",
	PoseType.SQUAT: "En Cuclillas",
	PoseType.JUMP: "¡Salta!"
}

var score = 0
var detected_pose_score = 0.0

func _ready():
	select_random_pose()

func select_random_pose():
	current_pose = randi() % PoseType.size()
	print("Postura objetivo: ", pose_name_dict[current_pose])

func evaluate_pose(skeleton: Skeleton3D) -> float:
	"""
	Evalúa la postura del jugador y retorna un score 0-1
	"""
	var score_value = 0.0
	
	match current_pose:
		PoseType.T_POSE:
			score_value = evaluate_t_pose(skeleton)
		PoseType.ARMS_UP:
			score_value = evaluate_arms_up(skeleton)
		PoseType.ARMS_DOWN:
			score_value = evaluate_arms_down(skeleton)
		PoseType.LEFT_ARM_UP:
			score_value = evaluate_left_arm_up(skeleton)
		PoseType.RIGHT_ARM_UP:
			score_value = evaluate_right_arm_up(skeleton)
		PoseType.SQUAT:
			score_value = evaluate_squat(skeleton)
		PoseType.JUMP:
			score_value = evaluate_jump(skeleton)
	
	self.detected_pose_score = score_value
	return score_value

func is_pose_correct() -> bool:
	"""Retorna true si la postura es correcta según la tolerancia"""
	return detected_pose_score >= tolerance

func get_pose_name() -> String:
	return pose_name_dict[current_pose]

# ===== EVALUADORES DE POSES =====

func evaluate_t_pose(skeleton: Skeleton3D) -> float:
	# T-Pose: brazos horizontales
	var left_arm = get_arm_angle(skeleton, "Brazo.L")
	var right_arm = get_arm_angle(skeleton, "Brazo.R")
	
	# 0 grados = horizontal (ideal)
	var left_score = 1.0 - (abs(left_arm) / 90.0)
	var right_score = 1.0 - (abs(right_arm) / 90.0)
	
	return clamp((left_score + right_score) / 2.0, 0.0, 1.0)

func evaluate_arms_up(skeleton: Skeleton3D) -> float:
	# Brazos arriba: ambos brazos elevados
	var left_arm = get_arm_angle(skeleton, "Brazo.L")
	var right_arm = get_arm_angle(skeleton, "Brazo.R")
	
	# -90 grados = arriba (ideal)
	var left_score = 1.0 - (abs(left_arm + 90.0) / 90.0)
	var right_score = 1.0 - (abs(right_arm + 90.0) / 90.0)
	
	return clamp((left_score + right_score) / 2.0, 0.0, 1.0)

func evaluate_arms_down(skeleton: Skeleton3D) -> float:
	# Brazos abajo: brazos pegados al cuerpo
	var left_arm = get_arm_angle(skeleton, "Brazo.L")
	var right_arm = get_arm_angle(skeleton, "Brazo.R")
	
	# ~180 grados = abajo
	var left_score = 1.0 - (abs(left_arm - 180.0) / 90.0)
	var right_score = 1.0 - (abs(right_arm - 180.0) / 90.0)
	
	return clamp((left_score + right_score) / 2.0, 0.0, 1.0)

func evaluate_left_arm_up(skeleton: Skeleton3D) -> float:
	# Solo brazo izq arriba
	var left_arm = get_arm_angle(skeleton, "Brazo.L")
	var right_arm = get_arm_angle(skeleton, "Brazo.R")
	
	var left_score = 1.0 - (abs(left_arm + 90.0) / 90.0)
	var right_score = 1.0 - (abs(right_arm - 180.0) / 90.0)
	
	return clamp((left_score + right_score) / 2.0, 0.0, 1.0)

func evaluate_right_arm_up(skeleton: Skeleton3D) -> float:
	# Solo brazo der arriba
	var left_arm = get_arm_angle(skeleton, "Brazo.L")
	var right_arm = get_arm_angle(skeleton, "Brazo.R")
	
	var left_score = 1.0 - (abs(left_arm - 180.0) / 90.0)
	var right_score = 1.0 - (abs(right_arm + 90.0) / 90.0)
	
	return clamp((left_score + right_score) / 2.0, 0.0, 1.0)

func evaluate_squat(skeleton: Skeleton3D) -> float:
	# En cuclillas: rodillas flexionadas
	var left_leg = get_leg_angle(skeleton, "Pierna.L")
	var right_leg = get_leg_angle(skeleton, "Pierna.R")
	
	# ~90 grados = cuclillas
	var left_score = 1.0 - (abs(left_leg - 90.0) / 90.0)
	var right_score = 1.0 - (abs(right_leg - 90.0) / 90.0)
	
	return clamp((left_score + right_score) / 2.0, 0.0, 1.0)

func evaluate_jump(skeleton: Skeleton3D) -> float:
	# Saltando: cuerpo elevado (se detecta por posición Y)
	# Simplificado: solo verificamos que los brazos estén abajo
	var left_arm = get_arm_angle(skeleton, "Brazo.L")
	var right_arm = get_arm_angle(skeleton, "Brazo.R")
	
	var left_score = 1.0 - (abs(left_arm - 180.0) / 90.0)
	var right_score = 1.0 - (abs(right_arm - 180.0) / 90.0)
	
	return clamp((left_score + right_score) / 2.0, 0.0, 1.0)

# ===== UTILIDADES =====

func get_arm_angle(skeleton: Skeleton3D, bone_name: String) -> float:
	"""Obtiene el ángulo del brazo en grados (simplificado)"""
	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		return 0.0
	
	var pose = skeleton.get_bone_pose(bone_idx)
	var basis = pose.basis
	
	# Convertir a ángulo Y (aproximado)
	return rad_to_deg(basis.get_euler().y)

func get_leg_angle(skeleton: Skeleton3D, bone_name: String) -> float:
	"""Obtiene el ángulo de la pierna en grados (simplificado)"""
	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		return 0.0
	
	var pose = skeleton.get_bone_pose(bone_idx)
	var basis = pose.basis
	
	# Convertir a ángulo X (aproximado)
	return rad_to_deg(basis.get_euler().x)

func add_score(points: int):
	score += points
	print("¡Puntos ganados! +%d (Total: %d)" % [points, score])
