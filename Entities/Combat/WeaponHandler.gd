# res://Entities/Combat/WeaponHandler.gd
# [武器處理器 / Weapon Handler]
# 掛載於 Player 下，管理武器資料、瞄準、射擊、換彈、冷卻。
# 由 Player 每幀呼叫 aim_at_position / fire / reload。
extends Node2D

@export var data: WeaponResource  # 武器資料資源（.tres）
var current_bullets: int          # 當前彈匣子彈數
var can_fire: bool = true         # 是否可射擊（冷卻結束）
var is_reloading: bool = false    # 是否正在換彈

# 抓取武器圖片節點
@onready var sprite: Sprite2D = $WeaponSprite
@onready var timer: Timer = Timer.new()  # 射擊冷卻計時器（執行期建立）

# 節點就緒：建立計時器子節點，初始化武器
func _ready():
	add_child(timer)
	if data:
		setup_weapon()

# 初始化武器：設定彈匣數、套用圖片
func setup_weapon():
	current_bullets = data.bullet_count
	
	# 當換武器時，自動把 Resource 裡的圖片換上去
	if data.texture:
		sprite.texture = data.texture
	print("武器已就緒：", data.name)

# 🎯 瞄準：旋轉武器朝向目標，並依左右翻轉貼圖
# target_global_pos=目標全域座標
func aim_at_position(target_global_pos: Vector2) -> void:
	look_at(target_global_pos)
	
	# 翻轉貼圖邏輯（以武器自身的 global_position 判斷目標在左邊還是右邊）
	if global_position.x > target_global_pos.x:
		sprite.flip_v = true
	else:
		sprite.flip_v = false

# 換彈：等待 reload_time 後補滿彈匣
func reload():
	if is_reloading: 
		return
		
	print("🔄 換彈中...")
	is_reloading = true
	
	# 等待資源檔設定的換彈時間
	await get_tree().create_timer(data.reload_time).timeout
	
	current_bullets = data.bullet_count
	is_reloading = false
	can_fire = true # 確保換彈完，開火開關要重新打開！
	print("✅ 換彈完成！目前子彈：", current_bullets)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.update_ammo(current_bullets, "∞")

# 射擊：消耗子彈、生成子彈、設定冷卻
# _target_global_pos=目標座標（保留參數供未來使用）, pos=槍口位置
func fire(_target_global_pos: Vector2, pos: Vector2):
	if not can_fire or is_reloading:
		return
	if current_bullets <= 0:
		print("彈藥耗盡！觸發自動換彈！")
		reload() 
		return   
		
	var bullet = data.bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = pos
	
	bullet.global_rotation = global_rotation
	
	bullet.setup(data.bullet_speed, data.damage)
	
	current_bullets -= 1
	
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.update_ammo(current_bullets, "∞")
		
	can_fire = false
	timer.start(data.cooldown)
	await timer.timeout
	can_fire = true
