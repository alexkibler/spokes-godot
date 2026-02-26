# Comparing Spokes: Phaser vs. Godot

This document analyzes the architectural, gameplay, and technical differences between the original Phaser implementation and the new Godot port.

## 1. Architectural Differences

| Feature | Phaser (Original) | Godot (Port) |
| :--- | :--- | :--- |
| **State Management** | Centralized `RunManager.ts` (Class) injected via `ServiceLocator`. | `RunManager.gd` (Autoload/Singleton). |
| **Dependency Injection** | Explicit `ServiceLocator` and `registry` injection. | Godot Singletons (Autoloads) and Node Tree access. |
| **UI System** | Custom `BaseOverlay.ts` hierarchy; manual DOM/Canvas rendering. | Native `.tscn` scenes with `Control` nodes and `Theme.tres`. |
| **Asset Management** | Phaser Loader (JSON/Image manifests). | Godot `.import` system and `load()/preload()`. |
| **Persistence** | `SaveManager.ts` with explicit `IStorageProvider` (LocalStorage). | `SaveManager.gd` (Simpler JSON serialization to `user://`). |

## 2. Gameplay & Progression

### Elite Challenges
- **Phaser**: Features a robust `EliteChallenge.ts` system with 5+ unique challenge types (TT, Peak Power, Threshold, No-Stop). Each challenge generates a *tailored* `CourseProfile` (e.g., steep ramps for VO2Max challenges).
- **Godot**: Challenges are currently more generic or missing the tailored terrain generation logic.

### Autoplay (Zen Mode)
- **Phaser**: Uses a **Dynamic Programming (DP)** algorithm to calculate the optimal path backwards from the finish/boss nodes.
- **Godot**: Uses a **Heuristic** (Vector2 distance to target) which is simpler but potentially less reliable on complex map layouts.

### Reward Logic
- **Phaser**: `RunManager.getBestReward()` uses a heuristic that calculates the "Net Value" of a reward (e.g., how much better a new item is than the currently equipped one).
- **Godot**: `get_best_reward()` uses a simpler rarity and biome-based score.

### Content Depth (Items & Rewards)
- **Phaser**: Highly modular item system. Items like `AntigravPedals`, `GoldCrank`, `RerollVoucher`, `TeleportConsumable`, and `DirtTires` have specific logic. Consumables like `Tailwind` can be triggered from the UI.
- **Godot**: Basic set of items (`Aero Helmet`, `Carbon Frame`). Missing special items like reroll vouchers and teleport consumables. The registry is currently a single hardcoded function.

### Map Generation & Progression Flow
- **Phaser**: The Hub is fully open. A player can attempt any spoke in any order. The final boss node is placed very close to the hub (`finalDist = 0.06`).
- **Godot**: Implements "Spoke Gates." Each subsequent spoke requires the medal from the previous one, forcing linear progression. The final boss is placed much further out (`finalDist = 0.45`). Adds random "Event/Hard" node types to linear spokes.

### Environment Effects (Wind)
- **Phaser**: Features an `EnvironmentEffectsUI.ts` that manages "Headwind" (0.5x power) and "Tailwind" (2x power) status effects. These can be toggled manually in the UI or triggered by items.
- **Godot**: Does not have a formal wind effect system yet, only a basic "tailwind" item in the inventory logic.

### Remote Controller & Network
- **Phaser**: Includes a full `RemoteService.ts` and `remote/` bridge that allows a secondary device (like a phone) to act as a controller via `Socket.io`. It shows a real-time HUD and item buttons on the remote device.
- **Godot**: No remote controller bridge or secondary device support currently implemented.

### Internationalization (i18n)
- **Phaser**: Uses `i18next` with `en` and `fr-CA` (French-Canadian) locales. All UI strings are translated.
- **Godot**: UI strings are currently hardcoded in English.

## 3. Physics & Hardware

### Trainer Simulation
- **Phaser**: `GameScene.ts` uses `massRatio` (Player Mass / 83kg) to scale grade and friction so the trainer feel is consistent regardless of rider weight.
- **Godot**: Recently updated to match this logic, but previously used raw values.

### Real Speed vs. Virtual Speed
- **Phaser**: Explicitly distinguishes between `rawTrainerSpeedMs` (from the flywheel) and virtual acceleration.
- **Godot**: Recently updated to match this smoothing logic.

### Heart Rate Integration
- **Phaser**: Robust `HeartRateService.ts` with Bluetooth and Remote (Bridge) support.
- **Godot**: `TrainerService.gd` handles basic trainer data; HR support is less developed or relies on different JS hooks.

### Rendering & Visuals
- **Phaser**: `ParallaxBackground.ts` handles complex cloud movement and biome-specific layering (Plains, Coast, Mountain). `CyclistRenderer.ts` has specific logic for ghost transparency and animation "juice."
- **Godot**: Implements `ParallaxBackground.gd` and `CyclistVisuals.tscn`, but has fewer visual layers and less complex biome transitions.

### Design System (Theme)
- **Phaser**: Extremely detailed `theme.ts` with 100+ color primitives, semantic tokens (e.g., `grades.steepClimb`, `parallax.mudDeep`), and layout/spacing constants.
- **Godot**: Sparse `Theme.gd` with only basic biome and parallax colors. Most UI styling is currently done directly in the `.tscn` files or via a generic `.tres`.

### Unit Conversions & Formatting
- **Phaser**: Centralized `UnitConversions.ts` using precise international standards (e.g., `LB_TO_KG = 0.45359237`). Includes helpers like `isCloseToInteger` to prevent floating-point jitter in the HUD.
- **Godot**: Conversions are currently hardcoded or using approximate values (e.g., `0.000621371` for meters to miles) in multiple places.

### Quality of Life (Juice)
- **Phaser**: Includes "bobbing" animations for cyclists, detailed slipstream visual rows (7 distinct colors), and smooth rotation of the entire world container based on road grade.
- **Godot**: Basic cyclist bobbing and world rotation implemented, but lacks the multi-layered slipstream visuals and some of the finer visual feedback.

### Menu System & UX
- **Phaser**: Highly detailed `MenuScene.ts` with:
    - Distance presets tailored to units (e.g., 5, 10, 20 miles vs 10, 25, 50 km).
    - Customizable "Autoplay Delay" (500ms to 10s).
    - Detailed "Save Banner" showing cleared floors, gold, and total elevation gain from the last run.
    - "Hardware Test" button for quick calibration rides.
    - Confirmation modals for starting new runs (warning about overwriting saves).
- **Godot**: Simplified menu with basic inputs. Lacks presets, detailed save summaries, and the hardware test mode.

### Sound & Audio
- **Both**: Currently appear to be silent (no `sound.play` or `AudioStreamPlayer` usage identified).

## 4. Recommended Next Steps for Godot Port

1. **Port Elite Challenges**: Implement the tailored `CourseProfile` generation for specific challenge types from `EliteChallenge.ts`.
2. **Improve Autoplay**: Port the DP-based pathfinding from `RunManager.ts` to handle more complex map topologies.
3. **Modular Content**: Refactor the item/reward registry to load from external data or modular scripts to match Phaser's content depth.
4. **Environment Effects**: Build a proper Wind system to allow for items like `Tailwind` and `Headwind` hazards.
5. **Internationalization**: Implement Godot's built-in i18n system (`.po` files) to match Phaser's language support.
6. **UI Animation**: Phaser uses `Tweens` extensively; Godot should leverage `AnimationPlayer` and `Tween` for menu transitions and "Slipstream" notifications to match the "juice" of the original.
