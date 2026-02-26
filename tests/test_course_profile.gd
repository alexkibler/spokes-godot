extends GutTest

# Tests ported from ~/Repos/spokes/src/core/course/__tests__/CourseProfile.test.ts

func build_course_profile(segments_data: Array) -> Dictionary:
	var total_dist = 0.0
	for s in segments_data:
		total_dist += s["distanceM"]
	return {
		"segments": segments_data,
		"totalDistanceM": total_dist
	}

# ─── Fixtures ─────────────────────────────────────────────────────────────────

func get_simple_course() -> Dictionary:
	return build_course_profile([
		{"distanceM": 1000.0, "grade": 0.00},
		{"distanceM": 1000.0, "grade": 0.05},
		{"distanceM": 1000.0, "grade": -0.03}
	])

func get_surface_course() -> Dictionary:
	return build_course_profile([
		{"distanceM": 500.0, "grade": 0.00},                        # asphalt (implicit)
		{"distanceM": 500.0, "grade": 0.02, "surface": "gravel"},
		{"distanceM": 500.0, "grade": 0.01, "surface": "mud"},
		{"distanceM": 500.0, "grade": 0.00}                         # asphalt (implicit)
	])

# ─── buildCourseProfile ───────────────────────────────────────────────────────

func test_build_course_profile():
	var simple_course = get_simple_course()
	assert_eq(simple_course.totalDistanceM, 3000.0, "totalDistanceM should be sum of segment distances")
	assert_eq(simple_course.segments[0].grade, 0.00)
	assert_eq(simple_course.segments[1].grade, 0.05)
	assert_eq(simple_course.segments[2].grade, -0.03)

# ─── getGradeAtDistance ───────────────────────────────────────────────────────

func test_get_grade_at_distance():
	var simple_course = get_simple_course()
	assert_eq(CourseProfile.get_grade_at_distance(simple_course, 0.0), 0.00)
	assert_eq(CourseProfile.get_grade_at_distance(simple_course, 500.0), 0.00)
	assert_eq(CourseProfile.get_grade_at_distance(simple_course, 1500.0), 0.05)
	assert_eq(CourseProfile.get_grade_at_distance(simple_course, 2500.0), -0.03)
	
	# it('returns the grade of a segment at its exact start boundary')
	assert_eq(CourseProfile.get_grade_at_distance(simple_course, 1000.0), 0.05)
	
	# it('wraps around when distance exceeds total course length')
	assert_eq(CourseProfile.get_grade_at_distance(simple_course, 3000.0), 0.00)
	assert_eq(CourseProfile.get_grade_at_distance(simple_course, 3500.0), 0.00)
	assert_eq(CourseProfile.get_grade_at_distance(simple_course, 4200.0), 0.05)
	
	# it('handles negative distances')
	assert_eq(CourseProfile.get_grade_at_distance(simple_course, -500.0), -0.03) # Should wrap to 2500m

# ─── getElevationAtDistance ───────────────────────────────────────────────────

func test_get_elevation_at_distance():
	var simple_course = get_simple_course()
	assert_eq(CourseProfile.get_elevation_at_distance(simple_course, 0.0), 0.0)
	assert_almost_eq(CourseProfile.get_elevation_at_distance(simple_course, 1000.0), 0.0, 0.00001)
	
	# After 500 m of 5% climbing: 500 * 0.05 = 25 m
	assert_almost_eq(CourseProfile.get_elevation_at_distance(simple_course, 1500.0), 25.0, 0.00001)
	
	# 1000 m of flat + 1000 m * 0.05 = 50 m peak
	assert_almost_eq(CourseProfile.get_elevation_at_distance(simple_course, 2000.0), 50.0, 0.00001)
	
	# After 500 m of −3% descent: 50 − 500 * 0.03 = 35 m
	assert_almost_eq(CourseProfile.get_elevation_at_distance(simple_course, 2500.0), 35.0, 0.00001)
	
	# Elevation at 3000 m (modulo 3000 = 0) is 0
	assert_almost_eq(CourseProfile.get_elevation_at_distance(simple_course, 3000.0), 0.0, 0.00001)

# ─── getSurfaceAtDistance ─────────────────────────────────────────────────────

func test_get_surface_at_distance():
	var surface_course = get_surface_course()
	assert_eq(CourseProfile.get_surface_at_distance(surface_course, 0.0), "asphalt")
	assert_eq(CourseProfile.get_surface_at_distance(surface_course, 250.0), "asphalt")
	assert_eq(CourseProfile.get_surface_at_distance(surface_course, 750.0), "gravel")
	assert_eq(CourseProfile.get_surface_at_distance(surface_course, 1250.0), "mud")
	
	# it('picks up the next segment exactly at the boundary')
	assert_eq(CourseProfile.get_surface_at_distance(surface_course, 500.0), "gravel")
	assert_eq(CourseProfile.get_surface_at_distance(surface_course, 1000.0), "mud")
	
	# it('wraps around to the start surface')
	assert_eq(CourseProfile.get_surface_at_distance(surface_course, 2000.0), "asphalt")

# ─── getCrrForSurface ─────────────────────────────────────────────────────────

func test_get_crr_for_surface():
	assert_gt(CourseProfile.get_crr_for_surface("gravel"), CourseProfile.get_crr_for_surface("asphalt"))
	assert_gt(CourseProfile.get_crr_for_surface("dirt"), CourseProfile.get_crr_for_surface("gravel"))
	assert_gt(CourseProfile.get_crr_for_surface("mud"), CourseProfile.get_crr_for_surface("dirt"))
	
	# Default to asphalt
	assert_eq(CourseProfile.get_crr_for_surface(), CourseProfile.get_crr_for_surface("asphalt"))
