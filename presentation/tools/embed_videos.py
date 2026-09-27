"""Embed MP4 clips into PDF pages as Screen annotations, for Okular.

Usage: embed_videos.py <in.pdf> <out.pdf> <page>=<clip.mp4> ...
(page is 1-based). Each clip becomes a full-page Screen annotation whose
click action plays the embedded file; the page's own still shows until then.
"""
import sys
from pathlib import Path

import pikepdf
from pikepdf import Array, Dictionary, Name, String


def _screen(pdf, page, clip):
    data = Path(clip).read_bytes()
    stream = pikepdf.Stream(pdf, data)
    stream.Type = Name.EmbeddedFile
    stream.Subtype = Name("/video#2Fmp4")
    name = String(Path(clip).name)
    filespec = pdf.make_indirect(Dictionary(
        Type=Name.Filespec, F=name, UF=name, EF=Dictionary(F=stream)))
    rendition = Dictionary(
        Type=Name.Rendition, S=Name.MR, N=name,
        C=Dictionary(Type=Name.MediaClip, S=Name.MCD, N=name,
                     CT=String("video/mp4"), D=filespec,
                     P=Dictionary(Type=Name.MediaPermissions, TF=String("TEMPACCESS"))),
        P=Dictionary(Type=Name.MediaPlayParams, BE=Dictionary(C=True, A=False)))
    box = page.mediabox
    annot = pdf.make_indirect(Dictionary(
        Type=Name.Annot, Subtype=Name.Screen, Rect=Array(list(box)), F=4,
        P=page.obj, T=name))
    annot.A = Dictionary(Type=Name.Action, S=Name.Rendition, OP=0, R=rendition, AN=annot)
    if "/Annots" not in page.obj:
        page.obj.Annots = Array()
    page.obj.Annots.append(annot)


def embed(pdf_in, pdf_out, videos):
    """videos: 0-based page index -> clip path."""
    with pikepdf.open(pdf_in) as pdf:
        for index, clip in videos.items():
            _screen(pdf, pdf.pages[index], clip)
        pdf.save(pdf_out)


if __name__ == "__main__":
    pairs = dict(arg.split("=", 1) for arg in sys.argv[3:])
    embed(sys.argv[1], sys.argv[2], {int(k) - 1: v for k, v in pairs.items()})
