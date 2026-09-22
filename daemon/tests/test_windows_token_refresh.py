#!/usr/bin/env python3
"""The Windows daemon nudges the Claude Code CLI on a 401, and only then.

The daemon itself still never refreshes the token (test_freeride.py); on an
expired token it asks claude_cli_refresh to run the CLI, which renews its own
credentials. Transient failures and `token_refresh=off` must not nudge.

Run: python -m pytest daemon/tests/test_windows_token_refresh.py -q
"""
import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

import daemon.claude_usage_daemon_windows as d


def _connected_client():
    client = AsyncMock()
    client.connect = AsyncMock(return_value=None)
    client.is_connected = True
    client.disconnect = AsyncMock()
    client.start_notify = AsyncMock()
    client.write_gatt_char = AsyncMock(return_value=None)
    return client


def _one_poll(poll_outcome, setting="on"):
    """Drive connect_and_run through a single poll; return the nudge calls."""
    nudges = []
    device = MagicMock()
    device.address = "AA:BB:CC:DD:EE:FF"

    async def go():
        stop_event = asyncio.Event()

        async def fake_poll(token):
            stop_event.set()  # one poll, then unwind the loop
            if isinstance(poll_outcome, Exception):
                raise poll_outcome
            return poll_outcome

        with patch.object(d, "BleakClient", return_value=_connected_client()), \
             patch.object(d, "read_token", return_value="TOKEN"), \
             patch.object(d, "poll_api", new=fake_poll), \
             patch.object(d, "add_clock_fields", lambda p: None), \
             patch.object(d, "add_codex_fields", lambda p: None), \
             patch.object(d, "read_token_refresh_setting", return_value=setting), \
             patch.object(d, "request_cli_refresh", lambda log: nudges.append(log)):
            await d.connect_and_run(device, stop_event)

    asyncio.run(go())
    return nudges


def test_expired_token_asks_the_cli_to_renew_it():
    assert len(_one_poll(d.AuthError(401))) == 1


def test_token_refresh_off_skips_the_nudge():
    assert _one_poll(d.AuthError(401), setting="off") == []


def test_transient_failure_does_not_nudge():
    assert _one_poll(None) == []  # poll_api returns None on network/5xx/429


def test_token_refresh_setting_defaults_on_and_honours_off(tmp_path, monkeypatch):
    cfg = tmp_path / "config"
    monkeypatch.setattr(d, "CONFIG_FILE", cfg)
    assert d.read_token_refresh_setting() == "on"  # no file
    cfg.write_text("clock=24\n", encoding="utf-8")
    assert d.read_token_refresh_setting() == "on"  # key absent
    cfg.write_bytes(b"\xef\xbb\xbftoken_refresh = OFF  # quota\nclock=24\n")
    assert d.read_token_refresh_setting() == "off"
