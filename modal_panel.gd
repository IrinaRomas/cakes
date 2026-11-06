extends Control

var panel: PanelContainer
var requested_size := Vector2i(600,540)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 1000
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := ColorRect.new()
	veil.color = Color(0.12,0.16,0.12,0.35)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	panel = PanelContainer.new()
	add_child(panel)
	hide()
	get_viewport().size_changed.connect(func():
		if visible:
			_fit()
	)

func popup_centered(dimensions: Vector2i = Vector2i.ZERO) -> void:
	if dimensions != Vector2i.ZERO:
		requested_size = dimensions
	get_parent().move_child(self, -1)
	show()
	_fit()
	call_deferred("_fit")

func _fit() -> void:
	var viewport := get_viewport_rect().size
	panel.size = Vector2(minf(requested_size.x, viewport.x-32), minf(requested_size.y, viewport.y-32))
	panel.position = (viewport-panel.size)*0.5
