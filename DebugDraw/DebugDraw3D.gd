extends CanvasLayer

var debug_draw_control: Control

func _exit_tree():
	debug_draw_control.queue_free()

func _ready():
	if not InputMap.has_action("toggle_debug"):
		InputMap.add_action("toggle_debug")
		var ev = InputEventKey.new()
		ev.scancode = KEY_F1
		InputMap.action_add_event("toggle_debug", ev)
	debug_draw_control = $Control

func _input(event):
	if event.is_action_pressed("toggle_debug"):
		for n in get_children():
			n.visible = not n.visible

func draw_point(position:Vector3, width:float = 3.0, color:Color = Color.magenta):
	debug_draw_control.points.append(debug_draw_control.DrawVector.new(position, width, color))

func draw_vector(start:Vector3, end:Vector3, width:float = 3.0, color:Color = Color.magenta):
	debug_draw_control.vectors.append(debug_draw_control.DrawVector.new(start, end, width, color))

func draw_path(path:Array, width:float = 3.0, start_color:Color = Color.green, end_color:Color = Color.red):
	debug_draw_control.paths.append(debug_draw_control.DrawLinePath.new(path, width, start_color, end_color))

func draw_text(position:Vector3, text:String, color:Color = Color.magenta):
	debug_draw_control.texts.append(debug_draw_control.DrawText.new(position, text, color))
