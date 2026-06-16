# MailSystem — 节日挂号信调度逻辑 (Autoload)
# GDD v2.17 §2.2.1 二、· T3-4 §5.5
# 基于客户端 Local Time 跨越 0 点进行本地化调度
extends Node

signal mail_delivered(mail_data: Dictionary)

# 邮件模板（占位——美术素材后续替换）
const MAIL_TEMPLATES := {
	"spring_festival": {
		"title_zh": "森林来信 · 春节",
		"body_zh": "主人！森林乐园今天挂满了红灯笼，我给蝴蝶们讲了我们的故事。新年快乐，我很想你。",
		"season": "spring",
		"month": 2,
		"day": 10,
	},
	"mid_autumn": {
		"title_zh": "森林来信 · 中秋",
		"body_zh": "今晚的月亮和你的眼睛一样圆。我在乐园最高的树上，替你看了很久的月亮。",
		"season": "autumn",
		"month": 9,
		"day": 15,
	},
	"thanksgiving": {
		"title_zh": "森林来信 · 感恩节",
		"body_zh": "谢谢你让我住进了这个乐园。这里有很多新朋友，但没有一个能替代你掌心的温度。",
		"season": "autumn",
		"month": 11,
		"day": 28,
	},
	"christmas": {
		"title_zh": "森林来信 · 圣诞",
		"body_zh": "我们在森林里堆了一棵小雪人。它的鼻子是我从厨房叼来的小胡萝卜。圣诞快乐。",
		"season": "winter",
		"month": 12,
		"day": 25,
	},
}

var _last_check_date: String = ""

func _ready() -> void:
	pass

# 每帧或定时调用：跨越 0 点后检查是否有节日邮件需要派发
func check_mail() -> void:
	var today: String = _today_key()
	if today == _last_check_date:
		return
	_last_check_date = today

	var dt: Dictionary = Time.get_date_dict_from_system()
	var month: int = int(dt["month"])
	var day: int = int(dt["day"])

	for _template_name in MAIL_TEMPLATES:
		var tpl: Dictionary = MAIL_TEMPLATES[_template_name]
		if int(tpl["month"]) == month and int(tpl["day"]) == day:
			mail_delivered.emit(tpl)

func _today_key() -> String:
	var dt: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(dt["year"]), int(dt["month"]), int(dt["day"])]

# 存档读写
func apply_save(data: Dictionary) -> void:
	_last_check_date = String(data.get("last_mail_check_date", ""))

func get_save_data() -> Dictionary:
	return {"last_mail_check_date": _last_check_date}
