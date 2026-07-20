class_name DefensePromptUI
extends CanvasLayer
# res://UI/DefensePromptUI.gd

@export var prompt_offset: Vector2 = Vector2(0, -80)
@export var warning_distance: float = 150.0
@export var fade_speed: float = 3.0

var prompt_label: Label
var player: Node2D
var current_alpha: float = 0.0
var prompt_visible: bool = false
var camera: Camera2D

func _ready() -> void:
	layer = 10
	
	prompt_label = Label.new()
	prompt_label.text = "按 Q 格擋！"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 20)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	prompt_label.visible = false
	prompt_label.z_index = 100
	add_child(prompt_label)
	
	player = get_tree().get_first_node_in_group("player")
	camera = get_viewport().get_camera_2d()

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		prompt_label.visible = false
		return
	
	var should_show = _check_enemies_attacking()
	
	if should_show:
		current_alpha = min(1.0, current_alpha + delta * fade_speed)
	else:
		current_alpha = max(0.0, current_alpha - delta * fade_speed)
	
	if current_alpha > 0.01:
		prompt_label.visible = true
		prompt_label.modulate.a = current_alpha
		var world_pos = player.global_position + prompt_offset
		var canvas_transform = get_viewport().get_canvas_transform()
		prompt_label.global_position = canvas_transform * world_pos - Vector2(prompt_label.size.x / 2.0, 0)
	else:
		prompt_label.visible = false

func _check_enemies_attacking() -> bool:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_method("get"):
			continue
		
		# 檢查近戰敵人是否在前搖或攻擊中
		if "attack_state" in enemy:
			if enemy.attack_state == enemy.AttackState.WINDUP:
				var dist = player.global_position.distance_to(enemy.global_position)
				if dist <= warning_distance:
					return true
		
		# 檢查遠程敵人是否在前搖或攻擊中
		if "attack_state" in enemy:
			if enemy.attack_state == enemy.AttackState.WINDUP:
				var dist = player.global_position.distance_to(enemy.global_position)
				if dist <= warning_distance * 1.5:
					return true
	
	return false
