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
    "MovementConfig": "server", "PlayerMovement": "server",
    "Rarity": "shared",
    "PlotFixture": "server", "PlotStyle": "server", "TownPlacements": "server", "Awning": "server", "NightLights": "server", "TownStyle": "server", "TownLayout": "server", "TownProps": "server", "PlazaFixture": "server", "LeaderboardBoard": "server", "LeaderboardStore": "server", "LeaderboardStats": "server", "DayNight": "server", "CollectionFixture": "server", "DisplayFixture": "server", "DisplayConfig": "shared", "ShelfConfig": "shared", "Shelves": "server", "LegacyCosmetics": "server", "LegacyShelfPages": "server", "PlotSlots": "server", "PlotConfig": "server", "PlotGeometry": "server", "PlayerPlot": "server", "ShopFixture": "server", "FigureSlots": "server", "World": "server",
    "AssetIds": "shared", "AssetManifest": "shared", "BlindBoxSpec": "shared", "BlindBoxModel": "shared",
    "Types": "shared", "Tutorial": "shared", "Catalog": "shared", "LoginRewards": "shared", "Economy": "server",
    "CollectionEconomy": "server", "Rules": "server", "Protocol": "server", "Transactions": "server",
    "DisplayInteraction": "client", "ShopKeeper": "client", "HomeTeleport": "server", "Profile": "server", "Persistence": "server", "Scroll": "client",
    "OpeningState": "client", "OpeningResult": "client", "OpeningConfig": "client", "OpeningLayout": "client",
    "OpeningAudioConfig": "client", "OpeningAudioSequence": "client", "SoundManifest": "client", "Sfx": "client", "Music": "client",
    "OpeningScope": "client", "OpeningBoxSource": "client", "OpeningCamera": "client", "OpeningController": "client",
    "OpeningCinematic": "client", "OpeningLighting": "client", "OpeningEffects": "client", "OpeningBox": "client",
    "OpeningFlight": "client", "OpeningFlightEffects": "client",
    "OpeningFallbackBox": "client", "OpeningFigure": "client", "OpeningAudio": "client", "BlindBoxSkin": "client",
    "ShopTheme": "client", "CoinCounter": "client", "CoinBurst": "client", "DisplayEarnings": "client",
    "UIState": "client", "UIScope": "client", "UILayout": "client", "UIContext": "client",
    "NavigationConfig": "client", "NavigationAssetIds": "shared",
}
# Redesigned UI: the real components, screens and Interface run on tests/UIEngine.luau.
ui = [
    "UIStyle", "UIKit", "UIIcons", "UIButton", "UIBadge", "UIProgress", "ScreenShell", "Dock",
    "Hud", "SettingsMenu", "GoalTracker", "CollectionList", "FigureTile", "Notifications",
    "ShopScreen", "CollectionScreen", "DisplayScreen", "DisplaySlot", "DisplayPicker", "PullSummary",
    "GoalsScreen", "ShelvesScreen", "LoginScreen", "RevealCard", "Onboarding", "Interface",
]
for name in ui:
    modules[name] = "client"
UI_PRELUDE = "\n".join([
    "--!strict",
    'local Engine = require("./UIEngine")',
    "local game, workspace, Instance, Enum, task = Engine.game, Engine.workspace, Engine.Instance, Engine.Enum, Engine.task",
    "local Color3, UDim2, UDim, Vector2, Rect = Engine.Color3, Engine.UDim2, Engine.UDim, Engine.Vector2, Engine.Rect",
    "local Font, TweenInfo, Vector3 = Engine.Font, Engine.TweenInfo, Engine.Vector3",
    "local NumberSequence, NumberSequenceKeypoint = Engine.NumberSequence, Engine.NumberSequenceKeypoint",
])
for name, folder in modules.items():
    source = (root / "src" / folder / f"{name}.luau").read_text(encoding="utf-8-sig")
    if name in ("CoinBurst", "DisplayEarnings"):
        source = source.replace("--!strict", '--!strict\nlocal Engine = require("./CoinEngine")\nlocal game, workspace, Instance, Enum, task, os, warn = Engine.game, Engine.workspace, Engine.Instance, Engine.Enum, Engine.task, Engine.os, Engine.warn\nlocal Color3, Vector3, Vector2, CFrame, UDim2, UDim, TweenInfo = Engine.Color3, Engine.Vector3, Engine.Vector2, Engine.CFrame, Engine.UDim2, Engine.UDim, Engine.TweenInfo\nlocal ColorSequence, NumberRange, NumberSequence, NumberSequenceKeypoint = Engine.ColorSequence, Engine.NumberRange, Engine.NumberSequence, Engine.NumberSequenceKeypoint')
        source = source.replace("require(script.Parent.UIIcons)", "Engine.Icons")
        source = source.replace("require(script.Parent.UIStyle)", "Engine.Style")
        source = source.replace("require(script.Parent.Sfx)", "Engine.Sfx")
    if name in ui:
        source = source.replace("require(script.Parent.UIPreview)", "Engine.Preview")
        source = source.replace("require(script.Parent.BlindBoxPreview)", "Engine.BoxPreview")
        source = source.replace("require(script.Parent.Sfx)", "Engine.Sfx")
        source = source.replace("--!strict", UI_PRELUDE, 1)
    for dependency in modules:
        for expression in (
            f'script.Parent.{dependency}',
            f'game:GetService("ReplicatedStorage").Shared.{dependency}',
        ):
            source = source.replace(f"require({expression})", f'require("./{dependency}")')
    if name == "OpeningConfig":
        source = source.replace("--!strict", '--!strict\nlocal Vector3 = require("./OpeningVisualEngine").Vector3')
    if name in ("OpeningFlight", "OpeningFlightEffects", "OpeningCinematic", "OpeningLighting", "OpeningEffects", "OpeningBox", "OpeningFallbackBox", "OpeningFigure", "OpeningAudio", "Sfx", "Music", "BlindBoxSkin", "BlindBoxModel"):
        source = source.replace('--!strict', '--!strict\nlocal Engine = require("./OpeningVisualEngine")\nlocal game, workspace, Instance, Enum, task, warn = Engine.game, Engine.workspace, Engine.Instance, Engine.Enum, Engine.task, Engine.warn\nlocal Vector3, Vector2, Color3, CFrame, UDim2 = Engine.Vector3, Engine.Vector2, Engine.Color3, Engine.CFrame, Engine.UDim2\nlocal NumberRange, NumberSequence, NumberSequenceKeypoint, ColorSequence = Engine.NumberRange, Engine.NumberSequence, Engine.NumberSequenceKeypoint, Engine.ColorSequence')
        for dependency in ("BlindBoxModel", "AssetManifest", "BlindBoxSpec"):
            for prefix in ("ReplicatedStorage.Shared", "Shared"):
                source = source.replace(f'require({prefix}.{dependency})', f'require("./{dependency}")')
        source = source.replace('local Shared = game:GetService("ReplicatedStorage").Shared', '')
        source = source.replace('require(game:GetService("ReplicatedStorage").Shared.FigureModel)', 'Engine.FigureModel')
    if name == "Music":
        source = source.replace("local TweenService", "local TweenInfo = Engine.TweenInfo\nlocal TweenService", 1)
    if name == "OpeningScope":
        source = source.replace("--!strict", '--!strict\nlocal warn = function(...) print("Expected cleanup fault:", ...) end')
    if name in ("OpeningController", "OpeningCamera"):
        source = source.replace("--!strict", '--!strict\nlocal Engine = require("./OpeningEngine")\nlocal game, workspace, Instance, Enum, Vector3, typeof, warn = Engine.game, Engine.workspace, Engine.Instance, Engine.Enum, Engine.Vector3, Engine.typeof, Engine.warn')
        for dependency in ("View", "Audio", "Cinematic"):
            for expression in (f"require(script.Parent.Opening{dependency})", f'require("./Opening{dependency}")'):
                source = source.replace(expression, f"Engine.{dependency}")
    if name == "DisplayInteraction":
        source = source.replace("--!strict", '--!strict\nlocal Engine = require("./PlotEngine")\nlocal game, workspace, Enum = Engine.game, Engine.workspace, Engine.Enum')
    if name == "ShopKeeper":
        # The test drives tick() and RenderStepped by hand, so the background loop is stubbed.
        source = source.replace("--!strict", '--!strict\nlocal Engine = require("./PlotEngine")\nlocal game, workspace, CFrame, Vector3 = Engine.game, Engine.workspace, Engine.CFrame, Engine.Vector3\nlocal task = {spawn = function() end, wait = function() end}\nlocal typeof = function(value) return if type(value) == "table" and getmetatable(value) == getmetatable(Vector3.zero) then "Vector3" else type(value) end')
    if name == "Scroll":
        source = source.replace("--!strict", "--!strict\nlocal Enum = {AutomaticSize={None=0},ScrollingDirection={Y=1},ScrollBarInset={ScrollBar=1}}\nlocal UDim2 = {fromOffset=function(x,y) return {X={Offset=x},Y={Offset=y}} end}")
    if name in ("PlotFixture", "ShopFixture", "CollectionFixture", "DisplayFixture", "PlotGeometry", "PlayerPlot", "HomeTeleport", "World", "FigureSlots", "PlotStyle", "Awning", "NightLights", "TownStyle", "TownLayout", "TownProps", "PlazaFixture", "LeaderboardBoard", "DayNight"):
        source = source.replace('--!strict', '--!strict\nlocal Engine = require("./PlotEngine")\nlocal Instance, Vector3, Color3, CFrame, UDim2, workspace = Engine.Instance, Engine.Vector3, Engine.Color3, Engine.CFrame, Engine.UDim2, Engine.workspace\nlocal Enum, Vector2, UDim, warn = Engine.Enum, Engine.Vector2, Engine.UDim, Engine.warn\nlocal NumberRange, NumberSequence = Engine.NumberRange, Engine.NumberSequence')
        source = source.replace('local FigureModel = require(game:GetService("ReplicatedStorage").Shared.FigureModel)', 'local FigureModel = Engine.FigureModel')
        if name == "PlayerPlot":
            source = source.replace('--!strict', '--!strict\nlocal game = require("./PlotEngine").game\nlocal os = {clock = function() return require("./PlotEngine").clock end}', 1)
    if name in ("Rarity", "Catalog", "OpeningConfig", "ShopTheme"):
        source = source.replace("--!strict", '--!strict\nlocal Color3 = require("./OpeningVisualEngine").Color3')
    (out / f"{name}.luau").write_text(source, encoding="utf-8")


def run(*names: str) -> None:
    """Copy test files into build/tests and run each spec; stop on the first failure."""
    for name in names:
        (out / f"{name}.luau").write_text((root / "tests" / f"{name}.luau").read_text(encoding="utf-8"), encoding="utf-8")
    for name in names:
        if name.endswith(".spec"):
            result = subprocess.run([sys.argv[1], str(out / f"{name}.luau")], cwd=root)
            if result.returncode:
                raise SystemExit(result.returncode)


run("OpeningEngine", "OpeningVisualEngine", "UIEngine", "Sfx.spec", "Music.spec", "OpeningAudio.spec", "OpeningLifecycle.spec", "OpeningResources.spec", "OpeningFlight.spec", "Rarity.spec")
run("CoinEngine", "CoinCounter.spec")
run("PlayerMovement.spec")
run("UIEngine", "Screens.spec", "Onboarding.spec")
run("DisplayReplacement.spec", "Mvp.spec", "FullGame.spec", "Scroll.spec", "Opening.spec", "UI.spec", "AssetManifest.spec")
run("BlindBox.spec", "Shelves.spec", "Leaderboard.spec", "BoxesOpened.spec", "Offline.spec", "LoginRewards.spec", "AudioSettings.spec", "Tutorial.spec", "PlotEngine", "Plots.spec", "DisplayInteraction.spec")
run("PlotEngine", "HomeTeleport.spec")
run("PlotEngine", "CollectionPlates.spec")
run("PlotEngine", "ShopKeeper.spec")
fixtures = [
    ('id = "grove.pebble"', 'id = "unknown"', "Invalid economy reference"),
    ('weight = 1', 'weight = 0', "Invalid income units/weight"),
    ('units = 0.55,', 'units = 8,', "Duplicate ceiling violates rarity order"),
    ('price = 1500', 'price = -1', "Invalid tier price"),
    ('paybackSeconds = 180', 'paybackSeconds = 0', "Invalid tier pacing"),
    ('Common = 60, Uncommon = 30', 'Common = 61, Uncommon = 30', "Bucket probabilities must total 100"),
    ('maximum = 0.6, curve = 5', 'maximum = 0.6, curve = 0', "Invalid duplicate curve"),
    ('base = 1, start = 40', 'base = 2, start = 40', "Pity base differs from bucket"),
    ('start = 40', 'start = -1', "Invalid pity start"),
    ('group = "star"', 'group = "concept"', "Shared pity must use identical profiles"),
    ('pity = "standard"', 'pity = "missing"', "Unknown pity profile"),
    ('units = 0.55', 'units = 0/0', "Invalid income units/weight"),
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
print(f"PASS: {len(fixtures)} invalid-configuration startup fixtures")
