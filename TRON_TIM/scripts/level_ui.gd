extends CanvasLayer

@export var level_num := 1
@export var time_left := 20

@onready var timer_label = $LevelTimerLabel
@onready var level_timer = $LevelTimer
@onready var timeout_sound = $"../CountDownSound"
@onready var reng_sound = $"../RengSound"

var on_level_win: Callable = func(): pass

func _ready():
	timer_label.text = str(time_left)
	level_timer.timeout.connect(_on_timer_tick)
	level_timer.start()
	Global.current_level = self
	Global.current_level_num = level_num
	on_level_win = Global._on_level_win

func _on_timer_tick():
	time_left -= 1
	timer_label.text = str(time_left)

	if time_left <= 3:
		timeout_sound.play()
	if time_left == 1:
		reng_sound.play()
	if time_left < 0:
		_on_level_complete()

func _on_level_complete():
	level_timer.stop()
	if on_level_win:
		on_level_win.call()
