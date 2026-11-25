-- Temucraft player spells window: one window with Specialization / Talents / Spellbook tabs at the bottom, like the
-- retail one. P (and the spellbook micro button) opens it on the Spellbook tab, N (and the talent micro button) on
-- Talents. "/tsb classic" (or the checkbox in the book) brings back the stock spellbook, "/ttf classic" the stock talent
-- frame; "/tsb new", "/ttf new" switch back. The panels are in TemucraftSpellBook.lua and TemucraftTalents.lua.
--
-- Combat: the spellbook's buttons are secure (they cast), so anything that moves, resizes or re-points them, or changes
-- their attributes, waits for the end of combat (TemucraftPlayerSpells_AfterCombat).
local WIDTH, WIDE_WIDTH, HEIGHT = 820, 1560, 640;
local TAB_SPEC, TAB_TALENTS, TAB_SPELLBOOK = 1, 2, 3;
TEMUCRAFT_PLAYERSPELLS_TAB_SPEC, TEMUCRAFT_PLAYERSPELLS_TAB_TALENTS, TEMUCRAFT_PLAYERSPELLS_TAB_SPELLBOOK = TAB_SPEC, TAB_TALENTS, TAB_SPELLBOOK;

-- things to do once combat ends (each key once: the latest wins)
local afterCombat, afterCombatOrder = {}, {};
function TemucraftPlayerSpells_AfterCombat(key, func)
	if ( not InCombatLockdown() ) then func(); return; end
	if ( not afterCombat[key] ) then table.insert(afterCombatOrder, key); end
	afterCombat[key] = func;
end

local frame = CreateFrame("Frame", "TemucraftPlayerSpellsFrame", UIParent);
frame:SetWidth(WIDTH); frame:SetHeight(HEIGHT);
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20);
frame:SetFrameStrata("HIGH");
frame:SetToplevel(true);
frame:EnableMouse(true);
frame:SetMovable(true);
frame:SetClampedToScreen(true);
frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } });
frame:Hide();
tinsert(UISpecialFrames, "TemucraftPlayerSpellsFrame");

-- parchment inside the border
local parchment = frame:CreateTexture(nil, "BACKGROUND", nil, 1);
parchment:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal");
parchment:SetPoint("TOPLEFT", 12, -12); parchment:SetPoint("BOTTOMRIGHT", -12, 12);
parchment:SetVertexColor(0.85, 0.8, 0.7);
frame.parchment = parchment;

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
title:SetPoint("TOP", 0, -20);
frame.title = title;

local close = CreateFrame("Button", "TemucraftPlayerSpellsFrameCloseButton", frame, "UIPanelCloseButton");
close:SetPoint("TOPRIGHT", -6, -6);

-- drag by the top strip
local drag = CreateFrame("Frame", nil, frame);
drag:SetPoint("TOPLEFT", 12, -8); drag:SetPoint("TOPRIGHT", -40, -8); drag:SetHeight(28);
drag:EnableMouse(true);
drag:RegisterForDrag("LeftButton");
drag:SetScript("OnDragStart", function() if ( not InCombatLockdown() ) then frame:StartMoving(); end end);
drag:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); end);

local panels, onShow = {}, {};
local TAB_NAMES = { "Specialization", "Talents", "Spellbook" };
local current = TAB_SPELLBOOK;

function TemucraftPlayerSpells_AddPanel(index, panel, show)
	panels[index] = panel;
	onShow[index] = show;
	panel:SetParent(frame);
	panel:SetPoint("TOPLEFT", 14, -14);
	panel:SetPoint("BOTTOMRIGHT", -14, 14);
	panel:Hide();
end

local wide = false;
function TemucraftPlayerSpells_SetWide(on)
	TemucraftPlayerSpells_AfterCombat("wide", function()
		wide = on and current == TAB_SPELLBOOK;
		frame:SetWidth(wide and WIDE_WIDTH or WIDTH);
	end);
end

function TemucraftPlayerSpells_GetTab() return frame:IsShown() and current or nil; end

local function TalentsAllowed() return UnitLevel("player") >= (SHOW_TALENT_LEVEL or 10); end

local tabs = {};
local function UpdateTabs()
	for i, tab in ipairs(tabs) do
		if ( i ~= TAB_SPELLBOOK and not TalentsAllowed() ) then
			PanelTemplates_DisableTab(frame, i);
		elseif ( i == current ) then
			PanelTemplates_SelectTab(tab);
		else
			PanelTemplates_DeselectTab(tab);
		end
	end
	frame.selectedTab = current;
end

function TemucraftPlayerSpells_Show(index)
	if ( index ~= TAB_SPELLBOOK and not TalentsAllowed() ) then index = TAB_SPELLBOOK; end
	current = index;
	for i, panel in pairs(panels) do
		if ( i ~= index ) then panel:Hide(); end
	end
	title:SetText(index == TAB_SPELLBOOK and SPELLBOOK or (index == TAB_TALENTS and TALENTS or "Specialization"));
	if ( index ~= TAB_SPELLBOOK and wide ) then TemucraftPlayerSpells_SetWide(false); end
	if ( panels[index] ) then
		panels[index]:Show();
		if ( onShow[index] ) then onShow[index](panels[index]); end
	end
	frame:Show();
	UpdateTabs();
	if ( UpdateMicroButtons ) then UpdateMicroButtons(); end
end

function TemucraftPlayerSpells_Toggle(index)
	if ( frame:IsShown() and current == index ) then
		frame:Hide();
	else
		TemucraftPlayerSpells_Show(index);
	end
end

for i, name in ipairs(TAB_NAMES) do
	local tab = CreateFrame("Button", "TemucraftPlayerSpellsFrameTab"..i, frame, "CharacterFrameTabButtonTemplate");
	tab:SetID(i);
	tab:SetText(name);
	if ( i == 1 ) then tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 20, 8);
	else tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", -16, 0); end
	tab:SetScript("OnClick", function(self)
		PlaySound("igCharacterInfoTab");
		TemucraftPlayerSpells_Show(self:GetID());
	end);
	tabs[i] = tab;
end
PanelTemplates_SetNumTabs(frame, #TAB_NAMES);
PanelTemplates_SetTab(frame, current);

frame:SetScript("OnShow", function() PlaySound("igSpellBookOpen"); end);
frame:SetScript("OnHide", function()
	PlaySound("igSpellBookClose");
	for _, panel in pairs(panels) do panel:Hide(); end
	if ( UpdateMicroButtons ) then UpdateMicroButtons(); end
end);

-- classic or new: account-wide choice (TemucraftStore), "1" = the stock frame
function TemucraftPlayerSpells_IsClassic(which)
	return TemucraftStore_Get and TemucraftStore_Get("A", "ui.classic"..which) == "1";
end
function TemucraftPlayerSpells_SetClassic(which, on)
	if ( TemucraftStore_Set ) then TemucraftStore_Set("A", "ui.classic"..which, on and "1" or ""); end
	if ( on and frame:IsShown() ) then
		if ( (which == "book" and current == TAB_SPELLBOOK) or (which == "talents" and current ~= TAB_SPELLBOOK) ) then frame:Hide(); end
	end
end

-- P / N and the micro buttons call these
local StockToggleSpellBook, StockToggleTalentFrame = ToggleSpellBook, ToggleTalentFrame;
TemucraftStockToggleSpellBook, TemucraftStockToggleTalentFrame = StockToggleSpellBook, StockToggleTalentFrame;
function ToggleSpellBook(bookType, ...)
	if ( bookType ~= BOOKTYPE_SPELL or TemucraftPlayerSpells_IsClassic("book") ) then
		return StockToggleSpellBook(bookType, ...);
	end
	if ( SpellBookFrame:IsShown() ) then HideUIPanel(SpellBookFrame); end
	TemucraftPlayerSpells_Toggle(TAB_SPELLBOOK);
end
function ToggleTalentFrame(...)
	if ( TemucraftPlayerSpells_IsClassic("talents") ) then
		return StockToggleTalentFrame(...);
	end
	if ( not TalentsAllowed() ) then return; end
	if ( PlayerTalentFrame and PlayerTalentFrame:IsShown() ) then HideUIPanel(PlayerTalentFrame); end
	TemucraftPlayerSpells_Toggle(TAB_TALENTS);
end

-- the micro buttons look pressed while their tab is open
hooksecurefunc("UpdateMicroButtons", function()
	local tab = TemucraftPlayerSpells_GetTab();
	if ( tab == TAB_SPELLBOOK and SpellbookMicroButton ) then SpellbookMicroButton:SetButtonState("PUSHED", 1); end
	if ( tab and tab ~= TAB_SPELLBOOK and TalentMicroButton ) then TalentMicroButton:SetButtonState("PUSHED", 1); end
end);

local function Slash(which, label, msg)
	msg = strlower(strtrim(msg or ""));
	if ( msg == "classic" or msg == "old" ) then
		TemucraftPlayerSpells_SetClassic(which, true);
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffTemucraft:|r the "..label.." opens the classic window now ("..(which == "book" and "/tsb new" or "/ttf new").." to switch back).");
	elseif ( msg == "new" or msg == "retail" ) then
		TemucraftPlayerSpells_SetClassic(which, false);
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffTemucraft:|r the "..label.." opens the new window now.");
	elseif ( which == "book" ) then
		TemucraftPlayerSpells_Toggle(TAB_SPELLBOOK);
	else
		TemucraftPlayerSpells_Toggle(TAB_TALENTS);
	end
end
SLASH_TEMUCRAFTSPELLBOOK1 = "/tsb";
SlashCmdList["TEMUCRAFTSPELLBOOK"] = function(msg) Slash("book", "spellbook", msg); end;
SLASH_TEMUCRAFTTALENTS1 = "/ttf";
SlashCmdList["TEMUCRAFTTALENTS"] = function(msg) Slash("talents", "talent window", msg); end;

local events = CreateFrame("Frame");
events:RegisterEvent("PLAYER_REGEN_ENABLED");
events:RegisterEvent("PLAYER_LEVEL_UP");
events:SetScript("OnEvent", function(self, event)
	if ( event == "PLAYER_REGEN_ENABLED" ) then
		local order = afterCombatOrder;
		afterCombatOrder = {};
		for _, key in ipairs(order) do
			local func = afterCombat[key];
			afterCombat[key] = nil;
			if ( func ) then func(); end
		end
	elseif ( frame:IsShown() ) then
		UpdateTabs();
	end
end);
