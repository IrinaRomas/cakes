extends RefCounted

const LEVEL_XP := [0,25,75,150]
const RECIPES := [
	{"id":"croissant","title":"Круассан","level":1,"price":15,"xp":5,"prep":2.0,"bake":5.0,"batch":6,"required":["mixer","oven","display"],"stations":[2,0,1]},
	{"id":"cookie","title":"Печенье","level":2,"price":22,"xp":6,"prep":2.0,"bake":6.0,"batch":8,"required":["mixer","forming","oven","display"],"stations":[2,4,0,1]},
	{"id":"cupcake","title":"Капкейк","level":3,"price":35,"xp":8,"prep":3.0,"bake":8.0,"batch":6,"required":["mixer","oven","decorator","display"],"stations":[2,0,5,1]},
	{"id":"mousse","title":"Клубничный мусс","level":4,"price":40,"xp":10,"prep":3.0,"bake":0.0,"batch":6,"required":["mixer","fridge","decorator","display"],"stations":[2,6,5,1]}
]

static func level_for_xp(total: int) -> int:
	var level := 1
	for i in range(LEVEL_XP.size()):
		if total >= LEVEL_XP[i]: level=i+1
	return level

static func has_recipe(id: String) -> bool:
	for recipe in RECIPES:
		if recipe.id == id: return true
	return false

static func get_recipe(id: String) -> Dictionary:
	for recipe in RECIPES:
		if recipe.id == id: return recipe
	return RECIPES[0]

static func unlocked_ids(total: int) -> Array[String]:
	var result: Array[String] = []
	for recipe in RECIPES:
		if recipe.level <= level_for_xp(total): result.append(recipe.id)
	return result

static func steps(id: String) -> Array[Dictionary]:
	var recipe := get_recipe(id)
	var result: Array[Dictionary] = [{"station":2,"key":"preparing","title":"Подготовка","duration":recipe.prep,"passive":false}]
	if id=="cookie": result.append({"station":4,"key":"forming","title":"Формовка","duration":1.5,"passive":false})
	if id=="mousse":
		result.append({"station":6,"key":"cooling","title":"Охлаждение","duration":8.0,"passive":true})
	else:
		result.append({"station":0,"key":"baking","title":"Выпечка","duration":recipe.bake,"passive":true})
	if id in ["cupcake","mousse"]: result.append({"station":5,"key":"decorating","title":"Оформление","duration":2.0,"passive":false})
	result.append({"station":1,"key":"displaying","title":"Выкладка","duration":0.8,"passive":false})
	return result

static func route_title(id: String) -> String:
	var titles := PackedStringArray()
	for step in steps(id): titles.append(step.title)
	return " → ".join(titles)
