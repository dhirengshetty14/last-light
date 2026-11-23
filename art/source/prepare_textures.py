"""Convert the vendor maps for glTF; preserve skin, hair, features and safety stripes."""

from pathlib import Path
import sys
import numpy as np
from PIL import Image

cache = Path(sys.argv[1])
for name in ("Nell", "Rafi"):
    dest = cache / name
    for src in sorted(dest.glob("*.tga")):
        im = Image.open(src).convert("RGBA")
        im.thumbnail(
            (1536, 1536) if "head_color" in src.stem else (1024, 1024),
            Image.Resampling.LANCZOS,
        )
        v = np.array(im)
        if "body_color" in src.stem:
            rgb = v[:, :, :3].astype(float)
            red, green, blue = rgb.transpose(2, 0, 1)
            mask = (blue > red * 1.27) & (blue > green * 1.09) & (blue > 17)
            intensity = np.maximum.reduce([red, green, blue])
            if name == "Rafi":
                mask = (
                    (intensity < 148) & (red - green < 42) & (green - blue < 43)
                ) | mask
                intensity = np.minimum(232.0, 34 + intensity * 0.91)
            t = np.array([0.23, 0.61, 0.57] if name == "Nell" else [0.69, 0.39, 0.57])
            v[:, :, :3][mask] = np.clip(intensity[mask, None] * t, 0, 255).astype(
                "uint8"
            )
        if "normal" in src.stem:
            v[:, :, 1] = 255 - v[:, :, 1]
        result = Image.fromarray(v)
        if "opacity" not in src.stem:
            result = result.convert("RGB")
        result.save(src.with_suffix(".png"), optimize=True)
