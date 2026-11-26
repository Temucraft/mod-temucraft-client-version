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
check("long text cut", len(g.first_sentence("word " * 60 + "1.")) <= 150, True)
if failed:
    print("%d failed" % failed)
    sys.exit(1)
print("all passed")
