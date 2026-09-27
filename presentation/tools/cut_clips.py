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


def main(cuts_path, recordings_dir):
    cuts = json.loads(Path(cuts_path).read_text())
    outs = []
    for stage, parts in cuts.items():
        out = Path(recordings_dir) / f"{stage}-talk.mp4"
        cmd = ["ffmpeg", "-v", "error", "-y"]
        for p in parts:
            cmd += ["-i", str(Path(recordings_dir) / p["src"])]
        cmd += ["-filter_complex", build_filter(parts), "-map", "[out]", "-an",
                "-c:v", "libx264", "-preset", "slow", "-crf", "23",
                "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(out)]
        subprocess.run(cmd, check=True)
        if out.stat().st_size > MAX_BYTES:
            sys.exit(f"{out} is over 19.5 MB; raise -crf")
        outs.append(out)
    return outs


if __name__ == "__main__":
    for o in main(sys.argv[1], sys.argv[2]):
        print(o)
