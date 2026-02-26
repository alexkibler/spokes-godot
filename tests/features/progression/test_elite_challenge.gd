extends "res://addons/gut/test.gd"

func test_evaluate_threshold_push_success():
	var challenge = {
		"id": "sustained_threshold",
		"condition": {"type": "avg_power_above_ftp_pct", "ftpMultiplier": 1.25}
	}
	# FTP 200, needed > 250.
	var metrics = {"avgPowerW": 260.0, "ftpW": 200}
	assert_true(EliteChallenge.evaluate_challenge(challenge, metrics))

func test_evaluate_threshold_push_failure():
	var challenge = {
		"id": "sustained_threshold",
		"condition": {"type": "avg_power_above_ftp_pct", "ftpMultiplier": 1.25}
	}
	var metrics = {"avgPowerW": 240.0, "ftpW": 200}
	assert_false(EliteChallenge.evaluate_challenge(challenge, metrics))

func test_evaluate_peak_power():
	var challenge = {
		"id": "sprint_peak",
		"condition": {"type": "peak_power_above_ftp_pct", "ftpMultiplier": 2.50}
	}
	# FTP 200, needed > 500
	var metrics_success = {"peakPowerW": 510.0, "ftpW": 200}
	var metrics_failure = {"peakPowerW": 490.0, "ftpW": 200}
	assert_true(EliteChallenge.evaluate_challenge(challenge, metrics_success))
	assert_false(EliteChallenge.evaluate_challenge(challenge, metrics_failure))

func test_evaluate_time_trial():
	var challenge = {
		"id": "time_trial",
		"condition": {"type": "time_under_seconds", "timeLimitSeconds": 120}
	}
	var metrics_success = {"elapsedSeconds": 110.0}
	var metrics_failure = {"elapsedSeconds": 130.0}
	assert_true(EliteChallenge.evaluate_challenge(challenge, metrics_success))
	assert_false(EliteChallenge.evaluate_challenge(challenge, metrics_failure))

func test_elite_course_generation():
	var challenge = {"id": "vo2max_ramp"}
	# Default limit is 0.10 (10%)
	var profile = EliteChallenge.generate_elite_course_profile(challenge)
	
	assert_gt(profile["segments"].size(), 0)
	# VO2 Ramp should have a 10% grade segment (clamped from 12%)
	var has_steep = false
	for s in profile["segments"]:
		if s["grade"] >= 0.10:
			has_steep = true
			break
	assert_true(has_steep, "VO2 Max ramp course should contain a steep segment at the limit")
