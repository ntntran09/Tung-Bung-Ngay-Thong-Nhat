extends Node

const BASE_SIZE := Vector2i(1920, 1080)
const MIN_SIZE := Vector2i(960, 540)

func _enter_tree() -> void:
	_apply_window_config()

func _apply_window_config() -> void:
	var root := get_tree().root

	root.content_scale_size = BASE_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.min_size = MIN_SIZE
	root.unresizable = false
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)

	if root.size.x < MIN_SIZE.x or root.size.y < MIN_SIZE.y:
		root.size = BASE_SIZE
