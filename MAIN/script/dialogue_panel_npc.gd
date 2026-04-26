extends Control

@onready var label: Label = $Label
@onready var title: Label = $Label2

var lines: Array[String] = []
var current_line := 0
var is_playing := false
var timer_token := 0

signal dialogue_closed

func _ready():
	visible = false

func start_from_text(text: String):
	var parsed_lines = parse_lines(text)
	if parsed_lines.is_empty():
		push_error("NPC dialogue text is empty")
		return

	lines = parsed_lines
	if not GameData.is_dialogue_open:
		GameData.is_dialogue_open = true
		start_dialogue()

func start_from_file(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to load dialogue file: " + path)
		return

	start_from_text(file.get_as_text())
	file.close()

func start_dialogue():
	timer_token += 1
	var my_token := timer_token
	start_dialogue_timer(my_token)

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.can_move = false

	current_line = 0
	is_playing = true
	visible = true

	title.text = lines[current_line]
	current_line += 1
	show_line()

func start_dialogue_timer(my_token: int):
	await get_tree().create_timer(9.0).timeout
	if my_token == timer_token and is_playing:
		_finish()

func advance():
	if not is_playing:
		return false

	current_line += 1
	if current_line < lines.size():
		show_line()
		return false

	_finish()
	emit_signal("dialogue_closed")
	return true

func show_line():
	if current_line < lines.size():
		label.text = lines[current_line]
	else:
		label.text = ""

func parse_lines(text: String) -> Array[String]:
	var parsed: Array[String] = []
	for line in text.strip_edges(true, true).split("\n"):
		var clean_line = line.strip_edges()
		if not clean_line.is_empty():
			parsed.append(clean_line)
	return parsed

func _finish():
	timer_token += 1
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.can_move = true

	is_playing = false
	GameData.is_dialogue_open = false
	visible = false
	label.text = ""
	title.text = ""

	if Input.is_action_just_pressed("ui_cancel"):
		emit_signal("dialogue_closed")
