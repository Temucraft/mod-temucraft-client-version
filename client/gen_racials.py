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
not an empty helper (no name or no description). Per racial:
  cat     its category, "Combat (Offense)": the spell's rank text ("Racial - Combat (Offense)", build_racial_bonuses.py's
          rank()); stock racials whose rank is still plain "Racial" get theirs from CATEGORY (same categories)
  text    the short view: one plain line, no formulas and never cut with "..." (SHORT for the ones whose first
          sentence is too long or has a scaling formula; the racial heal says "Racial heal: ...")
  detail  the detailed view (Shift held): the whole description with $s1 / $m1 / $o1 / $t1 / $d / $h / $u / $a1 /
          $x1 / $n / $12345s1 / ${...} / $lsingular:plural; resolved and the scaling written short
          ("10 x your level + 75% of attack power or 112% of spell power")
  meta    "Passive" or "Active - 2 min cooldown - 30 yd range - 1.5 sec cast" (from Spell.dbc, SpellRange.dbc,
          SpellCastTimes.dbc)
The list is sorted by category: Combat, Stats, Resistance, Weapon Skill, Profession, Utility (each race's own order
inside a category).

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
ATTR0_DO_NOT_DISPLAY, ATTR0_PASSIVE = 0x80, 0x40
F_CAST_TIME, F_RECOVERY, F_CATEGORY_RECOVERY, F_RANGE = 28, 29, 30, 46
# the categories build_racial_bonuses.py / build_racial_actives.py give their spells (rank(cat, sub)), for the stock
# racials whose rank text is still plain "Racial" / "Racial Passive"
CATEGORY_ORDER = ["Combat", "Stats", "Resistance", "Weapon Skill", "Profession", "Utility"]
CATEGORY = {
    20600: ("Utility", "Other"), 59752: ("Combat", "Defense"), 20572: ("Combat", "Offense"), 95045: ("Combat", "Defense"),
    2481: ("Utility", "Economy"), 20594: ("Combat", "Defense"), 58984: ("Combat", "Defense"), 95047: ("Combat", "Offense"),
    7744: ("Combat", "Defense"), 20577: ("Combat", "Healing"), 20549: ("Combat", "Defense"), 20589: ("Combat", "Defense"),
    95048: ("Combat", "Offense"), 26297: ("Combat", "Offense"), 95046: ("Combat", "Healing"), 69041: ("Combat", "Offense"),
    69046: ("Utility", "Other"), 69070: ("Utility", "Travel"), 25046: ("Combat", "Offense"), 28880: ("Combat", "Healing"),
    68992: ("Utility", "Travel"), 87840: ("Utility", "Travel"), 81092: ("Combat", "Offense"), 81102: ("Combat", "Defense"),
    81112: ("Combat", "Defense"), 81113: ("Combat", "Defense"), 81114: ("Profession", "Crafting"),
    81177: ("Stats", "Primary"), 81181: ("Stats", "Primary"), 81178: ("Resistance", "All"), 81182: ("Resistance", "All"),
    81117: ("Stats", "Health and Mana"), 81121: ("Stats", "Health and Mana"),
    81118: ("Profession", "Crafting"), 81122: ("Profession", "Crafting"),
}
HEAL_CATEGORY = ("Combat", "Healing")
# the short view's line where the description's first sentence is too long or carries a scaling formula
SHORT = {
    59752: "Removes all movement impairing and loss of control effects.",
    20573: "Stuns 20% shorter, and a 25% chance to resist them.",
    20574: "+5 expertise with Axes and Fist Weapons, +5 Axe skill.",
    95045: "Removes curses and makes you immune to them for 8 sec.",
    2481: "Find 20% more gold when looting, 50% more in chests.",
    20594: "Removes poison, disease and bleed effects, +10% armor for 8 sec.",
    20595: "+5 Gun skill and +1% crit with Guns.",
    20596: "Frost resistance equal to your level, -1% Frost damage taken.",
    20582: "+2% dodge, and 2% less chance to be hit.",
    20583: "Nature resistance equal to your level, -1% Nature damage taken.",
    20551: "Nature resistance equal to your level, -1% Nature damage taken.",
    20579: "Shadow resistance equal to your level, -1% Shadow damage taken.",
    20592: "Arcane resistance equal to your level, -1% Arcane damage taken.",
    59221: "Shadow resistance equal to your level, -1% Shadow damage taken.",
    95808: "Arcane resistance equal to your level, -1% Arcane damage taken.",
    68976: "Nature and Shadow resistance equal to your level, -1% damage taken from both.",
    21009: "+2% movement speed, 5% more while stealthed.",
    58984: "Slip into the shadows: enemies have less chance to detect you.",
    95804: "+1% haste at night, +1% crit during the day.",
    7744: "Removes Charm, Fear and Sleep effects.",
    20577: "Eat a nearby corpse to regenerate 7% health every 2 sec for 10 sec.",
    95148: "Attacks and damaging spells can drain life from the target.",
    20550: "+5% health and +1% hit.",
    95806: "Your speed builds up while you keep running on foot, up to 60%.",
    20591: "+5% Intellect and maximum mana, rage, energy and runic power.",
    95048: "Abilities cost 20% less and deal 10% more damage for 8 sec.",
    20555: "+20% health regeneration, part of it continues in combat.",
    20557: "+5% damage and +20% experience versus Beasts.",
    20558: "+5 Thrown skill and +1% crit with Thrown weapons.",
    26290: "+5 Bow skill and +1% crit with Bows.",
    69041: "Launches your belt rockets at an enemy for Fire damage.",
    69044: "Always the best vendor discount (20%).",
    69046: "Gobber gives you bank access for 1 min.",
    69070: "Rocket-jump forward.",
    822: "+5 to all resistances, 2% less chance to be hit by spells.",
    25046: "Silences nearby enemies for 2 sec and restores Energy.",
    6562: "+1% hit for you and your party, +1% to all your stats.",
    28880: "Heals the target over 15 sec.",
    68992: "+40% movement speed for 10 sec.",
    87840: "Run on all fours as fast as a wild animal.",
    81060: "Twice as much rested experience, +3% Spirit.",
    81032: "Twice as much rested experience, +3% Spirit.",
    81061: "50% less falling damage, +2% dodge.",
    81033: "50% less falling damage, +2% dodge.",
    81062: "+15 Cooking and +5% base health.",
    81034: "+15 Cooking and +5% base health.",
    95865: "Incapacitates the target for 4 sec.",
    81105: "+15 Inscription and +5% Intellect.",
    81106: "+1% magic damage, -1% magic damage taken.",
    95855: "Deals Arcane damage to nearby enemies and slows them.",
    95856: "Conjure a mailbox for 1 min 30 sec.",
    81108: "+1% damage and healing, +5% base health.",
    81109: "+15 Mining and faster mining, stuns 10% shorter.",
    81110: "Each hit you take is reduced, more with more Stamina.",
    95857: "Charge forward and knock down the enemies where you land.",
    81092: "Silences nearby enemies for 2 sec and restores mana, rage or energy.",
    81093: "In combat, a chance to gain +5% damage and healing for 12 sec.",
    95864: "Tear a rift ahead of you, then step through it.",
    95859: "Calls down Holy light that damages enemies in an area after 3 sec.",
    95861: "When you die, damages nearby enemies and heals nearby allies.",
    95835: "Regenerate 50% of your health over 6 sec.",
    95836: "While falling, glide down slowly and move faster.",
    95837: "Your attacks can drain the target and heal you.",
    81020: "Heal back 2% of damage taken, +1% damage and healing, +5% base health.",
    81021: "Hold your breath much longer and swim 10% faster.",
    81022: "-3% Frost and -1% Nature damage taken.",
    95847: "Punch your target, stunning it for 3 sec and knocking it back.",
    81125: "The first hit from each enemy is reduced, +2% dodge.",
    95848: "Throw something: damages and slows an enemy, or heals and speeds up an ally.",
    95816: "+5 Blacksmithing, and you craft Blacksmithing items 25% faster.",
    95839: "Removes harmful effects and raises your primary stat for 8 sec.",
    95841: "Tunnel to a Dark Iron place you have discovered.",
    95842: "Gain one of four random ancestral buffs for 15 sec.",
    273217: "+10% base health and +10% pet health.",
    273220: "Poison, Disease and Curse effects 10% shorter, 15% chance to resist them.",
    81112: "Removes stuns and slows; heals you once when you fall below 20% health.",
    95832: "Your main stats rise by 1% every 5 sec in combat, up to 10%.",
    95853: "Project two decoys that draw nearby enemies' attacks.",
    95854: "Pick locks on chests, lockboxes and doors.",
    95829: "+2 Perception when gathering: better odds of rare reagents.",
    95866: "Knocks back enemies in front of you and damages them.",
    95867: "Knocks nearby enemies up and away and damages them.",
    95868: "Leap into the air and glide, moving faster until you land.",
    81116: "+10% armor from items, stuns 10% shorter.",
    95823: "+25 Finesse when gathering: more bonus materials.",
    95825: "Always Well Fed: +60 Stamina and Spirit.",
    95870: "Damages enemies in front of you and heals allies there.",
    95871: "Restores 5% health and mana every second for 20 sec, out of combat.",
    95827: "+5 Herbalism and +10 Finesse when gathering herbs.",
    95828: "+1% damage and +10% experience versus Beasts and Elementals.",
    95872: "Thorns damage enemies and heal allies in an area over 12 sec.",
    95875: "Travel to Nighthaven in Moonglade.",
    20552: "+15 Herbalism, and you gather herbs faster.",
    95810: "+1% crit while you wield an Axe.",
    95041: "+1% crit with all attacks and spells.",
    95809: "+1% crit with all attacks and spells.",
    95044: "+1% hit with all attacks and spells.",
    95801: "Critical strikes deal 2% more damage.",
    95805: "Critical strikes deal 2% more damage.",
    95826: "Critical strikes deal 1% more damage.",
    20597: "+5 expertise and weapon skill with Swords.",
    20864: "+5 expertise and weapon skill with Maces.",
    59224: "+5 expertise with Maces.",
    95802: "+4 expertise with Daggers and One-Handed Swords.",
    95807: "+1% hit with Guns, Bows and Crossbows.",
    20599: "+10% reputation gains and cheaper vendors.",
}
SHORT_LIMIT = 80   # longer first sentences need a SHORT line (gen_racials_test.py checks the generated file)
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

    def __init__(self, spell, duration=None, radius=None, range_db=None, cast_db=None):
        self.db, self.dur, self.rad, self.range_db, self.cast_db = spell, duration, radius, range_db, cast_db

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

    def range_yd(self, sid):
        """the largest hostile / friendly range (SpellRange.dbc fields 3 and 4), 0 = self"""
        r = self.db.row(sid)
        if r is None or not self.range_db:
            return 0
        x = self.range_db.row(self.db.u(r, F_RANGE))
        return max(self.range_db.f(x, 3), self.range_db.f(x, 4)) if x is not None else 0

    def cast_ms(self, sid):
        r = self.db.row(sid)
        if r is None or not self.cast_db:
            return 0
        x = self.cast_db.row(self.db.u(r, F_CAST_TIME))
        return max(0, self.cast_db.i(x, 1)) if x is not None else 0


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


def first_sentence(text):
    """The first sentence that says what it does (has a number), else the first one: the modpaks' racials start with
    a line of flavour ("Pandaren masters strike the nerve points.") before the effect. Never cut: a sentence too long
    for the short view gets a SHORT line instead."""
    parts = [p.strip() for p in re.split(r"(?<=[\.!])\s+", text) if p.strip()]
    return next((p for p in parts if re.search(r"\d", p)), parts[0] if parts else text)


SCALING = re.compile(r"\(([^()]*\b(?:your level|attack power|spell power)\b[^()]*)\)")


def short_scaling(text):
    """The scaling formula written short: "(10 x your level plus 75% of your attack power or 112% of your spell
    power)" -> "(10 x your level + 75% of attack power or 112% of spell power)"."""
    def one(m):
        body = m.group(1).replace(" plus ", " + ").replace(", plus ", " + ")
        body = re.sub(r"\bof your (attack|spell) power", r"of \1 power", body)
        return "(" + body + ")"
    return SCALING.sub(one, text)


def short_text(sid, desc, heal):
    """the short view's line: SHORT, else the effect sentence without a scaling formula; the racial heal says so"""
    if sid in SHORT:
        return SHORT[sid]
    s = SCALING.sub("", first_sentence(desc))
    s = re.sub(r"\s+([,.])", r"\1", re.sub(r"\s+", " ", s)).strip()
    if heal:
        s = "Racial heal: " + re.sub(r"^Heals\b", "restores", s)
    return s


def category(sid, rank_text, heal):
    """("Combat", "Offense") from the rank text "Racial - Combat (Offense)", else CATEGORY / the racial heal."""
    m = re.match(r"^Racial - (.+?) \((.+)\)$", rank_text or "")
    if m:
        return m.group(1), m.group(2)
    if sid in CATEGORY:
        return CATEGORY[sid]
    if heal:
        return HEAL_CATEGORY
    return None


def meta_text(sid, passive, sp):
    """Passive, or Active - 2 min cooldown - 30 yd range - 1.5 sec cast."""
    if passive:
        return "Passive"
    parts = ["Active"]
    cd = sp.field(sid, F_RECOVERY) or sp.field(sid, F_CATEGORY_RECOVERY)
    if cd > 1500:
        parts.append(fmt_time(cd) + " cooldown")
    rng = sp.range_yd(sid)
    if rng >= 2:
        parts.append(fmt_num(rng) + " yd range")
    cast = sp.cast_ms(sid)
    parts.append((fmt_time(cast) + " cast") if cast > 0 else "Instant")
    return " - ".join(parts)


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
                heal = sid == RACIAL_HEAL.get(race) and sid != 20577   # Cannibalize is the Undead's own
                full = resolve(desc, sid, sp)
                cat = category(sid, spell.s(s, F_RANK), heal) or ("Utility", "Other")
                rows.append({"id": sid, "icon": icon or "Interface\\Icons\\INV_Misc_QuestionMark", "name": name,
                             "cat": "%s (%s)" % cat, "group": cat[0],
                             "text": short_text(sid, full, heal),
                             "detail": short_scaling(full),
                             "meta": meta_text(sid, spell.u(s, F_ATTR) & ATTR0_PASSIVE, sp)})
        order = {c: n for n, c in enumerate(CATEGORY_ORDER)}
        rows = [r for _, r in sorted(enumerate(rows), key=lambda t: (order.get(t[1]["group"], len(order)), t[0]))]
        out[race] = rows
    return out


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_lua(data, files, path):
    L = ["-- Generated by client/gen_racials.py from the PTR's Spell.dbc / SkillLineAbility.dbc: do not edit, run the",
         "-- script again. TEMUCRAFT_RACIALS[race file] = { { id, icon, name, cat (\"Combat (Offense)\"), text (the short",
         "-- view's line), detail (the whole description), meta (\"Passive\" / \"Active - 2 min cooldown ...\") }, ... }:",
         "-- the race tooltip's list, by category.",
         "", "TEMUCRAFT_RACIALS = {"]
    for race in sorted(data):
        L.append("\t[%s] = {  -- %d" % (lua_str(files[race]), race))
        for e in data[race]:
            L.append("\t\t{ id = %d, icon = %s, name = %s, cat = %s, text = %s, detail = %s, meta = %s }," % (
                e["id"], lua_str(e["icon"]), lua_str(e["name"]), lua_str(e["cat"]), lua_str(e["text"]),
                lua_str(e["detail"]), lua_str(e["meta"])))
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
    rng_data = mpqtool3.read_file(patch_t, "DBFilesClient\\SpellRange.dbc")
    cast_data = mpqtool3.read_file(patch_t, "DBFilesClient\\SpellCastTimes.dbc")
    sp = Spells(spell, dur, rad, DBC(rng_data) if rng_data else None, DBC(cast_data) if cast_data else None)
    data = racials(spell, sla, icons, sp)
    long_lines = ["%d %s: %s" % (e["id"], e["name"], e["text"]) for rows in data.values() for e in rows
                  if len(e["text"]) > SHORT_LIMIT or "..." in e["text"]]
    if long_lines:
        sys.exit("short lines too long, add them to SHORT:\n  " + "\n  ".join(sorted(set(long_lines))))
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
