-- Temucraft currency window (retail look, the same style as TemucraftReputation.lua): the currencies under their
-- categories (collapsible), the count on the right, and on the right a panel with the selected currency's icon,
-- count and description, Move to Unused and Show on Backpack (the stock SetCurrencyUnused / SetCurrencyBackpack,
-- at most MAX_WATCHED_TOKENS on the backpack as in the stock window). Shift-click links the currency.
-- The character panel's Currency tab and the stock one open it; "Classic currency window" (/tui) opens the stock one.
-- Like the reputation window it opens every stock category to read the whole list and keeps its own collapsed state.

----------------------------------------------------------------------------------------------------------------------
-- The logic (no frames: tests/reputation_test.lua runs it with stubs)
----------------------------------------------------------------------------------------------------------------------
TemucraftCurrencyLogic = {};
local L = TemucraftCurrencyLogic;

-- rows: { { index, name, isHeader, isUnused, isWatched, count, extra, icon, itemID } } (the whole list, expanded);
-- returns the lines: { kind = "group"|"currency", key, name, row, collapsed }
function L.Lines(rows, collapsed)
	collapsed = collapsed or {};
	local out, header = {}, nil;
	for _, r in ipairs(rows) do
		if ( r.isHeader ) then
			header = r.name;
			table.insert(out, { kind = "group", key = r.name, name = r.name, collapsed = collapsed[r.name] });
		elseif ( not (header and collapsed[header]) ) then
			table.insert(out, { kind = "currency", name = r.name, row = r });
		end
	end
	-- categories with nothing in them stay out
	local final = {};
	for i, line in ipairs(out) do
		local nextLine = out[i + 1];
		if ( line.kind ~= "group" or line.collapsed or (nextLine and nextLine.kind == "currency") ) then table.insert(final, line); end
	end
	return final;
end

function L.Watched(rows)
	local n = 0;
	for _, r in ipairs(rows) do if ( r.isWatched and not r.isHeader ) then n = n + 1; end end
	return n;
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

local function ExpandAll()
	if ( not GetCurrencyListSize ) then return; end
	for pass = 1, 5 do
		local any = false;
		for i = GetCurrencyListSize(), 1, -1 do
			local name, isHeader, isExpanded = GetCurrencyListInfo(i);
			if ( name and isHeader and not isExpanded ) then ExpandCurrencyList(i, 1); any = true; end
		end
		if ( not any ) then return; end
	end
end

local function ReadRows()
	ExpandAll();
	local rows = {};
	for i = 1, (GetCurrencyListSize and GetCurrencyListSize() or 0) do
		local name, isHeader, isExpanded, isUnused, isWatched, count, extra, icon, itemID = GetCurrencyListInfo(i);
		if ( name and name ~= "" ) then
			table.insert(rows, { index = i, name = name, isHeader = isHeader and true or false, isUnused = isUnused and true or false,
				isWatched = isWatched and true or false, count = count or 0, extra = extra, icon = icon, itemID = itemID });
		end
	end
	return rows;
end

local function FindIndex(name)
	for i = 1, (GetCurrencyListSize and GetCurrencyListSize() or 0) do
		if ( GetCurrencyListInfo(i) == name ) then return i; end
	end
	return nil;
end

-- the icon of a currency row (honor and arena points have their own)
local function SetIcon(texture, r)
	texture:SetTexCoord(0, 1, 0, 1);
	if ( r.extra == 1 ) then
		texture:SetTexture("Interface\\PVPFrame\\PVP-ArenaPoints-Icon");
	elseif ( r.extra == 2 ) then
		local side = UnitFactionGroup("player");
		texture:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..(side or "FFA"));
		texture:SetTexCoord(0.03125, 0.59375, 0.03125, 0.59375);
	else
		texture:SetTexture(r.icon);
	end
end

----------------------------------------------------------------------------------------------------------------------
-- The window
----------------------------------------------------------------------------------------------------------------------
local WIDTH, HEIGHT, LIST_WIDTH = 720, 500, 430;
local NUM_ROWS, ROW_HEIGHT = 17, 24;
local Panel = TemucraftReputationLogic and TemucraftReputationLogic.Panel;

local frame = CreateFrame("Frame", "TemucraftCurrencyFrame", UIParent);
frame:SetWidth(WIDTH); frame:SetHeight(HEIGHT);
frame:SetToplevel(true);
frame:EnableMouse(true);
frame:SetMovable(true);
frame:SetClampedToScreen(true);
frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } });
frame:Hide();
UIPanelWindows["TemucraftCurrencyFrame"] = { area = "left", pushable = 3, whileDead = 1 };

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
title:SetPoint("TOP", 0, -18);
title:SetText(CURRENCY or "Currency");
local close = CreateFrame("Button", "TemucraftCurrencyFrameCloseButton", frame, "UIPanelCloseButton");
close:SetPoint("TOPRIGHT", -6, -6);
local drag = CreateFrame("Frame", nil, frame);
drag:SetPoint("TOPLEFT", 12, -8); drag:SetPoint("TOPRIGHT", -40, -8); drag:SetHeight(26);
drag:EnableMouse(true);
drag:RegisterForDrag("LeftButton");
drag:SetScript("OnDragStart", function() frame:StartMoving(); end);
drag:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); end);

local listBox = Panel(frame);
listBox:SetPoint("TOPLEFT", 16, -64);
listBox:SetWidth(LIST_WIDTH); listBox:SetHeight(NUM_ROWS * ROW_HEIGHT + 12);
local detail = Panel(frame);
detail:SetPoint("TOPLEFT", listBox, "TOPRIGHT", 8, 0);
detail:SetPoint("BOTTOMRIGHT", -16, 24);

local scroll = CreateFrame("ScrollFrame", "TemucraftCurrencyScroll", listBox, "FauxScrollFrameTemplate");
scroll:SetPoint("TOPLEFT", 6, -6);
scroll:SetPoint("BOTTOMRIGHT", -28, 6);

local collapsed, selectedName, Update = {}, nil, nil;
local allRows = {};
local rows = {};
for i = 1, NUM_ROWS do
	local b = CreateFrame("Button", nil, listBox);
	b:SetHeight(ROW_HEIGHT - 2);
	b:SetPoint("TOPLEFT", 8, -8 - (i - 1) * ROW_HEIGHT);
	b:SetPoint("RIGHT", scroll, "RIGHT", 0, 0);
	b.band = b:CreateTexture(nil, "BACKGROUND");
	b.band:SetAllPoints();
	b.expand = b:CreateTexture(nil, "ARTWORK");
	b.expand:SetWidth(14); b.expand:SetHeight(14);
	b.expand:SetPoint("LEFT", 0, 0);
	b.icon = b:CreateTexture(nil, "ARTWORK");
	b.icon:SetWidth(ROW_HEIGHT - 6); b.icon:SetHeight(ROW_HEIGHT - 6);
	b.icon:SetPoint("LEFT", 16, 0);
	b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	b.count:SetPoint("RIGHT", -8, 0);
	b.check = b:CreateTexture(nil, "OVERLAY");
	b.check:SetWidth(14); b.check:SetHeight(14);
	b.check:SetPoint("RIGHT", b.count, "LEFT", -6, 0);
	b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check");
	b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.name:SetJustifyH("LEFT");
	b.name:SetPoint("RIGHT", b.check, "LEFT", -4, 0);
	b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD");
	b:SetScript("OnEnter", function(self)
		local line = self.line;
		if ( not line or line.kind ~= "currency" ) then return; end
		local index = FindIndex(line.name);
		if ( index ) then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetCurrencyToken(index);
			GameTooltip:Show();
		end
	end);
	b:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	b:SetScript("OnClick", function(self)
		local line = self.line;
		if ( not line ) then return; end
		if ( line.kind == "group" ) then
			collapsed[line.key] = not collapsed[line.key] or nil;
		elseif ( IsModifiedClick("CHATLINK") and line.row.itemID ) then
			local _, link = GetItemInfo(line.row.itemID);
			if ( link ) then ChatEdit_InsertLink(link); end
			return;
		else
			selectedName = line.name;
		end
		PlaySound("igMainMenuOptionCheckBoxOn");
		Update();
	end);
	rows[i] = b;
end

-- the detail panel
local dIcon = detail:CreateTexture(nil, "ARTWORK");
dIcon:SetWidth(40); dIcon:SetHeight(40);
dIcon:SetPoint("TOPLEFT", 12, -12);
local dName = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
dName:SetPoint("TOPLEFT", dIcon, "TOPRIGHT", 8, -2); dName:SetPoint("RIGHT", -12, 0);
dName:SetJustifyH("LEFT");
local dCount = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
dCount:SetPoint("TOPLEFT", dName, "BOTTOMLEFT", 0, -4);
local dDesc = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
dDesc:SetPoint("TOPLEFT", dIcon, "BOTTOMLEFT", 0, -12);
dDesc:SetPoint("RIGHT", -12, 0);
dDesc:SetHeight(220);
dDesc:SetJustifyH("LEFT"); dDesc:SetJustifyV("TOP");
local dNone = detail:CreateFontString(nil, "OVERLAY", "GameFontDisable");
dNone:SetPoint("CENTER");
dNone:SetText("Select a currency");

local function Check(name, label, y, tip)
	local c = CreateFrame("CheckButton", name, detail, "UICheckButtonTemplate");
	c:SetWidth(24); c:SetHeight(24);
	c:SetPoint("BOTTOMLEFT", 10, y);
	_G[name.."Text"]:SetText(label);
	c:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(tip, nil, nil, nil, nil, 1);
	end);
	c:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	return c;
end
local unusedCheck = Check("TemucraftCurrencyUnusedCheck", "Move to Unused", 40, TOKEN_MOVE_TO_UNUSED or "Moves this currency to the Unused list.");
local backpackCheck = Check("TemucraftCurrencyBackpackCheck", SHOW_ON_BACKPACK or "Show on Backpack", 16,
	TOKEN_SHOW_ON_BACKPACK or "Shows this currency at the bottom of your backpack.");

local function Backpack()
	if ( not BackpackTokenFrame_Update and TokenFrame_LoadUI ) then TokenFrame_LoadUI(); end
	if ( BackpackTokenFrame_Update ) then BackpackTokenFrame_Update(); end
	if ( ManageBackpackTokenFrame ) then ManageBackpackTokenFrame(); end
end
unusedCheck:SetScript("OnClick", function(self)
	local i = selectedName and FindIndex(selectedName);
	if ( i ) then SetCurrencyUnused(i, self:GetChecked() and 1 or 0); end
	PlaySound(self:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff");
	Update();
end);
backpackCheck:SetScript("OnClick", function(self)
	local i = selectedName and FindIndex(selectedName);
	if ( not i ) then return; end
	if ( self:GetChecked() ) then
		local max = MAX_WATCHED_TOKENS or 3;
		if ( L.Watched(allRows) >= max ) then
			self:SetChecked(false);
			UIErrorsFrame:AddMessage(format(TOO_MANY_WATCHED_TOKENS or "You can only watch %d currencies.", max), 1.0, 0.1, 0.1, 1.0);
			return;
		end
		SetCurrencyBackpack(i, 1);
	else
		SetCurrencyBackpack(i, 0);
	end
	PlaySound(self:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff");
	Backpack();
	Update();
end);

-- the description: the currency's tooltip lines after its name
local scan = CreateFrame("GameTooltip", "TemucraftCurrencyScanTooltip", nil, "GameTooltipTemplate");
local function Description(index)
	scan:SetOwner(UIParent, "ANCHOR_NONE");
	scan:ClearLines();
	scan:SetCurrencyToken(index);
	local out = {};
	for i = 2, scan:NumLines() do
		local fs = _G["TemucraftCurrencyScanTooltipTextLeft"..i];
		local text = fs and fs:GetText();
		if ( text and text ~= "" ) then table.insert(out, text); end
	end
	scan:Hide();
	return table.concat(out, "\n");
end

local function UpdateDetail(r)
	local shown = r ~= nil;
	for _, w in ipairs({ dIcon, dName, dCount, dDesc, unusedCheck, backpackCheck }) do if ( shown ) then w:Show(); else w:Hide(); end end
	if ( not shown ) then dNone:Show(); return; end
	dNone:Hide();
	SetIcon(dIcon, r);
	dName:SetText(r.name);
	dCount:SetText((r.count or 0).."");
	dDesc:SetText(Description(r.index));
	unusedCheck:SetChecked(r.isUnused);
	backpackCheck:SetChecked(r.isWatched);
end

Update = function()
	if ( not frame:IsShown() ) then return; end
	allRows = ReadRows();
	local lines = TemucraftCurrencyLogic.Lines(allRows, collapsed);
	FauxScrollFrame_Update(scroll, #lines, NUM_ROWS, ROW_HEIGHT);
	local offset = FauxScrollFrame_GetOffset(scroll);
	local selected;
	for _, r in ipairs(allRows) do if ( r.name == selectedName and not r.isHeader ) then selected = r; end end
	for i, b in ipairs(rows) do
		local line = lines[offset + i];
		b.line = line;
		if ( not line ) then
			b:Hide();
		else
			b.name:ClearAllPoints();
			b.name:SetPoint("RIGHT", b.check, "LEFT", -4, 0);
			if ( line.kind == "group" ) then
				b.expand:SetTexture(line.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up");
				b.expand:Show(); b.icon:Hide(); b.check:Hide();
				b.name:SetPoint("LEFT", b.expand, "RIGHT", 4, 0);
				b.name:SetFontObject(GameFontNormal);
				b.name:SetText(line.name);
				b.count:SetText("");
				b.band:SetTexture(1, 0.82, 0, 0.12);
			else
				local r = line.row;
				b.expand:Hide();
				SetIcon(b.icon, r); b.icon:Show();
				b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, 0);
				b.name:SetFontObject((r.count or 0) == 0 and GameFontDisableSmall or GameFontHighlightSmall);
				b.name:SetText(r.name);
				b.count:SetFontObject((r.count or 0) == 0 and GameFontDisable or GameFontHighlight);
				b.count:SetText((r.count or 0).."");
				if ( r.isWatched ) then b.check:Show(); else b.check:Hide(); end
				if ( r.name == selectedName ) then b.band:SetTexture(0.3, 0.5, 1, 0.25);
				elseif ( (offset + i) % 2 == 0 ) then b.band:SetTexture(1, 1, 1, 0.04);
				else b.band:SetTexture(0, 0, 0, 0); end
			end
			b:Show();
		end
	end
	UpdateDetail(selected);
end
scroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, Update); end);
listBox:EnableMouseWheel(true);
listBox:SetScript("OnMouseWheel", function(_, delta)
	local bar = _G["TemucraftCurrencyScrollScrollBar"];
	if ( bar ) then bar:SetValue(bar:GetValue() - delta * ROW_HEIGHT * 3); end
end);

local classic = CreateFrame("CheckButton", "TemucraftCurrencyClassicCheck", frame, "UICheckButtonTemplate");
classic:SetWidth(22); classic:SetHeight(22);
classic:SetPoint("BOTTOMLEFT", 16, 2);
classic:Hide();   -- it sat on the bottom tabs: the choice is in Interface > Temucraft (and /tui) only
_G[classic:GetName().."Text"]:SetText("Classic");
classic:SetScript("OnClick", function(self)
	self:SetChecked(false);
	TemucraftUI_SetClassic("currency", true);
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffTemucraft:|r classic currency window on (/tui to switch back).");
end);

local LayoutTabs = TemucraftCharacter_AddTabs and TemucraftCharacter_AddTabs(frame, TEMUCRAFT_CHARACTER_TAB_CURRENCY or 5);
frame:SetScript("OnShow", function()
	PlaySound("igCharacterInfoOpen");
	if ( LayoutTabs ) then LayoutTabs(); end
	Update();
	if ( UpdateMicroButtons ) then UpdateMicroButtons(); end
end);
frame:SetScript("OnHide", function()
	PlaySound("igCharacterInfoClose");
	if ( UpdateMicroButtons ) then UpdateMicroButtons(); end
end);

function TemucraftCurrency_Toggle()
	if ( frame:IsShown() ) then HideUIPanel(frame); else ShowUIPanel(frame); end
end

if ( TemucraftCharacter_Redirect ) then
	TemucraftCharacter_Redirect.TokenFrame = { classic = "currency", open = function()
		if ( TemucraftUI_IsClassic("currency") ) then
			if ( frame:IsShown() ) then HideUIPanel(frame); end
			return false;
		end
		if ( CharacterFrame and CharacterFrame:IsShown() ) then HideUIPanel(CharacterFrame); end
		TemucraftCurrency_Toggle();
		return true;
	end };
end

hooksecurefunc("UpdateMicroButtons", function()
	if ( frame:IsShown() and CharacterMicroButton ) then
		CharacterMicroButton:SetButtonState("PUSHED", 1);
		CharacterMicroButton_SetPushed();
	end
end);

TemucraftUI_OnChange("classiccurrency", function(on)
	if ( on and frame:IsShown() ) then HideUIPanel(frame); end
end);

local events = CreateFrame("Frame");
events:RegisterEvent("CURRENCY_DISPLAY_UPDATE");
events:RegisterEvent("KNOWN_CURRENCY_TYPES_UPDATE");
local dirty = false;
events:SetScript("OnEvent", function(self)
	if ( dirty or not frame:IsShown() ) then return; end
	dirty = true;
	self:SetScript("OnUpdate", function(f)
		f:SetScript("OnUpdate", nil);
		dirty = false;
		Update();
	end);
end);
