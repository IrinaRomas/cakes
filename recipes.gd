extends RefCounted

const LEVEL_XP := [0, 25, 75]
const RECIPES := [
	{"id": "croissant", "title": "Круассан", "level": 1, "price": 15, "xp": 5, "prep": 2.0, "bake": 5.0, "batch": 6, "required": ["mixer", "oven", "display"], "stations": [2,0,1]},
	{"id": "cookie", "title": "Печенье", "level": 2, "price": 22, "xp": 6, "prep": 2.0, "bake": 6.0, "batch": 8, "required": ["mixer", "forming", "oven", "display"], "stations": [2,4,0,1]},
	{"id": "cupcake", "title": "Капкейк", "level": 3, "price": 35, "xp": 8, "prep": 3.0, "bake": 8.0, "batch": 6, "required": ["mixer", "oven", "decorator", "display"], "stations": [2,0,5,1]}
]

static func level_for_xp(total: int) -> int:
	var level := 1
	for i in range(LEVEL_XP.size()):
		if total >= LEVEL_XP[i]:
			level = i + 1
	return level

static func get_recipe(id: String) -> Dictionary:
	for recipe in RECIPES:
		if recipe.id == id:
			return recipe
	return RECIPES[0]

static func unlocked_ids(total: int) -> Array[String]:
	var ids: Array[String] = []
	for recipe in RECIPES:
		if recipe.level <= level_for_xp(total):
			ids.append(recipe.id)
	return ids
