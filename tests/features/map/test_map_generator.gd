extends GutTest

# Tests ported from ~/Repos/spokes/src/core/course/__tests__/CourseGenerator.test.ts
# and ~/Repos/spokes/src/core/course/__tests__/HubGeneration.test.ts

# ─── compute_num_spokes ─────────────────────────────────────────────────────────

func test_compute_num_spokes() -> void:
	assert_eq(MapGenerator.compute_num_spokes(1), 2, "minimum 2 for 1km")
	assert_eq(MapGenerator.compute_num_spokes(10), 2, "minimum 2 for 10km")
	assert_eq(MapGenerator.compute_num_spokes(24), 2, "minimum 2 for 24km")
	
	var km_per_spoke: float = 20.0 # From MapGenerator.gd
	assert_eq(MapGenerator.compute_num_spokes(km_per_spoke * 1.5), 2)
	assert_eq(MapGenerator.compute_num_spokes(km_per_spoke * 2.5), 3)
	assert_eq(MapGenerator.compute_num_spokes(km_per_spoke * 3.5), 4)
	assert_eq(MapGenerator.compute_num_spokes(km_per_spoke * 5.0), 5)
	
	assert_eq(MapGenerator.compute_num_spokes(400), 8, "maximum 8 for 400km")
	assert_eq(MapGenerator.compute_num_spokes(1000), 8, "maximum 8 for 1000km")

# ─── generate_hub_and_spoke_map ───────────────────────────────────────────────────

func test_generate_hub_and_spoke_map_integrity() -> void:
	var run_data: Dictionary = {
		"totalDistanceKm": 100.0,
		"difficulty": "normal",
		"nodes": [],
		"edges": [],
		"stats": {"totalMapDistanceM": 0}
	}
	MapGenerator.generate_hub_and_spoke_map(run_data)
	
	var nodes: Array[Dictionary] = run_data.nodes
	var edges: Array[Dictionary] = run_data.edges
	
	# 1. Graph Integrity
	var start_nodes: Array[Dictionary] = []
	var finish_nodes: Array[Dictionary] = []
	for n: Dictionary in nodes:
		if n.type == "start": start_nodes.append(n)
		if n.type == "finish": finish_nodes.append(n)
		
	assert_eq(start_nodes.size(), 1, "should have exactly one start node")
	assert_gt(finish_nodes.size(), 0, "should have at least one finish node")
	
	# 2. Orphan check: ensure every node is connected to at least one edge
	var referenced_nodes: Dictionary = {}
	for e: Dictionary in edges:
		referenced_nodes[e.from] = true
		referenced_nodes[e.to] = true
		
	for n: Dictionary in nodes:
		assert_true(referenced_nodes.has(n.id), "node " + n.id + " should be referenced in edges")
		
	# 3. Edge Validity
	var node_ids: Dictionary = {}
	for n: Dictionary in nodes:
		node_ids[n.id] = true
		
	for e: Dictionary in edges:
		assert_true(node_ids.has(e.from), "edge from " + e.from + " should exist")
		assert_true(node_ids.has(e.to), "edge to " + e.to + " should exist")

func test_generate_hub_and_spoke_map_structure() -> void:
	var run_data: Dictionary = {
		"totalDistanceKm": 20.0,
		"difficulty": "normal",
		"nodes": [],
		"edges": [],
		"stats": {"totalMapDistanceM": 0}
	}
	MapGenerator.generate_hub_and_spoke_map(run_data)
	
	var num_spokes: int = MapGenerator.compute_num_spokes(20.0) # 1
	# Wait, compute_num_spokes(20) returns 1 but MIN_SPOKES is 2.
	# Let's re-verify MapGenerator.gd compute_num_spokes
	# static func compute_num_spokes(total_distance_km: float) -> int:
	#    return int(clamp(round(total_distance_km / KM_PER_SPOKE), MIN_SPOKES, MAX_SPOKES))
	# round(20/20) = 1. clamp(1, 2, 8) = 2.
	assert_eq(num_spokes, 2)
	
	var hub = null
	for n: Dictionary in run_data.nodes:
		if n.id == "node_hub":
			hub = n
			break
	assert_not_null(hub)
	
	# Hub connects to num_spokes spoke-starts + final boss
	assert_eq(hub.connectedTo.size(), num_spokes + 1)
	
	var boss_nodes: Array[Dictionary] = []
	for n: Dictionary in run_data.nodes:
		if n.type == "boss": boss_nodes.append(n)
	assert_eq(boss_nodes.size(), num_spokes)

func test_generate_hub_and_spoke_map_counts() -> void:
	var run_data: Dictionary = {
		"totalDistanceKm": 200.0,
		"difficulty": "normal",
		"nodes": [],
		"edges": [],
		"stats": {"totalMapDistanceM": 0}
	}
	MapGenerator.generate_hub_and_spoke_map(run_data)
	
	var num_spokes: int = MapGenerator.compute_num_spokes(200.0) # 10, clamped to 8
	assert_eq(num_spokes, 8)
	
	# Total nodes per biome = NODES_PER_SPOKE linear + 6 island
	# MapGenerator.gd: const NODES_PER_SPOKE = 2
	var nodes_per_biome: int = 2 + 6
	# Total nodes = 1 hub + numSpokes*nodesPerBiome + 1 final boss
	assert_eq(run_data.nodes.size(), 1 + num_spokes * nodes_per_biome + 1)
	
	var shop_nodes: Array[Dictionary] = []
	var boss_nodes: Array[Dictionary] = []
	for n: Dictionary in run_data.nodes:
		if n.type == "shop": shop_nodes.append(n)
		if n.type == "boss": boss_nodes.append(n)
		
	assert_eq(shop_nodes.size(), num_spokes)
	assert_eq(boss_nodes.size(), num_spokes)

func test_boss_metadata() -> void:
	var run_data: Dictionary = {
		"totalDistanceKm": 60.0,
		"difficulty": "normal",
		"nodes": [],
		"edges": [],
		"stats": {"totalMapDistanceM": 0}
	}
	MapGenerator.generate_hub_and_spoke_map(run_data)
	
	for n: Dictionary in run_data.nodes:
		if n.type == "boss":
			assert_true(n.has("metadata"), "boss should have metadata")
			assert_true(n.metadata.has("spokeId"), "boss should have spokeId")

func test_connectivity() -> void:
	var run_data: Dictionary = {
		"totalDistanceKm": 60.0,
		"difficulty": "normal",
		"nodes": [],
		"edges": [],
		"stats": {"totalMapDistanceM": 0}
	}
	MapGenerator.generate_hub_and_spoke_map(run_data)
	
	var start_node = null
	var finish_node = null
	for n: Dictionary in run_data.nodes:
		if n.type == "start": start_node = n
		if n.type == "finish": finish_node = n
		
	assert_not_null(start_node)
	assert_not_null(finish_node)
	
	# BFS to ensure finish is reachable from start
	var adjacency: Dictionary = {}
	for e: Dictionary in run_data.edges:
		if not adjacency.has(e.from): adjacency[e.from] = []
		adjacency[e.from].append(e.to)
		
	var queue: Array[String] = [start_node.id]
	var visited: Dictionary = {start_node.id: true}
	var reachable: bool = false
	
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == finish_node.id:
			reachable = true
			break
			
		var neighbors: Array = adjacency.get(current, [])
		for nxt: String in neighbors:
			if not visited.has(nxt):
				visited[nxt] = true
				queue.push_back(nxt)
				
	assert_true(reachable, "finish node should be reachable from start node")
