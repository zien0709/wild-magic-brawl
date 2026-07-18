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
var talent_points: int = 0
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
		"talent_points": talent_points,
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
			talent_points = data.get("talent_points", 0)
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
	exp_to_next_level = int(exp_to_next_level * 1.5)
	talent_points += 1
	print("🎉 恭喜升級！目前等級：", account_level, " 獲得 1 點天賦點數")
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_notification("🎉🎉 LEVEL UP! 目前等級: " + str(account_level) + " 🎉🎉", Color.GREEN)

	save_game()
	
	
