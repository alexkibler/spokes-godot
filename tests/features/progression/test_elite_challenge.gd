extends "res://addons/gut/test.gd"

func test_evaluate_threshold_push_success():
	var challenge = EliteChallenge.new()
	challenge.id = "sustained_threshold"
	challenge.condition_type = "avg_power_above_ftp_pct"
	challenge.ftp_multiplier = 1.25

	# FTP 200, needed > 250.
	var metrics = {"avgPowerW": 260.0, "ftpW": 200}
	assert_true(challenge.evaluate(metrics))

func test_evaluate_threshold_push_failure():
	var challenge = EliteChallenge.new()
	challenge.id = "sustained_threshold"
	challenge.condition_type = "avg_power_above_ftp_pct"
	challenge.ftp_multiplier = 1.25

	var metrics = {"avgPowerW": 240.0, "ftpW": 200}
	assert_false(challenge.evaluate(metrics))

func test_evaluate_peak_power():
	var challenge = EliteChallenge.new()
	challenge.id = "sprint_peak"
	challenge.condition_type = "peak_power_above_ftp_pct"
	challenge.ftp_multiplier = 2.50

	# FTP 200, needed > 500
	var metrics_success = {"peakPowerW": 510.0, "ftpW": 200}
	var metrics_failure = {"peakPowerW": 490.0, "ftpW": 200}
	assert_true(challenge.evaluate(metrics_success))
	assert_false(challenge.evaluate(metrics_failure))

func test_evaluate_time_trial():
	var challenge = EliteChallenge.new()
	challenge.id = "time_trial"
	challenge.condition_type = "time_under_seconds"
	challenge.time_limit_seconds = 120

	var metrics_success = {"elapsedSeconds": 110.0}
	var metrics_failure = {"elapsedSeconds": 130.0}
	assert_true(challenge.evaluate(metrics_success))
	assert_false(challenge.evaluate(metrics_failure))

func test_elite_course_generation():
	var challenge = EliteChallenge.new()
	challenge.id = "vo2max_ramp"

	# Default limit is 0.10 (10%)
	var profile: CourseProfile = challenge.generate_course_profile()
	
	assert_gt(profile.segments.size(), 0)
	# VO2 Ramp should have a 10% grade segment (clamped from 12%)
	var has_steep = false
	for s in profile.segments:
		if s["grade"] >= 0.10:
			has_steep = true
			break
	assert_true(has_steep, "VO2 Max ramp course should contain a steep segment at the limit")
