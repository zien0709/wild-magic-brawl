# res://Entities/Objects/WoodenBox.gd
extends ThrowableBase

func _ready() -> void:
	super._ready()
	# 預設木箱重量
	weight = 1.2
	arc_height_multiplier = 1.0
