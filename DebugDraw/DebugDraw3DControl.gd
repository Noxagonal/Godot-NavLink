extends Control



var points = []
var vectors = []
var paths = []
var texts = []

var debug_font_label_temp: Label
var debug_font: Font



func _enter_tree():
	debug_font_label_temp = Label.new()
	debug_font = debug_font_label_temp.get_font("")

func _exit_tree():
	debug_font_label_temp.queue_free()



class DrawPoint:
	var pos:Vector3
	var width:float
	var color:Color
	
	func _init(_position:Vector3, _width:float, _color:Color):
		pos = _position
		width = _width
		color = _color
	
	func draw(control, camera):
		var pos2d = camera.unproject_position(pos)
		var cross_size = 10.0
		var l1s = Vector2(+0.707, +0.707) * cross_size
		var l1e = Vector2(-0.707, -0.707) * cross_size
		var l2s = Vector2(+0.707, -0.707) * cross_size
		var l2e = Vector2(-0.707, +0.707) * cross_size
		control.draw_line(pos2d + l1s, pos2d + l1e, color, width)
		control.draw_line(pos2d + l2s, pos2d + l2e, color, width)



class DrawVector:
	var start:Vector3
	var end:Vector3
	var width:float
	var color:Color

	func _init(_start:Vector3, _end:Vector3, _width:float, _color:Color):
		start = _start
		end = _end
		width = _width
		color = _color

	func draw(control, camera):
		var start2d = camera.unproject_position(start)
		var end2d = camera.unproject_position(end)
		var dir = (end2d - start2d).angle()
		var arrow_angle = 2.75
		var arrow_line_1 = Vector2(cos(dir + arrow_angle), sin(dir + arrow_angle)) * 25.0
		var arrow_line_2 = Vector2(cos(dir - arrow_angle), sin(dir - arrow_angle)) * 25.0
		control.draw_line(start2d, end2d, color, width)
		control.draw_line(end2d, end2d + arrow_line_1, color, width)
		control.draw_line(end2d, end2d + arrow_line_2, color, width)



class DrawLinePath:
	var path:Array
	var width:float
	var start_color:Color
	var end_color:Color

	func _init(_path:Array, _width:float, _start_color:Color, _end_color:Color):
		path = _path
		width = _width
		start_color = _start_color
		end_color = _end_color

	func draw(control, camera):
		var path_last_element = len(path) - 1
		for i in range(0, path_last_element):
			var done_fraction:float = 0.0
			if path_last_element - 1 > 0:
				done_fraction = i / float(path_last_element - 1)
			var color = start_color * (1.0 - done_fraction) + end_color * done_fraction
			var start = path[i]
			var end = path[i + 1]
			var start2d = camera.unproject_position(start)
			var end2d = camera.unproject_position(end)
			# var dir = (end2d - start2d).angle()
			# var arrow_angle = 2.75
			# var arrow_line_1 = Vector2(cos(dir + arrow_angle), sin(dir + arrow_angle)) * 25.0
			# var arrow_line_2 = Vector2(cos(dir - arrow_angle), sin(dir - arrow_angle)) * 25.0
			control.draw_circle(start2d, width * 1.25, color)
			control.draw_line(start2d, end2d, color, width)
			# control.draw_line(end2d, end2d + arrow_line_1, color, width)
			# control.draw_line(end2d, end2d + arrow_line_2, color, width)
		
		if len(path):
			var end2d = camera.unproject_position(path.back())
			control.draw_circle(end2d, width * 1.25, end_color)



class DrawText:
	var position:Vector3
	var text:String
	var color:Color

	func _init(_position:Vector3, _text:String, _color:Color):
		position = _position
		text = _text
		color = _color

	func draw(control, camera):
		var position2d = camera.unproject_position(position)
		control.draw_string(control.debug_font, position2d, text, color)



func _process(delta):
	if not visible:
		return
	update()

func _draw():
	var camera = get_viewport().get_camera()
	
	for p in points:
		p.draw(self, camera)
	for p in vectors:
		p.draw(self, camera)
	for p in paths:
		p.draw(self, camera)
	for p in texts:
		p.draw(self, camera)
	
	points.clear()
	vectors.clear()
	paths.clear()
	texts.clear()
