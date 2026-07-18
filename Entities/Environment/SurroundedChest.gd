class_name SurroundedChest
extends Area2D

@export var enemy_scene: PackedScene
@export var spawn_count: int = 8
@export var spawn_radius: float = 200.0
@export var gold_reward: int = 100
@export var exp_reward: int = 50

var is_triggered: bool = false
var is_cleared: bool = false
var monitor_timer: Timer
var spawned_enemies: Array = []

signal chest_cleared(chest: SurroundedChest)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("chests")

func _on_body_entered(body: Node2D) -> void:
	if is_triggered:
		return
	if body.is_in_group("player"):
		_trigger_ambush()

func _trigger_ambush() -> void:
	is_triggered = true
	print("⚔️ 包圍寶箱觸發！生成 ", spawn_count, " 隻怪物")

	for i in range(spawn_count):
		if not enemy_scene:
			push_error("SurroundedChest: enemy_scene 未設定")
			return
		var enemy = enemy_scene.instantiate()
		var angle = randf() * TAU
		var offset = Vector2(cos(angle), sin(angle)) * spawn_radius
		enemy.global_position = global_position + offset
		enemy.set_meta("chest_source", self)
		spawned_enemies.append(enemy)
		get_tree().current_scene.add_child(enemy)

	monitor_timer = Timer.new()
	monitor_timer.name = "ChestMonitorTimer"
	monitor_timer.wait_time = 0.5
	monitor_timer.one_shot = false
	monitor_timer.timeout.connect(_check_enemies_cleared)
	add_child(monitor_timer)
	monitor_timer.start()

func _check_enemies_cleared() -> void:
	spawned_enemies = spawned_enemies.filter(func(e): return is_instance_valid(e))
	if spawned_enemies.is_empty():
		monitor_timer.stop()
		_on_cleared()

func _on_cleared() -> void:
	is_cleared = true
	print("🎉 包圍寶箱清除完畢！寶箱已解鎖")
	chest_cleared.emit(self)
	modulate = Color(1.0, 1.0, 0.6, 1.0)

func open_chest() -> void:
	if not is_cleared:
		print("寶箱尚未解鎖，無法開啟")
		return
	print("📦 開啟寶箱！獲得金幣: ", gold_reward, " 經驗值: ", exp_reward)
	PlayerData.gold += gold_reward
	PlayerData.gain_exp(exp_reward)
	queue_free()
