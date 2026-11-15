# res://Core/EnergyResource.gd
# [資源類別：玩家能量系統]
# 本類別繼承 Resource，可被序列化為 .tres 資源檔，供玩家與技能系統使用。
# 負責：能量的消耗（try_spend）、自然回復（regen）、以及相關事件通知。
# 設計：Observer Pattern —— 透過 signal 通知 HUD / 技能 UI 更新。
class_name EnergyResource
extends Resource

# 能量變更事件：current=當前能量, max=最大能量（供 HUD 進度條更新）
signal energy_changed(current: float, max: float)
# 能量歸零事件：用於觸發「能量耗盡」相關效果（如無法施放技能）
signal energy_depleted
# 技能被拒絕事件：skill_name=技能名, required=需求量, available=可用量（供 UI 顯示提示）
signal skill_rejected(skill_name: String, required: float, available: float)

@export var max_energy: float = 100.0          # 最大能量值（可在編輯器調整）
@export var regen_rate: float = 10.0           # 每秒自然回復量（per second）
var current_energy: float = 100.0             # 當前能量（執行期狀態，不序列化）

# 嘗試消耗能量：amount=消耗量, skill_name=技能名稱（用於拒絕時回報）
# 回傳 true 表示消耗成功；false 表示能量不足並發出 skill_rejected 訊號
func try_spend(amount: float, skill_name: String) -> bool:
	if current_energy < amount:                      # 能量不足
		skill_rejected.emit(skill_name, amount, current_energy)  # 通知 UI 被拒絕
		return false                                # 消耗失敗
	current_energy -= amount                         # 扣除能量
	energy_changed.emit(current_energy, max_energy)  # 通知 HUD 更新
	if current_energy <= 0.0:                       # 能量歸零
		energy_depleted.emit()                      # 觸發耗盡事件
	return true                                     # 消耗成功

# 能量自然回復：delta=本幀經過秒數
# 當能量未滿時，依 regen_rate 累加，並通知 HUD 更新
func regen(delta: float) -> void:
	if current_energy >= max_energy:                 # 已滿，不需回復
		return
	current_energy = min(max_energy, current_energy + regen_rate * delta)  # 累加並夾限
	energy_changed.emit(current_energy, max_energy)  # 通知 HUD 更新
