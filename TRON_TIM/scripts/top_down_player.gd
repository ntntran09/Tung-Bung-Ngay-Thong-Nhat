extends CharacterBody2D

@export var speed := 150.0
@export var use_footstep_sound := true

@onready var sprite := $AnimatedSprite2D
@onready var footstep_sound: AudioStreamPlayer2D = get_node_or_null("FootstepSound")

func _physics_process(delta):
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("walk_right") - Input.get_action_strength("walk_left")
	input_vector.y = Input.get_action_strength("walk_down") - Input.get_action_strength("walk_up")
	input_vector = input_vector.normalized()

	velocity = input_vector * speed
	move_and_slide()
	_update_animation(input_vector)
	_update_footsteps(input_vector)

func _update_animation(input_vector: Vector2) -> void:
	if input_vector == Vector2.ZERO:
		sprite.stop()
		return

	if abs(input_vector.x) > abs(input_vector.y):
		sprite.play("walk_right" if input_vector.x > 0 else "walk_left")
	else:
		sprite.play("walk_down" if input_vector.y > 0 else "walk_up")

func _update_footsteps(input_vector: Vector2) -> void:
	if not use_footstep_sound or footstep_sound == null:
		return

	if input_vector != Vector2.ZERO:
		if not footstep_sound.playing:
			footstep_sound.play()
	else:
		footstep_sound.stop()
