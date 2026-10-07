"""Peeka for the shops: a waist-up shopkeeper and the stall Peekaboo, true-colour plush finish.

Town decoration only (not a catalog figure). Reuses the Peeka sculpt in ../peeka-statues/figures.py
with lower triangle budgets, because several of these stand in the world at once. Built with:
  FIG_ASSETS=models blender -b --factory-startup --python tools/figures/build.py -- peeka-shop <slug> final
Units are studs at model scale. +Z is up, Peeka faces -Y, the character's left is +X.

Shopkeeper animation parts:
- PeekaShopkeeper_RightArm is separate and rigid. Rotate it about the shoulder ball at SHOULDER_R to
  wave. In the built model (3.25 studs tall, base at Z = 0) that is (-0.44, -0.10, 0.88): 0.44 to the
  character's right, 0.10 forward and 27% of the height up from the base. The ball stays inside the
  torso at any angle, so no gap opens.
- PeekaShopkeeper_Eyes + PeekaShopkeeper_EyeShine are the open eyes. PeekaShopkeeper_EyesClosed sits
  underneath them; hide Eyes and EyeShine to show the sleepy face.
"""

import importlib.util
import os

import numpy as np

from sdf import arc2, ellipse2, ellipsoid, overlay, smax, smin, sphere, tube

_spec = importlib.util.spec_from_file_location(
    "peeka_statues", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "peeka-statues", "figures.py"))
peeka = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(peeka)

RENDER_VIEW = peeka.RENDER_VIEW
Comp, Mat = peeka.Comp, peeka.Mat


def budget(comps, tris):
    """Overrides the statue triangle budgets by part suffix."""
    for c in comps:
        c.tris = tris[c.name.split("_", 1)[1]]
    return comps


# ------------------------------------------------------------------ shopkeeper

HEAD_C = np.array([0.0, -0.03, 1.8])
BODY_C = np.array([0.0, 0.0, 0.98])
BODY_R = (0.5, 0.44, 0.52)
WAIST = 0.5  # flat cut hidden by the counter
SHOULDER_R = np.array([-0.36, -0.08, 1.22])
BOX_C = (0.0, -0.68, 0.98)  # held box: centre of its base
BOX_HALF, BOX_TOP = 0.18, 0.35
HEM_Z = 0.62
POCKET = np.array([0.0, 0.0, 0.78])


def arm(p, sx):
    shoulder = np.array([sx * 0.36, -0.08, 1.22])
    elbow = np.array([sx * 0.52, -0.36, 1.02])
    hand = np.array([sx * 0.28, -0.66, 1.14])
    return tube(p, [shoulder, elbow, hand], [0.15, 0.135, 0.12])


def torso(p):
    return smax(ellipsoid(p, BODY_C, BODY_R), WAIST - p[2], 0.04)


def apron_region(p):
    # A front panel that widens toward the hem, top edge just under the held box.
    half_w = 0.27 + (1.26 - p[2]) * 0.2
    d = np.maximum(np.abs(p[0]) - half_w, p[2] - 1.26)
    d = np.maximum(d, (HEM_Z - 0.02) - p[2])
    return np.maximum(d, p[1] + 0.05)


def shopkeeper():
    N = "PeekaShopkeeper"
    m = peeka.palette(N, "color")
    apron_mat = (f"{N}_Apron", Mat("#CDEEDB", rough=0.6, sheen=0.3))
    lace_mat = (f"{N}_Lace", Mat("#FFFFFF", rough=0.55))
    left_paw = peeka.paw((0.28, -0.66, 1.14))
    right_paw = peeka.paw((-0.28, -0.66, 1.14))

    def body(p):
        return smin(smin(torso(p), arm(p, 1), 0.08), left_paw(p), 0.04)

    def right_arm(p):
        # The shoulder ball stays buried in the torso at any wave angle.
        return smin(smin(arm(p, -1), sphere(p, SHOULDER_R, 0.16), 0.04), right_paw(p), 0.04)

    def apron(p):
        return overlay(torso(p), apron_region(p), 0.02, depth=0.04, k=0.006)

    def lace(p):
        # A row of round white beads along the hem, on top of the apron skin.
        u = np.arctan2(p[0], -p[1]) * 0.45
        region = None
        for k in range(-5, 6):
            d = np.sqrt((u - k * 0.076) ** 2 + (p[2] - HEM_Z) ** 2) - 0.036
            region = d if region is None else np.minimum(region, d)
        region = np.maximum(region, p[1] + 0.05)
        return overlay(torso(p) - 0.02, region, 0.016, depth=0.04, k=0.003)

    def pocket(p):
        u, v = p[0] - POCKET[0], p[2] - POCKET[2]
        # A raised rim ring makes the disc read as a coin.
        rim = np.clip(1 - np.abs(np.sqrt(u * u + v * v) - 0.056) / 0.014, 0, 1)
        region = np.maximum(ellipse2(u, v, 0.09, 0.09), p[1] + 0.2)
        return overlay(torso(p) - 0.02, region, 0.016 + 0.012 * rim, depth=0.04, k=0.004)

    comps = [
        Comp(f"{N}_Body", body, m["fur"], voxel=0.01),
        Comp(f"{N}_RightArm", right_arm, m["fur"], voxel=0.008),
        Comp(f"{N}_Apron", apron, apron_mat, voxel=0.006),
        Comp(f"{N}_Lace", lace, lace_mat, voxel=0.004),
        Comp(f"{N}_CoinPocket", pocket, m["gold"], voxel=0.004),
    ]
    comps += peeka.gift_parts(N, m, BOX_C, BOX_HALF, BOX_TOP, z_band=0.27, mark_z=0.12, mark_size=0.36,
                              dots=False, recess=False)
    comps += peeka.head_parts(N, m, HEAD_C, ears="signature", lid=True)
    eye_z, ylim = HEAD_C[2] - 0.05, HEAD_C[1] - 0.23

    def eyes_closed(p):
        # Sleepy downward curves under the open eyes (peeka.face's closed eyes are happy arches).
        regs = [arc2(p[0] - sx * 0.225, p[2] - (eye_z + 0.04), 0.06, 62, 0.017) for sx in (-1, 1)]
        region = np.maximum(np.minimum(regs[0], regs[1]), p[1] - ylim)
        return overlay(peeka.head_sdf(p, HEAD_C), region, 0.01, depth=0.04, k=0.002)

    comps.append(Comp(f"{N}_EyesClosed", eyes_closed, m["eyes"], voxel=0.004))
    budget(comps, {
        "Body": 2000, "RightArm": 700, "Apron": 1100, "Lace": 900, "CoinPocket": 400,
        "Box": 700, "BoxRibbon": 400, "BoxMarks": 500,
        "Head": 4000, "InnerEars": 600, "Lid": 900, "LidRibbon": 500, "Bow": 800,
        "Eyes": 500, "EyeShine": 200, "EyesClosed": 300, "Cheeks": 300, "Nose": 100, "Mouth": 200,
    })
    bounds = ((-1.35, -1.05, WAIST - 0.1), (1.35, 1.0, 3.4))
    return peeka.assemble(N, "Peeka: Shopkeeper", "Mascot", comps, bounds, catalog=None)


# ------------------------------------------------------------------ stall Peekaboo

def stall():
    spec_comps = peeka.peekaboo("color", name="PeekaStall")
    budget(spec_comps["comps"], {
        "Head": 4000, "InnerEars": 600, "Paws": 800, "Box": 800, "BoxRibbon": 600, "BoxMarks": 1200,
        "BoxDots": 700, "Lid": 900, "LidRibbon": 500, "Bow": 800,
        "Eyes": 500, "EyeShine": 200, "Cheeks": 300, "Nose": 100, "Mouth": 200,
    })
    for c in spec_comps["comps"]:
        if c.name.endswith("_BoxDots"):
            c.min_faces = 8  # small dots fall under the default speck filter at this budget
        if c.name.endswith("_BoxMarks"):
            c.voxel = 0.0055  # the finer statue voxel leaves a sliver on the "?" hook after decimation
    return spec_comps


FIGURES = {
    "shopkeeper": shopkeeper,
    "stall": stall,
}
