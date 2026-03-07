class_name MapGenerator
extends Object

# Port of CourseGenerator.ts
# Procedurally generates the Hub-and-Spoke map structure.

const NODES_PER_SPOKE: int = 2
const SPOKE_STEP: float = 0.12
const MIN_SPOKES: int = 2
const MAX_SPOKES: int = 8
const KM_PER_SPOKE: int = 20

const SPOKE_IDS: Array[String] = [
    "plains", "coast", "mountain", "forest",
    "desert", "tundra", "canyon", "jungle",
]

const BIOME_COLORS: Dictionary = {
    "plains":   Color("#7bb661"),
    "coast":    Color("#4a90e2"),
    "mountain": Color("#9b9b9b"),
    "forest":   Color("#2d5a27"),
    "desert":   Color("#e2b14a"),
    "tundra":   Color("#d1e8e2"),
    "canyon":   Color("#a0522d"),
    "jungle":   Color("#228b22"),
}

const SPOKE_CONFIG: Dictionary = {
    "plains":   {"hazardSurface": "asphalt", "hazardGrade": 0.00},
    "coast":    {"hazardSurface": "mud",     "hazardGrade": 0.02},
    "mountain": {"hazardSurface": "gravel",  "hazardGrade": 0.15},
    "forest":   {"hazardSurface": "dirt",    "hazardGrade": 0.08},
    "desert":   {"hazardSurface": "gravel",  "hazardGrade": 0.06},
    "tundra":   {"hazardSurface": "mud",     "hazardGrade": 0.04},
    "canyon":   {"hazardSurface": "dirt",    "hazardGrade": 0.10},
    "jungle":   {"hazardSurface": "mud",     "hazardGrade": 0.05},
}

static func compute_num_spokes(total_distance_km: float) -> int:
    return int(clamp(round(total_distance_km / KM_PER_SPOKE), MIN_SPOKES, MAX_SPOKES))

static func random_island_node_type() -> String:
    var r: float = randf()
    if r < 0.3: return "standard"
    if r < 0.7: return "event"
    return "hard"

static func generate_hub_and_spoke_map(run_data: Dictionary) -> void:
    var nodes: Array[Dictionary] = []
    var edges: Array[Dictionary] = []
    
    var total_dist_km: float = run_data.get("totalDistanceKm", 50.0)
    var num_spokes: int = compute_num_spokes(total_dist_km)
    
    # Ridden Distance Weighting:
    # Each spoke requires a round trip: (NODES_PER_SPOKE + 3 island steps + boss_edge) * 2
    # Out: 2 (linear) + 1 (entry) + 1 (choice) + 1 (pre-boss) + 1.5 (boss) = 6.5
    # Back: 6.5
    # Total: 13.0 unit segments per spoke.
    # The final boss edge is weighted at 2.0 unit segments.
    var unit_segments_per_spoke: float = 13.0
    var total_unit_segments: float = (num_spokes * unit_segments_per_spoke) + 2.0
    var base_km: float = max(0.1, total_dist_km / total_unit_segments)
    
    var difficulty: String = run_data.get("difficulty", "normal")
    var absolute_max_grade: float = {
        "easy": 0.05,
        "normal": 0.07,
        "hard": 0.10
    }.get(difficulty, 0.07)
    
    # Target max_grade values to hit elevation per 10 miles:
    # Easy: <500ft -> ~0.015 avg max_grade
    # Normal: 750-1000ft -> ~0.04 avg max_grade
    # Hard: 1200-1500ft -> ~0.07 avg max_grade
    var diff_config: Dictionary = {
        "easy":   {"base_grade": 0.015, "hazard_mult": 0.1,  "rand_var": 0.005},
        "normal": {"base_grade": 0.048, "hazard_mult": 0.25, "rand_var": 0.008},
        "hard":   {"base_grade": 0.08,  "hazard_mult": 0.4,  "rand_var": 0.01}
    }.get(difficulty, {"base_grade": 0.048, "hazard_mult": 0.25, "rand_var": 0.008})
    
    run_data["runLength"] = num_spokes
    
    # Helper for adding edges
    var add_edge: Callable = func(from_id: String, to_id: String, km: float, base_max_grade: float, surface: String = "asphalt") -> void:
        var target_node: Dictionary = {}
        for n: Dictionary in nodes:
            if n["id"] == to_id:
                target_node = n
                break
        
        # Hazard grade (config["hazardGrade"]) is maxed at 0.15 (mountains)
        var grade: float = diff_config["base_grade"] + (base_max_grade * diff_config["hazard_mult"])
        grade += (randf() * 2.0 - 1.0) * diff_config["rand_var"]
        grade = max(0.005, grade)
        
        if not target_node.is_empty():
            if target_node["type"] == "hard": grade *= 1.5
            elif target_node["type"] == "boss": grade *= 2.0
            elif target_node["type"] == "finish": grade *= 2.5
            
        grade = min(grade, absolute_max_grade)
            
        edges.append({
            "from": from_id,
            "to": to_id,
            "profile": CourseProfile.generate_course_profile(km, grade, surface),
            "isCleared": false
        })

    # 1. Hub
    var hub_node: Dictionary = {
        "id": "node_hub",
        "type": "start",
        "floor": 0,
        "col": 0,
        "x": 0.5,
        "y": 0.5,
        "connectedTo": []
    }
    nodes.append(hub_node)
    
    # 2. Spokes
    var active_spokes: Array = SPOKE_IDS.slice(0, num_spokes)
    for spoke_index: int in range(active_spokes.size()):
        var spoke_id: String = active_spokes[spoke_index]
        var config: Dictionary = SPOKE_CONFIG[spoke_id]
        var angle: float = (TAU * spoke_index) / float(num_spokes) - (TAU / 16.0)
        
        var get_pos: Callable = func(radial: float, perp: float = 0.0) -> Dictionary:
            return {
                "x": 0.5 + cos(angle) * radial + (-sin(angle)) * perp,
                "y": 0.5 + sin(angle) * radial + (cos(angle)) * perp
            }
            
        # 2a. Linear spoke nodes
        var spoke_node_ids: Array[String] = []
        for i: int in range(1, NODES_PER_SPOKE + 1):
            var node_id: String = "node_%s_s%d" % [spoke_id, i]
            var pos: Dictionary = get_pos.call(SPOKE_STEP * i)
            
            var type: String = "standard"
            if randf() < 0.2: type = "event"
            elif randf() < 0.1: type = "hard"
            
            var node: Dictionary = {
                "id": node_id,
                "type": type,
                "floor": i,
                "col": 0,
                "x": pos["x"],
                "y": pos["y"],
                "connectedTo": [],
                "metadata": {"spokeId": spoke_id}
            }
            nodes.append(node)
            spoke_node_ids.append(node_id)
            
            if i == 1:
                add_edge.call(hub_node["id"], node_id, base_km, config["hazardGrade"], config["hazardSurface"])
                # Spoke Gate: require medal from previous spoke
                if spoke_index > 0:
                    var prev_spoke_id: String = active_spokes[spoke_index - 1]
                    for e: Dictionary in edges:
                        if e["from"] == hub_node["id"] and e["to"] == node_id:
                            e["requiredMedal"] = "medal_" + prev_spoke_id
                            break
                (hub_node["connectedTo"] as Array).append(node_id)
            else:
                var prev_id: String = spoke_node_ids[i-2]
                add_edge.call(prev_id, node_id, base_km, 0.04)
                # find prev node
                for n: Dictionary in nodes:
                    if n["id"] == prev_id:
                        (n["connectedTo"] as Array).append(node_id)
                        break

        # 2b. Island mini-DAG
        var last_spoke_id: String = spoke_node_ids[NODES_PER_SPOKE - 1]
        
        var ISLAND_ENTRY: float = SPOKE_STEP * NODES_PER_SPOKE + SPOKE_STEP * 0.8
        var ISLAND_MID: float   = SPOKE_STEP * NODES_PER_SPOKE + SPOKE_STEP * 1.6
        var ISLAND_PRE: float   = SPOKE_STEP * NODES_PER_SPOKE + SPOKE_STEP * 2.4
        var ISLAND_BOSS: float  = SPOKE_STEP * NODES_PER_SPOKE + SPOKE_STEP * 3.2
        
        var r_types: Array[String] = [random_island_node_type(), random_island_node_type(), random_island_node_type(), random_island_node_type()]
        
        var ie_id: String = "node_%s_ie" % spoke_id
        var il_id: String = "node_%s_il" % spoke_id
        var ic_id: String = "node_%s_ic" % spoke_id
        var ir_id: String = "node_%s_ir" % spoke_id
        var ip_id: String = "node_%s_ip" % spoke_id
        var boss_id: String = "node_%s_boss" % spoke_id
        
        var mk_node: Callable = func(id: String, type: String, p_floor: int, radial: float, perp: float = 0.0) -> Dictionary:
            var pos: Dictionary = get_pos.call(radial, perp)
            return {
                "id": id,
                "type": type,
                "floor": p_floor,
                "col": 0,
                "x": pos["x"],
                "y": pos["y"],
                "connectedTo": [],
                "metadata": {"spokeId": spoke_id}
            }
            
        var ie_node: Dictionary = mk_node.call(ie_id, r_types[0], NODES_PER_SPOKE + 1, ISLAND_ENTRY, 0.0)
        var il_node: Dictionary = mk_node.call(il_id, r_types[1], NODES_PER_SPOKE + 2, ISLAND_MID, -0.05)
        var ic_node: Dictionary = mk_node.call(ic_id, "shop", NODES_PER_SPOKE + 2, ISLAND_MID, 0.0)
        var ir_node: Dictionary = mk_node.call(ir_id, r_types[2], NODES_PER_SPOKE + 2, ISLAND_MID, 0.05)
        var ip_node: Dictionary = mk_node.call(ip_id, r_types[3], NODES_PER_SPOKE + 3, ISLAND_PRE, 0.0)
        var boss_node: Dictionary = mk_node.call(boss_id, "boss", NODES_PER_SPOKE + 4, ISLAND_BOSS, 0.0)
        
        nodes.append_array([ie_node, il_node, ic_node, ir_node, ip_node, boss_node])
        
        # Last spoke -> entry
        add_edge.call(last_spoke_id, ie_id, base_km, 0.04)
        for n: Dictionary in nodes:
            if n["id"] == last_spoke_id:
                (n["connectedTo"] as Array).append(ie_id)
                break
                
        # entry -> left/center/right
        add_edge.call(ie_id, il_id, base_km, 0.05)
        add_edge.call(ie_id, ic_id, base_km, 0.03)
        add_edge.call(ie_id, ir_id, base_km, 0.05)
        (ie_node["connectedTo"] as Array).append_array([il_id, ic_id, ir_id])
        
        # left/center/right -> pre-boss
        add_edge.call(il_id, ip_id, base_km, 0.05, "gravel")
        add_edge.call(ic_id, ip_id, base_km, 0.03)
        add_edge.call(ir_id, ip_id, base_km, 0.05, "gravel")
        (il_node["connectedTo"] as Array).append(ip_id)
        (ic_node["connectedTo"] as Array).append(ip_id)
        (ir_node["connectedTo"] as Array).append(ip_id)
        
        # pre-boss -> boss
        add_edge.call(ip_id, boss_id, base_km * 1.5, 0.08)
        (ip_node["connectedTo"] as Array).append(boss_id)

    # 3. Final Boss
    var final_angle: float = (TAU * (float(num_spokes) - 0.5)) / float(num_spokes) - (TAU / 16.0)
    var final_dist: float = 0.45
    var final_boss_node: Dictionary = {
        "id": "node_final_boss",
        "type": "finish",
        "floor": 99,
        "col": 0,
        "x": 0.5 + cos(final_angle) * final_dist,
        "y": 0.5 + sin(final_angle) * final_dist,
        "connectedTo": []
    }
    nodes.append(final_boss_node)
    
    # This edge is "Locked" - needs all medals
    add_edge.call(hub_node["id"], final_boss_node["id"], base_km * 2.0, 0.10)
    for e: Dictionary in edges:
        if e["from"] == hub_node["id"] and e["to"] == final_boss_node["id"]:
            e["requiresAllMedals"] = true
            break
            
    (hub_node["connectedTo"] as Array).append(final_boss_node["id"])
    
    run_data["nodes"] = nodes
    run_data["edges"] = edges
    run_data["currentNodeId"] = hub_node["id"]
    run_data["visitedNodeIds"] = [hub_node["id"]]
    hub_node["isUsed"] = true
    
    var total_map_dist: float = 0.0
    for e: Dictionary in edges:
        total_map_dist += (e["profile"] as CourseProfile).total_distance_m
    
    var raw_total_ascent_m: float = 0.0
    for e: Dictionary in edges:
        for s: Dictionary in (e["profile"] as CourseProfile).segments:
            if s["grade"] > 0:
                raw_total_ascent_m += s["distanceM"] * s["grade"]

    var target_ft_per_10mi: float = 0.0
    if difficulty == "easy":
        target_ft_per_10mi = randf_range(300.0, 500.0)
    elif difficulty == "normal":
        target_ft_per_10mi = randf_range(750.0, 1000.0)
    elif difficulty == "hard":
        target_ft_per_10mi = randf_range(1200.0, 1500.0)
    else:
        target_ft_per_10mi = randf_range(750.0, 1000.0)

    var target_ascent_m_per_m: float = target_ft_per_10mi / (16093.44 * 3.28084)
    var target_total_ascent_m: float = target_ascent_m_per_m * total_map_dist

    if raw_total_ascent_m > 0:
        var multiplier: float = target_total_ascent_m / raw_total_ascent_m
        for e: Dictionary in edges:
            for s: Dictionary in (e["profile"] as CourseProfile).segments:
                s["grade"] *= multiplier
                s["grade"] = clamp(s["grade"], -absolute_max_grade, absolute_max_grade)

    run_data["stats"]["totalMapDistanceM"] = total_map_dist
    
    print("[MAP GEN] spokes: %d, nodes: %d, edges: %d, total length: %.1fkm" % [
        num_spokes, nodes.size(), edges.size(), total_map_dist / 1000.0
    ])
