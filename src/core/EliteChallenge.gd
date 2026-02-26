class_name EliteChallenge
extends Object

# Port of EliteChallenge.ts
# Data types, challenge pool, and scoring helpers for Elite nodes.

const ELITE_CHALLENGES = [
	{
		"id": "sustained_threshold",
		"title": "Threshold Push",
		"flavorText": "A steep switchback cuts across the ridge. A local rival blocks the road and sneers: "Bet you can't hold threshold the whole way up."",
		"conditionText": "Complete this ride with average power above 125% of your FTP ({ftp_watts} W).",
		"condition": {"type": "avg_power_above_ftp_pct", "ftpMultiplier": 1.25},
		"reward": {"type": "gold", "goldAmount": 120, "description": "earn 120 gold"}
	},
	{
		"id": "sprint_peak",
		"title": "Sprint Finish",
		"flavorText": "The road levels out and a crowd lines the barriers. A hand-painted sign reads: "Town sprint — 200m." Your legs are fresh. Your ego is not.",
		"conditionText": "Hit a peak power above 250% of your FTP ({ftp_watts} W) at any point during this ride.",
		"condition": {"type": "peak_power_above_ftp_pct", "ftpMultiplier": 2.50},
		"reward": {"type": "item", "item": "tailwind", "description": "receive a Tailwind"}
	},
	{
		"id": "no_stop",
		"title": "Clean Ascent",
		"flavorText": "A rain-slicked cobbled climb stretches ahead. A chalk message on the tarmac reads: "The old code demands you never unclip."",
		"conditionText": "Complete this ride without coming to a full stop at any point.",
		"condition": {"type": "complete_no_stop"},
		"reward": {"type": "gold", "goldAmount": 40, "description": "earn 40 gold"}
	},
	{
		"id": "time_trial",
		"title": "Time Trial Effort",
		"flavorText": "Race marshals have chalked a start and finish line across the road. A stopwatch clicks. A crowd of two watches expectantly.",
		"conditionText": "Complete this ride in under 2 minutes.",
		"condition": {"type": "time_under_seconds", "timeLimitSeconds": 120},
		"reward": {"type": "gold", "goldAmount": 150, "description": "earn 150 gold"}
	},
	{
		"id": "vo2max_ramp",
		"title": "Red Zone Ramp",
		"flavorText": "The gradient ticks upward with every metre. A painted line on the road reads: "VO₂ or go home." Above it, someone has added: "Please go home."",
		"conditionText": "Complete this ride with average power above 140% of your FTP ({ftp_watts} W).",
		"condition": {"type": "avg_power_above_ftp_pct", "ftpMultiplier": 1.40},
		"reward": {"type": "gold", "goldAmount": 200, "description": "earn 200 gold"}
	}
]

static func get_random_challenge() -> Dictionary:
	return ELITE_CHALLENGES[randi() % ELITE_CHALLENGES.size()]

static func evaluate_challenge(challenge: Dictionary, metrics: Dictionary) -> bool:
	var condition = challenge.get("condition", {})
	var type = condition.get("type", "")
	var ftp_mult = condition.get("ftpMultiplier", 1.0)
	var time_limit = condition.get("timeLimitSeconds", 0)
	
	match type:
		"avg_power_above_ftp_pct":
			return metrics.get("avgPowerW", 0.0) >= metrics.get("ftpW", 200.0) * ftp_mult
		"peak_power_above_ftp_pct":
			return metrics.get("peakPowerW", 0.0) >= metrics.get("ftpW", 200.0) * ftp_mult
		"complete_no_stop":
			return not metrics.get("everStopped", false)
		"time_under_seconds":
			return metrics.get("elapsedSeconds", 0.0) < time_limit
	return false

static func grant_challenge_reward(challenge: Dictionary) -> void:
	var reward = challenge.get("reward", {})
	if reward.get("type") == "gold":
		RunManager.add_gold(reward.get("goldAmount", 0))
	elif reward.get("type") == "item":
		RunManager.add_to_inventory(reward.get("item", ""))

static func format_challenge_text(challenge: Dictionary, ftp_w: int) -> String:
	var text = challenge.get("conditionText", "")
	var condition = challenge.get("condition", {})
	if condition.has("ftpMultiplier"):
		var threshold = int(round(ftp_w * condition["ftpMultiplier"]))
		text = text.replace("{ftp_watts}", str(threshold))
	return text

static func generate_elite_course_profile(challenge: Dictionary) -> Dictionary:
	var segments = []
	match challenge.get("id", ""):
		"sustained_threshold":
			segments = [
				{"distanceM": 200,  "grade": 0,    "surface": "asphalt"},
				{"distanceM": 600,  "grade": 0.05, "surface": "asphalt"},
				{"distanceM": 1000, "grade": 0.07, "surface": "asphalt"},
				{"distanceM": 400,  "grade": 0.06, "surface": "gravel"},
				{"distanceM": 200,  "grade": 0,    "surface": "asphalt"}
			]
		"sprint_peak":
			segments = [
				{"distanceM": 600,  "grade": 0,    "surface": "asphalt"},
				{"distanceM": 200,  "grade": 0.02, "surface": "asphalt"},
				{"distanceM": 100,  "grade": 0.08, "surface": "asphalt"},
				{"distanceM": 200,  "grade": 0,    "surface": "asphalt"}
			]
		"no_stop":
			segments = [
				{"distanceM": 200,  "grade": 0.03,  "surface": "asphalt"},
				{"distanceM": 400,  "grade": -0.04, "surface": "asphalt"},
				{"distanceM": 300,  "grade": 0.05,  "surface": "gravel"},
				{"distanceM": 500,  "grade": -0.03, "surface": "gravel"},
				{"distanceM": 300,  "grade": 0.04,  "surface": "dirt"},
				{"distanceM": 300,  "grade": -0.02, "surface": "asphalt"},
				{"distanceM": 200,  "grade": 0,     "surface": "asphalt"}
			]
		"time_trial":
			segments = [
				{"distanceM": 150,  "grade": 0,     "surface": "asphalt"},
				{"distanceM": 700,  "grade": -0.01, "surface": "asphalt"},
				{"distanceM": 150,  "grade": 0,     "surface": "asphalt"}
			]
		"vo2max_ramp":
			segments = [
				{"distanceM": 200,  "grade": 0,    "surface": "asphalt"},
				{"distanceM": 500,  "grade": 0.07, "surface": "asphalt"},
				{"distanceM": 500,  "grade": 0.10, "surface": "asphalt"},
				{"distanceM": 500,  "grade": 0.12, "surface": "gravel"},
				{"distanceM": 200,  "grade": 0,    "surface": "asphalt"}
			]
		_:
			return CourseProfile.generate_course_profile(2, 0.06, "asphalt")
	
	var total_dist = 0.0
	for s in segments: total_dist += s["distanceM"]
	return {"segments": segments, "totalDistanceM": total_dist}
