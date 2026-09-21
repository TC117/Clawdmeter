# Port DevKitC + ST7796 480×320 và màn Usage hai cột Claude / Codex

Ngày: 2026-09-21 · Nhánh: `feat/devkitc-st7796-claude-codex`

## Mục tiêu

Chạy Clawdmeter trên board tự đấu dây của người dùng (ESP32-S3-DevKitC-1 N16R8 bản clone YD +
màn MSP4031 4.0" 480×320), với màn Usage mới: đồng hồ trên cùng, hai cột Claude và Codex, mỗi
cột có 5h và Weekly cùng giờ cập nhật để biết số liệu có đang real-time không.

## Quyết định đã chốt

| Việc | Quyết định |
|---|---|
| Bố cục | Đồng hồ trên cùng; cột trái Claude, cột phải Codex |
| Nguồn Claude | Giữ nguyên daemon gốc của Clawdmeter (người dùng chọn) |
| Nguồn Codex | Port từ bridge `usage-lcd` cũ: `codex app-server`, dự phòng đọc log `~/.codex/sessions` |
| Icon góc trái | Quả bơ từ Fluent Emoji (MIT), thay cho Clawd ở bố cục ngang |
| Ô `hh:mm` | Giờ nhận số liệu gần nhất của từng bên; viên xám, chuyển vàng khi cũ hơn 5 phút |
| Chữ trên màn | Tiếng Anh (font sẵn có chỉ có ASCII) |
| Nút BOOT | Space (voice mode) như Clawdmeter gốc |

## Phần cứng

Chân lấy từ `usage-lcd/src/config.h` (đã chạy thật trên board này).

| Tín hiệu | GPIO | Ghi chú |
|---|---|---|
| LCD SCK / MOSI / MISO | 12 / 11 / 13 | SPI2 (FSPI), 40 MHz vì đấu dây rời |
| LCD CS / DC / RST | 10 / 9 / 14 | ST7796S, native 320×480, dùng rotation 1 → 480×320 |
| LCD BL | 16 | LEDC PWM |
| CTP SDA / SCL / RST / INT | 4 / 5 / 6 / 7 | FT6336U @ 0x38 |
| SD CS | 15 | Giữ mức HIGH, không dùng thẻ |
| BOOT | 0 | Nút duy nhất → PRIMARY (Space) |

Không có PMU, pin, IMU, IO expander. Cáp cắm cổng UART (CH343, COM6), nên env này đặt
`ARDUINO_USB_CDC_ON_BOOT=0` để `Serial` (log + lệnh `screenshot`) đi qua UART0.

## Màn Usage 480×320 (bố cục ngang)

Tọa độ theo mockup đã duyệt. Font lấy từ bộ font có sẵn.

- **Thanh trên (y 0–48):** icon quả bơ 36×36 tại (14, 6). Đồng hồ Tiempos 34, căn giữa
  (dùng `t`/`tf` từ daemon như bản gốc; chưa có giờ thì hiện "Usage"). Chấm trạng thái BLE
  10 px tại (460, 19): xanh = có dữ liệu, vàng = đang tìm / mất kết nối.
- **Hai panel:** 222×252, y = 56, x = 12 (Claude) và x = 246 (Codex), bo góc 12, màu
  `COL_PANEL`.
- **Trong mỗi panel:**
  - Tiêu đề Styrene 20 tại (16, 10), màu nhận diện: Claude `#D97757`, Codex `#5DCAA5`.
  - Ô giờ góc phải trên: Styrene 14, viên pill, nội dung `HH:MM` (theo `tf` 12/24h).
    Viên xám khi số liệu mới; nền vàng (`COL_AMBER`) khi cũ hơn 5 phút; `--:--` khi chưa
    từng có số.
  - Mục 5h: % Styrene 48 tại (16, 48); nhãn "5h" Styrene 14 màu dim căn phải, y 52;
    bar 190×10 tại (16, 104) màu nhận diện; dòng "Resets in 1h 20m" Styrene 16 dim tại
    (16, 120).
  - Mục Weekly: giống mục 5h, dịch xuống 104 px (%, y 152; bar, y 208; reset, y 224).
  - Không có số: `--%` màu dim, bar trống, dòng reset ghi "No data".
- **Ca xấu nhất phải vừa:** "100%" + nhãn "Weekly" trong 222 px; "Resets in 6d 23h".
- Màn Splash và thao tác chạm để chuyển màn giữ nguyên. Splash tự căn giữa (cell 5 px,
  vùng vẽ 300×300).

### Cách tích hợp vào UI

- `compute_layout()` thêm cờ `landscape = W > H`. Các board hiện có đều W ≤ H nên
  không đổi gì.
- Khi `landscape`, màn Usage được dựng bởi file mới `firmware/src/ui_dual.{h,cpp}`
  (build + update), thay cho hai panel xếp chồng. Mascot góc và icon pin không dựng ở bố cục này.
- Không thêm `#ifdef BOARD_*` vào code dùng chung.

## Dữ liệu và giao thức BLE

Thêm trường Codex vào JSON daemon gửi (cùng cấu trúc với trường Claude):

| Khóa | Kiểu | Ý nghĩa |
|---|---|---|
| `cok` | bool | Có số Codex hợp lệ |
| `cs` / `csr` | float / int | Codex 5h: % / phút tới lúc reset |
| `cw` / `cwr` | float / int | Codex weekly: % / phút tới lúc reset |
| `ct` | long | Thời điểm đọc số Codex, cùng quy ước epoch giờ địa phương với `t` |

Ví dụ gói sau khi thêm (~170 byte, bộ đệm RX 512 byte):
`{"s":78,"sr":80,"w":35,"wr":5040,"st":"allowed","ok":true,"t":1789998120,"tf":24,"cok":true,"cs":52,"csr":185,"cw":61,"cwr":3360,"ct":1789998060}`

- `UsageData` thêm các trường Codex; `main.cpp` parse với giá trị mặc định khi thiếu khóa,
  nên daemon cũ vẫn dùng được (cột Codex sẽ hiện "No data").
- Giờ cập nhật Claude = `t` của gói `ok:true` gần nhất. Cũ khi quá 5 phút không nhận được
  gói `ok` mới (tính theo `millis()`).
- Giờ cập nhật Codex = `ct`. Cũ khi (giờ hiện tại suy ra từ `t` + thời gian trôi qua) − `ct`
  > 300 s.

## Daemon (chỉ bản Windows)

- File mới `daemon/codex_usage.py`, port từ `usage-lcd/bridge/usage_bridge.py`:
  - `CodexLive`: một tiến trình `codex app-server` sống lâu, gọi JSON-RPC
    `account/rateLimits/read` mỗi 60 s. Codex CLI tự lo đăng nhập. Tiến trình con chạy với
    `CREATE_NO_WINDOW` để tray app không bật cửa sổ console.
  - Dự phòng: đọc sự kiện `rate_limits` mới nhất trong `~/.codex/sessions/**/rollout-*.jsonl`
    (chọn theo timestamp bên trong sự kiện).
  - `add_codex_fields(payload)` điền các khóa ở trên; lỗi hoặc không có số → `cok:false`.
- `claude_usage_daemon_windows.py` gọi `add_codex_fields` cạnh `add_clock_fields`.
  Phần Claude không đổi.
- Không có `codex` trên PATH thì chỉ dùng log, không báo lỗi lên tray.

## Port board

- Thư mục `firmware/src/boards/devkitc_st7796/` tạo từ `template/`, theo mẫu `waveshare_lcd_154`:
  - `display.cpp`: `Arduino_ESP32SPI(9, 10, 12, 11, 13)` + `Arduino_ST7796(bus, 14, 1, ips=false, 320, 480)`,
    `begin(40000000)`, đèn nền `ledcAttach(16, …)`. Màu và đảo màu kiểm tra trên phần cứng.
  - `touch.cpp`: đọc FT6336U inline như `lcd_154` (thanh ghi 0x02..0x06, địa chỉ 0x38),
    xung reset trên GPIO 6, rồi đổi trục cho rotation 1: `x = raw_y`, `y = 319 − raw_x`
    (xác nhận trên phần cứng).
  - `input.cpp`: GPIO 0 → PRIMARY. `power.cpp` / `imu.cpp`: stub (không có pin/IMU).
  - `board_init.cpp`: `Wire.begin(4, 5)`, SD CS HIGH.
  - `caps.cpp`: 480×320, `button_count = 1`, không battery / rotation / IMU.
- Env `[env:devkitc_st7796]` trong `platformio.ini`: sao từ `waveshare_lcd_154` (16 MB, `qio_opi`,
  `default_16MB.csv`), đổi `build_src_filter`, `-DBOARD_DEVKITC_ST7796`, `ARDUINO_USB_CDC_ON_BOOT=0`.
- Icon quả bơ: tải `avocado_3d.png` từ Fluent Emoji, resize 36×36 bằng Pillow, chuyển bằng
  `tools/png_to_lvgl.js --no-tint` → RGB565A8 trong `icons.h`. Ghi nguồn + giấy phép MIT ở README
  phần Credits.

## Kiểm tra

1. Sao lưu flash hiện tại: `esptool read-flash 0 0x1000000` → `%USERPROFILE%\Clawdmeter-backup\`
   (ngoài OneDrive và ngoài repo).
2. Build `devkitc_st7796` và thêm `waveshare_amoled_216` + `waveshare_lcd_154` để chắc code chung
   không hỏng. Chạy test native có sẵn trong `firmware/test`.
3. Daemon: `pytest daemon/tests`, thêm `test_codex_usage.py` (fixture JSONL có `rate_limits`,
   kiểm tra khóa payload, ca không có số).
4. Phần cứng: nạp qua COM6 → chụp bằng lệnh `screenshot` ở từng trạng thái (bình thường, 100%,
   không có Codex, số liệu cũ) → xem ảnh và chỉnh. Tạm đổi màn khởi động sang `SCREEN_USAGE`
   để chụp, sau đó trả lại.
5. Chạm để chuyển Splash ↔ Usage; nhấn BOOT gửi Space; ghép đôi BLE với Windows; chạy daemon và
   thấy số Claude + Codex thật.

## Ngoài phạm vi

Font tiếng Việt; nút Shift+Tab; simulator 480×320; Codex cho daemon macOS/Linux; PR lên repo gốc.

## Rủi ro

- Thứ tự màu RGB/BGR hoặc đảo màu của ST7796 sai → chỉnh tham số `ips` / MADCTL.
- Trục cảm ứng sai sau khi xoay → chỉnh công thức đổi trục trong `touch.cpp`.
- Nhiễu SPI 40 MHz qua dây jumper → hạ xuống 27 MHz.
- `codex app-server` đổi giao thức → vẫn còn đường dự phòng đọc log.
