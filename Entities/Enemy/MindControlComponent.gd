class_name MindControlComponent
extends Node2D
# res://Entities/Enemy/MindControlComponent.gd

@export var control_duration: float = 5.0
@export var good_stun_duration: float = 2.0

var is_mind_controlled: bool = false
var original_modulate: Color = Color.WHITE

@onready var enemy = get_parent()

func _ready() -> void:
	pass

func trigger_qte(qte_result: String) -> void:
	match qte_result:
		"PERFECT":
			start_mind_control()
		"GOOD":
			start_stun()
		"FAIL":
			print("👾 QTE 失敗，怪物未受影響。")

func start_mind_control() -> void:
	if not is_instance_valid(enemy):
		return
	if is_mind_controlled:
		return
	is_mind_controlled = true
	original_modulate = enemy.modulate
	
	# 視覺調色：偏綠/粉紅代表被心控
	enemy.modulate = Color(0.3, 1.8, 0.3, 1.0)
	
	# 更換碰撞遮罩：關閉 Layer 3 (Player Hurtbox)，開啟 Layer 4 (Enemy Hurtbox)
	var hitbox = enemy.get_node_or_null("EnemyHitbox")
	if hitbox:
		hitbox.set_collision_mask_value(3, false)
		hitbox.set_collision_mask_value(4, true)
		
	print("🧠 敵人 [", enemy.name, "] 已被心控！持續 ", control_duration, " 秒")
	
	get_tree().create_timer(control_duration).timeout.connect(end_mind_control)

func start_stun() -> void:
	if not is_instance_valid(enemy):
		return
	print("🧠 敵人 [", enemy.name, "] 被定身！持續 ", good_stun_duration, " 秒")
	var original_speed = enemy.speed
	enemy.speed = 0.0
	enemy.modulate = Color(0.8, 0.8, 1.8, 1.0) # 藍色定身狀態
	
	get_tree().create_timer(good_stun_duration).timeout.connect(func():
		if is_instance_valid(enemy):
			enemy.speed = original_speed
			enemy.modulate = original_modulate
			print("🧠 敵人 [", enemy.name, "] 定身解除。")
	)

func end_mind_control() -> void:
	if not is_mind_controlled:
		return
	is_mind_controlled = false
	
	if is_instance_valid(enemy):
		enemy.modulate = original_modulate
		enemy.current_target = enemy.player
		
		var hitbox = enemy.get_node_or_null("EnemyHitbox")
		if hitbox:
			hitbox.set_collision_mask_value(3, true)
			hitbox.set_collision_mask_value(4, false)
			
		print("🧠 敵人 [", enemy.name, "] 心控解除，回歸正常。")

func _physics_process(_delta: float) -> void:
	if is_mind_controlled and is_instance_valid(enemy):
		var closest = enemy.find_closest_other_enemy()
		if closest and is_instance_valid(closest):
			enemy.current_target = closest
		else:
			enemy.current_target = null
