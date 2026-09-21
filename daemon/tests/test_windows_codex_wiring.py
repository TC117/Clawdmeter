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


def _run_one_cycle(read_token_value, poll_api_mock):
    """Drive connect_and_run for one write; return the payloads written to the device."""
    written = []
    stop = asyncio.Event()

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

    async def run():
        with patch.object(d, "BleakClient", return_value=client), \
             patch.object(d, "Session", FakeSession), \
             patch.object(d, "read_token", return_value=read_token_value), \
             patch.object(d, "poll_api", poll_api_mock), \
             patch.object(d, "add_clock_fields", lambda p: p.update({"t": 1789998120, "tf": 24})), \
             patch.object(d, "add_codex_fields", lambda p: p.update({"cok": True, "cs": 42})):
            await d.connect_and_run(MagicMock(), stop)

    asyncio.run(run())
    return written


def test_expired_token_beat_still_carries_codex_and_clock():
    # Claude has no data (401/403), but the Codex column and the clock must keep
    # flowing so the landscape view can show which source is live.
    written = _run_one_cycle("tok", AsyncMock(side_effect=d.AuthError(401)))
    assert written, "expected a no-data beat to be written"
    p = written[0]
    assert p["ok"] is False
    assert p["cok"] is True and p["cs"] == 42
    assert p["t"] == 1789998120 and p["tf"] == 24


def test_missing_token_beat_still_carries_codex_and_clock():
    poll = AsyncMock(return_value={"s": 5, "ok": True})
    written = _run_one_cycle(None, poll)
    assert written, "expected a no-data beat to be written"
    p = written[0]
    assert p["ok"] is False
    assert p["cok"] is True and p["cs"] == 42
    assert p["t"] == 1789998120 and p["tf"] == 24
    poll.assert_not_awaited()  # no token -> no API call


def test_transient_poll_failure_writes_nothing():
    # A None from poll_api (network/DNS/5xx) stays silent: nothing is written.
    written = []
    stop = asyncio.Event()

    class FakeSession:
        def __init__(self, client):
            self.refresh_requested = asyncio.Event()

        async def setup_refresh_subscription(self):
            return None

        async def write_payload(self, payload):
            written.append(dict(payload))
            return True

    client = MagicMock()
    client.is_connected = True
    client.connect = AsyncMock(return_value=True)
    client.disconnect = AsyncMock(return_value=True)

    async def poll_then_stop(_token):
        stop.set()
        return None

    async def run():
        with patch.object(d, "BleakClient", return_value=client), \
             patch.object(d, "Session", FakeSession), \
             patch.object(d, "read_token", return_value="tok"), \
             patch.object(d, "poll_api", poll_then_stop), \
             patch.object(d, "add_codex_fields", lambda p: p.update({"cok": True})):
            await d.connect_and_run(MagicMock(), stop)

    asyncio.run(run())
    assert written == []
