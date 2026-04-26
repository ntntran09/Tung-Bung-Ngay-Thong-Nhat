# Dialogue And Scene Routing Contract

## Purpose

This document is the canonical source for how hub dialogue text, scene instance properties, and shared state work together to launch mini-games and restore the player to the hub.

## Canonical Files

- `MAIN/dialogues/*.txt`
- `MAIN/script/stall_owner.gd`
- `MAIN/script/dialogue_panel.gd`
- `MAIN/script/npc.gd`
- `MAIN/script/dialogue_panel_npc.gd`
- `MAIN/script/game_data.gd`
- `MAIN/scenes/main.tscn`
- `MAIN/scenes/Characters/*.tscn`

## Related Docs

- [../architecture.md](../architecture.md): runtime scene flow and module boundaries.
- [../modules/MAIN.md](../modules/MAIN.md): hub module workflows and assumptions.
- [../runbooks/manual-smoke-test.md](../runbooks/manual-smoke-test.md): regression checks for dialogue and launch flow.
- [external-api.md](external-api.md): backend contract for roaming NPC dialogue.

## Contract Summary

The hub uses two related but different dialogue systems:

1. Stall-owner dialogue for launching mini-games.
2. Roaming NPC dialogue for backend-generated text.

Both systems depend on scene properties and singleton state, not just script logic.

## Stall-Owner Dialogue Contract

### Upstream inputs

- `input_file` exported property on the stall-owner scene instance
- file contents in `MAIN/dialogues/<input_file>`
- `target_scene_path` exported property on the `DialoguePanel` node

### Current hub bindings

| Hub scene instance | Dialogue file | Target scene |
| --- | --- | --- |
| stall owner for Co Ganh | `co_ganh.txt` | `res://CO_GANH/scenes/main.tscn` |
| stall owner for Noi Chu | `noi_chu.txt` | `res://NOI_CHU/scenes/main.tscn` |
| stall owner for O An Quan | `o_an_q.txt` | `res://O_AN_QUAN/scenes/SelectLevel.tscn` |
| stall owner for Tron Tim | `tron_tim.txt` | `res://TRON_TIM/scenes/level_select.tscn` |

The current source of truth for these bindings is the instantiated hub scene `MAIN/scenes/main.tscn`, not just the reusable character scenes under `MAIN/scenes/Characters/`.

### Dialogue file format

`MAIN/script/dialogue_panel.gd` treats the file as:

- line 1: dialogue title or speaker name
- remaining lines: dialogue body, advanced one line at a time

When the body is exhausted, the dialogue switches to a three-choice UI:

- `Yes`: save player position and change to `target_scene_path`
- `Again`: restart the same dialogue from the beginning
- `No`: close the dialogue

### Scene-return behavior

Before a `Yes` transition, `MAIN/script/dialogue_panel.gd` saves:

- `GameData.player_position = player.global_position`

When the hub loads again, `dialogue_panel.gd` restores the first node in the `player` group to `GameData.player_position`.

This means mini-game return flow is partly owned by shared state, not just by the mini-game scene.

## Roaming NPC Dialogue Contract

### Upstream inputs

- `input_file` exported property on the NPC scene instance
- `npc_name` exported property on the NPC scene instance
- `MAIN/dialogues/<input_file>`
- backend base URL from `AppConfig.backend_base_url()`

### Current hub bindings

Observed in `MAIN/scenes/main.tscn`:

| Hub scene instance | Effective dialogue file | Effective name |
| --- | --- | --- |
| `Npc` | `mo.txt` | `Mo` |
| `Npc2` | `tu.txt` | `Tu` |
| `Npc3` | inherited from reusable scene default `lan_chi.txt` | `Lan Chi` |
| `Npc4` | `khai.txt` | `Khai` |

### Important note on scene defaults

Reusable NPC scene defaults are not consistently trustworthy:

- `MAIN/scenes/Characters/npc.tscn` has no default `input_file`.
- `MAIN/scenes/Characters/npc_1.tscn` defaults to `npc_nam.txt`, but the hub scene overrides it to `tu.txt`.
- `MAIN/scenes/Characters/npc_3.tscn` defaults to `.txt`, but the hub scene overrides it to `khai.txt`.

When debugging hub behavior, trust the instance values in `MAIN/scenes/main.tscn` first.

### NPC dialogue generation flow

`MAIN/script/npc.gd`:

1. Builds `dialogue_file_path = "res://MAIN/dialogues/" + input_file`
2. Opens that file
3. Calls `/npc/npc_intro`
4. On success, builds a string like:
   - first line: `npc_name`
   - remaining text: backend reply
5. Passes the text to `dialogue_panel_npc.gd`

`dialogue_panel_npc.gd` expects newline-separated text and uses:

- line 1 as the title
- remaining lines as the dialogue body

It also starts an auto-close timer and unlocks player movement when the panel finishes.

## Shared State Contract

### `GameData.is_dialogue_open`

Prevents overlapping dialogue systems from running at once.

### `GameData.dialogue_cooldown`

Used by both stall owners and roaming NPCs to avoid immediate re-triggering.

### `GameData.player_position`

Used only for hub return placement after leaving via stall-owner dialogue.

## Failure Modes

- Missing `input_file` or bad file path: scripts call `push_error()` and dialogue fails to load.
- Bad `target_scene_path`: `Yes` is blocked by `SceneRoutes.is_valid_scene()` and a Godot error is pushed.
- Missing instance overrides in `MAIN/scenes/main.tscn`: the reusable scene defaults may be incorrect or placeholder values.
- Backend failure for roaming NPCs: current code falls back to a generic greeting if the response is not a `success` reply.

## Compatibility Risks

- Renaming dialogue files without updating scene instance properties breaks runtime behavior.
- Moving mini-game entry scenes without updating `target_scene_path` breaks stall-owner launches.
- Changing the meaning of line 1 in dialogue files breaks both panel scripts.
- Refactoring player-group setup in the hub can break return-position restore.

## Validation Checklist

After any change to dialogue files, hub scenes, or related scripts:

1. Run the full project and enter the hub.
2. Talk to each stall owner.
3. Check `No`, `Again`, and `Yes` behavior on at least one stall owner.
4. Launch at least one mini-game and return to the hub.
5. Confirm the player respawns at the expected hub position.
6. Talk to at least one roaming NPC and confirm either generated text or graceful fallback text appears.
