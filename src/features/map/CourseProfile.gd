class_name CourseProfile
extends Resource

# Port of CourseProfile.ts
# Defines a cycling course as an ordered list of grade segments.

const DEFAULT_SURFACE: Resource = preload("res://src/features/map/surfaces/asphalt.tres")

@export var segments: Array[Dictionary] = [] ## Array of Dictionaries {distanceM, grade, surface}
@export var total_distance_m: float = 0.0

static func get_surface_resource(surface_name: String) -> Resource:
	if surface_name == "asphalt": return preload("res://src/features/map/surfaces/asphalt.tres")
	if surface_name == "gravel": return preload("res://src/features/map/surfaces/gravel.tres")
	if surface_name == "dirt": return preload("res://src/features/map/surfaces/dirt.tres")
	if surface_name == "mud": return preload("res://src/features/map/surfaces/mud.tres")
	return DEFAULT_SURFACE

static func get_crr_for_surface(surface_name: String = "asphalt") -> float:
	var res: Resource = get_surface_resource(surface_name)
	if res.get("crr") != null:
		return res.get("crr")
	return 0.005

func get_grade_at_distance(distance_m: float) -> float:
	if total_distance_m <= 0: return 0.0
	
	var wrapped: float = fmod(distance_m, total_distance_m)
	if wrapped < 0: wrapped += total_distance_m
	var remaining: float = wrapped
	for segment: Dictionary in segments:
		if remaining < segment["distanceM"]:
			return segment["grade"]
		remaining -= segment["distanceM"]
	return 0.0

func get_elevation_at_distance(distance_m: float) -> float:
	if total_distance_m <= 0: return 0.0
	
	var num_wraps: float = floor(distance_m / total_distance_m)
	var wrapped: float = distance_m - (num_wraps * total_distance_m)
	
	var total_elev: float = 0.0
	for segment: Dictionary in segments:
		total_elev += segment["distanceM"] * segment["grade"]
		
	var remaining: float = wrapped
	var current_wrap_elev: float = 0.0
	for segment: Dictionary in segments:
		var dist: float = min(remaining, segment["distanceM"])
		current_wrap_elev += dist * segment["grade"]
		if remaining <= segment["distanceM"]: break
		remaining -= segment["distanceM"]
		
	return (num_wraps * total_elev) + current_wrap_elev

func get_surface_at_distance(distance_m: float) -> Resource:
	if total_distance_m <= 0: return DEFAULT_SURFACE
	
	var wrapped: float = fmod(distance_m, total_distance_m)
	if wrapped < 0: wrapped += total_distance_m
	var remaining: float = wrapped
	for segment: Dictionary in segments:
		if remaining < segment["distanceM"]:
			var surf_val: Variant = segment.get("surface", "asphalt")
			if typeof(surf_val) == TYPE_STRING:
				return CourseProfile.get_surface_resource(surf_val)
			return surf_val as Resource
		remaining -= segment["distanceM"]
	return DEFAULT_SURFACE

static func generate_course_profile(distance_km: float, max_grade: float, surface: String = "asphalt") -> CourseProfile:
	var total_m: float = distance_km * 1000.0
	var flat_end_m: float = clamp(total_m * 0.05, 50.0, 1500.0)
	
	var new_segments: Array[Dictionary] = []
	new_segments.append({"distanceM": flat_end_m, "grade": 0.0, "surface": surface})
	
	var budget_m: float = total_m - 2.0 * flat_end_m
	var net_elev_m: float = 0.0
	
	var seg_max: float = clamp(total_m * 0.04, 200.0, 2500.0)
	var seg_min: float = max(100.0, seg_max * 0.35)
	
	var mags: Array[float] = [max_grade * 0.25, max_grade * 0.50, max_grade * 0.75, max_grade]
	
	while budget_m >= seg_min:
		var hi: float = min(seg_max, budget_m - seg_min)
		if hi <= 0: break
		var lo: float = min(seg_min, hi)
		var length: float = lo + randf() * max(0.0, hi - lo)
		
		var pressure: float = clamp(net_elev_m / (total_m * max_grade * 1.0), -1.0, 1.0)
		var r: float = randf()
		var s_sign: int = 0
		
		if pressure > 0.7: s_sign = -1
		elif pressure < -0.7: s_sign = 1
		elif r < 0.08: s_sign = 0
		else: s_sign = 1 if (r < 0.55 - pressure * 0.2) else -1
		
		var grade: float = 0.0 if s_sign == 0 else s_sign * mags[randi() % mags.size()]
		
		new_segments.append({"distanceM": length, "grade": grade, "surface": surface})
		net_elev_m += length * grade
		budget_m -= length
		
	if budget_m > 0:
		if new_segments.size() == 1:
			var s_sign: int = 1 if randf() < 0.5 else -1
			var grade: float = float(s_sign) * mags[randi() % mags.size()]
			new_segments.append({"distanceM": budget_m, "grade": grade, "surface": surface})
		else:
			new_segments[new_segments.size() - 1]["distanceM"] += budget_m
			
	new_segments.append({"distanceM": flat_end_m, "grade": 0.0, "surface": surface})
	
	var final_total: float = 0.0
	for s: Dictionary in new_segments: final_total += s["distanceM"]
	
	var profile: CourseProfile = CourseProfile.new()
	profile.segments = new_segments
	profile.total_distance_m = final_total
	return profile

func invert_course_profile() -> CourseProfile:
	var reversed_segments: Array[Dictionary] = []
	for i in range(segments.size() - 1, -1, -1):
		var seg: Dictionary = segments[i].duplicate()
		seg["grade"] = -seg["grade"]
		reversed_segments.append(seg)
		
	var profile: CourseProfile = CourseProfile.new()
	profile.segments = reversed_segments
	profile.total_distance_m = total_distance_m
	return profile
