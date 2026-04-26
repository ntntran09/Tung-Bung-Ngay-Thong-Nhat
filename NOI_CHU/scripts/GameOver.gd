extends Control

@onready var play_again_button = $VBoxContainer/PlayAgainButton
@onready var quit_button = $VBoxContainer/QuitButton

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	play_again_button.pressed.connect(on_play_again_pressed)
	quit_button.pressed.connect(on_quit_pressed)

func on_play_again_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file(SceneRoutes.NOI_CHU_MAIN)

func on_quit_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file(SceneRoutes.MAIN_HUB)
