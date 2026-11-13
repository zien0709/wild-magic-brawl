# res://Modes/PortalModeHandler.gd
# [傳送門模式處理器 / Portal Mode Handler]
# 處理「三階段進度」模式：傳送門1 -> 移動傳送門2 -> 打完 Boss 拿 3 旗。
# 對應原本 GameLevel 的 THREE_STAGE_PROGRESSION 邏輯。
class_name PortalModeHandler
extends BaseModeHandler

# 當前關卡設定（執行期參考）
var current_level_data: LevelData

# 初始化：讀取傳送門速度、綁定刷怪器與擊殺事件
# data = LevelData, map = 地圖根節點
func initialize(data: LevelData, map: Node2D) -> void:
	current_level_data = data
	# 從 extra_params 讀取傳送門速度（預設 200.0）
	var portal_speed = data.extra_params.get("portal_speed", 200.0)
	print("🔮 傳送門模式載入，速度設定為：", portal_speed)
	
	# 若地圖上有 EnemySpawner，注入怪物清單與數量
	var spawner = map.get_node_or_null("EnemySpawner")
	if spawner and spawner.has_method("configure"):
		spawner.configure(data.enemy_list, data.enemy_count)
	
	# 🟢 修正：將原本錯誤的 enemy_died 改成與 GameEvents 宣告一致的 enemy_killed
	if GameEvents.has_signal("enemy_killed"):
		GameEvents.enemy_killed.connect(_on_enemy_killed_rules)

# 接收怪物被擊殺的廣播，處理內部分數或生成新傳送門邏輯
func _on_enemy_killed_rules(_exp_reward: int) -> void:
	print("🔮 傳送門模式：收到怪物被擊殺廣播，處理內部分數或生成新傳送門邏輯。")
