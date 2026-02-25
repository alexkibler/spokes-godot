extends Node

# Autoload: RewardManager.gd
# Handles the loot pool and reward UI orchestration.

var registry: ContentRegistry

func _ready() -> void:
    registry = ContentRegistry.new()
    registry.bootstrap()

func get_random_rewards(count: int = 3) -> Array:
    return registry.get_loot_pool(count, RunManager)

func apply_reward(reward_id: String) -> void:
    var r = registry.get_reward(reward_id)
    if r.has("apply"):
        r["apply"].call(RunManager)
