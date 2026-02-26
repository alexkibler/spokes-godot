# Spokes (Godot)

**Spokes** is a 2D roguelike cycling simulator built in **Godot 4.6**. It is a port of a Phaser/TypeScript project, enhanced with deeper physics, modular components, and a domain-driven architecture.

The player controls a cyclist navigating a procedurally generated "Hub-and-Spoke" map, interfacing with real-world indoor cycling trainers via Bluetooth (FTMS).

## 🚀 Key Features

-   **Realistic Cycling Physics**: High-fidelity simulation of acceleration, aerodynamic drag (CdA), rolling resistance (Crr), and gravity.
-   **Hardware Integration**: Real-time power and cadence data from smart trainers using Web Bluetooth (FTMS).
-   **Roguelike Progression**:
    -   Procedural "Hub-and-Spoke" map generation.
    -   Item and reward system with weighted loot pools.
    -   Gated progression (Spoke Medals) leading to a final boss.
-   **Advanced Drafting**: Godot-exclusive drafting model featuring curved benefit drop-off and "Leading Draft" (push effect).
-   **Surge & Recovery**: Tactical state machine logic—being in a draft enables a "Surge" (power boost) followed by a "Recovery" phase.
-   **FIT File Export**: Seamless recording of ride telemetry for export to platforms like Strava.
-   **Autoplay Mode**: Heuristic-based pathfinding for automated simulation and testing.

## 🛠 Technology Stack

-   **Engine**: Godot 4.6 (GDScript)
-   **Language**: Strict Static Typing GDScript 2.0
-   **Testing**: GUT (Godot Unit Test) Framework
-   **Export Targets**: Web (via JavaScriptBridge for Bluetooth) and Mobile/Desktop

## 📁 Project Structure

The project follows a Domain-Driven Design (DDD) inspired structure:

-   `src/core/`: Singletons and baseline utilities (SignalBus, Units, Settings).
-   `src/features/cycling/`: Physics engine, drafting logic, and the modular `Cyclist` entity.
-   `src/features/map/`: Procedural course and map generators.
-   `src/features/progression/`: Run management, items, rewards, and FIT encoding.
-   `src/ui/`: Reusable components and full-screen overlays (screens).
-   `tests/`: Comprehensive test suite mirroring the `src` structure.

## 🏁 Getting Started

### Prerequisites
-   Godot Engine 4.6+

### Running the Project
1.  Clone the repository.
2.  Open `project.godot` in Godot.
3.  Press **F5** to run the main menu.

### Running Tests
Tests can be run from the Godot Editor using the GUT bottom panel or via the command line:

```sh
# Headless test execution
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

## 🏗 Build & Deployment

The project includes a `deploy_local.sh` script for rapid iteration:
1.  Injects local Git hash into build info.
2.  Performs a headless Web export.
3.  Restarts a local Docker container for browser-based testing.

## ⚖️ License
[Insert License Info Here]
