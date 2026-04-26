extends Control

const MENU_FRAME_SIZE := Vector2(1536.0, 1024.0)

@onready var menu := $Control  # Menu chính (overlay + frame)
@onready var menu_frame: Control = $Control/MenuFrame
@onready var pause_button := $TextureButton  # Nút Pause
@onready var resume_button: Button = $Control/MenuFrame/VBoxContainer/ResumeButton
@onready var quit_button: Button = $Control/MenuFrame/VBoxContainer/QuitButton

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu.visible = false
	pause_button.visible = true
	get_tree().paused = false
	menu_frame.pivot_offset = MENU_FRAME_SIZE * 0.5
	get_viewport().size_changed.connect(_update_menu_scale)
	call_deferred("_update_menu_scale")

	# Kết nối các nút
	resume_button.pressed.connect(_on_resume)
	quit_button.pressed.connect(_on_quit)
	pause_button.pressed.connect(_toggle)

func _update_menu_scale() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var scale_factor: float = minf(
		viewport_size.x / MENU_FRAME_SIZE.x,
		viewport_size.y / MENU_FRAME_SIZE.y
	)
	menu_frame.scale = Vector2.ONE * scale_factor

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle()

func _toggle():
	if get_tree().paused:
		hide_menu()
	else:
		show_menu()

func show_menu():
	menu.visible = true
	pause_button.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_menu():
	menu.visible = false
	pause_button.visible = true
	get_tree().paused = false

func _on_resume():
	hide_menu()

func _on_quit():
	get_tree().paused = false
	menu.visible = false
	pause_button.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_file("res://MAIN/scenes/main.tscn")
