extends Node2D

signal pressed
# Measured top-plane edge directions in the source atlas, one pair per object.
# Correct the small camera deviations in generated art to the room's exact axes.
const FRONT_EDGES := [Vector2(286, 134), Vector2(370,215), Vector2(322, 193), Vector2(471, 240), Vector2(397,262), Vector2(391,258), Vector2(305,143)]
const SIDE_EDGES := [Vector2(228, -143), Vector2(252,-160), Vector2(209, -154), Vector2(375, -221), Vector2(353,-252), Vector2(359,-258), Vector2(247,-149)]
const GROUND_ANCHORS := [Vector2(365, 550), Vector2(455,695), Vector2(365, 550), Vector2(620, 940), Vector2(450,660), Vector2(450,660), Vector2(450,670)]
const SOURCE_WIDTHS := [540.0, 650.0, 540.0, 850.0, 750.0, 750.0, 560.0]
var item_index := 0
var button: TextureButton

func setup(atlas: Texture2D, index: int, title: String) -> void:
	item_index = index
	button = TextureButton.new()
	button.texture_normal = atlas
	button.tooltip_text = title
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mask := BitMap.new()
	mask.create_from_image_alpha(atlas.get_image(), 0.5)
	button.texture_click_mask = mask
	button.position = -GROUND_ANCHORS[index]
	button.pressed.connect(func(): pressed.emit())
	add_child(button)

func fit_to_grid(cell_center: Vector2, unit: float, slope: float) -> void:
	var front: Vector2 = FRONT_EDGES[item_index]
	var side: Vector2 = SIDE_EDGES[item_index]
	var front_slope := front.y / front.x
	var side_slope := side.y / side.x
	var vertical_scale := 2.0 * slope / (front_slope - side_slope)
	var shear := slope - vertical_scale * front_slope
	var pixel_scale: float = 2.0 * unit / SOURCE_WIDTHS[item_index]
	transform = Transform2D(Vector2(pixel_scale, shear * pixel_scale), Vector2(0, vertical_scale * pixel_scale), cell_center)
