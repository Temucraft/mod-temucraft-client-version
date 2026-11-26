#!/usr/bin/env python3
"""
Generates Interface/GlueXML/TemucraftRacialsData.lua: the racial abilities character create shows in the race
tooltip (icon, name, one line of what it does), as the PTR client has them.

  TEMUCRAFT_RACIALS["<RACE FILE>"] = { { id =, icon = "Interface\\Icons\\...", name = "...", text = "..." }, ... }
  (keyed by ChrRaces' file name in capitals, "HUMAN", "HORDEPANDAREN": what GetAvailableRaces gives the glue screen;
  ChrRaces.dbc from the PTR's patch-~.MPQ)

Source: the PTR's Spell.dbc and SkillLineAbility.dbc. Those with Temucraft's racials (the stock / Classic racials,
the best-version changes and the new spells 95800-95834, made by mod-temucraft-classes/tools/build_racial_bonuses.py
--client) are in _dev/racial-bonuses-client/DBFilesClient; without that folder, the release's patch-T.MPQ copies.
SpellIcon.dbc and SpellDuration.dbc: patch-T.MPQ.

Per race: every spell of its racial skill lines (RACE_LINES, the lines build_racial_bonuses.py uses) that a player
sees: taught by the line (AcquireMethod 1 / 2; plus EXTRA and the racial heal, RACIAL_HEAL), not hidden
(SPELL_ATTR0_DO_NOT_DISPLAY), not a lower rank (SkillLineAbility SupercededBySpell), not a language,
not a class copy of one already listed (Arcane Torrent, Blood Fury, Command ...: same name, the lowest id is kept),
not an empty helper (no name or no description). The text is the spell's description with $s1 / $m1 / $o1 / $t1 /
$d / $h / $u / $a1 / $x1 / $n / $12345s1 / ${...} / $lsingular:plural; resolved, cut to its first sentence.

    python3 gen_racials.py [--release "<TemuCraft Server>/5) Release"] [--tools "<TemuCraft Server>/_tools"]
                           [--dbc <folder with Spell.dbc and SkillLineAbility.dbc>]
"""
import argparse, os, re, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SERVER = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))

# race id -> racial skill lines (SkillLine.dbc; mod-temucraft-classes/tools/build_racial_bonuses.py LINE)
RACE_LINES = {
    1: [754], 2: [125], 3: [101], 4: [126], 5: [220], 6: [124], 7: [753], 8: [733], 9: [790], 10: [756], 11: [760],
    12: [789], 13: [797], 14: [797], 15: [812], 16: [801], 17: [804], 18: [805], 19: [795], 20: [799], 21: [796],
    22: [794], 23: [792], 24: [808], 25: [840], 26: [841], 27: [807], 28: [807], 29: [844, 845], 30: [844, 845],
}
# the racial heal mod-temucraft-classes teaches every class of the race in code (TemucraftClassChanges.cpp RACIAL_HEAL,
# RacialHeals = 1; _dev/reference/race_info.py has the same list): listed after the line's spells
RACIAL_HEAL = {1: 100172, 20: 100172, 2: 100173, 23: 100173, 3: 100174, 22: 100174, 4: 100175, 5: 20577,
               6: 100176, 16: 100176, 7: 100177, 9: 100177, 24: 100177, 8: 100178, 19: 100178, 10: 100179,
               15: 100179, 17: 100179, 11: 100180, 18: 100180, 12: 100181, 13: 100182, 14: 100182, 21: 100183,
               25: 100184, 26: 100184, 27: 100185, 28: 100185, 29: 100186, 30: 100186}
# racials taught another way: Running Wild sits on the Worgen line with AcquireMethod 0, mod-worgoblin-high-elf's
# running_wild.cpp teaches it at level 20
EXTRA = {12: [87840]}
ATTR0_DO_NOT_DISPLAY = 0x80
# Spell.dbc (3.3.5a 12340) fields
F_ATTR, F_DURATION, F_STACK, F_PROC_CHANCE, F_PROC_CHARGES = 4, 40, 49, 35, 36
F_EFFECT, F_DIE, F_BASE, F_RADIUS, F_AURA, F_AMPLITUDE, F_CHAIN, F_MISC, F_TRIGGER = 71, 74, 80, 92, 95, 98, 104, 110, 116
F_ICON, F_NAME, F_RANK, F_DESC, F_TOOLTIP, F_MAX_TARGETS = 133, 136, 153, 170, 187, 212


class DBC:
    def __init__(self, data):
        assert data[:4] == b"WDBC", "not a DBC"
        self.n, self.nf, self.rs, self.ss = struct.unpack_from("<4I", data, 4)
        self.d = data
        self.strs = 20 + self.n * self.rs
        self.index = {}

    def u(self, r, f):
        return struct.unpack_from("<I", self.d, 20 + r * self.rs + f * 4)[0]

    def i(self, r, f):
        return struct.unpack_from("<i", self.d, 20 + r * self.rs + f * 4)[0]

    def f(self, r, f):
        return struct.unpack_from("<f", self.d, 20 + r * self.rs + f * 4)[0]

    def s(self, r, f):
        o = self.strs + self.u(r, f)
        return self.d[o:self.d.index(b"\0", o)].decode("utf-8", "replace")

    def row(self, id_):
        if not self.index:
            self.index = {self.u(r, 0): r for r in range(self.n)}
        return self.index.get(id_)


class Spells:
    """Spell.dbc rows with the values the description tokens need."""

    def __init__(self, spell, duration=None, radius=None):
        self.db, self.dur, self.rad = spell, duration, radius

    def has(self, sid):
        return self.db.row(sid) is not None

    def base(self, sid, k):
        r = self.db.row(sid)
        if r is None:
            return 0
        return self.db.i(r, F_BASE + k) + max(1, self.db.i(r, F_DIE + k))

    def duration_ms(self, sid):
        r = self.db.row(sid)
        if r is None or not self.dur:
            return 0
        d = self.dur.row(self.db.u(r, F_DURATION))
        return self.dur.i(d, 1) if d is not None else 0

    def amplitude_ms(self, sid, k):
        r = self.db.row(sid)
        return self.db.u(r, F_AMPLITUDE + k) if r is not None else 0

    def radius(self, sid, k):
        r = self.db.row(sid)
        if r is None or not self.rad:
            return 0
        x = self.rad.row(self.db.u(r, F_RADIUS + k))
        return self.rad.f(x, 1) if x is not None else 0

    def field(self, sid, f):
        r = self.db.row(sid)
        return self.db.u(r, f) if r is not None else 0


def fmt_num(v):
    v = abs(v)
    if abs(v - round(v)) < 1e-6:
        return str(int(round(v)))
    return ("%.1f" % v).rstrip("0").rstrip(".")


def fmt_time(ms):
    s = abs(ms) / 1000.0
    if s >= 3600 and s % 3600 == 0:
        h = int(s // 3600)
        return "%d hour%s" % (h, "" if h == 1 else "s")
    if s >= 60 and s % 60 == 0:
        return "%d min" % int(s // 60)
    return fmt_num(s) + " sec"


TOKEN = re.compile(r"\$(\d*)([a-zA-Z])(\d?)")


def resolve(text, sid, sp):
    """The description with its $ tokens replaced by the spell's values (3.3.5 client rules, the common tokens)."""
    last = {"value": None}

    def value(ref, ch, k):
        ref = int(ref) if ref else sid
        k = int(k) - 1 if k else 0
        c = ch.lower()
        if c in ("s", "m"):
            return sp.base(ref, k)
        if c == "o":
            amp = sp.amplitude_ms(ref, k)
            dur = sp.duration_ms(ref)
            return sp.base(ref, k) * (dur // amp if amp else 1)
        if c == "t":
            return sp.amplitude_ms(ref, k) / 1000.0
        if c == "d":
            return ("time", sp.duration_ms(ref))
        if c == "h":
            return sp.field(ref, F_PROC_CHANCE)
        if c == "u":
            return sp.field(ref, F_STACK)
        if c == "n":
            return sp.field(ref, F_PROC_CHARGES)
        if c == "a":
            return sp.radius(ref, k)
        if c == "i":
            return sp.field(ref, F_MAX_TARGETS)
        if c == "x":
            return sp.field(ref, F_CHAIN + k)
        if c == "q":
            return sp.field(ref, F_MISC + k)
        return None

    # ${$m1/10} and friends: arithmetic over tokens
    def expr(m):
        body = TOKEN.sub(lambda t: str(_num(value(t.group(1), t.group(2), t.group(3)))), m.group(1))
        body = body.replace("$", "")
        if not re.fullmatch(r"[\d\.\s\+\-\*/\(\)]+", body):
            return ""
        try:
            return fmt_num(eval(body, {"__builtins__": {}}))
        except Exception:
            return ""

    def _num(v):
        if isinstance(v, tuple):
            return v[1] / 1000.0
        return v or 0

    # $?s12345[if known][else]: the player has none of those spells yet at character create -> the else part
    text = re.sub(r"\$\?[!]?[a-zA-Z]?\(?[^\[]*\[[^\]]*\]\[([^\]]*)\]", lambda m: m.group(1), text)
    text = re.sub(r"\$\{([^}]*)\}(\.\d)?", expr, text)
    # $/10;s1 (divide) form
    text = re.sub(r"\$/(\d+);(\d*)([a-zA-Z])(\d?)",
                  lambda m: fmt_num(_num(value(m.group(2), m.group(3), m.group(4))) / float(m.group(1))), text)
    text = re.sub(r"\$\*(\d+);(\d*)([a-zA-Z])(\d?)",
                  lambda m: fmt_num(_num(value(m.group(2), m.group(3), m.group(4))) * float(m.group(1))), text)

    def plural(m):
        n = last["value"]
        return m.group(1) if n is not None and abs(n) == 1 else m.group(2)

    out, pos = [], 0
    for m in re.finditer(r"\$[lL]([^:;]*):([^;]*);|" + TOKEN.pattern, text):
        out.append(text[pos:m.start()])
        if m.group(0)[1] in "lL" and m.group(1) is not None:
            out.append(plural(m))
        else:
            v = value(m.group(3), m.group(4), m.group(5))
            if v is None:
                out.append("")
            elif isinstance(v, tuple):
                out.append(fmt_time(v[1]))
                last["value"] = v[1] / 1000.0
            else:
                out.append(fmt_num(v))
                last["value"] = v
        pos = m.end()
    out.append(text[pos:])
    text = "".join(out)
    text = re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", text)
    text = text.replace("\r", " ").replace("\n", " ")
    return re.sub(r"\s+", " ", text).strip()


def first_sentence(text, limit=150):
    """The first sentence that says what it does (has a number), else the first one: the modpaks' racials start with
    a line of flavour ("Pandaren masters strike the nerve points.") before the effect."""
    parts = [p.strip() for p in re.split(r"(?<=[\.!])\s+", text) if p.strip()]
    s = next((p for p in parts if re.search(r"\d", p)), parts[0] if parts else text)
    if len(s) > limit:
        s = s[:limit - 3].rsplit(" ", 1)[0] + "..."
    return s


def racials(spell, sla, icons, sp):
    by_line = {}
    for r in range(sla.n):
        line = sla.u(r, 1)
        by_line.setdefault(line, []).append(r)
    out = {}
    for race, lines in sorted(RACE_LINES.items()):
        seen, rows = set(), []
        cands = []
        for line in lines:
            for r in sorted(by_line.get(line, []), key=lambda r: sla.u(r, 2)):
                mask = sla.u(r, 3)
                if mask and not mask & (1 << (race - 1)):
                    continue
                if sla.u(r, 8) or sla.u(r, 9) not in (1, 2):   # a lower rank, or not taught by the line
                    continue
                cands.append(sla.u(r, 2))
        cands += EXTRA.get(race, [])
        if race in RACIAL_HEAL:
            cands.append(RACIAL_HEAL[race])
        for sid in cands:
                s = spell.row(sid)
                if s is None or spell.u(s, F_ATTR) & ATTR0_DO_NOT_DISPLAY:
                    continue
                name, desc = spell.s(s, F_NAME), spell.s(s, F_DESC)
                base = re.sub(r"\s*\(.*\)$", "", name)
                if not name or not desc or name.lower().startswith("language") or name in seen or base in seen:
                    continue
                seen.add(name)
                i = icons.row(spell.u(s, F_ICON))
                icon = icons.s(i, 1) if i is not None else ""
                rows.append({"id": sid, "icon": icon or "Interface\\Icons\\INV_Misc_QuestionMark", "name": name,
                             "text": first_sentence(resolve(desc, sid, sp))})
        out[race] = rows
    return out


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_lua(data, files, path):
    L = ["-- Generated by client/gen_racials.py from the PTR's Spell.dbc / SkillLineAbility.dbc: do not edit, run the",
         "-- script again. TEMUCRAFT_RACIALS[race file] = { { id, icon, name, text (one line) }, ... }: the race tooltip's list.",
         "", "TEMUCRAFT_RACIALS = {"]
    for race in sorted(data):
        L.append("\t[%s] = {  -- %d" % (lua_str(files[race]), race))
        for e in data[race]:
            L.append("\t\t{ id = %d, icon = %s, name = %s, text = %s }," % (e["id"], lua_str(e["icon"]), lua_str(e["name"]), lua_str(e["text"])))
        L.append("\t},")
    L += ["};", ""]
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(L))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--release", default=os.path.join(SERVER, "5) Release"))
    ap.add_argument("--tools", default=os.path.join(SERVER, "_tools"))
    ap.add_argument("--dbc", default=os.path.join(SERVER, "_dev", "racial-bonuses-client", "DBFilesClient"))
    ap.add_argument("--out", default=os.path.join(HERE, "Interface", "GlueXML", "TemucraftRacialsData.lua"))
    a = ap.parse_args()
    sys.path.insert(0, a.tools)
    import mpqtool3
    patch_t = os.path.join(a.release, "patches", "patch-T.MPQ")

    def load(name):
        p = os.path.join(a.dbc, name)
        if os.path.exists(p):
            return DBC(open(p, "rb").read())
        data = mpqtool3.read_file(patch_t, "DBFilesClient\\" + name)
        if not data:
            sys.exit("%s not in %s or %s" % (name, a.dbc, patch_t))
        return DBC(data)

    spell, sla = load("Spell.dbc"), load("SkillLineAbility.dbc")
    icons = DBC(mpqtool3.read_file(patch_t, "DBFilesClient\\SpellIcon.dbc"))
    dur = DBC(mpqtool3.read_file(patch_t, "DBFilesClient\\SpellDuration.dbc"))
    rad_data = mpqtool3.read_file(patch_t, "DBFilesClient\\SpellRadius.dbc")
    rad = DBC(rad_data) if rad_data else None
    data = racials(spell, sla, icons, Spells(spell, dur, rad))
    chr_data = mpqtool3.read_file(os.path.join(a.release, "ptr", "patches", "patch-~.MPQ"), "DBFilesClient\\ChrRaces.dbc") \
        or mpqtool3.read_file(os.path.join(a.release, "patches", "patch-5.MPQ"), "DBFilesClient\\ChrRaces.dbc")
    chr_races = DBC(chr_data)
    files = {chr_races.u(r, 0): chr_races.s(r, 11).upper() for r in range(chr_races.n)}
    missing = [r for r in data if r not in files]
    if missing:
        sys.exit("races without a ChrRaces row: %s" % missing)
    write_lua(data, files, a.out)
    print("%s: %s" % (a.out, ", ".join("%d:%d" % (r, len(v)) for r, v in sorted(data.items()))))


if __name__ == "__main__":
    main()
