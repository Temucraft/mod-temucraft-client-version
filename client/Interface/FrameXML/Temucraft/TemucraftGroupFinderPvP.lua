-- Temucraft Group Finder: the Player vs. Player tab (retail-style PvP window for 3.3.5; TemucraftGroupFinder.lua is the
-- window). Three categories on the left:
--   Battlegrounds        Random Battleground and the Call to Arms (holiday) first, then every battleground you can
--                        enter (GetBattlegroundInfo, the "queue from anywhere" list); the selected one's art, its
--                        description or its win / loss rewards (honor, arena points), Join Battle and Join as Group
--                        (JoinBattlefield after RequestBattlegroundInstanceInfo, like PVPBattlegroundFrame), your queues
--                        with their time and Leave Queue / Enter, and the Wintergrasp timer (3.3.5 queues Wintergrasp
--                        only at a battlemaster or in the zone: the timer says when).
--   Arena                your 2v2, 3v3 and 5v5 teams (GetArenaTeam): banner in the team's colours, rating, this week or
--                        this season, your personal rating; click a team for its roster (ArenaTeamRoster), right-click a
--                        member for the stock team menu. Off season: the stock message.
--   Honor & Conquest     honor points and arena points (the 3.3.5 currencies), honorable kills today / yesterday /
--                        lifetime, and this week's arena points: an estimate from your teams with the stock formula
--                        (10 games a week, 30% of them yours; the server's rates can differ), the PvP flag.
-- The minimap battlefield button, its menu and the "ready to enter" popup stay stock (BattlefieldFrame.lua).
--   /pvp           opens or closes this tab (the stock /pvp toggled the PvP flag: /pvp flag does that now)

----------------------------------------------------------------------------------------------------------------------
-- The logic (no frames: tests/groupfinder_test.lua runs it with stubs)
----------------------------------------------------------------------------------------------------------------------
TemucraftGroupFinderPvPLogic = {};
local P = TemucraftGroupFinderPvPLogic;

-- GetBattlegroundInfo rows { index, name, canEnter, isHoliday, isRandom, id } -> the list: random, holiday, the rest
function P.Battlegrounds(rows)
	local random, holiday, rest = {}, {}, {};
	for _, r in ipairs(rows or {}) do
		if ( r.name and r.canEnter ) then
			if ( r.isRandom ) then table.insert(random, r);
			elseif ( r.isHoliday ) then table.insert(holiday, r);
			else table.insert(rest, r); end
		end
	end
	local out = {};
	for _, list in ipairs({ random, holiday, rest }) do for _, r in ipairs(list) do table.insert(out, r); end end
	return out;
end

-- the art of a battleground (BattlemasterList ids, as PVPBATTLEGROUND_TEXTURELIST)
P.ART = {
	[1] = "Interface\\PVPFrame\\PvpBg-AlteracValley", [2] = "Interface\\PVPFrame\\PvpBg-WarsongGulch",
	[3] = "Interface\\PVPFrame\\PvpBg-ArathiBasin", [7] = "Interface\\PVPFrame\\PvpBg-EyeOfTheStorm",
	[9] = "Interface\\PVPFrame\\PvpBg-StrandOfTheAncients", [30] = "Interface\\PVPFrame\\PvpBg-IsleOfConquest",
	[32] = "Interface\\PVPFrame\\PvpRandomBg",
};
function P.Art(id, isRandom)
	if ( isRandom ) then return P.ART[32]; end
	return P.ART[id] or "Interface\\PVPFrame\\PvpRandomBg";
end

-- GetBattlefieldStatus(i) rows { index, status, mapName, teamSize, registered, waited (s), estimate (s), expires (s) }
-- -> what to show: { index, kind = "queued" | "confirm" | "active", name, text }
function P.Queues(rows, clock)
	local out = {};
	for _, r in ipairs(rows or {}) do
		if ( r.status and r.status ~= "none" and r.status ~= "error" ) then
			local name = r.mapName or "?";
			if ( (r.teamSize or 0) > 0 ) then
				name = string.format("%s %dv%d", r.registered and "Rated" or "Skirmish", r.teamSize, r.teamSize);
			end
			local text;
			if ( r.status == "queued" ) then
				text = "In queue "..clock(r.waited or 0);
				if ( r.estimate and r.estimate > 0 ) then text = text..", about "..clock(r.estimate); end
			elseif ( r.status == "confirm" ) then
				text = "Ready to enter"..((r.expires and r.expires > 0) and (" ("..clock(r.expires)..")") or "");
			else
				text = "In progress";
			end
			table.insert(out, { index = r.index, kind = (r.status == "queued" or r.status == "confirm") and r.status or "active", name = name, text = text });
		end
	end
	return out;
end

-- arena points for a week (AzerothCore's ArenaTeam::GetPoints with the default rates): the team rating, or the
-- personal one when it is 150 or more lower; 1500 and under: 344 (season 6+; earlier seasons 0.22 x rating + 14)
P.RATES = { [2] = 0.76, [3] = 0.88, [5] = 1 };
function P.ArenaPoints(teamRating, personalRating, size, season)
	local rating = teamRating or 0;
	if ( personalRating and personalRating + 150 < rating ) then rating = personalRating; end
	local points;
	if ( rating <= 1500 ) then
		if ( season and season > 0 and season < 6 ) then points = rating * 0.22 + 14; else points = 344; end
	else
		points = 1511.26 / (1 + 1639.28 * math.exp(-0.00412 * rating));
	end
	points = points * (P.RATES[size] or 1);
	return math.floor(points);
end

-- this week's points: teams { { size, rating, personal, weekGames, playerWeekGames } }; the best team counts
-- returns points (0 = none yet), the size of that team, and per team { size, points, need = games still needed,
-- needYou = games you still need to play }
P.GAMES_REQUIRED = 10;
function P.ArenaWeek(teams, season, required)
	required = required or P.GAMES_REQUIRED;
	local best, bestSize, rows = 0, nil, {};
	for _, t in ipairs(teams or {}) do
		local row = { size = t.size, points = P.ArenaPoints(t.rating, t.personal, t.size, season), need = 0, needYou = 0 };
		local week = t.weekGames or 0;
		if ( week < required ) then row.need = required - week; end
		local forYou = math.ceil(math.max(week, required) * 0.3);
		local mine = t.playerWeekGames or 0;
		if ( mine < forYou ) then row.needYou = forYou - mine; end
		if ( row.need == 0 and row.needYou == 0 and row.points > best ) then best, bestSize = row.points, t.size; end
		table.insert(rows, row);
	end
	return best, bestSize, rows;
end

-- wins / played -> "60%" ("-" when none)
function P.WinRate(played, wins)
	if ( not played or played <= 0 ) then return "-"; end
	return math.floor((wins or 0) / played * 100 + 0.5).."%";
end

-- the team slots in size order (2, 3, 5): GetArenaTeam index for each size, or nil
function P.TeamSlots(sizeOf)
	local slots = { [2] = nil, [3] = nil, [5] = nil };
	for i = 1, 3 do
		local size = sizeOf(i);
		if ( size and (size == 2 or size == 3 or size == 5) ) then slots[size] = i; end
	end
	return slots;
end

-- /pvp: "flag" / "toggle" / "on" / "off" for the PvP flag (the stock /pvp), anything else opens the tab
function P.Slash(msg)
	local m = string.lower(string.match(msg or "", "^%s*(%S*)") or "");
	if ( m == "flag" or m == "toggle" ) then return "flag"; end
	if ( m == "on" ) then return "on"; end
	if ( m == "off" ) then return "off"; end
	return "open";
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

local Later = TemucraftGroupFinder_Later;
local L = TemucraftGroupFinderLogic;

local function Inset(parent)
	local f = CreateFrame("Frame", nil, parent);
	TemucraftStyle_Inset(f);
	return f;
end
local function Tip(owner, title, text)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT");
	GameTooltip:SetText(title);
	if ( text ) then GameTooltip:AddLine(text, 1, 1, 1, true); end
	GameTooltip:Show();
end
local function Button(parent, label, width)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
	b:SetWidth(width); b:SetHeight(22);
	b:SetText(label);
	return b;
end
local function Faction() return UnitFactionGroup("player") or "Alliance"; end
local function HonorIcon(size) return "|TInterface\\PVPFrame\\PVP-Currency-"..Faction()..":"..(size or 16)..":"..(size or 16)..":0:0|t"; end
local function ArenaIcon(size) return "|TInterface\\PVPFrame\\PVP-ArenaPoints-Icon:"..(size or 16)..":"..(size or 16)..":0:0|t"; end

----------------------------------------------------------------------------------------------------------------------
-- Battlegrounds
----------------------------------------------------------------------------------------------------------------------
local bgPage = CreateFrame("Frame");
local selectedBG = nil;     -- GetBattlegroundInfo index
local bgList = {};
local listBox = Inset(bgPage);
listBox:SetPoint("TOPLEFT", 0, 0); listBox:SetPoint("BOTTOMLEFT", 0, 96); listBox:SetWidth(210);
local BG_ROW = 34;
local bgRows = {};
for i = 1, 10 do
	local b = CreateFrame("Button", nil, listBox);
	b:SetHeight(BG_ROW - 2);
	b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * BG_ROW); b:SetPoint("RIGHT", -6, 0);
	b.bar = TemucraftStyle_Bar(b);
	TemucraftStyle_Highlight(b);
	b.sel = TemucraftStyle_Glow(b);
	b.sel:Hide();
	b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	b.name:SetPoint("LEFT", 8, 4); b.name:SetPoint("RIGHT", -24, 0); b.name:SetJustifyH("LEFT");
	b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -1);
	b.status = b:CreateTexture(nil, "OVERLAY");
	b.status:SetWidth(18); b.status:SetHeight(18);
	b.status:SetPoint("RIGHT", -4, 0);
	b:SetScript("OnClick", function(self)
		if ( not self.row ) then return; end
		PlaySound("igMainMenuOptionCheckBoxOn");
		if ( selectedBG ~= self.row.index ) then
			selectedBG = self.row.index;
			RequestBattlegroundInstanceInfo(selectedBG);
		end
		Later();
	end);
	b:SetScript("OnEnter", function(self) if ( self.statusTip ) then Tip(self, self.row.name, self.statusTip); end end);
	b:SetScript("OnLeave", GameTooltip_Hide);
	bgRows[i] = b;
end
local bgEmpty = listBox:CreateFontString(nil, "OVERLAY", "GameFontDisable");
bgEmpty:SetPoint("CENTER"); bgEmpty:SetWidth(180);
bgEmpty:SetText("No battleground for your level yet.");

local detail = Inset(bgPage);
detail:SetPoint("TOPLEFT", listBox, "TOPRIGHT", 6, 0); detail:SetPoint("BOTTOMRIGHT", 0, 96);
local art = detail:CreateTexture(nil, "BACKGROUND");
art:SetPoint("TOPLEFT", 5, -5); art:SetPoint("TOPRIGHT", -5, -5); art:SetHeight(150);
art:SetTexCoord(0, 1, 0, 0.6);
local artShade = detail:CreateTexture(nil, "BORDER");
artShade:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT"); artShade:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT"); artShade:SetHeight(40);
artShade:SetTexture(0, 0, 0, 0.55);
local bgTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge");
bgTitle:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", 12, 10); bgTitle:SetPoint("RIGHT", art, "RIGHT", -12, 0); bgTitle:SetJustifyH("LEFT");
local bgDesc = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
bgDesc:SetPoint("TOPLEFT", art, "BOTTOMLEFT", 10, -10); bgDesc:SetPoint("RIGHT", -12, 0); bgDesc:SetJustifyH("LEFT");
local rewardTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal");
rewardTitle:SetText(REWARDS or "Rewards");
local rewardBar = TemucraftStyle_Header(rewardTitle);
local winText = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
local lossText = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
rewardTitle:SetPoint("TOPLEFT", bgDesc, "BOTTOMLEFT", 0, -22);
winText:SetPoint("TOPLEFT", rewardTitle, "BOTTOMLEFT", 0, -12);
lossText:SetPoint("TOPLEFT", winText, "BOTTOMLEFT", 0, -6);
local wgText = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
wgText:SetPoint("BOTTOMLEFT", 12, 40); wgText:SetPoint("RIGHT", -12, 0); wgText:SetJustifyH("LEFT");
local wgFrame = CreateFrame("Frame", nil, detail);
wgFrame:SetAllPoints(wgText);
wgFrame:EnableMouse(true);
wgFrame:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP");
	GameTooltip:SetText("Wintergrasp");
	GameTooltip:AddLine((CanQueueForWintergrasp and CanQueueForWintergrasp()) and PVPBATTLEGROUND_WINTERGRASPTIMER_CAN_QUEUE or PVPBATTLEGROUND_WINTERGRASPTIMER_CANNOT_QUEUE, 1, 1, 1, true);
	GameTooltip:Show();
end);
wgFrame:SetScript("OnLeave", GameTooltip_Hide);
local joinButton = Button(detail, BATTLEFIELD_JOIN or "Join Battle", 130);
joinButton:SetPoint("BOTTOMRIGHT", -10, 10);
local groupButton = Button(detail, JOIN_AS_GROUP or "Join as Group", 130);
groupButton:SetPoint("RIGHT", joinButton, "LEFT", -6, 0);
joinButton:SetScript("OnClick", function() JoinBattlefield(0); Later(); end);
groupButton:SetScript("OnClick", function() JoinBattlefield(0, true); Later(); end);
groupButton:SetScript("OnEnter", function(self) Tip(self, JOIN_AS_GROUP or "Join as Group", JOIN_AS_GROUP_TOOLTIP); end);
groupButton:SetScript("OnLeave", GameTooltip_Hide);

-- the queues (MAX_BATTLEFIELD_QUEUES; arenas too)
local queueBox = Inset(bgPage);
queueBox:SetPoint("BOTTOMLEFT", 0, 0); queueBox:SetPoint("BOTTOMRIGHT", 0, 0); queueBox:SetHeight(90);
local queueTitle = queueBox:CreateFontString(nil, "OVERLAY", "GameFontNormal");
queueTitle:SetPoint("TOPLEFT", 12, -10);
queueTitle:SetText("Your queues");
local queueNone = queueBox:CreateFontString(nil, "OVERLAY", "GameFontDisable");
queueNone:SetPoint("TOPLEFT", queueTitle, "BOTTOMLEFT", 0, -10);
queueNone:SetText("You are not queued for a battleground or an arena.");
local queueRows = {};
for i = 1, 3 do
	local r = CreateFrame("Frame", nil, queueBox);
	r:SetHeight(22);
	r:SetPoint("TOPLEFT", 12, -28 - (i - 1) * 24); r:SetPoint("RIGHT", -10, 0);
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	r.name:SetPoint("LEFT", 0, 0); r.name:SetWidth(200); r.name:SetJustifyH("LEFT");
	r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	r.text:SetPoint("LEFT", 210, 0);
	r.leave = Button(r, LEAVE_QUEUE or "Leave Queue", 110);
	r.leave:SetPoint("RIGHT", 0, 0);
	r.enter = Button(r, ENTER_BATTLE or "Enter Battle", 110);
	r.enter:SetPoint("RIGHT", r.leave, "LEFT", -4, 0);
	r.leave:SetScript("OnClick", function(self) local q = self:GetParent().index; if ( q ) then AcceptBattlefieldPort(q); end Later(); end);
	r.enter:SetScript("OnClick", function(self) local q = self:GetParent().index; if ( q ) then AcceptBattlefieldPort(q, 1); end Later(); end);
	queueRows[i] = r;
end

local function ReadBattlegrounds()
	local rows = {};
	for i = 1, (GetNumBattlegroundTypes and GetNumBattlegroundTypes() or 0) do
		local name, canEnter, isHoliday, isRandom, id = GetBattlegroundInfo(i);
		rows[#rows + 1] = { index = i, name = name, canEnter = canEnter, isHoliday = isHoliday, isRandom = isRandom, id = id };
	end
	return P.Battlegrounds(rows);
end
local function ReadQueues()
	local rows = {};
	for i = 1, (MAX_BATTLEFIELD_QUEUES or 2) do
		local status, mapName, instanceID, minLevel, maxLevel, teamSize, registered = GetBattlefieldStatus(i);
		local row = { index = i, status = status, mapName = mapName, teamSize = teamSize, registered = registered };
		if ( status == "queued" ) then
			row.waited = (GetBattlefieldTimeWaited(i) or 0) / 1000;
			row.estimate = (GetBattlefieldEstimatedWaitTime(i) or 0) / 1000;
		elseif ( status == "confirm" ) then
			row.expires = GetBattlefieldPortExpiration and GetBattlefieldPortExpiration(i) or 0;
		end
		rows[#rows + 1] = row;
	end
	return P.Queues(rows, L.Clock), rows;
end

local function UpdateQueues()
	local queues, raw = ReadQueues();
	for i, r in ipairs(queueRows) do
		local q = queues[i];
		if ( q ) then
			r.index = q.index;
			r.name:SetText(q.name);
			r.text:SetText(q.text);
			if ( q.kind == "active" ) then r.leave:Hide(); else r.leave:Show(); end
			if ( q.kind == "confirm" ) then r.enter:Show(); else r.enter:Hide(); end
			r:Show();
		else
			r:Hide();
		end
	end
	if ( #queues == 0 ) then queueNone:Show(); else queueNone:Hide(); end
	return raw;
end

local function UpdateBattlegrounds()
	bgList = ReadBattlegrounds();
	local found = false;
	for _, r in ipairs(bgList) do if ( r.index == selectedBG ) then found = true; end end
	if ( not found ) then
		selectedBG = bgList[1] and bgList[1].index;
		if ( selectedBG ) then RequestBattlegroundInstanceInfo(selectedBG); end
	end
	local raw = UpdateQueues();
	local faction = "Interface\\PVPFrame\\PVP-Currency-"..Faction();
	for i, b in ipairs(bgRows) do
		local r = bgList[i];
		b.row = r;
		if ( r ) then
			b.name:SetText(r.isRandom and (RANDOM_BATTLEGROUND or r.name) or r.name);
			b.sub:SetText(r.isRandom and r.name ~= RANDOM_BATTLEGROUND and r.name or (r.isHoliday and (BATTLEGROUND_HOLIDAY or "Call to Arms") or ""));
			if ( r.index == selectedBG ) then b.sel:Show(); else b.sel:Hide(); end
			b.status:Hide(); b.statusTip = nil;
			for _, q in ipairs(raw) do
				if ( q.mapName == r.name and q.status == "queued" ) then
					b.status:SetTexture(faction); b.status:SetTexCoord(0, 1, 0, 1); b.status:Show(); b.statusTip = BATTLEFIELD_QUEUE_STATUS;
				elseif ( q.mapName == r.name and q.status == "confirm" ) then
					b.status:SetTexture("Interface\\CharacterFrame\\UI-StateIcon"); b.status:SetTexCoord(0.45, 0.95, 0, 0.5); b.status:Show();
					b.statusTip = BATTLEFIELD_CONFIRM_STATUS;
				end
			end
			b:Show();
		else
			b:Hide();
		end
	end
	if ( #bgList == 0 ) then bgEmpty:Show(); else bgEmpty:Hide(); end
	-- the selected one
	local sel;
	for _, r in ipairs(bgList) do if ( r.index == selectedBG ) then sel = r; end end
	if ( sel ) then
		art:SetTexture(P.Art(sel.id, sel.isRandom));
		bgTitle:SetText(sel.isRandom and (RANDOM_BATTLEGROUND or sel.name) or (sel.isHoliday and (sel.name.." - "..(BATTLEGROUND_HOLIDAY or "")) or sel.name));
		local hasWin, winHonor, winArena, lossHonor, lossArena;
		if ( sel.isRandom ) then
			hasWin, winHonor, winArena, lossHonor, lossArena = GetRandomBGHonorCurrencyBonuses();
			bgDesc:SetText(RANDOM_BATTLEGROUND_EXPLANATION or "");
		elseif ( sel.isHoliday ) then
			hasWin, winHonor, winArena, lossHonor, lossArena = GetHolidayBGHonorCurrencyBonuses();
			bgDesc:SetText(BATTLEGROUND_HOLIDAY_EXPLANATION or "");
		else
			local _, description = GetBattlefieldInfo();
			bgDesc:SetText(description or "");
		end
		if ( sel.isRandom or sel.isHoliday ) then
			rewardTitle:Show(); rewardBar:Show();
			winText:SetText(format("%s:  %s %d   %s %d", WIN or "Win", HonorIcon(), winHonor or 0, ArenaIcon(), winArena or 0)
				..(hasWin and "  |cff888888(first win done today)|r" or ""));
			lossText:SetText(format("%s:  %s %d   %s %d", LOSS or "Loss", HonorIcon(), lossHonor or 0, ArenaIcon(), lossArena or 0));
			winText:Show(); lossText:Show();
		else
			rewardTitle:Hide(); rewardBar:Hide(); winText:Hide(); lossText:Hide();
		end
		joinButton:Enable();
		local _, _, maxGroup = GetBattlefieldInfo();
		groupButton:SetText((maxGroup == 5) and (JOIN_AS_PARTY or "Join as Party") or (JOIN_AS_GROUP or "Join as Group"));
		if ( (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0) and IsPartyLeader() ) then groupButton:Enable(); else groupButton:Disable(); end
	else
		art:SetTexture("Interface\\PVPFrame\\PvpRandomBg");
		bgTitle:SetText(""); bgDesc:SetText("");
		rewardTitle:Hide(); rewardBar:Hide(); winText:Hide(); lossText:Hide();
		joinButton:Disable(); groupButton:Disable();
	end
end

local function UpdateWintergrasp()
	if ( not GetWintergraspWaitTime ) then wgText:SetText(""); return; end
	local wait = GetWintergraspWaitTime();
	local t;
	if ( wait and wait > 60 ) then t = SecondsToTime(wait, true);
	elseif ( wait and wait > 0 ) then t = SecondsToTime(wait, false);
	else t = WINTERGRASP_IN_PROGRESS or "In progress"; end
	local can = CanQueueForWintergrasp and CanQueueForWintergrasp();
	wgText:SetText(format("|cffffd100Wintergrasp:|r %s   %s", t, can and "|cff20ff20(queue at a Wintergrasp battlemaster now)|r" or "|cff888888(queue at a battlemaster shortly before it starts)|r"));
end

local tick = 0;
bgPage:SetScript("OnUpdate", function(self, elapsed)
	tick = tick + elapsed;
	if ( tick < 1 ) then return; end
	tick = 0;
	UpdateWintergrasp();
	UpdateQueues();
end);

TemucraftGroupFinder_AddCategory("pvp", "battlegrounds", {
	label = BATTLEGROUNDS or "Battlegrounds", sub = "Random, Call to Arms and more",
	art = "Interface\\PVPFrame\\PvpRandomBg", coords = { 0, 1, 0.1, 0.45 },
	icon = "Interface\\LFGFrame\\LFGICON-BATTLEGROUND", page = bgPage, title = BATTLEGROUNDS or "Battlegrounds",
	update = function() UpdateBattlegrounds(); UpdateWintergrasp(); end,
	onShow = function()
		if ( SortBGList ) then SortBGList(); end
		RequestBattlegroundInstanceInfo(selectedBG or 1);
	end,
	tooltip = "Queue for a random battleground, the Call to Arms or the battleground you pick, alone or with your group.",
});

----------------------------------------------------------------------------------------------------------------------
-- Arena
----------------------------------------------------------------------------------------------------------------------
local arenaPage = CreateFrame("Frame");
local seasonStats = false;
local selectedTeam = nil;   -- GetArenaTeam index
local cards = {};
local SIZES = { 2, 3, 5 };
for i, size in ipairs(SIZES) do
	local c = CreateFrame("Button", nil, arenaPage);
	c:SetHeight(190);
	TemucraftStyle_Inset(c);
	c.size = size;
	c.banner = c:CreateTexture(nil, "ARTWORK");
	c.banner:SetWidth(64); c.banner:SetHeight(64);
	c.banner:SetPoint("TOPLEFT", 12, -12);
	c.border = c:CreateTexture(nil, "OVERLAY");
	c.border:SetAllPoints(c.banner);
	c.emblem = c:CreateTexture(nil, "OVERLAY");
	c.emblem:SetWidth(40); c.emblem:SetHeight(40);
	c.emblem:SetPoint("CENTER", c.banner, "CENTER", 0, 4);
	c.kind = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	c.kind:SetPoint("TOPLEFT", c.banner, "TOPRIGHT", 10, -4);
	c.kind:SetText(size.."v"..size);
	c.name = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	c.name:SetPoint("TOPLEFT", c.kind, "BOTTOMLEFT", 0, -4); c.name:SetPoint("RIGHT", -8, 0); c.name:SetJustifyH("LEFT");
	c.rating = c:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge");
	c.rating:SetPoint("TOPLEFT", c.banner, "BOTTOMLEFT", 0, -10);
	c.ratingLabel = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	c.ratingLabel:SetPoint("LEFT", c.rating, "RIGHT", 6, 0);
	c.ratingLabel:SetText(ARENA_TEAM_RATING or "Team Rating");
	c.lines = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	c.lines:SetPoint("TOPLEFT", c.rating, "BOTTOMLEFT", 0, -8); c.lines:SetPoint("RIGHT", -8, 0);
	c.lines:SetJustifyH("LEFT");
	c.empty = c:CreateFontString(nil, "OVERLAY", "GameFontDisable");
	c.empty:SetPoint("TOPLEFT", c.banner, "BOTTOMLEFT", 0, -14); c.empty:SetPoint("RIGHT", -8, 0); c.empty:SetJustifyH("LEFT");
	c.empty:SetText((ARENA_TEAM_LEAD_IN or "Visit an Arena Master to form a new Arena Team."));
	c.sel = TemucraftStyle_Glow(c);
	c.sel:Hide();
	TemucraftStyle_Highlight(c);
	c:SetScript("OnClick", function(self)
		if ( not self.team ) then return; end
		PlaySound("igMainMenuOptionCheckBoxOn");
		if ( selectedTeam == self.team ) then selectedTeam = nil; CloseArenaTeamRoster();
		else selectedTeam = self.team; ArenaTeamRoster(self.team); end
		Later();
	end);
	cards[i] = c;
end
local function PlaceCards()
	local w = arenaPage:GetWidth();
	if ( not w or w <= 0 ) then w = 560; end
	local cw = math.floor((w - 12) / 3);
	for i, c in ipairs(cards) do
		c:SetWidth(cw);
		c:ClearAllPoints();
		c:SetPoint("TOPLEFT", (i - 1) * (cw + 6), 0);
	end
end
arenaPage:SetScript("OnSizeChanged", PlaceCards);

local toggleSeason = Button(arenaPage, ARENA_THIS_SEASON_TOGGLE or "View this Season's Stats", 190);
toggleSeason:SetPoint("TOPRIGHT", 0, -196);
toggleSeason:SetScript("OnClick", function() seasonStats = not seasonStats; Later(); end);
local rosterBox = Inset(arenaPage);
rosterBox:SetPoint("TOPLEFT", 0, -222); rosterBox:SetPoint("BOTTOMRIGHT", 0, 0);
local rosterTitle = rosterBox:CreateFontString(nil, "OVERLAY", "GameFontNormal");
rosterTitle:SetPoint("TOPLEFT", 12, -10);
local rcols = { { NAME or "Name", 12 }, { LEVEL_ABBR or "Lvl", 170 }, { CLASS or "Class", 210 }, { PLAYED or "Played", 320 }, { WIN_LOSS or "Win - Loss", 390 }, { RATING or "Rating", 480 } };
local rosterHeaders = {};
for _, c in ipairs(rcols) do
	local t = rosterBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	t:SetPoint("TOPLEFT", c[2], -32);
	t:SetText(c[1]);
	table.insert(rosterHeaders, t);
end
local rline = TemucraftStyle_Line(rosterBox);
rline:SetPoint("TOPLEFT", 6, -46); rline:SetPoint("TOPRIGHT", -6, -46);
local rosterNone = rosterBox:CreateFontString(nil, "OVERLAY", "GameFontDisable");
rosterNone:SetPoint("CENTER", 0, -10); rosterNone:SetWidth(420);
rosterNone:SetText("Click a team above to see its members.");
local memberRows = {};
for i = 1, (MAX_ARENA_TEAM_MEMBERS or 10) do
	local b = CreateFrame("Button", nil, rosterBox);
	b:SetHeight(18);
	b:SetPoint("TOPLEFT", 6, -50 - (i - 1) * 18); b:SetPoint("RIGHT", -6, 0);
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	TemucraftStyle_Highlight(b);
	b.cells = {};
	for j, c in ipairs(rcols) do
		local t = b:CreateFontString(nil, "OVERLAY", j == 1 and "GameFontNormalSmall" or "GameFontHighlightSmall");
		t:SetPoint("LEFT", c[2] - 6, 0);
		b.cells[j] = t;
	end
	b:SetScript("OnClick", function(self, button)
		if ( button == "RightButton" and self.member and PVPFrame_ShowDropdown and PVPTeamDetails ) then
			PVPTeamDetails.team = selectedTeam;   -- the stock team menu reads it (captain or not)
			PVPFrame_ShowDropdown(self.member, self.online);
		elseif ( self.member and IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() ) then
			ChatEdit_InsertLink(self.member);
		end
	end);
	memberRows[i] = b;
end
local offSeason = CreateFrame("Frame", nil, arenaPage);
offSeason:SetAllPoints(arenaPage);
offSeason:SetFrameLevel(arenaPage:GetFrameLevel() + 30);
offSeason:EnableMouse(true);
offSeason:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" });
offSeason:SetBackdropColor(0, 0, 0, 0.85);
local offText = offSeason:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge");
offText:SetPoint("CENTER"); offText:SetWidth(440);
offSeason:Hide();

local function Team(i)
	local t = { GetArenaTeam(i) };
	if ( not t[1] ) then return nil; end
	return { index = i, name = t[1], size = t[2], rating = t[3], played = t[4], wins = t[5], seasonPlayed = t[6], seasonWins = t[7],
		playerPlayed = t[8], seasonPlayerPlayed = t[9], rank = t[10], personal = t[11],
		bg = { t[12], t[13], t[14] }, emblem = t[15], emblemColor = { t[16], t[17], t[18] }, border = t[19], borderColor = { t[20], t[21], t[22] } };
end
function TemucraftGroupFinderPvP_Teams()
	local out = {};
	for i = 1, (MAX_ARENA_TEAMS or 3) do local t = Team(i); if ( t ) then out[#out + 1] = t; end end
	return out;
end

local function UpdateArena()
	PlaceCards();
	local season = GetCurrentArenaSeason and GetCurrentArenaSeason() or 1;
	if ( season == 0 ) then
		local prev = GetPreviousArenaSeason and GetPreviousArenaSeason() or 0;
		offText:SetText(format(ARENA_OFF_SEASON_TEXT or "Arena Season %d has come to an end! Season %d starts soon.", prev, prev + 1));
		offSeason:Show();
	else
		offSeason:Hide();
	end
	local slots = P.TeamSlots(function(i) local _, size = GetArenaTeam(i); return size; end);
	toggleSeason:SetText(seasonStats and (ARENA_THIS_WEEK_TOGGLE or "View this Week's Stats") or (ARENA_THIS_SEASON_TOGGLE or "View this Season's Stats"));
	local selectedStill = false;
	for _, c in ipairs(cards) do
		local idx = slots[c.size];
		local t = idx and Team(idx);
		c.team = t and t.index;
		c.banner:SetTexture("Interface\\PVPFrame\\PVP-Banner-"..c.size);
		if ( t ) then
			c.banner:SetVertexColor(t.bg[1] or 1, t.bg[2] or 1, t.bg[3] or 1);
			if ( t.border and t.border ~= -1 ) then
				c.border:SetTexture("Interface\\PVPFrame\\PVP-Banner-"..c.size.."-Border-"..t.border);
				c.border:SetVertexColor(t.borderColor[1] or 1, t.borderColor[2] or 1, t.borderColor[3] or 1); c.border:Show();
			else c.border:Hide(); end
			if ( t.emblem and t.emblem ~= -1 ) then
				c.emblem:SetTexture("Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-"..t.emblem);
				c.emblem:SetVertexColor(t.emblemColor[1] or 1, t.emblemColor[2] or 1, t.emblemColor[3] or 1); c.emblem:Show();
			else c.emblem:Hide(); end
			c.banner:SetAlpha(1);
			c.name:SetText(t.name);
			c.rating:SetText(t.rating or 0);
			local played, wins, mine = t.played, t.wins, t.playerPlayed;
			if ( seasonStats ) then played, wins, mine = t.seasonPlayed, t.seasonWins, t.seasonPlayerPlayed; end
			c.lines:SetText(format("|cffffd100%s|r\n%s: %d   %d - %d  (%s)\n%s: %d\n%s: %d   %s: %s",
				seasonStats and (ARENA_THIS_SEASON or "This Season") or (ARENA_THIS_WEEK or "This Week"),
				GAMES or "Games", played or 0, wins or 0, (played or 0) - (wins or 0), P.WinRate(played, wins),
				PLAYED or "Played", mine or 0,
				PVP_YOUR_RATING or "Your Rating", t.personal or 0, RANK or "Rank", (t.rank and t.rank > 0) and t.rank or "-"));
			c.rating:Show(); c.ratingLabel:Show(); c.lines:Show(); c.empty:Hide();
			if ( selectedTeam == t.index ) then c.sel:Show(); selectedStill = true; else c.sel:Hide(); end
		else
			c.banner:SetVertexColor(1, 1, 1); c.banner:SetAlpha(0.3);
			c.border:Hide(); c.emblem:Hide();
			c.name:SetText(format(PVP_TEAMSIZE or "(%dv%d)", c.size, c.size));
			c.rating:Hide(); c.ratingLabel:Hide(); c.lines:Hide(); c.empty:Show();
			c.sel:Hide();
		end
	end
	if ( not selectedStill ) then selectedTeam = nil; end
	-- the roster
	local t = selectedTeam and Team(selectedTeam);
	if ( not t ) then
		rosterTitle:SetText(ARENA_TEAM or "Arena Team");
		rosterNone:Show();
		for _, h in ipairs(rosterHeaders) do h:Hide(); end
		for _, b in ipairs(memberRows) do b:Hide(); end
		return;
	end
	rosterNone:Hide();
	for _, h in ipairs(rosterHeaders) do h:Show(); end
	rosterTitle:SetText(format("%s  |cffffffff%s|r", t.name, format(PVP_TEAMSIZE or "(%dv%d)", t.size, t.size)));
	local n = GetNumArenaTeamMembers(t.index, 1) or 0;
	for i, b in ipairs(memberRows) do
		if ( i <= n ) then
			local name, rank, level, class, online, played, win, seasonPlayed, seasonWin, rating = GetArenaTeamRosterInfo(t.index, i);
			if ( seasonStats ) then played, win = seasonPlayed, seasonWin; end
			b.member, b.online = name, online;
			b.cells[1]:SetText((rank == 0 and "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:12:12:0:0|t " or "")..(name or ""));
			b.cells[2]:SetText(level or "");
			b.cells[3]:SetText(class or "");
			b.cells[4]:SetText(played or 0);
			b.cells[5]:SetText(format("%d - %d", win or 0, (played or 0) - (win or 0)));
			b.cells[6]:SetText(rating or 0);
			local a = online and 1 or 0.5;
			for _, cell in ipairs(b.cells) do cell:SetAlpha(a); end
			b:Show();
		else
			b.member = nil;
			b:Hide();
		end
	end
end

TemucraftGroupFinder_AddCategory("pvp", "arena", {
	label = ARENA or "Arena", sub = "Your 2v2, 3v3 and 5v5 teams",
	art = "Interface\\PVPFrame\\PvpBg-ArathiBasin", coords = { 0, 1, 0.1, 0.45 },
	icon = "Interface\\Icons\\Achievement_Arena_2v2_7", page = arenaPage, title = ARENA or "Arena",
	update = UpdateArena,
	onShow = function() for i = 1, (MAX_ARENA_TEAMS or 3) do GetArenaTeam(i); end if ( selectedTeam ) then ArenaTeamRoster(selectedTeam); end end,
	tooltip = "Your arena teams: rating, games this week and this season, your personal rating and the roster.",
});
TemucraftGroupFinder_OnHide(function() if ( selectedTeam ) then CloseArenaTeamRoster(); end end);

----------------------------------------------------------------------------------------------------------------------
-- Honor & Conquest
----------------------------------------------------------------------------------------------------------------------
local honorPage = CreateFrame("Frame");
local currencyBox = Inset(honorPage);
currencyBox:SetPoint("TOPLEFT", 0, 0); currencyBox:SetPoint("TOPRIGHT", 0, 0); currencyBox:SetHeight(96);
local function BigCurrency(parent, x, icon, label)
	local t = parent:CreateTexture(nil, "ARTWORK");
	t:SetWidth(48); t:SetHeight(48);
	t:SetPoint("TOPLEFT", x, -22);
	t:SetTexture(icon);
	local v = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge");
	v:SetPoint("TOPLEFT", t, "TOPRIGHT", 10, -2);
	local l = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	l:SetPoint("TOPLEFT", v, "BOTTOMLEFT", 0, -4);
	l:SetText(label);
	return t, v;
end
local honorIcon, honorValue = BigCurrency(currencyBox, 16, "Interface\\PVPFrame\\PVP-Currency-Alliance", HONOR_POINTS or "Honor Points");
local _, arenaValue = BigCurrency(currencyBox, 290, "Interface\\PVPFrame\\PVP-ArenaPoints-Icon", ARENA_POINTS or "Arena Points");

local killsBox = Inset(honorPage);
killsBox:SetPoint("TOPLEFT", currencyBox, "BOTTOMLEFT", 0, -6); killsBox:SetPoint("TOPRIGHT", currencyBox, "BOTTOMRIGHT", 0, -6);
killsBox:SetHeight(120);
local killsTitle = killsBox:CreateFontString(nil, "OVERLAY", "GameFontNormal");
killsTitle:SetPoint("TOPLEFT", 12, -12);
killsTitle:SetText(HONORABLE_KILLS or "Honorable Kills");
TemucraftStyle_Header(killsTitle);
local killCols = {};
for i, label in ipairs({ HONOR_TODAY or "Today", HONOR_YESTERDAY or "Yesterday", HONOR_LIFETIME or "Lifetime" }) do
	local x = 16 + (i - 1) * 180;
	local l = killsBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	l:SetPoint("TOPLEFT", x, -44);
	l:SetText(label);
	local kills = killsBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	kills:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -6);
	local honor = killsBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	honor:SetPoint("TOPLEFT", kills, "BOTTOMLEFT", 0, -4);
	killCols[i] = { kills = kills, honor = honor };
end

local conquestBox = Inset(honorPage);
conquestBox:SetPoint("TOPLEFT", killsBox, "BOTTOMLEFT", 0, -6); conquestBox:SetPoint("BOTTOMRIGHT", 0, 0);
local cqTitle = conquestBox:CreateFontString(nil, "OVERLAY", "GameFontNormal");
cqTitle:SetPoint("TOPLEFT", 12, -12);
cqTitle:SetText("This week's arena points");
TemucraftStyle_Header(cqTitle);
local cqValue = conquestBox:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge");
cqValue:SetPoint("TOPLEFT", 16, -44);
local cqLines = conquestBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
cqLines:SetPoint("TOPLEFT", cqValue, "BOTTOMLEFT", 0, -10); cqLines:SetPoint("RIGHT", -16, 0); cqLines:SetJustifyH("LEFT");
local cqNote = conquestBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
cqNote:SetPoint("BOTTOMLEFT", 16, 40); cqNote:SetPoint("RIGHT", -16, 0); cqNote:SetJustifyH("LEFT");
cqNote:SetText("An estimate with the stock formula: points go out once a week (10 team games, 30% of them yours; the best team counts). The server's rates can make it differ.");
local flagButton = Button(conquestBox, PVP_FLAG or "PvP", 160);
flagButton:SetPoint("BOTTOMRIGHT", -10, 10);
flagButton:SetScript("OnClick", function() TogglePVP(); Later(); end);
local flagText = conquestBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
flagText:SetPoint("RIGHT", flagButton, "LEFT", -8, 0);

local function UpdateHonor()
	honorIcon:SetTexture("Interface\\PVPFrame\\PVP-Currency-"..Faction());
	honorValue:SetText(GetHonorCurrency and GetHonorCurrency() or 0);
	arenaValue:SetText(GetArenaCurrency and GetArenaCurrency() or 0);
	local hk, cp = GetPVPSessionStats();
	killCols[1].kills:SetText(hk or 0); killCols[1].honor:SetText(format("%s %d", HonorIcon(12), cp or 0));
	hk, cp = GetPVPYesterdayStats();
	killCols[2].kills:SetText(hk or 0); killCols[2].honor:SetText(format("%s %d", HonorIcon(12), cp or 0));
	hk = GetPVPLifetimeStats();
	killCols[3].kills:SetText(hk or 0); killCols[3].honor:SetText("");
	-- the arena estimate
	local teams = {};
	for _, t in ipairs(TemucraftGroupFinderPvP_Teams()) do
		teams[#teams + 1] = { size = t.size, rating = t.rating, personal = t.personal, weekGames = t.played, playerWeekGames = t.playerPlayed };
	end
	local season = GetCurrentArenaSeason and GetCurrentArenaSeason() or 0;
	local best, bestSize, rows = P.ArenaWeek(teams, season);
	if ( #teams == 0 ) then
		cqValue:SetText("-");
		cqLines:SetText(ARENA_TEAM_LEAD_IN or "Visit an Arena Master to form a new Arena Team.");
	else
		cqValue:SetText(format("%s %d", ArenaIcon(24), best));
		local lines = {};
		for _, r in ipairs(rows) do
			local s = format("%dv%d: %d points", r.size, r.size, r.points);
			if ( r.need > 0 ) then s = s..format("  |cffff6060(the team needs %d more games)|r", r.need);
			elseif ( r.needYou > 0 ) then s = s..format("  |cffff6060(play %d more of them)|r", r.needYou);
			elseif ( r.size == bestSize ) then s = s.."  |cff20ff20(counts)|r"; end
			lines[#lines + 1] = s;
		end
		cqLines:SetText(table.concat(lines, "\n"));
	end
	local on = UnitIsPVP("player");
	flagText:SetText(on and "|cffff2020Your PvP flag is on|r" or "Your PvP flag is off");
	flagButton:SetText(on and "Turn PvP off" or "Turn PvP on");
	if ( on and GetPVPDesired and not GetPVPDesired() ) then
		flagText:SetText("|cffff8020The flag goes off in a few minutes|r");
	end
end

TemucraftGroupFinder_AddCategory("pvp", "honor", {
	label = "Honor & Conquest", sub = "Honor, arena points, kills",
	art = "Interface\\PVPFrame\\PvpBg-AlteracValley", coords = { 0, 1, 0.1, 0.45 },
	icon = "Interface\\Icons\\Achievement_BG_masterofallBGs", page = honorPage, title = "Honor & Conquest",
	update = UpdateHonor,
	onShow = function() for i = 1, (MAX_ARENA_TEAMS or 3) do GetArenaTeam(i); end end,
	tooltip = "Your honor and arena points, honorable kills, and the arena points your teams would bring this week.",
});

----------------------------------------------------------------------------------------------------------------------
-- Events, /pvp
----------------------------------------------------------------------------------------------------------------------
local events = CreateFrame("Frame");
for _, e in ipairs({ "PVPQUEUE_ANYWHERE_SHOW", "PVPQUEUE_ANYWHERE_UPDATE_AVAILABLE", "UPDATE_BATTLEFIELD_STATUS", "PARTY_MEMBERS_CHANGED",
	"ARENA_TEAM_UPDATE", "ARENA_TEAM_ROSTER_UPDATE", "HONOR_CURRENCY_UPDATE", "PLAYER_PVP_KILLS_CHANGED", "PLAYER_PVP_RANK_CHANGED",
	"UNIT_FACTION", "PLAYER_FLAGS_CHANGED", "BATTLEFIELDS_SHOW", "BATTLEFIELDS_CLOSED" }) do
	events:RegisterEvent(e);
end
events:SetScript("OnEvent", function(self, event, a1)
	if ( event == "ARENA_TEAM_ROSTER_UPDATE" and a1 and selectedTeam and TemucraftGroupFinder_IsShown("pvp") ) then
		ArenaTeamRoster(selectedTeam);   -- the roster changed: ask again
		return;
	end
	if ( (event == "UNIT_FACTION" or event == "PLAYER_FLAGS_CHANGED") and a1 ~= "player" ) then return; end
	Later();
end);
-- the "queue from anywhere" list closes with the window, as PVPBattlegroundFrame's OnHide (not while a battlemaster's
-- own window is open)
TemucraftGroupFinder_OnHide(function()
	if ( not (BattlefieldFrame and BattlefieldFrame:IsShown()) and CloseBattlefield ) then CloseBattlefield(); end
end);

SlashCmdList["PVP"] = function(msg)
	local what = P.Slash(msg);
	if ( what == "flag" ) then TogglePVP(); return; end
	if ( what == "on" ) then SetPVP(1); return; end
	if ( what == "off" ) then SetPVP(nil); return; end
	TemucraftGroupFinder_SlashOpen("pvp", nil);
end;
