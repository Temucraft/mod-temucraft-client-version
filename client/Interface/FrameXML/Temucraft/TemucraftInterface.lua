-- Temucraft interface settings: the retail / classic choice of each overhauled piece (character panel, micro menu,
-- game menu) and the tooltip options, kept per account by TemucraftStore.lua (keys "ui.classic<which>", like the
-- spellbook's "ui.classicbook", and "ui.<option>"). A "Temucraft" page in Interface Options has the checkboxes; /tui
-- opens it.
--   TemucraftUI_IsClassic(which)            "char", "micro", "menu", "options", "guild", "gbank", "rep", "currency", "gossip",
--                                           "tradeskill" (the Professions window), "achievements" (and "book",
--                                           "talents" of TemucraftPlayerSpells.lua): the saved choice, or DragonUI has
--                                           that piece (TemucraftDragonUI.lua)
--   TemucraftUI_IsSavedClassic(which)       the player's own choice only
--   TemucraftUI_SetClassic(which, on)       saves it and tells the piece (TemucraftUI_OnChange)
--   TemucraftUI_GetOption(key, default)     true / false ("1" / "0" in the store)
--   TemucraftUI_SetOption(key, on)
--   TemucraftUI_OnChange(which, func)       func(classicOrOn) when the choice changes, and once the store is in
TemucraftUILogic = {};
local L = TemucraftUILogic;

-- "1" = on, "0" = off, nothing = the default
function L.Bool(text, default)
	if ( text == "1" ) then return true; elseif ( text == "0" ) then return false; end
	return default and true or false;
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

local listeners = {};
local function Notify(which, value)
	for _, func in ipairs(listeners[which] or {}) do func(value); end
end

function TemucraftUI_IsSavedClassic(which)
	return TemucraftStore_Get ~= nil and TemucraftStore_Get("A", "ui.classic"..which) == "1";
end

-- DragonUI's module for this piece is on: ours steps aside (the saved choice stays as it is)
function TemucraftUI_IsClassic(which)
	return TemucraftUI_IsSavedClassic(which) or (TemucraftDragonUI_Owns ~= nil and TemucraftDragonUI_Owns(which));
end

function TemucraftUI_SetClassic(which, on)
	if ( TemucraftPlayerSpells_SetClassic ) then TemucraftPlayerSpells_SetClassic(which, on);
	elseif ( TemucraftStore_Set ) then TemucraftStore_Set("A", "ui.classic"..which, on and "1" or ""); end
	Notify("classic"..which, on and true or false);
end

function TemucraftUI_GetOption(key, default)
	return L.Bool(TemucraftStore_Get and TemucraftStore_Get("A", "ui."..key), default);
end

function TemucraftUI_SetOption(key, on)
	if ( TemucraftStore_Set ) then TemucraftStore_Set("A", "ui."..key, on and "1" or "0"); end
	Notify(key, on and true or false);
end

-- which: "classicchar", "classicmicro", "classicmenu", "classicguild", "classicgbank", "classicrep", "classiccurrency"
-- or an option key ("tooltipids")
function TemucraftUI_OnChange(which, func)
	listeners[which] = listeners[which] or {};
	table.insert(listeners[which], func);
end

-- the Interface Options page
local panel = CreateFrame("Frame", "TemucraftInterfaceOptionsPanel", UIParent);
panel.name = "Temucraft";
panel:Hide();
local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
title:SetPoint("TOPLEFT", 16, -16);
title:SetText("Temucraft interface");
local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8);
subtitle:SetPoint("RIGHT", panel, "RIGHT", -16, 0); subtitle:SetJustifyH("LEFT");   -- wraps inside the page
subtitle:SetText("The new (retail-style) windows, or the classic 3.3.5 ones. Saved for your account.");

-- { label, get, set }
local CHECKS = {
	{ "Classic character panel", function() return TemucraftUI_IsSavedClassic("char"); end, function(on) TemucraftUI_SetClassic("char", on); end, "char" },
	{ "Classic micro menu", function() return TemucraftUI_IsSavedClassic("micro"); end, function(on) TemucraftUI_SetClassic("micro", on); end, "micro" },
	{ "Classic game menu (Esc)", function() return TemucraftUI_IsSavedClassic("menu"); end, function(on) TemucraftUI_SetClassic("menu", on); end, "menu" },
	{ "Classic options menu (the four stock windows)", function() return TemucraftUI_IsSavedClassic("options"); end, function(on) TemucraftUI_SetClassic("options", on); end, "options" },
	{ "Classic spellbook", function() return TemucraftUI_IsSavedClassic("book"); end, function(on) TemucraftUI_SetClassic("book", on); end, "book" },
	{ "Classic talent window", function() return TemucraftUI_IsSavedClassic("talents"); end, function(on) TemucraftUI_SetClassic("talents", on); end, "talents" },
	{ "Classic guild window (J)", function() return TemucraftUI_IsSavedClassic("guild"); end, function(on) TemucraftUI_SetClassic("guild", on); end, "guild" },
	{ "Classic guild bank", function() return TemucraftUI_IsSavedClassic("gbank"); end, function(on) TemucraftUI_SetClassic("gbank", on); end, "gbank" },
	{ "Classic reputation window", function() return TemucraftUI_IsSavedClassic("rep"); end, function(on) TemucraftUI_SetClassic("rep", on); end, "rep" },
	{ "Classic currency window", function() return TemucraftUI_IsSavedClassic("currency"); end, function(on) TemucraftUI_SetClassic("currency", on); end, "currency" },
	{ "Classic gossip window (small NPC option icons)", function() return TemucraftUI_IsSavedClassic("gossip"); end, function(on) TemucraftUI_SetClassic("gossip", on); end, "gossip" },
	{ "Classic professions window", function() return TemucraftUI_IsSavedClassic("tradeskill"); end, function(on) TemucraftUI_SetClassic("tradeskill", on); end, "tradeskill" },
	{ "Classic achievements window", function() return TemucraftUI_IsSavedClassic("achievements"); end, function(on) TemucraftUI_SetClassic("achievements", on); end, "achievements" },
	{ "Show recent guild chat in the chat window at login",
		function() return TemucraftUI_GetOption("guildloginchat", true); end, function(on) TemucraftUI_SetOption("guildloginchat", on); end },
	{ "Show SpellID / ItemID and icon names in tooltips",
		function() return TemucraftUI_GetOption("tooltipids", true); end, function(on) TemucraftUI_SetOption("tooltipids", on); end },
};
local checks = {};
for i, c in ipairs(CHECKS) do
	local check = CreateFrame("CheckButton", "TemucraftInterfaceOptionsCheck"..i, panel, "InterfaceOptionsCheckButtonTemplate");
	check:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -12 - (i - 1) * 28);
	_G[check:GetName().."Text"]:SetText(c[1]);
	_G[check:GetName().."Text"]:SetWidth(360); _G[check:GetName().."Text"]:SetJustifyH("LEFT");
	check:SetScript("OnClick", function(self)
		PlaySound(self:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff");
		c[3](self:GetChecked() and true or false);
	end);
	local text = _G[check:GetName().."Text"];
	text.temucraftColor = { text:GetTextColor() };
	checks[i] = check;
end
-- what DragonUI has taken over (its module is on): greyed, with a note; the saved choice is kept for when it's off
local dragonNote = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
dragonNote:SetPoint("TOPLEFT", checks[#checks], "BOTTOMLEFT", 2, -12);
dragonNote:SetPoint("RIGHT", panel, "RIGHT", -16, 0);
dragonNote:SetJustifyH("LEFT");
dragonNote:Hide();
panel:SetScript("OnShow", function()
	for i, c in ipairs(CHECKS) do
		local check, text = checks[i], _G[checks[i]:GetName().."Text"];
		check:SetChecked(c[2]());
		local note = c[4] and TemucraftDragonUI_Note and TemucraftDragonUI_Note(c[4]);
		if ( note ) then
			check:Disable();
			text:SetWidth(560);
			text:SetText(c[1].."  |cff888888- "..note.." is used (/dui to turn it off, then /reload)|r");
			text:SetTextColor(0.5, 0.5, 0.5);
		else
			check:Enable();
			text:SetWidth(360);
			text:SetText(c[1]);
			text:SetTextColor(unpack(text.temucraftColor));
		end
	end
	if ( TemucraftDragonUI_IsLoaded and TemucraftDragonUI_IsLoaded() ) then
		local more = TemucraftDragonUI_Note("addons");
		dragonNote:SetText("DragonUI is the base of the interface: where its module is on, the window above is DragonUI's."
			..(more and (" "..more.." is the AddOns list (Esc > AddOns, /addons).") or "")
			.." Ours stay: reputation and Renown, guild, guild bank, collections, flight map, Issue Reporter and the Esc menu.");
		dragonNote:Show();
	else
		dragonNote:Hide();
	end
end);
-- the boxes apply at once: OK / Cancel / Defaults have nothing to do
panel.okay = function() end;
panel.cancel = function() end;
panel.default = function() end;
if ( InterfaceOptions_AddCategory ) then InterfaceOptions_AddCategory(panel); end

function TemucraftUI_OpenOptions()
	if ( TemucraftOptions_Open and not TemucraftUI_IsClassic("options") ) then TemucraftOptions_Open(panel); return; end
	if ( InterfaceOptionsFrame_OpenToCategory ) then
		InterfaceOptionsFrame_OpenToCategory(panel);
		InterfaceOptionsFrame_OpenToCategory(panel);   -- the first call only opens the frame when it was closed
	end
end

SLASH_TEMUCRAFTUI1 = "/tui";
SlashCmdList["TEMUCRAFTUI"] = function() TemucraftUI_OpenOptions(); end;

-- once DragonUI's modules are known (login), the pieces it has step aside (and come back with it off after /reload)
if ( TemucraftDragonUI_OnChange ) then
	TemucraftDragonUI_OnChange(function()
		for which in pairs(TemucraftDragonUILogic.TAKEOVER) do
			if ( TemucraftDragonUI_Owns(which) ) then Notify("classic"..which, true); end
		end
	end);
end

-- once the server's values are in, every piece applies its choice
if ( TemucraftStore_OnReady ) then
	TemucraftStore_OnReady(function()
		for _, which in ipairs({ "char", "micro", "menu", "guild", "gbank", "rep", "currency" }) do Notify("classic"..which, TemucraftUI_IsClassic(which)); end
		Notify("tooltipids", TemucraftUI_GetOption("tooltipids", true));
	end);
end
