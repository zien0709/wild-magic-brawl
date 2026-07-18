class_name ThrowAimComponent
extends Node2D
# res://Entities/Player/ThrowAimComponent.gd

@export var snap_radius: float = 120.0 # 磁吸範圍半徑 (像素)

@onready var player = get_parent()

func _physics_process(_delta: float) -> void:
	if not player or not player.input_handler:
		return
		
	# 僅在玩家未抓取物件時，磁吸鎖定可丟擲物
	if player.grabbed_object == null:
		var target = get_best_throwable_target()
		if target:
			# 將虛擬瞄準點吸附到目標物件上
			player.input_handler.aim_position = target.global_position

func get_best_throwable_target() -> ThrowableBase:
	var aim_pos = player.input_handler.aim_position
	var objects = get_tree().get_nodes_in_group("interactable_objects")
	
	var best_target: ThrowableBase = null
	var highest_weight: float = -1.0
	var closest_dist: float = INF
	
	for obj in objects:
		if not is_instance_valid(obj) or not (obj is ThrowableBase) or obj.is_grabbed:
			continue
			
		var dist = aim_pos.distance_to(obj.global_position)
		if dist <= snap_radius:
			# 權重高優先；權重相同則距離近優先
			if obj.weight > highest_weight:
				highest_weight = obj.weight
				best_target = obj
				closest_dist = dist
			elif abs(obj.weight - highest_weight) < 0.01:
				if dist < closest_dist:
					best_target = obj
					closest_dist = dist
					
	return best_target
