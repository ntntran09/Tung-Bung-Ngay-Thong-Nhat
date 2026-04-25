# NOI_CHU

## Purpose

`NOI_CHU/` contains the word-chain mini-game. It combines local UI/timer logic with a backend service for session creation, starting words, word validation, and bot replies.

## Related Docs

- [../architecture.md](../architecture.md): runtime boundaries and hub launch flow.
- [../contracts/external-api.md](../contracts/external-api.md): canonical API contract for this module.
- [MAIN.md](MAIN.md): shared pause UI and hub-owned launch behavior.
- [../runbooks/manual-smoke-test.md](../runbooks/manual-smoke-test.md): Noi Chu smoke checks.

## What This Module Is Responsible For

- displaying score, timer, current word, input field, and toast messages
- starting a word-chain session through the backend
- validating local word-chain adjacency before backend validation
- requesting backend word validation and bot responses
- showing a game-over overlay
- playing module-specific music and sound effects

## What This Module Is Not Responsible For

- backend implementation
- hub dialogue that launches the game
- persistent score storage
- project-wide API configuration beyond reading `GameData.api_url`

## Structure

- `scenes/main.tscn`: main Noi Chu gameplay scene.
- `scripts/GameNoiTu.gd`: gameplay state, timer, API calls, and game-over trigger.
- `scenes/game_over.tscn`: game-over overlay scene.
- `scripts/GameOver.gd`: play-again and return-to-hub actions.
- `scripts/Toast.gd`: temporary toast message display.
- `assets/audio/`: module audio.
- `assets/pics/`: background and game-over imagery.
- `assets/themes/`: UI themes.

## Entry Points

- From the hub: `res://NOI_CHU/scenes/main.tscn`
- Direct debug entry: `NOI_CHU/scenes/main.tscn`

## Inputs And Outputs

### Inputs

- backend base URL from `GameData.api_url`
- keyboard input in the word input field
- submit button click or `text_submitted` event
- timer ticks from the scene `Timer`

### Outputs

- score label updates
- timer label updates
- toast messages
- backend requests to:
  - `/game/start`
  - `/game/new_word`
  - `/word/validate`
  - `/ask`
- instantiated `NOI_CHU/scenes/game_over.tscn` on failure/end state

## Important Runtime Assumptions

### The backend is required for normal play

`start_new_game()` calls the backend immediately. Without a valid backend response, normal gameplay cannot start.

### Client-side validation runs before server validation

The client checks that the last word segment of the current word matches the first word segment of the submitted word before calling `/word/validate`.

### Game over pauses the tree

`GameNoiTu.gd` sets `get_tree().paused = true` before adding the game-over scene. `GameOver.gd` sets its `process_mode` to `PROCESS_MODE_ALWAYS` so its buttons still work.

### Shared pause UI is present

`NOI_CHU/scenes/main.tscn` includes `MAIN/scenes/ui/game_control.tscn` as a `Pause` child.

## Common Workflows

### Change backend behavior

Read first:

- `scripts/GameNoiTu.gd`
- `docs/contracts/external-api.md`

Then re-test start, valid answer, invalid answer, timeout, and backend failure paths.

### Change UI layout

Read first:

- `scenes/main.tscn`
- `scripts/GameNoiTu.gd`
- `scripts/Toast.gd`

Preserve node paths used by `@onready` variables, or update the script paths at the same time.

### Change game-over behavior

Read first:

- `scripts/GameNoiTu.gd`
- `scenes/game_over.tscn`
- `scripts/GameOver.gd`

Then re-test play-again and return-to-hub while the tree is paused.

## Artifacts

- runtime session ID from backend
- runtime used-word list
- no visible local save file

## Change Impact

- editing `GameNoiTu.gd` can break both gameplay and backend communication
- editing scene node names can break `@onready` paths
- editing `GameOver.gd` can break play-again or return-to-hub while paused
- editing `GameData.api_url` affects this module immediately

## What To Test After Changes

1. Launch `NOI_CHU/scenes/main.tscn`.
2. Confirm the initial backend session starts or fails gracefully.
3. Submit a locally invalid word and confirm the local rule catches it.
4. Submit a word that reaches backend validation.
5. Confirm score/timer updates.
6. Trigger game over by invalid answer or timeout.
7. Test play-again and return-to-hub buttons.
