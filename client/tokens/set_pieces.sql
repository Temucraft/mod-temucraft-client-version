-- every piece of the item sets the tier tokens buy into (for trying the whole set on)
SELECT DISTINCT it.itemset AS sett, it.entry AS item, it.InventoryType AS slot, it.ItemLevel AS ilvl
FROM item_template it
WHERE it.itemset IN (
  SELECT DISTINCT i.itemset FROM npc_vendor v
  JOIN item_template i ON i.entry = v.item AND i.itemset > 0
  JOIN dbc.itemextendedcost x ON x.id = v.ExtendedCost
  JOIN item_template tok ON tok.entry IN (x.req_item_1, x.req_item_2, x.req_item_3, x.req_item_4, x.req_item_5)
  WHERE tok.class = 15 AND tok.name REGEXP 'Conqueror|Protector|Vanquisher|Champion|Defender|Hero|Wanderer')
ORDER BY it.itemset, it.InventoryType;
