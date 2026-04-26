# Technical Debt Refactor

## Purpose

This document records the broad technical-debt refactor that introduced shared configuration, route constants, HTTP helpers, validation, and module cleanup across the Folk Games Collection project.

It is intended for maintainers reviewing the refactor, future agents continuing the cleanup, and anyone debugging behavior that crosses scene boundaries.

## Scope

The refactor touched these areas:

- project-level configuration and autoloads
- backend URL and JSON API request handling
- hub dialogue and scene routing
- shared pause UI usage
- O An Quan node references and AI script consolidation
- Tron Tim shared scripts and pause scene normalization
- Co Ganh cleanup and debug logging
- repo hygiene for Godot temporary files
- documentation and validation preflight coverage

## Non-Goals

The refactor intentionally did not add:

- new gameplay rules
- persistence for Tron Tim progression
- a new offline mode for API-dependent paths
- a backend implementation
- a complete automated gameplay test suite

The goal was to keep current behavior equivalent while removing basic structural debt.

## Project-Level Helpers

### `AppConfig`

File: `MAIN/script/app_config.gd`

`AppConfig` centralizes settings that were previously hard-coded or scattered:

- `application/config/backend_base_url`
- `application/config/api_timeout_seconds`
- `application/config/debug_logging`

The default backend URL in `project.godot` is now empty:

```ini
config/backend_base_url=""
config/api_timeout_seconds=8.0
config/debug_logging=false
```

This prevents temporary tunnel, proxy, or Daytona URLs from being committed in source. API-dependent features must be configured per environment before normal play.

### `SceneRoutes`

File: `MAIN/script/scene_routes.gd`

`SceneRoutes` provides canonical paths for shared scene transitions:

- startup and hub scenes
- every mini-game entry scene
- Noi Chu game-over scene
- O An Quan select, main, and end-game scenes
- Tron Tim level select, game-over, level-complete, and level pattern

It also provides:

- `tron_tim_level(level_num)`
- `is_valid_scene(path)`
- `change_to(path, tree)`

Use these constants in scripts instead of repeating string paths.

### `DebugLog`

File: `MAIN/script/debug_log.gd`

`DebugLog` gates diagnostic output behind `AppConfig.is_debug_logging_enabled()`.

The only remaining intentional `print()` calls should live inside `DebugLog`. Gameplay scripts should call:

```gdscript
DebugLog.info("message")
DebugLog.value("message:", value)
```

## API Refactor

### Shared JSON Client

File: `MAIN/script/json_api_client.gd`

`JsonApiClient` wraps a scene-owned `HTTPRequest` node and standardizes:

- backend base URL lookup
- timeout assignment from `AppConfig`
- GET for empty request bodies
- POST with JSON for non-empty request bodies
- non-200 handling
- invalid JSON handling
- missing backend configuration
- single in-flight request protection

Callback shape:

```gdscript
{
	"ok": bool,
	"code": int,
	"data": Dictionary,
	"error": String,
}
```

### Current Consumers

`MAIN/script/npc.gd` now uses `JsonApiClient` for `/npc/npc_intro`.

Failure behavior:

- backend failure logs through `DebugLog`
- NPC text falls back to a local generic greeting
- gameplay should not hard-crash only because generated NPC text is unavailable

`NOI_CHU/scripts/GameNoiTu.gd` now uses `JsonApiClient` for:

- `/game/start`
- `/game/new_word`
- `/word/validate`
- `/ask`

Failure behavior:

- missing config, non-200, invalid JSON, or missing required fields route into the in-game error/game-over path
- no offline gameplay mode was added

See `docs/contracts/external-api.md` for the endpoint contract.

## Dialogue And Scene Routing

### Dialogue File Contract

`MAIN/script/dialogue_panel.gd` now validates that dialogue files have a non-empty first line. The first line remains the title or speaker name.

This protects the existing contract:

- line 1: title
- remaining lines: dialogue body
- end of body: `No`, `Again`, `Yes` choices

### Target Scene Validation

`target_scene_path` now defaults to an empty string in `MAIN/script/dialogue_panel.gd`.

Before launching a mini-game, the panel checks:

```gdscript
SceneRoutes.is_valid_scene(target_scene_path)
```

If the route is invalid, the scene change is blocked and a Godot error is pushed.

### Route Replacements

Hard-coded scene transitions were replaced with `SceneRoutes` in:

- `MAIN/script/start.gd`
- `MAIN/script/game_control.gd`
- `NOI_CHU/scripts/GameOver.gd`
- `O_AN_QUAN/scripts/select_level.gd`
- `O_AN_QUAN/scripts/end_game.gd`
- `O_AN_QUAN/scripts/SceneManager.gd`
- `TRON_TIM/scripts/Global.gd`
- `TRON_TIM/scripts/gameover.gd`
- `TRON_TIM/scripts/level_completed.gd`
- selected Tron Tim level-3 scripts
- `CO_GANH/scripts/board.gd`

## Shared Pause UI

Canonical packed scene:

- `MAIN/scenes/ui/game_control.tscn`

Canonical script:

- `MAIN/script/game_control.gd`

The refactor standardized mini-game scenes toward packed-scene usage instead of copying the pause menu structure, script, texture, theme, and stylebox resources into each scene.

Current direct users include:

- `CO_GANH/scenes/main.tscn`
- `NOI_CHU/scenes/main.tscn`
- `O_AN_QUAN/scenes/main.tscn`
- `O_AN_QUAN/scenes/SelectLevel.tscn`
- `TRON_TIM/scenes/level_select.tscn`
- `TRON_TIM/scenes/level_1.tscn`
- `TRON_TIM/scenes/level_2.tscn`
- `TRON_TIM/scenes/level_3.tscn`

When changing pause behavior, edit the packed scene or `MAIN/script/game_control.gd`, then retest every mini-game that instances it.

## O An Quan Refactor

### Node References

File: `O_AN_QUAN/scripts/game_manager.gd`

The gameplay manager no longer uses `/root/main/...` lookups. It now resolves board, popup, label, and captured-slot nodes relative to the `GameManager` node.

The scene tree still has a node-name contract. These paths remain important:

- `../Board`
- `../CanvasLayer/DirectionPopup`
- `../CanvasLayer/PlayerScore`
- `../CanvasLayer/AIScore`
- `../CapturedSlotLeft`
- `../CapturedSlotRight`

If the scene tree changes, update both the scene and the relative references.

### AI Consolidation

File: `O_AN_QUAN/scripts/ai_player.gd`

The previous duplicated AI scripts were removed:

- `O_AN_QUAN/scripts/ai_player_1.gd`
- `O_AN_QUAN/scripts/ai_player_2.gd`
- `O_AN_QUAN/scripts/ai_player_3.gd`

`ai_player.gd` now accepts depth through:

```gdscript
AIPlayer.set_max_depth(SceneManager.MAX_DEPTH)
```

Difficulty selection remains owned by `SceneManager`:

- `easy` -> depth `1`
- `medium` -> depth `3`
- `hard` -> depth `7`

## Tron Tim Refactor

### Shared Scripts

New shared scripts:

- `TRON_TIM/scripts/level_ui.gd`
- `TRON_TIM/scripts/top_down_player.gd`
- `TRON_TIM/scripts/vision_countdown_area.gd`

Level wrappers now extend shared scripts for repeated behavior:

- `TRON_TIM/scripts/level 1/ui.gd`
- `TRON_TIM/scripts/level 2/ui_2.gd`
- `TRON_TIM/scripts/level 3/ui 3.gd`
- `TRON_TIM/scripts/level 1/player_walk.gd`
- `TRON_TIM/scripts/level 2/player_2.gd`
- `TRON_TIM/scripts/level 1/vision_area.gd`
- `TRON_TIM/scripts/level 2/vision_area2.gd`

Level 3 keeps more specialized guard/player behavior because its detection and countdown rules differ.

### Route Cleanup

`TRON_TIM/scripts/Global.gd` now loads levels through `SceneRoutes.tron_tim_level(level_num)`.

Failure and level-complete scripts now route through `SceneRoutes` instead of repeating scene paths.

### Pause Scene Normalization

The Tron Tim level-select and playable scenes now instance:

```text
res://MAIN/scenes/ui/game_control.tscn
```

They no longer embed the pause script, pause icon, pause background, theme, or hover stylebox directly.

## Co Ganh Refactor

File: `CO_GANH/scripts/board.gd`

Changes:

- bot avatar paths moved to constants
- bot display names moved to constants
- duplicate reset cleanup moved into `_clear_board_runtime_state()`
- return-to-hub path uses `SceneRoutes.MAIN_HUB`
- debug prints use `DebugLog`

File: `CO_GANH/scripts/bot_select_layer.gd`

Changes:

- bot selection debug output uses `DebugLog`

Removed unused empty script:

- `CO_GANH/scripts/botselect.gd`

## Repo Hygiene

`.gitignore` now ignores:

```gitignore
*.tmp
```

Tracked Godot temporary scene backup files were removed. These files are editor artifacts and should not be used as source of truth.

New scripts include matching `.gd.uid` files so Godot resource identity stays stable across machines.

The refactor intentionally did not delete tracked `.import` files or unrelated `.uid` files.

## Validation Script

File: `tools/validate_project.gd`

The script checks:

- required autoloads exist
- `SceneRoutes` autoload is available
- canonical route constants point to loadable scenes
- Tron Tim level pattern resolves levels 1 to 3
- non-empty `target_scene_path` values in `.tscn` files are valid scenes
- dialogue files have non-empty first title lines
- `.gd` scripts do not contain hard-coded backend URLs

Run it with:

```powershell
& 'D:\Code\HCMUS\Godot_v4.6.2\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\Code\HCMUS\folk-games-collection' --script 'res://tools/validate_project.gd'
```

## Documentation Updated

The refactor also updated:

- `README.md`
- `AGENTS.md`
- `docs/architecture.md`
- `docs/contracts/dialogue-and-scene-routing.md`
- `docs/contracts/external-api.md`
- `docs/modules/MAIN.md`
- `docs/modules/NOI_CHU.md`
- `docs/modules/O_AN_QUAN.md`
- `docs/modules/TRON_TIM.md`
- `docs/modules/CO_GANH.md`
- `docs/repo-hygiene.md`
- `docs/runbooks/manual-smoke-test.md`

## Change Impact Summary

| Area | Main impact | Retest focus |
| --- | --- | --- |
| `project.godot` | new autoloads and config keys | startup, autoload availability |
| `MAIN` dialogue | validated title line and target scene path | stall-owner choices, hub return |
| API consumers | shared request behavior and config-driven backend | NPC fallback, Noi Chu API paths |
| Shared pause UI | packed scene is canonical | pause and quit in all mini-games |
| O An Quan | relative node refs and AI consolidation | difficulty select, first move, AI response |
| Tron Tim | shared scripts and packed pause scene | level select, level 1 movement, game-over/win paths |
| Co Ganh | reset cleanup and constants | bot select, first move, replay/return |
| Repo hygiene | `.tmp` ignored and removed | no generated backups in worktree |

## Known Remaining Risks

- Manual gameplay smoke still matters because the repo does not have a full automated gameplay suite.
- API-dependent play still needs a real backend configured through `application/config/backend_base_url`.
- Godot headless quit still reports the known resource/leak warning seen before this refactor.
- Web export requires Godot Web export templates installed for `4.6.2.stable`.
