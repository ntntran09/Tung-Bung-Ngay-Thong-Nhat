# Folk Games Collection

## What This Repo Is

`folk-games-collection` is a Godot project that bundles a festival-style hub with four mini-games:

- `CO_GANH`
- `NOI_CHU`
- `O_AN_QUAN`
- `TRON_TIM`

The runtime starts in `MAIN/scenes/start.tscn`, moves into the 3D hub in `MAIN/scenes/main.tscn`, and launches the mini-games from stall-owner interactions in the hub.

## Quick Start

1. Install Godot `4.6` or a compatible `4.x` build.
2. Import `project.godot` from the repo root.
3. Wait for Godot to finish asset import.
4. Run the project with `F5`.

For the full import workflow and common setup problems, see [docs/import-and-run-godot.md](docs/import-and-run-godot.md).

## Controls

- `WASD` or arrow keys: move
- `Shift`: run
- `E` or `Enter`: interact
- `Esc`: pause or close supported menus

## Repository Layout

- `MAIN/`: startup scene, hub world, player controller, dialogue systems, dialogue text files, and shared pause UI.
- `CO_GANH/`: Co Ganh board game module.
- `NOI_CHU/`: word-chain game module with HTTP backend dependency.
- `O_AN_QUAN/`: O An Quan board game with difficulty selection and AI settings.
- `TRON_TIM/`: multi-level stealth/avoidance module with unlock progression.
- `_SHARED ASSETS/`: shared font resources.
- `docs/`: architecture, contracts, runbooks, and module docs.

## Runtime Summary

- `project.godot` autoloads three singleton scripts:
  - `GameData` -> `MAIN/script/game_data.gd`
  - `SceneManager` -> `O_AN_QUAN/scripts/SceneManager.gd`
  - `Global` -> `TRON_TIM/scripts/Global.gd`
- Stall-owner dialogue in the hub launches mini-game scenes.
- Returning to the hub relies on a mix of shared pause UI and module-specific end scenes.
- Some hub NPC dialogue and all of `NOI_CHU` depend on the backend URL configured in `MAIN/script/game_data.gd`.

## Documentation Map

Use `docs/architecture.md` as the canonical runtime map, the contract docs as the canonical interface references, and `docs/runbooks/manual-smoke-test.md` as the current regression checklist.

- [docs/import-and-run-godot.md](docs/import-and-run-godot.md): import, run, and debug workflow.
- [docs/architecture.md](docs/architecture.md): scene flow, module boundaries, and autoload responsibilities.
- [docs/contracts/dialogue-and-scene-routing.md](docs/contracts/dialogue-and-scene-routing.md): dialogue file format and mini-game launch contract.
- [docs/contracts/external-api.md](docs/contracts/external-api.md): HTTP endpoints used by `MAIN` and `NOI_CHU`.
- [docs/runbooks/manual-smoke-test.md](docs/runbooks/manual-smoke-test.md): current regression checklist.
- [docs/modules/MAIN.md](docs/modules/MAIN.md): module guide for the hub and shared UI.
- [docs/modules/CO_GANH.md](docs/modules/CO_GANH.md): module guide for Co Ganh.
- [docs/modules/NOI_CHU.md](docs/modules/NOI_CHU.md): module guide for Noi Chu.
- [docs/modules/O_AN_QUAN.md](docs/modules/O_AN_QUAN.md): module guide for O An Quan.
- [docs/modules/TRON_TIM.md](docs/modules/TRON_TIM.md): module guide for Tron Tim.
- [docs/repo-hygiene.md](docs/repo-hygiene.md): generated files, exports, and commit hygiene.
- [AGENTS.md](AGENTS.md): coding-agent guide for safe changes.

## Known Constraints

- No automated tests or CI are visible in this repo.
- `NOI_CHU` and dynamic NPC dialogue in `MAIN` depend on a live HTTP backend.
- Some Godot resource headers still carry older path text even when the UID still resolves; see [docs/repo-hygiene.md](docs/repo-hygiene.md).
