#!/usr/bin/env python3
"""
Builds the Temucraft interface patch: Data/<locale>/patch-<locale>-T.MPQ.

It carries
  - Interface\\GlueXML\\TemucraftVersion.lua: "Temucraft <version>" on the login screen,
  - Interface\\FrameXML\\Temucraft\\*.lua: the core (sends the version to the server, shows "out of date") and the
    module windows (mission table / companions, wardrobe, vanity), loaded by FrameXML itself, so they always run like Blizzard's UI,
  - FrameXML.toc / GlueXML.toc: copies of the client's own lists (base/) with those files added.

The version comes from VERSION. Put the MPQ in the launcher's locales/<locale>/ folder, and the same version in
client-version.txt and in mod-temucraft-client-version.conf (Temucraft.ClientVersion.Required).

    python3 build_mpq.py [--locale enUS] [--out folder] [--stormlib path/to/libstorm.so|StormLib.dll]

base/*.toc must be the highest-priority copies of the client you ship (here: FrameXML.toc from patch-enUS-3.MPQ,
GlueXML.toc from patch-enUS-C.MPQ). If another patch changes them later, refresh base/.
"""
import argparse, ctypes, os, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
FRAME_FILES = ["Temucraft\\TemucraftCore.lua", "Temucraft\\TemucraftMissions.lua", "Temucraft\\TemucraftDisguise.lua",
               "Temucraft\\TemucraftAutoLearn.lua", "Temucraft\\TemucraftHeritage.lua",
               "Temucraft\\TemucraftSpellTabs.lua", "Temucraft\\TemucraftTankRoles.lua",
               "Temucraft\\TemucraftTokenPreview.lua", "Temucraft\\TemucraftCostumes.lua",
               "Temucraft\\TemucraftVanity.lua"]
GLUE_FILES = ["TemucraftVersion.lua"]


def insert_before(text, marker, lines):
    rows = text.replace("\r\n", "\n").split("\n")
    rows = [r for r in rows if r.strip() not in lines]
    at = next((i for i, r in enumerate(rows) if r.strip().lower().startswith(marker)), len(rows))
    return "\r\n".join(rows[:at] + lines + rows[at:])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--locale", default="enUS")
    ap.add_argument("--out", default=os.path.join(HERE, "out"))
    ap.add_argument("--stormlib", default=os.environ.get("STORMLIB", os.path.expanduser("~/StormLib/b/libstorm.so")))
    a = ap.parse_args()
    version = open(os.path.join(HERE, "VERSION")).read().strip()

    files = {}
    def add(name, data): files[name] = data if isinstance(data, bytes) else data.encode("utf-8")
    add("Interface\\FrameXML\\FrameXML.toc",
        insert_before(open(os.path.join(HERE, "base", "FrameXML.toc"), encoding="latin-1").read(), "## add new modules above", FRAME_FILES))
    add("Interface\\GlueXML\\GlueXML.toc",
        insert_before(open(os.path.join(HERE, "base", "GlueXML.toc"), encoding="latin-1").read(), "## this always runs last", GLUE_FILES))
    for f in FRAME_FILES:
        add("Interface\\FrameXML\\" + f, open(os.path.join(HERE, "Interface", "FrameXML", *f.split("\\"))).read().replace("@VERSION@", version))
    for f in GLUE_FILES:
        add("Interface\\GlueXML\\" + f, open(os.path.join(HERE, "Interface", "GlueXML", f)).read().replace("@VERSION@", version))

    L = ctypes.CDLL(a.stormlib); v = ctypes.c_void_p
    L.SFileCreateArchive.argtypes = [ctypes.c_char_p, ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(v)]
    L.SFileAddFileEx.argtypes = [v, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint]
    L.SFileCloseArchive.argtypes = [v]
    os.makedirs(os.path.join(a.out, a.locale), exist_ok=True)
    mpq = os.path.join(a.out, a.locale, f"patch-{a.locale}-T.MPQ")
    if os.path.exists(mpq): os.remove(mpq)
    h = v()
    # MPQ v1 with a listfile and attributes, like the client's own patches
    if not L.SFileCreateArchive(mpq.encode(), 0x00100000 | 0x00200000, 64, ctypes.byref(h)):
        sys.exit("could not create " + mpq)
    with tempfile.TemporaryDirectory() as tmp:
        for name, data in files.items():
            p = os.path.join(tmp, name.replace("\\", "_"))
            open(p, "wb").write(data)
            if not L.SFileAddFileEx(h, p.encode(), name.encode(), 0x80000200, 0x02, 0x02):
                sys.exit("could not add " + name)
    L.SFileCloseArchive(h)
    print(f"{mpq}: {len(files)} files, Temucraft {version}")


if __name__ == "__main__":
    main()
