"""Bake two Rocketbox characters and their movement into self-contained Godot GLBs.

Run prepare_textures.py first, then pass its source cache after Blender's --.
"""

import math
import sys
from pathlib import Path
import bpy
from mathutils import Quaternion, Vector

root = Path(__file__).resolve().parents[2]
cache = Path(sys.argv[sys.argv.index("--") + 1])


def map_material(mat, folder):
    tag = mat.name.lower()
    key = next(
        (x for x in ("opacity", "helmet", "tools", "head", "body") if x in tag), "body"
    )
    clr = next(iter(folder.glob("*_" + key + "_color*.png")), None)
    if not clr:
        return
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    link = mat.node_tree.links.new
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.inputs["Roughness"].default_value = 0.73
    out = nodes.new("ShaderNodeOutputMaterial")
    link(shader.outputs[0], out.inputs[0])
    tx = nodes.new("ShaderNodeTexImage")
    tx.image = bpy.data.images.load(str(clr), check_existing=True)
    link(tx.outputs["Color"], shader.inputs["Base Color"])
    if key == "opacity":
        link(tx.outputs["Alpha"], shader.inputs["Alpha"])
        mat.surface_render_method = "DITHERED"
        mat.use_backface_culling = False
    nm = next(iter(folder.glob("*_" + key + "_normal.png")), None)
    if nm:
        nt = nodes.new("ShaderNodeTexImage")
        nt.image = bpy.data.images.load(str(nm), check_existing=True)
        nt.image.colorspace_settings.name = "Non-Color"
        normal = nodes.new("ShaderNodeNormalMap")
        normal.inputs["Strength"].default_value = 0.48
        link(nt.outputs["Color"], normal.inputs["Color"])
        link(normal.outputs["Normal"], shader.inputs["Normal"])


def anim(rig, name, length):
    rig.animation_data_create()
    action = bpy.data.actions.new(name)
    rig.animation_data.action = action
    bones = rig.pose.bones

    def pose_bone(key, world_delta, frame):
        b = bones.get("Bip01 " + key)
        if b is None:
            return
        basis = (rig.matrix_world @ b.bone.matrix_local).to_quaternion()
        b.rotation_mode = "QUATERNION"
        b.rotation_quaternion = basis.inverted() @ world_delta @ basis
        b.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=key)

    zaxis = Vector((0, 0, 1))
    xaxis = Vector((1, 0, 0))
    yaxis = Vector((0, 1, 0))
    for fraction in [0, 0.25, 0.5, 0.75, 1]:
        phase = math.sin(2 * math.pi * fraction)
        f = 1 + round(fraction * length)
        for side in ("L", "R"):
            s = 1 if side == "L" else -1
            upper = bones["Bip01 " + side + " UpperArm"]
            fore = bones["Bip01 " + side + " Forearm"]
            shoulder = rig.matrix_world @ upper.bone.head_local
            elbow = rig.matrix_world @ fore.bone.head_local
            d = (elbow - shoulder).normalized()
            goal = Vector((math.copysign(0.24, d.x), -0.04, -1)).normalized()
            arm = d.rotation_difference(goal)
            swing = (
                phase * s * 0.47
                if name == "Walk"
                else (
                    0.70
                    if name == "Commit" and side == "R"
                    else 0.15
                    if name == "Alarm"
                    else 0.028 * phase
                )
            )
            pose_bone(side + " UpperArm", Quaternion(xaxis, -swing) @ arm, f)
            pose_bone(
                side + " Forearm",
                Quaternion(xaxis, -(0.63 if name == "Commit" else 0.16)),
                f,
            )
            pose_bone(
                side + " Thigh",
                Quaternion(xaxis, phase * s * 0.40 if name == "Walk" else -0.045),
                f,
            )
            pose_bone(
                side + " Calf",
                Quaternion(
                    xaxis, max(0, -phase * s) * 0.56 if name == "Walk" else 0.052
                ),
                f,
            )
            pose_bone(
                side + " Foot",
                Quaternion(xaxis, -0.13 * max(0, -phase * s) if name == "Walk" else 0),
                f,
            )
        pose_bone(
            "Spine2", Quaternion(xaxis, 0.065 if name == "Commit" else 0.025 * phase), f
        )
        pose_bone(
            "Head",
            Quaternion(zaxis, 0.16 if name == "Alarm" else 0.024 * phase)
            @ Quaternion(xaxis, -0.14 if name == "Relief" else 0),
            f,
        )
    rig.animation_data.action = None
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, action)
    strip.name = name
    track.mute = True


for name in ["Nell", "Rafi"]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    folder = cache / name
    bpy.ops.import_scene.fbx(filepath=str(folder / "figure.fbx"), use_anim=False)
    for mat in list(bpy.data.materials):
        map_material(mat, folder)
    rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    for o in bpy.context.scene.objects:
        if o.animation_data:
            o.animation_data_clear()
        if o.type == "MESH" and o.data.shape_keys:
            for key in list(o.data.shape_keys.key_blocks)[1:]:
                k = key.name.lower()
                if not any(
                    x in k
                    for x in (
                        "smile",
                        "brow",
                        "blink",
                        "jaw",
                        "cheek",
                        "surprise",
                        "frown",
                        "happy",
                        "sad",
                        "mouthcorner",
                        "10_aa",
                    )
                ):
                    o.shape_key_remove(key)
            print(
                "EXPRESSIONS",
                name,
                [k.name for k in o.data.shape_keys.key_blocks]
                if o.data.shape_keys
                else [],
            )
    for move, duration in [
        ("Idle", 48),
        ("Walk", 24),
        ("Commit", 28),
        ("Alarm", 28),
        ("Relief", 36),
    ]:
        anim(rig, move, duration)
    bpy.context.scene.render.fps = 24
    bpy.context.scene.frame_set(1)
    bpy.ops.export_scene.gltf(
        filepath=str(root / "assets" / "cast" / (name.lower() + ".glb")),
        export_format="GLB",
        export_yup=True,
        export_animation_mode="NLA_TRACKS",
        export_all_influences=False,
        export_morph=True,
        export_morph_normal=False,
        export_morph_tangent=False,
    )
