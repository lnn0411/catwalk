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
		# ── 便利店 (convenience_store) ──
		_make("conv_store_orange_01", "便利店", BREED_ORANGE, "发现了一根会转的食物", "发现了一根会转的橙色食物，决定守候它直到它停下来。", "convenience_store"),
		_make("conv_store_british_01", "便利店", BREED_BRITISH, "机器里的东西一直在转", "那个机器里的东西，一直在转。我观察了很久，决定不必理解它。", "convenience_store"),
		_make("conv_store_siamese_01", "便利店", BREED_SIAMESE, "那根热狗一直在转喵！", "喵！那边有根热狗喵！它一直在转喵！我盯了好久它也没停喵！", "convenience_store"),
		# ── 公园长椅 (park_bench) ──
		_make("park_bench_orange_01", "公园长椅", BREED_ORANGE, "晒太阳角度刚刚好", "嗯……这把椅子晒太阳角度刚刚好。我在这里等你，等了很久。", "park_bench"),
		_make("park_bench_british_01", "公园长椅", BREED_BRITISH, "这是我的椅子了，请绕道", "这是我的椅子了，请绕道。", "park_bench"),
		_make("park_bench_siamese_01", "公园长椅", BREED_SIAMESE, "为什么不和我说话喵？", "有人来坐了又走了！来了又走了喵！为什么不和我说话喵？！", "park_bench"),
		# ── 地铁站 (subway_station) ──
		_make("subway_orange_01", "地铁站", BREED_ORANGE, "很多脚，都很急", "很多脚。嗯……都很急。我慢慢走，没关系的。", "subway_station"),
		_make("subway_british_01", "地铁站", BREED_BRITISH, "他们都很急，而我不是", "他们都很急，而我不是。差距，就是这样体现的。", "subway_station"),
		_make("subway_siamese_01", "地铁站", BREED_SIAMESE, "那个会发声的门喵！", "那个会发声的门喵！它开了！关了！又开了喵！太神奇了喵！", "subway_station"),
		# ── 书店 (bookstore) ──
		_make("bookstore_orange_01", "书店", BREED_ORANGE, "纸的味道比风更温柔", "纸的味道，比外面的风更温柔。我在这里睡了一会儿。", "bookstore"),
		_make("bookstore_british_01", "书店", BREED_BRITISH, "这些人类把思维装进了这里", "纸的味道比猫薄荷更令我迷醉。这些人类把自己的思维都装进了这里。", "bookstore"),
		_make("bookstore_siamese_01", "书店", BREED_SIAMESE, "上面有猫的图喵！", "好多纸！好多字！有一本上面有猫的图喵！我坐在那本上面了喵！", "bookstore"),
		# ── 咖啡馆 (cafe) ──
		_make("cafe_orange_01", "咖啡馆", BREED_ORANGE, "暖暖的，像你的手", "有人把一杯热的东西放到我旁边，嗯……暖暖的，像你的手。", "cafe"),
		_make("cafe_british_01", "咖啡馆", BREED_BRITISH, "拿铁和手心的温度没有区别", "拿铁的热度和某人手心的温度，没什么区别。", "cafe"),
		_make("cafe_siamese_01", "咖啡馆", BREED_SIAMESE, "我用爪子戳了一下喵！", "那个白色泡泡好神奇喵！我用爪子戳了一下喵！咖啡师看了我一眼喵！", "cafe"),
		# ── 医院走廊 (hospital_corridor) ──
		_make("hospital_orange_01", "医院走廊", BREED_ORANGE, "我坐在他们旁边", "来这里的人，眼睛里有什么东西……嗯。我坐在他们旁边，希望有帮助。", "hospital_corridor"),
		_make("hospital_british_01", "医院走廊", BREED_BRITISH, "他们都特别需要被看见", "不知道为什么，来这里的人类，都特别需要被看见。", "hospital_corridor"),
		_make("hospital_siamese_01", "医院走廊", BREED_SIAMESE, "我没有跑开喵", "这里好安静喵。有个老爷爷摸了我很久喵。我没有跑开喵。", "hospital_corridor"),
		# ── 天桥 (sky_bridge) ──
		_make("sky_bridge_orange_01", "天桥", BREED_ORANGE, "城市变小了", "从上面看，城市变小了。你也在某个地方，只是我还没找到你。", "sky_bridge"),
		_make("sky_bridge_british_01", "天桥", BREED_BRITISH, "我欣赏这种秩序感", "城市从这个高度看，很有条不紊。我欣赏这种秩序感。", "sky_bridge"),
		_make("sky_bridge_siamese_01", "天桥", BREED_SIAMESE, "我能看见它但它看不见我喵！", "可以看到好远好远喵！那边有只鸽子喵！我能看见它但它看不见我喵！", "sky_bridge"),
		# ── 夜市 (night_market) ──
		_make("night_market_orange_01", "夜市", BREED_ORANGE, "好多吃的，我就看看", "好多吃的……嗯……我就看看。（尾巴抖了一下）", "night_market"),
		_make("night_market_british_01", "夜市", BREED_BRITISH, "无法忽视的活力", "这种混乱有一种我无法认同但也无法完全忽视的活力。", "night_market"),
		_make("night_market_siamese_01", "夜市", BREED_SIAMESE, "我都想要喵！", "烤串！臭豆腐！糖葫芦！全都有喵！我都想要喵！", "night_market"),
		# ── 儿童游乐场 (playground) ──
		_make("playground_orange_01", "儿童游乐场", BREED_ORANGE, "有一个直接摸了我", "小的人类比大的人类更直接。有一个直接摸了我，我没有躲。", "playground"),
		_make("playground_british_01", "儿童游乐场", BREED_BRITISH, "我维持了一定距离", "小孩子的眼睛是诚实的。不过……我维持了一定距离。", "playground"),
		_make("playground_siamese_01", "儿童游乐场", BREED_SIAMESE, "我们一起跑了好久喵！", "他们跑来跑去喵！我也跑了喵！我们一起跑了好久喵！太开心了喵！", "playground"),
		# ── 雨天 (rainy_day) ──
		_make("rainy_orange_01", "雨天", BREED_ORANGE, "我在屋檐下等", "你没有告诉我今天会下雨。嗯……我在屋檐下等。你知道的，我总会等的。", "rainy_day"),
		_make("rainy_british_01", "雨天", BREED_BRITISH, "这是我自己的决定", "雨天不适合出门。但我出门了。这是我自己的决定。", "rainy_day"),
		_make("rainy_siamese_01", "雨天", BREED_SIAMESE, "值得喵！", "下雨了喵！我的毛毛湿了喵！但我还是看到了一只蜗牛喵！值得喵！", "rainy_day"),
		# ── 隐藏明信片 (好感Lv5解锁) ──
		_make("hidden_orange_01", "谢谢你选了我", BREED_ORANGE, "是你先选了我", "你每天都来。不是路过。是专门来。我在这里躺了很久，见过很多人。只有你，坐下来的时候，不是急着要走。所以我选了你。不是你先选的我——是我先选了你。你只是刚好也选了我。嗯。真好。", "hidden"),
		_make("hidden_british_01", "我的领地", BREED_BRITISH, "你是我唯一愿意分享领地的人类", "我曾以为这个花园是我的领地。后来发现——你才是。你坐在那里的时候，整片阳光都有了归属。我曾经不习惯承认这一点。但现在我可以说了。你是我唯一愿意分享我的领地的人类。就这样。", "hidden"),
		_make("hidden_siamese_01", "全世界最棒的事", BREED_SIAMESE, "排名第一：你回来了！", "全世界最棒的事喵！排名第一：你回来了！排名第二：你摸了我！排名第三：你跟我说话喵！排名第四：你给我好吃的！排名第五——其实没有第五了喵！有前面四条就够了喵！我今天很开心！因为我发现——不管我排了多少条，你最棒的那一条永远是'你在这里'喵！", "hidden"),
		# ── 季节限定 (冬季雪天) ──
		_make("seasonal_snow_night_01", "雪夜圣诞", BREED_ORANGE, "如果你在的话，再吵也没关系", "雪落下来的时候，世界变安静了。我很喜欢安静。但如果你在的话，再吵也没关系。", "seasonal"),
		_make("seasonal_winter_01", "冬晴午后", BREED_SIAMESE, "四舍五入就是你在摸我喵！", "冬天的阳光照在背上好舒服喵！暖洋洋的！有点像你摸我的感觉！虽然你没在摸我——但阳光摸了我！四舍五入就是你在摸我喵！", "seasonal"),
		# ── 成就明信片 (E4奖励) ──
		_make("achievement_complete_01", "整座城市写给你的明信片", BREED_ORANGE, "我们走过的每一处，都记得你", "那家便利店。那个公园。那条天桥。我们都去过。有时候一起去。有时候一个人去。每次回来都想告诉你——那棵树开花了。那个咖啡师今天换了新围裙。那只鸽子还是站在同一个地方。你看，我们走过的每一处，都记得你。这是整座城市，写给你的明信片。", "achievement"),
	]

static func get_by_id(postcard_id: String) -> PostcardData:
	for p in get_all():
		if p.id == postcard_id:
			return p
	return null

static func get_count() -> int:
	return get_all().size()

# 按地点类型分组获取
static func get_by_location_type(location_type: String) -> Array[PostcardData]:
	var result: Array[PostcardData] = []
	for p in get_all():
		if p.location_type == location_type:
			result.append(p)
	return result

# 获取所有明信片ID列表
static func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for p in get_all():
		ids.append(p.id)
	return ids

# 获取首发30张城市明信片ID（不含隐藏/季节/成就）
static func get_city_postcard_ids() -> Array[String]:
	var ids: Array[String] = []
	for p in get_all():
		if p.location_type in ["convenience_store", "park_bench", "subway_station", "bookstore", "cafe", "hospital_corridor", "sky_bridge", "night_market", "playground", "rainy_day"]:
			ids.append(p.id)
	return ids
