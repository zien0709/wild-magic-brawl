# res://Entities/Enemy/RangedEnemy.gd
extends CharacterBody2D

@export var base_speed: float = 120.0
@export var base_max_hp: int = 4
@export var base_damage: int = 1
@export var base_exp_reward: int = 30
@export var preferred_range: float = 250.0
@export var flee_range: float = 150.0
@export var weapon_resource: WeaponResource

var player = null
var current_target: Node2D = null
var mind_control_component: MindControlComponent

var speed: float
var max_hp: int
var current_hp: int
var damage: int
var exp_reward: int

var shoot_timer: float = 0.0
var can_shoot: bool = true
var _target_direction: Vector2 = Vector2.RIGHT

var _cached_cooldown: float = 5.0
var _cached_bullet_speed: float = 500.0

@onready var weapon_handler: Node2D = $WeaponHandler
@onready var weapon_sprite: Sprite2D = $WeaponHandler/WeaponSprite
@onready var muzzle: Marker2D = $WeaponHandler/WeaponSprite/Muzzle

enum AttackState { IDLE, WINDUP, STRIKE, RECOVERY }
var attack_state: AttackState = AttackState.IDLE
var attack_timer: float = 0.0

@export var windup_time: float = 0.4
@export var strike_time: float = 0.1
@export var recovery_time: float = 0.8

signal enemy_died(exp_value: int)

func _ready():
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	current_target = player
	
	mind_control_component = MindControlComponent.new()
	mind_control_component.name = "MindControlComponent"
	add_child(mind_control_component)
	
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	
	scale_monster_stats("chapter_1")
	current_hp = max_hp
	
	if has_node("EnemyHealthBar"):
		$EnemyHealthBar.max_value = max_hp
		$EnemyHealthBar.value = current_hp
	
	setup_weapon()

func setup_weapon() -> void:
	if weapon_resource:
		if weapon_resource.texture:
			weapon_sprite.texture = weapon_resource.texture
		_cached_cooldown = weapon_resource.cooldown
		_cached_bullet_speed = weapon_resource.bullet_speed

func scale_monster_stats(current_chapter: String) -> void:
	var level_modifier: float = 1.0 + (PlayerData.account_level - 1) * 0.1
	var chapter_modifier: float = 1.0
	if current_chapter == "chapter_2":
		chapter_modifier = 2.0
	elif current_chapter == "chapter_3":
		chapter_modifier = 3.5
	
	max_hp = int(base_max_hp * level_modifier * chapter_modifier)
	damage = int(base_damage * level_modifier * chapter_modifier)
	exp_reward = int(base_exp_reward * level_modifier)
	speed = base_speed

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	
	_update_attack_state(delta)
	
	if not can_shoot:
		shoot_timer -= delta
		if shoot_timer <= 0.0:
			can_shoot = true
	
	var dist_to_player = global_position.distance_to(player.global_position)
	
	if mind_control_component and mind_control_component.is_mind_controlled:
		current_target = find_closest_other_enemy()
	else:
		current_target = player
	
	if not is_instance_valid(current_target):
		return
	
	var dir_to_target = global_position.direction_to(current_target.global_position)
	_target_direction = dir_to_target
	
	weapon_handler.look_at(current_target.global_position)
	
	if weapon_handler.global_position.x > current_target.global_position.x:
		weapon_sprite.flip_v = true
	else:
		weapon_sprite.flip_v = false
	
	if dist_to_player < flee_range:
		velocity = -dir_to_target * speed
		move_and_slide()
	elif dist_to_player > preferred_range:
		velocity = dir_to_target * speed
		move_and_slide()
	else:
		if can_shoot and attack_state == AttackState.IDLE and not (mind_control_component and mind_control_component.is_mind_controlled):
			_start_attack()

func _start_attack() -> void:
	attack_state = AttackState.WINDUP
	attack_timer = windup_time
	can_shoot = false
	shoot_timer = _cached_cooldown
	modulate = Color(1.0, 0.6, 0.0, 1.0)

func _update_attack_state(delta: float) -> void:
	match attack_state:
		AttackState.WINDUP:
			attack_timer -= delta
			var flash = sin(attack_timer * 20.0) * 0.3
			modulate = Color(1.0, 0.6 + flash, 0.0, 1.0)
			if attack_timer <= 0.0:
				attack_state = AttackState.STRIKE
				attack_timer = strike_time
				_perform_attack()
				
		AttackState.STRIKE:
			attack_timer -= delta
			if attack_timer <= 0.0:
				attack_state = AttackState.RECOVERY
				attack_timer = recovery_time
				modulate = Color(1.0, 0.8, 0.5, 1.0)
				
		AttackState.RECOVERY:
			attack_timer -= delta
			if attack_timer <= 0.0:
				attack_state = AttackState.IDLE
				modulate = Color.WHITE

func _perform_attack() -> void:
	if not is_instance_valid(current_target):
		return
	
	if not weapon_resource or not weapon_resource.bullet_scene:
		return
	
	var bullet = weapon_resource.bullet_scene.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.global_rotation = weapon_handler.global_rotation
	
	bullet.setup(_target_direction, weapon_resource.damage, _cached_bullet_speed)
	get_tree().current_scene.add_child(bullet)

func find_closest_other_enemy() -> CharacterBody2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy = null
	var min_dist = INF
	for e in enemies:
		if e == self or not is_instance_valid(e):
			continue
		if e.has_node("MindControlComponent") and e.get_node("MindControlComponent").is_mind_controlled:
			continue
		var dist = global_position.distance_to(e.global_position)
		if dist < min_dist:
			min_dist = dist
			closest_enemy = e
	return closest_enemy

func _on_enemy_hurtbox_on_hit(damage_amount: int, hitbox: Area2D = null):
	current_hp -= damage_amount
	if has_node("EnemyHealthBar"):
		$EnemyHealthBar.value = current_hp
	if current_hp <= 0:
		die()

func die():
	GameEvents.enemy_killed.emit(exp_reward)
	queue_free()
