#!/usr/bin/env python3
"""
Builds Interface\\FrameXML\\Temucraft\\TemucraftCollectionsData.lua: every mount and companion pet the game has, for the
Collections window (TemucraftCollections.lua) to show the ones still to get, greyed, with where they come from.

  - which spells: SkillLineAbility.dbc rows of skill line 777 (Mounts) and 778 (Companion Pets), with their race and
    class masks, plus every spell taught by a mount or pet item (item_template class 15, subclass 5 / 2: the item's
    spell, or the spell its "learning" spell teaches, Spell.dbc effect 36);
  - the creature: Spell.dbc, the mount aura (aura 78) or the summon effect (effect 28), EffectMiscValue;
  - the model, for the preview when the client has no creature cache: creature_template_model (world DB) ->
    CreatureDisplayInfo -> CreatureModelData;
  - the source line: the name of the item that teaches it (item_template, world DB).
Names, icons and descriptions are not stored: the client reads them from its own Spell.dbc (GetSpellInfo / tooltip).

    python3 build_collections.py [--dbc folder] [--world folder]

--dbc holds the server's DBC files (Spell, SkillLineAbility, CreatureDisplayInfo, CreatureModelData);
--world the world database's base SQL dumps (item_template.sql, creature_template_model.sql).
"""
import argparse, os, re, struct

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Interface", "FrameXML", "Temucraft", "TemucraftCollectionsData.lua")
DBC = os.path.expanduser("~/mnt/TemuCraft Server/_dev/server-dbc/dbc")
WORLD = os.path.expanduser("~/mnt/Ryans World of Warcraft/Z) Source/azerothcore-wotlk/data/sql/base/db_world")
JUNK = re.compile(r"\b(test|tester|qa|dnd|ph|unused|deprecated|old|zzold|gm)\b|\[ph\]|\(dnd\)", re.I)


def dbc(path):
    d = open(path, "rb").read()
    _, n, f, rs, ss = struct.unpack("<4s4I", d[:20])
    strings = d[20 + n * rs:]
    def s(off):
        e = strings.find(b"\0", off)
        return strings[off:e].decode("utf-8", "replace")
    rows = (struct.unpack_from("<%dI" % f, d, 20 + i * rs) for i in range(n))
    return rows, s


def sql_rows(path, table):
    """(columns, rows) of a mysqldump file: column order from CREATE TABLE, values from the INSERTs."""
    text = open(path, encoding="utf-8", errors="replace").read()
    m = re.search(r"CREATE TABLE `%s` \((.*?)\n\)" % table, text, re.S)
    cols = re.findall(r"^\s*`(\w+)`", m.group(1), re.M)
    rows = []
    for ins in re.finditer(r"INSERT INTO `%s` VALUES\s*(.*?);\n" % table, text, re.S):
        v, i, n = ins.group(1), 0, len(ins.group(1))
        while i < n:
            if v[i] != "(":
                i += 1; continue
            cur, field, q, j = [], [], False, i + 1
            while j < n:
                c = v[j]
                if q:
                    if c == "\\": field.append(v[j + 1]); j += 2; continue
                    if c == "'": q = False
                    else: field.append(c)
                elif c == "'": q = True
                elif c == ",": cur.append("".join(field)); field = []
                elif c == ")": cur.append("".join(field)); break
                else: field.append(c)
                j += 1
            rows.append(cur); i = j + 1
    return cols, rows


def lua(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dbc", default=DBC)
    ap.add_argument("--world", default=WORLD)
    a = ap.parse_args()

    spells, sstr = dbc(os.path.join(a.dbc, "Spell.dbc"))
    info = {}
    for r in spells:
        info[r[0]] = {"name": sstr(r[136]), "effect": r[71:74], "aura": r[95:98], "misc": r[110:113], "trigger": r[116:119]}

    kinds = {}                       # spell -> [kind, race mask, class mask]
    rows, _ = dbc(os.path.join(a.dbc, "SkillLineAbility.dbc"))
    for r in rows:
        if r[1] in (777, 778) and r[2] in info:
            kinds[r[2]] = ["MOUNT" if r[1] == 777 else "CRITTER", r[3], r[4]]

    source = {}
    cols, items = sql_rows(os.path.join(a.world, "item_template.sql"), "item_template")
    ix = {c: i for i, c in enumerate(cols)}
    for it in items:
        if it[ix["class"]] != "15" or it[ix["subclass"]] not in ("2", "5"):
            continue
        for k in range(1, 6):
            sp = int(it[ix["spellid_%d" % k]] or 0)
            for cand in [sp] + [t for e, t in zip(info.get(sp, {}).get("effect", ()), info.get(sp, {}).get("trigger", ())) if e == 36]:
                if cand in kinds or (cand in info and it[ix["subclass"]] == "5" and 78 in info[cand]["aura"]) or \
                   (cand in info and it[ix["subclass"]] == "2" and 28 in info[cand]["effect"]):
                    if cand not in kinds:
                        kinds[cand] = ["MOUNT" if it[ix["subclass"]] == "5" else "CRITTER", 0, 0]
                    source.setdefault(cand, it[ix["name"]])

    display = {}
    cols, models = sql_rows(os.path.join(a.world, "creature_template_model.sql"), "creature_template_model")
    for r in models:
        if r[1] == "0": display[int(r[0])] = int(r[2])
    rows, s = dbc(os.path.join(a.dbc, "CreatureModelData.dbc"))
    modelpath = {r[0]: s(r[2]) for r in rows}
    rows, _ = dbc(os.path.join(a.dbc, "CreatureDisplayInfo.dbc"))
    dispmodel = {r[0]: r[1] for r in rows}

    out = {"MOUNT": [], "CRITTER": []}
    for sp, (kind, race, cls) in sorted(kinds.items()):
        i = info[sp]
        if not i["name"] or JUNK.search(i["name"]):
            continue
        creature = 0
        for e, au, mv in zip(i["effect"], i["aura"], i["misc"]):
            if (kind == "MOUNT" and au == 78) or (kind == "CRITTER" and e == 28):
                creature = mv; break
        path = modelpath.get(dispmodel.get(display.get(creature, 0), 0), "")
        path = re.sub(r"\.md[xl]$", ".m2", path, flags=re.I)
        out[kind].append("{%d,%d,%d,%d,%s,%s}" % (sp, creature, race, cls, lua(path), lua(source.get(sp, ""))))

    with open(OUT, "w", newline="\n") as f:
        f.write("-- Generated by client/collections/build_collections.py: every mount and companion pet the game has.\n")
        f.write("-- { spell, creature, race mask, class mask, model path, item that teaches it }\n")
        f.write("TEMUCRAFT_COLLECTIONS = {\n")
        for kind in ("MOUNT", "CRITTER"):
            f.write("\t%s = {\n" % kind)
            for line in out[kind]:
                f.write("\t\t%s,\n" % line)
            f.write("\t},\n")
        f.write("};\n")
    print(OUT, len(out["MOUNT"]), "mounts", len(out["CRITTER"]), "pets")


if __name__ == "__main__":
    main()
