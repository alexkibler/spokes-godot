class_name CourseProfile
extends Object

# Port of CourseProfile.ts
# Defines a cycling course as an ordered list of grade segments.

const CRR_BY_SURFACE = {
    "asphalt": 0.005, # smooth tarmac — baseline
    "gravel":  0.012, # packed gravel  — ~2.4× baseline
    "dirt":    0.020, # dirt track     — ~4×   baseline
    "mud":     0.040, # soft mud       — ~8×   baseline
}

static func get_crr_for_surface(surface: String = "asphalt") -> float:
    return CRR_BY_SURFACE.get(surface, 0.005)

static func get_grade_at_distance(profile: Dictionary, distance_m: float) -> float:
    var total_dist = profile.get("totalDistanceM", 0.0)
    if total_dist <= 0: return 0.0
    
    var wrapped = fmod(distance_m, total_dist)
    if wrapped < 0: wrapped += total_dist
    var remaining = wrapped
    for segment in profile.get("segments", []):
        if remaining < segment["distanceM"]:
            return segment["grade"]
        remaining -= segment["distanceM"]
    return 0.0

static func get_elevation_at_distance(profile: Dictionary, distance_m: float) -> float:
    var total_dist = profile.get("totalDistanceM", 0.0)
    if total_dist <= 0: return 0.0
    
    var wrapped = fmod(distance_m, total_dist)
    if wrapped < 0: wrapped += total_dist
    var remaining = wrapped
    var elevation = 0.0
    for segment in profile.get("segments", []):
        var dist = min(remaining, segment["distanceM"])
        elevation += dist * segment["grade"]
        if remaining <= segment["distanceM"]: break
        remaining -= segment["distanceM"]
    return elevation

static func get_surface_at_distance(profile: Dictionary, distance_m: float) -> String:
    var total_dist = profile.get("totalDistanceM", 0.0)
    if total_dist <= 0: return "asphalt"
    
    var wrapped = fmod(distance_m, total_dist)
    if wrapped < 0: wrapped += total_dist
    var remaining = wrapped
    for segment in profile.get("segments", []):
        if remaining < segment["distanceM"]:
            return segment.get("surface", "asphalt")
        remaining -= segment["distanceM"]
    return "asphalt"

static func generate_course_profile(distance_km: float, max_grade: float, surface: String = "asphalt") -> Dictionary:
    var total_m = distance_km * 1000.0
    var flat_end_m = clamp(total_m * 0.05, 50.0, 1500.0)
    
    var segments = []
    segments.append({"distanceM": flat_end_m, "grade": 0.0, "surface": surface})
    
    var budget_m = total_m - 2.0 * flat_end_m
    var net_elev_m = 0.0
    
    var seg_max = clamp(total_m * 0.04, 200.0, 2500.0)
    var seg_min = max(100.0, seg_max * 0.35)
    
    var mags = [max_grade * 0.25, max_grade * 0.50, max_grade * 0.75, max_grade]
    
    while budget_m >= seg_min:
        var hi = min(seg_max, budget_m - seg_min)
        if hi <= 0: break
        var lo = min(seg_min, hi)
        var length = lo + randf() * max(0.0, hi - lo)
        
        var pressure = clamp(net_elev_m / (total_m * max_grade * 1.0), -1.0, 1.0)
        var r = randf()
        var sign = 0
        
        if pressure > 0.7: sign = -1
        elif pressure < -0.7: sign = 1
        elif r < 0.08: sign = 0
        else: sign = 1 if (r < 0.55 - pressure * 0.2) else -1
        
        var grade = 0.0 if sign == 0 else sign * mags[randi() % mags.size()]
        
        segments.append({"distanceM": length, "grade": grade, "surface": surface})
        net_elev_m += length * grade
        budget_m -= length
        
    if budget_m > 0:
        if segments.size() == 1:
            var sign = 1 if randf() < 0.5 else -1
            var grade = sign * mags[randi() % mags.size()]
            segments.append({"distanceM": budget_m, "grade": grade, "surface": surface})
        else:
            segments[segments.size() - 1]["distanceM"] += budget_m
            
    segments.append({"distanceM": flat_end_m, "grade": 0.0, "surface": surface})
    
    var final_total = 0.0
    for s in segments: final_total += s["distanceM"]
    
    return {
        "segments": segments,
        "totalDistanceM": final_total
    }

static func invert_course_profile(profile: Dictionary) -> Dictionary:
    var reversed_segments = []
    var old_segments = profile.get("segments", [])
    for i in range(old_segments.size() - 1, -1, -1):
        var seg = old_segments[i].duplicate()
        seg["grade"] = -seg["grade"]
        reversed_segments.append(seg)
        
    return {
        "segments": reversed_segments,
        "totalDistanceM": profile.get("totalDistanceM", 0.0)
    }
