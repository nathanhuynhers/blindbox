"""Synthetic geometry/material swatches. Not a character, collection or upload input.

Run with build.py -- --fixture technical final; output is confined to build/.
"""
import bpy

from materials import preset
from modeling import Comp, braid, garment_loft, hair_lock
from sdf import ellipsoid, ellipse2, front_decal, overlay


def beveled_mesh():
    bpy.ops.mesh.primitive_cube_add(size=0.6, location=(2.5, 0, 0.5))
    obj = bpy.context.object
    bevel = obj.modifiers.new("AuthoredBevel", "BEVEL")
    bevel.width, bevel.segments = 0.06, 3
    return obj


def technical():
    body = lambda p: ellipsoid(p, (-1, 0, 0.5), (0.4, 0.35, 0.45))
    head = lambda p: ellipsoid(p, (0, 0, 0.5), (0.3, 0.3, 0.3))
    skin = lambda p: overlay(head(p), front_decal(p, 0, 0.5, lambda u, v: ellipse2(u, v, 0.14, 0.10)), 0.012, 0.012)
    comps = [
        Comp("PipelineFixture_SDF", body, "vinyl", quality="simple", voxel=0.018,
             bounds=((-1.6, -0.6, -0.1), (-0.4, 0.6, 1.1)), max_surface_error=0.02),
        Comp("PipelineFixture_Eyes", skin, "eyes", quality="high", voxel=0.006, min_feature=0.024,
             bounds=((-0.4, -0.4, 0.1), (0.4, 0.1, 0.9)), max_surface_error=0.008),
        Comp("PipelineFixture_Lock", None, "resin", mesh=lambda: hair_lock(
            [(0.6, 0, 0.25), (0.75, -0.2, 0.6), (0.65, 0, 1.0)], [0.12, 0.15, 0.03], [0.05, 0.07, 0.025])),
        Comp("PipelineFixture_Garment", None, "fabric", mesh=lambda: garment_loft(
            [(1.5, 0, 0.1), (1.5, 0, 0.5), (1.5, 0, 0.85)], [(0.32, 0.28), (0.27, 0.23), (0.20, 0.18)],
            thickness=0.04, folds=8, fold_depth=0.02)),
        Comp("PipelineFixture_Native", None, "metal", mesh=beveled_mesh, smooth=False),
        Comp("PipelineFixture_Braid", None, "vinyl", expected_islands=3, mesh=lambda: braid(
            [(3.3, 0, 0.2), (3.4, 0.1, 0.6), (3.3, 0, 1.0)], radius=0.035, spread=0.045, turns=2)),
    ]
    return dict(name="PipelineFixture", title="Technical swatches", rarity="Common", catalog="test.fixture",
                comps=comps, bounds=((-2, -1, -1), (4, 1, 2)), mats={
                    "vinyl": preset("satin_vinyl", "#80A0C0"),
                    "eyes": preset("glossy_eyes", "#181820", pbr=True),
                    "resin": preset("painted_resin", "#D04030", pbr=True, render={"coat": 0.8}),
                    "fabric": preset("soft_fabric", "#608040", pbr=True),
                    "metal": preset("polished_metal", "#A0A0A0", pbr=True),
                })


FIGURES = {"technical": technical}
