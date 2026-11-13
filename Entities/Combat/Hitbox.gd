# res://Entities/Combat/Hitbox.gd
# [攻擊盒 / Hitbox]
# 繼承 Area2D，代表可造成傷害的區域（子彈、怪物攻擊等）。
# damage=傷害值, is_spent=是否已消費（防止同幀重複扣血）。
class_name Hitbox
extends Area2D

@export var damage: int = 1          # 本攻擊造成的傷害
var is_spent: bool = false           # 是否已消費（防止穿透時重複扣血）
