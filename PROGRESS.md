# Legends Battlegrounds PC (120 FPS Edition) — Development Roadmap & Progress

A standalone PC 3D Arena Battlegrounds fighting game built with **Godot 4.3 (Vulkan Forward+)** running at a locked **120 FPS + 120Hz Physics Tick**, inspired by *Legends Battlegrounds*, *Hyun's Dojo (KJ / Martial Legend)*, and *Combat Gods (Jun / Weapon God)*.

---

## Roadmap Status

- [x] **Step 1: Engine Setup, 120 FPS Pipeline & 3D Asset Library** *(COMPLETED)*
  - Installed portable **Godot 4.3 (Win64 Vulkan Forward+)** in `D:/LGB/engine/Godot_v4.3-stable_win64.exe`.
  - Configured `project.godot` for **120 FPS (`run/max_fps=120`, VSync Disabled)** and **120Hz Physics Interpolation (`physics_ticks_per_second=120`)**.
  - Downloaded & imported rigged 3D humanoid fighter & martial-arts/sword animation libraries (`assets/models/`):
    - `ual1_standard.glb` (43 animations: punches, jab, cross, jump, roll, hit reactions, sprint, etc.)
    - `ual2_standard.glb` (43 animations: melee hook, ninja jump, sword regular/heavy combos, sword dash, sword block, knockback, slide, etc.)
    - `fighter_hyun_dojo.glb` (Kimono/Martial Arts fighter mesh + 17 animations)
    - `fighter_combat_god.glb` (Ninja/Combat God fighter mesh + 17 animations)
    - `fighter_mannequin.glb` (Stickman/Dojo Mannequin fighter mesh + 16 animations)
  - Downloaded 3D weapons (`assets/weapons/`):
    - `katana.glb`, `staff_spear.glb`, `dagger.glb`, `claymore.glb`
  - Downloaded 3D Arena structure & destructible wall/floor models (`assets/arena/`):
    - `floor_tile_large.glb`, `floor_tile_large_rocks.glb`, `wall.glb`, `wall_cracked.glb`, `wall_broken.glb`, `pillar_decorated.glb`, `rubble_large.glb`
  - Downloaded photorealistic PBR rock & crater debris models (`assets/debris/`):
    - `boulder_01.glb`, `arena_boulder.glb`, `rock_chunk_01.glb`, `rock_chunk_02.glb`
  - Built initial 120Hz showcase scene (`scenes/Main.tscn` + `scripts/Main.gd`) with ACES Tonemapping, HDR Glow/Bloom, SSR, SSAO, Volumetric Fog, and live 120 FPS / Frame-Time HUD.

- [x] **Step 2: Full Destructible Battlegrounds Arena, Lighting & Next-Gen Post-Processing** *(COMPLETED)*
  - Built the full 52m x 52m Battlegrounds Arena (`scenes/BattlegroundsArena.tscn` + `scripts/BattlegroundsArena.gd` + `scripts/DestructibleWall.gd`) using 100% downloaded 3D GLB assets:
    - 13x13 tiled stone/rock floor (`floor_tile_large.glb`, `floor_tile_large_rocks.glb`) with randomized tile rotation + static physics floor.
    - 44 destructible perimeter wall segments with HP-based state machine swapping `wall.glb` -> `wall_cracked.glb` -> `wall_broken.glb`, camera/debris collision adjustment, and impact shake feedback.
    - Flying `RigidBody3D` debris bursts using `rock_chunk_01.glb` / `rock_chunk_02.glb` on heavy wall impacts (LOD0-only rendering, random spin/scale/velocity, TTL cleanup).
    - Decorated pillars (`pillar_decorated.glb`), rubble (`rubble_large.glb`), and 20 perimeter PBR boulders (`boulder_01.glb`, `arena_boulder.glb`) with physics colliders.
    - Dynamic corner/gateway omni lighting (warm/cool rim contrast) + secondary anime rim DirectionalLight.
  - Added Next-Gen Post-Processing & Anime Impact-Frame shader pipeline (`shaders/post_process_impact.gdshader` + `scripts/PostProcessController.gd`):
    - Black-and-white inverted anime Impact Frames on heavy hits (style 0), KJ "20 Series" crimson-black flash (style 1), and Weapon God cyan-white flash (style 2).
    - Radial anime speed-lines (double-frequency ray bursts) & dynamic chromatic aberration during dashes, wall-splats, and ultimates.
    - Hitstop controller using unscaled-delta recovery (`Engine.time_scale` freeze frames).
  - Implemented 120Hz Third-Person Battlegrounds Action Camera (`scripts/BattleCamera.gd`):
    - Smooth mouse orbit (captured cursor toggle via Right-Click / ESC), `Shift` or Middle-Mouse target Lock-On with camera yaw/pitch auto-tracking.
    - Dynamic FOV punch on dashes/impacts, 120Hz trauma-based camera shake + directional impact kicks.
    - Wall & pillar raycast collision avoidance with smooth pull-in/out interpolation.
  - Updated `scenes/Main.tscn` + `scripts/Main.gd` to integrate the arena, camera, post-FX, and Battle HUD:
    - `[WASD]` move fighter, `[E]` smash nearest wall (shows full wall -> cracked -> broken + debris showcase), `[F]` anime impact frame + hitstop + shake, `[Q]` dash speed-lines + FOV punch + debris burst, `[R]` repair all walls.
    - 2D projected lock-on reticle over locked target and live 120 FPS / frame-time / physics-tick HUD.
  - Verified headlessly with `Godot_v4.3-stable_win64_console.exe --headless --script test_step2.gd`: zero errors, 44 walls spawned, state machine + debris + camera + post-processing all functional.

- [ ] **Step 3: Core Battlegrounds Movement & 120Hz Physics Engine**
  - Implement `Q` Directional Dash (front dash punch, side-step, backflip), `F` Block & Perfect Parry, Active Ragdoll knockback, `Q` Ragdoll Evasive burst, Wall-splats, and physical ground crater rock debris.

- [ ] **Step 4: Fighter 1 — Hyun's Dojo ("Martial Legend" / KJ Moveset & VFX)**
  - Implement 4-hit M1 combo (with Uppercut & Downslam crater finishers), Skill 1 (*Swift Sweep*), Skill 2 (*Collateral Ruin*), Skill 3 (*Spiraling Storm*), and `G` Awakening (*20 Series / Unlimited*) with black-red lightning & anime impact frames.

- [ ] **Step 5: Fighter 2 — Combat Gods ("Weapon God" / Jun Moveset & VFX)**
  - Implement weapon-swapping M1 slashes (Katana + Spear/Staff), Skill 1 (*Flash Step Slash* teleport), Skill 2 (*Heaven Splitter*), Skill 3 (*Dragon Piercer* parry counter), and `G` Awakening (*God of Combat* dome slash ultimate).

- [ ] **Step 6: AI Opponent / Combo Dummy, Battlegrounds HUD & Character Select**
  - Add responsive AI fighter / practice dummy toggle, Awakening bar, animated skill cooldown cards (1, 2, 3, 4, G), combo/damage counter, character switcher (`Hyun's Dojo` vs `Combat Gods`), and synthesized/procedural impact audio.
