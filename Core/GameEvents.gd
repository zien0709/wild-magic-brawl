# res://Core/GameEvents.gd
# [AutoLoad] 全域事件總線
extends Node

# 傳遞怪物死亡與經驗值
signal enemy_killed(exp_reward: int)

# 傳遞玩家核心數值變化
signal player_health_changed(current: int, max_hp: int)
signal player_energy_changed(current: float, max_energy: float)

# ➕ 【新增加的訊號】為了讓新關卡大腦聽得到玩家的動作
signal player_skill_casted()              # 當玩家釋放技能時發出
signal player_dash_ticked(delta: float)   # 當玩家正在衝刺時，每幀把時間傳出來
