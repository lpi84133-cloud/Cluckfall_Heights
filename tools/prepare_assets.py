#!/usr/bin/env python3
"""Asset pipeline for Cluckfall Heights.

Reads the raw delivery in `assets/Cluckfall_Heights_APPLICATION_*` and produces a
Flutter-ready tree under `assets/img` with 1x / 2.0x / 3.0x densities, plus the
app icon sources under `assets/icon`.

Run from the repository root:
    python3 tools/prepare_assets.py
"""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation, label, uniform_filter

ROOT = Path(__file__).resolve().parent.parent
RAW_GAMEPLAY = ROOT / "assets" / "Cluckfall_Heights_APPLICATION_gameplay_assets"
RAW_EXTRA = ROOT / "assets" / "Cluckfall_Heights_APPLICATION_additional_assets"
RAW_SOUNDS = ROOT / "assets" / "Cluckfall_Heights_APPLICATION_sounds_assets"
OUT_IMG = ROOT / "assets" / "img"
OUT_ICON = ROOT / "assets" / "icon"
OUT_SOUND = ROOT / "assets" / "sounds"

# Alpha below this is treated as empty space when trimming.
ALPHA_FLOOR = 6
# Transparent margin kept around trimmed sprites, in percent of the long edge.
TRIM_PADDING = 0.02

DENSITIES = {"": 1.0, "2.0x": 2.0, "3.0x": 3.0}

WEBP_LOSSY = {"format": "WEBP", "quality": 92, "method": 6}
WEBP_PHOTO = {"format": "WEBP", "quality": 86, "method": 6}


# Twelve library objects. `wooden_shelf` and `metal_shelf` double as structure
# frames in the Stack Builder, so they are stored once and referenced twice.
OBJECTS = {
    "white_chicken_asset": "chicken",
    "white_egg_asset": "egg",
    "gold_coin_asset": "coin",
    "small_storage_box_asset": "storage_box",
    "wooden_shelf_asset": "wooden_shelf",
    "metal_shelf_asset": "metal_shelf",
    "plastic_container_asset": "plastic_container",
    "cardboard_box_asset": "cardboard_box",
    "bottle_asset": "bottle",
    "jar_asset": "jar",
    "book_asset": "book",
    "tool_box_asset": "tool_box",
}

BACKGROUNDS = {
    "pantry_background_asset": "pantry",
    "garage_background_asset": "garage",
    "storage_room_background_asset": "storage_room",
    "kitchen_cabinet_background_asset": "kitchen_cabinet",
}


def content_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.convert("RGBA"))[:, :, 3]
    rows = np.nonzero(alpha.max(axis=1) > ALPHA_FLOOR)[0]
    cols = np.nonzero(alpha.max(axis=0) > ALPHA_FLOOR)[0]
    if not len(rows) or not len(cols):
        return 0, 0, image.width, image.height
    return int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1


def trim(image: Image.Image) -> Image.Image:
    left, top, right, bottom = content_bbox(image)
    cropped = image.crop((left, top, right, bottom))
    pad = round(max(cropped.size) * TRIM_PADDING)
    if pad == 0:
        return cropped
    padded = Image.new("RGBA", (cropped.width + pad * 2, cropped.height + pad * 2), (0, 0, 0, 0))
    padded.paste(cropped, (pad, pad))
    return padded


def write_densities(image: Image.Image, out_dir: Path, name: str, base_long_edge: int, save_opts: dict) -> dict:
    scale = base_long_edge / max(image.size)
    written = {}
    for suffix, density in DENSITIES.items():
        target = (
            max(1, round(image.width * scale * density)),
            max(1, round(image.height * scale * density)),
        )
        if max(target) > max(image.size):
            # Never upscale past the delivered resolution.
            target = image.size
        resized = image.resize(target, Image.LANCZOS)
        directory = out_dir / suffix if suffix else out_dir
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / f"{name}.webp"
        resized.save(path, **save_opts)
        written[suffix or "1x"] = f"{target[0]}x{target[1]}"
    return written


def slice_center_of_mass(source: Path, report: dict) -> None:
    """The delivered marker is a circular badge on a long vertical axis line.

    The axis line is drawn natively in Flutter (it must stretch to the structure
    height), so the badge is exported separately. The badge is the widest band of
    the sprite, which makes it detectable without hardcoded coordinates.
    """
    image = Image.open(source).convert("RGBA")
    alpha = np.asarray(image)[:, :, 3]
    row_width = (alpha > ALPHA_FLOOR).sum(axis=1)
    badge_rows = np.nonzero(row_width > row_width.max() * 0.6)[0]
    badge = image.crop((0, int(badge_rows[0]), image.width, int(badge_rows[-1]) + 1))

    report["center_of_mass_marker"] = write_densities(
        trim(image), OUT_IMG / "indicators", "center_of_mass_marker", 240, dict(WEBP_LOSSY)
    )
    report["center_of_mass_badge"] = write_densities(
        trim(badge), OUT_IMG / "indicators", "center_of_mass_badge", 88, dict(WEBP_LOSSY)
    )


def longest_run(flags: np.ndarray) -> tuple[int, int] | None:
    """Return the [start, end) bounds of the longest contiguous True run."""
    best: tuple[int, int] | None = None
    start: int | None = None
    for index, flag in enumerate(flags):
        if flag and start is None:
            start = index
        elif not flag and start is not None:
            if best is None or index - start > best[1] - best[0]:
                best = (start, index)
            start = None
    if start is not None and (best is None or len(flags) - start > best[1] - best[0]):
        best = (start, len(flags))
    return best


def slice_stability_gauge(source: Path, report: dict) -> None:
    """The gauge is one capsule holding three stacked zones: stable, caution, unstable.

    The full capsule is kept as the vertical rail used in the Stack Builder. Each
    zone is also exported on its own so a single status can be shown without the
    other two competing for attention. Zone bounds come from the longest
    contiguous run of each hue down the centre column, because the delivered
    zones are not equal in height and the curved dividers produce stray rows.
    """
    image = Image.open(source).convert("RGBA")
    trimmed = trim(image)
    report["stability_gauge"] = write_densities(
        trimmed, OUT_IMG / "indicators", "stability_gauge", 200, dict(WEBP_LOSSY)
    )

    centre = np.asarray(trimmed).astype(int)[:, trimmed.width // 2, :]

    def zone_of(row: np.ndarray) -> str:
        r, g, b, a = row
        if a < 200 or (r < 100 and g < 100 and b < 100):
            return "frame"
        if g > r * 0.85:
            return "stable"
        if r > 225 and g > 150:
            return "caution"
        return "unstable"

    labels = np.array([zone_of(centre[y]) for y in range(trimmed.height)])

    zones = {}
    for status in ("stable", "caution", "unstable"):
        run = longest_run(labels == status)
        if run is None:
            continue
        y0, y1 = run
        crop = trim(trimmed.crop((0, y0, trimmed.width, y1)))
        zones[status] = write_densities(
            crop, OUT_IMG / "indicators", f"stability_zone_{status}", 120, dict(WEBP_LOSSY)
        )
        mid = centre[(y0 + y1) // 2]
        zones[status]["color"] = "#%02X%02X%02X" % (int(mid[0]), int(mid[1]), int(mid[2]))
        zones[status]["source_rows"] = f"{y0}-{y1}"
    report["stability_zones"] = zones


def sample_palette() -> dict:
    """Pull real colours out of the delivered art so the theme matches the assets."""
    palette = {}

    def dominant(path: Path, key: str, min_alpha: int = 220) -> None:
        image = Image.open(path).convert("RGBA")
        data = np.asarray(image).reshape(-1, 4)
        opaque = data[data[:, 3] > min_alpha][:, :3]
        if not len(opaque):
            return
        quantised = (opaque // 24 * 24).astype(np.uint8)
        colours, counts = np.unique(quantised, axis=0, return_counts=True)
        order = np.argsort(counts)[::-1][:4]
        palette[key] = ["#%02X%02X%02X" % tuple(int(c) for c in colours[i]) for i in order]

    dominant(RAW_GAMEPLAY / "gold_coin_asset.webp", "coin")
    dominant(RAW_GAMEPLAY / "white_chicken_asset.webp", "chicken")
    dominant(RAW_GAMEPLAY / "wooden_shelf_asset.webp", "wood")
    dominant(RAW_GAMEPLAY / "metal_shelf_asset.webp", "metal")
    dominant(RAW_EXTRA / "Game_Name.webp", "logo")
    dominant(RAW_EXTRA / "Icon.png", "icon")
    return palette


ADAPTIVE_CANVAS = 1024
# An adaptive icon layer is 108dp with only the central 72dp ever visible. Every
# launcher mask fits inside that square, and the strictest of them is a circle
# inscribed in it, so content belongs inside the circle and decoration belongs
# outside the square.
ADAPTIVE_VISIBLE = 2 / 3


def extend_edges(layer: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    """Stretch the pasted region's outermost pixels out to the canvas edges.

    The plate is a near-flat cream gradient, so replicating its border makes the
    layer fully opaque without a visible seam. That matters because an adaptive
    foreground smaller than the mask would otherwise show its own square edge.
    """
    width, height = layer.size
    left = max(0, min(box[0], width - 1))
    top = max(0, min(box[1], height - 1))
    right = max(left + 1, min(box[2], width))
    bottom = max(top + 1, min(box[3], height))
    if top > 0:
        strip = layer.crop((left, top, right, top + 1)).resize((right - left, top), Image.NEAREST)
        layer.paste(strip, (left, 0))
    if bottom < height:
        strip = layer.crop((left, bottom - 1, right, bottom)).resize((right - left, height - bottom), Image.NEAREST)
        layer.paste(strip, (left, bottom))
    if left > 0:
        strip = layer.crop((left, 0, left + 1, height)).resize((left, height), Image.NEAREST)
        layer.paste(strip, (0, 0))
    if right < width:
        strip = layer.crop((right - 1, 0, right, height)).resize((width - right, height), Image.NEAREST)
        layer.paste(strip, (right, 0))
    return layer


def cabinet_box(data: np.ndarray) -> tuple[int, int, int, int]:
    """Bounds of the graphite cabinet frame in the delivered icon.

    Only the darkest pixels are considered, which isolates the cabinet frame from
    the cream plate and from the gold ring. The frame is by far the largest dark
    component, so taking the largest one discards the thin dark outline that runs
    alongside the ring.
    """
    labels, count = label(data.sum(axis=2) < 260, structure=np.ones((3, 3)))
    assert count, "no dark cabinet frame found in the icon"
    sizes = np.bincount(labels.ravel())
    sizes[0] = 0
    frame = labels == int(sizes.argmax())
    rows = np.nonzero(frame.any(axis=1))[0]
    cols = np.nonzero(frame.any(axis=0))[0]
    return int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1


def protected_mask(data: np.ndarray, cabinet: tuple[int, int, int, int]) -> np.ndarray:
    """Region to leave untouched: the cabinet frame and everything it holds.

    The two small gold feet are deliberately left out. The decorative ring's
    bottom arc passes within a couple of pixels of them, so protecting the feet
    also protects slivers of the ring, which then survive as visible fragments.
    Dropping the feet costs a few pixels of decoration and leaves the cabinet
    standing flat, which reads correctly at icon size.
    """
    margin = 8
    protect = np.zeros(data.shape[:2], dtype=bool)
    protect[
        max(0, cabinet[1] - margin) : cabinet[3] + 2,
        max(0, cabinet[0] - margin) : cabinet[2] + margin,
    ] = True
    return protect


def erase_plate_decoration(source: Image.Image, protect: np.ndarray) -> Image.Image:
    """Paint everything except the cabinet off the plate, decorative ring included.

    Android draws its own mask, so keeping the delivered gold ring would read as
    an icon outlined inside another icon. Cropping it away is not an option: the
    ring's corner arcs cut diagonally well inside the cabinet's own bounds.
    Instead every non-cream pixel outside the protected area is replaced by the
    cream around it, sampled locally so the plate's soft gradient survives.
    """
    data = np.asarray(source).astype(float)
    cream = (data.min(axis=2) > 150) & ((data[:, :, 0] - data[:, :, 2]) < 125)

    repaint = binary_dilation(~cream & ~protect, structure=np.ones((9, 9))) & ~protect
    donor = cream & ~repaint & ~protect

    window = 61
    weight = uniform_filter(donor.astype(float), size=window)
    result = data.copy()
    for channel in range(3):
        blended = uniform_filter(data[:, :, channel] * donor, size=window)
        filled = np.where(weight > 1e-6, blended / np.maximum(weight, 1e-6), data[:, :, channel])
        result[:, :, channel] = np.where(repaint, filled, data[:, :, channel])
    return Image.fromarray(result.round().clip(0, 255).astype(np.uint8))


def build_icons(report: dict) -> None:
    """Produce the iOS marketing icon and Android adaptive icon layers."""
    OUT_ICON.mkdir(parents=True, exist_ok=True)
    source = Image.open(RAW_EXTRA / "Icon.png").convert("RGB")
    data = np.asarray(source).astype(int)

    ios = source.resize((ADAPTIVE_CANVAS, ADAPTIVE_CANVAS), Image.LANCZOS)
    ios.save(OUT_ICON / "icon_ios.png", format="PNG")
    report["icon_ios"] = f"1024x1024 (upscaled from {source.width}x{source.height})"

    # The plate colour is uniform along the outer edge of the delivered icon.
    edge = np.concatenate([data[0], data[-1], data[:, 0], data[:, -1]])
    plate = np.median(edge, axis=0).round().astype(int)
    plate_hex = "#%02X%02X%02X" % tuple(int(c) for c in plate)

    Image.new("RGB", (ADAPTIVE_CANVAS, ADAPTIVE_CANVAS), tuple(int(c) for c in plate)).save(
        OUT_ICON / "icon_android_background.png", format="PNG"
    )

    cabinet = cabinet_box(data)
    plate_art = erase_plate_decoration(source, protected_mask(data, cabinet))

    # Fit the cabinet inside the circle that every launcher mask contains, so no
    # part of it is ever clipped, then anchor on the cabinet rather than on the
    # plate: the delivered artwork sits low because the chicken stands on the top
    # shelf. The cream is finally stretched out to the layer edges so a launcher
    # using a wide mask never sees a transparent corner.
    guaranteed_radius = ADAPTIVE_CANVAS * ADAPTIVE_VISIBLE / 2
    half_diagonal = ((cabinet[2] - cabinet[0]) ** 2 + (cabinet[3] - cabinet[1]) ** 2) ** 0.5 / 2
    scale = guaranteed_radius * 0.97 / half_diagonal

    plate_size = round(plate_art.width * scale)
    scaled = plate_art.resize((plate_size, plate_size), Image.LANCZOS)
    offset = (
        round(ADAPTIVE_CANVAS / 2 - (cabinet[0] + cabinet[2]) / 2 * scale),
        round(ADAPTIVE_CANVAS / 2 - (cabinet[1] + cabinet[3]) / 2 * scale),
    )

    foreground = Image.new("RGB", (ADAPTIVE_CANVAS, ADAPTIVE_CANVAS), tuple(int(c) for c in plate))
    foreground.paste(scaled, offset)
    foreground = extend_edges(
        foreground, (offset[0], offset[1], offset[0] + plate_size, offset[1] + plate_size)
    )
    foreground.convert("RGBA").save(OUT_ICON / "icon_android_foreground.png", format="PNG")

    report["icon_android"] = {
        "background": plate_hex,
        "cabinet_in_source": cabinet,
        "cabinet_on_canvas": f"{round((cabinet[2]-cabinet[0])*scale)}x{round((cabinet[3]-cabinet[1])*scale)}",
        "cabinet_half_diagonal": round(half_diagonal * scale),
        "guaranteed_radius": round(guaranteed_radius),
        "plate_scaled_to": f"{plate_size}x{plate_size}",
        "offset": offset,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--icons-only", action="store_true", help="rebuild only the app icon layers")
    args = parser.parse_args()

    if args.icons_only:
        report: dict = {}
        build_icons(report)
        print(json.dumps(report, indent=2))
        return

    if OUT_IMG.exists():
        shutil.rmtree(OUT_IMG)
    report: dict = {"objects": {}, "backgrounds": {}, "brand": {}, "indicators": {}}

    for raw, name in OBJECTS.items():
        image = trim(Image.open(RAW_GAMEPLAY / f"{raw}.webp").convert("RGBA"))
        report["objects"][name] = write_densities(
            image, OUT_IMG / "objects", name, 220, dict(WEBP_LOSSY)
        )

    slice_stability_gauge(RAW_GAMEPLAY / "stability_indicator_asset.webp", report["indicators"])
    slice_center_of_mass(RAW_GAMEPLAY / "center_of_mass_marker_asset.webp", report["indicators"])

    fragile = trim(Image.open(RAW_GAMEPLAY / "fragile_symbol_asset.webp").convert("RGBA"))
    report["indicators"]["fragile_symbol"] = write_densities(
        fragile, OUT_IMG / "indicators", "fragile_symbol", 120, dict(WEBP_LOSSY)
    )

    # Decorative only: real weight bars are painted from live data.
    weight = trim(Image.open(RAW_GAMEPLAY / "weight_distribution_indicator_asset.webp").convert("RGBA"))
    report["indicators"]["weight_distribution_decor"] = write_densities(
        weight, OUT_IMG / "indicators", "weight_distribution_decor", 240, dict(WEBP_LOSSY)
    )

    # Full-screen photography: one resolution, scaled with BoxFit.cover.
    (OUT_IMG / "backgrounds").mkdir(parents=True, exist_ok=True)
    for raw, name in BACKGROUNDS.items():
        image = Image.open(RAW_GAMEPLAY / f"{raw}.webp").convert("RGB")
        image.save(OUT_IMG / "backgrounds" / f"{name}.webp", **WEBP_PHOTO)
        report["backgrounds"][name] = f"{image.width}x{image.height}"

    logo = trim(Image.open(RAW_EXTRA / "Game_Name.webp").convert("RGBA"))
    report["brand"]["logo"] = write_densities(logo, OUT_IMG / "brand", "logo", 170, dict(WEBP_LOSSY))

    (OUT_IMG / "brand").mkdir(parents=True, exist_ok=True)
    for raw, name in (
        ("Vertical_Loading_Screen", "loading_portrait"),
        ("Horizontal_Loading_Screen", "loading_landscape"),
    ):
        image = Image.open(RAW_EXTRA / f"{raw}.webp").convert("RGB")
        image.save(OUT_IMG / "brand" / f"{name}.webp", **WEBP_PHOTO)
        report["brand"][name] = f"{image.width}x{image.height}"

    # Short interface sounds, renamed off the delivery's `_asset` suffix.
    if OUT_SOUND.exists():
        shutil.rmtree(OUT_SOUND)
    OUT_SOUND.mkdir(parents=True, exist_ok=True)
    report["sounds"] = {}
    for source in sorted(RAW_SOUNDS.glob("*.mp3")):
        name = source.stem.removesuffix("_asset")
        shutil.copyfile(source, OUT_SOUND / f"{name}.mp3")
        report["sounds"][name] = f"{source.stat().st_size // 1024} KB"

    build_icons(report)
    report["palette"] = sample_palette()

    (ROOT / "tools" / "assets_report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
