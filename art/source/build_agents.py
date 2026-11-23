"""Build the three articulated dockworkers from the supplied cast reference."""

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent))
from meshwork import *

cache = (
    Path(sys.argv[sys.argv.index("--") + 1])
    if "--" in sys.argv
    else OUT.parent.parent / ".art-cache"
)
for mat in M.values():
    src = cache / (mat.name + ".jpg")
    if src.exists():
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str(src), check_existing=True)
        mat.node_tree.links.new(
            tex.outputs["Color"],
            mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"],
        )
M["honey"] = material("Honey eye diode", "FFC77A", 0.20, 0.11, 1.30)
M["whiteled"] = material("Ivory eye diode", "FFF3D4", 0.23, 0.06, 1.10)
M["skateled"] = material("Skate induction", "B2D8EF", 0.30, 0.13, 0.85)


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def bolts(p, pts, size=0.014):
    for pt in pts:
        orb("Recessed rivet", p, pt, (size, size * 0.62, size), "steel")


def badge(p, loc, sz):
    x, y, z = loc
    box("Stitched field patch", p, loc, (sz, 0.009, sz * 0.70), "cream")
    for i in [-1, 0, 1]:
        box(
            "Embroidered bar",
            p,
            (x + i * sz * 0.43, y - 0.012, z),
            (sz * 0.095, 0.004, sz * 0.44),
            "orange2",
        )


def flange(p, loc, rad, mat="brass"):
    obj = barrel(
        "Shoulder bearing", p, loc, (rad, rad, rad * 0.40), mat, (0, pi / 2, 0)
    )
    return obj


def arm(root, side, sh, el, hand, paint, th):
    arm = empty("PivotArm" + ("L" if side < 0 else "R"), root, sh)
    e = sub(el, sh)
    h = sub(hand, sh)
    flange(arm, (0, 0, 0), th * 1.05)
    rod("Inner piston", arm, (0, 0, 0), e, th * 0.45, "joint")
    panel("Upper arm plate", arm, (0, 0, -0.015), e, th * 0.80, paint)
    orb("Elbow joint", arm, e, (th * 0.76, th * 0.69, th * 0.72), "rubber")
    flange(arm, e, th * 0.62, "steel")
    rod("Forearm piston", arm, e, h, th * 0.40, "steel")
    panel("Forearm guard", arm, e, h, th * 0.68, paint)
    orb("Palm", arm, h, (th * 0.76, th * 0.65, th * 0.85), "rubber")
    for j in range(4):
        f = (h[0] + (j - 1.5) * th * 0.30, h[1] - 0.018, h[2] - 0.039)
        orb("Articulated finger", arm, f, (th * 0.145, th * 0.47, th * 0.61), "joint")
        orb(
            "Finger pad",
            arm,
            (f[0], f[1] - 0.015, f[2] - 0.019),
            (th * 0.14, th * 0.36, th * 0.35),
            "rubber",
        )
    orb(
        "Opposing thumb",
        arm,
        (h[0] - side * th * 0.60, h[1] - 0.021, h[2] + 0.006),
        (th * 0.23, th * 0.45, th * 0.50),
        "joint",
    )
    return arm, h


def legs(root, side, hip, knee, foot, paint, th, skate=False):
    p = empty("PivotLeg" + ("L" if side < 0 else "R"), root, hip)
    k = sub(knee, hip)
    f = sub(foot, hip)
    a = (0, 0, 0)
    orb("Hip ball", p, a, (th * 0.9, th * 0.89, th * 0.91), "joint")
    rod("Load spine", p, a, k, th * 0.45, "steel")
    panel("Thigh armour", p, a, k, th * 0.81, paint)
    orb("Knee ring", p, k, (th * 0.81, th * 0.74, th * 0.74), "joint")
    rod("Shin support", p, k, f, th * 0.42, "brass")
    panel("Shin shell", p, k, f, th * 0.78, paint)
    box(
        "Magnetic boot",
        p,
        (f[0], f[1] - 0.032, f[2] + 0.026),
        (th * 0.94, th * 1.44, th * 0.57),
        paint,
        (0.045, 0, 0),
    )
    box(
        "Rubber sole",
        p,
        (f[0], f[1] - 0.034, f[2] - 0.025),
        (th * 0.98, th * 1.49, 0.029),
        "rubber",
    )
    for j in range(3):
        box(
            "Boot status bar",
            p,
            (f[0], f[1] - th * 1.45, f[2] + 0.038 + j * 0.019),
            (th * 0.50, 0.012, 0.006),
            "honey",
        )
    if skate:
        box(
            "Magnetic skate runner",
            p,
            (f[0], f[1] - 0.04, f[2] - 0.057),
            (th * 0.85, th * 1.62, 0.018),
            "steel",
        )
        box(
            "Cold skate light",
            p,
            (f[0], f[1] - 0.04, f[2] - 0.073),
            (th * 0.75, th * 1.48, 0.008),
            "skateled",
        )
    return p


def led_array(p, x, y, z, rad):
    for a in range(-2, 3):
        for b in range(-2, 3):
            if a * a + b * b <= 5:
                orb(
                    "Amber matrix LED",
                    p,
                    (x + a * rad * 0.36, y, z + b * rad * 0.36),
                    (rad * 0.123, 0.0035, rad * 0.123),
                    "honey",
                )


def pip():
    root, _ = new_actor("Pip", 0)
    orb(
        "Counterweighted power belly",
        root,
        (0, 0, 0.584),
        (0.28, 0.23, 0.255),
        "orange",
    )
    orb("Lower bumper", root, (0, 0.018, 0.475), (0.267, 0.216, 0.128), "orange2")
    box("Chest carapace", root, (0, -0.125, 0.626), (0.218, 0.113, 0.135), "orange")
    box(
        "Painted rescue stripe",
        root,
        (0, -0.234, 0.641),
        (0.204, 0.009, 0.029),
        "cream",
    )
    box("Hatch latch", root, (0, -0.221, 0.509), (0.070, 0.015, 0.026), "joint")
    box("Hatch window", root, (0, -0.240, 0.510), (0.047, 0.005, 0.009), "honey")
    for s in [-1, 1]:
        bolts(root, [(s * 0.18, -0.236, 0.705), (s * 0.18, -0.232, 0.57)])
        legs(
            root,
            s,
            (s * 0.158, 0, 0.46),
            (s * 0.22, -0.012, 0.29),
            (s * 0.237, -0.02, 0.109),
            "orange",
            0.098,
        )
    neck = barrel("Neck bearing", root, (0, 0, 0.795), (0.10, 0.10, 0.046), "joint")
    head = empty("CastHead", root, (0, 0, 0.889))
    box(
        "Orange welding helmet",
        head,
        (0, 0.007, 0.042),
        (0.217, 0.147, 0.135),
        "orange",
    )
    box("Face bezel", head, (0, -0.135, 0.041), (0.196, 0.027, 0.098), "brass")
    box("Charcoal glass face", head, (0, -0.160, 0.042), (0.182, 0.013, 0.084), "eye")
    for side in [-1, 1]:
        led_array(head, side * 0.079, -0.176, 0.050, 0.037)
        flange(head, (side * 0.211, 0.017, 0.04), 0.070, "joint")
    rod(
        "Flexible aerial",
        head,
        (-0.119, 0.06, 0.157),
        (-0.16, 0.085, 0.325),
        0.009,
        "joint",
    )
    orb("Aerial tip", head, (-0.16, 0.085, 0.325), (0.013, 0.013, 0.017), "orange")
    left, h = arm(
        root,
        -1,
        (-0.25, 0.004, 0.712),
        (-0.299, -0.014, 0.52),
        (-0.307, -0.103, 0.395),
        "orange",
        0.07,
    )
    right, h = arm(
        root,
        1,
        (0.248, 0, 0.723),
        (0.325, -0.025, 0.692),
        (0.382, -0.14, 0.853),
        "orange",
        0.072,
    )
    pole = empty("NetPole", right, h)
    lower = (0.059, 0, -0.34)
    top = (-0.085, -0.026, 0.454)
    rod("Long insulated net pole", pole, lower, top, 0.023, "steel")
    for j in range(8):
        f = j / 12.0
        pt = tuple(lower[k] + (top[k] - lower[k]) * f for k in range(3))
        barrel(
            "Canvas handle wrapping",
            pole,
            pt,
            (0.026, 0.025, 0.011),
            "netedge",
            (0, -0.18, 0),
        )
    hoop = empty("Net hinge", pole, top)
    hoop.rotation_euler = (r(-8), r(-15), r(-7))
    radius = 0.365
    for j in range(7):
        u = j / 6.0
        rad = radius * (0.12 + 0.88 * u**0.76)
        z = 0.35 * u - 0.29
        pts = [
            (rad * math.cos(2 * pi * i / 30), rad * 0.60 * math.sin(2 * pi * i / 30), z)
            for i in range(30)
        ]
        cord(
            "Grip-safe rim" if j == 6 else "Knotted net ring",
            hoop,
            pts,
            0.014 if j == 6 else 0.0035,
            "brass" if j == 6 else "netedge",
            True,
        )
    for i in range(22):
        for flip in [-1, 1]:
            pts = []
            for j in range(7):
                u = j / 6.0
                a = 2 * pi * i / 22 + flip * (1 - u) * 0.38
                rad = radius * (0.12 + 0.88 * u**0.76)
                pts.append(
                    (rad * math.cos(a), rad * 0.60 * math.sin(a), 0.35 * u - 0.29)
                )
            cord("Crosswoven net", hoop, pts, 0.0030, "netedge")
    for j in range(4):
        loop(
            "Rescue rope coil",
            root,
            (-0.266, -0.003 - j * 0.017, 0.586),
            0.096,
            0.013,
            "canvas",
            (pi / 2, 0.06, 0),
            (0.65, 1.15, 1),
        )
    box("Tool pouch", root, (0.175, -0.176, 0.412), (0.074, 0.055, 0.081), "bag")
    badge(root, (-0.099, -0.242, 0.685), 0.041)
    return root


def morrow():
    root, _ = new_actor("Morrow", 0)
    for s in [-1, 1]:
        legs(
            root,
            s,
            (s * 0.115, 0.015, 0.912),
            (s * 0.149, -0.015, 0.51),
            (s * 0.162, 0.002, 0.094),
            "brass",
            0.073,
        )
    rod("Brass spine", root, (0, 0, 0.89), (0, 0, 1.48), 0.070, "brass")
    box(
        "Reel to reel chassis", root, (0, -0.006, 1.315), (0.218, 0.121, 0.188), "brass"
    )
    box("Shadowed faceplate", root, (0, -0.132, 1.333), (0.192, 0.016, 0.139), "rubber")
    for side in [-1, 1]:
        reel = empty(
            "ReelSpindle" + ("L" if side < 0 else "R"),
            root,
            (side * 0.09, -0.157, 1.361),
        )
        barrel(
            "Brushed tape reel",
            reel,
            (0, 0, 0),
            (0.080, 0.080, 0.012),
            "cream",
            (pi / 2, 0, 0),
        )
        for k in range(3):
            angle = k * 2 * pi / 3
            orb(
                "Tape reel opening",
                reel,
                (0.041 * math.sin(angle), -0.013, 0.041 * math.cos(angle)),
                (0.020, 0.004, 0.026),
                "joint",
                (0, angle + 0.30, 0),
            )
        barrel(
            "Spindle pin",
            reel,
            (0, -0.021, 0),
            (0.011, 0.011, 0.008),
            "brass",
            (pi / 2, 0, 0),
        )
    for j in range(6):
        orb(
            "Recorder key",
            root,
            ((j - 2.5) * 0.046, -0.151, 1.218),
            (0.012, 0.009, 0.012),
            "honey" if j in (0, 4) else "brass",
        )
    for s in [-1, 1]:
        bolts(root, [(s * 0.199, -0.130, 1.475), (s * 0.199, -0.133, 1.153)])
    box("Leather waist band", root, (0, 0.001, 1.027), (0.169, 0.11, 0.042), "bag")
    for s in [-1, 1]:
        verts = [
            (s * 0.015, -0.119, 1.01),
            (s * 0.146, -0.098, 1.012),
            (s * 0.215, -0.096, 0.444),
            (s * 0.025, -0.155, 0.473),
        ]
        thick(mesh("Split canvas apron", root, verts, [(0, 1, 2, 3)], "canvas"), 0.012)
        for j in range(2):
            z = 0.60 + j * 0.052
            v = [
                (s * 0.028, -0.153, z),
                (s * 0.197, -0.103, z + 0.051),
                (s * 0.197, -0.104, z + 0.070),
                (s * 0.028, -0.154, z + 0.021),
            ]
            thick(mesh("Apron oxide stripe", root, v, [(0, 1, 2, 3)], "red"), 0.004)
    box("Archive pouch", root, (-0.18, -0.018, 0.835), (0.075, 0.080, 0.112), "bag")
    rod("Neck and gimbal", root, (0, 0, 1.50), (0, 0, 1.632), 0.059, "joint")
    head = empty("CastHead", root, (0, -0.010, 1.719))
    orb("Brass skull", head, (0, 0.012, 0.012), (0.130, 0.118, 0.143), "brass")
    box("Lower face mask", head, (0, -0.073, -0.046), (0.085, 0.052, 0.079), "brass")
    box("Speech grille", head, (0, -0.125, -0.058), (0.052, 0.009, 0.012), "joint")
    orb("Round field cap", head, (0, 0.008, 0.093), (0.157, 0.146, 0.072), "brass")
    orb("Cap brim", head, (0, -0.027, 0.067), (0.165, 0.165, 0.022), "copper")
    for s in [-1, 1]:
        barrel(
            "Optical bezel",
            head,
            (s * 0.060, -0.102, 0.027),
            (0.052, 0.052, 0.022),
            "joint",
            (pi / 2, 0, 0),
        )
        orb(
            "Amber glass optic",
            head,
            (s * 0.060, -0.128, 0.029),
            (0.036, 0.019, 0.037),
            "honey",
        )
        flange(head, (s * 0.134, 0, -0.004), 0.045, "copper")
    rod(
        "Aerial stalk",
        head,
        (-0.123, 0.032, 0.097),
        (-0.177, 0.058, 0.217),
        0.008,
        "brass",
    )
    loop(
        "Listening aerial",
        head,
        (-0.172, 0.055, 0.190),
        0.031,
        0.006,
        "brass",
        (pi / 2, 0, 0),
    )
    arm(
        root,
        -1,
        (-0.224, 0.01, 1.43),
        (-0.299, 0.02, 1.205),
        (-0.264, -0.066, 0.989),
        "brass",
        0.068,
    )
    arm(
        root,
        1,
        (0.223, 0.01, 1.423),
        (0.287, 0.002, 1.235),
        (0.239, -0.158, 1.166),
        "brass",
        0.067,
    )
    book = empty("Herd archive book", root, (0.245, -0.138, 1.18))
    book.rotation_euler = (r(-14), r(17), r(-7))
    box("Paper edges", book, (0, 0, 0), (0.081, 0.030, 0.126), "cream")
    for y in [-0.034, 0.034]:
        box("Book boards", book, (0, y, 0), (0.087, 0.008, 0.133), "bag")
    for j in range(6):
        box(
            "Paper signatures",
            book,
            (0.081, -0.024 + j * 0.009, 0),
            (0.003, 0.002, 0.117),
            "canvas",
        )
    return root


def zip_():
    root, _ = new_actor("Zip", 0)
    for s in [-1, 1]:
        legs(
            root,
            s,
            (s * 0.115, 0.012, 0.815),
            (s * 0.17, -0.012, 0.469),
            (s * 0.206, 0.004, 0.118),
            "ivory",
            0.069,
            True,
        )
    orb("Waist swivel", root, (0, 0, 0.886), (0.125, 0.077, 0.125), "joint")
    orb("Ivory courier chest", root, (0, -0.014, 1.113), (0.178, 0.115, 0.235), "ivory")
    box(
        "Chest inset",
        root,
        (0.073, -0.113, 1.167),
        (0.044, 0.010, 0.031),
        "brass",
        (0, 0.21, 0),
    )
    for s in [-1, 1]:
        cord(
            "Inset seam",
            root,
            [
                (s * 0.085, -0.089, 1.24),
                (s * 0.134, -0.087, 1.14),
                (s * 0.103, -0.084, 1.064),
            ],
            0.006,
            "joint",
        )
    rod("Spring neck", root, (0, 0, 1.281), (0, 0, 1.399), 0.033, "joint")
    hd = empty("CastHead", root, (0, -0.005, 1.492))
    hd.rotation_euler = (0, r(-7), 0)
    orb("Ivory head dome", hd, (0, 0, 0.018), (0.157, 0.128, 0.128), "ivory")
    box("Rounded helmet shell", hd, (0, -0.026, 0.009), (0.151, 0.098, 0.093), "ivory")
    box("Dark convex visor", hd, (0, -0.116, 0.019), (0.135, 0.037, 0.072), "eye")
    for s in [-1, 1]:
        box(
            "White expression bar",
            hd,
            (s * 0.059, -0.153, 0.024),
            (0.012, 0.005, 0.041),
            "whiteled",
            (0, -s * 0.13, 0),
        )
        mesh(
            "Courier ear fin",
            hd,
            [
                (s * 0.125, 0, 0.06),
                (s * 0.257, 0.062, -0.016),
                (s * 0.135, 0.035, -0.026),
                (s * 0.137, -0.001, 0.04),
            ],
            [(0, 1, 2), (0, 2, 3)],
            "ivory",
        )
    arm(
        root,
        -1,
        (-0.172, 0.0, 1.233),
        (-0.260, -0.010, 1.073),
        (-0.205, -0.066, 0.967),
        "ivory",
        0.056,
    )
    arm(
        root,
        1,
        (0.175, 0.0, 1.228),
        (0.257, -0.018, 1.130),
        (0.280, -0.080, 1.271),
        "ivory",
        0.055,
    )
    sat = empty("Courier satchel", root, (-0.175, -0.021, 0.824))
    sat.rotation_euler = (0, r(-11), r(-6))
    box("Mail satchel", sat, (0, 0, 0), (0.128, 0.090, 0.102), "bag")
    box("Mail bag flap", sat, (0, -0.088, 0.040), (0.128, 0.019, 0.061), "canvas")
    for s in [-1, 1]:
        box(
            "Mail bag buckle",
            sat,
            (s * 0.07, -0.103, -0.021),
            (0.016, 0.009, 0.046),
            "brass",
        )
    cord(
        "Courier shoulder belt",
        root,
        [
            (0.126, -0.032, 1.254),
            (0.032, -0.128, 1.151),
            (-0.066, -0.116, 1.033),
            (-0.159, -0.093, 0.854),
        ],
        0.023,
        "bag",
    )
    return root


def merge_static_hardware(collection):
    """Batch fixed pieces under each articulated parent. The face's optical elements stay independent."""
    groups = {}
    for part in list(collection.objects):
        if part.type != "MESH" or part.children or not part.parent:
            continue
        if part.name.startswith(("Amber matrix LED", "White expression bar")):
            continue
        groups.setdefault(part.parent, []).append(part)
    for pivot, parts in groups.items():
        if len(parts) < 2:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for piece in parts:
            piece.select_set(True)
        first = parts[0]
        first.data = first.data.copy()
        bpy.context.view_layer.objects.active = first
        bpy.ops.object.join()
        first.name = "Fitted hardware of " + pivot.name


for name, build in [("Pip", pip), ("Morrow", morrow), ("Zip", zip_)]:
    root = build()
    col = root.users_collection[0]
    bpy.ops.object.select_all(action="DESELECT")
    curves = [o for o in col.objects if o.type == "CURVE"]
    for o in curves:
        o.select_set(True)
    if curves:
        bpy.context.view_layer.objects.active = curves[0]
        bpy.ops.object.convert(target="MESH")
    merge_static_hardware(col)
    bpy.ops.object.select_all(action="DESELECT")
    for o in col.objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / (name.lower() + ".glb")),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_animations=False,
    )
