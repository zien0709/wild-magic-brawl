# res://Core/LevelManager.gd
# [AutoLoad] 唯一的全域關卡組裝中心
extends Node

# 預載戰鬥 UI，待會地圖載入成功後要疊加在畫面上
var hud_scene: PackedScene = preload("res://Scenes/UI/GameHUD.tscn")
var player_scene: PackedScene = preload("res://Entities/Player/Player.tscn")


var current_spawned_count: int = 0


func _ready():
	if GameEvents.has_signal("enemy_killed"):
		GameEvents.enemy_killed.connect(_on_global_enemy_killed)

func _on_global_enemy_killed(xp: int):
	PlayerData.gain_exp(xp)
	# 動態尋找場上的 HUD 並發送擊殺通知
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("⚔️ 擊殺怪物! EXP +" + str(xp), Color.YELLOW)

## 核心組裝函式：負責卸載舊場景，注入新關卡
func load_career_level(level_data: LevelData) -> void:
	# ---- 步驟 1：安全防呆檢查（必須放在最前面） ----
	if level_data == null:
		push_error("❌ [LevelManager] 載入失敗：傳入的 LevelData 為 null！請確認 .tres 檔案是否存在且路徑正確。")
		return
		
	if level_data.map_path == "":
		push_error("❌ [LevelManager] 錯誤：LevelData 內未指定地圖場景路徑 (map_path)")
		return

	print("🎬 開始清空當前場景（如主選單）...")
	
	# ---- 步驟 2：清理舊世界（將當前主場景移出記憶體） ----
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.queue_free()

	# ---- 步驟 3：載入並實例化純地圖 ----
	var map_resource = load(level_data.map_path)
	if not map_resource:
		push_error("❌ 錯誤：找不到地圖檔案：" + level_data.map_path)
		return
		
	var map_instance = map_resource.instantiate()
	if not map_instance:
		push_error("❌ 錯誤：地圖實例化失敗！路徑：" + level_data.map_path)
		return
	get_tree().root.add_child(map_instance)
	get_tree().current_scene = map_instance  # 設定為當前主場景
	print("🗺️ 地圖載入成功：" + level_data.map_path)
	
	# 重設世界怪物計數
	current_spawned_count = 0
	
	# ---- 步驟 4：動態創建專屬的刷怪計時器（注入到地圖下） ----
	var spawn_timer = Timer.new()
	spawn_timer.name = "DynamicSpawnTimer"
	spawn_timer.wait_time = 2.0  # 刷怪間隔秒數（可改成隨你高興的時間）
	spawn_timer.one_shot = false # 循環觸發
	
	# 透過 Lambda 綁定超時訊號，並將必要的資料傳進去
	spawn_timer.timeout.connect(func(): _on_spawn_timer_timeout(level_data, map_instance))
	
	# 將計時器掛在地圖下，地圖被 queue_free 時它會自動一起消失
	map_instance.add_child(spawn_timer)
	spawn_timer.start()
	print("⏳ 動態刷怪計時器已啟動，間隔：", spawn_timer.wait_time, "秒")
	
	# ---- 步驟 5：動態生成並注入玩家角色 ----
	var player_instance = null
	if player_scene:
		player_instance = player_scene.instantiate()
		map_instance.add_child(player_instance)
		
		# 💡 防呆防卡：如果地圖裡面有設定出生點（Marker2D 節點叫 SpawnPoint），就把玩家移過去
		if map_instance.has_node("SpawnPoint"):
			player_instance.global_position = map_instance.get_node("SpawnPoint").global_position
		else:
			player_instance.global_position = Vector2.ZERO # 預設地圖原點
			
		print("🧍 玩家角色成功生成並注入地圖樹！群組生效中。")
	else:
		push_error("❌ 錯誤：LevelManager 找不到預載的 player_scene，無法生成玩家！")
		
	# ---- 步驟 6：動態生成關卡規則大腦 (Mode Handler) ----
	var handler: BaseModeHandler = null

	match level_data.mode_type:
		"FLAG":
			handler = FlagModeHandler.new()
		"PORTAL":
			handler = PortalModeHandler.new()
		_:
			print("⚠️ 未知模式，本關將作為沙盒自由探索。")

	# 如果有建立模式大腦，將其作為子節點掛在地圖下運作，並初始化
	if handler:
		map_instance.add_child(handler)
		handler.initialize(level_data, map_instance)
		print("🧠 關卡規則大腦組裝完畢：[" + level_data.mode_type + "]")

	# ---- 步驟 7：自動把戰鬥 UI (GameHUD) 蓋在畫面上 ----
	if hud_scene:
		var hud_instance = hud_scene.instantiate()
		map_instance.add_child(hud_instance)
		print("📊 戰鬥 HUD 介面疊加完成！")
func _on_spawn_timer_timeout(level_data: LevelData, map_node: Node2D):
	# 安全機制：如果地圖或設定檔意外失效，就停止
	if not is_instance_valid(map_node) or level_data.enemy_list.is_empty():
		return
		
	# 檢查目前場上的怪物數量，避免無限複製導致電腦卡死

	var current_enemies = get_tree().get_nodes_in_group("enemies")
	if current_enemies.size() >= level_data.max_spawn_count:
		print("⚠️ 場上怪物已達上限 (", level_data.max_spawn_count, ")，本次暫停生成")
		return

	# 從 LevelData 的怪物清單中隨機抽選一隻怪物場景
	var random_index = randi() % level_data.enemy_list.size()
	var enemy_scene = level_data.enemy_list[random_index]
	
	if enemy_scene:
		var enemy_instance = enemy_scene.instantiate()
		
		# 確保怪物加入到 "enemies" 群組，以便上方進行數量控管
		enemy_instance.add_to_group("enemies")
		var player = get_tree().get_first_node_in_group("player")
		var spawn_pos = Vector2.ZERO
		# 計算怪物的生成位置（此處示範：隨機在畫面上某個範圍生成）
		# 實戰中你可以依據玩家目前的位置 (PlayerData) 加上一個偏移量，讓怪在玩家畫面外生成
		if player and is_instance_valid(player):
			# 圍繞玩家隨機旋轉一個角度，延伸 550 ~ 750 像素（剛好在標準螢幕視野外）
			var random_angle = randf() * TAU
			var random_distance = randf_range(550, 750)
			spawn_pos = player.global_position + Vector2.UP.rotated(random_angle) * random_distance
		else:
			# 如果場上沒玩家（防呆），才用預設隨機原點
			spawn_pos = Vector2(randf_range(100, 500), randf_range(100, 500))
			
		enemy_instance.global_position = spawn_pos # 使用 global_position 確保座標不因父節點偏移
		var current_hp_mult = level_data.extra_params.get("hp_multiplier", 1.0)
		var current_dmg_mult = level_data.extra_params.get("damage_multiplier", 1.0)

		if "spawner_hp_mult" in enemy_instance:
			enemy_instance.spawner_hp_mult = current_hp_mult
			enemy_instance.spawner_dmg_mult = current_dmg_mult
		# 將怪物新增為地圖的子節點
		map_node.add_child(enemy_instance)
		print("👾 成功生成怪物：", enemy_instance.name, " 座標：", spawn_pos)
