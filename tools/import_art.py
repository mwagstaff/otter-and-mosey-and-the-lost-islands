#!/usr/bin/env python3
"""Optimises tools/raw/*.png and packages them into OtterAndMosey/Assets.xcassets.

Sprites are trimmed to their painted area, scaled down and palette-compressed; scenery
becomes JPEG. Requires ImageMagick (`magick`) and `pngquant` (both from Homebrew).
Usage: python3 tools/import_art.py
"""
import json, pathlib, shutil, subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "tools/raw"
CATALOG = ROOT / "OtterAndMosey/Assets.xcassets"

# Longest edge in pixels for each family of sprite.
LIMITS = {"otter": 760, "mosey": 900, "duo": 1000, "guardian": 900, "island": 560, "fg": 1536, "logo": 1200,
          "crystal": 420, "pearl": 200, "egg": 420, "babydragon": 420, "chest": 420, "ring": 520, "cliff": 700,
          "jar": 420, "friend": 380, "icon": 256, "reward": 320, "badge": 256, "trophy": 420}


# Talking frames. Each is the idle picture with only the mouth taken from a generated edit
# (tools/raw/<name>_talk_gen.png), so the rest of the character cannot shift between frames.
# Values are the mouth area in the 1024-pixel raw image: centre x, centre y, radius x, radius y.
MOUTHS = {"otter": (640, 300, 110, 75), "mosey": (890, 465, 115, 70)}


def build_talk_frames():
    for name, (cx, cy, rx, ry) in MOUTHS.items():
        idle, edit, talk = RAW / f"{name}_idle.png", RAW / f"{name}_talk_gen.png", RAW / f"{name}_talk.png"
        if not edit.exists():
            continue
        mask = RAW / ".mouth_mask.png"
        subprocess.run(["magick", "-size", "1024x1024", "xc:black", "-fill", "white", "-draw",
                        f"ellipse {cx},{cy} {rx},{ry} 0,360", "-blur", "0x7", str(mask)], check=True)
        # Cut the mouth out of the edit (its own transparency times the soft mask), then lay that
        # patch over the untouched idle picture.
        patch = RAW / ".mouth_patch.png"
        subprocess.run(["magick", str(edit), "(", "+clone", "-alpha", "extract", str(mask), "-compose", "Multiply", "-composite", ")",
                        "-alpha", "off", "-compose", "CopyOpacity", "-composite", str(patch)], check=True)
        subprocess.run(["magick", str(idle), str(patch), "-compose", "Over", "-composite", str(talk)], check=True)
        mask.unlink()
        patch.unlink()
        # Prove it: with the mouth area painted over in both, the two frames must be identical.
        cover = ["-fill", "black", "-draw", f"rectangle {cx - rx - 30},{cy - ry - 30} {cx + rx + 30},{cy + ry + 30}"]
        covered = [RAW / ".covered_idle.png", RAW / ".covered_talk.png"]
        subprocess.run(["magick", str(idle), *cover, str(covered[0])], check=True)
        subprocess.run(["magick", str(talk), *cover, str(covered[1])], check=True)
        result = subprocess.run(["magick", "compare", "-metric", "AE", str(covered[0]), str(covered[1]), "null:"],
                                capture_output=True, text=True)
        for file in covered:
            file.unlink()
        differing = (result.stderr.strip().split() or ["nan"])[0]
        if float(differing) != 0:
            raise SystemExit(f"{name}_talk differs from {name}_idle outside the mouth area ({differing} pixels)")
        print(f"{name}_talk: only the mouth differs from {name}_idle")


def write_set(name, source, extension):
    folder = CATALOG / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    shutil.move(source, folder / f"{name}.{extension}")
    (folder / "Contents.json").write_text(json.dumps({
        "images": [{"idiom": "universal", "filename": f"{name}.{extension}"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2))


def main():
    CATALOG.mkdir(parents=True, exist_ok=True)
    (CATALOG / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))
    accent = CATALOG / "AccentColor.colorset"
    accent.mkdir(exist_ok=True)
    (accent / "Contents.json").write_text(json.dumps({"colors": [{"idiom": "universal", "color": {
        "color-space": "srgb", "components": {"red": "0.090", "green": "0.722", "blue": "0.651", "alpha": "1.000"}}}],
        "info": {"author": "xcode", "version": 1}}, indent=2))
    tmp = ROOT / "tools/raw/.tmp"
    tmp.mkdir(exist_ok=True)
    build_talk_frames()
    count = 0
    for path in sorted(RAW.glob("*.png")):
        name = path.stem
        if name.endswith("_ref") or name.endswith("_gen"):
            continue
        if name == "app_icon":
            folder = CATALOG / "AppIcon.appiconset"
            folder.mkdir(exist_ok=True)
            subprocess.run(["magick", str(path), "-resize", "1024x1024!", "-background", "white", "-alpha", "remove",
                            "-alpha", "off", str(folder / "icon.png")], check=True)
            (folder / "Contents.json").write_text(json.dumps({
                "images": [{"filename": "icon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
                "info": {"author": "xcode", "version": 1}}, indent=2))
        elif name.startswith("bg_"):
            out = tmp / f"{name}.jpg"
            subprocess.run(["magick", str(path), "-resize", "1536x1024>", "-quality", "86", str(out)], check=True)
            write_set(name, out, "jpg")
        else:
            limit = LIMITS.get(name.split("_")[0], 512)
            out = tmp / f"{name}.png"
            # Generated sprites carry a faint, invisible haze in their "transparent" areas, so a plain
            # trim does not crop them. Find the painted bounds from the alpha channel, clear the haze,
            # then crop to those bounds.
            # A talking frame is cropped exactly like its idle frame so the two line up.
            outline = RAW / name.replace("_talk", "_idle") if name.endswith("_talk") else path
            outline = outline if outline.suffix else outline.with_suffix(".png")
            bounds = subprocess.run(["magick", str(outline), "-alpha", "extract", "-threshold", "10%", "-format", "%@", "info:"],
                                    check=True, capture_output=True, text=True).stdout.strip()
            subprocess.run(["magick", str(path), "-channel", "A", "-level", "6%,100%", "+channel", "-crop", bounds, "+repage",
                            "-resize", f"{limit}x{limit}>", str(out)], check=True)
            subprocess.run(["pngquant", "--force", "--skip-if-larger", "--quality", "70-96", "--output", str(out), str(out)])
            write_set(name, out, "png")
        count += 1
    shutil.rmtree(tmp, ignore_errors=True)
    size = sum(f.stat().st_size for f in CATALOG.rglob("*") if f.is_file()) / 1_048_576
    print(f"imported {count} images, catalogue is {size:.1f} MB")


if __name__ == "__main__":
    main()
