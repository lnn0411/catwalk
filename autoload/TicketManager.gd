extends Node

signal tickets_changed(count: int)
signal ticket_earned(source: String, count: int)
signal ticket_spent(count: int)

const STEPS_PER_TICKET := 1500
const DAILY_STEP_TICKET_MAX := 3
const DAILY_INTERACTION_TICKET_MAX := 2
const INTERACTIONS_PER_TICKET := 5
const DAILY_AD_TICKET_MAX := 3
const DAILY_COIN_TICKET_MAX := 2
const COIN_COST_PER_TICKET := 50
const LOGIN_TICKET_NORMAL := 2
const LOGIN_TICKET_NEW_PLAYER := 3
const NEW_PLAYER_DAYS := 7

var tickets: int = 0
var daily_step_progress: int = 0
var daily_step_tickets: int = 0
var daily_interaction_count: int = 0
var daily_interaction_tickets: int = 0
var daily_ad_tickets: int = 0
var daily_coin_tickets: int = 0
var _last_ticket_date: String = ""
var _login_claimed_today: bool = false

func _ready() -> void:
	_last_ticket_date = _today_key()
	_connect_step_engine()
	if EventBus != null and not EventBus.cat_interacted.is_connected(_on_cat_interacted):
		EventBus.cat_interacted.connect(_on_cat_interacted)
	await get_tree().process_frame
	_connect_step_engine()

func _connect_step_engine() -> void:
	if StepEngine != null and not StepEngine.steps_updated.is_connected(_on_steps_updated):
		StepEngine.steps_updated.connect(_on_steps_updated)

func _on_steps_updated(delta: int, _total: int) -> void:
	_check_daily_reset()
	if delta <= 0: return
	daily_step_progress += delta
	while daily_step_progress >= STEPS_PER_TICKET and daily_step_tickets < DAILY_STEP_TICKET_MAX:
		daily_step_progress -= STEPS_PER_TICKET
		daily_step_tickets += 1
		_add_tickets(1, "steps")

func _on_cat_interacted(_cat_id: String, _interaction_type: String) -> void:
	add_interaction(1)

func add_interaction(count: int = 1) -> void:
	_check_daily_reset()
	daily_interaction_count += count
	while daily_interaction_count >= INTERACTIONS_PER_TICKET and daily_interaction_tickets < DAILY_INTERACTION_TICKET_MAX:
		daily_interaction_count -= INTERACTIONS_PER_TICKET
		daily_interaction_tickets += 1
		_add_tickets(1, "interaction")

func add_login_bonus(is_new_player: bool) -> void:
	_check_daily_reset()
	if _login_claimed_today:
		return
	_login_claimed_today = true
	var amount = LOGIN_TICKET_NEW_PLAYER if is_new_player else LOGIN_TICKET_NORMAL
	_add_tickets(amount, "login")

func add_ad_ticket() -> bool:
	_check_daily_reset()
	if daily_ad_tickets >= DAILY_AD_TICKET_MAX: return false
	daily_ad_tickets += 1
	_add_tickets(1, "ad")
	return true

func buy_with_coins() -> bool:
	_check_daily_reset()
	if daily_coin_tickets >= DAILY_COIN_TICKET_MAX: return false
	if not CurrencyManager.spend_gold(COIN_COST_PER_TICKET): return false
	daily_coin_tickets += 1
	_add_tickets(1, "coin")
	return true

func spend_ticket() -> bool:
	_check_daily_reset()
	if tickets <= 0: return false
	tickets -= 1
	ticket_spent.emit(1)
	tickets_changed.emit(tickets)
	return true

func get_tickets() -> int: return tickets

func is_login_claimed_today() -> bool:
	_check_daily_reset()
	return _login_claimed_today

func get_daily_remaining() -> Dictionary:
	_check_daily_reset()
	return {
		"steps": DAILY_STEP_TICKET_MAX - daily_step_tickets,
		"steps_progress": daily_step_progress,
		"interaction": DAILY_INTERACTION_TICKET_MAX - daily_interaction_tickets,
		"ad": DAILY_AD_TICKET_MAX - daily_ad_tickets,
		"coin": DAILY_COIN_TICKET_MAX - daily_coin_tickets,
	}

func get_save_data() -> Dictionary:
	return {
		"tickets": tickets,
		"daily_step_progress": daily_step_progress,
		"daily_step_tickets": daily_step_tickets,
		"daily_interaction_count": daily_interaction_count,
		"daily_interaction_tickets": daily_interaction_tickets,
		"daily_ad_tickets": daily_ad_tickets,
		"daily_coin_tickets": daily_coin_tickets,
		"last_ticket_date": _last_ticket_date,
		"login_claimed_today": _login_claimed_today,
	}

func apply_save(data: Dictionary) -> void:
	tickets = int(data.get("tickets", 0))
	daily_step_progress = int(data.get("daily_step_progress", 0))
	daily_step_tickets = int(data.get("daily_step_tickets", 0))
	daily_interaction_count = int(data.get("daily_interaction_count", 0))
	daily_interaction_tickets = int(data.get("daily_interaction_tickets", 0))
	daily_ad_tickets = int(data.get("daily_ad_tickets", 0))
	daily_coin_tickets = int(data.get("daily_coin_tickets", 0))
	_last_ticket_date = String(data.get("last_ticket_date", _today_key()))
	_login_claimed_today = bool(data.get("login_claimed_today", false))
	_check_daily_reset()

func _add_tickets(amount: int, source: String) -> void:
	tickets += amount
	ticket_earned.emit(source, amount)
	tickets_changed.emit(tickets)

func _check_daily_reset() -> void:
	var today = _today_key()
	if _last_ticket_date == today: return
	daily_step_progress = 0
	daily_step_tickets = 0
	daily_interaction_count = 0
	daily_interaction_tickets = 0
	daily_ad_tickets = 0
	daily_coin_tickets = 0
	_login_claimed_today = false
	_last_ticket_date = today

func _today_key() -> String:
	var date = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [date.year, date.month, date.day]
