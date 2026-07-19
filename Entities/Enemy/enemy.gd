# res://Entities/Enemy/enemy.gd
extends CharacterBody2D

@export var base_speed: float = 150.0
@export var base_max_hp: int = 3
@export var base_damage: int = 1
@export var base_exp_reward: int = 20

@export var attack_range: float = 130.0
@export var windup_time: float = 0.4
@export var strike_time: float = 0.1
@export var recovery_time: float = 0.6

enum AttackState { IDLE, WINDUP, STRIKE, RECOVERY }
var attack_state: AttackState = AttackState.IDLE
var attack_timer: float = 0.0

var spawner_hp_mult: float = 1.0
var spawner_dmg_mult: float = 1.0

var player = null
var current_target: Node2D = null
var mind_control_component: MindControlComponent

var speed: float
var max_hp: int
var current_hp: int
var damage: int
var exp_reward: int 

var original_color: Color = Color(1, 0, 0, 1)

func _ready():
	add_to_group("enemies")
	
	player = get_tree().get_first_node_in_group("player")
	current_target = player
	
	mind_control_component = MindControlComponent.new()
	mind_control_component.name = "MindControlComponent"
	add_child(mind_control_component)
	
	scale_monster_stats("chapter_1") 

	current_hp = max_hp
	if has_node("EnemyHealthBar"):
		$EnemyHealthBar.max_value = max_hp
		$EnemyHealthBar.value = current_hp
	
	if has_node("Sprite2D"):
		original_color = $Sprite2D.modulate
	
	# 初始化時禁用攻擊盒，等待進入攻擊狀態
	_set_hitbox_enabled(false)

func scale_monster_stats(current_chapter: String) -> void:
	var level_modifier: float = 1.0 + (PlayerData.account_level - 1) * 0.1
	var chapter_modifier: float = 1.0
	if current_chapter == "chapter_2":
		chapter_modifier = 2.0
	elif current_chapter == "chapter_3":
		chapter_modifier = 3.5
		
	max_hp = int(base_max_hp * level_modifier * chapter_modifier * spawner_hp_mult)
	damage = int(base_damage * level_modifier * chapter_modifier * spawner_dmg_mult)
	exp_reward = int(base_exp_reward * level_modifier) 
	speed = base_speed
	if has_node("EnemyHitbox"):
		$EnemyHitbox.damage = damage

func _physics_process(delta: float) -> void:
	_update_attack_state(delta)
	
	if attack_state != AttackState.IDLE:
		return
	
	if current_target and is_instance_valid(current_target):
		var direction = global_position.direction_to(current_target.global_position)
		var dist = global_position.distance_to(current_target.global_position)
		
		# 心控狀態下，尋找其他敵人
		if mind_control_component and mind_control_component.is_mind_controlled:
			current_target = find_closest_other_enemy()
			if is_instance_valid(current_target):
				velocity = direction * speed
				move_and_slide()
			return
		
		# 在攻擊範圍內，開始攻擊
		if dist <= attack_range:
			_start_attack()
		else:
			velocity = direction * speed
			move_and_slide()

func _start_attack() -> void:
	attack_state = AttackState.WINDUP
	attack_timer = windup_time
	velocity = Vector2.ZERO

func _update_attack_state(delta: float) -> void:
	match attack_state:
		AttackState.WINDUP:
			attack_timer -= delta
			# 前搖視覺：紅色閃爍警告
			var flash = sin(attack_timer * 25.0) * 0.4
			if has_node("Sprite2D"):
				$Sprite2D.modulate = Color(1.0, 0.3 + flash, 0.3 + flash, 1.0)
			
			if attack_timer <= 0.0:
				attack_state = AttackState.STRIKE
				attack_timer = strike_time
				_perform_strike()
				
		AttackState.STRIKE:
			attack_timer -= delta
			# 攻擊中：亮紅色
			if has_node("Sprite2D"):
				$Sprite2D.modulate = Color(1.0, 0.1, 0.1, 1.0)
			
			if attack_timer <= 0.0:
				attack_state = AttackState.RECOVERY
				attack_timer = recovery_time
				_set_hitbox_enabled(false)
				
		AttackState.RECOVERY:
			attack_timer -= delta
			# 恢復中：暗紅色
			if has_node("Sprite2D"):
				$Sprite2D.modulate = Color(0.6, 0.2, 0.2, 1.0)
			
			if attack_timer <= 0.0:
				attack_state = AttackState.IDLE
				if has_node("Sprite2D"):
					$Sprite2D.modulate = original_color

func _perform_strike() -> void:
	_set_hitbox_enabled(true)

func _set_hitbox_enabled(enabled: bool) -> void:
	if has_node("EnemyHitbox"):
		$EnemyHitbox.monitoring = enabled
		$EnemyHitbox.monitorable = enabled
		if enabled:
			$EnemyHitbox.is_spent = false

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
