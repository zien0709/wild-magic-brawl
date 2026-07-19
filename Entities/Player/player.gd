# player.gd
extends CharacterBody2D
var input_handler: InputComponent
# 📣 定義訊號：當血量或能量改變時，通知任何想聽的 UI
signal health_changed(current: int, max_hp: int)
signal energy_changed(current: float, max_energy: float)

@onready var weapon = $WeaponHandler # 確保節點路徑正確
@export var speed: float = 300.0 
@export var max_hp: int = 10     # 最大血量（可以由右邊屬性面板直接改）
var current_hp: int = 0         # 當前血量

# === 🌪️ Cril 加速瞬移系統變數 ===
@export var max_energy: float = 100.0
@export var dash_energy_cost: float = 30.0  # 每次閃避消耗的固定能量
@export var dash_duration: float = 0.58
@export var qte_energy_cost: float = 20.0   # 每次 QTE 心控消耗的能量

var energy: EnergyResource
var shield_component: ShieldComponent
var throw_aim_component: ThrowAimComponent

@export var normal_speed: float = 200.0  # 正常走路速度
@export var dash_speed: float = 600.0    # 衝鋒瘋狂速度

var dash_time_left: float = 0.0             # 衝刺剩餘時間倒數
var dash_direction: Vector2 = Vector2.ZERO  # 鎖定衝刺時的方向

var is_dashing: bool = false

var grabbed_object: RigidBody2D = null

@onready var hurtbox = $PlayerHurtbox

const HUD_SCENE = preload("res://Scenes/UI/GameHUD.tscn")

func _ready():
	current_hp = max_hp         # 遊戲一開始，把血量補滿
	# 🟢 核心防呆：如果沒有從外部注入控制器，預設給他鍵盤控制器
	if not input_handler:
		input_handler = InputComponent.new()
		add_child(input_handler)
	
	# 初始化能量資源
	energy = EnergyResource.new()
	energy.max_energy = max_energy
	energy.current_energy = max_energy
	
	if PlayerData.talents.get("energy_regen_up", false) == true:
		energy.regen_rate = 30.0
	else:
		energy.regen_rate = 15.0
		
	# 初始化護盾元件
	shield_component = ShieldComponent.new()
	shield_component.name = "ShieldComponent"
	add_child(shield_component)
	
	# 初始化磁吸瞄準元件
	throw_aim_component = ThrowAimComponent.new()
	throw_aim_component.name = "ThrowAimComponent"
	add_child(throw_aim_component)
		
	# 監聽能量變化並轉發
	energy.energy_changed.connect(func(curr, mx):
		energy_changed.emit(curr, mx)
	)
	
	# 監聽能量耗盡與技能拒絕訊號
	energy.energy_depleted.connect(func():
		print("⚡ 能量耗盡！")
	)
	energy.skill_rejected.connect(func(skill_name, required, available):
		print("❌ 技能 [", skill_name, "] 施放失敗：需要能量 ", required, "，目前僅有 ", available)
		# TODO: 觸發音效或 UI 閃紅等拒絕回饋
	)
	
	health_changed.emit(current_hp, max_hp)
	energy_changed.emit(energy.current_energy, energy.max_energy)
	
	_load_hud()

func _load_hud():
	if get_tree().current_scene == null:
		return
	if get_tree().get_first_node_in_group("hud") != null:
		return
	var hud = HUD_SCENE.instantiate()
	get_tree().current_scene.add_child.call_deferred(hud)

func _on_player_hurtbox_on_hit(damage_amount: int, hitbox: Area2D = null):
	if shield_component and shield_component.handle_hit(damage_amount, hitbox):
		return
	current_hp -= damage_amount
	print("💥 玩家痛痛！遭受傷害：", damage_amount)
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		die()

func _physics_process(delta):
	if not input_handler: return
	
	# 1. 更新目前控制器輸入的數據
	input_handler.update_input()
	
	# 2. 處理衝刺與能量消耗邏輯
	if is_dashing:
		dash_time_left -= delta
		if dash_time_left <= 0:
			end_dash()
	else:
		energy.regen(delta)
	
	if input_handler.is_dashing:
		if energy.try_spend(dash_energy_cost, "dash"):
			start_dash()
			
	# QTE Space 鍵觸發心控
	if input_handler.is_qte_pressed:
		var target_enemy = _get_qte_target_enemy()
		if target_enemy:
			if energy.try_spend(qte_energy_cost, "qte"):
				_start_qte(target_enemy)
		else:
			print("❌ 範圍內沒有可心控的敵對目標！")
			
	# 🛠️ [重構] 箱子丟擲方向：改用 input_handler 的瞄準點計算
	if input_handler.is_interacting:
		if grabbed_object == null:
			_try_grab_object()
		else:
			var throw_dir = (input_handler.aim_position - global_position).normalized()
			grabbed_object.throw(throw_dir)
			grabbed_object = null

	var current_speed = dash_speed if is_dashing else normal_speed
	if is_dashing:
		velocity = dash_direction * current_speed
	else:
		velocity = input_handler.move_direction * current_speed
	move_and_slide()

	# 🛠️ [重構] 處理武器瞄準與開火
	if weapon:
		# 每一影格都把控制器的瞄準點注入給武器
		weapon.aim_at_position(input_handler.aim_position)
		
		if input_handler.is_shooting:
			var muzzle = weapon.get_node_or_null("WeaponSprite/Muzzle")
			var muzzle_pos = muzzle.global_position if muzzle else global_position
			
			if weapon.can_fire and not weapon.is_reloading and weapon.current_bullets > 0:
				weapon.fire(input_handler.aim_position, muzzle_pos)
			elif weapon.current_bullets <= 0 and not weapon.is_reloading:
				weapon.reload()
			
		if input_handler.is_reloading:
			weapon.reload()
			
	RenderingServer.global_shader_parameter_set("player_position", global_position)
	
func start_dash():
	is_dashing = true
	dash_time_left = dash_duration  # 重設倒數時間
	
	# 🔴 核心鎖定：記錄按下瞬間的方向
	if input_handler.move_direction != Vector2.ZERO:
		dash_direction = input_handler.move_direction.normalized()
	#else:
		#dash_direction = input_handler.move_direction
		
	modulate = Color(1, 2, 2, 0.6) # 讓玩家角色變亮、變透明（很有特效感！）
	
	# 🔴 核心防呆：關掉受傷盒的監聽，達成「絕對無敵」！

	hurtbox.set_deferred("monitoring", false)   # 玩家不再偵測怪物攻擊
	hurtbox.set_deferred("monitorable", false)  # 怪物攻擊也穿透玩家、偵測不到玩家
	set_collision_mask_value(7, false)
	set_collision_layer_value(2, false)
# === 🛑 結束 Cril 加速瞬移 ===
func end_dash():
	is_dashing = false
	modulate = Color(1, 1, 1, 1) # 恢復正常顏色
	

	# 🔴 恢復正常：重新打開受傷盒，讓玩家可以再次被怪打到
	hurtbox.set_deferred("monitoring", true)
	hurtbox.set_deferred("monitorable", true)
	set_collision_mask_value(7, true)
	set_collision_layer_value(2, true)
	
func _try_grab_object():
	var bodies = $TelekinesisZone.get_overlapping_bodies()
	var closest_dist = INF
	
	for body in bodies:
		if body.is_in_group("interactable_objects"):
			var dist = global_position.distance_squared_to(body.global_position)
			if dist < closest_dist:
				closest_dist = dist
				grabbed_object = body
				
	if grabbed_object:
		grabbed_object.grab(self) # 把自己(玩家)傳過去當作吸引目標
	
func die():
	print("玩家死亡！")
	queue_free()

func _get_qte_target_enemy() -> CharacterBody2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy = null
	var min_dist = 350.0 # 鎖定範圍 350 像素
	
	for e in enemies:
		if not is_instance_valid(e): continue
		if e.has_node("MindControlComponent") and e.get_node("MindControlComponent").is_mind_controlled:
			continue
		var dist = global_position.distance_to(e.global_position)
		if dist < min_dist:
			min_dist = dist
			closest_enemy = e
			
	return closest_enemy

func _start_qte(target_enemy: CharacterBody2D) -> void:
	var qte_scene = load("res://UI/QTEWidget.tscn")
	if qte_scene:
		var qte_inst = qte_scene.instantiate()
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			hud.add_child(qte_inst)
		else:
			get_tree().current_scene.add_child(qte_inst)
			
		qte_inst.qte_finished.connect(func(result: String):
			if is_instance_valid(target_enemy) and target_enemy.has_node("MindControlComponent"):
				target_enemy.get_node("MindControlComponent").trigger_qte(result)
		)
