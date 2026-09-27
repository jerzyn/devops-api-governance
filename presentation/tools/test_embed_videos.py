import subprocess

import pikepdf

from embed_videos import embed


def _tiny_mp4(path):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i",
                    "testsrc=d=1:s=320x180", "-pix_fmt", "yuv420p", str(path)], check=True)


def test_embeds_a_playable_screen_annotation(tmp_path):
    src, out, clip = tmp_path / "in.pdf", tmp_path / "out.pdf", tmp_path / "t.mp4"
    _tiny_mp4(clip)
    pdf = pikepdf.new()
    pdf.add_blank_page(page_size=(960, 540))
    pdf.add_blank_page(page_size=(960, 540))
    pdf.save(src)

    embed(src, out, {1: clip})

    pdf = pikepdf.open(out)
    assert "/Annots" not in pdf.pages[0].obj
    annots = pdf.pages[1].obj.Annots
    assert len(annots) == 1
    screen = annots[0]
    assert screen.Subtype == "/Screen"
    action = screen.A
    assert action.S == "/Rendition" and action.OP == 0
    assert action.AN.objgen == screen.objgen
    clipdata = action.R.C
    assert action.R.S == "/MR" and clipdata.S == "/MCD"
    assert str(clipdata.CT) == "video/mp4"
    stream = clipdata.D.EF.F
    assert len(stream.read_bytes()) == clip.stat().st_size
