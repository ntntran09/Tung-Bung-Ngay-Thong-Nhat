extends CharacterBody2D

@export var patrol_points: Array[Node2D] = []
@export var player_path: NodePath
@export var chase_speed := 200.0  # Tốc độ khi đuổi theo
@export var patrol_speed := 180.0  # Tốc độ khi tuần tra
@export var approach_speed := 130.0  # Tốc độ khi tiến gần player
@export var acceleration := 0.2  # Tăng tốc mượt mà hơn
@export var memory_time := 3.0  # Thời gian nhớ vị trí player sau khi mất dấu

@onready var player: Node2D = get_node_or_null(player_path)
@onready var sprite = $AnimatedSprite2D
@onready var vision_root = $VisionRoot
@onready var vision_area = $VisionRoot/VisionCone/Area2D
@onready var light = $PointLight2D
@onready var vision_cone_light = $PointLight2D  # Thêm tham chiếu đến đèn cone
@onready var countdown_label := get_node("../UI/CountdownLabel")
@onready var warning_sound = get_node("../WarningSound")  # Tham chiếu đến warning sound (đảm bảo đã thêm node này)
@onready var suspicious_icon := $SuspiciousIcon

enum State {PATROL, CHASE, SUSPICIOUS, SEARCH}

const CELL_SIZE = 64*3
const ROTATION_EPSILON = deg_to_rad(5)  # chỉ xoay VisionRoot nếu lệch trên 5 độ
const CLOSE_TO_PLAYER_DISTANCE = 180     # Khoảng cách để NPC khi gần player
const PATH_UPDATE_TIME = 2.0            # Cập nhật đường đi mỗi 2 giây

var astar_full_map := AStar2D.new()
var path := PackedVector2Array()
var current_path_index := 0
var speed := 100.0
var current_state = State.PATROL
var patrol_index := 0
var last_target_position := Vector2.ZERO  # Ghi nhớ vị trí player cũ khi đuổi
var last_known_position := Vector2.ZERO   # Vị trí cuối cùng thấy player
var chase_update_timer := Timer.new()
var memory_timer := Timer.new()
var reaction_timer := Timer.new()
var reaction_time := 0.3  # Thời gian để NPC phản ứng khi thấy player
var blink_timer := Timer.new()  # Timer cho hiệu ứng nháy đèn
var original_light_energy := 0.0  # Lưu giá trị năng lượng ban đầu của đèn
var check_proximity_timer := Timer.new()  # Timer kiểm tra khoảng cách
var countdown_timer := Timer.new()  # Timer để đếm ngược
var countdown_time := 3.0  # Thời gian đếm ngược 3 giây
var is_player_detected := false  # Trạng thái phát hiện player
var previous_position := Vector2.ZERO
var stuck_check_timer := Timer.new()

func _ready():
	if patrol_points.is_empty():
		push_warning("⚠️ Chưa gán patrol_points trong Inspector!")
		return

	if not player:
		push_warning("⚠️ Chưa gán player_path trong Inspector!")
		
	# Kiểm tra countdown_label
	if not countdown_label:
		push_warning("⚠️ Không tìm thấy countdown_label tại đường dẫn $UI/CountdownLabel!")
		
	if vision_area:
		# Thay đổi kết nối tín hiệu để sử dụng hàm chung _detect_player
		vision_area.connect("body_entered", _on_vision_body_entered)
		vision_area.connect("body_exited", _on_vision_body_exited)
	else:
		push_error("❌ Không tìm thấy Area2D trong VisionCone!")

	_generate_astar_full_map()
	_set_path_weights()
	
	stuck_check_timer.wait_time = 1.0
	stuck_check_timer.one_shot = false
	stuck_check_timer.timeout.connect(_check_if_stuck)
	add_child(stuck_check_timer)
	stuck_check_timer.start()
	
	# Thiết lập timer cập nhật đường đi
	chase_update_timer.wait_time = PATH_UPDATE_TIME
	chase_update_timer.autostart = false
	chase_update_timer.one_shot = false
	chase_update_timer.timeout.connect(_update_chase_path)
	add_child(chase_update_timer)
	
	# Thiết lập timer nhớ
	memory_timer.wait_time = memory_time
	memory_timer.one_shot = true
	add_child(memory_timer)
	
	# Thiết lập timer phản ứng
	reaction_timer.wait_time = reaction_time
	reaction_timer.one_shot = true
	add_child(reaction_timer)
	
	# Thiết lập timer cho hiệu ứng nháy đèn
	blink_timer.wait_time = 0.3  # Nháy mỗi 0.3 giây
	blink_timer.autostart = false
	blink_timer.one_shot = false
	blink_timer.timeout.connect(_blink_light)
	add_child(blink_timer)
	
	# Thiết lập timer để kiểm tra khoảng cách mỗi giây
	check_proximity_timer.wait_time = 1.0
	check_proximity_timer.autostart = true
	check_proximity_timer.one_shot = false
	check_proximity_timer.timeout.connect(_check_player_proximity)
	add_child(check_proximity_timer)
	
	# Thiết lập timer đếm ngược
	countdown_timer.wait_time = 1.0
	countdown_timer.one_shot = false
	countdown_timer.timeout.connect(_on_countdown_timer_tick)
	add_child(countdown_timer)

	if vision_cone_light:
		original_light_energy = vision_cone_light.energy
	
	# Ẩn label đếm ngược ban đầu
	if countdown_label:
		countdown_label.visible = false
	else:
		DebugLog.info("Không tìm thấy countdown_label!")
	
	_go_to_nearest_patrol_point()  # Bắt đầu với điểm tuần tra gần nhất
	
func _reverse_direction():
	if path.size() > 1:
		path.reverse()
		current_path_index = 0
	else:
		# Nếu không có path, đổi patrol_index
		patrol_index = (patrol_index + 1) % patrol_points.size()
		_set_path_to_target(patrol_points[patrol_index].global_position)
		DebugLog.value("Patrol index:", patrol_index)

func _check_if_stuck():
	var distance_moved = global_position.distance_to(previous_position)
	
	if distance_moved < 5.0 and velocity.length() > 0.1:
		DebugLog.info("NPC có vẻ bị kẹt -> xoay hướng")
		_reverse_direction()
	else:
		# cập nhật lại vị trí nếu di chuyển được
		previous_position = global_position

# Hàm chung để xử lý khi phát hiện player
func _detect_player():
	if not is_player_detected and _player_is_in_vision():
		is_player_detected = true
		DebugLog.info("Phát hiện player, bắt đầu reaction_timer")
		reaction_timer.start()
		await reaction_timer.timeout

		# Đảm bảo player vẫn còn trong vision khi timeout kết thúc
		if _player_is_in_vision():
			DebugLog.info("Player bị phát hiện hoàn toàn sau khi reaction_timer kết thúc")
			_start_countdown()
			_start_chase()
			_start_light_blinking()
		else:
			DebugLog.info("Player đã rời khỏi vùng tầm nhìn trước khi bị detect hoàn toàn")
			is_player_detected = false  # reset trạng thái


# Tách các hành động khi phát hiện thành các hàm riêng
func _start_chase():
	if current_state != State.CHASE:
		DebugLog.info("NPC phát hiện player -> bắt đầu đuổi")
		current_state = State.CHASE
		last_target_position = player.global_position
		last_known_position = player.global_position
		_set_path_to_target(player.global_position)
		chase_update_timer.start()

func _start_light_blinking():
	if vision_cone_light:
		DebugLog.info("Bắt đầu nháy đèn")
		vision_cone_light.energy = original_light_energy * 2  # Tăng độ sáng ban đầu
		blink_timer.start()

func _stop_light_blinking():
	if vision_cone_light:
		DebugLog.info("Dừng nháy đèn")
		vision_cone_light.energy = original_light_energy  # Khôi phục độ sáng ban đầu
		blink_timer.stop()

func _start_countdown():
	# Kiểm tra lại label và hiển thị nó
	if not countdown_label:
		DebugLog.info("Không thể hiển thị countdown: Label không tồn tại!")
		# Thử truy cập lại node
		countdown_label = get_node_or_null("UI/CountdownLabel")
		if not countdown_label:
			DebugLog.info("Vẫn không tìm thấy countdown_label!")
			return
	
	DebugLog.info("Bắt đầu đếm ngược")
	countdown_time = 3.0
	countdown_label.text = str(int(countdown_time))
	
	# Đảm bảo label hiển thị
	countdown_label.visible = true
	
	# Kiểm tra xem label có thực sự visible hay không
	await get_tree().process_frame
	
	countdown_timer.start()
	
	# Nếu có âm thanh cảnh báo, phát nó
	if warning_sound and warning_sound.has_method("play"):
		warning_sound.play()
		DebugLog.info("Đã phát âm thanh cảnh báo")

func _stop_countdown():
	if countdown_timer:
		countdown_timer.stop()
	if countdown_label:
		countdown_label.visible = false

func _blink_light():
	if vision_cone_light:
		# Đảo trạng thái đèn
		if vision_cone_light.energy > original_light_energy:
			vision_cone_light.energy = original_light_energy * 0.5  # Mờ hơn
		else:
			vision_cone_light.energy = original_light_energy * 2.0  # Sáng hơn

func _on_countdown_timer_tick():
	DebugLog.info("Countdown timer tick: " + str(countdown_time))
	
	if not _should_detect_player():
		DebugLog.info("Không còn phát hiện player -> dừng đếm ngược")
		_stop_countdown()
		is_player_detected = false
		return
	
	# Kiểm tra lại trạng thái của label
	if countdown_label and not countdown_label.visible:
		DebugLog.info("Label bị ẩn trong quá trình đếm ngược! Hiển thị lại.")
		countdown_label.visible = true
		
	countdown_time -= 1.0
	if countdown_time <= 0:
		countdown_timer.stop()
		if countdown_label:
			countdown_label.visible = false
		DebugLog.info("Game Over!")
		get_tree().change_scene_to_file(SceneRoutes.TRON_TIM_GAME_OVER)
	else:
		if countdown_label:
			countdown_label.text = str(int(countdown_time))
			DebugLog.info("Countdown còn lại: " + str(int(countdown_time)))

func _on_vision_body_entered(body):
	if body == player:
		DebugLog.info("Player đi vào tầm nhìn")
		if _should_detect_player():
			_detect_player()

func _on_vision_body_exited(body):
	if body == player and current_state == State.CHASE:
		DebugLog.info("Mất dấu player")
		
		# Dừng đếm ngược và chuyển sang trạng thái tìm kiếm
		_stop_countdown()
		is_player_detected = false
		
		current_state = State.SEARCH
		chase_update_timer.stop()
		
		# Đi đến vị trí cuối cùng thấy player
		_set_path_to_target(last_known_position)
		
		# Bắt đầu đếm thời gian nhớ
		memory_timer.start()
		
		DebugLog.info("Bắt đầu tìm kiếm")

# Hàm kiểm tra xem có nên phát hiện player không
func _should_detect_player() -> bool:
	if not player:
		return false
	
	var is_player_moving = _is_player_moving()
	var distance = global_position.distance_to(player.global_position)
	
	# Trong vùng nhìn thấy và đang di chuyển
	if is_player_moving and _player_is_in_vision():
		DebugLog.info("Player bị phát hiện")
		return true
	
	# Trong khoảng cách gần và đứng im
	if distance <= CLOSE_TO_PLAYER_DISTANCE:
		DebugLog.info("Player distance is so close")
		return true
	
	return false

# Hàm kiểm tra xem player có đang di chuyển không
func _is_player_moving() -> bool:
	if "velocity" in player:
		return player.velocity.length() > 0.1
	return player.has_method("get_is_moving") and player.get_is_moving()

func _update_chase_path():
	if current_state == State.CHASE and player:
		# Chỉ cập nhật đường đi nếu player đã di chuyển đủ xa
		if player.global_position.distance_to(last_target_position) > 10:
			var from_id = _get_closest_astar_id(astar_full_map, global_position)
			
			# Dự đoán vị trí player trong tương lai dựa trên hướng di chuyển (nếu có)
			var predicted_position = player.global_position
			if "velocity" in player and player.velocity.length() > 0:
				predicted_position += player.velocity.normalized() * 30
				
			var to_id = _get_closest_astar_id(astar_full_map, predicted_position)
			
			if from_id != -1 and to_id != -1:
				path = astar_full_map.get_point_path(from_id, to_id)
				_optimize_path()  # Tối ưu đường đi
				current_path_index = 0
				last_target_position = player.global_position
				DebugLog.info("Cập nhật đường đuổi")

func _go_to_nearest_patrol_point():
	if patrol_points.is_empty():
		return
		
	var nearest_id := 0
	var min_dist := INF
	for i in range(patrol_points.size()):
		var dist = global_position.distance_to(patrol_points[i].global_position)
		if dist < min_dist:
			min_dist = dist
			nearest_id = i
	patrol_index = nearest_id
	_set_path_to_target(patrol_points[patrol_index].global_position)
	DebugLog.info("Đi đến điểm tuần tra gần nhất: " + str(patrol_index))

func _physics_process(delta):
	if not player:
		return
	
	# Kiểm tra điều kiện phát hiện liên tục trong _physics_process
	if _should_detect_player() and not is_player_detected:
		_detect_player()
	
	# Cập nhật trạng thái và xử lý hành vi
	match current_state:
		State.PATROL:
			_handle_patrol(delta)
		State.CHASE:
			_handle_chase(delta)
		State.SUSPICIOUS:
			_handle_suspicious(delta)
		State.SEARCH:
			_handle_search(delta)
	
	queue_redraw()

func _handle_patrol(delta):
	var target_speed = patrol_speed
	speed = lerp(speed, target_speed, acceleration)
	
	_process_movement()
	
	# Nếu đã hoàn thành đường đi, chuyển đến điểm tuần tra tiếp theo
	if path.is_empty():
		_next_patrol()
	
	if 	current_state == State.SUSPICIOUS and suspicious_icon.visible:
		suspicious_icon.visible = false
		


func _handle_chase(delta):
	var distance_to_player = global_position.distance_to(player.global_position)
	var target_speed = chase_speed
	
	# Giảm tốc độ khi đến gần player
	if distance_to_player < CLOSE_TO_PLAYER_DISTANCE:
		target_speed = approach_speed
	
	speed = lerp(speed, target_speed, acceleration)
	
	# Kiểm tra tầm nhìn thẳng
	if _check_line_of_sight():
		# Cập nhật vị trí cuối được biết
		last_known_position = player.global_position
	
	_process_movement()

func _handle_suspicious(delta):
	# Di chuyển chậm và nhìn xung quanh khi nghi ngờ
	var target_speed = patrol_speed * 0.7
	speed = lerp(speed, target_speed, acceleration)
	
	# Xoay vision cone để tìm kiếm
	_rotate_vision_to_search(delta)
	
	_process_movement()
	
	# Kiểm tra nếu thấy player trong quá trình nghi ngờ
	if _should_detect_player():
		_detect_player()

func _handle_search(delta):
	var target_speed = patrol_speed * 0.8
	speed = lerp(speed, target_speed, acceleration)
	
	_process_movement()
	
	# Nếu đã đến vị trí cuối được biết và không tìm thấy player
	if path.is_empty():
		if not memory_timer.is_stopped():
			memory_timer.stop()
			
		current_state = State.SUSPICIOUS
		suspicious_icon.visible = true
		# Đợi một lúc trong trạng thái nghi ngờ rồi quay lại tuần tra
		await get_tree().create_timer(2.0).timeout
		if current_state == State.SUSPICIOUS:
			suspicious_icon.visible = false
			current_state = State.PATROL
			_stop_light_blinking()
			_go_to_nearest_patrol_point()

func _player_is_visible() -> bool:
	# Kiểm tra xem player có trong tầm nhìn không
	if vision_area and vision_area.get_overlapping_bodies().has(player):
		return _check_line_of_sight()
	return false

func _process_movement():
	if path.is_empty():
		velocity = Vector2.ZERO
		return
	
	if current_path_index < path.size():
		var target = path[current_path_index]
		var direction = (target - global_position).normalized()
		velocity = direction * speed
		
		# Cập nhật hoạt ảnh và xoay hướng nhìn
		if abs(direction.x) > abs(direction.y):
			sprite.play("walk_right" if direction.x > 0 else "walk_left")
		else:
			sprite.play("walk_down" if direction.y > 0 else "walk_up")

		# Xoay VisionRoot và đèn theo hướng di chuyển
		if velocity.length() > 0.1:
			var desired_angle = direction.angle() + deg_to_rad(180)  # nếu cần xoay ngược
			if abs(vision_root.rotation - desired_angle) > ROTATION_EPSILON:
				vision_root.rotation = lerp_angle(vision_root.rotation, desired_angle, 0.1)
				light.position = Vector2.ZERO  # nằm đúng giữa NPC
				light.rotation = vision_root.rotation

		move_and_slide()

		# Kiểm tra nếu đã đến điểm tiếp theo
		if global_position.distance_to(target) < 5:
			current_path_index += 1
			if current_path_index >= path.size():
				path.clear()

func _rotate_vision_to_search(delta):
	# Xoay vision cone để tìm kiếm xung quanh
	vision_root.rotation += delta * 2.0  # Xoay 2 radian/giây
	light.rotation = vision_root.rotation

func _generate_astar_full_map():
	var id := 0
	var occupied = {}
	
	# Tạo lưới điểm đồng đều
	for y in range(-10, 11):
		for x in range(-10, 11):
			var pos = Vector2(x, y) * CELL_SIZE + Vector2(CELL_SIZE/2, CELL_SIZE/2)
			if _is_position_blocked(pos):
				continue
			astar_full_map.add_point(id, pos)
			occupied[Vector2i(x, y)] = id
			id += 1
	
	# Kết nối các điểm lân cận
	for pos in occupied.keys():
		var center_id = occupied[pos]
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
			Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(1,1)]:
			var neighbor = pos + offset
			if occupied.has(neighbor):
				astar_full_map.connect_points(center_id, occupied[neighbor])

func _set_path_weights():
	# Thiết lập trọng số cho các đường đi 
	for id in astar_full_map.get_point_ids():
		var pos = astar_full_map.get_point_position(id)
		# Các điểm gần tường sẽ có trọng số cao hơn
		if _is_near_wall(pos):
			astar_full_map.set_point_weight_scale(id, 2.0)

func _is_near_wall(pos: Vector2) -> bool:
	# Kiểm tra xem điểm có gần tường không
	var space_state = get_world_2d().direct_space_state
	
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var query := PhysicsRayQueryParameters2D.new()
		query.from = pos
		query.to = pos + dir * 20  # Kiểm tra trong phạm vi 20px
		query.exclude = [self, player] if player else [self]
		
		var result = space_state.intersect_ray(query)
		if not result.is_empty():
			return true
	
	return false

func _is_position_blocked(pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var result = space_state.intersect_point(query)
	
	for collision in result:
		var collider = collision["collider"]
		# Bỏ qua va chạm với Area2D của chính NPC
		if collider == vision_area or collider == self:
			continue
		# Bỏ qua va chạm với player
		if collider == player:
			continue
		return true
		
	return false

# Thống nhất một phương thức để thiết lập đường đi
func _set_path_to_target(target: Vector2):
	# Nếu là điểm tuần tra, đi thẳng đến đó
	if current_state == State.PATROL:
		path.clear()
		path.append(target)
		current_path_index = 0
	# Nếu đang đuổi hoặc tìm kiếm, sử dụng AStar
	else:
		var from_id = _get_closest_astar_id(astar_full_map, global_position)
		var to_id = _get_closest_astar_id(astar_full_map, target)
		
		if from_id != -1 and to_id != -1:
			path = astar_full_map.get_point_path(from_id, to_id)
			_optimize_path()
			current_path_index = 0

func _optimize_path():
	# Giảm số điểm trong đường đi để di chuyển mượt hơn
	if path.size() > 3:
		var simplified_path = PackedVector2Array()
		simplified_path.append(path[0])
		
		for i in range(1, path.size() - 1):
			# Kiểm tra xem có thể bỏ qua điểm này không
			if not _can_move_directly(path[i-1], path[i+1]):
				simplified_path.append(path[i])
				
		simplified_path.append(path[path.size()-1])
		path = simplified_path

func _can_move_directly(from_pos: Vector2, to_pos: Vector2) -> bool:
	# Kiểm tra xem có thể di chuyển trực tiếp từ điểm này đến điểm kia không
	var space_state = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.new()
	query.from = from_pos
	query.to = to_pos
	query.exclude = [self, player] if player else [self]
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func _get_closest_astar_id(astar: AStar2D, pos: Vector2) -> int:
	var closest_id = -1
	var min_dist = INF
	
	for id in astar.get_point_ids():
		var dist = astar.get_point_position(id).distance_to(pos)
		if dist < min_dist:
			min_dist = dist
			closest_id = id
			
	return closest_id

func _next_patrol():
	if patrol_points.is_empty():
		return
		
	patrol_index = (patrol_index + 1) % patrol_points.size()
	_set_path_to_target(patrol_points[patrol_index].global_position)
	DebugLog.info("Đi đến điểm tuần tra tiếp theo: " + str(patrol_index))

func _check_line_of_sight() -> bool:
	# Kiểm tra xem có vật cản giữa NPC và player không
	if not player:
		return false
			
	var space_state = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.new()
	query.from = global_position
	query.to = player.global_position
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	return result.is_empty() or (not result.is_empty() and result["collider"] == player)

func _player_is_in_vision() -> bool:
	if vision_area and player:
		return vision_area.get_overlapping_bodies().has(player)
	return false

func _check_player_proximity():
	if not player:
		return
		
	if _should_detect_player() and not is_player_detected:
		DebugLog.info("Điều kiện phát hiện thoả mãn -> Bắt đầu truy đuổi")
		_detect_player()

#func _draw():
	## Vẽ đường đi để debug
	#if path.size() > 1:
		#for i in range(path.size() - 1):
			#draw_line(to_local(path[i]), to_local(path[i+1]), Color.YELLOW, 2)
#
	## Vẽ các điểm tuần tra
	#for p in patrol_points:
		#draw_circle(to_local(p.global_position), 5, Color.RED)
		#
	## Vẽ vị trí cuối cùng thấy player (nếu đang tìm kiếm)
	#if current_state == State.SEARCH:
		#draw_circle(to_local(last_known_position), 8, Color.ORANGE)
