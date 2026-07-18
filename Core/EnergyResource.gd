class_name EnergyResource
extends Resource

signal energy_changed(current: float, max: float)
signal energy_depleted
signal skill_rejected(skill_name: String, required: float, available: float)

@export var max_energy: float = 100.0
@export var regen_rate: float = 10.0  # per second
var current_energy: float = 100.0

func try_spend(amount: float, skill_name: String) -> bool:
	if current_energy < amount:
		skill_rejected.emit(skill_name, amount, current_energy)
		return false
	current_energy -= amount
	energy_changed.emit(current_energy, max_energy)
	if current_energy <= 0.0:
		energy_depleted.emit()
	return true

func regen(delta: float) -> void:
	if current_energy >= max_energy:
		return
	current_energy = min(max_energy, current_energy + regen_rate * delta)
	energy_changed.emit(current_energy, max_energy)
