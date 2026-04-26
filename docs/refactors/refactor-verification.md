# Refactor Verification

## Purpose

This document records how to verify the technical-debt refactor described in `technical-debt-refactor.md`.

Use it when reviewing the refactor, splitting it into smaller commits, or preparing a release/export after the cleanup.

## Automated Checks

### Project Validation

Command:

```powershell
& 'D:\Code\HCMUS\Godot_v4.6.2\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\Code\HCMUS\folk-games-collection' --script 'res://tools/validate_project.gd'
```

Expected result:

- exit code `0`
- no validation errors

Current coverage:

- autoload presence
- route constant loadability
- Tron Tim level pattern
- `target_scene_path` loadability in `.tscn` files
- dialogue title-line contract
- no hard-coded backend URLs in `.gd` scripts

### Headless Project Load

Command:

```powershell
& 'D:\Code\HCMUS\Godot_v4.6.2\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\Code\HCMUS\folk-games-collection' --quit
```

Expected result:

- exit code `0`

Known current output:

- `ObjectDB instances leaked at exit`
- `1 resources still in use at exit`

That warning existed in the baseline and is not treated as a blocker for this refactor.

### Git Whitespace Check

Command:

```powershell
git diff --check
```

Expected result:

- no output
- exit code `0`

### Hard-Code Scan

Command:

```powershell
Get-ChildItem -Path . -Recurse -Include *.gd |
	Where-Object { $_.FullName -notmatch '\\.godot|EXPORT' } |
	Select-String -Pattern 'https?://|GameData\.api_url|SERVER_URL|/root/main|ai_player_1|ai_player_2|ai_player_3'
```

Expected result:

- no matches

### Debug Print Scan

Command:

```powershell
Get-ChildItem -Path MAIN,CO_GANH,NOI_CHU,O_AN_QUAN,TRON_TIM -Recurse -Include *.gd |
	Select-String -Pattern 'print\('
```

Expected result:

- matches only in `MAIN/script/debug_log.gd`

### Godot Temporary Files

Command:

```powershell
Get-ChildItem -Path . -Recurse -Include *.tmp |
	Where-Object { $_.FullName -notmatch '\\.godot|EXPORT' }
```

Expected result:

- no files

## Manual Smoke Checklist

Run the full checklist in `docs/runbooks/manual-smoke-test.md` before treating the refactor as release-ready.

Minimum manual coverage for this refactor:

1. Start from `MAIN/scenes/start.tscn`.
2. Enter the hub and move the player.
3. Interact with one stall owner.
4. Test `No`, `Again`, and `Yes`.
5. Launch one mini-game and return to hub.
6. Talk to one roaming NPC with backend unavailable or reachable.
7. Launch Co Ganh, select a bot, make one move, and return.
8. Launch Noi Chu and verify either API success or graceful API failure.
9. Launch O An Quan, select a difficulty, make one move, and open pause.
10. Launch Tron Tim, enter level 1, move, see timer/countdown behavior, and open pause.

## Focused Checks By Refactor Area

### `AppConfig`

Check:

- `project.godot` contains the expected config keys
- backend URL defaults to an empty string
- API consumers fail gracefully when backend URL is empty

### `JsonApiClient`

Check:

- missing backend URL returns `ok == false`
- non-empty request body sends POST JSON
- empty request body sends GET
- invalid or missing response fields do not crash the caller

### Dialogue Routing

Check:

- every `MAIN/dialogues/*.txt` file has a title line
- every stall-owner `target_scene_path` points to a loadable scene
- player return position still restores through `GameData.player_position`

### Shared Pause UI

Check pause menu in:

- `CO_GANH/scenes/main.tscn`
- `NOI_CHU/scenes/main.tscn`
- `O_AN_QUAN/scenes/main.tscn`
- `TRON_TIM/scenes/level_select.tscn`
- one Tron Tim playable level

### O An Quan

Check:

- each difficulty sets the intended AI depth
- board initializes
- direction popup appears after selecting a valid slot
- first move resolves without node-path errors
- end-game route still works

### Tron Tim

Check:

- level select loads
- only level 1 is unlocked on a fresh session
- level 1 movement works
- level UI timer updates
- failure route reaches `TRON_TIM/scenes/gameover.tscn`
- win route reaches `TRON_TIM/scenes/level_completed.tscn`
- progression remains in-memory only

### Co Ganh

Check:

- bot descriptions and selected bot level still work
- avatar and name mapping are correct for each level
- reset/replay clears board runtime state once
- return-to-hub uses the shared route

## Web Export Check

Preset:

- `Web 2`

Command:

```powershell
& 'D:\Code\HCMUS\Godot_v4.6.2\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\Code\HCMUS\folk-games-collection' --export-release 'Web 2' 'D:\Code\HCMUS\folk-games-collection\EXPORT\index.html'
```

Current blocker:

Godot Web export templates for `4.6.2.stable` are not installed on the current machine. The export command reports missing templates:

- `C:/Users/Hoang/AppData/Roaming/Godot/export_templates/4.6.2.stable/web_nothreads_debug.zip`
- `C:/Users/Hoang/AppData/Roaming/Godot/export_templates/4.6.2.stable/web_nothreads_release.zip`

After installing the templates:

1. Re-run the export command.
2. Zip the contents of `EXPORT/`.
3. Upload to itch.io as an HTML game build.
4. Test startup, hub launch, and API behavior in a browser context.

## Current Verified State

Verified in the current worktree:

- validation script passed
- Godot headless load passed with known leak/resource warning
- `git diff --check` passed
- hard-code scan found no forbidden script matches
- debug print scan found only `DebugLog`
- no non-cache `*.tmp` files remain in the working tree

Not yet verified:

- full manual gameplay smoke
- successful Web 2 export
- browser or itch.io hosted load
