extends Control

@export var talent_resources: Array[TalentData]

@onready var points_label: Label = $VBoxContainer/PointsLabel
@onready var talent_list: VBoxContainer = $VBoxContainer/TalentList

var talent_buttons: Dictionary = {}

func _ready() -> void:
	_refresh_ui()

func _refresh_ui() -> void:
	points_label.text = "可用天賦點數: " + str(PlayerData.talent_points)

	for child in talent_list.get_children():
		child.queue_free()
	talent_buttons.clear()

	for t in talent_resources:
		var is_unlocked = PlayerData.talents.get(t.talent_id, false)
		var current_rank = PlayerData.talents.get(t.talent_id, 0) if typeof(PlayerData.talents.get(t.talent_id)) == TYPE_INT else (1 if is_unlocked else 0)
		var maxed = current_rank >= t.max_rank
		var prereqs_met = true
		for pid in t.prerequisite_talent_ids:
			if not PlayerData.talents.get(pid, false):
				prereqs_met = false
				break

		var can_unlock = PlayerData.talent_points > 0 and not maxed and prereqs_met

		var row = HBoxContainer.new()
		var name_label = Label.new()
		name_label.text = t.display_name + (" (Lv." + str(current_rank) + "/" + str(t.max_rank) + ")" if t.max_rank > 1 else "")
		name_label.custom_minimum_size.x = 200
		row.add_child(name_label)

		var status_label = Label.new()
		if maxed:
			status_label.text = "已滿級"
		elif not prereqs_met:
			status_label.text = "未解鎖 (前置未滿足)"
		elif can_unlock:
			status_label.text = ""
		else:
			status_label.text = "無法解鎖"

		row.add_child(status_label)

		if can_unlock:
			var btn = Button.new()
			btn.text = "解鎖"
			btn.pressed.connect(_on_unlock_talent.bind(t.talent_id))
			row.add_child(btn)

		talent_list.add_child(row)

func _on_unlock_talent(talent_id: String) -> void:
	if PlayerData.talent_points <= 0:
		return
	var current_val = PlayerData.talents.get(talent_id, false)
	if typeof(current_val) == TYPE_BOOL:
		if current_val:
			return
		PlayerData.talents[talent_id] = true
	else:
		var rank = current_val as int
		if rank >= _get_max_rank(talent_id):
			return
		PlayerData.talents[talent_id] = rank + 1

	PlayerData.talent_points -= 1
	PlayerData.save_game()
	_refresh_ui()

func _get_max_rank(talent_id: String) -> int:
	for t in talent_resources:
		if t.talent_id == talent_id:
			return t.max_rank
	return 1
