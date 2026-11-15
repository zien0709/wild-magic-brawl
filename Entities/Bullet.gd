# res://Entities/Bullet.gd
# [子彈實體 / Bullet]
# 繼承 Hitbox (Area2D)，負責子彈的移動、碰撞偵測、穿透天賦、自動銷毀。
extends Hitbox

var speed: float = 0.0   # 子彈速度（由 WeaponHandler.setup 傳入）

# 🎯 武器系統呼叫的初始化函式
# p_speed=子彈速度, p_damage=傷害值
func setup(p_speed: float, p_damage: int) -> void:
	speed = p_speed
	damage = p_damage

# 節點就緒：綁定牆壁/區域碰撞，設定 3 秒自動銷毀安全機制
func _ready() -> void:
	# 綁定牆壁碰撞與區域碰撞
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# 安全機制：3秒內沒打中任何東西自動銷毀，免得記憶體爆炸
	get_tree().create_timer(3.0).timeout.connect(queue_free)

# 每幀移動：朝 transform.x 方向飛行
func _physics_process(delta: float) -> void:
	# 讓子彈朝著它面向的方向（X軸正向）飛過去
	position += transform.x * speed * delta

# 撞到物理身體（牆壁等）時銷毀
func _on_body_entered(_body: Node2D) -> void:
	# 撞擊到牆壁等環境物理主體時直接銷毀
	queue_free()

# 進入 Area2D（Hurtbox）時處理傷害與穿透
func _on_area_entered(area: Area2D) -> void:
	# 偵測到對方是 Hurtbox 且屬於敵人時
	if area is Hurtbox and area.get_parent() and area.get_parent().is_in_group("enemies"):
		if PlayerData.talents.get("bullet_pierce", false):
			# 🌟 穿透天賦邏輯：
			# 因為 Hurtbox 會自動將子彈的 is_spent 設為 true 以防止同幀重複扣血，
			# 這裡將其重設為 false，確保子彈能繼續對下一個穿透的敵人造成傷害！
			is_spent = false
		else:
			# 沒有穿透天賦則直接銷毀
			queue_free()

# 自訂繪製：黃色圓形子彈
func _draw() -> void:
	# 恢復原本的黃色圓形子彈繪製
	draw_circle(Vector2.ZERO, 4.0, Color.YELLOW)
