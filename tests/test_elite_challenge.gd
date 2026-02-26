extends "res://addons/gut/test.gd"

# Tests ported from ~/Repos/spokes/src/core/roguelike/__tests__/EliteChallenge.test.ts

func make_metrics(overrides: Dictionary = {}) -> Dictionary:
	var m = {
		"avgPowerW": 200.0,
		"peakPowerW": 300.0,
		"ftpW": 200.0,
		"everStopped": false,
		"elapsedSeconds": 120.0
	}
	for key in overrides:
		m[key] = overrides[key]
	return m

# ─── ELITE_CHALLENGES pool ─────────────────────────────────────────────────────

func test_pool_sanity():
	var pool = EliteChallenge.ELITE_CHALLENGES
	assert_eq(pool.size(), 5, "contains exactly 5 challenges")
	
	var ids = []
	for c in pool:
		assert_gt(c.id.length(), 0, "unique id required")
		assert_gt(c.title.length(), 0, "title required")
		assert_gt(c.conditionText.length(), 0, "conditionText required")
		ids.append(c.id)
		
	# Check unique ids
	var unique_ids = []
	for id in ids:
		if not id in unique_ids:
			unique_ids.append(id)
	assert_eq(unique_ids.size(), ids.size(), "ids should be unique")

# ─── get_random_challenge ───────────────────────────────────────────────────────

func test_get_random_challenge():
	var c = EliteChallenge.get_random_challenge()
	assert_not_null(c)
	# Check it exists in pool
	var found = false
	for entry in EliteChallenge.ELITE_CHALLENGES:
		if entry.id == c.id:
			found = true
			break
	assert_true(found, "random challenge should be from the pool")

# ─── evaluate_challenge ─────────────────────────────────────────────────────────

func test_evaluate_avg_power():
	var challenge = {
		"id": "test_avg",
		"condition": {"type": "avg_power_above_ftp_pct", "ftpMultiplier": 1.10}
	}
	
	assert_true(EliteChallenge.evaluate_challenge(challenge, make_metrics({"avgPowerW": 221, "ftpW": 200})))
	assert_true(EliteChallenge.evaluate_challenge(challenge, make_metrics({"avgPowerW": 250, "ftpW": 200})))
	assert_false(EliteChallenge.evaluate_challenge(challenge, make_metrics({"avgPowerW": 219, "ftpW": 200})))

func test_evaluate_peak_power():
	var challenge = {
		"id": "test_peak",
		"condition": {"type": "peak_power_above_ftp_pct", "ftpMultiplier": 1.50}
	}
	
	assert_true(EliteChallenge.evaluate_challenge(challenge, make_metrics({"peakPowerW": 300, "ftpW": 200})))
	assert_true(EliteChallenge.evaluate_challenge(challenge, make_metrics({"peakPowerW": 500, "ftpW": 200})))
	assert_false(EliteChallenge.evaluate_challenge(challenge, make_metrics({"peakPowerW": 299, "ftpW": 200})))

func test_evaluate_no_stop():
	var challenge = {
		"id": "test_no_stop",
		"condition": {"type": "complete_no_stop"}
	}
	
	assert_true(EliteChallenge.evaluate_challenge(challenge, make_metrics({"everStopped": false})))
	assert_false(EliteChallenge.evaluate_challenge(challenge, make_metrics({"everStopped": true})))

func test_evaluate_time_trial():
	var challenge = {
		"id": "test_time",
		"condition": {"type": "time_under_seconds", "timeLimitSeconds": 180}
	}
	
	assert_true(EliteChallenge.evaluate_challenge(challenge, make_metrics({"elapsedSeconds": 179})))
	assert_false(EliteChallenge.evaluate_challenge(challenge, make_metrics({"elapsedSeconds": 180})))
	assert_false(EliteChallenge.evaluate_challenge(challenge, make_metrics({"elapsedSeconds": 240})))

# ─── format_challenge_text ──────────────────────────────────────────────────────

func test_format_challenge_text():
	var challenge = {
		"conditionText": "Avg power above 110% of your FTP ({ftp_watts} W).",
		"condition": {"type": "avg_power_above_ftp_pct", "ftpMultiplier": 1.10}
	}
	assert_eq(EliteChallenge.format_challenge_text(challenge, 200), "Avg power above 110% of your FTP (220 W).")
	
	# Rounding 183 * 1.5 = 274.5 -> 275
	challenge["condition"]["ftpMultiplier"] = 1.5
	challenge["conditionText"] = "{ftp_watts}"
	assert_eq(EliteChallenge.format_challenge_text(challenge, 183), "275")

# ─── grant_challenge_reward ─────────────────────────────────────────────────────

func test_grant_challenge_reward():
	RunManager.start_new_run(3, 10.0, "normal", 200, 68.0, "imperial")
	var gold_before = RunManager.get_run().gold
	
	var gold_challenge = {
		"reward": {"type": "gold", "goldAmount": 60}
	}
	EliteChallenge.grant_challenge_reward(gold_challenge)
	assert_eq(RunManager.get_run().gold, gold_before + 60)
	
	var item_challenge = {
		"reward": {"type": "item", "item": "tailwind"}
	}
	EliteChallenge.grant_challenge_reward(item_challenge)
	assert_has(RunManager.get_run().inventory, "tailwind")
