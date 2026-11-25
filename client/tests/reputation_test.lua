-- Stub tests for the reputation, currency and Renown logic (no client): lua5.1 client/tests/reputation_test.lua (from the module folder)
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
local ui = dir.."/Interface/FrameXML/Temucraft/";
for _, f in ipairs({ "TemucraftReputationData.lua", "TemucraftReputation.lua", "TemucraftCurrency.lua", "TemucraftRenown.lua" }) do dofile(ui..f); end
local L, C, J, D = TemucraftReputationLogic, TemucraftCurrencyLogic, TemucraftRenownLogic, TemucraftReputationData;
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end

-- the generated data
check("data names", D.names["Argent Crusade"] == 1106 and D.names["Kul Tiras"] == 2160 and D.names["Classic"] == 1118);
check("data groups", D.groups[2160] == "allied" and D.groups[1134] == "cata" and D.groups[1353] == "mists" and D.groups[2311] == "lostlands"
	and D.groups[2233] == "crafting" and D.groups[1106] == nil);
check("data roots", D.roots[1118] == "classic" and D.roots[980] == "tbc" and D.roots[1097] == "wotlk");

-- pieces and fields
check("fields keep the rest", L.Fields("V~1~2~3~4~5~6~7~title~a ~ b", 10)[10] == "a ~ b");
check("pieces", L.Feed("+ab") == nil and L.Feed("=cd") == "abcd" and L.Feed("S~1~0") == "S~1~0");

-- the server's tracks
check("hello", L.OnMessage("S~1~1") == "S" and L.server.renown and L.server.warband);
L.OnMessage("T~1106~Renown~3~Argent Crusade");
L.OnMessage("TD~1106~0~The Crusade remembers.");
L.OnMessage("V~1106~1~3000~none~0~1~1~Friend of the Crusade~Known by name.");
L.OnMessage("+V~1106~2~9000~item~43154~1~0~Tabard~A long ");
L.OnMessage("=description ~ with a tilde");
L.OnMessage("V~1106~3~42000~title~131~1~1~the Argent Champion~");
L.OnMessage("T~1073~Level~1~The Kalu'ak");
L.OnMessage("V~1073~1~21000~vendor~44723~1~0~~");
L.OnMessage("T~999~Renown~0~Empty");
check("tracks end", L.OnMessage("TE~3") == "TE");
local t = L.tracks[1106];
check("track read", t and t.max == 3 and t.label == "Renown" and t.desc == "The Crusade remembers." and t.levels[2].reward == 43154
	and t.levels[2].desc == "A long description ~ with a tilde" and t.levels[3].type == "title" and t.levels[1].highlight);
check("empty track dropped", L.tracks[999] == nil and L.tracks[1073].label == "Level");
check("track name known", L.IdOf("Argent Crusade") == 1106 and L.NameOf(1073) == "The Kalu'ak");

-- renown levels from the standing
local function lv(s) return { L.RenownLevel(t, s) }; end
check("below level 1", lv(1500)[1] == 0 and lv(1500)[2] == 1500 and lv(1500)[3] == 3000);
check("level 1", lv(3000)[1] == 1 and lv(3000)[2] == 0 and lv(3000)[3] == 6000);
check("level 2 progress", lv(20000)[1] == 2 and lv(20000)[2] == 11000 and lv(20000)[3] == 33000);
check("max", lv(42999)[1] == 3 and lv(42999)[4] == true);
check("negative standing", lv(-5000)[1] == 0 and lv(-5000)[2] == 0);
check("no track", L.RenownLevel(nil, 100) == 0);

-- granted levels
L.OnMessage("P~1106~1");
L.OnMessage("PE");
check("granted", L.granted[1106][1] and not L.granted[1106][2]);
check("states", L.LevelState(t, 1, 1) == "got" and L.LevelState(t, 2, 1) == "next" and L.LevelState(t, 3, 1) == "locked");
local seen;
L.On("granted", function(id, level) seen = id and (id..":"..level); end);
L.OnMessage("G~1106~2");
check("level up", seen == "1106:2" and L.granted[1106][2] and L.LevelState(t, 2, 1) == "got");

-- warband and names
L.OnMessage("W~1106,1073");
check("warband", L.warband[1106] and L.warband[1073] and not L.warband[1098]);
L.OnMessage("F~1106=Argentumkreuzzug^1098=Ritter der Schwarzen Klinge");
L.OnMessage("FE");
check("locale names", L.IdOf("Argentumkreuzzug") == 1106 and L.IdOf("Ritter der Schwarzen Klinge") == 1098 and L.IdOf("Stormwind") == 72);

-- bar text
local text, value, max = L.BarInfo({ id = 1106, barValue = 20000 });
check("renown bar", text == "Renown 2" and value == 11000 and max == 33000);
text, value, max = L.BarInfo({ standing = 5, barMin = 3000, barMax = 9000, barValue = 4500 });
check("standing bar", text == "Friendly" and value == 1500 and max == 6000);

-- grouping: a stock list (expanded)
local function F(name, o) o = o or {}; o.name = name; o.standing = o.standing or 4; o.barMin = 0; o.barMax = 3000; o.barValue = o.barValue or 0; return o; end
local rows = {
	F("Classic", { isHeader = true }),
	F("Alliance", { isHeader = true, isChild = true }),
	F("Stormwind", { isChild = true }),
	F("Gilneas", { isChild = true }),              -- ours: Cataclysm
	F("Kul Tiras", { isChild = true, atWar = true }),  -- ours: Allied Races
	F("Darnassus", { isChild = true }),
	F("Argent Dawn", {}),
	F("Wrath of the Lich King", { isHeader = true }),
	F("Alliance Vanguard", { isHeader = true, isChild = true, hasRep = true }),
	F("Valiance Expedition", { isChild = true }),
	F("Argentumkreuzzug", {}),
	F("Other", { isHeader = true }),
	F("Wintersaber Trainers", {}),
	F("Inactive", { isHeader = true }),
	F("Booty Bay", { inactive = true }),
};
local groups = L.Group(rows);
local keys = {};
for _, g in ipairs(groups) do table.insert(keys, g.key); end
check("group order", table.concat(keys, ",") == "allied,cata,wotlk,classic,stock:Other,inactive");
check("stock header names kept", groups[3].name == "Wrath of the Lich King" and groups[4].name == "Classic" and groups[1].name == "Allied Races");
check("sub header children", groups[4].items[1].kind == "sub" and #groups[4].items[1].children == 2 and groups[4].items[2].row.name == "Argent Dawn");
check("ours moved out", groups[2].items[1].row.name == "Gilneas" and groups[1].items[1].row.name == "Kul Tiras");
local lines = L.Flatten(groups, "all", {});
check("flatten all", #lines == 17 and lines[1].kind == "group" and lines[#lines].row.name == "Booty Bay");
lines = L.Flatten(groups, "active", {});
check("flatten active hides inactive", lines[#lines].row.name == "Wintersaber Trainers");
lines = L.Flatten(groups, "war", {});
check("flatten at war", #lines == 2 and lines[2].row.name == "Kul Tiras");
lines = L.Flatten(groups, "inactive", {});
check("flatten inactive", #lines == 2 and lines[1].key == "inactive");
lines = L.Flatten(groups, "all", { classic = true, ["sub:wotlk:Alliance Vanguard"] = true });
local names = {};
for _, l in ipairs(lines) do table.insert(names, l.name or ""); end
check("collapsed", not string.find(table.concat(names, ","), "Stormwind") and not string.find(table.concat(names, ","), "Valiance")
	and string.find(table.concat(names, ","), "Alliance Vanguard"));

-- currency
local crows = {
	{ name = "Dungeon and Raid", isHeader = true }, { name = "Emblem of Frost", count = 3, isWatched = true },
	{ name = "Empty", isHeader = true },
	{ name = "Player vs. Player", isHeader = true }, { name = "Honor Points", count = 0, extra = 2, isWatched = true },
};
local cl = C.Lines(crows, {});
check("currency lines", #cl == 4 and cl[1].kind == "group" and cl[2].row.name == "Emblem of Frost" and cl[3].name == "Player vs. Player");
cl = C.Lines(crows, { ["Dungeon and Raid"] = true });
check("currency collapsed", #cl == 3 and cl[1].collapsed and cl[2].name == "Player vs. Player");
check("currency watched", C.Watched(crows) == 2);

-- journeys
local hl = J.Highlights(t);
check("highlights marked", #hl == 2 and hl[1].level == 1 and hl[2].level == 3);
check("highlights by title", #J.Highlights(L.tracks[1073]) == 0);
check("page start", J.PageStart(1, 8) == 1 and J.PageStart(8, 8) == 1 and J.PageStart(9, 8) == 9 and J.PageStart(0, 8) == 1);
check("reward text", J.RewardText(t.levels[3]) == "Title: the Argent Champion" and J.RewardText(t.levels[1]) == nil);
check("find journey", J.Find("argent").faction == 1106 and J.Find("The Kalu'ak").faction == 1073 and J.Find("nope") == nil);

print(failed == 0 and "all passed" or (failed.." failed"));
os.exit(failed == 0 and 0 or 1);
