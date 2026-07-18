# res://Modes/BaseModeHandler.gd
# 模式基底類別
class_name BaseModeHandler
extends Node

# 虛擬函式，強迫所有子模式遵守統一的初始化接口
func initialize(_data: LevelData, _map: Node2D) -> void:
	pass
