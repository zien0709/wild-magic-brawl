
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
