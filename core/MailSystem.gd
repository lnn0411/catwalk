# MailSystem — 节日挂号信调度 (Autoload)
# GDD v2.17 §2.2.1  T3-4 §5.5  基于客户端本地时间跨 0 点触发
extends Node

signal mail_delivered(mail: Dictionary)

# type: "fixed" | "window" | "computed"
# compute: "easter" | "thanksgiving"  (仅 computed 类型使用)
const HOLIDAYS: Array = [
	{
		"id": "spring_festival",
		"type": "window",
		"month_start": 1, "day_start": 25,
		"month_end": 2,   "day_end": 2,
		"title": "新春来信 · 春节快乐",
		"body": "主人，过年啦！乐园里的小伙伴们一起挂起了红灯笼，还包了许多糯糯的汤圆。新的一年，愿你万事顺遂、步步生花，阖家幸福安康。我会一直在这里陪着你哦~ 🧧",
		"sender": "猫步天下",
	},
	{
		"id": "valentines",
		"type": "fixed",
		"month": 2, "day": 14,
		"title": "粉色来信 · 情人节",
		"body": "今天是情人节，我悄悄在你的门口放了一束野花。不管你身边有没有人陪，记得今天要好好爱自己。被爱的感觉，从来都不需要理由。💌",
		"sender": "猫步天下",
	},
	{
		"id": "easter",
		"type": "computed",
		"compute": "easter",
		"title": "彩蛋来信 · 复活节",
		"body": "复活节快乐！我把染好色的彩蛋藏在了花丛里，你能找到几颗呢？春天已经悄悄爬进每一个角落，希望你也感受到那股暖融融的喜悦。🐣",
		"sender": "猫步天下",
	},
	{
		"id": "mid_autumn",
		"type": "fixed",
		"month": 9, "day": 15,
		"title": "月光来信 · 中秋节",
		"body": "今晚的月亮又大又圆，我爬到乐园最高的树上替你看了好久。月饼分你一半，思念留给自己。无论身在何处，都要记得抬头望望同一轮明月。🌕",
		"sender": "猫步天下",
	},
	{
		"id": "halloween",
		"type": "fixed",
		"month": 10, "day": 31,
		"title": "南瓜来信 · 万圣节",
		"body": "咚咚咚！不给糖就捣蛋哦！我戴上了小巫师帽，在乐园门口摆了一排会发光的南瓜灯。今晚的夜风带着一点甜，是属于你的糖果味万圣节。🎃",
		"sender": "猫步天下",
	},
	{
		"id": "thanksgiving",
		"type": "computed",
		"compute": "thanksgiving",
		"title": "暖心来信 · 感恩节",
		"body": "感恩节快乐！谢谢你让乐园变得这么有温度。谢谢你每一次的陪伴，每一次轻轻的点击。有你在，这里才真的像一个家。我也很感谢，遇见了你。🦃",
		"sender": "猫步天下",
	},
	{
		"id": "christmas",
		"type": "fixed",
		"month": 12, "day": 25,
		"title": "雪花来信 · 圣诞节",
		"body": "叮叮当，铃儿响！圣诞老爷爷把礼物偷偷放在了你的袜子里。我们在乐园里堆了一棵雪人，它的鼻子是我叼来的小胡萝卜。圣诞快乐，愿冬天因你而温暖。🎄",
		"sender": "猫步天下",
	},
]

var last_mail_check_date: String = ""
var mailed_holidays: Array = []

var _last_day_key: String = ""

func _ready() -> void:
	_last_day_key = _today_key()

# 由外部（GameLoop / Timer）每帧或定时调用，检测跨 0 点后派送节日邮件
func check_day_boundary() -> void:
	var today := _today_key()
	if today == _last_day_key:
		return
	_last_day_key = today
	_check_and_deliver(today)

func _check_and_deliver(date_key: String) -> void:
	var parts := date_key.split("-")
	var year  := int(parts[0])
	var month := int(parts[1])
	var day   := int(parts[2])
	for h: Dictionary in HOLIDAYS:
		var dedup: String = str(h["id"]) + "_" + str(year)
		if dedup in mailed_holidays:
			continue
		if _holiday_matches(h, year, month, day):
			mailed_holidays.append(dedup)
			last_mail_check_date = date_key
			mail_delivered.emit(_build_mail(h, date_key, year))

func _holiday_matches(h: Dictionary, year: int, month: int, day: int) -> bool:
	match h["type"]:
		"fixed":
			return month == int(h["month"]) and day == int(h["day"])
		"window":
			var s := _doy(year, int(h["month_start"]), int(h["day_start"]))
			var e := _doy(year, int(h["month_end"]),   int(h["day_end"]))
			var t := _doy(year, month, day)
			return t >= s and t <= e if s <= e else t >= s or t <= e
		"computed":
			var target: Dictionary
			if h["compute"] == "easter":
				target = _calc_easter_sunday(year)
			else:
				target = _calc_thanksgiving(year)
			return month == int(target["month"]) and day == int(target["day"])
	return false

# 匿名格里高利算法（Butcher / Anonymous Gregorian）计算复活节
func _calc_easter_sunday(year: int) -> Dictionary:
	var a := year % 19
	var b := year / 100
	var c := year % 100
	var d := b / 4
	var e := b % 4
	var f := (b + 8) / 25
	var g := (b - f + 1) / 3
	var h := (19 * a + b - d - g + 15) % 30
	var i := c / 4
	var k := c % 4
	var l := (32 + 2 * e + 2 * i - h - k) % 7
	var m := (a + 11 * h + 22 * l) / 451
	var raw := h + l - 7 * m + 114
	return {"month": raw / 31, "day": raw % 31 + 1}

# 11 月第 4 个星期四（美国感恩节）
func _calc_thanksgiving(year: int) -> Dictionary:
	var dow := _day_of_week(year, 11, 1)          # 0=Sun … 6=Sat
	var first_thu := 1 + (4 - dow + 7) % 7
	return {"month": 11, "day": first_thu + 21}

# Tomohiko Sakamoto 算法：返回 0=Sun, 1=Mon … 6=Sat
func _day_of_week(year: int, month: int, day: int) -> int:
	var t := [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
	var y := year - 1 if month < 3 else year
	return (y + y / 4 - y / 100 + y / 400 + t[month - 1] + day) % 7

# 年内第几天（用于窗口型节日范围判断）
func _doy(year: int, month: int, day: int) -> int:
	var dim := [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0:
		dim[2] = 29
	var n := 0
	for mo in range(1, month):
		n += dim[mo]
	return n + day

func _today_key() -> String:
	var dt := Time.get_datetime_dict_from_system(false)   # false = 本地时区
	return "%04d-%02d-%02d" % [int(dt["year"]), int(dt["month"]), int(dt["day"])]

func _build_mail(h: Dictionary, date_key: String, year: int) -> Dictionary:
	return {
		"id":     h["id"] + "_" + str(year),
		"title":  h["title"],
		"body":   h["body"],
		"sender": h["sender"],
		"date":   date_key,
		"read":   false,
	}

# ── 存档读写 ──────────────────────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	return {
		"last_mail_check_date": last_mail_check_date,
		"mailed_holidays":      mailed_holidays.duplicate(),
	}

func apply_save(data: Dictionary) -> void:
	last_mail_check_date = str(data.get("last_mail_check_date", ""))
	mailed_holidays = (data.get("mailed_holidays", []) as Array).duplicate()
	_last_day_key = _today_key()
	# 首次登录当天检查（离线期间跨过的节日不补发，只补当天）
	_check_and_deliver(_last_day_key)
