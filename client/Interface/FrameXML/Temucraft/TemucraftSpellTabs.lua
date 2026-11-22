-- Temucraft spellbook tabs (mod-temucraft-spellbook, prefix TSB): Racials, Professions, Mounts, Companions and Guild
-- tabs beside the spellbook, and a line in spellbook tooltips saying what a spell is.
local PREFIX = "TSB";
local flags, pending = {}, nil;
local F_RACIAL, F_PROFESSION, F_GUILD, F_PASSIVE, F_TELEPORT, F_TALENT, F_MOUNT, F_COMPANION = 1, 2, 4, 8, 16, 32, 64, 128;
local PER_PAGE = 12;

local function Send(text) SendAddonMessage(PREFIX, text, "WHISPER", UnitName("player")); end
local function Has(f, bit) return f and (f % (bit * 2)) >= bit; end
local function SpellIdOf(slot, book)
	local link = GetSpellLink(slot, book);
	return link and tonumber(string.match(link, "spell:(%d+)"));
end

-- what a spell is, for the tooltip line
local function Label(id, passive)
	local f = flags[id] or 0;
	local parts = {};
	if ( Has(f, F_RACIAL) ) then table.insert(parts, "Racial"); end
	if ( Has(f, F_PROFESSION) ) then table.insert(parts, "Profession"); end
	if ( Has(f, F_GUILD) ) then table.insert(parts, "Guild perk"); end
	if ( Has(f, F_TALENT) ) then table.insert(parts, "Talent"); end
	if ( Has(f, F_MOUNT) ) then table.insert(parts, "Mount"); end
	if ( Has(f, F_COMPANION) ) then table.insert(parts, "Companion"); end
	if ( Has(f, F_TELEPORT) ) then table.insert(parts, "Teleport"); end
	if ( passive or Has(f, F_PASSIVE) ) then table.insert(parts, "Passive"); end
	if ( #parts == 0 ) then table.insert(parts, "Spell"); end
	return table.concat(parts, " - ");
end

hooksecurefunc(GameTooltip, "SetSpell", function(tooltip, slot, book)
	local id = SpellIdOf(slot, book);
	if ( not id ) then return; end
	tooltip:AddLine(Label(id, IsPassiveSpell(slot, book)), 0.55, 0.75, 1);
	tooltip:Show();
end);

-- the panel over the spell pages (parented to UIParent: its buttons are secure, and a secure child would make the
-- spellbook itself impossible to open or close in combat)
local panel = CreateFrame("Frame", "TemucraftSpellTabsPanel", UIParent);
panel:SetFrameStrata("HIGH");
panel:SetPoint("TOPLEFT", SpellBookFrame, "TOPLEFT", 22, -74);
panel:SetWidth(300); panel:SetHeight(330);
-- solid: the spellbook's own buttons are under it and must not show through
local bgFill = panel:CreateTexture(nil, "BACKGROUND");
bgFill:SetAllPoints(); bgFill:SetTexture(0.18, 0.14, 0.09, 1);
local bg = panel:CreateTexture(nil, "BORDER");
bg:SetAllPoints(); bg:SetTexture("Interface\\QuestFrame\\QuestBG"); bg:SetTexCoord(0, 0.586, 0, 0.66);
panel:EnableMouse(true);
panel:Hide();
local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge");
title:SetPoint("TOP", 0, -6);
local pageText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal");
pageText:SetPoint("BOTTOM", 0, 8);
local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable");
empty:SetPoint("CENTER");

local buttons = {};
for i = 1, PER_PAGE do
	local b = CreateFrame("Button", "TemucraftSpellTabsButton"..i, panel, "SecureActionButtonTemplate");
	b:SetWidth(36); b:SetHeight(36);
	local col, row = (i - 1) % 2, floor((i - 1) / 2);
	b:SetPoint("TOPLEFT", panel, "TOPLEFT", 10 + col * 148, -32 - row * 46);
	b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints();
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
	b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	b.name:SetPoint("LEFT", b, "RIGHT", 4, 6); b.name:SetWidth(104); b.name:SetJustifyH("LEFT");
	b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
	b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -2); b.sub:SetWidth(104); b.sub:SetJustifyH("LEFT");
	b:RegisterForDrag("LeftButton");
	b:SetAttribute("type", "spell");
	b:SetScript("OnDragStart", function(self)
		if ( self.companion ) then PickupCompanion(self.companion, self.index);
		elseif ( self.slot ) then PickupSpell(self.slot, BOOKTYPE_SPELL); end
	end);
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		if ( self.slot ) then GameTooltip:SetSpell(self.slot, BOOKTYPE_SPELL);
		elseif ( self.spellId ) then GameTooltip:SetHyperlink("spell:"..self.spellId); end
		GameTooltip:Show();
	end);
	b:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	b:Hide();
	buttons[i] = b;
end

local current, page, entries = nil, 1, {};

-- spellbook spells with a flag
local function BookSpells(bit)
	local out = {};
	local i = 1;
	while true do
		local name, rank = GetSpellName(i, BOOKTYPE_SPELL);
		if ( not name ) then break; end
		local id = SpellIdOf(i, BOOKTYPE_SPELL);
		if ( id and Has(flags[id], bit) ) then
			-- keep only the highest rank of each name
			if ( #out > 0 and out[#out].name == name ) then table.remove(out); end
			table.insert(out, { name = name, rank = rank, slot = i, icon = GetSpellTexture(i, BOOKTYPE_SPELL), spell = name..(rank and rank ~= "" and "("..rank..")" or "") });
		end
		i = i + 1;
	end
	return out;
end

local function Companions(kind)
	local out = {};
	for i = 1, GetNumCompanions(kind) do
		local _, name, spellId, icon = GetCompanionInfo(kind, i);
		if ( name ) then table.insert(out, { name = name, rank = "", icon = icon, spellId = spellId, spell = GetSpellInfo(spellId) or name, companion = kind, index = i }); end
	end
	return out;
end

local TABS = {
	{ name = "Racials",     icon = "Interface\\Icons\\Achievement_Character_Human_Male", list = function() return BookSpells(F_RACIAL); end },
	{ name = "Professions", icon = "Interface\\Icons\\Trade_BlackSmithing",              list = function() return BookSpells(F_PROFESSION); end },
	{ name = "Mounts",      icon = "Interface\\Icons\\Ability_Mount_RidingHorse",        list = function() return Companions("MOUNT"); end },
	{ name = "Companions",  icon = "Interface\\Icons\\INV_Box_PetCarrier_01",            list = function() return Companions("CRITTER"); end },
	{ name = "Guild",       icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01",         list = function() return BookSpells(F_GUILD); end },
};

local function Show()
	if ( InCombatLockdown() ) then return; end
	if ( not current ) then panel:Hide(); return; end
	entries = TABS[current].list();
	local pages = max(1, ceil(#entries / PER_PAGE));
	if ( page > pages ) then page = pages; end
	title:SetText(TABS[current].name);
	pageText:SetText(format("Page %d / %d", page, pages));
	empty:SetText(#entries == 0 and "Nothing here yet." or "");
	for i = 1, PER_PAGE do
		local e, b = entries[(page - 1) * PER_PAGE + i], buttons[i];
		if ( e ) then
			b.icon:SetTexture(e.icon);
			b.name:SetText(e.name);
			b.sub:SetText(e.rank or "");
			b.slot, b.spellId, b.companion, b.index = e.slot, e.spellId, e.companion, e.index;
			b:SetAttribute("spell", e.spell);
			b:Show();
		else
			b:Hide();
		end
	end
	panel:Show();
end

local prev = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate");
prev:SetWidth(24); prev:SetHeight(22); prev:SetText("<"); prev:SetPoint("BOTTOMLEFT", 8, 4);
prev:SetScript("OnClick", function() if ( page > 1 ) then page = page - 1; Show(); end end);
local nextb = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate");
nextb:SetWidth(24); nextb:SetHeight(22); nextb:SetText(">"); nextb:SetPoint("BOTTOMRIGHT", -8, 4);
nextb:SetScript("OnClick", function() if ( page * PER_PAGE < #entries ) then page = page + 1; Show(); end end);

-- the tab buttons, on the right side below the spellbook's own tabs
local tabs = {};
for i, t in ipairs(TABS) do
	local tab = CreateFrame("CheckButton", "TemucraftSpellTab"..i, SpellBookFrame);
	tab:SetWidth(32); tab:SetHeight(32);
	tab:SetPoint("TOPLEFT", SpellBookFrame, "TOPRIGHT", -32, -300 - (i - 1) * 40);
	tab:SetNormalTexture(t.icon);
	tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
	tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD");
	local border = tab:CreateTexture(nil, "BACKGROUND");
	border:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab");
	border:SetWidth(64); border:SetHeight(64); border:SetPoint("TOPLEFT", -3, 11);
	tab:SetScript("OnClick", function(self)
		if ( InCombatLockdown() ) then self:SetChecked(current == i); return; end
		if ( current == i ) then current = nil; else current, page = i, 1; end
		for j, other in ipairs(tabs) do other:SetChecked(current == j); end
		Show();
	end);
	tab:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(t.name); GameTooltip:Show();
	end);
	tab:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	tabs[i] = tab;
end

local closeLater = false;
local function Close()
	current = nil;
	for _, tab in ipairs(tabs) do tab:SetChecked(false); end
	if ( InCombatLockdown() ) then closeLater = true; else panel:Hide(); end
end
SpellBookFrame:HookScript("OnHide", Close);
hooksecurefunc("SpellBookFrame_Update", function() if ( current ) then Show(); end end);
for i = 1, 8 do
	local skillTab = _G["SpellBookSkillLineTab"..i];
	if ( skillTab ) then skillTab:HookScript("OnClick", Close); end
end

local events = CreateFrame("Frame");
events:RegisterEvent("PLAYER_ENTERING_WORLD");
events:RegisterEvent("LEARNED_SPELL_IN_TAB");
events:RegisterEvent("COMPANION_LEARNED");
events:RegisterEvent("PLAYER_REGEN_ENABLED");
events:RegisterEvent("CHAT_MSG_ADDON");
local asked = 0;
events:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
	if ( event == "CHAT_MSG_ADDON" ) then
		if ( prefix ~= PREFIX or channel ~= "WHISPER" or sender ~= UnitName("player") ) then return; end
		if ( message == "BEGIN" ) then pending = {};
		elseif ( message == "END" and pending ) then flags, pending = pending, nil; if ( current ) then Show(); end
		elseif ( pending and string.sub(message, 1, 2) == "C~" ) then
			for id, f in string.gmatch(string.sub(message, 3), "(%d+):(%d+)") do pending[tonumber(id)] = tonumber(f); end
		end
	elseif ( event == "PLAYER_REGEN_ENABLED" ) then
		if ( closeLater ) then closeLater = false; if ( not current ) then panel:Hide(); end end
		if ( current and SpellBookFrame:IsShown() ) then Show(); end
	elseif ( GetTime() - asked > 2 ) then
		asked = GetTime();
		Send("LIST");
	end
end);
