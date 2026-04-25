# Import And Run In Godot

## Scope

This document explains how to import the repo into Godot, run the full game, and debug individual scenes safely.

## Requirements

- Godot `4.6` is the declared target in `project.godot`
- a local clone of this repo

## Import The Project

1. Open the Godot Project Manager.
2. Choose `Import`.
3. Select the repo-root `project.godot`.
4. Choose `Import & Edit`.
5. Wait for Godot to finish importing assets and rebuilding `.godot/`.

## Current Project Settings In Source Control

As of the current repo state:

- main scene in `project.godot` points to `MAIN/scenes/start.tscn` by UID
- autoloads are:
  - `GameData` -> `res://MAIN/script/game_data.gd`
  - `SceneManager` -> `res://O_AN_QUAN/scripts/SceneManager.gd`
  - `Global` -> `res://TRON_TIM/scripts/Global.gd`
- the input map includes:
  - `walk_up`
  - `walk_down`
  - `walk_left`
  - `walk_right`
  - `run`
  - `interact`

The repo also contains Web export presets in `export_presets.cfg`, including an explicit include filter for `MAIN/dialogues/*.txt`.

For generated-file and export-output guidance, see [repo-hygiene.md](repo-hygiene.md).

## Run The Full Project

1. Open the imported project in Godot.
2. Press `F5` or choose `Run Project`.
3. Confirm the project opens `MAIN/scenes/start.tscn`.
4. Press any key to enter the hub in `MAIN/scenes/main.tscn`.

## Common Controls

- `WASD` or arrow keys: move
- `Shift`: run
- `E` or `Enter`: interact
- `Esc`: pause or close supported menus

## Run Individual Scenes For Debugging

Use `F6` on a scene if you want to debug one part of the repo without playing the full intro path.

Useful direct-entry scenes:

- `MAIN/scenes/start.tscn`
- `MAIN/scenes/main.tscn`
- `CO_GANH/scenes/main.tscn`
- `NOI_CHU/scenes/main.tscn`
- `O_AN_QUAN/scenes/SelectLevel.tscn`
- `O_AN_QUAN/scenes/main.tscn`
- `TRON_TIM/scenes/level_select.tscn`
- `TRON_TIM/scenes/level_1.tscn`
- `TRON_TIM/scenes/level_2.tscn`
- `TRON_TIM/scenes/level_3.tscn`

## Common Problems

### Missing singleton errors

Symptoms:

- `GameData` not declared
- `SceneManager` not declared
- `Global` not declared

Fix:

1. Open `Project > Project Settings > Autoload`.
2. Recreate the three autoloads listed above if they are missing.
3. Save and reopen the project if needed.

### Input actions do not work

Symptoms:

- player cannot move
- interaction keys do nothing

Fix:

1. Open `Project > Project Settings > Input Map`.
2. Confirm the action names listed above exist.
3. Re-add the missing keys if needed.

### Pink textures or broken imports

Fix:

1. Close Godot.
2. Delete the local `.godot/` folder.
3. Reopen the project and let Godot import again.

### API-dependent features fail

Affected areas:

- roaming NPC dialogue in the hub
- `NOI_CHU`

Fix:

- verify the backend URL in `MAIN/script/game_data.gd`
- confirm the backend is reachable
- if the backend is intentionally offline, verify the game fails gracefully instead of hard-crashing

## Recommended Quick Sanity Check After Import

1. Run the full project.
2. Enter the hub.
3. Move the player.
4. Talk to one stall owner.
5. Launch one mini-game.
6. Return to the hub.

For the full regression checklist, see [runbooks/manual-smoke-test.md](runbooks/manual-smoke-test.md).

## Maintenance Note

Update this document when any of these change:

- the configured main scene
- autoload names or paths
- input action names
- import-sensitive project settings
- export filters that include gameplay content such as dialogue text files
