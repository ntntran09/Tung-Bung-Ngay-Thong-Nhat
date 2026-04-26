extends Control

@export var next_scene_path: String = SceneRoutes.MAIN_HUB

func _input(event):
	if event.is_pressed():
		DebugLog.value("Any input detected. Switching to: ", next_scene_path)
		get_tree().change_scene_to_file(next_scene_path)
