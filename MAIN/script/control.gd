extends Control

const MENU_FRAME_SIZE := Vector2(1536.0, 1024.0)

@export var skins: Array[SpriteFrames]  # Assign your skin animations in the Inspector

@onready var menu_frame: Control = $Control/MenuFrame
@onready var skin_option: OptionButton = $Control/MenuFrame/VBoxContainer/SkinOptionButton
@onready var resume_button: Button = $Control/MenuFrame/VBoxContainer/ResumeButton
@onready var quit_button: Button = $Control/MenuFrame/VBoxContainer/QuitButton
@onready var preview_sprite := $Control/MenuFrame/AnimatedSprite2D  # UI skin preview


# These will be fetched dynamically
var player: Node = null
var sprite3d: AnimatedSprite3D = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	get_tree().paused = false
	menu_frame.pivot_offset = MENU_FRAME_SIZE * 0.5
	get_viewport().size_changed.connect(_update_menu_scale)
	call_deferred("_update_menu_scale")


	# Get player and their sprite
	player = get_tree().get_first_node_in_group("player")
	if player:
		sprite3d = player.get_node_or_null("Sprite3D")  # Adjust if needed

	# Setup UI
	skin_option.select(GameData.selected_skin_index)
	skin_option.text = "Skin"
	skin_option.item_selected.connect(apply_skin)
	resume_button.pressed.connect(_on_resume)
	quit_button.pressed.connect(_on_quit)

	# Apply saved skin initially
	apply_skin(GameData.selected_skin_index)

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
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	preview_sprite.visible = true


func hide_menu():
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	preview_sprite.visible = false


func _on_resume():
	hide_menu()

func _on_quit():
	get_tree().quit()

func apply_skin(index: int):
	GameData.selected_skin_index = index

	if index < skins.size():
		var selected_skin = skins[index]

		# Apply to 3D player
		if sprite3d:
			sprite3d.frames = selected_skin

		# Apply to 2D preview
		if preview_sprite:
			preview_sprite.frames = selected_skin
			if selected_skin.has_animation("Idle_front"):
				preview_sprite.play("Idle_front")
