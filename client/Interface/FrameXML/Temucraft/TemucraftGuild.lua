-- Temucraft guild window (retail "Guild & Communities" look), with mod-temucraft-guild (TemucraftGuild.cpp, addon
-- prefix TGD) keeping the guild's chat, bank logs, event log and news forever on the server.
--   Chat     the guild and officer chat with its stored history (timestamps; older pages on request) and the live
--            lines, the online members beside it, a box to write to the guild or the officers
--   Roster   every member: class colours, level, rank, zone, note, last online (sort by any column, offline too)
--   News     achievements, epic items, members joining, leaving, promoted (from the server; else the stock log)
--   Info     message of the day and guild information (editable with the rights), the guild log (the server's
--            archive, else the stock last entries)
--   Perks    mod-temucraft-guild-perks' perks and whether they are on for the guild (when the server has them)
-- J (the Guild key, set once when nothing else uses J), the micro menu's guild button and ToggleFriendsFrame(3)
-- open it. "Classic guild window" (Interface Options > Temucraft, /tui, or "/tguild classic") opens the stock guild
-- tab instead; the "Classic window" button opens the stock tab once (guild control, ranks). After login the last
-- lines of guild chat are written to the chat window ("Show recent guild chat at login", /tui).
-- Nothing here is secure or protected: it opens and closes in combat; the key is only set out of combat.
--
-- TemucraftGuildLogic is also used by TemucraftGuildBank.lua (the bank's logs from the archive).

----------------------------------------------------------------------------------------------------------------------
-- The logic (no frames: tests/guild_test.lua runs it with stubs)
----------------------------------------------------------------------------------------------------------------------
TemucraftGuildLogic = {};
local L = TemucraftGuildLogic;
L.PREFIX = "TGD";

-- class id -> class file (the client's RAID_CLASS_COLORS keys)
L.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER" };
local FALLBACK_COLORS = {
	WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 }, ROGUE = { 1.0, 0.96, 0.41 },
	PRIEST = { 1.0, 1.0, 1.0 }, DEATHKNIGHT = { 0.77, 0.12, 0.23 }, SHAMAN = { 0.0, 0.44, 0.87 }, MAGE = { 0.41, 0.8, 0.94 },
	WARLOCK = { 0.58, 0.51, 0.79 }, MONK = { 0.0, 1.0, 0.59 }, DRUID = { 1.0, 0.49, 0.04 }, DEMONHUNTER = { 0.64, 0.19, 0.79 },
};
local QUALITY_HEX = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80", "ffe6cc80" };

function L.ClassFile(id) return L.CLASSES[tonumber(id) or 0]; end

-- "ffrrggbb" of a class file (or a class id); nil = the default yellow
function L.ClassHex(class)
	if ( type(class) == "number" or (type(class) == "string" and string.match(class, "^%d+$")) ) then class = L.ClassFile(class); end
	local c = class and ((RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]) or FALLBACK_COLORS[class]);
	if ( not c ) then return "ffffd100"; end
	local r, g, b = c.r or c[1], c.g or c[2], c.b or c[3];
	return string.format("ff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5));
end

function L.ColoredName(name, class)
	if ( not name or name == "" ) then name = "Unknown"; end
	return "|c"..L.ClassHex(class)..name.."|r";
end

local function Plural(n, one, many) return n.." "..(n == 1 and one or many); end

-- "just now", "5 minutes ago", "3 hours ago", "2 days ago", "10 months ago", "2 years ago"
function L.Ago(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0));
	if ( seconds < 60 ) then return "just now"; end
	local minutes = math.floor(seconds / 60);
	if ( minutes < 60 ) then return Plural(minutes, "minute", "minutes").." ago"; end
	local hours = math.floor(minutes / 60);
	if ( hours < 24 ) then return Plural(hours, "hour", "hours").." ago"; end
	local days = math.floor(hours / 24);
	if ( days < 30 ) then return Plural(days, "day", "days").." ago"; end
	local months = math.floor(days / 30);
	if ( days < 365 ) then return Plural(months, "month", "months").." ago"; end
	return Plural(math.floor(days / 365), "year", "years").." ago";
end

-- the stock logs' "years, months, days, hours ago" in seconds (for L.Ago)
function L.StockSeconds(years, months, days, hours)
	return ((((years or 0) * 365 + (months or 0) * 30 + (days or 0)) * 24) + (hours or 0)) * 3600;
end

-- the roster's last online (GetGuildRosterLastOnline)
function L.LastOnline(years, months, days, hours)
	years, months, days, hours = years or 0, months or 0, days or 0, hours or 0;
	if ( years > 0 ) then return Plural(years, "year", "years"); end
	if ( months > 0 ) then return Plural(months, "month", "months"); end
	if ( days > 0 ) then return Plural(days, "day", "days"); end
	if ( hours > 0 ) then return Plural(hours, "hour", "hours"); end
	return "< an hour";
end

-- "12 Gold 34 Silver 5 Copper" (no zero parts)
function L.Money(copper)
	copper = math.floor(tonumber(copper) or 0);
	local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100;
	local parts = {};
	if ( gold > 0 ) then table.insert(parts, gold.." Gold"); end
	if ( silver > 0 ) then table.insert(parts, silver.." Silver"); end
	if ( rest > 0 or #parts == 0 ) then table.insert(parts, rest.." Copper"); end
	return table.concat(parts, " ");
end

function L.ItemLink(id, name, quality)
	id = tonumber(id) or 0;
	if ( (not name or name == "") and GetItemInfo ) then
		local n, link = GetItemInfo(id);
		if ( link ) then return link; end
		name = n;
	end
	return "|c"..(QUALITY_HEX[tonumber(quality) or 1] or "ffffffff").."|Hitem:"..id..":0:0:0:0:0:0:0|h["..(name or ("Item "..id)).."]|h|r";
end

-- the record's fields, the last one taking the rest (it may hold "~")
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

L.server = nil;        -- { chat, bank, news, perks, page } once the server said hello
L.chat = {};           -- { id, ch = "g"|"o", time, class, name, text }, oldest first
L.chatMore = false;    -- older lines on the server
L.live = {};           -- lines seen live since the last fresh page was asked for
L.bankLog = {};        -- [tab] = { entries = {...}, more = bool }
L.news, L.newsMore = {}, false;
L.events, L.eventsMore = {}, false;
L.perks = {};
local incoming = {};
local listeners = {};

function L.On(kind, func) listeners[kind] = listeners[kind] or {}; table.insert(listeners[kind], func); end
local function Fire(kind, ...) for _, f in ipairs(listeners[kind] or {}) do f(...); end end

local function Now() return (time and time()) or os.time(); end
local function Num(v) return tonumber(v) or 0; end

-- live lines the fresh page already has (stored a moment before it was read) are dropped: a stored line of the
-- same channel, name and text from around the time the live line came (each stored line matches one live line)
function L.MergeLive(lines, live)
	local recent = {};
	for i = math.max(1, #lines - 50), #lines do
		local l = lines[i];
		if ( l ) then
			local key = l.ch.."\1"..l.name.."\1"..l.text;
			recent[key] = recent[key] or {};
			table.insert(recent[key], l.time or 0);
		end
	end
	for _, l in ipairs(live) do
		local key = l.ch.."\1"..l.name.."\1"..l.text;
		local found;
		for i, t in ipairs(recent[key] or {}) do
			if ( math.abs(t - (l.time or 0)) <= 15 ) then found = i; break; end
		end
		if ( found ) then table.remove(recent[key], found); else table.insert(lines, l); end
	end
	return lines;
end

function L.AddLive(ch, name, class, text)
	local line = { ch = ch, name = name or "", class = class, text = text or "", time = Now() };
	table.insert(L.chat, line);
	table.insert(L.live, line);
	while ( #L.live > 100 ) do table.remove(L.live, 1); end
	Fire("chat");
end

-- the id of the oldest stored line we have (the next older page starts there)
function L.OldestId()
	for _, l in ipairs(L.chat) do if ( l.id ) then return l.id; end end
	return 0;
end

local HANDLERS = {};
HANDLERS.S = function(f)
	L.server = { chat = f[2] == "1", bank = f[3] == "1", news = f[4] == "1", perks = f[5] == "1", page = Num(f[6]) };
	Fire("server");
end
HANDLERS.H = function(f, rec)
	f = L.Fields(rec, 7);
	table.insert(incoming, { id = Num(f[2]), ch = f[3] == "o" and "o" or "g", time = Now() - Num(f[4]), class = Num(f[5]), name = f[6] or "", text = f[7] or "" });
end
HANDLERS.HE = function(f)
	local lines = incoming;
	incoming = {};
	local what, more = f[2], f[4] == "1";
	if ( what == "L" ) then
		if ( #L.chat == 0 ) then L.chat = lines; L.chatMore = more; end
		Fire("login", lines);
	elseif ( L.wantOlder ) then
		L.wantOlder = nil;
		for i = #lines, 1, -1 do table.insert(L.chat, 1, lines[i]); end
		L.chatMore = more;
	else
		L.chat = L.MergeLive(lines, L.live);
		L.live = {};
		L.chatMore = more;
	end
	Fire("chat");
end
HANDLERS.L = function(f, rec)
	f = L.Fields(rec, 12);
	table.insert(incoming, { id = Num(f[2]), time = Now() - Num(f[3]), type = Num(f[4]), tab = Num(f[5]), class = Num(f[6]), name = f[7],
		amount = Num(f[8]), count = Num(f[9]), destTab = Num(f[10]), quality = Num(f[11]), itemName = f[12] });
end
HANDLERS.LE = function(f)
	local tab, offset = Num(f[2]), Num(f[3]);
	local log = L.bankLog[tab] or { entries = {} };
	if ( offset == 0 ) then log.entries = {}; end
	for _, e in ipairs(incoming) do table.insert(log.entries, e); end
	incoming = {};
	log.more = f[5] == "1";
	L.bankLog[tab] = log;
	Fire("banklog", tab);
end
HANDLERS.N = function(f, rec)
	f = L.Fields(rec, 8);
	table.insert(incoming, { time = Now() - Num(f[2]), kind = f[3], class = Num(f[4]), name = f[5], value = Num(f[6]), quality = Num(f[7]), text = f[8] });
end
HANDLERS.NE = function(f)
	if ( Num(f[2]) == 0 ) then L.news = {}; end
	for _, e in ipairs(incoming) do table.insert(L.news, e); end
	incoming = {};
	L.newsMore = f[4] == "1";
	Fire("news");
end
HANDLERS.E = function(f, rec)
	f = L.Fields(rec, 8);
	table.insert(incoming, { time = Now() - Num(f[2]), type = Num(f[3]), class1 = Num(f[4]), name1 = f[5], class2 = Num(f[6]), name2 = f[7], rank = Num(f[8]) });
end
HANDLERS.EE = function(f)
	if ( Num(f[2]) == 0 ) then L.events = {}; end
	for _, e in ipairs(incoming) do table.insert(L.events, e); end
	incoming = {};
	L.eventsMore = f[4] == "1";
	Fire("events");
end
HANDLERS.K = function(f, rec)
	f = L.Fields(rec, 5);
	table.insert(incoming, { id = Num(f[2]), state = f[3], spell = Num(f[4]), name = f[5] });
end
HANDLERS.KE = function()
	L.perks = incoming;
	incoming = {};
	Fire("perks");
end

-- one addon message from the server; the record's kind when one was complete
function L.OnMessage(msg)
	local rec = L.Feed(msg);
	if ( not rec ) then return nil; end
	local f = L.Fields(rec, 12);
	local h = HANDLERS[f[1]];
	if ( not h ) then return nil; end
	h(f, rec);
	return f[1];
end

-- bank log entries, numeric type -> what happened
local BANK_TYPES = { [1] = "deposit", [2] = "withdraw", [3] = "move", [4] = "deposit", [5] = "withdraw", [6] = "repair", [7] = "move",
	[8] = "withdrawForTab", [9] = "buyTab" };
local MONEY_TYPES = { [4] = true, [5] = true, [6] = true, [8] = true, [9] = true };
L.BANK_TYPES, L.MONEY_TYPES = BANK_TYPES, MONEY_TYPES;
local GREEN, RED, YELLOW, GREY = "|cff20ff20", "|cffff2020", "|cffffd100", "|cff808080";

-- e = { what = "deposit"|..., name, class, link, count, tab1, tab2 (names), money (copper or nil), seconds (ago) }
function L.BankLine(e)
	local who = L.ColoredName(e.name, e.class);
	local text;
	if ( e.money ) then
		local amount = "|cffffffff"..L.Money(e.money).."|r";
		if ( e.what == "deposit" ) then text = who.." "..GREEN.."deposited|r "..amount;
		elseif ( e.what == "withdraw" ) then text = who.." "..RED.."withdrew|r "..amount;
		elseif ( e.what == "repair" ) then text = who.." "..RED.."withdrew|r "..amount.." for repairs";
		elseif ( e.what == "withdrawForTab" ) then text = who.." "..RED.."withdrew|r "..amount.." to buy a bank tab";
		else text = who.." "..YELLOW.."bought a bank tab|r for "..amount; end
	else
		local item = (e.link or "?")..(((e.count or 0) > 1) and (" x"..e.count) or "");
		if ( e.what == "deposit" ) then text = who.." "..GREEN.."deposited|r "..item;
		elseif ( e.what == "withdraw" ) then text = who.." "..RED.."withdrew|r "..item;
		else text = who.." "..YELLOW.."moved|r "..item.." from "..(e.tab1 or "?").." to "..(e.tab2 or "?"); end
	end
	return text.." "..GREY.."("..L.Ago(e.seconds)..")|r";
end

-- a server bank log entry for L.BankLine (tabName(tab) gives a tab's name)
function L.FromArchive(e, tabName)
	local money = MONEY_TYPES[e.type] and e.amount or nil;
	return { what = BANK_TYPES[e.type] or "move", name = e.name, class = e.class, money = money,
		link = (not money) and L.ItemLink(e.amount, e.itemName, e.quality) or nil, count = e.count,
		tab1 = tabName and tabName(e.tab), tab2 = tabName and tabName(e.destTab), seconds = Now() - e.time };
end

-- news line (rankName(rank) gives a rank's name)
function L.NewsLine(n, rankName)
	local who = L.ColoredName(n.name, n.class);
	local text;
	if ( n.kind == "a" ) then
		local link = GetAchievementLink and GetAchievementLink(n.value);
		text = who.." earned the achievement "..(link or ("#"..n.value));
	elseif ( n.kind == "i" ) then text = who.." looted "..L.ItemLink(n.value, n.text, n.quality);
	elseif ( n.kind == "c" ) then text = who.." crafted "..L.ItemLink(n.value, n.text, n.quality);
	elseif ( n.kind == "j" ) then text = who.." joined the guild";
	elseif ( n.kind == "l" ) then text = who.." left the guild";
	elseif ( n.kind == "k" ) then text = who.." was removed from the guild"..((n.text and n.text ~= "") and (" by "..n.text) or "");
	elseif ( n.kind == "p" or n.kind == "d" ) then
		text = who.." was "..(n.kind == "p" and "promoted" or "demoted").." to "..((rankName and rankName(n.value)) or ("rank "..(n.value + 1)))
			..((n.text and n.text ~= "") and (" by "..n.text) or "");
	else text = who; end
	return text;
end

-- guild log line: type 1 invite, 2 join, 3 promote, 4 demote, 5 remove, 6 quit (or the stock names)
local EVENT_NAMES = { invite = 1, join = 2, promote = 3, demote = 4, remove = 5, quit = 6 };
function L.EventLine(e, rankName)
	local t = EVENT_NAMES[e.type] or e.type;
	local a, b = L.ColoredName(e.name1, e.class1), L.ColoredName(e.name2, e.class2);
	local rank = e.rankText or (rankName and rankName(e.rank)) or ("rank "..((e.rank or 0) + 1));
	if ( t == 1 ) then return a.." invited "..b.." to the guild"; end
	if ( t == 2 ) then return a.." joined the guild"; end
	if ( t == 3 ) then return a.." promoted "..b.." to "..rank; end
	if ( t == 4 ) then return a.." demoted "..b.." to "..rank; end
	if ( t == 5 ) then return a.." removed "..b.." from the guild"; end
	if ( t == 6 ) then return a.." left the guild"; end
	return a;
end

-- members = { { name, level, rank, rankIndex, zone, note, online, class, last (seconds offline) } }
local SORT_KEYS = { name = "name", level = "level", rank = "rankIndex", zone = "zone", note = "note", online = "last", class = "class" };
function L.SortRoster(members, key, descending)
	local field = SORT_KEYS[key] or "name";
	table.sort(members, function(a, b)
		local x, y = a[field], b[field];
		if ( field == "last" ) then x, y = a.online and -1 or (a.last or 0), b.online and -1 or (b.last or 0); end
		if ( type(x) == "string" ) then x, y = string.lower(x or ""), string.lower(y or ""); end
		if ( x == y ) then return string.lower(a.name or "") < string.lower(b.name or ""); end
		if ( x == nil ) then return false; end
		if ( y == nil ) then return true; end
		if ( descending ) then return x > y; end
		return x < y;
	end);
	return members;
end

-- the timestamp of a chat line: the time today, else the date and time
function L.Stamp(t, now)
	if ( not date ) then return ""; end
	now = now or Now();
	if ( date("%Y%m%d", t) == date("%Y%m%d", now) ) then return date("%H:%M", t); end
	return date("%m/%d %H:%M", t);
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

----------------------------------------------------------------------------------------------------------------------
-- Talking to the server
----------------------------------------------------------------------------------------------------------------------
local function Ask(text) SendAddonMessage(L.PREFIX, text, "WHISPER", UnitName("player")); end
L.Ask = Ask;

function TemucraftGuild_HasServer(what) return L.server ~= nil and L.server[what] == true; end

-- names in the roster -> class file (for the stock logs and live chat)
local rosterClass = {};
local function ClassOf(name)
	return name and rosterClass[name];
end
L.ClassOf = ClassOf;

local function RankName(rank) return GuildControlGetRankName and GuildControlGetRankName((rank or 0) + 1); end
L.RankName = RankName;

----------------------------------------------------------------------------------------------------------------------
-- A plain scrolling list (newest first): rows of text with an age on the right, "Show more" at the end
----------------------------------------------------------------------------------------------------------------------
function TemucraftGuild_CreateList(parent, numRows, rowHeight)
	local list = CreateFrame("Frame", nil, parent);
	list.rows, list.items, list.offset = {}, {}, 0;
	list:EnableMouseWheel(true);
	for i = 1, numRows do
		local r = CreateFrame("Button", nil, list);
		r:SetHeight(rowHeight);
		r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * rowHeight);
		r:SetPoint("RIGHT", list, "RIGHT", -4, 0);
		r.band = r:CreateTexture(nil, "BACKGROUND");
		r.band:SetAllPoints();
		r.band:SetTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0);
		r.icon = r:CreateTexture(nil, "ARTWORK");
		r.icon:SetWidth(rowHeight - 2); r.icon:SetHeight(rowHeight - 2);
		r.icon:SetPoint("LEFT", 2, 0);
		r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		r.text:SetJustifyH("LEFT");
		r.right = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
		r.right:SetPoint("RIGHT", -4, 0);
		r.right:SetJustifyH("RIGHT");
		r.text:SetPoint("RIGHT", r.right, "LEFT", -6, 0);
		r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD");
		r:SetScript("OnEnter", function(self)
			local item = self.item;
			if ( not item ) then return; end
			local link = item.link or (item.text and string.match(item.text, "(|H[^|]+|h.-|h)"));
			if ( link ) then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
				GameTooltip:SetHyperlink(string.match(link, "|H([^|]+)|h"));
				GameTooltip:Show();
			elseif ( item.tip ) then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
				GameTooltip:SetText(item.tip, 1, 1, 1, 1, 1);
				GameTooltip:Show();
			end
		end);
		r:SetScript("OnLeave", function() GameTooltip:Hide(); end);
		r:SetScript("OnClick", function(self)
			if ( self.isMore and list.onMore ) then list.onMore(); return; end
			local item = self.item;
			if ( item and IsModifiedClick("CHATLINK") ) then
				local link = item.link or (item.text and string.match(item.text, "(|c%x+|H[^|]+|h.-|h|r)"));
				if ( link ) then ChatEdit_InsertLink(link); end
			end
		end);
		list.rows[i] = r;
	end
	function list:Refresh()
		local total = #self.items + (self.more and 1 or 0);
		self.offset = math.max(0, math.min(self.offset, total - numRows));
		for i, r in ipairs(self.rows) do
			local index = self.offset + i;
			local item = self.items[index];
			r.item, r.isMore = item, nil;
			if ( item ) then
				r.text:SetText(item.text or "");
				r.right:SetText(item.right or "");
				if ( item.icon ) then
					r.icon:SetTexture(item.icon); r.icon:Show();
					r.text:SetPoint("LEFT", r.icon, "RIGHT", 4, 0);
				else
					r.icon:Hide();
					r.text:SetPoint("LEFT", 4, 0);
				end
				r:Show();
			elseif ( index == #self.items + 1 and self.more ) then
				r.isMore = true;
				r.icon:Hide();
				r.text:SetPoint("LEFT", 4, 0);
				r.text:SetText("|cff66ccffShow more...|r");
				r.right:SetText("");
				r:Show();
			elseif ( index == 1 and self.empty ) then
				r.icon:Hide();
				r.text:SetPoint("LEFT", 4, 0);
				r.text:SetText("|cff808080"..self.empty.."|r");
				r.right:SetText("");
				r:Show();
			else
				r:Hide();
			end
		end
	end
	function list:SetItems(items, more)
		self.items, self.more = items or {}, more;
		self:Refresh();
	end
	list:SetScript("OnMouseWheel", function(self, delta)
		self.offset = self.offset - delta * 3;
		self:Refresh();
	end);
	return list;
end

----------------------------------------------------------------------------------------------------------------------
-- The window
----------------------------------------------------------------------------------------------------------------------
local WIDTH, HEIGHT, SIDE = 840, 520, 190;
local frame = CreateFrame("Frame", "TemucraftGuildFrame", UIParent);
frame:SetWidth(WIDTH); frame:SetHeight(HEIGHT);
frame:SetToplevel(true);
frame:EnableMouse(true);
frame:SetMovable(true);
frame:SetClampedToScreen(true);
frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } });
frame:Hide();
UIPanelWindows["TemucraftGuildFrame"] = { area = "left", pushable = 1, whileDead = 1 };

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
title:SetPoint("TOP", 0, -18);
title:SetText("Guild & Communities");
local close = CreateFrame("Button", "TemucraftGuildFrameCloseButton", frame, "UIPanelCloseButton");
close:SetPoint("TOPRIGHT", -6, -6);
local drag = CreateFrame("Frame", nil, frame);
drag:SetPoint("TOPLEFT", 12, -8); drag:SetPoint("TOPRIGHT", -40, -8); drag:SetHeight(26);
drag:EnableMouse(true);
drag:RegisterForDrag("LeftButton");
drag:SetScript("OnDragStart", function() frame:StartMoving(); end);
drag:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); end);

local function Panel(parent)
	local p = CreateFrame("Frame", nil, parent);
	p:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } });
	p:SetBackdropColor(0, 0, 0, 0.6);
	p:SetBackdropBorderColor(0.5, 0.45, 0.35, 0.9);
	return p;
end

-- the sidebar: the guild's card
local side = Panel(frame);
side:SetPoint("TOPLEFT", 16, -40);
side:SetPoint("BOTTOMLEFT", 16, 16);
side:SetWidth(SIDE);
local guildName = side:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
guildName:SetPoint("TOPLEFT", 12, -12); guildName:SetPoint("RIGHT", -10, 0);
guildName:SetJustifyH("LEFT");
local guildRank = side:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
guildRank:SetPoint("TOPLEFT", guildName, "BOTTOMLEFT", 0, -4);
local guildOnline = side:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
guildOnline:SetPoint("TOPLEFT", guildRank, "BOTTOMLEFT", 0, -4);
local motdLabel = side:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
motdLabel:SetPoint("TOPLEFT", guildOnline, "BOTTOMLEFT", 0, -14);
motdLabel:SetText("Message of the Day");
local motdText = side:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
motdText:SetPoint("TOPLEFT", motdLabel, "BOTTOMLEFT", 0, -4);
motdText:SetWidth(SIDE - 24);
motdText:SetJustifyH("LEFT"); motdText:SetJustifyV("TOP");
motdText:SetHeight(150);

local function SideButton(text, y, onClick)
	local b = CreateFrame("Button", nil, side, "UIPanelButtonTemplate");
	b:SetWidth(SIDE - 24); b:SetHeight(22);
	b:SetPoint("BOTTOM", 0, y);
	b:SetText(text);
	b:SetScript("OnClick", onClick);
	return b;
end
local stockToggle;   -- the stock ToggleFriendsFrame, set below
local classicButton = SideButton("Classic Window", 12, function()
	HideUIPanel(frame);
	stockToggle(3);
end);
local inviteButton = SideButton("Add Member", 38, function() StaticPopup_Show("ADD_GUILDMEMBER"); end);
local leaveButton = SideButton("Leave Guild", 64, function()
	StaticPopup_Show("CONFIRM_GUILD_LEAVE", GetGuildInfo("player"));
end);

-- the content area, right of the sidebar
local content = CreateFrame("Frame", nil, frame);
content:SetPoint("TOPLEFT", side, "TOPRIGHT", 8, 0);
content:SetPoint("BOTTOMRIGHT", -16, 16);

local views = {};
local function View()
	local v = CreateFrame("Frame", nil, content);
	v:SetAllPoints();
	v:Hide();
	return v;
end

------------------------------------------------------------------ Chat
local chatView = View();
views.chat = chatView;
local chatBox = Panel(chatView);
chatBox:SetPoint("TOPLEFT"); chatBox:SetPoint("BOTTOMRIGHT", -196, 34);
local members = Panel(chatView);
members:SetPoint("TOPLEFT", chatBox, "TOPRIGHT", 6, 0);
members:SetPoint("BOTTOMRIGHT", 0, 0);
local membersTitle = members:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
membersTitle:SetPoint("TOPLEFT", 10, -10);
local memberList = TemucraftGuild_CreateList(members, 26, 15);
memberList:SetPoint("TOPLEFT", 4, -24); memberList:SetPoint("BOTTOMRIGHT", -4, 4);

local messages = CreateFrame("ScrollingMessageFrame", "TemucraftGuildChatMessages", chatBox);
messages:SetPoint("TOPLEFT", 10, -28); messages:SetPoint("BOTTOMRIGHT", -10, 8);
messages:SetFontObject(ChatFontNormal);
messages:SetJustifyH("LEFT");
messages:SetFading(false);
messages:SetMaxLines(2000);
messages:EnableMouse(true);
messages:EnableMouseWheel(true);
if ( messages.SetHyperlinksEnabled ) then messages:SetHyperlinksEnabled(true); end
messages:SetScript("OnHyperlinkClick", function(self, link, text, button) SetItemRef(link, text, button); end);
messages:SetScript("OnMouseWheel", function(self, delta)
	if ( delta > 0 ) then
		if ( IsShiftKeyDown() ) then self:ScrollToTop(); else self:ScrollUp(); self:ScrollUp(); end
	else
		if ( IsShiftKeyDown() ) then self:ScrollToBottom(); else self:ScrollDown(); self:ScrollDown(); end
	end
end);
local older = CreateFrame("Button", nil, chatBox);
older:SetPoint("TOP", 0, -8);
older:SetHeight(16); older:SetWidth(240);
local olderText = older:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
olderText:SetAllPoints();
older:SetFontString(olderText);
older:SetText("|cff66ccffLoad older messages|r");
older:SetScript("OnClick", function()
	L.wantOlder = true;
	Ask("HIST~"..L.OldestId());
end);

local channel = "GUILD";
local input = CreateFrame("EditBox", "TemucraftGuildChatInput", chatView, "InputBoxTemplate");
input:SetPoint("BOTTOMLEFT", 84, 6); input:SetPoint("RIGHT", chatBox, "RIGHT", -4, 0);
input:SetHeight(20);
input:SetAutoFocus(false);
input:SetMaxLetters(255);
local channelButton = CreateFrame("Button", "TemucraftGuildChatChannel", chatView, "UIPanelButtonTemplate");
channelButton:SetPoint("BOTTOMLEFT", 0, 5);
channelButton:SetWidth(76); channelButton:SetHeight(22);
local function UpdateChannel() channelButton:SetText(channel == "GUILD" and "Guild" or "Officer"); end
channelButton:SetScript("OnClick", function() channel = (channel == "GUILD") and "OFFICER" or "GUILD"; UpdateChannel(); end);
UpdateChannel();
input:SetScript("OnEnterPressed", function(self)
	local text = strtrim(self:GetText() or "");
	if ( text ~= "" ) then SendChatMessage(text, channel); end
	self:SetText("");
	self:ClearFocus();
end);
input:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); end);

local function ChatColor(ch)
	local info = ChatTypeInfo and ChatTypeInfo[ch == "o" and "OFFICER" or "GUILD"];
	if ( info ) then return info.r, info.g, info.b; end
	if ( ch == "o" ) then return 0.25, 0.75, 0.25; end
	return 0.25, 1.0, 0.25;
end

local function ChatLine(l)
	local who = "|Hplayer:"..l.name.."|h["..L.ColoredName(l.name, l.class ~= 0 and l.class or ClassOf(l.name)).."]|h";
	local tag = (l.ch == "o") and "[Officer] " or "";
	return "|cff808080"..L.Stamp(l.time).."|r "..tag..who..": "..l.text;
end

local function RefreshChat()
	if ( not chatView:IsShown() ) then return; end
	messages:Clear();
	for _, l in ipairs(L.chat) do messages:AddMessage(ChatLine(l), ChatColor(l.ch)); end
	messages:ScrollToBottom();
	if ( L.chatMore ) then older:Show(); else older:Hide(); end
end
L.On("chat", RefreshChat);

------------------------------------------------------------------ Roster
local rosterView = View();
views.roster = rosterView;
local rosterBox = Panel(rosterView);
rosterBox:SetPoint("TOPLEFT", 0, -26); rosterBox:SetPoint("BOTTOMRIGHT");
local COLUMNS = {
	{ key = "name", label = "Name", width = 120 }, { key = "level", label = "Level", width = 40 },
	{ key = "rank", label = "Rank", width = 90 }, { key = "zone", label = "Zone", width = 120 },
	{ key = "note", label = "Note", width = 130 }, { key = "online", label = "Last Online", width = 90 },
};
local ROSTER_ROWS, ROW_H = 24, 16;
local rosterSort, rosterDesc = "online", false;
local roster, rosterOffset = {}, 0;
local UpdateRoster;
local x = 10;
for _, c in ipairs(COLUMNS) do
	local h = CreateFrame("Button", nil, rosterBox);
	h:SetPoint("TOPLEFT", x, -8);
	h:SetWidth(c.width); h:SetHeight(16);
	local t = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	t:SetAllPoints(); t:SetJustifyH("LEFT");
	t:SetText(c.label);
	h:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD");
	h:SetScript("OnClick", function()
		if ( rosterSort == c.key ) then rosterDesc = not rosterDesc; else rosterSort, rosterDesc = c.key, false; end
		UpdateRoster();
	end);
	c.x = x;
	x = x + c.width + 6;
end
local rosterRows = {};
for i = 1, ROSTER_ROWS do
	local r = CreateFrame("Button", nil, rosterBox);
	r:SetHeight(ROW_H);
	r:SetPoint("TOPLEFT", 6, -26 - (i - 1) * ROW_H); r:SetPoint("RIGHT", -6, 0);
	r:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD");
	r.band = r:CreateTexture(nil, "BACKGROUND");
	r.band:SetAllPoints();
	r.band:SetTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0);
	r.cells = {};
	for j, c in ipairs(COLUMNS) do
		local t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		t:SetPoint("LEFT", c.x - 6 + 4, 0);
		t:SetWidth(c.width); t:SetHeight(ROW_H);
		t:SetJustifyH("LEFT");
		r.cells[j] = t;
	end
	r:SetScript("OnClick", function(self, button)
		local m = self.member;
		if ( not m ) then return; end
		if ( button == "RightButton" ) then
			FriendsFrame_ShowDropdown(m.name, m.online);
		elseif ( IsModifiedClick("CHATLINK") or IsShiftKeyDown() ) then
			ChatFrame_SendTell(m.name);
		end
	end);
	r:SetScript("OnDoubleClick", function(self) if ( self.member ) then ChatFrame_SendTell(self.member.name); end end);
	r:SetScript("OnEnter", function(self)
		local m = self.member;
		if ( not m ) then return; end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:AddLine(L.ColoredName(m.name, m.class));
		GameTooltip:AddLine(string.format("Level %d %s", m.level or 0, m.className or ""), 1, 1, 1);
		GameTooltip:AddLine(m.rank or "", 1, 0.82, 0);
		if ( m.zone and m.zone ~= "" ) then GameTooltip:AddLine(m.zone, 1, 1, 1); end
		if ( m.note and m.note ~= "" ) then GameTooltip:AddLine("Note: "..m.note, 0.8, 0.8, 0.8, 1); end
		if ( m.officerNote and m.officerNote ~= "" and CanViewOfficerNote() ) then GameTooltip:AddLine("Officer note: "..m.officerNote, 0.25, 0.75, 0.25, 1); end
		GameTooltip:AddLine(m.online and "|cff20ff20Online|r" or ("Last online: "..m.lastText), 0.7, 0.7, 0.7);
		GameTooltip:AddLine("Double click: whisper. Right click: menu.", 0.5, 0.5, 0.5);
		GameTooltip:Show();
	end);
	r:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	rosterRows[i] = r;
end
rosterBox:EnableMouseWheel(true);
rosterBox:SetScript("OnMouseWheel", function(self, delta)
	rosterOffset = math.max(0, math.min(#roster - ROSTER_ROWS, rosterOffset - delta * 3));
	UpdateRoster();
end);
local offlineCheck = CreateFrame("CheckButton", "TemucraftGuildShowOffline", rosterView, "UICheckButtonTemplate");
offlineCheck:SetPoint("TOPLEFT", -2, 2);
offlineCheck:SetWidth(24); offlineCheck:SetHeight(24);
_G["TemucraftGuildShowOfflineText"]:SetText("Show offline members");
offlineCheck:SetScript("OnClick", function(self)
	SetGuildRosterShowOffline(self:GetChecked() and true or false);
	GuildRoster();
end);
local rosterCount = rosterView:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
rosterCount:SetPoint("TOPRIGHT", -4, -6);

-- the roster from the client's guild roster
local function ReadRoster()
	local list, online = {}, 0;
	local total = GetNumGuildMembers(true) or GetNumGuildMembers();
	for i = 1, (GetNumGuildMembers() or 0) do
		local name, rank, rankIndex, level, className, zone, note, officerNote, isOnline, status, classFile = GetGuildRosterInfo(i);
		if ( name ) then
			local years, months, days, hours = GetGuildRosterLastOnline(i);
			local m = { name = name, rank = rank, rankIndex = rankIndex, level = level, className = className, zone = zone or "",
				note = note or "", officerNote = officerNote, online = isOnline and true or false, class = classFile,
				last = L.StockSeconds(years, months, days, hours), lastText = L.LastOnline(years, months, days, hours) };
			if ( m.online ) then online = online + 1; end
			rosterClass[name] = classFile;
			table.insert(list, m);
		end
	end
	return list, online, total;
end

local numOnline, numTotal = 0, 0;
UpdateRoster = function()
	roster, numOnline, numTotal = ReadRoster();
	L.SortRoster(roster, rosterSort, rosterDesc);
	if ( rosterView:IsShown() ) then
		rosterOffset = math.max(0, math.min(rosterOffset, #roster - ROSTER_ROWS));
		for i, r in ipairs(rosterRows) do
			local m = roster[rosterOffset + i];
			r.member = m;
			if ( m ) then
				local grey = not m.online;
				r.cells[1]:SetText(grey and ("|cff808080"..m.name.."|r") or L.ColoredName(m.name, m.class));
				r.cells[2]:SetText(m.level or "");
				r.cells[3]:SetText(m.rank or "");
				r.cells[4]:SetText(m.zone);
				r.cells[5]:SetText(m.note);
				r.cells[6]:SetText(m.online and "|cff20ff20Online|r" or m.lastText);
				local a = grey and 0.6 or 1;
				for j = 2, #COLUMNS do r.cells[j]:SetAlpha(a); end
				r:Show();
			else
				r:Hide();
			end
		end
		rosterCount:SetText(string.format("%d online, %d members", numOnline, numTotal or #roster));
		offlineCheck:SetChecked(GetGuildRosterShowOffline());
	end
	-- the online members beside the chat
	local items = {};
	for _, m in ipairs(roster) do
		if ( m.online ) then
			table.insert(items, { text = L.ColoredName(m.name, m.class), right = m.level and tostring(m.level) or "", tip = m.zone, sortName = string.lower(m.name) });
		end
	end
	table.sort(items, function(a, b) return a.sortName < b.sortName; end);
	memberList:SetItems(items);
	membersTitle:SetText(string.format("Online (%d)", numOnline));
	guildOnline:SetText(string.format("|cff20ff20%d|r online, %d members", numOnline, numTotal or #roster));
end

------------------------------------------------------------------ News
local newsView = View();
views.news = newsView;
local newsBox = Panel(newsView);
newsBox:SetAllPoints();
local newsTitle = newsBox:CreateFontString(nil, "OVERLAY", "GameFontNormal");
newsTitle:SetPoint("TOPLEFT", 12, -10);
newsTitle:SetText("Guild News");
local newsList = TemucraftGuild_CreateList(newsBox, 28, 16);
newsList:SetPoint("TOPLEFT", 4, -28); newsList:SetPoint("BOTTOMRIGHT", -4, 4);
newsList.empty = "No news yet.";
newsList.onMore = function() Ask("NEWS~"..#L.news); end;

-- the stock guild log (last entries), when the server keeps none
local function StockEvents()
	local out = {};
	for i = (GetNumGuildEvents and GetNumGuildEvents() or 0), 1, -1 do
		local type, player1, player2, rank, year, month, day, hour = GetGuildEventInfo(i);
		table.insert(out, { type = type, name1 = player1, class1 = ClassOf(player1), name2 = player2, class2 = ClassOf(player2), rankText = rank,
			seconds = L.StockSeconds(year, month, day, hour) });
	end
	return out;
end

local function UpdateNews()
	if ( not newsView:IsShown() ) then return; end
	local items = {};
	if ( TemucraftGuild_HasServer("news") ) then
		for _, n in ipairs(L.news) do
			local icon;
			if ( n.kind == "a" and GetAchievementInfo ) then icon = select(10, GetAchievementInfo(n.value));
			elseif ( (n.kind == "i" or n.kind == "c") and GetItemIcon ) then icon = GetItemIcon(n.value); end
			table.insert(items, { text = L.NewsLine(n, RankName), right = L.Ago(time() - n.time), icon = icon });
		end
		newsList:SetItems(items, L.newsMore);
	else
		for _, e in ipairs(StockEvents()) do
			table.insert(items, { text = L.EventLine(e, RankName), right = L.Ago(e.seconds) });
		end
		newsList:SetItems(items, false);
	end
end
L.On("news", UpdateNews);

------------------------------------------------------------------ Info
local infoView = View();
views.info = infoView;
local infoLeft = Panel(infoView);
infoLeft:SetPoint("TOPLEFT"); infoLeft:SetPoint("BOTTOMLEFT");
infoLeft:SetWidth(300);
local infoRight = Panel(infoView);
infoRight:SetPoint("TOPLEFT", infoLeft, "TOPRIGHT", 6, 0); infoRight:SetPoint("BOTTOMRIGHT");

local function TextArea(parent, name, top, height, label)
	local l = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	l:SetPoint("TOPLEFT", 12, top);
	l:SetText(label);
	local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate");
	scroll:SetPoint("TOPLEFT", 12, top - 18);
	scroll:SetWidth(250); scroll:SetHeight(height);
	local edit = CreateFrame("EditBox", name.."EditBox", scroll);
	edit:SetMultiLine(true);
	edit:SetWidth(245); edit:SetHeight(height);
	edit:SetFontObject(GameFontHighlightSmall);
	edit:SetAutoFocus(false);
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
	edit:SetScript("OnTextChanged", function(self) ScrollingEdit_OnTextChanged(self, scroll); end);
	edit:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged);
	edit:SetScript("OnUpdate", function(self, elapsed) ScrollingEdit_OnUpdate(self, elapsed, scroll); end);
	scroll:SetScrollChild(edit);
	local save = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
	save:SetPoint("TOPRIGHT", scroll, "BOTTOMRIGHT", 22, -4);
	save:SetWidth(80); save:SetHeight(20);
	save:SetText(SAVE or "Save");
	return edit, save;
end
local motdEdit, motdSave = TextArea(infoLeft, "TemucraftGuildMotd", -10, 70, "Message of the Day");
motdEdit:SetMaxLetters(128);
motdSave:SetScript("OnClick", function() GuildSetMOTD(motdEdit:GetText() or ""); motdEdit:ClearFocus(); end);
local infoEdit, infoSave = TextArea(infoLeft, "TemucraftGuildInfoText", -140, 250, "Guild Information");
infoEdit:SetMaxLetters(500);
infoSave:SetScript("OnClick", function() SetGuildInfoText(infoEdit:GetText() or ""); infoEdit:ClearFocus(); end);

local logTitle = infoRight:CreateFontString(nil, "OVERLAY", "GameFontNormal");
logTitle:SetPoint("TOPLEFT", 12, -10);
logTitle:SetText("Guild Log");
local eventList = TemucraftGuild_CreateList(infoRight, 28, 16);
eventList:SetPoint("TOPLEFT", 4, -28); eventList:SetPoint("BOTTOMRIGHT", -4, 4);
eventList.empty = "Nothing in the guild log.";
eventList.onMore = function() Ask("ELOG~"..#L.events); end;

local function UpdateInfo()
	if ( not infoView:IsShown() ) then return; end
	if ( not motdEdit:HasFocus() ) then motdEdit:SetText(GetGuildRosterMOTD() or ""); end
	if ( not infoEdit:HasFocus() ) then infoEdit:SetText(GetGuildInfoText() or ""); end
	if ( CanEditMOTD() ) then motdSave:Show(); motdEdit:EnableMouse(true); else motdSave:Hide(); motdEdit:EnableMouse(false); end
	if ( CanEditGuildInfo() ) then infoSave:Show(); infoEdit:EnableMouse(true); else infoSave:Hide(); infoEdit:EnableMouse(false); end
	local items = {};
	if ( TemucraftGuild_HasServer("bank") ) then
		for _, e in ipairs(L.events) do table.insert(items, { text = L.EventLine(e, RankName), right = L.Ago(time() - e.time) }); end
		eventList:SetItems(items, L.eventsMore);
	else
		for _, e in ipairs(StockEvents()) do table.insert(items, { text = L.EventLine(e, RankName), right = L.Ago(e.seconds) }); end
		eventList:SetItems(items, false);
	end
end
L.On("events", UpdateInfo);

------------------------------------------------------------------ Perks
local perksView = View();
views.perks = perksView;
local perksBox = Panel(perksView);
perksBox:SetAllPoints();
local perksTitle = perksBox:CreateFontString(nil, "OVERLAY", "GameFontNormal");
perksTitle:SetPoint("TOPLEFT", 12, -10);
perksTitle:SetText("Guild Perks");
local perkList = TemucraftGuild_CreateList(perksBox, 20, 22);
perkList:SetPoint("TOPLEFT", 4, -28); perkList:SetPoint("BOTTOMRIGHT", -4, 4);
perkList.empty = "No perks on this server.";
local PERK_STATES = { ["1"] = "|cff20ff20Active|r", ["0"] = "|cffffff40Switched off|r", l = "|cffff8040Locked|r", x = "|cff808080Not on this server|r" };
local function UpdatePerks()
	if ( not perksView:IsShown() ) then return; end
	local items = {};
	for _, p in ipairs(L.perks) do
		local spellName, _, icon = nil, nil, nil;
		if ( p.spell > 0 and GetSpellInfo ) then spellName, _, icon = GetSpellInfo(p.spell); end
		table.insert(items, { text = (p.state == "1" and "|cffffffff" or "|cff9d9d9d")..p.name.."|r", right = PERK_STATES[p.state] or "",
			icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark", tip = p.name, link = (p.spell > 0 and spellName) and ("|Hspell:"..p.spell.."|h["..spellName.."]|h") or nil });
	end
	perkList:SetItems(items);
end
L.On("perks", UpdatePerks);

------------------------------------------------------------------ Tabs
local TABS = {
	{ "Chat", "chat" }, { "Roster", "roster" }, { "News", "news" }, { "Info", "info" }, { "Perks", "perks", function() return TemucraftGuild_HasServer("perks"); end },
};
local tabs, current = {}, "chat";
local ShowView;
for i, t in ipairs(TABS) do
	local tab = CreateFrame("Button", "TemucraftGuildFrameTab"..i, frame, "CharacterFrameTabButtonTemplate");
	tab:SetID(i);
	tab:SetText(t[1]);
	tab:SetScript("OnClick", function() PlaySound("igCharacterInfoTab"); ShowView(t[2]); end);
	tabs[i] = tab;
end
PanelTemplates_SetNumTabs(frame, #TABS);
local function LayoutTabs()
	local last;
	for i, t in ipairs(TABS) do
		local tab = tabs[i];
		if ( t[3] and not t[3]() ) then
			tab:Hide();
		else
			tab:ClearAllPoints();
			if ( last ) then tab:SetPoint("LEFT", last, "RIGHT", -16, 0); else tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 20, 8); end
			tab:Show();
			last = tab;
		end
	end
end

ShowView = function(key)
	if ( key == "perks" and not TemucraftGuild_HasServer("perks") ) then key = "chat"; end
	current = key;
	for k, v in pairs(views) do if ( k == key ) then v:Show(); else v:Hide(); end end
	for i, t in ipairs(TABS) do if ( t[2] == key ) then PanelTemplates_SetTab(frame, i); end end
	if ( key == "chat" ) then RefreshChat();
	elseif ( key == "roster" ) then GuildRoster(); UpdateRoster();
	elseif ( key == "news" ) then
		if ( TemucraftGuild_HasServer("news") ) then Ask("NEWS~0"); elseif ( QueryGuildEventLog ) then QueryGuildEventLog(); end
		UpdateNews();
	elseif ( key == "info" ) then
		if ( TemucraftGuild_HasServer("bank") ) then Ask("ELOG~0"); elseif ( QueryGuildEventLog ) then QueryGuildEventLog(); end
		UpdateInfo();
	elseif ( key == "perks" ) then Ask("PERKS"); UpdatePerks(); end
end

local function UpdateCard()
	local name, rankName = GetGuildInfo("player");
	guildName:SetText(name or "");
	guildRank:SetText(rankName and ("Rank: |cffffffff"..rankName.."|r") or "");
	motdText:SetText(GetGuildRosterMOTD() or "");
	if ( CanGuildInvite() ) then inviteButton:Show(); else inviteButton:Hide(); end
	title:SetText(name and ("Guild & Communities - "..name) or "Guild & Communities");
end

frame:SetScript("OnShow", function()
	PlaySound("igCharacterInfoOpen");
	GuildRoster();
	if ( TemucraftGuild_HasServer("chat") ) then L.live = {}; Ask("HIST~0"); end
	LayoutTabs();
	UpdateCard();
	UpdateRoster();
	ShowView(current);
	if ( UpdateMicroButtons ) then UpdateMicroButtons(); end
end);
frame:SetScript("OnHide", function()
	PlaySound("igCharacterInfoClose");
	if ( UpdateMicroButtons ) then UpdateMicroButtons(); end
end);

function TemucraftGuild_Toggle()
	if ( frame:IsShown() ) then HideUIPanel(frame); return; end
	if ( not IsInGuild() ) then return; end
	ShowUIPanel(frame);
end

-- J, the micro menu's guild button and everything else that opens the stock guild tab
stockToggle = ToggleFriendsFrame;
TemucraftStockToggleFriendsFrame = stockToggle;
function ToggleFriendsFrame(tab, ...)
	if ( tab == 3 and not TemucraftUI_IsClassic("guild") ) then
		if ( FriendsFrame:IsShown() and PanelTemplates_GetSelectedTab(FriendsFrame) == 3 ) then HideUIPanel(FriendsFrame); end
		TemucraftGuild_Toggle();
		return;
	end
	return stockToggle(tab, ...);
end

hooksecurefunc("UpdateMicroButtons", function()
	if ( frame:IsShown() ) then
		if ( SocialsMicroButton ) then SocialsMicroButton:SetButtonState("PUSHED", 1); end
		if ( TemucraftMicroButton_guild ) then TemucraftMicroButton_guild:SetButtonState("PUSHED", 1); end
	end
end);

TemucraftUI_OnChange("classicguild", function(on)
	if ( on and frame:IsShown() ) then HideUIPanel(frame); end
end);

SLASH_TEMUCRAFTGUILD1 = "/tguild";
SlashCmdList["TEMUCRAFTGUILD"] = function(msg)
	msg = strlower(strtrim(msg or ""));
	if ( msg == "classic" or msg == "old" ) then
		TemucraftUI_SetClassic("guild", true);
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffTemucraft:|r J opens the classic guild window now (/tguild new to switch back).");
	elseif ( msg == "new" or msg == "retail" ) then
		TemucraftUI_SetClassic("guild", false);
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffTemucraft:|r J opens the new guild window now.");
	else
		TemucraftGuild_Toggle();
	end
end;

----------------------------------------------------------------------------------------------------------------------
-- Events
----------------------------------------------------------------------------------------------------------------------
-- J for the guild window, once per account, if J and the Guild binding are both free
local function BindJ()
	if ( InCombatLockdown() or not TemucraftStore_Get or TemucraftStore_Get("A", "ui.guildkey") == "1" ) then return; end
	TemucraftStore_Set("A", "ui.guildkey", "1");
	if ( GetBindingKey("TOGGLEGUILDTAB") ) then return; end
	local action = GetBindingAction("J");
	if ( action and action ~= "" ) then return; end
	SetBinding("J", "TOGGLEGUILDTAB");
	SaveBindings(GetCurrentBindingSet());
end

-- the last lines of guild chat, in the chat window after login
local function PrintLogin(lines)
	if ( #lines == 0 or not TemucraftUI_GetOption("guildloginchat", true) ) then return; end
	DEFAULT_CHAT_FRAME:AddMessage("|cff40ff40Recent guild chat:|r", 0.25, 1, 0.25);
	for _, l in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage(ChatLine(l), ChatColor(l.ch)); end
end
L.On("login", PrintLogin);
L.On("server", function() if ( frame:IsShown() ) then LayoutTabs(); end end);

local hello = false;
local events = CreateFrame("Frame");
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "CHAT_MSG_ADDON", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "GUILD_ROSTER_UPDATE",
	"PLAYER_GUILD_UPDATE", "GUILD_MOTD", "GUILD_EVENT_LOG_UPDATE", "PLAYER_REGEN_ENABLED" }) do
	events:RegisterEvent(e);
end
events:SetScript("OnEvent", function(self, event, a1, a2, a3, a4)
	if ( event == "CHAT_MSG_ADDON" ) then
		if ( a1 == L.PREFIX and a3 == "WHISPER" and a4 == UnitName("player") ) then L.OnMessage(a2); end
	elseif ( event == "PLAYER_ENTERING_WORLD" ) then
		if ( not hello ) then
			hello = true;
			Ask("HELLO");
			if ( IsInGuild() ) then GuildRoster(); end
			if ( TemucraftStore_OnReady ) then TemucraftStore_OnReady(BindJ); end
		end
	elseif ( event == "PLAYER_REGEN_ENABLED" ) then
		if ( TemucraftStore_IsReady and TemucraftStore_IsReady() ) then BindJ(); end
	elseif ( event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_OFFICER" ) then
		L.AddLive(event == "CHAT_MSG_OFFICER" and "o" or "g", a2, ClassOf(a2), a1);
	elseif ( event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" ) then
		if ( event == "PLAYER_GUILD_UPDATE" and not IsInGuild() and frame:IsShown() ) then HideUIPanel(frame); return; end
		UpdateRoster();
		if ( frame:IsShown() ) then UpdateCard(); end
	elseif ( event == "GUILD_MOTD" ) then
		if ( frame:IsShown() ) then UpdateCard(); UpdateInfo(); end
	elseif ( event == "GUILD_EVENT_LOG_UPDATE" ) then
		UpdateNews(); UpdateInfo();
	end
end);
