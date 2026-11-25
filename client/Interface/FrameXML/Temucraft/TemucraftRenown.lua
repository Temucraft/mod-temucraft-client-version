-- Temucraft Renown "Journeys" page (retail look), for the Renown tracks of mod-temucraft-renown (addon prefix TRN,
-- read by TemucraftReputation.lua into TemucraftReputationLogic.tracks).
--   Header     the faction's name, a ring with its Renown level, "Current Progress: X / Y" and a bar
--   Rewards    an icon strip 1..N: got (a check), next (lit), locked (grey, a lock); arrows page through long
--              tracks; mouse over shows the reward (item, spell, title, vendor unlock)
--   Overview   what the track is about (its level 0 text) and the "Journey Highlights": cards with each highlighted
--              level's title, level and description
-- Its own window for now (the Adventure Guide comes later): "View Renown" in the reputation window's detail panel,
-- /renown (the watched faction's track, else the first) and /renown <faction>.

----------------------------------------------------------------------------------------------------------------------
-- The logic (no frames: tests/reputation_test.lua runs it with stubs)
----------------------------------------------------------------------------------------------------------------------
TemucraftRenownLogic = {};
local L = TemucraftRenownLogic;
local R = TemucraftReputationLogic;

-- the levels to show as highlight cards: those marked highlight, else every level with a title
function L.Highlights(track)
	local marked, titled = {}, {};
	for i = 1, track.max or 0 do
		local l = track.levels[i];
		if ( l ) then
			if ( l.highlight ) then table.insert(marked, l); end
			if ( l.title and l.title ~= "" ) then table.insert(titled, l); end
		end
	end
	return #marked > 0 and marked or titled;
end

-- the first level of the page that holds `level` (pages of `size`)
function L.PageStart(level, size)
	level = math.max(1, level or 1);
	return math.floor((level - 1) / size) * size + 1;
end

-- what a reward is, in words
function L.RewardText(l)
	if ( l.type == "item" ) then return "Item reward";
	elseif ( l.type == "spell" ) then return "Spell reward";
	elseif ( l.type == "title" ) then return "Title: "..(l.title ~= "" and l.title or "?");
	elseif ( l.type == "vendor" ) then return "Unlocks an item at the faction's vendors";
	end
	return nil;
end

-- a faction's track by (part of) its name
function L.Find(text)
	if ( not text or text == "" ) then return nil; end
	text = string.lower(text);
	for _, t in ipairs(R.TrackList()) do
		local name = string.lower(R.NameOf(t.faction) or "");
		if ( name == text ) then return t; end
	end
	for _, t in ipairs(R.TrackList()) do
		local name = string.lower(R.NameOf(t.faction) or "");
		if ( string.find(name, text, 1, true) ) then return t; end
	end
	return nil;
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

----------------------------------------------------------------------------------------------------------------------
-- The window
----------------------------------------------------------------------------------------------------------------------
local WIDTH, HEIGHT = 720, 520;
local STRIP = 8;          -- reward icons on a page
local CARDS = 6;          -- highlight cards (3 x 2)
local Panel = R.Panel;
local ICONS = {
	title = "Interface\\Icons\\INV_Scroll_03",
	vendor = "Interface\\Icons\\INV_Misc_Coin_01",
	none = "Interface\\Icons\\Achievement_Reputation_01",
};

local frame = CreateFrame("Frame", "TemucraftRenownFrame", UIParent);
frame:SetWidth(WIDTH); frame:SetHeight(HEIGHT);
frame:SetPoint("CENTER");
frame:SetToplevel(true);
frame:SetFrameStrata("HIGH");
frame:EnableMouse(true);
frame:SetMovable(true);
frame:SetClampedToScreen(true);
frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } });
frame:Hide();
table.insert(UISpecialFrames, "TemucraftRenownFrame");

local close = CreateFrame("Button", "TemucraftRenownFrameCloseButton", frame, "UIPanelCloseButton");
close:SetPoint("TOPRIGHT", -6, -6);
local drag = CreateFrame("Frame", nil, frame);
drag:SetPoint("TOPLEFT", 12, -8); drag:SetPoint("TOPRIGHT", -40, -8); drag:SetHeight(26);
drag:EnableMouse(true);
drag:RegisterForDrag("LeftButton");
drag:SetScript("OnDragStart", function() frame:StartMoving(); end);
drag:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); end);
local pageTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
pageTitle:SetPoint("TOP", 0, -18);
pageTitle:SetText("Journeys");

local current, page = nil, 1;
local Update;

-- the other journeys
local menu = CreateFrame("Frame", "TemucraftRenownFactionMenu", frame, "UIDropDownMenuTemplate");
menu:SetPoint("TOPLEFT", 4, -34);
UIDropDownMenu_SetWidth(menu, 170);
UIDropDownMenu_Initialize(menu, function()
	for _, t in ipairs(R.TrackList()) do
		local info = UIDropDownMenu_CreateInfo();
		info.text = R.NameOf(t.faction) or ("Faction "..t.faction);
		info.checked = current == t.faction;
		info.func = function() TemucraftRenown_Show(t.faction); end;
		UIDropDownMenu_AddButton(info);
	end
end);
local back = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
back:SetWidth(110); back:SetHeight(22);
back:SetPoint("TOPRIGHT", -36, -38);
back:SetText(REPUTATION or "Reputation");
back:SetScript("OnClick", function()
	frame:Hide();
	if ( TemucraftReputation_Show and not TemucraftUI_IsClassic("rep") ) then TemucraftReputation_Show(current); else ToggleCharacter("ReputationFrame"); end
end);

-- header: the ring, the name, the progress
local header = Panel(frame);
header:SetPoint("TOPLEFT", 16, -68); header:SetPoint("TOPRIGHT", -16, -68);
header:SetHeight(112);
local ring = header:CreateTexture(nil, "ARTWORK");
ring:SetWidth(84); ring:SetHeight(84);
ring:SetPoint("LEFT", 16, 0);
ring:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask");
ring:SetVertexColor(0.2, 0.55, 0.95);
local ringInner = header:CreateTexture(nil, "OVERLAY");
ringInner:SetWidth(68); ringInner:SetHeight(68);
ringInner:SetPoint("CENTER", ring, "CENTER");
ringInner:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask");
ringInner:SetVertexColor(0.04, 0.08, 0.16);
local ringText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge");
ringText:SetPoint("CENTER", ring, "CENTER", 0, 0);
ringText:SetTextColor(1, 1, 1);
ringText:SetDrawLayer("OVERLAY");
local fName = header:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge");
fName:SetPoint("TOPLEFT", ring, "TOPRIGHT", 16, -6);
fName:SetPoint("RIGHT", -16, 0);
fName:SetJustifyH("LEFT");
local fLevel = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
fLevel:SetPoint("TOPLEFT", fName, "BOTTOMLEFT", 0, -6);
local fProgress = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
fProgress:SetPoint("TOPLEFT", fLevel, "BOTTOMLEFT", 0, -6);
local bar = CreateFrame("StatusBar", nil, header);
bar:SetPoint("TOPLEFT", fProgress, "BOTTOMLEFT", 0, -6);
bar:SetWidth(360); bar:SetHeight(12);
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
bar:SetStatusBarColor(0.0, 0.55, 0.95);
local barBg = bar:CreateTexture(nil, "BACKGROUND");
barBg:SetAllPoints();
barBg:SetTexture(0, 0, 0, 0.6);

-- the reward strip
local strip = Panel(frame);
strip:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8); strip:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -8);
strip:SetHeight(92);
local stripTitle = strip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
stripTitle:SetPoint("TOPLEFT", 12, -8);
stripTitle:SetText("Rewards");
local prev = CreateFrame("Button", nil, strip);
prev:SetWidth(28); prev:SetHeight(28);
prev:SetPoint("LEFT", 8, -6);
prev:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up");
prev:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down");
prev:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled");
prev:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD");
local nextB = CreateFrame("Button", nil, strip);
nextB:SetWidth(28); nextB:SetHeight(28);
nextB:SetPoint("RIGHT", -8, -6);
nextB:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up");
nextB:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down");
nextB:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled");
nextB:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD");
prev:SetScript("OnClick", function() page = math.max(1, page - STRIP); Update(); end);
nextB:SetScript("OnClick", function() page = page + STRIP; Update(); end);

local function RewardIcon(l)
	if ( l.type == "item" and l.reward > 0 ) then
		return (GetItemIcon and GetItemIcon(l.reward)) or select(10, GetItemInfo(l.reward)) or "Interface\\Icons\\INV_Misc_QuestionMark";
	elseif ( l.type == "spell" and l.reward > 0 ) then
		return select(3, GetSpellInfo(l.reward)) or "Interface\\Icons\\INV_Misc_QuestionMark";
	elseif ( l.type == "vendor" and l.reward > 0 ) then
		return (GetItemIcon and GetItemIcon(l.reward)) or ICONS.vendor;
	end
	return ICONS[l.type] or ICONS.none;
end

local icons, links = {}, {};
local SPACING = (WIDTH - 32 - 80) / STRIP;
for i = 1, STRIP do
	local b = CreateFrame("Button", nil, strip);
	b:SetWidth(40); b:SetHeight(40);
	b:SetPoint("LEFT", 40 + (i - 1) * SPACING + (SPACING - 40) / 2, -6);
	b.icon = b:CreateTexture(nil, "ARTWORK");
	b.icon:SetAllPoints();
	b.glow = b:CreateTexture(nil, "OVERLAY");
	b.glow:SetWidth(70); b.glow:SetHeight(70);
	b.glow:SetPoint("CENTER");
	b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border");
	b.glow:SetBlendMode("ADD");
	b.glow:SetVertexColor(1, 0.85, 0.2);
	b.check = b:CreateTexture(nil, "OVERLAY");
	b.check:SetWidth(18); b.check:SetHeight(18);
	b.check:SetPoint("BOTTOMRIGHT", 4, -4);
	b.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready");
	b.lock = b:CreateTexture(nil, "OVERLAY");
	b.lock:SetWidth(18); b.lock:SetHeight(18);
	b.lock:SetPoint("BOTTOMRIGHT", 4, -4);
	b.lock:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-LOCK");
	b.level = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	b.level:SetPoint("TOP", b, "BOTTOM", 0, -3);
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
	b:SetScript("OnEnter", function(self)
		local l = self.data;
		if ( not l ) then return; end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		if ( (l.type == "item" or l.type == "vendor") and l.reward > 0 ) then GameTooltip:SetHyperlink("item:"..l.reward..":0:0:0:0:0:0:0");
		elseif ( l.type == "spell" and l.reward > 0 ) then GameTooltip:SetHyperlink("spell:"..l.reward);
		else GameTooltip:SetText(l.title ~= "" and l.title or ("Level "..l.level), 1, 0.82, 0); end
		local track = current and R.tracks[current];
		GameTooltip:AddLine(((track and track.label) or "Renown").." "..l.level, 0.4, 0.75, 1);
		if ( l.title ~= "" and (l.type == "item" or l.type == "spell" or l.type == "vendor") ) then GameTooltip:AddLine(l.title, 1, 0.82, 0); end
		local what = L.RewardText(l);
		if ( what ) then GameTooltip:AddLine(what, 0.8, 0.8, 0.8); end
		if ( l.count > 1 and l.type == "item" ) then GameTooltip:AddLine("x"..l.count, 1, 1, 1); end
		if ( l.desc ~= "" ) then GameTooltip:AddLine(l.desc, 1, 1, 1, 1); end
		local state = self.state;
		if ( state == "got" ) then GameTooltip:AddLine("Earned", 0.1, 1, 0.1);
		elseif ( state == "next" ) then GameTooltip:AddLine("Next reward", 1, 0.82, 0);
		else GameTooltip:AddLine("Locked", 0.6, 0.6, 0.6); end
		GameTooltip:Show();
	end);
	b:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	b:SetScript("OnClick", function(self)
		local l = self.data;
		if ( l and IsModifiedClick("CHATLINK") and (l.type == "item" or l.type == "vendor") and l.reward > 0 ) then
			local _, link = GetItemInfo(l.reward);
			if ( link ) then ChatEdit_InsertLink(link); end
		end
	end);
	icons[i] = b;
	if ( i > 1 ) then
		local line = strip:CreateTexture(nil, "BACKGROUND");
		line:SetHeight(3);
		line:SetPoint("LEFT", icons[i - 1], "RIGHT", 4, 0);
		line:SetPoint("RIGHT", b, "LEFT", -4, 0);
		links[i] = line;
	end
end

-- overview and the highlight cards
local overview = Panel(frame);
overview:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, -8); overview:SetPoint("BOTTOMRIGHT", -16, 16);
local ovTitle = overview:CreateFontString(nil, "OVERLAY", "GameFontNormal");
ovTitle:SetPoint("TOPLEFT", 12, -10);
ovTitle:SetText("Overview");
local ovText = overview:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
ovText:SetPoint("TOPLEFT", ovTitle, "BOTTOMLEFT", 0, -6);
ovText:SetPoint("RIGHT", -12, 0);
ovText:SetHeight(30);
ovText:SetJustifyH("LEFT"); ovText:SetJustifyV("TOP");
local hlTitle = overview:CreateFontString(nil, "OVERLAY", "GameFontNormal");
hlTitle:SetPoint("TOPLEFT", ovText, "BOTTOMLEFT", 0, -6);
hlTitle:SetText("Journey Highlights");
local cards = {};
local CARD_W, CARD_H = (WIDTH - 32 - 24 - 16) / 3, 74;
for i = 1, CARDS do
	local c = Panel(overview);
	c:SetWidth(CARD_W); c:SetHeight(CARD_H);
	c:SetPoint("TOPLEFT", hlTitle, "BOTTOMLEFT", ((i - 1) % 3) * (CARD_W + 8), -6 - math.floor((i - 1) / 3) * (CARD_H + 6));
	c.title = c:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	c.title:SetPoint("TOPLEFT", 10, -8); c.title:SetPoint("RIGHT", -60, 0);
	c.title:SetJustifyH("LEFT");
	c.level = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	c.level:SetPoint("TOPRIGHT", -10, -9);
	c.desc = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	c.desc:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -4);
	c.desc:SetPoint("BOTTOMRIGHT", -10, 6);
	c.desc:SetJustifyH("LEFT"); c.desc:SetJustifyV("TOP");
	cards[i] = c;
end
local hlNone = overview:CreateFontString(nil, "OVERLAY", "GameFontDisable");
hlNone:SetPoint("TOPLEFT", hlTitle, "BOTTOMLEFT", 0, -10);
hlNone:SetText("No highlights for this journey yet.");
local empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable");
empty:SetPoint("CENTER");
empty:SetText("No Renown journeys on this server.");

Update = function()
	if ( not frame:IsShown() ) then return; end
	local track = current and R.tracks[current];
	if ( not track ) then
		local list = R.TrackList();
		track = list[1];
		current = track and track.faction;
	end
	for _, w in ipairs({ header, strip, overview }) do if ( track ) then w:Show(); else w:Hide(); end end
	if ( not track ) then empty:Show(); return; end
	empty:Hide();
	UIDropDownMenu_SetText(menu, R.NameOf(track.faction) or "");
	local row = R.RowOf(track.faction);
	local standing = row and row.barValue or 0;
	local level, cur, need, isMax = R.RenownLevel(track, standing);
	fName:SetText(R.NameOf(track.faction) or "");
	ringText:SetText(level);
	fLevel:SetText((track.label or "Renown").." "..level..(row and ("  |cffaaaaaa("..R.StandingText(row.standing)..")|r") or ""));
	if ( isMax ) then
		fProgress:SetText("Maximum "..(track.label or "Renown").." reached");
		bar:SetMinMaxValues(0, 1); bar:SetValue(1);
	else
		fProgress:SetText("Current Progress: "..cur.." / "..need);
		bar:SetMinMaxValues(0, need); bar:SetValue(cur);
	end
	-- the strip
	page = math.max(1, math.min(page, L.PageStart(track.max, STRIP)));
	for i, b in ipairs(icons) do
		local l = track.levels[page + i - 1];
		b.data = l;
		if ( not l ) then
			b:Hide();
			if ( links[i] ) then links[i]:Hide(); end
		else
			local state = R.LevelState(track, l.level, level);
			b.state = state;
			b.icon:SetTexture(RewardIcon(l));
			b.icon:SetDesaturated(state == "locked");
			b.icon:SetAlpha(state == "locked" and 0.6 or 1);
			if ( state == "got" ) then b.check:Show(); else b.check:Hide(); end
			if ( state == "next" ) then b.glow:Show(); else b.glow:Hide(); end
			if ( state == "locked" ) then b.lock:Show(); else b.lock:Hide(); end
			b.level:SetText(l.level);
			if ( state == "locked" ) then b.level:SetTextColor(0.6, 0.6, 0.6); else b.level:SetTextColor(1, 0.82, 0); end
			b:Show();
			if ( links[i] ) then
				links[i]:SetTexture(state == "got" and 0.2 or 0.35, state == "got" and 0.6 or 0.35, state == "got" and 1 or 0.35, 0.9);
				links[i]:Show();
			end
		end
	end
	if ( page > 1 ) then prev:Enable(); else prev:Disable(); end
	if ( page + STRIP <= track.max ) then nextB:Enable(); else nextB:Disable(); end
	-- overview
	ovText:SetText(track.desc ~= "" and track.desc or (row and row.description) or "");
	local hl = L.Highlights(track);
	for i, c in ipairs(cards) do
		local l = hl[i];
		if ( l ) then
			local got = R.LevelState(track, l.level, level) == "got";
			c.title:SetText(l.title ~= "" and l.title or (L.RewardText(l) or ""));
			c.level:SetText((track.label or "Renown").." "..l.level);
			c.desc:SetText(l.desc or "");
			c:SetBackdropBorderColor(got and 0.3 or 0.5, got and 0.6 or 0.45, got and 1 or 0.35, 0.9);
			c.title:SetTextColor(got and 1 or 0.7, got and 0.82 or 0.7, got and 0 or 0.7);
			c:Show();
		else
			c:Hide();
		end
	end
	if ( #hl == 0 ) then hlNone:Show(); else hlNone:Hide(); end
end

frame:SetScript("OnShow", function() PlaySound("igCharacterInfoOpen"); Update(); end);
frame:SetScript("OnHide", function() PlaySound("igCharacterInfoClose"); end);

-- open on a faction's journey (nil: the one already shown, else the first)
function TemucraftRenown_Show(id)
	if ( id and R.tracks[id] ) then
		current = id;
		local level = R.RenownLevel(R.tracks[id], (R.RowOf(id) or {}).barValue or 0);
		page = L.PageStart(level + 1, STRIP);
	end
	if ( frame:IsShown() ) then Update(); else frame:Show(); end
end

SLASH_TEMUCRAFTRENOWN1 = "/renown";
SlashCmdList["TEMUCRAFTRENOWN"] = function(msg)
	msg = strtrim(msg or "");
	if ( msg ~= "" ) then
		local t = L.Find(msg);
		if ( not t ) then
			DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffTemucraft:|r no Renown journey for \""..msg.."\".");
			return;
		end
		TemucraftRenown_Show(t.faction);
		return;
	end
	if ( frame:IsShown() ) then frame:Hide(); return; end
	local watched = GetWatchedFactionInfo and GetWatchedFactionInfo();
	local id = watched and R.IdOf(watched);
	TemucraftRenown_Show((id and R.tracks[id]) and id or nil);
end;

R.On("tracks", function() Update(); end);
R.On("granted", function() Update(); end);
R.On("update", function() Update(); end);
