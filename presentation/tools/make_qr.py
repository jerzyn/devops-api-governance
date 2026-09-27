"""Make the repo QR code for the closing slide."""
import sys

import qrcode


def make_qr(url, path):
    qrcode.make(url, box_size=24, border=2).save(path)


if __name__ == "__main__":
    make_qr(sys.argv[1], sys.argv[2])
