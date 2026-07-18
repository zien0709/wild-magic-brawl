# res://Scripts/Components/InputComponent.gd
class_name InputComponent
extends Node

# 供 Player 與 Weapon 讀取的標準接口
var move_direction: Vector2 = Vector2.ZERO
var aim_position: Vector2 = Vector2.ZERO
var aim_direction: Vector2 = Vector2.RIGHT # 直接取得當前旋轉/瞄準方向（正規化向量）

var is_dashing: bool = false
var is_shooting: bool = false
var is_reloading: bool = false
var is_interacting: bool = false # 企劃書中的 M2 投擲
var is_protecting: bool = false  # 企劃書中的 Q 護盾
var is_qte_pressed: bool = false # 企劃書中的 Space QTE 心控

@export var joystick_deadzone: float = 0.2
var last_aim_direction: Vector2 = Vector2.RIGHT
var is_using_gamepad: bool = false

func _ready() -> void:
	_setup_custom_inputs()

func _setup_custom_inputs():
	# 1. Setup ui_qte on Space key if it doesn't exist
	if not InputMap.has_action("ui_qte"):
		InputMap.add_action("ui_qte")
	InputMap.action_erase_events("ui_qte")
	var space_event = InputEventKey.new()
	space_event.physical_keycode = KEY_SPACE
	InputMap.action_add_event("ui_qte", space_event)
	
	var controller_qte = InputEventJoypadButton.new()
	controller_qte.button_index = JOY_BUTTON_Y
	InputMap.action_add_event("ui_qte", controller_qte)

	# 2. Ensure ui_interact is mapped to Right Click (MOUSE_BUTTON_RIGHT)
	if not InputMap.has_action("ui_interact"):
		InputMap.add_action("ui_interact")
	InputMap.action_erase_events("ui_interact")
	var right_click = InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("ui_interact", right_click)
	
	var controller_rb = InputEventJoypadButton.new()
	controller_rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	InputMap.action_add_event("ui_interact", controller_rb)

func _input(event: InputEvent) -> void:
	# 偵測到鍵盤按鍵、滑鼠點擊、滑鼠移動 -> 切換到鍵鼠模式
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		is_using_gamepad = false
	# 偵測到手把按鈕、搖桿推動 -> 切換到手把模式
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# 濾掉搖桿極輕微的飄移（死區），避免搖桿自然放開時的細微晃動誤觸手把模式
		if event is InputEventJoypadMotion and abs(event.axis_value) < joystick_deadzone:
			return
		is_using_gamepad = true

func update_input() -> void:
	var player = get_parent() as Node2D
	if not player: return

	# 1. 處理移動（左搖桿 或 WASD，在專案設定綁定同一個 Action）
	move_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# 2. 處理瞄準方向
	var joystick_dir = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if is_using_gamepad:
		# 🎮 手把模式
		if joystick_dir.length() > joystick_deadzone:
			aim_direction = joystick_dir.normalized()
			last_aim_direction = aim_direction
		else:
			# 放開搖桿時，維持最後一次瞄準的方向，避免武器彈回預設右邊
			aim_direction = last_aim_direction
			
		# 核心魔法：計算出全域的虛擬瞄準點，讓原本吃 Position 的舊程式碼（如 look_at）不會壞掉
		aim_position = player.global_position + aim_direction * 200.0
	else:
		# ⌨️ 鍵鼠模式：由滑鼠座標計算出精準的方向與位置
		aim_position = player.get_global_mouse_position()
		aim_direction = (aim_position - player.global_position).normalized()

	# 3. 讀取按鍵（完全對應你的遊戲企劃書設定）
	is_dashing = Input.is_action_just_pressed("ui_dash")          # 鍵盤 Shift / 手把 A
	is_reloading = Input.is_action_just_pressed("ui_reload")      # 鍵盤 R / 手把 X
	is_interacting = Input.is_action_just_pressed("ui_interact")  # 鍵盤 M2 右鍵 / 手把 RB
	is_protecting = Input.is_action_just_pressed("ui_protect")    # 鍵盤 Q / 手把 LT
	is_shooting = Input.is_action_pressed("ui_shooting")
	is_qte_pressed = Input.is_action_just_pressed("ui_qte")        # 鍵盤 Space / 手把 Y
