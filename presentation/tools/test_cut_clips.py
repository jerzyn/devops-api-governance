from cut_clips import build_filter


def test_filter_trims_speeds_and_concats():
    parts = [{"src": "a.mp4", "from": 1.0, "to": 3.0, "speed": 1.0},
             {"src": "b.mp4", "from": 0.0, "to": 4.0, "speed": 2.0}]
    f = build_filter(parts)
    assert "[0:v]trim=start=1.0:end=3.0,setpts=(PTS-STARTPTS)/1.0[v0]" in f
    assert "[1:v]trim=start=0.0:end=4.0,setpts=(PTS-STARTPTS)/2.0[v1]" in f
    assert f.endswith("[v0][v1]concat=n=2:v=1:a=0,fps=25[out]")
