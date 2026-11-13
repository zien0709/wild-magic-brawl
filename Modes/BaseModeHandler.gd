# res://Modes/BaseModeHandler.gd
# [模式基底類別 / Base Mode Handler]
# 所有關卡模式處理器（Flag/Portal 等）的共同父類別。
# 設計：Template Method Pattern —— 定義 initialize 介面，子類別覆寫以實作各自規則。
class_name BaseModeHandler
extends Node

# 虛擬函式：初始化關卡規則大腦
# _data = 本關的 LevelData 設定, _map = 地圖根節點
# 子類別必須覆寫此方法以綁定事件與初始化狀態
func initialize(_data: LevelData, _map: Node2D) -> void:
	pass
