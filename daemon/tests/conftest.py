"""Keep every daemon test hermetic with respect to the Claude Code CLI nudge.

connect_and_run's 401 path asks claude_cli_refresh to run `claude -p ...` in a
background thread. No test may spawn the real CLI, so the thread starter is
swapped for a recorder and the cooldown is reset before each test.
"""
import pytest

from daemon import claude_cli_refresh


@pytest.fixture(autouse=True)
def cli_refresh_starts(monkeypatch):
    started = []
    monkeypatch.setattr(claude_cli_refresh, "_start", lambda exe, log: started.append(exe))
    monkeypatch.setattr(claude_cli_refresh, "_last_attempt", None)
    return started
