# res://Entities/Player/ShieldComponent.gd
# [護盾元件 / Shield Component]
# 管理玩家護盾狀態機：IDLE → PERFECT_WINDOW → ACTIVE → BROKEN_COOLDOWN。
# 處理舉盾、完美格擋（反傷+眩暈）、一般格擋、破盾冷卻。
class_name ShieldComponent
extends Node2D

# 護盾狀態列舉
enum ShieldState { IDLE, ACTIVE, PERFECT_WINDOW, BROKEN_COOLDOWN }

@export var perfect_window_ms: int = 150   # 完美格擋容錯窗口（毫秒）
@export var shield_cost: float = 15.0       # 舉盾消耗能量
@export var broken_cooldown_sec: float = 1.2 # 破盾冷卻時間（秒）

var current_state: ShieldState = ShieldState.IDLE
var state_timer: float = 0.0
var perfect_timer: float = 0.0

@onready var player = get_parent()

# 護盾狀態變更訊號
signal shield_state_changed(new_state: ShieldState)
signal perfect_block_triggered(attacker: Node2D)
signal normal_block_triggered()
signal shield_broken()

# 節點就緒
func _ready() -> void:
	print("🛡️ ShieldComponent ready!")

# 每幀：更新計時器、處理舉盾輸入、放開取消
func _physics_process(delta: float) -> void:
	if not player or not player.input_handler:
		return
		
	# 狀態計時器更新
	if current_state == ShieldState.PERFECT_WINDOW:
		perfect_timer -= delta * 1000.0
		if perfect_timer <= 0.0:
			_transition_to(ShieldState.ACTIVE)
			
	elif current_state == ShieldState.BROKEN_COOLDOWN:
		state_timer -= delta
		if state_timer <= 0.0:
			_transition_to(ShieldState.IDLE)
			
	# 舉盾輸入處理
	if player.input_handler.is_protecting:
		if current_state == ShieldState.IDLE:
			if player.energy.try_spend(shield_cost, "shield"):
				_start_shielding()
			else:
				# 能量不足，無法舉盾
				print("⚠️ 能量不足，無法舉盾！")
				
	# 若放開 Q 鍵，取消盾牌狀態 (僅在 PERFECT_WINDOW 或 ACTIVE 狀態時)
	if current_state == ShieldState.ACTIVE or current_state == ShieldState.PERFECT_WINDOW:
		if not Input.is_action_pressed("ui_protect"):
			_transition_to(ShieldState.IDLE)

# 開始舉盾：進入完美窗口
func _start_shielding() -> void:
	_transition_to(ShieldState.PERFECT_WINDOW)
	perfect_timer = perfect_window_ms

# 狀態轉移：更新狀態、發訊號、設定視覺
func _transition_to(new_state: ShieldState) -> void:
	current_state = new_state
	shield_state_changed.emit(new_state)
	
	match current_state:
		ShieldState.IDLE:
			print("🛡️ 護盾狀態：IDLE")
			player.modulate = Color.WHITE
		ShieldState.PERFECT_WINDOW:
			print("🛡️ 護盾狀態：PERFECT_WINDOW")
			# 完美格擋黃色/金色閃光視覺
			player.modulate = Color(1.8, 1.8, 0.4, 1.0)
		ShieldState.ACTIVE:
			print("🛡️ 護盾狀態：ACTIVE")
			# 一般格擋藍色視覺
			player.modulate = Color(0.4, 0.7, 1.8, 1.0)
		ShieldState.BROKEN_COOLDOWN:
			print("🛡️ 護盾狀態：BROKEN_COOLDOWN")
			# 破盾灰暗視覺
			player.modulate = Color(0.3, 0.3, 0.3, 0.7)
			state_timer = broken_cooldown_sec
			shield_broken.emit()

# 處理受傷攔截：成功格擋回傳 true，否則 false
# damage_amount=傷害值, hitbox=攻擊來源
func handle_hit(damage_amount: int, hitbox: Area2D) -> bool:
	if current_state == ShieldState.PERFECT_WINDOW:
		print("⭐ 觸發完美格擋！")
		var attacker = hitbox.get_parent() if hitbox else null
		perfect_block_triggered.emit(attacker)
		
		# 反傷與眩暈攻擊者
		if attacker and attacker.has_method("_on_enemy_hurtbox_on_hit"):
			attacker._on_enemy_hurtbox_on_hit(damage_amount * 2)
			if "speed" in attacker:
				var original_speed = attacker.speed
				attacker.speed = 0.0
				print("💫 敵人受到完美格擋反擊，眩暈中！")
				get_tree().create_timer(1.2).timeout.connect(func():
					if is_instance_valid(attacker):
						attacker.speed = original_speed
						print("💫 敵人眩暈恢復")
				)
		return true
		
	elif current_state == ShieldState.ACTIVE:
		print("🛡️ 觸發一般格擋！")
		normal_block_triggered.emit()
		return true
		
	elif current_state == ShieldState.BROKEN_COOLDOWN:
		print("💥 破盾狀態，無法格擋傷害！")
		_transition_to(ShieldState.BROKEN_COOLDOWN) # 重置冷卻
		return false
		
	return false
