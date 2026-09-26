#!/usr/bin/env python3
"""Build and run native Shelf interaction regressions in a temporary directory."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
env = os.environ.copy()
env.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
sources = [ROOT / "CaelestiaNotch/App/AppModel.swift", ROOT / "CaelestiaNotch/App/AppDelegate.swift"]
for folder in ("Core", "Services", "UI", "Window"):
    sources.extend(sorted((ROOT / "CaelestiaNotch" / folder).glob("*.swift")))
sources.append(ROOT / "scripts/check-shelf-interactions.swift")
with tempfile.TemporaryDirectory(prefix="caelestia-shelf-check-") as directory:
    executable = str(Path(directory) / "check-shelf-interactions")
    subprocess.run(["xcrun", "swiftc", *map(str, sources), "-o", executable], env=env, check=True)
    subprocess.run([executable], env=env, check=True, timeout=30)
