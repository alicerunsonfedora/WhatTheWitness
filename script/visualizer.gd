extends Node

class PuzzleCanvas:
	
	var drawing_target
	var view_scale = 100.0
	var view_origin = Vector2(200, 300)
	
	var puzzle
		
	func normalize_view(canvas_size):
		if (len(puzzle.vertices) == 0):
			return
		var min_x = puzzle.vertices[0].pos.x
		var max_x = puzzle.vertices[0].pos.x
		var min_y = puzzle.vertices[0].pos.y
		var max_y = puzzle.vertices[0].pos.y
		for vertex in puzzle.vertices:
			max_x = max(max_x, vertex.pos.x)
			min_x = min(min_x, vertex.pos.x)
			max_y = max(max_y, vertex.pos.y)
			min_y = min(min_y, vertex.pos.y)
		view_scale = min(canvas_size.x * 0.8 / (max_x - min_x + 0.8), 
						 canvas_size.y * 0.8 / (max_y - min_y + 0.8))
		view_origin = canvas_size / 2 - Vector2((max_x + min_x) / 2, (max_y + min_y) / 2) * view_scale
	
	func add_circle(pos, radius, color):
		drawing_target.draw_circle(pos * view_scale, radius * view_scale - 0.5, color)
		drawing_target.draw_arc(pos * view_scale, radius * view_scale - 0.5, 0.0, 2 * PI, 64, color, 1.0, true)
		
	func add_line(pos1, pos2, width, color):
		drawing_target.draw_line(pos1 * view_scale, pos2 * view_scale, color, width * view_scale, true)
	
	func add_rect(pos1, pos2, width, color):
		drawing_target.draw_line(Vector2((pos1.x + pos2.x) / 2, pos1.y) * view_scale, Vector2((pos1.x + pos2.x) / 2, pos2.y) * view_scale, color, (pos2.x - pos1.x) * view_scale, true)
	
	func add_texture(center, size, texture):
		var origin = center * view_scale
		var screen_size = size * view_scale
		var rect = Rect2(origin - screen_size / 2, screen_size)
		drawing_target.draw_texture_rect(texture, rect, false)
		
	func add_polygon(pos_list, color):
		var result_list = []
		for pos in pos_list:
			result_list.push_back(pos * view_scale)
		drawing_target.draw_polygon(result_list, PoolColorArray([color]), [], null, null, true)

	func screen_to_world(position):
		return (position - view_origin) / view_scale

	func world_to_screen(position):
		return position * view_scale

	func draw_puzzle(target):
		drawing_target = target
		drawing_target.draw_set_transform(view_origin, 0.0, Vector2(1.0, 1.0))
		for vertex in puzzle.vertices:
			if (!vertex.hidden):
				add_circle(vertex.pos, puzzle.line_width * 0.5, puzzle.line_color)
		for edge in puzzle.edges:
			add_line(edge.start.pos, edge.end.pos, puzzle.line_width, puzzle.line_color)
		for vertex in puzzle.vertices:
			if (vertex.decorator != null):
				drawing_target.draw_set_transform(view_origin + vertex.pos * view_scale, vertex.decorator.angle, Vector2(1.0, 1.0))
				vertex.decorator.draw_foreground(self, vertex, 0, puzzle)

		drawing_target.draw_set_transform(view_origin, 0.0, Vector2(1.0, 1.0))
		for decorator in puzzle.decorators:
			decorator.draw_foreground(self, null, -1, puzzle)

	func draw_solution(target, solution):
		drawing_target = target
		drawing_target.draw_set_transform(view_origin, 0.0, Vector2(1.0, 1.0))
		if (solution.started):
			var state = solution.state_stack[-1]
			var main_way = Solution.MAIN_WAY
			var vertices_main_way = state.vertices[main_way]
			for way in range(puzzle.n_ways):
				var vertices_way = state.vertices[way]
				var color = puzzle.solution_colors[way]
				if (solution.validity == -1):
					color = Color.black
				var last_pos = puzzle.vertices[vertices_way[0]].pos
				var delta_shift = Vector2.ZERO
				add_circle(puzzle.vertices[vertices_way[0]].pos, puzzle.start_size, color)
				for i in range(1, len(vertices_way)):
					var segment = [puzzle.vertices[vertices_way[i - 1]].pos, puzzle.vertices[vertices_way[i]].pos]
					var segment_main = [puzzle.vertices[vertices_main_way[i - 1]].pos, puzzle.vertices[vertices_main_way[i]].pos]
					var main_line_length = (segment_main[1] - segment_main[0]).length()
					var line_length = (segment[1] - segment[0]).length()
					var segment_progress = 1 if len(vertices_way) > i + 1 else solution.progress
					var percentage = segment_progress * main_line_length / line_length
					var pos = segment[0] * (1.0 - percentage) + segment[1] * percentage
					if (last_pos != null):
						add_line(last_pos, pos, puzzle.line_width, color)
						add_circle(pos, puzzle.line_width / 2.0, color)
					last_pos = pos

		for vertex in puzzle.vertices:
			if (vertex.decorator != null):
				drawing_target.draw_set_transform(view_origin + vertex.pos * view_scale, vertex.decorator.angle, Vector2(1.0, 1.0))
				vertex.decorator.draw_above_solution(self, vertex, 0, puzzle, solution)
		drawing_target.draw_set_transform(view_origin, 0.0, Vector2(1.0, 1.0))
		for decorator in puzzle.decorators:
			decorator.draw_above_solution(self, null, -1, puzzle, solution)

	
