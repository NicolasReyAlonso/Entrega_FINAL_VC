extends Node3D

@export var wall_spawn_interval: float = 3.0
@export var wall_speed: float = 5.0

var timer: float = 0.0
var wall_count: int = 0

const WALL_POSES = [
	"T_POSE",
	"ARMS_UP",
	"ARMS_DOWN",
	"LEFT_ARM_UP",
	"RIGHT_ARM_UP",
	"SQUAT",
	"JUMP"
]

func _ready():
	timer = wall_spawn_interval

func _process(delta):
	timer -= delta
	if timer <= 0:
		spawn_wall()
		timer = wall_spawn_interval
	
	# Mover las paredes hacia adelante (Z negativo)
	for wall in get_children():
		wall.position.z -= wall_speed * delta
		
		# Limpiar walls que salieron del rango
		if wall.position.z < -30:
			wall.queue_free()

func spawn_wall():
	# Crear un Node3D que será el contenedor de la pared
	var wall_container = Node3D.new()
	wall_container.name = "Wall_%d" % wall_count
	wall_count += 1
	
	# Seleccionar postura aleatoria
	var pose_idx = randi() % WALL_POSES.size()
	var pose_type = WALL_POSES[pose_idx]
	
	# Crear MeshInstance3D para visualizar
	var wall = MeshInstance3D.new()
	var mesh = create_wall_mesh(pose_type)
	wall.mesh = mesh
	
	# Material de la pared
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.2, 0.8, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	wall.set_surface_override_material(0, material)
	
	wall_container.add_child(wall)
	
	# Posición inicial (frente, en Z positivo)
	wall_container.position = Vector3(0, 2, 20)
	
	# Etiqueta para identificar tipo de postura
	wall_container.set_meta("pose_type", pose_type)
	
	add_child(wall_container)
	print("Pared generada: ", pose_type)

func create_wall_mesh(pose_type: String) -> Mesh:
	"""Crea una pared con agujero según la postura"""
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	match pose_type:
		"T_POSE":
			create_t_pose_wall(st)
		"ARMS_UP":
			create_arms_up_wall(st)
		"ARMS_DOWN":
			create_arms_down_wall(st)
		"LEFT_ARM_UP":
			create_left_arm_wall(st)
		"RIGHT_ARM_UP":
			create_right_arm_wall(st)
		"SQUAT":
			create_squat_wall(st)
		"JUMP":
			create_jump_wall(st)
		_:
			create_t_pose_wall(st)
	
	st.generate_normals()
	var mesh = st.commit()
	return mesh

func create_t_pose_wall(st: SurfaceTool):
	"""Crea pared con agujero en forma de T"""
	var left = -2.5
	var right = 2.5
	var top = 1.25
	var bottom = -1.25
	
	# Agujero T (brazos y cuerpo)
	var arm_left = -1.0
	var arm_right = 1.0
	var arm_top = 0.75
	var arm_bottom = 0.0
	
	var body_left = -0.375
	var body_right = 0.375
	var body_top = 0.0
	var body_bottom = -1.0
	
	# Marco superior (encima de los brazos)
	add_rect(st, left, top, right, arm_top)
	
	# Marcos laterales de los brazos
	add_rect(st, left, arm_top, arm_left, arm_bottom)
	add_rect(st, arm_right, arm_top, right, arm_bottom)
	
	# Marcos laterales del cuerpo
	add_rect(st, left, arm_bottom, body_left, body_bottom)
	add_rect(st, body_right, arm_bottom, right, body_bottom)
	
	# Marco inferior
	add_rect(st, left, body_bottom, right, bottom)

func create_arms_up_wall(st: SurfaceTool):
	"""Crea pared con agujero arriba (brazos arriba)"""
	var left = -2.5
	var right = 2.5
	var top = 1.25
	var bottom = -1.25
	
	var hole_left = -0.5
	var hole_right = 0.5
	var hole_top = 0.75
	var hole_bottom = -0.75
	
	# Lados del agujero
	add_rect(st, left, top, hole_left, bottom)
	add_rect(st, hole_right, top, right, bottom)
	
	# Abajo del agujero
	add_rect(st, hole_left, hole_bottom, hole_right, bottom)

func create_arms_down_wall(st: SurfaceTool):
	"""Crea pared con agujero abajo (brazos abajo)"""
	var left = -2.5
	var right = 2.5
	var top = 1.25
	var bottom = -1.25
	
	var hole_left = -0.5
	var hole_right = 0.5
	var hole_top = 0.75
	var hole_bottom = -0.75
	
	# Arriba del agujero
	add_rect(st, left, top, right, hole_top)
	
	# Lados del agujero
	add_rect(st, left, hole_top, hole_left, bottom)
	add_rect(st, hole_right, hole_top, right, bottom)

func create_left_arm_wall(st: SurfaceTool):
	"""Crea pared con agujero a la izquierda"""
	var left = -2.5
	var right = 2.5
	var top = 1.25
	var bottom = -1.25
	
	var hole_left = -2.0
	var hole_right = -0.5
	var hole_top = 0.75
	var hole_bottom = -0.75
	
	# Arriba del agujero
	add_rect(st, left, top, right, hole_top)
	
	# Abajo del agujero
	add_rect(st, left, hole_bottom, right, bottom)
	
	# Derecha del agujero
	add_rect(st, hole_right, hole_top, right, hole_bottom)

func create_right_arm_wall(st: SurfaceTool):
	"""Crea pared con agujero a la derecha"""
	var left = -2.5
	var right = 2.5
	var top = 1.25
	var bottom = -1.25
	
	var hole_left = 0.5
	var hole_right = 2.0
	var hole_top = 0.75
	var hole_bottom = -0.75
	
	# Arriba del agujero
	add_rect(st, left, top, right, hole_top)
	
	# Abajo del agujero
	add_rect(st, left, hole_bottom, right, bottom)
	
	# Izquierda del agujero
	add_rect(st, left, hole_top, hole_left, hole_bottom)

func create_squat_wall(st: SurfaceTool):
	"""Crea pared con agujero bajo (cuclillas)"""
	var left = -2.5
	var right = 2.5
	var top = 1.25
	var bottom = -1.25
	
	var hole_left = -1.25
	var hole_right = 1.25
	var hole_top = 0.25
	var hole_bottom = -1.0
	
	# Arriba del agujero
	add_rect(st, left, top, right, hole_top)
	
	# Lados del agujero
	add_rect(st, left, hole_top, hole_left, hole_bottom)
	add_rect(st, hole_right, hole_top, right, hole_bottom)
	
	# Abajo del agujero
	add_rect(st, hole_left, hole_bottom, hole_right, bottom)

func create_jump_wall(st: SurfaceTool):
	"""Crea pared con agujero estrecho (salto)"""
	var left = -2.5
	var right = 2.5
	var top = 1.25
	var bottom = -1.25
	
	var hole_left = -0.25
	var hole_right = 0.25
	var hole_top = 0.75
	var hole_bottom = -0.25
	
	# Arriba del agujero
	add_rect(st, left, top, right, hole_top)
	
	# Abajo del agujero
	add_rect(st, left, hole_bottom, right, bottom)
	
	# Lados del agujero
	add_rect(st, left, hole_top, hole_left, hole_bottom)
	add_rect(st, hole_right, hole_top, right, hole_bottom)

func add_rect(st: SurfaceTool, x1: float, y1: float, x2: float, y2: float):
	"""Agrega un rectángulo a la malla como dos triángulos"""
	var z = 0.0
	var normal = Vector3.FORWARD
	
	var v1 = Vector3(x1, y1, z)
	var v2 = Vector3(x2, y1, z)
	var v3 = Vector3(x2, y2, z)
	var v4 = Vector3(x1, y2, z)
	
	# Triángulo 1
	st.set_normal(normal)
	st.add_vertex(v1)
	st.add_vertex(v2)
	st.add_vertex(v3)
	
	# Triángulo 2
	st.set_normal(normal)
	st.add_vertex(v1)
	st.add_vertex(v3)
	st.add_vertex(v4)
