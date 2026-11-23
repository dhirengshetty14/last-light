"""Make deterministic embedded paint, brass and canvas maps for the three machine rigs."""

from pathlib import Path
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
palette = {
    "orange": "A95528",
    "orange2": "914328",
    "ivory": "DBD1AE",
    "cream": "DBCCA6",
    "brass": "A6844F",
    "copper": "9C6446",
    "canvas": "B7A284",
    "bag": "92632D",
    "joint": "44464A",
    "rubber": "282C31",
    "steel": "838D91",
    "red": "8B493A",
    "netedge": "BFAD88",
}
for idx, (name, hexcol) in enumerate(palette.items()):
    rng = np.random.default_rng(110 + idx)
    size = 512
    base = np.array(bytes.fromhex(hexcol) and list(bytes.fromhex(hexcol)), dtype=float)
    grain = rng.normal(0, 4, (size, size, 1))
    low = Image.fromarray(rng.integers(0, 256, (16, 16), dtype=np.uint8)).resize(
        (size, size), Image.Resampling.BICUBIC
    )
    shade = (np.asarray(low).astype(float) - 128)[:, :, None] * 0.12
    y, x = np.indices((size, size))
    if name in {"canvas", "bag", "netedge"}:
        grain += ((x % 4 == 0) * 5 - (y % 4 == 0) * 7)[:, :, None]
    pix = np.clip(base + grain + shade, 0, 255).astype("uint8")
    im = Image.fromarray(pix)
    d = ImageDraw.Draw(im)
    for n in range(470 if name not in {"canvas", "bag"} else 90):
        x0, y0 = rng.integers(0, size, 2)
        w = int(rng.integers(1, 15))
        h = int(rng.integers(-3, 5))
        col = tuple(
            int(v)
            for v in np.clip(
                base * rng.uniform(0.36, 0.85) + rng.integers(3, 18), 0, 255
            )
        )
        d.line(
            [(x0, y0), (x0 + w * 0.45, y0 + h - 1), (x0 + w, y0 + h)],
            fill=col,
            width=int(rng.integers(1, 3)),
        )
        if n % 8 == 0:
            d.line(
                [(x0, y0 + 1), (x0 + w * 0.55, y0 + h + 1)],
                fill=tuple(int(v) for v in np.clip(base * 1.15 + 12, 0, 255)),
            )
    im.save(out / (name + ".jpg"), quality=91)
