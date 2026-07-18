
class_name LevelData
extends Resource

enum ChallengeType { KILLS, SKILL_CASTS, DASH_DURATION }

@export_category("🌐 關卡基礎識別")
@export var chapter_id: String = "chapter_1"
@export var level_id: String = "level_1_1"
@export var map_path: String = ""

@export_category("🏆 規則模式指定")
@export var mode_type: String = "FLAG"

@export_category("👹 怪物刷怪設定")
@export var enemy_list: Array[PackedScene] = []
@export var enemy_count: int = 10
@export var max_spawn_count: int = 30

@export_category("🏆 旗幟挑戰設定 (FlagMode)")
@export var challenge_type: ChallengeType = ChallengeType.KILLS
@export var has_time_limit: bool = false
@export var time_limit_seconds: float = 60.0
@export var target_value: int = 10

@export_category("📊 模式專屬延伸參數")
@export var extra_params: Dictionary = {
	"portal_speed": 200.0,
	"target_kills": 10
}
