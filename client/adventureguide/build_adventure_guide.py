#!/usr/bin/env python3
"""
Builds Interface\\FrameXML\\Temucraft\\TemucraftAdventureGuideData.lua: the data of the Adventure Guide window
(TemucraftAdventureGuide.lua), the 3.3.5 client's stand-in for retail's Encounter Journal. 3.3.5 has no journal
DBCs, so everything is read offline from the server's DBC files and world database SQL:

  - instances: Map.dbc (name, dungeon or raid, expansion, players), LFGDungeons.dbc (level range, recommended level,
    the LFG icon / background names, heroic levels), the entrance's zone (Map.dbc corpse point, else the area trigger
    that teleports into the map, looked up in WorldMapArea.dbc / AreaTable.dbc);
  - bosses: DungeonEncounter.dbc (name, order) and instance_encounters (the creature that gives the kill credit);
    for maps with no DungeonEncounter rows (Temucraft's Cataclysm / Mists / Lost Lands instances) the creatures
    spawned on the map with a boss_ script or boss rank;
  - abilities: the boss's spells from creature_template_spell, its SmartAI casts (smart_scripts action 11) and the
    SPELL_ enums of its C++ script (core src/server/scripts and mod-temucraft-instances), kept when Spell.dbc has them
    and they aren't visuals / triggers / credits; the client shows their names, icons and tooltips itself;
  - loot: the boss's creature_loot_template (and its difficulty entries) with references followed, items of quality
    2 (green) and up, quest items left out; references shared by more than 25 creatures are world drops and are left
    out (retail's journal lists a boss's own loot);
  - items: name, quality, slot, class / subclass and item level, so the list reads before the client has the item
    (tooltips need it in the client's cache: the window asks the server, addon message TAG);
  - zones for Suggested Content: LFGDungeons.dbc rows of type 4 (name, level range, faction);
  - texts: client/adventureguide/descriptions.tsv (hand written: instance overviews, boss descriptions, zone fixes).

    python3 build_adventure_guide.py [--dbc folder] [--world folder] [--extra file.sql ...] [--scripts folder ...]

--world is a folder of the world database's SQL dumps (the core's data/sql/base/db_world, or a mysqldump of the live
world database, one file per table: see the README). --extra adds module SQL on top (INSERTs with or without a
column list, ScriptName UPDATEs); by default mod-temucraft-world's and mod-temucraft-instances' SQL.
"""
import argparse, glob, os, re, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Interface", "FrameXML", "Temucraft", "TemucraftAdventureGuideData.lua")
TEXTS = os.path.join(HERE, "descriptions.tsv")
SERVER = os.path.expanduser("~/mnt/TemuCraft Server")
DBC = os.path.join(SERVER, "_dev", "server-dbc", "dbc")
WORLD = os.path.join(SERVER, "1) Source", "data", "sql", "base", "db_world")
MODULES = os.path.join(SERVER, "1) Source", "modules")
EXTRA = [os.path.join(MODULES, "mod-temucraft-world", "data", "sql", "db-world", "base", "*.sql"),
         os.path.join(MODULES, "mod-temucraft-instances", "data", "sql", "db-world", "base", "*.sql")]
SCRIPTS = [os.path.join(SERVER, "1) Source", "src", "server", "scripts", d) for d in ("EasternKingdoms", "Kalimdor", "Outland", "Northrend")] \
    + [os.path.join(MODULES, "mod-temucraft-instances", "src")]

# stock 3.3.5 art that exists in the client (Interface\LFGFrame\UI-LFG-BACKGROUND-<name>, LFGIcon-<name>)
BACKGROUNDS = ["AQRuins", "AQTemple", "Ahnkalet", "ArgentDungeon", "ArgentRaid", "Auchindoun", "AzjolNerub", "BlackTemple",
    "BlackfathomDeeps", "BlackrockDepths", "BlackrockSpire", "BlackwingLair", "CavernsOfTime", "ChamberOfAspects", "CoilFang",
    "Deadmines", "DireMaul", "DrakTharon", "Gnomeregan", "GruulsLair", "Gundrak", "HallsofLightning", "HallsofReflection",
    "HallsofStone", "HellfireCitadel", "HellfireCitadelRaid", "HyjalPast", "IcecrownCitadel", "Karazhan", "MagistersTerrace",
    "Malygos", "Maraudon", "MoltenCore", "Naxxramas", "Outland", "PitofSaron", "RagefireChasm", "RazorfenDowns", "RazorfenKraul",
    "ScarletMonastery", "Scholomance", "ShadowFangKeep", "StormwindStockades", "Stratholme", "SunkenTemple", "Sunwell",
    "TempestKeep", "TheForgeofSouls", "TheNexus", "TheOculus", "TheVioletHold", "Uldaman", "Ulduar", "Utgarde", "UtgardePinnacle",
    "VaultOfArchavon", "WailingCaverns", "ZulAman", "ZulFarak", "ZulGurub"]
ICONS = ["AQRUINS", "AQTEMPLE", "AUCHINDOUN", "BLACKFATHOMDEEPS", "BLACKROCKDEPTHS", "BLACKROCKSPIRE", "BLACKTEMPLE", "BLACKWINGLAIR",
    "CAVERNSOFTIME", "COILFANG", "DEADMINES", "DIREMAUL", "GNOMEREGAN", "GRUULSLAIR", "HELLFIRECITADEL", "HELLFIRECITADEL5MAN",
    "HELLFIRECITADELRAID", "HYJALPAST", "KARAZHAN", "MAGISTERSTERRACE", "MARAUDON", "MOLTENCORE", "NAXXRAMAS", "RAGEFIRECHASM",
    "RAZORFENDOWNS", "RAZORFENKRAUL", "SCARLETMONASTERY", "SCHOLOMANCE", "SERPENTSHRINECAVERN", "SHADOWFANGKEEP", "STORMWINDSTOCKADES",
    "STRATHOLME", "SUNKENTEMPLE", "SUNWELL", "TEMPESTKEEP", "ULDAMAN", "WAILINGCAVERNS", "ZULAMAN", "ZULFARAK", "ZULGURUB",
    "AHNKAHET", "ARGENTDUNGEON", "ARGENTRAID", "AZJOLNERUB", "CHAMBEROFASPECTS", "DRAKTHARON", "GUNDRAK", "HALLSOFLIGHTNING",
    "HALLSOFSTONE", "MALYGOS", "OLDSTRATHOLME", "THENEXUS", "THEOCULUS", "THEVIOLETHOLD", "ULDUAR", "ULDUARRAID", "UTGARDE",
    "UTGARDEPINNACLE", "VAULTOFARCHAVON", "HALLSOFREFLECTION", "ICECROWNCITADEL", "ONYXIAENCOUNTER", "PITOFSARON",
    "THEFORGEOFSOULS", "RUBYSANCTUM"]
BG_BY_ICON = {"AHNKAHET": "Ahnkalet", "HELLFIRECITADEL5MAN": "HellfireCitadel", "SERPENTSHRINECAVERN": "CoilFang",
    "OLDSTRATHOLME": "CavernsOfTime", "ULDUARRAID": "Ulduar", "ONYXIAENCOUNTER": "BlackwingLair"}
WORLD_DROP_USERS = 25       # a reference used by more creatures than this is a world drop
MIN_QUALITY = 2
MAX_SPELLS = 10
SPELL_JUNK = re.compile(r"visual|dummy|trigger|credit|cosmetic|teleport|despawn|\bclear\b|kill ?credit|achievement|"
                        r"\bsound\b|emote|test|\bdnd\b|\(dnd\)|bunny|quest|\bph\b|state|\bstun self\b|self stun|"
                        r"\bspawn\b|spawn effect|\breset\b|aggro|\bevade\b|transform(ation)? visual|instakill self|suicide|"
                        r"\bdeath\b$|permanent feign|feign death|root self|\bcopy\b|\bmount\b|\bdismount\b", re.I)
ENUM_JUNK = re.compile(r"VISUAL|DUMMY|TRIGGER|CREDIT|COSMETIC|TELEPORT|DESPAWN|CLEAR|ACHIEV|SOUND|EMOTE|KILL_|_KILL|"
                       r"SUMMON_.*_VISUAL|BUNNY|QUEST|STATE|SPAWN|RESET|EVADE|SUICIDE|INSTAKILL|FEIGN|ROOT_SELF|"
                       r"_DND|PORTAL_EFFECT|SELF_STUN|STUN_SELF|COPY|MOUNT|_AURA_VIS|_FX", re.I)
HIDDEN = 0x80               # SPELL_ATTR0_DO_NOT_DISPLAY


# --- DBC ----------------------------------------------------------------------------------------------------------
def dbc(path):
    d = open(path, "rb").read()
    _, n, f, rs, ss = struct.unpack("<4s4I", d[:20])
    strings = d[20 + n * rs:]
    def s(off):
        e = strings.find(b"\0", off)
        return strings[off:e].decode("utf-8", "replace")
    rows = [struct.unpack_from("<%dI" % f, d, 20 + i * rs) for i in range(n)]
    return rows, s


def flt(u):
    return struct.unpack("<f", struct.pack("<I", u))[0]


def i32(u):
    return u - (1 << 32) if u >= (1 << 31) else u


# --- SQL ----------------------------------------------------------------------------------------------------------
TOKEN = re.compile(r"\s*(?:'((?:[^'\\]|\\.|'')*)'|(\()|(\))|(,)|(;)|([^,()';\s]+))", re.S)
UNESC = re.compile(r"\\(.)", re.S)
UNESC_MAP = {"n": "\n", "r": "", "t": "\t", "0": ""}


def unescape(s):
    return UNESC.sub(lambda m: UNESC_MAP.get(m.group(1), m.group(1)), s)


def columns_of(text, table):
    m = re.search(r"CREATE TABLE (?:IF NOT EXISTS )?`%s` \((.*?)\n\)" % table, text, re.S)
    return re.findall(r"^\s*`(\w+)`", m.group(1), re.M) if m else None


class Tables:
    """Rows of the tables we read, as dicts of the wanted columns (strings), from mysqldump files and module SQL."""

    def __init__(self, wanted):
        self.wanted = wanted          # table -> set of columns
        self.cols = {}                # table -> column order of the base dump
        self.rows = {t: [] for t in wanted}
        self.scriptnames = {}         # entry -> ScriptName (UPDATE statements)
        self.base_counts = {}         # table -> rows read from the base dump (the rest come from modules)

    def read(self, path, base=False):
        text = open(path, encoding="utf-8", errors="replace").read()
        vars_ = {}
        for m in re.finditer(r"SET\s+@(\w+)\s*:?=\s*(-?\d+)\s*;", text):
            vars_[m.group(1).upper()] = int(m.group(2))
        for t in self.wanted:
            if base:
                c = columns_of(text, t)
                if c: self.cols[t] = c
            for m in re.finditer(r"(?:INSERT|REPLACE)(?:\s+IGNORE)?\s+INTO\s+`?%s`?\s*(\(([^)]*)\))?\s*VALUES" % t, text, re.I):
                cols = [c.strip(" `\n\r\t") for c in m.group(2).split(",")] if m.group(2) else self.cols.get(t)
                if not cols:
                    continue
                self._values(text, m.end(), t, cols, vars_)
        for m in re.finditer(r"UPDATE\s+`?creature_template`?\s+SET\s+`?ScriptName`?\s*=\s*'([^']*)'\s+WHERE\s+`?entry`?\s*(?:=\s*(\d+)|IN\s*\(([^)]*)\))", text, re.I):
            for e in ([m.group(2)] if m.group(2) else re.findall(r"\d+", m.group(3))):
                self.scriptnames[int(e)] = m.group(1)

    def _values(self, text, pos, table, cols, vars_):
        keep = [(i, c) for i, c in enumerate(cols) if c in self.wanted[table]]
        out = self.rows[table]
        cur, depth = None, 0
        for m in TOKEN.finditer(text, pos):
            q, op, cl, comma, semi, bare = m.groups()
            if op:
                depth += 1
                if depth == 1: cur = []
            elif cl:
                depth -= 1
                if depth == 0 and cur is not None:
                    out.append({c: cur[i] if i < len(cur) else "" for i, c in keep})
                    cur = None
            elif semi and depth == 0:
                return
            elif q is not None:
                if cur is not None:
                    if "''" in q: q = q.replace("''", "'")
                    cur.append(unescape(q) if "\\" in q else q)
            elif bare is not None and cur is not None:
                if "@" in bare:
                    expr = re.sub(r"@(\w+)", lambda v: str(vars_.get(v.group(1).upper(), 0)), bare)
                    try: bare = str(int(eval(expr, {"__builtins__": {}})))
                    except Exception: pass
                cur.append("" if bare == "NULL" else bare)


def num(s, default=0):
    try: return int(float(s))
    except (TypeError, ValueError): return default


def lua(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "") + '"'


# --- texts ----------------------------------------------------------------------------------------------------------
def read_texts(path):
    out = {"map": {}, "npc": {}, "zone": {}, "name": {}, "level": {}}
    if not os.path.exists(path):
        return out
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) >= 3 and parts[0] in out:
            out[parts[0]][int(parts[1])] = parts[2]
    return out


# --- C++ boss scripts: SPELL_ enums per script name -------------------------------------------------------------------
def script_spells(folders, wanted_names):
    found = {}
    files = []
    for f in folders:
        for root, _, names in os.walk(f):
            files += [os.path.join(root, n) for n in names if n.endswith((".cpp", ".h"))]
    reg = re.compile(r"(?:struct|class)\s+(boss_\w+|npc_\w+)\b|Register\w*AI\w*\(\s*(boss_\w+|npc_\w+)|new\s+(boss_\w+|npc_\w+)\s*\(|\"(boss_\w+|npc_\w+)\"")
    spell = re.compile(r"\b(SPELL_\w+)\s*=\s*(\d+)")
    for path in files:
        text = open(path, encoding="utf-8", errors="replace").read()
        names = set(n for m in reg.finditer(text) for n in m.groups() if n)
        mine = names & wanted_names
        if not mine:
            continue
        bosses = [n for n in names if n.startswith("boss_")]
        spells = [(m.group(1), int(m.group(2))) for m in spell.finditer(text)]
        if len(bosses) <= 2:
            for n in mine: found.setdefault(n, []).extend(spells)
        else:
            # many bosses in one file: only the enum block right before each boss's own struct
            for n in mine:
                at = re.search(r"(?:struct|class)\s+%s\b" % n, text)
                if not at: continue
                prev = max(text.rfind("struct boss_", 0, at.start()), text.rfind("class boss_", 0, at.start()))
                block = text[max(prev, 0):at.start()]
                found.setdefault(n, []).extend((m.group(1), int(m.group(2))) for m in spell.finditer(block))
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dbc", default=DBC)
    ap.add_argument("--world", default=WORLD)
    ap.add_argument("--extra", nargs="*", default=None, help="module SQL files (globs) applied over --world")
    ap.add_argument("--scripts", nargs="*", default=SCRIPTS)
    ap.add_argument("--texts", default=TEXTS)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--only", default="", help="comma list of map ids (a small sample)")
    a = ap.parse_args()
    only = set(int(x) for x in a.only.split(",") if x.strip())

    texts = read_texts(a.texts)
    # DBCs
    maps, ms = dbc(os.path.join(a.dbc, "Map.dbc"))
    mapinfo = {}
    for r in maps:
        mapinfo[r[0]] = {"dir": ms(r[1]), "type": r[2], "name": ms(r[5]), "corpse": (i32(r[59]), flt(r[60]), flt(r[61])),
                         "exp": r[63], "players": r[65]}
    lfg, ls = dbc(os.path.join(a.dbc, "LFGDungeons.dbc"))
    enc, es = dbc(os.path.join(a.dbc, "DungeonEncounter.dbc"))
    area, ars = dbc(os.path.join(a.dbc, "AreaTable.dbc"))
    areaname = {r[0]: ars(r[11]) for r in area}
    wma, _ = dbc(os.path.join(a.dbc, "WorldMapArea.dbc"))
    zones_rect = [(r[1], r[2], flt(r[4]), flt(r[5]), flt(r[6]), flt(r[7])) for r in wma if r[2]]
    triggers = {}
    if os.path.exists(os.path.join(a.dbc, "AreaTrigger.dbc")):
        at, _ = dbc(os.path.join(a.dbc, "AreaTrigger.dbc"))
        triggers = {r[0]: (r[1], flt(r[2]), flt(r[3])) for r in at}
    mapdiff = {}                  # map -> {difficulty: (players, heroic)}
    md, mds = dbc(os.path.join(a.dbc, "MapDifficulty.dbc"))
    for r in md:
        mapdiff.setdefault(r[1], {})[r[2]] = (r[21], 1 if "HEROIC" in mds(r[22]) else 0)
    spells, ss = dbc(os.path.join(a.dbc, "Spell.dbc"))
    spellinfo = {r[0]: (ss(r[136]), ss(r[170]), r[4]) for r in spells}

    def zone_at(cont, x, y):
        best = None
        for m, aid, left, right, top, bottom in zones_rect:
            if m == cont and right <= y <= left and bottom <= x <= top:
                size = (left - right) * (top - bottom)
                if best is None or size < best[0]: best = (size, aid)
        return areaname.get(best[1], "") if best else ""

    # world database
    want = {
        "creature_template": {"entry", "difficulty_entry_1", "difficulty_entry_2", "difficulty_entry_3", "name", "subname",
                              "minlevel", "maxlevel", "rank", "type", "lootid", "ScriptName", "AIName", "flags_extra", "unit_flags"},
        "creature_loot_template": {"Entry", "Item", "Reference"},
        "reference_loot_template": {"Entry", "Item", "Reference"},
        "item_template": {"entry", "class", "subclass", "name", "Quality", "InventoryType", "ItemLevel"},
        "instance_encounters": {"entry", "creditType", "creditEntry"},
        "creature_template_spell": {"CreatureID", "Spell"},
        "smart_scripts": {"entryorguid", "source_type", "action_type", "action_param1"},
        "dungeon_access_template": {"map_id", "difficulty", "min_level", "max_level"},
        "areatrigger_teleport": {"ID", "target_map"},
        "creature": {"id", "id1", "map", "spawnMask"},
        "map_dbc": {"ID", "InstanceType", "MapName_Lang_enUS", "ExpansionID", "MaxPlayers"},
    }
    T = Tables(want)
    for t in want:
        p = os.path.join(a.world, t + ".sql")
        if os.path.exists(p):
            T.read(p, base=True)
            T.base_counts[t] = len(T.rows[t])
            print("read", t, len(T.rows[t]), file=sys.stderr)
    extra = a.extra if a.extra is not None else EXTRA
    for g in extra:
        for p in sorted(glob.glob(g)):
            n0 = {t: len(v) for t, v in T.rows.items()}
            T.read(p)
            added = {t: len(v) - n0[t] for t, v in T.rows.items() if len(v) - n0[t]}
            print("extra", os.path.basename(p), added, len(T.scriptnames), file=sys.stderr)

    # later rows (modules) win
    ct = {}
    for r in T.rows["creature_template"]:
        ct[num(r["entry"])] = r
    for e, sn in T.scriptnames.items():
        if e in ct: ct[e]["ScriptName"] = sn
    items = {}
    for r in T.rows["item_template"]:
        items[num(r["entry"])] = r
    for r in T.rows["map_dbc"]:
        mid = num(r["ID"])
        mi = mapinfo.setdefault(mid, {"dir": "", "corpse": (-1, 0, 0)})
        mi.update({"type": num(r.get("InstanceType")), "name": r.get("MapName_Lang_enUS") or mi.get("name", ""),
                   "exp": num(r.get("ExpansionID")), "players": num(r.get("MaxPlayers"))})
    loot, refs = {}, {}
    for r in T.rows["creature_loot_template"]:
        loot.setdefault(num(r["Entry"]), []).append((num(r["Item"]), num(r["Reference"])))
    for r in T.rows["reference_loot_template"]:
        refs.setdefault(num(r["Entry"]), []).append((num(r["Item"]), num(r["Reference"])))
    ref_users = {}
    for e, rows in loot.items():
        for item, ref in rows:
            if ref: ref_users.setdefault(ref, set()).add(e)
    credit = {num(r["entry"]): num(r["creditEntry"]) for r in T.rows["instance_encounters"] if num(r["creditType"]) == 0}
    tspells = {}
    for r in T.rows["creature_template_spell"]:
        tspells.setdefault(num(r["CreatureID"]), []).append(num(r["Spell"]))
    sai = {}
    for r in T.rows["smart_scripts"]:
        if num(r["source_type"]) == 0 and num(r["action_type"]) == 11:
            sai.setdefault(num(r["entryorguid"]), []).append(num(r["action_param1"]))
    access = {}
    for r in T.rows["dungeon_access_template"]:
        access[(num(r["map_id"]), num(r["difficulty"]))] = (num(r["min_level"]), num(r["max_level"]))
    tele = {}
    for r in T.rows["areatrigger_teleport"]:
        tele.setdefault(num(r["target_map"]), []).append(num(r["ID"]))
    spawns, module_spawns = {}, {}
    nbase = T.base_counts.get("creature", 0)
    for n, r in enumerate(T.rows["creature"]):
        cid = num(r.get("id1") or r.get("id"))
        spawns.setdefault(num(r["map"]), set()).add(cid)
        if n >= nbase: module_spawns.setdefault(num(r["map"]), set()).add(cid)

    def expand(entry, table, out, depth=0, level=0):
        if depth > 6: return
        for item, ref in table.get(entry, []):
            if ref:
                if depth == 0 and table is loot and len(ref_users.get(ref, ())) > WORLD_DROP_USERS: continue
                expand(ref, refs, out, depth + 1, level)
                continue
            it = items.get(item)
            if not it or num(it["Quality"]) < MIN_QUALITY or num(it["class"]) == 12 or item in out:
                continue
            # world drops that slipped in through a small reference: far below the boss's level
            if level >= 30 and num(it["class"]) in (2, 4) and num(it["ItemLevel"]) < level - 22:
                continue
            out.append(item)

    def boss_loot(npc, diffs):
        out = {}
        t = ct.get(npc)
        if not t: return out
        for d in diffs:
            src = t if d == 0 else ct.get(num(t.get("difficulty_entry_%d" % d)))
            if not src or not num(src.get("lootid")): continue
            lst = []
            expand(num(src["lootid"]), loot, lst, 0, num(src.get("maxlevel")))
            if lst: out[d] = lst
        return out

    # bosses' C++ scripts
    wanted_scripts = set(r.get("ScriptName", "") for r in ct.values() if r.get("ScriptName", "").startswith(("boss_", "npc_")))
    cpp = script_spells([s for s in a.scripts if os.path.isdir(s)], wanted_scripts)

    def boss_spells(npc):
        t = ct.get(npc, {})
        cand = list(tspells.get(npc, [])) + list(sai.get(npc, []))
        for enum, sid in cpp.get(t.get("ScriptName", ""), []):
            if not ENUM_JUNK.search(enum): cand.append(sid)
        out, names = [], set()
        for sid in cand:
            info = spellinfo.get(sid)
            if not info or not info[0] or info[2] & HIDDEN or SPELL_JUNK.search(info[0]): continue
            key = info[0].lower()
            if key in names:
                continue
            names.add(key)
            out.append(sid)
        # the ones with a description first, in their order
        out.sort(key=lambda s: 0 if spellinfo[s][1] else 1)
        return out[:MAX_SPELLS]

    def boss_desc(npc):
        if npc in texts["npc"]: return texts["npc"][npc]
        return ""

    # instances from LFGDungeons (levels, icons) and Map.dbc
    insts = {}
    zones = []
    for r in lfg:
        name, mid, typ, diff = ls(r[1]), i32(r[23]), r[26], r[24]
        if typ == 4 and mid < 0:
            zones.append((name, r[18], r[19], i32(r[27]), r[29]))
            continue
        if typ not in (1, 2) or mid < 0 or mid not in mapinfo:
            continue
        if r[25] & 4:             # LFG_FLAG_SEASONAL: holiday bosses
            continue
        i = insts.setdefault(mid, {"map": mid, "lfg": []})
        i["lfg"].append((r[18], r[19], r[20], r[21], r[22], ls(r[28]), diff))
    bosses_by_map = {}
    for r in sorted(enc, key=lambda r: (r[1], r[3], r[2])):
        mid, diff, idx = r[1], r[2], r[3]
        if mid not in mapinfo: continue
        b = bosses_by_map.setdefault(mid, {})
        bname = es(r[5]).strip()
        boss = b.setdefault(bname, {"name": bname, "npc": 0, "diffs": set(), "order": idx})
        boss["order"] = min(boss["order"], idx)
        boss["diffs"].add(diff)
        if not boss["npc"] and credit.get(r[0]): boss["npc"] = credit[r[0]]
        insts.setdefault(mid, {"map": mid, "lfg": []})
    # Temucraft's own instances: maps with no DungeonEncounter rows, bosses = spawned boss creatures
    custom = {}
    diff_of = set()
    for t in ct.values():
        for k in ("difficulty_entry_1", "difficulty_entry_2", "difficulty_entry_3"):
            if num(t.get(k)): diff_of.add(num(t[k]))
    for mid, ids in spawns.items():
        mi = mapinfo.get(mid)
        if not mi or mi.get("type") not in (1, 2): continue
        list_ = []
        for cid in ids:
            t = ct.get(cid)
            if not t or cid in diff_of: continue
            sn = t.get("ScriptName", "")
            boss = sn.startswith("boss_") or (num(t.get("rank")) == 3 and not num(t.get("flags_extra")) & 128
                                              and not num(t.get("unit_flags")) & 0x2000000)
            if boss: list_.append(cid)
        if not list_: continue
        if mid in bosses_by_map:
            known = set(b["npc"] for b in bosses_by_map[mid].values())
            mods = module_spawns.get(mid, set())
            list_ = [c for c in list_ if c not in known and c in mods and ct[c].get("ScriptName", "").startswith("boss_")]
            if not list_: continue
        custom[mid] = sorted(list_, key=lambda c: (num(ct[c].get("minlevel")), c))

    out_inst = []
    used_items = set()

    def location(mid):
        if mid in texts["zone"]: return texts["zone"][mid]
        cont, x, y = mapinfo[mid]["corpse"]
        z = zone_at(cont, x, y) if cont >= 0 and (x or y) else ""
        if not z:
            for tid in tele.get(mid, []):
                if tid in triggers:
                    z = zone_at(*triggers[tid])
                    if z: break
        return z

    def art(lfg_rows, mid):
        tex = next((l[5] for l in lfg_rows if l[5]), "").upper()
        icon = tex if tex in ICONS else ""
        bg = BG_BY_ICON.get(tex) or next((b for b in BACKGROUNDS if b.upper() == tex), "")
        if not bg:
            d = re.sub(r"[^a-z]", "", mapinfo[mid]["name"].lower())
            bg = next((b for b in BACKGROUNDS if b.lower() == d or b.lower() == "the" + d), "")
        return icon, bg

    def boss_level(npc, d):
        t = ct.get(npc)
        if t and d: t = ct.get(num(t.get("difficulty_entry_%d" % d))) or t
        return num(t.get("maxlevel")) if t else 0

    def levels(mid, d, lfg_rows, bosses, kind):
        rows = [l for l in lfg_rows if l[6] == d]
        if rows:
            lo = min(l[3] or l[0] for l in rows); hi = max(l[4] or l[1] for l in rows); rec = min(l[2] for l in rows)
            if hi - lo > 12: hi = rec + 3          # "60 to 83": a level 60 raid that lets everyone in
            return lo, hi, rec
        acc = access.get((mid, d))
        lv = [boss_level(b["npc"], d) for b in bosses if b["npc"]]
        top = max(lv) if lv else 0
        if acc and acc[0]: return acc[0], max(acc[1] if acc[1] < 255 else 0, top, acc[0]), acc[0]
        if not top: return 0, 0, 0
        if top > 80: top = 80
        return max(1, top - 3), top, top

    def make(mid, name, bosses, kind, tier, lfg_rows, diffs, desc):
        mi = mapinfo[mid]
        dl = []
        for d in diffs:
            players, heroic = mapdiff.get(mid, {}).get(d, (0, 0))
            if not players: players = mi.get("players") or (5 if kind == 1 else 10)
            if kind == 1 and d == 1: heroic = 1
            if kind == 2 and d >= 2 and players in (10, 25): heroic = 1
            lo, hi, rec = levels(mid, d, lfg_rows, bosses, kind)
            if mid in texts["level"] and d == diffs[0]:
                lo, hi = (int(x) for x in texts["level"][mid].split("-"))
            dl.append((d, players, lo, hi, heroic, rec))
        icon, bg = art(lfg_rows, mid)
        first = dl[0] if dl else (0, 5, 0, 0, 0, 0)
        e = {"id": mid, "name": texts["name"].get(mid, name), "kind": kind, "tier": tier, "min": first[2], "max": first[3],
             "rec": first[5] or first[2], "zone": location(mid), "icon": icon, "bg": bg, "desc": desc, "bosses": bosses, "diffs": dl}
        return e

    for mid in sorted(insts):
        if only and mid not in only: continue
        mi = mapinfo[mid]
        if mi.get("type") not in (1, 2) or mid not in bosses_by_map: continue
        kind = 2 if mi["type"] == 2 else 1
        diffs_all = set()
        bosses = []
        order = sorted(bosses_by_map[mid].values(), key=lambda b: b["order"])
        for b in order:
            diffs_all |= b["diffs"]
        # difficulties the server has for the map (MapDifficulty.dbc) that have bosses or levels
        for d in mapdiff.get(mid, {}):
            if any(l[6] == d for l in insts[mid]["lfg"]) or any(num(ct.get(b["npc"], {}).get("difficulty_entry_%d" % d)) for b in order if d):
                diffs_all.add(d)
        for b in order:
            npc = b["npc"]
            l = boss_loot(npc, sorted(diffs_all)) if npc else {}
            for lst in l.values(): used_items.update(lst)
            t = ct.get(npc, {})
            bosses.append({"name": b["name"], "npc": npc, "desc": boss_desc(npc), "spells": boss_spells(npc) if npc else [],
                           "loot": l, "level": num(t.get("maxlevel")), "subname": t.get("subname", "")})
        tier = min(mi.get("exp", 0), 2) + 1
        out_inst.append(make(mid, mi["name"], bosses, kind, tier, insts[mid]["lfg"], sorted(diffs_all), texts["map"].get(mid, "")))
    for mid in sorted(custom):
        if only and mid not in only: continue
        mi = mapinfo[mid]
        kind = 2 if mi["type"] == 2 else 1
        stock = mid in bosses_by_map
        diffs = sorted(mapdiff.get(mid, {}) or {0: 1})
        if stock: diffs = [d for d in diffs if d > 0] or [1]   # the stock dungeon keeps its normal mode
        bosses = []
        for npc in custom[mid]:
            t = ct[npc]
            l = boss_loot(npc, diffs)
            for lst in l.values(): used_items.update(lst)
            bosses.append({"name": t["name"], "npc": npc, "desc": boss_desc(npc), "spells": boss_spells(npc), "loot": l,
                           "level": num(t.get("maxlevel")), "subname": t.get("subname", "")})
        name = mi["name"] + (" (Heroic)" if stock else "")
        with_loot = set(d for b in bosses for d in b["loot"])
        diffs = [d for d in diffs if d in with_loot] or diffs[:1]
        e = make(mid, name, bosses, kind, 4, insts.get(mid, {}).get("lfg", []) if not stock else [], diffs,
                 texts["map"].get(mid + 100000 if stock else mid, ""))
        if stock:
            e["key"] = mid + 100000
            e["diffs"] = [(d, p, 80, 80, 1, 80) for d, p, lo, hi, h, r in e["diffs"]]
            e["min"], e["max"], e["rec"] = 80, 80, 80
        out_inst.append(e)

    out_inst.sort(key=lambda e: (e["tier"], e["kind"], e["rec"] or e["min"], e["name"]))
    # write
    L = []
    L.append("-- Adventure Guide data (TemucraftAdventureGuide.lua), written by client/adventureguide/build_adventure_guide.py")
    L.append("-- from the server's DBCs and world database. Do not edit: change descriptions.tsv or the database, run it again.")
    L.append("-- instances: kind 1 dungeon / 2 raid; tier 1 Classic, 2 Burning Crusade, 3 Wrath of the Lich King, 4 Temucraft;")
    L.append("--   diffs: { difficulty, players, min level, max level, heroic } per difficulty the server has (MapDifficulty.dbc)")
    L.append("--   bosses: name, npc (creature entry), desc, level, subname, spells (Spell.dbc ids), loot[difficulty] = item ids")
    L.append("-- items[id] = { quality, inventory type, class, subclass, item level, name }")
    L.append("-- zones: { name, min level, max level, faction (-1 both, 0 Horde, 1 Alliance), expansion }")
    L.append("TEMUCRAFT_ADVENTURE_GUIDE = {")
    L.append("instances = {")
    for e in out_inst:
        head = "{ id = %d, %sname = %s, kind = %d, tier = %d, min = %d, max = %d, rec = %d, zone = %s, icon = %s, bg = %s, diffs = { %s }," % (
            e["id"], ("key = %d, " % e["key"]) if e.get("key") else "", lua(e["name"]), e["kind"], e["tier"], e["min"], e["max"], e["rec"],
            lua(e["zone"]), lua(e["icon"]), lua(e["bg"]), ", ".join("{ %d, %d, %d, %d, %d }" % d[:5] for d in e["diffs"]))
        L.append(head)
        L.append("  desc = %s," % lua(e["desc"]))
        L.append("  bosses = {")
        for b in e["bosses"]:
            lootp = ", ".join("[%d] = { %s }" % (d, ", ".join(str(i) for i in lst)) for d, lst in sorted(b["loot"].items()))
            L.append("    { name = %s, npc = %d, level = %d, subname = %s, desc = %s, spells = { %s }, loot = { %s } }," % (
                lua(b["name"]), b["npc"], b["level"], lua(b["subname"]), lua(b["desc"]), ", ".join(str(s) for s in b["spells"]), lootp))
        L.append("  } },")
    L.append("},")
    L.append("items = {")
    for iid in sorted(used_items):
        it = items[iid]
        L.append("[%d] = { %d, %d, %d, %d, %d, %s }," % (iid, num(it["Quality"]), num(it["InventoryType"]), num(it["class"]),
                 num(it["subclass"]), num(it["ItemLevel"]), lua(it["name"])))
    L.append("},")
    L.append("zones = {")
    for z in sorted(zones, key=lambda z: (z[1], z[0])):
        L.append("{ %s, %d, %d, %d, %d }," % (lua(z[0]), z[1], z[2], z[3], z[4]))
    L.append("},")
    L.append("};")
    open(a.out, "w", encoding="utf-8", newline="\n").write("\n".join(L) + "\n")
    nb = sum(len(e["bosses"]) for e in out_inst)
    print("wrote %s: %d instances, %d bosses, %d items, %d zones" % (a.out, len(out_inst), nb, len(used_items), len(zones)))
    missing = [e["name"] for e in out_inst if not e["desc"]]
    if missing: print("no description:", ", ".join(missing), file=sys.stderr)
    nozone = [e["name"] for e in out_inst if not e["zone"]]
    if nozone: print("no zone:", ", ".join(nozone), file=sys.stderr)


if __name__ == "__main__":
    main()
