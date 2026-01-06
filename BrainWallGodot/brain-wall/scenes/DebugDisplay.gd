extends Node3D

# Script de debugging para mostrar posiciones en pantalla

var debug_labels: Array = []

func _ready():
	create_debug_labels()

func create_debug_labels():
	"""Crea labels de debug para mostrar posiciones"""
	var viewport_size = get_viewport().get_visible_rect().size
	
	var debug_label = Label.new()
	debug_label.text = "DEBUG INFO"
	debug_label.add_theme_font_size_override("font_size", 20)
	debug_label.position = Vector2(20, viewport_size.y - 200)
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.add_child(debug_label)
	add_child(canvas_layer)
	
	debug_labels.append(debug_label)

func _process(delta):
	if debug_labels.size() > 0:
		var main_script = get_parent()
		var info = "=== DEBUG ===\n"
		
		if main_script and "players" in main_script:
			var players = main_script.players
			info += "Players: %d\n" % players.size()
			
			for i in range(players.size()):
				var player = players[i]
				info += "P%d: (%.2f, %.2f, %.2f)\n" % [
					i + 1,
					player.global_position.x,
					player.global_position.y,
					player.global_position.z
				]
			
			info += "\nScore: %d\n" % main_script.score
			info += "Lives: %d\n" % main_script.lives
			
			if "wall_generator" in main_script and main_script.wall_generator:
				info += "Walls: %d\n" % main_script.wall_generator.get_child_count()
		
		debug_labels[0].text = info
