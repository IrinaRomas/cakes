extends RefCounted

const STARTING_COINS := 500
const IDS := ["oven", "display", "mixer", "register", "forming", "decorator", "fridge"]
const STARTER := ["register"]
const LEGACY := ["oven", "display", "mixer", "register"]
const ITEMS := [
	{"id":"display", "title":"Витрина", "index":1, "level":1, "price":150, "description":"Хранит 18 изделий. Нужна для продажи любой выпечки."},
	{"id":"mixer", "title":"Стол с миксером", "index":2, "level":1, "price":100, "description":"Подготовка теста для всех десертов."},
	{"id":"oven", "title":"Печь", "index":0, "level":1, "price":200, "description":"Выпечка круассанов, печенья и капкейков."},
	{"id":"forming", "title":"Формовочный стол", "index":4, "level":2, "price":90, "description":"Раскатка теста и формовка печенья."},
	{"id":"decorator", "title":"Стол декора", "index":5, "level":3, "price":180, "description":"Украшение капкейков кремом после выпечки."},
	{"id":"fridge", "title":"Холодильник", "index":6, "level":4, "price":220, "description":"Охлаждение мусса. Холодные десерты готовятся без печи."},
	{"id":"register", "title":"Касса", "index":3, "level":1, "price":0, "description":"Установлена бесплатно. Здесь принимаются заказы."}
]

static func item(id: String) -> Dictionary:
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
