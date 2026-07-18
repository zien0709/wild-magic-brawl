extends Resource
# 自訂資源：武器數值契約
class_name WeaponResource  # 這讓這份檔案變成一個可以被選取的類型
@export var texture: Texture2D


@export var name: String = "未命名武器"
@export var bullet_scene: PackedScene     # 要發射的子彈場景
@export var bullet_count: int = 10         # 彈匣容量
@export var max_bullets: int = 100000
@export var cooldown: float = 0.2          # 射擊間隔(秒)
@export var reload_time: float = 1.5       # 換彈時間(秒)
@export var bullet_speed: float = 500.0    # 子彈速度
@export var damage: int = 1                # 子彈傷害
