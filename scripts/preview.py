#!/usr/bin/env python3
"""Render the full synthetic Chronicle client area, without OS titlebar."""
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess


def main():
    root = Path(__file__).resolve().parents[1]
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
               QT_SCALE_FACTOR="1", QT_QPA_PLATFORMTHEME="", QT_QUICK_CONTROLS_STYLE="Basic")
    for key in ("DISPLAY", "WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE", "QT_SCREEN_SCALE_FACTORS"):
        env.pop(key, None)
    result = subprocess.run(["/usr/lib/qt6/bin/qmltestrunner", "-input", "tests/qml_preview", "-import", "tests/support"],
                            cwd=root, env=env, capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise SystemExit(result.stdout + result.stderr)
    matches = re.findall(r"Fixture screenshot: (/tmp/chronicle-fixture-timeline-\d+\.png)", result.stdout + result.stderr)
    if len(matches) != 1:
        raise SystemExit("Expected exactly one successful timeline capture; preview not replaced.")
    capture = Path(matches[0])
    data = capture.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or struct.unpack(">II", data[16:24]) != (1280, 840):
        raise SystemExit("Unexpected capture dimensions; preview not replaced.")
    destination = root / "preview.png"
    if destination.is_symlink():
        raise SystemExit("Refusing a symlink preview destination.")
    shutil.copyfile(capture, destination)
    print(f"Rendered {destination.name}: 1280×840 full client area, synthetic data, no OS titlebar; {len(data)} bytes.")


if __name__ == "__main__":
    main()
