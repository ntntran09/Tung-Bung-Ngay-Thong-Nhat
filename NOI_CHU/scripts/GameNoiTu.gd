extends Control

const JsonApiClient = preload("res://MAIN/script/json_api_client.gd")

var score: int = 0
var time_left: int = 20
var session_id: String = ""
var used_words: Array[String] = []
var current_word: String = ""
var pending_player_word: String = ""
var game_over_started := false

@onready var score_label: Label = $MainLayout/ScoreTimerBox/ScoreLabel
@onready var time_label: Label = $MainLayout/ScoreTimerBox/TimeLabel
@onready var current_word_label: Label = $MainLayout/CurrentWordContainer/CurrentWordLabel
@onready var word_input: LineEdit = $MainLayout/InputBar/InputField
@onready var submit_button: Button = $MainLayout/InputBar/SubmitButton
@onready var timer: Timer = $Timer
@onready var toast_label = $MainLayout/ToastContainer/ToastLabel
@onready var api: HTTPRequest = $APIRequest
@onready var music_player = $MusicPlayer
@onready var ding_player = $SFXContainer/DingPlayer
@onready var wrong_player = $SFXContainer/WrongPlayer
@onready var timeout_player = $SFXContainer/TimeoutPlayer

var api_client

func _ready():
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	api_client = JsonApiClient.new(api)
	timer.wait_time = 1.0
	timer.timeout.connect(_on_timer_tick)
	word_input.focus_mode = Control.FOCUS_ALL
	word_input.text_submitted.connect(_on_word_submitted)
	word_input.grab_focus()
	set_input_enabled(false)
	start_new_game()

func api_call(path: String, body: Dictionary, callback: Callable):
	api_client.request(path, body, func(result: Dictionary):
		if not result["ok"]:
			wrong_player.play()
			game_over(str(result["error"]))
			return
		callback.call(result["data"])
	)

func start_new_game():
	game_over_started = false
	score = 0
	time_left = 20
	session_id = ""
	current_word = ""
	pending_player_word = ""
	used_words.clear()
	update_ui()
	set_input_enabled(false)
	current_word_label.text = "Đang tạo phiên chơi mới..."

	api_call("/game/start", {}, func(result):
		if not result.has("session_id"):
			wrong_player.play()
			game_over("Phản hồi server không hợp lệ.")
			return

		session_id = str(result["session_id"])
		fetch_new_word("Không lấy được từ bắt đầu.")
	)

func fetch_new_word(error_message: String, mark_used := false):
	current_word_label.text = "Đang lấy từ mới..."
	api_call("/game/new_word", {"session_id": session_id}, func(res):
		if not res.has("answer"):
			wrong_player.play()
			game_over(error_message)
			return

		current_word = normalize_word(str(res["answer"]))
		if mark_used and not is_word_used(current_word):
			used_words.append(current_word)
		current_word_label.text = "Từ hiện tại: " + current_word
		time_left = 20
		timer.start()
		update_ui()
		set_input_enabled(true)
	)

func is_word_used(word: String) -> bool:
	return word in used_words

func _on_word_submitted(user_word: String):
	if game_over_started:
		return

	var normalized_word = normalize_word(user_word)
	if normalized_word.is_empty():
		return

	set_input_enabled(false)

	if is_word_used(normalized_word):
		wrong_player.play()
		show_toast("Từ này đã được sử dụng!")
		word_input.clear()
		set_input_enabled(true)
		return

	if current_word.is_empty() or not validate_pair(current_word, normalized_word):
		wrong_player.play()
		game_over("Không đúng luật nối từ!")
		return

	pending_player_word = normalized_word
	api_call("/word/validate", {"word": normalized_word}, _on_validate_response)

func _on_validate_response(result):
	if not result.has("valid"):
		wrong_player.play()
		game_over("Phản hồi server không hợp lệ.")
		return

	if result["valid"] != true:
		wrong_player.play()
		var reason = str(result.get("reason", "Từ không hợp lệ."))
		game_over(reason)
		return

	score += 10
	time_left = 20
	timer.stop()
	used_words.append(pending_player_word)
	current_word_label.text = "Đợi bot..."
	word_input.clear()
	ding_player.play()

	var data = {
		"prompt": pending_player_word,
		"session_id": session_id,
	}
	api_call("/ask", data, _on_ask_responded)

func _on_ask_responded(result):
	if not result.has("status") or not result.has("answer"):
		wrong_player.play()
		game_over("Phản hồi server không hợp lệ.")
		return

	var status = str(result["status"])
	var answer = normalize_word(str(result["answer"]))
	if answer.is_empty():
		wrong_player.play()
		game_over("Phản hồi server không hợp lệ.")
		return

	if status == "error":
		wrong_player.play()
		game_over(answer)
		return

	if status == "unfound":
		score += 50
		show_toast("+50 điểm! Bot không tìm được từ phù hợp")
		ding_player.play()
		update_ui()
		set_input_enabled(false)
		fetch_new_word("Không lấy được từ mới.", true)
		return

	current_word = answer
	used_words.append(current_word)
	time_left = 20
	current_word_label.text = "Từ hiện tại: " + current_word
	timer.start()
	update_ui()
	set_input_enabled(true)

func update_ui():
	score_label.text = "Điểm: %d" % score
	time_label.text = "Thời gian: %d" % time_left

func game_over(reason: String):
	if game_over_started:
		return

	game_over_started = true
	timer.stop()
	set_input_enabled(false)
	show_toast(reason)
	await get_tree().create_timer(3.0).timeout

	get_tree().paused = true
	var game_over_scene = load(SceneRoutes.NOI_CHU_GAME_OVER).instantiate()
	add_child(game_over_scene)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_timer_tick():
	time_left -= 1
	update_ui()
	if time_left <= 0:
		timeout_player.play()
		game_over("Hết giờ!")

func validate_pair(word1: String, word2: String) -> bool:
	var w1 = normalize_word(word1).split(" ", false)
	var w2 = normalize_word(word2).split(" ", false)
	return w1.size() > 0 and w2.size() > 0 and w1[-1] == w2[0]

func normalize_word(word: String) -> String:
	return word.strip_edges().to_lower()

func show_toast(message: String):
	toast_label.show_message(message)

func set_input_enabled(enabled: bool):
	word_input.editable = enabled
	submit_button.disabled = not enabled
	if enabled:
		word_input.grab_focus()

func _on_submit_button_pressed() -> void:
	_on_word_submitted(word_input.text)
