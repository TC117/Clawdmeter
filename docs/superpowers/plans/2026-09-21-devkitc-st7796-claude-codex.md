# DevKitC + ST7796 port with Claude/Codex dual view — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run Clawdmeter on a hand-wired ESP32-S3-DevKitC-1 N16R8 + MSP4031 (ST7796S 480×320, FT6336U) with a landscape usage view: clock on top, Claude and Codex columns, per-column last-update badge.

**Architecture:** New board folder `firmware/src/boards/devkitc_st7796/` + PlatformIO env. Shared UI gains a `landscape` layout flag; when set, `ui.cpp` delegates the live usage view to a new `ui_dual.{h,cpp}`. The Windows daemon adds Codex fields (`cok/cs/csr/cw/cwr/ct`) from a new `daemon/codex_usage.py` (ported from the user's `usage-lcd` bridge); the Claude path is unchanged.

**Tech Stack:** PlatformIO (pioarduino 55.03.38-1, Arduino core 3.x), LVGL 9, GFX Library for Arduino ≥1.6.4 (`Arduino_ST7796`), NimBLE, Python 3.13 daemon (bleak, httpx, pystray), pytest.

**Spec:** `docs/superpowers/specs/2026-09-21-devkitc-st7796-claude-codex-design.md`

## Global Constraints

- Branch: `feat/devkitc-st7796-claude-codex`. Commit messages end with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- No `#ifdef BOARD_*` in shared code (`main.cpp`, `ui.cpp`, `ui_dual.cpp`, `splash.cpp`); layout decisions are runtime (`L.landscape`).
- Existing boards must still build: `waveshare_amoled_216` and `waveshare_lcd_154` after every firmware task.
- On-screen copy is English, ASCII only (fonts have no Vietnamese glyphs).
- Stale threshold: 300 s (both columns). Stale badge colour `0xc9a13a`, text on it `0x141413`. Codex accent `0x5dcaa5`, Claude accent `THEME_ACCENT` (`0xd97757`).
- Pins (spec table): LCD SCK 12, MOSI 11, MISO 13, CS 10, DC 9, RST 14, BL 16; CTP SDA 4, SCL 5, RST 6, INT 7, addr 0x38; SD_CS 15 held HIGH; BOOT GPIO 0. SPI 40 MHz. Rotation 1.
- Env `devkitc_st7796` sets `-DARDUINO_USB_CDC_ON_BOOT=0` (cable is on the CH343 UART port, COM6).
- The serial port must be opened with DTR/RTS **deasserted** (`dtr=False, rts=False` before `open()`) or the CH343 auto-reset circuit reboots the board.
- Tool paths (PowerShell): `$PIO = "$env:USERPROFILE\.platformio\penv\Scripts\pio.exe"`; daemon venv `.venv` at repo root; QA venv `$env:TEMP\cm-esptool` (has esptool + pyserial).
- Payload keys added: `cok` bool, `cs`/`cw` float %, `csr`/`cwr` int minutes, `ct` long local-wall-clock epoch (same convention as `t`). Absent keys → firmware shows that window as unknown.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `daemon/codex_usage.py` | create | Codex readings (live app-server + session logs) → payload fields |
| `daemon/tests/test_codex_usage.py` | create | Unit tests for the above |
| `daemon/claude_usage_daemon_windows.py` | modify | Start live reader in `main()`, add Codex fields before each payload write |
| `daemon/tests/test_windows_codex_wiring.py` | create | Asserts the daemon merges Codex fields into written payloads |
| `firmware/src/data.h` | modify | Codex fields on `UsageData` |
| `firmware/src/main.cpp` | modify | Parse Codex keys |
| `firmware/src/boards/devkitc_st7796/*` | create | Board port (board.h, board_init, caps, display, touch, input, power, imu, sound) |
| `firmware/platformio.ini` | modify | `[env:devkitc_st7796]` |
| `assets/icons/avocado_36.png` | create | 36×36 source for the corner icon (Fluent Emoji, MIT) |
| `firmware/src/icons.h` | modify | `icon_avocado_data` RGB565A8 array |
| `firmware/src/theme.h` | modify | `THEME_CODEX`, `THEME_STALE`, `THEME_ON_STALE` |
| `firmware/src/ui_dual.h`, `ui_dual.cpp` | create | Landscape two-column view |
| `firmware/src/ui.cpp` | modify | `L.landscape`, landscape breakpoint, delegation to `ui_dual`, avocado corner icon |
| `README.md` | modify | Credits line for Fluent Emoji; short note on the new env |
| `CLAUDE.md` | modify | Board list + pins for the new port |

---

### Task 1: Codex reader module (daemon)

**Files:**
- Create: `daemon/codex_usage.py`
- Test: `daemon/tests/test_codex_usage.py`

**Interfaces:**
- Produces:
  - `newest_logged(sessions_dir: Path | None = None) -> tuple[float, dict] | None` — (seen_epoch_utc, rate_limits dict)
  - `codex_fields(reading: tuple[float, dict] | None, now: float) -> dict` — payload keys
  - `pick_reading(logged, live, now) -> tuple | None`
  - `start_live() -> CodexLive | None`
  - `add_codex_fields(payload: dict, now: float | None = None) -> None`

- [ ] **Step 1: Create the daemon venv with test deps**

```powershell
cd C:\Users\tinvt\OneDrive\Documents\GitHub\Clawdmeter
python -m venv .venv
.venv\Scripts\python.exe -m pip install -q -r daemon\requirements-windows.txt pytest
.venv\Scripts\python.exe -m pytest daemon/tests -q -x
```
Expected: existing suite passes (baseline). If any pre-existing test fails, record it and continue — do not fix unrelated tests.

- [ ] **Step 2: Write the failing tests** — `daemon/tests/test_codex_usage.py`

```python
#!/usr/bin/env python3
"""Unit tests for daemon/codex_usage.py — Codex limits for the two-column display.

Run: python -m pytest daemon/tests/test_codex_usage.py -q
"""
import json
import os

from daemon import codex_usage as cu

NOW = 1_790_000_000.0


def _event(ts_iso, primary_pct, secondary_pct, p_reset, s_reset):
    return {
        "timestamp": ts_iso,
        "type": "event_msg",
        "payload": {
            "type": "token_count",
            "rate_limits": {
                "limit_id": "codex",
                "primary": {"used_percent": primary_pct, "window_minutes": 300, "resets_at": p_reset},
                "secondary": {"used_percent": secondary_pct, "window_minutes": 10080, "resets_at": s_reset},
            },
        },
    }


def _write_session(dir_, name, events, mtime=None):
    path = dir_ / name
    lines = [json.dumps(e) for e in events]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    if mtime is not None:
        os.utime(path, (mtime, mtime))
    return path


def test_last_rate_limits_returns_newest_event_in_file(tmp_path):
    path = _write_session(tmp_path, "rollout-a.jsonl", [
        _event("2026-09-19T10:00:00.000Z", 10, 1, NOW + 60, NOW + 600),
        {"timestamp": "2026-09-19T10:01:00.000Z", "type": "other", "payload": {}},
        _event("2026-09-19T10:02:00.000Z", 20, 2, NOW + 60, NOW + 600),
    ])
    stamp, limits = cu.last_rate_limits(path)
    assert stamp == "2026-09-19T10:02:00.000Z"
    assert limits["primary"]["used_percent"] == 20


def test_newest_logged_prefers_event_timestamp_over_file_mtime(tmp_path):
    day = tmp_path / "2026" / "09"
    day.mkdir(parents=True)
    # Old reading in a file touched recently (resume/backup) must not win.
    _write_session(day, "rollout-old.jsonl",
                   [_event("2026-09-10T08:00:00.000Z", 90, 9, NOW + 60, NOW + 600)], mtime=NOW)
    _write_session(day, "rollout-new.jsonl",
                   [_event("2026-09-19T08:00:00.000Z", 30, 3, NOW + 60, NOW + 600)], mtime=NOW - 3600)
    seen, limits = cu.newest_logged(tmp_path)
    assert limits["primary"]["used_percent"] == 30
    assert seen == cu.iso_epoch("2026-09-19T08:00:00.000Z")


def test_newest_logged_none_without_sessions(tmp_path):
    assert cu.newest_logged(tmp_path) is None


def test_codex_fields_without_reading():
    assert cu.codex_fields(None, NOW) == {"cok": False}


def test_codex_fields_snake_case_log_format(monkeypatch):
    monkeypatch.setattr(cu, "local_epoch", lambda ts: int(ts) + 7 * 3600)
    limits = {
        "primary": {"used_percent": 29.4, "window_minutes": 300, "resets_at": NOW + 3600},
        "secondary": {"used_percent": 12.0, "window_minutes": 10080, "resets_at": NOW + 86400},
    }
    assert cu.codex_fields((NOW - 60, limits), NOW) == {
        "cok": True, "ct": int(NOW - 60) + 7 * 3600,
        "cs": 29, "csr": 60, "cw": 12, "cwr": 1440,
    }


def test_codex_fields_camel_case_live_format(monkeypatch):
    monkeypatch.setattr(cu, "local_epoch", lambda ts: int(ts))
    limits = {
        "primary": {"usedPercent": 52, "windowDurationMins": 300, "resetsAt": NOW + 185 * 60},
        "secondary": {"usedPercent": 61, "windowDurationMins": 10080, "resetsAt": NOW + 3360 * 60},
    }
    out = cu.codex_fields((NOW, limits), NOW)
    assert (out["cs"], out["csr"], out["cw"], out["cwr"]) == (52, 185, 61, 3360)


def test_codex_fields_drops_window_that_rolled_over(monkeypatch):
    monkeypatch.setattr(cu, "local_epoch", lambda ts: int(ts))
    limits = {
        "primary": {"used_percent": 80, "window_minutes": 300, "resets_at": NOW - 10},
        "secondary": {"used_percent": 40, "window_minutes": 10080, "resets_at": NOW + 600},
    }
    out = cu.codex_fields((NOW - 7200, limits), NOW)
    assert out["cok"] is True
    assert "cs" not in out and "csr" not in out
    assert (out["cw"], out["cwr"]) == (40, 10)


def test_pick_reading_prefers_fresh_live():
    logged = (NOW - 600, {"a": 1})
    live = (NOW - 30, {"b": 2})
    assert cu.pick_reading(logged, live, NOW) is live


def test_pick_reading_ignores_stale_live():
    logged = (NOW - 600, {"a": 1})
    live = (NOW - cu.CODEX_LIVE_MAX_AGE - 1, {"b": 2})
    assert cu.pick_reading(logged, live, NOW) is logged


def test_add_codex_fields_merges_into_payload(monkeypatch, tmp_path):
    monkeypatch.setattr(cu, "CODEX_SESSIONS", tmp_path)
    monkeypatch.setattr(cu, "_live", None)
    _write_session(tmp_path, "rollout-x.jsonl",
                   [_event("2026-09-19T08:00:00.000Z", 30, 3, NOW + 600, NOW + 6000)])
    payload = {"s": 1, "ok": True}
    cu.add_codex_fields(payload, now=NOW)
    assert payload["s"] == 1 and payload["ok"] is True
    assert payload["cok"] is True and payload["cs"] == 30 and payload["cw"] == 3


def test_add_codex_fields_survives_reader_errors(monkeypatch):
    def boom(*_a, **_k):
        raise OSError("disk gone")
    monkeypatch.setattr(cu, "newest_logged", boom)
    monkeypatch.setattr(cu, "_live", None)
    payload = {}
    cu.add_codex_fields(payload, now=NOW)
    assert payload == {"cok": False}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `.venv\Scripts\python.exe -m pytest daemon/tests/test_codex_usage.py -q`
Expected: collection error `ImportError: cannot import name 'codex_usage'`.

- [ ] **Step 4: Implement** — `daemon/codex_usage.py`

```python
#!/usr/bin/env python3
"""Codex rate limits for the Windows daemon's two-column (Claude | Codex) display.

Ported from the usage-lcd bridge. Two sources, newest wins:
  - live: one long-lived official `codex app-server`, asked `account/rateLimits/read`
    every CODEX_POLL seconds (the Codex CLI does its own auth; nothing here reads a
    credential)
  - logs: the newest `rate_limits` event in ~/.codex/sessions/**/rollout-*.jsonl

add_codex_fields(payload) adds cok/cs/csr/cw/cwr/ct for the firmware; see
docs/superpowers/specs/2026-09-21-devkitc-st7796-claude-codex-design.md.
"""
import glob
import json
import os
import queue
import shutil
import subprocess
import threading
import time
from datetime import datetime
from pathlib import Path

CODEX_SESSIONS = Path.home() / ".codex" / "sessions"
TAIL_BYTES = 512 * 1024
MAX_SESSION_FILES = 30
CODEX_POLL = 60          # live read interval (s)
CODEX_LIVE_MAX_AGE = 300  # older live readings lose to the session logs


def iso_epoch(value):
    """'2026-09-19T10:48:32.133Z' -> epoch seconds, or None if unusable."""
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
    except (AttributeError, TypeError, ValueError):
        return None


def last_rate_limits(path):
    """(timestamp, rate_limits) of the last event in a session log that carries limits."""
    with open(path, "rb") as f:
        f.seek(0, os.SEEK_END)
        f.seek(max(0, f.tell() - TAIL_BYTES))
        lines = f.read().split(b"\n")
    for raw in reversed(lines):
        if b'"rate_limits"' not in raw:
            continue
        try:
            event = json.loads(raw)
        except ValueError:
            continue  # the first line of the tail may be cut mid-record
        limits = (event.get("payload") or {}).get("rate_limits")
        if limits:
            return event.get("timestamp"), limits
    return None


def newest_logged(sessions_dir=None):
    """Newest (seen_epoch, limits) across recent session logs, or None.

    Picks by the timestamp INSIDE the event, not by file mtime: an old session file
    can be touched (resume, backup, indexer) and would otherwise feed a stale reading.
    """
    root = Path(sessions_dir or CODEX_SESSIONS)
    files = glob.glob(str(root / "**" / "rollout-*.jsonl"), recursive=True)
    files.sort(key=os.path.getmtime, reverse=True)
    newest = None
    for path in files[:MAX_SESSION_FILES]:
        try:
            found = last_rate_limits(path)
        except OSError:
            continue
        if not found:
            continue
        stamp, limits = found
        seen = iso_epoch(stamp) or os.path.getmtime(path)
        if newest is None or seen > newest[0]:
            newest = (seen, limits)
    return newest


def windows(limits, seen, now):
    """{"h5": (pct, reset_s), "wk": (pct, reset_s)} from snake_case (logs) or camelCase
    (app-server) limits. A window that reset after the reading was taken is dropped:
    usage in the new window is unknown until fresh data arrives, so don't claim 0%."""
    out = {}
    for block in (limits.get("primary"), limits.get("secondary")):
        if not block:
            continue
        minutes = block.get("window_minutes") or block.get("windowDurationMins") or 0
        key = "h5" if minutes <= 24 * 60 else "wk"
        epoch = block.get("resets_at") or block.get("resetsAt")
        if epoch is None and "resets_in_seconds" in block:
            epoch = seen + block["resets_in_seconds"]
        used = block.get("used_percent")
        if used is None:
            used = block.get("usedPercent")
        pct = max(0, min(100, round(used or 0)))
        if epoch is None:
            out[key] = (pct, minutes * 60)
        elif epoch > now:
            out[key] = (pct, int(epoch - now))
    return out


def local_epoch(ts):
    """UTC epoch -> the firmware's local wall-clock epoch (same convention as "t")."""
    return int(ts) + time.localtime(ts).tm_gmtoff


def codex_fields(reading, now):
    """Payload keys for one reading (or {"cok": False} when there is none)."""
    if not reading:
        return {"cok": False}
    seen, limits = reading
    w = windows(limits, seen, now)
    out = {"cok": True, "ct": local_epoch(seen)}
    if "h5" in w:
        out["cs"], out["csr"] = w["h5"][0], round(w["h5"][1] / 60)
    if "wk" in w:
        out["cw"], out["cwr"] = w["wk"][0], round(w["wk"][1] / 60)
    return out


def pick_reading(logged, live, now):
    """A live reading wins while it is fresh and at least as new as the logs."""
    if live and now - live[0] < CODEX_LIVE_MAX_AGE and (logged is None or live[0] >= logged[0]):
        return live
    return logged


class CodexLive:
    """Live Codex limits from the official `codex app-server` (OpenAI's documented JSON-RPC
    protocol for embedding Codex). One long-lived process asked every CODEX_POLL seconds;
    restarts itself if the process dies."""

    def __init__(self):
        self.reading = None  # (taken_at_epoch, rateLimits dict)
        self.err = None
        threading.Thread(target=self._run, daemon=True, name="codex-live").start()

    def _run(self):
        while True:
            try:
                self._session()
            except Exception as e:  # keep the daemon alive whatever the CLI does
                self.err = f"{type(e).__name__}: {e}"
            time.sleep(30)

    def _session(self):
        exe = shutil.which("codex")
        if not exe:
            raise RuntimeError("codex CLI not on PATH")
        no_window = getattr(subprocess, "CREATE_NO_WINDOW", 0)  # tray runs under pythonw
        proc = subprocess.Popen([exe, "app-server"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL, creationflags=no_window)
        lines = queue.Queue()
        threading.Thread(target=lambda: [lines.put(l) for l in proc.stdout], daemon=True).start()
        try:
            self._call(proc, lines, 1, "initialize",
                       {"clientInfo": {"name": "clawdmeter", "title": "Clawdmeter daemon", "version": "1.0"}})
            self._send(proc, {"method": "initialized"})
            req = 2
            while proc.poll() is None:
                result = self._call(proc, lines, req, "account/rateLimits/read")
                req += 1
                limits = (result or {}).get("rateLimits")
                if limits:
                    self.reading, self.err = (time.time(), limits), None
                time.sleep(CODEX_POLL)
        finally:
            try:
                proc.stdin.close()  # EOF lets the node shim and codex.exe exit together
            except OSError:
                pass
            if proc.poll() is None and os.name == "nt":
                subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True,
                               creationflags=no_window)
            elif proc.poll() is None:
                proc.kill()

    @staticmethod
    def _send(proc, msg):
        proc.stdin.write((json.dumps(msg) + "\n").encode())
        proc.stdin.flush()

    def _call(self, proc, lines, req_id, method, params=None):
        msg = {"method": method, "id": req_id}
        if params is not None:
            msg["params"] = params
        self._send(proc, msg)
        deadline = time.time() + 30
        while time.time() < deadline:
            try:
                raw = lines.get(timeout=1)
            except queue.Empty:
                if proc.poll() is not None:
                    raise RuntimeError("codex app-server exited")
                continue
            try:
                reply = json.loads(raw)
            except ValueError:
                continue  # notifications and stray output are not ours
            if reply.get("id") == req_id:
                if "error" in reply:
                    raise RuntimeError(f"{method}: {reply['error'].get('message')}")
                return reply.get("result")
        raise TimeoutError(method)


_live = None


def start_live():
    """Start the background app-server reader once; no-op without `codex` on PATH."""
    global _live
    if _live is None and shutil.which("codex"):
        _live = CodexLive()
    return _live


def add_codex_fields(payload, now=None):
    """Merge Codex keys into a Claude payload. Never raises: Codex trouble must not
    cost the Claude numbers, it just shows as "No data" in the Codex column."""
    now = time.time() if now is None else now
    try:
        reading = pick_reading(newest_logged(), _live.reading if _live else None, now)
    except Exception:
        reading = None
    payload.update(codex_fields(reading, now))
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `.venv\Scripts\python.exe -m pytest daemon/tests/test_codex_usage.py -q`
Expected: `11 passed`.

- [ ] **Step 6: Smoke-test against the real Codex logs on this PC**

Run: `.venv\Scripts\python.exe -c "import json,daemon.codex_usage as c; p={}; c.add_codex_fields(p); print(json.dumps(p))"`
Expected: a line like `{"cok": true, "ct": 17899..., "cw": 12, "cwr": ...}` (`cs` may be missing if the 5h window has already reset since the last Codex session — that is correct behaviour).

- [ ] **Step 7: Commit**

```powershell
git add daemon/codex_usage.py daemon/tests/test_codex_usage.py
git commit -m "daemon: add Codex rate-limit reader for the dual-column display"
```

---

### Task 2: Wire Codex fields into the Windows daemon

**Files:**
- Modify: `daemon/claude_usage_daemon_windows.py` (imports near line 28; `connect_and_run` near line 645; `main` near line 700)
- Test: `daemon/tests/test_windows_codex_wiring.py`

**Interfaces:**
- Consumes: `codex_usage.add_codex_fields(payload)`, `codex_usage.start_live()` (Task 1)
- Produces: every payload written after a successful Claude poll carries the Codex keys.

- [ ] **Step 1: Write the failing test** — `daemon/tests/test_windows_codex_wiring.py`

```python
#!/usr/bin/env python3
"""The Windows daemon merges Codex fields into each successful payload it writes.

Run: python -m pytest daemon/tests/test_windows_codex_wiring.py -q
"""
import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

import daemon.claude_usage_daemon_windows as d


def test_payload_written_to_device_includes_codex_fields():
    written = []

    class FakeSession:
        def __init__(self, client):
            self.refresh_requested = asyncio.Event()

        async def setup_refresh_subscription(self):
            return None

        async def write_payload(self, payload):
            written.append(dict(payload))
            stop.set()  # one cycle is enough
            return True

    client = MagicMock()
    client.is_connected = True
    client.connect = AsyncMock(return_value=True)
    client.disconnect = AsyncMock(return_value=True)
    stop = None

    async def run():
        nonlocal stop
        stop = asyncio.Event()
        with patch.object(d, "BleakClient", return_value=client), \
             patch.object(d, "Session", FakeSession), \
             patch.object(d, "read_token", return_value="tok"), \
             patch.object(d, "poll_api", AsyncMock(return_value={"s": 5, "ok": True})), \
             patch.object(d, "add_codex_fields", lambda p: p.update({"cok": True, "cs": 42})):
            await d.connect_and_run(MagicMock(), stop)

    asyncio.run(run())
    assert written and written[0]["cok"] is True and written[0]["cs"] == 42 and written[0]["s"] == 5
```

> Why these patches: `connect_and_run` (line 527) builds `BleakClient(device, address_type=..., use_cached_services=False)`, awaits `client.connect()`, checks `client.is_connected`, then wraps it in `Session(client)` (class at line 373). The fake session stops the loop after the first write so the test finishes in one cycle.

- [ ] **Step 2: Run to verify it fails**

Run: `.venv\Scripts\python.exe -m pytest daemon/tests/test_windows_codex_wiring.py -q`
Expected: FAIL — `AttributeError: ... has no attribute 'add_codex_fields'` (patch target missing).

- [ ] **Step 3: Implement**

After the `from bleak.exc import BleakError` import (line 27) add:

```python
try:
    from daemon.codex_usage import add_codex_fields, start_live as start_codex_live
except ImportError:  # run as a script: python daemon\claude_usage_daemon_windows.py
    from codex_usage import add_codex_fields, start_live as start_codex_live
```

In `connect_and_run`, change the successful-payload branch (currently `if payload is not None:` followed by `if await session.write_payload(payload):`) to:

```python
                    if payload is not None:
                        add_codex_fields(payload)  # Codex column (cok/cs/csr/cw/cwr/ct)
                        if await session.write_payload(payload):
```

In `main()`, right after `stop_event = asyncio.Event()` / `loop = asyncio.get_running_loop()`, add:

```python
    start_codex_live()  # background `codex app-server` reader; no-op without the Codex CLI
```

- [ ] **Step 4: Run the new test and the full daemon suite**

Run: `.venv\Scripts\python.exe -m pytest daemon/tests -q`
Expected: all pass (same count as the Step 1 baseline of Task 1 + 12 new).

- [ ] **Step 5: Commit**

```powershell
git add daemon/claude_usage_daemon_windows.py daemon/tests/test_windows_codex_wiring.py
git commit -m "daemon(windows): send Codex fields with each usage payload"
```

---

### Task 3: Firmware — Codex fields in `UsageData`

**Files:**
- Modify: `firmware/src/data.h`
- Modify: `firmware/src/main.cpp:109-123` (`parse_json`)

**Interfaces:**
- Produces (used by Task 6): `UsageData::codex_ok (bool)`, `codex_session_pct (float, -1 = unknown)`, `codex_session_reset_mins (int, -1 = unknown)`, `codex_weekly_pct (float, -1)`, `codex_weekly_reset_mins (int, -1)`, `codex_epoch (long, 0 = none)`.

- [ ] **Step 1: Add fields** — in `firmware/src/data.h`, before `bool ok;`:

```cpp
    // Codex column (landscape dual layout). Absent payload keys → unknown.
    bool  codex_ok;                  // daemon had a Codex reading ("cok")
    float codex_session_pct;         // 5h window %, -1 = unknown / rolled over
    int   codex_session_reset_mins;  // minutes until the 5h reset, -1 = unknown
    float codex_weekly_pct;          // weekly %, -1 = unknown
    int   codex_weekly_reset_mins;   // minutes until the weekly reset, -1 = unknown
    long  codex_epoch;               // local wall-clock epoch (s) of the reading, 0 = none
```

- [ ] **Step 2: Parse them** — in `parse_json`, after `out->clock_fmt = doc["tf"] | 24;`:

```cpp
    out->codex_ok = doc["cok"] | false;
    out->codex_session_pct = doc["cs"] | -1.0f;
    out->codex_session_reset_mins = doc["csr"] | -1;
    out->codex_weekly_pct = doc["cw"] | -1.0f;
    out->codex_weekly_reset_mins = doc["cwr"] | -1;
    out->codex_epoch = doc["ct"] | 0L;
```

- [ ] **Step 3: Build an existing env (the "test" for this task)**

Run: `& $PIO run -d firmware -e waveshare_lcd_154`
Expected: `SUCCESS`.

- [ ] **Step 4: Commit**

```powershell
git add firmware/src/data.h firmware/src/main.cpp
git commit -m "firmware: parse Codex usage fields from the daemon payload"
```

---

### Task 4: Board port `devkitc_st7796`

**Files:**
- Create: `firmware/src/boards/devkitc_st7796/{board.h,board_init.cpp,caps.cpp,display.cpp,touch.cpp,input.cpp,power.cpp,imu.cpp,sound.cpp}`
- Modify: `firmware/platformio.ini` (append env)

**Interfaces:**
- Produces: HAL implementations per `firmware/src/hal/*.h`; `board_caps()` = 480×320, `button_count = 1`, no battery/rotation/IMU.

- [ ] **Step 1: `board.h`**

```cpp
#pragma once

// ESP32-S3-DevKitC-1 N16R8 (YD clone) + MSP4031 4.0" TFT, hand-wired.
// ST7796S 320x480 over 4-wire SPI, used at rotation 1 (480x320 landscape), and
// an FT6336U capacitive touch controller on I2C. Pin map from the usage-lcd
// project that drove this exact wiring. No PMU, battery, IMU or codec.

#define BOARD_NAME           "DevKitC + ST7796 4.0"

// ---- Display geometry (after rotation) ----
#define LCD_WIDTH            480
#define LCD_HEIGHT           320
#define LCD_NATIVE_W         320        // ST7796 GRAM is portrait
#define LCD_NATIVE_H         480
#define LCD_ROTATION         1          // landscape; 3 if the image is upside down
#define LCD_SPI_HZ           40000000   // jumper wires: 40 MHz is the safe ceiling

// ---- SPI display pins (ST7796S) ----
#define LCD_CS               10
#define LCD_MOSI             11
#define LCD_SCLK             12
#define LCD_MISO             13         // wired, unused (write-only driver)
#define LCD_RST              14
#define LCD_DC               9
#define LCD_BL               16         // backlight, LEDC PWM
#define SD_CS                15         // MSP4031 SD slot, held HIGH (unused)

// ---- I2C bus (touch only) ----
#define IIC_SDA              4
#define IIC_SCL              5

// ---- Touch (FT6336U, minimal inline I2C reader) ----
#define TP_RST               6
#define TP_INT               7
#define FT6336_ADDR          0x38

// ---- Buttons ----
#define BTN_BOOT_GPIO        0          // BOOT — primary, Space (PTT)

// ---- Capability flags ----
#define BOARD_HAS_SECONDARY_BUTTON 0
#define BOARD_HAS_ROTATION         0
#define BOARD_HAS_IMU              0
#define BOARD_HAS_BATTERY          0
#define BOARD_HAS_IO_EXPANDER      0
#define BOARD_HAS_SOUND            0
```

- [ ] **Step 2: `board_init.cpp`, `caps.cpp`, `input.cpp`**

```cpp
// board_init.cpp
#include "board.h"
#include <Arduino.h>
#include <Wire.h>

// No expander or power-hold line: park the unused SD card's CS so it can't
// answer on the shared SPI pins, then bring up the touch I2C bus.
extern "C" void board_init(void) {
    pinMode(SD_CS, OUTPUT);
    digitalWrite(SD_CS, HIGH);
    Wire.begin(IIC_SDA, IIC_SCL, 400000);
}
```

```cpp
// caps.cpp
#include "../../hal/board_caps.h"
#include "board.h"

static const BoardCaps caps = {
    .name = BOARD_NAME,
    .width = LCD_WIDTH,
    .height = LCD_HEIGHT,
    .button_count = 1,          // BOOT only
    .has_rotation = (bool)BOARD_HAS_ROTATION,
    .has_battery  = (bool)BOARD_HAS_BATTERY,
    .has_imu      = (bool)BOARD_HAS_IMU,
};

const BoardCaps& board_caps(void) { return caps; }
```

```cpp
// input.cpp
#include "../../hal/input_hal.h"
#include "board.h"
#include <Arduino.h>

void input_hal_init(void) {
    pinMode(BTN_BOOT_GPIO, INPUT_PULLUP);
}

bool input_hal_is_held(InputButton btn) {
    return btn == INPUT_BTN_PRIMARY && digitalRead(BTN_BOOT_GPIO) == LOW;
}
```

- [ ] **Step 3: Stubs — `power.cpp`, `imu.cpp`, `sound.cpp`**

```cpp
// power.cpp
#include "../../hal/power_hal.h"

// USB-powered DevKit: no PMU, no battery, no PWR button (so no hold-to-pair
// gesture — re-pair by removing the device in Windows and adding it again).
void power_hal_init(void) {}
void power_hal_tick(void) {}
int  power_hal_battery_pct(void) { return -1; }
bool power_hal_is_charging(void) { return false; }
bool power_hal_is_vbus_in(void)  { return true; }
bool power_hal_pwr_pressed(void) { return false; }
bool power_hal_pwr_long_pressed(void) { return false; }
bool power_hal_pwr_released(void) { return false; }
```

```cpp
// imu.cpp
#include "../../hal/imu_hal.h"

void    imu_hal_init(void) {}
void    imu_hal_tick(void) {}
uint8_t imu_hal_rotation_quadrant(void) { return 0; }
```

```cpp
// sound.cpp
#include "../../hal/sound_hal.h"

// No codec or buzzer on this build.
void sound_hal_init(void) {}
void sound_hal_tick(void) {}
void sound_hal_play_reset(void) {}
```

- [ ] **Step 4: `display.cpp`**

```cpp
#include "../../hal/display_hal.h"
#include "board.h"
#include <Arduino.h>
#include <Arduino_GFX_Library.h>

// ST7796S over plain 4-wire SPI, same shape as the LCD-1.54 port. The panel is
// portrait-native; Arduino_GFX's rotation 1 turns it into the 480x320 frame
// LVGL draws in, so the flush path needs no CPU remapping. Brightness is PWM
// on the LED pin (the ST7796 has no brightness command).

static Arduino_DataBus* bus = nullptr;
static Arduino_ST7796*  gfx = nullptr;

void display_hal_init(void) {
    bus = new Arduino_ESP32SPI(LCD_DC, LCD_CS, LCD_SCLK, LCD_MOSI,
                               GFX_NOT_DEFINED /* MISO unused */);
    // ips=false: the usage-lcd LovyanGFX config ran this panel with invert=false.
    gfx = new Arduino_ST7796(bus, LCD_RST, LCD_ROTATION, false /* ips */,
                             LCD_NATIVE_W, LCD_NATIVE_H);
}

void display_hal_begin(void) {
    gfx->begin(LCD_SPI_HZ);
    gfx->fillScreen(0x0000);
    ledcAttach(LCD_BL, 12000 /* Hz */, 8 /* bits */);
    ledcWrite(LCD_BL, 200);
}

void display_hal_set_brightness(uint8_t level) {
    ledcWrite(LCD_BL, level);
}

void display_hal_fill_screen(uint16_t color) {
    if (gfx) gfx->fillScreen(color);
}

void display_hal_draw_bitmap(int32_t x, int32_t y, int32_t w, int32_t h,
                             const uint16_t* pixels) {
    if (gfx) gfx->draw16bitRGBBitmap(x, y, (uint16_t*)pixels, w, h);
}

void display_hal_tick(void) {}

// SPI TFT: no flush-region alignment requirement.
void display_hal_round_area(int32_t* x1, int32_t* y1, int32_t* x2, int32_t* y2) {
    (void)x1; (void)y1; (void)x2; (void)y2;
}
```

- [ ] **Step 5: `touch.cpp`**

```cpp
#include "../../hal/touch_hal.h"
#include "board.h"
#include <Arduino.h>
#include <Wire.h>

// Minimal FT6336U reader — FocalTech register layout, same as the inline
// readers in the LCD-1.54 / AMOLED-1.8 ports (keeps the tree copyleft-free):
//   reg 0x02:        low nibble = active touch count
//   reg 0x03 / 0x04: X high (low nibble) + X low
//   reg 0x05 / 0x06: Y high (low nibble) + Y low
// Coordinates come in the panel's native portrait frame (x 0..319, y 0..479)
// and are mapped to the rotation-1 landscape frame below.

static volatile bool     touch_data_ready = false;
static volatile bool     touch_pressed = false;
static volatile uint16_t touch_x = 0;
static volatile uint16_t touch_y = 0;

static void IRAM_ATTR touch_isr(void) {
    touch_data_ready = true;
}

static void touch_read_into_shared_state(void) {
    Wire.beginTransmission(FT6336_ADDR);
    Wire.write(0x02);
    if (Wire.endTransmission(false) != 0) { touch_pressed = false; return; }
    if (Wire.requestFrom((uint8_t)FT6336_ADDR, (uint8_t)5) != 5) { touch_pressed = false; return; }
    uint8_t touches = Wire.read() & 0x0F;
    uint8_t xH = Wire.read();
    uint8_t xL = Wire.read();
    uint8_t yH = Wire.read();
    uint8_t yL = Wire.read();
    if (touches == 0 || touches > 2) {   // FT6336 tracks at most 2 points
        touch_pressed = false;
        return;
    }
    uint16_t rx = ((uint16_t)(xH & 0x0F) << 8) | xL;
    uint16_t ry = ((uint16_t)(yH & 0x0F) << 8) | yL;
    // Portrait (rx, ry) → rotation-1 landscape (x, y).
    touch_x = ry;
    touch_y = (rx < LCD_NATIVE_W) ? (LCD_NATIVE_W - 1 - rx) : 0;
    touch_pressed = true;
}

void touch_hal_init(void) {
    pinMode(TP_RST, OUTPUT);
    digitalWrite(TP_RST, LOW);
    delay(10);
    digitalWrite(TP_RST, HIGH);
    delay(300);   // FT6336U needs ~300 ms after reset before it answers

    // FocalTech vendor id lives at reg 0xA8.
    Wire.beginTransmission(FT6336_ADDR);
    Wire.write(0xA8);
    if (Wire.endTransmission(false) == 0 &&
        Wire.requestFrom((uint8_t)FT6336_ADDR, (uint8_t)1) == 1) {
        Serial.printf("Touch FT6336 vendor=0x%02X (addr 0x%02X)\n", Wire.read(), FT6336_ADDR);
    } else {
        Serial.printf("Touch ID read failed (addr 0x%02X)\n", FT6336_ADDR);
    }

    pinMode(TP_INT, INPUT_PULLUP);
    attachInterrupt(TP_INT, touch_isr, FALLING);
}

void touch_hal_read(uint16_t* x, uint16_t* y, bool* pressed) {
    if (touch_data_ready) {
        touch_data_ready = false;
        touch_read_into_shared_state();
    } else if (touch_pressed) {
        // Re-read while down so a missed release edge can't leave us stuck pressed.
        touch_read_into_shared_state();
    }
    *x = touch_x;
    *y = touch_y;
    *pressed = touch_pressed;
}
```

- [ ] **Step 6: PlatformIO env** — append to `firmware/platformio.ini` before `[env:sim]`:

```ini
[env:devkitc_st7796]
; ESP32-S3-DevKitC-1 N16R8 (YD clone) + MSP4031 4.0" TFT, hand-wired —
; ST7796S 480x320 (SPI, rotation 1) + FT6336U touch @ 0x38, BOOT button only.
; N16R8: 16 MB quad flash + 8 MB octal PSRAM (esptool-verified), hence
; qio_opi and the 16 MB partition layout.
platform = https://github.com/pioarduino/platform-espressif32/releases/download/55.03.38-1/platform-espressif32.zip
board = esp32-s3-devkitc-1
framework = arduino
board_build.arduino.memory_type = qio_opi
board_upload.flash_size = 16MB
board_upload.maximum_size = 16777216
board_build.partitions = default_16MB.csv
upload_speed = 921600
monitor_speed = 115200

build_src_filter =
    +<*>
    -<boards/>
    +<boards/devkitc_st7796/>

build_flags =
    -DBOARD_DEVKITC_ST7796
    ; The cable goes in the DevKit's UART (CH343) port, so Serial must stay on
    ; UART0. With CDC_ON_BOOT=1 the logs and the `screenshot` command would go
    ; to the native USB port, which isn't connected.
    -DARDUINO_USB_CDC_ON_BOOT=0
    -DBOARD_HAS_PSRAM
    -DCONFIG_BT_NIMBLE_ROLE_BROADCASTER=1
    -DCONFIG_BT_NIMBLE_ROLE_PERIPHERAL=1
    -DCONFIG_BT_NIMBLE_ROLE_CENTRAL=0
    -DCONFIG_BT_NIMBLE_ROLE_OBSERVER=0
    -DCONFIG_BT_NIMBLE_MAX_CONNECTIONS=2
    ; Peripheral Preferred Connection Parameters — see the waveshare_amoled_216
    ; env for the rationale (Windows supervision-timeout churn fix).
    -DMYNEWT_VAL_BLE_SVC_GAP_PPCP_MIN_CONN_INTERVAL=12
    -DMYNEWT_VAL_BLE_SVC_GAP_PPCP_MAX_CONN_INTERVAL=24
    -DMYNEWT_VAL_BLE_SVC_GAP_PPCP_SLAVE_LATENCY=0
    -DMYNEWT_VAL_BLE_SVC_GAP_PPCP_SUPERVISION_TMO=600
    -DLV_CONF_SKIP
    -DLV_COLOR_DEPTH=16
    -DLV_USE_LOG=0
    -DLV_USE_BAR=1
    -DLV_USE_LABEL=1
    -DLV_USE_ARC=1
    -DLV_USE_BTN=1
    -DLV_USE_LINE=1
    -DLV_USE_OBJ=1
    -DLV_USE_IMG=1
    -DLV_USE_IMAGE=1
    -DLV_USE_ANIMIMG=0
    -DLV_TICK_CUSTOM=1
    -DLV_USE_SNAPSHOT=1

lib_deps =
    ; 1.6.4+ has Arduino_ST7796 and builds against Arduino Core 3.x
    moononournation/GFX Library for Arduino@^1.6.4
    lvgl/lvgl@^9.2.0
    bblanchon/ArduinoJson@^7.0.0
    h2zero/NimBLE-Arduino@^2.1.1
```

- [ ] **Step 7: Build**

Run: `& $PIO run -d firmware -e devkitc_st7796`
Expected: `SUCCESS`. (UI is still the old portrait layout at this point — Task 6 fixes that. Do not flash yet.)
If the link fails on `sound_hal_*`/`es8311`/`chime` symbols, compare against `boards/waveshare_amoled_206/` (also sound-less) and match what it provides.

- [ ] **Step 8: Commit**

```powershell
git add firmware/src/boards/devkitc_st7796 firmware/platformio.ini
git commit -m "firmware: add devkitc_st7796 board port (ST7796S 480x320 + FT6336U)"
```

---

### Task 5: Avocado corner icon asset

**Files:**
- Create: `assets/icons/avocado_36.png`
- Modify: `firmware/src/icons.h` (append)
- Modify: `README.md` (Credits)

**Interfaces:**
- Produces: `ICON_AVOCADO_W` (36), `ICON_AVOCADO_H` (36), `static const uint8_t icon_avocado_data[3888]` (RGB565A8, planar).

- [ ] **Step 1: Download and resize** (Fluent Emoji, MIT — https://github.com/microsoft/fluentui-emoji)

```powershell
$tmp = "$env:TEMP\cm-esptool"
& "$tmp\Scripts\python.exe" -m pip install -q pillow
Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/microsoft/fluentui-emoji/main/assets/Avocado/3D/avocado_3d.png" -OutFile "$tmp\avocado_3d.png"
New-Item -ItemType Directory -Force assets\icons | Out-Null
& "$tmp\Scripts\python.exe" -c "from PIL import Image; Image.open(r'$tmp\avocado_3d.png').convert('RGBA').resize((36,36), Image.LANCZOS).save(r'assets\icons\avocado_36.png')"
```
Expected: `assets\icons\avocado_36.png` exists, 36×36 with alpha.

- [ ] **Step 2: Convert with the repo tool** (needs `pngjs`; install outside the repo)

```powershell
npm install --prefix "$env:TEMP\cm-node" pngjs --silent
$env:NODE_PATH = "$env:TEMP\cm-node\node_modules"
node tools\png_to_lvgl.js assets\icons\avocado_36.png icon_avocado_data ICON_AVOCADO_W ICON_AVOCADO_H --no-tint > "$env:TEMP\cm-node\avocado.h"
Get-Content "$env:TEMP\cm-node\avocado.h" -TotalCount 3
```
Expected: `#define ICON_AVOCADO_W 36`, `#define ICON_AVOCADO_H 36`, `static const uint8_t icon_avocado_data[3888] = {`.

- [ ] **Step 3: Append to `firmware/src/icons.h`** with a provenance comment:

```powershell
Add-Content -Encoding utf8 firmware\src\icons.h "`n// Avocado 36x36 RGB565A8 — Fluent Emoji 'Avocado' 3D (Microsoft, MIT).`n// Source: assets/icons/avocado_36.png, converted with tools/png_to_lvgl.js --no-tint."
Get-Content "$env:TEMP\cm-node\avocado.h" | Add-Content -Encoding utf8 firmware\src\icons.h
```

- [ ] **Step 4: Credit** — in `README.md` under `## Credits`, add after the Lucide line:

```markdown
- Avocado corner icon on the landscape layout: [Fluent Emoji](https://github.com/microsoft/fluentui-emoji) (Microsoft, MIT).
```

- [ ] **Step 5: Build (the icon is unused until Task 6, the build proves the header compiles)**

Run: `& $PIO run -d firmware -e devkitc_st7796`
Expected: `SUCCESS`.

- [ ] **Step 6: Commit**

```powershell
git add assets/icons/avocado_36.png firmware/src/icons.h README.md
git commit -m "assets: add avocado corner icon (Fluent Emoji, MIT)"
```

---

### Task 6: Landscape dual view (`ui_dual`) + `ui.cpp` integration

**Files:**
- Create: `firmware/src/ui_dual.h`, `firmware/src/ui_dual.cpp`
- Modify: `firmware/src/theme.h`
- Modify: `firmware/src/ui.cpp` (Layout struct ~27; `compute_layout` 75-179; `init_usage_screen` 501-530; `ui_init` 566-580; `ui_update` 593-609; `update_view_state` 682-699; `ui_tick_anim` 706-727)

**Interfaces:**
- Consumes: `UsageData` Codex fields (Task 3); `ICON_AVOCADO_W/H`, `icon_avocado_data` (Task 5).
- Produces:
  - `void ui_dual_build(lv_obj_t* container, lv_obj_t* group);`
  - `void ui_dual_update(const UsageData* d, long now_epoch);`
  - `void ui_dual_tick(long now_epoch, uint32_t claude_age_ms);`
  - `void ui_dual_set_live(bool live);`

- [ ] **Step 1: Theme tokens** — append to `firmware/src/theme.h`:

```cpp
#define THEME_CODEX    lv_color_hex(0x5dcaa5)   // Codex column accent (landscape dual view)
#define THEME_STALE    lv_color_hex(0xc9a13a)   // stale-data badge / link-down dot
#define THEME_ON_STALE lv_color_hex(0x141413)   // text on THEME_STALE
```

- [ ] **Step 2: `firmware/src/ui_dual.h`**

```cpp
#pragma once
#include <lvgl.h>
#include "data.h"

// Landscape (W > H) live usage view: Claude and Codex side by side, each with
// 5h + Weekly and a last-update badge. The clock above them stays owned by
// ui.cpp. ui.cpp calls these only when its layout is landscape.

// Panels go in `group` (hidden with the rest of the live view); the link dot
// goes in `container` so it stays visible on the pairing / idle views.
void ui_dual_build(lv_obj_t* container, lv_obj_t* group);

// Apply an ok:true payload. now_epoch = device local wall-clock epoch (s),
// 0 when the daemon sends no clock.
void ui_dual_update(const UsageData* d, long now_epoch);

// Re-evaluate badge staleness. Cheap when nothing changed; call every loop.
void ui_dual_tick(long now_epoch, uint32_t claude_age_ms);

// Link dot: green while the live usage view shows, amber otherwise.
void ui_dual_set_live(bool live);
```

- [ ] **Step 3: `firmware/src/ui_dual.cpp`**

```cpp
#include "ui_dual.h"
#include <time.h>
#include "theme.h"

LV_FONT_DECLARE(font_styrene_48);
LV_FONT_DECLARE(font_styrene_20);
LV_FONT_DECLARE(font_styrene_16);
LV_FONT_DECLARE(font_styrene_14);

// Geometry for 480x320, from the approved mockup (spec §Màn Usage).
static const int MARGIN    = 12;
static const int PANEL_Y   = 56;
static const int PANEL_W   = 222;
static const int PANEL_H   = 252;
static const int PANEL_GAP = 12;
static const int PAD       = 16;
static const int SEC_Y[2]  = {48, 152};   // % top per section
static const int BAR_DY    = 56;          // bar top below the % top
static const int RESET_DY  = 72;          // reset line below the % top
static const int BAR_H     = 10;
static const long STALE_S  = 300;

struct Section { lv_obj_t* pct; lv_obj_t* bar; lv_obj_t* reset; };
struct Column  {
    lv_obj_t* badge;
    Section   sec[2];          // 0 = 5h, 1 = Weekly
    long      stamp;           // epoch shown in the badge, 0 = none
    bool      stale_shown;
};
enum { CLAUDE = 0, CODEX = 1 };

static Column    cols[2];
static lv_obj_t* link_dot = nullptr;
static int       clock_fmt = 24;

static lv_obj_t* make_label(lv_obj_t* parent, const lv_font_t* font,
                            lv_color_t color, const char* text) {
    lv_obj_t* l = lv_label_create(parent);
    lv_label_set_text(l, text);
    lv_obj_set_style_text_font(l, font, 0);
    lv_obj_set_style_text_color(l, color, 0);
    return l;
}

static void format_reset(int mins, char* buf, size_t len) {
    if (mins < 0)           snprintf(buf, len, "---");
    else if (mins < 60)     snprintf(buf, len, "Resets in %dm", mins);
    else if (mins < 1440)   snprintf(buf, len, "Resets in %dh %02dm", mins / 60, mins % 60);
    else                    snprintf(buf, len, "Resets in %dd %02dh", mins / 1440, (mins % 1440) / 60);
}

static void format_hhmm(long epoch, char* buf, size_t len) {
    if (epoch <= 0) { snprintf(buf, len, "--:--"); return; }
    time_t t = (time_t)epoch;
    struct tm tmv;
    gmtime_r(&t, &tmv);   // epoch is already local wall-clock
    if (clock_fmt == 12) {
        int h = tmv.tm_hour % 12;
        if (h == 0) h = 12;
        snprintf(buf, len, "%d:%02d %s", h, tmv.tm_min, tmv.tm_hour < 12 ? "AM" : "PM");
    } else {
        snprintf(buf, len, "%02d:%02d", tmv.tm_hour, tmv.tm_min);
    }
}

static void build_column(lv_obj_t* group, int idx, int x, const char* name, lv_color_t accent) {
    Column& c = cols[idx];

    lv_obj_t* panel = lv_obj_create(group);
    lv_obj_set_pos(panel, x, PANEL_Y);
    lv_obj_set_size(panel, PANEL_W, PANEL_H);
    lv_obj_set_style_bg_color(panel, THEME_PANEL, 0);
    lv_obj_set_style_bg_opa(panel, LV_OPA_COVER, 0);
    lv_obj_set_style_radius(panel, 12, 0);
    lv_obj_set_style_border_width(panel, 0, 0);
    lv_obj_set_style_pad_all(panel, 0, 0);
    lv_obj_clear_flag(panel, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_add_flag(panel, LV_OBJ_FLAG_EVENT_BUBBLE);

    lv_obj_t* title = make_label(panel, &font_styrene_20, accent, name);
    lv_obj_set_pos(title, PAD, 10);

    c.badge = make_label(panel, &font_styrene_14, THEME_DIM, "--:--");
    lv_obj_set_style_bg_color(c.badge, THEME_BAR_BG, 0);
    lv_obj_set_style_bg_opa(c.badge, LV_OPA_COVER, 0);
    lv_obj_set_style_radius(c.badge, LV_RADIUS_CIRCLE, 0);
    lv_obj_set_style_pad_left(c.badge, 8, 0);
    lv_obj_set_style_pad_right(c.badge, 8, 0);
    lv_obj_set_style_pad_top(c.badge, 2, 0);
    lv_obj_set_style_pad_bottom(c.badge, 2, 0);
    lv_obj_align(c.badge, LV_ALIGN_TOP_RIGHT, -12, 12);
    c.stamp = 0;
    c.stale_shown = false;

    static const char* const names[2] = {"5h", "Weekly"};
    for (int s = 0; s < 2; s++) {
        Section& sec = c.sec[s];
        sec.pct = make_label(panel, &font_styrene_48, THEME_DIM, "--%");
        lv_obj_set_pos(sec.pct, PAD, SEC_Y[s]);

        lv_obj_t* lbl = make_label(panel, &font_styrene_14, THEME_DIM, names[s]);
        lv_obj_align(lbl, LV_ALIGN_TOP_RIGHT, -PAD, SEC_Y[s] + 4);

        sec.bar = lv_bar_create(panel);
        lv_obj_set_pos(sec.bar, PAD, SEC_Y[s] + BAR_DY);
        lv_obj_set_size(sec.bar, PANEL_W - 2 * PAD, BAR_H);
        lv_bar_set_range(sec.bar, 0, 100);
        lv_bar_set_value(sec.bar, 0, LV_ANIM_OFF);
        lv_obj_set_style_bg_color(sec.bar, THEME_BAR_BG, LV_PART_MAIN);
        lv_obj_set_style_bg_opa(sec.bar, LV_OPA_COVER, LV_PART_MAIN);
        lv_obj_set_style_radius(sec.bar, 5, LV_PART_MAIN);
        lv_obj_set_style_bg_color(sec.bar, accent, LV_PART_INDICATOR);
        lv_obj_set_style_bg_opa(sec.bar, LV_OPA_COVER, LV_PART_INDICATOR);
        lv_obj_set_style_radius(sec.bar, 5, LV_PART_INDICATOR);

        sec.reset = make_label(panel, &font_styrene_16, THEME_DIM, "No data");
        lv_obj_set_pos(sec.reset, PAD, SEC_Y[s] + RESET_DY);
    }
}

static void set_section(Section& s, float pct, int reset_mins) {
    if (pct < 0) {
        lv_label_set_text(s.pct, "--%");
        lv_obj_set_style_text_color(s.pct, THEME_DIM, 0);
        lv_bar_set_value(s.bar, 0, LV_ANIM_OFF);
        lv_label_set_text(s.reset, "No data");
        return;
    }
    int p = (int)(pct + 0.5f);
    lv_label_set_text_fmt(s.pct, "%d%%", p);
    lv_obj_set_style_text_color(s.pct, THEME_TEXT, 0);
    lv_bar_set_value(s.bar, p > 100 ? 100 : p, LV_ANIM_ON);
    char buf[32];
    format_reset(reset_mins, buf, sizeof(buf));
    lv_label_set_text(s.reset, buf);
}

static void set_badge_stale(Column& c, bool stale) {
    if (stale == c.stale_shown) return;
    c.stale_shown = stale;
    lv_obj_set_style_bg_color(c.badge, stale ? THEME_STALE : THEME_BAR_BG, 0);
    lv_obj_set_style_text_color(c.badge, stale ? THEME_ON_STALE : THEME_DIM, 0);
}

void ui_dual_build(lv_obj_t* container, lv_obj_t* group) {
    build_column(group, CLAUDE, MARGIN, "Claude", THEME_ACCENT);
    build_column(group, CODEX, MARGIN + PANEL_W + PANEL_GAP, "Codex", THEME_CODEX);

    link_dot = lv_obj_create(container);
    lv_obj_set_size(link_dot, 10, 10);
    lv_obj_set_pos(link_dot, 480 - MARGIN - 8 - 10, 19);
    lv_obj_set_style_radius(link_dot, LV_RADIUS_CIRCLE, 0);
    lv_obj_set_style_border_width(link_dot, 0, 0);
    lv_obj_set_style_bg_opa(link_dot, LV_OPA_COVER, 0);
    lv_obj_set_style_bg_color(link_dot, THEME_STALE, 0);
    lv_obj_clear_flag(link_dot, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_add_flag(link_dot, LV_OBJ_FLAG_EVENT_BUBBLE);
}

void ui_dual_update(const UsageData* d, long now_epoch) {
    clock_fmt = d->clock_fmt;

    set_section(cols[CLAUDE].sec[0], d->session_pct, d->session_reset_mins);
    set_section(cols[CLAUDE].sec[1], d->weekly_pct, d->weekly_reset_mins);
    cols[CLAUDE].stamp = now_epoch;

    if (d->codex_ok) {
        set_section(cols[CODEX].sec[0], d->codex_session_pct, d->codex_session_reset_mins);
        set_section(cols[CODEX].sec[1], d->codex_weekly_pct, d->codex_weekly_reset_mins);
    } else {
        set_section(cols[CODEX].sec[0], -1.0f, -1);
        set_section(cols[CODEX].sec[1], -1.0f, -1);
    }
    cols[CODEX].stamp = d->codex_ok ? d->codex_epoch : 0;

    char buf[12];
    for (Column& c : cols) {
        format_hhmm(c.stamp, buf, sizeof(buf));
        lv_label_set_text(c.badge, buf);
    }
    ui_dual_tick(now_epoch, 0);
}

void ui_dual_tick(long now_epoch, uint32_t claude_age_ms) {
    set_badge_stale(cols[CLAUDE], claude_age_ms > (uint32_t)STALE_S * 1000u);
    const long codex_ts = cols[CODEX].stamp;
    set_badge_stale(cols[CODEX], codex_ts > 0 && now_epoch > 0 && now_epoch - codex_ts > STALE_S);
}

void ui_dual_set_live(bool live) {
    if (link_dot) lv_obj_set_style_bg_color(link_dot, live ? THEME_GREEN : THEME_STALE, 0);
}
```

Note: `link_dot` x uses the literal 480 because the dual view is only built at 480×320; if another landscape size is ever added, pass `L.scr_w` in via `ui_dual_build`.

- [ ] **Step 4: `ui.cpp` — include + Layout flag**

After `#include "icons.h"` add `#include "ui_dual.h"`.
In `struct Layout`, after `int16_t scr_w, scr_h;` add:

```cpp
    bool    landscape;               // W > H → two-column Claude/Codex view (ui_dual.cpp)
```

- [ ] **Step 5: `ui.cpp` — landscape breakpoint in `compute_layout`**

After `L.scr_h = c.height;` add `L.landscape = c.width > c.height;`.
Change `if (c.height >= 460) {` to `if (L.landscape) { ...block below... } else if (c.height >= 460) {`, with this block:

```cpp
        // Landscape — tuned for 480x320 (DevKitC + ST7796). The live view is
        // the two-column Claude/Codex layout in ui_dual.cpp; these values place
        // the shared chrome (clock, pairing hint, idle creature, status line).
        L.margin = 12;
        L.title_y = 4;
        L.content_y = 56;
        L.usage_panel_h = 0;       // unused: ui_dual.cpp owns the panels
        L.usage_panel_gap = 0;
        L.usage_bar_y = 0;
        L.usage_reset_y = 0;
        L.title_font = &font_tiempos_34;
        L.anim_font = &font_mono_18;
        L.anim_y = -12;
        L.small_icons = true;
        L.title_nudge = 0;
        L.logo_y = 6;
        L.batt_y = 10;
        L.batt_w = ICON_BATTERY_SMALL_W;
        L.pair_y1 = 40;
        L.pair_y2 = 100;
        L.pair_y3 = 130;
        L.idle_px = 120;
        L.bt_info_panel_h = 90;
        L.bt_reset_zone_h = 60;
        L.bt_title_font    = &font_tiempos_34;
        L.bt_status_font   = &font_styrene_28;
        L.bt_device_font   = &font_styrene_20;
        L.bt_credit_1_font = &font_styrene_16;
        L.bt_credit_2_font = &font_styrene_14;
```

- [ ] **Step 6: `ui.cpp` — build the dual view instead of the stacked panels**

In `init_usage_screen`, wrap the block from `panel_session = make_usage_panel(...)` through `lv_label_set_recolor(lbl_weekly_reset, true);` as the `else` branch:

```cpp
    if (L.landscape) {
        ui_dual_build(usage_container, usage_group);
    } else {
        panel_session = make_usage_panel(usage_group, L.content_y, "Current",
        // ... existing lines unchanged ...
        lv_label_set_recolor(lbl_weekly_reset, true);
    }
```

- [ ] **Step 7: `ui.cpp` — avocado in the corner-mascot slot**

In `ui_init`, wrap the existing corner-mascot block `{ const int slot = ...; ... }` as the `else` branch of:

```cpp
    if (L.landscape) {
        // Landscape header: static avocado in the corner-mascot slot. logo_img
        // is already hidden on the splash by ui_show_screen().
        init_icon_dsc_rgb565a8(&logo_dsc, ICON_AVOCADO_W, ICON_AVOCADO_H, icon_avocado_data);
        logo_img = lv_image_create(scr);
        lv_image_set_src(logo_img, &logo_dsc);
        lv_obj_set_pos(logo_img, 14, 6);
    } else {
        // ... existing corner-mascot block unchanged ...
    }
```

- [ ] **Step 8: `ui.cpp` — epoch helper, update/tick/view-state hooks**

Above `void ui_update(`, add:

```cpp
// Device-local wall-clock epoch at lv_tick `now`, or 0 before the daemon sent a clock.
static long current_epoch(uint32_t now) {
    return clock_base_epoch > 0 ? clock_base_epoch + (long)((now - clock_base_ms) / 1000) : 0;
}
```

In `ui_update`, right after the clock `if/else if` block (before `int s_pct = ...`), add:

```cpp
    if (L.landscape) {
        ui_dual_update(data, current_epoch(last_data_ms));
        return;
    }
```

In `update_view_state`, after the final `lv_obj_clear_flag(... LV_OBJ_FLAG_HIDDEN);`, add:

```cpp
    if (L.landscape) {
        // The two columns fill the strip the status line would use, so it only
        // shows on the pairing / idle views here.
        if (lbl_anim) {
            if (v == 2) lv_obj_add_flag(lbl_anim, LV_OBJ_FLAG_HIDDEN);
            else        lv_obj_clear_flag(lbl_anim, LV_OBJ_FLAG_HIDDEN);
        }
        ui_dual_set_live(v == 2);
    }
```

In `ui_tick_anim`, replace `time_t cur = (time_t)(clock_base_epoch + (now - clock_base_ms) / 1000);` with `time_t cur = (time_t)current_epoch(now);`, and immediately after the whole `if (clock_base_epoch > 0) { ... }` block add:

```cpp
    if (L.landscape) ui_dual_tick(current_epoch(now), now - last_data_ms);
```

- [ ] **Step 9: Build all three envs**

```powershell
& $PIO run -d firmware -e devkitc_st7796
& $PIO run -d firmware -e waveshare_lcd_154
& $PIO run -d firmware -e waveshare_amoled_216
```
Expected: three `SUCCESS`.

- [ ] **Step 10: Commit**

```powershell
git add firmware/src/ui_dual.h firmware/src/ui_dual.cpp firmware/src/ui.cpp firmware/src/theme.h
git commit -m "ui: landscape two-column Claude/Codex view with last-update badges"
```

---

### Task 7: Hardware bring-up and visual QA

**Files:**
- Temporary (never committed): `firmware/src/main.cpp` demo hook; `$env:TEMP\cm-esptool\qa_shot.py`
- Possibly modify: `firmware/src/boards/devkitc_st7796/{display,touch}.cpp`, `firmware/src/ui_dual.cpp` (fixes found here)

**Interfaces:** none new.

- [ ] **Step 1: Confirm the flash backup exists** (made before planning)

Run: `(Get-Item "$env:USERPROFILE\Clawdmeter-backup\usage-lcd-firmware-2026-09-21.bin").Length`
Expected: `16777216`. Restore command, if ever needed: `& "$env:TEMP\cm-esptool\Scripts\python.exe" -m esptool --port COM6 write-flash 0 "$env:USERPROFILE\Clawdmeter-backup\usage-lcd-firmware-2026-09-21.bin"`.

- [ ] **Step 2: QA capture script** — `$env:TEMP\cm-esptool\qa_shot.py`

```python
"""Grab the LVGL framebuffer over the CH343 UART port without resetting the board."""
import sys

import serial
from PIL import Image

port, out = sys.argv[1], sys.argv[2]
s = serial.Serial()
s.port, s.baudrate, s.timeout = port, 115200, 10
s.dtr = False  # CH343 auto-reset: keep EN and IO0 released
s.rts = False
s.open()
s.reset_input_buffer()
s.write(b"screenshot\n")
s.flush()
while True:
    line = s.readline()
    if not line:
        sys.exit("timeout waiting for SCREENSHOT_START")
    if line.startswith(b"SCREENSHOT_ERR"):
        sys.exit("device reported SCREENSHOT_ERR")
    if line.startswith(b"SCREENSHOT_START"):
        _, w, h, n = line.split()
        w, h, n = int(w), int(h), int(n)
        break
data = bytearray()
while len(data) < n:
    chunk = s.read(min(4096, n - len(data)))
    if not chunk:
        sys.exit(f"short read {len(data)}/{n}")
    data += chunk
s.close()
img = Image.new("RGB", (w, h))
px = img.load()
for i in range(w * h):
    v = data[2 * i] | (data[2 * i + 1] << 8)   # rgb565 little-endian
    px[i % w, i // w] = (((v >> 11) & 0x1F) << 3, ((v >> 5) & 0x3F) << 2, (v & 0x1F) << 3)
img.save(out)
print(f"saved {out} {w}x{h}")
```

- [ ] **Step 3: Temporary demo hook** (do NOT commit) — in `main.cpp` `setup()`, replace `ui_show_screen(SCREEN_SPLASH);` with:

```cpp
    // QA ONLY — revert before commit. Fake a connected host + one payload.
    {
        static UsageData demo = {};
        const char* j = QA_DEMO_JSON;
        parse_json(j, &demo);
        ui_update_ble_status(BLE_STATE_CONNECTED, "", "");
        ui_update(&demo);
        ui_show_screen(SCREEN_USAGE);
    }
```

and near the top of `main.cpp` (after includes) add:

```cpp
#define QA_DEMO_JSON "{\"s\":78,\"sr\":80,\"w\":35,\"wr\":5040,\"ok\":true,\"t\":1789998120,\"tf\":24," \
                     "\"cok\":true,\"cs\":52,\"csr\":185,\"cw\":61,\"cwr\":3360,\"ct\":1789998060}"
```

- [ ] **Step 4: Flash and read the boot log**

```powershell
& $PIO run -d firmware -e devkitc_st7796 -t upload --upload-port COM6
& "$env:TEMP\cm-esptool\Scripts\python.exe" "$env:TEMP\cm-esptool\bootlog.py"
```
Expected in the log: `{"ready":true}`, `Touch FT6336 vendor=0x..`, `Dashboard ready (DevKitC + ST7796 4.0, 480x320)`. No `Guru Meditation` / reboot loop.

- [ ] **Step 5: Ask the user to eyeball the physical panel** (screenshots can't catch this — they read LVGL's buffer, not the glass):
  1. Background black (not white) → otherwise flip `ips` to `true` in `display.cpp`.
  2. "Claude" title orange, "Codex" title teal → if orange shows as blue, the panel's red/blue order is swapped. Open `firmware/.pio/libdeps/devkitc_st7796/GFX Library for Arduino/src/display/Arduino_ST7796.cpp`, find `setRotation()` and note which MADCTL value it writes for rotation 1 (it ORs `ST7796_MADCTL_BGR` or `ST7796_MADCTL_RGB`). In `display_hal_begin()`, after `gfx->begin(...)`, rewrite MADCTL with the other colour-order bit: `bus->beginWrite(); bus->writeC8D8(ST7796_MADCTL, <same value with BGR bit toggled>); bus->endWrite();`.
  3. Image not upside down → otherwise set `LCD_ROTATION 3` and swap the touch mapping to `touch_x = (LCD_NATIVE_H - 1) - ry; touch_y = rx;`.
  Reflash after each fix and re-ask.

- [ ] **Step 6: Screenshot the normal state and review**

Run: `& "$env:TEMP\cm-esptool\Scripts\python.exe" "$env:TEMP\cm-esptool\qa_shot.py" COM6 "$env:TEMP\cm-esptool\qa_normal.png"` then Read the PNG.
Expected: matches the mockup — clock `19:42` centred, avocado top-left, green dot top-right, Claude 78% / 35%, Codex 52% / 61%, badges `19:42` (Claude) and `19:41` (Codex), nothing clipped. Fix spacing in `ui_dual.cpp` constants if anything overlaps; rebuild, reflash, recapture.

- [ ] **Step 7: Worst case** — change `QA_DEMO_JSON` to `{"s":100,"sr":59,"w":100,"wr":10019,"ok":true,"t":1789998120,"tf":24,"cok":false}`, reflash, capture `qa_worst.png`.
Expected: "100%" does not collide with "Weekly"; "Resets in 6d 22h" fits; Codex shows `--%`, "No data", badge `--:--`.
If "100%" collides: reduce `font_styrene_48` → `font_styrene_28` for `sec.pct` only if no spacing tweak fixes it (tell the user; it changes the look).

- [ ] **Step 8: Stale badge** — `QA_DEMO_JSON` with `"ct":1789990000` (≈2 h old) and `cok:true`, reflash, capture `qa_stale.png`.
Expected: Codex badge amber with dark text `17:26`.

- [ ] **Step 9: Touch check** — ask the user to tap the screen; expected: Usage ↔ Splash toggles each tap; splash shows centred Clawd with black side bars; avocado hidden on the splash.

- [ ] **Step 10: Remove the demo hook, rebuild, reflash**

Revert `main.cpp` to `ui_show_screen(SCREEN_SPLASH);` and delete `QA_DEMO_JSON`. Run `git diff firmware/src/main.cpp` — expected: only the Task 3 parse lines differ from `main`.
Flash: `& $PIO run -d firmware -e devkitc_st7796 -t upload --upload-port COM6`.

- [ ] **Step 11: Commit any fixes found** (board/ui files only)

```powershell
git add firmware/src/boards/devkitc_st7796 firmware/src/ui_dual.cpp
git commit -m "devkitc_st7796: hardware bring-up fixes"
```
(Skip if nothing changed.)

---

### Task 8: End-to-end with the real daemon

**Files:**
- Modify: `CLAUDE.md` (board list + pins), `README.md` (hardware list line)
- Local only: `%LOCALAPPDATA%\Clawdmeter\config`

- [ ] **Step 1: Enable the clock in the daemon config**

```powershell
$cfg = "$env:LOCALAPPDATA\Clawdmeter\config"
New-Item -ItemType Directory -Force (Split-Path $cfg) | Out-Null
if (-not (Test-Path $cfg) -or -not (Select-String -Path $cfg -Pattern '^\s*clock\s*=' -Quiet)) { Add-Content -Encoding utf8 $cfg "clock=auto" }
Get-Content $cfg
```
Expected: file contains `clock=auto`.

- [ ] **Step 2: User pairs the board** — ask the user: Settings → Bluetooth & devices → Add device → Bluetooth → "Clawdmeter". Wait for confirmation.

- [ ] **Step 3: Run the daemon in the foreground for one cycle**

Run: `.venv\Scripts\python.exe daemon\claude_usage_daemon_windows.py` (stop with Ctrl+C after the first "write" log line, or run with a 90 s timeout).
Expected: log shows the device connected and a payload written; board switches from pairing hint to the two columns with real Claude numbers, clock, and Codex numbers (or `--%` if Codex has no recent session).

- [ ] **Step 4: Screenshot the live state**

Run: `& "$env:TEMP\cm-esptool\Scripts\python.exe" "$env:TEMP\cm-esptool\qa_shot.py" COM6 "$env:TEMP\cm-esptool\qa_live.png"` and Read it.
Expected: real values, green dot, Claude badge = current time.

- [ ] **Step 5: Install the tray daemon**

Run: `powershell -ExecutionPolicy Bypass -File install-windows.ps1`
Expected: installer finishes; tray icon appears; board keeps updating every ~60 s.

- [ ] **Step 6: Docs** — in `CLAUDE.md`, add to the port list:

```markdown
- `boards/devkitc_st7796/` — hand-wired ESP32-S3-DevKitC-1 N16R8 + MSP4031 4.0" (ST7796S SPI 480×320 landscape, rotation 1; FT6336U touch @ 0x38 on SDA 4 / SCL 5 / RST 6 / INT 7). Build env: `devkitc_st7796`. **Landscape → `ui_dual.cpp` two-column Claude | Codex view** (Codex fields `cok/cs/csr/cw/cwr/ct` from the Windows daemon's `codex_usage.py`). Serial is on the CH343 UART port (`ARDUINO_USB_CDC_ON_BOOT=0`); open it with DTR/RTS deasserted or the board resets. BOOT only; no PWR button, so no hold-to-pair.
```

and in `README.md` under "Boards supported out of the box" add:

```markdown
- Hand-wired ESP32-S3-DevKitC-1 N16R8 + MSP4031 4.0" ST7796S (480×320, landscape Claude + Codex view) — env `devkitc_st7796`
```

- [ ] **Step 7: Commit**

```powershell
git add CLAUDE.md README.md
git commit -m "docs: document the devkitc_st7796 port and Codex column"
```
