extends RefCounted
const Catalog=preload("res://recipes.gd")
var sales_income:=0

func quote(id: String, purchased: Array[String], _level: int) -> Dictionary:
	var recipe:=Catalog.get_recipe(id).duplicate(true)
	if "oven_upgrade" in purchased and id!="mousse":
		recipe.batch+=2
		recipe.bake*=0.7
	recipe.work_factor=0.75 if "staff_work" in purchased else 1.0
	recipe.prep*=recipe.work_factor
	recipe.revenue=int(recipe.batch)*int(recipe.price)
	return recipe

func write_save(data: ConfigFile) -> void:
	data.set_value("economy","version",2)
	data.set_value("economy","sales",sales_income)

func restore(data: ConfigFile) -> void:
	sales_income=maxi(0,int(data.get_value("economy","sales",0)))
