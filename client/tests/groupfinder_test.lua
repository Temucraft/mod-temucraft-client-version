-- Stub tests for the Group Finder and PvP window logic (no client): lua5.1 client/tests/groupfinder_test.lua (from the module folder)
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
dofile(dir.."/Interface/FrameXML/Temucraft/TemucraftGroupFinder.lua");
dofile(dir.."/Interface/FrameXML/Temucraft/TemucraftGroupFinderPvP.lua");
local L, P = TemucraftGroupFinderLogic, TemucraftGroupFinderPvPLogic;
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end

-- key bindings and the micro buttons
local none = function() return false; end
local classicPvp = function(which) return which == "pvp"; end
local classicLfg = function(which) return which == "lfg"; end
local MIN = { dungeons = 15, pvp = 10 };
local how, tab, page = L.Route("TOGGLELFGPARENT", none, 80, MIN);
check("I opens our Dungeon Finder", how == "ours" and tab == "pve" and page == "dungeons");
how, tab, page = L.Route("TOGGLECHARACTER4", none, 80, MIN);
check("H opens our PvP tab", how == "ours" and tab == "pvp" and page == "battlegrounds");
how, tab, page = L.Route("TOGGLELFRPARENT", none, 80, MIN);
check("the Raid Browser key opens our Raid Finder", how == "ours" and tab == "pve" and page == "raids");
check("Classic PvP: H opens the stock window, I stays ours",
	L.Route("TOGGLECHARACTER4", classicPvp, 80, MIN) == "stock" and L.Route("TOGGLELFGPARENT", classicPvp, 80, MIN) == "ours");
check("Classic group finder: I and the raid key go stock, H stays ours",
	L.Route("TOGGLELFGPARENT", classicLfg, 80, MIN) == "stock" and L.Route("TOGGLELFRPARENT", classicLfg, 80, MIN) == "stock"
	and L.Route("TOGGLECHARACTER4", classicLfg, 80, MIN) == "ours");
check("below the level nothing opens (as stock)", L.Route("TOGGLELFGPARENT", none, 14, MIN) == "none" and L.Route("TOGGLECHARACTER4", none, 9, MIN) == "none");
check("the raid browser has no level (as stock)", L.Route("TOGGLELFRPARENT", none, 1, MIN) == "ours");
check("level limits reached", L.Route("TOGGLELFGPARENT", none, 15, MIN) == "ours" and L.Route("TOGGLECHARACTER4", none, 10, MIN) == "ours");
check("unknown binding", L.Route("TOGGLEBAGS", none, 80, MIN) == nil);
check("toggle: closed -> show", L.ToggleAction(false, "pve", "dungeons", "pve", "dungeons") == "show");
check("toggle: same page -> hide", L.ToggleAction(true, "pve", "dungeons", "pve", "dungeons") == "hide");
check("toggle: other page -> switch", L.ToggleAction(true, "pve", "raids", "pve", "dungeons") == "switch"
	and L.ToggleAction(true, "pvp", "arena", "pve", "dungeons") == "switch");
check("toggle: the tab, any page (/pvp) -> hide", L.ToggleAction(true, "pvp", "arena", "pvp", nil) == "hide");

-- roles
local r = L.Roles(true, false, true, true, true, false);
check("roles your class can't do stay off", r.tank and not r.healer and not r.dps);
check("has a role", L.HasRole(r) and not L.HasRole(L.Roles(true, true, true, false, false, false)) and not L.HasRole(nil));
check("roles change only outside a queue", L.RolesChangeable(nil) and L.RolesChangeable("lfgparty")
	and not L.RolesChangeable("queued") and not L.RolesChangeable("rolecheck") and not L.RolesChangeable("proposal") and not L.RolesChangeable("listed"));

-- the Find Group button
local label, enabled, why = L.FindButton(nil, false, true, false, true, true);
check("solo: Find Group", label == "find" and enabled and why == nil);
label, enabled = L.FindButton(nil, true, true, false, true, true);
check("in a group: Join as Party", label == "party" and enabled);
label, enabled = L.FindButton("queued", false, true, false, false, false);
check("queued: Leave Queue, even without roles", label == "leave" and enabled);
label, enabled = L.FindButton("rolecheck", true, true, false, true, true);
check("role check: Leave Queue", label == "leave" and enabled);
label, enabled = L.FindButton("proposal", false, true, false, true, true);
check("during the proposal: the popup answers, not the button", label == "leave" and not enabled);
label, enabled = L.FindButton(nil, true, false, false, true, true);
check("not the leader: can't queue", not enabled);
label, enabled = L.FindButton("listed", false, true, false, true, true);
check("listed in the raid browser: can't queue", not enabled);
label, enabled = L.FindButton(nil, true, true, true, true, true);
check("the backfill offer is shown: answer it first", not enabled);
label, enabled, why = L.FindButton(nil, false, true, false, false, true);
check("no role picked", not enabled and why == "role");
label, enabled, why = L.FindButton(nil, false, true, false, true, false);
check("nothing ticked", not enabled and why == "choice");

-- the raid browser's list button
check("list me / list my group", L.ListButton(nil, false, true, true, true) == "listme" and L.ListButton(nil, true, true, true, false) == "listgroup");
label, enabled = L.ListButton("listed", false, true, true, true);
check("listed: unlist", label == "unlistme" and enabled and L.ListButton("listed", true, true, true, true) == "unlistgroup");
check("queued in the dungeon finder: can't list", select(2, L.ListButton("queued", false, true, true, true)) == false);
check("no raid ticked: can't list", select(2, L.ListButton(nil, false, true, false, true)) == false);
check("solo without a role: can't list", select(2, L.ListButton(nil, false, true, true, false)) == false);

-- random dungeons on offer
local randoms = {
	{ id = 258, name = "Random Classic Dungeon", minLevel = 15, maxLevel = 58, expansion = 0 },
	{ id = 259, name = "Random Burning Crusade Dungeon", minLevel = 59, maxLevel = 68, expansion = 1 },
	{ id = 262, name = "Random Lich King Heroic", minLevel = 80, maxLevel = 83, expansion = 2 },
	{ id = 285, name = "The Headless Horseman", minLevel = 78, maxLevel = 82, expansion = 0 },
};
local offer = L.RandomChoices(randoms, 80, 2);
check("level 80 sees the heroic and the holiday", #offer == 2 and offer[1].id == 262 and offer[2].id == 285);
offer = L.RandomChoices(randoms, 60, 0);
check("expansion too low hides Outland", #offer == 0);
offer = L.RandomChoices(randoms, 20, 2);
check("level 20 sees classic", #offer == 1 and offer[1].id == 258);

-- the specific list with a search
local names = { [-1] = "Classic Dungeons", [36] = "Deadmines", [43] = "Wailing Caverns", [-4] = "Wrath of the Lich King Normal",
	[202] = "Utgarde Keep", [204] = "The Nexus", [272] = "Maraudon - Purple Crystals" };
local groups = { [36] = -1, [43] = -1, [202] = -4, [204] = -4, [272] = -1 };
local ids = { -1, 36, 43, 272, -4, 202, 204 };
local nameOf = function(id) return names[id]; end
local groupOf = function(id) return groups[id]; end
local f = L.FilterList(ids, nameOf, groupOf, "");
check("no search: the whole list", #f == 7 and f[1] == -1 and f[7] == 204);
f = L.FilterList(ids, nameOf, groupOf, "nexus");
check("search keeps the dungeon and its header", #f == 2 and f[1] == -4 and f[2] == 204);
f = L.FilterList(ids, nameOf, groupOf, "CLASSIC");
check("a header that matches keeps its dungeons, any case", #f == 4 and f[1] == -1 and f[4] == 272);
f = L.FilterList(ids, nameOf, groupOf, "zzz");
check("nothing matches", #f == 0);
check("has a choice", L.HasChoice(ids, { [36] = true }, {}) and not L.HasChoice(ids, { [36] = true }, { [36] = 1 })
	and not L.HasChoice(ids, { [-1] = true }, {}) and not L.HasChoice({}, {}, {}));

-- the queue status
local t, h, d = L.Found(0, 1, 2);
check("found: tank yes, healer no, one damage", t == 1 and h == 0 and d == 1);
t, h, d = L.Found(1, 1, 3);
check("found nobody", t == 0 and h == 0 and d == 0);
t, h, d = L.Found(0, 0, 0);
check("all found", t == 1 and h == 1 and d == 3);
check("clock", L.Clock(0) == "0:00" and L.Clock(65) == "1:05" and L.Clock(3723) == "1:02:03" and L.Clock(-5) == "0:00" and L.Clock(nil) == "0:00");
check("money", L.Money(12345) == "1g 23s 45c" and L.Money(0) == "0c" and L.Money(10000) == "1g" and L.Money(250) == "2s 50c");

-- the raid browser's filter
local res = {
	{ name = "Tanky", className = "Warrior", comment = "ICC 10 alt", partyMembers = 0, isTank = true },
	{ name = "Healz", className = "Priest", comment = "", partyMembers = 0, isHealer = true, isDamage = true },
	{ name = "Raidlead", className = "Paladin", comment = "VoA 25 need all", partyMembers = 12 },
};
local function same(a, b) if ( #a ~= #b ) then return false; end for i = 1, #a do if ( a[i] ~= b[i] ) then return false; end end return true; end
check("browse: all", same(L.BrowseFilter(res, {}), { 1, 2, 3 }));
check("browse: groups", same(L.BrowseFilter(res, { kind = "groups" }), { 3 }));
check("browse: players", same(L.BrowseFilter(res, { kind = "players" }), { 1, 2 }));
check("browse: healers (groups stay)", same(L.BrowseFilter(res, { role = "healer" }), { 2, 3 }));
check("browse: damage players", same(L.BrowseFilter(res, { kind = "players", role = "dps" }), { 2 }));
check("browse: search names, comments, classes", same(L.BrowseFilter(res, { search = "voa" }), { 3 })
	and same(L.BrowseFilter(res, { search = "PRIEST" }), { 2 }) and same(L.BrowseFilter(res, { search = "tank" }), { 1 }));

-- the Adventure Guide link
local ag = { instances = { { id = 36, name = "Deadmines" }, { key = "tc1", id = 9001, name = "Lost City" }, { id = 349, name = "Maraudon" }, { id = 230, name = "Blackrock Depths" } } };
check("adventure guide by name", L.AdventureGuideId("Deadmines", ag) == 36 and L.AdventureGuideId("deadmines", ag) == 36);
check("adventure guide: a wing finds its instance", L.AdventureGuideId("Maraudon - Purple Crystals", ag) == 349
	and L.AdventureGuideId("Blackrock Depths - Upper City", ag) == 230);
check("adventure guide: its key when it has one", L.AdventureGuideId("Lost City", ag) == "tc1");
check("adventure guide: none", L.AdventureGuideId("Halls of Reflection", ag) == nil and L.AdventureGuideId("Deadmines", nil) == nil
	and L.AdventureGuideId(nil, ag) == nil);

-- PvP: the battleground list
local bgs = P.Battlegrounds({
	{ index = 1, name = "Alterac Valley", canEnter = true, id = 1 },
	{ index = 2, name = "Warsong Gulch", canEnter = true, isHoliday = true, id = 2 },
	{ index = 3, name = "Arathi Basin", canEnter = false, id = 3 },
	{ index = 4, name = "Random Battleground", canEnter = true, isRandom = true, id = 32 },
	{ index = 5, name = nil, canEnter = true },
});
check("random first, the holiday next, what you can't enter out", #bgs == 3 and bgs[1].index == 4 and bgs[2].index == 2 and bgs[3].index == 1);
check("battleground art", P.Art(2) == "Interface\\PVPFrame\\PvpBg-WarsongGulch" and P.Art(30, true) == "Interface\\PVPFrame\\PvpRandomBg"
	and P.Art(999) == "Interface\\PVPFrame\\PvpRandomBg");

-- PvP: queues
local q = P.Queues({
	{ index = 1, status = "queued", mapName = "Warsong Gulch", waited = 65, estimate = 120 },
	{ index = 2, status = "confirm", mapName = "Arathi Basin", expires = 80 },
	{ index = 3, status = "none" },
	{ index = 4, status = "active", mapName = "Eye of the Storm" },
	{ index = 5, status = "queued", mapName = "Nagrand Arena", teamSize = 2, registered = true, waited = 5 },
}, L.Clock);
check("queues: none left out", #q == 4);
check("queued with time and estimate", q[1].kind == "queued" and q[1].text == "In queue 1:05, about 2:00");
check("ready to enter with the time left", q[2].kind == "confirm" and q[2].text == "Ready to enter (1:20)");
check("in progress", q[3].kind == "active" and q[3].name == "Eye of the Storm");
check("arena queue named by size", q[4].name == "Rated 2v2");

-- PvP: arena points
check("arena points 5v5 at 1500 (season 8): 344", P.ArenaPoints(1500, 1500, 5, 8) == 344);
check("arena points 2v2 at 1500: 344 x 0.76", P.ArenaPoints(1500, 1500, 2, 8) == math.floor(344 * 0.76));
check("arena points old seasons under 1500", P.ArenaPoints(1000, 1000, 5, 3) == 234);
local p2200 = math.floor(1511.26 / (1 + 1639.28 * math.exp(-0.00412 * 2200)));
check("arena points 5v5 at 2200", P.ArenaPoints(2200, 2200, 5, 8) == p2200 and p2200 > 1000 and p2200 < 1511);
check("a personal rating 150 under the team's counts", P.ArenaPoints(2200, 2000, 3, 8) == math.floor(1511.26 / (1 + 1639.28 * math.exp(-0.00412 * 2000)) * 0.88)
	and P.ArenaPoints(2200, 2100, 3, 8) == math.floor(p2200 * 0.88));
local best, size, rows = P.ArenaWeek({
	{ size = 2, rating = 2000, personal = 2000, weekGames = 12, playerWeekGames = 12 },
	{ size = 3, rating = 2200, personal = 2200, weekGames = 8, playerWeekGames = 8 },
	{ size = 5, rating = 1800, personal = 1800, weekGames = 20, playerWeekGames = 4 },
}, 8);
check("the week: only teams with 10 games and 30% yours count", size == 2 and best == P.ArenaPoints(2000, 2000, 2, 8));
check("the week: what is missing", rows[2].need == 2 and rows[2].needYou == 0 and rows[3].need == 0 and rows[3].needYou == 2);
check("the week: no teams", P.ArenaWeek({}, 8) == 0);
check("win rate", P.WinRate(10, 6) == "60%" and P.WinRate(0, 0) == "-" and P.WinRate(3, 1) == "33%");
local sizes = { 3, nil, 2 };
local slots = P.TeamSlots(function(i) return sizes[i]; end);
check("team slots by size", slots[2] == 3 and slots[3] == 1 and slots[5] == nil);

-- /pvp
check("/pvp opens the window", P.Slash("") == "open" and P.Slash(nil) == "open" and P.Slash("arena") == "open");
check("/pvp flag keeps the old PvP flag toggle", P.Slash("flag") == "flag" and P.Slash(" Toggle ") == "flag"
	and P.Slash("on") == "on" and P.Slash("OFF") == "off");

print(failed == 0 and "all passed" or (failed.." failed"));
os.exit(failed == 0 and 0 or 1);
