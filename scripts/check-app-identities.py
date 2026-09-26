#!/usr/bin/env python3
"""Check the built app identities that macOS uses for privacy authorization."""
import pathlib
import plistlib
import subprocess
import sys


def identity(bundle):
    with (bundle / "Contents" / "Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    subprocess.run(
        ["codesign", "--verify", "--deep", "--strict", str(bundle)], check=True
    )
    return info["CFBundleIdentifier"], info.get("CFBundleDisplayName", info["CFBundleName"])


root = pathlib.Path(__file__).resolve().parent.parent
products = root / "build" / "Build" / "Products"
debug = identity(products / "Debug" / "Caelestia Notch.app")
release = identity(products / "Release" / "Caelestia Notch.app")
print(f"Debug:   {debug[0]} — {debug[1]}")
print(f"Release: {release[0]} — {release[1]}")

if debug[0] == release[0]:
    sys.exit("FAIL: Debug and Release share a privacy identity despite different ad-hoc signatures.")
if debug[1] == release[1]:
    sys.exit("FAIL: Debug and Release cannot be distinguished in Privacy settings.")
print("PASS: valid signatures, separate privacy identities, distinct display names.")
