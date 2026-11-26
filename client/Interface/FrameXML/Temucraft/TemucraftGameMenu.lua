-- Temucraft game menu (Esc), retail look ("Game Menu"): Options (the one Options window, TemucraftOptions.lua), Shop,
-- then AddOns, What's New, Edit Mode (DragonUI's editor, only while it is there), DragonUI's settings, Support,
-- Macros, then Log Out, Exit Game and Return to Game. "Classic options menu" (Interface > Temucraft) turns Options
-- back into Options +/- with the four stock windows (System, Sound, Interface, Key Bindings) under it. It is the stock
-- GameMenuFrame with its stock buttons (Log Out, Exit Game, Macros ... keep their own code) laid out again and ours
-- added; "Classic game menu" (Interface Options > Temucraft) puts back the stock layout.
-- What's New shows TEMUCRAFT_CHANGELOG (TemucraftChangelog.lua).
TemucraftGameMenuLogic = {};
local L = TemucraftGameMenuLogic;

-- the latest entries, as text: entries = TEMUCRAFT_CHANGELOG; version = this client's
function L.ChangelogText(entries, version, max)
	if ( not entries or #entries == 0 ) then return nil; end
	local out = {};
	for i, e in ipairs(entries) do
		if ( max and i > max ) then break; end
		local head = (e.version == "next") and "Coming next" or ("Temucraft "..e.version);
		if ( e.version == version ) then head = head.." (your client)"; end
		table.insert(out, "|cffffd100"..head.."|r");
		for _, line in ipairs(e.lines or {}) do table.insert(out, "- "..line); end
		table.insert(out, "");
	end
	return table.concat(out, "\n");
end

-- the menu's rows: { name, gapBefore } in order. extra: editmode = DragonUI's Edit Mode (moving the bars and frames),
-- dragonui = its settings button, classicoptions = the classic Options +/- (sub rows only while it is open)
function L.Rows(optionsOpen, mac, extra)
	extra = extra or {};
	local rows = { { "options" } };
	if ( optionsOpen and extra.classicoptions ) then
		for _, s in ipairs({ "GameMenuButtonOptions", "GameMenuButtonSoundOptions", "GameMenuButtonUIOptions", "GameMenuButtonKeybindings" }) do
			table.insert(rows, { s, nil, true });
		end
		if ( mac ) then table.insert(rows, { "GameMenuButtonMacOptions", nil, true }); end
	end
	table.insert(rows, { "shop" });
	-- Edit Mode and DragonUI's settings only while DragonUI has them: no dead ends in the menu
	local gap = 12;
	for _, s in ipairs({ "addons", "whatsnew", "editmode", "dragonui", "support", "GameMenuButtonMacros" }) do
		if ( (s ~= "editmode" and s ~= "dragonui") or extra[s] ) then table.insert(rows, { s, gap }); gap = nil; end
	end
	table.insert(rows, { "GameMenuButtonLogout", 12 });
	table.insert(rows, { "GameMenuButtonQuit" });
	table.insert(rows, { "GameMenuButtonContinue", 12 });
	return rows;
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

local BUTTON_WIDTH, SUB_WIDTH, BUTTON_HEIGHT = 170, 150, 24;
local STOCK = { "GameMenuButtonOptions", "GameMenuButtonSoundOptions", "GameMenuButtonUIOptions", "GameMenuButtonMacOptions",
	"GameMenuButtonKeybindings", "GameMenuButtonMacros", "GameMenuButtonRatings", "GameMenuButtonLogout", "GameMenuButtonQuit",
	"GameMenuButtonContinue" };
local SUB_TEXT = { GameMenuButtonOptions = "System", GameMenuButtonSoundOptions = "Sound", GameMenuButtonUIOptions = "Interface" };
local CLASSIC_BACKDROP = { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } };
local NEW_BACKDROP = { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } };

-- the stock layout, to put back
local saved = { height = GameMenuFrame:GetHeight(), width = GameMenuFrame:GetWidth() };
for _, name in ipairs(STOCK) do
	local b = _G[name];
	if ( b ) then
		local points = {};
		for i = 1, b:GetNumPoints() do points[i] = { b:GetPoint(i) }; end
		saved[name] = { points = points, width = b:GetWidth(), height = b:GetHeight(), text = b:GetText() };
	end
end

-- What's New
local news = CreateFrame("Frame", "TemucraftWhatsNewFrame", UIParent);
news:SetWidth(460); news:SetHeight(380);
news:SetPoint("CENTER");
news:SetFrameStrata("DIALOG");
news:SetToplevel(true);
news:EnableMouse(true);
news:SetBackdrop(NEW_BACKDROP);
news:Hide();
tinsert(UISpecialFrames, "TemucraftWhatsNewFrame");
local newsTitle = news:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
newsTitle:SetPoint("TOP", 0, -18);
newsTitle:SetText("What's New");
CreateFrame("Button", nil, news, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -6, -6);
local newsScroll = CreateFrame("ScrollFrame", "TemucraftWhatsNewScroll", news, "UIPanelScrollFrameTemplate");
newsScroll:SetPoint("TOPLEFT", 20, -46); newsScroll:SetPoint("BOTTOMRIGHT", -36, 20);
local newsChild = CreateFrame("Frame", nil, newsScroll);
newsChild:SetWidth(400); newsChild:SetHeight(10);
newsScroll:SetScrollChild(newsChild);
local newsText = newsChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
newsText:SetPoint("TOPLEFT"); newsText:SetWidth(400);
newsText:SetJustifyH("LEFT"); newsText:SetJustifyV("TOP");
news:SetScript("OnShow", function()
	local text = L.ChangelogText(TEMUCRAFT_CHANGELOG, TEMUCRAFT_CLIENT_VERSION);
	newsText:SetText(text or "Nothing here yet: the changes of each Temucraft update will show here.");
	newsChild:SetHeight(newsText:GetHeight() + 10);
	newsScroll:SetVerticalScroll(0);
end);

StaticPopupDialogs["TEMUCRAFT_EDIT_MODE_SOON"] = {
	text = "Edit Mode (moving the bars and frames) is coming in a later Temucraft update.",
	button1 = OKAY, timeout = 0, whileDead = 1, hideOnEscape = 1,
};

-- our buttons
local optionsOpen = false;
local ours = {};
local Layout;
local function Ours(key, text, onClick)
	local b = CreateFrame("Button", "TemucraftGameMenuButton_"..key, GameMenuFrame, "GameMenuButtonTemplate");
	b:SetText(text);
	b:SetScript("OnClick", function(self, button)
		PlaySound("igMainMenuOption");
		onClick(self, button);
	end);
	b:Hide();
	ours[key] = b;
	return b;
end
local function ClassicOptions() return TemucraftUI_IsClassic ~= nil and TemucraftUI_IsClassic("options"); end
Ours("options", "Options", function()
	if ( ClassicOptions() or not TemucraftOptions_Open ) then optionsOpen = not optionsOpen; Layout(); return; end
	HideUIPanel(GameMenuFrame);
	TemucraftOptions_Open(nil, GameMenuFrame);
end);
Ours("shop", "Shop", function() HideUIPanel(GameMenuFrame); TemucraftShop_Toggle(); end);
Ours("whatsnew", "What's New", function() HideUIPanel(GameMenuFrame); news:Show(); end);
Ours("addons", ADDONS or "AddOns", function() HideUIPanel(GameMenuFrame); TemucraftAddOnList_Toggle(); end);
-- DragonUI's editor mode (DragonUI.EditorMode, /dui edit); the row is there only while DragonUI runs
Ours("editmode", "Edit Mode", function()
	HideUIPanel(GameMenuFrame);
	local dui = _G.DragonUI;
	if ( dui and dui.EditorMode and dui.EditorMode.Toggle ) then
		if ( InCombatLockdown() ) then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "Not in combat.", 1, 0.1, 0.1); return; end
		dui.EditorMode:Toggle();
	else
		StaticPopup_Show("TEMUCRAFT_EDIT_MODE_SOON");
	end
end);
Ours("support", "Support", function() HideUIPanel(GameMenuFrame); ToggleHelpFrame(); end);

local function Classic()
	GameMenuFrame:SetBackdrop(CLASSIC_BACKDROP);
	GameMenuFrame:SetWidth(saved.width); GameMenuFrame:SetHeight(saved.height);
	for _, b in pairs(ours) do b:Hide(); end
	for _, name in ipairs(STOCK) do
		local b, s = _G[name], saved[name];
		if ( b and s ) then
			b:ClearAllPoints();
			for _, p in ipairs(s.points) do b:SetPoint(unpack(p)); end
			b:SetWidth(s.width); b:SetHeight(s.height);
			if ( s.text ) then b:SetText(s.text); end
		end
	end
	if ( not IsMacClient() and GameMenuButtonMacOptions ) then GameMenuButtonMacOptions:Hide(); end
	for _, name in ipairs({ "GameMenuButtonOptions", "GameMenuButtonSoundOptions", "GameMenuButtonUIOptions", "GameMenuButtonKeybindings", "GameMenuButtonMacros" }) do
		if ( _G[name] ) then _G[name]:Show(); end
	end
	-- DragonUI's AddOns button sits under Macros with Log Out below it, and both its buttons made the menu taller
	local addons = GameMenuButtonDragonUIAddons;
	if ( addons and addons:IsShown() ) then
		GameMenuButtonLogout:ClearAllPoints();
		GameMenuButtonLogout:SetPoint("TOP", addons, "BOTTOM", 0, -1);
		GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + addons:GetHeight() + 1);
	end
	if ( DragonUIGameMenuButton and DragonUIGameMenuButton:IsShown() ) then
		GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + DragonUIGameMenuButton:GetHeight() + 1);
	end
end

-- DragonUI adds two buttons to the menu (modules/gamemenu.lua: DragonUIGameMenuButton, its settings;
-- modules/addonmanager.lua: GameMenuButtonDragonUIAddons, its AddOns list) and keeps putting them back where it wants
-- them for a moment after the menu opens: they become rows here, and when it moves one we lay the menu out again.
local laying, relayout = false, CreateFrame("Frame");
relayout:Hide();
relayout:SetScript("OnUpdate", function(self) self:Hide(); if ( GameMenuFrame:IsShown() ) then Layout(); end end);
local watched = {};
local function Watch(b)
	if ( not b or watched[b] ) then return; end
	watched[b] = true;
	hooksecurefunc(b, "SetPoint", function() if ( not laying ) then relayout:Show(); end end);
end
local function DragonRows()
	if ( not (TemucraftDragonUI_IsLoaded and TemucraftDragonUI_IsLoaded()) ) then return {}, {}; end
	local dui = _G.DragonUI;
	local extra, buttons = { editmode = (type(dui) == "table" and dui.EditorMode and dui.EditorMode.Toggle) and true or nil }, {};
	-- DragonUI hides its settings button when DragonUI_Options is missing or off
	local reason = GetAddOnInfo and select(6, GetAddOnInfo("DragonUI_Options"));
	if ( DragonUIGameMenuButton and reason ~= "MISSING" and reason ~= "DISABLED" ) then extra.dragonui = true; buttons.dragonui = DragonUIGameMenuButton; Watch(DragonUIGameMenuButton); end
	if ( TemucraftDragonUI_Owns("addons") and GameMenuButtonDragonUIAddons ) then
		buttons.addons = GameMenuButtonDragonUIAddons; Watch(GameMenuButtonDragonUIAddons);
	end
	return extra, buttons;
end

-- the header says "Game Menu" (retail) in the new layout, the stock text in the classic one
local headerText;
for _, region in ipairs({ GameMenuFrame:GetRegions() }) do
	if ( region:GetObjectType() == "FontString" and region:GetText() == MAIN_MENU ) then headerText = region; end
end
local function HeaderText(new)
	if ( headerText ) then headerText:SetText(new and (MAINMENU_BUTTON or "Game Menu") or MAIN_MENU); end
end

function Layout()
	if ( TemucraftUI_IsClassic("menu") ) then HeaderText(false); Classic(); return; end
	laying = true;
	HeaderText(true);
	GameMenuFrame:SetBackdrop(NEW_BACKDROP);
	local inRows = {};
	local last, height = nil, 44;
	local extra, dragon = DragonRows();
	extra.classicoptions = ClassicOptions();
	if ( not extra.classicoptions ) then optionsOpen = false; end
	for _, row in ipairs(L.Rows(optionsOpen, IsMacClient(), extra)) do
		local key, gap, sub = row[1], row[2] or 2, row[3];
		local b = dragon[key] or ours[key] or _G[key];
		if ( b ) then
			inRows[b] = true;
			b:ClearAllPoints();
			if ( last ) then b:SetPoint("TOP", last, "BOTTOM", 0, -gap); else b:SetPoint("TOP", GameMenuFrame, "TOP", 0, -36); gap = 0; end
			b:SetWidth(sub and SUB_WIDTH or BUTTON_WIDTH); b:SetHeight(sub and BUTTON_HEIGHT - 4 or BUTTON_HEIGHT);
			if ( SUB_TEXT[key] ) then b:SetText(SUB_TEXT[key]); end
			b:Show();
			height = height + b:GetHeight() + gap;
			last = b;
		end
	end
	if ( extra.classicoptions ) then ours.options:SetText(optionsOpen and "Options  -" or "Options  +");
	else ours.options:SetText("Options"); end
	for _, name in ipairs(STOCK) do
		local b = _G[name];
		if ( b and not inRows[b] ) then b:Hide(); end
	end
	for _, b in pairs(ours) do if ( not inRows[b] ) then b:Hide(); end end
	GameMenuFrame:SetWidth(BUTTON_WIDTH + 44);
	GameMenuFrame:SetHeight(height + 16);
	laying = false;
end

-- next frame too: DragonUI makes its buttons in its own OnShow, after this one
GameMenuFrame:HookScript("OnShow", function() Layout(); relayout:Show(); end);
TemucraftUI_OnChange("classicmenu", function() Layout(); end);
TemucraftUI_OnChange("classicoptions", function() if ( GameMenuFrame:IsShown() ) then Layout(); end end);
