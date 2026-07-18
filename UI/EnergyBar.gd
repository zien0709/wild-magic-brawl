extends ProgressBar
# res://UI/EnergyBar.gd

func _ready() -> void:
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.energy_changed.connect(_on_energy_changed)
		max_value = player.energy.max_energy
		value = player.energy.current_energy

func _on_energy_changed(current: float, max_energy: float) -> void:
	max_value = max_energy
	value = current
