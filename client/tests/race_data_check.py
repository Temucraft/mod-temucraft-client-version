#!/usr/bin/env python3
"""Data check for races and racials (no server): python3 -B client/tests/race_data_check.py [--dev <_dev>] [--ptr <ptr>]

Runs the data part of _dev/reference/race_info.py (its DBC loading and its has_srci / line_spells, the way the core
hands racials out; nothing of it is written) and fails when
  1. a playable race (1-30) learns no racial from its racial line for some class, so only its racial heal
     (mod-temucraft-classes RacialHeals) is left;
  2. a race x class pair (races 1-30 x the 10 classes: every race can be every class) has no row in the PTR client's
     CharBaseInfo.dbc (character create can't offer the pair);
  3. a race's racial line (RACE_LINE) has no SkillRaceClassInfo row for one of its race x class pairs (the core then
     never teaches the line to that pair).
CharBaseInfo.dbc is read from the PTR's patches (5) Release/ptr/patches, the highest one that has it: patch-~, then
patch-^, patch-T, patch-6), with StormLib (~/StormLib/b/libstorm.so or STORMLIB); without StormLib, from
_tools/glue/DBFilesClient/CharBaseInfo.dbc (the copy patch-~ is built from).
"""
import argparse, ctypes, os, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", ".."))     # F:\TemuCraft Server
PATCH_ORDER = ["patch-~.MPQ", "patch-^.MPQ", "patch-T.MPQ", "patch-6.MPQ"]
CLASS_IDS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 11]


def race_info(dev):
    """race_info.py's data part (everything before its effects section), run in its own namespace."""
    path = os.path.join(dev, "reference", "race_info.py")
    src = open(path, encoding="utf-8").read()
    cut = src.index("# ---------------------------------------------------------------- effects")
    ns = {"__file__": path, "__name__": "race_info_data"}
    src = src[:cut].replace("H = os.path.expanduser('~/mnt/TemuCraft Server')", "H = %r" % os.path.dirname(dev))
    exec(compile(src, path, "exec"), ns)
    return ns


def mpq_file(mpq, name, stormlib):
    L = ctypes.CDLL(stormlib)
    v = ctypes.c_void_p
    L.SFileOpenArchive.argtypes = [ctypes.c_char_p, ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(v)]
    L.SFileOpenFileEx.argtypes = [v, ctypes.c_char_p, ctypes.c_uint, ctypes.POINTER(v)]
    L.SFileGetFileSize.argtypes = [v, ctypes.POINTER(ctypes.c_uint)]
    L.SFileGetFileSize.restype = ctypes.c_uint
    L.SFileReadFile.argtypes = [v, ctypes.c_void_p, ctypes.c_uint, ctypes.POINTER(ctypes.c_uint), v]
    L.SFileCloseFile.argtypes = [v]
    L.SFileCloseArchive.argtypes = [v]
    h = v()
    if not L.SFileOpenArchive(mpq.encode(), 0, 0x100, ctypes.byref(h)):    # read only
        return None
    try:
        f = v()
        if not L.SFileOpenFileEx(h, name.encode(), 0, ctypes.byref(f)):
            return None
        try:
            size = L.SFileGetFileSize(f, None)
            buf = ctypes.create_string_buffer(size)
            got = ctypes.c_uint()
            L.SFileReadFile(f, buf, size, ctypes.byref(got), None)
            return buf.raw[:got.value]
        finally:
            L.SFileCloseFile(f)
    finally:
        L.SFileCloseArchive(h)


def char_base_pairs(data):
    """CharBaseInfo.dbc: (race, class) bytes per record."""
    magic, n, fields, size, _ = struct.unpack("<4s4I", data[:20])
    assert magic == b"WDBC" and fields == 2, "not CharBaseInfo.dbc"
    out = set()
    for i in range(n):
        rec = data[20 + i * size:20 + (i + 1) * size]
        race, cls = (rec[0], rec[1]) if size == 2 else struct.unpack("<II", rec[:8])
        out.add((race, cls))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dev", default=os.path.join(ROOT, "_dev"))
    ap.add_argument("--ptr", default=os.path.join(ROOT, "5) Release", "ptr"))
    ap.add_argument("--stormlib", default=os.environ.get("STORMLIB", os.path.expanduser("~/StormLib/b/libstorm.so")))
    a = ap.parse_args()
    R = race_info(a.dev)
    races, lines, heal = R["RACE"], R["RACE_LINE"], R["RACIAL_HEAL"]
    problems = []

    # 1. and 3.: every race x class pair gets its line (SkillRaceClassInfo) and something on it
    for race in range(1, 31):
        name = races.get(race, "race %d" % race)
        for cls in CLASS_IDS:
            for line in lines.get(race, []):
                if not R["has_srci"](line, race, cls):
                    problems.append("%s (%d) x %s: no SkillRaceClassInfo row for its racial line %d" % (name, race, R["CLASSES"][cls], line))
            got = [s for line in lines.get(race, []) if R["has_srci"](line, race, cls) for s in R["line_spells"](line, race, cls)]
            if not got:
                problems.append("%s (%d) x %s: learns only its racial heal %s (nothing from line %s)"
                                % (name, race, R["CLASSES"][cls], heal.get(race), lines.get(race)))
        if race not in lines:
            problems.append("%s (%d): no racial line in RACE_LINE" % (name, race))

    # 2.: CharBaseInfo of the PTR client
    data, source = None, None
    if os.path.exists(a.stormlib):
        for p in PATCH_ORDER:
            mpq = os.path.join(a.ptr, "patches", p)
            if os.path.exists(mpq):
                data = mpq_file(mpq, "DBFilesClient\\CharBaseInfo.dbc", a.stormlib)
                if data:
                    source = mpq
                    break
    if not data:
        copy = os.path.join(ROOT, "_tools", "glue", "DBFilesClient", "CharBaseInfo.dbc")
        if os.path.exists(copy):
            data, source = open(copy, "rb").read(), copy
    if not data:
        problems.append("CharBaseInfo.dbc not found (PTR patches or _tools/glue/DBFilesClient)")
    else:
        pairs = char_base_pairs(data)
        missing = [(r, c) for r in range(1, 31) for c in CLASS_IDS if (r, c) not in pairs]
        for r, c in missing:
            problems.append("%s (%d) x %s: no CharBaseInfo row in %s" % (races.get(r, r), r, R["CLASSES"][c], os.path.basename(source)))
        print("CharBaseInfo: %d pairs in %s" % (len(pairs), source))

    for p in problems:
        print("FAIL " + p)
    if problems:
        print("%d problem(s)" % len(problems))
        sys.exit(1)
    print("races and racials: all 300 race x class pairs have create data, their racial line and racials")


if __name__ == "__main__":
    main()
