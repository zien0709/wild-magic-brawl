class_name ChestData
extends Resource

@export var chest_name: String = "普通木箱"
@export var closed_texture: Texture2D  # 寶箱關閉時的圖
@export var opened_texture: Texture2D  # 寶箱打開時的圖
@export var gold_reward: int = 50      # 開箱給多少錢
@export var drop_item_scene: PackedScene # (選填) 開箱噴出的武器或補血包場景
