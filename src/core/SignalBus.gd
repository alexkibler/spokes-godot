extends Node
## Centralized Event Bus for Global Signals
##
## This singleton manages communication between decoupled systems.
## Instead of direct references, systems emit signals here, and UI/other systems listen.

# --- Hardware Signals ---
signal trainer_connected
signal trainer_disconnected
signal trainer_power_updated(watts: float)
signal trainer_cadence_updated(rpm: float)
signal trainer_speed_updated(kmh: float)

# --- Run / Gameplay Signals ---
signal run_started
signal run_ended
signal modifiers_changed
signal autoplay_changed(enabled: bool)
signal gold_changed(total_gold: int)
signal inventory_changed
signal item_discovered(item_id: String)
