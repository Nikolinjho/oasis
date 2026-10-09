#!/usr/bin/python3
"""Сохраняет только лимиты Claude Code и дополняет прежний statusline."""
import fcntl
import json
import math
import os
import signal
import subprocess
import sys
import tempfile
import time

DEFAULT_DIR = "~/Library/Application Support/Oasis"


def load_json(path):
    try:
        with open(path) as stream:
            value = json.load(stream)
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError, RecursionError):
        return {}


def number(value):
    try:
        return type(value) in (int, float) and math.isfinite(value)
    except (OverflowError, ValueError):
        return False


def windows(status):
    result = {}
    raw = status.get("rate_limits") if isinstance(status, dict) else None
    if not isinstance(raw, dict):
        return result
    for key in ("five_hour", "seven_day"):
        window = raw.get(key)
        if not isinstance(window, dict):
            continue
        used, reset = window.get("used_percentage"), window.get("resets_at")
        if number(used) and number(reset) and 0 < reset <= 64092211200:
            result[key] = {"used_percentage": min(max(used, 0), 100), "resets_at": reset}
    return result


def save_atomically(directory, limits):
    os.makedirs(directory, mode=0o700, exist_ok=True)
    lock_fd = os.open(os.path.join(directory, ".claude-limits.lock"), os.O_CREAT | os.O_RDWR, 0o600)
    with os.fdopen(lock_fd, "w") as lock:
        os.fchmod(lock.fileno(), 0o600)
        fcntl.flock(lock, fcntl.LOCK_EX)
        fd, temporary = tempfile.mkstemp(dir=directory, prefix=".claude-limits.", suffix=".tmp")
        try:
            with os.fdopen(fd, "w") as stream:
                os.fchmod(stream.fileno(), 0o600)
                json.dump({"captured_at": time.time(), "rate_limits": limits}, stream,
                          sort_keys=True, allow_nan=False)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, os.path.join(directory, "claude-limits.json"))
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)


def run_chain(command, raw):
    if not isinstance(command, str) or not command:
        return b""
    try:
        process = subprocess.Popen(command, shell=True, stdin=subprocess.PIPE,
                                   stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                   start_new_session=True)
        try:
            output, _ = process.communicate(raw, timeout=1)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except OSError:
                pass
            process.communicate()
            return b""
        return output.rstrip(b"\n")
    except (OSError, ValueError):
        return b""


def main():
    raw = sys.stdin.buffer.read()
    directory = os.environ.get("OASIS_CLAUDE_DIR") or os.path.expanduser(DEFAULT_DIR)
    config = load_json(os.path.join(directory, "claude-statusline.json"))
    try:
        status = json.loads(raw)
    except (ValueError, UnicodeError, RecursionError):
        status = None
    limits = windows(status)
    if limits:
        try:
            save_atomically(directory, limits)
        except (OSError, ValueError):
            pass
    parts = []
    chained = run_chain(config.get("chain"), raw)
    if chained:
        parts.append(chained)
    five = limits.get("five_hour")
    if config.get("text", True) and five:
        remaining = int(math.floor(100 - five["used_percentage"] + 0.5))
        parts.append(("5h %d%%" % remaining).encode("ascii"))
    sys.stdout.buffer.write(" · ".encode("utf-8").join(parts) + b"\n")


if __name__ == "__main__":
    main()
