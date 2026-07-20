#res://Scenes/UI/GameHUD.gd
extends CanvasLayer


@onready var health_bar = $PlayerHealthBar 
@onready var energy_bar = $DashEnergyBar  
@onready var ammo_label: Label = $RightTopContainer/WeaponHUD/HBoxContainer/AmmoLabel
@onready var weapon_icon: TextureRect = $RightTopContainer/WeaponHUD/HBoxContainer/WeaponIcon
@onready var notification_box: VBoxContainer = $LeftTopContainer/NotificationBox
# --- 新增控制佇列的變數 ---
var notification_queue: Array = []  # 存放等待顯示的訊息佇列
var is_processing_queue: bool = false  # 記錄目前是否正在播放訊息
const MSG_INTERVAL: float = 0.3  # 每條訊息跳出來的間隔時間（秒）

func _ready() -> void:
	add_to_group("hud")
	# 剛進入遊戲時，先把通知欄清空
	for child in notification_box.get_children():
		child.queue_free()
	# 🕒 安全機制：等一個 frame，確保玩家已經在場景中生成完畢
	await get_tree().process_frame

	# 🕵️‍♂️ 透過 Group 自動在全場景尋找玩家，完全不需要知道路徑！
	var player = get_tree().get_first_node_in_group("player")
	
	if player:
		
		player.health_changed.connect(_on_player_health_changed)
		player.energy_changed.connect(_on_player_energy_changed)
		_on_player_health_changed(player.current_hp, player.max_hp)
		_on_player_energy_changed(player.energy.current_energy, player.energy.max_energy)
		
		print("✅ HUD 初始化成功，已主動同步初始血量（", player.current_hp, "/", player.max_hp, "）")

	else:
		print("❌ HUD 找不到玩家，請檢查 Player 節點是否有加入 'player' 群組")
	if player and player.has_node("WeaponHandler"):
		var weapon_handler = player.get_node("WeaponHandler")
		
		# 🎯 核心：直接讀取 WeaponHandler 裡面的 WeaponResource (data)
		if weapon_handler and weapon_handler.data:
			var weapon_data = weapon_handler.data
			
			# 🖼️ 自動載入圖片！Resource 裝哪把槍，UI 就變哪張圖
			if weapon_data.texture:
				weapon_icon.texture = weapon_data.texture
			
			# 初始子彈數更新
			update_ammo(weapon_handler.current_bullets, "∞")
	

# 🩸 當玩家發射 health_changed 訊號時，會自動執行這裡
func _on_player_health_changed(current: int, max_hp: int):
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current

# ⚡ 當玩家發射 energy_changed 訊號時，會自動執行這裡
func _on_player_energy_changed(current: float, max_energy: float):
	if energy_bar:
		energy_bar.max_value = max_energy
		energy_bar.value = current
# 🔄 更新子彈 UI 的函式 (供玩家或武器腳本呼叫)
func update_ammo(current: int, reserve: String) -> void:
	ammo_label.text = str(current) + " / " + reserve

# 📣 核心功能：只負責把訊息丟進排隊名單
func show_notification(text: String, color: Color = Color.WHITE) -> void:
	# 1. 將訊息資料包成字典，塞進排隊陣列
	notification_queue.append({"text": text, "color": color})
	
	# 2. 如果目前沒有人在播放動畫，就啟動排程器
	if not is_processing_queue:
		_process_notification_queue()

# ⚙️ 內部排程器：負責依序處理排隊中的訊息
func _process_notification_queue() -> void:
	# 如果隊伍空了，就收工
	if notification_queue.is_empty():
		is_processing_queue = false
		return
		
	is_processing_queue = true
	
	# 取出隊伍最前面的訊息
	var current_msg = notification_queue.pop_front()
	
	# 3. 動態建立文字標籤（原本的邏輯）
	var new_label = Label.new()
	new_label.text = current_msg["text"]
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_label.add_theme_color_override("font_color", current_msg["color"])
	
	notification_box.add_child(new_label)
	
	# 4. Tween 動畫（原本的邏輯）
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(new_label, "position:y", new_label.position.y - 30, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(new_label, "modulate:a", 0.0, 1.6)
	tween.chain().tween_callback(new_label.queue_free)
	
	# 5. 🔥 核心魔法：等待設定的間隔時間後，自動呼叫自己處理下一條訊息
	await get_tree().create_timer(MSG_INTERVAL).timeout
	_process_notification_queue()
