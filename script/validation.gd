extends Node

class DecoratorResponse:
	var decorator
	var rule: String
	var color = null
	var pos: Vector2
	var vertex_index: int
	var state: int
	var state_before_elimination: int
	var clone_source_decorator
	var index: int
	
	const NORMAL = 0
	const ERROR = 1
	const ELIMINATED = 2
	const CONVERTED = 3
	const NO_ELIMINATION_CHANGES = -1
	
class Region:
	
	var facet_indices: Array
	var vertice_indices: Array
	var decorator_indices: Array
	var decorator_dict: Dictionary
	var is_near_solution_line: bool
	var index
	
	func _to_string():
		return '[%d] Facets: %s, Decorators: %s\n' % [index, str(facet_indices), str(decorator_dict)]
	
	func has_any(rule):
		return rule in decorator_dict and len(decorator_dict[rule]) != 0

class Validator:
	
	var elimination_happended: bool
	var solution_validity: int # 0: unknown, 1: correct, -1: wrong
	var decorator_responses: Array
	var decorator_responses_of_vertex: Dictionary
	var regions: Array
	var region_of_facet: Array
	var vertex_region: Array # -1: unknown; -2, -3, ...: covered by solution; 0, 1, ...: in regions
	var puzzle: Graph.Puzzle
	var solution: Solution.DiscreteSolutionState
	var has_boxes: bool
	var has_lasers: bool
	
	func alter_rule(decorator_index, region, new_rule):
		var old_rule = decorator_responses[decorator_index].rule
		if (!old_rule.begins_with('!')):
			region.decorator_dict[old_rule].erase(decorator_index)
		decorator_responses[decorator_index].rule = new_rule
		if (!new_rule.begins_with('!')):
			if (!(new_rule in region.decorator_dict)):
				region.decorator_dict[new_rule] = []
			region.decorator_dict[new_rule].append(decorator_index)

	func add_decorator(decorator, pos, vertex_index):
		var response = DecoratorResponse.new()
		response.decorator = decorator
		response.rule = decorator.rule
		if (decorator.color != null):
			response.color = decorator.color
		response.pos = pos
		response.vertex_index = vertex_index
		response.state = DecoratorResponse.NORMAL
		response.state_before_elimination = DecoratorResponse.NO_ELIMINATION_CHANGES
		response.index = len(decorator_responses)
		decorator_responses.append(response)
		return response
	
	func validate(input_puzzle: Graph.Puzzle, input_solution, require_errors=true):
		puzzle = input_puzzle
		solution = input_solution.state_stack[-1]
		decorator_responses = []
		decorator_responses_of_vertex = {}
		elimination_happended = false
		for i in range(len(puzzle.vertices)):
			var vertex = puzzle.vertices[i]
			if (vertex.decorator.rule != 'none'):
				var response = add_decorator(vertex.decorator, vertex.pos, i)
				decorator_responses_of_vertex[i] = [response]
		for i in range(len(puzzle.decorators)):
			var decorator = puzzle.decorators[i]
			if (decorator.rule == 'box'):
				if (len(solution.event_properties) > i):
					var v = solution.event_properties[i]
					if (!(v in decorator_responses_of_vertex)):
						decorator_responses_of_vertex[v] = []
					var vertex = puzzle.vertices[v]
					var response = add_decorator(puzzle.decorators[i].inner_decorator, vertex.pos, v)
					decorator_responses_of_vertex[v].append(response)
				has_boxes = true
			elif (decorator.rule == 'laser-manager'):
				has_lasers = true
		var ghost_properties = null
		var ghost_manager = null
		for i in range(len(puzzle.decorators)):
			if (puzzle.decorators[i].rule == 'ghost-manager'):
				ghost_manager = puzzle.decorators[i]
				ghost_properties = solution.event_properties[i]
		vertex_region = []
		for i in range(len(puzzle.vertices)):
			vertex_region.push_back(-1)
		for way in range(puzzle.n_ways):
			if (way >= len(solution.vertices)):
				continue
			var vertices_way = solution.vertices[way]
			for i in range(len(vertices_way)):
				var v = vertices_way[i]
				if (ghost_manager != null and ghost_manager.is_solution_point_ghosted(ghost_properties, way, i)):
					continue
				if (v >= len(puzzle.vertices)):
					continue
				vertex_region[v] = -way - 2
		var visit = []
		var stack = []
		regions = []
		for i in range(len(puzzle.facets)):
			visit.append(false)
			region_of_facet.append(-1)
		for i in range(len(puzzle.facets)):
			var facet = puzzle.facets[i]
			if (!visit[i]):
				stack.push_back(i)
				visit[i] = true
				var single_region = Region.new()
				while (!stack.empty()):
					var fid = stack.pop_back()
					single_region.facet_indices.push_back(fid)
					for edge_tuple in puzzle.facets[fid].edge_tuples:
						var mid_v = puzzle.edge_detector_node[edge_tuple]
						if (vertex_region[mid_v] == -1):
							for j in puzzle.edge_shared_facets[edge_tuple]:
								if (!visit[j]):
									stack.push_back(j)
									visit[j] = true
						elif (vertex_region[mid_v] < -1):
							single_region.is_near_solution_line = true
				single_region.index = len(regions)
				for f in single_region.facet_indices:
					region_of_facet[f] = single_region
					vertex_region[puzzle.facets[f].center_vertex_index] = single_region.index
					for edge_tuple in puzzle.facets[f].edge_tuples:
						var mid_v = puzzle.edge_detector_node[edge_tuple]
						for v_id in [edge_tuple[0], edge_tuple[1], mid_v]:
							if (vertex_region[v_id] == -1):
								vertex_region[v_id] = single_region.index
				regions.append(single_region)
		for i in range(len(puzzle.vertices)):
			if (vertex_region[i] >= 0):
				if (i in decorator_responses_of_vertex):
					for response in decorator_responses_of_vertex[i]:
						regions[vertex_region[i]].decorator_indices.append(response.index)
						var rule = response.rule
						if (!(rule in regions[vertex_region[i]].decorator_dict)):
							regions[vertex_region[i]].decorator_dict[rule] = []
						regions[vertex_region[i]].decorator_dict[rule].append(response.index)
				regions[vertex_region[i]].vertice_indices.append(i)
		
		return BasicJudgers.judge_all(self, require_errors)
