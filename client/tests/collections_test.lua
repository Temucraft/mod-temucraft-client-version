-- Stub tests for the Collections and talent loadout logic (no client): lua5.1 client/tests/collections_test.lua
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
dofile(dir.."/Interface/FrameXML/Temucraft/TemucraftCollections.lua");
dofile(dir.."/Interface/FrameXML/Temucraft/TemucraftTalents.lua");
local L, P = assert(TemucraftCollectionsLogic), assert(TemucraftTalentsLogic);
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end

local data = {
	{ 458, 284, 0, 0, "Creature\\RidingHorse\\RidingHorse.m2", "Brown Horse Bridle" },
	{ 6777, 4710, 0, 0, "Creature\\Ram\\RidingRam.m2", "Gray Ram" },
	{ 23161, 0, 0, 256, "", "" },               -- warlock only (class mask), no item
	{ 5784, 304, 0, 0, "", "" },                -- no source
	{ 999, 1, 2, 0, "", "Orc thing" },          -- race mask: orcs only
};
local names = { [458] = "Brown Horse", [6777] = "Gray Ram", [23161] = "Dreadsteed", [5784] = "Felsteed", [999] = "Wolf", [77] = "Custom Mount" };
local owned = { [6777] = { index = 1, name = "Gray Ram", icon = "x", creature = 4710, active = false },
	[77] = { index = 2, name = "Custom Mount", icon = "y", creature = 5, active = true } };
local list, collected, total = L.Build(data, owned, function(id) return names[id], "icon"; end, { [458] = true }, 1, 1);
check("favourite first", list[1].spell == 458);
check("collected next", list[2].owned and list[3].owned);
check("custom owned mount kept", list[2].spell == 77 or list[3].spell == 77);
check("race mask hides other races", (function() for _, e in ipairs(list) do if ( e.spell == 999 ) then return false; end end return true; end)());
check("class mask hides other classes", (function() for _, e in ipairs(list) do if ( e.spell == 23161 ) then return false; end end return true; end)());
check("counts", collected == 2 and total == 3);
local shown = L.Filter(list, "", { collected = true, missing = true, unknown = false });
check("unknown sources hidden by default", #shown == 3);
shown = L.Filter(list, "", { collected = true, missing = true, unknown = true });
check("unknown sources on request", #shown == 4);
shown = L.Filter(list, "", { collected = false, missing = true, unknown = false });
check("not collected only", #shown == 1 and shown[1].spell == 458);
shown = L.Filter(list, "bridle", { collected = true, missing = true, unknown = false });
check("search by source", #shown == 1 and shown[1].spell == 458);
local warlock = L.Build(data, {}, function(id) return names[id], "i"; end, {}, 1, 9);
check("class mask shows to its class", (function() for _, e in ipairs(warlock) do if ( e.spell == 23161 ) then return true; end end return false; end)());
local fav = L.ParseFavourites("458,6777");
check("favourites round trip", L.SerializeFavourites(fav) == "458,6777");

local chunks = L.Chunks({ 32158, 7561, 0, 7561, 1, 22, 333 }, 12, 3);
check("cache asks: each entry once, no 0", table.concat(chunks, "|") == "32158,7561,1|22,333");
chunks = L.Chunks({ 123456, 123457, 123458 }, 14, 40);
check("cache asks: length limit", #chunks == 2 and chunks[1] == "123456,123457" and chunks[2] == "123458");
check("cache asks: nothing to ask", #L.Chunks({ 0 }, 200, 40) == 0);

local builds = P.Parse("Raid=05500.3200.0=@PvP=0..555");
check("loadouts parse", #builds == 1 or #builds == 2);
builds = P.Parse(P.Serialize({ { name = "Raid", trees = { "0550", "32", "" } }, { name = "PvP", trees = { "", "", "555" } } }));
check("loadouts round trip", #builds == 2 and builds[1].trees[2] == "32" and builds[2].trees[3] == "555" and builds[1].trees[3] == "");
check("loadout names cleaned", P.CleanName("My=Build@1.x|y") == "MyBuild1xy");

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
