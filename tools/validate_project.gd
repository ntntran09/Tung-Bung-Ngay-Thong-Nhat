extends SceneTree

var failed := false

func _initialize():
	_validate_autoloads()
	_validate_routes()
	_validate_target_scene_paths()
	_validate_dialogues()
	_validate_hardcoded_urls()
	quit(1 if failed else 0)

func _validate_autoloads() -> void:
	for name in ["AppConfig", "SceneRoutes", "DebugLog", "GameData", "SceneManager", "Global", "WindowConfig"]:
		_check(ProjectSettings.has_setting("autoload/" + name), "Missing autoload: " + name)

func _validate_routes() -> void:
	var routes_source := root.get_node_or_null("SceneRoutes")
	_check(routes_source != null, "SceneRoutes autoload is not available")
	if routes_source == null:
		return

	var routes := [
		routes_source.MAIN_START,
		routes_source.MAIN_HUB,
		routes_source.CO_GANH_MAIN,
		routes_source.NOI_CHU_MAIN,
		routes_source.NOI_CHU_GAME_OVER,
		routes_source.O_AN_QUAN_SELECT_LEVEL,
		routes_source.O_AN_QUAN_MAIN,
		routes_source.O_AN_QUAN_END_GAME,
		routes_source.TRON_TIM_LEVEL_SELECT,
		routes_source.TRON_TIM_GAME_OVER,
		routes_source.TRON_TIM_LEVEL_COMPLETED,
	]
	for route in routes:
		_check(ResourceLoader.exists(route), "Missing scene route: " + route)
		_check(load(route) is PackedScene, "Route is not a loadable scene: " + route)

	for level in [1, 2, 3]:
		var path: String = routes_source.tron_tim_level(level)
		_check(ResourceLoader.exists(path), "Missing Tron Tim level route: " + path)
		_check(load(path) is PackedScene, "Tron Tim level is not loadable: " + path)

func _validate_target_scene_paths() -> void:
	var routes_source := root.get_node_or_null("SceneRoutes")
	if routes_source == null:
		return

	var regex := RegEx.new()
	regex.compile('target_scene_path\\s*=\\s*"([^"]*)"')
	for path in _list_files("res://", ".tscn"):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue

		var text := file.get_as_text()
		file.close()
		for result in regex.search_all(text):
			var target := result.get_string(1)
			if target.strip_edges().is_empty():
				continue
			_check(routes_source.is_valid_scene(target), "Invalid target_scene_path in " + path + ": " + target)

func _validate_dialogues() -> void:
	for path in _list_files("res://MAIN/dialogues", ".txt"):
		var file := FileAccess.open(path, FileAccess.READ)
		_check(file != null, "Cannot open dialogue: " + path)
		if file == null:
			continue

		var lines := file.get_as_text().strip_edges(true, true).split("\n")
		file.close()
		_check(not lines.is_empty() and not lines[0].strip_edges().is_empty(), "Dialogue missing title line: " + path)

func _validate_hardcoded_urls() -> void:
	var bad_http := "http" + "://"
	var bad_https := "https" + "://"
	for path in _list_files("res://", ".gd"):
		if path == "res://tools/validate_project.gd":
			continue

		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue

		var text := file.get_as_text()
		file.close()
		_check(not text.contains(bad_http) and not text.contains(bad_https), "Hard-coded URL in script: " + path)

func _list_files(path: String, extension: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return results

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		var child_path := path.path_join(file_name)
		if dir.current_is_dir():
			if not file_name in [".git", ".godot", "EXPORT"]:
				results.append_array(_list_files(child_path, extension))
		elif file_name.ends_with(extension):
			results.append(child_path)
		file_name = dir.get_next()
	return results

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failed = true
	push_error(message)
