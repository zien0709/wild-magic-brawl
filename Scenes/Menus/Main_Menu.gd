# MainMenu.gd
extends Control

var talent_tree_instance: Control = null

func _on_start_button_pressed() -> void:
	print("🚀 冒險開始！載入遊戲世界...")
	LevelManager.load_career_level(load("res://Resources/Levels/Level_1_1.tres"))

func _on_talent_button_pressed() -> void:
	if talent_tree_instance:
		talent_tree_instance.queue_free()
		talent_tree_instance = null
		return
	var tscn = load("res://Scenes/UI/TalentTreeUI.tscn")
	if not tscn:
		return
	talent_tree_instance = tscn.instantiate()
	talent_tree_instance.talent_resources = [
		load("res://Resources/Talents/bullet_pierce.tres"),
		load("res://Resources/Talents/energy_regen_up.tres"),
		load("res://Resources/Talents/shield_hp.tres")
	]
	add_child(talent_tree_instance)
	talent_tree_instance.position = (get_viewport_rect().size - talent_tree_instance.size) / 2

func _on_quit_button_pressed() -> void:
	print("🚪 關閉遊戲。")
	get_tree().quit()
