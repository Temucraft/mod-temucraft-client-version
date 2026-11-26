-- Stub tests for the Achievements window logic (no client): lua5.1 client/tests/achievements_test.lua (from the module folder)
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
dofile(dir.."/Interface/FrameXML/Temucraft/TemucraftAchievements.lua");
local L = TemucraftAchievementsLogic;
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end

-- the category tree (GetCategoryList order, GetCategoryInfo -> name, parent)
local CATS = {
	[92] = { "General", -1 }, [96] = { "Quests", -1 }, [14861] = { "Classic", 96 }, [14862] = { "Burning Crusade", 96 },
	[81] = { "Feats of Strength", -1 }, [97] = { "Exploration", -1 }, [14777] = { "Eastern Kingdoms", 97 },
	[999] = { "Orphan", 12345 },
};
local ids = { 92, 96, 14861, 81, 14862, 97, 14777, 999 };
local tree = L.Tree(ids, function(id) return CATS[id][1], CATS[id][2]; end);
check("top categories in order, Feats of Strength last", #tree.top == 5 and tree.top[1].id == 92 and tree.top[2].id == 96
	and tree.top[3].id == 97 and tree.top[4].id == 999 and tree.top[5].id == 81);
check("children under their parent, in order", #tree.byId[96].children == 2 and tree.byId[96].children[1].id == 14861
	and tree.byId[96].children[2].id == 14862 and tree.byId[14861].parent == 96);
check("a category whose parent isn't listed goes on top", tree.byId[999].parent == nil);
check("top of a child, of a top one, of nothing", L.TopOf(tree, 14862) == 96 and L.TopOf(tree, 92) == 92 and L.TopOf(tree, 5) == nil);

local rows = L.Rows(tree, nil, true);
check("closed tree: summary and the five top rows", #rows == 6 and rows[1].id == "summary" and rows[3].id == 96 and rows[3].hasChildren and not rows[3].expanded);
rows = L.Rows(tree, 96, true);
check("an open category shows its children right under it", #rows == 8 and rows[3].expanded and rows[4].id == 14861 and rows[4].depth == 1
	and rows[5].id == 14862 and rows[5].parent == 96 and rows[6].id == 97);
rows = L.Rows(tree, 97, false);
check("statistics tree: no summary row; only one open", #rows == 6 and rows[1].id == 92 and rows[4].id == 14777);
check("opening one without children shows nothing more", #L.Rows(tree, 92, false) == 5);

-- per-category progress (with the subcategories)
local COUNT = { [96] = { 10, 4 }, [14861] = { 20, 15 }, [14862] = { 5, 0 }, [92] = { 3, 3 } };
local function count(id) local c = COUNT[id]; if ( c ) then return c[1], c[2]; end return 0, 0; end
local t, d = L.Progress(tree, 96, count);
check("progress sums the subcategories", t == 35 and d == 19);
t, d = L.Progress(tree, 92, count);
check("progress without subcategories", t == 3 and d == 3);
t, d = L.Progress(tree, 4242, count);
check("progress of an unknown category", t == 0 and d == 0);
local sc = L.SummaryCategories(tree);
check("summary bars: the top categories but Feats of Strength", #sc == 4 and sc[1].id == 92 and sc[4].id == 999);
check("bar text", L.BarText(3, 10) == "3/10" and string.find(L.BarText(3, 10, 7), "7", 1, true) ~= nil and L.BarText(nil, nil) == "0/0");

-- filter and search
local entries = {
	L.Entry(92, 6, "Level 10", 10, true, 5, 3, 9, "Reach level 10.", 0, "icon", ""),
	L.Entry(92, 7, "Level 20", 10, false, nil, nil, nil, "Reach level 20.", 0, "icon", ""),
	L.Entry(96, 503, "50 Quests Completed", 10, false, nil, nil, nil, "Complete 50 quests.", 0, "icon", "Title Reward: the Seeker"),
	L.Entry(81, 60001, "Realm First! Level 60 Mage", 0, true, 1, 1, 26, "First mage to 60.", 256, "icon", nil),
};
check("entry from GetAchievementInfo", entries[3].id == 503 and entries[3].category == 96 and entries[4].reward == ""
	and entries[1].completed == true and entries[2].completed == false and L.Entry(92, nil) == nil);
check("filter all", #L.Select(entries, "all", "") == 4);
local done = L.Select(entries, "complete", "");
check("filter completed", #done == 2 and done[1].id == 6 and done[2].id == 60001);
local todo = L.Select(entries, "incomplete", "");
check("filter incomplete", #todo == 2 and todo[1].id == 7 and todo[2].id == 503);
check("search by name, any case", #L.Select(entries, "all", "LEVEL") == 3);
check("search by description", #L.Select(entries, "all", "50 quests") == 1);
local byReward = L.Select(entries, "all", "seeker");
check("search by reward", #byReward == 1 and byReward[1].id == 503);
check("search is plain text (no patterns)", #L.Select(entries, "all", "level (") == 0 and #L.Select(entries, "all", "first!") == 1);
check("search ignores spaces around", #L.Select(entries, "all", "  mage  ") == 1);
check("search and filter together", #L.Select(entries, "incomplete", "level") == 1 and L.Select(entries, "incomplete", "level")[1].id == 7);
check("realm first flag", L.Has(entries[4].flags, 256) and not L.Has(entries[4].flags, 512) and not L.Has(0, 1));

-- every achievement for the search: each id once
local BYCAT = { [92] = { 6, 7 }, [96] = { 503, 6 }, [81] = {} };
local all = L.Collect({ 92, 96, 81 }, function(c) return #BYCAT[c]; end,
	function(c, i) local id = BYCAT[c][i]; return id, "A"..id, 10, false, nil, nil, nil, "", 0, nil, ""; end);
check("collect: every category, each id once", #all == 3 and all[1].id == 6 and all[2].id == 7 and all[3].id == 503 and all[1].category == 92);

-- tracking (10 at most, not a finished one)
check("track: add", L.TrackAction(false, 3, false) == "add");
check("track: the eleventh is refused", L.TrackAction(false, 10, false) == "full" and L.TrackAction(false, 9, false) == "add");
check("track: a finished one can't be tracked", L.TrackAction(false, 0, true) == "completed");
check("track: a tracked one is removed, even at the cap", L.TrackAction(true, 10, false) == "remove");
check("track: own cap", L.TrackAction(false, 5, false, 5) == "full" and L.MAX_TRACKED == 10);

-- series
local PREV = { [3] = 2, [2] = 1 };
local NEXT = { [1] = 2, [2] = 3 };
local DONE = { [1] = true, [2] = true };
local POINTS = { [1] = 10, [2] = 10, [3] = 20 };
local function prev(id) return PREV[id]; end
local function nextOf(id) local n = NEXT[id]; if ( n ) then return n, DONE[n] == true; end return nil; end
local function completed(id) return DONE[id] == true; end
local chain = L.Chain(3, prev);
check("series in order", #chain == 3 and chain[1] == 1 and chain[3] == 3 and #L.Chain(1, prev) == 1);
check("series points", L.ChainPoints(3, prev, function(id) return POINTS[id]; end) == 40);
check("select a completed step: the last completed one", L.ResolveSelect(1, completed, prev, nextOf) == 2);
check("select an incomplete step: itself when the one before is done", L.ResolveSelect(3, completed, prev, nextOf) == 3);
DONE[2] = nil;
check("select an incomplete step: back to the first incomplete", L.ResolveSelect(3, completed, prev, nextOf) == 2);
check("select outside a series: itself", L.ResolveSelect(99, completed, prev, nextOf) == 99);
local list = { { id = 7 }, { id = 2 }, { id = 9 } };
check("index of an entry", L.IndexOf(list, 9) == 3 and L.IndexOf(list, 5) == nil);
check("index of a series step through another step", L.IndexOf(list, 3, prev, nextOf) == 2 and L.IndexOf(list, 1, prev, nextOf) == 2);

-- criteria
check("criteria: meta", L.CriteriaKind(8, 0, 1234) == "meta" and L.CriteriaKind(8, 0, 0) == "text");
check("criteria: bar", L.CriteriaKind(0, 1, 0) == "bar" and L.CriteriaKind(27, 3, nil) == "bar");
check("criteria: text", L.CriteriaKind(27, 2, 0) == "text" and L.CriteriaKind(nil, nil, nil) == "text");
local cols, perCol = L.Columns(3);
check("three criteria: one column", cols == 1 and perCol == 3);
cols, perCol = L.Columns(7);
check("seven criteria: two columns of four", cols == 2 and perCol == 4);

-- dates and the list's scroll
check("date fallback", L.Date(3, 5, 9) == "5/3/09" and L.Date(nil, 5, 9) == "");
check("date with a format", L.Date(3, 5, 9, "%d.%d.%02d") == "3.5.09");
local hs = { 84, 84, 84, 300 };
check("fit from the end: a tall last row and one more", L.FitFromEnd({ 1, 2, 3, 4 }, function(i) return hs[i]; end, 400) == 2);
check("fit from the end: several", L.FitFromEnd({ 1, 2, 3 }, function(i) return hs[i]; end, 400) == 3);
check("fit from the end: never zero", L.FitFromEnd({ 4 }, function() return 999; end, 400) == 1 and L.FitFromEnd({}, function() return 1; end, 400) == 1);

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
