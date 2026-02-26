class_name EliteChallenge
extends Resource

# Port of EliteChallenge.ts
# Data types, challenge pool, and scoring helpers for Elite nodes.

@export var id: String = ""
@export var title: String = ""
@export_multiline var flavor_text: String = ""
@export_multiline var condition_text: String = ""

@export_group("Condition")
@export var condition_type: String = ""
@export var ftp_multiplier: float = 1.0
@export var time_limit_seconds: float = 0.0

@export_group("Reward")
@export var reward_type: String = ""
@export var reward_amount: int = 0
@export var reward_item: String = ""
@export var reward_description: String = ""

static func create(data: Dictionary) -> EliteChallenge:
    var c = EliteChallenge.new()
    c.id = data.get("id", "")
    c.title = data.get("title", "")
    c.flavor_text = data.get("flavorText", "")
    c.condition_text = data.get("conditionText", "")

    var cond = data.get("condition", {})
    c.condition_type = cond.get("type", "")
    c.ftp_multiplier = cond.get("ftpMultiplier", 1.0)
    c.time_limit_seconds = float(cond.get("timeLimitSeconds", 0.0))

    var rew = data.get("reward", {})
    c.reward_type = rew.get("type", "")
    c.reward_amount = rew.get("goldAmount", 0)
    c.reward_item = rew.get("item", "")
    c.reward_description = rew.get("description", "")
    return c

static func get_all_challenges() -> Array[EliteChallenge]:
    var challenges: Array[EliteChallenge] = []

    var data_list = [
        {
            "id": "sustained_threshold",
            "title": "Threshold Push",
            "flavorText": "A steep switchback cuts across the ridge. A local rival blocks the road and sneers: \"Bet you can't hold threshold the whole way up.\"",
            "conditionText": "Complete this ride with average power above 125% of your FTP ({ftp_watts} W).",
            "condition": {"type": "avg_power_above_ftp_pct", "ftpMultiplier": 1.25},
            "reward": {"type": "gold", "goldAmount": 120, "description": "earn 120 gold"}
        },
        {
            "id": "sprint_peak",
            "title": "Sprint Finish",
            "flavorText": "The road levels out and a crowd lines the barriers. A hand-painted sign reads: \"Town sprint — 200m.\" Your legs are fresh. Your ego is not.",
            "conditionText": "Hit a peak power above 250% of your FTP ({ftp_watts} W) at any point during this ride.",
            "condition": {"type": "peak_power_above_ftp_pct", "ftpMultiplier": 2.50},
            "reward": {"type": "item", "item": "tailwind", "description": "receive a Tailwind"}
        },
        {
            "id": "no_stop",
            "title": "Clean Ascent",
            "flavorText": "A rain-slicked cobbled climb stretches ahead. A chalk message on the tarmac reads: \"The old code demands you never unclip.\"",
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
            "flavorText": "The gradient ticks upward with every metre. A painted line on the road reads: \"VO₂ or go home.\" Above it, someone has added: \"Please go home.\"",
            "conditionText": "Complete this ride with average power above 140% of your FTP ({ftp_watts} W).",
            "condition": {"type": "avg_power_above_ftp_pct", "ftpMultiplier": 1.40},
            "reward": {"type": "gold", "goldAmount": 200, "description": "earn 200 gold"}
        }
    ]

    for d in data_list:
        challenges.append(EliteChallenge.create(d))

    return challenges

static func get_random_challenge() -> EliteChallenge:
    var all_challenges = get_all_challenges()
    return all_challenges[randi() % all_challenges.size()]

func evaluate(metrics: Dictionary) -> bool:
    match condition_type:
        "avg_power_above_ftp_pct":
            return metrics.get("avgPowerW", 0.0) >= metrics.get("ftpW", 200.0) * ftp_multiplier
        "peak_power_above_ftp_pct":
            return metrics.get("peakPowerW", 0.0) >= metrics.get("ftpW", 200.0) * ftp_multiplier
        "complete_no_stop":
            return not metrics.get("everStopped", false)
        "time_under_seconds":
            return metrics.get("elapsedSeconds", 0.0) < time_limit_seconds
    return false

func grant_reward() -> void:
    if reward_type == "gold":
        RunManager.add_gold(reward_amount)
    elif reward_type == "item":
        RunManager.add_to_inventory(reward_item)

func format_text(ftp_w: int) -> String:
    var text = condition_text
    if ftp_multiplier > 0: # crude check if it's relevant
        var threshold = int(round(ftp_w * ftp_multiplier))
        text = text.replace("{ftp_watts}", str(threshold))
    return text

func generate_course_profile(max_grade_limit: float = 0.10) -> CourseProfile:
    var segments = []
    match id:
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
            return CourseProfile.generate_course_profile(2, max_grade_limit, "asphalt")

    # Clamp grades
    for s in segments:
        s["grade"] = clamp(s["grade"], -max_grade_limit, max_grade_limit)

    var total_dist = 0.0
    for s in segments: total_dist += s["distanceM"]

    var profile = CourseProfile.new()
    profile.segments = segments
    profile.total_distance_m = total_dist
    return profile
