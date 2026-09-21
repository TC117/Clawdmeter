#!/usr/bin/env python3
"""The Windows daemon's config readers tolerate a UTF-8 BOM.

PowerShell 5.1 (`Set-Content`/`Add-Content -Encoding utf8`, `Out-File`) writes one;
without "utf-8-sig" the first key reads as '\\ufeffclock' and the option is ignored.

Run: python -m pytest daemon/tests/test_windows_config.py -q
"""
import daemon.claude_usage_daemon_windows as d

BOM = b"\xef\xbb\xbf"


def test_clock_setting_read_through_bom(monkeypatch, tmp_path):
    cfg = tmp_path / "config"
    cfg.write_bytes(BOM + b"clock=auto\n")
    monkeypatch.setattr(d, "CONFIG_FILE", cfg)
    assert d.read_clock_setting() == "auto"


def test_chime_setting_read_through_bom(monkeypatch, tmp_path):
    cfg = tmp_path / "config"
    cfg.write_bytes(BOM + b"chime=on\n")
    monkeypatch.setattr(d, "CONFIG_FILE", cfg)
    assert d.read_chime_setting() == "on"


def test_non_utf8_bytes_do_not_raise(monkeypatch, tmp_path):
    # An ANSI-saved config with a non-ASCII comment must not crash the poll loop
    # (UnicodeDecodeError is not an OSError); the ASCII keys still read.
    cfg = tmp_path / "config"
    cfg.write_bytes(b"# caf\xe9\nclock=12\nchime=on\n")
    monkeypatch.setattr(d, "CONFIG_FILE", cfg)
    assert d.read_clock_setting() == "12"
    assert d.read_chime_setting() == "on"


def test_settings_without_bom_still_read(monkeypatch, tmp_path):
    cfg = tmp_path / "config"
    cfg.write_bytes(b"chime=on\r\nclock=24\r\n")
    monkeypatch.setattr(d, "CONFIG_FILE", cfg)
    assert d.read_chime_setting() == "on"
    assert d.read_clock_setting() == "24"
