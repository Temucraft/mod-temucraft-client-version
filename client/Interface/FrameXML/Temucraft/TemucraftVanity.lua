-- Temucraft vanity collection (mod-temucraft-account-wide, addon prefix TVA): the vanity items the account has
-- unlocked (the Stones and Scrolls of Homecoming and the like), each with its icon, name, cooldown and a Summon button
-- that puts it back in the bags. Open with /vanity, .collection vanity or the Vanity button of the Wardrobe.
local PREFIX = "TVA";
local ROWS, ROW_H = 8, 42;

local state = { items = {}, pending = {}, owned = 0, total = 0, loading = false, showLocked = true };
local view = { list = {} };

local function Send(text) SendAddonMessage(PREFIX, text, "WHISPER", UnitName("player")); end

-- the client asks the server for items it hasn't seen yet
local scanTip = CreateFrame("GameTooltip", "TemucraftVanityScanTip", nil, "GameTooltipTemplate");
local asked = {};
local function ItemData(e)
	local name, link, quality, _, _, _, _, _, _, texture = GetItemInfo(e.entry);
	if ( not name and not asked[e.entry] ) then
		asked[e.entry] = true;
		scanTip:SetOwner(WorldFrame, "ANCHOR_NONE");
		scanTip:SetHyperlink("item:"..e.entry..":0:0:0:0:0:0:0");
		scanTip:Hide();
	end
	return name or e.name, link, quality or 1, texture or "Interface\\Icons\\INV_Misc_QuestionMark";
end

local function FormatTime(s)
	if ( s >= 3600 ) then return format("%d h %d min", floor(s / 3600), floor(mod(s, 3600) / 60)); end
	if ( s >= 60 ) then return format("%d min", ceil(s / 60)); end
	return format("%d sec", s);
end

-- seconds left on the item's cooldown
local function Cooldown(e)
	if ( GetItemCount(e.entry) > 0 ) then
		local start, duration = GetItemCooldown(e.entry);
		if ( start and start > 0 and duration and duration > 1.5 ) then return max(0, start + duration - GetTime()); end
		return 0;
	end
	return max(0, (e.cdEnd or 0) - GetTime());
end

-- window ------------------------------------------------------------------------------------------------------------
local f = CreateFrame("Frame", "TemucraftVanityFrame", UIParent);
f:SetWidth(430); f:SetHeight(440); f:SetPoint("CENTER");
f:SetFrameStrata("DIALOG"); f:SetToplevel(true); f:SetClampedToScreen(true);
f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton");
f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing);
f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } });
f:Hide();
tinsert(UISpecialFrames, "TemucraftVanityFrame");

local header = f:CreateTexture(nil, "ARTWORK");
header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header"); header:SetWidth(300); header:SetHeight(64);
header:SetPoint("TOP", f, "TOP", 0, 12);
local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal");
title:SetPoint("TOP", header, "TOP", 0, -14); title:SetText("Vanity");
local close = CreateFrame("Button", nil, f, "UIPanelCloseButton");
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6);
local counter = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
counter:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -30);

local Refresh, Render;
local locked = CreateFrame("CheckButton", "TemucraftVanityShowLocked", f, "UICheckButtonTemplate");
locked:SetWidth(24); locked:SetHeight(24); locked:SetPoint("TOPRIGHT", f, "TOPRIGHT", -120, -24);
locked:SetChecked(true);
_G["TemucraftVanityShowLockedText"]:SetText("Show locked");
locked:SetScript("OnClick", function(self) state.showLocked = self:GetChecked() and true or false; Refresh(); end);

local listBg = CreateFrame("Frame", nil, f);
listBg:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -52); listBg:SetWidth(394); listBg:SetHeight(ROWS * ROW_H + 10);
listBg:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } });
listBg:SetBackdropColor(0, 0, 0, 0.6);
local scroll = CreateFrame("ScrollFrame", "TemucraftVanityScroll", listBg, "FauxScrollFrameTemplate");
scroll:SetPoint("TOPLEFT", listBg, "TOPLEFT", 0, -5); scroll:SetPoint("BOTTOMRIGHT", listBg, "BOTTOMRIGHT", -26, 5);

local rows = {};
for i = 1, ROWS do
	local r = CreateFrame("Frame", nil, listBg);
	r:SetWidth(362); r:SetHeight(ROW_H);
	r:SetPoint("TOPLEFT", listBg, "TOPLEFT", 6, -5 - (i - 1) * ROW_H);
	r.icon = CreateFrame("Button", nil, r);
	r.icon:SetWidth(34); r.icon:SetHeight(34); r.icon:SetPoint("LEFT", r, "LEFT", 2, 0);
	r.icon.tex = r.icon:CreateTexture(nil, "ARTWORK"); r.icon.tex:SetAllPoints();
	r.icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
	r.icon.cd = CreateFrame("Cooldown", nil, r.icon, "CooldownFrameTemplate"); r.icon.cd:SetAllPoints();
	r.icon:SetScript("OnEnter", function(self)
		if ( not self.entry ) then return; end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetHyperlink("item:"..self.entry..":0:0:0:0:0:0:0");
		GameTooltip:Show();
	end);
	r.icon:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	r.icon:SetScript("OnClick", function(self)
		if ( self.entry and IsModifiedClick("CHATLINK") ) then
			local _, link = GetItemInfo(self.entry);
			if ( link ) then ChatEdit_InsertLink(link); end
		end
	end);
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -2); r.name:SetWidth(220); r.name:SetJustifyH("LEFT");
	r.note = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	r.note:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3); r.note:SetWidth(220); r.note:SetJustifyH("LEFT");
	r.summon = CreateFrame("Button", nil, r, "UIPanelButtonTemplate");
	r.summon:SetWidth(80); r.summon:SetHeight(22); r.summon:SetPoint("RIGHT", r, "RIGHT", -2, 0);
	r.summon:SetText("Summon");
	r.summon:SetScript("OnClick", function(self) if ( self.entry ) then Send("SUMMON~"..self.entry); end end);
	rows[i] = r;
end

local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 22, 24); hint:SetWidth(386); hint:SetJustifyH("LEFT");
hint:SetText("Get one on any character and every character of your account can summon it here. Its cooldown stays.");

-- filling -----------------------------------------------------------------------------------------------------------
local function Build()
	local list = {};
	for _, e in ipairs(state.items) do
		if ( e.unlocked or state.showLocked ) then list[#list + 1] = e; end
	end
	view.list = list;
end

Refresh = function()
	if ( not f:IsShown() ) then return; end
	Build();
	Render();
end

Render = function()
	if ( not f:IsShown() ) then return; end
	local n = #view.list;
	FauxScrollFrame_Update(scroll, n, ROWS, ROW_H);
	local offset = FauxScrollFrame_GetOffset(scroll);
	for i = 1, ROWS do
		local r, e = rows[i], view.list[offset + i];
		if ( e ) then
			local name, _, quality, texture = ItemData(e);
			local have = GetItemCount(e.entry, true) > 0 or e.have;
			r.icon.entry = e.entry; r.summon.entry = e.entry;
			r.icon.tex:SetTexture(texture);
			r.name:SetText(name);
			if ( e.unlocked ) then
				local c = ITEM_QUALITY_COLORS[quality] or ITEM_QUALITY_COLORS[1];
				r.name:SetTextColor(c.r, c.g, c.b); r.icon.tex:SetDesaturated(nil);
			else
				r.name:SetTextColor(0.5, 0.5, 0.5); r.icon.tex:SetDesaturated(1);
			end
			local cd = Cooldown(e);
			local note;
			if ( not e.unlocked ) then
				note = "|cff808080Not unlocked yet: buy one from an innkeeper.|r";
			elseif ( cd > 0 ) then
				note = "|cffff6060Cooldown: "..FormatTime(ceil(cd)).."|r";
			else
				note = "|cff60ff60Ready|r";
			end
			if ( e.unlocked and have ) then note = note.."  |cffffd100(in your bags)|r"; end
			if ( e.level > UnitLevel("player") ) then note = note.."  |cffff6060Level "..e.level.."|r"; end
			r.note:SetText(note);
			if ( cd > 0 ) then
				local start, duration = GetItemCooldown(e.entry);
				if ( GetItemCount(e.entry) == 0 or not start or start == 0 ) then start, duration = e.cdRecv, e.cdEnd - e.cdRecv; end
				r.icon.cd:SetCooldown(start, duration);
			else
				r.icon.cd:Hide();
			end
			if ( e.unlocked and not have ) then r.summon:Enable(); else r.summon:Disable(); end
			r:Show();
		else
			r:Hide();
		end
	end
	if ( state.loading ) then
		counter:SetText("Loading your collection...");
	else
		counter:SetText(state.owned.." of "..state.total.." unlocked");
	end
end

scroll:SetScript("OnVerticalScroll", function(self, value) FauxScrollFrame_OnVerticalScroll(self, value, ROW_H, Render); end);
f:SetScript("OnShow", function() state.loading = true; Send("LIST"); Refresh(); end);
local tick = 0;
f:SetScript("OnUpdate", function(self, elapsed)
	tick = tick + elapsed;
	if ( tick >= 1 ) then tick = 0; Render(); end
end);

-- server ------------------------------------------------------------------------------------------------------------
local events = CreateFrame("Frame");
events:RegisterEvent("CHAT_MSG_ADDON");
events:RegisterEvent("BAG_UPDATE");
events:SetScript("OnEvent", function(_, event, prefix, text, channel, sender)
	if ( event == "BAG_UPDATE" ) then Render(); return; end
	if ( prefix ~= PREFIX or channel ~= "WHISPER" or sender ~= UnitName("player") ) then return; end
	local cmd, a, b, c, d, e2, g, h = strsplit("~", text);
	if ( cmd == "OPEN" ) then
		if ( not f:IsShown() ) then f:Show(); end
	elseif ( cmd == "BEGIN" ) then
		state.pending = {}; state.owned = tonumber(a) or 0; state.total = tonumber(b) or 0;
	elseif ( cmd == "ITEM" and a ) then
		-- ITEM~entry~unlocked~in bags~cooldown seconds~required level~category~name
		local now = GetTime();
		state.pending[#state.pending + 1] = { entry = tonumber(a), unlocked = b == "1", have = c == "1",
			cdRecv = now, cdEnd = now + (tonumber(d) or 0), level = tonumber(e2) or 0, category = g or "", name = h or ("item "..a) };
	elseif ( cmd == "END" ) then
		state.items = state.pending; state.pending = {}; state.loading = false; Refresh();
	elseif ( cmd == "NEW" ) then
		if ( f:IsShown() ) then Send("LIST"); end
	end
end);

-- a Vanity button on the Wardrobe (mod-temucraft-costumes), when it is there
if ( TemucraftWardrobeFrame ) then
	local b = CreateFrame("Button", "TemucraftWardrobeVanityButton", TemucraftWardrobeFrame, "UIPanelButtonTemplate");
	b:SetWidth(80); b:SetHeight(22); b:SetPoint("TOPRIGHT", TemucraftWardrobeFrame, "TOPRIGHT", -44, -24);
	b:SetText("Vanity");
	b:SetScript("OnClick", function() if ( f:IsShown() ) then f:Hide(); else f:Show(); end end);
end

SLASH_TEMUCRAFTVANITY1 = "/vanity";
SlashCmdList["TEMUCRAFTVANITY"] = function() if ( f:IsShown() ) then f:Hide(); else f:Show(); end end;
