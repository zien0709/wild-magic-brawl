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
	
