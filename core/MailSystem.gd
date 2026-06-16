# MailSystem — 节日挂号信调度自动加载 (Autoload)
# GDD v2.17 §2.2.1 二、· T3-4 §5.5
# 基于客户端 Local Time 跨越 0 点进行本地化调度
extends Node

signal mail_delivered(mail: Dictionary)

# 节日定义：window=[month_start,day_start,month_end,day_end]，fixed=[month,day]
const HOLIDAYS: Array = [
	{
		"id": "spring_festival",
		"title": "森林来信 · 春节",
		"body": "主人！森林乐园今天挂满了红灯笼，我给蝴蝶们讲了我们的故事。\n新年快乐，我很想你。\n——你的小家伙",
		"sender": "乐园信差",
		"type": "window",
		"month_start": 1, "day_start": 25,
		"month_end": 2, "day_end": 2,
	},
	{
		"id": "valentines",
		"title": "森林来信 · 情人节",
		"body": "今天松鼠姐姐在树洞门口偷偷放了一颗松果，说是送给最喜欢的人。\n我把它留好了，等你来拿。\n——你的小家伙",
		"sender": "乐园信差",
		"type": "fixed",
		"month": 2, "day": 14,
	},
	{
		"id": "easter",
		"title": "森林来信 · 复活节",
		"body": "乐园里的兔子今早藏了好多彩蛋，我数了数，少了一颗——那颗留给你的。\n愿你总能找到属于自己的惊喜。\n——你的小家伙",
		"sender": "乐园信差",
		"type": "computed",
		"compute": "easter",
	},
	{
		"id": "mid_autumn",
		"title": "森林来信 · 中秋",
		"body": "今晚的月亮和你的眼睛一样圆。\n我在乐园最高的树上，替你看了很久的月亮。\n——你的小家伙",
		"sender": "乐园信差",
		"type": "fixed",
		"month": 9, "day": 15,
	},
	{
		"id": "halloween",
		"title": "森林来信 · 万圣节",
		"body": "乐园今晚点起了南瓜灯，小狐狸画了个大胡子，把大家都逗笑了。\n我给你留了一颗最甜的糖。\n——你的小家伙",
		"sender": "乐园信差",
		"type": "fixed",
		"month": 10, "day": 31,
	},
	{
		"id": "thanksgiving",
		"title": "森林来信 · 感恩节",
		"body": "谢谢你让我住进了这个乐园。这里有很多新朋友，但没有一个能替代你掌心的温度。\n——你的小家伙",
		"sender": "乐园信差",
		"type": "computed",
		"compute": "thanksgiving",
	},
	{
		"id": "christmas",
		"title": "森林来信 · 圣诞",
		"body": "我们在森林里堆了一棵小雪人，它的鼻子是我从厨房叼来的小胡萝卜。\n圣诞快乐，愿你被温柔对待。\n——你的小家伙",
		"sender": "乐园信差",
		"type": "fixed",
		"month": 12, "day": 25,
	},
]

var last_mail_check_date: String = ""
var mailed_holidays: Array = []

func _ready() -> void:
	pass

# 每帧或定时调用：跨越 0 点后检查是否有节日邮件需要派发
func check_day_boundary() -> void:
	var today: String = _today_key()
	if today == last_mail_check_date:
		return
	last_mail_check_date = today

	var dt: Dictionary = Time.get_date_dict_from_system()
	var year: int  = int(dt["year"])
	var month: int = int(dt["month"])
	var day: int   = int(dt["day"])

	for holiday in HOLIDAYS:
		if _holiday_matches(holiday, year, month, day):
			var dedup_key: String = "%s_%d" % [holiday["id"], year]
			if dedup_key in mailed_holidays:
				continue
			mailed_holidays.append(dedup_key)
			var letter: Dictionary = _build_letter(holiday, year, month, day)
			mail_delivered.emit(letter)

func _holiday_matches(h: Dictionary, year: int, month: int, day: int) -> bool:
	match h["type"]:
		"fixed":
			return month == int(h["month"]) and day == int(h["day"])
		"window":
			var sm: int = int(h["month_start"])
			var sd: int = int(h["day_start"])
			var em: int = int(h["month_end"])
			var ed: int = int(h["day_end"])
			var cur: int = month * 100 + day
			var start: int = sm * 100 + sd
			var end_: int  = em * 100 + ed
			return cur >= start and cur <= end_
		"computed":
			var target: Dictionary = {}
			if h["compute"] == "easter":
				target = _calc_easter_sunday(year)
			elif h["compute"] == "thanksgiving":
				target = _calc_thanksgiving(year)
			if target.is_empty():
				return false
			return month == int(target["month"]) and day == int(target["day"])
	return false

func _build_letter(h: Dictionary, year: int, month: int, day: int) -> Dictionary:
	return {
		"id": h["id"],
		"title": h["title"],
		"body": h["body"],
		"sender": h["sender"],
		"date": "%04d-%02d-%02d" % [year, month, day],
		"read": false,
	}

# 匿名格里高利算法计算复活节（公历）
func _calc_easter_sunday(year: int) -> Dictionary:
	var a: int = year % 19
	var b: int = year / 100
	var c: int = year % 100
	var d: int = b / 4
	var e: int = b % 4
	var f: int = (b + 8) / 25
	var g: int = (b - f + 1) / 3
	var h: int = (19 * a + b - d - g + 15) % 30
	var i: int = c / 4
	var k: int = c % 4
	var l: int = (32 + 2 * e + 2 * i - h - k) % 7
	var m: int = (a + 11 * h + 22 * l) / 451
	var month: int = (h + l - 7 * m + 114) / 31
	var day: int   = ((h + l - 7 * m + 114) % 31) + 1

	# 题目要求第三个周日 4 月 —— 若算出结果非 4 月则回退到 4 月第三个周日
	if month != 4:
		# 计算 4 月第三个周日
		return _third_sunday_in_april(year)
	return {"month": month, "day": day}

# 4 月第三个周日（复活节不在 4 月时的回退，以及 spec 要求的 "3rd Sun Apr"）
func _third_sunday_in_april(year: int) -> Dictionary:
	# 找出 4/1 是星期几（0=Sunday … 6=Saturday 采用 Godot 的 weekday）
	var ts: int = Time.get_unix_time_from_datetime_dict({
		"year": year, "month": 4, "day": 1,
		"hour": 12, "minute": 0, "second": 0
	})
	var wd: int = Time.get_datetime_dict_from_unix_time(ts)["weekday"]  # 0=Sun
	var days_to_first_sun: int = (7 - wd) % 7
	var third_sun_day: int = 1 + days_to_first_sun + 14
	return {"month": 4, "day": third_sun_day}

# 11 月第四个星期四（感恩节）
func _calc_thanksgiving(year: int) -> Dictionary:
	var ts: int = Time.get_unix_time_from_datetime_dict({
		"year": year, "month": 11, "day": 1,
		"hour": 12, "minute": 0, "second": 0
	})
	var wd: int = Time.get_datetime_dict_from_unix_time(ts)["weekday"]  # 0=Sun
	# Thursday = 4
	var days_to_first_thu: int = (4 - wd + 7) % 7
	var fourth_thu_day: int = 1 + days_to_first_thu + 21
	return {"month": 11, "day": fourth_thu_day}

func _today_key() -> String:
	var dt: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(dt["year"]), int(dt["month"]), int(dt["day"])]

# 存档读写
func apply_save(data: Dictionary) -> void:
	last_mail_check_date = str(data.get("last_mail_check_date", ""))
	var raw: Variant = data.get("mailed_holidays", [])
	mailed_holidays = raw if raw is Array else []

func get_save_data() -> Dictionary:
	return {
		"last_mail_check_date": last_mail_check_date,
		"mailed_holidays": mailed_holidays,
	}
