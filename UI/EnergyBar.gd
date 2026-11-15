# res://UI/EnergyBar.gd
# [能量進度條 / Energy Bar]
# 繼承 ProgressBar，綁定玩家能量系統，即時更新進度條。
extends ProgressBar

# 節點就緒：等待一幀後綁定玩家能量訊號並同步初始值
func _ready() -> void:
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.energy_changed.connect(_on_energy_changed)
		max_value = player.energy.max_energy
		value = player.energy.current_energy

# 能量變更回呼：更新進度條最大值與當前值
func _on_energy_changed(current: float, max_energy: float) -> void:
	max_value = max_energy
	value = current
