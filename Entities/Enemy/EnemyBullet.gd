class_name EnemyBullet
extends Area2D
# res://Entities/Enemy/EnemyBullet.gd

@export var speed: float = 400.0
@export var damage: int = 1
@export var max_range: float = 500.0

var direction: Vector2 = Vector2.RIGHT
var distance_traveled: float = 0.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var movement = direction * speed * delta
	global_position += movement
	distance_traveled += movement.length()
	
	if distance_traveled >= max_range:
		queue_free()

func setup(dir: Vector2, dmg: int, rng: float) -> void:
	direction = dir.normalized()
	damage = dmg
	max_range = rng
	rotation = direction.angle()

func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		area.on_hit.emit(damage, self)
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		queue_free()
