#!/usr/bin/env python3
"""Tests for gen_racials.py's tooltip token resolver and sentence picker (no DBCs needed):
python3 client/tests/gen_racials_test.py"""
import os, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import gen_racials as g


class FakeSpells:
    """Spell values by id: base points per effect, duration, amplitude, radius, proc chance, max targets."""
    DATA = {
        1: dict(base=[5, -2, 20], dur=15000, amp=[3000, 0, 0], rad=[8.0, 0, 0], proc=20, targets=5),
        2: dict(base=[150, 0, 0], dur=600000, amp=[0, 0, 0], rad=[0, 0, 0], proc=0, targets=0),
    }

    def base(self, sid, k): return self.DATA[sid]["base"][k]
    def duration_ms(self, sid): return self.DATA[sid]["dur"]
    def amplitude_ms(self, sid, k): return self.DATA[sid]["amp"][k]
    def radius(self, sid, k): return self.DATA[sid]["rad"][k]

    def field(self, sid, f):
        d = self.DATA[sid]
        return {g.F_PROC_CHANCE: d["proc"], g.F_MAX_TARGETS: d["targets"]}.get(f, 0)


failed = 0


def check(name, got, want):
    global failed
    if got != want:
        failed += 1
        print("FAIL %s: %r (want %r)" % (name, got, want))
    else:
        print("ok   %s" % name)


sp = FakeSpells()
r = lambda t: g.resolve(t, 1, sp)
check("$s1 / $s2 (absolute) / $m3", r("Up by $s1%, down by $s2%, $m3 more."), "Up by 5%, down by 2%, 20 more.")
check("$d and $t1", r("Every $t1 sec for $d."), "Every 3 sec for 15 sec.")
check("$o1: total over the duration", r("Heals $o1 over $d."), "Heals 25 over 15 sec.")
check("$a1, $i, $h", r("Up to $i enemies within $a1 yds, $h% chance."), "Up to 5 enemies within 8 yds, 20% chance.")
check("another spell's value", r("Lasts $2d and gives $2s1."), "Lasts 10 min and gives 150.")
check("${} arithmetic", r("Reduced by ${$s1*2}%."), "Reduced by 10%.")
check("$l plural", r("Lasts $s1 $lsecond:seconds;."), "Lasts 5 seconds.")
check("$?s condition: the else part", r("Restores Mana$?s805000[, 15 Focus,][] and Energy."), "Restores Mana and Energy.")
check("colour codes and new lines out", r("|cffffffffWhite|r\nNext"), "White Next")
check("first sentence with a number", g.first_sentence("Pandaren masters strike. Stuns for 4 sec. More."), "Stuns for 4 sec.")
check("decimals don't split", g.first_sentence("Damage reduced by 1.8% of your Stamina."), "Damage reduced by 1.8% of your Stamina.")
check("long text never cut", "..." in g.first_sentence("word " * 60 + "1."), False)
check("scaling written short",
      g.short_scaling("Deals Arcane damage (10 x your level plus 75% of your attack power or 112% of your spell power) to all."),
      "Deals Arcane damage (10 x your level + 75% of attack power or 112% of spell power) to all.")
check("short line: formula taken out",
      g.short_text(1, "Deals Fire damage (5 x your level plus 20% of your attack power) to enemies. More.", False),
      "Deals Fire damage to enemies.")
check("short line: SHORT wins", g.short_text(95855, "anything", False), g.SHORT[95855])
check("short line: the racial heal says so",
      g.short_text(100179, "Draw on stored arcane power. Heals 7% of your maximum health every 2 sec for 10 sec.", True),
      "Racial heal: restores 7% of your maximum health every 2 sec for 10 sec.")
check("category from the rank text", g.category(1, "Racial - Weapon Skill (Melee)", False), ("Weapon Skill", "Melee"))
check("category of a stock racial", g.category(59752, "Racial", False), ("Combat", "Defense"))
check("category of the racial heal", g.category(100172, "Racial", True), ("Combat", "Healing"))
check("every SHORT line fits", [k for k, v in g.SHORT.items() if len(v) > g.SHORT_LIMIT or "..." in v], [])
check("every CATEGORY is a known one", [k for k, v in g.CATEGORY.items() if v[0] not in g.CATEGORY_ORDER], [])


class MetaSpells(FakeSpells):
    def field(self, sid, f): return {g.F_RECOVERY: 120000}.get(f, 0)
    def range_yd(self, sid): return 30.0
    def cast_ms(self, sid): return 1500


check("meta: passive", g.meta_text(1, True, MetaSpells()), "Passive")
check("meta: active", g.meta_text(1, False, MetaSpells()), "Active - 2 min cooldown - 30 yd range - 1.5 sec cast")

# the generated file: every racial has a category, a short line that fits and a detail text
data = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Interface", "GlueXML", "TemucraftRacialsData.lua"),
            encoding="utf-8").read()
rows = [l for l in data.splitlines() if l.strip().startswith("{ id =")]
check("generated rows have cat / text / detail / meta", all(' cat = "' in l and ' detail = "' in l and ' meta = "' in l for l in rows) and len(rows) > 150, True)
check("generated short lines never end in ...", [l for l in rows if '...", detail' in l], [])
if failed:
    print("%d failed" % failed)
    sys.exit(1)
print("all passed")
