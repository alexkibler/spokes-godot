# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Spokes** is a 2D roguelike cycling simulator built in **Godot 4.6** (Mobile target, 1280×720). It is a port of an original Phaser/TypeScript project. The player rides a smart trainer (via Bluetooth/FTMS) through a procedurally generated hub-and-spoke map.

## Running Tests

Tests use the **GUT (Godot Unit Test)** framework (`addons/gut/`). Tests live in `tests/` and mirror the structure of `src/core/` and `src/autoloads/`.

To run tests, open the project in the Godot editor and use the GUT panel, or run headlessly:

```sh
# Run all tests headlessly
"/Volumes/1TB/External Applications/Godot.app/Contents/MacOS/Godot" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

To run a single test file:
```sh
"/Volumes/1TB/External Applications/Godot.app/Contents/MacOS/Godot" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_cyclist_physics.gd -gexit
```

Test files: `test_cyclist_physics.gd`, `test_course_profile.gd`, `test_run_manager.gd`, `test_map_generator.gd`, `test_units.gd`, `test_elite_challenge.gd`, `test_fit_writer.gd`.

## Architecture

### Autoloads (Singletons)

All registered in `project.godot` and accessible globally:

| Autoload | Role |
|---|---|
| `Units` | Unit conversion constants and formatting helpers (port of `UnitConversions.ts`) |
| `ContentRegistry` | Item/reward database with weighted loot pool (`bootstrap()` hardcodes all content) |
| `RunManager` | Central run state: gold, inventory, equipped items, modifiers, map nodes/edges |
| `TrainerService` | Bluetooth FTMS trainer bridge via `JavaScriptBridge` (web export only); mock mode for desktop |
| `SettingsManager` | Persists FTP, weight, units to `user://settings.cfg` |

### Core (Pure Logic, No Scene Dependencies)

| File | Role |
|---|---|
| `CyclistPhysics.gd` | Physics engine — `calculate_acceleration(power, velocity, config, modifiers)` |
| `DraftingPhysics.gd` | Draft factor calculation with Godot-specific curved drop-off and leading draft |
| `CourseProfile.gd` | Course segment definitions; `get_grade_at_distance`, `get_elevation_at_distance`, `get_surface_at_distance` |
| `MapGenerator.gd` | Hub-and-spoke procedural map generation; computes nodes and edges with `CourseProfile` embedded per edge |
| `EliteChallenge.gd` | Elite challenge type definitions |
| `FitWriter.gd` | Encodes ride data into `.fit` file format |
| `Theme.gd` | Biome color constants |

### Scenes

Main scene flow: `MenuScene` → `MapScene` → `GameScene` → `VictoryScene`

- **`GameScene.gd`**: Ride orchestrator. Reads active edge from `RunManager`, runs the physics loop (`CyclistPhysics`), handles surge/recovery state machine (Godot-exclusive), drives ghosts, FIT recording, and HUD updates.
- **`MapScene.gd`**: Displays the hub-and-spoke map, handles node selection and edge traversal gating (spoke medals).
- **`MenuScene.gd`**: Run setup (FTP, weight, distance, difficulty).
- **`VictoryScene.gd`**: Post-ride stats and FIT export.

### UI Overlays (in `src/ui/`)

Scene-attached overlays opened modally during `MapScene`: `RewardOverlay`, `ShopOverlay`, `EquipmentOverlay`, `EventOverlay`, `PauseOverlay`, `MapHUD`.

## Key Design Decisions (Godot vs Phaser Deviations)

- **Spoke Gates**: Each spoke requires the medal from the previous spoke. The finish node (`requiresAllMedals: true`) requires all medals. This is Godot-only; Phaser's hub is fully open.
- **Drafting curve**: Godot uses `pow(1.5)` curved drop-off; Phaser uses linear.
- **Leading Draft**: Godot adds a small aero benefit to the rider *in front* (max 0.03 reduction at 3m).
- **Attacking/Surge**: Being in a draft triggers `surge_timer` (5s, 1.25× power) then `recovery_timer` (4s, 0.85× power). This state machine lives in `GameScene.gd`.
- **Autoplay**: Uses a heuristic (Vector2 distance to target boss/finish). Phaser uses dynamic programming.
- **Final boss placement**: `final_dist = 0.45` (much further than Phaser's `0.06`).
- **Trainer integration**: Done via `JavaScriptBridge` to injected JS (Web export only). The JS sets `window.godot_ftms_callback` etc. Desktop uses mock data.

## Modifier System

`RunManager.run_data["modifiers"]` holds `{powerMult, dragReduction, weightMult, crrMult}`. Modifiers are:
- **Multiplicative**: `powerMult`, `weightMult`, `crrMult`
- **Additive/capped at 0.99**: `dragReduction`

`apply_modifier(delta, label)` stacks modifiers. `equip_item`/`unequip_item` auto-apply/reverse item modifiers via `ContentRegistry`.

## Map Structure

`generate_hub_and_spoke_map` produces:
- 1 hub node (`node_hub`)
- Per spoke: 2 linear nodes + 6 island nodes (entry, left, center/shop, right, pre-boss, boss)
- 1 final finish node
- All edge `profile` fields are pre-generated `CourseProfile` dictionaries

`compute_num_spokes(total_distance_km)` = `clamp(round(km / 20), 2, 8)` using biome IDs from `SPOKE_IDS` (plains → jungle).
