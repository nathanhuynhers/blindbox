"""Portable core glTF materials; beauty extras are deliberately separate.

Maps are file paths to authored/baked PNGs. Normal maps must be tangent-space
OpenGL (+Y). No new dependencies. PBR is opt-in to avoid texture cost on flat colors.
"""
from dataclasses import dataclass, field
import re


PRESETS = {
    "satin_vinyl": (0.38, 0.0, 1.0),
    "glossy_vinyl": (0.18, 0.0, 1.0),
    "matte_plastic": (0.65, 0.0, 1.0),
    "glossy_eyes": (0.10, 0.0, 1.0),
    "painted_resin": (0.30, 0.0, 1.0),
    "soft_fabric": (0.88, 0.0, 1.0),
    "polished_metal": (0.22, 1.0, 1.0),
    # Portable approximation; actual interference/refraction is beauty-only.
    "pearlescent": (0.28, 0.25, 1.0),
    "translucent": (0.20, 0.0, 0.45),
}


@dataclass
class Mat:
    color: object
    rough: float = 0.5
    metal: float = 0.0
    alpha: float = 1.0
    render: dict = field(default_factory=dict)
    pbr: bool = False
    color_map: str = None
    roughness_map: str = None
    metalness_map: str = None
    normal_map: str = None

    def __post_init__(self):
        colors = self.color if isinstance(self.color, list) else [self.color]
        if not colors or any(not re.fullmatch(r"#?[0-9a-fA-F]{6}", str(c)) for c in colors):
            raise ValueError("color needs hex RGB or a nonempty ramp")
        if any(not 0 <= v <= 1 for v in (self.rough, self.metal, self.alpha)):
            raise ValueError("roughness, metalness and alpha must be in [0, 1]")
        if any((self.roughness_map, self.metalness_map, self.normal_map)):
            self.pbr = True


def preset(name, color, *, pbr=False, **overrides):
    rough, metal, alpha = PRESETS[name]
    return Mat(color, **dict(dict(rough=rough, metal=metal, alpha=alpha, pbr=pbr), **overrides))
