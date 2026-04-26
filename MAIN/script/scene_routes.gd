extends Node

const MAIN_START := "res://MAIN/scenes/start.tscn"
const MAIN_HUB := "res://MAIN/scenes/main.tscn"

const CO_GANH_MAIN := "res://CO_GANH/scenes/main.tscn"

const NOI_CHU_MAIN := "res://NOI_CHU/scenes/main.tscn"
const NOI_CHU_GAME_OVER := "res://NOI_CHU/scenes/game_over.tscn"

const O_AN_QUAN_SELECT_LEVEL := "res://O_AN_QUAN/scenes/SelectLevel.tscn"
const O_AN_QUAN_MAIN := "res://O_AN_QUAN/scenes/main.tscn"
const O_AN_QUAN_END_GAME := "res://O_AN_QUAN/scenes/EndGame.tscn"

const TRON_TIM_LEVEL_SELECT := "res://TRON_TIM/scenes/level_select.tscn"
const TRON_TIM_GAME_OVER := "res://TRON_TIM/scenes/gameover.tscn"
const TRON_TIM_LEVEL_COMPLETED := "res://TRON_TIM/scenes/level_completed.tscn"
const TRON_TIM_LEVEL_PATTERN := "res://TRON_TIM/scenes/level_%d.tscn"

func tron_tim_level(level_num: int) -> String:
	return TRON_TIM_LEVEL_PATTERN % level_num

func is_valid_scene(path: String) -> bool:
	return not path.strip_edges().is_empty() and ResourceLoader.exists(path)

func change_to(path: String, tree: SceneTree) -> int:
	if not is_valid_scene(path):
		push_error("Scene route is invalid: " + path)
		return ERR_FILE_NOT_FOUND
	return tree.change_scene_to_file(path)
