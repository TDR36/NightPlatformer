extends CharacterBody2D

@export var speed = 300
@export var gravity = 30
@export var jump_force = 700

@onready var ap = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var cshape = $CollisionShape2D
@onready var crouch_raycast_1 = $crouch_raycast_1
@onready var crouch_raycast_2 = $crouch_raycast_2
@onready var coyote_timer = $CoyoteTimer
@onready var jump_buffer_timer = $JumpBufferTime
@onready var jump_height_timer = $JumpHightTimer
@onready var attack_timer = $attackTimer
@onready var attack_zone = $attackArea

var is_crouching = false
var stuck_under_object = false
var can_coyote_jump = false
var jump_beffered = false
var current_attack = false

var player_position = "stand"

var standing_cshape = preload("res://Ressources/standing_night_cshape.tres")
var crouching_cshape = preload("res://Ressources/crouching_night_cshape.tres")


func _ready():
	attack_timer.one_shot = true


#####################################################################
# Mouvements
#####################################################################

func stand():
	if is_crouching == false:
		return
	is_crouching = false
	cshape.shape = standing_cshape
	cshape.position.y = -19

func crouch():
	if is_crouching:
		return
	is_crouching = true
	cshape.shape = crouching_cshape
	cshape.position.y = -13.5

func jump():
	if is_on_floor() || can_coyote_jump:
		if not Input.is_action_pressed("crouch"):
			if above_head_is_empty():
				velocity.y = -jump_force
			else:
				velocity.y = -10
		else:
			velocity.y = -200
		if can_coyote_jump:
			can_coyote_jump = false
	else:
		if not jump_beffered:
			jump_beffered = true
			jump_buffer_timer.start()

func horizontal_move(horizontal_direction):
	if not Input.is_action_pressed("crouch"):
		velocity.x = speed * horizontal_direction
	elif Input.is_action_pressed("crouch") || not above_head_is_empty():
		velocity.x = 30 * horizontal_direction
	if Input.is_action_pressed("crouch") && Input.is_action_pressed("jump"):
		velocity.x = 350 * horizontal_direction


#####################################################################
# Timers
#####################################################################

func _on_coyote_timer_timeout():
	can_coyote_jump = false

func _on_jump_buffer_time_timeout():
	jump_beffered = false

func _on_jump_hight_timer_timeout():
	if not Input.is_action_pressed("jump"):
		if velocity.y < -100:
			velocity.y = -100

func _on_attack_timer_timeout():
	current_attack = false
	print("end attack")


#####################################################################
# Checks
#####################################################################

func check_position():
	if velocity.y != 0:
		player_position = "jump"
	if not above_head_is_empty() || Input.is_action_pressed("crouch"):
		player_position = "crouch"
	if velocity.x != 0:
		player_position = "run"
	print(player_position)
	return player_position

func above_head_is_empty() -> bool:
	var result = not crouch_raycast_1.is_colliding() && not crouch_raycast_2.is_colliding()
	return result


#####################################################################
# Apparences
#####################################################################

func update_animation(horizontal_direction):
	if current_attack:
		return
	if is_on_floor():
		if horizontal_direction == 0:
			if is_crouching:
				ap.play("crouch")
			else:
				ap.play("idle")
		else:
			if is_crouching:
				ap.play("crouch_walk")
			else:
				ap.play("run")
	else:
		if not is_crouching:
			if velocity.y < 0:
				ap.play("jump")
			elif velocity.y > 0:
				ap.play("fall")
		else:
			ap.play("crouch")

func switch_direction(horizontal_direction):
	sprite.flip_h = (horizontal_direction == -1)
	sprite.position.x = horizontal_direction * 4

func attack_animations():
	var was_moving = velocity.x != 0

	current_attack = true
	velocity.x = 0  

	if was_moving && is_on_floor():
		print("run attack")
		ap.play("run_attack")
	elif is_on_floor():
		print("stand attack")
		ap.play("stand_attack")
	else:
		print("air attack")
		ap.play("run_attack") # si tu veux une anim aérienne
	attack_timer.start()



#####################################################################
# Contrôles
#####################################################################

func _process(delta):
	if current_attack:
		# bloque tout sauf gravité et glissement
		velocity.x = 0
		move_and_slide()
		return

	if Input.is_action_just_pressed("jump"):
		jump_height_timer.start()
		jump()
		
	var horizontal_direction = Input.get_axis("move_left", "move_right")
	horizontal_move(horizontal_direction)
	
	if Input.is_action_just_pressed("dash"):
		velocity.x = 100 * speed * horizontal_direction
	
	if horizontal_direction != 0:
		switch_direction(horizontal_direction)
		
	if Input.is_action_just_pressed("crouch"):
		crouch()
	elif Input.is_action_just_released("crouch"):
		if above_head_is_empty():
			stand()
		else:
			if stuck_under_object != true:
				stuck_under_object = true
	if stuck_under_object && above_head_is_empty() && not Input.is_action_pressed("crouch"):
		stand()
		stuck_under_object = false
		
	var was_on_floor = is_on_floor()
	
	if Input.is_action_just_pressed("attack"):
		attack_animations()
	
	move_and_slide()
	
	if was_on_floor && not is_on_floor() && velocity.y >= 0:
		can_coyote_jump = true
		coyote_timer.start()
	
	if not was_on_floor && is_on_floor():
		if jump_beffered:
			jump_beffered = false
			jump()
		
	update_animation(horizontal_direction)


#####################################################################
# Physics
#####################################################################

func _physics_process(delta):
	if not is_on_floor() && can_coyote_jump == false:
		velocity.y += gravity
		if velocity.y > 1000:
			velocity.y = 1000
