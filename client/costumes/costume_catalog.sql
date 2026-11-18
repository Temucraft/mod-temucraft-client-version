-- the wardrobe window's catalog: one creature (name, type) per wearable display, chosen like the server does
SELECT m.CreatureDisplayID AS display, t.entry, t.type, t.name
FROM creature_template_model m
JOIN creature_template t ON t.entry = m.CreatureID
JOIN mod_temucraft_costume_display d ON d.display = m.CreatureDisplayID
WHERE t.name <> '' AND t.name NOT LIKE '%Trigger%' AND t.name NOT LIKE '%Bunny%' AND t.name NOT LIKE '%DND%'
ORDER BY t.`rank` DESC, t.entry;
