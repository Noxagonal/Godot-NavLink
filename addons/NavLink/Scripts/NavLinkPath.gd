tool
extends Spatial

class_name NavLinkPath



enum LINK_REQUIRE_TAGS_TYPE {ONE, ALL}



export var link_cost:float = 1.0 setget set_link_cost, get_link_cost
export var link_width:float = 1.0 setget set_link_width, get_link_width
export(PoolStringArray) var link_tags setget set_link_tags, get_link_tags
export(LINK_REQUIRE_TAGS_TYPE) var link_require_tags_type = LINK_REQUIRE_TAGS_TYPE.ONE setget set_link_require_tags_type, get_link_require_tags_type



var start_node_scene_template
var end_node_scene_template

var start_node
var end_node
var line_draw: Spatial
var origin_draw: MeshInstance

# var start_position: Vector3 = Vector3(0.0, 0.0, 0.0)
# var end_position: Vector3 = Vector3(0.0, 0.0, 1.0)


func _enter_tree():
	start_node_scene_template = preload("res://addons/NavLink/Scenes/NavLinkPathStart.tscn")
	end_node_scene_template = preload("res://addons/NavLink/Scenes/NavLinkPathEnd.tscn")
	
	if Engine.editor_hint:
		_setup_for_editor()
	else:
		if line_draw != null:
			remove_child(line_draw)
			line_draw.queue_free()
	
	start_node = $Start
	end_node = $End
	
	# start_position = start_node.transform.origin
	# end_position = end_node.transform.origin
	
	if not Engine.editor_hint:
		start_node.hide()
		end_node.hide()
	
	add_to_group("NavLinkPaths")

func _exit_tree():
	remove_from_group("NavLinkPaths")

func _ready():
	pass

func _process(delta):
	if Engine.editor_hint:
		_process_editor(delta)



func set_link_cost(new_link_cost:float):
	link_cost = new_link_cost

func get_link_cost() -> float:
	return link_cost

func get_link_travel_cost() -> float:
	return link_cost * start_node.global_transform.origin.distance_to(end_node.global_transform.origin)

func set_link_width(new_link_width:float):
	link_width = new_link_width

func get_link_width() -> float:
	return link_width

func set_link_tags(new_link_tags:PoolStringArray):
	link_tags = new_link_tags

func get_link_tags() -> PoolStringArray:
	return link_tags

func add_link_tag(tag:String):
	if not tag in link_tags:
		link_tags.append(tag)

func remove_link_tag(tag:String):
	var p = -1
	for i in range(0, len(link_tags)):
		if link_tags[i] == tag:
			p = i
			break
	if p > -1:
		link_tags.remove(p)

func set_link_require_tags_type(new_link_require_tags_type):
	link_require_tags_type = new_link_require_tags_type

func get_link_require_tags_type():
	return link_require_tags_type



func _setup_for_editor():
	if self != get_tree().get_edited_scene_root():
		start_node = _add_start_node_if_not_exist(Vector3(-1.0, 0.0, 0.0))
		end_node = _add_end_node_if_not_exist(Vector3(1.0, 0.0, 0.0))
		origin_draw = _add_visual_origin_node_if_not_exist("(Editor Only) Origin", Vector3.ZERO, Color.magenta)
		line_draw = _add_line_draw_node_if_not_exist("(Editor Only) LineDraw", Color.cyan)

func _process_editor(delta: float):
	var lenght = ($End.transform.origin - $Start.transform.origin).length()
	$"(Editor Only) LineDraw".transform.origin = (end_node.transform.origin + start_node.transform.origin) / 2.0
	$"(Editor Only) LineDraw/(Editor Only) MeshInstance".look_at(end_node.global_transform.origin, Vector3.UP)
	$"(Editor Only) LineDraw/(Editor Only) MeshInstance".scale = Vector3(1.0, 1.0, lenght)
	
	# start_position = start_node.transform.origin
	# end_position = end_node.transform.origin


func _add_start_node_if_not_exist(position:Vector3):
	var node = start_node
	if not has_node("Start"):
		node = start_node_scene_template.instance()
		node.name = "Start"
		node.transform.origin = position
	
		add_child(node)
		node.set_owner(get_tree().get_edited_scene_root())
	
	return node

func _add_end_node_if_not_exist(position:Vector3):
	var node = end_node
	if not has_node("End"):
		node = end_node_scene_template.instance()
		node.name = "End"
		node.transform.origin = position
	
		add_child(node)
		node.set_owner(get_tree().get_edited_scene_root())
	
	return node


func _add_visual_origin_node_if_not_exist(name:String, position:Vector3, color:Color) -> MeshInstance:
	var node: MeshInstance = null
	if not has_node(name):
		node = MeshInstance.new()
		node.name = name
		node.transform.origin = position
		
		var mesh = CubeMesh.new()
		mesh.size = Vector3(0.2, 0.2, 0.2)
		
		var material = SpatialMaterial.new()
		material.flags_unshaded = true
		material.albedo_color = color
		
		mesh.material = material
		node.mesh = mesh
		
		add_child(node)
		# node.set_owner(get_tree().get_edited_scene_root())
	
	return node


func _add_line_draw_node_if_not_exist(name:String, color:Color) -> Spatial:
	var node: Spatial = null
	if not has_node(name):
		node = Spatial.new()
		node.name = name
		
		var line_draw_mesh_instance = MeshInstance.new()
		line_draw_mesh_instance.name = "(Editor Only) MeshInstance"
		
		var mesh = CubeMesh.new()
		mesh.size = Vector3(0.025, 0.025, 1.0)
		
		var material = SpatialMaterial.new()
		material.flags_unshaded = true
		material.flags_no_depth_test = true
		material.albedo_color = color
		
		mesh.material = material
		line_draw_mesh_instance.mesh = mesh
		
		add_child(node)
		node.add_child(line_draw_mesh_instance)
		
		# line_draw_mesh_instance.set_owner(get_tree().get_edited_scene_root())
		# node.set_owner(get_tree().get_edited_scene_root())
	
	return node










