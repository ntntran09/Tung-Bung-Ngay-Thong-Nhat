extends CharacterBody3D

const JsonApiClient = preload("res://MAIN/script/json_api_client.gd")

@export var speed := 3.0
@export var patrol_parent_path: NodePath
@export var max_point_distance := 5.0
@export var input_file: String
@export var npc_name: String

@onready var npc_sprite: Sprite3D = $Sprite3D
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var sprite_front: AnimatedSprite3D = $AnimatedSprite3D
@onready var sprite_back: AnimatedSprite3D = $AnimatedSprite3D2
@onready var detection_area: Area3D = $Area3D
@onready var dialogue_box: Control = $DialoguePanel
@onready var api: HTTPRequest = $APIRequest

var api_client
var text := ""
var patrol_parent: Node3D
var last_point: Node3D = null
var was_moving := false
var is_choosing_next_point := false
var turn_tween: Tween = null
var stuck_timer := 0.0
var previous_distance := INF
var is_player_inside := false
var just_closed := false
var dialogue_file_path := ""

func _ready():
	dialogue_file_path = "res://MAIN/dialogues/" + input_file
	text = get_fallback_text()
	api_client = JsonApiClient.new(api)

	if not _setup_patrol():
		return

	play_animation("Idle")
	_go_to_forward_point()
	_bind_dialogue()
	_reset_conver()

func _setup_patrol() -> bool:
	if patrol_parent_path.is_empty():
		push_error("patrol_parent_path is not set.")
		return false

	patrol_parent = get_node_or_null(patrol_parent_path)
	if patrol_parent == null:
		push_error("patrol_parent not found: " + str(patrol_parent_path))
		return false

	if patrol_parent.get_child_count() == 0:
		push_error("No patrol points under patrol_parent.")
		return false

	nav_agent.path_desired_distance = 0.1
	nav_agent.target_desired_distance = 0.2
	return true

func _bind_dialogue() -> void:
	detection_area.body_entered.connect(_on_Area3D_body_entered)
	detection_area.body_exited.connect(_on_Area3D_body_exited)

	if dialogue_box and dialogue_box.has_signal("dialogue_closed"):
		dialogue_box.dialogue_closed.connect(_on_dialogue_closed)

func _physics_process(delta):
	if dialogue_box.visible:
		face_player()
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if nav_agent.is_navigation_finished():
		if not is_choosing_next_point:
			await _choose_next_point()
		return

	var next_pos = nav_agent.get_next_path_position()
	var direction = next_pos - global_position
	var dist = direction.length()

	if dist > previous_distance - 0.05:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
	previous_distance = dist

	if stuck_timer > 2.0:
		DebugLog.info("NPC might be stuck, repathing")
		_go_to_forward_point()
		stuck_timer = 0.0
		return

	if dist > 0.05:
		direction = direction.normalized()
		_turn_towards(direction)
		if not was_moving:
			play_animation("Walk")
			was_moving = true
	else:
		if was_moving:
			play_animation("Idle")
			was_moving = false

	velocity = direction * speed
	move_and_slide()

func _choose_next_point() -> void:
	is_choosing_next_point = true
	if was_moving:
		play_animation("Idle")
		was_moving = false

	if randf() < 0.4:
		await get_tree().create_timer(randf_range(1.0, 2.0)).timeout

	_go_to_forward_point()
	is_choosing_next_point = false

func _turn_towards(direction: Vector3) -> void:
	var angle = atan2(-direction.x, -direction.z)
	var target_deg = rad_to_deg(angle)

	if abs(rotation_degrees.y - target_deg) > 2.0:
		turn_tween = create_tween()
		turn_tween.tween_property(self, "rotation_degrees:y", target_deg, 0.2) \
			.set_trans(Tween.TransitionType.TRANS_SINE) \
			.set_ease(Tween.EaseType.EASE_OUT)

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
		push_warning("No patrol points found at runtime.")
		return

	var forward := -transform.basis.z.normalized()
	var forward_candidates: Array[Node3D] = []

	for point in points:
		if point == last_point:
			continue

		var to_point = (point.global_position - global_position).normalized()
		if forward.dot(to_point) > 0.2 and global_position.distance_to(point.global_position) <= max_point_distance:
			forward_candidates.append(point)

	if forward_candidates.is_empty():
		forward_candidates = points.filter(func(p): return p != last_point)
	if forward_candidates.is_empty():
		forward_candidates = points

	var chosen_point = forward_candidates[randi() % forward_candidates.size()]
	last_point = chosen_point
	DebugLog.value("Moving forward to: ", chosen_point.name)
	nav_agent.target_position = chosen_point.global_position

func play_animation(name: String):
	if sprite_front.sprite_frames.has_animation(name):
		sprite_front.play(name)
		sprite_back.play(name)

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
	if not file:
		push_error("Failed to load dialogue file: " + dialogue_file_path)
		return

	var file_text := file.get_as_text()
	file.close()
	api_client.request("/npc/npc_intro", {"npc_background": file_text}, _on_npc_intro_response)

func _on_npc_intro_response(result: Dictionary) -> void:
	if not result["ok"]:
		DebugLog.value("NPC intro request failed: ", result["error"])
		text = get_fallback_text()
		return

	var data: Dictionary = result["data"]
	if data.has("status") and data["status"] == "success" and data.has("reply"):
		text = npc_name + "\n" + str(data["reply"])
	else:
		text = get_fallback_text()

func get_fallback_text() -> String:
	var display_name := npc_name.strip_edges()
	if display_name.is_empty():
		display_name = "NPC"
	return display_name + "\nChúc bạn ngày vui vẻ!"

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
	DebugLog.info("Dialogue closed; enter cooldown")
	GameData.dialogue_cooldown = true
	start_dialogue_cooldown()

func start_close_cooldown():
	await get_tree().create_timer(0.2).timeout
	just_closed = false
	DebugLog.info("Short cooldown ended")

func start_dialogue_cooldown():
	await get_tree().create_timer(1.0).timeout
	GameData.dialogue_cooldown = false
	DebugLog.info("Dialogue cooldown ended")

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
