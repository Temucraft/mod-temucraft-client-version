#!/usr/bin/env python3
"""
Generates Interface/GlueXML/TemucraftNameFilters.lua: the reserved and profane name lists for character create's name
check, from the client's own NamesReserved.dbc and NamesProfanity.dbc.

Sources: every locale the release ships (base/Data/enUS and locales/<xxXX>), each from its highest patch that has the
file (patch-<xxXX>-3, -2, patch-<xxXX>, then locale-<xxXX>), all merged. A row is a pattern: \\< and \\> mark the
start and end of the name, "." one letter, ".*" any letters, [abc] one of them; plain text matches anywhere.

  TEMUCRAFT_NAME_FILTERS = {
      reserved = "<word>\\n<word>...", profane = "...",   -- whole names (lower case): the server says no to these
      patterns = { { kind, "<Lua pattern>" }, ... },     -- the other rows, as Lua patterns on the lower-case name
  }

The server (AzerothCore ObjectMgr::IsReservedName / IsProfanityName, with StrictNames.Reserved / .Profanity = 1, the
defaults) loads the same DBCs, strips \\< and \\> and compares whole names (lower case); plus its reserved_name /
profanity_name tables and "every name ending in GM". So the whole-name rows are exactly what the server refuses; the
other rows (a part of the name, wildcards) are what Blizzard meant the lists for and the client marks them too.
Rows with a space (a name can't have one) or with non-ASCII inside [ ] (Lua patterns work on bytes) are left out.

    python3 gen_name_filters.py [--release "<TemuCraft Server>/5) Release"] [--tools "<TemuCraft Server>/_tools"]
                                [--server-dbc <server dbc folder>]   (compare with the server's own copies)
"""
import argparse, glob, os, re, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SERVER = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
FILES = (("reserved", "NamesReserved.dbc"), ("profane", "NamesProfanity.dbc"))


def patterns(data):
    """The pattern strings of a Names*.dbc (ID, Pattern, Language)."""
    n, nf, rs, ss = struct.unpack_from("<4I", data, 4)
    strs = 20 + n * rs
    out = []
    for r in range(n):
        o = strs + struct.unpack_from("<I", data, 20 + r * rs + 4)[0]
        out.append(data[o:data.index(b"\0", o)].decode("utf-8", "replace"))
    return out


def locale_chains(release):
    dirs = [os.path.join(release, "base", "Data", "enUS")] + sorted(glob.glob(os.path.join(release, "locales", "*")))
    for d in dirs:
        loc = os.path.basename(d)
        chain = ["patch-%s-3.MPQ" % loc, "patch-%s-2.MPQ" % loc, "patch-%s.MPQ" % loc, "lichking-locale-%s.MPQ" % loc,
                 "expansion-locale-%s.MPQ" % loc, "locale-%s.MPQ" % loc]
        yield loc, [os.path.join(d, c) for c in chain if os.path.exists(os.path.join(d, c))]


LUA_MAGIC = set("^$()%.[]*+-?")


def to_lua(pat):
    """A Names*.dbc pattern -> (kind, value): ("exact", word) for a whole name, ("pattern", lua) otherwise, or None
    when it can never match a name."""
    p = pat.strip().lower()
    if not p or " " in p:
        return None
    start = p.startswith("\\<")
    end = p.endswith("\\>")
    body = p[2 if start else 0:len(p) - 2 if end else len(p)]
    body = body.replace("\\<", "").replace("\\>", "")
    if not body:
        return None
    if start and end and not re.search(r"[\.\[\]\*\\]", body):
        return ("exact", body)
    out, i = [], 0
    while i < len(body):
        c = body[i]
        if c == "\\" and i + 1 < len(body):
            nxt = body[i + 1]
            out.append("%" + nxt if nxt in LUA_MAGIC else nxt)
            i += 2
            continue
        if c == ".":
            if body[i + 1:i + 2] == "*":
                out.append(".*")
                i += 2
            else:
                out.append(".")
                i += 1
            continue
        if c == "[":
            j = body.find("]", i + 1)
            if j < 0:
                return None
            inner = body[i + 1:j]
            if not inner or any(ord(ch) > 127 for ch in inner):
                return None
            out.append("[" + inner.replace("%", "%%") + "]")   # a-z ranges mean the same in Lua
            i = j + 1
            continue
        if c == "*":       # a bare * (repeat the last): rare, as ".*"
            out.append(".*")
            i += 1
            continue
        out.append("%" + c if c in LUA_MAGIC else c)
        i += 1
    lua = ("^" if start else "") + "".join(out) + ("$" if end else "")
    return ("pattern", lua)


def collect(release, tools, server_dbc=None):
    sys.path.insert(0, tools)
    import mpqtool3
    words = {"reserved": set(), "profane": set()}
    pats = {"reserved": set(), "profane": set()}
    raw = {"reserved": set(), "profane": set()}
    seen = []
    for loc, chain in locale_chains(release):
        for kind, name in FILES:
            for mpq in chain:
                try:
                    data = mpqtool3.read_file(mpq, "DBFilesClient\\" + name)
                except Exception:
                    data = None
                if data:
                    seen.append("%s %s: %s" % (loc, name, os.path.basename(mpq)))
                    raw[kind].update(patterns(data))
                    break
    skipped = 0
    for kind in raw:
        for p in raw[kind]:
            r = to_lua(p)
            if r is None:
                skipped += 1
            elif r[0] == "exact":
                words[kind].add(r[1])
            else:
                pats[kind].add(r[1])
    same = None
    if server_dbc and os.path.isdir(server_dbc):
        same = {}
        for kind, name in FILES:
            p = os.path.join(server_dbc, name)
            if os.path.exists(p):
                server = set(patterns(open(p, "rb").read()))
                same[name] = (len(server), len(server - raw[kind]), len(raw[kind] - server))
    return words, pats, skipped, seen, same


def long_string(s):
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + s + "]" + eq + "]"


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_lua(words, pats, path):
    L = ["-- Generated by client/gen_name_filters.py from the client's NamesReserved.dbc / NamesProfanity.dbc (every",
         "-- locale): do not edit, run the script again. Character create's name check uses it (TemucraftCharCreate.lua",
         "-- Logic.NameFilter); the UI never shows a word from it.", "",
         "TEMUCRAFT_NAME_FILTERS = {"]
    for kind in ("reserved", "profane"):
        L.append("\t%s = %s," % (kind, long_string("\n".join(sorted(words[kind])))))
    L.append("\tpatterns = {")
    for kind in ("reserved", "profane"):
        for p in sorted(pats[kind]):
            L.append("\t\t{ %s, %s }," % (lua_str(kind), lua_str(p)))
    L += ["\t},", "};", ""]
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(L))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--release", default=os.path.join(SERVER, "5) Release"))
    ap.add_argument("--tools", default=os.path.join(SERVER, "_tools"))
    ap.add_argument("--server-dbc", default=os.path.join(SERVER, "_dev", "server-dbc", "dbc"))
    ap.add_argument("--out", default=os.path.join(HERE, "Interface", "GlueXML", "TemucraftNameFilters.lua"))
    a = ap.parse_args()
    words, pats, skipped, seen, same = collect(a.release, a.tools, a.server_dbc)
    write_lua(words, pats, a.out)
    print("%s: %d reserved + %d profane whole names, %d + %d patterns, %d rows left out" % (
        a.out, len(words["reserved"]), len(words["profane"]), len(pats["reserved"]), len(pats["profane"]), skipped))
    print("sources: " + "; ".join(seen))
    if same:
        for name, (n, only_server, only_client) in same.items():
            print("server %s: %d rows, %d only on the server, %d only in the client" % (name, n, only_server, only_client))


if __name__ == "__main__":
    main()
