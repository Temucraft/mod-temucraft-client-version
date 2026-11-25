-- Temucraft micro menu (retail look): one row of buttons at the bottom right of the screen, on a dark strip:
-- Character, Spellbook & Talents (the Temucraft window), Achievements, Quest Log, Guild & Communities (right click:
-- friends), Group Finder (right click: PvP), Collections, Shop, Game Menu, Help. The stock micro buttons leave the main
-- bar (in a vehicle they come back on the vehicle bar, like stock). Every button calls what its stock button calls,
-- and takes its stock button's state (pushed while its window is open, disabled below its level), so key bindings,
-- level limits and the "pushed" looks keep working. "Classic micro menu" (Interface Options > Temucraft, /tui) puts
-- the stock buttons back. Nothing here is secure; nothing it opens is protected.
TemucraftMicroMenuLogic = {};
local L = TemucraftMicroMenuLogic;

-- key, label, stock button it mirrors, texture ("char:<icon>" = the character frame with an icon in it)
L.BUTTONS = {
	{ key = "character",    label = "Character Info",         stock = "CharacterMicroButton", binding = "TOGGLECHARACTER0" },
	{ key = "spellbook",    label = "Spellbook & Talents",    stock = "SpellbookMicroButton", texture = "Spellbook", binding = "TOGGLESPELLBOOK",
		right = "Right click: Talents" },
	{ key = "achievements", label = "Achievements",           stock = "AchievementMicroButton", texture = "Achievement", binding = "TOGGLEACHIEVEMENT" },
	{ key = "quests",       label = "Quest Log",              stock = "QuestLogMicroButton", texture = "Quest", binding = "TOGGLEQUESTLOG" },
	{ key = "guild",        label = "Guild & Communities",    stock = "SocialsMicroButton", texture = "Socials", binding = "TOGGLESOCIAL",
		right = "Right click: Friends" },
	{ key = "lfd",          label = "Group Finder",           stock = "LFDMicroButton", texture = "LFG", binding = "TOGGLELFGPARENT",
		right = "Right click: Player vs. Player" },
	{ key = "collections",  label = "Collections",            icon = "Interface\\Icons\\Ability_Mount_RidingHorse" },
	{ key = "shop",         label = "Shop",                   icon = "Interface\\Icons\\INV_Misc_Coin_02" },
	{ key = "menu",         label = "Game Menu",              stock = "MainMenuMicroButton", texture = "MainMenu", binding = "TOGGLEGAMEMENU" },
	{ key = "help",         label = "Help",                   stock = "HelpMicroButton", texture = "Help" },
};

-- x offsets from the right edge, right to left (the last button at 0)
function L.Layout(count, width, gap)
	local out = {};
	for i = 1, count do out[i] = -((count - i) * (width + gap)); end
	return out;
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

local WIDTH, GAP = 28, -2;
local STOCK = { "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "AchievementMicroButton",
	"QuestLogMicroButton", "SocialsMicroButton", "PVPMicroButton", "LFDMicroButton", "MainMenuMicroButton", "HelpMicroButton" };

local bar = CreateFrame("Frame", "TemucraftMicroMenu", UIParent);
bar:SetHeight(44);
bar:SetWidth(#L.BUTTONS * (WIDTH + GAP) + 14);
bar:SetFrameStrata("MEDIUM");
bar:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
bar:SetBackdropColor(0.05, 0.05, 0.08, 0.85);
bar:SetBackdropBorderColor(0.5, 0.45, 0.35, 0.9);
bar:Hide();

-- what each button does (the stock buttons' own calls)
local ACTIONS = {
	character = function() ToggleCharacter("PaperDollFrame"); end,
	spellbook = function(button)
		if ( button == "RightButton" ) then ToggleTalentFrame(); else ToggleSpellBook(BOOKTYPE_SPELL); end
	end,
	achievements = function() ToggleAchievementFrame(); end,
	quests = function() ToggleFrame(QuestLogFrame); end,
	guild = function(button)
		if ( button == "RightButton" ) then ToggleFriendsFrame(1); else ToggleFriendsFrame(3); end
	end,
	lfd = function(button)
		if ( button == "RightButton" ) then
			if ( PVPMicroButton:IsEnabled() == 1 ) then TogglePVPFrame(); end
		else
			ToggleLFDParentFrame();
		end
	end,
	collections = function() if ( TemucraftCollections_Toggle ) then TemucraftCollections_Toggle(); end end,
	shop = function() TemucraftShop_Toggle(); end,
	menu = function()
		if ( GameMenuFrame:IsShown() ) then
			PlaySound("igMainMenuQuit");
			HideUIPanel(GameMenuFrame);
		elseif ( VideoOptionsFrame:IsShown() ) then VideoOptionsFrameCancel:Click();
		elseif ( AudioOptionsFrame:IsShown() ) then AudioOptionsFrameCancel:Click();
		elseif ( InterfaceOptionsFrame:IsShown() ) then InterfaceOptionsFrameCancel:Click();
		else
			CloseMenus();
			CloseAllWindows();
			PlaySound("igMainMenuOpen");
			ShowUIPanel(GameMenuFrame);
		end
	end,
	help = function() ToggleHelpFrame(); end,
};

-- the shop window comes later (TemucraftShop.lua can define TemucraftShop_Show); until then, where to buy
function TemucraftShop_Toggle()
	if ( TemucraftShop_Show ) then TemucraftShop_Show(); return; end
	StaticPopup_Show("TEMUCRAFT_SHOP_SOON");
end
StaticPopupDialogs["TEMUCRAFT_SHOP_SOON"] = {
	text = "The in-game shop window is on its way.\n\nFor now, the Temucraft Curator in every capital sells everything (tokens).",
	button1 = OKAY, timeout = 0, whileDead = 1, hideOnEscape = 1,
};

local buttons = {};
local offsets = L.Layout(#L.BUTTONS, WIDTH, GAP);
for i, def in ipairs(L.BUTTONS) do
	local b = CreateFrame("Button", "TemucraftMicroButton_"..def.key, bar, "MainMenuBarMicroButton");
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	b:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", offsets[i] - 6, 3);
	b.def = def;
	if ( def.texture ) then
		local prefix = "Interface\\Buttons\\UI-MicroButton-"..def.texture;
		b:SetNormalTexture(prefix.."-Up"); b:SetPushedTexture(prefix.."-Down"); b:SetDisabledTexture(prefix.."-Disabled");
	else
		b:SetNormalTexture("Interface\\Buttons\\UI-MicroButtonCharacter-Up");
		b:SetPushedTexture("Interface\\Buttons\\UI-MicroButtonCharacter-Down");
		b.icon = b:CreateTexture(nil, "OVERLAY");
		b.icon:SetWidth(18); b.icon:SetHeight(25);
		b.icon:SetPoint("TOP", 0, -28);
		b.icon:SetTexCoord(0.2, 0.8, 0.0666, 0.9);
		if ( def.icon ) then b.icon:SetTexture(def.icon); end
	end
	b:SetHighlightTexture("Interface\\Buttons\\UI-MicroButton-Hilight");
	b:SetScript("OnClick", function(self, button) ACTIONS[def.key](button); end);
	local function Tip(self)
		self.tooltipText = def.binding and MicroButtonTooltipText(def.label, def.binding) or def.label;
		local stock = def.stock and _G[def.stock];
		self.minLevel = stock and stock.minLevel;
		self.newbieText = stock and stock.newbieText;
	end
	if ( def.key == "menu" ) then
		b:SetScript("OnEnter", function(self) Tip(self); MainMenuBarPerformanceBarFrame_OnEnter(self); end);
	else
		local enter = b:GetScript("OnEnter");   -- the template's: the tooltip and the "available at level" line
		b:SetScript("OnEnter", function(self)
			Tip(self);
			enter(self);
			if ( def.right and GameTooltip:IsOwned(self) ) then GameTooltip:AddLine(def.right, 0.7, 0.7, 0.7); GameTooltip:Show(); end
		end);
	end
	buttons[def.key] = b;
end

-- the character button shows your portrait, like the stock one
local function Portrait() SetPortraitTexture(buttons.character.icon, "player"); end

local function Pushed(b, on)
	if ( on ) then b:SetButtonState("PUSHED", 1); else b:SetButtonState("NORMAL"); end
	if ( b.icon ) then
		if ( on ) then b.icon:SetTexCoord(0.2666, 0.8666, 0, 0.8333); b.icon:SetAlpha(0.5);
		else b.icon:SetTexCoord(0.2, 0.8, 0.0666, 0.9); b.icon:SetAlpha(1); end
	end
end

local function Shown(name) local f = _G[name]; return f and f:IsShown(); end

-- copy the stock buttons' states
local function Mirror()
	if ( not bar:IsShown() ) then return; end
	for _, def in ipairs(L.BUTTONS) do
		local b, stock = buttons[def.key], def.stock and _G[def.stock];
		if ( stock ) then
			if ( stock:IsEnabled() == 1 ) then b:Enable(); else b:Disable(); end
			Pushed(b, stock:GetButtonState() == "PUSHED");
		end
	end
	Pushed(buttons.spellbook, Shown("TemucraftPlayerSpellsFrame") or Shown("SpellBookFrame") or Shown("PlayerTalentFrame"));
	Pushed(buttons.collections, Shown("TemucraftCollectionsFrame"));
	if ( LFDMicroButton:IsEnabled() ~= 1 and PVPMicroButton:IsEnabled() == 1 ) then buttons.lfd:Enable(); end
end
hooksecurefunc("UpdateMicroButtons", Mirror);
if ( TemucraftCollectionsFrame ) then
	TemucraftCollectionsFrame:HookScript("OnShow", Mirror);
	TemucraftCollectionsFrame:HookScript("OnHide", Mirror);
end

-- bottom right of the screen when there is room beside the main bar (smaller if need be), else above the main bar's
-- right end
local function Place()
	bar:ClearAllPoints();
	local free = (UIParent:GetRight() or 0) - (MainMenuBar:GetRight() or 0) - 8;
	local scale = min(1, free / bar:GetWidth());
	if ( scale >= 0.75 ) then
		bar:SetScale(scale);
		bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -4 / scale, 2 / scale);
	else
		bar:SetScale(1);
		local y = (MainMenuBar:GetTop() or 53) + ((MultiBarBottomRight and MultiBarBottomRight:IsShown()) and 42 or 0);
		bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -4, y);
	end
end

-- where the stock buttons are: the main bar, a vehicle bar or nowhere (this menu)
local vehicleSkin = nil;
local function Apply()
	-- DragonUI's micro menu has the stock buttons: leave them where and as it put them
	if ( TemucraftDragonUI_Owns and TemucraftDragonUI_Owns("micro") ) then bar:Hide(); return; end
	local useOurs = not TemucraftUI_IsClassic("micro") and not vehicleSkin;
	for _, name in ipairs(STOCK) do
		local b = _G[name];
		if ( b ) then if ( useOurs ) then b:Hide(); else b:Show(); end end
	end
	if ( useOurs ) then Place(); bar:Show(); Portrait(); Mirror(); else bar:Hide(); end
end
hooksecurefunc("UIParent_ManageFramePositions", function() if ( bar:IsShown() ) then Place(); end end);
hooksecurefunc("VehicleMenuBar_MoveMicroButtons", function(skinName) vehicleSkin = skinName; Apply(); end);
TemucraftUI_OnChange("classicmicro", Apply);

local events = CreateFrame("Frame");
events:RegisterEvent("PLAYER_ENTERING_WORLD");
events:RegisterEvent("UNIT_PORTRAIT_UPDATE");
events:RegisterEvent("UI_SCALE_CHANGED");
events:RegisterEvent("DISPLAY_SIZE_CHANGED");
events:SetScript("OnEvent", function(self, event, unit)
	if ( event == "PLAYER_ENTERING_WORLD" ) then Apply();
	elseif ( event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" ) then if ( bar:IsShown() ) then Place(); end
	elseif ( unit == "player" and bar:IsShown() ) then Portrait(); end
end);
