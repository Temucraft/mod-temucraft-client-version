-- Temucraft game menu (Esc), retail look: Options (opens System, Sound, Interface and Key Bindings under it), Shop,
-- What's New, AddOns, Support, Macros, then Log Out, Exit Game and Return to Game. It is the stock
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

-- the menu's rows: { name, gapBefore } in order; sub rows only when Options is open
function L.Rows(optionsOpen, mac)
	local rows = { { "options" } };
	if ( optionsOpen ) then
		for _, s in ipairs({ "GameMenuButtonOptions", "GameMenuButtonSoundOptions", "GameMenuButtonUIOptions", "GameMenuButtonKeybindings" }) do
			table.insert(rows, { s, nil, true });
		end
		if ( mac ) then table.insert(rows, { "GameMenuButtonMacOptions", nil, true }); end
	end
	-- "editmode" (its button is below) comes back here once Edit Mode exists: no dead ends in the menu
	for _, s in ipairs({ "shop", "whatsnew", "addons", "support", "GameMenuButtonMacros" }) do table.insert(rows, { s }); end
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
Ours("options", "Options", function() optionsOpen = not optionsOpen; Layout(); end);
Ours("shop", "Shop", function() HideUIPanel(GameMenuFrame); TemucraftShop_Toggle(); end);
Ours("whatsnew", "What's New", function() HideUIPanel(GameMenuFrame); news:Show(); end);
Ours("addons", ADDONS or "AddOns", function() HideUIPanel(GameMenuFrame); TemucraftAddOnList_Toggle(); end);
Ours("editmode", "Edit Mode", function() HideUIPanel(GameMenuFrame); StaticPopup_Show("TEMUCRAFT_EDIT_MODE_SOON"); end);
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
end

function Layout()
	if ( TemucraftUI_IsClassic("menu") ) then Classic(); return; end
	GameMenuFrame:SetBackdrop(NEW_BACKDROP);
	local inRows = {};
	local last, height = nil, 44;
	for _, row in ipairs(L.Rows(optionsOpen, IsMacClient())) do
		local key, gap, sub = row[1], row[2] or 2, row[3];
		local b = ours[key] or _G[key];
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
	ours.options:SetText(optionsOpen and "Options  -" or "Options  +");
	for _, name in ipairs(STOCK) do
		local b = _G[name];
		if ( b and not inRows[b] ) then b:Hide(); end
	end
	GameMenuFrame:SetWidth(BUTTON_WIDTH + 44);
	GameMenuFrame:SetHeight(height + 16);
end

GameMenuFrame:HookScript("OnShow", function() Layout(); end);
TemucraftUI_OnChange("classicmenu", function() Layout(); end);
