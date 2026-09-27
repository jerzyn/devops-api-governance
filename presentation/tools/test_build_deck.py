import json
import re

from build_deck import ORDER, build


def test_deck_files_follow_the_slides_format(tmp_path):
    slides = build(tmp_path, "2026-09-27T00:00:00Z")
    index = json.loads((tmp_path / "project" / "deck.json").read_text())
    assert index["order"] == ORDER and set(slides) == set(ORDER)
    for sid in ORDER:
        html = (tmp_path / "project" / "slides" / f"{sid}.html").read_text()
        assert html.startswith(f'<section id="{sid}"') and html.rstrip().endswith("</section>")
        assert html.count("<section") == 1
        notes = re.search(r"<aside>(.*)</aside>", html, re.S).group(1)
        assert 0 < len(notes) <= 4000
        assert html.rstrip()[:-len("</section>")].rstrip().endswith("</aside>")
        for size in re.findall(r"font-size:(\d+)px", html):
            assert int(size) >= 24, (sid, size)
        for banned in ("margin", "<style", "class=", "var("):
            assert banned not in html, (sid, banned)
        assert not re.search(r"\d(r?em)\b", html), sid
        assert len(re.findall(r"<(?!/|br|aside)[a-z-]+", html)) <= 200, sid
        for src in re.findall(r'(?:src|data-video)="([^"]+)"', html):
            assert src.startswith("/_blob/"), (sid, src)


def test_every_video_slide_plays_its_clip_on_click(tmp_path):
    slides = build(tmp_path, "2026-09-27T00:00:00Z")
    for n in range(1, 6):
        html = slides[f"v{n}"]
        assert 'data-video="/_blob/' in html and 'data-video-start="click"' in html
        assert f"DEMO · STEP {n}" in html


def test_notes_carry_checkpoints_valid_cue_times_and_transitions(tmp_path):
    slides = build(tmp_path, "2026-09-27T00:00:00Z")
    for sid in ("thread", "t2", "t4"):
        assert "Behind?" in slides[sid], sid
    for n in range(1, 6):
        html = slides[f"v{n}"]
        assert not re.search(r"~0:[6-9]\d", html), n
        assert "Transition:" in html, n
