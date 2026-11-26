-- Temucraft Achievements window (retail-style, like Dragonflight's achievement frame, for 3.3.5): it takes the place
-- of the stock AchievementFrame (Blizzard_AchievementUI, load on demand). Same look as our other windows
-- (TemucraftStyle.lua) with the stock achievement art for the rows (parchment, title bar, icon frame, points shield).
--   Top     your achievement points, the Achievements / Statistics tabs, the filter (All / Completed / Incomplete)
--           and a search box (achievement names, descriptions and rewards in every category).
--   Left    the category tree: Summary, then each category with a progress bar ("12/40"); a category with
--           subcategories opens and closes with a click (only one open at a time, like retail).
--   Right   Summary: recent achievements, overall progress and a bar per category. A category: its achievements
--           (icon, points shield, name, description, date, reward). A click opens one: criteria with checks,
--           progress bars, the achievements a meta asks for (click: go there), the steps of a series. Shift-click:
--           track it in the quest tracker (up to 10; DragonUI's, Questie's or the stock one), or link it while
--           typing in chat. Statistics: the same tree with the statistics categories, a value per row.
-- Comparing with another player (right-click menu "Compare Achievements", InspectAchievements) shows their date or
-- "Incomplete" on every row, their points, their bars and their statistics beside yours.
-- 3.3.5 has no guild achievements and no account-wide ones (GetAchievementInfo has no "earned by" or account flag),
-- so there is no Guild tab and no "Earned by" filter.
-- Blizzard_AchievementUI still loads (the alerts, the Classic window): its AchievementFrame_ToggleAchievementFrame,
-- _SelectAchievement and _DisplayComparison open this window instead, so the micro button, the key, the quest
-- tracker, the "achievement earned" alert and chat links all land here. "Classic achievements window" (/tui) keeps
-- the stock one; Krowi_AchievementFilter or Overachiever, when loaded, are left alone too.
--   /achievements (/tach)   opens or closes it

----------------------------------------------------------------------------------------------------------------------
-- The logic (no frames: tests/achievements_test.lua runs it with stubs)
----------------------------------------------------------------------------------------------------------------------
TemucraftAchievementsLogic = {};
local L = TemucraftAchievementsLogic;

L.MAX_TRACKED = 10;                 -- WATCHFRAME_MAXACHIEVEMENTS
L.FEAT_OF_STRENGTH = 81;
L.CRITERIA_TYPE_ACHIEVEMENT = 8;    -- a meta achievement's criteria: another achievement (assetID)
L.CRITERIA_PROGRESS_BAR = 1;        -- criteria flag: show as a bar
L.FLAG_HAS_PROGRESS_BAR = 128;      -- achievement flag (ACHIEVEMENT_FLAGS_HAS_PROGRESS_BAR)
L.FILTERS = { "all", "complete", "incomplete" };

-- flags has the bit f (a power of two); no bit library in the tests
function L.Has(flags, f)
	return math.floor((flags or 0) / f) % 2 == 1;
end

-- the category tree from GetCategoryList() (ids in the client's order) and info(id) -> name, parent (-1: top level).
-- Returns { top = { node }, byId = { [id] = node } }, node = { id, name, parent (nil on top), children = { node } }.
-- Feats of Strength goes last, as in the stock window.
function L.Tree(ids, info)
	local byId, top = {}, {};
	for _, id in ipairs(ids or {}) do
		local name, parent = info(id);
		byId[id] = { id = id, name = name or ("#"..id), parent = (parent and parent ~= -1) and parent or nil, children = {} };
	end
	local feat;
	for _, id in ipairs(ids or {}) do
		local n = byId[id];
		if ( n.parent and byId[n.parent] ) then
			table.insert(byId[n.parent].children, n);
		else
			n.parent = nil;
			if ( id == L.FEAT_OF_STRENGTH ) then feat = n; else table.insert(top, n); end
		end
	end
	if ( feat ) then table.insert(top, feat); end
	return { top = top, byId = byId };
end

-- the rows of the tree: { id, name, depth (0 or 1), hasChildren, expanded, parent }; open = the open top category
-- (or one of its children's parent); summary = a "summary" row first
function L.Rows(tree, open, summary)
	local rows = {};
	if ( summary ) then table.insert(rows, { id = "summary", depth = 0 }); end
	for _, n in ipairs(tree.top) do
		local isOpen = open ~= nil and open == n.id;
		table.insert(rows, { id = n.id, name = n.name, depth = 0, hasChildren = #n.children > 0, expanded = isOpen and #n.children > 0 });
		if ( isOpen ) then
			for _, c in ipairs(n.children) do
				table.insert(rows, { id = c.id, name = c.name, depth = 1, parent = n.id });
			end
		end
	end
	return rows;
end

-- the top category a category sits under (itself on top), or nil
function L.TopOf(tree, id)
	local n = tree.byId[id];
	if ( not n ) then return nil; end
	return n.parent or n.id;
end

-- a category's progress with its subcategories: count(id) -> total, done
function L.Progress(tree, id, count)
	local total, done = count(id);
	total, done = total or 0, done or 0;
	local n = tree.byId[id];
	if ( n ) then
		for _, c in ipairs(n.children) do
			local t, d = count(c.id);
			total, done = total + (t or 0), done + (d or 0);
		end
	end
	return total, done;
end

-- the categories the Summary shows a bar for: the top ones but Feats of Strength
function L.SummaryCategories(tree)
	local out = {};
	for _, n in ipairs(tree.top) do
		if ( n.id ~= L.FEAT_OF_STRENGTH ) then table.insert(out, n); end
	end
	return out;
end

function L.PassFilter(completed, filter)
	if ( filter == "complete" ) then return completed and true or false; end
	if ( filter == "incomplete" ) then return not completed; end
	return true;
end

local function lower(s) return string.lower(s or ""); end

-- e = { name, description, reward }; text: what the search box has (plain, any case)
function L.Matches(e, text)
	local s = lower(text);
	s = string.gsub(s, "^%s+", ""); s = string.gsub(s, "%s+$", "");
	if ( s == "" ) then return true; end
	return string.find(lower(e.name), s, 1, true) ~= nil or string.find(lower(e.description), s, 1, true) ~= nil
		or string.find(lower(e.reward), s, 1, true) ~= nil;
end

-- entries (in order) that pass the filter and the search
function L.Select(entries, filter, text)
	local out = {};
	for _, e in ipairs(entries or {}) do
		if ( L.PassFilter(e.completed, filter) and L.Matches(e, text) ) then table.insert(out, e); end
	end
	return out;
end

-- every achievement the window lists: for each category (ids), num(cat) achievements, get(cat, i) -> GetAchievementInfo's
-- values. Each id once (first category wins).
function L.Collect(ids, num, get)
	local out, seen = {}, {};
	for _, cat in ipairs(ids or {}) do
		for i = 1, (num(cat) or 0) do
			local e = L.Entry(cat, get(cat, i));
			if ( e and not seen[e.id] ) then seen[e.id] = true; table.insert(out, e); end
		end
	end
	return out;
end

-- GetAchievementInfo's values -> an entry
function L.Entry(cat, id, name, points, completed, month, day, year, description, flags, icon, reward)
	if ( not id ) then return nil; end
	return { id = id, category = cat, name = name or "", points = points or 0, completed = completed and true or false,
		month = month, day = day, year = year, description = description or "", flags = flags or 0, icon = icon,
		reward = reward or "" };
end

-- shift-click on an achievement: "remove", "add", "full" (10 tracked) or "completed" (can't track a done one)
function L.TrackAction(isTracked, count, completed, max)
	if ( isTracked ) then return "remove"; end
	if ( (count or 0) >= (max or L.MAX_TRACKED) ) then return "full"; end
	if ( completed ) then return "completed"; end
	return "add";
end

-- a series up to id: { first, ..., id } (prev(id) -> the step before, or nil)
function L.Chain(id, prev)
	local list, guard = { id }, 0;
	local p = prev(id);
	while ( p and guard < 50 ) do
		table.insert(list, 1, p);
		p = prev(p);
		guard = guard + 1;
	end
	return list;
end

-- the points a series is worth up to id (the shield of a series shows them all)
function L.ChainPoints(id, prev, points)
	local total = 0;
	for _, step in ipairs(L.Chain(id, prev)) do total = total + (points(step) or 0); end
	return total;
end

-- which step of a series the window shows for id (the stock rule): an incomplete one goes back to the first incomplete
-- step, a completed one forward to the last completed step. completed(id), prev(id), nextOf(id) -> nextId, done
function L.ResolveSelect(id, completed, prev, nextOf)
	local guard = 0;
	if ( not completed(id) and prev(id) ) then
		local p = prev(id);
		while ( p and not completed(p) and guard < 50 ) do
			id = p; p = prev(id); guard = guard + 1;
		end
	elseif ( completed(id) ) then
		local n, done = nextOf(id);
		while ( n and done and guard < 50 ) do
			id = n; n, done = nextOf(id); guard = guard + 1;
		end
	end
	return id;
end

-- where id (or a step of its series) is in a list of entries
function L.IndexOf(list, id, prev, nextOf)
	for i, e in ipairs(list) do if ( e.id == id ) then return i; end end
	if ( prev ) then
		local chain = {};
		for _, step in ipairs(L.Chain(id, prev)) do chain[step] = true; end
		local n, guard = nextOf and nextOf(id), 0;
		while ( n and guard < 50 ) do chain[n] = true; n = nextOf(n); guard = guard + 1; end
		for i, e in ipairs(list) do if ( chain[e.id] ) then return i; end end
	end
	return nil;
end

-- how a criteria line shows: "meta" (another achievement), "bar" or "text"
function L.CriteriaKind(ctype, flags, assetID)
	if ( ctype == L.CRITERIA_TYPE_ACHIEVEMENT and assetID and assetID ~= 0 ) then return "meta"; end
	if ( L.Has(flags, L.CRITERIA_PROGRESS_BAR) ) then return "bar"; end
	return "text";
end

-- text criteria in columns: n lines -> columns (1 or 2), rows
function L.Columns(n)
	if ( n <= 3 ) then return 1, n; end
	return 2, math.ceil(n / 2);
end

-- a completion date (fmt: SHORTDATE; WoW's string.format takes its %2$d)
function L.Date(day, month, year, fmt)
	if ( not day or not month ) then return ""; end
	if ( fmt ) then
		local ok, text = pcall(string.format, fmt, day, month, year or 0);
		if ( ok ) then return text; end
	end
	return string.format("%d/%d/%02d", month, day, (year or 0) % 100);
end

-- the bar text of a category: "12/40", in comparison "12/40 (them 9)"
function L.BarText(done, total, theirs)
	local t = (done or 0).."/"..(total or 0);
	if ( theirs ) then t = t.."  |cff88ccff"..theirs.."|r"; end
	return t;
end

-- the list's scroll: how many entries fit at the end (heights: entry -> its height), at least one
function L.FitFromEnd(list, height, avail)
	local h, n = 0, 0;
	for i = #list, 1, -1 do
		local rh = height(list[i]);
		if ( h + rh > avail ) then break; end
		h = h + rh; n = n + 1;
	end
	return math.max(1, n);
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

----------------------------------------------------------------------------------------------------------------------
-- State
----------------------------------------------------------------------------------------------------------------------
local AF = "Interface\\AchievementFrame\\";
local WIDTH, HEIGHT, TREE_W = 840, 590, 220;
local TOP_Y, BODY_Y = -36, -80;
local CAT_H = 30;
local ROW_H, ROW_GAP = 84, 4;          -- a closed achievement row
local STAT_H = 22;
local DESC_W = 0;                       -- set once the content width is known
local NUM_ROWS = 8;
local MAX_TEXTS, MAX_METAS = 40, 16;    -- criteria shown in an opened row (two columns of 20; eight rows of metas)

local tab = "achievements";             -- "achievements" or "stats"
local category = { achievements = "summary", stats = nil };
local open = { achievements = nil, stats = nil };   -- the open top category of each tree
local filter = "all";
local searchText = "";
local selectedId, selectedHeight = nil, ROW_H;
local compare = nil;                    -- { unit, name } while comparing
local trees = {};                       -- by tab
local index = nil;                      -- every achievement (search), rebuilt after one is earned
local statIndex = nil;
local listEntries = {};
local Update, UpdateTree, UpdateList, UpdateSummary, UpdateStats, UpdateTop;

local function Tree(which)
	if ( not trees[which] ) then
		local ids = (which == "stats" and GetStatisticsCategoryList or GetCategoryList)() or {};
		trees[which] = L.Tree(ids, function(id) local name, parent = GetCategoryInfo(id); return name, parent; end);
		trees[which].ids = ids;
	end
	return trees[which];
end

local function Info(id) return GetAchievementInfo(id); end
local function Completed(id) return select(4, GetAchievementInfo(id)) and true or false; end
local function Points(id) return select(3, GetAchievementInfo(id)) or 0; end
local function Prev(id) return GetPreviousAchievement and GetPreviousAchievement(id) or nil; end
local function NextOf(id) if ( not GetNextAchievement ) then return nil; end return GetNextAchievement(id); end

local function CategoryEntries(cat)
	local out = {};
	if ( type(cat) ~= "number" ) then return out; end
	for i = 1, (GetCategoryNumAchievements(cat) or 0) do
		local e = L.Entry(cat, GetAchievementInfo(cat, i));
		if ( e ) then table.insert(out, e); end
	end
	return out;
end

local function Index()
	if ( not index ) then
		index = L.Collect(Tree("achievements").ids, function(c) return (GetCategoryNumAchievements(c)); end, GetAchievementInfo);
	end
	return index;
end
local function StatIndex()
	if ( not statIndex ) then
		statIndex = L.Collect(Tree("stats").ids, function(c) return (GetCategoryNumAchievements(c)); end, GetAchievementInfo);
	end
	return statIndex;
end

-- count functions for the bars: the stock window's totals (every step of a series), or in comparison what the
-- stock comparison counts, with the other player's
local function CountAll(id) local t, d = GetCategoryNumAchievements(id, true); return t, d; end
local function CountShown(id) local t, d = GetCategoryNumAchievements(id); return t, d; end
local function CountTheirs(id) local d = GetComparisonCategoryNumAchievements and GetComparisonCategoryNumAchievements(id); return 0, d or 0; end

local function NumTracked()
	-- Questie's tracker replaces GetNumTrackedAchievements: with true it counts its own; the stock one ignores it
	return (GetNumTrackedAchievements and GetNumTrackedAchievements(true)) or 0;
end

local function InsertLink(link)
	if ( not link ) then return false; end
	if ( ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() ) then return ChatEdit_InsertLink(link) and true or false; end
	return false;
end

local function ToggleTracking(id)
	local _, _, _, completed = GetAchievementInfo(id);
	local action = L.TrackAction(IsTrackedAchievement(id), NumTracked(), completed, WATCHFRAME_MAXACHIEVEMENTS or L.MAX_TRACKED);
	if ( action == "remove" ) then
		RemoveTrackedAchievement(id);
	elseif ( action == "full" ) then
		UIErrorsFrame:AddMessage(format(ACHIEVEMENT_WATCH_TOO_MANY or "You may only track %d achievements at a time.", WATCHFRAME_MAXACHIEVEMENTS or L.MAX_TRACKED), 1.0, 0.1, 0.1, 1.0);
		return;
	elseif ( action == "completed" ) then
		UIErrorsFrame:AddMessage(ERR_ACHIEVEMENT_WATCH_COMPLETED or "That achievement is already complete.", 1.0, 0.1, 0.1, 1.0);
		return;
	else
		AddTrackedAchievement(id);
	end
	if ( WatchFrame_Update ) then WatchFrame_Update(); end
	if ( Update ) then Update(); end
end

local function Tip(owner, title, text, anchor)
	GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT");
	GameTooltip:SetText(title);
	if ( text ) then GameTooltip:AddLine(text, 1, 1, 1, true); end
	GameTooltip:Show();
end

local function AchievementTooltip(owner, id)
	local _, name, points, completed, month, day, year, description = GetAchievementInfo(id);
	if ( not name ) then return; end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT");
	GameTooltip:SetText(name);
	if ( description and description ~= "" ) then GameTooltip:AddLine(description, 1, 1, 1, true); end
	if ( points and points > 0 ) then GameTooltip:AddLine(format("%d points", points), 1, 0.82, 0); end
	if ( completed ) then GameTooltip:AddLine(L.Date(day, month, year, SHORTDATE), 0.25, 0.75, 0.25);
	else GameTooltip:AddLine(INCOMPLETE or "Incomplete", 0.6, 0.6, 0.6); end
	GameTooltip:Show();
end

----------------------------------------------------------------------------------------------------------------------
-- The window
----------------------------------------------------------------------------------------------------------------------
local frame = CreateFrame("Frame", "TemucraftAchievementFrame", UIParent);
frame:SetWidth(WIDTH); frame:SetHeight(HEIGHT);
frame:EnableMouse(true);
frame:SetMovable(true);
frame:SetClampedToScreen(true);
frame:SetToplevel(true);
frame:Hide();
UIPanelWindows["TemucraftAchievementFrame"] = { area = "doublewide", pushable = 0, width = WIDTH, xoffset = 20, whileDead = 1 };
TemucraftStyle_Window(frame, ACHIEVEMENTS or "Achievements");
local close = CreateFrame("Button", "TemucraftAchievementFrameCloseButton", frame, "UIPanelCloseButton");
close:SetPoint("TOPRIGHT", -6, -6);
local drag = CreateFrame("Frame", nil, frame);
drag:SetPoint("TOPLEFT", 12, -8); drag:SetPoint("TOPRIGHT", -40, -8); drag:SetHeight(26);
drag:EnableMouse(true);
drag:RegisterForDrag("LeftButton");
drag:SetScript("OnDragStart", function() frame:StartMoving(); end);
drag:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); end);

local function Inset(parent)
	local f = CreateFrame("Frame", nil, parent);
	TemucraftStyle_Inset(f);
	return f;
end

local function Bar(parent, height)
	local b = CreateFrame("StatusBar", nil, parent);
	b:SetHeight(height);
	b:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
	b:SetStatusBarColor(0.0, 0.6, 0.1);
	b:SetMinMaxValues(0, 1); b:SetValue(0);
	local bg = b:CreateTexture(nil, "BACKGROUND");
	bg:SetAllPoints(); bg:SetTexture(0, 0, 0, 0.6);
	local border = CreateFrame("Frame", nil, b);
	border:SetPoint("TOPLEFT", -3, 3); border:SetPoint("BOTTOMRIGHT", 3, -3);
	border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 9 });
	border:SetBackdropBorderColor(0.78, 0.62, 0.3, 1);
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.text:SetPoint("CENTER", 0, 1);
	return b;
end

local function SetBar(bar, done, total)
	bar:SetMinMaxValues(0, math.max(1, total or 0));
	bar:SetValue(done or 0);
end

-- [[ top: points, tabs, comparison, filter, search ]] --
local top = Inset(frame);
top:SetPoint("TOPLEFT", 16, TOP_Y); top:SetPoint("TOPRIGHT", -16, TOP_Y); top:SetHeight(40);
local shield = top:CreateTexture(nil, "ARTWORK");
shield:SetTexture(AF.."UI-Achievement-Shields");
shield:SetTexCoord(0, 0.5, 0, 0.45);
shield:SetWidth(36); shield:SetHeight(32);
shield:SetPoint("LEFT", 8, 0);
local pointsText = top:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
pointsText:SetPoint("LEFT", shield, "RIGHT", 4, 0);
local pointsHit = CreateFrame("Frame", nil, top);
pointsHit:SetPoint("TOPLEFT", shield, "TOPLEFT"); pointsHit:SetPoint("BOTTOMRIGHT", pointsText, "BOTTOMRIGHT");
pointsHit:EnableMouse(true);
pointsHit:SetScript("OnEnter", function(self)
	local total, done = GetNumCompletedAchievements();
	Tip(self, ACHIEVEMENT_POINTS or "Achievement Points", format("%d of %d achievements earned.", done or 0, total or 0));
end);
pointsHit:SetScript("OnLeave", GameTooltip_Hide);

local tabs = {};
local function Tab(i, label, key)
	local b = CreateFrame("Button", nil, top);
	b:SetWidth(110); b:SetHeight(24);
	b:SetPoint("LEFT", 120 + (i - 1) * 116, 0);
	TemucraftStyle_Bar(b);
	TemucraftStyle_Highlight(b);
	b.glow = TemucraftStyle_Glow(b);
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	b.text:SetPoint("CENTER");
	b.text:SetText(label);
	b.key = key;
	b:SetScript("OnClick", function(self)
		PlaySound("igCharacterInfoTab");
		if ( tab == self.key ) then return; end
		tab = self.key;
		selectedId = nil;
		Update();
	end);
	tabs[i] = b;
	return b;
end
Tab(1, ACHIEVEMENTS or "Achievements", "achievements");
Tab(2, STATISTICS or "Statistics", "stats");

-- comparing: their name and points, and a button to stop
local compareText = top:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
compareText:SetPoint("LEFT", tabs[2], "RIGHT", 14, 0);
compareText:SetJustifyH("LEFT");
local compareStop = CreateFrame("Button", nil, top, "UIPanelButtonTemplate");
compareStop:SetWidth(60); compareStop:SetHeight(20);
compareStop:SetText(DONE or "Done");
compareStop:SetPoint("LEFT", compareText, "RIGHT", 8, 0);
compareStop:Hide();

local search = CreateFrame("EditBox", "TemucraftAchievementSearch", top, "InputBoxTemplate");
search:SetWidth(170); search:SetHeight(20);
search:SetPoint("RIGHT", -12, 0);
search:SetAutoFocus(false);
local searchIcon = search:CreateTexture(nil, "OVERLAY");
searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon");
searchIcon:SetWidth(14); searchIcon:SetHeight(14);
searchIcon:SetPoint("LEFT", -2, -1);
searchIcon:SetVertexColor(0.6, 0.6, 0.6);
search:SetTextInsets(12, 4, 0, 0);
local searchHint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
searchHint:SetPoint("LEFT", 14, 0);
searchHint:SetText(SEARCH or "Search");
search:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); end);
search:SetScript("OnTextChanged", function(self)
	local text = self:GetText() or "";
	if ( text == "" ) then searchHint:Show(); else searchHint:Hide(); end
	if ( text ~= searchText ) then
		searchText = text;
		selectedId = nil;
		if ( frame:IsShown() ) then Update(); end
	end
end);
search:SetScript("OnEditFocusGained", function() searchHint:Hide(); end);
search:SetScript("OnEditFocusLost", function(self) if ( (self:GetText() or "") == "" ) then searchHint:Show(); end end);

local FILTER_TEXT = {
	all = ACHIEVEMENTFRAME_FILTER_ALL or "All",
	complete = ACHIEVEMENTFRAME_FILTER_COMPLETED or "Completed",
	incomplete = ACHIEVEMENTFRAME_FILTER_INCOMPLETE or "Incomplete",
};
local filterDrop = CreateFrame("Frame", "TemucraftAchievementFilter", top, "UIDropDownMenuTemplate");
filterDrop:SetPoint("RIGHT", search, "LEFT", 0, -2);
UIDropDownMenu_SetWidth(filterDrop, 96);
local function SetFilter(value)
	filter = value;
	UIDropDownMenu_SetText(filterDrop, FILTER_TEXT[value]);
	if ( frame:IsShown() ) then Update(); end
end
UIDropDownMenu_Initialize(filterDrop, function()
	for _, value in ipairs(L.FILTERS) do
		local info = UIDropDownMenu_CreateInfo();
		info.text = FILTER_TEXT[value];
		info.value = value;
		info.checked = (filter == value) and 1 or nil;
		info.func = function(self) SetFilter(self.value); end;
		UIDropDownMenu_AddButton(info);
	end
end);
UIDropDownMenu_SetText(filterDrop, FILTER_TEXT[filter]);

-- [[ left: the category tree ]] --
local treeBox = Inset(frame);
treeBox:SetPoint("TOPLEFT", 16, BODY_Y); treeBox:SetPoint("BOTTOMLEFT", 16, 16); treeBox:SetWidth(TREE_W);
local treeScroll = CreateFrame("ScrollFrame", "TemucraftAchievementTreeScroll", treeBox, "FauxScrollFrameTemplate");
treeScroll:SetPoint("TOPLEFT", 6, -8); treeScroll:SetPoint("BOTTOMRIGHT", -28, 8);
local NUM_CATS = math.floor((HEIGHT + BODY_Y - 16 - 16) / CAT_H);
local catButtons = {};
local treeRows = {};

local function SelectCategory(row)
	PlaySound("igMainMenuOptionCheckBoxOn");
	if ( row.id ~= "summary" and row.depth == 0 and row.hasChildren ) then
		-- a top category opens (and the open one closes); clicking the open one again closes it
		if ( open[tab] == row.id and category[tab] == row.id ) then open[tab] = nil; else open[tab] = row.id; end
	elseif ( row.depth == 0 ) then
		open[tab] = nil;
	end
	category[tab] = row.id;
	selectedId = nil;
	searchText = ""; search:SetText(""); search:ClearFocus();
	local bar = _G["TemucraftAchievementListScrollScrollBar"];
	if ( bar ) then bar:SetValue(0); end
	bar = _G["TemucraftAchievementStatsScrollScrollBar"];
	if ( bar ) then bar:SetValue(0); end
	Update();
end

for i = 1, NUM_CATS do
	local b = CreateFrame("Button", nil, treeBox);
	b:SetHeight(CAT_H - 2);
	b:SetPoint("TOPLEFT", 8, -8 - (i - 1) * CAT_H);
	b:SetPoint("RIGHT", treeScroll, "RIGHT", 0, 0);
	b.bg = TemucraftStyle_Bar(b);
	b.glow = TemucraftStyle_Glow(b);
	TemucraftStyle_Highlight(b);
	b.expand = b:CreateTexture(nil, "ARTWORK");
	b.expand:SetWidth(12); b.expand:SetHeight(12);
	b.expand:SetPoint("TOPLEFT", 4, -4);
	b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	b.name:SetPoint("TOPLEFT", 18, -4);
	b.name:SetPoint("RIGHT", -6, 0);
	b.name:SetJustifyH("LEFT");
	b.bar = Bar(b, 7);
	b.bar:SetPoint("BOTTOMLEFT", 20, 5); b.bar:SetPoint("BOTTOMRIGHT", -46, 5);
	b.bar.text:Hide();
	b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.count:SetPoint("LEFT", b.bar, "RIGHT", 4, 0);
	b.count:SetPoint("RIGHT", -2, 0);
	b.count:SetJustifyH("RIGHT");
	b:SetScript("OnClick", function(self) if ( self.row ) then SelectCategory(self.row); end end);
	b:SetScript("OnEnter", function(self)
		local row = self.row;
		if ( not row ) then return; end
		if ( row.id == L.FEAT_OF_STRENGTH ) then
			Tip(self, row.name, FEAT_OF_STRENGTH_DESCRIPTION);
		elseif ( tab == "achievements" and self.total ) then
			Tip(self, self.name:GetText(), format("%d / %d completed", self.done or 0, self.total or 0)
				..(self.theirs and ("\n"..(compare and compare.name or "").." "..self.theirs) or ""));
		end
	end);
	b:SetScript("OnLeave", GameTooltip_Hide);
	catButtons[i] = b;
end
treeScroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, CAT_H, UpdateTree); end);

-- [[ right: the pages ]] --
local content = Inset(frame);
content:SetPoint("TOPLEFT", treeBox, "TOPRIGHT", 8, 0); content:SetPoint("BOTTOMRIGHT", -16, 16);
local CONTENT_W = WIDTH - 16 - TREE_W - 8 - 16;
local CONTENT_H = HEIGHT + BODY_Y - 16;
local summaryPage = CreateFrame("Frame", nil, content);
summaryPage:SetAllPoints();
local listPage = CreateFrame("Frame", nil, content);
listPage:SetAllPoints();
local statsPage = CreateFrame("Frame", nil, content);
statsPage:SetAllPoints();

-- [[ Summary ]] --
local recentTitle = summaryPage:CreateFontString(nil, "OVERLAY", "GameFontNormal");
recentTitle:SetPoint("TOPLEFT", 14, -12);
recentTitle:SetText(ACHIEVEMENT_SUMMARY_RECENT or "Recent Achievements");
TemucraftStyle_Header(recentTitle);
local recentEmpty = summaryPage:CreateFontString(nil, "OVERLAY", "GameFontDisable");
recentEmpty:SetPoint("TOP", 0, -60);
recentEmpty:SetText(NO_RECENT_ACHIEVEMENTS or "No recent achievements");
local recent = {};
for i = 1, 5 do
	local b = CreateFrame("Button", nil, summaryPage);
	b:SetHeight(42);
	b:SetPoint("TOPLEFT", 10, -34 - (i - 1) * 44); b:SetPoint("RIGHT", -10, 0);
	b:SetBackdrop({ bgFile = AF.."UI-Achievement-Parchment-Horizontal", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	b:SetBackdropBorderColor(0.7, 0.15, 0.05, 1);
	b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD");
	b:GetHighlightTexture():SetVertexColor(1, 0.82, 0, 0.25);
	b.icon = b:CreateTexture(nil, "ARTWORK");
	b.icon:SetWidth(32); b.icon:SetHeight(32);
	b.icon:SetPoint("LEFT", 6, 0);
	b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	b.name:SetTextColor(0.25, 0.12, 0); b.name:SetShadowOffset(0, 0);
	b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 8, -1);
	b.name:SetPoint("RIGHT", -110, 0); b.name:SetJustifyH("LEFT");
	b.desc = b:CreateFontString(nil, "OVERLAY", "GameFontBlackSmall");
	b.desc:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 8, 1);
	b.desc:SetPoint("RIGHT", -110, 0); b.desc:SetJustifyH("LEFT");
	b.shield = b:CreateTexture(nil, "ARTWORK");
	b.shield:SetTexture(AF.."UI-Achievement-Shields");
	b.shield:SetTexCoord(0, 0.5, 0, 0.45);
	b.shield:SetWidth(34); b.shield:SetHeight(30);
	b.shield:SetPoint("RIGHT", -8, 0);
	b.points = b:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	b.points:SetPoint("CENTER", b.shield, "CENTER", 0, 1);
	b.date = b:CreateFontString(nil, "OVERLAY", "GameFontBlackSmall");
	b.date:SetPoint("RIGHT", b.shield, "LEFT", -6, 0);
	b:SetScript("OnClick", function(self)
		if ( IsModifiedClick("CHATLINK") and InsertLink(GetAchievementLink(self.id)) ) then return; end
		TemucraftAchievements_Select(self.id);
	end);
	b:SetScript("OnEnter", function(self) AchievementTooltip(self, self.id); end);
	b:SetScript("OnLeave", GameTooltip_Hide);
	recent[i] = b;
end

local progressTitle = summaryPage:CreateFontString(nil, "OVERLAY", "GameFontNormal");
progressTitle:SetPoint("TOPLEFT", 14, -268);
progressTitle:SetText(ACHIEVEMENT_SUMMARY_CATEGORIES or "Progress Overview");
TemucraftStyle_Header(progressTitle);
local totalBar = Bar(summaryPage, 20);
totalBar:SetPoint("TOPLEFT", 24, -298); totalBar:SetPoint("TOPRIGHT", -24, -298);
local totalTheirs = Bar(summaryPage, 10);
totalTheirs:SetStatusBarColor(0.2, 0.5, 0.9);
totalTheirs:SetPoint("TOPLEFT", totalBar, "BOTTOMLEFT", 0, -4); totalTheirs:SetPoint("TOPRIGHT", totalBar, "BOTTOMRIGHT", 0, -4);
totalTheirs.text:SetFontObject(GameFontHighlightSmall);
local catBars = {};
local CB_W = math.floor((CONTENT_W - 24 * 2 - 16) / 2);
for i = 1, 8 do   -- four rows fit (the stock eight categories)
	local b = CreateFrame("Button", nil, summaryPage);
	b:SetWidth(CB_W); b:SetHeight(30);
	local col, row = (i - 1) % 2, math.floor((i - 1) / 2);
	b:SetPoint("TOPLEFT", 24 + col * (CB_W + 16), -340 - row * 34);
	b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.label:SetPoint("TOPLEFT", 0, 0); b.label:SetPoint("RIGHT", 0, 0); b.label:SetJustifyH("LEFT");
	b.bar = Bar(b, 12);
	b.bar:SetPoint("BOTTOMLEFT", 2, 3); b.bar:SetPoint("BOTTOMRIGHT", -2, 3);
	b.bar.text:SetFontObject(GameFontHighlightSmall);
	b:SetScript("OnClick", function(self)
		if ( not self.node ) then return; end
		SelectCategory({ id = self.node.id, depth = 0, hasChildren = #self.node.children > 0 });
	end);
	b:SetScript("OnEnter", function(self) if ( self.node ) then Tip(self, self.node.name, "Click to open this category."); end end);
	b:SetScript("OnLeave", GameTooltip_Hide);
	catBars[i] = b;
end

-- [[ the achievement list ]] --
local listTitle = listPage:CreateFontString(nil, "OVERLAY", "GameFontNormal");
listTitle:SetPoint("TOPLEFT", 14, -10);
listTitle:SetPoint("RIGHT", -120, 0); listTitle:SetJustifyH("LEFT");
local listCompare = listPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
listCompare:SetPoint("TOPRIGHT", -34, -12);
local listEmpty = listPage:CreateFontString(nil, "OVERLAY", "GameFontDisable");
listEmpty:SetPoint("TOP", 0, -80); listEmpty:SetWidth(CONTENT_W - 40);
local LIST_TOP = 30;
local LIST_AVAIL = CONTENT_H - LIST_TOP - 8;
local listScroll = CreateFrame("ScrollFrame", "TemucraftAchievementListScroll", listPage, "FauxScrollFrameTemplate");
listScroll:SetPoint("TOPLEFT", 6, -LIST_TOP); listScroll:SetPoint("BOTTOMRIGHT", -28, 8);
local ROW_W = CONTENT_W - 6 - 28 - 4;
DESC_W = ROW_W - 76 - 76;
local rows = {};

local function RowAt(i)
	if ( rows[i] ) then return rows[i]; end
	local b = CreateFrame("Button", "TemucraftAchievementRow"..i, listPage);
	b:SetWidth(ROW_W); b:SetHeight(ROW_H);
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	b:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } });
	b.bg = b:CreateTexture(nil, "BACKGROUND");
	b.bg:SetPoint("TOPLEFT", 3, -3); b.bg:SetPoint("BOTTOMRIGHT", -3, 3);
	b.titleBg = b:CreateTexture(nil, "BORDER");
	b.titleBg:SetTexture(AF.."UI-Achievement-Title");
	b.titleBg:SetHeight(24);
	b.titleBg:SetPoint("TOPLEFT", 5, -5); b.titleBg:SetPoint("TOPRIGHT", -5, -5);
	b.titleBg:SetAlpha(0.8);
	b.rewardBg = b:CreateTexture(nil, "BORDER");
	b.rewardBg:SetTexture(AF.."UI-Achievement-Reward-Background");
	b.rewardBg:SetTexCoord(0, 0.69, 0, 0.75);
	b.rewardBg:SetHeight(20);
	b.rewardBg:SetPoint("BOTTOMLEFT", 72, 5); b.rewardBg:SetPoint("BOTTOMRIGHT", -72, 5);
	b.reward = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	b.reward:SetPoint("CENTER", b.rewardBg, "CENTER", 0, 1);
	b.icon = b:CreateTexture(nil, "ARTWORK");
	b.icon:SetWidth(48); b.icon:SetHeight(48);
	b.icon:SetPoint("TOPLEFT", 14, -16);
	b.iconFrame = b:CreateTexture(nil, "OVERLAY");
	b.iconFrame:SetTexture(AF.."UI-Achievement-IconFrame");
	b.iconFrame:SetTexCoord(0, 0.5625, 0, 0.5625);
	b.iconFrame:SetWidth(68); b.iconFrame:SetHeight(68);
	b.iconFrame:SetPoint("CENTER", b.icon, "CENTER", -1, 2);
	b.shield = b:CreateTexture(nil, "ARTWORK");
	b.shield:SetWidth(60); b.shield:SetHeight(58);
	b.shield:SetPoint("TOPRIGHT", -8, -8);
	b.points = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	b.points:SetPoint("CENTER", b.shield, "CENTER", -1, 2);
	b.date = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.date:SetPoint("TOP", b.shield, "BOTTOM", -2, 6);
	b.theirs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.theirs:SetPoint("TOP", b.date, "BOTTOM", 0, -2);
	b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	b.label:SetPoint("TOP", b.titleBg, "TOP", 0, -4);
	b.check = b:CreateTexture(nil, "OVERLAY");
	b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check");
	b.check:SetWidth(18); b.check:SetHeight(16);
	b.check:SetPoint("LEFT", b.label, "RIGHT", 2, -1);
	b.plusMinus = b:CreateTexture(nil, "OVERLAY");
	b.plusMinus:SetTexture(AF.."UI-Achievement-PlusMinus");
	b.plusMinus:SetWidth(15); b.plusMinus:SetHeight(15);
	b.plusMinus:SetPoint("TOPLEFT", 72, -9);
	b.desc = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	b.desc:SetWidth(DESC_W);
	b.desc:SetPoint("TOP", 0, -32);
	b.desc:SetJustifyH("CENTER"); b.desc:SetJustifyV("TOP");
	b.track = CreateFrame("CheckButton", "TemucraftAchievementRow"..i.."Track", b, "UICheckButtonTemplate");
	b.track:SetWidth(18); b.track:SetHeight(18);
	b.track:SetPoint("TOPLEFT", 8, -62);
	_G[b.track:GetName().."Text"]:SetText(TRACK_ACHIEVEMENT or "Track");
	_G[b.track:GetName().."Text"]:SetFontObject(GameFontHighlightSmall);
	b.track:SetScript("OnClick", function(self) local id = self:GetParent().id; if ( id ) then ToggleTracking(id); end end);
	b.track:SetScript("OnEnter", function(self) Tip(self, TRACK_ACHIEVEMENT or "Track", format("Show it in the quest tracker (up to %d). Shift-click a row does the same.", L.MAX_TRACKED)); end);
	b.track:SetScript("OnLeave", GameTooltip_Hide);
	b.highlight = b:CreateTexture(nil, "HIGHLIGHT");
	b.highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2");
	b.highlight:SetBlendMode("ADD");
	b.highlight:SetVertexColor(1, 0.82, 0, 0.15);
	b.highlight:SetPoint("TOPLEFT", 4, -4); b.highlight:SetPoint("BOTTOMRIGHT", -4, 4);
	b:SetScript("OnClick", function(self, button)
		local e = self.entry;
		if ( not e ) then return; end
		if ( IsModifiedClick("CHATLINK") and InsertLink(GetAchievementLink(e.id)) ) then return; end
		if ( IsModifiedClick("QUESTWATCHTOGGLE") or button == "RightButton" ) then ToggleTracking(e.id); return; end
		PlaySound("igMainMenuOptionCheckBoxOn");
		if ( selectedId == e.id ) then selectedId = nil; else selectedId = e.id; end
		UpdateList();
	end);
	b:SetScript("OnEnter", function(self)
		if ( not self.entry ) then return; end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(self.entry.name);
		GameTooltip:AddLine("Click: criteria. Shift-click: track (or link while typing in chat). Right-click: track.", 0.6, 0.6, 0.6, true);
		GameTooltip:Show();
	end);
	b:SetScript("OnLeave", GameTooltip_Hide);
	rows[i] = b;
	return b;
end
for i = 1, NUM_ROWS do RowAt(i); end

-- the opened row's criteria (one frame, moved to the opened row like the stock "objectives")
local detail = CreateFrame("Frame", nil, listPage);
detail:Hide();
local critLines, critBars, critMetas, critMinis = {}, {}, {}, {};
local function CritLine(i)
	if ( critLines[i] ) then return critLines[i]; end
	local f = CreateFrame("Frame", nil, detail);
	f:SetHeight(15);
	f.check = f:CreateTexture(nil, "ARTWORK");
	f.check:SetTexture(AF.."UI-Achievement-Criteria-Check");
	f.check:SetTexCoord(0, 0.625, 0, 1);
	f.check:SetWidth(16); f.check:SetHeight(13);
	f.check:SetPoint("LEFT", 0, 0);
	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	f.text:SetPoint("LEFT", f.check, "RIGHT", 2, 0); f.text:SetPoint("RIGHT", 0, 0);
	f.text:SetJustifyH("LEFT");
	critLines[i] = f;
	return f;
end
local function CritBar(i)
	if ( critBars[i] ) then return critBars[i]; end
	local b = Bar(detail, 14);
	b:SetStatusBarTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar");
	b:SetStatusBarColor(0, 0.6, 0);
	critBars[i] = b;
	return b;
end
local function CritMeta(i)
	if ( critMetas[i] ) then return critMetas[i]; end
	local b = CreateFrame("Button", nil, detail);
	b:SetHeight(24);
	b.icon = b:CreateTexture(nil, "ARTWORK");
	b.icon:SetWidth(20); b.icon:SetHeight(20);
	b.icon:SetPoint("LEFT", 2, 0);
	b.border = b:CreateTexture(nil, "OVERLAY");
	b.border:SetTexture(AF.."UI-Achievement-Progressive-IconBorder");
	b.border:SetTexCoord(0, 0.65625, 0, 0.65625);
	b.border:SetWidth(28); b.border:SetHeight(28);
	b.border:SetPoint("CENTER", b.icon, "CENTER", 0, 0);
	b.check = b:CreateTexture(nil, "OVERLAY");
	b.check:SetTexture(AF.."UI-Achievement-Criteria-Check");
	b.check:SetTexCoord(0, 0.625, 0, 1);
	b.check:SetWidth(14); b.check:SetHeight(11);
	b.check:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 4, -2);
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0); b.text:SetPoint("RIGHT", 0, 0);
	b.text:SetJustifyH("LEFT");
	b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD");
	b:GetHighlightTexture():SetVertexColor(1, 0.82, 0, 0.3);
	b:SetScript("OnClick", function(self) if ( self.id ) then TemucraftAchievements_Select(self.id); end end);
	b:SetScript("OnEnter", function(self) if ( self.id ) then AchievementTooltip(self, self.id); end end);
	b:SetScript("OnLeave", GameTooltip_Hide);
	critMetas[i] = b;
	return b;
end
local function CritMini(i)
	if ( critMinis[i] ) then return critMinis[i]; end
	local b = CreateFrame("Button", nil, detail);
	b:SetWidth(36); b:SetHeight(40);
	b.icon = b:CreateTexture(nil, "ARTWORK");
	b.icon:SetWidth(28); b.icon:SetHeight(28);
	b.icon:SetPoint("TOP", 0, -2);
	b.border = b:CreateTexture(nil, "OVERLAY");
	b.border:SetTexture(AF.."UI-Achievement-Progressive-IconBorder");
	b.border:SetTexCoord(0, 0.65625, 0, 0.65625);
	b.border:SetWidth(38); b.border:SetHeight(38);
	b.border:SetPoint("CENTER", b.icon, "CENTER", 0, 0);
	b.points = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.points:SetPoint("BOTTOM", 0, 0);
	b:SetScript("OnEnter", function(self) if ( self.id ) then AchievementTooltip(self, self.id); end end);
	b:SetScript("OnLeave", GameTooltip_Hide);
	critMinis[i] = b;
	return b;
end

-- fills the detail frame for an entry; returns its height
local function BuildDetail(row, e)
	for _, t in ipairs({ critLines, critBars, critMetas, critMinis }) do for _, f in ipairs(t) do f:Hide(); end end
	detail:SetParent(row);
	detail:ClearAllPoints();
	detail:SetPoint("TOPLEFT", row.desc, "BOTTOMLEFT", 0, -6);
	detail:SetWidth(DESC_W);
	detail:SetFrameLevel(row:GetFrameLevel() + 2);
	local y = 0;
	local doneAch = e.completed;
	if ( doneAch and Prev(e.id) ) then
		-- a finished series: its steps
		local chain = L.Chain(e.id, Prev);
		local perRow = math.floor(DESC_W / 40);
		local count = math.min(#chain, perRow * 2);
		local left = (DESC_W - math.min(count, perRow) * 40) / 2;
		for i = 1, count do
			local id = chain[i];
			local _, _, points, _, _, _, _, _, _, icon = GetAchievementInfo(id);
			local m = CritMini(i);
			m.id = id;
			m.icon:SetTexture(icon);
			m.points:SetText(points and points > 0 and points or "");
			m:ClearAllPoints();
			m:SetPoint("TOPLEFT", detail, "TOPLEFT", left + ((i - 1) % perRow) * 40, -math.floor((i - 1) / perRow) * 44);
			m:Show();
		end
		y = math.ceil(count / perRow) * 44;
	else
		local texts, bars, metas = {}, {}, {};
		for i = 1, (GetAchievementNumCriteria(e.id) or 0) do
			local text, ctype, done, quantity, req, _, flags, assetID, quantityString = GetAchievementCriteriaInfo(e.id, i);
			local kind = L.CriteriaKind(ctype, flags, assetID);
			local c = { text = text or "", done = done, quantity = quantity, req = req, asset = assetID, qs = quantityString };
			if ( kind == "meta" ) then table.insert(metas, c);
			elseif ( kind == "bar" ) then table.insert(bars, c);
			else table.insert(texts, c); end
		end
		-- very long lists (Loremaster, the explorers) stay inside the window
		while ( #bars > 6 ) do table.remove(bars); end
		while ( #metas > MAX_METAS ) do table.remove(metas); end
		if ( #texts > MAX_TEXTS ) then
			local more = #texts - (MAX_TEXTS - 1);
			while ( #texts > MAX_TEXTS - 1 ) do table.remove(texts); end
			table.insert(texts, { text = format("... and %d more", more), done = false, more = true });
		end
		for i, c in ipairs(bars) do
			local b = CritBar(i);
			b:ClearAllPoints();
			b:SetWidth(math.min(DESC_W - 20, 280));
			b:SetPoint("TOP", detail, "TOP", 0, -y - 3);
			SetBar(b, c.quantity or 0, c.req or 1);
			b.text:SetText(c.qs or ((c.quantity or 0).." / "..(c.req or 0)));
			b:Show();
			y = y + 20;
		end
		if ( #metas > 0 ) then
			local half = math.floor(DESC_W / 2);
			for i, c in ipairs(metas) do
				local m = CritMeta(i);
				local _, name, _, done, _, _, _, _, _, icon = GetAchievementInfo(c.asset);
				m.id = c.asset;
				m.icon:SetTexture(icon);
				m.text:SetText(name or c.text);
				if ( done ) then
					m.check:Show(); m.icon:SetVertexColor(1, 1, 1);
					if ( doneAch ) then m.text:SetTextColor(0, 0, 0); m.text:SetShadowOffset(0, 0);
					else m.text:SetTextColor(0, 1, 0); m.text:SetShadowOffset(1, -1); end
				else
					m.check:Hide(); m.icon:SetVertexColor(0.55, 0.55, 0.55);
					m.text:SetTextColor(0.6, 0.6, 0.6); m.text:SetShadowOffset(1, -1);
				end
				m:SetWidth(half - 4);
				m:ClearAllPoints();
				m:SetPoint("TOPLEFT", detail, "TOPLEFT", ((i - 1) % 2) * half, -y - math.floor((i - 1) / 2) * 26);
				m:Show();
			end
			y = y + math.ceil(#metas / 2) * 26;
		end
		if ( #texts > 0 ) then
			local cols, perCol = L.Columns(#texts);
			local colW = math.floor(DESC_W / cols);
			for i, c in ipairs(texts) do
				local f = CritLine(i);
				f:SetWidth(colW - 4);
				f:ClearAllPoints();
				local col, r = math.floor((i - 1) / perCol), (i - 1) % perCol;
				f:SetPoint("TOPLEFT", detail, "TOPLEFT", col * colW + (cols == 1 and 40 or 0), -y - r * 15);
				local text = c.text;
				if ( c.req and c.req > 1 and not c.done and c.quantity ) then text = text.." ("..c.quantity.."/"..c.req..")"; end
				if ( c.more ) then
					f.check:Hide(); f.text:SetText(text);
					f.text:SetTextColor(0.6, 0.6, 0.6); f.text:SetShadowOffset(1, -1);
				elseif ( c.done ) then
					f.check:Show(); f.text:SetText(text);
					if ( doneAch ) then f.text:SetTextColor(0, 0, 0); f.text:SetShadowOffset(0, 0);
					else f.text:SetTextColor(0, 1, 0); f.text:SetShadowOffset(1, -1); end
				else
					f.check:Hide(); f.text:SetText("- "..text);
					f.text:SetTextColor(0.6, 0.6, 0.6); f.text:SetShadowOffset(1, -1);
				end
				f:Show();
			end
			y = y + perCol * 15;
		end
	end
	detail:SetHeight(math.max(1, y));
	if ( y > 0 ) then detail:Show(); else detail:Hide(); end
	return y;
end

local function HasMore(e)
	return (GetAchievementNumCriteria(e.id) or 0) > 0 or (e.completed and Prev(e.id) ~= nil);
end

-- one row: an entry, opened or not; returns its height
local function DrawRow(b, e)
	b.entry, b.id = e, e.id;
	local opened = selectedId == e.id;
	local tracked = IsTrackedAchievement and IsTrackedAchievement(e.id);
	b.label:SetText(e.name);
	b.icon:SetTexture(e.icon);
	local points = e.points;
	if ( Prev(e.id) ) then points = L.ChainPoints(e.id, Prev, Points); end
	b.points:SetText(points > 0 and points or "");
	b.shield:SetTexture(AF..(points > 0 and "UI-Achievement-Shields" or "UI-Achievement-Shields-NoPoints"));
	if ( e.reward ~= "" ) then b.reward:SetText(e.reward); b.reward:Show(); b.rewardBg:Show(); else b.reward:Hide(); b.rewardBg:Hide(); end
	if ( e.completed ) then
		b.bg:SetTexture(AF.."UI-Achievement-Parchment-Horizontal");
		b.titleBg:SetTexCoord(0, 0.9765625, 0, 0.3125);
		b:SetBackdropBorderColor(0.7, 0.15, 0.05, 1);
		b.icon:SetVertexColor(1, 1, 1); b.iconFrame:SetVertexColor(1, 1, 1);
		b.shield:SetTexCoord(0, 0.5, 0, 1);
		b.points:SetVertexColor(1, 1, 1);
		b.label:SetVertexColor(1, 1, 1);
		b.desc:SetTextColor(0, 0, 0); b.desc:SetShadowOffset(0, 0);
		b.reward:SetVertexColor(1, 0.82, 0);
		b.rewardBg:SetVertexColor(1, 1, 1);
		b.date:SetText(L.Date(e.day, e.month, e.year, SHORTDATE)); b.date:Show();
	else
		b.bg:SetTexture(AF.."UI-Achievement-Parchment-Horizontal-Desaturated");
		b.titleBg:SetTexCoord(0, 0.9765625, 0.34375, 0.65625);
		b:SetBackdropBorderColor(0.5, 0.5, 0.5, 1);
		b.icon:SetVertexColor(0.55, 0.55, 0.55); b.iconFrame:SetVertexColor(0.75, 0.75, 0.75);
		b.shield:SetTexCoord(0.5, 1, 0, 1);
		b.points:SetVertexColor(0.65, 0.65, 0.65);
		b.label:SetVertexColor(0.65, 0.65, 0.65);
		b.desc:SetTextColor(1, 1, 1); b.desc:SetShadowOffset(1, -1);
		b.reward:SetVertexColor(0.8, 0.8, 0.8);
		b.rewardBg:SetVertexColor(0.35, 0.35, 0.35);
		b.date:Hide();
	end
	-- comparing: their date or "Incomplete" under yours
	if ( compare and GetAchievementComparisonInfo ) then
		local done, month, day, year = GetAchievementComparisonInfo(e.id);
		local who = compare.name or "";
		if ( done ) then b.theirs:SetText("|cff88ccff"..who..":|r "..L.Date(day, month, year, SHORTDATE));
		else b.theirs:SetText("|cff88ccff"..who..":|r |cff999999"..(INCOMPLETE or "Incomplete").."|r"); end
		b.theirs:Show();
		if ( not e.completed ) then b.date:SetText("|cff999999"..(INCOMPLETE or "Incomplete").."|r"); b.date:Show(); end
	else
		b.theirs:Hide();
	end
	if ( tracked ) then b.check:Show(); else b.check:Hide(); end
	b.track:SetChecked(tracked and true or false);
	b.desc:SetText(e.description);
	local more = HasMore(e);
	if ( more ) then
		b.plusMinus:Show();
		local x = opened and 0.5 or 0;
		b.plusMinus:SetTexCoord(e.completed and 0 or 0.5, e.completed and 0.5 or 1, x, x + 0.5);
	else
		b.plusMinus:Hide();
	end
	local height = ROW_H;
	if ( opened ) then
		b.desc:SetHeight(0);   -- the whole text
		local descH = b.desc:GetHeight() or 14;
		local dh = BuildDetail(b, e);
		height = math.max(ROW_H, 32 + descH + (dh > 0 and dh + 10 or 0) + (e.reward ~= "" and 28 or 10));
		if ( not e.completed or tracked ) then b.track:Show(); else b.track:Hide(); end
		if ( height < 96 and b.track:IsShown() ) then height = 96; end
		selectedHeight = height;
	else
		b.desc:SetHeight(28);  -- two lines
		if ( tracked ) then b.track:Show(); else b.track:Hide(); end
		if ( detail:GetParent() == b ) then detail:Hide(); end
	end
	local coords = math.min(1, height / 256);
	b.bg:SetTexCoord(0, 1, 1 - coords, 1);
	b:SetHeight(height);
	return height;
end

-- [[ Statistics ]] --
local statsTitle = statsPage:CreateFontString(nil, "OVERLAY", "GameFontNormal");
statsTitle:SetPoint("TOPLEFT", 14, -10);
local statsCompare = statsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
statsCompare:SetPoint("TOPRIGHT", -34, -12);
local statsScroll = CreateFrame("ScrollFrame", "TemucraftAchievementStatsScroll", statsPage, "FauxScrollFrameTemplate");
statsScroll:SetPoint("TOPLEFT", 6, -LIST_TOP); statsScroll:SetPoint("BOTTOMRIGHT", -28, 8);
local NUM_STATS = math.floor(LIST_AVAIL / STAT_H);
local statRows = {};
local statLines = {};
local statsEmpty = statsPage:CreateFontString(nil, "OVERLAY", "GameFontDisable");
statsEmpty:SetPoint("TOP", 0, -80);
for i = 1, NUM_STATS do
	local b = CreateFrame("Button", nil, statsPage);
	b:SetHeight(STAT_H);
	b:SetPoint("TOPLEFT", 8, -LIST_TOP - (i - 1) * STAT_H);
	b:SetPoint("RIGHT", statsScroll, "RIGHT", 0, 0);
	b.bg = b:CreateTexture(nil, "BACKGROUND");
	b.bg:SetAllPoints();
	b.bg:SetTexture(AF.."UI-Achievement-Stat-Buttons");
	b.header = TemucraftStyle_Bar(b);
	b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.name:SetPoint("LEFT", 10, 0); b.name:SetPoint("RIGHT", -190, 0); b.name:SetJustifyH("LEFT");
	b.value = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.value:SetPoint("RIGHT", -100, 0); b.value:SetWidth(90); b.value:SetJustifyH("RIGHT");
	b.theirs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.theirs:SetPoint("RIGHT", -6, 0); b.theirs:SetWidth(90); b.theirs:SetJustifyH("RIGHT");
	b.theirs:SetTextColor(0.55, 0.8, 1);
	b:SetScript("OnClick", function(self)
		if ( self.id and IsModifiedClick("CHATLINK") ) then InsertLink(GetAchievementLink(self.id)); end
	end);
	b:SetScript("OnEnter", function(self)
		if ( not self.id ) then return; end
		local _, name, _, _, _, _, _, description = GetAchievementInfo(self.id);
		if ( description and description ~= "" and description ~= name ) then Tip(self, name, description); end
	end);
	b:SetScript("OnLeave", GameTooltip_Hide);
	statRows[i] = b;
end

----------------------------------------------------------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------------------------------------------------------
function UpdateTop()
	pointsText:SetText(GetTotalAchievementPoints and GetTotalAchievementPoints() or 0);
	for _, t in ipairs(tabs) do if ( t.key == tab ) then t.glow:Show(); else t.glow:Hide(); end end
	if ( compare ) then
		local theirs = GetComparisonAchievementPoints and GetComparisonAchievementPoints() or 0;
		compareText:SetText(format("Comparing with |cff88ccff%s|r  (%s points)", compare.name or "?", tostring(theirs)));
		compareText:Show(); compareStop:Show();
	else
		compareText:Hide(); compareStop:Hide();
	end
	if ( tab == "achievements" ) then filterDrop:Show(); else filterDrop:Hide(); end
end

function UpdateTree()
	local tree = Tree(tab);
	if ( tab == "stats" and not category.stats and tree.top[1] ) then category.stats = tree.top[1].id; end
	treeRows = L.Rows(tree, open[tab], tab == "achievements");
	FauxScrollFrame_Update(treeScroll, #treeRows, NUM_CATS, CAT_H);
	local offset = FauxScrollFrame_GetOffset(treeScroll);
	local count = compare and CountShown or CountAll;
	for i, b in ipairs(catButtons) do
		local row = treeRows[offset + i];
		b.row = row;
		if ( row ) then
			local name = row.id == "summary" and (ACHIEVEMENT_SUMMARY_CATEGORY or "Summary") or row.name;
			b.name:SetText(name);
			b.name:SetFontObject(row.depth == 0 and GameFontNormal or GameFontHighlightSmall);
			b:ClearAllPoints();
			b:SetPoint("TOPLEFT", 8 + row.depth * 12, -8 - (i - 1) * CAT_H);
			b:SetPoint("RIGHT", treeScroll, "RIGHT", 0, 0);
			b.bg:SetVertexColor(row.depth == 0 and 1 or 0.6, row.depth == 0 and 1 or 0.6, row.depth == 0 and 1 or 0.6);
			if ( row.hasChildren ) then
				b.expand:SetTexture(row.expanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up");
				b.expand:Show();
			else
				b.expand:Hide();
			end
			if ( category[tab] == row.id ) then b.glow:Show(); else b.glow:Hide(); end
			b.total, b.done, b.theirs = nil, nil, nil;
			if ( tab == "achievements" and row.id ~= L.FEAT_OF_STRENGTH ) then
				local total, done;
				if ( row.id == "summary" ) then
					if ( compare ) then total, done = GetCategoryNumAchievements(-1); else total, done = GetNumCompletedAchievements(); end
				elseif ( row.depth == 0 ) then
					total, done = L.Progress(tree, row.id, count);
				else
					total, done = count(row.id);
				end
				local theirs;
				if ( compare ) then
					if ( row.id == "summary" ) then theirs = select(2, CountTheirs(-1));
					elseif ( row.depth == 0 ) then theirs = select(2, L.Progress(tree, row.id, CountTheirs));
					else theirs = select(2, CountTheirs(row.id)); end
				end
				b.total, b.done, b.theirs = total or 0, done or 0, theirs;
				SetBar(b.bar, done or 0, total or 0);
				b.bar:Show();
				b.count:SetText(L.BarText(done, total, theirs));
				b.name:SetPoint("TOPLEFT", 18, -3);
			elseif ( row.id == L.FEAT_OF_STRENGTH ) then
				b.bar:Hide();
				b.count:SetText(select(2, GetCategoryNumAchievements(row.id)) or "");
				b.name:SetPoint("TOPLEFT", 18, -8);
			else
				b.bar:Hide();
				b.count:SetText("");
				b.name:SetPoint("TOPLEFT", 18, -8);
			end
			b.expand:ClearAllPoints();
			b.expand:SetPoint("TOPLEFT", 4, b.bar:IsShown() and -4 or -8);
			b:Show();
		else
			b:Hide();
		end
	end
end

function UpdateSummary()
	local list = { GetLatestCompletedAchievements() };
	for i, b in ipairs(recent) do
		local id = list[i];
		local name, points, completed, month, day, year, description, icon;
		if ( id ) then _, name, points, completed, month, day, year, description, _, icon = GetAchievementInfo(id); end
		if ( id and name ) then
			b.id = id;
			b.icon:SetTexture(icon);
			b.name:SetText(name);
			b.desc:SetText(description);
			b.points:SetText(points and points > 0 and points or "");
			b.shield:SetTexture(AF..((points or 0) > 0 and "UI-Achievement-Shields" or "UI-Achievement-Shields-NoPoints"));
			b.date:SetText(completed and L.Date(day, month, year, SHORTDATE) or "");
			b:Show();
		else
			b:Hide(); b.id = nil;
		end
	end
	if ( #list == 0 ) then recentEmpty:Show(); else recentEmpty:Hide(); end
	local total, done = GetNumCompletedAchievements();
	SetBar(totalBar, done or 0, total or 0);
	totalBar.text:SetText(format("%s  %d / %d", ACHIEVEMENTS_COMPLETED or "Achievements Earned", done or 0, total or 0));
	if ( compare ) then
		local _, theirs = CountTheirs(-1);
		local shownTotal = GetCategoryNumAchievements(-1);
		SetBar(totalTheirs, theirs or 0, shownTotal or total or 0);
		totalTheirs.text:SetText((compare.name or "").."  "..(theirs or 0));
		totalTheirs:Show();
	else
		totalTheirs:Hide();
	end
	local tree = Tree("achievements");
	local cats = L.SummaryCategories(tree);
	for i, b in ipairs(catBars) do
		local n = cats[i];
		b.node = n;
		if ( n ) then
			local t, d = L.Progress(tree, n.id, compare and CountShown or CountAll);
			b.label:SetText(n.name);
			SetBar(b.bar, d, t);
			local theirs = compare and select(2, L.Progress(tree, n.id, CountTheirs)) or nil;
			b.bar.text:SetText(L.BarText(d, t, theirs));
			b:Show();
		else
			b:Hide();
		end
	end
end

local listOffset = 0;
function UpdateList(fromScroll)
	local searching = (searchText or "") ~= "";
	local list;
	if ( searching ) then
		list = L.Select(Index(), filter, searchText);
		listTitle:SetText(format("Search: \"%s\"  (%d)", searchText, #list));
	else
		list = L.Select(CategoryEntries(category.achievements), filter, "");
		local name = type(category.achievements) == "number" and GetCategoryInfo(category.achievements) or "";
		local parentNode = Tree("achievements").byId[category.achievements];
		if ( parentNode and parentNode.parent ) then
			name = (GetCategoryInfo(parentNode.parent) or "").." - "..(name or "");
		end
		listTitle:SetText(name or "");
	end
	listEntries = list;
	if ( compare ) then listCompare:SetText("|cffffd100"..(UnitName("player") or "").."|r  /  |cff88ccff"..(compare.name or "").."|r"); listCompare:Show();
	else listCompare:Hide(); end
	local fit = L.FitFromEnd(list, function(e) return (e.id == selectedId and selectedHeight or ROW_H) + ROW_GAP; end, LIST_AVAIL);
	FauxScrollFrame_Update(listScroll, #list, fit, ROW_H);
	local offset = FauxScrollFrame_GetOffset(listScroll);
	listOffset = offset;
	local y = 0;
	detail:Hide();
	for i = 1, NUM_ROWS do
		local b = rows[i];
		local e = list[offset + i];
		if ( e and y < LIST_AVAIL ) then
			b:ClearAllPoints();
			b:SetPoint("TOPLEFT", listPage, "TOPLEFT", 8, -LIST_TOP - y);
			local h = DrawRow(b, e);
			if ( i > 1 and y + h > LIST_AVAIL ) then
				-- doesn't fit below the window: the next scroll step shows it
				b:Hide(); b.entry = nil; b.id = nil;
				y = LIST_AVAIL;
			else
				y = y + h + ROW_GAP;
				b:Show();
			end
		else
			b:Hide(); b.entry = nil; b.id = nil;
		end
	end
	if ( #list == 0 ) then
		listEmpty:SetText(searching and "No achievements match." or "No achievements here with this filter.");
		listEmpty:Show();
	else
		listEmpty:Hide();
	end
end

-- the statistics of a category, with a header per subcategory (the stock layout); while searching, every match
local function StatLines()
	local out = {};
	if ( (searchText or "") ~= "" ) then
		for _, e in ipairs(L.Select(StatIndex(), "all", searchText)) do table.insert(out, { id = e.id, name = e.name }); end
		return out, format("Search: \"%s\"  (%d)", searchText, #out);
	end
	local tree = Tree("stats");
	local cat = category.stats;
	if ( not cat ) then return out, ""; end
	local function Add(id, header)
		if ( header ) then table.insert(out, { header = true, name = GetCategoryInfo(id) }); end
		for i = 1, (GetCategoryNumAchievements(id) or 0) do
			local aid, name = GetAchievementInfo(id, i);
			if ( aid ) then table.insert(out, { id = aid, name = name }); end
		end
	end
	Add(cat, false);
	local n = tree.byId[cat];
	if ( n ) then for _, c in ipairs(n.children) do Add(c.id, true); end end
	local title = GetCategoryInfo(cat) or "";
	if ( n and n.parent ) then title = (GetCategoryInfo(n.parent) or "").." - "..title; end
	return out, title;
end

function UpdateStats()
	local title;
	statLines, title = StatLines();
	statsTitle:SetText(title or "");
	if ( compare ) then statsCompare:SetText("|cffffd100"..(UnitName("player") or "").."|r     |cff88ccff"..(compare.name or "").."|r"); statsCompare:Show();
	else statsCompare:Hide(); end
	FauxScrollFrame_Update(statsScroll, #statLines, NUM_STATS, STAT_H);
	local offset = FauxScrollFrame_GetOffset(statsScroll);
	for i, b in ipairs(statRows) do
		local s = statLines[offset + i];
		if ( s ) then
			b.id = s.id;
			if ( s.header ) then
				b.header:Show(); b.bg:Hide();
				b.name:SetFontObject(GameFontNormal);
				b.name:SetText(s.name or "");
				b.value:SetText(""); b.theirs:SetText("");
			else
				b.header:Hide(); b.bg:Show();
				if ( (offset + i) % 2 == 1 ) then
					b.bg:SetTexCoord(0, 1, 0.1875, 0.3671875); b.bg:SetBlendMode("BLEND"); b.bg:SetAlpha(1);
				else
					b.bg:SetTexCoord(0, 1, 0.375, 0.5390625); b.bg:SetBlendMode("ADD"); b.bg:SetAlpha(0.5);
				end
				b.name:SetFontObject(GameFontHighlightSmall);
				b.name:SetText(s.name or "");
				b.value:SetText(GetStatistic(s.id) or "--");
				if ( compare and GetComparisonStatistic ) then b.theirs:SetText(GetComparisonStatistic(s.id) or "--"); else b.theirs:SetText(""); end
			end
			b:Show();
		else
			b:Hide(); b.id = nil;
		end
	end
	if ( #statLines == 0 ) then statsEmpty:SetText((searchText or "") ~= "" and "No statistics match." or ""); statsEmpty:Show();
	else statsEmpty:Hide(); end
end

function Update()
	if ( not frame:IsShown() ) then return; end
	UpdateTop();
	UpdateTree();
	local searching = (searchText or "") ~= "";
	summaryPage:Hide(); listPage:Hide(); statsPage:Hide();
	if ( tab == "stats" ) then
		statsPage:Show(); UpdateStats();
	elseif ( category.achievements == "summary" and not searching ) then
		summaryPage:Show(); UpdateSummary();
	else
		listPage:Show(); UpdateList();
	end
end

listScroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, function() UpdateList(true); end); end);
statsScroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, STAT_H, UpdateStats); end);
local function Wheel(name, step)
	return function(_, delta)
		local bar = _G[name];
		if ( bar and bar:IsShown() ) then bar:SetValue(bar:GetValue() - delta * step); end
	end
end
listPage:EnableMouseWheel(true); listPage:SetScript("OnMouseWheel", Wheel("TemucraftAchievementListScrollScrollBar", ROW_H));
statsPage:EnableMouseWheel(true); statsPage:SetScript("OnMouseWheel", Wheel("TemucraftAchievementStatsScrollScrollBar", STAT_H * 3));
treeBox:EnableMouseWheel(true); treeBox:SetScript("OnMouseWheel", Wheel("TemucraftAchievementTreeScrollScrollBar", CAT_H * 2));

-- many events come at once (criteria updates while fighting): one redraw, at most twice a second
local dirty = CreateFrame("Frame");
dirty:Hide();
dirty.wait = 0;
dirty:SetScript("OnUpdate", function(self, elapsed)
	self.wait = self.wait - elapsed;
	if ( self.wait > 0 ) then return; end
	self:Hide();
	Update();
end);
local function Later(delay)
	if ( not frame:IsShown() ) then return; end
	if ( not dirty:IsShown() ) then dirty.wait = delay or 0; dirty:Show(); end
end

----------------------------------------------------------------------------------------------------------------------
-- Opening, selecting, comparing
----------------------------------------------------------------------------------------------------------------------
-- the stock comparison frame listens for INSPECT_ACHIEVEMENT_READY and redraws its own bars for the stock window's
-- category (which may be "summary"): it doesn't hear ours
local function StockCompareEvents(on)
	local f = _G.AchievementFrameComparison;
	if ( not f ) then return; end
	if ( on ) then f:RegisterEvent("INSPECT_ACHIEVEMENT_READY"); else f:UnregisterEvent("INSPECT_ACHIEVEMENT_READY"); end
end

local function StopCompare()
	if ( not compare ) then return; end
	compare = nil;
	if ( ClearAchievementComparisonUnit ) then ClearAchievementComparisonUnit(); end
	StockCompareEvents(true);
end
compareStop:SetScript("OnClick", function() StopCompare(); Update(); end);

local function Show()
	if ( not frame:IsShown() ) then ShowUIPanel(frame); end
	if ( not frame:IsShown() ) then frame:Show(); end   -- (a UI panel that did not fit)
end

-- scroll the list so that the selected entry is on top
local function ScrollTo(id)
	local i = L.IndexOf(listEntries, id, Prev, function(x) return (NextOf(x)); end);
	if ( not i ) then return; end
	if ( listEntries[i] ) then selectedId = listEntries[i].id; end
	local bar = _G["TemucraftAchievementListScrollScrollBar"];
	if ( bar ) then
		local _, max = bar:GetMinMaxValues();
		bar:SetValue(math.min((i - 1) * ROW_H, max or 0));
	end
	UpdateList();
end

function TemucraftAchievements_Select(id)
	if ( not id ) then return; end
	id = L.ResolveSelect(id, Completed, Prev, NextOf);
	local _, _, _, completed = GetAchievementInfo(id);
	if ( not L.PassFilter(completed, filter) ) then SetFilter("all"); end
	searchText = ""; search:SetText("");
	local tree = Tree("achievements");
	local cat = GetAchievementCategory and GetAchievementCategory(id);
	if ( cat and tree.byId[cat] ) then
		category.achievements = cat;
		local topId = L.TopOf(tree, cat);
		if ( topId and #tree.byId[topId].children > 0 ) then open.achievements = topId; end
	end
	tab = "achievements";
	selectedId = id;
	Show();
	Update();
	local bar = _G["TemucraftAchievementListScrollScrollBar"];
	if ( bar ) then bar:SetValue(0); end
	UpdateList();
	ScrollTo(id);
end

local function Toggle(stats)
	local want = stats and "stats" or "achievements";
	if ( frame:IsShown() and tab == want and not compare ) then HideUIPanel(frame); return; end
	StopCompare();
	tab = want;
	Show();
	Update();
end

local function Compare(unit)
	if ( not unit or not SetAchievementComparisonUnit ) then return; end
	StockCompareEvents(false);
	if ( ClearAchievementComparisonUnit ) then ClearAchievementComparisonUnit(); end
	SetAchievementComparisonUnit(unit);
	compare = { unit = unit, name = UnitName(unit) };
	tab = "achievements";
	if ( category.achievements == nil ) then category.achievements = "summary"; end
	Show();
	Update();
end

frame:SetScript("OnShow", function()
	PlaySound("AchievementMenuOpen");
	if ( UpdateMicroButtons ) then UpdateMicroButtons(); end
	Update();
end);
frame:SetScript("OnHide", function()
	PlaySound("AchievementMenuClose");
	StopCompare();
	if ( UpdateMicroButtons ) then UpdateMicroButtons(); end
end);

-- the micro button looks pressed while ours is open (the stock code only knows its own frame)
if ( hooksecurefunc and UpdateMicroButtons ) then
	hooksecurefunc("UpdateMicroButtons", function()
		if ( frame:IsShown() and AchievementMicroButton ) then AchievementMicroButton:SetButtonState("PUSHED", 1); end
	end);
end

----------------------------------------------------------------------------------------------------------------------
-- Taking the stock window's place
----------------------------------------------------------------------------------------------------------------------
local REPLACEMENTS = { "Krowi_AchievementFilter", "Overachiever" };
function TemucraftAchievements_IsActive()
	if ( TemucraftUI_IsClassic and TemucraftUI_IsClassic("achievements") ) then return false; end
	for _, name in ipairs(REPLACEMENTS) do
		if ( IsAddOnLoaded(name) ) then return false; end
	end
	return true;
end

-- something showed the stock frame anyway (ShowUIPanel(AchievementFrame)): ours instead, a frame later
local redirect = CreateFrame("Frame");
redirect:Hide();
redirect:SetScript("OnUpdate", function(self)
	self:Hide();
	if ( AchievementFrame and AchievementFrame:IsShown() and TemucraftAchievements_IsActive() ) then
		HideUIPanel(AchievementFrame);
		Show();
	end
end);

local hooked = false;
local function Hook()
	if ( hooked or not AchievementFrame_ToggleAchievementFrame ) then return; end
	hooked = true;
	local stockToggle, stockSelect, stockCompare = AchievementFrame_ToggleAchievementFrame, AchievementFrame_SelectAchievement, AchievementFrame_DisplayComparison;
	AchievementFrame_ToggleAchievementFrame = function(stats, ...)
		if ( TemucraftAchievements_IsActive() ) then Toggle(stats); return; end
		if ( frame:IsShown() ) then HideUIPanel(frame); end
		return stockToggle(stats, ...);
	end
	-- the quest tracker, the alert and DragonUI's tracker select an achievement this way
	AchievementFrame_SelectAchievement = function(id, forceSelect, ...)
		if ( TemucraftAchievements_IsActive() ) then TemucraftAchievements_Select(id); return; end
		return stockSelect(id, forceSelect, ...);
	end
	AchievementFrame_DisplayComparison = function(unit, ...)
		if ( TemucraftAchievements_IsActive() ) then
			if ( AchievementFrame:IsShown() ) then HideUIPanel(AchievementFrame); end
			Compare(unit);
			return;
		end
		if ( frame:IsShown() ) then HideUIPanel(frame); end
		return stockCompare(unit, ...);
	end
	AchievementFrame:HookScript("OnShow", function() if ( TemucraftAchievements_IsActive() ) then redirect:Show(); end end);
end

-- the "Achievement earned" alert: a click opens ours on that achievement (AlertFrames.lua shows the stock frame)
if ( AchievementAlertFrame_OnClick ) then
	local stockAlertClick = AchievementAlertFrame_OnClick;
	AchievementAlertFrame_OnClick = function(self, ...)
		if ( self and self.id and TemucraftAchievements_IsActive() ) then
			AchievementFrame_LoadUI();
			TemucraftAchievements_Select(self.id);
			return;
		end
		return stockAlertClick(self, ...);
	end
end

----------------------------------------------------------------------------------------------------------------------
-- Events, the option, /achievements
----------------------------------------------------------------------------------------------------------------------
local events = CreateFrame("Frame");
events:RegisterEvent("ADDON_LOADED");
events:RegisterEvent("PLAYER_LOGIN");
events:RegisterEvent("ACHIEVEMENT_EARNED");
events:RegisterEvent("CRITERIA_UPDATE");
events:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE");
events:RegisterEvent("INSPECT_ACHIEVEMENT_READY");
events:SetScript("OnEvent", function(self, event, a1)
	if ( event == "ADDON_LOADED" ) then
		if ( a1 == "Blizzard_AchievementUI" ) then Hook(); end
	elseif ( event == "PLAYER_LOGIN" ) then
		if ( IsAddOnLoaded("Blizzard_AchievementUI") ) then Hook(); end
	elseif ( event == "ACHIEVEMENT_EARNED" ) then
		index = nil;
		Later();
	elseif ( event == "INSPECT_ACHIEVEMENT_READY" ) then
		if ( compare ) then Later(); end
	else
		Later(0.5);
	end
end);

-- tracking from elsewhere (the tracker's own menus): the check marks follow
if ( hooksecurefunc ) then
	for _, name in ipairs({ "AddTrackedAchievement", "RemoveTrackedAchievement" }) do
		if ( _G[name] ) then hooksecurefunc(name, function() Later(); end); end
	end
end

if ( TemucraftUI_OnChange ) then
	TemucraftUI_OnChange("classicachievements", function(on) if ( on and frame:IsShown() ) then HideUIPanel(frame); end end);
end

SLASH_TEMUCRAFTACHIEVEMENTS1 = "/achievements";
SLASH_TEMUCRAFTACHIEVEMENTS2 = "/tach";
SlashCmdList["TEMUCRAFTACHIEVEMENTS"] = function(msg)
	if ( not TemucraftAchievements_IsActive() ) then
		if ( ToggleAchievementFrame ) then ToggleAchievementFrame(); end
		return;
	end
	if ( not IsAddOnLoaded("Blizzard_AchievementUI") and AchievementFrame_LoadUI ) then AchievementFrame_LoadUI(); end
	Toggle(msg == "stats" or msg == "statistics");
end;
function TemucraftAchievements_Toggle(stats) Toggle(stats); end
