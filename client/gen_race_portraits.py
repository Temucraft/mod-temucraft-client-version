#!/usr/bin/env python3
"""
Makes character create's race portraits from Ryan's 130x130 retail portraits (_dev/race-portraits-130/
Charactercreate-races_<name>-<male|female>.png):

  Interface/Glues/CharacterCreate/TemucraftRace_<RACE FILE>_<MALE|FEMALE>.blp   128x128, round (soft-edged alpha
      circle, so the thin gold ring sits on its edge), DXT5 with every mip level (BLP2)
  Interface/GlueXML/TemucraftRacePortraits.lua   TEMUCRAFT_RACE_PORTRAIT_FILES["<RACE FILE>"] = true for every race
      that has them (the others keep the old atlas icon), TEMUCRAFT_RACE_PORTRAIT_FACING["<RACE FILE>_<SEX>"] =
      "left" / "right": which way the picture looks (LEFT below), so character create can turn each column's
      portraits toward the middle

Race ids -> pictures: RACE_ART below. Dracthyr (25, 26) use the visage pictures: the client shows the Blood Elf-like
visage model on character create (Character\\DracthyrVisage in the PTR's patch-~.MPQ), not the dragon form. Worgen use
the "-male2 / -female2" pictures, Haranir the plain ones (not "-beta"). Race file names: ChrRaces.dbc from the PTR's
patch-~.MPQ.

    python3 gen_race_portraits.py [--src <folder of PNGs>] [--release "<TemuCraft Server>/5) Release"] [--lua-only]
"""
import argparse, io, os, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SERVER = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
SIZE = 128

RACE_ART = {
    1: "human", 2: "orc", 3: "dwarf", 4: "nightelf", 5: "undead", 6: "tauren", 7: "gnome", 8: "troll", 9: "goblin",
    10: "bloodelf", 11: "draenei", 12: ("worgen", "2"), 13: "panda", 14: "panda", 15: "nightborne", 16: "highmountain",
    17: "voidelf", 18: "lightforged", 19: "ZandalariTroll", 20: "kultiranhuman", 21: "vulpera", 22: "darkirondwarf",
    23: "maghar", 24: "mechagnome", 25: "dracthyr-visage", 26: "dracthyr-visage", 27: "earthen", 28: "earthen",
    29: "haranir", 30: "haranir",
}


# which way each picture looks (checked by eye on the 130 px PNGs): "left" = toward the viewer's left. Character create
# mirrors a picture that looks away from the middle (Alliance column: right, Horde column: left).
LEFT = {("ZandalariTroll", "male"), ("ZandalariTroll", "female"), ("goblin", "male"), ("goblin", "female"),
        ("highmountain", "male"), ("highmountain", "female"), ("maghar", "male"), ("maghar", "female"),
        ("nightborne", "male"), ("nightborne", "female"), ("orc", "male"), ("orc", "female"),
        ("tauren", "male"), ("tauren", "female"), ("troll", "male"), ("troll", "female"), ("undead", "male"),
        ("vulpera", "male"), ("vulpera", "female")}


def facing(art, sex):
    stem = art if isinstance(art, str) else art[0]
    return "left" if (stem, sex) in LEFT else "right"


def png_name(art, sex):
    stem, suffix = (art, "") if isinstance(art, str) else art
    return "Charactercreate-races_%s-%s%s.png" % (stem, sex, suffix)


_MASKS = {}


def round_mask(img):
    """RGBA, alpha a soft circle filling the picture (1 px anti-aliased edge)."""
    from PIL import Image, ImageChops
    img = img.convert("RGBA")
    w, h = img.size
    if (w, h) not in _MASKS:
        _MASKS[(w, h)] = _circle(w, h)
    img.putalpha(ImageChops.multiply(img.getchannel("A"), _MASKS[(w, h)]))
    return img


def _circle(w, h):
    from PIL import Image
    ss = 4
    big = Image.new("L", (w * ss, h * ss), 0)
    px = big.load()
    cx, cy, r = w * ss / 2.0, h * ss / 2.0, (w * ss) / 2.0 - ss * 0.5
    for y in range(h * ss):
        dy = y + 0.5 - cy
        for x in range(w * ss):
            dx = x + 0.5 - cx
            if dx * dx + dy * dy <= r * r:
                px[x, y] = 255
    return big.resize((w, h), Image.LANCZOS)


def dxt5(img):
    """DXT5 blocks of an RGBA picture (sides multiples of 4) via Pillow's DDS writer."""
    buf = io.BytesIO()
    img.save(buf, format="DDS", pixel_format="DXT5")
    data = buf.getvalue()
    assert data[:4] == b"DDS " and data[84:88] == b"DXT5"
    n = max(1, img.size[0] // 4) * max(1, img.size[1] // 4) * 16
    return data[128:128 + n]


def blp2(img):
    """BLP2, DXT5 (compression 2, alpha depth 8, alpha type 7), every mip level down to 1x1."""
    from PIL import Image
    mips, w = [], img.size[0]
    level = img
    while True:
        side = level.size[0]
        if side >= 4:
            mips.append(dxt5(level))
        else:                       # 2x2 and 1x1: one 4x4 block of the scaled picture
            mips.append(dxt5(level.resize((4, 4), Image.LANCZOS)))
        if side == 1:
            break
        level = img.resize((side // 2, side // 2), Image.LANCZOS)
    header = struct.pack("<4sIBBBBII", b"BLP2", 1, 2, 8, 7, 1, w, w)
    offs, sizes, pos = [], [], len(header) + 16 * 4 * 2 + 256 * 4
    for m in mips:
        offs.append(pos); sizes.append(len(m)); pos += len(m)
    offs += [0] * (16 - len(offs)); sizes += [0] * (16 - len(sizes))
    return header + struct.pack("<16I", *offs) + struct.pack("<16I", *sizes) + b"\0" * 1024 + b"".join(mips)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.join(SERVER, "_dev", "race-portraits-130"))
    ap.add_argument("--release", default=os.path.join(SERVER, "5) Release"))
    ap.add_argument("--tools", default=os.path.join(SERVER, "_tools"))
    ap.add_argument("--out", default=HERE)
    ap.add_argument("--lua-only", action="store_true", help="write only TemucraftRacePortraits.lua (no BLPs)")
    a = ap.parse_args()
    if not a.lua_only:
        from PIL import Image
    sys.path.insert(0, a.tools)
    import mpqtool3
    sys.path.insert(0, HERE)
    from gen_racials import DBC
    chr_races = DBC(mpqtool3.read_file(os.path.join(a.release, "ptr", "patches", "patch-~.MPQ"), "DBFilesClient\\ChrRaces.dbc"))
    files = {chr_races.u(r, 0): chr_races.s(r, 11).upper() for r in range(chr_races.n)}
    art_dir = os.path.join(a.out, "Interface", "Glues", "CharacterCreate")
    os.makedirs(art_dir, exist_ok=True)
    done, missing, faces = [], [], {}
    for race, art in sorted(RACE_ART.items()):
        ok = True
        for sex, label in (("male", "MALE"), ("female", "FEMALE")):
            src = os.path.join(a.src, png_name(art, sex))
            if not os.path.exists(src):
                missing.append(os.path.basename(src)); ok = False
                continue
            faces["%s_%s" % (files[race], label)] = facing(art, sex)
            if a.lua_only:
                continue
            img = Image.open(src).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)
            data = blp2(round_mask(img))
            open(os.path.join(art_dir, "TemucraftRace_%s_%s.blp" % (files[race], label)), "wb").write(data)
        if ok:
            done.append(files[race])
    lua = ["-- Generated by client/gen_race_portraits.py from Ryan's 130 px retail race portraits: do not edit, run the script",
           "-- again. The races with a TemucraftRace_<file>_<MALE|FEMALE>.blp portrait (Interface\\Glues\\CharacterCreate).",
           "", "TEMUCRAFT_RACE_PORTRAIT_FILES = {"]
    lua += ['\t["%s"] = true,' % f for f in sorted(set(done))]
    lua += ["};", "",
            "-- which way each picture looks (\"left\" / \"right\", the viewer's): character create mirrors the ones that look",
            "-- away from the middle (the Alliance column faces right, the Horde column left).",
            "TEMUCRAFT_RACE_PORTRAIT_FACING = {"]
    lua += ['\t["%s"] = "%s",' % (k, faces[k]) for k in sorted(faces)]
    lua += ["};", ""]
    open(os.path.join(a.out, "Interface", "GlueXML", "TemucraftRacePortraits.lua"), "w", encoding="utf-8", newline="\n").write("\n".join(lua))
    print("%d races, %d portraits%s" % (len(set(done)), 2 * len(done), ("; missing: " + ", ".join(missing)) if missing else ""))


if __name__ == "__main__":
    main()
