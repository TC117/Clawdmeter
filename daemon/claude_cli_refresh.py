#!/usr/bin/env python3
"""Nudge Claude Code's own CLI to renew its OAuth token (Windows daemon).

The daemon never refreshes the token itself: two clients rotating one refresh
token trip reuse detection and a shared 429 bucket (upstream commit 6807b0c,
guarded by test_freeride.py). But Claude Code only renews its ~8 h access token
when the CLI runs, so on a machine where Claude is used through the desktop app
the stored token lapses and the Claude column freezes.

On a 401 the daemon calls request_refresh(): one tiny headless `claude -p` call
in a background thread. The CLI rewrites its own credentials as a side effect
and the next poll reads the fresh token (the approach of upstream PR #147).
At most one attempt per COOLDOWN_S, stamped before the attempt so a missing CLI
or a dead login can't turn into a spawn-per-poll loop. Never raises.
"""
import os
import shutil
import subprocess
import threading
import time
from pathlib import Path

COOLDOWN_S = 15 * 60  # one attempt per 15 min
TIMEOUT_S = 120       # a hung CLI is killed together with its cmd/node children
MODEL = "claude-haiku-4-5-20251001"
# Run outside the user's projects so the CLI's per-directory history stays apart.
WORK_DIR = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local")) / "Clawdmeter"

_last_attempt = None  # time.monotonic() of the last attempt, successful or not


def build_command(exe):
    return [exe, "-p", "ok", "--model", MODEL, "--output-format", "text"]


def _kill_tree(proc):
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True,
                       creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    else:
        proc.kill()


def _run(exe, log):
    log("Token expired: asking the Claude Code CLI to renew it")
    try:
        WORK_DIR.mkdir(parents=True, exist_ok=True)
        proc = subprocess.Popen(build_command(exe), cwd=WORK_DIR, stdin=subprocess.DEVNULL,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    except OSError as e:
        log(f"Token renewal: could not start the Claude Code CLI: {e}")
        return
    try:
        code = proc.wait(timeout=TIMEOUT_S)
    except subprocess.TimeoutExpired:
        _kill_tree(proc)
        log(f"Token renewal: Claude Code CLI timed out after {TIMEOUT_S}s")
        return
    log(f"Token renewal: Claude Code CLI finished (exit {code})")


def _start(exe, log):
    threading.Thread(target=_run, args=(exe, log), daemon=True, name="claude-cli-refresh").start()


def request_refresh(log=print, now=None):
    """Start one background CLI call unless one was attempted in the last COOLDOWN_S.

    Returns True when a call was started. Only for a token the API rejected (401/403):
    transient failures must not spend the user's quota.
    """
    global _last_attempt
    now = time.monotonic() if now is None else now
    if _last_attempt is not None and now - _last_attempt < COOLDOWN_S:
        return False
    _last_attempt = now
    exe = shutil.which("claude")
    if not exe:
        log("Token renewal: claude CLI not on PATH; run `claude` once to renew the token")
        return False
    _start(exe, log)
    return True
