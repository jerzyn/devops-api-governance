import subprocess
import zipfile

from embed_exports import embed_html, embed_pptx


def _tiny_mp4(path):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i",
                    "testsrc=d=1:s=320x180", "-pix_fmt", "yuv420p", str(path)], check=True)


def test_html_still_becomes_video_with_poster(tmp_path):
    clip = tmp_path / "c.mp4"
    _tiny_mp4(clip)
    html = ('<section><img data-x="" src="data:image/jpeg;base64,AAAA" '
            'alt="Recorded demo, step 1: API catalog" style="width: 100%; object-fit: contain;"></section>'
            '<img src="data:image/png;base64,BBBB" alt="QR code">')
    out = embed_html(html, {1: clip})
    assert '<video ' in out and 'poster="data:image/jpeg;base64,AAAA"' in out
    assert 'src="data:video/mp4;base64,' in out and " controls" in out
    assert 'alt="QR code"' in out            # other images untouched
    assert 'alt="Recorded demo' not in out   # the still is replaced


def _mini_pptx(path):
    ct = ('<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="xml" ContentType="application/xml"/></Types>')
    slide = ('<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
             'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
             'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree>'
             '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
             '<p:pic><p:nvPicPr><p:cNvPr id="2" name="Image 0" descr="Recorded demo, step 1: API catalog">'
             '</p:cNvPr><p:cNvPicPr/><p:nvPr></p:nvPr></p:nvPicPr><p:blipFill><a:blip r:embed="rId1"/>'
             '</p:blipFill><p:spPr/></p:pic></p:spTree></p:cSld></p:sld>')
    rels = ('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
            'Target="../media/image-11-1.jpeg"/></Relationships>')
    with zipfile.ZipFile(path, "w") as z:
        z.writestr("[Content_Types].xml", ct)
        z.writestr("ppt/slides/slide11.xml", slide)
        z.writestr("ppt/slides/_rels/slide11.xml.rels", rels)


def test_pptx_picture_becomes_embedded_video(tmp_path):
    src, out, clip = tmp_path / "in.pptx", tmp_path / "out.pptx", tmp_path / "c.mp4"
    _tiny_mp4(clip)
    _mini_pptx(src)
    embed_pptx(src, out, {1: clip})
    z = zipfile.ZipFile(out)
    slide = z.read("ppt/slides/slide11.xml").decode()
    rels = z.read("ppt/slides/_rels/slide11.xml.rels").decode()
    assert '<a:videoFile r:link="' in slide and "p14:media" in slide
    assert "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" in slide
    pic = slide[slide.index("<p:pic>"):]
    assert pic.index("<a:videoFile") < pic.index("</p:nvPicPr>")
    assert 'action="ppaction://media"' in slide
    assert '<p:video><p:cMediaNode' in slide and '<p:spTgt spid="2"/>' in slide
    assert "relationships/video" in rels and "2007/relationships/media" in rels
    assert z.read("ppt/media/stage1-talk.mp4") == clip.read_bytes()
    assert 'Extension="mp4"' in z.read("[Content_Types].xml").decode()
