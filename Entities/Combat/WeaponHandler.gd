# res://Entities/Combat/WeaponHandler.gd
extends Node2D

@export var data: WeaponResource 
var current_bullets: int
var can_fire: bool = true
var is_reloading: bool = false

# 抓取武器圖片節點
@onready var sprite: Sprite2D = $WeaponSprite
@onready var timer: Timer = Timer.new()

func _ready():
	add_child(timer)
	if data:
		setup_weapon()

func setup_weapon():
	current_bullets = data.bullet_count
	
	# 當換武器時，自動把 Resource 裡的圖片換上去
	if data.texture:
		sprite.texture = data.texture
	print("武器已就緒：", data.name)

# 🎯 [修正] 移除重複的宣告與整個 _process 邏輯
# 這個函式現在完全交由外面的 player.gd 來呼叫，並傳入不論是鍵鼠還是手把的瞄準點
func aim_at_position(target_global_pos: Vector2) -> void:
	look_at(target_global_pos)
	
	# 翻轉貼圖邏輯（以武器自身的 global_position 判斷目標在左邊還是右邊）
	if global_position.x > target_global_pos.x:
		sprite.flip_v = true
	else:
		sprite.flip_v = false

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

func fire(target_global_pos: Vector2, pos: Vector2):
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
