# File: Main.gd
extends Node

const GRID_SIZE = 4
const TILE_SIZE = 64

const PIECE_LUA = preload("res://CO_GANH/assets/sprites/sun.png")
const PIECE_NUOC = preload("res://CO_GANH/assets/sprites/mon.png")
const PIECE_SCENE = preload("res://CO_GANH/scenes/Piece.tscn")

const DOT_RED = preload("res://CO_GANH/assets/sprites/red_dot.png")
const DOT_BLUE = preload("res://CO_GANH/assets/sprites/blue_dot.png")

const BOT_AVATAR_POSITION := Vector2(1510, 250)
const BOT_NAME_LABEL_OFFSET := Vector2(-70, 120)
const BOT_DEFAULT_AVATAR_PATH := "res://CO_GANH/assets/sprites/default_avatar.png"
const BOT_AVATAR_PATHS := {
	1: "res://CO_GANH/assets/sprites/ava1.png",
	2: "res://CO_GANH/assets/sprites/ava2.png",
	3: "res://CO_GANH/assets/sprites/av4.png",
	4: "res://CO_GANH/assets/sprites/ava5.png",
	5: "res://CO_GANH/assets/sprites/ava3.png",
}
const BOT_NAMES := {
	1: "Lam",
	2: "Mai",
	3: "Hoang",
	4: "Nghi",
	5: "Tran",
}
const LOSS_MAIN_BUTTON_TEXTURE_RECT := Rect2(380, 520, 780, 190)
const LOSS_RETRY_BUTTON_TEXTURE_RECT := Rect2(480, 752, 580, 184)
const WIN_MAIN_BUTTON_TEXTURE_RECT := Rect2(342, 515, 720, 174)
const WIN_NEXT_BUTTON_TEXTURE_RECT := Rect2(374, 730, 686, 190)

var current_turn := "Lua"
var selected_piece: Area2D = null
var selected_moves: Array[Vector2i] = []
var is_game_over := false
var turn_generation := 0

@onready var move_hints: Node2D = $main/move_hint
@onready var tile_map: TileMapLayer = $main/Board
@onready var pieces: Node2D = $main/Pieces
@onready var moved_dot: Node2D = $main/moved_dot
@onready var win_game_over_bg: TextureRect = $GameOver_win/BG
@onready var win_next_button: Button = $GameOver_win/BG/BotSelectButton
@onready var win_main_button: Button = $GameOver_win/BG/mhchinh
@onready var loss_game_over_bg: TextureRect = $GameOver_loss/BG
@onready var loss_retry_button: Button = $GameOver_loss/BG/choilai
@onready var loss_main_button: Button = $GameOver_loss/BG/mhchinh
@export var board_start_position: Vector2 = Vector2(50, 30)


var bot_avatar = Sprite2D.new()
var name_label = Label.new()
var cur_level 

#audio
@onready var sfx_click = $main/Audio/click
@onready var sfx_move = $main/Audio/move
@onready var sfx_ganh = $main/Audio/ganh
@onready var sfx_vay = $main/Audio/vay
@onready var sfx_win = $main/Audio/win
@onready var sfx_loss = $main/Audio/loss
@onready var bot_select = $main/Audio/botselect

@onready var bot_select_layer = $BotSelectLayer
var Bot = preload("res://CO_GANH/scripts/bot_logic.gd").new()

var lua_one_piece_streak := 0
var nuoc_one_piece_streak := 0

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	bot_select.play()
	hide_game_over_panels()
	$main/Board.visible = false
	$main/Pieces.visible = false
	$main/move_hint.visible = false
	$main/moved_dot.visible = false
	$ColorRect.visible = false
	$Player.visible = false
	$Point.visible = false
	$CanvasLayer.visible = true 
	
	bot_select_layer.bot_selected.connect(_on_bot_selected)
	
	$main.position = board_start_position
	build_valid_moves()
	draw_board()
	get_viewport().size_changed.connect(_update_game_over_button_layouts)
	call_deferred("_update_game_over_button_layouts")

func hide_game_over_panels() -> void:
	$GameOver_win.visible = false
	$GameOver_win/BG.visible = false
	$GameOver_loss.visible = false
	$GameOver_loss/BG.visible = false

func show_win_panel() -> void:
	_update_game_over_button_layouts()
	$GameOver_win.visible = true
	$GameOver_win/BG.visible = true

func show_loss_panel() -> void:
	_update_game_over_button_layouts()
	$GameOver_loss.visible = true
	$GameOver_loss/BG.visible = true

func _update_game_over_button_layouts() -> void:
	_place_button_on_texture(win_game_over_bg, win_main_button, WIN_MAIN_BUTTON_TEXTURE_RECT)
	_place_button_on_texture(win_game_over_bg, win_next_button, WIN_NEXT_BUTTON_TEXTURE_RECT)
	_place_button_on_texture(loss_game_over_bg, loss_main_button, LOSS_MAIN_BUTTON_TEXTURE_RECT)
	_place_button_on_texture(loss_game_over_bg, loss_retry_button, LOSS_RETRY_BUTTON_TEXTURE_RECT)

func _place_button_on_texture(background: TextureRect, button: Control, texture_rect: Rect2) -> void:
	if background == null or button == null or background.texture == null:
		return

	var texture_size := background.texture.get_size()
	if texture_size.x <= 0 or texture_size.y <= 0 or background.size.x <= 0 or background.size.y <= 0:
		return

	var scale: float = max(background.size.x / texture_size.x, background.size.y / texture_size.y)
	var rendered_texture_size := texture_size * scale
	var rendered_texture_offset := (background.size - rendered_texture_size) * 0.5
	button.position = rendered_texture_offset + texture_rect.position * scale
	button.size = texture_rect.size * scale

func _on_bot_selected(level: int):
	DebugLog.value("Bắt đầu game với bot cấp:", level)

	# Gán level cho bot_logic
	Bot.difficulty_level = level
	cur_level = level
	# Ẩn màn chọn bot
	bot_select_layer.visible = false
	bot_select.stop()
	# Hiện bàn cờ
	$main/Board.visible = true
	$main/BG.visible = true
	$main/Pieces.visible = true
	$main/move_hint.visible = true
	$main/moved_dot.visible = true
	$ColorRect.visible = true
	$Player.visible = true
	$Point.visible = true
	# Gọi khởi tạo quân cờ nếu có
	if has_method("spawn_initial_pieces"):
		spawn_initial_pieces()
	show_bot_info(level)
	
func show_bot_info(level: int):
	# Nếu đã có thì xóa avatar và label cũ
	if bot_avatar.get_parent():
		bot_avatar.queue_free()
	bot_avatar = Sprite2D.new()

	if name_label.get_parent():
		name_label.queue_free()
	name_label = Label.new()

	# Tạo avatar mới
	var avatar_path: String = BOT_AVATAR_PATHS.get(level, BOT_DEFAULT_AVATAR_PATH)

	bot_avatar.texture = load(avatar_path)
	bot_avatar.scale = Vector2(2.6, 2.6)
	bot_avatar.position = BOT_AVATAR_POSITION
	add_child(bot_avatar)

	# Label tên bot
	var name = BOT_NAMES.get(level, "Unknown")
	name_label.text = name + " (Level " + str(level) + ")"
	name_label.set("theme_override_colors/font_color", Color.BLACK)
	name_label.set("theme_override_font_sizes/font_size", 36)
	var custom_font = preload("res://_SHARED ASSETS/font/SVN-Retron 2000.otf")
	name_label.set("theme_override_fonts/font", custom_font)

	add_child(name_label)
	name_label.position = BOT_AVATAR_POSITION + BOT_NAME_LABEL_OFFSET


func draw_board():
	for i in range(GRID_SIZE):
		for j in range(GRID_SIZE):
			var atlas_coords = Vector2i(0, 0)
			if (i + j) % 2 != 0:
				atlas_coords = Vector2i(1, 0)
			tile_map.set_cell(Vector2i(i, j), 14, atlas_coords)  # ✅ Cập nhật chuẩn Godot 4.3

func spawn_initial_pieces():
	for j in range(GRID_SIZE + 1):
		spawn_piece(PIECE_NUOC, Vector2i(0, j), "Nuoc")  # Người chơi ở phía trên
		spawn_piece(PIECE_LUA, Vector2i(4, j), "Lua")     # Bot ở phía dưới

	spawn_piece(PIECE_LUA, Vector2i(3, 0), "Lua")
	spawn_piece(PIECE_LUA, Vector2i(2, 0), "Lua")
	spawn_piece(PIECE_NUOC, Vector2i(1, 0), "Nuoc")
	spawn_piece(PIECE_LUA, Vector2i(3, 4), "Lua")
	spawn_piece(PIECE_NUOC, Vector2i(2, 4), "Nuoc")
	spawn_piece(PIECE_NUOC, Vector2i(1, 4), "Nuoc")

	clear_all_highlights()


func spawn_piece(texture: Texture2D, grid_point: Vector2i, phe: String):
	var piece = PIECE_SCENE.instantiate()
	piece.phe = phe
	piece.position_on_grid = grid_point
	piece.get_node("Sprite2D").texture = texture
	piece.position = Vector2(grid_point.y * TILE_SIZE, grid_point.x * TILE_SIZE)
	piece.connect("input_event", Callable(self, "_on_piece_clicked").bind(piece))
	pieces.add_child(piece)

func _on_piece_clicked(viewport, event, shape_idx, piece):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_game_over:
			return
		sfx_click.play()
		if piece.phe != current_turn:
			return
		
		# Bỏ chọn quân cũ nếu chọn lại
		if selected_piece and selected_piece != piece:
			selected_piece.get_node("Sprite2D").modulate = Color(1, 1, 1)

		# Cập nhật lại chọn mới
		selected_piece = piece
		selected_piece.get_node("Sprite2D").modulate = Color(1.5, 1.5, 1.5)
		
		# Hiện lại các nước đi
		show_valid_moves(piece)



func _on_hint_clicked(viewport, event, shape_idx, dot):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_game_over:
			return
		var target = dot.get_meta("target_pos") as Vector2i
		if selected_piece != null and selected_moves.has(target):
			var moved_piece := selected_piece
			var game_ended := apply_move(moved_piece, target)
			if is_instance_valid(moved_piece):
				moved_piece.get_node("Sprite2D").modulate = Color(1, 1, 1)
			selected_piece = null
			selected_moves.clear()
			clear_move_hints()
			if game_ended:
				return
			current_turn = "Nuoc"
			var expected_turn_generation := turn_generation
			await get_tree().create_timer(0.5).timeout
			call_bot_turn(expected_turn_generation)

func apply_move(piece: Area2D, to_pos: Vector2i) -> bool:
	sfx_move.play()
	var from_pos = piece.position_on_grid
	clear_all_highlights()
	show_previous_position_dot(from_pos)
	move_piece_to(piece, to_pos)
	highlight_piece(piece)
	check_ganh(to_pos, piece.phe)
	check_vay(piece.phe)
	return check_game_over()


func call_bot_turn(expected_turn_generation: int) -> void:
	if is_game_over or expected_turn_generation != turn_generation:
		return

	var board_data = extract_board_data()
	var move = Bot.get_best_move(board_data, valid_moves, "Nuoc")
	DebugLog.value("Bot chọn nước đi:", move)
	if move.has("from") and move.has("to"):
		var piece = get_piece_at(move["from"])
		if piece:
			var game_ended := apply_move(piece, move["to"])
			if game_ended:
				return
		if expected_turn_generation == turn_generation and not is_game_over:
			current_turn = "Lua"
	else:
		if expected_turn_generation == turn_generation and not is_game_over:
			current_turn = "Lua"
		DebugLog.info("Bot không tìm thấy nước đi nào")

func extract_board_data() -> Array:
	var board := []
	for piece in pieces.get_children():
		board.append({"pos": piece.position_on_grid, "phe": piece.phe})
	return board

func build_valid_moves():
	valid_moves = {}
	for x in range(5):
		for y in range(5):
			var pos = Vector2i(x, y)
			valid_moves[pos] = []
			var directions = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
			for dir in directions:
				var target = pos + dir
				if target.x >= 0 and target.x < 5 and target.y >= 0 and target.y < 5:
					valid_moves[pos].append(target)
	var edges = [
		[[0, 0], [1, 1]], [[1, 1], [2, 2]], [[2, 2], [3, 3]], [[3, 3], [4, 4]],
		[[0, 4], [1, 3]], [[1, 3], [2, 2]], [[2, 2], [3, 1]], [[3, 1], [4, 0]],
		[[0, 2], [1, 1]], [[0, 2], [1, 3]], [[1, 1], [2, 0]], [[2, 0], [3, 1]],
		[[3, 1], [4, 2]], [[4, 2], [3, 3]], [[3, 3], [2, 4]], [[2, 4], [1, 3]]
	]
	for pair in edges:
		var a = Vector2i(pair[0][0], pair[0][1])
		var b = Vector2i(pair[1][0], pair[1][1])
		if a in valid_moves:
			valid_moves[a].append(b)
		if b in valid_moves:
			valid_moves[b].append(a)

func show_valid_moves(piece):
	clear_move_hints()
	selected_moves.clear()
	var pos = piece.position_on_grid
	if not valid_moves.has(pos): return
	for target in valid_moves[pos]:
		if is_cell_empty(target):
			spawn_hint_dot(target, piece.phe)
			selected_moves.append(target)

func move_piece_to(piece, target: Vector2i):
	piece.position_on_grid = target
	piece.position = Vector2(target.y * TILE_SIZE, target.x * TILE_SIZE)

func check_ganh(center: Vector2i, phe: String):
	var opposite = ""
	if phe == "Lua":
		opposite = "Nuoc"
	else:
		opposite = "Lua"

	var dirs = [Vector2i(0,1), Vector2i(1,0), Vector2i(1,1), Vector2i(1,-1)]
	for dir in dirs:
		var l = center - dir
		var r = center + dir
		if not (valid_moves.has(l) and valid_moves[l].has(center) and valid_moves.has(r) and valid_moves[r].has(center)):
			continue
		var pl = get_piece_at(l)
		var pr = get_piece_at(r)
		if pl != null and pr != null and pl.phe == opposite and pr.phe == opposite:
			convert_piece(pl, phe)
			convert_piece(pr, phe)

func check_vay(phe_di: String):
	var phe_bi_vay = ""
	if phe_di == "Lua":
		phe_bi_vay = "Nuoc"
	else:
		phe_bi_vay = "Lua"

	for piece in pieces.get_children():
		if piece.phe != phe_bi_vay: continue
		var pos = piece.position_on_grid
		var neighbors = valid_moves.get(pos, [])
		var has_escape = false
		var count_enemy = 0
		var count_friend = 0
		for n in neighbors:
			if is_cell_empty(n):
				has_escape = true
				break
			var other = get_piece_at(n)
			if other == null: continue
			if other.phe == phe_bi_vay:
				count_friend += 1
			elif other.phe == phe_di:
				count_enemy += 1
		if not has_escape and count_enemy > count_friend:
			convert_piece(piece, phe_di)

func convert_piece(piece: Area2D, new_phe: String):
	sfx_ganh.play()
	if new_phe == "Lua":
		piece.get_node("Sprite2D").texture = PIECE_LUA
	else:
		piece.get_node("Sprite2D").texture = PIECE_NUOC
	piece.phe = new_phe

	piece.phe = new_phe

func get_piece_at(pos: Vector2i) -> Area2D:
	for piece in pieces.get_children():
		if piece.position_on_grid == pos:
			return piece
	return null

func is_cell_empty(pos: Vector2i) -> bool:
	return get_piece_at(pos) == null

func spawn_hint_dot(pos: Vector2i, phe: String):
	var dot = Area2D.new()
	var sprite = Sprite2D.new()
	if phe == "Lua":
		sprite.texture = DOT_RED
	else:
		sprite.texture = DOT_BLUE

	sprite.centered = true
	sprite.scale = Vector2(0.5, 0.5)
	dot.add_child(sprite)
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(32, 32)
	shape.shape = rect
	dot.add_child(shape)
	dot.position = Vector2(pos.y * TILE_SIZE, pos.x * TILE_SIZE)
	dot.set_meta("target_pos", pos)
	dot.connect("input_event", Callable(self, "_on_hint_clicked").bind(dot))
	move_hints.add_child(dot)

func clear_move_hints():
	for hint in move_hints.get_children():
		hint.queue_free()

var valid_moves := {}

func _finish_game(winner: String) -> void:
	is_game_over = true
	turn_generation += 1
	selected_piece = null
	selected_moves.clear()
	clear_move_hints()
	if winner == "Lua":
		sfx_win.play()
		show_win_panel()
	else:
		sfx_loss.play()
		show_loss_panel()
	
func check_game_over() -> bool:
	if is_game_over:
		return true

	var lua_count = 0
	var nuoc_count = 0
	var lua_moves = 0
	var nuoc_moves = 0

	for piece in pieces.get_children():
		if piece.phe == "Lua":
			lua_count += 1
			var pos = piece.position_on_grid
			for move in valid_moves.get(pos, []):
				if is_cell_empty(move):
					lua_moves += 1
		elif piece.phe == "Nuoc":
			nuoc_count += 1
			var pos = piece.position_on_grid
			for move in valid_moves.get(pos, []):
				if is_cell_empty(move):
					nuoc_moves += 1

	# 👉 Check nếu chỉ còn đúng 1 quân trong 10 lượt liên tiếp
	if lua_count == 1:
		lua_one_piece_streak += 1
	else:
		lua_one_piece_streak = 0

	if nuoc_count == 1:
		nuoc_one_piece_streak += 1
	else:
		nuoc_one_piece_streak = 0

	if lua_one_piece_streak >= 16:
		DebugLog.info("Player chỉ còn 1 quân trong 8 lượt liên tiếp - kết thúc game")
		_finish_game("Nuoc")
		return true
	elif nuoc_one_piece_streak >= 10:
		DebugLog.info("Bot chỉ còn 1 quân trong 8 lượt liên tiếp - kết thúc game")
		_finish_game("Lua")
		return true

	# 👉 Điều kiện thắng thông thường
	var winner = ""
	if lua_count == 0 or lua_moves == 0:
		winner = "Nuoc"
	elif nuoc_count == 0 or nuoc_moves == 0:
		winner = "Lua"

	if winner != "":
		DebugLog.value("Bên thắng:", winner)
		_finish_game(winner)
		return true

	return false

func board_to_pixel_position(pos: Vector2i) -> Vector2:
	return Vector2(pos.y * TILE_SIZE, pos.x * TILE_SIZE)

func show_previous_position_dot(prev_pos: Vector2i):
	for child in moved_dot.get_children():
		child.queue_free()  # xoá tất cả dot cũ
	
	var dot = Sprite2D.new()
	dot.texture = DOT_BLUE
	dot.position = board_to_pixel_position(prev_pos)
	dot.z_index = 2
	moved_dot.add_child(dot)


func highlight_piece(piece: Area2D):
	var highlight = piece.get_node("HighlightSprite")
	if highlight:
		highlight.visible = true



func clear_all_highlights():
	for piece in pieces.get_children():
		if piece.has_node("HighlightSprite"):
			piece.get_node("HighlightSprite").visible = false
		piece.get_node("Sprite2D").modulate = Color(1, 1, 1)



func _on_restart_pressed():
	reset_game()

func reset_game():
	turn_generation += 1
	is_game_over = false
	lua_one_piece_streak = 0
	nuoc_one_piece_streak = 0
	hide_game_over_panels()
	_clear_board_runtime_state()
	spawn_initial_pieces()

func _clear_board_runtime_state() -> void:
	_remove_children_now(moved_dot)
	_remove_children_now(move_hints)
	_remove_children_now(pieces)
	selected_piece = null
	selected_moves.clear()
	current_turn = "Lua"

func _remove_children_now(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()



func _on_bot_select_button_pressed():
	DebugLog.info("Replay with stronger bot")

	var new_level = Bot.difficulty_level + 1
	if new_level > 5:
		new_level = 5

	Bot.difficulty_level = new_level
	cur_level = new_level
	show_bot_info(new_level)
	reset_game()


func _on_choilai_pressed() -> void:
	reset_game()
	
func _on_mhchinh_pressed():
	get_tree().change_scene_to_file(SceneRoutes.MAIN_HUB)
