"""Opt-in Cycles baking for opaque procedural materials / high-to-low normals.

Call while assembling a definition, before returning its spec, and keep the
returned PNG paths in materials.Mat. UVs must already be unwrapped; the builder
will preserve them. This bakes detail, never lighting or unsupported shader lobes.
"""
from pathlib import Path
import bpy


def bake_maps(obj, directory, *, resolution=512, channels=("color", "roughness", "metalness"), high=None, cage=0.02):
    """Return Mat keyword paths. high is used only for tangent-space normal baking.

    Each shader must use a Principled surface. Alpha/transmission are deliberately
    excluded; bake opaque painted/fabric detail, then specify alpha explicitly.
    Existing nodes/selection/render settings are restored even on a failed bake.
    """
    if resolution not in (128, 256, 512, 1024, 2048) or not obj.data.uv_layers:
        raise ValueError("baking needs unwrapped UVs and a supported texture size")
    if obj.mode != "OBJECT" or not obj.data.materials:
        raise ValueError("baking needs an object with Principled materials")
    if not channels or any(c not in ("color", "roughness", "metalness", "normal") for c in channels):
        raise ValueError("unsupported bake channel")
    out = Path(directory)
    out.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    engine, samples = scene.render.engine, scene.cycles.samples
    selected, active = list(bpy.context.selected_objects), bpy.context.view_layer.objects.active
    bake = scene.render.bake
    settings = {k: getattr(bake, k) for k in ("use_selected_to_active", "cage_extrusion", "margin", "normal_space", "normal_r", "normal_g", "normal_b", "use_clear")}
    targets, materials, images = [], [], []
    try:
        scene.render.engine = "CYCLES"
        scene.cycles.samples = 1
        bake.margin, bake.normal_space = 8, "TANGENT"
        bake.normal_r, bake.normal_g, bake.normal_b = "POS_X", "POS_Y", "POS_Z"
        bake.use_clear = True
        for mat in set(obj.data.materials):
            nt = mat.node_tree
            surface = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL" and n.is_active_output), None)
            if surface is None or not surface.inputs["Surface"].is_linked:
                raise ValueError("material lacks active surface")
            link = surface.inputs["Surface"].links[0]
            shader = link.from_node
            if shader.type != "BSDF_PRINCIPLED":
                raise ValueError("bake_maps supports Principled surfaces")
            previous = nt.nodes.active
            target = nt.nodes.new("ShaderNodeTexImage")
            targets.append((nt, target, previous))
            emit = nt.nodes.new("ShaderNodeEmission")
            materials.append((nt, surface, shader, link.from_socket, emit))
        paths = {}
        for channel in channels:
            image = bpy.data.images.new(f"{obj.name}_{channel}", resolution, resolution, alpha=False)
            images.append(image)
            image.colorspace_settings.name = "sRGB" if channel == "color" else "Non-Color"
            for nt, target, _ in targets:
                target.image = image
                nt.nodes.active = target
            for nt, surface, shader, original, emit in materials:
                if channel == "normal":
                    nt.links.new(original, surface.inputs["Surface"])
                else:
                    socket = shader.inputs[{"color": "Base Color", "roughness": "Roughness", "metalness": "Metallic"}[channel]]
                    for link in list(emit.inputs["Color"].links):
                        nt.links.remove(link)
                    if socket.is_linked:
                        nt.links.new(socket.links[0].from_socket, emit.inputs["Color"])
                    else:
                        value = socket.default_value
                        emit.inputs["Color"].default_value = value if channel == "color" else (value, value, value, 1)
                    nt.links.new(emit.outputs[0], surface.inputs["Surface"])
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bake.use_selected_to_active = channel == "normal" and high is not None
            bake.cage_extrusion = cage
            if bake.use_selected_to_active:
                high.select_set(True)
            bpy.ops.object.bake(type="NORMAL" if channel == "normal" else "EMIT")
            path = out / f"{obj.name}_{channel}.png"
            image.filepath_raw, image.file_format = str(path), "PNG"
            image.save()
            paths[{"color": "color_map", "roughness": "roughness_map", "metalness": "metalness_map", "normal": "normal_map"}[channel]] = str(path)
        return paths
    finally:
        for nt, surface, shader, original, emit in materials:
            nt.links.new(original, surface.inputs["Surface"])
            nt.nodes.remove(emit)
        for nt, target, previous in targets:
            nt.nodes.remove(target)
            nt.nodes.active = previous
        for image in images:
            bpy.data.images.remove(image)
        for k, value in settings.items():
            setattr(bake, k, value)
        scene.render.engine, scene.cycles.samples = engine, samples
        bpy.ops.object.select_all(action="DESELECT")
        for o in selected:
            o.select_set(True)
        bpy.context.view_layer.objects.active = active
