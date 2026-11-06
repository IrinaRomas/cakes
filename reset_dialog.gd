extends "res://modal_panel.gd"

signal confirmed
var title := "Начать новую игру?"
var dialog_text := ""
var ok_button_text := "Начать заново"
var cancel_button_text := "Отмена"

func _ready() -> void:
	super._ready()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f5f1e9")
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel",style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",16)
	panel.add_child(box)
	for text in [title,dialog_text]:
		var label := Label.new()
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 460
		label.size.x = 460
		label.add_theme_color_override("font_color",Color("344b3f"))
		box.add_child(label)
	var row := HBoxContainer.new()
	box.add_child(row)
	var cancel := Button.new()
	cancel.text = cancel_button_text
	cancel.custom_minimum_size.y = 48
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(hide)
	row.add_child(cancel)
	var accept := Button.new()
	accept.text = ok_button_text
	accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept.pressed.connect(func(): hide(); confirmed.emit())
	row.add_child(accept)
