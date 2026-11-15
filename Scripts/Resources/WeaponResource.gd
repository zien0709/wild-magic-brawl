# res://Scripts/Resources/WeaponResource.gd
# 自訂資源：武器數值契約
# res://Scripts/Resources/WeaponResource.gd
class_name WeaponResource  # 這讓這份檔案變成一個可以被選取的類型
extends Resource

@export var texture: Texture2D                       # 武器圖片（Sprite2D 顯示用）

@export var name: String = "未命名武器"               # 武器名稱
@export var bullet_scene: PackedScene                # 要發射的子彈場景（PackedScene）
@export var bullet_count: int = 10                   # 彈匣容量（當前可用子彈）
@export var max_bullets: int = 100000               # 最大攜帶彈藥
@export var cooldown: float = 0.2                    # 射擊間隔（秒）
@export var reload_time: float = 1.5                 # 換彈時間（秒）
@export var bullet_speed: float = 500.0              # 子彈速度（像素/秒）
@export var damage: int = 1                          # 子彈傷害
