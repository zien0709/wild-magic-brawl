# res://Modes/PortalModeHandler.gd
# 傳送門模式處理器
# 處理原本 GameLevel 的 THREE_STAGE_PROGRESSION
class_name PortalModeHandler
extends BaseModeHandler

var current_level_data: LevelData

func initialize(data: LevelData, map: Node2D) -> void:
	current_level_data = data
	var portal_speed = data.extra_params.get("portal_speed", 200.0)
	print("🔮 傳送門模式載入，速度設定為：", portal_speed)
	
	var spawner = map.get_node_or_null("EnemySpawner")
	if spawner and spawner.has_method("configure"):
		spawner.configure(data.enemy_list, data.enemy_count)
	
	# 🟢 修正：將原本錯誤的 enemy_died 改成與 GameEvents 宣告一致的 enemy_killed
	if GameEvents.has_signal("enemy_killed"):
		GameEvents.enemy_killed.connect(_on_enemy_killed_rules)

func _on_enemy_killed_rules(_exp_reward: int) -> void:
	print("🔮 傳送門模式：收到怪物被擊殺廣播，處理內部分數或生成新傳送門邏輯。")
