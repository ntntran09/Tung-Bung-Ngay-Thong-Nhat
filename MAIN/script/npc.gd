extends CharacterBody3D

@export var speed := 3.0
@export var patrol_parent_path: NodePath
@export var max_point_distance := 5.0
@export var input_file: String  # Dialogue file name
@export var npc_name: String  # Dialogue file name

@onready var npc_sprite: Sprite3D = $Sprite3D
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var sprite_front: AnimatedSprite3D = $AnimatedSprite3D
@onready var sprite_back: AnimatedSprite3D = $AnimatedSprite3D2
@onready var detection_area: Area3D = $Area3D
@onready var dialogue_box: Control = $DialoguePanel
@onready var api: HTTPRequest = $APIRequest
var last_callback: Callable
const SERVER_URL := GameData.api_url

var text:= ""
var patrol_parent: Node3D
var last_point: Node3D = null
var was_moving := false
var is_choosing_next_point := false
var is_requesting := false
var turn_tween: Tween = null
var stuck_timer := 0.0
var previous_distance := INF
var is_player_inside := false
var just_closed := false
var just_got := false
var dialogue_file_path := ""

func _ready():

	dialogue_file_path = "res://MAIN/dialogues/" + input_file
	text = get_fallback_text()
	api.timeout = 8.0

	# --- Patrol setup ---
	if patrol_parent_path.is_empty():
		push_error("❗ patrol_parent_path is not set!")
		return

	patrol_parent = get_node_or_null(patrol_parent_path)
	if patrol_parent == null:
		push_error("❌ patrol_parent not found: " + str(patrol_parent_path))
		return

	if patrol_parent.get_child_count() == 0:
		push_error("🚫 No patrol points under patrol_parent!")
		return

	nav_agent.path_desired_distance = 0.1
	nav_agent.target_desired_distance = 0.2

	play_animation("Idle")
	_go_to_forward_point()

	# --- Dialogue setup ---
	detection_area.body_entered.connect(_on_Area3D_body_entered)
	detection_area.body_exited.connect(_on_Area3D_body_exited)

	if dialogue_box and dialogue_box.has_signal("dialogue_closed"):
		dialogue_box.dialogue_closed.connect(_on_dialogue_closed)
		


	_reset_conver()


func _physics_process(delta):
	if dialogue_box.visible:
		# Pause movement when talking
		face_player()
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if nav_agent.is_navigation_finished():
		if not is_choosing_next_point:
			is_choosing_next_point = true
			if was_moving:
				play_animation("Idle")
				was_moving = false

			if randf() < 0.4:
				var wait_time = randf_range(1.0, 2.0)
				print("💤 NPC pauses for", wait_time, "seconds")
				await get_tree().create_timer(wait_time).timeout
			else:
				print("⚡ NPC skips pause and keeps moving")

			_go_to_forward_point()
			is_choosing_next_point = false
		return

	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position)
	var dist = direction.length()

	if dist > previous_distance - 0.05:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
	previous_distance = dist

	if stuck_timer > 2.0:
		print("❌ NPC might be stuck, repathing...")
		_go_to_forward_point()
		stuck_timer = 0.0
		return

	if dist > 0.05:
		direction = direction.normalized()
		var angle = atan2(-direction.x, -direction.z)
		var target_deg = rad_to_deg(angle)

		if abs(rotation_degrees.y - target_deg) > 2.0:
			turn_tween = create_tween()
			turn_tween.tween_property(self, "rotation_degrees:y", target_deg, 0.2) \
				.set_trans(Tween.TransitionType.TRANS_SINE) \
				.set_ease(Tween.EaseType.EASE_OUT)

		if not was_moving:
			play_animation("Walk")
			was_moving = true
	else:
		if was_moving:
			play_animation("Idle")
			was_moving = false

	velocity = direction * speed
	move_and_slide()

func show_sprite():
	npc_sprite.visible = true

func hide_sprite():
	npc_sprite.visible = false
	
func _go_to_forward_point():
	var points: Array[Node3D] = []
	for child in patrol_parent.get_children():
		if child is Node3D:
			points.append(child)

	if points.is_empty():
		push_warning("⚠️ No patrol points found at runtime!")
		return

	var forward := -transform.basis.z.normalized()
	var forward_candidates := []

	for point in points:
		if point == last_point:
			continue

		var to_point = (point.global_position - global_position).normalized()
		var dot := forward.dot(to_point)

		if dot > 0.2 and global_position.distance_to(point.global_position) <= max_point_distance:
			forward_candidates.append(point)

	if forward_candidates.is_empty():
		forward_candidates = points.filter(func(p): return p != last_point)

	if forward_candidates.is_empty():
		forward_candidates = points

	var chosen_point = forward_candidates[randi() % forward_candidates.size()]
	last_point = chosen_point

	print("🔀 Moving forward to:", chosen_point.name)
	nav_agent.target_position = chosen_point.global_position

func play_animation(name: String):
	if sprite_front.sprite_frames.has_animation(name):
		sprite_front.play(name)
		sprite_back.play(name)

# Dialogue integration

func _input(event: InputEvent):
	if not is_player_inside or just_closed or GameData.dialogue_cooldown:
		return
	
	if event.is_action_pressed("interact"):
		if dialogue_box.visible:
			if dialogue_box.has_method("advance"):
				var reached_end = dialogue_box.advance()
				if reached_end:
					_reset_conver()
					just_closed = true
					await start_close_cooldown()
		else:
			if dialogue_box.has_method("start_from_text"):
				if text.strip_edges().is_empty():
					text = get_fallback_text()
				dialogue_box.start_from_text(text)

func _reset_conver():
	while GameData.is_dialogue_open and is_player_inside:
		await get_tree().create_timer(1).timeout
	text = get_fallback_text()
	var file := FileAccess.open(dialogue_file_path, FileAccess.READ)
	var file_text := ""
	if file:
		file_text = file.get_as_text()
		file.close()
	else:
		push_error("❌ Failed to load dialogue file: " + dialogue_file_path)
		return
	api_call("/npc/npc_intro", {"npc_background": file_text}, func(res):
		print(res)
		if res.has("status") and res["status"] == "success" and res.has("reply"):
			text = npc_name + '\n' + res["reply"] 
			print(text)
		else:
			text = npc_name + "\n Chúc bạn ngày vui vẻ!" 
	)
	
	
func get_fallback_text() -> String:
	var display_name := npc_name.strip_edges()
	if display_name.is_empty():
		display_name = "NPC"
	return display_name + "\nChuc ban ngay vui ve!"


func _on_Area3D_body_entered(body: Node):
	if body.is_in_group("player"):
		is_player_inside = true
		show_sprite()
		


func _on_Area3D_body_exited(body: Node):
	if body.is_in_group("player"):
		is_player_inside = false
		hide_sprite()
		GameData.dialogue_cooldown = false

func _on_dialogue_closed():
	print("❌ Dialogue closed → enter cooldown")
	GameData.dialogue_cooldown = true
	start_dialogue_cooldown()

func start_close_cooldown():
	await get_tree().create_timer(0.2).timeout
	just_closed = false
	print("✅ Short cooldown ended")
	
#func start_http_cooldown():
	#await get_tree().create_timer(1).timeout
	#just_got = false
	#print("✅ Short cooldown ended")

func start_dialogue_cooldown():
	await get_tree().create_timer(1.0).timeout
	GameData.dialogue_cooldown = false
	print("🕓 Dialogue cooldown ended")
	
func face_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players.front()

	var to_player = (player.global_position - global_position).normalized()
	var angle = atan2(-to_player.x, -to_player.z)
	var target_deg = rad_to_deg(angle)

	var tween = create_tween()
	tween.tween_property(self, "rotation_degrees:y", target_deg, 0.2) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
		
		
func api_call(path: String, body: Variant, callback: Callable):
	if is_requesting:
		print("Already processing a request.")
		return
	last_callback = callback  # Lưu lại để gọi sau khi có kết quả

	var headers = ["Content-Type: application/json"]
	var json_data = JSON.stringify(body)
	var method = HTTPClient.METHOD_GET
	var payload := ""

	if body != {}:
		method = HTTPClient.METHOD_POST
		payload = json_data
	if not api.is_connected("request_completed", Callable(self, "_on_api_response")):
		var result = api.request_completed.connect(_on_api_response, CONNECT_ONE_SHOT)
		print(result)
	is_requesting = true
	var err = api.request(SERVER_URL + path, headers, method, payload)
	if err != OK:
		is_requesting = false
		print("Request failed to start.")
	else:
		print("Request started.")
	#var result = api.request_completed.connect(_on_api_response, CONNECT_ONE_SHOT)
	#print(result)

func _on_api_response(result, code, headers, body):
	is_requesting = false
	print("Response received")
	print("Result code: ", result)
	print("HTTP code: ", code)
	print("Raw body: ", body.get_string_from_utf8())
	if code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		print(json)
		if json:
			last_callback.call(json)  # ✅ Gọi callback đã lưu
	else:
		print(code)
		return
