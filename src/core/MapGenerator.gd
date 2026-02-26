class_name MapGenerator
extends Object

# Port of CourseGenerator.ts
# Procedurally generates the Hub-and-Spoke map structure.

const NODES_PER_SPOKE = 2
const SPOKE_STEP = 0.07
const MIN_SPOKES = 2
const MAX_SPOKES = 8
const KM_PER_SPOKE = 20

const SPOKE_IDS = [
    "plains", "coast", "mountain", "forest",
    "desert", "tundra", "canyon", "jungle",
]

const BIOME_COLORS = {
    "plains":   Color("#7bb661"),
    "coast":    Color("#4a90e2"),
    "mountain": Color("#9b9b9b"),
    "forest":   Color("#2d5a27"),
    "desert":   Color("#e2b14a"),
    "tundra":   Color("#d1e8e2"),
    "canyon":   Color("#a0522d"),
    "jungle":   Color("#228b22"),
}

const SPOKE_CONFIG = {
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
    var r = randf()
    if r < 0.3: return "standard"
    if r < 0.7: return "event"
    return "hard"

static func generate_hub_and_spoke_map(run_data: Dictionary) -> void:
    var nodes = []
    var edges = []
    
    var total_dist_km = run_data.get("totalDistanceKm", 50.0)
    var num_spokes = compute_num_spokes(total_dist_km)
    
    var weight_per_spoke = NODES_PER_SPOKE + 4.5
    var total_run_weight = num_spokes * weight_per_spoke + 2
    var base_km = max(0.1, total_dist_km / total_run_weight)
    
    var difficulty = run_data.get("difficulty", "normal")
    var diff_scale = 1.5 if difficulty == "hard" else (0.7 if difficulty == "easy" else 1.0)
    
    run_data["runLength"] = num_spokes
    
    # Helper for adding edges
    var add_edge = func(from_id: String, to_id: String, km: float, base_max_grade: float, surface: String = "asphalt"):
        var target_node = null
        for n in nodes:
            if n["id"] == to_id:
                target_node = n
                break
        
        var grade = base_max_grade * diff_scale
        if target_node:
            if target_node["type"] == "hard": grade *= 1.5
            elif target_node["type"] == "boss": grade *= 2.0
            elif target_node["type"] == "finish": grade *= 2.5
            
        edges.append({
            "from": from_id,
            "to": to_id,
            "profile": CourseProfile.generate_course_profile(km, grade, surface),
            "isCleared": false
        })

    # 1. Hub
    var hub_node = {
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
    var active_spokes = SPOKE_IDS.slice(0, num_spokes)
    for spoke_index in range(active_spokes.size()):
        var spoke_id = active_spokes[spoke_index]
        var config = SPOKE_CONFIG[spoke_id]
        var angle = (2.0 * PI * spoke_index) / float(num_spokes)
        
        var get_pos = func(radial: float, perp: float = 0.0):
            return {
                "x": 0.5 + cos(angle) * radial + (-sin(angle)) * perp,
                "y": 0.5 + sin(angle) * radial + (cos(angle)) * perp
            }
            
        # 2a. Linear spoke nodes
        var spoke_node_ids = []
        for i in range(1, NODES_PER_SPOKE + 1):
            var node_id = "node_%s_s%d" % [spoke_id, i]
            var pos = get_pos.call(SPOKE_STEP * i)
            
            var type = "standard"
            if randf() < 0.2: type = "event"
            elif randf() < 0.1: type = "hard"
            
            var node = {
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
                    var prev_spoke_id = active_spokes[spoke_index - 1]
                    for e in edges:
                        if e["from"] == hub_node["id"] and e["to"] == node_id:
                            e["requiredMedal"] = "medal_" + prev_spoke_id
                            break
                hub_node["connectedTo"].append(node_id)
            else:
                var prev_id = spoke_node_ids[i-2]
                add_edge.call(prev_id, node_id, base_km, 0.04)
                # find prev node
                for n in nodes:
                    if n["id"] == prev_id:
                        n["connectedTo"].append(node_id)
                        break

        # 2b. Island mini-DAG
        var last_spoke_id = spoke_node_ids[NODES_PER_SPOKE - 1]
        
        var ISLAND_ENTRY = SPOKE_STEP * NODES_PER_SPOKE + SPOKE_STEP * 0.8
        var ISLAND_MID   = SPOKE_STEP * NODES_PER_SPOKE + SPOKE_STEP * 1.6
        var ISLAND_PRE   = SPOKE_STEP * NODES_PER_SPOKE + SPOKE_STEP * 2.4
        var ISLAND_BOSS  = SPOKE_STEP * NODES_PER_SPOKE + SPOKE_STEP * 3.2
        
        var r_types = [random_island_node_type(), random_island_node_type(), random_island_node_type(), random_island_node_type()]
        
        var ie_id = "node_%s_ie" % spoke_id
        var il_id = "node_%s_il" % spoke_id
        var ic_id = "node_%s_ic" % spoke_id
        var ir_id = "node_%s_ir" % spoke_id
        var ip_id = "node_%s_ip" % spoke_id
        var boss_id = "node_%s_boss" % spoke_id
        
        var mk_node = func(id: String, type: String, floor: int, radial: float, perp: float = 0.0):
            var pos = get_pos.call(radial, perp)
            return {
                "id": id,
                "type": type,
                "floor": floor,
                "col": 0,
                "x": pos["x"],
                "y": pos["y"],
                "connectedTo": [],
                "metadata": {"spokeId": spoke_id}
            }
            
        var ie_node = mk_node.call(ie_id, r_types[0], NODES_PER_SPOKE + 1, ISLAND_ENTRY, 0.0)
        var il_node = mk_node.call(il_id, r_types[1], NODES_PER_SPOKE + 2, ISLAND_MID, -0.05)
        var ic_node = mk_node.call(ic_id, "shop", NODES_PER_SPOKE + 2, ISLAND_MID, 0.0)
        var ir_node = mk_node.call(ir_id, r_types[2], NODES_PER_SPOKE + 2, ISLAND_MID, 0.05)
        var ip_node = mk_node.call(ip_id, r_types[3], NODES_PER_SPOKE + 3, ISLAND_PRE, 0.0)
        var boss_node = mk_node.call(boss_id, "boss", NODES_PER_SPOKE + 4, ISLAND_BOSS, 0.0)
        
        nodes.append_array([ie_node, il_node, ic_node, ir_node, ip_node, boss_node])
        
        # Last spoke -> entry
        add_edge.call(last_spoke_id, ie_id, base_km, 0.04)
        for n in nodes:
            if n["id"] == last_spoke_id:
                n["connectedTo"].append(ie_id)
                break
                
        # entry -> left/center/right
        add_edge.call(ie_id, il_id, base_km, 0.05)
        add_edge.call(ie_id, ic_id, base_km, 0.03)
        add_edge.call(ie_id, ir_id, base_km, 0.05)
        ie_node["connectedTo"].append_array([il_id, ic_id, ir_id])
        
        # left/center/right -> pre-boss
        add_edge.call(il_id, ip_id, base_km, 0.05, "gravel")
        add_edge.call(ic_id, ip_id, base_km, 0.03)
        add_edge.call(ir_id, ip_id, base_km, 0.05, "gravel")
        il_node["connectedTo"].append(ip_id)
        ic_node["connectedTo"].append(ip_id)
        ir_node["connectedTo"].append(ip_id)
        
        # pre-boss -> boss
        add_edge.call(ip_id, boss_id, base_km * 1.5, 0.08)
        ip_node["connectedTo"].append(boss_id)

    # 3. Final Boss
    var final_angle = PI * (2.0 * num_spokes - 1.0) / float(num_spokes)
    var final_dist = 0.45
    var final_boss_node = {
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
    for e in edges:
        if e["from"] == hub_node["id"] and e["to"] == final_boss_node["id"]:
            e["requiresAllMedals"] = true
            break
            
    hub_node["connectedTo"].append(final_boss_node["id"])
    
    run_data["nodes"] = nodes
    run_data["edges"] = edges
    run_data["currentNodeId"] = hub_node["id"]
    run_data["visitedNodeIds"] = [hub_node["id"]]
    
    var total_map_dist = (num_spokes * weight_per_spoke + 2) * base_km * 1000.0
    run_data["stats"]["totalMapDistanceM"] = total_map_dist
    
    print("[MAP GEN] spokes: %d, nodes: %d, edges: %d, total length: %.1fkm" % [
        num_spokes, nodes.size(), edges.size(), total_map_dist / 1000.0
    ])
