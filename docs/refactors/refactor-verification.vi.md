# Kiểm chứng refactor

## Mục đích

Tài liệu này ghi lại cách kiểm chứng đợt refactor nợ kỹ thuật được mô tả trong `technical-debt-refactor.md`.

Dùng tài liệu này khi review refactor, tách refactor thành các commit nhỏ hơn, hoặc chuẩn bị release/export sau đợt dọn dẹp.

## Kiểm tra tự động

### Kiểm tra hợp lệ dự án

Command:

```powershell
& 'D:\Code\HCMUS\Godot_v4.6.2\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\Code\HCMUS\folk-games-collection' --script 'res://tools/validate_project.gd'
```

Kết quả mong đợi:

- exit code `0`
- không có validation error

Phạm vi hiện tại:

- autoload tồn tại
- route constant load được
- pattern level Tron Tim
- `target_scene_path` trong file `.tscn` load được
- contract dòng tiêu đề dialogue
- không có URL backend hard-code trong script `.gd`

### Load project headless

Command:

```powershell
& 'D:\Code\HCMUS\Godot_v4.6.2\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\Code\HCMUS\folk-games-collection' --quit
```

Kết quả mong đợi:

- exit code `0`

Output hiện đã biết:

- `ObjectDB instances leaked at exit`
- `1 resources still in use at exit`

Warning này đã tồn tại ở baseline và không được xem là blocker cho refactor này.

### Kiểm tra whitespace bằng Git

Command:

```powershell
git diff --check
```

Kết quả mong đợi:

- không có output
- exit code `0`

### Scan hard-code

Command:

```powershell
Get-ChildItem -Path . -Recurse -Include *.gd |
	Where-Object { $_.FullName -notmatch '\\.godot|EXPORT' } |
	Select-String -Pattern 'https?://|GameData\.api_url|SERVER_URL|/root/main|ai_player_1|ai_player_2|ai_player_3'
```

Kết quả mong đợi:

- không có match

### Scan debug print

Command:

```powershell
Get-ChildItem -Path MAIN,CO_GANH,NOI_CHU,O_AN_QUAN,TRON_TIM -Recurse -Include *.gd |
	Select-String -Pattern 'print\('
```

Kết quả mong đợi:

- chỉ match trong `MAIN/script/debug_log.gd`

### File tạm Godot

Command:

```powershell
Get-ChildItem -Path . -Recurse -Include *.tmp |
	Where-Object { $_.FullName -notmatch '\\.godot|EXPORT' }
```

Kết quả mong đợi:

- không có file

## Checklist smoke thủ công

Chạy checklist đầy đủ trong `docs/runbooks/manual-smoke-test.md` trước khi xem refactor là sẵn sàng release.

Phạm vi thủ công tối thiểu cho refactor này:

1. Khởi động từ `MAIN/scenes/start.tscn`.
2. Vào hub và di chuyển player.
3. Tương tác với một stall owner.
4. Test `No`, `Again`, và `Yes`.
5. Launch một mini-game và quay về hub.
6. Nói chuyện với một roaming NPC khi backend không khả dụng hoặc khả dụng.
7. Launch Co Ganh, chọn bot, đi một nước, và quay về.
8. Launch Noi Chu và xác minh API thành công hoặc lỗi API được xử lý mềm.
9. Launch O An Quan, chọn độ khó, đi một nước, và mở pause.
10. Launch Tron Tim, vào level 1, di chuyển, quan sát timer/countdown, và mở pause.

## Kiểm tra tập trung theo khu vực refactor

### `AppConfig`

Kiểm tra:

- `project.godot` chứa các config key mong đợi
- backend URL mặc định là chuỗi rỗng
- API consumer lỗi mềm khi backend URL rỗng

### `JsonApiClient`

Kiểm tra:

- thiếu backend URL trả về `ok == false`
- request body không rỗng gửi POST JSON
- request body rỗng gửi GET
- response không hợp lệ hoặc thiếu field không làm caller crash

### Dialogue routing

Kiểm tra:

- mọi file `MAIN/dialogues/*.txt` có dòng tiêu đề
- mọi `target_scene_path` của stall-owner trỏ đến scene load được
- vị trí quay về của player vẫn restore qua `GameData.player_position`

### UI pause dùng chung

Kiểm tra pause menu trong:

- `CO_GANH/scenes/main.tscn`
- `NOI_CHU/scenes/main.tscn`
- `O_AN_QUAN/scenes/main.tscn`
- `TRON_TIM/scenes/level_select.tscn`
- một level playable của Tron Tim

### O An Quan

Kiểm tra:

- mỗi độ khó gán đúng AI depth dự định
- board khởi tạo
- direction popup xuất hiện sau khi chọn slot hợp lệ
- nước đi đầu tiên xử lý không có lỗi node-path
- route end-game vẫn hoạt động

### Tron Tim

Kiểm tra:

- level select load được
- chỉ level 1 được mở khóa trong session mới
- di chuyển level 1 hoạt động
- timer UI của level cập nhật
- route thất bại đến `TRON_TIM/scenes/gameover.tscn`
- route thắng đến `TRON_TIM/scenes/level_completed.tscn`
- progression vẫn chỉ nằm trong bộ nhớ

### Co Ganh

Kiểm tra:

- mô tả bot và level bot được chọn vẫn hoạt động
- mapping avatar và tên đúng cho từng level
- reset/replay xóa board runtime state đúng một lần
- quay về hub dùng route dùng chung

## Kiểm tra Web export

Preset:

- `Web 2`

Command:

```powershell
& 'D:\Code\HCMUS\Godot_v4.6.2\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\Code\HCMUS\folk-games-collection' --export-release 'Web 2' 'D:\Code\HCMUS\folk-games-collection\EXPORT\index.html'
```

Blocker hiện tại:

Godot Web export templates cho `4.6.2.stable` chưa được cài trên máy hiện tại. Lệnh export báo thiếu templates:

- `C:/Users/Hoang/AppData/Roaming/Godot/export_templates/4.6.2.stable/web_nothreads_debug.zip`
- `C:/Users/Hoang/AppData/Roaming/Godot/export_templates/4.6.2.stable/web_nothreads_release.zip`

Sau khi cài templates:

1. Chạy lại lệnh export.
2. Zip nội dung trong `EXPORT/`.
3. Upload lên itch.io dưới dạng HTML game build.
4. Test startup, launch hub, và hành vi API trong ngữ cảnh browser.

## Trạng thái đã kiểm chứng hiện tại

Đã kiểm chứng trong worktree hiện tại:

- validation script passed
- Godot headless load passed với warning leak/resource đã biết
- `git diff --check` passed
- hard-code scan không tìm thấy match script bị cấm
- debug print scan chỉ tìm thấy `DebugLog`
- không còn file `*.tmp` ngoài cache trong working tree

Chưa kiểm chứng:

- full manual gameplay smoke
- Web 2 export thành công
- load trên browser hoặc itch.io hosted
