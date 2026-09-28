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
        assert "left:0px; top:0px; width:1920px; height:1080px" in html
        assert "<p " not in html.split("<aside>")[0]  # nothing drawn over the video


def test_notes_carry_checkpoints_valid_cue_times_and_transitions(tmp_path):
    slides = build(tmp_path, "2026-09-27T00:00:00Z")
    for sid in ("thread", "t2", "t4"):
        assert "Behind?" in slides[sid], sid
    for n in range(1, 6):
        html = slides[f"v{n}"]
        assert not re.search(r"~0:[6-9]\d", html), n
        assert "Transition:" in html, n


def test_review_round_1_changes(tmp_path):
    slides = build(tmp_path, "2026-09-27T00:00:00Z")
    event = re.search(r'<p style="([^"]*)">FOST London 2026', slides["title"])
    assert event and "position:absolute" in event.group(1)
    assert "Lead of Policy as Code in API governance" in slides["about"]
    assert "ac781fdac69e95bab1e7fc8700ebff3c" in slides["book"]  # book QR moved to its own slide
    assert "f845b612ff5c3c5f08f2e3c379bf5372" not in slides["thanks"]
    assert "f845b612ff5c3c5f08f2e3c379bf5372" in slides["feedback"]
    assert ORDER.index("feedback") == ORDER.index("thanks") + 1


def test_review_round_2_layout_fixes(tmp_path):
    slides = build(tmp_path, "2026-09-27T00:00:00Z")
    for number in ("70–80%", "99.6%", "~60%"):
        tag = re.search(r'<p style="([^"]*)">' + re.escape(number) + "</p>", slides["agents"])
        assert tag and "white-space:nowrap" in tag.group(1), number
    assert "fc6979b5ff4e9fec57245e41f0e67fea" in slides["catalog"]


def test_visible_text_has_no_trailing_period(tmp_path):
    slides = build(tmp_path, "2026-09-27T00:00:00Z")
    for sid, html in slides.items():
        visible = html.split("<aside>")[0]
        assert not re.search(r"\.</(p|h1|h2|h3|li|b|span)>", visible), sid


def test_statement_and_code_colors(tmp_path):
    slides = build(tmp_path, "2026-09-27T00:00:00Z")
    assert "AI-ready APIs are not a separate initiative" in slides["agents"]
    assert "product of your API governance program" in slides["agents"]
    for sid in ("catalogfile", "t2", "t3", "t4", "t5"):
        code_block = re.search(r"JetBrains Mono[^>]*>(.*?)</p>", slides[sid]).group(1)
        assert code_block.count('<span style="color:') >= 3, sid
    assert '<span style="color:#f28b82">error</span>' in slides["t5"]
    assert '<span style="color:#7cc8ea">apiVersion</span>' in slides["catalogfile"]


def test_pipeline_is_25_percent_larger_and_fits():
    from build_deck import pipeline
    html = pipeline("guidelines")
    sizes = set(int(x) for x in re.findall(r"font-size:(\d+)px", html))
    assert sizes == {30}  # was 24px
    widths = [int(x) for x in re.findall(r"width:(\d+)px", html)]
    # PR + 3 outer arrows + CI box (4 gates, 3 arrows, 2x20 padding, 2x2 border) + Merge + right column
    gates = widths.count(230)
    assert gates == 4
    total = 160 + 3 * 30 + (4 * 230 + 3 * 24 + 40 + 4) + 130 + 200
    assert total <= 1664


def test_about_photo_only_and_book_slide_follows(tmp_path):
    slides = build(tmp_path, "2026-09-27T00:00:00Z")
    book_cover, book_qr = "87da81414be4cd152ed5b1d65641ba3c", "ac781fdac69e95bab1e7fc8700ebff3c"
    assert book_cover not in slides["about"] and book_qr not in slides["about"]
    assert "align-self:center" in slides["about"]
    assert book_cover in slides["book"] and book_qr in slides["book"]
    assert ORDER.index("book") == ORDER.index("about") + 1
    assert book_cover not in slides["thanks"]
    assert "One example, many uses" in slides["t3"]


def test_review_round_3(tmp_path):
    slides = build(tmp_path, "2026-09-27T00:00:00Z")
    about = slides["about"]
    order = [about.index(x) for x in (">3scale<", ">adidas<", ">ING<", ">PZU<")]
    assert order == sorted(order)
    assert "iWelcome" not in about and ">Author<" not in about
    assert "hard to do things wrong" in slides["why"]
    assert "opacity:0.08" in slides["catalog"]
    assert "Publish" in slides["gateway"]
    assert "x-krakend" in slides["t4"] and "Enterprise" in slides["t4"]
    # pipeline: current gate glows, everything else at 60%
    g = slides["guidelines"]
    assert g.count("opacity:0.6") >= 7 and "box-shadow" in g
    assert "opacity:0.6" not in slides["pipeline"]  # final slide: everything active


def test_t2_points_to_spotlight(tmp_path):
    slides = build(tmp_path, "2026-09-28T00:00:00Z")
    assert "328448ddaed6edf1c34a5d1ae7b4deb8" in slides["t2"]
    assert "Spotlight" in slides["t2"] and "telemetry" in slides["t2"]
