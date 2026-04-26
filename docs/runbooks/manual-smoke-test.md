# Manual Smoke Test

## Purpose

This is the current regression checklist for the repo. Use it after changes to scenes, dialogue, autoloads, input actions, shared UI, or backend-dependent features.

## When To Run It

Run at least the relevant subset after changes to:

- `project.godot`
- `MAIN/` scenes or dialogue scripts
- `MAIN/dialogues/*.txt`
- shared pause UI
- `GameData`, `SceneManager`, or `Global`
- any module launch or return path
- backend request logic

## Prerequisites

- Godot has re-imported assets cleanly.
- If you changed backend-dependent code, the backend configured by `application/config/backend_base_url` is reachable.

## Automated Preflight

Before manual smoke testing, run:

```powershell
& 'D:\Code\HCMUS\Godot_v4.6.2\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\Code\HCMUS\folk-games-collection' --script 'res://tools/validate_project.gd'
```

Pass condition:

- required autoloads exist
- canonical scene routes load
- dialogue files have title lines
- `.gd` scripts do not contain hard-coded backend URLs

## 1. Startup Path

1. Run the project with `F5`.
2. Confirm `MAIN/scenes/start.tscn` loads.
3. Press any key.
4. Confirm the project transitions to `MAIN/scenes/main.tscn`.

Pass condition:

- no startup errors
- hub scene loads

## 2. Hub Traversal

1. Move with `WASD` or arrow keys.
2. Run with `Shift`.
3. Walk near a stall owner and confirm the interact prompt appears.

Pass condition:

- player movement works
- interaction trigger appears when near a valid character

## 3. Stall-Owner Dialogue

1. Interact with one stall owner.
2. Advance through the dialogue.
3. Check all three outcomes across one or more stall owners:
   - `No`
   - `Again`
   - `Yes`

Pass condition:

- dialogue opens and advances
- `No` closes cleanly
- `Again` restarts from the first line
- `Yes` launches the expected module

## 4. Hub Return Position

1. Launch a mini-game from a stall owner with `Yes`.
2. Return to the hub using the mini-game's quit or back path.

Pass condition:

- the hub reloads
- the player reappears at a sensible saved location

## 5. Roaming NPC Dialogue

1. Talk to at least one roaming NPC in the hub.
2. Confirm the player cannot move while dialogue is open.
3. Close the dialogue and confirm movement returns.

Pass condition:

- dialogue appears
- control lock/unlock works
- if the backend is unavailable, the game does not hard-crash

## 6. Co Ganh

1. Launch `CO_GANH` from the hub.
2. Select a bot level.
3. Make one legal move.
4. Use the module's restart or return-to-hub path.

Pass condition:

- board appears after bot selection
- legal move interaction works
- return path to the hub still works

## 7. Noi Chu

1. Launch `NOI_CHU` from the hub.
2. Confirm the game either:
   - creates a session and shows a starting word, or
   - fails gracefully with an in-game error path
3. Submit one word.
4. Open the shared pause menu with `Esc`.

Pass condition:

- no scene crash
- API-dependent path behaves predictably
- pause menu still works

## 8. O An Quan

1. Launch `O_AN_QUAN` from the hub.
2. Select `easy`, `medium`, or `hard`.
3. In gameplay, click a valid player slot and confirm the direction popup appears.
4. Make one move.
5. Open the shared pause menu with `Esc`.

Pass condition:

- difficulty select transitions correctly
- board initializes
- move input works
- pause menu still works

## 9. Tron Tim

1. Launch `TRON_TIM` from the hub.
2. Confirm level select loads.
3. On a fresh run, confirm only level 1 is unlocked.
4. Start level 1.
5. Move the player and confirm the countdown updates.
6. Open the shared pause menu with `Esc`.

Pass condition:

- level select works
- level 1 loads
- timer UI updates
- pause menu still works

## 10. Tron Tim Progression

If you touched `TRON_TIM` logic:

1. Reach a win path for one level, or invoke it via an existing debug-friendly path if available.
2. Confirm the next level becomes selectable in the same app session.
3. Restart the app and confirm progression resets unless you intentionally added persistence.

Pass condition:

- `Global._on_level_win()` still unlocks the next level
- progression behavior matches the current in-memory design

## Focused Retest By Change Type

### If you changed `project.godot`

Retest:

- startup
- autoload behavior
- input actions
- import workflow

### If you changed dialogue files or hub scene wiring

Retest:

- stall-owner launch flow
- hub return placement
- roaming NPC dialogue

### If you changed shared pause UI

Retest:

- `NOI_CHU`
- `O_AN_QUAN`
- `TRON_TIM`

### If you changed backend request logic

Retest:

- one roaming NPC
- full `NOI_CHU` start/validate/respond loop

## Current Gap

This repo does not expose an automated test suite, so this runbook is the practical source of truth for regression coverage today.
