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
      that is used more than once, with a label per row ("Northrend", "Broken Isles", "Kalimdor, Cataclysm" ...).
      Top-level zones come first in each list, lowest id first.

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


def era(area_id, map_id):
    if area_id >= 60000:
        return "Temucraft"
    if area_id <= 4987:   # the 3.3.5a client's own rows
        return {530: "Burning Crusade", 571: "Wrath of the Lich King"}.get(map_id, "Classic")
    for top, name in EXPANSIONS:
        if area_id <= top:
            return name
    return "Midnight"


def zone_brackets(at, mp):
    maps = {mp.u(r, 0): mp.s(r, 5) or mp.s(r, 1) for r in range(mp.n)}
    rows = {at.u(r, 0): (at.s(r, 11), at.u(r, 1), at.u(r, 2)) for r in range(at.n)}

    def top(aid):
        seen = set()
        while rows.get(aid) and rows[aid][2] and rows[aid][2] in rows and aid not in seen:
            seen.add(aid)
            aid = rows[aid][2]
        return aid

    names = collections.defaultdict(list)
    for aid, (name, _, _) in rows.items():
        if name:
            names[name].append(aid)
    groups = {}
    for name, ids in names.items():
        if len(ids) > 1:
            groups[name] = sorted(ids, key=lambda a: (rows[a][2] != 0, a))

    def label_all(top_locs):
        labels, locs = {}, {}
        for name, ids in groups.items():
            loc = {}
            for a in ids:
                t = top(a)
                # a zone: its map; a subzone: the zone it is in
                where = maps.get(rows[a][1], str(rows[a][1])) if t == a else rows[t][0]
                loc[a] = None if where == name else where
            same_zone = collections.Counter(loc.values())
            for a in ids:
                t = top(a)
                # two subzones in zones of the same name (Dalaran City): those zones' maps
                if t != a and same_zone[loc[a]] > 1 and top_locs.get(t):
                    loc[a] = top_locs[t]
                locs[a] = loc[a]
            used = collections.Counter(loc.values())
            first = collections.defaultdict(list)
            for a in ids:
                parts = [loc[a]] if loc[a] else []
                if not loc[a] or used[loc[a]] > 1:
                    parts.append(era(a, rows[a][1]))
                labels[a] = ", ".join(parts)
                first[labels[a]].append(a)
            for label, same in first.items():
                if len(same) > 1:
                    for k, a in enumerate(sorted(same)):
                        labels[a] = "%s %d" % (label, k + 1)
        return labels, locs

    _, first = label_all({})
    labels, _ = label_all({a: l for a, l in first.items() if l and top(a) == a})
    return labels, groups, rows, maps


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
    labels, groups, rows, maps = zone_brackets(dbc("patches/patch-T.MPQ", "DBFilesClient\\AreaTable.dbc"),
                                               dbc("patches/patch-X.MPQ", "DBFilesClient\\Map.dbc"))

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
    L += ["-- AreaTable names used more than once: a label per row (docs/zone-brackets.md has the list)",
          "TEMUCRAFT_ZONE_BRACKET = {"]
    for aid in sorted(labels):
        L.append("\t[%d] = %s," % (aid, lua_str(labels[aid])))
    L += ["};", "TEMUCRAFT_ZONE_BRACKET_NAMES = {"]
    for name in sorted(groups):
        L.append("\t[%s] = { %s }," % (lua_str(name), ", ".join(map(str, groups[name]))))
    L += ["};", ""]
    out = os.path.join(HERE, "Interface", "GlueXML", "TemucraftGlueData.lua")
    open(out, "w", encoding="utf-8", newline="\n").write("\n".join(L))

    md = ["# Zone brackets", "",
          "Generated by `client/gen_glue_data.py` from the release AreaTable.dbc (patch-T) and Map.dbc (patch-X). Every area",
          "name that is used by more than one AreaTable row, with the bracket label each row gets. The label is the map (or the",
          "zone a subzone belongs to); rows that would share it also get the expansion, guessed from the area id",
          "(3.3.5a ids up to 4987: Classic / Burning Crusade / Wrath by map; later ids by range; 60000+ = Temucraft).",
          "",
          "Character select only gets the zone's name from the client (GetCharacterInfo), not its id, so a character card",
          "shows the label of the first row of a name (top-level zones first, lowest id first; **bold** below). Change a",
          "label: edit the rules in the script (or ask), not the Lua file.", "",
          "| Name | Area id | Map | Parent | Label |", "|---|---|---|---|---|"]
    for name in sorted(groups, key=str.lower):
        for k, aid in enumerate(groups[name]):
            n, m, parent = rows[aid]
            lab = labels[aid]
            if k == 0:
                lab = "**" + lab + "**"
            md.append("| %s | %d | %s (%d) | %s | %s |" % (name.replace("|", "/"), aid, maps.get(m, "?"), m,
                                                         rows[parent][0] if parent in rows else "", lab))
    mdpath = os.path.join(HERE, "..", "docs", "zone-brackets.md")
    open(mdpath, "w", encoding="utf-8", newline="\n").write("\n".join(md) + "\n")
    diff = sum(1 for k in hdc if k in classic and hdc[k] != classic[k] and k[0] in race_file)
    print("%s: %d race/sex rows (%d differ in HD), %d area rows in %d names" % (out, len(classic), diff, len(labels), len(groups)))


if __name__ == "__main__":
    main()
