# MainMenu.gd
extends Control

# 當點擊「開始遊戲」時觸發
func _on_start_button_pressed() -> void:
	print("🚀 冒險開始！載入遊戲世界...")
	# 這裡就是「載入地圖與遊戲」的關鍵時機！
	LevelManager.load_career_level(load("res://Resources/Levels/Level_1_1.tres"))

# 當點擊「離開遊戲」時觸發
func _on_quit_button_pressed() -> void:
	print("🚪 關閉遊戲。")
	get_tree().quit() # 關閉遊戲程式
