#!/usr/bin/env python3
"""Verify copied media bytes, rather than trusting sync timestamps or source hashes."""
import hashlib, json, os
from pathlib import Path
root = Path(__file__).resolve().parent.parent
source = root / "OtterAndMosey"
dest = root / "web/dist-playtest/assets"
pairs = []
for manifest in (source / "Assets.xcassets").glob("*.imageset/Contents.json"):
    for image in json.loads(manifest.read_text())["images"]:
        if image.get("filename"):
            path = manifest.parent / image["filename"]
            pairs.append((path, dest / "art" / (manifest.parent.stem + path.suffix.lower())))
            break
for directory, target in [("Audio", "audio"), ("Speech", "speech")]:
    for path in (source / "Resources" / directory).iterdir():
        if path.suffix in [".mp3", ".m4a"]: pairs.append((path, dest / target / path.name))
manifest = {}
for path, copy in pairs:
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    assert copy.exists(), f"Missing packaged asset: {copy}"
    assert hashlib.sha256(copy.read_bytes()).hexdigest() == digest, f"Stale packaged asset: {copy}"
    manifest[str(path.relative_to(root))] = digest
for path in (root / "Packages/LostIslandsCore/Sources/LostIslandsCore/Resources").glob("*.json"):
    manifest[str(path.relative_to(root))] = hashlib.sha256(path.read_bytes()).hexdigest()
Path(os.environ["PLAYTEST_OUTPUT"], "content-manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True))
print(f"Verified {len(pairs)} bundled media files; recorded content hashes.")
