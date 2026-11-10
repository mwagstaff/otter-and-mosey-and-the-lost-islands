#!/usr/bin/env python3
"""Development-time art generator for Otter & Mosey: The Lost Islands.

Reads tools/art_manifest.json and calls the OpenAI Images API for any asset whose raw
output is missing from tools/raw/. Nothing here runs inside the app, and the API key is
read from the environment (OPENAI_API_KEY_CHATGPT_GRAPHICS) and never written anywhere.

Usage:
    python3 tools/generate_art.py                 # everything still missing
    python3 tools/generate_art.py otter_ref bg_*  # only the named assets (globs allowed)
    python3 tools/generate_art.py --force otter_cheer

Spend is tracked in tools/.art-ledger.json and generation stops at BUDGET_USD.
"""
import base64, concurrent.futures, fnmatch, json, os, pathlib, subprocess, sys, tempfile, threading

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "tools/raw"
LEDGER = ROOT / "tools/.art-ledger.json"
BUDGET_USD = float(os.environ.get("ART_BUDGET_USD", "13"))
# Published token rates (USD per million tokens) shared by the GPT Image 2.x family.
RATE_TEXT_IN, RATE_IMAGE_IN, RATE_OUT = 5.0, 8.0, 30.0
KEY = os.environ.get("OPENAI_API_KEY_CHATGPT_GRAPHICS")
lock = threading.Lock()


def load_ledger():
    return json.loads(LEDGER.read_text()) if LEDGER.exists() else {"total_usd": 0.0, "entries": []}


def cost(usage):
    details = usage.get("input_tokens_details", {})
    return (details.get("text_tokens", 0) * RATE_TEXT_IN + details.get("image_tokens", 0) * RATE_IMAGE_IN
            + usage.get("output_tokens", 0) * RATE_OUT) / 1_000_000


def call(asset, style):
    prompt = asset["prompt"] + " " + style[asset.get("style", "sprite")]
    common = {
        "model": asset.get("model", "gpt-image-2.5-flare"),
        "prompt": prompt,
        "size": asset.get("size", "1024x1024"),
        "quality": asset.get("quality", "medium"),
        "background": asset.get("background", "transparent"),
        "output_format": "png",
    }
    with tempfile.NamedTemporaryFile(suffix=".json") as out:
        if asset.get("refs"):
            cmd = ["curl", "-sS", "--max-time", "600", "--config", "-", "https://api.openai.com/v1/images/edits",
                   "-o", out.name]
            for key, value in common.items():
                cmd += ["-F", f"{key}={value}"]
            for ref in asset["refs"]:
                path = ROOT / ref
                if not path.exists():
                    raise RuntimeError(f"missing reference {ref}")
                cmd += ["-F", f"image[]=@{path}"]
        else:
            cmd = ["curl", "-sS", "--max-time", "600", "--config", "-", "https://api.openai.com/v1/images/generations",
                   "-H", "Content-Type: application/json",
                   "-d", json.dumps(common), "-o", out.name]
        # The key goes to curl on stdin so it never appears in argv, logs or error messages.
        last = None
        for _ in range(3):
            last = subprocess.run(cmd, input=f'header = "Authorization: Bearer {KEY}"\n', text=True, capture_output=True)
            if last.returncode == 0:
                break
        if last.returncode != 0:
            raise RuntimeError(f"curl exited {last.returncode}: {last.stderr.strip()[:200]}")
        response = json.loads(pathlib.Path(out.name).read_text())
    if "data" not in response:
        raise RuntimeError(json.dumps(response.get("error", response))[:400])
    (RAW / f"{asset['name']}.png").write_bytes(base64.b64decode(response["data"][0]["b64_json"]))
    return cost(response.get("usage", {}))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    if not KEY:
        sys.exit("OPENAI_API_KEY_CHATGPT_GRAPHICS is not set (try: bw-reload)")
    manifest = json.loads((ROOT / "tools/art_manifest.json").read_text())
    RAW.mkdir(parents=True, exist_ok=True)
    todo = []
    for asset in manifest["assets"]:
        if args and not any(fnmatch.fnmatch(asset["name"], pattern) for pattern in args):
            continue
        if (RAW / f"{asset['name']}.png").exists() and not force:
            continue
        todo.append(asset)
    if not todo:
        print("nothing to generate")
        return

    def work(asset):
        with lock:
            ledger = load_ledger()
            if ledger["total_usd"] >= BUDGET_USD:
                return f"SKIP {asset['name']}: budget of ${BUDGET_USD:.2f} reached"
        try:
            spent = call(asset, manifest["styles"])
        except Exception as error:  # keep going with the rest of the batch
            return f"FAIL {asset['name']}: {error}"
        with lock:
            ledger = load_ledger()
            ledger["total_usd"] = round(ledger["total_usd"] + spent, 4)
            ledger["entries"].append({"name": asset["name"], "usd": round(spent, 4)})
            LEDGER.write_text(json.dumps(ledger, indent=1))
            return f"ok   {asset['name']}  ${spent:.3f}  (total ${ledger['total_usd']:.2f})"

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for line in pool.map(work, todo):
            print(line, flush=True)


if __name__ == "__main__":
    main()
