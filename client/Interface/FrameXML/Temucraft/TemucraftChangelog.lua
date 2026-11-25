-- What's New (the game menu's button, TemucraftGameMenu.lua): newest first. Add a block at the top with each client
-- release (the version as in client/VERSION; "next" until it has one).
TEMUCRAFT_CHANGELOG = {
	{ version = "next", lines = {
		"New character panel: the paper doll with slots down both sides, a bigger model, item level and stats in sections (Classic option: /tchar classic).",
		"New micro menu at the bottom right, with Spellbook & Talents in one button, Collections and Shop.",
		"New game menu (Esc) with Shop, What's New, AddOns, Edit Mode and Support.",
		"AddOn list in game: enable or disable addons, see their memory and CPU (/addons).",
		"Tooltips: SpellID / ItemID and icon lines (Interface Options > Temucraft to hide them), cooldown remaining, and a reminder for spells that aren't on your bars.",
		"Spellbook flyouts: teleports, portals and the Temucraft helper items in one entry each.",
	} },
	{ version = "1.5.0", lines = {
		"Retail-style spellbook, talents and collections windows.",
		"Spell tooltips: one line per talent with its rank and effect, base and real values.",
	} },
	{ version = "1.4.0", lines = {
		"Rebuilt interface patch with the .temucraft commands and the merged modules.",
		"Expedition window.",
	} },
	{ version = "1.3.0", lines = {
		"Vanity window.",
	} },
};
