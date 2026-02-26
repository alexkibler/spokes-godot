# GEMINI.md - Spokes (Godot)

Foundational mandates and precedence instructions for Gemini CLI.

## Foundational Mandates
- **Strict Static Typing**: This project uses 100% strict static typing. Never declare a variable without a type (`var x: int = 0`) and never write a function without a return type (`func x() -> void`).
- **Domain-Driven Architecture**: Adhere strictly to the `src/features/` and `src/core/` directory structure. Keep logic separated from UI.
- **Test-Driven Mentality**: Always check for corresponding tests in `tests/` before making logic changes. Add new tests for every fix or feature.
- **Signal-Based Decoupling**: Use `SignalBus.gd` for all communication between state managers and UI screens. Do not introduce direct cross-singleton dependencies unless absolutely necessary.

## Project Structure (Quick Reference)
- `src/core/`: Utilities and global bus.
- `src/features/cycling/`: Physics, `Cyclist` entity, and components (`HardwareReceiver`, `Drafting`, `Surge`).
- `src/features/map/`: `MapGenerator`, `CourseProfile`.
- `src/features/progression/`: `RunManager`, `ContentRegistry`, `FitWriter`.
- `src/ui/`: All screens and UI components.

## Development Workflows
### Modifying Physics
Physics logic lives in `src/features/cycling/CyclistPhysics.gd` (static). Always verify changes against `tests/features/cycling/test_cyclist_physics.gd`.

### Adding a New Item/Reward
1. Register the item/reward in `src/features/progression/ContentRegistry.gd` inside `bootstrap()`.
2. Update `tests/features/progression/test_items_rewards.gd` to verify behavior.

### UI/UX Updates
Screens live in `src/ui/screens/`. Use `@onready` variables for node references and connect to `SignalBus` signals for state updates. Ensure all new components are strictly typed.

## Command Palette
- **Run All Tests**: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- **Deploy Local**: `./deploy_local.sh`

## CI/CD Note
Pull requests are automatically validated using GitHub Actions. Unit tests MUST pass for the Docker build to proceed.

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
