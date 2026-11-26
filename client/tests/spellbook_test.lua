-- Stub tests for the spellbook logic (no client): lua5.1 client/tests/spellbook_test.lua (from the module folder)
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
dofile(dir.."/Interface/FrameXML/Temucraft/TemucraftSpellBook.lua");
local L = assert(TemucraftSpellBookLogic);
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end

local list = {
	{ name = "Attack", sub = "", tab = 1, tabName = "General", passive = false, flags = 0 },
	{ name = "Shadowmeld", sub = "Racial", tab = 1, tabName = "General", passive = false, flags = 1 },
	{ name = "Quickness", sub = "Racial Passive", tab = 1, tabName = "General", passive = true, flags = 1 },
	{ name = "Fast Track", sub = "Guild Perk", tab = 1, tabName = "General", passive = true, flags = 0 },
	{ name = "Tailoring", sub = "Journeyman", tab = 1, tabName = "General", passive = false, flags = 2 },
	{ name = "Wrath", sub = "Rank 1", tab = 2, tabName = "Balance", passive = false, flags = 0 },
	{ name = "Wrath", sub = "Rank 2", tab = 2, tabName = "Balance", passive = false, flags = 0 },
	{ name = "Bear Form", sub = "Shapeshift", tab = 3, tabName = "Feral Combat", passive = false, flags = 0 },
	{ name = "Natural Shapeshifter", sub = "", tab = 3, tabName = "Feral Combat", passive = true, flags = 32 },
	{ name = "Rejuvenation", sub = "Rank 3", tab = 4, tabName = "Restoration", passive = false, flags = 0 },
	{ name = "Wayfinder", sub = "", tab = 5, tabName = "Temucraft", passive = false, flags = 0 },
};
local books = L.Group(list, { "Balance", "Feral Combat", "Restoration" }, "Druid");
check("class sections in talent order", books.class[1].title == "Balance" and books.class[2].title == "Feral Combat" and books.class[3].title == "Restoration");
check("highest rank only", #books.class[1].entries == 1 and books.class[1].entries[1].sub == "Rank 2");
check("rank is no subtitle", books.class[1].entries[1].subtitle == "");
check("shapeshift subtitle", books.class[2].entries[1].subtitle == "Shapeshift");
check("passive subtitle", books.class[2].entries[2].subtitle == "Passive");
local order = {};
for _, s in ipairs(books.general) do table.insert(order, s.title); end
check("general order", table.concat(order, ",") == "General,Racial,Professions,Guild Perks,Temucraft");
check("racial passive", books.general[2].entries[2].subtitle == "Racial Passive");
check("guild perk", books.general[4].entries[1].subtitle == "Guild Perk");

local filtered = L.Filter(books.class, "bear", nil);
check("search by name", #filtered == 1 and filtered[1].entries[1].name == "Bear Form");
filtered = L.Filter(books.class, "heal over time", function(e) return e.name == "Rejuvenation" and "heals the target over time" or ""; end);
check("search by description, every word", #filtered == 1 and filtered[1].title == "Restoration");
check("search by subtitle", #L.Filter(books.general, "racial passive") == 1);
check("empty query keeps all", #L.Filter(books.class, "") == 3);

local many = { { title = "A", entries = {} }, { title = "B", entries = {} } };
for i = 1, 40 do table.insert(many[1].entries, { name = "a"..i }); end
for i = 1, 2 do table.insert(many[2].entries, { name = "b"..i }); end
local pages = L.Paginate(many, 3, 470, 30, 50, 8);
local count = 0;
for _, p in ipairs(pages) do for _, it in ipairs(p) do if ( it.kind == "spell" ) then count = count + 1; assert(it.y + 50 <= 470); end end end
check("every spell placed, inside the page", count == 42);
local lastOk = true;
for _, p in ipairs(pages) do if ( p[#p].kind == "header" ) then lastOk = false; end end
check("no heading ends a page", lastOk);
check("several pages", #pages >= 2);
check("one empty page when nothing", #L.Paginate({}, 3, 470, 30, 50, 8) == 1);

-- ranks
local wrath = books.class[1].entries[1];
check("ranks kept on the highest", wrath.ranks and #wrath.ranks == 2 and wrath.ranks[1].sub == "Rank 1");
check("lower ranks, next lower first", #L.LowerRanks(wrath) == 1 and L.LowerRanks(wrath)[1].sub == "Rank 1");
check("single rank has none lower", #L.LowerRanks(books.class[2].entries[1]) == 0);
local all = L.ExpandRanks(books.class, {});
local bal = all[1].entries;
check("all ranks: group bar then ranks, highest first", bal[1].group and bal[1].count == 2 and bal[2].subtitle == "Rank 2" and bal[3].subtitle == "Rank 1");
check("all ranks: members carry the group", bal[2].groupKey == bal[1].groupKey and bal[2].ranks == nil);
check("all ranks: single-rank spells unchanged", #all[2].entries == 2 and not all[2].entries[1].group);
local foldedAll = L.ExpandRanks(books.class, { [bal[1].groupKey] = true });
check("folded group keeps only its bar", #foldedAll[1].entries == 1 and foldedAll[1].entries[1].folded);
local mixed = { { title = "S", entries = { { name = "x" }, { group = true, groupKey = "g", name = "G" },
	{ name = "g1", groupKey = "g" }, { name = "g2", groupKey = "g" }, { name = "y" } } } };
local mp = L.Paginate(mixed, 3, 470, 30, 50, 8, 24)[1];
check("group bar on its own row", mp[3].kind == "group" and mp[3].y == 30 + 50);
check("ranks under the bar, then a new row", mp[4].y == 30 + 50 + 24 and mp[4].col == 0 and mp[6].y == 30 + 50 + 24 + 50 and mp[6].col == 0);

-- skills
local lines = {
	{ name = "Class Skills", header = true }, { name = "Balance", rank = 1, max = 1 },
	{ name = "Professions", header = true }, { name = "Herbalism", rank = 120, max = 150, modifier = 0 },
	{ name = "Secondary Skills", header = true }, { name = "Cooking", rank = 75, max = 150 },
	{ name = "Weapon Skills", header = true }, { name = "Staves", rank = 50, max = 60 }, { name = "Defense", rank = 58, max = 60, modifier = 5 },
	{ name = "Armor Proficiencies", header = true }, { name = "Cloth", rank = 1, max = 1 }, { name = "Leather", rank = 1, max = 1 },
	{ name = "Languages", header = true }, { name = "Language: Darnassian", rank = 300, max = 300, description = "Speak it" },
	{ name = "Empty", header = true },
};
local ss = L.SkillSections(lines, { balance = "Interface\\Icons\\Spell_Nature_StarFall" });
local order2 = {};
for _, s in ipairs(ss) do table.insert(order2, s.title); end
check("skill sections in retail order, empty ones dropped", table.concat(order2, ",") == "Weapon Skills,Armor Proficiencies,Secondary Skills,Languages,Class Skills,Professions");
check("weapon icon", ss[1].entries[1].icon == "Interface\\Icons\\INV_Staff_08");
check("defense icon and modifier", ss[1].entries[2].icon == "Interface\\Icons\\Ability_Defend" and L.SkillRankText(ss[1].entries[2]) == "58 (+5) / 60");
check("armour has no rank", ss[2].entries[1].rank == nil and L.SkillRankText(ss[2].entries[1]) == "");
check("language icon", ss[4].entries[1].icon == "Interface\\Icons\\INV_Misc_Book_09");
check("class skill uses the tree icon", ss[5].entries[1].icon == "Interface\\Icons\\Spell_Nature_StarFall");
check("professions read-only flag", ss[6].entries[1].profession and L.SkillRankText(ss[6].entries[1]) == "120 / 150");
check("skills search", #L.Filter(ss, "staves") == 1 and #L.Filter(ss, "speak", function(e) return string.lower(e.description or ""); end) == 1);
check("unknown skill falls back to its heading", L.SkillIcon("Foo", "Weapon Skills") == "Interface\\Icons\\INV_Sword_04");

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
