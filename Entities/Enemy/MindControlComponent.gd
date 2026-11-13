# res://Entities/Enemy/MindControlComponent.gd
# [心控元件 / Mind Control Component]
# 掛載於敵人節點，處理 QTE 結果：完美格擋→心控、良好→定身、失敗→無效。
# 心控期間敵人改為攻擊其他敵人。
class_name MindControlComponent
extends Node2D

@export var control_duration: float = 5.0      # 心控持續秒數
@export var good_stun_duration: float = 2.0   # 定身持續秒數

var is_mind_controlled: bool = false
var original_modulate: Color = Color.WHITE     # 原始顏色（用於恢復）

@onready var enemy = get_parent()             # 所屬敵人節點

# 節點就緒（無特殊處理）
func _ready() -> void:
	pass

# 接收 QTE 結果並觸發對應效果
# qte_result = "PERFECT" / "GOOD" / "FAIL"
func trigger_qte(qte_result: String) -> void:
	match qte_result:
		"PERFECT":
			start_mind_control()
		"GOOD":
			start_stun()
		"FAIL":
			print("👾 QTE 失敗，怪物未受影響。")

# 開始心控：改變顏色、切換碰撞遮罩、設定計時器
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

# 定身：暫停移動並變藍色
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

# 結束心控：恢復顏色與目標、碰撞遮罩
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

# 每幀：心控期間追蹤最近的其他敵人
func _physics_process(_delta: float) -> void:
	if is_mind_controlled and is_instance_valid(enemy):
		var closest = enemy.find_closest_other_enemy()
		if closest and is_instance_valid(closest):
			enemy.current_target = closest
		else:
			enemy.current_target = null
