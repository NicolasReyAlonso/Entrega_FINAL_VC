extends Node3D

var socket := WebSocketPeer.new()
var pose = []

func _ready():
	var err = socket.connect_to_url("ws://localhost:8765")
	if err != OK:
		print("Error al conectar WebSocket: ", err)
	set_process(true)

func _process(delta):
	socket.poll()

	var state = socket.get_ready_state()

	# 1 = OPEN
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var data = socket.get_packet().get_string_from_utf8()
			pose = JSON.parse_string(data)
			print("Pose recibida: ", pose.size(), " puntos")

func get_pose_points_3d():
	var pts_3d = []
	for p in pose:
		var x = (p.x - 0.5) * 2.0
		var y = (0.5 - p.y) * 2.0
		var z = 0
		pts_3d.append(Vector3(x, y, z))
	return pts_3d
