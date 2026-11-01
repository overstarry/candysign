#!/usr/bin/env python3
"""Verify the configured charger without exposing its endpoint in process arguments."""

import os
from pathlib import Path
import subprocess
import sys
import tomllib


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    codex_home = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex")))
    try:
        config = tomllib.loads((codex_home / "config.toml").read_text())
        endpoint = config["mcp_servers"]["candysign-2838"]["url"]
    except (OSError, KeyError, tomllib.TOMLDecodeError):
        print("Could not read the candysign-2838 MCP configuration.", file=sys.stderr)
        return 1
    subprocess.run(["swift", "build", "--product", "CandySignProbe"], cwd=root, check=True)
    binary_dir = subprocess.check_output(
        ["swift", "build", "--show-bin-path"], cwd=root, text=True
    ).strip()
    result = subprocess.run(
        [str(Path(binary_dir) / "CandySignProbe")],
        input=endpoint,
        text=True,
        cwd=root,
        timeout=180,
    )
    return result.returncode


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (subprocess.SubprocessError, OSError):
        print("Build or live verification did not complete.", file=sys.stderr)
        sys.exit(1)
