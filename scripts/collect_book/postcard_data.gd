extends Resource
class_name PostcardData

const BREED_ORANGE := "orange"
const BREED_BRITISH := "british"
const BREED_SIAMESE := "siamese"

@export var id: String = ""
@export var location_name: String = ""
@export var sender_cat_species: String = ""
@export var description: String = ""
@export var back_text: String = ""
@export var location_type: String = ""

static func _make(p_id: String, p_loc: String, p_species: String, p_desc: String, p_back: String, p_type: String) -> PostcardData:
	var d := PostcardData.new()
	d.id = p_id; d.location_name = p_loc; d.sender_cat_species = p_species
	d.description = p_desc; d.back_text = p_back; d.location_type = p_type
	return d

static func get_all() -> Array[PostcardData]:
	return [
		_make("park_01", "城市公园", BREED_ORANGE, "阳光洒在长椅上的午后", "今天阳光很好，我在长椅上睡了一觉…醒来的时候，叶子落在我尾巴上。", "park"),
		_make("park_02", "樱花公园", BREED_SIAMESE, "花瓣飘落的季节", "樱花开了又落喵！我在树下追了半小时花瓣，一片都没抓到喵！", "park"),
		_make("street_01", "转角面包店", BREED_BRITISH, "烤面包的香味飘在巷子里", "转角那家面包店今天关门了。我路过的时候，觉得你应该也想闻一下那个味道。", "street"),
		_make("street_02", "旧书摊巷子", BREED_ORANGE, "巷子深处的安静角落", "这条巷子很窄，阳光只能挤进来一条。我趴在地上看它慢慢移动，看了整个下午。", "street"),
		_make("cafe_01", "猫尾咖啡馆", BREED_SIAMESE, "窗台上的最佳观景位", "咖啡馆老板看到我来了喵！给了我一碟牛奶。窗外的路人看到我在喝牛奶，都在笑喵！", "cafe"),
		_make("cafe_02", "清晨咖啡馆", BREED_BRITISH, "晨光里的第一杯咖啡", "早上的咖啡馆很安静，只有咖啡机的声音。我坐在窗边，保持优雅。", "cafe"),
		_make("sea_01", "海边栈道", BREED_ORANGE, "海风吹过傍晚的栈道", "海风把毛吹乱了。但我不介意。它和我一样，慢慢来就好。", "sea"),
		_make("sea_02", "灯塔下", BREED_SIAMESE, "灯塔的光一圈一圈转", "灯塔的光每十秒转一圈喵！我数了十七圈。然后忘记了为什么在数喵！", "sea"),
		_make("bookstore_01", "猫头鹰书店", BREED_BRITISH, "书架之间的午后", "书店老板是个安静的人。我们互相不打扰——他看书，我看他。", "bookstore"),
		_make("bookstore_02", "街角旧书店", BREED_ORANGE, "旧书的气味让人安心", "这里有很多纸张的气味。我钻到最底层的书架后面睡着了，老板找了半小时。", "bookstore"),
		_make("flower_01", "花店门口", BREED_SIAMESE, "水桶旁边的探险", "花店门口的水桶里有一只蝴蝶喵！我看了它很久，它飞走了喵！", "flower"),
		_make("flower_02", "向日葵花田", BREED_BRITISH, "花比我还高的地方", "向日葵都比我高。我走在里面，没有人看到我。这样很好。", "flower"),
	]

static func get_by_id(postcard_id: String) -> PostcardData:
	for p in get_all():
		if p.id == postcard_id:
			return p
	return null

static func get_count() -> int:
	return get_all().size()
