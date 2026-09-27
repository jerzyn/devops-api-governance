"""Put the five demo clips into the deck's PDF, HTML and PPTX exports.

The Slides exports show a still frame on each video slide. This swaps that
still for the real clip, in place:
  PDF  -> a click-to-play Screen annotation (embed_videos.py; plays in Okular)
  HTML -> a <video> element with the clip inlined as a data: URL
  PPTX -> an embedded video on the picture (PowerPoint, LibreOffice, OnlyOffice)

Usage: embed_exports.py <export basename without extension>
The clips are recordings/stage{1..5}-talk.mp4; video slide N is the one whose
still has the alt text "Recorded demo, step N: ...".
"""
import base64
import re
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

from build_deck import ORDER
from embed_videos import embed as embed_pdf

HERE = Path(__file__).resolve().parent
CLIPS = {n: HERE.parent / "recordings" / f"stage{n}-talk.mp4" for n in range(1, 6)}
VIDEO_REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/video"
MEDIA_REL = "http://schemas.microsoft.com/office/2007/relationships/media"


def _still_tag(n):
    return re.compile(r'<img\b[^>]*\balt="Recorded demo, step %d:[^"]*"[^>]*>' % n)


def embed_html(html, clips):
    for n, clip in clips.items():
        m = _still_tag(n).search(html)
        if not m:
            raise ValueError(f"no still for step {n} in the HTML")
        tag = m.group(0)
        poster = re.search(r'\bsrc="([^"]*)"', tag).group(1)
        m_style = re.search(r'\bstyle="([^"]*)"', tag)
        style = m_style.group(1) if m_style else ""
        data = base64.b64encode(Path(clip).read_bytes()).decode()
        video = (f'<video src="data:video/mp4;base64,{data}" poster="{poster}" '
                 f'controls playsinline preload="auto" style="{style}"></video>')
        html = html[:m.start()] + video + html[m.end():]
    return html


def embed_pptx(src, out, clips):
    tmp = Path(tempfile.mkdtemp())
    with zipfile.ZipFile(src) as z:
        z.extractall(tmp)
    slides = sorted((tmp / "ppt" / "slides").glob("slide*.xml"))
    for n, clip in clips.items():
        slide = next((s for s in slides
                      if f'descr="Recorded demo, step {n}:' in s.read_text()), None)
        if slide is None:
            raise ValueError(f"no still for step {n} in the PPTX")
        media = f"stage{n}-talk.mp4"
        (tmp / "ppt" / "media").mkdir(exist_ok=True)
        shutil.copy(clip, tmp / "ppt" / "media" / media)
        rels = slide.parent / "_rels" / (slide.name + ".rels")
        r = rels.read_text()
        r = r.replace("</Relationships>",
                      f'<Relationship Id="rIdVid{n}" Type="{VIDEO_REL}" Target="../media/{media}"/>'
                      f'<Relationship Id="rIdMed{n}" Type="{MEDIA_REL}" Target="../media/{media}"/>'
                      "</Relationships>")
        rels.write_text(r)
        x = slide.read_text()
        # the picture keeps its still as the poster; it gains a click-to-play video
        x = re.sub(r'(<p:cNvPr [^>]*descr="Recorded demo, step %d:[^"]*"[^>]*>)\s*(</p:cNvPr>)?' % n,
                   r'\1<a:hlinkClick r:id="" action="ppaction://media"/></p:cNvPr>', x, count=1)
        x = x.replace("</p:cNvPr></p:cNvPr>", "</p:cNvPr>")
        nvpr = (f'<p:nvPr><a:videoFile r:link="rIdVid{n}"/><p:extLst>'
                '<p:ext uri="{DAA4B4D4-6D71-4841-9C94-3DE7FCFB9230}">'
                '<p14:media xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main" '
                f'r:embed="rIdMed{n}"/></p:ext></p:extLst></p:nvPr>')
        # only inside this picture's <p:nvPicPr>, never the slide's group shape
        pic_start = x.index(f'descr="Recorded demo, step {n}:')
        pic_end = x.index("</p:nvPicPr>", pic_start)
        x = x[:pic_start] + re.sub(r"<p:nvPr>\s*</p:nvPr>|<p:nvPr/>", nvpr,
                                   x[pic_start:pic_end], count=1) + x[pic_end:]
        # a media timing node: PowerPoint plays on click, LibreOffice needs it to import the video
        spid = re.search(r'<p:cNvPr id="(\d+)"[^>]*descr="Recorded demo, step %d:' % n, x).group(1)
        timing = ('<p:timing><p:tnLst><p:par><p:cTn id="1" dur="indefinite" restart="never" '
                  'nodeType="tmRoot"><p:childTnLst><p:video><p:cMediaNode vol="80000">'
                  '<p:cTn id="2" fill="hold" display="0"><p:stCondLst><p:cond delay="indefinite"/>'
                  f'</p:stCondLst></p:cTn><p:tgtEl><p:spTgt spid="{spid}"/></p:tgtEl></p:cMediaNode>'
                  '</p:video></p:childTnLst></p:cTn></p:par></p:tnLst></p:timing>')
        if "<p:timing>" not in x:
            x = x.replace("</p:clrMapOvr>", "</p:clrMapOvr>" + timing, 1) if "</p:clrMapOvr>" in x \
                else x.replace("</p:sld>", timing + "</p:sld>")
        slide.write_text(x)
    ct = tmp / "[Content_Types].xml"
    c = ct.read_text()
    if 'Extension="mp4"' not in c:
        c = c.replace("</Types>", '<Default Extension="mp4" ContentType="video/mp4"/></Types>')
        ct.write_text(c)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        ct_path = tmp / "[Content_Types].xml"
        z.write(ct_path, "[Content_Types].xml")
        for f in sorted(tmp.rglob("*")):
            if f.is_file() and f != ct_path:
                arc = f.relative_to(tmp).as_posix()
                z.write(f, arc, zipfile.ZIP_STORED if arc.endswith(".mp4") else zipfile.ZIP_DEFLATED)
    shutil.rmtree(tmp)


def main(base):
    base = Path(base)
    visible = [s for s in ORDER if s != "qa"]
    pdf_pages = {visible.index(f"v{n}"): clip for n, clip in CLIPS.items()}
    for ext in (".pdf", ".html", ".pptx"):
        src = base.with_name(base.name + ext)
        if not src.exists():
            print(f"skip {src.name}: not found")
            continue
        tmp = src.with_name(src.stem + ".embedding" + ext)
        if ext == ".pdf":
            embed_pdf(src, tmp, pdf_pages)
        elif ext == ".html":
            tmp.write_text(embed_html(src.read_text(), CLIPS))
        else:
            embed_pptx(src, tmp, CLIPS)
        tmp.replace(src)
        print(f"{src.name}: {src.stat().st_size / 1e6:.1f} MB, 5 videos embedded")


if __name__ == "__main__":
    main(sys.argv[1])
