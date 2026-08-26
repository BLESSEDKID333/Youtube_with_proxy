#!/usr/bin/env python3
"""
Generate iOS 6 launch images for the YouTube client.

The presence of Default-568h@2x.png is what tells iOS 6 to run the app
in full 320x568-point mode on the iPhone 5 instead of letterboxing it to
320x480. We also emit the 3.5" retina (@2x) and non-retina fallbacks.

Each image is a solid dark background (matching COLOR_DARK_BG = 35,35,35)
with a centered YouTube-style red rounded "play" badge. No PIL required.
"""
import struct, zlib, os

BG = (35, 35, 35)
RED = (204, 24, 30)
WHITE = (255, 255, 255)


def rounded_rect_mask(x, y, w, h, r, px, py):
    """Return True if pixel (px,py) is inside a rounded rect."""
    if px < x or px >= x + w or py < y or py >= y + h:
        return False
    # corner checks
    corners = [
        (x + r, y + r, px < x + r and py < y + r),
        (x + w - r, y + r, px >= x + w - r and py < y + r),
        (x + r, y + h - r, px < x + r and py >= y + h - r),
        (x + w - r, y + h - r, px >= x + w - r and py >= y + h - r),
    ]
    for cx, cy, in_corner in corners:
        if in_corner:
            return (px - cx) ** 2 + (py - cy) ** 2 <= r * r
    return True


def point_in_triangle(px, py, ax, ay, bx, by, cx, cy):
    d1 = (px - bx) * (ay - by) - (ax - bx) * (py - by)
    d2 = (px - cx) * (by - cy) - (bx - cx) * (py - cy)
    d3 = (px - ax) * (cy - ay) - (cx - ax) * (py - ay)
    neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
    pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
    return not (neg and pos)


def render(width, height):
    # badge geometry scaled to width
    bw = int(width * 0.42)
    bh = int(bw * 0.70)
    bx = (width - bw) // 2
    by = (height - bh) // 2
    r = int(bh * 0.22)
    # triangle inside badge
    tw = int(bw * 0.34)
    th = int(bh * 0.44)
    tcx = bx + bw // 2
    tcy = by + bh // 2
    ax, ay = tcx - tw // 3, tcy - th // 2
    bx2, by2 = tcx - tw // 3, tcy + th // 2
    cx2, cy2 = tcx + tw * 2 // 3, tcy

    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type 0
        for x in range(width):
            if rounded_rect_mask(bx, by, bw, bh, r, x, y):
                if point_in_triangle(x, y, ax, ay, bx2, by2, cx2, cy2):
                    px = WHITE
                else:
                    px = RED
            else:
                px = BG
            raw.extend(px)
    return bytes(raw)


def write_png(path, width, height):
    data = render(width, height)

    def chunk(tag, payload):
        c = struct.pack(">I", len(payload)) + tag + payload
        return c + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # 8-bit RGB
    idat = zlib.compress(data, 9)
    png = sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
    print("wrote %s (%dx%d, %d bytes)" % (path, width, height, len(png)))


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "YouTube")
    write_png(os.path.join(out, "Default.png"), 320, 480)
    write_png(os.path.join(out, "Default@2x.png"), 640, 960)
    write_png(os.path.join(out, "Default-568h@2x.png"), 640, 1136)
