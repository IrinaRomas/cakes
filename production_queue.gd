extends RefCounted

const LIMIT := 5
const Catalog = preload("res://recipes.gd")
var waiting: Array[Dictionary] = []
var active: Dictionary = {}
var next_id := 1

func enqueue(recipe: String) -> int:
	if waiting.size()>=LIMIT or not Catalog.has_recipe(recipe): return -1
	var id := next_id
	next_id+=1
	waiting.append({"id":id,"recipe":recipe})
	return id

func begin_next() -> Dictionary:
	if not active.is_empty() or waiting.is_empty(): return {}
	active=waiting.pop_front()
	return active

func finish() -> void:
	active={}

func move_job(id: int, direction: int) -> bool:
	for i in range(waiting.size()):
		if waiting[i].id==id:
			var target:=i+direction
			if target<0 or target>=waiting.size(): return false
			var job: Dictionary=waiting[i]
			waiting.remove_at(i)
			waiting.insert(target,job)
			return true
	return false

func cancel(id: int) -> bool:
	for i in range(waiting.size()):
		if waiting[i].id==id:
			waiting.remove_at(i)
			return true
	return false

func write_save(data: ConfigFile) -> void:
	data.set_value("queue","waiting",waiting)
	data.set_value("queue","active",active)

func restore(data: ConfigFile, legacy_pending: String) -> void:
	waiting.clear()
	active={}
	next_id=1
	var saved_active=data.get_value("queue","active",{})
	var resume_id: String=str(saved_active.get("recipe","")) if saved_active is Dictionary else ""
	if resume_id.is_empty(): resume_id=legacy_pending
	if Catalog.has_recipe(resume_id):
		var job: Dictionary=saved_active.duplicate(true) if saved_active is Dictionary else {}
		job.id=next_id
		job.recipe=resume_id
		job.preparing=false
		job.erase("paid")
		job.erase("cost")
		waiting.append(job)
		next_id+=1
	var saved=data.get_value("queue","waiting",[])
	if saved is Array:
		for job in saved:
			if waiting.size()>=LIMIT+1: break
			if job is Dictionary and Catalog.has_recipe(str(job.get("recipe",""))):
				var restored: Dictionary=job.duplicate(true)
				restored.id=next_id
				restored.preparing=false
				restored.erase("paid")
				restored.erase("cost")
				waiting.append(restored)
				next_id+=1
