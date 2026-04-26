# Tái cấu trúc nợ kỹ thuật

## Mục đích

Tài liệu này ghi lại đợt tái cấu trúc nợ kỹ thuật diện rộng đã giới thiệu cấu hình dùng chung, hằng số định tuyến, helper HTTP, kiểm tra hợp lệ, và dọn dẹp module trong dự án Folk Games Collection.

Tài liệu dành cho maintainer khi review đợt refactor, các agent trong tương lai tiếp tục dọn dẹp, và bất kỳ ai cần debug hành vi đi qua ranh giới giữa các scene.

## Phạm vi

Đợt refactor đã chạm đến các khu vực sau:

- cấu hình cấp dự án và autoload
- URL backend và xử lý request JSON API
- dialogue ở hub và định tuyến scene
- cách dùng UI pause dùng chung
- tham chiếu node trong Ô Ăn Quan và hợp nhất script AI
- script dùng chung của Trốn Tìm và chuẩn hóa pause scene
- dọn dẹp Cờ Gánh và debug logging
- vệ sinh repo cho file tạm của Godot
- tài liệu và phạm vi kiểm tra preflight

## Không thuộc phạm vi

Đợt refactor cố ý không thêm:

- luật gameplay mới
- lưu trạng thái tiến trình cho Trốn Tìm
- chế độ offline mới cho các luồng phụ thuộc API
- triển khai backend
- bộ test gameplay tự động đầy đủ

Mục tiêu là giữ hành vi hiện tại tương đương trong khi loại bỏ nợ cấu trúc cơ bản.

## Helper cấp dự án

### `AppConfig`

File: `MAIN/script/app_config.gd`

`AppConfig` tập trung hóa các thiết lập trước đây bị hard-code hoặc nằm rải rác:

- `application/config/backend_base_url`
- `application/config/api_timeout_seconds`
- `application/config/debug_logging`

URL backend mặc định trong `project.godot` hiện là chuỗi rỗng:

```ini
config/backend_base_url=""
config/api_timeout_seconds=8.0
config/debug_logging=false
```

Điều này ngăn các URL tunnel, proxy, hoặc Daytona tạm thời bị commit vào source. Các tính năng phụ thuộc API phải được cấu hình theo từng môi trường trước khi chơi bình thường.

### `SceneRoutes`

File: `MAIN/script/scene_routes.gd`

`SceneRoutes` cung cấp các path chuẩn cho chuyển scene dùng chung:

- scene khởi động và hub
- scene vào của từng mini-game
- scene game-over của Noi Chu
- scene chọn màn, scene chính, và scene end-game của Ô Ăn Quan
- scene chọn level, game-over, hoàn thành level, và pattern level của Trốn Tìm

Nó cũng cung cấp:

- `tron_tim_level(level_num)`
- `is_valid_scene(path)`
- `change_to(path, tree)`

Dùng các hằng số này trong script thay vì lặp lại path dạng chuỗi.

### `DebugLog`

File: `MAIN/script/debug_log.gd`

`DebugLog` khóa output chẩn đoán phía sau `AppConfig.is_debug_logging_enabled()`.

Những lệnh `print()` còn lại có chủ ý chỉ nên nằm trong `DebugLog`. Script gameplay nên gọi:

```gdscript
DebugLog.info("message")
DebugLog.value("message:", value)
```

## Refactor API

### JSON client dùng chung

File: `MAIN/script/json_api_client.gd`

`JsonApiClient` bọc một node `HTTPRequest` thuộc scene và chuẩn hóa:

- tra cứu backend base URL
- gán timeout từ `AppConfig`
- GET cho request body rỗng
- POST với JSON cho request body không rỗng
- xử lý trạng thái không phải 200
- xử lý JSON không hợp lệ
- thiếu cấu hình backend
- bảo vệ chỉ một request đang chạy tại một thời điểm

Dạng callback:

```gdscript
{
	"ok": bool,
	"code": int,
	"data": Dictionary,
	"error": String,
}
```

### Consumer hiện tại

`MAIN/script/npc.gd` hiện dùng `JsonApiClient` cho `/npc/npc_intro`.

Hành vi khi lỗi:

- lỗi backend được log qua `DebugLog`
- lời thoại NPC fallback về lời chào chung cục bộ
- gameplay không nên hard-crash chỉ vì không lấy được text NPC sinh ra

`NOI_CHU/scripts/GameNoiTu.gd` hiện dùng `JsonApiClient` cho:

- `/game/start`
- `/game/new_word`
- `/word/validate`
- `/ask`

Hành vi khi lỗi:

- thiếu config, trạng thái không phải 200, JSON không hợp lệ, hoặc thiếu field bắt buộc đều đi vào luồng lỗi/game-over trong game
- không thêm chế độ gameplay offline

Xem `docs/contracts/external-api.md` để biết contract endpoint.

## Dialogue và định tuyến scene

### Contract file dialogue

`MAIN/script/dialogue_panel.gd` hiện kiểm tra file dialogue phải có dòng đầu tiên không rỗng. Dòng đầu tiên vẫn là tiêu đề hoặc tên người nói.

Điều này bảo vệ contract hiện có:

- dòng 1: tiêu đề
- các dòng còn lại: nội dung thoại
- cuối nội dung: lựa chọn `No`, `Again`, `Yes`

### Kiểm tra target scene

`target_scene_path` hiện mặc định là chuỗi rỗng trong `MAIN/script/dialogue_panel.gd`.

Trước khi launch mini-game, panel kiểm tra:

```gdscript
SceneRoutes.is_valid_scene(target_scene_path)
```

Nếu route không hợp lệ, việc chuyển scene bị chặn và Godot error được push.

### Thay thế route

Các lệnh chuyển scene hard-code đã được thay bằng `SceneRoutes` trong:

- `MAIN/script/start.gd`
- `MAIN/script/game_control.gd`
- `NOI_CHU/scripts/GameOver.gd`
- `O_AN_QUAN/scripts/select_level.gd`
- `O_AN_QUAN/scripts/end_game.gd`
- `O_AN_QUAN/scripts/SceneManager.gd`
- `TRON_TIM/scripts/Global.gd`
- `TRON_TIM/scripts/gameover.gd`
- `TRON_TIM/scripts/level_completed.gd`
- một số script level 3 của Trốn Tìm
- `CO_GANH/scripts/board.gd`

## UI pause dùng chung

Packed scene chuẩn:

- `MAIN/scenes/ui/game_control.tscn`

Script chuẩn:

- `MAIN/script/game_control.gd`

Đợt refactor đã chuẩn hóa các scene mini-game theo hướng dùng packed scene thay vì copy trực tiếp cấu trúc pause menu, script, texture, theme, và stylebox resource vào từng scene.

Các scene đang dùng trực tiếp gồm:

- `CO_GANH/scenes/main.tscn`
- `NOI_CHU/scenes/main.tscn`
- `O_AN_QUAN/scenes/main.tscn`
- `O_AN_QUAN/scenes/SelectLevel.tscn`
- `TRON_TIM/scenes/level_select.tscn`
- `TRON_TIM/scenes/level_1.tscn`
- `TRON_TIM/scenes/level_2.tscn`
- `TRON_TIM/scenes/level_3.tscn`

Khi thay đổi hành vi pause, hãy sửa packed scene hoặc `MAIN/script/game_control.gd`, rồi retest mọi mini-game instance scene đó.

## Refactor Ô Ăn Quan

### Tham chiếu node

File: `O_AN_QUAN/scripts/game_manager.gd`

Gameplay manager không còn dùng lookup `/root/main/...`. Nó hiện resolve các node board, popup, label, và captured-slot tương đối với node `GameManager`.

Scene tree vẫn có contract về tên node. Các path này vẫn quan trọng:

- `../Board`
- `../CanvasLayer/DirectionPopup`
- `../CanvasLayer/PlayerScore`
- `../CanvasLayer/AIScore`
- `../CapturedSlotLeft`
- `../CapturedSlotRight`

Nếu scene tree thay đổi, hãy cập nhật cả scene và các tham chiếu tương đối.

### Hợp nhất AI

File: `O_AN_QUAN/scripts/ai_player.gd`

Các script AI trùng lặp trước đây đã bị xóa:

- `O_AN_QUAN/scripts/ai_player_1.gd`
- `O_AN_QUAN/scripts/ai_player_2.gd`
- `O_AN_QUAN/scripts/ai_player_3.gd`

`ai_player.gd` hiện nhận depth qua:

```gdscript
AIPlayer.set_max_depth(SceneManager.MAX_DEPTH)
```

Chọn độ khó vẫn do `SceneManager` quản lý:

- `easy` -> depth `1`
- `medium` -> depth `3`
- `hard` -> depth `7`

## Refactor Trốn Tìm

### Script dùng chung

Script dùng chung mới:

- `TRON_TIM/scripts/level_ui.gd`
- `TRON_TIM/scripts/top_down_player.gd`
- `TRON_TIM/scripts/vision_countdown_area.gd`

Các wrapper level hiện extend script dùng chung cho hành vi lặp lại:

- `TRON_TIM/scripts/level 1/ui.gd`
- `TRON_TIM/scripts/level 2/ui_2.gd`
- `TRON_TIM/scripts/level 3/ui 3.gd`
- `TRON_TIM/scripts/level 1/player_walk.gd`
- `TRON_TIM/scripts/level 2/player_2.gd`
- `TRON_TIM/scripts/level 1/vision_area.gd`
- `TRON_TIM/scripts/level 2/vision_area2.gd`

Level 3 giữ nhiều hành vi guard/player chuyên biệt hơn vì luật phát hiện và countdown khác.

### Dọn dẹp route

`TRON_TIM/scripts/Global.gd` hiện load level qua `SceneRoutes.tron_tim_level(level_num)`.

Các script thất bại và hoàn thành level hiện route qua `SceneRoutes` thay vì lặp lại scene path.

### Chuẩn hóa pause scene

Scene chọn level và các scene playable của Trốn Tìm hiện instance:

```text
res://MAIN/scenes/ui/game_control.tscn
```

Chúng không còn nhúng trực tiếp pause script, pause icon, pause background, theme, hoặc hover stylebox.

## Refactor Cờ Gánh

File: `CO_GANH/scripts/board.gd`

Thay đổi:

- path avatar bot được chuyển thành hằng số
- tên hiển thị của bot được chuyển thành hằng số
- phần reset trùng lặp được chuyển vào `_clear_board_runtime_state()`
- path quay về hub dùng `SceneRoutes.MAIN_HUB`
- debug print dùng `DebugLog`

File: `CO_GANH/scripts/bot_select_layer.gd`

Thay đổi:

- output debug khi chọn bot dùng `DebugLog`

Script rỗng không dùng đã bị xóa:

- `CO_GANH/scripts/botselect.gd`

## Vệ sinh repo

`.gitignore` hiện ignore:

```gitignore
*.tmp
```

Các file backup scene tạm của Godot từng được track đã bị xóa. Đây là artifact của editor và không nên dùng làm source of truth.

Script mới có file `.gd.uid` tương ứng để định danh resource của Godot ổn định giữa các máy.

Đợt refactor cố ý không xóa các file `.import` đang được track hoặc các file `.uid` không liên quan.

## Script kiểm tra hợp lệ

File: `tools/validate_project.gd`

Script kiểm tra:

- các autoload bắt buộc tồn tại
- autoload `SceneRoutes` khả dụng
- hằng số route chuẩn trỏ đến scene load được
- pattern level Trốn Tìm resolve được level 1 đến 3
- các giá trị `target_scene_path` không rỗng trong file `.tscn` là scene hợp lệ
- file dialogue có dòng tiêu đề đầu tiên không rỗng
- script `.gd` không chứa URL backend hard-code

Chạy bằng:

```powershell
& 'D:\Code\HCMUS\Godot_v4.6.2\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\Code\HCMUS\folk-games-collection' --script 'res://tools/validate_project.gd'
```

## Tài liệu đã cập nhật

Đợt refactor cũng đã cập nhật:

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

## Tóm tắt ảnh hưởng thay đổi

| Khu vực | Ảnh hưởng chính | Trọng tâm retest |
| --- | --- | --- |
| `project.godot` | autoload và config key mới | startup, autoload khả dụng |
| dialogue trong `MAIN` | kiểm tra dòng tiêu đề và target scene path | lựa chọn của stall-owner, quay về hub |
| API consumer | hành vi request dùng chung và backend theo config | NPC fallback, luồng API Noi Chu |
| UI pause dùng chung | packed scene là chuẩn | pause và quit trong mọi mini-game |
| Ô Ăn Quan | node ref tương đối và hợp nhất AI | chọn độ khó, nước đi đầu, phản hồi AI |
| Trốn Tìm | script dùng chung và packed pause scene | chọn level, di chuyển level 1, đường game-over/win |
| Cờ Gánh | dọn reset và hằng số | chọn bot, nước đi đầu, replay/quay về |
| Vệ sinh repo | ignore và xóa `.tmp` | không có backup sinh tự động trong worktree |

## Rủi ro còn lại đã biết

- Manual gameplay smoke vẫn quan trọng vì repo chưa có bộ gameplay test tự động đầy đủ.
- Gameplay phụ thuộc API vẫn cần backend thật được cấu hình qua `application/config/backend_base_url`.
- Godot headless quit vẫn báo resource/leak warning đã biết, tồn tại từ trước refactor này.
- Web export yêu cầu cài Godot Web export templates cho `4.6.2.stable`.
