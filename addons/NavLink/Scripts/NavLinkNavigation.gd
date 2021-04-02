extends Navigation

class_name NavLinkNavigation



class PathWithCost:
	var cost:float
	var path:PoolVector3Array

class NavLinkPathConnection:
	var cost:float
	var nav_link_path_node
	var path:PoolVector3Array


# Maximum distance from navmesh to the beginning of the nav link
# path start that the navigation agent can reach.
export var navigation_reachable_gap_size: float = 0.5

var all_nav_link_path_nodes: Array

# key : [NavLinkPathConnection]
var nav_link_path_graph: Dictionary



func _ready():
	parse_nav_link_nodes()



# This function handles the pre-processing of the nav links
# If you modify something during runtime you may call this function again
# to update the navigation mesh. This may be a slow operation however.
func parse_nav_link_nodes():
	
	nav_link_path_graph.clear()
	all_nav_link_path_nodes.clear()
	all_nav_link_path_nodes = _get_nav_link_paths()
	
	# Idea here is to precompute paths and weights between every link node the
	# scene has. Later when finding the path we can solve it from start to
	# finish directly to get a raw base value, then find first 10 or so
	# closest nodes to start and end positions and use A* to compute path
	# between link nodes and their precalculated weights.
	# This allows changing link weights and other values on the fly.
	# (not between links however)
	# This system is relatively heavy but should result in accurate
	# pathfinding.
	
	for nav_link_path_node in all_nav_link_path_nodes:
		var from_end_point = nav_link_path_node.end_node.global_transform.origin
		
		var reachable_nav_links = get_cost_sorted_reachable_nav_link_path_starts(
			from_end_point, [nav_link_path_node]
		)
		nav_link_path_graph[nav_link_path_node] = reachable_nav_links



enum PATH_TYPE {DIRECT_PATH, NAV_LINK_PATH}

# Returns the shortest path between from_position and to_position using
# nav link paths.
# Return format is a dictionary:
# {
# "type": <path_type>,
# "complete_cost": float: total cost,
# "complete_path": PoolVector3Array: positions of the entire final path,
# "nav_link_to_first": PoolVector3Array: positions leading to the first nav link path node,
# "nav_link_to_first_cost": float: cost of the route to the first nav_link_path object,
# "nav_link_from_last": PoolVector3Array: positions leading from last nav link path node to final position,
# "nav_link_from_last_cost": float: cost of the route from last nav_link_path object to the final position,
# "nav_link_path_nodes": Array: NavLinkPath objects in order, use "get_nav_link_path_node_inbetween()",
# "nav_link_path_node_cost": PoolRealArray: per path node cost as floats,
# "nav_link_path_inbetween": [PoolVector3Array: representing regular paths in-between nav link paths],
# "nav_link_path_inbetween_costs": PoolRealArray: Tells costs for paths inbetween nav_link_path objects.
# }
# Only "cost" and "start" are provided in cases where nav links are not used.
func get_nav_link_path(
	from_position:Vector3,
	to_position:Vector3,
	agent_tags:PoolStringArray = [],
	agent_width:float = 1.0
) -> Dictionary:
	# Get direct path
	# Returns [cost, [path]]
	var direct_path:PathWithCost = get_simple_path_with_cost(from_position, to_position)
	var direct_path_exists:bool = len(direct_path.path) > 0
	
	var total_nav_link_cost: float = 0.0
	var nav_link_path: Dictionary = {}
	
	# Find path through nav link path nodes.
	# Returns a dictionary {
	# "path_to_first_nav_link_cost": float,
	# "path_to_first_nav_link": PoolVector3Array,
	# "path_from_last_nav_link_cost": float,
	# "path_from_last_nav_link": PoolVector3Array,
	# "nav_links": [nav_link_path_object]
	nav_link_path = _nav_link_path_find_dijkstra(
		from_position,
		to_position,
		agent_tags,
		agent_width
	)
	
	var nav_link_path_exists = not nav_link_path.empty()
	
	var nav_link_to_first:PoolVector3Array = []
	var nav_link_from_last:PoolVector3Array = []
	var nav_link_to_first_cost: float = 0.0
	var nav_link_from_last_cost: float = 0.0
	var nav_link_complete_path: PoolVector3Array = []
	var nav_link_path_node_costs: PoolRealArray = []
	var nav_link_path_inbetween: Array = []
	var nav_link_path_inbetween_costs: PoolRealArray = []
	
	if nav_link_path_exists:
		nav_link_to_first = nav_link_path.path_to_first_nav_link
		nav_link_from_last = nav_link_path.path_from_last_nav_link
		
		nav_link_to_first_cost = nav_link_path.path_to_first_nav_link_cost
		nav_link_from_last_cost = nav_link_path.path_from_last_nav_link_cost
		
		total_nav_link_cost = nav_link_to_first_cost
		total_nav_link_cost += nav_link_from_last_cost
		
		nav_link_complete_path.append_array(nav_link_to_first)
		
		if len(nav_link_path.nav_links) > 1:
			for i in range(0, len(nav_link_path.nav_links) - 1):
				var nav_link_prop:PathWithCost = get_nav_link_path_node_inbetween(
					nav_link_path.nav_links[i],
					nav_link_path.nav_links[i + 1]
				)
				total_nav_link_cost += nav_link_prop.cost
				
				nav_link_path_inbetween_costs.append(nav_link_prop.cost)
				nav_link_path_inbetween.append([nav_link_prop.path])
				
				nav_link_complete_path.append_array(nav_link_prop.path)
		
		for n in nav_link_path.nav_links:
			var travel_cost = n.get_link_travel_cost()
			nav_link_path_node_costs.append(travel_cost)
			total_nav_link_cost += travel_cost
		
		nav_link_complete_path.append_array(nav_link_from_last)
		
	if not direct_path_exists and not nav_link_path_exists:
		# No path found
		return {}
	
	var path_type
	var complete_path_cost:float
	var nav_link_path_nodes = []
	var complete_path:PoolVector3Array
	
	if direct_path_exists and not nav_link_path_exists:
		path_type = PATH_TYPE.DIRECT_PATH
	elif not direct_path_exists and nav_link_path_exists:
		path_type = PATH_TYPE.NAV_LINK_PATH
	elif direct_path.cost < total_nav_link_cost:
		path_type = PATH_TYPE.DIRECT_PATH
	else:
		path_type = PATH_TYPE.NAV_LINK_PATH
	
	if path_type == PATH_TYPE.DIRECT_PATH:
		complete_path_cost = direct_path.cost
		complete_path = direct_path.path
	
	elif path_type == PATH_TYPE.NAV_LINK_PATH:
		complete_path_cost = total_nav_link_cost
		complete_path = nav_link_complete_path
	
	return {
		"type": path_type,
		"complete_path_cost": complete_path_cost,
		"complete_path": complete_path,
		"nav_link_to_first": nav_link_to_first,
		"nav_link_to_first_cost": nav_link_to_first_cost,
		"nav_link_from_last": nav_link_from_last,
		"nav_link_from_last_cost": nav_link_from_last_cost,
		"nav_link_path_nodes": nav_link_path_nodes,
		"nav_link_path_node_costs": nav_link_path_node_costs,
		"nav_link_path_inbetween": nav_link_path_inbetween,
		"nav_link_path_inbetween_costs": nav_link_path_inbetween_costs
	}



# Returns PathWithCost if predefined path between path link nodes exists.
# Returns null if path does not exist.
# TODO: Rename this...
func get_nav_link_path_node_inbetween(from_nav_link_path_node, to_nav_link_path_node) -> PathWithCost:
	var from_paths = nav_link_path_graph[from_nav_link_path_node]
	for f in from_paths:
		if f.nav_link_path_node == to_nav_link_path_node:
			var ret:PathWithCost = PathWithCost.new()
			ret.cost = f.cost
			ret.path = f.path
			return ret
	return null



# To find the lowest cost for nav link path when running
# _nav_link_path_find_dijkstra. Internal function.
func _get_lowest_cost_key(dict:Dictionary):
	# reachable starts and ends format is [cost, reach_from]
	var lowest_cost: float = INF
	var found_key = null
	for s in dict.keys():
		if not s == null:
			var cost = dict[s][0]
			if cost < lowest_cost:
				lowest_cost = cost
				found_key = s
	return found_key

#func _add_reachable_ends_seen(reachable_ends_seen:Array, reachable_ends:Array, end_node):
#	# reachable_ends = array of [NavLinkPathConnection]
#	if end_node in reachable_ends_seen:
#		return
#	for r in reachable_ends:
#		if r.nav_link_path_node == end_node:
#			reachable_ends_seen.append(end_node)

func _find_in_reachable_nav_link_paths(reachable_nav_link_paths:Array, nav_link_path) -> Array:
	for r in reachable_nav_link_paths:
		if r.nav_link_path_node == nav_link_path:
			return [r.cost, r.path]
	return []

func _check_allow_passage(nav_link_path_node, agent_tags:PoolStringArray, agent_width:float) -> bool:
	if nav_link_path_node is String:
		return true
	
	if agent_width > nav_link_path_node.get_link_width():
		return false
	
	if nav_link_path_node.link_tags.empty():
		return true
	
	var require_tags_type = nav_link_path_node.require_tags_type
	if require_tags_type == nav_link_path_node.REQUIRE_TAGS_TYPE.ONE:
		# check for one tag exists
		for at in agent_tags:
			if at in nav_link_path_node.tags:
				return true
	
	elif require_tags_type == nav_link_path_node.REQUIRE_TAGS_TYPE.ALL:
		# check that all tags exist
		for at in agent_tags:
			if not at in nav_link_path_node.tags:
				return false
		return true
	
	return false

# Returns a path formed by the nav links
# Returns an array where each element is: [cost, path_node]
# Returns a dictionary {
# "path_to_first_nav_link_cost": float,
# "path_to_first_nav_link": PoolVector3Array,
# "path_from_last_nav_link_cost": float,
# "path_from_last_nav_link": PoolVector3Array,
# "nav_links": [nav_link_path_object]
# }
# TODO: Optimization opportunity: Remember last link so reachable nav link path
# starts could be narrowed down
# TODO: Optimization opportunity: Find first reachable nav link end so reachable
# nav link path ends could be narrowed down
func _nav_link_path_find_dijkstra(
	start_pos:Vector3,
	end_pos:Vector3,
	agent_tags:PoolStringArray,
	agent_width:float
) -> Dictionary:
	# reachable starts and ends format is [NavLinkPathConnection]
	var reachable_starts:Array = get_cost_sorted_reachable_nav_link_path_starts(start_pos, [], true)
	var reachable_ends:Array = get_cost_sorted_reachable_nav_link_path_ends(end_pos, [], true)
	if reachable_starts.empty() or reachable_ends.empty():
		# No path via nav_links, use regular pathfinding.
		return {}
	
	# key : [NavLinkPathConnection]
	var nav_link_path_graph_copy = nav_link_path_graph.duplicate(true)
	nav_link_path_graph_copy["start"] = reachable_starts
	nav_link_path_graph_copy["end"] = []
	
	# Need to add a connection from the reachable ends going to the actual end coordinates
	for r in reachable_ends:
		var node = r.nav_link_path_node
		var end_connection:NavLinkPathConnection = NavLinkPathConnection.new()
		end_connection.cost = r.cost
		end_connection.nav_link_path_node = "end"
		end_connection.path = r.path
		nav_link_path_graph_copy[node].append(end_connection)
		#nav_link_path_graph_copy[node].append(
		#	[r.cost, "end", r.path]
		#)
	
	# {from_nav_link_path_node, [cost, reach_from]}
	var done = {}
	var seen = {"start": [0, null]}
	
	while true:
		# Find lowest cost seen key
		var current = _get_lowest_cost_key(seen)
		
		if current == null:
			# Something went wrong
			return {}
		
		if current is String and current == "end":
			# Found shortest path, compile final path and return it
			# nav_links: [nav_link_path]
			var nav_links = []
			var previous_node = seen[current][1]
			
			if previous_node == null:
				# Path not found.
				return {}
			
			while not previous_node is String or previous_node != "start":
				nav_links.push_front(previous_node)
				previous_node = done[previous_node][1]
			
			var first_node = nav_links.front()
			var last_node = nav_links.back()
			
			# reachable starts and ends format is [cost, [path]]
			var to_first_nav_link = _find_in_reachable_nav_link_paths(reachable_starts, first_node)
			var from_last_nav_link = _find_in_reachable_nav_link_paths(reachable_ends, last_node)
			if to_first_nav_link.empty() or from_last_nav_link.empty():
				return {}
			var path_to_first_nav_link_cost = to_first_nav_link[0]
			var path_to_first_nav_link = to_first_nav_link[1]
			var path_from_last_nav_link_cost = from_last_nav_link[0]
			var path_from_last_nav_link = from_last_nav_link[1]
			
			return {
				"path_to_first_nav_link_cost": path_to_first_nav_link_cost,
				"path_to_first_nav_link": path_to_first_nav_link,
				"path_from_last_nav_link_cost": path_from_last_nav_link_cost,
				"path_from_last_nav_link": path_from_last_nav_link,
				"nav_links": nav_links
			}
		
		# Check weight, value is: [NavLinkPathConnection]
		var neighbouring_path_nodes:Array = nav_link_path_graph_copy[current]
		var current_cost = seen[current][0]
		
		for neighbour in neighbouring_path_nodes:
			var neighbour_node = neighbour.nav_link_path_node
			var neighbour_cost = neighbour.cost
			if not neighbour_node is String or neighbour_node != "end":
				neighbour_cost += neighbour_node.get_link_travel_cost()
			if not neighbour_node in done:
				if neighbour_node in seen:
					if neighbour_cost + current_cost < seen[neighbour_node][0]:
						seen[neighbour_node] = [neighbour_cost + current_cost, current]
				else:
					if _check_allow_passage(neighbour_node, agent_tags, agent_width):
						seen[neighbour_node] = [neighbour_cost + current_cost, current]
		
		# _add_reachable_ends_seen(reachable_ends_seen, reachable_ends, current)
		done[current] = seen[current]
		seen.erase(current)
	
	return {}



# Returns all reachable nav link path start points from a location in world space.
# Returns array where each element is: [NavLinkPathConnection]
func get_reachable_nav_link_path_starts(
		from_position: Vector3, exlude:Array = [], include_link_cost:bool = false
	) -> Array:
	var ret: Array
	for nav_link_path_node in all_nav_link_path_nodes:
		if not nav_link_path_node in exlude:
			var node_origin = nav_link_path_node.start_node.global_transform.origin
			var path_to_node:PathWithCost = get_simple_path_with_cost(from_position, node_origin)
			
			# Check if simple path to start of the node is reachable or not.
			# Only add the node to nodes array if it is reachable
			if len(path_to_node.path):
				var cost: float = path_to_node.cost
				if include_link_cost:
					cost += nav_link_path_node.get_link_travel_cost()
				var connection:NavLinkPathConnection = NavLinkPathConnection.new()
				connection.cost = cost
				connection.nav_link_path_node = nav_link_path_node
				connection.path = path_to_node.path
				ret.append(connection)
	return ret



# Returns all reachable nav link path end points from a location in world space.
# Returns array where each element is: [NavLinkPathConnection]
func get_reachable_nav_link_path_ends(
		to_position: Vector3, exlude:Array = [], include_link_cost:bool = false
	) -> Array:
	var ret: Array
	for nav_link_path_node in all_nav_link_path_nodes:
		if not nav_link_path_node in exlude:
			var node_origin:Vector3 = nav_link_path_node.end_node.global_transform.origin
			var path_to_node:PathWithCost = get_simple_path_with_cost(node_origin, to_position)
			
			# Check if simple path to start of the node is reachable or not.
			# Only add the node to nodes array if it is reachable
			if len(path_to_node.path):
				var cost: float = path_to_node.cost
				if include_link_cost:
					cost += nav_link_path_node.get_link_travel_cost()
				var connection:NavLinkPathConnection = NavLinkPathConnection.new()
				connection.cost = cost
				connection.nav_link_path_node = nav_link_path_node
				connection.path = path_to_node.path
				ret.append(connection)
	return ret



class _CostSorterFor_get_cost_sorted_reachable_nav_link_paths:
	static func sort_ascending(a:NavLinkPathConnection, b:NavLinkPathConnection):
		return a.cost < b.cost

# Returns all reachable nav link paths in order of cost starting
# from a location in world space.
# Returns array where each element is: [NavLinkPathConnection]
func get_cost_sorted_reachable_nav_link_path_starts(
		from_position: Vector3, exlude:Array = [], include_link_cost:bool = false
	) -> Array:
	
	var nodes: Array = get_reachable_nav_link_path_starts(from_position, exlude, include_link_cost)
	nodes.sort_custom(
		_CostSorterFor_get_cost_sorted_reachable_nav_link_paths,
		"sort_ascending"
	)
	return nodes

# Returns all reachable nav link paths in order of cost starting
# from a location in world space.
# Returns array where each element is: [NavLinkPathConnection]
func get_cost_sorted_reachable_nav_link_path_ends(
		to_position: Vector3, exlude:Array = [], include_link_cost:bool = false
	) -> Array:
	
	var nodes: Array = get_reachable_nav_link_path_ends(to_position, exlude, include_link_cost)
	nodes.sort_custom(
		_CostSorterFor_get_cost_sorted_reachable_nav_link_paths,
		"sort_ascending"
	)
	return nodes



# Similar to get_simple_path() but also returns the total lenght of the path.
# Returns PathWithCost
func get_simple_path_with_cost(from_position: Vector3, to_position: Vector3, optimize: bool = true) -> PathWithCost:
	var ret:PathWithCost = PathWithCost.new()
	ret.path = get_simple_path(from_position, to_position, optimize)
	ret.cost = 0.0
	for i in range(0, len(ret.path) - 1):
		ret.cost += ret.path[i].distance_to(ret.path[i + 1])
	return ret



func _get_nav_link_paths() -> Array:
	var nav_link_group = get_tree().get_nodes_in_group("NavLinkPaths")
	var nav_link_paths: Array
	for p in nav_link_group:
		if p is NavLinkPath:
			nav_link_paths.append(p)
	return nav_link_paths
