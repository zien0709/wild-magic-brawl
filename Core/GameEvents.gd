# res://Core/GameEvents.gd
# [AutoLoad 全域事件總線 / Event Bus]
# 本模組為全域單例（Autoload），負責在「不直接耦合」的情況下，
# 讓各系統（玩家、敵人、關卡、UI）透過訊號互相通知。
# 設計模式：Observer Pattern（觀察者模式）—— 發送者不需知道接收者是誰。
extends Node

# 傳遞怪物死亡與經驗值：
# 當敵人死亡時由 Enemy 呼叫 GameEvents.enemy_killed.emit(xp)，
# LevelManager 監聽此訊號以給予玩家經驗值並更新 HUD。
signal enemy_killed(exp_reward: int)

# 傳遞玩家核心數值變化：
# 供 HUD / 其他系統監聽血量與能量的即時更新。
signal player_health_changed(current: int, max_hp: int)   # 玩家血量改變時發出
signal player_energy_changed(current: float, max_energy: float)  # 玩家能量改變時發出

# ➕ 【新增加的訊號】為了讓新關卡大腦（FlagModeHandler）聽得到玩家的動作
signal player_skill_casted()              # 當玩家釋放技能時發出（用於計數挑戰）
signal player_dash_ticked(delta: float)   # 當玩家正在衝刺時，每幀把經過時間傳出來（用於衝刺時長挑戰）
