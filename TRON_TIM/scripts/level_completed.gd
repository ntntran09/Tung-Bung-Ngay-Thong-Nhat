extends Node

func _ready():
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file(SceneRoutes.TRON_TIM_LEVEL_SELECT)
