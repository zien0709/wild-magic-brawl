# res://Core/HapticManager.gd
extends Node

# 預設玩家 1 的裝置 ID 是 0
var default_device: int = 0

## 🛡️ Q護盾：完美反彈 (極短、高頻清脆)
func play_perfect_parry(device: int = default_device) -> void:
	# 強馬達 0.0 (不要沉重感) / 弱馬達 0.9 (極高頻) / 持續 0.12 秒
	Input.start_joy_vibration(device, 0.9, 0.0, 0.12)

## 🎯 QTE：成功停在 C 區 (柔和、舒服的回饋)
func play_qte_success(device: int = default_device) -> void:
	# 強馬達 0.2 / 弱馬達 0.4 / 持續 0.15 秒，輕微點一下的感覺
	Input.start_joy_vibration(device, 0.4, 0.2, 0.15)

## ❌ QTE：手殘失敗 (雙馬達打架狂震、極強肉體懲罰感)
func play_qte_failed(device: int = default_device) -> void:
	# 雙馬達直接全開 1.0 / 持續 0.5 秒，製造強烈的挫敗手感
	Input.start_joy_vibration(device, 1.0, 1.0, 0.5)

## 💔 額外追加：能量歸零/破產瞬間的特殊震動 (脈衝式抽搐感)
func play_energy_bankrupt(device: int = default_device) -> void:
	Input.start_joy_vibration(device, 0.8, 0.3, 0.3)

## 🛑 強制停止所有震動 (例如玩家突然按 Pause 暫停遊戲時呼叫)
func stop_all_vibration(device: int = default_device) -> void:
	Input.stop_joy_vibration(device)
