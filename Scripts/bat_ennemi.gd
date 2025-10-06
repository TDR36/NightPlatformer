extends CharacterBody2D

class_name BatEnemy

@onready var ap = $AnimationBAT

const speed = 30
var dir: Vector2 = Vector2.ZERO

var is_bat_chase: bool

var player: CharacterBody2D

var health = 50
var health_max = 50
var health_min = 0
var dead = false
var taking_damage = false
var is_roaming: bool
var damage_to_deal = 20


func _ready():
	$Timer.start()


func _process(delta):
	Global.batDamageAmount = damage_to_deal
	Global.batDamageZone = $BatDealDamageArea
	
	if Global.playerAlive:
		is_bat_chase = true
		
	if is_on_floor() && dead:
		await get_tree().create_timer(3.0).timeout
		self.queue_free()
	
	move(delta)
	handle_animation()


func move(delta):
	player = Global.playerBody
	if !dead:
		is_roaming = true
		if !taking_damage && is_bat_chase && Global.playerAlive:
			velocity = position.direction_to(player.position) * speed
			dir.x = sign(velocity.x)
		elif taking_damage:
			var knockback_dir = position.direction_to(player.position) * -50
			velocity = knockback_dir
			is_bat_chase = true
		else:
			velocity += dir * speed * delta
			if velocity >=  dir * speed * delta * 5:
				velocity =  dir * speed * delta * 5
	elif dead:
		velocity.y += 10 * delta
		velocity.x = 0
	move_and_slide()


func _on_timer_timeout():
	$Timer.wait_time = choose([0.5,0.8])
	if !is_bat_chase:
		dir = choose([Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN, 	Vector2(1, 1).normalized(),Vector2(-1, 1).normalized(),Vector2(1, -1).normalized(),Vector2(-1, -1).normalized()])

func handle_animation():
	var sprite = $Sprite2D
	if !dead && !taking_damage:
		ap.play("flying")
		sprite.flip_h = (dir.x ==-1)
	elif !dead && taking_damage:
		ap.play("hurt")
		await get_tree().create_timer(0.4).timeout
		taking_damage = false
	elif dead && is_roaming:
		is_roaming = false
		ap.play("bat_death")
		set_collision_layer_value(1, true)
		set_collision_layer_value(2, false)
		set_collision_mask_value(1, true)
		set_collision_mask_value(2, false)
	
func choose (array):
	array.shuffle()
	return array.front()


func _on_bat_hitbox_area_entered(area):
	if area == Global.playerDamageZone:
		var damage = Global.playerDamageAmount
		take_damage(damage)
		
func take_damage (damage):
	health -= damage
	taking_damage = true
	if health <= 0:
		health = 0
		dead = true
	print(str(self), "current healt is ", health)
