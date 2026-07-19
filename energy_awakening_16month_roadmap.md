# 《代號:能量覺醒》16 個月開發規格書
### 給 Agentic Coding AI(Claude Code / Gemini CLI 等)直接執行用

---

## 0. 使用說明(給執行 AI 看的)

你是被指派來實作這個 Godot 4.x 遊戲專案的 agentic coding AI。這份文件把 16 個月的開發拆成 **4 個階段、共 40+ 個獨立任務**。規則:

1. **一次只做一個任務**。做完後,對照該任務的「驗收標準(DoD)」自我檢查,全部打勾才算完成。
2. **任務有依賴順序**,前面標示「依賴:任務 X」的,必須等該任務完成才能開始。
3. **每個任務都要先讀取現有相關檔案**,不要憑空假設現有程式碼長什麼樣子——這個專案已經有 `EventBus`(全域事件匯流排)、`LevelManager` + `LevelData.tres`(資料驅動關卡系統)、`BaseModeHandler` 子類別(`FlagModeHandler`/`PortalModeHandler`)、`HapticManager`(手把震動)等既有架構,新功能要盡量融入這些既有模式,不要重造輪子或另開一套平行系統。
4. 遇到「⚠️ 人工決策點」標記的項目,**停下來詢問使用者**,不要自己假設數值或美術風格繼續往下做。
5. 每個階段結尾都有「里程碑 Demo 驗收清單」,那是給使用者本人玩測試用的,不是給你判斷完成度用的——你做完程式碼任務即可,不用自己模擬「好不好玩」。
6. **⚠️ 系統做出來≠玩得到**。實測發現過:M2 拋物線投擲系統(`ThrowableBase`/`ThrowAimComponent`)做完了,但沒有任何地圖場景真的放置 `WoodenBox` 實例,導致玩家實際遊玩時「根本沒有東西可以丟」。這是規格書先前的疏漏——每個涉及「玩家會在關卡中互動的物件/敵人」的任務,**驗收標準都必須包含「已在至少一個地圖場景中實際放置該物件/敵人的實例」**,不能只做出可重用的類別/元件就視為完成。做完一個互動系統後,永遠自問:「如果現在打開遊戲玩,我實際看得到、摸得到這個系統嗎?」

---

## 1. 總體架構原則(貫穿全部四階段)

### 1.1 核心資料流:共用能量資源池(所有階段的地基)

這是全專案最優先要生出來的系統,Q 護盾 / Space QTE / M2 投擲 / Shift 衝刺全部共用同一條能量條。

**新檔案:`res://Core/EnergyResource.gd`**
```gdscript
class_name EnergyResource
extends Resource

signal energy_changed(current: float, max: float)
signal energy_depleted
signal skill_rejected(skill_name: String, required: float, available: float)

@export var max_energy: float = 100.0
@export var regen_rate: float = 10.0  # per second
var current_energy: float = 100.0

func try_spend(amount: float, skill_name: String) -> bool:
    if current_energy < amount:
        skill_rejected.emit(skill_name, amount, current_energy)
        return false
    current_energy -= amount
    energy_changed.emit(current_energy, max_energy)
    if current_energy <= 0.0:
        energy_depleted.emit()
    return true

func regen(delta: float) -> void:
    if current_energy >= max_energy:
        return
    current_energy = min(max_energy, current_energy + regen_rate * delta)
    energy_changed.emit(current_energy, max_energy)
```

**任務 0.1:建立 EnergyResource 並掛載到 player.gd**
- 依賴:無(最優先任務)
- 在 `player.gd` 的 `_ready()` 建立 `energy: EnergyResource` 實例
- 在 `_physics_process` 呼叫 `energy.regen(delta)`
- DoD:
  - [ ] `EnergyResource.gd` 檔案存在且無語法錯誤
  - [ ] player.gd 持有 energy 實例,場景執行後 `current_energy` 會隨時間回滿
  - [ ] `energy_rejected` 訊號能被至少一個佔位的 `print()` 監聽到(先確認訊號線路通,不用做 UI)

**任務 0.2:能量條 UI 元件**
- 依賴:任務 0.1
- 新檔案:`res://UI/EnergyBar.gd` + `EnergyBar.tscn`,監聽 `energy_changed` 更新 ProgressBar
- ⚠️ 人工決策點:UI 視覺風格(顏色、位置)由使用者決定,先用預設 ProgressBar 佔位即可
- DoD:
  - [ ] 場景中能即時看到能量條隨技能施放/回復變動

**任務 0.3:各技能改接能量池預扣**
- 依賴:任務 0.1
- ⚠️ 修正(先前版本寫錯,已在實測中確認並修正):**基礎射擊(左鍵/M1)不消耗共用能量池**,只有 Dash(Shift)、Q 護盾、Space QTE、M2 丟擲這四項才需要在施放前呼叫 `energy.try_spend()`,回傳 false 則不執行技能且觸發拒絕回饋(音效/UI 閃紅,先留 TODO 註解即可)。基礎射擊維持原本只受彈藥數與冷卻時間限制,不受能量池影響
- DoD:
  - [ ] 能量歸零時,Dash 無法觸發,且不會扣出負數能量
  - [ ] 能量歸零時,基礎射擊仍然可以正常開火,不受能量池影響

**任務 0.4:Dash 衝刺方向鎖定(⚠️ 補進去——先前實作漏接,導致衝刺中可任意變向)**
- 依賴:任務 0.1
- 實測發現:`start_dash()` 有把衝刺瞬間的方向鎖存到 `dash_direction` 變數,但 `_physics_process` 裡實際計算 `velocity` 時,不論是否在衝刺中,永遠使用即時輸入的 `input_handler.move_direction`,導致 `dash_direction` 完全沒被使用,玩家衝刺中可以隨意改變方向
- 需求:修改 `velocity` 賦值邏輯——`is_dashing` 為 `true` 時,`velocity` 應使用鎖存的 `dash_direction * dash_speed`,忽略當下的即時輸入方向;只有 `is_dashing` 為 `false` 時才使用 `input_handler.move_direction * normal_speed`
- DoD:
  - [ ] 衝刺觸發後,即使玩家改變方向鍵/搖桿輸入,角色仍沿衝刺瞬間鎖定的方向移動,直到衝刺結束

---

## 2. 第一階段(第 1–5 個月):單機戰鬥地基

**目標**:把現有「未完品」的 PvE 打怪雛形,擴充成企劃書描述的完整單人戰鬥迴圈——護盾、QTE 心控、天賦樹、升級系統、動態刷怪、包圍寶箱。這階段做完,PvE 模式應該已經「好玩」,不只是「能動」。

### 2.0 敵人攻擊預警系統(⚠️ 補進去的地基任務——沒有這個,護盾機制無法被玩家實際操作)

實測發現:現有 `enemy.gd` 的攻擊邏輯是「貼近玩家→碰撞就扣血」,沒有任何前搖動畫或預警訊號。這代表就算把 Q 護盾的完美格擋邏輯做得再精確,玩家在實際遊玩時也沒有任何依據可以判斷「現在該按 Q 了」——完美格擋會變成純粹瞎猜時機,而不是一個可以練習、有反應空間的技巧。這個系統必須先做,再做護盾才有意義。

**任務 1.0a:攻擊前搖狀態與視覺訊號**
- 依賴:無
- 修改 `enemy.gd`,新增攻擊前搖狀態機:`enum AttackState { IDLE, WINDUP, STRIKE, RECOVERY }`
- ⚠️ 人工決策點:`WINDUP`(前搖)持續時間,先給合理預設(如 0.4 秒),後續由使用者實測調整——這個數值必須跟護盾的 `perfect_window_ms` 互相搭配過,原則上前搖時間要明顯長於完美格擋窗口,讓玩家有反應時間
- 邏輯:敵人進入攻擊距離後,先進入 `WINDUP`(此階段敵人不造成傷害,但要有明顯視覺訊號,例如放大/變色/晃動,先用 `modulate` 變化或簡單 tween 頂著,不用等美術資源到位),`WINDUP` 結束才進入 `STRIKE` 階段造成傷害判定,再進入短暫 `RECOVERY` 硬直
- DoD:
  - [ ] 敵人攻擊前有明顯可觀察的視覺變化(顏色/大小/晃動皆可),且傷害判定只在 `STRIKE` 階段觸發
  - [ ] `WINDUP` 階段的持續時間可以在 Inspector 調整,不需改程式碼

**任務 1.0b:把護盾完美窗口與攻擊前搖時序對齊**
- 依賴:任務 1.0a、任務 1.1(護盾狀態機)
- 邏輯:確保「按 Q 進入 `PERFECT_WINDOW`」與「敵人 `STRIKE` 判定觸發的瞬間」在時間軸上是可以透過觀察前搖訊號來抓準的——也就是玩家看到敵人開始 `WINDUP` 視覺變化後,有清楚的操作窗口可以在 `STRIKE` 前按下 Q
- DoD:
  - [ ] 實測時,玩家可以透過觀察敵人的前搖視覺訊號,主動抓時機按 Q 觸發完美格擋,而不是純粹碰運氣

### 2.1 Q 護盾系統

**任務 1.1:護盾狀態機**
- 依賴:任務 0.1
- 新檔案:`res://Entities/Player/ShieldComponent.gd`
- 資料結構:
```gdscript
enum ShieldState { IDLE, ACTIVE, PERFECT_WINDOW, BROKEN_COOLDOWN }
@export var perfect_window_ms: int = 150   # ⚠️人工決策點:完美格擋容錯窗口,先用此值,後續由使用者實測調整
@export var shield_cost: float = 15.0
@export var broken_cooldown_sec: float = 1.2
```
- 邏輯:按住 Q → 呼叫 `energy.try_spend(shield_cost, "shield")` 成功才進 ACTIVE;進入 ACTIVE 的前 `perfect_window_ms` 毫秒為 `PERFECT_WINDOW`;此窗口內受到傷害觸發「完美反彈」(對攻擊來源造成反傷+短暫昏迷),窗口外受到傷害觸發「破盾」進入 `BROKEN_COOLDOWN`,此期間無法再次舉盾
- 接線:`InputComponent.gd` 已有 `is_protecting` 讀取,直接接上這個新元件,不要再新增輸入判斷
- DoD:
  - [ ] 舉盾消耗能量,能量不足時無法舉盾
  - [ ] 完美窗口內格擋 vs 窗口外格擋,兩者觸發的訊號/效果不同(可先用 print 驗證,不用做完整特效)
  - [ ] 破盾後有硬直冷卻,冷卻中按 Q 無反應

**任務 1.2:護盾視覺與音效回饋**
- 依賴:任務 1.1
- 三種視覺狀態(一般格擋色/完美格擋閃光色/破盾灰暗色),用 `AnimationPlayer` 或 shader 皆可
- DoD:
  - [ ] 三種狀態視覺可明顯區分

### 2.2 Space QTE 心控(單機版:命中即倒戈)

**任務 1.3:QTE 判定 UI(指針/區間)**
- 依賴:任務 0.1
- 新檔案:`res://UI/QTEWidget.gd` + `.tscn`
- 邏輯:一個左右來回移動的指針 + 一個目標區間(區間大小、指針速度可調參數化,方便後續平衡);判定結果分三級:`PERFECT` / `GOOD` / `FAIL`
- ⚠️ 人工決策點:指針速度、區間寬度的具體數值,先給合理預設(如指針 1.5 秒來回一次、區間佔總長 20%),標註 TODO 待實測調整
- DoD:
  - [ ] Space 觸發時 QTE widget 出現,可以互動並回傳三種判定結果之一

**任務 1.4:QTE 心控效果實作(單機)**
- 依賴:任務 1.3、任務 0.1
- 新檔案:`res://Entities/Enemy/MindControlComponent.gd`,掛在敵人身上
- 邏輯:對指定敵人觸發 QTE;`PERFECT` 判定 → 敵人陣營暫時切換為玩家方,攻擊其他敵人,持續 N 秒後恢復;`GOOD` → 短暫定身但不倒戈;`FAIL` → 技能空放,能量照扣不退還
- 敵人陣營切換需要和現有 `enemy.gd` 的目標選擇邏輯串接(敵人選目標時應排除「暫時友軍」狀態的同類)
- DoD:
  - [ ] `PERFECT` 判定後可觀察到目標敵人攻擊其他敵人
  - [ ] 效果時間到後,敵人陣營正確恢復為敵對

### 2.3 M2 磁吸曲線投擲(重寫 WoodenBox 系統)

**任務 1.5:可拋物線投擲物件基底類別**
- 依賴:無
- 新檔案:`res://Entities/Throwable/ThrowableBase.gd`,取代現有 `WoodenBox.gd` 的陽春直線衝量邏輯
- 資料結構:
```gdscript
@export var weight: float = 1.0  # 石頭=1.0, 汽油桶=2.5 等,⚠️人工決策點:各物件權重數值由使用者決定
@export var arc_height_multiplier: float = 1.0
```
- 邏輯:拋物線運動用簡單彈道公式(初速度 + 重力 + 到達目標點的時間反推),不要用現成的直線 `apply_impulse`
- DoD:
  - [ ] 丟出的物件會走弧線而非直線
  - [ ] 不同 `weight` 值的物件,飛行弧度/距離有可觀察的差異

**任務 1.5b:玩家抓取偵測範圍節點(⚠️ 補進去——先前實作漏掉,導致抓取直接報錯)**
- 依賴:任務 1.5
- 實測發現:`player.gd` 的 `_try_grab_object()` 呼叫 `$TelekinesisZone.get_overlapping_bodies()`,但 `Player.tscn` 場景樹中從未真正建立過這個節點,導致玩家按互動鍵時直接報錯(Node not found)
- 需求:在 `Player.tscn` 中新增一個 `Area2D` 節點,命名為 `TelekinesisZone`,掛在 `Player` 底下,並附上合理大小的 `CollisionShape2D` 作為抓取偵測範圍(⚠️人工決策點:半徑先給 100~150 像素的合理預設,後續由使用者實測調整),`collision_mask` 需要能偵測到 `interactable_objects` 群組物件所在的碰撞層
- DoD:
  - [ ] 場景樹中確實存在 `TelekinesisZone` 節點且有碰撞範圍
  - [ ] 玩家按互動鍵時不再報錯,能正確偵測範圍內的可抓取物件

**任務 1.6:M2 磁吸瞄準與 AI 權重選擇**
- 依賴:任務 1.5
- 新檔案:`res://Entities/Player/ThrowAimComponent.gd`
- 邏輯:滑鼠/搖桿瞄準範圍內若有多個可丟擲物件,依 `weight` 由高到低優先「磁吸」吸附游標到該物件上(汽油桶優先於石頭)
- ⚠️ 注意:這個磁吸覆寫瞄準點的邏輯,只能在玩家「明確準備丟擲互動」時生效(例如按住互動鍵且尚未抓取物件的當下),平常自由移動/射擊時不能覆寫玩家的射擊瞄準方向,兩套瞄準系統不可互相干擾
- DoD:
  - [ ] 場景中同時放置石頭與汽油桶,瞄準游標會優先鎖定汽油桶

**任務 1.6b:把可丟擲物件實際放進遊玩地圖(⚠️ 補進去——先前規格書漏掉這一步)**
- 依賴:任務 1.5、任務 1.5b、任務 1.6
- 實測發現:`ThrowableBase`/`WoodenBox` 系統做完後,`Map_Level_1_1.tscn` 與 `Map_Level_1_2.tscn` 兩張地圖裡完全沒有放置任何 `WoodenBox` 實例,玩家實際遊玩時找不到任何東西可以丟
- 需求:在至少一張現有可遊玩地圖中,實際放置數個 `WoodenBox`(或其他 `ThrowableBase` 子類別)實例,分布在合理的戰鬥區域內,讓玩家一進關卡就能實際體驗抓取/磁吸/拋物線丟擲的完整流程
- DoD:
  - [ ] 至少一張地圖打開後,場景中肉眼可見數個可丟擲物件,玩家可以實際抓取並丟出去,不需要額外手動放置才能測試

### 2.4 天賦樹與升級系統

**任務 1.7:天賦資料結構**
- 依賴:無
- 新檔案:`res://Scripts/Resources/TalentData.gd`(仿照現有 `LevelData.gd` 的 Resource 模式)
```gdscript
class_name TalentData
extends Resource

@export var talent_id: String
@export var display_name: String
@export var max_rank: int = 1
@export var effect_per_rank: Dictionary  # e.g. {"damage_mult": 0.05}
@export var prerequisite_talent_ids: Array[String]
```
- 新增全域 `PlayerData.talents: Dictionary`,存放已解鎖天賦與等級
- 把先前程式碼審查發現的 `bullet_pierce` 天賦,正式接進這個系統(之前是死碼欄位)
- DoD:
  - [ ] 至少建立 3 個 `TalentData.tres` 資源實例(如 bullet_pierce、shield_cost_reduction、energy_max_up)
  - [ ] `PlayerData.talents` 能正確記錄解鎖狀態,且各技能程式碼會讀取這個字典來改變行為(例如 `bullet_pierce=true` 時子彈不因擊中敵人而銷毀)

**任務 1.8:升級/經驗值系統**
- 依賴:任務 1.7
- 新增 `PlayerData.level`、`PlayerData.exp`、`PlayerData.exp_to_next_level`
- 敵人死亡時透過 `EventBus` 廣播 `enemy_killed(exp_value)` (若現有事件已有類似訊號,擴充而非新增重複訊號)
- 升級時給予「天賦點數」,供天賦樹消費
- DoD:
  - [ ] 擊殺敵人可以看到經驗值累積、升級時能量上限或其他數值確實提升
  - [ ] 升級後可以在(暫時陽春的)UI 上把點數投入任務 1.7 的天賦

**任務 1.9:天賦樹 UI**
- 依賴:任務 1.7、1.8
- ⚠️ 人工決策點:UI 排版/美術風格由使用者決定,先做功能性佔位版本(列表+按鈕即可)
- DoD:
  - [ ] 可以點擊解鎖/升級天賦,天賦點數正確扣除

### 2.5 動態刷怪與包圍寶箱

**任務 1.10:整併/移除舊 `enemy_spawner.gd`**
- 依賴:無(可最先做,是清理債務)
- 確認專案內無任何場景/腳本引用 `enemy_spawner.gd` 後刪除該檔案
- 確認 `LevelManager.gd` 內建的動態刷怪計時器邏輯完整,群組名稱統一使用 `"enemies"`
- DoD:
  - [ ] 專案內找不到 `enemy_spawner.gd` 的殘留引用
  - [ ] 遊戲執行時怪物仍會正常動態刷新

**任務 1.11:「包圍寶箱」機制**
- 依賴:任務 1.10
- 新檔案:`res://Entities/Environment/SurroundedChest.gd`
- 邏輯:寶箱被觸發時,`LevelManager` 在寶箱周圍生成一波高密度怪物(數量/半徑可參數化),清完波次寶箱才能開啟
- DoD:
  - [ ] 觸發寶箱時場景內怪物數量明顯增加,清完後寶箱可開啟並給予戰利品/經驗值

### 2.6 舊架構清理(技術債)

**任務 1.12:刪除 `GameLevel.gd`,統一 `Map_Level_1_2.tscn` 到新架構**
- 依賴:無(可與其他任務並行)
- 移除 `Map_Level_1_2.tscn` 根節點上的 `GameLevel.gd` 綁定,改為與 `Map_Level_1_1.tscn` 相同,交由 `LevelManager` + 對應 `LevelData.tres` 驅動
- ⚠️ 人工決策點:`Map_Level_1_2` 若尚無對應 `LevelData.tres`,需要使用者在編輯器 Inspector 手動建立資源並填入 `mode_type`/`enemy_list` 等欄位,agent 只能生成範本結構,無法自動在 Godot 編輯器內操作 Inspector
- DoD:
  - [ ] `GameLevel.gd` 已刪除,專案內無殘留 `class_name GameLevel` 的引用
  - [ ] `Map_Level_1_2.tscn` 場景執行時走新的 ModeHandler 架構,無報錯

**任務 1.13:修正 Bullet 碰撞層/穿透邏輯**
- 依賴:任務 1.7(需要 `bullet_pierce` 天賦資料先存在)
- `Bullet.tscn` 設定正確 `collision_mask` 對應牆壁圖層
- `Bullet.gd` 新增 `area_entered` 綁定,命中敵人 Hurtbox 時預設銷毀,若 `PlayerData.talents["bullet_pierce"]` 為真則不銷毀繼續飛行
- DoD:
  - [ ] 子彈撞牆確實消失
  - [ ] 未點天賦時子彈打中一隻怪就消失;點了天賦後可連續命中多隻怪

**任務 1.14:清理 `LevelManager.gd` 死碼**
- 依賴:無
- 移除未使用的 `hp_multiplier`/`damage_multiplier` 類別變數宣告
- DoD:
  - [ ] 專案編譯/執行無報錯,行為無變化

### 🎯 第一階段里程碑 Demo 驗收清單(使用者親自測試用,非 agent 自我檢查項目)
- [ ] 能量條驅動全部技能,能量不足時技能確實被拒絕
- [ ] Q 護盾三種判定(完美/一般/破盾)手感明確可分辨
- [ ] Space QTE 心控可以讓一隻敵人倒戈打自己人
- [ ] M2 丟擲汽油桶會優先磁吸鎖定,飛行軌跡是弧線
- [ ] 天賦樹至少 3 項天賦可解鎖並實際影響戰鬥
- [ ] 包圍寶箱觸發動態刷怪波次
- [ ] 專案內無殘留的 `GameLevel.gd`/`enemy_spawner.gd`/死碼

---

## 3. 第二階段(第 6–9 個月):離線單機 Mode 完整打磨

**目標**:把第一階段做出來的系統,串成企劃書描述的「1-1 關:平面國」完整可玩戰役,這是保底一定要交出來的成品。

**任務 2.1:1-1 關卡場景搭建(平面國、四路徑分支)**
- 依賴:第一階段全部任務
- ⚠️ 人工決策點:四條黑色喜劇分支的具體劇情內容、對話文本、關卡美術由使用者提供,agent 負責搭建觸發區域(Area2D)、分支狀態機、劇情事件的程式框架
- 新檔案:`res://Scenes/Maps/Map_Level_1_1_Sandbox.tscn` + `res://Core/BranchEventManager.gd`
- 邏輯:自由探索地圖 → 觸發四選一分支事件區域之一 → 各分支各自的小段落 → 全部收束進「警報/逃脫」強制段落 → 轉場進入核心戰鬥迴圈關卡
- DoD:
  - [ ] 至少一條分支路徑可以從觸發到收束完整跑一輪不報錯
  - [ ] 收束後正確轉場進戰鬥關卡,且第一階段系統(能量池/護盾/QTE/天賦)全部正常運作

**任務 2.2:另外三條分支路徑補完**
- 依賴:任務 2.1
- 用同一套 `BranchEventManager` 框架複製擴充,不要每條分支各寫一套獨立系統
- DoD:
  - [ ] 四條分支皆可觸發並收束到同一個強制段落,無邏輯衝突(例如同時觸發兩條分支的邊界情況需處理)

**任務 2.3:單機戰役數值平衡與難度曲線**
- 依賴:任務 2.1、2.2、第一階段全部
- ⚠️ 人工決策點:具體數值(怪物血量、傷害、能量回復速率)需要使用者實測後由使用者決定,agent 負責把這些數值全部抽成可調參數(exported 變數或 `LevelData.tres` 欄位),不要寫死在程式碼裡
- DoD:
  - [ ] 所有平衡相關數值都能在 Inspector 或 `.tres` 資源中直接調整,不需改程式碼重新編譯

**任務 2.4:存檔/讀檔系統**
- 依賴:任務 1.8(升級系統)
- 新檔案:`res://Core/SaveManager.gd`,序列化 `PlayerData`(等級/經驗/天賦/已完成分支)成 JSON 或 Godot 的 `ResourceSaver`
- DoD:
  - [ ] 關閉遊戲重開後,天賦/等級/關卡進度可正確還原

**任務 2.5:單機戰役結尾與結算畫面**
- 依賴:任務 2.1-2.4
- 通關後顯示戰鬥數據統計(擊殺數、耗時、完美格擋次數等)
- DoD:
  - [ ] 通關觸發結算畫面且數據正確

### 🎯 第二階段里程碑 Demo 驗收清單
- [ ] 從主選單開始,可以完整玩過一遍「平面國」四選一分支任一路徑到最終結算畫面
- [ ] 中途關閉遊戲重開,進度正確保留
- [ ] 全程無明顯 bug 中斷(閃退、卡關、碰撞穿模)

---

## 4. 第三階段(第 10–13 個月):PvE 深化 + PvP 本機原型

**目標**:PvE 模式加深内容量;PvP 對戰機制先在**本機雙人(同機雙輸入裝置)**驗證,完全不碰網路同步,把「多人控制退化」機制的手感與平衡先確認過。

### 4.1 PvE 深化

**任務 3.1:新增第二、第三種怪物類型**
- 依賴:第一階段
- ⚠️ 人工決策點:怪物設計(外型、技能)由使用者提供,agent 負責用現有 `enemy.gd`/`BaseModeHandler` 架構擴充為可配置的怪物種類系統(而非每種怪物複製貼上一份腳本)
- 新檔案:`res://Scripts/Resources/EnemyData.gd`(仿 `TalentData.gd`/`LevelData.gd` 模式),把怪物數值/行為抽成資源檔
- DoD:
  - [ ] 至少 2 種新怪物可在 `LevelData.tres` 中設定出現,行為與原本怪物有明確差異

**任務 3.2:第二個 PvE 關卡(非平面國)**
- 依賴:任務 3.1、第二階段全部
- DoD:
  - [ ] 新關卡可從關卡選擇介面進入,使用新怪物與新地形

### 4.2 PvP 本機雙人原型

**任務 3.3:雙輸入裝置支援(本機分割輸入,非分割畫面)**
- 依賴:第一階段全部
- 新檔案:`res://Core/LocalMultiplayerInputManager.gd`
- 邏輯:支援兩組獨立輸入裝置(例如鍵盤+滑鼠 vs 搖桿),各自綁定到場景中不同的 Player 節點實例,同畫面對戰(不做分割畫面,單一鏡頭涵蓋雙方,參考企劃書提到的 16:9 固定運鏡)
- DoD:
  - [ ] 兩組裝置可同時獨立控制各自角色,互不干擾

**任務 3.4:「控制退化」CC 系統**
- 依賴:任務 1.1(護盾)、任務 1.4(QTE 邏輯可重用判定框架)、任務 3.3
- 新檔案:`res://Entities/Player/ControlDegradeComponent.gd`
```gdscript
@export var degrade_duration: float = 2.0      # ⚠️人工決策點:單次最長持續秒數,由使用者實測決定
@export var diminishing_return_factor: float = 0.5  # 連續命中遞減係數
var stack_count: int = 0
var last_hit_time: float = 0.0

func apply_degrade() -> void:
    var effective_duration = degrade_duration * pow(diminishing_return_factor, stack_count)
    # 無法移動 + 左右輸入反轉,持續 effective_duration 秒
    stack_count += 1
    # stack_count 需要有計時器歸零機制,避免無限疊加,具體歸零時間⚠️人工決策點
```
- 重要:根據先前討論,**必須保留受害者的部分反制手段**(例如仍可攻擊,但瞄準有干擾),不要做成完全零互動的鎖死,並且要有遞減機制防止無限連鎖控場
- DoD:
  - [ ] 命中後角色確實無法移動且左右輸入反轉
  - [ ] 連續命中時效果持續時間遞減,不會無限疊加
  - [ ] 被控制期間受害者仍保有企劃書定義的部分操作權(非完全鎖死)

**任務 3.5:PvP 能量池/技能對戰平衡框架**
- 依賴:任務 0.1、任務 3.3、任務 3.4
- 把 PvE 與 PvP 情境下技能效果差異(命中敵人=倒戈 vs 命中玩家=控制退化)用同一個 Space QTE 判定核心,依「目標是否為真人玩家」分流不同結果處理器,而不是寫兩套 QTE 系統
- DoD:
  - [ ] 同一個 QTE 判定邏輯,目標是 AI 時觸發倒戈,目標是另一位本機玩家時觸發控制退化

**任務 3.6:PvP 勝負判定與圓場**
- 依賴:任務 3.3-3.5
- 血量歸零/場地圈縮(⚠️人工決策點:是否要圈縮機制由使用者決定)判定勝負,顯示結算畫面
- DoD:
  - [ ] 一場本機雙人對戰可以正常分出勝負並顯示結果

### 🎯 第三階段里程碑 Demo 驗收清單
- [ ] 兩位測試者用不同輸入裝置在同一台電腦上,可以完整打完一場 PvP 對戰
- [ ] 「控制退化」機制手感經過至少一輪人工測試調整(不是很難受/搞笑的鎖死感,而是有掙扎空間的劣勢)
- [ ] PvE 新增的怪物與關卡可正常遊玩

---

## 5. 第四階段(第 14–16 個月):P2P 網路同步

**目標**:把第三階段驗證過手感的本機雙人 PvP,改造成真正的點對點連線對戰。**範圍嚴格限制在直連,不做正式配對服務(EOS matchmaking)與雲端反作弊**,這兩項寫進企劃書當未來擴充即可。

**任務 4.1:Godot 高階多人 API 基礎架構**
- 依賴:第三階段全部
- 使用 Godot 內建 `ENetMultiplayerPeer` + `MultiplayerSynchronizer`/`MultiplayerSpawner`,不要自己刻底層 socket 協議
- 新檔案:`res://Core/NetworkManager.gd`,負責建立房間(host)/加入房間(輸入 IP 或房間碼,不做正式配對服務)
- ⚠️ 人工決策點:是否需要簡易的中繼/打洞(NAT traversal)服務,若使用者的目標玩家都在同一區域網路測試,可以先跳過這塊,只做區網直連
- DoD:
  - [ ] 兩台不同電腦(或同區網內)可以透過輸入 IP 建立連線並看到彼此存在

**任務 4.2:玩家狀態同步(位置/血量/能量池)**
- 依賴:任務 4.1
- 把第三階段的 `EnergyResource`、玩家位置/朝向,透過 `MultiplayerSynchronizer` 同步
- ⚠️ 重要技術風險提示給使用者:P2P 直連沒有權威伺服器仲裁,容易出現雙方判定不一致(例如兩邊都覺得自己先格擋成功),需要決定「以誰的判定為準」的權威模型(host-authoritative 是最簡單的起點)
- DoD:
  - [ ] 雙方畫面上能即時看到對方位置移動同步,延遲在區網環境下可接受(無需在此階段處理跨區域高延遲補償)

**任務 4.3:技能/傷害判定的網路同步(含控制退化 CC)**
- 依賴:任務 4.2、任務 3.4
- 護盾格擋判定、QTE 控制退化效果,改為由 host 端權威判定後廣播結果,client 端只負責顯示,不要讓雙方各自獨立判定同一次命中
- DoD:
  - [ ] 護盾完美格擋、QTE 控制退化效果,在雙方畫面上呈現一致的結果(不會出現各自看到不同判定)

**任務 4.4:網路斷線/重連處理**
- 依賴:任務 4.1-4.3
- 基本斷線偵測與提示(不需要做到無縫重連,做到「偵測到斷線並回到選單」即可)
- DoD:
  - [ ] 手動拔網路線或關閉一方遊戲,另一方能正確偵測並顯示斷線訊息,不會卡死或閃退

**任務 4.5:P2P 對戰整合測試與延遲手感調整**
- 依賴:任務 4.1-4.4
- ⚠️ 人工決策點:實際延遲補償手法(如客戶端預測/插值)是否需要,取決於使用者實測後的手感,若時間緊迫可以先接受「輕微延遲感」作為已知限制,寫進企劃書的「已知限制與未來優化方向」
- DoD:
  - [ ] 完整跑完至少 5 場真人對真人的網路對戰,無閃退,勝負判定一致

### 🎯 第四階段(最終)里程碑 Demo 驗收清單
- [ ] 兩台實體不同電腦透過輸入 IP 可以建立 P2P 對戰
- [ ] PvP 對戰中護盾、QTE 控制退化判定雙方畫面一致
- [ ] 至少能撐過 5 場完整對戰不崩潰
- [ ] 企劃書中「EOS matchmaking / Azure 反作弊 / 手機端 / 網頁導流」明確標註為「未來擴充,非本次 MVP 範圍」,並附上簡短說明為什麼延後(範圍管理是特殊選才審查會加分的成熟度展現)

---

## 6. 附錄:給使用者的人工決策點總覽(agent 執行時會停下來問的項目)

| 任務編號 | 需要你決定的事 |
|---|---|
| 1.0a | 敵人攻擊前搖(WINDUP)持續時間,要跟護盾完美窗口互相搭配 |
| 1.1 | 護盾完美格擋容錯窗口毫秒數 |
| 1.3 | QTE 指針速度、判定區間寬度 |
| 1.5 | 各投擲物件的重量權重數值 |
| 1.5b | `TelekinesisZone` 抓取偵測範圍半徑 |
| 1.9 | 天賦樹 UI 美術風格 |
| 1.12 | Map_Level_1_2 的 LevelData.tres 需要你在編輯器手動建立 |
| 2.1/2.2 | 四條分支的劇情文本、對話、美術 |
| 2.3 | 戰役數值平衡的具體數字 |
| 3.1 | 新怪物的外型與技能設計 |
| 3.4 | CC 效果持續時間、遞減係數、疊加歸零時間 |
| 3.6 | PvP 是否要圈縮機制 |
| 4.1 | 是否需要 NAT 打洞服務,或先只支援區網直連 |
| 4.5 | 是否投入客戶端預測/延遲補償,或接受已知限制 |

---

## 7. 修訂記錄:實測抓出的規格書漏洞(第一階段實作後回填)

第一階段實作完 code review 通過後,使用者實際上手玩,抓出了 4 個 code review 抓不出來、只有實際遊玩才會浮現的缺口,已回填進上面對應章節:

1. **場景層級的節點缺失不會被 code review 抓到**——`TelekinesisZone` 節點從沒被建立,但 code review 只看得出「有呼叫這個節點」,看不出「場景裡真的沒這個節點」,只有實際按下互動鍵報錯才會暴露。→ 已補進任務 1.5b
2. **變數算了但沒接線的邏輯,review 容易漏看**——`dash_direction` 有算、有存,但 `velocity` 賦值那行從沒真的讀取它,邏輯上看起來「有鎖定方向的機制」,但實際完全沒生效。→ 已補進任務 0.4
3. **系統做完 ≠ 出現在關卡裡**——`ThrowableBase` 系統很完整,但沒有任何地圖場景放置實例,玩家進遊戲根本找不到東西丟。→ 已補進任務 1.6b,並在使用說明加入第 6 條通用規則
4. **機制的「觸發時機」本身也是一個要設計的系統,不是理所當然存在**——完美格擋需要玩家能預判時機,但敵人攻擊完全沒有前搖或預警,導致按 Q 變成純猜測。→ 已補進任務 1.0a/1.0b 作為護盾系統的前置地基

**给你的啟示**:code review(不管是我做的還是 AI agent 自己做的)能抓出邏輯錯誤、死碼、命名不一致這類「靜態看得出來」的問題,但**「這個節點真的存在嗎」「這個變數真的被用到嗎」「這個系統真的塞進關卡了嗎」「玩家真的有辦法感知到该做什么嗎」這幾類問題,只有實際跑起來玩過才會現形**。之後每完成一小段任務,除了讓我 review 程式碼,你自己也要花時間實際玩一輪、故意去戳每個系統,兩者搭配抓 bug 的覆蓋率才會比較完整。

---

## 8. 給你(人類)的一句話總結

這份規格書刻意把**所有「品味/平衡/美術」類的決策都標成人工決策點**,agent 只負責把系統的骨架、資料結構、訊號串接做出來——因為這些才是會拖垮一個人專案的重複性工程量,而美術風格、數值手感這種東西,終究還是要靠你自己玩過、調過才會準。16 個月看似寬裕,但第四階段的網路同步風險最高,如果中途發現進度落後,**第一個該砍的是任務 4.5 的延遲補償**,直接接受「已知限制」交出去,不要為了打磨網路手感而犧牲前三階段的完整度。
