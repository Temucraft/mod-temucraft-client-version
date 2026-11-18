SELECT tok.entry token, tok.name tname, it.entry item, it.name iname, it.AllowableClass cls, it.ItemLevel ilvl, it.Quality q, it.itemset sett
FROM npc_vendor v
JOIN item_template it ON it.entry = v.item
JOIN dbc.itemextendedcost x ON x.id = v.ExtendedCost
JOIN item_template tok ON tok.entry IN (x.req_item_1, x.req_item_2, x.req_item_3, x.req_item_4, x.req_item_5)
WHERE tok.class = 15 AND tok.name REGEXP 'Conqueror|Protector|Vanquisher|Champion|Defender|Hero|Wanderer'
GROUP BY tok.entry, it.entry;
