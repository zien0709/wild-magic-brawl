# res://Modes/FlagModeHandler.gd
# [旗幟/成就挑戰模式處理器 / Flag Mode Handler]
# 處理「單一階段成就挑戰」模式：看擊殺數/技能次數/衝刺時間拿旗幟。
# 對接 LevelData 欄位（challenge_type、has_time_limit、target_value 等）。
class_name FlagModeHandler
extends BaseModeHandler

# 當前關卡設定（執行期參考）
var current_level_data: LevelData
# 當前挑戰進度值（擊殺數/技能次數/衝刺秒數）
var current_value: float = 0.0
# 關卡計時器（限時模式用）
var level_timer: float = 0.0
# 關卡是否仍在進行
var is_level_active: bool = true

# 初始化：根據 challenge_type 決定監聽哪一個全域事件
# data = LevelData 設定, map = 地圖根節點
func initialize(data: LevelData, map: Node2D) -> void:
	current_level_data = data
	current_value = 0.0
	level_timer = 0.0
	is_level_active = true
	
	# 🎯 根據這關設定的 challenge_type，決定要監聽哪一個全域事件
	match current_level_data.challenge_type:
		LevelData.ChallengeType.KILLS:          # 擊殺數挑戰
			if GameEvents.has_signal("enemy_killed"):
				GameEvents.enemy_killed.connect(_on_enemy_killed)
				
		LevelData.ChallengeType.SKILL_CASTS:    # 技能釋放次數挑戰
			if GameEvents.has_signal("player_skill_casted"):
				GameEvents.player_skill_casted.connect(_on_skill_casted)
				
		LevelData.ChallengeType.DASH_DURATION:  # 衝刺時長挑戰
			if GameEvents.has_signal("player_dash_ticked"):
				GameEvents.player_dash_ticked.connect(_on_dash_ticked)

# 每幀處理限時邏輯（由 Godot 自動呼叫）
func _process(delta: float) -> void:
	if not is_level_active: return
	
	# 🕒 處理限時邏輯（直接從 LevelData 讀取欄位）
	if current_level_data.has_time_limit:
		level_timer += delta
		if level_timer >= current_level_data.time_limit_seconds:
			end_level(false) # 時間到，未達標則失敗或依當前分數結算

# 🏹 殺怪事件觸發：每次殺怪 +1 進度
func _on_enemy_killed(_exp_reward: int) -> void:
	if current_level_data.challenge_type != LevelData.ChallengeType.KILLS: return
	_add_progress(1.0)

# ⚡ 放技能事件觸發：每次放技能 +1 進度
func _on_skill_casted() -> void:
	if current_level_data.challenge_type != LevelData.ChallengeType.SKILL_CASTS: return
	_add_progress(1.0)

# 💨 衝刺時間累計觸發：每幀累加衝刺秒數
func _on_dash_ticked(delta: float) -> void:
	if current_level_data.challenge_type != LevelData.ChallengeType.DASH_DURATION: return
	_add_progress(delta)

# 📈 統一推進進度的函式
func _add_progress(amount: float) -> void:
	if not is_level_active: return
	
	current_value += amount
	print("📊 當前挑戰進度: ", int(current_value), " / ", current_level_data.target_value)
	
	# 🏁 方案 B：達到設定的單一目標數值，直接通關！
	if current_value >= current_level_data.target_value:
		end_level(true)

# 🏁 結算關卡
# is_success = 是否達標通關
func end_level(is_success: bool) -> void:
	is_level_active = false
	set_process(false) # 停止計時
	
	if is_success:
		print("🎉 恭喜通關！達到目標值: ", current_level_data.target_value)
		# 呼叫全域存檔，方案 B 成功直接給 1 面勝利旗幟
		PlayerData.complete_level(current_level_data.chapter_id, current_level_data.level_id, 1)
	else:
		print("❌ 挑戰時間到！通關失敗。")
		PlayerData.complete_level(current_level_data.chapter_id, current_level_data.level_id, 0)
	
	# TODO: 這裡可以呼叫 HUD 顯示結算畫面
