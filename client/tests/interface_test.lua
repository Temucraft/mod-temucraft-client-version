-- Stub tests for the player UI overhaul logic (no client): lua5.1 client/tests/interface_test.lua (from the module folder)
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
local ui = dir.."/Interface/FrameXML/Temucraft/";
for _, f in ipairs({ "TemucraftInterface.lua", "TemucraftTooltips.lua", "TemucraftCharacter.lua", "TemucraftMicroMenu.lua",
	"TemucraftAddOns.lua", "TemucraftChangelog.lua", "TemucraftGameMenu.lua", "TemucraftFlyouts.lua", "TemucraftSpellBook.lua", "TemucraftGossip.lua" }) do
	dofile(ui..f);
end
local U, T, C, M, A, G, F, B = TemucraftUILogic, TemucraftTooltipsLogic, TemucraftCharacterLogic, TemucraftMicroMenuLogic,
	TemucraftAddOnsLogic, TemucraftGameMenuLogic, TemucraftFlyoutLogic, TemucraftSpellBookLogic;
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end

-- settings
check("option default on", U.Bool(nil, true) == true and U.Bool("0", true) == false and U.Bool("1", false) == true);

-- gossip icons
local GS = TemucraftGossipLogic;
check("gossip binder is the hearthstone", GS.Icon("binder", "Alliance") == "Interface\\Icons\\INV_Misc_Rune_01");
check("gossip taxi by faction", GS.Icon("taxi", "Horde") == "Interface\\Icons\\Ability_Mount_Wyvern_01" and GS.Icon("taxi", "Alliance") == "Interface\\Icons\\Ability_Mount_Gryphon_01");
check("gossip unknown type", GS.Icon("somethingnew") == "Interface\\Icons\\INV_Misc_Note_01" and GS.Icon(nil) == GS.Icon("gossip"));

-- tooltips
check("spell id from link", T.IdFromLink("|cff71d5ff|Hspell:53140|h[Teleport: Dalaran]|h|r") == 53140);
check("item id from link", T.IdFromLink("|cffa335ee|Hitem:40395:0:0:0:0:0:0:0:80|h[Torch of Holy Fire]|h|r", "item") == 40395);
check("icon name", T.IconName("Interface\\Icons\\Spell_Nature_StarFall") == "Spell_Nature_StarFall" and T.IconName(nil) == nil);
check("no cooldown text off cooldown", T.CooldownText(0, 0, 100) == nil);
check("global cooldown ignored", T.CooldownText(99, 1.5, 100) == nil);
check("cooldown seconds", T.CooldownText(90, 30, 100) == "Cooldown remaining: 20 sec");
check("cooldown minutes", T.CooldownText(100, 600, 100.2) == "Cooldown remaining: 10 min 0 sec");
check("cooldown over", T.CooldownText(10, 30, 100) == nil);
local bars = { { kind = "spell", spellId = 133, name = "Fireball" }, { kind = "macro", name = "Frostbolt" } };
check("on bars by id", T.OnBars(133, "Fireball", bars));
check("on bars by name (other rank)", T.OnBars(38692, "Fireball", bars));
check("on bars by macro", T.OnBars(116, "Frostbolt", bars));
check("not on bars", not T.OnBars(10, "Blizzard", bars));

-- character panel
local items = { [1] = { level = 200 }, [16] = { level = 226, equipLoc = "INVTYPE_2HWEAPON" } };
check("two-hander counts twice", math.abs(C.AverageItemLevel(items) - (200 + 226 * 2) / 17) < 0.001);
items[17] = { level = 100 };
check("off hand counts itself", math.abs(C.AverageItemLevel(items) - (200 + 226 + 100) / 17) < 0.001);
items[4], items[19] = { level = 999 }, { level = 999 };
check("shirt and tabard ignored", math.abs(C.AverageItemLevel(items) - (200 + 226 + 100) / 17) < 0.001);
check("empty: 0", C.AverageItemLevel({}) == 0);
check("roles", C.Role("MAGE") == "caster" and C.Role("HUNTER") == "ranged" and C.Role("ROGUE") == "melee"
	and C.Role("DRUID", 2) == "melee" and C.Role("DRUID", 3) == "caster" and C.Role("PALADIN", 1) == "caster");
local s = { str = 100, agi = 50, sta = 300, int = 20, spi = 30, armor = 5000, ap = 2500.4, meleeCrit = 25.123, sp = 0, heal = 0 };
local sections = C.Sections(s, "melee");
check("three sections", #sections == 3 and sections[1].title == "Attributes" and sections[2].title == "Enhancements" and sections[3].title == "Defense");
check("attack power rounded", sections[2].rows[1][1] == "Attack Power" and sections[2].rows[1][2] == "2500");
check("crit percent", sections[2].rows[2][2] == "25.12%");
local caster = C.Sections({ sp = 1500, heal = 1500, spellCrit = 10, spellHaste = 5, spellHit = 1, mp5 = 100, mp5Casting = 50 }, "caster");
check("caster rows", caster[2].rows[1][1] == "Spell Power" and caster[2].rows[#caster[2].rows][2] == "50 / 100");
check("slot columns", #C.LEFT == 8 and #C.RIGHT == 8 and #C.BOTTOM == 3);

-- micro menu
local keys = {};
for _, b in ipairs(M.BUTTONS) do table.insert(keys, b.key); end
check("micro order", table.concat(keys, ",") == "character,spellbook,achievements,quests,guild,lfd,collections,shop,menu,help");
local x = M.Layout(3, 28, -2);
check("micro layout right to left", x[3] == 0 and x[2] == -26 and x[1] == -52);

-- addons
check("strip colours", A.StripColors("|cff00ff00Deadly|r Boss Mods") == "Deadly Boss Mods");
check("memory KB", A.FormatMemory(511.6) == "512 KB");
check("memory MB", A.FormatMemory(2560) == "2.50 MB");
check("status loaded", A.Status({ enabled = true, loaded = true }) == "Loaded");
check("status disabled on reload", select(2, A.Status({ enabled = false, loaded = true })) == "warn");
check("status out of date", A.Status({ enabled = true, loaded = false, reason = "INTERFACE_VERSION" }) == "Out of date");
check("status missing dep", A.Status({ enabled = true, loaded = false, reason = "DEP_MISSING", reasonText = "Dependency missing" }) == "Dependency missing");
check("status on demand", A.Status({ enabled = true, loaded = false, demand = true }) == "Load on demand");
check("status disabled", A.Status({ enabled = false, loaded = false, reason = "DISABLED" }) == "Disabled");
local sorted = A.Sort({ { name = "b", title = "|cffff0000Zed|r" }, { name = "a", title = "alpha" }, { name = "c", title = "Beta" } });
check("sorted by title without colours", sorted[1].name == "a" and sorted[2].name == "c" and sorted[3].name == "b");

-- game menu
check("changelog present", type(TEMUCRAFT_CHANGELOG) == "table" and #TEMUCRAFT_CHANGELOG > 0);
local text = G.ChangelogText({ { version = "1.6.0", lines = { "A" } }, { version = "1.5.0", lines = { "B" } } }, "1.6.0", 1);
check("changelog text, latest only", string.find(text, "Temucraft 1.6.0 %(your client%)") and string.find(text, "- A") and not string.find(text, "- B"));
check("no changelog: nil", G.ChangelogText({}, "1.0") == nil);
local rows = G.Rows(false, false);
local names = {};
for _, r in ipairs(rows) do table.insert(names, r[1]); end
check("menu rows", table.concat(names, ",") == "options,shop,whatsnew,addons,support,GameMenuButtonMacros,GameMenuButtonLogout,GameMenuButtonQuit,GameMenuButtonContinue");
check("options open adds 4", #G.Rows(true, false) == #rows + 4 and #G.Rows(true, true) == #rows + 5);

-- flyouts
local list = {
	{ name = "Fireball", sub = "Rank 1", slot = 1, id = 133, tab = 2, tabName = "Fire", passive = false, flags = 0 },
	{ name = "Teleport: Stormwind", sub = "", slot = 2, id = 3561, tab = 2, tabName = "Arcane", passive = false, flags = 0 },
	{ name = "Portal: Stormwind", sub = "", slot = 3, id = 10059, tab = 2, tabName = "Arcane", passive = false, flags = 0 },
	{ name = "Teleport: Ironforge", sub = "", slot = 4, id = 3562, tab = 2, tabName = "Arcane", passive = false, flags = 0 },
	{ name = "Mystery Port", sub = "", slot = 5, id = 999001, tab = 2, tabName = "Arcane", passive = false, flags = 16 },
	{ name = "Teleport Mastery", sub = "", slot = 6, id = 999002, tab = 2, tabName = "Arcane", passive = true, flags = 0 },
};
check("groups", F.SpellGroup(list[2]) == "teleports" and F.SpellGroup(list[3]) == "portals" and F.SpellGroup(list[5]) == "teleports"
	and F.SpellGroup(list[6]) == nil and F.SpellGroup(list[1]) == nil);
local out = F.Collapse(list, {});
check("teleports collapsed, lone portal kept", #out == 4 and out[2].flyout and out[2].flyout.key == "teleports"
	and #out[2].flyout.members == 3 and out[3].name == "Portal: Stormwind" and out[4].passive);
check("flyout subtitle", out[2].sub == "3 spells");
out = F.Collapse(list, { { item = 610140, name = "Courier's Bell", icon = "x" } });
check("helpers entry", out[#out].flyout and out[#out].flyout.key == "helpers" and out[#out].tab == 1);
local books = B.Group(F.Collapse(list, { { item = 610140, name = "Courier's Bell" } }), { "Arcane", "Fire", "Frost" }, "Mage");
check("flyout in its tree", books.class[1].title == "Arcane" and books.class[1].entries[1].name == "Teleports");
check("helpers in General", books.general[1].title == "General" and books.general[1].entries[1].name == "Temucraft Helpers");

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
