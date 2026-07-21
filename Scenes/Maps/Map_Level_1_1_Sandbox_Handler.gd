# res://Scenes/Maps/Map_Level_1_1_Sandbox_Handler.gd
# 掛載在 Map_Level_1_1_Sandbox 根節點上
# 接聽 BranchEventManager 的三個訊號,作為分支劇情/對話/UI 呈現的統一入口
extends Node2D

@onready var branch_event_manager: BranchEventManager = $BranchEventManager


func _ready() -> void:
	branch_event_manager.branch_triggered.connect(_on_branch_triggered)
	branch_event_manager.convergence_reached.connect(_on_convergence_reached)
	branch_event_manager.combat_phase_started.connect(_on_combat_phase_started)
	print("[SandboxHandler] 已接聽 BranchEventManager 三個訊號")


func _on_branch_triggered(branch_index: int) -> void:
	print("[SandboxHandler] branch_triggered - 分支 ", branch_index, " 被觸發")
	# TODO: 此處需要使用者填入該分支的劇情文本/對話/UI 呈現
	# 例如：顯示對話框、播放過場動畫、切換 BGM 等
	# branch_index 對應：0=A(北), 1=B(東), 2=C(南), 3=D(西)


func _on_convergence_reached() -> void:
	print("[SandboxHandler] convergence_reached - 收束段落開始")
	# TODO: 此處需要使用者填入收束段落的劇情文本/對話/UI 呈現
	# 所有分支完成後進入此處，例如：觸發警報事件、逃脫段落等


func _on_combat_phase_started() -> void:
	print("[SandboxHandler] combat_phase_started - 進入核心戰鬥迴圈")
	# TODO: 此處需要使用者填入戰鬥階段開始的劇情文本/UI 呈現
	# 例如：顯示「戰鬥開始」UI、啟動刷怪、播放戰鬥 BGM 等
