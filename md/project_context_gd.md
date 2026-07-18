# [荒野魔法亂鬥遊戲專案] Project Context File: .gd

## res://

### Core

**GameEvents.gd**
```gdscript
# res://Core/GameEvents.gd
# [AutoLoad] 全域事件總線
extends Node

# 傳遞怪物死亡與經驗值
signal enemy_killed(exp_reward: int)

# 傳遞玩家核心數值變化
signal player_health_changed(current: int, max_hp: int)
signal player_energy_changed(current: float, max_energy: float)

```

**HapticManager.gd**
```gdscript
# res://Core/HapticManager.gd
extends Node

# 預設玩家 1 的裝置 ID 是 0
var default_device: int = 0

## 🛡️ Q護盾：完美反彈 (極短、高頻清脆)
func play_perfect_parry(device: int = default_device) -> void:
	# 強馬達 0.0 (不要沉重感) / 弱馬達 0.9 (極高頻) / 持續 0.12 秒
	Input.start_joy_vibration(device, 0.9, 0.0, 0.12)

## 🎯 QTE：成功停在 C 區 (柔和、舒服的回饋)
func play_qte_success(device: int = default_device) -> void:
	# 強馬達 0.2 / 弱馬達 0.4 / 持續 0.15 秒，輕微點一下的感覺
	Input.start_joy_vibration(device, 0.4, 0.2, 0.15)

## ❌ QTE：手殘失敗 (雙馬達打架狂震、極強肉體懲罰感)
func play_qte_failed(device: int = default_device) -> void:
	# 雙馬達直接全開 1.0 / 持續 0.5 秒，製造強烈的挫敗手感
	Input.start_joy_vibration(device, 1.0, 1.0, 0.5)

## 💔 額外追加：能量歸零/破產瞬間的特殊震動 (脈衝式抽搐感)
func play_energy_bankrupt(device: int = default_device) -> void:
	Input.start_joy_vibration(device, 0.8, 0.3, 0.3)

## 🛑 強制停止所有震動 (例如玩家突然按 Pause 暫停遊戲時呼叫)
func stop_all_vibration(device: int = default_device) -> void:
	Input.stop_joy_vibration(device)

```

**LevelManager.gd**
```gdscript
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

```

**PlayerData.gd**
```gdscript
# PlayerData.gd (全域管理，不掛載在任何特定場景上)
# [AutoLoad] 永久存檔管理
# res://Core/PlayerData.gd
extends Node
# 💾 本地硬碟存檔路徑 (Godot 自動對應至 AppData/Roaming 等安全位置)
const SAVE_FILE_PATH = "user://savegame.json"
# 📊 玩家核心屬性（生涯永久進度）
var account_level: int = 1
var account_exp: int = 0
var exp_to_next_level: int = 100
# 🪙 貨幣（如果有的話）
var gold: int = 0
# 🏁 玩家目前的生涯進度
var total_flags: int = 0
var unlocked_chapters = ["chapter_1"] # 一開始只解鎖第一章

# 🗺️ 整個遊戲的生涯關卡資料庫 (結構樹)
var career_data = {
	"chapter_1": {
		"chapter_name": "荒野起步",
		"is_unlocked": true,
		"levels": {
			"level_1_1": {
				"level_name": "初試身手",
				"flags_earned": 0,
				"max_flags": 3,
				"scene_path": "res://Scenes/Maps/Map_Level_1_1.tscn", # 👈 新地圖指到這裡！
				"reward_chapter": ""
			},
			"level_1_2": {
				"level_name": "傳送門試煉",
				"flags_earned": 1,
				"scene_path": "res://Scenes/Maps/Map_Level_1_2.tscn", # 👈 新增地圖只要加這行！
				"reward_chapter": ""
			},
			"level_1_3": {
				"level_name": "全新大冒險", # 可以自己改名
				"flags_earned": 2,
				"max_flags": 3,
				"scene_path": "res://Scenes/Maps/Map_Level_1_3.tscn",
				"reward_chapter": "chapter_2"
				}
		}
	},
	"chapter_2": {
		"chapter_name": "第二章：狂野荒原", # 👈 統一使用 chapter_name
		"is_unlocked": false,
		"levels": {
			"level_2_1": { 
				"level_name": "荒原狂飆", 
				"scene_path": "res://Scenes/Maps/Map_Level_2_1.tscn", 
				"flags_earned": 0, 
				"max_flags": 3, 
				"reward_chapter": "" 
			},
			"level_2_2": { 
				"level_name": "熔岩核心", 
				"scene_path": "res://Scenes/Maps/Map_Level_2_2.tscn", 
				"flags_earned": 0, 
				"max_flags": 3, 
				"reward_chapter": "chapter_3" 
			}
		}
	}
}

	

# 🎯 當玩家通關並獲得旗幟時呼叫
func complete_level(chapter_id: String, level_id: String, flags_won: int):
	if not career_data.has(chapter_id) or not career_data[chapter_id]["levels"].has(level_id):
		print("❌ 錯誤：找不到指定的章節或關卡！")
		return
		
	var level = career_data[chapter_id]["levels"][level_id]
	
	# 如果這次拿到的旗幟比以前多，才更新
	if flags_won > level["flags_earned"]:
		var diff = flags_won - level["flags_earned"]
		level["flags_earned"] = flags_won
		total_flags += diff # 增加總旗幟數
	
	# 🌟 核心解鎖邏輯：如果這一關有「解鎖新章節」的獎勵，且拿到了至少 1 面旗幟（算通關）
	if level.get("reward_chapter", "") != "" and flags_won > 0:
		var target_chapter = level["reward_chapter"]
		
		# 1. 塞入解鎖列表
		if not unlocked_chapters.has(target_chapter):
			unlocked_chapters.append(target_chapter)
			print("🎉 傳奇解鎖！獲得新章節鑰匙：", target_chapter)
		
		# 2. 同步更新資料庫內的布林值（防呆、避免 UI 不同步）
		if career_data.has(target_chapter):
			career_data[target_chapter]["is_unlocked"] = true
	save_game()
# 🎯 天賦系統（用 Dictionary 記錄解鎖狀態）
var talents = {
	"double_dash": false,     # 是否能連續衝刺兩次
	"shield_hp": 0,          # 護盾強化等級
	"energy_regen_up": false,
	"bullet_pierce": false,   # 子彈是否穿透
	"bullet_split": false
}
# 🌟 遊戲啟動時自動讀檔
func _ready() -> void:
	load_game()
# ─── 💾 核心存檔邏輯 (同時相容本地與未來 EOS 雲端) ───

# 1. 把所有資料打包成一個乾淨的字典 (Serialization)
func create_save_dictionary() -> Dictionary:

	var save_dict = {
		"account_level": account_level,
		"account_exp": account_exp,
		"exp_to_next_level": exp_to_next_level,
		"total_flags": total_flags,
		"gold": gold,
		"talents": talents,
		"unlocked_chapters": unlocked_chapters,
		"flags_data": {}
	}
	
	# 🟢 安全的防護改法：完全根據 career_data 現有的結構來導出存檔
	# 這樣就算你玩了某個測試關卡，存檔系統也不會因為硬生資料而崩潰
	for ch_id in career_data.keys():
		var ch_data = career_data[ch_id]
		if ch_data.has("levels"):
			for lvl_id in ch_data["levels"].keys():
				save_dict["flags_data"][lvl_id] = ch_data["levels"][lvl_id]["flags_earned"]
				
	return save_dict
# 2. 寫入硬碟
func save_game() -> void:
	var save_dict = create_save_dictionary()
	var json_string = JSON.stringify(save_dict) # 轉成字串
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("💾 存檔成功！已寫入實體硬碟路徑: ", ProjectSettings.globalize_path(SAVE_FILE_PATH))
		
		# 💡 未來串接 EOS 的地方：
		# if EOS.is_logged_in(): 
		#     EOS.PlayerDataStorage.save_file("mysave.json", json_string)

# 3. 從硬碟讀取
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("ℹ️ 找不到存檔，將以全新進度開始遊戲。")
		return
		
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.get_data()
			
			# 🎯 將解開的資料倒回變數中 (Deserialization)
			account_level = data.get("account_level", 1)
			account_exp = data.get("account_exp", 0)
			exp_to_next_level = data.get("exp_to_next_level", 100)
			total_flags = data.get("total_flags", 0)
			unlocked_chapters = data.get("unlocked_chapters", ["chapter_1"])
			talents = data.get("talents", talents)
			gold = data.get("gold", 0)
			# 🟢 安全、動態的關卡還原邏輯
			var flags_data = data.get("flags_data", {})
			for lvl_id in flags_data.keys():
				var found = false
				
				# 遍歷所有章節，動態尋找這個 level_id 屬於哪一章
				for ch_id in career_data.keys():
					if career_data[ch_id]["levels"].has(lvl_id):
						career_data[ch_id]["levels"][lvl_id]["flags_earned"] = flags_data[lvl_id]
						found = true
						break # 找到了就跳出內層迴圈
						
				if not found:
					print("⚠️ 警告：存檔中有關卡 ", lvl_id, " 的資料，但當前遊戲資料庫中找不到該關卡。")	
			# 根據解鎖列表還原大章節的 is_unlocked
			for ch_id in unlocked_chapters:
				if career_data.has(ch_id):
					career_data[ch_id]["is_unlocked"] = true
					
			print("📂 存檔讀取成功！歡迎回來，等級: ", account_level)
		else:
			print("❌ 存檔損毀，解析 JSON 失敗。")

# 📈 獲得經驗值的函數
func gain_exp(amount: int):
	account_exp += amount
	print("獲得經驗值：", amount, " 目前經驗：", account_exp, "/", exp_to_next_level)
	
	# 🔄 使用 while 防止暴漲的經驗值卡住連續升級
	while account_exp >= exp_to_next_level:
		level_up()
	save_game()

# 🆙 升級！
func level_up():
	account_exp -= exp_to_next_level
	account_level += 1
	exp_to_next_level = int(exp_to_next_level * 1.5) # 下一級需要更多經驗
	print("🎉 恭喜升級！目前等級：", account_level)
	# 🎯 呼叫 HUD 跳出全滿升級通知！
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_notification("🎉🎉 LEVEL UP! 目前等級: " + str(account_level) + " 🎉🎉", Color.GREEN)
		
	save_game()                  # 💾 升級完順便存檔！
	
	

```

### Entities

**Bullet.gd**
```gdscript
# res://Entities/Bullet.gd
extends Hitbox

var speed: float = 0.0

# 🎯 恢復被武器系統呼叫的初始化函式
func setup(p_speed: float, p_damage: int) -> void:
	speed = p_speed
	damage = p_damage

func _ready() -> void:
	# 綁定牆壁碰撞與區域碰撞
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# 安全機制：3秒內沒打中任何東西自動銷毀，免得記憶體爆炸
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	# 讓子彈朝著它面向的方向（X軸正向）飛過去
	position += transform.x * speed * delta

func _on_body_entered(_body: Node2D) -> void:
	# 撞擊到牆壁等環境物理主體時直接銷毀
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	# 偵測到對方是 Hurtbox 且屬於敵人時
	if area is Hurtbox and area.get_parent() and area.get_parent().is_in_group("enemies"):
		if PlayerData.talents.get("bullet_pierce", false):
			# 🌟 穿透天賦邏輯：
			# 因為 Hurtbox 會自動將子彈的 is_spent 設為 true 以防止同幀重複扣血，
			# 這裡將其重設為 false，確保子彈能繼續對下一個穿透的敵人造成傷害！
			is_spent = false
		else:
			# 沒有穿透天賦則直接銷毀
			queue_free()

func _draw() -> void:
	# 恢復原本的黃色圓形子彈繪製
	draw_circle(Vector2.ZERO, 4.0, Color.YELLOW)

```

#### Combat

**Hitbox.gd**
```gdscript
# Hitbox.gd
class_name Hitbox
extends Area2D

@export var damage: int = 1
var is_spent: bool = false

```

**Hurtbox.gd**
```gdscript
# Hurtbox.gd
class_name Hurtbox
extends Area2D

# 這裡用一個訊號，當被打中時，通知主人（玩家或怪物）
signal on_hit(damage_amount: int) # 🟢 調整為合規的小寫格式

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
			
		on_hit.emit(area.damage)

```

**WeaponHandler.gd**
```gdscript
# res://Entities/Combat/WeaponHandler.gd
extends Node2D

@export var data: WeaponResource 
var current_bullets: int
var can_fire: bool = true
var is_reloading: bool = false

# 抓取武器圖片節點
@onready var sprite: Sprite2D = $WeaponSprite
@onready var timer: Timer = Timer.new()

func _ready():
	add_child(timer)
	if data:
		setup_weapon()

func setup_weapon():
	current_bullets = data.bullet_count
	
	# 當換武器時，自動把 Resource 裡的圖片換上去
	if data.texture:
		sprite.texture = data.texture
	print("武器已就緒：", data.name)

# 🎯 [修正] 移除重複的宣告與整個 _process 邏輯
# 這個函式現在完全交由外面的 player.gd 來呼叫，並傳入不論是鍵鼠還是手把的瞄準點
func aim_at_position(target_global_pos: Vector2) -> void:
	look_at(target_global_pos)
	
	# 翻轉貼圖邏輯（以武器自身的 global_position 判斷目標在左邊還是右邊）
	if global_position.x > target_global_pos.x:
		sprite.flip_v = true
	else:
		sprite.flip_v = false

func reload():
	if is_reloading: 
		return
		
	print("🔄 換彈中...")
	is_reloading = true
	
	# 等待資源檔設定的換彈時間
	await get_tree().create_timer(data.reload_time).timeout
	
	current_bullets = data.bullet_count
	is_reloading = false
	can_fire = true # 確保換彈完，開火開關要重新打開！
	print("✅ 換彈完成！目前子彈：", current_bullets)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.update_ammo(current_bullets, "∞")

func fire(target_global_pos: Vector2, pos: Vector2):
	if not can_fire or is_reloading:
		return
	if current_bullets <= 0:
		print("彈藥耗盡！觸發自動換彈！")
		reload() 
		return   
		
	var bullet = data.bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = pos
	
	bullet.global_rotation = global_rotation
	
	bullet.setup(data.bullet_speed, data.damage)
	
	current_bullets -= 1
	
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.update_ammo(current_bullets, "∞")
		
	can_fire = false
	timer.start(data.cooldown)
	await timer.timeout
	can_fire = true

```

#### Enemy

**enemy.gd**
```gdscript
# res://Entities/enemy.gd
extends CharacterBody2D

@export var base_speed: float = 150.0
@export var base_max_hp: int = 3
@export var base_damage: int = 1
@export var base_exp_reward: int = 20

# 建立兩個暫存變數，用來接收 Spawner 傳進來的環境倍率
var spawner_hp_mult: float = 1.0
var spawner_dmg_mult: float = 1.0

var player = null
var speed: float
var max_hp: int
var current_hp: int
var damage: int
var exp_reward: int 

func _ready():

	player = get_tree().get_first_node_in_group("player")
	
	scale_monster_stats("chapter_1") 

	current_hp = max_hp
	if has_node("EnemyHealthBar"):
		$EnemyHealthBar.max_value = max_hp
		$EnemyHealthBar.value = current_hp

func scale_monster_stats(current_chapter: String) -> void:
	var level_modifier: float = 1.0 + (PlayerData.account_level - 1) * 0.1
	var chapter_modifier: float = 1.0
	if current_chapter == "chapter_2":
		chapter_modifier = 2.0
	elif current_chapter == "chapter_3":
		chapter_modifier = 3.5
		
	# 完美融合：玩家等級補正 * 章節補正 * Spawner難度注入
	max_hp = int(base_max_hp * level_modifier * chapter_modifier * spawner_hp_mult)
	damage = int(base_damage * level_modifier * chapter_modifier * spawner_dmg_mult)
	exp_reward = int(base_exp_reward * level_modifier) 
	speed = base_speed

func _physics_process(_delta):
	if player:
		var direction = global_position.direction_to(player.global_position)
		velocity = direction * speed
		move_and_slide()

func _on_enemy_hurtbox_on_hit(damage_amount: int):
	current_hp -= damage_amount
	if has_node("EnemyHealthBar"):
		$EnemyHealthBar.value = current_hp
	if current_hp <= 0:
		die()
		
func die():
	# 🟢 改為透過全域事件流廣播，不直接依賴外面的 HUD 節點與 PlayerData 腳本
	GameEvents.enemy_killed.emit(exp_reward)
	queue_free()

```

#### Objects

**WoodenBox.gd**
```gdscript
# res://Entities/Objects/WoodenBox.gd
extends RigidBody2D

var is_grabbed: bool = false
var grabber: Node2D = null

func _physics_process(delta):
	if is_grabbed and is_instance_valid(grabber):
		# 物理吸力：計算箱子到玩家的向量，用物理力量拉過去
		var direction = global_position.direction_to(grabber.global_position)
		var distance = global_position.distance_to(grabber.global_position)
		
		# 距離越遠拉力越強，靠近時減速懸浮在玩家身邊
		linear_velocity = direction * distance * 10.0

# 被玩家吸取
func grab(target: Node2D):
	is_grabbed = true
	grabber = target
	collision_mask = 0 # 暫時關閉與其他牆壁的碰撞，免得卡在半路

# 被玩家丟出去
func throw(direction: Vector2, force: float = 1200.0):
	is_grabbed = false
	grabber = null
	collision_mask = 1 # 恢復碰撞
	
	# 給予強大的瞬間衝量砸出去！
	apply_central_impulse(direction * force)

```

#### Player

**player.gd**
```gdscript
# player.gd
extends CharacterBody2D
var input_handler: InputComponent
# 📣 定義訊號：當血量或能量改變時，通知任何想聽的 UI
signal health_changed(current: int, max_hp: int)
signal energy_changed(current: float, max_energy: float)

@onready var weapon = $WeaponHandler # 確保節點路徑正確
@export var speed: float = 300.0 
@export var max_hp: int = 10     # 最大血量（可以由右邊屬性面板直接改）
var current_hp: int = 0         # 當前血量

# === 🌪️ Cril 加速瞬移系統變數 ===
@export var max_energy: float = 100.0
var current_energy: float = 100.0

@export var normal_speed: float = 200.0  # 正常走路速度
@export var dash_speed: float = 600.0    # 衝鋒瘋狂速度

@export var dash_energy_cost: float = 30.0  # 每次閃避消耗的固定能量
@export var dash_duration: float = 0.58

#@export var energy_drain: float = 50.0   # 每秒消耗多少能量（50 代表長按 2 秒噴光）
@export var energy_regen: float = 25.0   # 每秒恢復多少能量（25 代表 4 秒充飽）

var dash_time_left: float = 0.0             # 衝刺剩餘時間倒數
var dash_direction: Vector2 = Vector2.ZERO  # 鎖定衝刺時的方向

var is_dashing: bool = false

var grabbed_object: RigidBody2D = null

@onready var hurtbox = $PlayerHurtbox


func _ready():
	current_hp = max_hp         # 遊戲一開始，把血量補滿
	# 🟢 核心防呆：如果沒有從外部注入控制器，預設給他鍵盤控制器
	if not input_handler:
		input_handler = InputComponent.new()
		add_child(input_handler)
	health_changed.emit(current_hp, max_hp)
	energy_changed.emit(current_energy, max_energy)
	
	if PlayerData.talents["energy_regen_up"] == true:
		energy_regen = 30.0 # 點了天賦回復變快 (原本可能是 15.0)
	else:
		energy_regen = 15.0

func _on_player_hurtbox_on_hit(damage_amount: int):
	current_hp -= damage_amount
	print("💥 玩家痛痛！遭受傷害：", damage_amount)
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		die()

func _physics_process(delta):
	if not input_handler: return
	
	# 1. 更新目前控制器輸入的數據
	input_handler.update_input()
	
	# 2. 處理衝刺與能量消耗邏輯
	if is_dashing:
		dash_time_left -= delta
		if dash_time_left <= 0:
			end_dash()
	else:
		if current_energy < max_energy:
			current_energy += energy_regen * delta
			if current_energy > max_energy: 
				current_energy = max_energy
	
	if input_handler.is_dashing and current_energy >= dash_energy_cost:
		start_dash()
			
	energy_changed.emit(current_energy, max_energy)
	
	# 🛠️ [重構] 箱子丟擲方向：改用 input_handler 的瞄準點計算
	if input_handler.is_interacting:
		if grabbed_object == null:
			_try_grab_object()
		else:
			var throw_dir = (input_handler.aim_position - global_position).normalized()
			grabbed_object.throw(throw_dir)
			grabbed_object = null

	var current_speed = dash_speed if is_dashing else normal_speed
	velocity = input_handler.move_direction * current_speed
	move_and_slide()

	# 🛠️ [重構] 處理武器瞄準與開火
	if weapon:
		# 每一影格都把控制器的瞄準點注入給武器
		weapon.aim_at_position(input_handler.aim_position)
		
		if input_handler.is_shooting:
			var muzzle = weapon.get_node_or_null("WeaponSprite/Muzzle")
			var muzzle_pos = muzzle.global_position if muzzle else global_position
			# 傳入控制器的瞄準點
			weapon.fire(input_handler.aim_position, muzzle_pos)
			
		if input_handler.is_reloading:
			weapon.reload()
			
	RenderingServer.global_shader_parameter_set("player_position", global_position)
	
func start_dash():
	is_dashing = true
	dash_time_left = dash_duration  # 重設倒數時間
	current_energy -= dash_energy_cost  # 直接扣除固定能量
	
	# 🔴 核心鎖定：記錄按下瞬間的方向
	if input_handler.move_direction != Vector2.ZERO:
		dash_direction = input_handler.move_direction.normalized()
	#else:
		#dash_direction = input_handler.move_direction
		
	modulate = Color(1, 2, 2, 0.6) # 讓玩家角色變亮、變透明（很有特效感！）
	
	# 🔴 核心防呆：關掉受傷盒的監聽，達成「絕對無敵」！

	hurtbox.set_deferred("monitoring", false)   # 玩家不再偵測怪物攻擊
	hurtbox.set_deferred("monitorable", false)  # 怪物攻擊也穿透玩家、偵測不到玩家
	set_collision_mask_value(7, false)
	set_collision_layer_value(2, false)
# === 🛑 結束 Cril 加速瞬移 ===
func end_dash():
	is_dashing = false
	modulate = Color(1, 1, 1, 1) # 恢復正常顏色
	

	# 🔴 恢復正常：重新打開受傷盒，讓玩家可以再次被怪打到
	hurtbox.set_deferred("monitoring", true)
	hurtbox.set_deferred("monitorable", true)
	set_collision_mask_value(7, true)
	set_collision_layer_value(2, true)
	
func _try_grab_object():
	var bodies = $TelekinesisZone.get_overlapping_bodies()
	var closest_dist = INF
	
	for body in bodies:
		if body.is_in_group("interactable_objects"):
			var dist = global_position.distance_squared_to(body.global_position)
			if dist < closest_dist:
				closest_dist = dist
				grabbed_object = body
				
	if grabbed_object:
		grabbed_object.grab(self) # 把自己(玩家)傳過去當作吸引目標
	
func die():
	print("玩家死亡！")
	queue_free()

```

### Modes

**BaseModeHandler.gd**
```gdscript
# res://Modes/BaseModeHandler.gd
# 模式基底類別
class_name BaseModeHandler
extends Node

# 虛擬函式，強迫所有子模式遵守統一的初始化接口
func initialize(_data: LevelData, _map: Node2D) -> void:
	pass

```

**FlagModeHandler.gd**
```gdscript
# res://Modes/FlagModeHandler.gd
# 旗幟模式處理器
# 處理原本 GameLevel 的 SINGLE_STAGE_ACHIEVEMENT
class_name FlagModeHandler
extends BaseModeHandler

var target_kills: int = 10
var current_kills: int = 0
var current_level_data: LevelData

func initialize(data: LevelData, map: Node2D) -> void:
	current_level_data = data
	target_kills = data.extra_params.get("target_kills", 10)
	
	# 對接 Spawner 節點
	var spawner = map.get_node_or_null("EnemySpawner")
	if spawner and spawner.has_method("configure"):
		spawner.configure(data.enemy_list, data.enemy_count)
		
	# 監聽全域事件總線
	if GameEvents.has_signal("enemy_killed"):
		GameEvents.enemy_killed.connect(_on_enemy_killed)

func _on_enemy_killed(_exp_reward: int) -> void:
	current_kills += 1
	print("🏁 旗幟模式進度：", current_kills, "/", target_kills)
	if current_kills >= target_kills:
		print("🎉 達到目標擊殺數！結算關卡！")
		PlayerData.complete_level(current_level_data.chapter_id, current_level_data.level_id, 3)

```

**PortalModeHandler.gd**
```gdscript
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

```

### Scenes

#### Menus

**Main_Menu.gd**
```gdscript
# MainMenu.gd
extends Control

# 當點擊「開始遊戲」時觸發
func _on_start_button_pressed() -> void:
	print("🚀 冒險開始！載入遊戲世界...")
	# 這裡就是「載入地圖與遊戲」的關鍵時機！
	LevelManager.load_career_level(load("res://Resources/Levels/Level_1_1.tres"))

# 當點擊「離開遊戲」時觸發
func _on_quit_button_pressed() -> void:
	print("🚪 關閉遊戲。")
	get_tree().quit() # 關閉遊戲程式

```

#### UI

**GameHUD.gd**
```gdscript
#res://Scenes/UI/GameHUD.gd
extends CanvasLayer

# 🎯 用你的實際節點路徑（請根據編輯器右側微調）
@onready var health_bar = $PlayerHealthBar  # 如果你的名字叫 HealthBar 就改成 $HealthBar
@onready var energy_bar = $DashEnergyBar  # 如果名字叫 EnergyBar 就改成 $EnergyBar
@onready var ammo_label: Label = $RightTopContainer/WeaponHUD/HBoxContainer/AmmoLabel
@onready var weapon_icon: TextureRect = $RightTopContainer/WeaponHUD/HBoxContainer/WeaponIcon
@onready var notification_box: VBoxContainer = $LeftTopContainer/NotificationBox
# --- 新增控制佇列的變數 ---
var notification_queue: Array = []  # 存放等待顯示的訊息佇列
var is_processing_queue: bool = false  # 記錄目前是否正在播放訊息
const MSG_INTERVAL: float = 0.3  # 每條訊息跳出來的間隔時間（秒）

func _ready() -> void:
	add_to_group("hud")
	# 剛進入遊戲時，先把通知欄清空
	for child in notification_box.get_children():
		child.queue_free()
	# 🕒 安全機制：等一個 frame，確保玩家已經在場景中生成完畢
	await get_tree().process_frame

	# 🕵️‍♂️ 透過 Group 自動在全場景尋找玩家，完全不需要知道路徑！
	var player = get_tree().get_first_node_in_group("player")
	
	if player:
		
		player.health_changed.connect(_on_player_health_changed)
		player.energy_changed.connect(_on_player_energy_changed)
		_on_player_health_changed(player.current_hp, player.max_hp)
		_on_player_energy_changed(player.current_energy, player.max_energy)
		
		print("✅ HUD 初始化成功，已主動同步初始血量（", player.current_hp, "/", player.max_hp, "）")

	else:
		print("❌ HUD 找不到玩家，請檢查 Player 節點是否有加入 'player' 群組")
	if player and player.has_node("WeaponHandler"):
		var weapon_handler = player.get_node("WeaponHandler")
		
		# 🎯 核心：直接讀取 WeaponHandler 裡面的 WeaponResource (data)
		if weapon_handler and weapon_handler.data:
			var weapon_data = weapon_handler.data
			
			# 🖼️ 自動載入圖片！Resource 裝哪把槍，UI 就變哪張圖
			if weapon_data.texture:
				weapon_icon.texture = weapon_data.texture
			
			# 初始子彈數更新
			update_ammo(weapon_handler.current_bullets, "∞")
	

# 🩸 當玩家發射 health_changed 訊號時，會自動執行這裡
func _on_player_health_changed(current: int, max_hp: int):
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current

# ⚡ 當玩家發射 energy_changed 訊號時，會自動執行這裡
func _on_player_energy_changed(current: float, max_energy: float):
	if energy_bar:
		energy_bar.max_value = max_energy
		energy_bar.value = current
# 🔄 更新子彈 UI 的函式 (供玩家或武器腳本呼叫)
func update_ammo(current: int, reserve: String) -> void:
	ammo_label.text = str(current) + " / " + reserve

# 📣 核心功能：只負責把訊息丟進排隊名單
func show_notification(text: String, color: Color = Color.WHITE) -> void:
	# 1. 將訊息資料包成字典，塞進排隊陣列
	notification_queue.append({"text": text, "color": color})
	
	# 2. 如果目前沒有人在播放動畫，就啟動排程器
	if not is_processing_queue:
		_process_notification_queue()

# ⚙️ 內部排程器：負責依序處理排隊中的訊息
func _process_notification_queue() -> void:
	# 如果隊伍空了，就收工
	if notification_queue.is_empty():
		is_processing_queue = false
		return
		
	is_processing_queue = true
	
	# 取出隊伍最前面的訊息
	var current_msg = notification_queue.pop_front()
	
	# 3. 動態建立文字標籤（原本的邏輯）
	var new_label = Label.new()
	new_label.text = current_msg["text"]
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_label.add_theme_color_override("font_color", current_msg["color"])
	
	notification_box.add_child(new_label)
	
	# 4. Tween 動畫（原本的邏輯）
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(new_label, "position:y", new_label.position.y - 30, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(new_label, "modulate:a", 0.0, 1.6)
	tween.chain().tween_callback(new_label.queue_free)
	
	# 5. 🔥 核心魔法：等待設定的間隔時間後，自動呼叫自己處理下一條訊息
	await get_tree().create_timer(MSG_INTERVAL).timeout
	_process_notification_queue()

```

### Scripts

#### Components

**InputComponent.gd**
```gdscript
# res://Scripts/Components/InputComponent.gd
class_name InputComponent
extends Node

# 供 Player 與 Weapon 讀取的標準接口
var move_direction: Vector2 = Vector2.ZERO
var aim_position: Vector2 = Vector2.ZERO
var aim_direction: Vector2 = Vector2.RIGHT # 直接取得當前旋轉/瞄準方向（正規化向量）


var is_dashing: bool = false
var is_shooting: bool = false
var is_reloading: bool = false
var is_interacting: bool = false # 企劃書中的 M2 投擲
var is_protecting: bool = false  # 企劃書中的 Q 護盾

@export var joystick_deadzone: float = 0.2
var last_aim_direction: Vector2 = Vector2.RIGHT
var is_using_gamepad: bool = false

func _input(event: InputEvent) -> void:
	# 偵測到鍵盤按鍵、滑鼠點擊、滑鼠移動 -> 切換到鍵鼠模式
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		is_using_gamepad = false
	# 偵測到手把按鈕、搖桿推動 -> 切換到手把模式
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# 濾掉搖桿極輕微的飄移（死區），避免搖桿自然放開時的細微晃動誤觸手把模式
		if event is InputEventJoypadMotion and abs(event.axis_value) < joystick_deadzone:
			return
		is_using_gamepad = true

func update_input() -> void:
	var player = get_parent() as Node2D
	if not player: return

	# 1. 處理移動（左搖桿 或 WASD，在專案設定綁定同一個 Action）
	move_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# 2. 處理瞄準方向
	var joystick_dir = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if is_using_gamepad:
		# 🎮 手把模式
		if joystick_dir.length() > joystick_deadzone:
			aim_direction = joystick_dir.normalized()
			last_aim_direction = aim_direction
		else:
			# 放開搖桿時，維持最後一次瞄準的方向，避免武器彈回預設右邊
			aim_direction = last_aim_direction
			
		# 核心魔法：計算出全域的虛擬瞄準點，讓原本吃 Position 的舊程式碼（如 look_at）不會壞掉
		aim_position = player.global_position + aim_direction * 200.0
	else:
		# ⌨️ 鍵鼠模式：由滑鼠座標計算出精準的方向與位置
		aim_position = player.get_global_mouse_position()
		aim_direction = (aim_position - player.global_position).normalized()

	# 3. 讀取按鍵（完全對應你的遊戲企劃書設定）
	is_dashing = Input.is_action_just_pressed("ui_dash")          # 鍵盤 Shift / 手把 A
	is_reloading = Input.is_action_just_pressed("ui_reload")      # 鍵盤 R / 手把 X
	is_interacting = Input.is_action_just_pressed("ui_interact")  # 鍵盤 M2 右鍵 / 手把 RB
	is_protecting = Input.is_action_just_pressed("ui_protect")    # 鍵盤 Q / 手把 LT
	is_shooting = Input.is_action_pressed("ui_shooting")

```

### Scripts

**GameLevel.gd**
```gdscript
# GameLevel.gd (每一關的場景根節點都掛這個腳本)
class_name GameLevel
extends Node2D

# 🎮 定義有哪些遊戲模式
enum LevelMode {
	SINGLE_STAGE_ACHIEVEMENT, # (1) 單一階段：看擊殺數/技能次數/衝刺時間拿旗幟
	THREE_STAGE_PROGRESSION    # (2) 三部分進度：傳送門1 -> 移動傳送門2 -> 打完Boss拿3旗
}

# 🎯 模式(1) 的旗幟統計類型
enum AchievementType { KILLS, SKILL_CASTS, DASH_DURATION }

@export_category("🌐 關卡核心識別")
@export var chapter_id: String = "chapter_1"
@export var level_id: String = "level_1_1"

@export_category("🏆 遊戲模式選擇")
@export var game_mode: LevelMode = LevelMode.SINGLE_STAGE_ACHIEVEMENT

@export_group("📊 模式 (1) 的詳細設定 (成就挑戰)")
@export var challenge_type: AchievementType = AchievementType.KILLS
@export var has_time_limit: bool = false
@export var time_limit_seconds: float = 60.0
@export var target_for_flag_1: int = 10  # 拿到第一面旗需要的數值 (例如殺 10 隻怪)
@export var target_for_flag_2: int = 25  # 拿到第二面旗需要的數值
@export var target_for_flag_3: int = 50  # 拿到第三面旗需要的數值

@export_group("👹 怪物與難度控制")
@export var monster_hp_multiplier: float = 1.0     # 填 1.5 就是這關怪物血量 1.5 倍
@export var monster_damage_multiplier: float = 1.0 # 攻擊力倍率
@export var max_spawn_count: int = 30              # 這關最多產生幾隻怪就停止

# 🕒 運行期間的計數器
var current_kills: int = 0
var current_skill_casts: int = 0
var current_dash_seconds: float = 0.0
var level_timer: float = 0.0
var current_stage_part: int = 1 # 用於模式(2) 的第幾階段

func _ready() -> void:
	print("🎬 載入關卡: ", level_id, " 模式為: ", LevelMode.keys()[game_mode])
	
	# 如果是模式 (2) 三階段模式，先初始化第一階段的傳送門
	if game_mode == LevelMode.THREE_STAGE_PROGRESSION:
		setup_three_stage_part(1)

func _process(delta: float) -> void:
	# 處理模式(1) 的計時器
	if game_mode == LevelMode.SINGLE_STAGE_ACHIEVEMENT and has_time_limit:
		level_timer += delta
		if level_timer >= time_limit_seconds:
			end_level_mode_1() # 時間到，結算

# 🔔 當怪物死掉時，由 Enemy 或 Spawner 呼叫此函式
func record_kill():
	current_kills += 1
	print("🏹 關卡累計擊殺: ", current_kills)
	
	# 如果是模式(1) 且沒限時，達到最高目標時自動通關
	if game_mode == LevelMode.SINGLE_STAGE_ACHIEVEMENT and not has_time_limit:
		if current_kills >= target_for_flag_3:
			end_level_mode_1()

# 🔔 當玩家釋放技能時呼叫
func record_skill_cast():
	current_skill_casts += 1
	if game_mode == LevelMode.SINGLE_STAGE_ACHIEVEMENT and challenge_type == AchievementType.SKILL_CASTS:
		if not has_time_limit and current_skill_casts >= target_for_flag_3:
			end_level_mode_1()

# 🏁 模式 (1) 結束與旗幟結算
func end_level_mode_1():
	set_process(false) # 停止計時
	var final_value = 0
	
	# 根據設定的挑戰類型，檢查玩家的最終數值
	match challenge_type:
		AchievementType.KILLS: final_value = current_kills
		AchievementType.SKILL_CASTS: final_value = current_skill_casts
		AchievementType.DASH_DURATION: final_value = int(current_dash_seconds)
		
	# 計算得到幾面旗
	var flags_won = 0
	if final_value >= target_for_flag_3: flags_won = 3
	elif final_value >= target_for_flag_2: flags_won = 2
	elif final_value >= target_for_flag_1: flags_won = 1
	
	print("🏁 關卡時間結束或目標達成！獲得旗幟數: ", flags_won)
	# 呼叫全域存檔與結算
	PlayerData.complete_level(chapter_id, level_id, flags_won)
	# TODO: 這裡之後可以呼叫你的「 Mission Accomplished 結算大畫面 UI 」

# 🚪 模式 (2) 專用的階段切換控制
func setup_three_stage_part(part: int):
	current_stage_part = part
	print("🔄 進入三部分關卡的第 ", part, " 階段")
	
	match part:
		1:
			print("🚪 階段 1：生成普通傳送門。")
			# 這裡用程式碼動態生成普通傳送門，或讓場景內的第一階段傳送門顯示
		2:
			print("🚪 階段 2：生成會移動的傳送門！")
			# 可以把傳送門裝上 Path2D 移動軌跡，或者在程式碼給它一個速度向量
		3:
			print("👹 階段 3：Boss 戰！")
			# 隱藏傳送門，動態實例化（Instantiate）你的大 Boss 登場！

# 🔔 當玩家踩到傳送門時，傳送門呼叫這個函式
func on_portal_entered():
	if game_mode != LevelMode.THREE_STAGE_PROGRESSION: return
	
	if current_stage_part == 1:
		setup_three_stage_part(2)
	elif current_stage_part == 2:
		setup_three_stage_part(3)

# 🔔 當 Boss 死亡時，由 Boss 的 die() 呼叫這個函式
func on_boss_defeated():
	if game_mode == LevelMode.THREE_STAGE_PROGRESSION and current_stage_part == 3:
		print("🎉 擊敗大 Boss！完美通關，直接獲得 3 面旗幟！")
		PlayerData.complete_level(chapter_id, level_id, 3)
		# TODO: 彈出通關 UI
	

```

#### Resources

**ChestData.gd**
```gdscript
class_name ChestData
extends Resource

@export var chest_name: String = "普通木箱"
@export var closed_texture: Texture2D  # 寶箱關閉時的圖
@export var opened_texture: Texture2D  # 寶箱打開時的圖
@export var gold_reward: int = 50      # 開箱給多少錢
@export var drop_item_scene: PackedScene # (選填) 開箱噴出的武器或補血包場景

```

**LevelData.gd**
```gdscript

# 自訂資源：關卡設定契約
# res://Scripts/Resources/LevelData.gd
class_name LevelData
extends Resource

@export_category("🌐 關卡基礎識別")
@export var chapter_id: String = "chapter_1"
@export var level_id: String = "level_1_1"
@export var map_path: String = ""

@export_category("🏆 規則模式指定")
@export var mode_type: String = "FLAG" # "FLAG" 或是 "PORTAL"

@export_category("👹 怪物刷怪設定")
@export var enemy_list: Array[PackedScene] = []
@export var enemy_count: int = 10
@export var max_spawn_count: int = 30

@export_category("📊 模式專屬延伸參數")
@export var extra_params: Dictionary = {
	"portal_speed": 200.0,
	"target_kills": 10
}

```

**WeaponResource.gd**
```gdscript
extends Resource
# 自訂資源：武器數值契約
class_name WeaponResource  # 這讓這份檔案變成一個可以被選取的類型
@export var texture: Texture2D


@export var name: String = "未命名武器"
@export var bullet_scene: PackedScene     # 要發射的子彈場景
@export var bullet_count: int = 10         # 彈匣容量
@export var max_bullets: int = 100000
@export var cooldown: float = 0.2          # 射擊間隔(秒)
@export var reload_time: float = 1.5       # 換彈時間(秒)
@export var bullet_speed: float = 500.0    # 子彈速度
@export var damage: int = 1                # 子彈傷害

```

