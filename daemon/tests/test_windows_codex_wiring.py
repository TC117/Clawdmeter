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
