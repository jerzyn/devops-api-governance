"""Cut the talk clips from the raw recordings, per cuts.json.

Each stage is a list of parts (source clip, from/to in seconds, speed);
the parts are trimmed, sped up and joined into recordings/<stage>-talk.mp4.
"""
import json
import subprocess
import sys
from pathlib import Path

# The Slides artifact refuses clips over 20 MB.
MAX_BYTES = int(19.5 * 1024 * 1024)


def build_filter(parts):
    chains = [f"[{i}:v]trim=start={p['from']}:end={p['to']},"
              f"setpts=(PTS-STARTPTS)/{p['speed']}[v{i}]" for i, p in enumerate(parts)]
    joined = "".join(f"[v{i}]" for i in range(len(parts)))
    return ";".join(chains) + f";{joined}concat=n={len(parts)}:v=1:a=0,fps=25[out]"


def retime_segments(total, retimes):
    """Cover [0, total] of an already-cut clip: the given ranges at their speed, the rest at 1x."""
    segs, pos = [], 0.0
    for r in sorted(retimes, key=lambda r: r["from"]):
        if r["from"] > pos:
            segs.append((pos, r["from"], 1.0))
        segs.append((r["from"], r["to"], r["speed"]))
        pos = r["to"]
    if pos < total:
        segs.append((pos, total, 1.0))
    return segs


def _duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                          "-of", "csv=p=0", str(path)], capture_output=True, text=True, check=True)
    return float(out.stdout)


def _retime(path, retimes):
    """Second pass on the cut clip: speed up ranges given in the cut clip's own timeline."""
    segs = retime_segments(_duration(path), retimes)
    chains = [f"[0:v]trim=start={a}:end={b},setpts=(PTS-STARTPTS)/{sp}[r{i}]"
              for i, (a, b, sp) in enumerate(segs)]
    joined = "".join(f"[r{i}]" for i in range(len(segs)))
    filt = ";".join(chains) + f";{joined}concat=n={len(segs)}:v=1:a=0,fps=25[out]"
    tmp = path.with_suffix(".retime.mp4")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(path), "-filter_complex", filt,
                    "-map", "[out]", "-an", "-c:v", "libx264", "-preset", "slow", "-crf", "21",
                    "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(tmp)], check=True)
    tmp.replace(path)


def main(cuts_path, recordings_dir):
    cuts = json.loads(Path(cuts_path).read_text())
    outs = []
    for stage, spec in cuts.items():
        # a stage is a list of parts, or {"parts": [...], "retime": [...]} where
        # retime speeds up ranges of the cut clip (times in the cut clip's timeline)
        parts = spec["parts"] if isinstance(spec, dict) else spec
        out = Path(recordings_dir) / f"{stage}-talk.mp4"
        cmd = ["ffmpeg", "-v", "error", "-y"]
        for p in parts:
            cmd += ["-i", str(Path(recordings_dir) / p["src"])]
        cmd += ["-filter_complex", build_filter(parts), "-map", "[out]", "-an",
                "-c:v", "libx264", "-preset", "slow", "-crf", "23",
                "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(out)]
        subprocess.run(cmd, check=True)
        if isinstance(spec, dict) and spec.get("retime"):
            _retime(out, spec["retime"])
        if out.stat().st_size > MAX_BYTES:
            sys.exit(f"{out} is over 19.5 MB; raise -crf")
        outs.append(out)
    return outs


if __name__ == "__main__":
    for o in main(sys.argv[1], sys.argv[2]):
        print(o)
