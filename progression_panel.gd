extends "res://modal_panel.gd"
const Progression=preload("res://progression.gd")
var list: VBoxContainer
func _ready() -> void:
	super._ready()
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("f5f1e9")
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new()
	panel.add_child(box)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(520,280)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	list=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",14)
	scroll.add_child(list)
	var close:=Button.new()
	close.text="Вернуться в кондитерскую"
	close.custom_minimum_size.y=48
	close.pressed.connect(hide)
	box.add_child(close)
func show_map(xp: int) -> void:
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	var level:=Progression.level_for_xp(xp)
	for index in range(8):
		var label:=Label.new()
		label.size.x=520
		label.custom_minimum_size.x=520
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color",Color("344b3f") if index+1<=level else Color("74806f"))
		label.text="Уровень %d · %d опыта%s\n%s\nГостей одновременно: %d" % [index+1,Progression.LEVEL_XP[index]," · сейчас" if index+1==level else (" · пройден" if index+1<level else ""),Progression.MILESTONES[index],Progression.buyers(index+1)]
		list.add_child(label)
	popup_centered(Vector2i(580,520))
