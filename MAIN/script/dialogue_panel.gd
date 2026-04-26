extends Control

@onready var dialogue_box: Control = $DialogueBox
@onready var label: Label = $DialogueBox/Label
@onready var title: Label = $DialogueBox/Label2
@onready var choice_box: HBoxContainer = $DialogueBox/ChoiceBox
@onready var selector: TextureRect = $DialogueBox/Selector
@onready var press_e_icon: TextureRect = $DialogueBox/TextureRect2
@onready var buttons := [
	$DialogueBox/ChoiceBox/NoButton,
	$DialogueBox/ChoiceBox/AgainButton,
	$DialogueBox/ChoiceBox/YesButton
]

@export var target_scene_path: String = "res://path/to/next_scene.tscn"

var lines: PackedStringArray = []
var current_line := 0
var is_playing := false
var choice_active := false
var selected_index := 2
var player
signal dialogue_closed


func _ready():
	

	choice_box.visible = false
	selector.visible = false
	set_interact_hint_visible(false)
	selector.z_index = 100  # ✅ Ensure it's above all buttons
	visible = false
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.global_position = GameData.player_position
		  # 🛠 Restore player position
	$DialogueBox/ChoiceBox/YesButton.pressed.connect(on_yes_selected)
	$DialogueBox/ChoiceBox/AgainButton.pressed.connect(on_again_selected)
	$DialogueBox/ChoiceBox/NoButton.pressed.connect(on_no_selected)

func start_from_file(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		lines = file.get_as_text().strip_edges(true, true).split("\n")
		file.close()
	else:
		push_error("❌ Failed to load dialogue file: " + path)
		return
	if not GameData.is_dialogue_open:
		GameData.is_dialogue_open = true
		start_dialogue()



func start_dialogue():
	if player:
		player.can_move = false
	
	current_line = 0
	is_playing = true
	choice_active = false
	visible = true
	choice_box.visible = false
	selector.visible = false
	set_interact_hint_visible(true)
	if lines.size() > 0:
		title.text = lines[current_line]
		current_line += 1
		if current_line < lines.size():
			show_line()
		else:
			show_choices()

func advance():
	if not is_playing:
		return false
	
	current_line += 1
	if current_line < lines.size():
		show_line()
		return false
	else:
		show_choices()
		return true

func show_line():
	if current_line < lines.size():
		label.text = lines[current_line]
		set_interact_hint_visible(true)

func show_choices():
	print("Showing choices")
	is_playing = false
	choice_active = true
	choice_box.visible = true
	set_interact_hint_visible(false)

	selected_index = 2
	selector.visible = true
	call_deferred("update_selector_position")

func update_selector_position():
	var target_btn = buttons[selected_index]
	if not is_instance_valid(target_btn):
		print("❌ Invalid target button")
		return

	var btn_rect: Rect2 = target_btn.get_global_rect()
	var box_position := dialogue_box.global_position
	var selector_size := selector.size
	if selector_size == Vector2.ZERO:
		selector_size = Vector2(48, 48)

	selector.position = Vector2(
		btn_rect.position.x - box_position.x - selector_size.x - 14,
		btn_rect.position.y - box_position.y + (btn_rect.size.y - selector_size.y) * 0.5
	)
	selector.visible = true

	print("🎯 Button pos: ", btn_rect.position)
	print("🎯 Selector pos: ", selector.global_position)

func set_interact_hint_visible(is_visible: bool):
	if is_instance_valid(press_e_icon):
		press_e_icon.visible = is_visible





func _input(event: InputEvent):
	if not visible or not choice_active:
		return
		
	if event.is_action_pressed("walk_right") or event.is_action_pressed("ui_right"):
		selected_index = (selected_index + 1) % buttons.size()
		update_selector_position()
	elif event.is_action_pressed("walk_left") or event.is_action_pressed("ui_left"):
		selected_index = (selected_index - 1) % buttons.size()
		update_selector_position()
	elif event.is_action_pressed("interact"):
		print("✅ Pressed Interact on index:", selected_index)
		match selected_index:
			2: on_yes_selected()
			1: on_again_selected()
			0: on_no_selected()
	elif event.is_action_pressed("ui_cancel"):
		print("🔙 Cancel (ESC) pressed")
		finish()

func on_yes_selected():
	print("🟢 YES selected → changing scene to: ", target_scene_path)
	
	# 1. Save player position before changing scene
	if player:
		GameData.player_position = player.global_position
	
	# 2. Finish dialogue or pause menu
	finish()

	# 3. Change to the new scene
	var err = get_tree().change_scene_to_file(target_scene_path)
	if err != OK:
		push_error("Failed to change scene to: " + target_scene_path)


func on_again_selected():
	print("🔁 AGAIN selected → restarting dialogue")
	start_dialogue()

func on_no_selected():
	print("❌ NO selected → closing dialogue")
	finish()
	emit_signal("dialogue_closed")

func finish():
	print("🛑 Dialogue closed")
	if player:
		player.can_move = true
	GameData.is_dialogue_open = false
	is_playing = false
	choice_active = false
	visible = false
	selected_index = 2
	choice_box.visible = false
	selector.visible = false
	set_interact_hint_visible(false)
	label.text = ""
	title.text = ""
