extends RefCounted

const STARTING_COINS := 500
const IDS := ["oven", "display", "mixer", "register", "forming", "decorator", "fridge", "display_extra", "assistant_station", "display_shelves", "oven_upgrade", "staff_walk", "staff_work", "staff_tasks"]
const STARTER := ["register"]
const LEGACY := ["oven", "display", "mixer", "register"]
const ITEMS := [
	{"id":"display", "title":"Витрина", "index":1, "level":1, "price":150, "description":"Хранит 18 изделий. Нужна для продажи любой выпечки."},
	{"id":"mixer", "title":"Стол с миксером", "index":2, "level":1, "price":100, "description":"Подготовка теста для всех десертов."},
	{"id":"oven", "title":"Печь", "index":0, "level":1, "price":200, "description":"Выпечка круассанов, печенья и капкейков."},
	{"id":"forming", "title":"Формовочный стол", "index":4, "level":2, "price":90, "description":"Раскатка теста и формовка печенья."},
	{"id":"decorator", "title":"Стол декора", "index":5, "level":3, "price":180, "description":"Украшение капкейков кремом после выпечки."},
	{"id":"fridge", "title":"Холодильник", "index":6, "level":4, "price":220, "description":"Охлаждение мусса. Холодные десерты готовятся без печи."},
	{"id":"display_shelves", "title":"Полки для витрин", "index":-1, "level":6, "price":180, "requires":["display"], "description":"24 места вместо 18 в каждой витрине. Две витрины хранят 48 изделий."},
	{"id":"oven_upgrade", "title":"Улучшение печи", "index":-1, "level":6, "price":220, "requires":["oven"], "description":"На 30% короче выпечка и на 2 изделия больше в каждой выпекаемой партии."},
	{"id":"assistant_station", "title":"Рабочее место помощника", "index":8, "level":7, "price":320, "requires":["mixer"], "description":"Стол для параллельной подготовки подноса. После покупки отдельно найми помощника в панели «Персонал»."},
	{"id":"staff_walk", "title":"Персонал: быстрый шаг", "index":-1, "level":5, "price":160, "requires":["register"], "description":"Кондитер и кассир перемещаются на 40% быстрее. Помогает при большом расстоянии между оборудованием."},
	{"id":"staff_work", "title":"Персонал: сноровка", "index":-1, "level":5, "price":200, "requires":["register"], "description":"На 25% короче ручные этапы готовки, приём и выдача заказов. Выпечку и охлаждение ускоряет только оборудование."},
	{"id":"staff_tasks", "title":"Персонал: организация", "index":-1, "level":8, "price":240, "requires":["register"], "description":"До 8 ожидающих производственных поручений вместо 5 и на 15 секунд больше ожидания у кассы. Гостей в зале по-прежнему не больше 3."},
	{"id":"register", "title":"Касса", "index":3, "level":1, "price":0, "description":"Установлена бесплатно. Здесь принимаются заказы."}
]

static func display_count(purchased: Array[String]) -> int:
	return int("display" in purchased)+int("display_extra" in purchased)

static func item(id: String) -> Dictionary:
	# Keep the saved second instance compatible with existing games.
	if id=="display_extra":
		var entry:=item("display").duplicate()
		entry.id=id
		entry.index=7
		entry.level=2
		return entry
	for entry in ITEMS:
		if entry.id == id:
			return entry
	return {}

static func missing(recipe: Dictionary, purchased: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for id in recipe.required:
		if id not in purchased:
			result.append(id)
	return result

static func missing_titles(recipe: Dictionary, purchased: Array[String]) -> String:
	var titles := PackedStringArray()
	for id in missing(recipe, purchased):
		titles.append(item(id).title)
	return ", ".join(titles)

static func prerequisites(entry: Dictionary, purchased: Array[String]) -> String:
	var names:=PackedStringArray()
	for id in entry.get("requires",[]):
		if id not in purchased: names.append(item(id).title)
	return ", ".join(names)
