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


def test_add_codex_fields_survives_malformed_reading(monkeypatch):
    def malformed(*_a, **_k):
        return (NOW - 60, {"primary": "garbage", "secondary": {"used_percent": "n/a", "window_minutes": 10080, "resets_at": NOW + 600}})
    monkeypatch.setattr(cu, "newest_logged", malformed)
    monkeypatch.setattr(cu, "_live", None)
    payload = {}
    cu.add_codex_fields(payload, now=NOW)
    assert payload == {"cok": False}


def test_add_codex_fields_keeps_live_reading_when_log_scan_fails(monkeypatch):
    # A log-scan error must not discard a fresh live reading from the app-server.
    def boom(*_a, **_k):
        raise OSError("sessions dir unreadable")

    class LiveStub:
        reading = (NOW - 30, {
            "primary": {"usedPercent": 52, "windowDurationMins": 300, "resetsAt": NOW + 3600},
            "secondary": {"usedPercent": 61, "windowDurationMins": 10080, "resetsAt": NOW + 86400},
        })

    monkeypatch.setattr(cu, "newest_logged", boom)
    monkeypatch.setattr(cu, "_live", LiveStub())
    payload = {}
    cu.add_codex_fields(payload, now=NOW)
    assert payload["cok"] is True
    assert payload["cs"] == 52 and payload["cw"] == 61


def test_retry_delay_backs_off_and_caps():
    # 0 = the last session produced a reading; n = n sessions in a row without one.
    delays = [cu.retry_delay(n) for n in range(0, 9)]
    assert delays == [30, 30, 60, 120, 240, 480, 600, 600, 600]
    assert cu.retry_delay(10_000) == 600


def test_codex_live_run_backs_off_then_resets_after_a_reading(monkeypatch):
    class Stop(Exception):
        pass

    live = cu.CodexLive.__new__(cu.CodexLive)  # skip __init__: no background thread
    live.reading, live.err = None, None
    outcomes = iter([False, False, False, True, False, False])  # True = session got a reading

    def session():
        if next(outcomes):
            live.reading = (NOW, {"primary": {}})
            raise RuntimeError("codex app-server exited")
        raise RuntimeError("codex CLI not on PATH")

    sleeps = []

    def fake_sleep(s):
        sleeps.append(s)
        if len(sleeps) == 6:
            raise Stop

    live._session = session
    monkeypatch.setattr(cu.time, "sleep", fake_sleep)
    try:
        live._run()
    except Stop:
        pass
    assert sleeps == [30, 60, 120, 30, 30, 60]
    assert live.err == "RuntimeError: codex CLI not on PATH"


def test_pump_lines_copies_every_line_in_order():
    import io
    import queue

    q = queue.Queue()
    cu.pump_lines(io.BytesIO(b'{"id":1}\n{"id":2}\nnoise\n'), q)
    got = [q.get_nowait() for _ in range(q.qsize())]
    assert got == [b'{"id":1}\n', b'{"id":2}\n', b"noise\n"]
