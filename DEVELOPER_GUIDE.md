# Spokes Developer Guide

*For experienced web developers with zero game dev background.*

---

## Part 1: Godot for Web Developers

Before touching any Spokes-specific code, you need a mental model for how Godot works — because it's quite different from a React/Node/browser environment.

### The SceneTree is the DOM

In web dev, everything lives in the DOM tree. In Godot, everything lives in the **SceneTree** — a hierarchy of **Nodes**.

```
DOM                          Godot SceneTree
─────────────────────        ─────────────────────────
<html>                       Root
  <body>                       MenuScene (Node)
    <div class="game">           Background (Sprite2D)
      <canvas>                   UIPanel (Control)
                                   StartButton (Button)
```

A **Node** is the base building block. It can be a 2D object, a UI element, an audio player, a timer, a script runner — anything. Nodes are composed into **Scenes**, which are reusable subtrees (like React components, but heavier).

### GDScript is Python with Types

GDScript is Godot's scripting language. It looks like Python. This project uses **strict static typing**, so it looks more like TypeScript:

```gdscript
# TypeScript equivalent:
# function calculateSpeed(velocity: number, delta: number): number {
#   return velocity * delta
# }

func calculate_speed(velocity: float, delta: float) -> float:
    return velocity * delta
```

Every variable needs a type. Every function parameter needs a type. Every return value needs a type. Warnings are treated as compilation errors in this project.

### Autoloads are Singletons (like Redux Store)

In web, you might use Redux or a React context for global state. Godot has **Autoloads** — scripts that are instantiated once at startup and available everywhere by name.

```gdscript
# This works anywhere, like accessing window.myStore in a browser:
RunManager.run_data["gold"] += 100
SignalBus.emit_signal("gold_changed", 100)
SettingsManager.ftp_watts = 250
```

This project has 5 autoloads:
- `SignalBus` — global event bus
- `RunManager` — all run/game state
- `TrainerService` — Bluetooth hardware
- `SettingsManager` — user preferences
- `BuildInfo` — version metadata

### Signals are EventEmitter / Custom Events

Godot signals work exactly like `EventEmitter` in Node.js or `CustomEvent` in the browser.

```gdscript
# Define a signal (like: const myEvent = new EventTarget())
signal gold_changed(total_gold: int)

# Emit it (like: element.dispatchEvent(new CustomEvent('gold_changed', {detail: 100})))
SignalBus.gold_changed.emit(100)

# Listen to it (like: element.addEventListener('gold_changed', handler))
SignalBus.gold_changed.connect(_on_gold_changed)

func _on_gold_changed(total_gold: int) -> void:
    label.text = str(total_gold) + "g"
```

### `_ready()` is `componentDidMount()` / `connectedCallback()`

The `_ready()` function runs once when a node is added to the SceneTree — equivalent to `useEffect(() => {}, [])` or `componentDidMount()`.

### `_process()` and `_physics_process()` are the Game Loop

This is the biggest mental shift from web dev. Games run a **game loop** — a function that executes every frame (typically 60 times per second). There's no "wait for an event" — the loop always runs.

```gdscript
# Runs every frame (~60/s) - for UI, animations
func _process(delta: float) -> void:
    update_hud()

# Runs every physics tick (~60/s, but fixed timestep) - for physics
func _physics_process(delta: float) -> void:
    integrate_velocity(delta)  # delta is always the same here (~0.016s)
```

`delta` is the time elapsed since the last frame (in seconds). You multiply everything by `delta` to make behavior framerate-independent — the same reason you'd use `requestAnimationFrame` timestamps in JavaScript.

### Scene Transitions are like Page Navigation

Changing from the main menu to the game is done by swapping the active scene:

```gdscript
# Like: window.location.href = '/game'
get_tree().change_scene_to_file("res://src/features/cycling/GameScene.tscn")
```

### Resources are Serializable Data Objects

A **Resource** in Godot is a data container that can be saved to disk (`.tres` files) and loaded at runtime — like JSON but typed. This project uses them for:
- `CyclistStats` — physical constants (mass, drag, rolling resistance)
- `CourseProfile` — elevation segments
- `EliteChallenge` — challenge definitions
- `SurfaceType` — surface properties

---

## Part 2: Project Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                   AUTOLOADS (Singletons)             │
│  SignalBus │ RunManager │ TrainerService │ Settings  │
└──────┬──────────────┬───────────────┬───────────────┘
       │              │               │
       ▼              ▼               ▼
┌──────────┐   ┌──────────┐   ┌──────────────┐
│  SCENES  │   │ PHYSICS  │   │  HARDWARE    │
│          │   │          │   │              │
│ MenuScene│   │ Cyclist  │   │TrainerService│
│ MapScene │   │  ├─HW    │   │  (Bluetooth) │
│ GameScene│   │  ├─Draft │   └──────────────┘
│ Overlays │   │  ├─Surge │
└──────────┘   │  └─Visuals│
               └──────────┘
```

The game has three main "screens":
1. **MenuScene** — settings, Bluetooth pairing, difficulty
2. **MapScene** — roguelike map navigation
3. **GameScene** — the actual ride

Between screens, modal **overlays** appear for rewards, shops, events, etc.

---

## Part 3: Data Flow — From Pedal Power to Screen

This is the heart of the game. Let's trace what happens when you push on the pedals.

### Step 1: Hardware Input

**File:** `src/features/hardware/TrainerService.gd`

A smart trainer (like a Wahoo Kickr) connects via **Bluetooth FTMS** (Fitness Machine Service Protocol). On a web build, this goes through a JavaScript bridge:

```
Real Trainer → Bluetooth → Web Bluetooth API (JS) → JavaScriptBridge → TrainerService
```

On desktop (no Bluetooth), `TrainerService` uses mock mode — a timer that fires every second with fake data (200W constant, 60–110 RPM cadence).

TrainerService emits signals when data arrives:
```gdscript
# src/core/SignalBus.gd defines these:
signal trainer_power_updated(watts: float)
signal trainer_cadence_updated(rpm: float)
signal trainer_speed_updated(kmh: float)
```

### Step 2: HardwareReceiverComponent

**File:** `src/features/cycling/components/HardwareReceiverComponent.gd`

The player's `Cyclist` entity has a `HardwareReceiverComponent` that listens to those signals:

```gdscript
func _ready() -> void:
    SignalBus.trainer_power_updated.connect(_on_power_updated)

func _on_power_updated(watts: float) -> void:
    _current_power = watts
```

This component is the bridge between the hardware layer and the physics layer. AI ghosts don't use this — they have their power set programmatically.

### Step 3: Physics Calculation

**File:** `src/features/cycling/CyclistPhysics.gd`

Every physics frame (~60/s), `GameScene` calls `process_cyclist()` on the player. This:
1. Reads current power from `HardwareReceiverComponent`
2. Gets draft/surge modifiers
3. Calls `CyclistPhysics.calculate_acceleration()`

The physics engine solves a force balance equation:

```
Net Force = Propulsion - Aero Drag - Rolling Resistance - Gravity

a = (P/v  -  0.5·ρ·CdA·v²  -  Crr·m·g·cos(θ)  -  m·g·sin(θ)) / m

Where:
  P    = power in watts
  v    = current speed (m/s), min 0.1 to avoid division by zero
  ρ    = air density (1.225 kg/m³)
  CdA  = drag coefficient × frontal area (m²)
  Crr  = rolling resistance coefficient (surface-dependent)
  m    = mass in kg (rider + bike)
  g    = 9.80665 m/s²
  θ    = road angle in radians (from % grade)
```

This is essentially the same equation that cycling power meter apps use. It's well-validated physics.

The result is an acceleration value (m/s²). The game loop integrates it:
```gdscript
velocity_ms += acceleration * delta
distance_m += velocity_ms * delta
```

### Step 4: Modifiers Stack

Multiple systems modify the base physics. These are collected into a single dict:

```gdscript
{
    "powerMult":      1.0,   # × applied to raw power
    "dragReduction":  0.0,   # subtracted from CdA (additive benefits)
    "weightMult":     1.0,   # × applied to mass
    "crrMult":        1.0,   # × applied to rolling resistance
}
```

Sources that contribute to modifiers:
| Source | Effect | System |
|--------|--------|--------|
| Equipped items | powerMult, dragReduction, etc. | RunManager |
| Drafting (following) | +0.01–0.30 dragReduction | DraftingComponent |
| Drafting (leading) | +0.03 dragReduction | DraftingComponent |
| Surge state | ×1.25 power (5s) then ×0.85 (4s) | SurgeComponent |
| Surface type | crrMult varies | CourseProfile |

### Step 5: Trainer Resistance Feedback

The game also tells the trainer to change its resistance to simulate the current grade. This creates the "ERG mode" feel where it gets harder on hills:

```
GameScene → TrainerService.set_simulation_params({grade, crr, cwa})
          → JS: window.setFTMSGrade()
          → Bluetooth → Trainer motor adjusts resistance
```

### Step 6: HUD Display

`GameScene._update_hud()` runs every frame and pushes values to the UI labels:
- Power (W)
- Speed (km/h or mph, based on settings)
- Current grade (%)
- Distance remaining
- Course elevation graph (minimap style)

---

## Part 4: The Cyclist Entity (Entity-Component Pattern)

**File:** `src/features/cycling/Cyclist.gd`

Think of `Cyclist` like a React component that orchestrates child components. The scene tree looks like:

```
Cyclist (Node2D) ← Cyclist.gd
├── HardwareReceiver ← HardwareReceiverComponent.gd
├── Drafting ← DraftingComponent.gd
├── Surge ← SurgeComponent.gd
└── Visuals ← CyclistVisuals (sub-scene)
```

Each child extends `CyclistComponent` (a base class) and is initialized with a reference to the parent `Cyclist`. Communication is via return values and signals — not by reaching up the tree.

There are multiple `Cyclist` instances in a game:
- 1 **player cyclist** — reads from `HardwareReceiverComponent`
- 3 **ghost cyclists** (AI) — have power set via `set_power_manual()`

All share the same code path through `CyclistPhysics`. The only difference is input source.

### Why `.call()` Instead of Direct Method Calls?

You'll see this pattern everywhere:
```gdscript
hardware_receiver.call("set_power_manual", 200.0)
# instead of:
hardware_receiver.set_power_manual(200.0)
```

Godot's static analyzer doesn't know the concrete type of a `Node` fetched by path (`$HardwareReceiver`). It only knows it's a `Node`. Calling an unknown method on `Node` is a parse error. `.call()` bypasses the analyzer — it's like JavaScript's `obj['methodName']()`.

---

## Part 5: Drafting & Surge (Aerodynamics)

### Drafting Physics

**File:** `src/features/cycling/DraftingPhysics.gd`

Drafting (riding behind someone) reduces aerodynamic drag. The benefit follows a curve:

```
drag_reduction = 0.01 + (0.29 × (1 - distance/20m)^1.5)

At 0m:  0.30 drag reduction (30% less drag)
At 10m: ~0.11 drag reduction
At 20m: 0.01 (minimal benefit)
```

There's also a "leading push" — if someone is drafting you within 3m, you get a tiny benefit too (simulates the air pressure zone ahead of the follower).

### Surge State Machine

**File:** `src/features/cycling/components/SurgeComponent.gd`

When you get a drafting benefit, your character "surges" — a brief power boost followed by a recovery dip.

```
States:
  NORMAL (idle)
      ↓ when draft_factor > 0.01
  SURGE (5 seconds)
      powerMult = 1.25  (+25% power)
      ↓ after 5s
  RECOVERY (4 seconds)
      powerMult = 0.85  (-15% power)
      ↓ after 4s
  → back to NORMAL
```

This mimics real cycling: you "surf" the draft, slingshot past, then need a moment to recover.

---

## Part 6: The Map & Procedural Generation

### Hub-and-Spoke Topology

**File:** `src/features/map/MapGenerator.gd`

The roguelike map uses a "hub and spoke" structure — like a bicycle wheel:

```
         [shop]─[boss]
        /
[hub]──[node]──[event]──[boss]
        \
         [hard]──[shop]──[boss]
                            \
                         [FINISH]
```

- **Hub:** Starting node, you always start here
- **Spokes:** 2–8 radial branches (count scales with total distance)
- **Spoke nodes:** 1–3 intermediate nodes before the boss
- **Boss:** End of each spoke, grants a **medal**
- **Finish:** Requires all medals, triggers victory

Node types on spokes:
| Type | Description |
|------|-------------|
| `standard` | Basic ride, gold reward |
| `event` | Random narrative event |
| `hard` | Elite challenge node |
| `shop` | Buy equipment with gold |
| `boss` | Spoke boss (must complete for medal) |

The finish node is locked behind all medals — you can't reach it without clearing every spoke. This is the core roguelike gating mechanic.

### Course Profile Generation

**File:** `src/features/map/CourseProfile.gd`

Each edge (path between nodes) has a procedurally generated elevation profile. The algorithm:

1. Create flat start buffer (so you can get up to speed)
2. Pick a random number of segments
3. Assign each segment a grade (up or down), constrained by:
   - Max grade from difficulty setting
   - A "pressure" system that keeps elevation balanced (you have to come back down)
4. Create flat end buffer

The result is a list of `{distance_m, grade, surface}` tuples. During the ride, the game looks up the current grade from this list based on `distance_m` traveled.

Surface types affect rolling resistance (`Crr`):
| Surface | Crr | Visual |
|---------|-----|--------|
| Asphalt | 0.0041 | Default |
| Gravel | 0.006 | Tan/brown |
| Dirt | 0.007 | Orange-brown |
| Mud | 0.009 | Dark grey |

---

## Part 7: Roguelike Progression

### RunManager — The Redux Store

**File:** `src/features/progression/RunManager.gd`

`RunManager` is the single source of truth for everything in a run. Think of it like a Redux store:

```gdscript
# The "state" object:
run_data = {
    "gold": 0,
    "inventory": [],           # unequipped items
    "equipped": {},            # slot -> item_id
    "modifiers": {             # active physics effects
        "powerMult": 1.0,
        "dragReduction": 0.0,
        "weightMult": 1.0,
        "crrMult": 1.0
    },
    "modifierLog": [],         # audit trail
    "nodes": [],               # all map nodes
    "edges": [],               # all map edges
    "currentNodeId": "",
    "visitedNodeIds": [],
    "activeEdge": null,        # current course being ridden
    "stats": { ... }           # telemetry aggregates
}
```

When you equip an item, `RunManager` recalculates `modifiers` from scratch (all equipped items combined), then emits `SignalBus.modifiers_changed`. `GameScene` listens and picks up the new values next frame.

### Items vs Rewards

There are two kinds of progression bonuses:

**Items** (equipment with slots):
- Persist in inventory between nodes
- Can be equipped/unequipped
- Example: `aero_helmet` (-3% drag), `carbon_frame` (-12% weight, -3% drag)

**Rewards** (one-time permanent stat boosts):
- Applied immediately and permanently to the run
- Example: `stat_power_1` (Leg Day, +4% power)

Both are defined in `ContentRegistry.gd`.

### Elite Challenges

**File:** `src/features/progression/EliteChallenge.gd`

On `hard` nodes, you can opt into an elite challenge before starting the ride. Each challenge has a custom condition evaluated post-ride:

| Challenge | Goal | Reward |
|-----------|------|--------|
| Threshold Push | Sustain 125% FTP | 120 gold |
| Sprint Finish | Hit 250% FTP peak | Tailwind item |
| Clean Ascent | Never fully stop | 40 gold |
| Time Trial | Complete in 2 min | 150 gold |
| Red Zone Ramp | Sustain 140% FTP | 200 gold |

The challenge is tracked via `GameScene` accumulating metrics during the ride (power_sum, peak_power, elapsed_time, etc.) and evaluated in `_on_ride_complete()`.

### FIT Export

**File:** `src/features/progression/FitWriter.gd`

When a ride ends, all recorded data can be exported as a `.fit` file — the binary format used by Garmin, Strava, TrainingPeaks, etc. `FitWriter` implements the minimal FIT binary spec from scratch (no libraries), including the 16-bit CRC checksum.

---

## Part 8: Screens & Navigation Flow

```
MenuScene
    │
    ├─► [Start Run] → MapScene
    │
    └─► [Settings] (inline panel)

MapScene
    │
    ├─► [Click node] → GameScene (active_edge set in RunManager)
    │       │
    │       └─► [Ride complete] → back to MapScene
    │               │
    │               ├─► RewardOverlay (pick 1 of 3)
    │               ├─► ShopOverlay (buy with gold)
    │               ├─► EventOverlay (narrative + effect)
    │               └─► EliteOverlay (accept/decline challenge)
    │
    └─► [All medals] → VictoryScene
```

Scene transitions use `get_tree().change_scene_to_file()`. Overlays are instanced on top of the current scene and removed when dismissed.

### The Overlay Pattern

Overlays are modal dialogs. They're loaded into the scene as children, do their thing (show rewards, etc.), and emit a signal when done:

```gdscript
# GameScene spawns an overlay
var overlay := REWARD_OVERLAY.instantiate()
add_child(overlay)
overlay.call("setup", reward_choices)
overlay.overlay_dismissed.connect(_on_overlay_dismissed)
```

The overlay calls `RunManager` methods to apply changes (add items, deduct gold), then emits `overlay_dismissed`. `GameScene` removes it and continues.

---

## Part 9: The SignalBus (Event Architecture)

**File:** `src/core/SignalBus.gd`

The `SignalBus` is a blank `Node` that just declares signals. It replaces direct dependencies between systems. The key signals:

```
Hardware Events:
  trainer_connected
  trainer_disconnected
  trainer_power_updated(watts: float)
  trainer_cadence_updated(rpm: float)
  trainer_speed_updated(kmh: float)

Progression Events:
  run_started
  run_ended
  gold_changed(total_gold: int)
  inventory_changed
  item_discovered(item_id: String)
  modifiers_changed

State Events:
  autoplay_changed(enabled: bool)
```

Systems never hold direct references to each other. Instead:
- `TrainerService` emits `trainer_power_updated`
- `HardwareReceiverComponent` listens to `trainer_power_updated`
- Neither knows the other exists

This is the same pattern as Redux actions or a message bus.

---

## Part 10: Testing

**Framework:** GUT (Godot Unit Testing) — like Jest for Godot.

Tests live in `tests/` and mirror the `src/` structure:

```
tests/
  features/cycling/
    test_cyclist_physics.gd    # Unit tests for physics formulas
    test_drafting_physics.gd   # Draft factor curve tests
    test_surge_component.gd    # State machine transition tests
  features/map/
    test_map_generator.gd      # Topology tests
    test_course_profile.gd     # Grade/elevation tests
  features/progression/
    test_run_manager.gd        # State mutation tests
    test_elite_challenge.gd    # Challenge evaluation tests
    test_fit_writer.gd         # Binary encoding tests
  test_scenes_smoke.gd         # Instantiates every scene (crash detection)
  test_audit.gd                # Stats over 1000 procedural runs
```

Run all tests:
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Run one file:
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/features/cycling/test_cyclist_physics.gd -gexit
```

Tests look like this:
```gdscript
func test_climbing_reduces_speed() -> void:
    var stats := CyclistStats.create_from_weight(75.0)
    var flat_accel := CyclistPhysics.calculate_acceleration(200.0, 5.0, stats, 0.0)
    var climb_accel := CyclistPhysics.calculate_acceleration(200.0, 5.0, stats, 0.08)
    assert_gt(flat_accel, climb_accel)
```

---

## Part 11: Common GDScript Gotchas

These will bite you coming from TypeScript/JavaScript:

### 1. Iterating typed arrays from Dictionaries requires casting

```gdscript
# WRONG — parse error
for node: Dictionary in run_data["nodes"]:
    pass

# RIGHT
for node: Dictionary in (run_data["nodes"] as Array):
    pass
```

### 2. Calling unknown methods requires `.call()`

```gdscript
# WRONG — "Method not found on type Node"
var overlay: Node = $Overlay
overlay.setup(data)

# RIGHT
overlay.call("setup", data)
```

### 3. JavaScriptObject uses `.set()`/`.get()`

```gdscript
# WRONG — parse error
window.godot_callback = my_func

# RIGHT
window.set("godot_callback", my_func)
```

### 4. Node type before casting

Always check the `.tscn` file to verify what type a node actually is before casting. Casting to the wrong type gives `null` silently.

```gdscript
# Only safe if ParallaxBackground/HillLayer/Hills is actually a Polygon2D in the .tscn
var hills := $ParallaxBackground/HillLayer/Hills as Polygon2D
```

### 5. `class_name` on autoloads can cause circular deps

`RunManager` deliberately does NOT have a `class_name`. Autoloads that are heavily cross-referenced can cause cyclic compilation failures if given a `class_name`.

---

## Part 12: Adding New Features — Cookbook

### Add a new item

1. **Register it** in `ContentRegistry.gd`:
```gdscript
register_item({
    "id": "power_meter",
    "label": "Power Meter",
    "slot": "accessory",
    "modifier": {"powerMult": 1.03},
    "rarity": "uncommon",
    "description": "+3% effective power output"
})
```

2. **Write a test** in `tests/features/progression/test_items_rewards.gd`:
```gdscript
func test_power_meter_adds_3_percent() -> void:
    RunManager.start_new_run()
    RunManager.call("add_to_inventory", "power_meter")
    RunManager.call("equip_item", "power_meter")
    assert_almost_eq(
        RunManager.run_data["modifiers"]["powerMult"],
        1.03, 0.001
    )
```

3. Run the test to verify.

### Add a new surface type

1. Create `src/features/map/surfaces/cobblestone.tres`:
```
[gd_resource type="SurfaceType"]
name = "cobblestone"
crr = 0.008
particle_color = Color(0.5, 0.5, 0.5)
```

2. Add it to `CourseProfile.gd`'s surface selection logic.

3. Add a test checking that cobblestone Crr is higher than asphalt.

### Add a new elite challenge

1. Add to `EliteChallenge.get_all_challenges()`:
```gdscript
challenges.append(EliteChallenge.create(
    "sprint_intervals",
    "Sprint Intervals",
    "Hit 200% FTP three times",
    {"reward_gold": 250}
))
```

2. Track the metric in `GameScene._physics_process()`.

3. Evaluate in `GameScene._on_ride_complete()` using the challenge's conditions.

4. Write a test in `tests/features/progression/test_elite_challenge.gd`.

---

## Part 13: File Reference

| File | Purpose | Web Analogy |
|------|---------|-------------|
| `src/core/SignalBus.gd` | Global event bus | EventEmitter / Redux |
| `src/core/SettingsManager.gd` | User preferences | localStorage wrapper |
| `src/core/Units.gd` | Unit conversions (metric/imperial) | Utility library |
| `src/core/BuildInfo.gd` | Version watermark | `process.env.COMMIT_HASH` |
| `src/features/hardware/TrainerService.gd` | Bluetooth FTMS bridge | WebSocket client |
| `src/features/cycling/Cyclist.gd` | Player entity root | React component |
| `src/features/cycling/CyclistPhysics.gd` | Force calculations | Pure function / math util |
| `src/features/cycling/CyclistStats.gd` | Physical constants | Config object / Resource |
| `src/features/cycling/CyclistVisuals.gd` | Animation control | CSS/animation controller |
| `src/features/cycling/DraftingPhysics.gd` | Aero drag calculations | Pure math util |
| `src/features/cycling/components/HardwareReceiverComponent.gd` | Hardware → physics bridge | API service layer |
| `src/features/cycling/components/DraftingComponent.gd` | Manages drafting state | Stateful service |
| `src/features/cycling/components/SurgeComponent.gd` | Surge/recovery FSM | State machine |
| `src/features/cycling/GameScene.gd` | Main game loop | App root / game controller |
| `src/features/map/MapGenerator.gd` | Procedural map creation | Data factory |
| `src/features/map/CourseProfile.gd` | Elevation profile generation | Data model |
| `src/features/map/MapScene.gd` | Map UI & navigation | Page/view component |
| `src/features/map/SurfaceType.gd` | Surface properties | Config Resource |
| `src/features/progression/RunManager.gd` | All run state | Redux store |
| `src/features/progression/ContentRegistry.gd` | Items & rewards database | Static data / CMS |
| `src/features/progression/EliteChallenge.gd` | Challenge definitions | Data model + factory |
| `src/features/progression/FitWriter.gd` | Binary .fit file encoder | File serializer |
| `src/features/progression/VictoryScene.gd` | End screen | Page component |
| `src/ui/screens/MenuScene.gd` | Settings & start | Settings page |
| `src/ui/screens/RewardOverlay.gd` | Pick reward | Modal dialog |
| `src/ui/screens/ShopOverlay.gd` | Buy items | Modal dialog |
| `src/ui/screens/EventOverlay.gd` | Narrative events | Modal dialog |
| `src/ui/screens/EliteOverlay.gd` | Challenge prompt | Modal dialog |
| `src/ui/screens/PauseOverlay.gd` | Pause menu | Modal dialog |
| `src/ui/components/MapHUD.gd` | Map screen heads-up display | HUD component |

---

## Recommended Reading Order

If you're sitting down to understand this codebase for the first time:

1. **`project.godot`** — see what autoloads exist
2. **`src/core/SignalBus.gd`** — understand every cross-system signal
3. **`src/features/progression/RunManager.gd`** — understand the state shape
4. **`src/features/cycling/Cyclist.gd`** — see the entity structure
5. **`src/features/cycling/CyclistPhysics.gd`** — read the physics formulas
6. **`src/features/cycling/GameScene.gd`** — follow the game loop
7. **`src/features/map/MapGenerator.gd`** — see how maps are built
8. **`src/features/hardware/TrainerService.gd`** — understand Bluetooth integration
9. **`tests/features/cycling/test_cyclist_physics.gd`** — see how physics is tested

After that, the overlays and UI files follow naturally once you understand what data they're reading from `RunManager`.
