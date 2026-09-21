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
RETRY_MIN_S = 30          # app-server restart delay after a productive session...
RETRY_MAX_S = 600         # ...doubling per unproductive one, up to this cap


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


def retry_delay(failures):
    """Seconds to wait before restarting the app-server. `failures` counts the sessions in
    a row that produced no reading (0 = the last one did): 30, 30, 60, 120 ... capped at 600,
    so a missing or broken CLI isn't respawned every 30 s forever."""
    return min(RETRY_MIN_S * 2 ** min(max(failures - 1, 0), 5), RETRY_MAX_S)


def pump_lines(stream, lines):
    """Copy every line of the app-server's stdout into the `lines` queue (reader thread)."""
    for line in stream:
        lines.put(line)


class CodexLive:
    """Live Codex limits from the official `codex app-server` (OpenAI's documented JSON-RPC
    protocol for embedding Codex). One long-lived process asked every CODEX_POLL seconds;
    restarts itself if the process dies."""

    def __init__(self):
        self.reading = None  # (taken_at_epoch, rateLimits dict)
        self.err = None
        threading.Thread(target=self._run, daemon=True, name="codex-live").start()

    def _run(self):
        failures = 0
        while True:
            before = self.reading
            try:
                self._session()
            except Exception as e:  # keep the daemon alive whatever the CLI does
                self.err = f"{type(e).__name__}: {e}"
            failures = 0 if self.reading is not before else failures + 1
            time.sleep(retry_delay(failures))

    def _session(self):
        exe = shutil.which("codex")
        if not exe:
            raise RuntimeError("codex CLI not on PATH")
        no_window = getattr(subprocess, "CREATE_NO_WINDOW", 0)  # tray runs under pythonw
        proc = subprocess.Popen([exe, "app-server"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL, creationflags=no_window)
        lines = queue.Queue()
        threading.Thread(target=pump_lines, args=(proc.stdout, lines), daemon=True).start()
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
    live = _live.reading if _live else None
    try:
        logged = newest_logged()
    except Exception:
        logged = None  # a log-scan error must not discard a fresh live reading
    try:
        fields = codex_fields(pick_reading(logged, live, now), now)
    except Exception:
        fields = {"cok": False}
    payload.update(fields)
