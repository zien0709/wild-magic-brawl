class_name ThrowableBase
extends RigidBody2D
# res://Entities/Throwable/ThrowableBase.gd

@export var weight: float = 1.0               # 石頭=1.0, 汽油桶=2.5 等
@export var arc_height_multiplier: float = 1.0 # 弧度高度係數

var is_grabbed: bool = false
var grabber: Node2D = null

# 拋物線飞行狀態
var is_flying: bool = false
var start_pos: Vector2
var target_pos: Vector2
var flight_time: float = 0.0
var total_flight_time: float = 0.0
var base_max_height: float = 80.0

@onready var sprite = $Sprite2D

func _ready() -> void:
	add_to_group("interactable_objects")

func _physics_process(delta: float) -> void:
	if is_grabbed and is_instance_valid(grabber):
		# 被吸取狀態：物理拉力朝向抓取者
		var direction = global_position.direction_to(grabber.global_position)
		var distance = global_position.distance_to(grabber.global_position)
		linear_velocity = direction * distance * 10.0
		
	elif is_flying:
		flight_time += delta
		var t = clamp(flight_time / total_flight_time, 0.0, 1.0)
		
		# 2D 地面座標插值
		global_position = start_pos.lerp(target_pos, t)
		
		# 拋物線高度計算 (Y offset)
		var max_height = base_max_height * arc_height_multiplier / (weight if weight > 0.0 else 1.0)
		var height = max_height * 4.0 * t * (1.0 - t)
		
		if sprite:
			sprite.position.y = -height
			
		if t >= 1.0:
			_land()

func grab(target: Node2D) -> void:
	is_grabbed = true
	is_flying = false
	grabber = target
	collision_mask = 0
	freeze = false
	if sprite:
		sprite.position = Vector2.ZERO

func throw(direction: Vector2, force: float = 1200.0) -> void:
	is_grabbed = false
	grabber = null
	collision_mask = 1
	
	# 投擲距離隨重量遞減
	var throw_dist = (force / 3.0) / (weight if weight > 0.0 else 1.0)
	start_pos = global_position
	target_pos = global_position + direction * throw_dist
	
	# 飞行時間隨重量增加（重量大飛行慢）
	var speed = 400.0 / (weight if weight > 0.0 else 1.0)
	total_flight_time = max(0.3, throw_dist / speed)
	
	flight_time = 0.0
	is_flying = true
	freeze = true # 飛行期間關閉剛體引擎物理模擬

func _land() -> void:
	is_flying = false
	freeze = false
	if sprite:
		sprite.position = Vector2.ZERO
	print("📦 [", name, "] 著地！")
