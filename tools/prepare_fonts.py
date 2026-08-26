#!/usr/bin/env python3
"""Font pipeline for Cluckfall Heights.

The app must work fully offline, so fonts are bundled rather than fetched at
runtime. Google serves these families only as variable fonts, and relying on
Flutter to map `fontWeight` onto a variable axis is fragile, so static instances
are cut here instead.

Run from the repository root:
    python3 tools/prepare_fonts.py
"""

from __future__ import annotations

import urllib.request
from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache" / "fonts"
OUT = ROOT / "assets" / "fonts"

RAW = "https://github.com/google/fonts/raw/main/ofl"

SOURCES = {
    "Manrope": f"{RAW}/manrope/Manrope%5Bwght%5D.ttf",
    "Fraunces": f"{RAW}/fraunces/Fraunces%5BSOFT%2CWONK%2Copsz%2Cwght%5D.ttf",
}
LICENSES = {
    "Manrope": f"{RAW}/manrope/OFL.txt",
    "Fraunces": f"{RAW}/fraunces/OFL.txt",
}

# Manrope carries the interface: four weights cover body, labels and emphasis.
MANROPE_WEIGHTS = {"Regular": 400, "Medium": 500, "SemiBold": 600, "Bold": 700}

# Fraunces is the display face for headings only. Its optical size axis is pinned
# to a display value, terminals are softened to match the rounded 3D artwork, and
# the quirky WONK axis is switched off to keep the tone premium rather than
# playful.
FRAUNCES_STATIC = {"opsz": 72.0, "SOFT": 40.0, "WONK": 0.0}
FRAUNCES_WEIGHTS = {"SemiBold": 600, "Bold": 700}


def fetch(url: str, destination: Path) -> Path:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.exists():
        print(f"downloading {destination.name}")
        with urllib.request.urlopen(url) as response:
            destination.write_bytes(response.read())
    return destination


def cut(source: Path, family: str, style: str, axes: dict[str, float]) -> None:
    font = instantiateVariableFont(TTFont(source), axes, inplace=False, updateFontNames=False)
    target = OUT / f"{family}-{style}.ttf"
    font.save(target)
    print(f"{target.name:26s} {target.stat().st_size // 1024:4d} KB  {axes}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    manrope = fetch(SOURCES["Manrope"], CACHE / "Manrope-var.ttf")
    for style, weight in MANROPE_WEIGHTS.items():
        cut(manrope, "Manrope", style, {"wght": float(weight)})

    fraunces = fetch(SOURCES["Fraunces"], CACHE / "Fraunces-var.ttf")
    for style, weight in FRAUNCES_WEIGHTS.items():
        cut(fraunces, "Fraunces", style, {**FRAUNCES_STATIC, "wght": float(weight)})

    for family, url in LICENSES.items():
        fetch(url, OUT / f"OFL-{family}.txt")


if __name__ == "__main__":
    main()
