# res://Entities/enemy.gd
extends CharacterBody2D

@export var base_speed: float = 150.0
@export var base_max_hp: int = 3
@export var base_damage: int = 1
@export var base_exp_reward: int = 20

# 建立兩個暫存變數，用來接收 Spawner 傳進來的環境倍率
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

func _ready():

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

func scale_monster_stats(current_chapter: String) -> void:
	var level_modifier: float = 1.0 + (PlayerData.account_level - 1) * 0.1
	var chapter_modifier: float = 1.0
	if current_chapter == "chapter_2":
		chapter_modifier = 2.0
	elif current_chapter == "chapter_3":
		chapter_modifier = 3.5
		
	# 完美融合：玩家等級補正 * 章節補正 * Spawner難度注入
	max_hp = int(base_max_hp * level_modifier * chapter_modifier * spawner_hp_mult)
	damage = int(base_damage * level_modifier * chapter_modifier * spawner_dmg_mult)
	exp_reward = int(base_exp_reward * level_modifier) 
	speed = base_speed

func _physics_process(_delta):
	if current_target and is_instance_valid(current_target):
		var direction = global_position.direction_to(current_target.global_position)
		velocity = direction * speed
		move_and_slide()

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
	# 🟢 改為透過全域事件流廣播，不直接依賴外面的 HUD 節點與 PlayerData 腳本
	GameEvents.enemy_killed.emit(exp_reward)
	queue_free()
