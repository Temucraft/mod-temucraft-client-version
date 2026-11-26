-- Temucraft reputation window (retail look), with mod-temucraft-renown (TemucraftRenown.cpp, addon prefix TRN) for
-- Renown and account-wide ("Warband") reputation.
--   The list   factions under expansion headers you can collapse: Classic, The Burning Crusade, Wrath of the Lich
--              King, and our own groups (Allied Races, Mists of Pandaria, Cataclysm, Lost Lands, Crafting Orders;
--              TemucraftReputationData.lua says which faction goes where), Inactive last. A filter: All / Active /
--              Inactive / At War. Bars show "Renown N" (or "Level N") for factions with a Renown track, else the
--              standing with its value on mouse over; the tooltip says "Warband Reputation" for shared factions.
--   Details    on the right: description, At War, Move to Inactive, Show as Experience Bar (the stock
--              FactionToggleAtWar / SetFactionInactive / SetWatchedFactionIndex, with the stock frame's rules for
--              when each can be used) and View Renown (TemucraftRenown.lua's Journeys page).
-- It is the Reputation page of the character window (TemucraftCharacter.lua: one window for every tab, the same size
-- and place). The character window's Reputation tab, U and the stock Reputation tab open it; "Classic reputation
-- window" (/tui) opens the stock one.
-- 3.3.5 gives the interface no faction ids: factions are known by name (the server sends the names in the player's
-- locale; TemucraftReputationData.lua has the English ones). The window expands every stock header to read the whole
-- list and keeps its own collapsed / expanded state.
--
-- TemucraftReputationLogic also keeps the Renown tracks for TemucraftRenown.lua.

----------------------------------------------------------------------------------------------------------------------
-- The logic (no frames: tests/reputation_test.lua runs it with stubs)
----------------------------------------------------------------------------------------------------------------------
TemucraftReputationLogic = {};
local L = TemucraftReputationLogic;
L.PREFIX = "TRN";
local DATA = TemucraftReputationData or { names = {}, groups = {}, roots = {} };
L.DATA = DATA;

-- our groups and the stock expansion headers, in the order the list shows them (retail: newest first); stock headers
-- the client has that aren't here ("Other", ...) come after them, Inactive last
L.GROUPS = {
	{ key = "allied", name = "Allied Races" },
	{ key = "mists", name = "Mists of Pandaria" },
	{ key = "cata", name = "Cataclysm" },
	{ key = "wotlk", name = "Wrath of the Lich King" },
	{ key = "tbc", name = "The Burning Crusade" },
	{ key = "classic", name = "Classic" },
	{ key = "lostlands", name = "Lost Lands" },
	{ key = "crafting", name = "Crafting Orders" },
};
L.INACTIVE_NAME = "Inactive";
L.FILTERS = { { "all", "All" }, { "active", "Active" }, { "inactive", "Inactive" }, { "war", "At War" } };
local STANDINGS = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" };
L.STANDINGS = STANDINGS;
L.BAR_COLORS = {
	{ 0.8, 0.3, 0.22 }, { 0.8, 0.3, 0.22 }, { 0.75, 0.27, 0 }, { 0.9, 0.7, 0 },
	{ 0, 0.6, 0.1 }, { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 },
};
L.RENOWN_COLOR = { 0.0, 0.55, 0.95 };

L.server = nil;      -- { renown = bool, warband = bool } once the server said hello
L.tracks = {};       -- [faction] = { faction, name, label, base, desc, max, levels = { [n] = level } }
L.granted = {};      -- [faction] = { [level] = true }
L.warband = {};      -- [faction] = true
L.serverNames = {};  -- [name] = faction (the server's, in the player's locale)
local listeners = {};
local incoming = {};

function L.On(kind, func) listeners[kind] = listeners[kind] or {}; table.insert(listeners[kind], func); end
local function Fire(kind, ...) for _, f in ipairs(listeners[kind] or {}) do f(...); end end
local function Num(v) return tonumber(v) or 0; end

-- faction id of a name (the server's names first, then the English ones)
function L.IdOf(name)
	if ( not name ) then return nil; end
	return L.serverNames[name] or DATA.names[name];
end

function L.NameOf(id)
	for name, fid in pairs(L.serverNames) do if ( fid == id ) then return name; end end
	local track = L.tracks[id];
	if ( track and track.name and track.name ~= "" ) then return track.name; end
	for name, fid in pairs(DATA.names) do if ( fid == id ) then return name; end end
	return nil;
end

-- the record's fields, the last one taking the rest
function L.Fields(s, n)
	local out, pos = {}, 1;
	for i = 1, n - 1 do
		local at = string.find(s, "~", pos, true);
		if ( not at ) then out[i] = string.sub(s, pos); return out; end
		out[i] = string.sub(s, pos, at - 1);
		pos = at + 1;
	end
	out[n] = string.sub(s, pos);
	return out;
end

-- long records come in pieces: "+piece"..., then "=last"
function L.Feed(msg)
	if ( type(msg) ~= "string" or msg == "" ) then return nil; end
	local c = string.sub(msg, 1, 1);
	if ( c == "+" ) then L.partial = (L.partial or "")..string.sub(msg, 2); return nil; end
	if ( c == "=" ) then local r = (L.partial or "")..string.sub(msg, 2); L.partial = nil; return r; end
	L.partial = nil;
	return msg;
end

----------------------------------------------------------------------------------------------------------------------
-- Renown
----------------------------------------------------------------------------------------------------------------------
-- level reached at `standing` (the faction's whole standing, -42000 .. 42999, as GetFactionInfo's barValue), and the
-- progress to the next one: level, current, needed, isMax
function L.RenownLevel(track, standing)
	if ( not track or not track.max or track.max == 0 ) then return 0, 0, 1, false; end
	standing = tonumber(standing) or 0;
	local level = 0;
	for i = 1, track.max do
		local l = track.levels[i];
		if ( l and standing >= l.rep ) then level = i; else break; end
	end
	if ( level >= track.max ) then return track.max, 1, 1, true; end
	local low = level > 0 and track.levels[level].rep or (track.base or 0);
	local high = track.levels[level + 1].rep;
	local need = math.max(1, high - low);
	return level, math.max(0, math.min(need, standing - low)), need, false;
end

-- "got", "next" or "locked" for a level of a track (got = the server granted it, or it is reached and the server
-- hasn't said otherwise yet)
function L.LevelState(track, level, reached)
	local granted = L.granted[track.faction];
	if ( (granted and granted[level]) or level <= (reached or 0) ) then return "got"; end
	if ( level == (reached or 0) + 1 ) then return "next"; end
	return "locked";
end

-- the bar of a faction row: text, value, max, r, g, b
function L.BarInfo(row, standingText)
	local track = row.id and L.tracks[row.id];
	if ( track ) then
		local level, cur, need, isMax = L.RenownLevel(track, row.barValue);
		local c = L.RENOWN_COLOR;
		return (track.label or "Renown").." "..level, cur, need, c[1], c[2], c[3], isMax;
	end
	local c = L.BAR_COLORS[row.standing or 4] or L.BAR_COLORS[4];
	local max = (row.barMax or 0) - (row.barMin or 0);
	local value = (row.barValue or 0) - (row.barMin or 0);
	return standingText or STANDINGS[row.standing or 4] or "", value, math.max(1, max), c[1], c[2], c[3];
end

----------------------------------------------------------------------------------------------------------------------
-- The list
----------------------------------------------------------------------------------------------------------------------
function L.Matches(row, filter)
	if ( filter == "active" ) then return not row.inactive; end
	if ( filter == "inactive" ) then return row.inactive and true or false; end
	if ( filter == "war" ) then return row.atWar and true or false; end
	return true;
end

local ORDER = {};
for i, g in ipairs(L.GROUPS) do ORDER[g.key] = i; end

-- rows: the client's whole list, expanded ({ index, name, description, standing, barMin, barMax, barValue, atWar,
-- canToggleAtWar, isHeader, hasRep, isWatched, isChild, inactive }); returns the groups, in order:
-- { { key, name, items = { { kind = "faction"|"sub", row, children = { rows } } } } }
function L.Group(rows)
	local groups, byKey, stockOrder = {}, {}, 0;
	local topKey, topName, lastSub, lastSubKey;
	local function GroupFor(key, name)
		local g = byKey[key];
		if ( not g ) then
			g = { key = key, name = name, items = {} };
			if ( key == "inactive" ) then g.order = 10000;
			elseif ( ORDER[key] ) then g.order = ORDER[key];
			else stockOrder = stockOrder + 1; g.order = 100 + stockOrder; end
			byKey[key] = g;
			table.insert(groups, g);
		end
		if ( name and ORDER[key] and not g.localName ) then g.name = name; end
		return g;
	end
	for _, r in ipairs(rows) do
		r.id = L.IdOf(r.name);
		if ( r.isHeader and not r.isChild ) then
			-- a stock top header: Classic, The Burning Crusade, Wrath, Other, Inactive
			local root = r.id and DATA.roots[r.id];
			topKey = root or ("stock:"..(r.name or "?"));
			topName = r.name;
			if ( root ) then local g = GroupFor(root, r.name); g.localName = true; end
			lastSub, lastSubKey = nil, nil;
			if ( r.hasRep and not r.inactive ) then
				table.insert(GroupFor(topKey, topName).items, { kind = "faction", row = r });
			end
		else
			local key, name;
			if ( r.inactive ) then key, name = "inactive", L.INACTIVE_NAME;
			elseif ( r.id and DATA.groups[r.id] ) then key = DATA.groups[r.id];
			else key, name = topKey or "stock:?", topName; end
			if ( not name ) then
				for _, g in ipairs(L.GROUPS) do if ( g.key == key ) then name = g.name; end end
			end
			local g = GroupFor(key, name);
			if ( r.isHeader ) then
				local node = { kind = "sub", row = r, children = {} };
				table.insert(g.items, node);
				lastSub, lastSubKey = node, key;
			elseif ( r.isChild and lastSub and lastSubKey == key ) then
				table.insert(lastSub.children, r);
			else
				table.insert(g.items, { kind = "faction", row = r });
				if ( not r.isChild ) then lastSub, lastSubKey = nil, nil; end
			end
		end
	end
	table.sort(groups, function(a, b) return a.order < b.order; end);
	return groups;
end

-- the lines the window shows: { kind = "group"|"sub"|"faction", key, name, row, depth, collapsed }
function L.Flatten(groups, filter, collapsed)
	collapsed = collapsed or {};
	local out = {};
	for _, g in ipairs(groups) do
		if ( not (filter == "active" and g.key == "inactive") ) then
			local lines = {};
			for _, item in ipairs(g.items) do
				if ( item.kind == "sub" ) then
					local kids = {};
					for _, r in ipairs(item.children) do if ( L.Matches(r, filter) ) then table.insert(kids, r); end end
					local own = item.row.hasRep and L.Matches(item.row, filter);
					if ( own or #kids > 0 ) then
						local key = "sub:"..g.key..":"..(item.row.name or "");
						table.insert(lines, { kind = "sub", key = key, name = item.row.name, row = item.row, depth = 1, collapsed = collapsed[key] });
						if ( not collapsed[key] ) then
							for _, r in ipairs(kids) do table.insert(lines, { kind = "faction", name = r.name, row = r, depth = 2 }); end
						end
					end
				elseif ( L.Matches(item.row, filter) ) then
					table.insert(lines, { kind = "faction", name = item.row.name, row = item.row, depth = 1 });
				end
			end
			if ( #lines > 0 ) then
				table.insert(out, { kind = "group", key = g.key, name = g.name, depth = 0, collapsed = collapsed[g.key] });
				if ( not collapsed[g.key] ) then
					for _, line in ipairs(lines) do table.insert(out, line); end
				end
			end
		end
	end
	return out;
end

----------------------------------------------------------------------------------------------------------------------
-- The server's messages
----------------------------------------------------------------------------------------------------------------------
local HANDLERS = {};
HANDLERS.S = function(f)
	L.server = { renown = f[2] == "1", warband = f[3] == "1" };
	Fire("server");
end
-- T~faction~label~levels~name: a track (its levels follow)
HANDLERS.T = function(f, rec)
	f = L.Fields(rec, 5);
	local id = Num(f[2]);
	incoming[id] = { faction = id, label = (f[3] ~= "" and f[3]) or "Renown", max = Num(f[4]), name = f[5] or "", base = 0, desc = "", levels = {} };
	if ( f[5] and f[5] ~= "" ) then L.serverNames[f[5]] = id; end
end
-- TD~faction~base~description: level 0 (where the track starts and what it is about)
HANDLERS.TD = function(f, rec)
	f = L.Fields(rec, 4);
	local t = incoming[Num(f[2])];
	if ( t ) then t.base = Num(f[3]); t.desc = f[4] or ""; end
end
-- V~faction~level~reputation~type~reward~count~highlight~title~description
HANDLERS.V = function(f, rec)
	f = L.Fields(rec, 10);
	local t = incoming[Num(f[2])];
	if ( not t ) then return; end
	local level = Num(f[3]);
	t.levels[level] = { level = level, rep = Num(f[4]), type = f[5] or "none", reward = Num(f[6]), count = math.max(1, Num(f[7])),
		highlight = f[8] == "1", title = f[9] or "", desc = f[10] or "" };
end
HANDLERS.TE = function()
	L.tracks = {};
	for id, t in pairs(incoming) do
		local n = 0;
		while ( t.levels[n + 1] ) do n = n + 1; end
		t.max = n;
		if ( n > 0 ) then L.tracks[id] = t; end
	end
	incoming = {};
	Fire("tracks");
end
-- W~id,id,...: the account-wide factions
HANDLERS.W = function(f, rec)
	f = L.Fields(rec, 2);
	L.warband = {};
	for id in string.gmatch(f[2] or "", "%d+") do L.warband[tonumber(id)] = true; end
	Fire("warband");
end
-- P~faction~level,level,...: levels the server granted this character
HANDLERS.P = function(f, rec)
	f = L.Fields(rec, 3);
	local set = {};
	for level in string.gmatch(f[3] or "", "%d+") do set[tonumber(level)] = true; end
	L.granted[Num(f[2])] = set;
end
HANDLERS.PE = function() Fire("granted"); end
-- F~id=name^id=name...: faction names in the player's locale
HANDLERS.F = function(f, rec)
	f = L.Fields(rec, 2);
	for id, name in string.gmatch(f[2] or "", "(%d+)=([^%^]+)") do L.serverNames[name] = tonumber(id); end
end
HANDLERS.FE = function() Fire("names"); end
-- G~faction~level: a level just reached (its rewards given)
HANDLERS.G = function(f)
	local id, level = Num(f[2]), Num(f[3]);
	L.granted[id] = L.granted[id] or {};
	L.granted[id][level] = true;
	Fire("granted", id, level);
end
-- R: the tracks were reloaded, ask again
HANDLERS.R = function() Fire("reload"); end

function L.OnMessage(msg)
	local rec = L.Feed(msg);
	if ( not rec ) then return nil; end
	local f = L.Fields(rec, 10);
	local h = HANDLERS[f[1]];
	if ( not h ) then return nil; end
	h(f, rec);
	return f[1];
end

-- the tracks, sorted by name (for menus)
function L.TrackList()
	local list = {};
	for _, t in pairs(L.tracks) do table.insert(list, t); end
	table.sort(list, function(a, b) return (L.NameOf(a.faction) or "") < (L.NameOf(b.faction) or ""); end);
	return list;
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

----------------------------------------------------------------------------------------------------------------------
-- Reading the client's list
----------------------------------------------------------------------------------------------------------------------
local function Ask(text) SendAddonMessage(L.PREFIX, text, "WHISPER", UnitName("player")); end
L.Ask = Ask;

-- every stock header open (children first open more headers: repeat until none is collapsed)
local function ExpandAll()
	for pass = 1, 10 do
		local any = false;
		for i = GetNumFactions(), 1, -1 do
			local _, _, _, _, _, _, _, _, isHeader, isCollapsed = GetFactionInfo(i);
			if ( isHeader and isCollapsed ) then ExpandFactionHeader(i); any = true; end
		end
		if ( not any ) then return; end
	end
end

function L.ReadRows()
	ExpandAll();
	local rows = {};
	for i = 1, GetNumFactions() do
		local name, description, standing, barMin, barMax, barValue, atWar, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(i);
		if ( name ) then
			table.insert(rows, { index = i, name = name, description = description, standing = standing, barMin = barMin, barMax = barMax,
				barValue = barValue, atWar = atWar and true or false, canToggleAtWar = canToggleAtWar and true or false, isHeader = isHeader and true or false,
				hasRep = hasRep and true or false, isWatched = isWatched and true or false, isChild = isChild and true or false,
				inactive = IsFactionInactive(i) and true or false });
		end
	end
	return rows;
end

-- the client's index of a faction now (indices move when a faction becomes inactive)
function L.FindIndex(name)
	for i = 1, GetNumFactions() do
		if ( GetFactionInfo(i) == name ) then return i; end
	end
	return nil;
end

-- the faction's current row (for TemucraftRenown.lua)
function L.RowOf(id)
	local name = L.NameOf(id);
	local index = name and L.FindIndex(name);
	if ( not index ) then
		ExpandAll();
		index = name and L.FindIndex(name);
	end
	if ( not index ) then return nil; end
	local n, description, standing, barMin, barMax, barValue = GetFactionInfo(index);
	return { index = index, id = id, name = n, description = description, standing = standing, barMin = barMin, barMax = barMax, barValue = barValue };
end

local function StandingText(standing)
	return (GetText and GetText("FACTION_STANDING_LABEL"..(standing or 4), UnitSex("player"))) or STANDINGS[standing or 4];
end
L.StandingText = StandingText;

----------------------------------------------------------------------------------------------------------------------
-- The window
----------------------------------------------------------------------------------------------------------------------
local LIST_WIDTH = 430;
local NUM_ROWS, ROW_HEIGHT = 17, 24;

-- a page of the character window (its frame, header, close button, tabs and place); the title is its header
local frame = CreateFrame("Frame", "TemucraftReputationFrame", TemucraftCharacterFrame or UIParent);
frame:Hide();

-- the character window's inset box (TemucraftCharacter.lua), else a dark tooltip box
local function Panel(parent)
	if ( TemucraftCharacter_Panel ) then return TemucraftCharacter_Panel(parent); end
	local p = CreateFrame("Frame", nil, parent);
	p:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } });
	p:SetBackdropColor(0, 0, 0, 0.6);
	p:SetBackdropBorderColor(0.5, 0.45, 0.35, 0.9);
	return p;
end
L.Panel = Panel;

local listBox = Panel(frame);
listBox:SetPoint("TOPLEFT", 16, -64);
listBox:SetWidth(LIST_WIDTH); listBox:SetHeight(NUM_ROWS * ROW_HEIGHT + 12);

local detail = Panel(frame);
detail:SetPoint("TOPLEFT", listBox, "TOPRIGHT", 8, 0);
detail:SetPoint("BOTTOMRIGHT", -16, 24);

-- the filter
local filter, collapsed, selectedName = "all", {}, nil;
local filterMenu = CreateFrame("Frame", "TemucraftReputationFilterMenu", frame, "UIDropDownMenuTemplate");
-- over the list's left end (the window's gold header is in the middle)
filterMenu:SetPoint("BOTTOMLEFT", listBox, "TOPLEFT", 22, -2);
UIDropDownMenu_SetWidth(filterMenu, 110);
local Update;
local function FilterName(key) for _, f in ipairs(L.FILTERS) do if ( f[1] == key ) then return f[2]; end end return key; end
UIDropDownMenu_Initialize(filterMenu, function()
	for _, f in ipairs(L.FILTERS) do
		local info = UIDropDownMenu_CreateInfo();
		info.text = f[2];
		info.checked = (filter == f[1]);
		info.func = function() filter = f[1]; UIDropDownMenu_SetText(filterMenu, f[2]); Update(); end;
		UIDropDownMenu_AddButton(info);
	end
end);
UIDropDownMenu_SetText(filterMenu, FilterName(filter));
local filterLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
filterLabel:SetPoint("RIGHT", filterMenu, "LEFT", 14, 2);
filterLabel:SetText(FILTER or "Filter");

local scroll = CreateFrame("ScrollFrame", "TemucraftReputationScroll", listBox, "FauxScrollFrameTemplate");
scroll:SetPoint("TOPLEFT", 6, -6);
scroll:SetPoint("BOTTOMRIGHT", -28, 6);

local rows = {};
local lines = {};

local function ShowTooltip(self)
	local line = self.line;
	if ( not line or line.kind == "group" ) then return; end
	local r = line.row;
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText(r.name, 1, 0.82, 0);
	if ( r.hasRep or not r.isHeader ) then
		local track = r.id and L.tracks[r.id];
		if ( track ) then
			local level, cur, need, isMax = L.RenownLevel(track, r.barValue);
			GameTooltip:AddLine((track.label or "Renown").." "..level, 0.4, 0.75, 1);
			GameTooltip:AddLine(isMax and "Maximum reached" or ("Current Progress: "..cur.." / "..need), 1, 1, 1);
			GameTooltip:AddLine(StandingText(r.standing).." ("..(r.barValue - r.barMin).." / "..(r.barMax - r.barMin)..")", 0.8, 0.8, 0.8);
		else
			GameTooltip:AddLine(StandingText(r.standing), 1, 1, 1);
			GameTooltip:AddLine((r.barValue - r.barMin).." / "..(r.barMax - r.barMin), 0.8, 0.8, 0.8);
		end
	end
	if ( r.id and L.warband[r.id] ) then
		GameTooltip:AddLine("Warband Reputation", 0.0, 0.8, 1.0);
		GameTooltip:AddLine("Shared by every character on your account.", 0.6, 0.6, 0.6, 1);
	end
	if ( r.atWar ) then GameTooltip:AddLine(AT_WAR or "At War", 1, 0.1, 0.1); end
	if ( r.inactive ) then GameTooltip:AddLine(FACTION_INACTIVE or "Inactive", 0.5, 0.5, 0.5); end
	GameTooltip:Show();
end

for i = 1, NUM_ROWS do
	local b = CreateFrame("Button", nil, listBox);
	b:SetHeight(ROW_HEIGHT - 2);
	b:SetPoint("TOPLEFT", 8, -8 - (i - 1) * ROW_HEIGHT);
	b:SetPoint("RIGHT", scroll, "RIGHT", 0, 0);
	b.band = b:CreateTexture(nil, "BACKGROUND");
	b.band:SetAllPoints();
	b.expand = b:CreateTexture(nil, "ARTWORK");
	b.expand:SetWidth(14); b.expand:SetHeight(14);
	b.header = TemucraftCharacter_HeaderBar and TemucraftCharacter_HeaderBar(b);
	b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.name:SetJustifyH("LEFT");
	b.bar = CreateFrame("StatusBar", nil, b);
	b.bar:SetWidth(150); b.bar:SetHeight(14);
	b.bar:SetPoint("RIGHT", -4, 0);
	b.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
	b.bar.bg = b.bar:CreateTexture(nil, "BACKGROUND");
	b.bar.bg:SetAllPoints();
	b.bar.bg:SetTexture(0, 0, 0, 0.5);
	b.bar.text = b.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.bar.text:SetPoint("CENTER");
	b.war = b.bar:CreateTexture(nil, "OVERLAY");
	b.war:SetAllPoints();
	b.war:SetTexture(1, 0, 0, 0.25);
	b.warband = b:CreateTexture(nil, "OVERLAY");
	b.warband:SetWidth(14); b.warband:SetHeight(14);
	b.warband:SetPoint("RIGHT", b.bar, "LEFT", -4, 0);
	b.warband:SetTexture("Interface\\FriendsFrame\\Battlenet-Portrait");
	b.name:SetPoint("RIGHT", b.warband, "LEFT", -4, 0);
	if ( TemucraftCharacter_Highlight ) then TemucraftCharacter_Highlight(b); else b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD"); end
	b:SetScript("OnEnter", function(self)
		ShowTooltip(self);
		if ( self.line and self.line.kind == "faction" and self.valueText ) then self.bar.text:SetText(self.valueText); end
	end);
	b:SetScript("OnLeave", function(self)
		GameTooltip:Hide();
		if ( self.barText ) then self.bar.text:SetText(self.barText); end
	end);
	b:SetScript("OnClick", function(self)
		local line = self.line;
		if ( not line ) then return; end
		local x = GetCursorPosition() / self:GetEffectiveScale();
		local onIcon = line.kind ~= "faction" and (x - self:GetLeft()) < line.depth * 14 + 22;
		if ( line.kind == "group" or (line.kind == "sub" and (onIcon or not line.row.hasRep)) ) then
			collapsed[line.key] = not collapsed[line.key] or nil;
			PlaySound(collapsed[line.key] and "igMainMenuOptionCheckBoxOff" or "igMainMenuOptionCheckBoxOn");
		else
			if ( IsModifiedClick("CHATLINK") ) then return; end
			selectedName = line.row.name;
			PlaySound("igMainMenuOptionCheckBoxOn");
		end
		Update();
	end);
	rows[i] = b;
end

-- the detail panel
local dName = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
dName:SetPoint("TOPLEFT", 12, -12); dName:SetPoint("RIGHT", -12, 0);
dName:SetJustifyH("LEFT");
local dStanding = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
dStanding:SetPoint("TOPLEFT", dName, "BOTTOMLEFT", 0, -6);
dStanding:SetPoint("RIGHT", -12, 0);
dStanding:SetJustifyH("LEFT");
local dWarband = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
dWarband:SetPoint("TOPLEFT", dStanding, "BOTTOMLEFT", 0, -4);
dWarband:SetTextColor(0.0, 0.8, 1.0);
dWarband:SetText("Warband Reputation");
local dDesc = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
dDesc:SetPoint("TOPLEFT", dWarband, "BOTTOMLEFT", 0, -10);
dDesc:SetPoint("RIGHT", -12, 0);
dDesc:SetHeight(170);
dDesc:SetJustifyH("LEFT"); dDesc:SetJustifyV("TOP");
local dNone = detail:CreateFontString(nil, "OVERLAY", "GameFontDisable");
dNone:SetPoint("CENTER");
dNone:SetText("Select a faction");

local function Check(name, label, y, tip)
	local c = CreateFrame("CheckButton", name, detail, "UICheckButtonTemplate");
	c:SetWidth(24); c:SetHeight(24);
	c:SetPoint("BOTTOMLEFT", 10, y);
	c.label = _G[name.."Text"];
	c.label:SetText(label);
	c:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(tip, nil, nil, nil, nil, 1);
	end);
	c:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	return c;
end
local atWarCheck = Check("TemucraftReputationAtWarCheck", AT_WAR or "At War", 104, REPUTATION_AT_WAR_DESCRIPTION or "At war with this faction.");
local inactiveCheck = Check("TemucraftReputationInactiveCheck", MOVE_TO_INACTIVE or "Move to Inactive", 80,
	REPUTATION_MOVE_TO_INACTIVE or "Moves this faction to the Inactive list.");
local watchCheck = Check("TemucraftReputationWatchCheck", SHOW_FACTION_ON_MAINSCREEN or "Show as Experience Bar", 56,
	REPUTATION_SHOW_AS_XP or "Shows this faction's reputation instead of the experience bar.");
local renownButton = CreateFrame("Button", "TemucraftReputationRenownButton", detail, "UIPanelButtonTemplate");
renownButton:SetWidth(150); renownButton:SetHeight(22);
renownButton:SetPoint("BOTTOM", 0, 16);
renownButton:SetText("View Renown");

local function Sound(on) PlaySound(on and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff"); end
atWarCheck:SetScript("OnClick", function(self)
	local i = selectedName and L.FindIndex(selectedName);
	if ( i ) then FactionToggleAtWar(i); end
	Sound(self:GetChecked());
end);
inactiveCheck:SetScript("OnClick", function(self)
	local i = selectedName and L.FindIndex(selectedName);
	if ( i ) then if ( self:GetChecked() ) then SetFactionInactive(i); else SetFactionActive(i); end end
	Sound(self:GetChecked());
end);
watchCheck:SetScript("OnClick", function(self)
	local i = selectedName and L.FindIndex(selectedName);
	if ( self:GetChecked() and i ) then SetWatchedFactionIndex(i); else SetWatchedFactionIndex(0); end
	if ( ReputationWatchBar_Update ) then ReputationWatchBar_Update(); end
	Sound(self:GetChecked());
end);

local function Enable(check, on, red)
	if ( on ) then
		check:Enable();
		if ( red ) then check.label:SetTextColor(1, 0.1, 0.1); else check.label:SetTextColor(1, 0.82, 0); end
	else
		check:Disable();
		check.label:SetTextColor(0.5, 0.5, 0.5);
	end
end

local function UpdateDetail(row)
	local shown = row ~= nil;
	for _, w in ipairs({ dName, dStanding, dDesc, atWarCheck, inactiveCheck, watchCheck, renownButton }) do if ( shown ) then w:Show(); else w:Hide(); end end
	if ( shown ) then dNone:Hide(); else dNone:Show(); dWarband:Hide(); return; end
	dName:SetText(row.name);
	local track = row.id and L.tracks[row.id];
	if ( track ) then
		local level, cur, need, isMax = L.RenownLevel(track, row.barValue);
		dStanding:SetText("|cff66bbff"..(track.label or "Renown").." "..level.."|r  "..(isMax and "(max)" or (cur.." / "..need)));
	elseif ( row.hasRep or not row.isHeader ) then
		dStanding:SetText(StandingText(row.standing).."  |cffcccccc"..(row.barValue - row.barMin).." / "..(row.barMax - row.barMin).."|r");
	else
		dStanding:SetText("");
	end
	if ( row.id and L.warband[row.id] ) then dWarband:Show(); else dWarband:Hide(); end
	dDesc:SetText(row.description or "");
	atWarCheck:SetChecked(row.atWar);
	Enable(atWarCheck, row.canToggleAtWar and not row.isHeader, true);
	inactiveCheck:SetChecked(row.inactive);
	Enable(inactiveCheck, not row.isHeader);
	watchCheck:SetChecked(row.isWatched);
	Enable(watchCheck, row.hasRep or not row.isHeader);
	if ( track and TemucraftRenown_Show ) then
		renownButton:Enable();
		renownButton:SetScript("OnClick", function() TemucraftRenown_Show(row.id); end);
	else
		renownButton:Disable();
	end
end

local groupsCache;
Update = function()
	if ( not frame:IsVisible() ) then return; end
	groupsCache = L.Group(L.ReadRows());
	lines = L.Flatten(groupsCache, filter, collapsed);
	FauxScrollFrame_Update(scroll, #lines, NUM_ROWS, ROW_HEIGHT);
	local offset = FauxScrollFrame_GetOffset(scroll);
	local selectedRow;
	for _, g in ipairs(groupsCache) do
		for _, item in ipairs(g.items) do
			if ( item.row.name == selectedName ) then selectedRow = item.row; end
			for _, r in ipairs(item.children or {}) do if ( r.name == selectedName ) then selectedRow = r; end end
		end
	end
	for i, b in ipairs(rows) do
		local line = lines[offset + i];
		b.line = line;
		b.barText, b.valueText = nil, nil;
		if ( not line ) then
			b:Hide();
		else
			local indent = line.depth * 14;
			b.expand:ClearAllPoints();
			b.expand:SetPoint("LEFT", indent, 0);
			b.name:ClearAllPoints();
			if ( line.kind == "faction" ) then
				b.expand:Hide();
				b.name:SetPoint("LEFT", indent + 6, 0);
			else
				b.expand:SetTexture(line.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up");
				b.expand:Show();
				b.name:SetPoint("LEFT", b.expand, "RIGHT", 4, 0);
			end
			b.name:SetPoint("RIGHT", b.warband, "LEFT", -4, 0);
			if ( line.kind == "group" ) then
				b.name:SetFontObject(GameFontNormal);
				b.name:SetText(line.name);
				if ( b.header ) then b.header:Show(); b.band:SetTexture(0, 0, 0, 0); else b.band:SetTexture(1, 0.82, 0, 0.12); end
				b.bar:Hide(); b.warband:Hide();
			else
				local r = line.row;
				if ( b.header ) then b.header:Hide(); end
				b.name:SetFontObject(line.kind == "sub" and GameFontNormalSmall or GameFontHighlightSmall);
				b.name:SetText(r.name);
				if ( r.name == selectedName ) then b.band:SetTexture(0.3, 0.5, 1, 0.25);
				elseif ( (offset + i) % 2 == 0 ) then b.band:SetTexture(1, 1, 1, 0.04);
				else b.band:SetTexture(0, 0, 0, 0); end
				if ( r.hasRep or line.kind == "faction" ) then
					local text, value, max, cr, cg, cb = L.BarInfo(r, StandingText(r.standing));
					b.bar:SetMinMaxValues(0, max);
					b.bar:SetValue(value);
					b.bar:SetStatusBarColor(cr, cg, cb);
					b.barText = text;
					b.valueText = (r.id and L.tracks[r.id]) and (value.." / "..max) or ((r.barValue - r.barMin).." / "..(r.barMax - r.barMin));
					b.bar.text:SetText(text);
					if ( r.atWar ) then b.war:Show(); else b.war:Hide(); end
					b.bar:Show();
				else
					b.bar:Hide();
				end
				if ( r.id and L.warband[r.id] ) then b.warband:Show(); else b.warband:Hide(); end
			end
			b:Show();
		end
	end
	UpdateDetail(selectedRow);
end
L.Update = Update;
scroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, Update); end);
listBox:EnableMouseWheel(true);
listBox:SetScript("OnMouseWheel", function(_, delta)
	local bar = _G["TemucraftReputationScrollScrollBar"];
	if ( bar ) then bar:SetValue(bar:GetValue() - delta * ROW_HEIGHT * 3); end
end);

frame:SetScript("OnShow", function() Update(); end);

-- the character window's Reputation tab, U and the stock Reputation tab (ToggleCharacter("ReputationFrame") goes to
-- this page, or to the stock frame with the Classic option on)
if ( TemucraftCharacter_AddPage ) then TemucraftCharacter_AddPage("rep", frame, { title = REPUTATION or "Reputation" }); end

function TemucraftReputation_Toggle() ToggleCharacter("ReputationFrame"); end

-- open on a faction (TemucraftRenown.lua's back button)
function TemucraftReputation_Show(id)
	local name = id and L.NameOf(id);
	if ( name ) then selectedName = name; end
	if ( frame:IsVisible() ) then Update(); return; end
	if ( not (TemucraftCharacter_Open and TemucraftCharacter_Open("rep")) ) then ToggleCharacter("ReputationFrame"); end
end

----------------------------------------------------------------------------------------------------------------------
-- Events
----------------------------------------------------------------------------------------------------------------------
local hello = false;
local events = CreateFrame("Frame");
events:RegisterEvent("PLAYER_ENTERING_WORLD");
events:RegisterEvent("CHAT_MSG_ADDON");
events:RegisterEvent("UPDATE_FACTION");
local dirty = false;
local function Later()
	if ( dirty ) then return; end
	dirty = true;
	events:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil);
		dirty = false;
		Update();
		Fire("update");
	end);
end
L.Later = Later;
events:SetScript("OnEvent", function(self, event, a1, a2, a3, a4)
	if ( event == "CHAT_MSG_ADDON" ) then
		if ( a1 == L.PREFIX and a3 == "WHISPER" and a4 == UnitName("player") ) then L.OnMessage(a2); end
	elseif ( event == "PLAYER_ENTERING_WORLD" ) then
		if ( not hello ) then hello = true; Ask("HELLO"); end
	elseif ( event == "UPDATE_FACTION" ) then
		Later();
	end
end);
L.On("reload", function() Ask("HELLO"); end);
for _, kind in ipairs({ "tracks", "warband", "granted", "names" }) do L.On(kind, Later); end
