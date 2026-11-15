# res://Scripts/Resources/ChestData.gd
# [資源類別：寶箱資料]
# 定義寶箱的外觀、獎勵與掉落物，可序列化為 .tres 資源檔供場景使用。
class_name ChestData
extends Resource

@export var chest_name: String = "普通木箱"          # 寶箱名稱（顯示用）
@export var closed_texture: Texture2D                # 寶箱關閉時的圖示
@export var opened_texture: Texture2D                # 寶箱打開時的圖示
@export var gold_reward: int = 50                    # 開箱給予的金幣數量
@export var drop_item_scene: PackedScene             # (選填) 開箱噴出的武器或補血包場景
