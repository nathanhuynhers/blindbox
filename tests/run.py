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
    "Rarity": "shared", "UITheme": "client",
    "PlotFixture": "server", "CollectionFixture": "server", "DisplayFixture": "server", "DisplayConfig": "shared", "ShelfConfig": "shared", "Shelves": "server", "LegacyCosmetics": "server", "LegacyShelfPages": "server", "PlotSlots": "server", "PlotConfig": "server", "PlotGeometry": "server", "PlayerPlot": "server", "FigureSlots": "server", "World": "server",
    "AssetIds": "shared", "AssetManifest": "shared", "BlindBoxSpec": "shared", "BlindBoxModel": "shared",
    "CollectionAssets": "client",
    "Types": "shared", "Catalog": "shared", "Economy": "server",
    "Rules": "server", "Protocol": "server", "Transactions": "server",
    "Profile": "server", "Persistence": "server", "Scroll": "client",
    "OpeningState": "client", "OpeningResult": "client", "OpeningConfig": "client",
    "OpeningScope": "client", "OpeningBoxSource": "client", "OpeningCamera": "client", "OpeningController": "client",
    "OpeningCinematic": "client", "OpeningEffects": "client", "OpeningBox": "client",
    "OpeningFlight": "client", "OpeningFlightEffects": "client",
    "OpeningFallbackBox": "client", "OpeningFigure": "client", "OpeningAudio": "client", "BlindBoxSkin": "client",
    "CollectionLayout": "client", "CollectionSelection": "client",
    "ShopLayout": "client", "ShopState": "client", "ShopTheme": "client",
    "UIState": "client", "UIScope": "client", "UILayout": "client", "CollectionStyle": "client",
    "NavigationConfig": "client",
    "NavigationAssetIds": "shared",
    "SystemLayout": "client", "SystemState": "client",
    "UIContext": "client", "SystemStyle": "client", "DisplaySlotCard": "client",
    "ShelfFigureCard": "client", "DailyGoalCard": "client",
    "DisplayScreen": "client", "ShelvesScreen": "client", "GoalsScreen": "client",
}
for name, folder in modules.items():
    source = (root / "src" / folder / f"{name}.luau").read_text(encoding="utf-8-sig")
    for dependency in modules:
        for expression in (
            f'script.Parent.{dependency}',
            f'game:GetService("ReplicatedStorage").Shared.{dependency}',
        ):
            source = source.replace(f"require({expression})", f'require("./{dependency}")')
    if name == "OpeningConfig":
        source = source.replace("--!strict", '--!strict\nlocal Vector3 = require("./OpeningVisualEngine").Vector3')
    if name in ("UITheme", "OpeningFlight", "OpeningFlightEffects", "OpeningCinematic", "OpeningEffects", "OpeningBox", "OpeningFallbackBox", "OpeningFigure", "OpeningAudio", "BlindBoxSkin", "BlindBoxModel"):
        source = source.replace('--!strict', '--!strict\nlocal Engine = require("./OpeningVisualEngine")\nlocal game, workspace, Instance, Enum, task, warn = Engine.game, Engine.workspace, Engine.Instance, Engine.Enum, Engine.task, Engine.warn\nlocal Vector3, Vector2, Color3, CFrame, UDim2 = Engine.Vector3, Engine.Vector2, Engine.Color3, Engine.CFrame, Engine.UDim2\nlocal NumberRange, NumberSequence, NumberSequenceKeypoint, ColorSequence = Engine.NumberRange, Engine.NumberSequence, Engine.NumberSequenceKeypoint, Engine.ColorSequence')
        for dependency in ("BlindBoxModel", "AssetManifest", "BlindBoxSpec"):
            for prefix in ("ReplicatedStorage.Shared", "Shared"):
                source = source.replace(f'require({prefix}.{dependency})', f'require("./{dependency}")')
        source = source.replace('local Shared = game:GetService("ReplicatedStorage").Shared', '')
        source = source.replace('require(game:GetService("ReplicatedStorage").Shared.FigureModel)', 'Engine.FigureModel')
    if name == "OpeningScope":
        source = source.replace("--!strict", '--!strict\nlocal warn = function(...) print("Expected cleanup fault:", ...) end')
    if name in ("OpeningController", "OpeningCamera"):
        source = source.replace("--!strict", '--!strict\nlocal Engine = require("./OpeningEngine")\nlocal game, workspace, Instance, Enum, Vector3, typeof, warn = Engine.game, Engine.workspace, Engine.Instance, Engine.Enum, Engine.Vector3, Engine.typeof, Engine.warn')
        for dependency in ("View", "Audio", "Cinematic"):
            for expression in (f"require(script.Parent.Opening{dependency})", f'require("./Opening{dependency}")'):
                source = source.replace(expression, f"Engine.{dependency}")
    if name == "Scroll":
        source = source.replace("--!strict", "--!strict\nlocal Enum = {AutomaticSize={None=0},ScrollingDirection={Y=1},ScrollBarInset={ScrollBar=1}}\nlocal UDim2 = {fromOffset=function(x,y) return {X={Offset=x},Y={Offset=y}} end}")
    if name in ("PlotFixture", "CollectionFixture", "DisplayFixture", "PlotGeometry", "PlayerPlot", "World", "FigureSlots"):
        source = source.replace('--!strict', '--!strict\nlocal Engine = require("./PlotEngine")\nlocal Instance, Vector3, Color3, CFrame, UDim2, workspace = Engine.Instance, Engine.Vector3, Engine.Color3, Engine.CFrame, Engine.UDim2, Engine.workspace\nlocal Enum, Vector2 = Engine.Enum, Engine.Vector2')
        source = source.replace('local FigureModel = require(game:GetService("ReplicatedStorage").Shared.FigureModel)', 'local FigureModel = Engine.FigureModel')
    if name == "CollectionAssets":
        source = source.replace('local W = require(script.Parent.Widgets)', 'local W = Engine.Widgets')
        source = source.replace('--!strict', '--!strict\nlocal Engine = require("./AssetMountEngine")\nlocal Instance, UDim2, Rect, Enum = Engine.Instance, Engine.UDim2, Engine.Rect, Engine.Enum')
    if name in ("Rarity", "Catalog", "OpeningConfig", "CollectionStyle", "ShopTheme"):
        source = source.replace("--!strict", '--!strict\nlocal Color3 = require("./OpeningVisualEngine").Color3')
    if name in ("SystemStyle", "DisplaySlotCard", "ShelfFigureCard", "DailyGoalCard", "DisplayScreen", "ShelvesScreen", "GoalsScreen"):
        source = source.replace('--!strict', '--!strict\nlocal Engine = require("./SystemUIEngine")\nlocal Instance, Color3, UDim2, Enum, TweenInfo = Engine.Instance, Engine.Color3, Engine.UDim2, Engine.Enum, Engine.TweenInfo')
        for module, field in (("Widgets", "Widgets"), ("UIPreview", "Preview"), ("UIIcons", "Icons"), ("UITheme", "Theme")):
            source = source.replace(f'require(script.Parent.{module})', f'Engine.{field}')
        source = source.replace('game:GetService("TweenService")', 'Engine.TweenService')
    (out / f"{name}.luau").write_text(source, encoding="utf-8")
for name in ("OpeningEngine", "OpeningVisualEngine", "OpeningLifecycle.spec", "OpeningResources.spec", "OpeningFlight.spec", "Rarity.spec", "AssetMountEngine"):
    (out / f"{name}.luau").write_text((root / "tests" / f"{name}.luau").read_text(encoding="utf-8"), encoding="utf-8")
result = subprocess.run([sys.argv[1], str(out / "OpeningLifecycle.spec.luau")], cwd=root)
if result.returncode:
    raise SystemExit(result.returncode)
result = subprocess.run([sys.argv[1], str(out / "OpeningResources.spec.luau")], cwd=root)
if result.returncode:
    raise SystemExit(result.returncode)
result = subprocess.run([sys.argv[1], str(out / "OpeningFlight.spec.luau")], cwd=root)
if result.returncode:
    raise SystemExit(result.returncode)
result = subprocess.run([sys.argv[1], str(out / "Rarity.spec.luau")], cwd=root)
if result.returncode:
    raise SystemExit(result.returncode)
(out / "Mvp.spec.luau").write_text((root / "tests" / "Mvp.spec.luau").read_text(encoding="utf-8"), encoding="utf-8")
for name in ("SystemUIEngine", "SystemScreens.spec"):
    (out / f"{name}.luau").write_text((root / "tests" / f"{name}.luau").read_text(encoding="utf-8"), encoding="utf-8")
result = subprocess.run([sys.argv[1], str(out / "SystemScreens.spec.luau")], cwd=root)
if result.returncode:
    raise SystemExit(result.returncode)
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
(out / "Opening.spec.luau").write_text((root / "tests" / "Opening.spec.luau").read_text(encoding="utf-8"), encoding="utf-8")
result = subprocess.run([sys.argv[1], str(out / "Opening.spec.luau")], cwd=root)
if result.returncode:
    raise SystemExit(result.returncode)
(out / "UI.spec.luau").write_text((root / "tests" / "UI.spec.luau").read_text(encoding="utf-8"), encoding="utf-8")
result = subprocess.run([sys.argv[1], str(out / "UI.spec.luau")], cwd=root)
if result.returncode:
    raise SystemExit(result.returncode)
(out / "Collection.spec.luau").write_text((root / "tests" / "Collection.spec.luau").read_text(encoding="utf-8"), encoding="utf-8")
result = subprocess.run([sys.argv[1], str(out / "Collection.spec.luau")], cwd=root)
if result.returncode:
    raise SystemExit(result.returncode)
(out / "AssetManifest.spec.luau").write_text((root / "tests" / "AssetManifest.spec.luau").read_text(encoding="utf-8"), encoding="utf-8")
result = subprocess.run([sys.argv[1], str(out / "AssetManifest.spec.luau")], cwd=root)
if result.returncode:
    raise SystemExit(result.returncode)
for name in ("AssetMountEngine", "CollectionAssets.spec", "BlindBox.spec", "Shelves.spec", "PlotEngine", "Plots.spec"):
    (out / f"{name}.luau").write_text((root / "tests" / f"{name}.luau").read_text(encoding="utf-8"), encoding="utf-8")
result = subprocess.run([sys.argv[1], str(out / "CollectionAssets.spec.luau")], cwd=root)
if result.returncode:
    raise SystemExit(result.returncode)
result = subprocess.run([sys.argv[1], str(out / "BlindBox.spec.luau")], cwd=root)
if result.returncode:
    raise SystemExit(result.returncode)
result = subprocess.run([sys.argv[1], str(out / "Shelves.spec.luau")], cwd=root)
if result.returncode:
    raise SystemExit(result.returncode)
result = subprocess.run([sys.argv[1], str(out / "Plots.spec.luau")], cwd=root)
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
    for helper in ("OpeningEngine", "OpeningVisualEngine"):
        (fixture / f"{helper}.luau").write_text((out / f"{helper}.luau").read_text(encoding="utf-8"), encoding="utf-8")
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
