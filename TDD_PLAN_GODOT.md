# TDD Strategy for Spokes: Godot Port

## Overview
This document outlines the strategy for implementing a comprehensive test suite in Godot, achieving parity with the original Phaser project. We will use GUT (Godot Unit Test) or a similar testing framework. The goal is to write failing tests based on Phaser's algorithms, then update the Godot codebase to pass them, ensuring core logic remains identical while accommodating intentional Godot-specific enhancements (e.g., Attacking and Leading Draft mechanics).

## 1. Core Physics (`CyclistPhysics`)
*   **Target File:** `src/core/CyclistPhysics.gd`
*   **Parity Goals:**
    *   `calculate_acceleration` should produce identical results given the same power, speed, grade, and `physics_config`.
    *   Test positive acceleration (pedaling flat), negative acceleration (coasting flat), coasting downhill, and terminal velocity.
    *   Test modifiers: `powerMult`, `dragReduction`, and `weightMult`.
*   **Godot Specifics:** 
    *   Ensure the `mass_ratio` scaling for trainer feel doesn't break the core acceleration math (it should be applied before/outside `calculate_acceleration` or tested explicitly in `GameScene` tests).

## 2. Drafting & Attacking (`DraftingPhysics` & `GameScene`)
*   **Target Files:** `src/core/DraftingPhysics.gd`, `src/scenes/GameScene.gd`
*   **Parity Goals:**
    *   Trailing draft (`get_draft_factor`): Ensure it respects the `DRAFT_MAX_DISTANCE_M` (20m) and boundaries.
*   **Godot Specifics (INTENTIONAL DEVIATIONS):**
    *   **Drafting Curve:** Godot uses a curved drop-off (`pow(1.5)`) instead of Phaser's linear drop-off.
    *   **Leading Draft (Push):** Test `get_leading_draft_factor` (Max 0.03 reduction, 3m distance). A rider in front gets a slight aero benefit from a rider close behind.
    *   **Attacking (Surge):** Test that being in a draft (`player_draft_factor > 0.01`) triggers the `surge_timer` (5s duration, 1.25x power).
    *   **Recovery:** Test that after a surge, the `recovery_timer` begins (4s duration, 0.85x power).
    *   *Note:* These tests will explicitly document the Godot-exclusive state machine.

## 3. Course Geometry (`CourseProfile`)
*   **Target File:** `src/core/CourseProfile.gd`
*   **Parity Goals:**
    *   `get_grade_at_distance`, `get_elevation_at_distance`, `get_surface_at_distance` must exactly match Phaser boundaries.
    *   Test distance wrapping (modulo course length).
    *   Test elevation accumulation across climbs and descents.
    *   Test surface changes and `get_crr_for_surface`.

## 4. Run Management (`RunManager`)
*   **Target File:** `src/autoloads/RunManager.gd`
*   **Parity Goals:**
    *   Test initialization (`start_new_run`): zero gold, empty inventory, neutral modifiers (1.0, 0.0, 1.0).
    *   Test gold transactions (`add_gold`, `spend_gold`).
    *   Test inventory limits and duplicates.
    *   Test `apply_modifier` (multiplicative for power/weight, additive/capped for drag).
    *   Test `complete_node_visit`: awarding gold, tracking visited nodes.
*   **Godot Specifics:**
    *   `equip_item` and `unequip_item` now rely on the global `ContentRegistry`. Tests must mock or initialize `ContentRegistry`.
    *   `is_edge_traversable`: Test the "Spoke Gate" mechanic (`requiredMedal` and `requiresAllMedals`), which is unique to Godot's linear spoke progression.

## 5. Map Generation (`MapGenerator`)
*   **Target File:** `src/core/MapGenerator.gd`
*   **Parity Goals:**
    *   Test `compute_num_spokes` based on total distance.
*   **Godot Specifics:**
    *   Test the generation of "Spoke Gates" (edges requiring previous spoke's medal).
    *   Test the placement of the final boss (`final_dist = 0.45`).
    *   Test the inclusion of random 'event' and 'hard' nodes on the linear spoke paths.

## 6. Centralized Utilities (`Units` & `ContentRegistry`)
*   **Target Files:** `src/autoloads/Units.gd`, `src/autoloads/ContentRegistry.gd`
*   **Parity Goals:**
    *   `Units`: Test exact precision of constants (`MI_TO_KM = 1.609344`). Test `format_fixed` and `is_close_to_integer` for floating-point jitter handling. Test speed conversions (`ms_to_kmh`).
    *   `ContentRegistry`: Test `register_item`, `get_item`, and weighted random `get_loot_pool` generation.

## Implementation Plan for Jules
1.  **Setup GUT:** Install Godot Unit Test (GUT) via the AssetLib.
2.  **Scaffold Test Classes:** Create mirroring test scripts in a `tests/` directory (e.g., `test_cyclist_physics.gd`, `test_run_manager.gd`).
3.  **Port Assertions:** Translate Vitest assertions (`expect(x).toBe(y)`) to GUT assertions (`assert_eq(x, y)`).
4.  **Red Tests:** Run the suite. Tests involving Attacking, Leading Draft, and Map Generation *should* fail if strictly copied from Phaser because Godot handles them differently.
5.  **Green Tests:** Update the assertions for Godot-specific mechanics to document the intended new behavior. Ensure all core math (Physics, CourseProfile, Units) passes without modification to the source code.
