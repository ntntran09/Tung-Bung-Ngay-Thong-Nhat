# Architecture

## Purpose

This document explains how the repo is wired at runtime so scene changes, dialogue edits, and module work can happen without accidental breakage.

This is the canonical runtime map. Use the contract docs for interface details and the module docs for change-specific workflows.

## Related Docs

- [contracts/dialogue-and-scene-routing.md](contracts/dialogue-and-scene-routing.md): hub dialogue file format, scene launch bindings, and return-position behavior.
- [contracts/external-api.md](contracts/external-api.md): HTTP endpoints consumed by `MAIN` and `NOI_CHU`.
- [modules/MAIN.md](modules/MAIN.md): startup, hub, dialogue, NPCs, and shared UI.
- [modules/CO_GANH.md](modules/CO_GANH.md): Co Ganh module guide.
- [modules/NOI_CHU.md](modules/NOI_CHU.md): Noi Chu module guide.
- [modules/O_AN_QUAN.md](modules/O_AN_QUAN.md): O An Quan module guide.
- [modules/TRON_TIM.md](modules/TRON_TIM.md): Tron Tim module guide.
- [runbooks/manual-smoke-test.md](runbooks/manual-smoke-test.md): manual regression checklist.
- [repo-hygiene.md](repo-hygiene.md): generated files, stale resource path text, and commit hygiene.

## System Summary

This is a Godot `4.6` project with:

- a startup scene in `MAIN/scenes/start.tscn`
- a hub world in `MAIN/scenes/main.tscn`
- four mini-game modules launched from hub interactions
- three autoload singletons that carry cross-scene state

## Startup And Scene Flow

```text
project.godot
  -> main scene: MAIN/scenes/start.tscn
      -> on any input: MAIN/scenes/main.tscn
          -> stall-owner dialogue
              -> CO_GANH/scenes/main.tscn
              -> NOI_CHU/scenes/main.tscn
              -> O_AN_QUAN/scenes/SelectLevel.tscn
                  -> O_AN_QUAN/scenes/main.tscn
                  -> O_AN_QUAN/scenes/EndGame.tscn
              -> TRON_TIM/scenes/level_select.tscn
                  -> TRON_TIM/scenes/level_1.tscn
                  -> TRON_TIM/scenes/level_2.tscn
                  -> TRON_TIM/scenes/level_3.tscn
                  -> TRON_TIM/scenes/level_completed.tscn
                  -> TRON_TIM/scenes/gameover.tscn
          -> roaming hub NPC dialogue
              -> HTTP backend via GameData.api_url
```

## Module Boundaries

### `MAIN/`

Responsibilities:

- startup flow
- 3D hub world
- player movement and skin selection
- stall-owner dialogue that launches mini-games
- roaming NPC dialogue
- shared pause UI used by other modules
- dialogue text files in `MAIN/dialogues/`

Non-responsibilities:

- mini-game rule logic
- O An Quan score state
- Tron Tim progression state

Important files:

- `MAIN/scenes/start.tscn`
- `MAIN/scenes/main.tscn`
- `MAIN/script/start.gd`
- `MAIN/script/dialogue_panel.gd`
- `MAIN/script/dialogue_panel_npc.gd`
- `MAIN/script/stall_owner.gd`
- `MAIN/script/npc.gd`
- `MAIN/script/game_data.gd`
- `MAIN/script/game_control.gd`
- `MAIN/scenes/ui/game_control.tscn`

### `CO_GANH/`

Responsibilities:

- board creation
- move rules
- bot selection and turn logic
- win/loss UI

This module is comparatively self-contained. Its main outward contract is how it is launched from the hub and how it returns to the hub.

### `NOI_CHU/`

Responsibilities:

- word-chain UI
- score and timer handling
- game-over scene
- backend-driven word generation and validation

This module is the most backend-dependent gameplay path in the repo.

### `O_AN_QUAN/`

Responsibilities:

- difficulty selection
- board setup
- sow/capture rules
- AI move search
- endgame scene and result display

Shared state is kept in the `SceneManager` autoload.

### `TRON_TIM/`

Responsibilities:

- level select
- per-level player and enemy logic
- unlock progression
- game-over and level-complete flows

Shared state is kept in the `Global` autoload and is not persisted to disk.

## Autoload Responsibilities

### `GameData`

File: `MAIN/script/game_data.gd`

Used for:

- selected player skin
- whether dialogue is open
- dialogue cooldown
- saved hub player position
- backend base URL

Impact:

- breaking this singleton affects hub dialogue, player return position, and backend-dependent features.

### `SceneManager`

File: `O_AN_QUAN/scripts/SceneManager.gd`

Used for:

- selected O An Quan difficulty
- AI depth value
- result-scene scores
- scene transitions for fade helper

Impact:

- breaking this singleton affects the O An Quan select-level -> gameplay -> result flow.

### `Global`

File: `TRON_TIM/scripts/Global.gd`

Used for:

- unlocked Tron Tim levels
- current level number
- level loading
- level-complete routing

Impact:

- breaking this singleton affects the entire Tron Tim progression loop.

## Runtime Boundaries

### Local Godot runtime

Most scene loading, board logic, movement, and audio are local-only.

### External HTTP backend

The backend base URL lives in `MAIN/script/game_data.gd`.

The expected client-side API shape is documented in [contracts/external-api.md](contracts/external-api.md).

Current consumers:

- roaming hub NPCs in `MAIN/script/npc.gd`
- `NOI_CHU/scripts/GameNoiTu.gd`

That means the repo has both local-only gameplay paths and backend-dependent gameplay paths.

## Artifact Flow

### Text content

- `MAIN/dialogues/*.txt` drive hub dialogue and mini-game launch prompts; see [contracts/dialogue-and-scene-routing.md](contracts/dialogue-and-scene-routing.md).
- Web export explicitly includes `MAIN/dialogues/*.txt` in `export_presets.cfg`.

### Scene state

- `GameData.player_position` stores where the hub player should reappear after returning from a mini-game.
- `SceneManager` stores O An Quan difficulty and endgame score display state.
- `Global` stores Tron Tim unlock state for the current app session.

### Shared UI and resources

- `_SHARED ASSETS/font/*.tres` are reused across modules.
- The shared pause implementation lives in `MAIN/script/game_control.gd` and `MAIN/scenes/ui/game_control.tscn`.
- `NOI_CHU` uses `MAIN/scenes/ui/game_control.tscn` directly, `O_AN_QUAN` uses the same scene by UID with stale path text in scene headers, and `CO_GANH` plus `TRON_TIM` embed the same pause script and assets directly in their scenes.

## Current Limitations And Risks

- No automated tests are visible; verification is manual.
- Backend-dependent behavior has no documented environment switch or retry strategy.
- Scene-template defaults are not always authoritative; parent-scene instance overrides often define the real behavior.
- Some scene resources still contain stale path text even when UIDs still resolve.
- The repo tracks multiple `*.tmp` Godot scene backups, which are not reliable sources of truth.

## Change Impact Notes

### If you change `project.godot`

Re-test startup, autoloads, input actions, and import behavior.

### If you change `MAIN/dialogues/`

Re-test hub dialogue, choice flow, and mini-game launch/return behavior.

### If you change autoload singletons

Re-test every feature that crosses scene boundaries.

### If you change shared pause UI

Re-test `NOI_CHU`, `O_AN_QUAN`, and `TRON_TIM`.

### If you change `O_AN_QUAN/scenes/main.tscn`

Preserve node names expected by absolute paths in `game_manager.gd`.

### If you change `TRON_TIM` level naming or UI wiring

Preserve `Global.load_level()` compatibility and the level-complete callback flow.
