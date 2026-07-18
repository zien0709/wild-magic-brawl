# Hurtbox.gd
class_name Hurtbox
extends Area2D

# 這裡用一個訊號，當被打中時，通知主人（玩家或怪物）
signal on_hit(damage_amount: int, hitbox: Area2D) # 🟢 調整為合規的小寫格式並新增 hitbox 參數

func _ready():
	# 自己綁定：當有別的 Area2D (必須是 Hitbox) 進入我的範圍時
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D):
	if area is Hitbox:
		# 🟢 檢查進入的 Hitbox 是否有「已被標記失效」的屬性
		if "is_spent" in area and area.is_spent:
			return # 如果這顆子彈這影格已經打過別的東西了，直接無視它，拒絕雙重扣血！
			
		# 標記這顆子彈已經消費過了
		if "is_spent" in area:
			area.is_spent = true
			
		on_hit.emit(area.damage, area)
