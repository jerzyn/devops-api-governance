from PIL import Image

from make_qr import make_qr


def test_qr_is_square_and_large(tmp_path):
    out = tmp_path / "qr.png"
    make_qr("https://codeberg.org/pierogi/devops-api-governance", out)
    w, h = Image.open(out).size
    assert w == h and w >= 600
