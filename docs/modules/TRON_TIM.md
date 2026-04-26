# TRON_TIM

## Purpose

`TRON_TIM/` contains the Tron Tim mini-game: a level-select scene, three playable levels, enemy detection logic, win/lose routing, and in-session level unlocking.

## Related Docs

- [../architecture.md](../architecture.md): scene flow and `Global` autoload responsibilities.
- [MAIN.md](MAIN.md): shared pause UI and hub-owned launch behavior.
- [../runbooks/manual-smoke-test.md](../runbooks/manual-smoke-test.md): Tron Tim smoke checks.

## What This Module Is Responsible For

- level select UI
- loading level scenes
- per-level player and guard behavior
- countdown and win/lose logic
- unlocking the next level in the current app session
- routing to game-over and level-complete scenes

## What This Module Is Not Responsible For

- hub dialogue that launches the module
- backend API communication
- persistent save data
- shared pause-menu implementation

## Structure

- `scripts/Global.gd`: autoload for unlock state and level transitions.
- `scenes/level_select.tscn`: level-select entry scene.
- `scripts/level_select.gd`: enables/disables level buttons based on `Global`.
- `scenes/level_1.tscn`, `level_2.tscn`, `level_3.tscn`: playable levels.
- `scripts/level 1/*`, `scripts/level 2/*`, `scripts/level 3/*`: level-specific player, guard, and UI logic.
- `scripts/level_ui.gd`: shared timer and level-complete routing for level UI scripts.
- `scripts/top_down_player.gd`: shared player movement for levels 1 and 2.
- `scripts/vision_countdown_area.gd`: shared detection countdown area for levels 1 and 2.
- `scripts/countdown_label.gd`: shared countdown behavior used in levels 1 and 2.
- `scripts/level 3/countdown_label_lv3.gd`: level-3-specific countdown behavior.
- `scenes/level_completed.tscn` + `scripts/level_completed.gd`: level-complete scene.
- `scenes/gameover.tscn` + `scripts/gameover.gd`: failure scene.
- `scripts/player.gd`: free movement script used in the level-select scene.

## Entry Points

- From the hub: `res://TRON_TIM/scenes/level_select.tscn`
- Direct debug entry:
  - `TRON_TIM/scenes/level_select.tscn`
  - `TRON_TIM/scenes/level_1.tscn`
  - `TRON_TIM/scenes/level_2.tscn`
  - `TRON_TIM/scenes/level_3.tscn`

## Inputs And Outputs

### Inputs

- `Global.unlocked_levels`
- `Global.current_level_num`
- per-level scene node wiring for:
  - player
  - guard vision area
  - countdown label
  - waypoints

### Outputs

- scene transitions to:
  - `TRON_TIM/scenes/level_%d.tscn`
  - `TRON_TIM/scenes/level_completed.tscn`
  - `TRON_TIM/scenes/gameover.tscn`
  - `MAIN/scenes/main.tscn` via shared pause UI

## Important Runtime Assumptions

### Unlock state is session-only

`Global.gd` initializes:

```gdscript
var unlocked_levels := [1]
```

There is no visible persistence layer. Restarting the application resets progression unless the code is changed deliberately.

### Level file naming is part of the contract

`Global.load_level(level_num)` uses:

```gdscript
get_tree().change_scene_to_file("res://TRON_TIM/scenes/level_%d.tscn" % level_num)
```

If you rename level files, update that pattern and all callers.

### Level UI scripts must report completion through `Global`

The level UI scripts assign:

- `Global.current_level = self`
- `Global.current_level_num = <level>`
- `on_level_win = Global._on_level_win`

That wiring is how win state unlocks the next level and routes to `level_completed.tscn`.

### Guard scripts depend on stable node paths

The level scenes wire together guard, player, waypoint, and countdown nodes using fixed paths. Small scene-tree changes can break the level scripts even when the art still looks correct.

## Common Workflows

### Change level unlock behavior

Read first:

- `scripts/Global.gd`
- `scripts/level_select.gd`
- `scripts/level 1/ui.gd`
- `scripts/level 2/ui_2.gd`
- `scripts/level 3/ui 3.gd`

Then re-test level-complete routing and unlocked buttons in the same session.

### Change player movement or detection

Read first:

- level-specific player scripts
- level-specific guard scripts
- vision-area scripts

Then re-test movement, collision, and both game-over and win paths.

### Change pause or quit flow

Tron Tim level-select and playable level scenes instance `MAIN/scenes/ui/game_control.tscn` for the shared pause menu. Keep that packed-scene reference instead of embedding `MAIN/script/game_control.gd` and pause assets directly.

Re-test:

- `TRON_TIM/scenes/level_select.tscn`
- at least one playable level

## Artifacts

- runtime unlock state in `Global`
- level scene state
- shared pause UI imported from `MAIN`

No persistent progression artifacts are currently written.

## Change Impact

- editing `Global.gd` affects the whole Tron Tim module
- editing level scene names affects loading immediately
- editing UI scripts affects unlock routing and timers
- editing guard node structure can break vision and fail states
- editing shared pause UI can affect both level-select and level scenes

## What To Test After Changes

1. Open `TRON_TIM/scenes/level_select.tscn`.
2. Confirm level 1 is available on a fresh session.
3. Start level 1 and verify movement works.
4. Confirm countdown UI updates.
5. Trigger either a win or a fail path for the level you changed.
6. Confirm `level_completed.tscn` or `gameover.tscn` appears as expected.
7. Return to level select and verify unlock state.
8. Restart the app if your change touches progression assumptions.
