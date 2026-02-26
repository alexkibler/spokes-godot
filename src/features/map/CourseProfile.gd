class_name CourseProfile
extends Resource

# Port of CourseProfile.ts
# Defines a cycling course as an ordered list of grade segments.

const CRR_BY_SURFACE = {
    "asphalt": 0.005, # smooth tarmac — baseline
    "gravel":  0.012, # packed gravel  — ~2.4× baseline
    "dirt":    0.020, # dirt track     — ~4×   baseline
    "mud":     0.040, # soft mud       — ~8×   baseline
}

@export var segments: Array = [] ## Array of Dictionaries {distanceM, grade, surface}
@export var total_distance_m: float = 0.0

static func get_crr_for_surface(surface: String = "asphalt") -> float:
    return CRR_BY_SURFACE.get(surface, 0.005)

func get_grade_at_distance(distance_m: float) -> float:
    if total_distance_m <= 0: return 0.0
    
    var wrapped = fmod(distance_m, total_distance_m)
    if wrapped < 0: wrapped += total_distance_m
    var remaining = wrapped
    for segment in segments:
        if remaining < segment["distanceM"]:
            return segment["grade"]
        remaining -= segment["distanceM"]
    return 0.0

func get_elevation_at_distance(distance_m: float) -> float:
    if total_distance_m <= 0: return 0.0
    
    var num_wraps = floor(distance_m / total_distance_m)
    var wrapped = distance_m - (num_wraps * total_distance_m)
    
    var total_elev = 0.0
    for segment in segments:
        total_elev += segment["distanceM"] * segment["grade"]
        
    var remaining = wrapped
    var current_wrap_elev = 0.0
    for segment in segments:
        var dist = min(remaining, segment["distanceM"])
        current_wrap_elev += dist * segment["grade"]
        if remaining <= segment["distanceM"]: break
        remaining -= segment["distanceM"]
        
    return (num_wraps * total_elev) + current_wrap_elev

func get_surface_at_distance(distance_m: float) -> String:
    if total_distance_m <= 0: return "asphalt"
    
    var wrapped = fmod(distance_m, total_distance_m)
    if wrapped < 0: wrapped += total_distance_m
    var remaining = wrapped
    for segment in segments:
        if remaining < segment["distanceM"]:
            return segment.get("surface", "asphalt")
        remaining -= segment["distanceM"]
    return "asphalt"

static func generate_course_profile(distance_km: float, max_grade: float, surface: String = "asphalt") -> CourseProfile:
    var total_m = distance_km * 1000.0
    var flat_end_m = clamp(total_m * 0.05, 50.0, 1500.0)
    
    var new_segments = []
    new_segments.append({"distanceM": flat_end_m, "grade": 0.0, "surface": surface})
    
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
        var s_sign = 0
        
        if pressure > 0.7: s_sign = -1
        elif pressure < -0.7: s_sign = 1
        elif r < 0.08: s_sign = 0
        else: s_sign = 1 if (r < 0.55 - pressure * 0.2) else -1
        
        var grade = 0.0 if s_sign == 0 else s_sign * mags[randi() % mags.size()]
        
        new_segments.append({"distanceM": length, "grade": grade, "surface": surface})
        net_elev_m += length * grade
        budget_m -= length
        
    if budget_m > 0:
        if new_segments.size() == 1:
            var s_sign = 1 if randf() < 0.5 else -1
            var grade = s_sign * mags[randi() % mags.size()]
            new_segments.append({"distanceM": budget_m, "grade": grade, "surface": surface})
        else:
            new_segments[new_segments.size() - 1]["distanceM"] += budget_m
            
    new_segments.append({"distanceM": flat_end_m, "grade": 0.0, "surface": surface})
    
    var final_total = 0.0
    for s in new_segments: final_total += s["distanceM"]
    
    var profile = CourseProfile.new()
    profile.segments = new_segments
    profile.total_distance_m = final_total
    return profile

func invert_course_profile() -> CourseProfile:
    var reversed_segments = []
    for i in range(segments.size() - 1, -1, -1):
        var seg = segments[i].duplicate()
        seg["grade"] = -seg["grade"]
        reversed_segments.append(seg)
        
    var profile = CourseProfile.new()
    profile.segments = reversed_segments
    profile.total_distance_m = total_distance_m
    return profile
