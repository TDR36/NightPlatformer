extends CharacterBody2D

@export var speed = 300
@export var gravity = 30
@export var jump_force = 700

@onready var ap = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var cshape = $CollisionShape2D
@onready var coyote_timer = $CoyoteTimer
@onready var jump_buffer_timer = $JumpBufferTime
@onready var jump_height_timer = $JumpHeightTimer
@onready var attack_timer = $attackTimer
@onready var deal_damage_zone = $DealDamageZone/CollisionShape2D
@onready var deal_damage_area = $DealDamageZone

var attack_type: String
var current_attack: bool
var weapon_equip: bool
var stuck_under_object = false
var can_coyote_jump = false
var jump_beffered = false
var player_position = "stand"
var standing_cshape = preload("res://Ressources/standing_night_cshape.tres")
var dead_cshape = preload("res://Ressources/dead_night_cshape.tres")

var health = 100
var health_max = 100
var health_min = 0
var can_take_damage: bool
var dead: bool


func _ready():
	Global.playerBody = self
	deal_damage_zone.disabled = true
	current_attack = false
	dead = false
	can_take_damage = true
	Global.playerAlive = true
#=============================
# Mouvements
#=============================

func jump():
	if is_on_floor() or can_coyote_jump:
		velocity.y = -jump_force
		can_coyote_jump = false
		jump_beffered = false
	else:
		if not jump_beffered:
			jump_beffered = true
			jump_buffer_timer.start()

func horizontal_move(horizontal_direction):
	velocity.x = speed * horizontal_direction

#=============================
# Collision shapes
#=============================
func update_cshape():
	cshape.shape = standing_cshape
	cshape.position.y = -19
	if current_attack:
		cshape.shape = standing_cshape
		if sprite.flip_h:
			cshape.position.x = -13
		else:
			cshape.position.x = 13
	else:
		cshape.position.x = 0


#=============================
# Timers
#=============================
func _on_coyote_timer_timeout():
	can_coyote_jump = false

func _on_jump_buffer_time_timeout():
	jump_beffered = false

func _on_jump_height_timer_timeout():
	if not Input.is_action_pressed("jump") and velocity.y < -100:
		velocity.y = -100

func _on_attack_timer_timeout():
	stop_attack()

func take_damage_cooldown(wait_time):
	can_take_damage = false
	await get_tree().create_timer(wait_time).timeout
	can_take_damage = true

#=============================
# Checks
#=============================
func check_position():
	if velocity.y != 0:
		player_position = "jump"
	if velocity.x != 0:
		player_position = "run"
	return player_position

func check_hitbox():
	var hitbox_areas = $PlayerHitbox.get_overlapping_areas()
	var damage: int
	if hitbox_areas:
		var hitbox = hitbox_areas.front()
		if hitbox.get_parent() is BatEnemy:
			damage = Global.batDamageAmount
	if can_take_damage:
		take_damage(damage)
#=============================
# Animations
#=============================
func update_animation(horizontal_direction):
	if current_attack:
		return
	elif !velocity:
		ap.play("idle")
	elif velocity.x && is_on_floor():
		ap.play("run")
	elif velocity.y < 0:
		ap.play("jump")
	else:
		ap.play("fall")

func switch_direction(horizontal_direction):
	sprite.flip_h = horizontal_direction == -1
	deal_damage_area.scale.x = horizontal_direction
	sprite.position.x = horizontal_direction * 4
	update_cshape()

#=============================
# Attaques
#=============================
func attack_animations():
	var was_moving = velocity.x != 0
	var attack_type : String
	current_attack = true
	velocity.x = 0
	update_cshape()
	if was_moving && is_on_floor():
		ap.play("run_attack")
		deal_damage_area.position.x = 5*Input.get_axis("move_left", "move_right")
		deal_damage_area.position.y = 0
		attack_type = "run_attack"
	elif !is_on_floor() && Input.is_action_just_pressed("left_click") && (Input.is_action_pressed("bas") ||  Input.is_action_pressed("haut")):
		if Input.is_action_pressed("bas"):
			ap.play("attack_bas")
			deal_damage_area.position.y =  25
			attack_type = "jump_bas_attack"
		elif Input.is_action_pressed("haut"):
			deal_damage_area.position.y =  -25
			attack_type = "jump_haut_attack"
	elif is_on_floor() && !velocity:
		deal_damage_area.position.y = 0
		ap.play("stand_attack")
		deal_damage_area.position.x = 30*Input.get_axis("move_left", "move_right")
		attack_type = "stand_attack"
	else:
		deal_damage_area.position.y = 0
		ap.play("run_attack")
		deal_damage_area.position.x = 15*Input.get_axis("move_left", "move_right")
		attack_type = "run_attack"
	set_damage(attack_type)
	deal_damage_zone.disabled = false
	attack_timer.start()

func stop_attack():
	deal_damage_zone.disabled = true
	current_attack = false
	update_cshape()

func set_damage(attack_type):
	var current_damage_to_deal: int
	if attack_type == "run_attack":
		current_damage_to_deal = 8
	elif attack_type == "stand_attack":
		current_damage_to_deal = 13
	elif attack_type == "jump_bas_attack":
		current_damage_to_deal = 20
	else:
		current_damage_to_deal = 10
	Global.playerDamageAmount = current_damage_to_deal

#=============================
#Dégâts
#=============================

func take_damage(damage):
	if damage != 0 and can_take_damage:
		health -= damage
		print("player health:", health)
		if health <= 0 and not dead:
			health = 0
			Global.playerAlive = false
			handle_death()
		take_damage_cooldown(1.0)



func handle_death():
	$CollisionShape2D.position.y = 5
	dead = true
	ap.play("death")
	cshape.shape = dead_cshape
	cshape.position.y = -1
	await get_tree().create_timer(0.5).timeout
	$Camera2D.zoom.x = 2
	$Camera2D.zoom.y = 2
	await get_tree().create_timer(3.5).timeout
	self.queue_free()
#=============================
# Contrôles
#=============================
func _process(delta): 
	weapon_equip = Global.playerWeaponEquip
	Global.playerDamageZone = deal_damage_area
	if current_attack && weapon_equip:
		velocity.x = 0
		move_and_slide()
		return
	if !dead:
		if Input.is_action_just_pressed("jump"):
			jump_height_timer.start()
			jump()

		var horizontal_direction = Input.get_axis("move_left", "move_right")
		horizontal_move(horizontal_direction)

		if Input.is_action_just_pressed("dash"):
			velocity.x = 100 * speed * horizontal_direction

		if horizontal_direction != 0:
			switch_direction(horizontal_direction)


		var was_on_floor = is_on_floor()
		if Input.is_action_just_pressed("left_click") || Input.is_action_just_pressed("right_click"):
			attack_animations()
		if was_on_floor and not is_on_floor() and velocity.y >= 0:
			can_coyote_jump = true
			coyote_timer.start()

		if not was_on_floor and is_on_floor():
			if jump_beffered:
				jump_beffered = false
				jump()
		if not was_on_floor and is_on_floor():
			if jump_beffered:
				jump_beffered = false
				jump()
		Global.playerDamageZone = deal_damage_area
		update_animation(horizontal_direction)
		check_hitbox()
	move_and_slide()


#=============================
# Physics
#=============================
func _physics_process(delta):
	if not is_on_floor() and not can_coyote_jump:
		velocity.y += gravity
		if velocity.y > 1000:
			velocity.y = 1000
