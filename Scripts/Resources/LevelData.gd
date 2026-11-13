# res://Scripts/Resources/LevelData.gd
# [自訂資源：關卡設定契約 / Level Data Contract]
# 定義一關的完整設定：基礎識別、規則模式、刷怪設定、旗幟挑戰、延伸參數。
# 可序列化為 .tres 資源檔，由 LevelManager 讀取並組裝地圖。
class_name LevelData
extends Resource

# 旗幟挑戰類型列舉：決定本關挑戰的計分方式
enum ChallengeType { KILLS, SKILL_CASTS, DASH_DURATION }

@export_category("🌐 關卡基礎識別")
@export var chapter_id: String = "chapter_1"   # 章節 ID（對應 PlayerData.career_data）
@export var level_id: String = "level_1_1"     # 關卡 ID
@export var map_path: String = ""              # 地圖場景路徑（.tscn）

@export_category("🏆 規則模式指定")
@export var mode_type: String = "FLAG"         # "FLAG"=旗幟挑戰, "PORTAL"=傳送門模式

@export_category("👹 怪物刷怪設定")
@export var enemy_list: Array[PackedScene] = [] # 可生成的敵人場景清單
@export var enemy_count: int = 10              # 敵人總數（Portal 模式用）
@export var max_spawn_count: int = 30          # 場上最大同時存在敵數

@export_category("📊 旗幟挑戰設定 (FLAG 模式)")
@export var challenge_type: ChallengeType = ChallengeType.KILLS  # 挑戰類型
@export var has_time_limit: bool = false       # 是否限時
@export var time_limit_seconds: float = 60.0   # 限時秒數
@export var target_value: int = 10             # 達標目標值
@export var target_for_flag_1: int = 10        # 第 1 面旗所需數值
@export var target_for_flag_2: int = 25        # 第 2 面旗所需數值
@export var target_for_flag_3: int = 50        # 第 3 面旗所需數值

@export_category("📊 模式專屬延伸參數")
@export var extra_params: Dictionary = {       # 彈性參數（Portal 速度、血量倍率等）
	"portal_speed": 200.0,
	"target_kills": 10
}
