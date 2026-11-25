-- Temucraft talent trees as specializations (the Specialization tab of TemucraftTalents.lua): per class token and
-- tree (in the order GetTalentTabInfo gives them), the roles, a short description, the preferred weapon, the primary
-- stat and two sample abilities (spell ids: the icons and tooltips come from the client).
-- roles: "DAMAGER", "TANK", "HEALER" (the first is the one the card shows first).
TEMUCRAFT_TALENT_SPECS = {
	WARRIOR = {
		{ roles = { "DAMAGER" }, text = "A battle-hardened fighter who wields a two-handed weapon and wears enemies down with bleeding wounds and crushing strikes.", weapon = "Two-handed axe, mace or sword; polearm", stat = "Strength", samples = { 12294, 46924 } },
		{ roles = { "DAMAGER" }, text = "A furious berserker who fights with a weapon in each hand, building rage to unleash a flurry of blows.", weapon = "Two one-handed weapons (or two two-handed with Titan's Grip)", stat = "Strength", samples = { 23881, 1680 } },
		{ roles = { "TANK" }, text = "A stalwart protector who uses a shield to guard allies and hold the attention of enemies.", weapon = "One-handed weapon and shield", stat = "Stamina", samples = { 23922, 46968 } },
	},
	PALADIN = {
		{ roles = { "HEALER" }, text = "Calls on the Light to heal and protect allies, and to strike down the undead.", weapon = "One-handed mace or sword, shield or off-hand", stat = "Intellect", samples = { 20473, 53563 } },
		{ roles = { "TANK" }, text = "Uses holy magic and a shield to protect allies and keep many enemies at bay.", weapon = "One-handed weapon and shield", stat = "Stamina", samples = { 31935, 53595 } },
		{ roles = { "DAMAGER" }, text = "A righteous crusader who judges enemies and smites them with a two-handed weapon and holy power.", weapon = "Two-handed axe, mace or sword; polearm", stat = "Strength", samples = { 35395, 53385 } },
	},
	HUNTER = {
		{ roles = { "DAMAGER" }, text = "A master of the wild who fights alongside a powerful animal companion.", weapon = "Bow, crossbow or gun", stat = "Agility", samples = { 19574, 34026 } },
		{ roles = { "DAMAGER" }, text = "A sharpshooter who strikes from a distance with precise, powerful shots.", weapon = "Bow, crossbow or gun", stat = "Agility", samples = { 19434, 53209 } },
		{ roles = { "DAMAGER" }, text = "A tracker who uses traps, explosives and venom to bring down prey.", weapon = "Bow, crossbow or gun", stat = "Agility", samples = { 53301, 3674 } },
	},
	ROGUE = {
		{ roles = { "DAMAGER" }, text = "A deadly assassin who poisons enemies and finishes them with quick, lethal strikes.", weapon = "Two daggers", stat = "Agility", samples = { 1329, 14177 } },
		{ roles = { "DAMAGER" }, text = "A swashbuckler who trades blows face to face with a quick weapon in each hand.", weapon = "Two one-handed weapons", stat = "Agility", samples = { 1752, 51690 } },
		{ roles = { "DAMAGER" }, text = "A shadowy fighter who strikes from stealth and controls the fight with tricks.", weapon = "Daggers or one-handed weapons", stat = "Agility", samples = { 16511, 51713 } },
	},
	PRIEST = {
		{ roles = { "HEALER" }, text = "Shields allies from harm with divine magic and heals through atonement and willpower.", weapon = "Staff, or one-handed mace or dagger and off-hand", stat = "Intellect", samples = { 47540, 17 } },
		{ roles = { "HEALER" }, text = "A devoted healer who mends groups of allies and keeps them alive with the Light.", weapon = "Staff, or one-handed mace or dagger and off-hand", stat = "Intellect", samples = { 34861, 47788 } },
		{ roles = { "DAMAGER" }, text = "Uses dark shadow magic to torment the minds and bodies of enemies.", weapon = "Staff, or one-handed mace or dagger and off-hand", stat = "Intellect", samples = { 15407, 34914 } },
	},
	DEATHKNIGHT = {
		{ roles = { "TANK", "DAMAGER" }, text = "A dark guardian who feeds on the blood of enemies to survive their attacks.", weapon = "Two-handed weapon", stat = "Strength", samples = { 55050, 49028 } },
		{ roles = { "DAMAGER", "TANK" }, text = "An icy harbinger of doom who strikes with frost-infused weapons.", weapon = "Two one-handed weapons or a two-handed weapon", stat = "Strength", samples = { 49184, 49143 } },
		{ roles = { "DAMAGER" }, text = "A master of death and disease who raises undead minions to fight at their side.", weapon = "Two-handed weapon", stat = "Strength", samples = { 55090, 49206 } },
	},
	SHAMAN = {
		{ roles = { "DAMAGER" }, text = "A spellcaster who calls on fire, lightning and the earth to destroy enemies.", weapon = "Staff, or one-handed mace, axe or dagger and shield", stat = "Intellect", samples = { 403, 51490 } },
		{ roles = { "DAMAGER" }, text = "A totemic warrior who strikes with weapons charged by the elements.", weapon = "Two one-handed weapons", stat = "Agility", samples = { 17364, 51533 } },
		{ roles = { "HEALER" }, text = "A healer who calls on the spirits of water and earth to restore allies.", weapon = "One-handed mace, axe or dagger and shield", stat = "Intellect", samples = { 61295, 974 } },
	},
	MAGE = {
		{ roles = { "DAMAGER" }, text = "Bends raw arcane magic to batter enemies, at the cost of a lot of mana.", weapon = "Staff, or one-handed sword or dagger and off-hand", stat = "Intellect", samples = { 30451, 44425 } },
		{ roles = { "DAMAGER" }, text = "Burns enemies with fireballs and flames that grow hotter with every critical strike.", weapon = "Staff, or one-handed sword or dagger and off-hand", stat = "Intellect", samples = { 133, 44457 } },
		{ roles = { "DAMAGER" }, text = "Freezes enemies in place and shatters them with icy spells.", weapon = "Staff, or one-handed sword or dagger and off-hand", stat = "Intellect", samples = { 116, 44572 } },
	},
	WARLOCK = {
		{ roles = { "DAMAGER" }, text = "A master of curses and shadow that drain the life of enemies over time.", weapon = "Staff, or one-handed sword or dagger and off-hand", stat = "Intellect", samples = { 172, 48181 } },
		{ roles = { "DAMAGER" }, text = "Commands demons, and in time takes on a demon's form.", weapon = "Staff, or one-handed sword or dagger and off-hand", stat = "Intellect", samples = { 47241, 30146 } },
		{ roles = { "DAMAGER" }, text = "Calls down fire and chaos to destroy enemies in a few big blows.", weapon = "Staff, or one-handed sword or dagger and off-hand", stat = "Intellect", samples = { 50796, 29722 } },
	},
	DRUID = {
		{ roles = { "DAMAGER" }, text = "Takes the form of a moonkin and balances arcane and nature magic to destroy enemies from afar.", weapon = "Staff, or one-handed mace or dagger and off-hand", stat = "Intellect", samples = { 48505, 24858 } },
		{ roles = { "TANK", "DAMAGER" }, text = "Takes the form of a great bear to protect allies, or a cat to tear enemies apart.", weapon = "Staff or polearm", stat = "Agility", samples = { 33876, 5487 } },
		{ roles = { "HEALER" }, text = "Uses nature magic to heal allies over time, and in time takes the form of a Tree of Life.", weapon = "Staff, or one-handed mace or dagger and off-hand", stat = "Intellect", samples = { 48438, 33763 } },
	},
};
TEMUCRAFT_ROLE_NAMES = { DAMAGER = "Damage", TANK = "Tank", HEALER = "Healer" };
-- Interface\LFGFrame\UI-LFG-ICON-ROLES
TEMUCRAFT_ROLE_COORDS = { TANK = { 0, 0.2617, 0.2617, 0.5234 }, HEALER = { 0.2617, 0.5234, 0, 0.2617 }, DAMAGER = { 0.2617, 0.5234, 0.2617, 0.5234 } };
