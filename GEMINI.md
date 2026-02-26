# GEMINI.md - Spokes (Godot)

## Project Overview
**Spokes** is a 2D roguelike cycling simulator built in **Godot 4.6** (Mobile/Web target, 1280x720). It is a port of a Phaser/TypeScript project where the player rides a smart trainer (via Bluetooth FTMS) through a procedurally generated hub-and-spoke map.

### Core Technologies
- **Engine**: Godot 4.6 (GDScript)
- **Testing**: GUT (Godot Unit Test) framework
- **Target Platforms**: Web (via JavaScriptBridge for Bluetooth) and Mobile
- **Key Features**: Procedural map generation, realistic cycling physics, drafting mechanics, and FIT file export.

---

## Building and Running

### Running the Project
Open `project.godot` in the Godot 4.6+ editor and press **F5** (Run).

### Running Tests
Tests are located in `res://tests/` and use the GUT framework.

**Headless (CLI):**
```sh
# Run all tests
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# Run a specific test file
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_cyclist_physics.gd -gexit
```

**In-Editor:**
1. Enable the GUT plugin in Project Settings.
2. Use the "GUT" bottom panel to run tests.

---

## CI/CD Pipeline
The project uses GitHub Actions for continuous integration and deployment:
- **Unit Testing**: GUT tests are executed on every push and pull request using `chickensoft-games/setup-godot` and manual GUT CLI commands.
- **Deployment Gating**: The Docker build and push to GHCR will **only** proceed if the unit tests pass.
- **PR Validation**: Pull requests must pass all tests before they can be merged.

---

## Architecture & File Structure

### Autoloads (Singletons)
| Autoload | Path | Role |
|---|---|---|
| `Units` | `src/autoloads/Units.gd` | Unit conversion constants and formatting (Metric/Imperial). |
| `ContentRegistry` | `src/autoloads/ContentRegistry.gd` | Database of items, rewards, and loot pools. |
| `RunManager` | `src/autoloads/RunManager.gd` | Central run state: gold, inventory, visited nodes, active modifiers. |
| `TrainerService` | `src/autoloads/TrainerService.gd` | Bluetooth FTMS bridge (JSBridge for Web, Mock for Desktop). |
| `SettingsManager` | `src/autoloads/SettingsManager.gd` | Persistence for user settings (FTP, weight, units). |

### Core Logic (`src/core/`)
- **`CyclistPhysics.gd`**: The core math for acceleration, drag, and rolling resistance.
- **`DraftingPhysics.gd`**: Logic for trailing and leading draft factors.
- **`CourseProfile.gd`**: Grade and elevation lookup for procedural segments.
- **`MapGenerator.gd`**: Generates the hub-and-spoke graph structure.
- **`FitWriter.gd`**: Encodes ride telemetry into the `.fit` file format.

### Main Scenes (`src/scenes/`)
- **`MenuScene.tscn`**: Entry point, run configuration.
- **`MapScene.tscn`**: Hub-and-spoke navigation and progression.
- **`GameScene.tscn`**: The cycling simulation loop, physics integration, and HUD.

---

## Development Conventions

### Coding Style
- **Pure Logic**: Business logic, physics, and math should live in `src/core/` and inherit from `Object` or `RefCounted` to remain decoupled from the SceneTree.
- **Type Safety**: Use static typing in GDScript (`var x: float = 0.0`) wherever possible.
- **Units**: Always use `Units` autoload for conversions to ensure consistency across the app. Base calculations should generally use Metric (m, m/s, kg).

### Testing Practices
- **Mirroring**: Every file in `src/core/` or `src/autoloads/` should have a corresponding test file in `tests/` prefixed with `test_`.
- **TDD**: When porting or adding physics/math features, write a GUT test first to confirm parity or expected behavior.

### Godot-Specific Enhancements (Deviations from Phaser)
- **Leading Draft**: Riders get a slight benefit when a rider is close behind them (`DraftingPhysics`).
- **Surge/Recovery**: Being in a draft triggers a "Surge" (increased power) followed by a "Recovery" phase (`GameScene`).
- **Spoke Gates**: Progression is gated by medals earned in previous spokes (`RunManager`).
