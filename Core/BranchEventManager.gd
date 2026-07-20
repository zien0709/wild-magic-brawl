# res://Core/BranchEventManager.gd
# 平面國四選一分支事件通用框架
# 挂在地圖場景下,由 LevelManager 或手動初始化
class_name BranchEventManager
extends Node2D

enum BranchState { IDLE, BRANCH_ACTIVE, BRANCH_RESOLVING, CONVERGENCE, COMBAT }

signal branch_triggered(branch_index: int)
signal branch_completed(branch_index: int)
signal convergence_reached()
signal combat_phase_started()

@export var convergence_delay: float = 2.0

var current_state: BranchState = BranchState.IDLE
var active_branch: int = -1
var completed_branches: Array[int] = []
var branch_count: int = 0
var convergence_timer: float = 0.0

func _ready() -> void:
	_setup_branch_triggers()

func _process(delta: float) -> void:
	if current_state == BranchState.BRANCH_RESOLVING:
		convergence_timer -= delta
		if convergence_timer <= 0.0:
			_enter_convergence()

func _setup_branch_triggers() -> void:
	var branches = _find_branch_nodes()
	branch_count = branches.size()
	print("[BranchEventManager] 偵測到 ", branch_count, " 條分支觸發區")

	for i in range(branch_count):
		var branch_area = branches[i]
		if branch_area is Area2D:
			branch_area.body_entered.connect(_on_branch_body_entered.bind(i))

func _on_branch_body_entered(body: Node2D, branch_index: int) -> void:
	if current_state != BranchState.IDLE:
		return
	if not body.is_in_group("player"):
		return

	print("[BranchEventManager] 玩家觸發分支: ", branch_index)
	active_branch = branch_index
	current_state = BranchState.BRANCH_ACTIVE
	branch_triggered.emit(branch_index)
	_lock_other_branches(branch_index)

func _lock_other_branches(triggered_index: int) -> void:
	var branches = _find_branch_nodes()
	for i in range(branches.size()):
		if i != triggered_index and branches[i] is Area2D:
			branches[i].set_deferred("monitoring", false)

func resolve_branch() -> void:
	if current_state != BranchState.BRANCH_ACTIVE:
		return

	print("[BranchEventManager] 分支 ", active_branch, " 解決,準備收束")
	completed_branches.append(active_branch)
	current_state = BranchState.BRANCH_RESOLVING
	convergence_timer = convergence_delay
	branch_completed.emit(active_branch)

func _enter_convergence() -> void:
	print("[BranchEventManager] 收束段落開始")
	current_state = BranchState.CONVERGENCE
	convergence_reached.emit()

func start_combat_phase() -> void:
	print("[BranchEventManager] 進入核心戰鬥迴圈")
	current_state = BranchState.COMBAT
	combat_phase_started.emit()

func is_branch_completed(branch_index: int) -> bool:
	return branch_index in completed_branches

func get_completed_count() -> int:
	return completed_branches.size()

func reset() -> void:
	current_state = BranchState.IDLE
	active_branch = -1
	completed_branches.clear()
	convergence_timer = 0.0
	var branches = _find_branch_nodes()
	for b in branches:
		if b is Area2D:
			b.set_deferred("monitoring", true)

func _find_branch_nodes() -> Array[Node]:
	var result: Array[Node] = []
	for child in get_children():
		if child.name.begins_with("Branch"):
			result.append(child)
	result.sort_custom(func(a, b): return a.name < b.name)
	return result
