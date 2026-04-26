# External API Contract

## Purpose

This document records the HTTP contract that the current Godot project expects. It is intentionally grounded in the client code that exists in this repo, including quirks and weak assumptions.

## Canonical Files

- `MAIN/script/game_data.gd`
- `MAIN/script/npc.gd`
- `NOI_CHU/scripts/GameNoiTu.gd`

## Related Docs

- [../architecture.md](../architecture.md): runtime boundaries and API-dependent modules.
- [../modules/MAIN.md](../modules/MAIN.md): roaming NPC behavior.
- [../modules/NOI_CHU.md](../modules/NOI_CHU.md): Noi Chu gameplay and API usage.
- [../runbooks/manual-smoke-test.md](../runbooks/manual-smoke-test.md): API-dependent smoke checks.

## Base URL

The backend base URL is currently hard-coded in `MAIN/script/game_data.gd` as `GameData.api_url`.

This document does not duplicate the literal host because the value is likely to change independently of the client-side contract.

## Current Consumers

| Consumer | File | Backend dependence |
| --- | --- | --- |
| Hub roaming NPC dialogue | `MAIN/script/npc.gd` | required for generated reply text |
| Noi Chu gameplay | `NOI_CHU/scripts/GameNoiTu.gd` | required for session setup, word generation, validation, and bot reply |

## Request Helper Behavior

### `NOI_CHU/scripts/GameNoiTu.gd`

- empty body `{}` -> sends a `GET`
- non-empty body -> sends a `POST` with JSON
- expects a single response per request
- uses an HTTP timeout and routes bad responses to the in-game game-over/error path

### `MAIN/script/npc.gd`

- guards against overlapping requests with `is_requesting`
- sends `POST` when body is non-empty
- stores a callback and invokes it on `200` responses
- uses a timeout and keeps local fallback text available if the backend response is unusable

## Endpoint Contracts

### `/game/start`

#### Caller

- `NOI_CHU/scripts/GameNoiTu.gd`

#### Current method

- `GET`

#### Current request body

- none

#### Expected response fields

- `session_id`

#### Client behavior

- if `session_id` is present, the client immediately requests `/game/new_word`
- if missing, the game ends with an error message

### `/game/new_word`

#### Caller

- `NOI_CHU/scripts/GameNoiTu.gd`

#### Current method

- `POST`

#### Current request body

```json
{
  "session_id": "<session id>"
}
```

#### Expected response fields

- `answer`

#### Client behavior

- stores `answer` as the current word
- resets timer and enables gameplay
- if missing, the game ends with an error

### `/word/validate`

#### Caller

- `NOI_CHU/scripts/GameNoiTu.gd`

#### Current method

- `POST`

#### Current request body

```json
{
  "word": "<player word>"
}
```

#### Expected response fields

- `valid` as boolean
- `reason` when invalid

#### Client behavior

- if `valid == true`, score increases and the client requests `/ask`
- if `valid == false`, the game ends with the provided `reason`

### `/ask`

#### Caller

- `NOI_CHU/scripts/GameNoiTu.gd`

#### Current method

- `POST`

#### Current request body

```json
{
  "prompt": "<player word>",
  "session_id": "<session id>"
}
```

#### Expected response fields

- `status`
- `answer`

#### Status values explicitly handled by current code

- `error`
- `unfound`
- any other value is treated as success

#### Client behavior

- `error`: end the game with the returned text
- `unfound`: award bonus points, request `/game/new_word`, continue session
- anything else: treat `answer` as the next current word

### `/npc/npc_intro`

#### Caller

- `MAIN/script/npc.gd`

#### Current method

- `POST`

#### Current request body in code

The request sends NPC background material read from the local dialogue/background text file:

```json
{
  "npc_background": "<local NPC background text>"
}
```

#### Expected response fields

- `status`
- `reply`

#### Client behavior

- if `status == "success"` and `reply` exists, the client shows:
  - line 1: NPC name
  - following text: backend reply
- otherwise, the client falls back to a generic greeting using the NPC name

## Failure Behavior

### `NOI_CHU`

- non-`200` responses trigger the in-game connection-error path
- missing required fields also end the game
- the game has no documented offline fallback mode

### Hub NPCs

- if the local text file cannot be opened, the NPC script raises an error and keeps its generic fallback text
- if the backend is unavailable or responds without the expected success shape, the script uses a generic fallback line

## Compatibility Risks

- The backend contract is implicit and not schema-validated.
- The base URL is hard-coded, not environment-configured.
- `NOI_CHU` assumes exact field names and does not tolerate alternate response shapes.
- `MAIN/script/npc.gd` uses the same request field for backend-generated text and falls back locally when the response is unusable.

## Validation Checklist

After changing the backend URL, request helpers, or any API-dependent gameplay:

1. Launch `NOI_CHU` from the hub.
2. Confirm `/game/start` and `/game/new_word` produce a playable initial state.
3. Submit one word and confirm the `/word/validate` -> `/ask` chain still works.
4. Talk to at least one roaming NPC in the hub.
5. Confirm the NPC path still shows either generated text or graceful fallback text.
