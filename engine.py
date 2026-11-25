"""Local batch renderer. Requires FFmpeg and rights-cleared local media."""
import argparse
import hashlib
import json
import math
import subprocess
from pathlib import Path

def render(manifest, song, output, limit=20, duration=15):
    if not 1 <= limit <= 2500 or not 5 <= duration <= 30:
        raise ValueError("Invalid batch limit or duration")
    rows = json.loads(Path(manifest).read_text())
    if not isinstance(rows, list):
        raise ValueError("Manifest must be an array")
    song = Path(song).resolve(strict=True)
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    results = []
    seen = set()
    for row in rows:
        if len(results) >= limit:
            break
        if row.get("rights_confirmed") is not True:
            continue
        source = Path(row["video"]).resolve(strict=True)
        start = float(row.get("start", 0))
        if not math.isfinite(start) or start < 0:
            continue
        key = hashlib.sha256(f"{source}|{start}|{song}|{duration}".encode()).hexdigest()
        if key in seen:
            continue
        seen.add(key)
        dest = output / f"{key[:24]}.mp4"
        if dest.exists():
            results.append({"file": str(dest), "status": "existing"})
            continue
        temp = dest.with_suffix(".partial.mp4")
        cmd = ["ffmpeg", "-nostdin", "-v", "error", "-y", "-ss", str(start),
               "-i", str(source), "-stream_loop", "-1", "-i", str(song),
               "-map", "0:v:0", "-map", "1:a:0", "-t", str(duration), "-shortest",
               "-vf", "scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280,setsar=1,fps=30",
               "-c:v", "libx264", "-preset", "veryfast", "-crf", "23",
               "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "128k",
               "-movflags", "+faststart", str(temp)]
        try:
            subprocess.run(cmd, check=True, timeout=300, capture_output=True)
            temp.replace(dest)
            results.append({"file": str(dest), "status": "rendered"})
        except (subprocess.SubprocessError, OSError) as exc:
            temp.unlink(missing_ok=True)
            results.append({"file": str(dest), "status": "failed", "error": str(exc)})
    (output / "batch_report.json").write_text(json.dumps(results, indent=2))
    return results

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest")
    parser.add_argument("song")
    parser.add_argument("output")
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument("--duration", type=int, default=15)
    args = parser.parse_args()
    print(json.dumps(render(args.manifest, args.song, args.output, args.limit, args.duration), indent=2))
