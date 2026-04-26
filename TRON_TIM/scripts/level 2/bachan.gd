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
#@onready var warning_sound = $"../WarningSound"  

enum State {PATROL, CHASE, SUSPICIOUS, SEARCH}

const CELL_SIZE = 64*3
const ROTATION_EPSILON = deg_to_rad(5)  # chỉ xoay VisionRoot nếu lệch trên 5 độ
const CLOSE_TO_PLAYER_DISTANCE = 200     # Khoảng cách để NPC đứng yên khi gần player
const PATH_UPDATE_TIME = 2.0           # Cập nhật đường đi mỗi 2 giây

var astar_full_map := AStar2D.new()
var path := PackedVector2Array()
var current_path_index := 0
var speed := 80.0
var current_state = State.PATROL
var patrol_index := 0
var last_target_position := Vector2.ZERO  # Ghi nhớ vị trí player cũ khi đuổi
var last_known_position := Vector2.ZERO   # Vị trí cuối cùng thấy player
var chase_update_timer := Timer.new()
var memory_timer := Timer.new()
var reaction_timer := Timer.new()
var reaction_time := 1.0  # Thời gian để NPC phản ứng khi thấy player
var previous_position := Vector2.ZERO
var stuck_check_timer := Timer.new()

func _ready():
	if patrol_points.is_empty():
		push_warning("⚠️ Chưa gán patrol_points trong Inspector!")
		return

	if not player:
		push_warning("⚠️ Chưa gán player_path trong Inspector!")
		
	if vision_area:
		# Chỉ kết nối một signal và một hàm xử lý
		vision_area.connect("body_entered", Callable(self, "_on_body_entered"))
		vision_area.connect("body_exited", Callable(self, "_on_body_exited"))
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
	
	_go_to_nearest_patrol_point()  # Bắt đầu với điểm tuần tra gần nhất

func _reverse_direction():
	if path.size() > 1:
		path.reverse()
		current_path_index = 0
	else:
		# Nếu không có path, đổi patrol_index
		patrol_index = (patrol_index + 1) % patrol_points.size()
		_set_path_to_target(patrol_points[patrol_index].global_position)

func _check_if_stuck():
	var distance_moved = global_position.distance_to(previous_position)
	
	if distance_moved < 5.0 and velocity.length() > 0.1:
		DebugLog.info("NPC có vẻ bị kẹt -> xoay hướng")
		_reverse_direction()
	else:
		# cập nhật lại vị trí nếu di chuyển được
		previous_position = global_position

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
	
	# Nếu thấy player, chuyển sang trạng thái đuổi
	if vision_area.get_overlapping_bodies().has(player):
		current_state = State.CHASE
		_set_path_to_target(player.global_position)
		chase_update_timer.start()

func _handle_search(delta):
	var target_speed = patrol_speed * 0.8
	speed = lerp(speed, target_speed, acceleration)
	
	_process_movement()
	
	# Nếu đã đến vị trí cuối được biết và không tìm thấy player
	if path.is_empty():
		if not memory_timer.is_stopped():
			memory_timer.stop()
			
		current_state = State.SUSPICIOUS
		# Đợi một lúc trong trạng thái nghi ngờ rồi quay lại tuần tra
		await get_tree().create_timer(2.0).timeout
		if current_state == State.SUSPICIOUS:
			current_state = State.PATROL
			_go_to_nearest_patrol_point()

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

		# Xoay VisionRoot theo hướng di chuyển
		if velocity.length() > 0.1:
			var desired_angle = direction.angle() + deg_to_rad(180)  # nếu cần xoay ngược
			if abs(vision_root.rotation - desired_angle) > ROTATION_EPSILON:
				vision_root.rotation = lerp_angle(vision_root.rotation, desired_angle, 0.1)

		move_and_slide()

		# Kiểm tra nếu đã đến điểm tiếp theo
		if global_position.distance_to(target) < 2:
			current_path_index += 1
			if current_path_index >= path.size():
				path.clear()

func _rotate_vision_to_search(delta):
	# Xoay vision cone để tìm kiếm xung quanh
	vision_root.rotation += delta * 2.0  # Xoay 2 radian/giây
	
	# Hoặc xoay qua lại trong góc nhìn
	# var time = Time.get_ticks_msec() / 1000.0
	# vision_root.rotation = sin(time * 1.5) * deg_to_rad(60)  # Xoay qua lại 60 độ

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

func _on_body_entered(body: Node2D) -> void:
	if body == player and current_state != State.CHASE:
		# Thêm độ trễ phản ứng để tự nhiên hơn 
		reaction_timer.start()
		await reaction_timer.timeout
		
		DebugLog.info("Bắt đầu đuổi theo player")
		#warning_sound.play()
		
		current_state = State.CHASE
		last_target_position = player.global_position
		last_known_position = player.global_position
		
		# Thiết lập đường đi đến player và bắt đầu timer
		_set_path_to_target(player.global_position)
		chase_update_timer.start()

func _on_body_exited(body: Node2D):
	if _check_line_of_sight():
		return  # Không thật sự mất dấu
	
	if body == player and current_state == State.CHASE:
		DebugLog.info("Mất dấu player")
		#warning_sound.stop()
		
		# Chuyển sang trạng thái tìm kiếm
		current_state = State.SEARCH
		chase_update_timer.stop()
		
		# Đi đến vị trí cuối cùng thấy player
		_set_path_to_target(last_known_position)
		
		# Bắt đầu đếm thời gian nhớ
		memory_timer.start()
		
		DebugLog.info("Bắt đầu tìm kiếm")

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
