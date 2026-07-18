extends Control
# res://UI/QTEWidget.gd

signal qte_finished(result: String)

@export var pointer_speed: float = 1.5      # 指針來回一次所需秒數
@export var perfect_zone_width: float = 0.1  # 完美區間佔總寬比例
@export var good_zone_width: float = 0.3     # 成功區間佔總寬比例
@export var target_center: float = 0.5       # 區間中心點

var current_position: float = 0.0
var direction: float = 1.0
var active: bool = true
var time_limit: float = 2.0                  # 無操作自動 FAIL 時間限制

@onready var pointer = $Pointer
@onready var target_area = $TargetArea
@onready var perfect_area = $PerfectArea

func _ready() -> void:
	_update_zones()
	
func _update_zones():
	# 基礎排版設定 (假設寬度為 200px)
	custom_minimum_size = Vector2(200, 30)
	
	if has_node("TargetArea"):
		var ta = $TargetArea
		ta.size.x = 200.0 * good_zone_width
		ta.position.x = 200.0 * (target_center - good_zone_width / 2.0)
		
	if has_node("PerfectArea"):
		var pa = $PerfectArea
		pa.size.x = 200.0 * perfect_zone_width
		pa.position.x = 200.0 * (target_center - perfect_zone_width / 2.0)

func _process(delta: float) -> void:
	if not active:
		return
		
	time_limit -= delta
	if time_limit <= 0.0:
		_evaluate_result(true)
		return
		
	current_position += direction * (delta / (pointer_speed / 2.0))
	if current_position >= 1.0:
		current_position = 1.0
		direction = -1.0
	elif current_position <= 0.0:
		current_position = 0.0
		direction = 1.0
		
	if has_node("Pointer"):
		$Pointer.position.x = 200.0 * current_position

	# 讀取 QTE 輸入
	if Input.is_action_just_pressed("ui_qte"):
		_evaluate_result(false)

func _evaluate_result(timeout: bool) -> void:
	active = false
	var result = "FAIL"
	
	if not timeout:
		var dist = abs(current_position - target_center)
		if dist <= perfect_zone_width / 2.0:
			result = "PERFECT"
		elif dist <= good_zone_width / 2.0:
			result = "GOOD"
			
	print("🎯 QTE 判定結果：", result)
	qte_finished.emit(result)
	
	# 漸變消失或短暫延遲後銷毀
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
