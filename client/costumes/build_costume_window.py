#!/usr/bin/env python3
"""Writes Interface/FrameXML/Temucraft/TemucraftCostumes.lua, the wardrobe window of mod-temucraft-costumes.
Input: the TSV of costume_catalog.sql run on the world database (after the module's SQL is in), first creature per
display wins, like the server's catalog."""
import csv, os, sys
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'costumes', 'costumes.tsv')
out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, 'Interface', 'FrameXML', 'Temucraft', 'TemucraftCostumes.lua')
TYPES = {7, 1, 2, 3, 4, 5, 6, 9}
seen = {}
with open(src, encoding='utf-8') as f:
    for r in csv.DictReader(f, delimiter='\t'):
        d = int(r['display'])
        if d not in seen:
            t = int(r['type'])
            seen[d] = (int(r['entry']), t if t in TYPES else 10, r['name'])
def q(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
head = ['-- Temucraft wardrobe (mod-temucraft-costumes, addon prefix TCO). Made by build_costume_window.py; the',
        '-- catalog below comes from the world database: display = { creature, type, name }.',
        'local C = {']
body = ['[%d]={%d,%d,%s},' % (d, e, t, q(n)) for d, (e, t, n) in sorted(seen.items())]
ui = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'costume_window.lua'), encoding='utf-8').read()
open(out, 'w', encoding='utf-8').write('\n'.join(head + body + ['};', '']) + ui)
print(len(seen), 'costumes ->', out)
