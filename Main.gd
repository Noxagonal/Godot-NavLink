extends Spatial

signal follow_path(nav_link_path)



# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export var continous:bool = false

var hit_position:Vector3


func _ready():
	pass


func _process(delta):
	if continous:
		var nav_link_path = $NavLinkNavigation.get_nav_link_path(
			$StartPoint.global_transform.origin,
			hit_position
		)
		if not nav_link_path.empty():
			emit_signal("follow_path", nav_link_path)


func _on_Camera_surface_hit(position):
	hit_position = position
	var nav_link_path = $NavLinkNavigation.get_nav_link_path(
		$StartPoint.global_transform.origin,
		hit_position
	)
	if not nav_link_path.empty():
		emit_signal("follow_path", nav_link_path)


func _on_HSlider_value_changed(value):
	# Slider value changed. Relay to teleport link.
	var set_value = value / 50.0
	$NavLinks/TeleportLink.set_link_cost(set_value)
	$CanvasLayer/SliderValue.text = String(set_value)


func _on_CheckBox_toggled(button_pressed):
	# Door locked or unlocked
	var door_link = $NavLinks/DoorLink
	if button_pressed:
		door_link.add_tag("locked")
	else:
		door_link.remove_tag("locked")
	
	print(door_link.tags)








