"""Shared low-poly machining, fabric and joint geometry for the illustrated dock crew."""

import math
import os
import sys
from pathlib import Path
from mathutils import Vector
import bpy

OUT = Path(__file__).resolve().parents[2] / "assets" / "cast"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
pi = math.pi
r = math.radians


def color(h):
    raw = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(
        v / 12.92 if v < 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in raw
    ) + (1,)


def material(name, h, rough=0.43, metal=0, glow=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = color(h)
    m.use_nodes = True
    shader = m.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color(h)
    shader.inputs["Roughness"].default_value = rough
    shader.inputs["Metallic"].default_value = metal
    if glow:
        shader.inputs["Emission Color"].default_value = color(h)
        shader.inputs["Emission Strength"].default_value = glow
    return m


M = {}
for name, h, rough, metal, glow in [
    ("rubber", "263336", 0.53, 0.08, 0),
    ("joint", "435052", 0.34, 0.55, 0),
    ("cream", "F0DFB4", 0.42, 0.11, 0),
    ("ivory", "E8E2CC", 0.30, 0.38, 0),
    ("brass", "BF8A4E", 0.27, 0.72, 0),
    ("copper", "B97549", 0.32, 0.60, 0),
    ("orange", "DF773E", 0.37, 0.40, 0),
    ("orange2", "A34B2D", 0.44, 0.30, 0),
    ("canvas", "D5B084", 0.84, 0.02, 0),
    ("netedge", "EFE2B8", 0.58, 0.04, 0),
    ("eye", "23363C", 0.15, 0.38, 0),
    ("lamp", "8DE9DB", 0.24, 0.09, 0.62),
    ("blue", "2D315E", 0.33, 0.28, 0),
    ("wing", "61558F", 0.30, 0.27, 0),
    ("vein", "C79DD8", 0.26, 0.10, 0.24),
    ("drop", "8F738B", 0.42, 0.24, 0),
    ("red", "B74635", 0.68, 0.05, 0),
    ("bag", "916B48", 0.70, 0.08, 0),
    ("teal", "327F7C", 0.60, 0.08, 0),
    ("teal2", "225A5E", 0.64, 0.12, 0),
    ("plum", "78475F", 0.66, 0.09, 0),
    ("plum2", "583944", 0.66, 0.10, 0),
    ("faceN", "BF886B", 0.58, 0.01, 0),
    ("faceR", "9D7155", 0.61, 0.01, 0),
    ("hair", "352D2B", 0.62, 0.04, 0),
    ("brow", "493B37", 0.73, 0.01, 0),
    ("lips", "865E56", 0.60, 0.02, 0),
    ("amber", "F4C46F", 0.30, 0.08, 0.41),
    ("deck", "536566", 0.72, 0.12, 0),
    ("base", "B9BCAD", 0.67, 0.07, 0),
    ("steel", "849697", 0.32, 0.61, 0),
    ("white", "E5D9C2", 0.48, 0.04, 0),
    ("pink", "C49685", 0.63, 0.01, 0),
]:
    M[name] = material(name, h, rough, metal, glow)


def coll(name):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    return c


studio = coll("Studio | lights, floor and animated camera")
where = studio


def move_collection(obj):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    where.objects.link(obj)


def parent(obj, p):
    if p:
        obj.parent = p
    return obj


def empty(name, p=None, loc=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    where.objects.link(obj)
    obj.empty_display_size = 0.09
    parent(obj, p)
    obj.location = loc
    return obj


def assign(obj, name):
    obj.data.materials.append(M[name])


def mesh(name, p, verts, faces, mat, smooth=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    where.objects.link(obj)
    assign(obj, mat)
    parent(obj, p)
    if smooth:
        for f in data.polygons:
            f.use_smooth = True
    return obj


protos = {}


def primitive(shape, mat):
    key = (shape, mat)
    if key in protos:
        return protos[key]
    if shape == "orb":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=14)
    elif shape == "box":
        bpy.ops.mesh.primitive_cube_add()
        obj = bpy.context.object
        m = obj.modifiers.new("Rounded edges", "BEVEL")
        m.width = 0.16
        m.segments = 3
        bpy.ops.object.modifier_apply(modifier=m.name)
        m = obj.modifiers.new("Face normals", "WEIGHTED_NORMAL")
        bpy.ops.object.modifier_apply(modifier=m.name)
    elif shape == "bar":
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=1, depth=2)
        obj = bpy.context.object
        m = obj.modifiers.new("Machined edges", "BEVEL")
        m.width = 0.055
        m.segments = 2
        bpy.ops.object.modifier_apply(modifier=m.name)
    else:
        major, minor = shape
        bpy.ops.mesh.primitive_torus_add(
            major_segments=56, minor_segments=12, major_radius=major, minor_radius=minor
        )
    obj = bpy.context.object
    data = obj.data
    data.name = f"{shape} | {mat}"
    assign(obj, mat)
    if shape != "box":
        for f in data.polygons:
            if shape != "bar" or len(f.vertices) < 10:
                f.use_smooth = True
    data.use_fake_user = True
    bpy.data.objects.remove(obj, do_unlink=True)
    protos[key] = data
    return data


def part(shape, n, p, loc, sz, mat, rot=(0, 0, 0)):
    obj = bpy.data.objects.new(n, primitive(shape, mat))
    where.objects.link(obj)
    parent(obj, p)
    obj.location = loc
    obj.scale = sz
    obj.rotation_euler = rot
    return obj


def orb(n, p, loc, sz, mat, rot=(0, 0, 0)):
    return part("orb", n, p, loc, sz, mat, rot)


def box(n, p, loc, sz, mat, rot=(0, 0, 0)):
    return part("box", n, p, loc, sz, mat, rot)


def barrel(n, p, loc, sz, mat, rot=(0, 0, 0)):
    return part("bar", n, p, loc, sz, mat, rot)


def loop(n, p, loc, major, minor, mat, rot=(0, 0, 0), sz=(1, 1, 1)):
    return part((major, minor), n, p, loc, sz, mat, rot)


def rod(n, p, a, b, rad, mat, ry=None):
    v = Vector(b) - Vector(a)
    mid = (Vector(a) + Vector(b)) * 0.5
    obj = barrel(n, p, mid, (rad, rad if ry is None else ry, v.length * 0.5), mat)
    obj.rotation_euler = v.to_track_quat("Z", "Y").to_euler()
    return obj


def cord(n, p, pts, rad, mat, cyclic=False):
    curve = bpy.data.curves.new(n, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 6
    curve.bevel_depth = rad
    curve.bevel_resolution = 2
    s = curve.splines.new("BEZIER")
    s.bezier_points.add(len(pts) - 1)
    for pt, co in zip(s.bezier_points, pts):
        pt.co = co
        pt.handle_left_type = pt.handle_right_type = "AUTO"
    s.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(n, curve)
    where.objects.link(obj)
    assign(obj, mat)
    parent(obj, p)
    return obj


def panel(n, p, a, b, rad, mat):
    v = Vector(b) - Vector(a)
    ob = orb(
        n, p, (Vector(a) + Vector(b)) * 0.5, (rad, rad * 0.93, v.length * 0.60), mat
    )
    ob.rotation_euler = v.to_track_quat("Z", "Y").to_euler()
    return ob


def thick(obj, t):
    mod = obj.modifiers.new("Surface thickness", "SOLIDIFY")
    mod.thickness = t
    return obj


def signcurve(n, p, pts, rad, mat):
    return cord(n, p, pts, rad, mat)


roots = {}
rigs = {}


def new_actor(n, x):
    global where
    where = coll(n + " | cast")
    roots[n] = empty(n + " | identity", loc=(x, 0, 0))
    rigs[n] = {}
    return roots[n], rigs[n]


def dots(n, p, pts, rad, mat):
    for i, pt in enumerate(pts):
        orb(n + str(i + 1), p, pt, (rad, rad, rad), mat)
