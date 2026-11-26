-- Stub tests for the Adventure Guide (no client): lua5.1 client/tests/adventureguide_test.lua
-- The data file's shape and the hand-checked sample instances, then the tab / expansion / search / suggestion logic.
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
dofile(dir.."/Interface/FrameXML/Temucraft/TemucraftAdventureGuideData.lua");
dofile(dir.."/Interface/FrameXML/Temucraft/TemucraftAdventureGuide.lua");
local L, D = assert(TemucraftAdventureGuideLogic), assert(TEMUCRAFT_ADVENTURE_GUIDE);
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end

-- data shape
local byKey, problems = {}, {};
local function bad(what) if ( #problems < 5 ) then table.insert(problems, what); end end
for _, inst in ipairs(D.instances) do
	local key = L.Key(inst);
	if ( byKey[key] ) then bad("duplicate "..key); end
	byKey[key] = inst;
	if ( type(inst.name) ~= "string" or inst.name == "" ) then bad("name "..key); end
	if ( inst.kind ~= 1 and inst.kind ~= 2 ) then bad("kind "..inst.name); end
	if ( not (inst.tier >= 1 and inst.tier <= 4) ) then bad("tier "..inst.name); end
	if ( type(inst.diffs) ~= "table" or #inst.diffs == 0 ) then bad("diffs "..inst.name); end
	for _, row in ipairs(inst.diffs or {}) do
		if ( #row ~= 5 or row[2] <= 0 or row[3] > row[4] ) then bad("diff row "..inst.name); end
	end
	if ( type(inst.bosses) ~= "table" or #inst.bosses == 0 ) then bad("bosses "..inst.name); end
	for _, b in ipairs(inst.bosses or {}) do
		if ( type(b.name) ~= "string" or type(b.npc) ~= "number" or type(b.spells) ~= "table" or type(b.loot) ~= "table" ) then bad("boss "..inst.name); end
		for d, list in pairs(b.loot) do
			for _, id in ipairs(list) do if ( not D.items[id] ) then bad("item "..id.." of "..b.name); end end
		end
	end
end
check("data: instances well formed "..table.concat(problems, ", "), #problems == 0 and #D.instances > 50);
local itemsOk = true;
for id, row in pairs(D.items) do
	if ( type(id) ~= "number" or #row ~= 6 or type(row[6]) ~= "string" or row[1] < 2 ) then itemsOk = false; end
end
check("data: items { quality >= 2, inv, class, sub, ilvl, name }", itemsOk);
check("data: zones { name, min, max, faction, expansion }", #D.zones > 30 and #D.zones[1] == 5);
local described = true;
for _, inst in ipairs(D.instances) do if ( inst.tier <= 3 and (inst.desc == "" or inst.zone == "") ) then described = false; end end
check("data: every stock instance has an overview and a zone", described);

-- hand-checked sample (stock AzerothCore world database)
local function boss(inst, npc) for _, b in ipairs(inst.bosses) do if ( b.npc == npc ) then return b; end end end
local function has(list, id) for _, v in ipairs(list or {}) do if ( v == id ) then return true; end end return false; end
local dm, rfc, mc, kara, naxx = byKey[36], byKey[389], byKey[409], byKey[532], byKey[533];
check("sample: Deadmines, 7 bosses, Westfall, levels 17-20", dm and #dm.bosses == 7 and dm.zone == "Westfall" and dm.diffs[1][3] == 17 and dm.diffs[1][4] == 20);
local van = dm and boss(dm, 639);
check("sample: VanCleef drops Cruel Barb and Cape of the Brotherhood", van and has(van.loot[0], 5191) and has(van.loot[0], 5193));
check("sample: Ragefire Chasm, Orgrimmar, Taragaman", rfc and rfc.zone == "Orgrimmar" and boss(rfc, 11520) ~= nil and #rfc.bosses == 4);
check("sample: Molten Core, 40 players, 10 bosses, Ragnaros with loot and abilities", mc and mc.diffs[1][2] == 40 and #mc.bosses == 10
	and boss(mc, 11502) and #boss(mc, 11502).loot[0] > 5 and #boss(mc, 11502).spells > 0);
check("sample: Garr drops the Bindings of the Windseeker (left)", mc and has(boss(mc, 12057).loot[0], 18564));
check("sample: Karazhan, Burning Crusade raid, Prince Malchezaar", kara and kara.tier == 2 and kara.kind == 2 and boss(kara, 15690) ~= nil);
local kt = naxx and boss(naxx, 15990);
check("sample: Naxxramas 10 and 25 player loot for Kel'Thuzad", kt and #kt.loot[0] > 0 and #kt.loot[1] > 0 and kt.loot[0][1] ~= kt.loot[1][1]);
check("sample: hand-written boss texts", van and van.desc ~= "" and kt.desc ~= "");
check("sample: heroic dungeons have a heroic row", byKey[574] and byKey[574].diffs[2] and byKey[574].diffs[2][5] == 1);

-- tabs and expansion filter
local fake = { instances = {
	{ id = 1, name = "Low Dungeon", kind = 1, tier = 1, zone = "Elwynn", desc = "", diffs = { { 0, 5, 15, 20, 0 } },
		bosses = { { name = "Hogger", npc = 448, level = 20, subname = "Gnoll", desc = "", spells = {}, loot = { [0] = { 10, 11 } } },
		           { name = "Bigger Hogger", npc = 449, level = 21, subname = "", desc = "", spells = {}, loot = { [0] = { 11, 12 } } } } },
	{ id = 2, name = "Old Raid", kind = 2, tier = 1, zone = "Mountain", desc = "", diffs = { { 0, 40, 60, 63, 0 } }, bosses = {} },
	{ id = 3, name = "Outland Dungeon", kind = 1, tier = 2, zone = "Hellfire", desc = "", diffs = { { 0, 5, 60, 63, 0 }, { 1, 5, 70, 72, 1 } }, bosses = {} },
	{ id = 4, name = "Northrend Raid", kind = 2, tier = 3, zone = "Dragonblight", desc = "", diffs = { { 0, 10, 80, 83, 0 }, { 1, 25, 80, 83, 0 }, { 2, 10, 80, 83, 1 } },
		bosses = { { name = "Lich", npc = 5, level = 83, subname = "", desc = "", spells = {}, loot = { [0] = { 20 }, [1] = { 21 } } } } },
	{ id = 5, key = 100005, name = "Low Dungeon (Heroic)", kind = 1, tier = 4, zone = "Elwynn", desc = "", diffs = { { 1, 5, 80, 80, 1 } }, bosses = {} },
}, items = {}, zones = { { "Elwynn Forest", 1, 10, 1, 0 }, { "Durotar", 1, 10, 0, 0 }, { "Westfall", 9, 18, 1, 0 }, { "Stranglethorn", 30, 45, -1, 0 } } };
check("dungeons of Classic", #L.List(fake, 1, 1) == 1 and L.List(fake, 1, 1)[1].id == 1);
check("raids of every tier", #L.List(fake, 2) == 2);
local tiers = L.Tiers(fake, 1);
check("tiers with dungeons: Classic, Burning Crusade, Temucraft", table.concat(tiers, ",") == "1,2,4");
check("tiers with raids: Classic, Wrath", table.concat(L.Tiers(fake, 2), ",") == "1,3");
check("tier for level", L.TierForLevel(15) == 1 and L.TierForLevel(60) == 1 and L.TierForLevel(65) == 2 and L.TierForLevel(80) == 3);
check("real data: four tiers of dungeons", #L.Tiers(D, 1) == 4);
check("difficulty names", L.DiffLabel(fake.instances[3], fake.instances[3].diffs[2]) == "Heroic" and L.DiffLabel(fake.instances[1], fake.instances[1].diffs[1]) == "Normal"
	and L.DiffLabel(fake.instances[4], fake.instances[4].diffs[2]) == "25 Player" and L.DiffLabel(fake.instances[4], fake.instances[4].diffs[3]) == "10 Player (Heroic)");
check("level text", L.LevelText(17, 20) == "Levels 17-20" and L.LevelText(80, 80) == "Level 80" and L.LevelText(0, 0) == "");
check("difficulty row falls back to the first", L.DiffRow(fake.instances[1], 3)[1] == 0 and L.DiffRow(fake.instances[4], 1)[2] == 25);
check("pages", L.Pages(0, 9) == 1 and L.Pages(9, 9) == 1 and L.Pages(10, 9) == 2);

-- search
check("search by boss name", #L.Search(fake, 1, "hogger") == 1 and L.Search(fake, 1, "hogger")[1].id == 1);
check("search by zone, all words", #L.Search(fake, 1, "elwynn heroic") == 1 and L.Search(fake, 1, "elwynn heroic")[1].id == 5);
check("search keeps to the tab's kind", #L.Search(fake, 2, "hogger") == 0);
check("real data: search vancleef", L.Search(D, 1, "vancleef")[1] and L.Search(D, 1, "vancleef")[1].id == 36);
local inst, d = L.FindByName(fake, "low dungeon", 1);
check("opens inside an instance by name", inst and inst.id == 1 and d == 0);
inst, d = L.FindByName(fake, "Northrend Raid", 2);
check("raid difficulty from the client's index", inst and d == 1);
check("the Temucraft heroic copy is never the one you're in", L.FindByName(fake, "Low Dungeon (Heroic)", 2) == nil);

-- loot
local all = L.Loot(fake.instances[1], nil, 0);
check("instance loot: every boss, each item once", #all == 3 and all[1] == 10 and all[3] == 12);
check("boss loot per difficulty", #L.Loot(fake.instances[4], fake.instances[4].bosses[1], 1) == 1 and L.Loot(fake.instances[4], fake.instances[4].bosses[1], 1)[1] == 21);
check("no loot for a difficulty", #L.Loot(fake.instances[4], fake.instances[4].bosses[1], 2) == 0);
check("slot and armour type", L.SlotText({ 4, 1, 4, 4, 70, "Helm" }, nil, {}) == "Head, Plate");
check("client's strings win", L.SlotText({ 4, 1, 4, 4, 70, "Helm" }, "Platte", { INVTYPE_HEAD = "Kopf" }) == "Kopf, Platte");
check("weapon", L.SlotText({ 4, 17, 2, 1, 70, "Axe" }, nil, {}) == "Two-Hand, Axe");
check("rings have no armour type", L.SlotText({ 4, 11, 4, 0, 70, "Ring" }, nil, {}) == "Finger");
check("not equippable", L.SlotText({ 3, 0, 9, 0, 60, "Pattern" }, nil, {}) == "Recipe");
check("boss line", L.BossLine({ subname = "Gnoll", level = 20 }) == "Gnoll. Level 20" and L.BossLine({ subname = "", level = 0 }) == "");

-- suggestions
local s = L.Suggest(fake, 16, "Alliance", 6);
local kinds = {};
for _, e in ipairs(s) do table.insert(kinds, e.kind..":"..e.name); end
check("level 16 Alliance: dungeon, then zones in turn", kinds[1] == "dungeon:Low Dungeon" and kinds[2] == "zone:Westfall" and #s == 2);
s = L.Suggest(fake, 5, "Horde", 6);
check("level 5 Horde: Durotar, not Elwynn", #s == 1 and s[1].name == "Durotar");
s = L.Suggest(fake, 80, "Horde", 6);
local raid = nil;
for _, e in ipairs(s) do if ( e.kind == "raid" ) then raid = e; end end
check("level 80: the heroic dungeon and the raid", s[1].kind == "dungeon" and s[1].inst.id == 5 and raid and raid.inst.id == 4 and raid.diff == 0);
check("level 71: the heroic row of the Outland dungeon", L.Suggest(fake, 71, "Horde", 6)[1].diff == 1);
check("level 61: its normal row", L.Suggest(fake, 61, "Horde", 6)[1].diff == 0);
s = L.Suggest(D, 18, "Alliance", 6);
local names = {};
for _, e in ipairs(s) do names[e.name] = true; end
check("real data, level 18: Deadmines or Wailing Caverns", (names["Deadmines"] or names["Wailing Caverns"]) and #s == 6);
s = L.Suggest(D, 80, "Horde", 6);
local raids = 0;
for _, e in ipairs(s) do if ( e.kind == "raid" ) then raids = raids + 1; end end
check("real data, level 80: raids too", raids >= 1);

-- item cache asks (addon message TAG)
local chunks = L.Chunks({ 40384, 40385, 0, 40384, 7, 12345 }, 12, 3);
check("TAG asks: each id once, no 0", table.concat(chunks, "|") == "40384,40385|7,12345");
check("TAG asks: count limit", #L.Chunks({ 1, 2, 3, 4, 5 }, 200, 2) == 3);

-- mod-temucraft-journal's export
local journal = {
	{ map = 1, name = "Low Dungeon", raid = false, exp = 0, diff = 1, bosses = { { name = "Hogger", npc = 448, loot = {} } } },
	{ map = 800, name = "Karazhan Crypt", raid = false, exp = 0, diff = 3, bosses = { { name = "Alarus", npc = 1200001, loot = { [0] = { 1200100 } } } } },
	{ map = 801, name = "Emerald Sanctum", raid = true, exp = 0, diff = 1, bosses = { { name = "Erennius", npc = 1200002, loot = {} } } },
	{ map = 802, name = "Empty", raid = false, exp = 0, diff = 1, bosses = {} },
};
local copy = { instances = {}, items = {}, zones = {} };
for _, i in ipairs(fake.instances) do table.insert(copy.instances, i); end
check("journal: two new instances", L.MergeJournal(copy, journal) == 2 and #copy.instances == #fake.instances + 2);
local crypt = copy.instances[#fake.instances + 1];
check("journal: under Temucraft, normal and heroic", crypt.id == 800 and crypt.tier == 4 and #crypt.diffs == 2 and crypt.diffs[2][5] == 1);
check("journal: boss loot kept", crypt.bosses[1].loot[0][1] == 1200100);
check("journal: a raid", copy.instances[#fake.instances + 2].kind == 2);
check("journal: no table, nothing", L.MergeJournal(copy, nil) == 0);

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
