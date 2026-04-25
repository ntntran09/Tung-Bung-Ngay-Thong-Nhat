# MAIN

## Purpose

`MAIN/` owns the startup path, the 3D hub world, player control, hub dialogue, hub NPCs, and shared UI used by the mini-games.

This is the most important module for cross-module behavior because all mini-games are launched from here.

## Related Docs

- [../architecture.md](../architecture.md): overall runtime flow and autoload responsibilities.
- [../contracts/dialogue-and-scene-routing.md](../contracts/dialogue-and-scene-routing.md): hub dialogue and scene launch contract.
- [../contracts/external-api.md](../contracts/external-api.md): backend contract for roaming NPC dialogue.
- [../runbooks/manual-smoke-test.md](../runbooks/manual-smoke-test.md): hub and launch regression checks.

## What This Module Is Responsible For

- start screen to hub transition
- hub scene and navigation area
- player movement, camera, and skin selection
- stall-owner dialogue that launches mini-games
- roaming NPC dialogue
- shared pause UI for mini-games
- dialogue text files under `MAIN/dialogues/`
- shared hub assets and UI themes

## What This Module Is Not Responsible For

- mini-game rule logic
- O An Quan AI state
- Tron Tim level progression state
- backend implementation

## Structure

- `scenes/start.tscn`: configured runtime entry scene.
- `script/start.gd`: moves from start scene to `MAIN/scenes/main.tscn` on any input.
- `scenes/main.tscn`: main 3D hub scene.
- `scenes/Characters/`: player, stall-owner, and NPC scenes.
- `scenes/ui/control.tscn`: hub pause/settings UI.
- `scenes/ui/game_control.tscn`: canonical packed-scene version of the shared mini-game pause menu.
- `scenes/ui/dialogue_panel.tscn`: stall-owner dialogue panel.
- `scenes/ui/dialogue_panel_npc.tscn`: roaming NPC dialogue panel.
- `script/game_data.gd`: `GameData` autoload.
- `script/character_body_3d.gd`: hub player controller.
- `script/game_control.gd`: shared pause-menu logic reused across modules.
- `script/dialogue_panel.gd`: stall-owner dialogue behavior and scene launches.
- `script/dialogue_panel_npc.gd`: roaming NPC dialogue behavior.
- `script/stall_owner.gd`: player proximity and interaction for stall owners.
- `script/npc.gd`: roaming NPC patrol and backend-generated dialogue.
- `dialogues/`: hub dialogue and NPC background text.

## Entry Points

- full project entry: `MAIN/scenes/start.tscn`
- hub debug entry: `MAIN/scenes/main.tscn`
- alternate or older hub view: `MAIN/scenes/view_from_top.tscn`

`project.godot` points at `MAIN/scenes/start.tscn` by UID.

## Inputs And Outputs

### Inputs

- input actions from `project.godot`
- dialogue files in `MAIN/dialogues/`
- stall-owner scene properties:
  - `input_file`
  - `target_scene_path`
- roaming NPC scene properties:
  - `input_file`
  - `npc_name`
  - `patrol_parent_path`
- backend base URL from `GameData.api_url`

### Outputs

- scene changes to the mini-game entry scenes
- saved hub return position in `GameData.player_position`
- selected player skin in `GameData.selected_skin_index`
- backend requests for roaming NPC dialogue

## Important Runtime Assumptions

### The player must be in the `player` group

`MAIN/script/character_body_3d.gd` adds itself to the `player` group. Dialogue scripts find the player through that group and toggle `can_move`.

### Stall-owner scene instances carry real launch data

The reusable stall-owner scenes are templates. The hub scene instance values in `MAIN/scenes/main.tscn` are the practical source of truth for which dialogue file and target scene are used.

### Roaming NPC scene defaults may be stale

Some reusable NPC scene defaults are missing or placeholder values. Check `MAIN/scenes/main.tscn` when debugging actual hub behavior.

### Hub dialogue and backend dialogue share state

Both systems use:

- `GameData.is_dialogue_open`
- `GameData.dialogue_cooldown`

Changing those flags affects both stall owners and roaming NPCs.

## Common Workflows

### Add or change a mini-game launch point

Read first:

- `scenes/main.tscn`
- `script/stall_owner.gd`
- `script/dialogue_panel.gd`
- `docs/contracts/dialogue-and-scene-routing.md`

Then update:

- dialogue file in `dialogues/`
- `input_file` on the stall-owner instance
- `target_scene_path` on that stall-owner's dialogue panel

### Change player movement or skins

Read first:

- `script/character_body_3d.gd`
- `script/control.gd`
- `script/game_data.gd`
- `scenes/Characters/character.tscn`
- `scenes/ui/control.tscn`

Then re-test movement, run, mouse capture, skin preview, and hub pause menu.

### Change roaming NPC behavior

Read first:

- `script/npc.gd`
- `script/dialogue_panel_npc.gd`
- `docs/contracts/external-api.md`

Then re-test patrol, interaction, backend response, fallback behavior, and movement unlock.

## Artifacts

- dialogue text under `MAIN/dialogues/`
- shared runtime state in `GameData`
- local Godot import metadata for assets

This module does not write persistent save files.

## Change Impact

- editing `game_data.gd` can affect every module through autoload state
- editing dialogue panel scripts can break mini-game launch flow
- editing player group setup can break dialogue movement locks and return-position restore
- editing or moving shared pause UI can affect `CO_GANH`, `NOI_CHU`, `O_AN_QUAN`, and `TRON_TIM`

## What To Test After Changes

1. Run the full project from `MAIN/scenes/start.tscn`.
2. Enter the hub.
3. Move, run, and interact.
4. Open and close the hub pause/settings UI.
5. Talk to one stall owner and launch a mini-game.
6. Return to the hub.
7. Talk to one roaming NPC.
