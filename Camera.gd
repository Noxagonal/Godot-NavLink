extends Camera

signal surface_hit(position)



var mouse_pressed: bool


func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT && event.is_pressed():
			mouse_pressed = true
		else:
			mouse_pressed = false


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func _process(delta):
	var mouse_position = get_viewport().get_mouse_position()
	var ray_origin = project_ray_origin(mouse_position)
	var ray_normal = project_ray_normal(mouse_position)
	var ray_end = ray_origin + ray_normal * get_zfar()
	var space_state = get_world().direct_space_state
	var result = space_state.intersect_ray(ray_origin, ray_end)
	if mouse_pressed:
		if not result.empty():
			emit_signal("surface_hit", result.position)
