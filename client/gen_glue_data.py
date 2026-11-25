#!/usr/bin/env python3
"""
Generates Interface/GlueXML/TemucraftGlueData.lua (the login screens' data) and docs/zone-brackets.md from the
release DBCs. Run it again when one of those DBCs changes.

  TEMUCRAFT_CUSTOMIZE_COUNTS["<RACE>_<MALE|FEMALE>"] = { skin, face, hair style, hair colour, facial, dk skin, dk face,
      dk hair colour }: how many choices each appearance option of character create cycles through, worked out like
      the 3.3.5 client does it (CCharacterComponent::SetNextSkin/Face/HairStyle/HairColor/FacialFeature: CharSections
      rows whose flags match the create context, flag 1 = playable, 4 = death knight only, 8 = never; facial hair
      falls back to the CharacterFacialHairStyles row count). Death knights see extra skins (flag 4).
  TEMUCRAFT_ZONE_BRACKET[areaId] = label, TEMUCRAFT_ZONE_BRACKET_NAMES[name] = { areaId, ... }: every AreaTable name
      that players can find on more than one map, with a short label per row: the expansion ("Vanilla", "Legion"),
      or the map's name when two maps would share one. Names whose copies are all on one map get none. Playable maps:
      the client has their terrain (.wdt in a release MPQ), minus STAFF_ONLY_MAPS. Top-level zones come first in each
      list, lowest id first.
Sources (the copies the client loads, highest patch wins):
  CharSections / CharHairGeosets / CharacterFacialHairStyles / ChrRaces: patches/patch-5.MPQ (Classic). The HD option's
      copies in options/Character models/HD/Data/TemucraftHD/hd-common.MPQ (Temucraft\\HD\\*.dbc) are compared, and
      rows that differ go into TEMUCRAFT_CUSTOMIZE_COUNTS_HD.
  AreaTable: patches/patch-T.MPQ, Map: patches/patch-X.MPQ (checked: nothing above them carries one).

    python3 gen_glue_data.py [--release "<TemuCraft Server>/5) Release"] [--tools "<TemuCraft Server>/_tools"]
"""
import argparse, collections, os, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SERVER = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))


class DBC:
    def __init__(self, data):
        assert data[:4] == b"WDBC", "not a DBC"
        self.n, self.nf, self.rs, self.ss = struct.unpack_from("<4I", data, 4)
        self.d = data
        self.strs = 20 + self.n * self.rs

    def u(self, r, f):
        return struct.unpack_from("<I", self.d, 20 + r * self.rs + f * 4)[0]

    def s(self, r, f):
        o = self.strs + self.u(r, f)
        return self.d[o:self.d.index(b"\0", o)].decode("utf-8", "replace")


def match(flags, dk):
    # ComponentFlagsMatch, COMPONENT_SELECTION_0 / _1 (create context, class 6 = death knight)
    if dk:
        return bool(flags & 1) and bool(flags & 0x14) and not flags & 8
    return bool(flags & 1) and not flags & 0xC


def customize_counts(cs, fh):
    sec = collections.defaultdict(dict)   # (race, sex, section) -> {(variation, colour): flags}
    for r in range(cs.n):
        sec[(cs.u(r, 1), cs.u(r, 2), cs.u(r, 3))][(cs.u(r, 8), cs.u(r, 9))] = cs.u(r, 7)
    styles = collections.Counter((fh.u(r, 0), fh.u(r, 1)) for r in range(fh.n))
    out = {}
    for race, sex in sorted(set((k[0], k[1]) for k in sec) | set(styles)):
        S, F, FH, H, U = (sec.get((race, sex, b), {}) for b in range(5))
        row = {}
        for dk in (False, True):
            ok = lambda d, k: k in d and match(d[k], dk)
            nsk = max([c for (v, c) in S if v == 0], default=-1) + 1
            skins = [s for s in range(nsk) if ok(S, (0, s)) and ok(U, (0, s))]
            nf = max([v for (v, c) in F], default=-1) + 1
            face = sum(1 for f in range(nf) if any(ok(F, (f, s)) for s in skins))
            skin = sum(1 for s in skins if any(ok(F, (f, s)) for f in range(nf)))
            nh = max([v for (v, c) in H], default=-1) + 1
            hair = sum(1 for v in range(nh) if any(ok(H, k) for k in H if k[0] == v))
            colours = collections.Counter(sum(1 for k in H if k[0] == v and ok(H, k)) for v in range(nh))
            colours.pop(0, None)
            colour = colours.most_common(1)[0][0] if colours else 0
            nfh = max([v for (v, c) in FH], default=-1) + 1
            fsec = sum(1 for v in range(nfh) if any(ok(FH, k) for k in FH if k[0] == v))
            facial = fsec if fsec > 0 and fsec >= styles.get((race, sex), 0) else styles.get((race, sex), 0)
            row[dk] = (skin, face, hair, colour, facial)
        out[(race, sex)] = row[False] + (row[True][0], row[True][1], row[True][3])
    return out


EXPANSIONS = [  # AreaTable id ranges (approximate: ids were handed out in this order)
    (5735, "Cataclysm"), (6499, "Mists of Pandaria"), (7299, "Warlords of Draenor"), (8499, "Legion"),
    (10399, "Battle for Azeroth"), (13599, "Shadowlands"), (14899, "Dragonflight"), (15999, "The War Within"),
    (59999, "Midnight"),
]
STOCK_EXPANSIONS = ["Vanilla", "Burning Crusade", "Wrath of the Lich King"]

# Maps the client has terrain for but players are not taken to: the Forever maps that only have a staff .tele point
# (mod-temucraft-world/tools/forever_tele.py MAPS, no spawns, entrances or exits). City of Dalaran (2959) is not in
# here: it is in use. Take a map out of this list when it gets content.
STAFF_ONLY_MAPS = {2720, 2784, 2789, 2791, 2804, 2806, 2807, 2817, 2832, 2853, 2856, 2868, 2875, 2902, 2921, 2980,
                   2991, 2995, 2996, 2998, 2999, 3002, 3005, 3021, 3065, 3104}


def client_maps(mp, release, mpqtool3, cache_path):
    """Map ids whose World\\Maps\\<dir>\\<dir>.wdt is in one of the release's MPQs (the client can show them).
    Probing every MPQ takes a few minutes, so the answer is kept in client/out/ until an MPQ changes."""
    import glob, json
    mpqs = sorted(glob.glob(os.path.join(release, "base", "Data", "*.MPQ")) + glob.glob(os.path.join(release, "patches", "*.MPQ")))
    key = [[os.path.basename(p), os.path.getsize(p), int(os.path.getmtime(p))] for p in mpqs]
    try:
        cached = json.load(open(cache_path))
        if cached.get("key") == key:
            return set(cached["maps"])
    except (OSError, ValueError):
        pass
    found = set()
    for r in range(mp.n):
        d = mp.s(r, 1)
        name = "World\\Maps\\%s\\%s.wdt" % (d, d)
        for p in mpqs:
            try:
                if mpqtool3.read_file(p, name, True):
                    found.add(mp.u(r, 0))
                    break
            except Exception:
                continue
    os.makedirs(os.path.dirname(cache_path), exist_ok=True)
    json.dump({"key": key, "maps": sorted(found)}, open(cache_path, "w"))
    return found


def era(area_id, map_id, map_exp):
    """The expansion a row belongs to, short: "Vanilla", "Cataclysm" ..."""
    if area_id >= 60000:
        return "Temucraft"
    if area_id <= 4987:
        # the 3.3.5a client's own rows: the later of their map's expansion (Map.dbc, stock maps; arenas there say 0)
        # and their id's (rows added in Burning Crusade have ids from 3430, Eversong Woods; in Wrath, like Acherus on
        # map 0, from 4000)
        e = map_exp.get(map_id, 0) if map_id < 800 else 0
        if 530 <= map_id <= 570 or map_id in (572, 580, 585):
            e = max(e, 1)
        elif 571 <= map_id < 800:
            e = max(e, 2)
        if area_id >= 4000:
            e = max(e, 2)
        elif area_id >= 3430:
            e = max(e, 1)
        return STOCK_EXPANSIONS[min(max(e, 0), len(STOCK_EXPANSIONS) - 1)]
    for top, name in EXPANSIONS:
        if area_id <= top:
            return name
    return "Midnight"


MAP_TYPES = {1: "Dungeon", 2: "Raid", 3: "Battleground", 4: "Arena", 5: "Scenario"}


def short_labels(name, ids, rows, maps, types, map_exp):
    """The expansion of each row; rows on different maps that would share one get their map's name (or, when the map
    is called like the zone, its kind: "Battleground", "Dungeon" ...), and the map id if that ties too."""
    lab = {a: era(a, rows[a][1], map_exp) for a in ids}

    def untie(make):
        on_maps = collections.defaultdict(set)
        for a in ids:
            on_maps[lab[a]].add(rows[a][1])
        for a in ids:
            if len(on_maps[lab[a]]) > 1:
                lab[a] = make(a)

    def map_label(a):
        m = rows[a][1]
        n = maps.get(m, str(m))
        return MAP_TYPES.get(types.get(m), n) if n == name else n

    untie(map_label)
    untie(lambda a: "%s %d" % (maps.get(rows[a][1], "map"), rows[a][1]))
    return lab


def zone_brackets(at, mp, playable):
    """Labels for names that players can find on more than one map.

    Only rows on playable maps count. A name whose rows are all on one map (Elwynn Forest 12 and the later Elwynn
    rows on map 0) gets no bracket. TEMUCRAFT_ZONE_BRACKET (by area id, for the in-game map): every row of such a
    name. TEMUCRAFT_ZONE_BRACKET_NAMES (character select, which only gets the name of the character's zone): the
    names whose zones (top-level rows) are on more than one map a character can be saved on (not battlegrounds or
    arenas: logging out there puts you back outside), lowest id first."""
    maps = {mp.u(r, 0): mp.s(r, 5) or mp.s(r, 1) for r in range(mp.n)}
    types = {mp.u(r, 0): mp.u(r, 2) for r in range(mp.n)}
    map_exp = {mp.u(r, 0): mp.u(r, 63) for r in range(mp.n)} if mp.nf > 63 else {}
    rows = {at.u(r, 0): (at.s(r, 11), at.u(r, 1), at.u(r, 2)) for r in range(at.n)}
    names = collections.defaultdict(list)
    for aid, (name, m, _) in rows.items():
        if name and m in playable:
            names[name].append(aid)

    def is_zone(a):
        p = rows[a][2]
        return p == 0 or p == a or p not in rows

    groups, labels, select = {}, {}, {}
    for name, ids in names.items():
        if len(set(rows[a][1] for a in ids)) < 2:
            continue
        ids = sorted(ids, key=lambda a: (not is_zone(a), a))   # zones before subzones, lowest id first
        groups[name] = ids
        labels.update(short_labels(name, ids, rows, maps, types, map_exp))
        zones = [a for a in ids if is_zone(a) and types.get(rows[a][1]) not in (3, 4)]
        if len(set(rows[a][1] for a in zones)) > 1:
            select[name] = zones
    return labels, groups, select, rows, maps


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--release", default=os.path.join(SERVER, "5) Release"))
    ap.add_argument("--tools", default=os.path.join(SERVER, "_tools"))
    a = ap.parse_args()
    sys.path.insert(0, a.tools)
    import mpqtool3

    def dbc(archive, name):
        data = mpqtool3.read_file(os.path.join(a.release, archive), name)
        if not data:
            sys.exit("%s not in %s" % (name, archive))
        return DBC(data)

    p5 = "patches/patch-5.MPQ"
    hd = "options/Character models/HD/Data/TemucraftHD/hd-common.MPQ"
    races = dbc(p5, "DBFilesClient\\ChrRaces.dbc")
    race_file = {races.u(r, 0): races.s(r, 11).upper() for r in range(races.n)}
    classic = customize_counts(dbc(p5, "DBFilesClient\\CharSections.dbc"), dbc(p5, "DBFilesClient\\CharacterFacialHairStyles.dbc"))
    hdc = customize_counts(dbc(hd, "Temucraft\\HD\\CharSections.dbc"), dbc(hd, "Temucraft\\HD\\CharacterFacialHairStyles.dbc"))
    mapdbc = dbc("patches/patch-X.MPQ", "DBFilesClient\\Map.dbc")
    shown = client_maps(mapdbc, a.release, mpqtool3, os.path.join(HERE, "out", "client_maps.json"))
    playable = shown - STAFF_ONLY_MAPS
    labels, groups, select, rows, maps = zone_brackets(dbc("patches/patch-T.MPQ", "DBFilesClient\\AreaTable.dbc"), mapdbc, playable)

    def counts_table(var, counts, only=None):
        out = [var + " = {"]
        for (race, sex), c in sorted(counts.items()):
            if race not in race_file or (only is not None and only.get((race, sex)) == c) or not any(c[:5]):
                continue
            out.append('\t["%s_%s"] = { %s },' % (race_file[race], "FEMALE" if sex else "MALE", ", ".join(map(str, c))))
        return out + ["};"]

    L = ["-- Generated by client/gen_glue_data.py from the release DBCs: do not edit, run the script again.",
         "-- See that script for what the numbers are.", ""]
    L += counts_table("TEMUCRAFT_CUSTOMIZE_COUNTS", classic) + [""]
    L += ["-- the HD option's rows that differ (Character models: HD)"]
    L += counts_table("TEMUCRAFT_CUSTOMIZE_COUNTS_HD", hdc, classic) + [""]
    L += ["-- Names players can find on more than one map: a short label per row (docs/zone-brackets.md has the list)",
          "TEMUCRAFT_ZONE_BRACKET = {"]
    for aid in sorted(labels):
        L.append("\t[%d] = %s," % (aid, lua_str(labels[aid])))
    L += ["};", "-- character select: names whose zones are on more than one map, the row to show first",
          "TEMUCRAFT_ZONE_BRACKET_NAMES = {"]
    for name in sorted(select):
        L.append("\t[%s] = { %s }," % (lua_str(name), ", ".join(map(str, select[name]))))
    L += ["};", ""]
    out = os.path.join(HERE, "Interface", "GlueXML", "TemucraftGlueData.lua")
    open(out, "w", encoding="utf-8", newline="\n").write("\n".join(L))

    md = ["# Zone brackets", "",
          "Generated by `client/gen_glue_data.py` from the release AreaTable.dbc (patch-T) and Map.dbc (patch-X): every area",
          "name that players can find on more than one map, with the bracket label each row gets.", "",
          "Rules:", "",
          "- Only playable maps count: the client has the map's terrain (its .wdt is in a release MPQ), and it is not one of",
          "  the staff-only Forever test maps (`STAFF_ONLY_MAPS` in the script). A name whose copies are all on one map",
          "  (Elwynn Forest 12 and the later Elwynn Forest rows on map 0) gets no bracket: those are only extra rows.",
          "- The label is the row's expansion, short: Vanilla / Burning Crusade / Wrath of the Lich King for the 3.3.5a",
          "  client's own rows (by their map and id: 3430+ Burning Crusade, 4000+ Wrath), later ids by range (Cataclysm ... Midnight), 60000+ = Temucraft.",
          "- Two rows on different maps that would get the same expansion get their map's name instead.", "",
          "- If that ties too (the map is called like the zone), its kind: Battleground, Dungeon, Raid, Arena, Scenario.", "",
          "Character select only gets the name of the character's zone from the client (GetCharacterInfo), not its id. Its",
          "cards show a bracket only for names whose zones (top-level rows) are on more than one map a character can be",
          "saved on (battlegrounds and arenas do not count), with the label of the lowest such id (**bold** below). Names",
          "without a bold row get no bracket there. The by-id table (`TEMUCRAFT_ZONE_BRACKET`, every row below) is for the",
          "in-game map, which knows the area id. Change a label: edit the rules in the script (or ask), not the Lua file.", "",
          "Playable maps with more than the 3.3.5a client's own: " + ", ".join("%s (%d)" % (maps.get(m, "?"), m) for m in sorted(playable) if m >= 800) + ".", "",
          "| Name | Area id | Map | Parent | Label |", "|---|---|---|---|---|"]
    for name in sorted(groups, key=str.lower):
        for k, aid in enumerate(groups[name]):
            n, m, parent = rows[aid]
            lab = labels[aid]
            if name in select and aid == select[name][0]:
                lab = "**" + lab + "**"
            md.append("| %s | %d | %s (%d) | %s | %s |" % (name.replace("|", "/"), aid, maps.get(m, "?"), m,
                                                         rows[parent][0] if parent in rows else "", lab))
    mdpath = os.path.join(HERE, "..", "docs", "zone-brackets.md")
    open(mdpath, "w", encoding="utf-8", newline="\n").write("\n".join(md) + "\n")
    diff = sum(1 for k in hdc if k in classic and hdc[k] != classic[k] and k[0] in race_file)
    print("%s: %d race/sex rows (%d differ in HD), %d area rows in %d names (%d on character select)" % (out, len(classic), diff, len(labels), len(groups), len(select)))


if __name__ == "__main__":
    main()
