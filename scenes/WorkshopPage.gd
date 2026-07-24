extends "res://ui/UIPage.gd"

# C1 爱意工坊页（步数礼盒模型）：进度 + 待拆礼盒 + 拆盒动画 + 礼物背包。
# 旧 4 槽能量队列 UI 已随 WorkshopManager 重写移除。

const BoxOpenAnimation := preload("res://ui/BoxOpenAnimation.gd")
const GiftInventoryGrid := preload("res://ui/GiftInventoryGrid.gd")

const PROGRESS_WIDTH := 420.0

var _progress_label: Label
var _progress_fill: ColorRect
var _unopened_label: Label
var _open_btn: Button
var _box_animation: BoxOpenAnimation
var _inventory_grid: GiftInventoryGrid
var _anim_playing := false
var _last_dupe_petals: int = 0


func on_enter(_data: Dictionary = {}) -> void:
	_refresh()


func _ready() -> void:
	super()
	_build_layout()
	_connect_signals()
	_refresh()


func handle_back() -> bool:
	if _inventory_grid and _inventory_grid.visible:
		_inventory_grid.clear()
		return true
	UIManager.pop()
	return true


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.PAPER_CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "🎁 爱意工坊"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0.0, 48.0)
	title.size = Vector2(720.0, 44.0)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "每走 %d 步，猫咪们就为你做好一份小惊喜" % WorkshopManager.BOX_STEPS
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0.0, 96.0)
	subtitle.size = Vector2(720.0, 30.0)
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	add_child(subtitle)

	var track := ColorRect.new()
	track.color = Palette.BORDER
	track.position = Vector2((720.0 - PROGRESS_WIDTH) * 0.5, 170.0)
	track.size = Vector2(PROGRESS_WIDTH, 22.0)
	add_child(track)

	_progress_fill = ColorRect.new()
	_progress_fill.color = Palette.AMBER
	_progress_fill.position = track.position
	_progress_fill.size = Vector2(0.0, 22.0)
	add_child(_progress_fill)

	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.position = Vector2(0.0, 200.0)
	_progress_label.size = Vector2(720.0, 28.0)
	_progress_label.add_theme_font_size_override("font_size", 14)
	_progress_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	add_child(_progress_label)

	_unopened_label = Label.new()
	_unopened_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unopened_label.position = Vector2(0.0, 252.0)
	_unopened_label.size = Vector2(720.0, 36.0)
	_unopened_label.add_theme_font_size_override("font_size", 20)
	_unopened_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	add_child(_unopened_label)

	_open_btn = Button.new()
	_open_btn.text = "拆礼盒"
	_open_btn.position = Vector2(260.0, 310.0)
	_open_btn.size = Vector2(200.0, 64.0)
	_open_btn.add_theme_font_size_override("font_size", 20)
	_open_btn.pressed.connect(_on_open_pressed)
	add_child(_open_btn)

	var inventory_btn := Button.new()
	inventory_btn.text = "我的礼物"
	inventory_btn.flat = true
	inventory_btn.position = Vector2(260.0, 392.0)
	inventory_btn.size = Vector2(200.0, 44.0)
	inventory_btn.add_theme_font_size_override("font_size", 16)
	inventory_btn.pressed.connect(_on_inventory_pressed)
	add_child(inventory_btn)

	var back_btn := Button.new()
	back_btn.text = "← 返回"
	back_btn.flat = true
	back_btn.position = Vector2(24.0, 40.0)
	back_btn.size = Vector2(120.0, 44.0)
	back_btn.pressed.connect(func() -> void: handle_back())
	add_child(back_btn)

	_box_animation = BoxOpenAnimation.new()
	add_child(_box_animation)

	_inventory_grid = GiftInventoryGrid.new()
	add_child(_inventory_grid)


func _connect_signals() -> void:
	if WorkshopManager:
		if not WorkshopManager.progress_changed.is_connected(_on_progress_changed):
			WorkshopManager.progress_changed.connect(_on_progress_changed)
		if not WorkshopManager.box_minted.is_connected(_on_box_minted):
			WorkshopManager.box_minted.connect(_on_box_minted)
	if _box_animation and not _box_animation.animation_finished.is_connected(_on_anim_finished):
		_box_animation.animation_finished.connect(_on_anim_finished)


func _refresh() -> void:
	if WorkshopManager == null or _progress_fill == null:
		return
	var p: Dictionary = WorkshopManager.get_progress()
	var steps_into: int = int(p.get("steps_into_box", 0))
	var box_steps: int = int(p.get("box_steps", 3000))
	var unopened: int = int(p.get("unopened", 0))
	var boxes_today: int = int(p.get("boxes_today", 0))
	var daily_cap: int = int(p.get("daily_cap", 3))
	_progress_fill.size.x = PROGRESS_WIDTH * clampf(float(steps_into) / float(box_steps), 0.0, 1.0)
	if unopened >= int(p.get("unopened_cap", 5)):
		_progress_label.text = "礼盒堆满啦，先把礼物拆了吧（步数照常累计）"
	elif boxes_today >= daily_cap:
		_progress_label.text = "今日 %d 份已做满，明天继续（步数照常累计）" % daily_cap
	else:
		_progress_label.text = "距下一份礼盒还差 %d 步" % max(box_steps - steps_into, 0)
	_unopened_label.text = "待拆礼盒 ×%d　（今日 %d/%d）" % [unopened, boxes_today, daily_cap]
	_open_btn.disabled = unopened <= 0 or _anim_playing


func _on_open_pressed() -> void:
	if _anim_playing or WorkshopManager == null:
		return
	var result: Dictionary = WorkshopManager.open_box()
	if not bool(result.get("success", false)):
		if Popups: Popups.show_toast("还没有做好的礼盒，去走走吧")
		return
	var gift_id := String(result.get("gift_id", ""))
	var gift: Dictionary = WorkshopData.get_gift_data(gift_id) if WorkshopData else {}
	_anim_playing = true
	_open_btn.disabled = true
	_last_dupe_petals = int(result.get("dupe_petals", 0))
	_box_animation.play(0, gift_id, String(gift.get("rarity", "common")),
		String(gift.get("name", gift_id)), String(gift.get("category", "")))


func _on_anim_finished(_slot_index: int, gift_id: String) -> void:
	_anim_playing = false
	var gift: Dictionary = WorkshopData.get_gift_data(gift_id) if WorkshopData else {}
	if _last_dupe_petals > 0 and Popups:
		Popups.show_toast("已拥有「%s」→ 爱心花瓣 +%d" % [String(gift.get("name", gift_id)), _last_dupe_petals])
	_last_dupe_petals = 0
	_refresh()


func _on_inventory_pressed() -> void:
	if _inventory_grid == null or GiftInventory == null:
		return
	_inventory_grid.populate(GiftInventory.get_all_gifts())
	_inventory_grid.refresh()


func _on_progress_changed(_steps_into_box: int, _box_steps: int) -> void:
	_refresh()


func _on_box_minted(_unopened: int) -> void:
	_refresh()
