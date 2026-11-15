extends RefCounted
const GOALS=[
	{"title":"Первая выпечка","needs":{"croissant":6},"coins":30,"xp":60},
	{"title":"Любимые круассаны","needs":{"croissant":12},"coins":45,"xp":55},
	{"title":"Попробуйте печенье","needs":{"cookie":8},"coins":40,"xp":60},
	{"title":"На любой вкус","needs":{"croissant":6,"cookie":8},"coins":60,"xp":60},
	{"title":"Нежные капкейки","needs":{"cupcake":6},"coins":60,"xp":100},
	{"title":"Богатый ассортимент","needs":{"croissant":6,"cookie":8,"cupcake":6},"coins":90,"xp":100},
	{"title":"Холодный десерт","needs":{"mousse":6},"coins":70,"xp":300},
	{"title":"Десерты для всех","needs":{"cookie":24,"cupcake":18,"mousse":18},"coins":150,"xp":420},
	{"title":"Большой праздник","needs":{"croissant":30,"cookie":32,"cupcake":24,"mousse":24},"coins":220,"xp":600},
	{"title":"Мастерская сладостей","needs":{"croissant":48,"cookie":48,"cupcake":36,"mousse":36},"coins":300,"xp":800}
]
const Recipes=preload("res://recipes.gd")
const Equipment=preload("res://equipment_catalog.gd")
var index:=0
var active:=false
var counts: Dictionary={}
func sync(xp: int, purchased: Array[String]) -> void:
	if active or index>=GOALS.size(): return
	for id in GOALS[index].needs:
		var recipe=Recipes.get_recipe(id)
		if recipe.level>Recipes.level_for_xp(xp) or not Equipment.missing(recipe,purchased).is_empty(): return
	active=true
func sold(id: String) -> void:
	if not active or index>=GOALS.size() or not GOALS[index].needs.has(id): return
	counts[id]=mini(int(GOALS[index].needs[id]),int(counts.get(id,0))+1)
func complete() -> bool:
	if not active or index>=GOALS.size(): return false
	for id in GOALS[index].needs:
		if int(counts.get(id,0))<int(GOALS[index].needs[id]): return false
	return true
func claim() -> Dictionary:
	if not complete(): return {}
	var reward: Dictionary=GOALS[index]
	index+=1
	active=false
	counts={}
	return reward
func write_save(data: ConfigFile) -> void:
	data.set_value("tasks","index",index)
	data.set_value("tasks","active",active)
	data.set_value("tasks","counts",counts)
func restore(data: ConfigFile) -> void:
	index=clampi(int(data.get_value("tasks","index",0)),0,GOALS.size())
	active=bool(data.get_value("tasks","active",false)) and index<GOALS.size()
	counts={}
	var saved=data.get_value("tasks","counts",{})
	if saved is Dictionary and index<GOALS.size():
		for id in GOALS[index].needs:
			if saved.has(id): counts[id]=clampi(int(saved[id]),0,int(GOALS[index].needs[id]))
