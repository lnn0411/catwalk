extends RefCounted
class_name DiaryPools

const BREEDS := ["orange", "british", "siamese"]

# 好感等级门槛：Lv.1=0, Lv.2=30, Lv.3=80, Lv.4=180, Lv.5=360
const GRADE_THRESHOLDS := [0, 30, 80, 180, 360]
const GRADE_COUNT := 4
const HIDDEN_INDEX := 4

const DIARY_POOLS := {
	"orange": [
		[
			['第一次观察你', '\u201c你走路的样子，不像是有什么目的地。嗯...我喜欢这样的人。\u201d'],
			['你的气味', '\u201c你身上有一种味道，不是食物，是...你。我闭上眼也能认出来。\u201d'],
			['你什么时候回来', '\u201c我听到脚步声就知道是不是你。不是你的话，我就继续睡。\u201d']
		],
		[
			['等待的哲学', '\u201c等你回来不是一件难事。难的是不知道等多久——但我从来不数。\u201d'],
			['今天看到的东西', '\u201c今天有一片叶子飘了很久才落地。我想告诉你来着。但你不在，我就自己看了。\u201d'],
			['你的手机', '\u201c你总是看那个发光的东西。我不理解它，但我理解它在让你开心。那就够了。\u201d']
		],
		[
			['关于食物的诚实', '\u201c我承认，有时候我是因为闻到气味才去门口的。但后来你就来了。\u201d'],
			['你摸我的时候', '\u201c你的手暖的时候，我呼噜得大声一点；冷的时候，我蹭久一点。这不是商量好的。\u201d'],
			['另一只猫', '\u201c今天我看到一只别的猫。它看了我一眼。我没理它。这里不差它一个位置。\u201d']
		],
		[
			['被选中的理由', '\u201c我见过很多人路过这里。只有你，走得慢，还会停下来看我。我想，这就是了。\u201d'],
			['如果有一天', '\u201c如果你不来了——嗯，我不太想写这个。但如果你真的不来了，我会记得你。\u201d'],
			['你睡着的时候', '\u201c你睡着的时候呼吸很慢。我坐在旁边听着。你的睡眠是我一天里最安静的时刻。\u201d']
		]
	],
	"british": [
		[
			['评估你', '\u201c你没有做什么让我反感的事。这是一个相当不错的开始。\u201d'],
			['这里的环境', '\u201c这个空间还算整洁。你打理它的方式，让我觉得你是一个认真的人。\u201d'],
			['你的声音', '\u201c你的声音比我预想的要低一些。不算难听。我允许你多说话。\u201d']
		],
		[
			['边界感的解释', '\u201c我不是冷漠。我只是相信，有些距离，是用来让彼此都好看的。\u201d'],
			['今天没有等你', '\u201c你回来晚了。我并不是在等。只是恰好走到了门口的位置。\u201d'],
			['关于呼噜', '\u201c我并非有意发出那种声音。那是一种...生理现象。请不要误解。\u201d']
		],
		[
			['第一次主动', '\u201c今天我坐到了你旁边。不是因为我想。是因为那个位置，光线恰好。\u201d'],
			['你的手', '\u201c你的手停下来的时候，我会稍微靠近一点。这不是邀请。只是——比较暖和。\u201d'],
			['另一个人类', '\u201c今天来了另一个人。我不认为他比你好。我去了另一个房间。\u201d']
		],
		[
			['承认', '\u201c如果你明天不来了，我不会在门口等。但我会知道少了什么。\u201d'],
			['我的选择', '\u201c我选择这里，不是因为这里最好。是因为你在这里。经过了充分的考虑。\u201d'],
			['一件小事', '\u201c今早你出门前看了我一眼。那个眼神——我花了整个上午分析。但我不想告诉你结果。\u201d']
		]
	],
	"siamese": [
		[
			['你终于来了', '\u201c我有好多话想跟你说！今天我看到一只鸟，一朵奇怪的云，一个小孩子看了我三秒！你来了就好了喵！\u201d'],
			['你好！你好！你好！', '\u201c你终于注意到我了！！我等了好——久——了！你去哪了喵？好玩吗？下次带我喵！\u201d'],
			['你的名字', '\u201c你叫什么名字？我叫...嗯...你还没给我起名字喵！快点想一个！要好的！要帅气的！\u201d']
		],
		[
			['为什么我喜欢你', '\u201c我想了想，我喜欢你是因为——你听我说话的时候，不看手机喵。\u201d'],
			['今天的大冒险', '\u201c今天我看到一只超级大的虫子！它有很多脚！我想抓它，但它爬走了喵！不过没关系！\u201d'],
			['你的背包', '\u201c你的包里有好多东西喵！我偷偷看了一眼！有一根笔！一个本子！还有——是给我的零食吗喵？！\u201d']
		],
		[
			['你走路的时候我在想什么', '\u201c你出门的时候，我在想你会经过什么地方。好不好玩。有没有好吃的。有没有别的猫！我有点嫉妒喵。\u201d'],
			['外面的世界', '\u201c我也好想出去！我想追鸽子！想爬树！想闻所有的花！不过你回来了我就不想了喵。\u201d'],
			['你摸别的猫了吗', '\u201c你今天回来身上有别的味道。是猫吗？是吗是吗是吗？我不高兴！但如果你摸了我我就不生气了喵。\u201d']
		],
		[
			['我说完了', '\u201c我说了好多话，你都听完了。没有人能听我说这么多的。所以——谢谢你喵。\u201d'],
			['最重要的事', '\u201c我今天想了一整天——最重要的事不是吃了什么、看到了什么。最重要的事是你在喵。\u201d'],
			['喵呜', '\u201c我其实没什么事。就是叫一下你。确认你还在。没事。你继续。我也继续在这里。\u201d']
		]
	]
}

const HIDDEN_DIARIES := {
	"orange": ['你不在的那几天', '\u201c那几天下雨，我一直在门口。不是在等你。就是在那里。\u201d'],
	"british": ['被人看见的感觉', '\u201c你总是先看我的眼睛。不是爪子，不是毛色。是眼睛。这让我有些不知所措。\u201d'],
	"siamese": ['深夜的话', '\u201c深夜我一个人在外面走，城市很安静。我想，还好我认识你喵。\u201d']
}

# 获取当前好感对应的最高等级索引（0-3），低于lv2返回-1
static func get_grade_for_friendship(friendship: int) -> int:
	for i in range(GRADE_COUNT - 1, -1, -1):
		if friendship >= GRADE_THRESHOLDS[i + 1]:
			return i
	return -1

# 获取已解锁的等级数
static func get_unlocked_count(friendship: int) -> int:
	var count := 0
	for i in range(GRADE_COUNT):
		if friendship >= GRADE_THRESHOLDS[i + 1]:
			count += 1
	return count

# 抽取一篇日记，从指定等级池中随机选
static func draw_for_grade(breed: String, grade_index: int, existing_picks: Array) -> int:
	if not DIARY_POOLS.has(breed):
		return 0
	var pool = DIARY_POOLS[breed][grade_index]
	var used: Array = []
	for p in existing_picks:
		if p is int and p >= 0:
			used.append(p)
	var available: Array = []
	for i in range(pool.size()):
		if i not in used:
			available.append(i)
	if available.is_empty():
		return 0
	return available[randi() % available.size()]

# 获取指定日记的标题和内容
static func get_diary(breed: String, grade_index: int, pick_index: int) -> Array:
	if grade_index == HIDDEN_INDEX:
		var h = HIDDEN_DIARIES.get(breed, HIDDEN_DIARIES["orange"])
		return [h[0], h[1]]
	var pool = DIARY_POOLS.get(breed, DIARY_POOLS["orange"])
	if grade_index < 0 or grade_index >= pool.size():
		return ["", ""]
	var grade = pool[grade_index]
	if pick_index < 0 or pick_index >= grade.size():
		pick_index = 0
	return [grade[pick_index][0], grade[pick_index][1]]
