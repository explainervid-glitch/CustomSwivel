"""
Reports which fonts are actually embedded in assets/SwivelFonts.swf and
whether every font named in SwivelHuey.xml matches one of them.

Run from the project root after republishing the FLA:

    python tools/check-fonts.py

A font that is requested but not embedded still *looks* fine on a machine
where that font is installed -- Swivel falls back to the system copy. It
disappears on every other machine. This check is the only reliable way to
catch that before shipping.
"""

import io
import os
import re
import struct
import sys
import zlib

SWF = os.path.join("assets", "SwivelFonts.swf")
XML = "SwivelHuey.xml"


def embedded_fonts(path):
    """Returns {font name: glyph count} for DefineFont2/3 tags in the SWF."""
    data = open(path, "rb").read()
    raw = data[:8] + zlib.decompress(data[8:]) if data[:3] == b"CWS" else data

    # Skip header: signature, version, length, frame rect, rate, count.
    p = 8
    nbits = raw[p] >> 3
    p += (5 + nbits * 4 + 7) // 8
    p += 4

    fonts = {}
    while p < len(raw) - 1:
        try:
            header = struct.unpack("<H", raw[p:p + 2])[0]
        except struct.error:
            break
        p += 2
        code, length = header >> 6, header & 0x3F
        if length == 0x3F:
            length = struct.unpack("<I", raw[p:p + 4])[0]
            p += 4
        body = raw[p:p + length]
        p += length

        if code in (48, 75):  # DefineFont2 / DefineFont3
            name_len = body[4]
            name = body[5:5 + name_len].split(b"\x00")[0].decode("latin1", "replace")
            fonts[name] = struct.unpack("<H", body[5 + name_len:7 + name_len])[0]

    return fonts


def requested_fonts(path):
    return sorted(set(re.findall(r'font="([^"]+)"', io.open(path, encoding="utf-8").read())))


def main():
    if not os.path.exists(SWF) or not os.path.exists(XML):
        print("Run this from the project root.")
        return 2

    embedded = embedded_fonts(SWF)
    requested = requested_fonts(XML)

    print("Embedded in %s:" % SWF)
    for name, glyphs in sorted(embedded.items()):
        print("   %-34s %d glyphs" % (name, glyphs))

    print("\nRequested by %s:" % XML)
    missing = []
    for name in requested:
        if name in embedded:
            print("   %-34s ok" % name)
        else:
            print("   %-34s NOT EMBEDDED" % name)
            missing.append(name)

    if missing:
        print("\n%d font(s) will vanish on machines without them installed:" % len(missing))
        for name in missing:
            print("   %s" % name)
        print("\nEither rename them in SwivelHuey.xml to match the embedded")
        print("names above, or re-export the FLA so the embedded names match.")
        return 1

    print("\nAll requested fonts are embedded.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
