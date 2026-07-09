# IAPProvider — 真实货币 IAP 购买抽象层 (Autoload)
# 不加 class_name：已注册同名 autoload，class_name 会与单例命名冲突。
# Editor/桌面/headless：mock 模式，purchase() 延迟 0.5s 后直接发放并回报成功。
# Android 真机：预留 Google Play Billing 接口，当前返回 IAP_NOT_AVAILABLE。
# 持久化交由 SaveManager（ConfigFile section "iap_store"）通过 apply_save/get_save_data 驱动。
extends Node

# 购买完成信号：sku_id + 是否成功。UI 监听此信号刷新界面/播放获得动画。
signal purchase_completed(sku_id: String, success: bool)

const SECTION := "iap_store"
const MONTHLY_CARD_DURATION := 30 * 24 * 60 * 60   # 月卡时长（秒）
const MOCK_PURCHASE_DELAY := 0.5                    # mock 模式模拟支付延迟
const ERR_NOT_AVAILABLE := "IAP_NOT_AVAILABLE"      # Android 未接入计费时的错误码

# GDD §12.1 IAP 商品清单（9 SKU），顺序即商店展示顺序。
const SKUS := {
	"remove_ads":    {"name": "去广告",       "price_yuan": 12, "type": "non_consumable", "icon": "🚫", "desc": "永久移除广告等待时间"},
	"energy_pack_3": {"name": "能量补充包×4", "price_yuan": 6,  "type": "consumable",     "icon": "🔋", "desc": "3000能量×4份"},
	"diamond_100":   {"name": "钻石×100",     "price_yuan": 6,  "type": "consumable",     "icon": "💎", "desc": "100钻石"},
	"diamond_600":   {"name": "钻石×600",     "price_yuan": 30, "type": "consumable",     "icon": "💎", "desc": "600钻石（赠送60）"},
	"newbie_pack":   {"name": "新手礼包",     "price_yuan": 6,  "type": "one_time",       "icon": "🎁", "desc": "钻石×200+补签卡×3+能量包×2"},
	"limited_skin":  {"name": "限定外观礼包", "price_yuan": 30, "type": "seasonal",       "icon": "👘", "desc": "限定季节皮肤+专属装饰"},
	"monthly_card":  {"name": "月卡",         "price_yuan": 30, "type": "subscription",   "icon": "💳", "desc": "每日钻石×20+金币×100+花瓣×20"},
	"garden_expand": {"name": "花园扩展包",   "price_yuan": 18, "type": "non_consumable", "icon": "🏡", "desc": "花园扩容+猫上限+4"},
	"breed_unlock":  {"name": "品种快速解锁", "price_yuan": 45, "type": "non_consumable", "icon": "🔓", "desc": "v1.1新品种提前解锁"},
}

# ── 购买标志（持久化到 iap_store section）──
var ads_removed: bool = false
var garden_expand_purchased: bool = false
var breed_fast_unlock: bool = false
var newbie_pack_purchased: bool = false
var limited_skin_owned: bool = false
var monthly_card_end_time: float = 0.0            # unix 时间戳，0=未激活
var _monthly_card_last_grant_date: String = ""    # 上次月卡每日发放的日期 key
var _makeup_cards: int = 0                         # 补签卡库存（新手礼包发放）

var _is_purchasing: bool = false

# ── 生命周期 ──

func _ready() -> void:
	# 真正的状态由 SaveManager.load_and_apply → apply_save() 注入。
	pass

# ── 购买入口 ──

# 发起购买，返回 purchase_completed 信号（调用方可 await 或提前 connect）。
func purchase(sku_id: String) -> Signal:
	if not SKUS.has(sku_id):
		push_warning("[IAPProvider] 未知 SKU：%s" % sku_id)
		call_deferred("_emit_result", sku_id, false)
		return purchase_completed

	if _is_android():
		# Android 真机计费未接入，返回失败（预留 Google Play Billing 接口）。
		push_warning("[IAPProvider] Android 计费未接入：%s" % ERR_NOT_AVAILABLE)
		call_deferred("_emit_result", sku_id, false)
		return purchase_completed

	if _is_purchasing:
		call_deferred("_emit_result", sku_id, false)
		return purchase_completed

	_start_mock_purchase(sku_id)
	return purchase_completed

# Editor/桌面 mock：0.5s 模拟支付延迟 → grant_product → 回报成功。
func _start_mock_purchase(sku_id: String) -> void:
	_is_purchasing = true
	var timer := get_tree().create_timer(MOCK_PURCHASE_DELAY)
	timer.timeout.connect(func() -> void:
		grant_product(sku_id)
		_is_purchasing = false
		_emit_result(sku_id, true)
	)

func _emit_result(sku_id: String, success: bool) -> void:
	purchase_completed.emit(sku_id, success)

func _is_android() -> bool:
	return OS.get_name() == "Android"

# ── 发放（按 type 分发）──

func grant_product(sku_id: String) -> void:
	var sku: Dictionary = SKUS.get(sku_id, {})
	if sku.is_empty():
		return

	match sku_id:
		"remove_ads":
			ads_removed = true
		"energy_pack_3":
			_grant_energy(3000.0, 4)
		"diamond_100":
			if CurrencyManager:
				CurrencyManager.add_diamonds(100, "iap:diamond_100")
		"diamond_600":
			if CurrencyManager:
				CurrencyManager.add_diamonds(660, "iap:diamond_600")   # 600 + 赠送 60
		"newbie_pack":
			if CurrencyManager:
				CurrencyManager.add_diamonds(200, "iap:newbie_pack")
			_makeup_cards += 3
			_grant_energy(3000.0, 2)
			newbie_pack_purchased = true
		"limited_skin":
			limited_skin_owned = true
		"monthly_card":
			_activate_monthly_card()
		"garden_expand":
			garden_expand_purchased = true
			_apply_garden_expand()
		"breed_unlock":
			breed_fast_unlock = true

	if SaveManager:
		SaveManager.save_all()

func _grant_energy(amount: float, times: int) -> void:
	if EnergyEngine == null:
		return
	for _i in range(max(times, 0)):
		EnergyEngine.add_pool_with_overflow(amount)

func _apply_garden_expand() -> void:
	# 花园扩容：网格/背包容量提升 + 猫上限 +4（均由各系统内部 clamp 到硬上限）。
	var ps := get_node_or_null("/root/PackageSystem")
	if ps and ps.has_method("set_capacity"):
		ps.set_capacity(64)
	if HatchEngine:
		HatchEngine.garden_expand_purchased = true
	var cs := get_node_or_null("/root/CatScreenManager")
	if cs and cs.has_method("set_max_cats"):
		cs.set_max_cats(int(cs.max_cats) + 4)

# ── 月卡 ──

func _activate_monthly_card() -> void:
	var now := Time.get_unix_time_from_system()
	# 已激活则顺延 30 天，否则从当前时间起算。
	var base: float = max(monthly_card_end_time, now)
	monthly_card_end_time = base + float(MONTHLY_CARD_DURATION)
	_monthly_card_last_grant_date = ""   # 允许激活当天立即发放一次
	process_monthly_card()

# 月卡每日发放：每天首次触发发放钻石/金币/爱心花瓣。冷启动与页面进入时调用。
func process_monthly_card() -> void:
	if monthly_card_end_time <= 0.0:
		return
	var now := Time.get_unix_time_from_system()
	if now >= monthly_card_end_time:
		return   # 已到期
	var today := _today_key()
	if _monthly_card_last_grant_date == today:
		return
	_monthly_card_last_grant_date = today
	if CurrencyManager:
		CurrencyManager.add_diamonds(20, "monthly_card")
		CurrencyManager.add_gold(100, "monthly_card")
		CurrencyManager.add_love_petals(20, "monthly_card")

func get_monthly_card_days_left() -> int:
	if monthly_card_end_time <= 0.0:
		return 0
	var remaining: float = monthly_card_end_time - Time.get_unix_time_from_system()
	if remaining <= 0.0:
		return 0
	return int(ceil(remaining / 86400.0))

# ── 查询 ──

# 非消耗/一次性/季度型是否已拥有。
func is_owned(sku_id: String) -> bool:
	match sku_id:
		"remove_ads":    return ads_removed
		"garden_expand": return garden_expand_purchased
		"breed_unlock":  return breed_fast_unlock
		"newbie_pack":   return newbie_pack_purchased
		"limited_skin":  return limited_skin_owned
		_:               return false

func is_ads_removed() -> bool:
	return ads_removed

func is_newbie_pack_purchased() -> bool:
	return newbie_pack_purchased

func is_limited_skin_owned() -> bool:
	return limited_skin_owned

func get_makeup_cards() -> int:
	return _makeup_cards

# 消耗一张补签卡；库存不足返回 false。
func consume_makeup_card() -> bool:
	if _makeup_cards <= 0:
		return false
	_makeup_cards -= 1
	if SaveManager:
		SaveManager.save_all()
	return true

# ── 存档（对齐 SaveManager 的 ConfigFile section "iap_store"）──

func apply_save(data: Dictionary) -> void:
	ads_removed = bool(data.get("ads_removed", false))
	garden_expand_purchased = bool(data.get("garden_expand_purchased", false))
	breed_fast_unlock = bool(data.get("breed_fast_unlock", false))
	newbie_pack_purchased = bool(data.get("newbie_pack_purchased", false))
	limited_skin_owned = bool(data.get("limited_skin_owned", false))
	monthly_card_end_time = float(data.get("monthly_card_end_time", 0.0))
	_monthly_card_last_grant_date = String(data.get("monthly_card_last_grant_date", ""))
	_makeup_cards = max(int(data.get("makeup_cards", 0)), 0)
	# 重新对齐已购买的持久效果（clamp 保证幂等）。
	if garden_expand_purchased:
		_apply_garden_expand()
	process_monthly_card()

func get_save_data() -> Dictionary:
	return {
		"ads_removed": ads_removed,
		"garden_expand_purchased": garden_expand_purchased,
		"breed_fast_unlock": breed_fast_unlock,
		"newbie_pack_purchased": newbie_pack_purchased,
		"limited_skin_owned": limited_skin_owned,
		"monthly_card_end_time": monthly_card_end_time,
		"monthly_card_last_grant_date": _monthly_card_last_grant_date,
		"makeup_cards": _makeup_cards,
	}

# ── 内部 ──

func _today_key() -> String:
	var date: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]
