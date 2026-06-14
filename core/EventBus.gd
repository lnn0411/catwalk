# EventBus — 集中式信号总线 (Autoload)
# 不要加 class_name，autoload 注册已提供全局名称
extends Node

signal step_updated(delta_steps: int, total_steps: int, tier: int)
signal energy_changed(pool: int, reserve: int, total_produced: int)
signal hatch_slot_updated(slot_id: int, status: int, progress: float)
signal hatch_completed(cat_id: String)
signal cat_spawned(cat_id: String, breed: String)
signal cat_interacted(cat_id: String, interaction_type: String)
signal emotion_changed(cat_id: String, emotion: String)
signal explore_dispatched(cat_id: String, return_time: float)
signal explore_returned(cat_id: String, reward_type: String)
signal weather_changed(weather: String)
signal time_period_changed(period: String)
signal achievement_unlocked(achievement_id: String, reward: Dictionary)
signal network_status_changed(online: bool)
signal save_completed(success: bool)
signal level_up(cat_id: String, from_level: int, to_level: int)
signal postcard_obtained(postcard_id: String, location_type: String)
signal signin_completed(day: int, reward: Dictionary)
signal currency_changed(gold: int, diamonds: int, petals: int)
signal inventory_changed(item_type: String, quantity: int)

# 新增信号
signal time_anomaly_detected(drift_seconds: float)
signal progressive_energy_routed(egg_index: int, amount: float)


# --- Emit 辅助方法 ---

func emit_step_updated(delta_steps: int, total_steps: int, tier: int) -> void:
	step_updated.emit(delta_steps, total_steps, tier)

func emit_energy_changed(pool: int, reserve: int, total_produced: int) -> void:
	energy_changed.emit(pool, reserve, total_produced)

func emit_hatch_slot_updated(slot_id: int, status: int, progress: float) -> void:
	hatch_slot_updated.emit(slot_id, status, progress)

func emit_hatch_completed(cat_id: String) -> void:
	hatch_completed.emit(cat_id)

func emit_cat_spawned(cat_id: String, breed: String) -> void:
	cat_spawned.emit(cat_id, breed)

func emit_cat_interacted(cat_id: String, interaction_type: String) -> void:
	cat_interacted.emit(cat_id, interaction_type)

func emit_emotion_changed(cat_id: String, emotion: String) -> void:
	emotion_changed.emit(cat_id, emotion)

func emit_explore_dispatched(cat_id: String, return_time: float) -> void:
	explore_dispatched.emit(cat_id, return_time)

func emit_explore_returned(cat_id: String, reward_type: String) -> void:
	explore_returned.emit(cat_id, reward_type)

func emit_weather_changed(weather: String) -> void:
	weather_changed.emit(weather)

func emit_time_period_changed(period: String) -> void:
	time_period_changed.emit(period)

func emit_achievement_unlocked(achievement_id: String, reward: Dictionary) -> void:
	achievement_unlocked.emit(achievement_id, reward)

func emit_network_status_changed(online: bool) -> void:
	network_status_changed.emit(online)

func emit_save_completed(success: bool) -> void:
	save_completed.emit(success)

func emit_level_up(cat_id: String, from_level: int, to_level: int) -> void:
	level_up.emit(cat_id, from_level, to_level)

func emit_postcard_obtained(postcard_id: String, location_type: String) -> void:
	postcard_obtained.emit(postcard_id, location_type)

func emit_signin_completed(day: int, reward: Dictionary) -> void:
	signin_completed.emit(day, reward)

func emit_currency_changed(gold: int, diamonds: int, petals: int) -> void:
	currency_changed.emit(gold, diamonds, petals)

func emit_inventory_changed(item_type: String, quantity: int) -> void:
	inventory_changed.emit(item_type, quantity)

func emit_time_anomaly_detected(drift_seconds: float) -> void:
	time_anomaly_detected.emit(drift_seconds)

func emit_progressive_energy_routed(egg_index: int, amount: float) -> void:
	progressive_energy_routed.emit(egg_index, amount)


# --- 通用工具方法 ---

# 通过信号名动态发射，args 为参数数组
func safe_emit(signal_name: String, args: Array) -> void:
	if not has_signal(signal_name):
		push_warning("EventBus.safe_emit: 未知信号 '%s'" % signal_name)
		return
	var call_args := [signal_name]
	call_args.append_array(args)
	callv("emit_signal", call_args)

# 检查指定信号是否有监听者
func has_listeners(signal_name: String) -> bool:
	if not has_signal(signal_name):
		return false
	return get_signal_connection_list(signal_name).size() > 0
