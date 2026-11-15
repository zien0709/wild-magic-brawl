# res://Entities/Objects/WoodenBox.gd
# [木箱 / Wooden Box]
# 繼承 ThrowableBase，代表可被抓取、投擲的木箱。
# 設定重量與弧度係數以調整投擲手感。
extends ThrowableBase

# 節點就緒：呼叫父類初始化，設定木箱重量與弧度
func _ready() -> void:
	super._ready()
	# 預設木箱重量
	weight = 1.2
	arc_height_multiplier = 1.0
