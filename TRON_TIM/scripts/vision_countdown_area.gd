extends Area2D

@export var player_path: NodePath
@export var countdown_label: Label
@export var countdown_start := 3.0

@onready var player = get_node(player_path)

var countdown_time := 3.0
var countdown_timer: Timer

func _ready():
	countdown_time = countdown_start
	countdown_timer = Timer.new()
	countdown_timer.wait_time = 1.0
	countdown_timer.one_shot = false
	add_child(countdown_timer)

	countdown_timer.timeout.connect(_on_timer_tick)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if countdown_label:
		countdown_label.visible = false
	else:
		push_error("countdown_label is not assigned.")

func _on_body_entered(body):
	if body == player:
		countdown_time = countdown_start
		countdown_label.text = str(int(countdown_time))
		countdown_label.visible = true
		countdown_timer.start()

func _on_body_exited(body):
	if body == player:
		countdown_timer.stop()
		countdown_label.visible = false

func _on_timer_tick():
	countdown_time -= 1.0
	if countdown_time <= 0:
		countdown_timer.stop()
		countdown_label.visible = false
		get_tree().change_scene_to_file(SceneRoutes.TRON_TIM_GAME_OVER)
	else:
		countdown_label.text = str(int(countdown_time))
