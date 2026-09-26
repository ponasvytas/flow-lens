"""Export the master SVG, generate platform icons, then apply platform-specific artwork."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
BRANDING = ASSETS / "branding"
LIGHT = "#C4A5FA"
DARK = "#100E17"
SVG_NS = "http://www.w3.org/2000/svg"


def recolor(image, color):
    result = Image.new("RGBA", image.size, color)
    result.putalpha(image.getchannel("A"))
    return result


def fit_mark(mark, extent, background=None):
    tile = mark.copy()
    tile.thumbnail((extent, extent), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", (1024, 1024), background or (0, 0, 0, 0))
    result.alpha_composite(tile, ((1024 - tile.width) // 2, (1024 - tile.height) // 2))
    return result if background is None else result.convert("RGB")


def export_master(inkscape):
    subprocess.run([
        inkscape, str(ASSETS / "logo.svg"), "--export-area-page",
        "--export-width=1024", "--export-background-opacity=0",
        f"--export-filename={ASSETS / 'logo-transparent.png'}",
    ], check=True, cwd=ROOT)
    with Image.open(ASSETS / "logo-transparent.png") as source:
        master = source.convert("RGBA")
    if master.size != (1024, 1024):
        raise ValueError("The master SVG page must be square; expected a 1024 x 1024 export.")
    bounds = master.getchannel("A").getbbox()
    if bounds is None or master.getchannel("A").getextrema()[0] != 0:
        raise ValueError("Expected visible artwork on a transparent page.")
    print(f"Master page: {master.size}; artwork bounds: {bounds}", flush=True)
    return master, master.crop(bounds)


def prepare_inputs(mark):
    BRANDING.mkdir(exist_ok=True)
    fit_mark(mark, 740, "white").save(BRANDING / "launcher.png")
    fit_mark(recolor(mark, LIGHT), 740).save(BRANDING / "ios-dark.png")
    fit_mark(recolor(mark, "white"), 740, "black").save(BRANDING / "ios-tinted.png")
    # All artwork fits within Android's 66/108 safe-zone circle, including corners.
    fit_mark(mark, 440).save(BRANDING / "android-foreground.png")
    fit_mark(recolor(mark, "white"), 440).save(BRANDING / "android-monochrome.png")
    # A 576px square fits within the PWA's central 80%-diameter safe-zone circle.
    fit_mark(mark, 576, "white").save(BRANDING / "maskable.png")
    macos = Image.new("RGBA", (1024, 1024))
    ImageDraw.Draw(macos).rounded_rectangle((100, 100, 924, 924), radius=180, fill="white")
    macos.alpha_composite(fit_mark(mark, 600))
    macos.save(BRANDING / "macos.png")


def write_svg_assets():
    ET.register_namespace("", SVG_NS)
    tree = ET.parse(ASSETS / "logo.svg")
    root = tree.getroot()
    # Strip editor metadata; leave the master document and its geometry untouched.
    for parent in list(root.iter()):
        for child in list(parent):
            if (child.tag == f"{{{SVG_NS}}}metadata"
                    or not child.tag.startswith(f"{{{SVG_NS}}}")
                    or (child.tag == f"{{{SVG_NS}}}defs" and len(child) == 0)):
                parent.remove(child)
        for key in list(parent.attrib):
            if key.startswith("{") and not key.startswith(f"{{{SVG_NS}}}"):
                del parent.attrib[key]
    tree.write(BRANDING / "logo.svg", encoding="utf-8", xml_declaration=True)
    style = ET.Element(f"{{{SVG_NS}}}style")
    style.text = f"@media (prefers-color-scheme: dark) {{ path {{ fill: {LIGHT} !important; }} }}"
    root.insert(0, style)
    tree.write(ROOT / "web/favicon.svg", encoding="utf-8", xml_declaration=True)


def finish_icons(master):
    # The launcher package reuses one web image for every purpose, so replace maskable icons.
    with Image.open(BRANDING / "maskable.png") as maskable:
        for size in (192, 512):
            maskable.resize((size, size), Image.Resampling.LANCZOS).save(
                ROOT / f"web/icons/Icon-maskable-{size}.png")
    with Image.open(BRANDING / "launcher.png") as launcher:
        launcher.resize((180, 180), Image.Resampling.LANCZOS).save(
            ROOT / "web/icons/apple-touch-icon.png")
    master.resize((32, 32), Image.Resampling.LANCZOS).save(ROOT / "web/favicon.png")
    write_svg_assets()
    # Include small native sizes instead of a single 256px image in the Windows ICO.
    master.save(ROOT / "windows/runner/resources/app_icon.ico", format="ICO",
                sizes=[(size, size) for size in (16, 24, 32, 48, 64, 128, 256)])
    catalog = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json"
    catalog.write_text(json.dumps(json.loads(catalog.read_text()), indent=2) + "\n", encoding="utf-8")


def verify_outputs():
    for filename in ("web/favicon.png", "web/icons/Icon-192.png", "web/icons/Icon-512.png"):
        with Image.open(ROOT / filename) as image:
            assert image.convert("RGBA").getchannel("A").getextrema()[0] == 0, filename
    for filename in ("web/icons/apple-touch-icon.png", "web/icons/Icon-maskable-192.png",
                     "web/icons/Icon-maskable-512.png"):
        with Image.open(ROOT / filename) as image:
            assert image.convert("RGBA").getchannel("A").getextrema() == (255, 255), filename
    for filename in ("android-foreground.png", "android-monochrome.png"):
        with Image.open(BRANDING / filename) as image:
            bounds = image.getchannel("A").getbbox()
            radius = 1024 * 66 / 108 / 2
            assert all((x - 512) ** 2 + (y - 512) ** 2 <= radius ** 2
                       for x in (bounds[0], bounds[2]) for y in (bounds[1], bounds[3]))
    with Image.open(ROOT / "windows/runner/resources/app_icon.ico") as icon:
        assert (16, 16) in icon.ico.sizes() and (256, 256) in icon.ico.sizes()
    catalog = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    entries = json.loads((catalog / "Contents.json").read_text())["images"]
    for entry in entries:
        with Image.open(catalog / entry["filename"]) as image:
            scale = float(entry["scale"].removesuffix("x"))
            expected = tuple(round(float(side) * scale) for side in entry["size"].split("x"))
            assert image.size == expected, entry["filename"]
            appearances = entry.get("appearances", [])
            alpha = image.convert("RGBA").getchannel("A").getextrema()
            if not appearances:
                assert alpha == (255, 255), entry["filename"]
            elif appearances[0]["value"] == "dark":
                assert alpha[0] == 0, entry["filename"]
            elif appearances[0]["value"] == "tinted":
                red, green, blue = image.convert("RGB").split()
                assert red.tobytes() == green.tobytes() == blue.tobytes(), entry["filename"]
    print("Verified transparent web icons, opaque touch/maskable icons, Android safe zones and Windows ICO sizes.")
    print(f"Verified all {len(entries)} iOS catalog entries, dimensions and appearance channels.")


def preview(master):
    sheet = Image.new("RGB", (1000, 660), "white")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=16)
    draw.rectangle((500, 0, 1000, 330), fill=DARK)
    for offset, foreground, text_color in ((0, master, "#17121F"),
                                            (500, recolor(master, LIGHT), "white")):
        draw.text((offset + 20, 16), "Transparent logo: 16 / 24 / 30 / 48 / 128 px", font=font, fill=text_color)
        x = offset + 20
        for size in (16, 24, 30, 48, 128):
            tile = foreground.resize((size, size), Image.Resampling.LANCZOS)
            sheet.paste(tile, (x, 80), tile)
            x += size + 22
    for index, (filename, label) in enumerate((
        ("launcher.png", "iOS default / Apple touch"),
        ("ios-dark.png", "iOS dark (on dark)"),
        ("maskable.png", "PWA maskable safe zone"),
        ("android-foreground.png", "Android adaptive safe zone"),
    )):
        x = index * 250
        draw.rectangle((x, 330, x + 249, 659), fill=DARK if index == 1 else "#EEEEEE")
        with Image.open(BRANDING / filename) as source:
            tile = source.convert("RGBA").resize((220, 220), Image.Resampling.LANCZOS)
            sheet.paste(tile, (x + 15, 365), tile)
        if index in (2, 3):
            diameter = 220 * (0.8 if index == 2 else 66 / 108)
            cx, cy = x + 125, 475
            draw.ellipse((cx - diameter / 2, cy - diameter / 2,
                          cx + diameter / 2, cy + diameter / 2), outline="#DC6B16", width=2)
        draw.text((x + 8, 610), label, font=font, fill="white" if index == 1 else "#17121F")
    target = ROOT / ".local/branding-preview.png"
    target.parent.mkdir(exist_ok=True)
    sheet.save(target)
    print(f"Preview: {target}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inkscape", default=os.environ.get("INKSCAPE") or shutil.which("inkscape"),
                        help="Path to Inkscape; alternatively set INKSCAPE or add it to PATH.")
    options = parser.parse_args()
    if not options.inkscape:
        parser.error("Provide --inkscape with the installed Inkscape executable path.")
    master, mark = export_master(options.inkscape)
    prepare_inputs(mark)
    command = ["cmd", "/c", "dart"] if os.name == "nt" else ["dart"]
    subprocess.run(command + ["run", "flutter_launcher_icons"], cwd=ROOT, check=True)
    finish_icons(master)
    verify_outputs()
    preview(master)


if __name__ == "__main__":
    main()
