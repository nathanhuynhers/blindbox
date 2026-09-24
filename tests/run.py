"""Run actual domain modules in standalone Luau; only Roblox module resolution/colors are shimmed.

Usage: python tests/run.py path/to/luau.exe
Generated copies live in ignored build/tests. No production test grants or test dependencies.
"""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
out = root / "build" / "tests"
out.mkdir(parents=True, exist_ok=True)
modules = {
    "Types": "shared", "Catalog": "shared", "Economy": "server",
    "Rules": "server", "Protocol": "server", "Transactions": "server",
    "Profile": "server", "Persistence": "server", "Scroll": "client",
}
for name, folder in modules.items():
    source = (root / "src" / folder / f"{name}.luau").read_text(encoding="utf-8-sig")
    for dependency in modules:
        for expression in (
            f'script.Parent.{dependency}',
            f'game:GetService("ReplicatedStorage").Shared.{dependency}',
        ):
            source = source.replace(f"require({expression})", f'require("./{dependency}")')
    if name == "Scroll":
        source = source.replace("--!strict", "--!strict\nlocal Enum = {AutomaticSize={None=0},ScrollingDirection={Y=1},ScrollBarInset={ScrollBar=1}}\nlocal UDim2 = {fromOffset=function(x,y) return {X={Offset=x},Y={Offset=y}} end}")
    if name == "Catalog":
        source = source.replace("--!strict", "--!strict\nlocal Color3 = { fromRGB = function(r: number, g: number, b: number) return {r, g, b} end }")
    (out / f"{name}.luau").write_text(source, encoding="utf-8")
(out / "Mvp.spec.luau").write_text((root / "tests" / "Mvp.spec.luau").read_text(encoding="utf-8"), encoding="utf-8")
result = subprocess.run([sys.argv[1], str(out / "Mvp.spec.luau")], cwd=root)
if result.returncode:
    raise SystemExit(result.returncode)
(out / "FullGame.spec.luau").write_text((root / "tests" / "FullGame.spec.luau").read_text(encoding="utf-8"), encoding="utf-8")
result = subprocess.run([sys.argv[1], str(out / "FullGame.spec.luau")], cwd=root)
if result.returncode:
    raise SystemExit(result.returncode)
(out / "Scroll.spec.luau").write_text((root / "tests" / "Scroll.spec.luau").read_text(encoding="utf-8"), encoding="utf-8")
result = subprocess.run([sys.argv[1], str(out / "Scroll.spec.luau")], cwd=root)
if result.returncode:
    raise SystemExit(result.returncode)
fixtures = [
    ('id = "grove.pebble"', 'id = "unknown"', "Invalid economy reference"),
    ('weight = 20', 'weight = 0', "Invalid rate/weight"),
    ('rate = 1,', 'rate = 8,', "Rate outside rarity band"),
    ('price = 150', 'price = -1', "Invalid economy bound"),
]
for index, (old, new, expected) in enumerate(fixtures):
    fixture = out / f"invalid-{index}"
    fixture.mkdir(exist_ok=True)
    for name in modules:
        source = (out / f"{name}.luau").read_text(encoding="utf-8")
        if name == "Economy":
            assert old in source
            source = source.replace(old, new, 1)
        (fixture / f"{name}.luau").write_text(source, encoding="utf-8")
    (fixture / "load.luau").write_text('require("./Rules")\n', encoding="utf-8")
    result = subprocess.run([sys.argv[1], str(fixture / "load.luau")], cwd=root, capture_output=True, text=True)
    assert result.returncode != 0 and expected in result.stderr, result.stderr
print("PASS: 4 invalid-configuration startup fixtures")
