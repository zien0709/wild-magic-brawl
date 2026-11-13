# res://Scripts/Resources/TalentData.gd
# [資源類別：天賦資料]
# 定義單一天賦的屬性與前置條件，可序列化為 .tres 供天賦樹系統使用。
# res://Scripts/Resources/TalentData.gd
class_name TalentData
extends Resource

@export var talent_id: String                        # 天賦唯一識別碼
@export var display_name: String                      # 天賦顯示名稱
@export var max_rank: int = 1                        # 最大可投資等級
@export var effect_per_rank: Dictionary               # 每級效果，例：{"damage_mult": 0.05}
@export var prerequisite_talent_ids: Array[String]   # 前置天賦 ID 列表（需先解鎖）
