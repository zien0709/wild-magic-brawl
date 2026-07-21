# res://Entities/Bullet.gd
extends Hitbox

var speed: float = 0.0
var direction: Vector2 = Vector2.RIGHT

# 🎯 恢復被武器系統呼叫的初始化函式
func setup(p_direction: Vector2, p_damage: int, p_speed: float) -> void:
	direction = p_direction.normalized()
	damage = p_damage
	speed = p_speed

func _ready() -> void:
	# 綁定牆壁碰撞與區域碰撞
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)	
	
	# 安全機制：3秒內沒打中任何東西自動銷毀，免得記憶體爆炸
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	# 讓子彈朝著設定的方向飛過去
	position += direction * speed * delta

func _on_body_entered(_body: Node2D) -> void:
	# 撞擊到牆壁等環境物理主體時直接銷毀
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox and area.get_parent():
		var parent = area.get_parent()
		if parent.is_in_group("enemies"):
			if PlayerData.talents.get("bullet_pierce", false):
				# 🌟 穿透天賦邏輯：
				# 因為 Hurtbox 會自動將子彈的 is_spent 設為 true 以防止同幀重複扣血，
				# 這裡將其重設為 false，確保子彈能繼續對下一個穿透的敵人造成傷害！
				is_spent = false
			else:
				# 沒有穿透天賦則直接銷毀
				queue_free()
		elif parent.is_in_group("player"):
			queue_free()

func _draw() -> void:
	# 恢復原本的黃色圓形子彈繪製
	draw_circle(Vector2.ZERO, 4.0, Color.YELLOW)
