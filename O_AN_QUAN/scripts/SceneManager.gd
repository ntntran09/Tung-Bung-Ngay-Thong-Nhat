extends Node

var ai_level: String = "easy"
var player_score: int = 0
var ai_score: int = 0
var MAX_DEPTH: int = 1

func change_scene(scene_path: String):
	var error = SceneRoutes.change_to(scene_path, get_tree())
	if error != OK:
		push_error("Failed to change scene: " + scene_path)
