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
