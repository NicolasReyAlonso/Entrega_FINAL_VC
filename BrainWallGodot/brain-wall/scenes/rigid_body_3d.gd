extends RigidBody3D

@export var float_force: float = 5.0
@export var water_drag: float = 0.1
@export var water_angular_drag: float = 0.1

@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var water: Node3D = get_node("../MeshInstance3D") # ajusta la ruta a tu nodo de agua

var submerged: bool = false

func _physics_process(delta: float) -> void:
	submerged = false
	# Calcula la profundidad respecto al plano de agua
	var depth: float = water.global_position.y - global_position.y
	if depth > 0.0:
		submerged = true
		# Aplica fuerza hacia arriba proporcional a la profundidad
		apply_force(Vector3.UP * float_force * gravity * depth)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if submerged:
		# Aplica resistencia al movimiento cuando está bajo el agua
		state.linear_velocity *= (1.0 - water_drag)
		state.angular_velocity *= (1.0 - water_angular_drag)
