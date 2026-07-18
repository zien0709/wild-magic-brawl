class_name TalentData
extends Resource
# res://Scripts/Resources/TalentData.gd

@export var talent_id: String
@export var display_name: String
@export var max_rank: int = 1
@export var effect_per_rank: Dictionary  # e.g. {"damage_mult": 0.05}
@export var prerequisite_talent_ids: Array[String]
