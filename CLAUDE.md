# CLAUDE.md - Spokes (Godot)

Project instructions and conventions for Claude Code.

## Project Overview
**Spokes** is a 2D Roguelike Cycling Simulator in Godot 4.6. It interfaces with smart trainers (Bluetooth FTMS) and features realistic physics and procedural map generation.

## Build & Test Commands
- **Run Game**: Open `project.godot` and press F5.
- **Run All Tests (Headless)**: 
  `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- **Run Specific Test File**: 
  `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/features/cycling/test_cyclist_physics.gd -gexit`
- **Local Web Deployment**: `./deploy_local.sh` (Injects hash, exports Web, restarts Docker).

## Coding Standards (Strict Static Typing)
- **Mandatory Static Typing**: Every variable, function parameter, and return value MUST have an explicit static type (e.g., `var x: float = 0.0`, `func f(a: int) -> void`).
- **Domain-Driven Directory Structure**:
  - `src/core/`: Global singletons (`SignalBus`, `Units`, `SettingsManager`).
  - `src/features/cycling/`: Physics, drafting, and `Cyclist` entity/components.
  - `src/features/map/`: Procedural generation and course profiles.
  - `src/features/progression/`: `RunManager`, `ContentRegistry`, rewards, items, FIT export.
  - `src/ui/`: Components and screens.
- **Conventions**:
  - Use `class_name` for all logic scripts to enable type-hinting.
  - Logic MUST be decoupled from SceneTree where possible (inherit from `RefCounted` or `Object`).
  - Use `SignalBus` for decoupled communication between managers and UI.
  - Units: Base calculations use Metric (m, m/s, kg). Use `Units` singleton for conversions.
  - Testing: Every feature script should have a corresponding test in `tests/` prefixed with `test_`.

## Key Architectural Patterns
- **Entity-Component**: `Cyclist.gd` coordinates modular child nodes (`HardwareReceiver`, `Drafting`, `Surge`, `Visuals`).
- **Resource-Based Data**: Data models (e.g., `CyclistStats`, `CourseProfile`, `EliteChallenge`) inherit from `Resource`.
- **Global Signal Bus**: UI and state managers communicate via `SignalBus.gd`.
- **Hardware Abstraction**: `TrainerService.gd` handles Web Bluetooth vs. Mock Desktop data.

## Godot 4.6 Strict Typing & GDScript Quirks
This project treats GDScript warnings as compilation errors. To prevent CI/CD failures and parse errors, strictly adhere to the following rules:

1. **Variant and Array/Dictionary Casting:**
   - GDScript will fail to compile if you iterate over a `Variant` that it cannot guarantee is an `Array`. Always explicitly cast loosely typed data structures:
     ```gdscript
     # BAD (Parse Error):
     for node: Dictionary in run_data["nodes"]: 
     
     # GOOD:
     for node: Dictionary in (run_data["nodes"] as Array):
     ```
   - Same applies to retrieving typed values from dictionaries: `var id: String = (dict.get("metadata", {}) as Dictionary).get("id", "")`

2. **Dynamic Method Calling (Duck Typing):**
   - If a method exists on a Node or Autoload (like `RunManager` or instantiated `PackedScene`) but the static analyzer only knows it as a base `Node` or `Variant`, **do not use dot notation**. Use `.call()` to bypass the compiler check safely.
     ```gdscript
     # BAD (Parse Error: Method not present on inferred type):
     overlay.setup(data)
     rm_node.add_to_inventory("item")
     
     # GOOD:
     overlay.call("setup", data)
     rm_node.call("add_to_inventory", "item")
     ```

3. **Verifying Node Types Before Casting:**
   - Never assume a node's type based on its name or siblings. Casting a `Polygon2D` to a `ColorRect` will silently evaluate to `null` and cause a runtime crash when properties like `.color` are accessed. Always verify the type in the `.tscn` file before casting.
     ```gdscript
     ($ParallaxBackground/HillLayer/Hills as Polygon2D).color = ...
     ```

4. **JavaScriptObject Properties:**
   - In Godot 4.6+, you cannot use dot notation to set properties on a `JavaScriptObject` (it will trigger a parse error). You must use `.set()` and `.get()`.
     ```gdscript
     # BAD: window.godot_ftms_callback = my_callback
     # GOOD: window.set("godot_ftms_callback", my_callback)
     ```

5. **Autoloads and `class_name`:**
   - Be highly cautious adding `class_name` to heavily cross-referenced Autoloads (like `RunManager`). It can create cyclic compilation failures. Prefer `extends Node` and use `.call()` when passing the Autoload as a dependency to lambdas or other classes.
