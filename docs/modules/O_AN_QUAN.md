# O_AN_QUAN

## Purpose

`O_AN_QUAN/` contains the O An Quan mini-game, including difficulty selection, gameplay board state, AI move logic, and end-of-match results.

## Related Docs

- [../architecture.md](../architecture.md): scene flow and `SceneManager` autoload responsibilities.
- [MAIN.md](MAIN.md): shared pause UI and hub-owned launch behavior.
- [../repo-hygiene.md](../repo-hygiene.md): shared pause scene guidance.
- [../runbooks/manual-smoke-test.md](../runbooks/manual-smoke-test.md): O An Quan smoke checks.

## What This Module Is Responsible For

- selecting AI difficulty before entering gameplay
- creating the 12-slot board state
- handling sow/capture logic
- updating scores and captured-piece displays
- choosing AI moves based on current difficulty
- displaying end-of-game results

## What This Module Is Not Responsible For

- launching itself from the hub
- storing persistent user settings
- backend API communication
- long-term save data

## Structure

- `scenes/SelectLevel.tscn`: difficulty select entry scene.
- `scripts/select_level.gd`: writes `SceneManager.ai_level` and transitions into gameplay.
- `scenes/main.tscn`: gameplay scene. Root node name is currently `main`.
- `scripts/game_manager.gd`: main gameplay controller.
- `scripts/SceneManager.gd`: autoload state for difficulty and result-scene values.
- `scripts/ai_player.gd`: AI search used by current gameplay flow.
- `scripts/ai_player_1.gd`, `ai_player_2.gd`, `ai_player_3.gd`: present in the repo but not the script preloaded by `game_manager.gd`.
- `scenes/BoardSlot.tscn` + `scripts/board_slot.gd`: board slot display and interaction.
- `scenes/CaptureSlot.tscn` + `scripts/CapturedSlot.gd`: captured-piece display.
- `scenes/EndGame.tscn` + `scripts/end_game.gd`: result scene.
- `scripts/fade_transition.gd`: fade-and-change-scene helper.

## Entry Points

- From the hub: `res://O_AN_QUAN/scenes/SelectLevel.tscn`
- Direct debug entry:
  - `O_AN_QUAN/scenes/SelectLevel.tscn`
  - `O_AN_QUAN/scenes/main.tscn`
  - `O_AN_QUAN/scenes/EndGame.tscn`

## Inputs And Outputs

### Inputs

- `SceneManager.ai_level` is set by `scripts/select_level.gd`
- `game_manager.gd` maps difficulty to `SceneManager.MAX_DEPTH`
  - `easy` -> `1`
  - `medium` -> `3`
  - `hard` -> `7`

### Outputs

- `SceneManager.player_score`
- `SceneManager.ai_score`
- scene transitions to:
  - `O_AN_QUAN/scenes/main.tscn`
  - `O_AN_QUAN/scenes/EndGame.tscn`
  - `O_AN_QUAN/scenes/SelectLevel.tscn`
  - shared quit path back to `MAIN/scenes/main.tscn` through pause UI

## Important Runtime Assumptions

### The gameplay scene root must stay `main`

`scripts/game_manager.gd` uses absolute node lookups such as:

- `/root/main/Board`
- `/root/main/CanvasLayer/DirectionPopup`

If you rename the gameplay scene root, update those paths everywhere before running.

### Board node names are part of the contract

The following node layout is currently coupled to code:

- `Board`
- `MainBoard`
- `DanSlot/Left`
- `DanSlot/Right`
- `CapturedSlotLeft`
- `CapturedSlotRight`
- `CanvasLayer/DirectionPopup`

### Shared pause UI is imported from `MAIN`

`O_AN_QUAN` scenes use the shared pause-menu scene from `MAIN/scenes/ui/game_control.tscn`.

## Common Workflows

### Change AI behavior

Read first:

- `scripts/game_manager.gd`
- `scripts/SceneManager.gd`
- `scripts/ai_player.gd`

Then re-test difficulty selection and first AI move timing.

### Change board layout or capture UI

Read first:

- `scenes/main.tscn`
- `scenes/BoardSlot.tscn`
- `scenes/CaptureSlot.tscn`
- `scripts/board_slot.gd`
- `scripts/CapturedSlot.gd`

Then re-test move input, capture animation, and score labels.

### Change result flow

Read first:

- `scripts/game_manager.gd`
- `scenes/EndGame.tscn`
- `scripts/end_game.gd`

Then re-test retry, back, and pause-to-hub paths.

## Artifacts

- runtime score state in `SceneManager`
- runtime board state in `game_manager.gd`
- audio and art assets under `O_AN_QUAN/assets/`

This module does not currently write persistent save data.

## Change Impact

- editing `SceneManager.gd` affects difficulty, AI depth, and endgame display
- editing `game_manager.gd` affects almost every gameplay path
- editing scene root or node names can break runtime immediately because of absolute node paths
- editing shared pause references can affect both O An Quan and other modules

## What To Test After Changes

1. Open `O_AN_QUAN/scenes/SelectLevel.tscn`.
2. Choose each difficulty you touched.
3. Confirm the gameplay board initializes.
4. Click one valid player slot and choose a direction.
5. Confirm scores and turn labels still update.
6. Open the pause menu with `Esc`.
7. Confirm retry or back flow still reaches the expected scene.
