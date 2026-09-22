#!/usr/bin/env python3
"""Tests for daemon/claude_cli_refresh.py — nudging the Claude Code CLI to renew
its own OAuth token when the daemon's poll gets a 401.

Run: python -m pytest daemon/tests/test_claude_cli_refresh.py -q
"""
import subprocess

from daemon import claude_cli_refresh as cr

EXE = r"C:\tools\claude.CMD"


def test_request_starts_cli_then_waits_out_the_cooldown(monkeypatch, cli_refresh_starts):
    monkeypatch.setattr(cr.shutil, "which", lambda name: EXE)
    assert cr.request_refresh(log=lambda m: None, now=1000.0) is True
    assert cr.request_refresh(log=lambda m: None, now=1000.0 + 60) is False
    assert cr.request_refresh(log=lambda m: None, now=1000.0 + cr.COOLDOWN_S + 1) is True
    assert cli_refresh_starts == [EXE, EXE]


def test_missing_cli_is_logged_and_still_counts_as_an_attempt(monkeypatch, cli_refresh_starts):
    lookups, logs = [], []
    monkeypatch.setattr(cr.shutil, "which", lambda name: lookups.append(name))  # -> None
    assert cr.request_refresh(log=logs.append, now=5.0) is False
    assert cr.request_refresh(log=logs.append, now=6.0) is False
    assert lookups == ["claude"]  # the second call was held back by the cooldown
    assert cli_refresh_starts == []
    assert any("not on PATH" in m for m in logs)


def test_command_is_one_tiny_headless_haiku_call():
    assert cr.build_command(EXE) == [
        EXE, "-p", "ok", "--model", "claude-haiku-4-5-20251001", "--output-format", "text",
    ]


class FakeProc:
    def __init__(self, wait_raises=None):
        self.pid = 4242
        self._wait_raises = wait_raises

    def wait(self, timeout=None):
        if self._wait_raises:
            raise self._wait_raises
        return 0


def test_run_is_windowless_and_isolated(monkeypatch, tmp_path):
    seen = {}

    def fake_popen(cmd, **kwargs):
        seen["cmd"], seen["kwargs"] = cmd, kwargs
        return FakeProc()

    monkeypatch.setattr(cr.subprocess, "Popen", fake_popen)
    monkeypatch.setattr(cr, "WORK_DIR", tmp_path / "Clawdmeter")
    logs = []
    cr._run(EXE, logs.append)
    kw = seen["kwargs"]
    assert seen["cmd"] == cr.build_command(EXE)
    assert kw["cwd"] == tmp_path / "Clawdmeter"
    assert (tmp_path / "Clawdmeter").is_dir()
    assert kw["stdin"] is subprocess.DEVNULL
    assert kw["stdout"] is subprocess.DEVNULL
    assert kw["stderr"] is subprocess.DEVNULL
    assert kw["creationflags"] == getattr(subprocess, "CREATE_NO_WINDOW", 0)
    assert any("exit 0" in m for m in logs)


def test_run_kills_the_whole_tree_on_timeout(monkeypatch, tmp_path):
    killed = []
    monkeypatch.setattr(
        cr.subprocess, "Popen",
        lambda cmd, **kw: FakeProc(wait_raises=subprocess.TimeoutExpired(cmd, cr.TIMEOUT_S)),
    )
    monkeypatch.setattr(cr, "WORK_DIR", tmp_path)
    monkeypatch.setattr(cr, "_kill_tree", lambda proc: killed.append(proc.pid))
    logs = []
    cr._run(EXE, logs.append)
    assert killed == [4242]
    assert any("timed out" in m for m in logs)


def test_run_logs_unexpected_errors_instead_of_raising(monkeypatch, tmp_path):
    monkeypatch.setattr(cr.subprocess, "Popen",
                        lambda cmd, **kw: FakeProc(wait_raises=RuntimeError("handle closed")))
    monkeypatch.setattr(cr, "WORK_DIR", tmp_path)
    logs = []
    cr._run(EXE, logs.append)  # must not raise
    assert any("handle closed" in m for m in logs)


def test_run_never_raises_when_the_cli_cannot_start(monkeypatch, tmp_path):
    def boom(cmd, **kw):
        raise OSError("access denied")

    monkeypatch.setattr(cr.subprocess, "Popen", boom)
    monkeypatch.setattr(cr, "WORK_DIR", tmp_path)
    logs = []
    cr._run(EXE, logs.append)  # must not raise
    assert any("access denied" in m for m in logs)
