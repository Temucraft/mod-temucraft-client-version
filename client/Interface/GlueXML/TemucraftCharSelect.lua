--[[
	Temucraft character select, the retail way: character cards on the right (name, level, class colour, zone with its
	version bracket, faction crest), a search box over them, a top bar with Menu (Options, AddOns, Credits,
	Cinematics, Exit) and Realms, an eye button that hides the interface to show only the scene, Create / Delete
	under the cards. Enter World, Back and the rotate buttons stay the client's own.

	The client's CharacterSelect.lua (patch-<locale>-C) still runs: its character list is only moved into a hidden
	holder, and the cards call its functions (CharacterSelect_SelectCharacter, CharacterSelect_EnterWorld ...). The
	background is the client's too: each character's race scene (SetBackgroundModel in GlueParent.lua, which also
	applies the player's own picks from Interface\TemucraftScenes.lua).

	TEMUCRAFT_LOGIN_UI = "classic" (Interface\TemucraftScenes.lua) keeps the old screen.
--]]

TemucraftSelectLogic = {};
local Logic = TemucraftSelectLogic;

Logic.CLASS_COLORS = {
	WARRIOR = "c79c6e", PALADIN = "f58cba", HUNTER = "abd473", ROGUE = "fff569", PRIEST = "ffffff",
	DEATHKNIGHT = "c41f3b", SHAMAN = "0070de", MAGE = "69ccf0", WARLOCK = "9482c9", DRUID = "ff7d0a",
	MONK = "00ff96", DEMONHUNTER = "a330c9", EVOKER = "33937f",
};
Logic.ROLES = {
	tank = { WARRIOR = true, PALADIN = true, DEATHKNIGHT = true, DRUID = true, MONK = true, DEMONHUNTER = true },
	heal = { PRIEST = true, PALADIN = true, SHAMAN = true, DRUID = true, MONK = true, EVOKER = true },
	dps = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, DEATHKNIGHT = true, SHAMAN = true,
		MAGE = true, WARLOCK = true, DRUID = true, MONK = true, DEMONHUNTER = true, EVOKER = true },
};
Logic.ROLE_WORDS = { tank = "tank", tanks = "tank", heal = "heal", heals = "heal", healer = "heal", healers = "heal",
	healing = "heal", dps = "dps", damage = "dps" };

-- GetCharacterInfo gives the class's name in the client's language: the English names, and the class colours the
-- client's own CharacterSelect.lua knows in every language (GetColorByClass)
Logic.CLASS_NAMES = {
	["warrior"] = "WARRIOR", ["paladin"] = "PALADIN", ["hunter"] = "HUNTER", ["rogue"] = "ROGUE", ["priest"] = "PRIEST",
	["death knight"] = "DEATHKNIGHT", ["shaman"] = "SHAMAN", ["mage"] = "MAGE", ["warlock"] = "WARLOCK", ["druid"] = "DRUID",
	["monk"] = "MONK", ["demon hunter"] = "DEMONHUNTER", ["evoker"] = "EVOKER",
};
function Logic.ClassFile(className, colored)
	local file = Logic.CLASS_NAMES[string.lower(className or "")];
	if ( file ) then
		return file;
	end
	local hex = colored and string.match(colored, "^|c%x%x(%x%x%x%x%x%x)");
	if ( hex ) then
		hex = string.lower(hex);
		for f, c in pairs(Logic.CLASS_COLORS) do
			if ( c == hex ) then
				return f;
			end
		end
	end
	return nil;
end

-- The faction of a character: its race file from GetSelectBackgroundModel (not for death knights), else the race's
-- English name. Pandaren, Dracthyr, Earthen and Haranir play on both sides: only the race file tells.
Logic.RACE_NAMES = {
	["human"] = "Alliance", ["dwarf"] = "Alliance", ["night elf"] = "Alliance", ["gnome"] = "Alliance",
	["draenei"] = "Alliance", ["worgen"] = "Alliance", ["void elf"] = "Alliance", ["lightforged draenei"] = "Alliance",
	["dark iron dwarf"] = "Alliance", ["kul tiran"] = "Alliance", ["mechagnome"] = "Alliance", ["gilnean"] = "Alliance",
	["high elf"] = "Alliance",
	["orc"] = "Horde", ["undead"] = "Horde", ["forsaken"] = "Horde", ["tauren"] = "Horde", ["troll"] = "Horde",
	["blood elf"] = "Horde", ["goblin"] = "Horde", ["nightborne"] = "Horde", ["highmountain tauren"] = "Horde",
	["zandalari troll"] = "Horde", ["mag'har orc"] = "Horde", ["mag'har"] = "Horde", ["vulpera"] = "Horde",
};
function Logic.Faction(raceName, raceFile)
	if ( raceFile and raceFile ~= "" and string.upper(raceFile) ~= "DEATHKNIGHT" and TemucraftRaceFaction ) then
		local f = TemucraftRaceFaction(raceFile);
		if ( f ) then
			return f;
		end
	end
	return Logic.RACE_NAMES[string.lower(raceName or "")];
end

-- "Dalaran" -> "Dalaran (Northrend)": the client only gives the zone's name, so a name used more than once gets the
-- bracket of its first row (see docs/zone-brackets.md)
function Logic.ZoneText(zone)
	if ( not zone or zone == "" ) then
		return "";
	end
	local ids = TEMUCRAFT_ZONE_BRACKET_NAMES and TEMUCRAFT_ZONE_BRACKET_NAMES[zone];
	local label = ids and TEMUCRAFT_ZONE_BRACKET and TEMUCRAFT_ZONE_BRACKET[ids[1]];
	if ( label and label ~= "" ) then
		return zone.." ("..label..")";
	end
	return zone;
end

-- Every word of the query must match the character: its name, level ("70", "60-70", "70+"), class, race, faction,
-- zone (with the bracket), or a role ("tank", "heal", "dps")
function Logic.Matches(c, query)
	for word in string.gmatch(string.lower(query or ""), "%S+") do
		local ok = false;
		local lo, hi = string.match(word, "^(%d+)%-(%d+)$");
		local plus = string.match(word, "^(%d+)%+$");
		local role = Logic.ROLE_WORDS[word];
		if ( lo ) then
			ok = (c.level or 0) >= tonumber(lo) and (c.level or 0) <= tonumber(hi);
		elseif ( plus ) then
			ok = (c.level or 0) >= tonumber(plus);
		elseif ( string.match(word, "^%d+$") ) then
			ok = (c.level == tonumber(word));
		end
		if ( not ok and role and c.classFile ) then
			ok = Logic.ROLES[role][c.classFile] and true or false;
		end
		if ( not ok ) then
			for _, field in ipairs({ c.name, c.class, c.race, c.faction, c.zone, c.classFile }) do
				if ( field and string.find(string.lower(field), word, 1, true) ) then
					ok = true;
					break;
				end
			end
		end
		if ( not ok ) then
			return false;
		end
	end
	return true;
end

function Logic.Filter(list, query)
	local out = {};
	for _, c in ipairs(list) do
		if ( Logic.Matches(c, query) ) then
			table.insert(out, c);
		end
	end
	return out;
end

---------------------------------------------------------------------------------------------------------------------
-- The screen (only in the client)
---------------------------------------------------------------------------------------------------------------------
if ( not CharacterSelect or not CreateFrame ) then
	return;
end

local CARD_HEIGHT, CARD_WIDTH, VISIBLE = 58, 270, 9;
local root, holder, cards, eye, menu = nil, nil, {}, nil, nil;
local list, shown, offset, lastQuery = {}, {}, 0, nil;
local hiddenByEye;
local returnToSelect = false;
local throttle = 0;

local function Active()
	return TEMUCRAFT_LOGIN_UI ~= "classic";
end
TemucraftCharSelect_Active = Active;

local function Tooltip(owner, text)
	if ( text and GlueTooltip_SetOwner ) then
		GlueTooltip_SetOwner(owner);
		GlueTooltip_SetText(text);
	end
end
local function HideTooltip()
	if ( GlueTooltip ) then GlueTooltip:Hide(); end
end

local function Panel(parent)
	local f = CreateFrame("Frame", nil, parent);
	f:SetBackdrop({ bgFile = "Interface\\Glues\\Common\\Glue-Tooltip-Background", edgeFile = "Interface\\Glues\\Common\\Glue-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16, insets = { left = 10, right = 5, top = 4, bottom = 9 } });
	f:SetBackdropColor(0, 0, 0, 0.75);
	return f;
end

local function SmallButton(name, parent, text, width, onClick)
	local b = CreateFrame("Button", name, parent, "GlueButtonSmallTemplate");
	b:SetWidth(width); b:SetHeight(28);
	b:SetText(text);
	b:SetScript("OnClick", onClick);
	return b;
end

local function ReadCharacters()
	list = {};
	for id = 1, GetNumCharacters() do
		local name, race, class, level, zone, sex, ghost, PCC, PRC, PFC = GetCharacterInfo(id);
		if ( name ) then
			local colored = GetColorByClass and GetColorByClass(class) or class;
			local classFile = Logic.ClassFile(class, colored);
			local bgFile = GetSelectBackgroundModel and GetSelectBackgroundModel(id);
			table.insert(list, {
				id = id, name = name, race = race, class = class, level = level or 0, ghost = ghost,
				zone = Logic.ZoneText(zone), classFile = classFile, faction = Logic.Faction(race, bgFile),
				paid = (PFC and PAID_FACTION_CHANGE) or (PRC and PAID_RACE_CHANGE) or (PCC and PAID_CHARACTER_CUSTOMIZATION) or nil,
			});
		end
	end
end

local Refresh;

local function Clamp()
	offset = math.max(0, math.min(offset, #shown - VISIBLE));
end

local function ShowSelected()
	local sel = CharacterSelect.selectedIndex or 0;
	for i, c in ipairs(shown) do
		if ( c.id == sel ) then
			if ( i <= offset ) then offset = i - 1; elseif ( i > offset + VISIBLE ) then offset = i - VISIBLE; end
		end
	end
	Clamp();
end

local function MakeCard(n)
	local b = CreateFrame("Button", "TemucraftSelectCard"..n, root.list);
	b:SetWidth(CARD_WIDTH); b:SetHeight(CARD_HEIGHT - 4);
	b:SetBackdrop({ bgFile = "Interface\\Glues\\Common\\Glue-Tooltip-Background", edgeFile = "Interface\\Glues\\Common\\Glue-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	b:SetBackdropColor(0.05, 0.05, 0.1, 0.85);
	b:RegisterForClicks("LeftButtonUp");
	b.name = b:CreateFontString(nil, "OVERLAY", "GlueFontNormal");
	b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 12, -7);
	b.info = b:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall");
	b.info:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -2);
	b.zone = b:CreateFontString(nil, "OVERLAY", "GlueFontDisableSmall");
	b.zone:SetPoint("TOPLEFT", b.info, "BOTTOMLEFT", 0, -2);
	b.zone:SetWidth(CARD_WIDTH - 60); b.zone:SetJustifyH("LEFT");
	b.crest = b:CreateTexture(nil, "ARTWORK");
	b.crest:SetWidth(36); b.crest:SetHeight(36);
	b.crest:SetPoint("RIGHT", b, "RIGHT", -6, 0);
	b.selected = b:CreateTexture(nil, "BACKGROUND");
	b.selected:SetTexture("Interface\\Glues\\CharacterSelect\\Glue-CharacterSelect-Highlight");
	b.selected:SetBlendMode("ADD");
	b.selected:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3);
	b.selected:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3);
	b.selected:Hide();
	local hl = b:CreateTexture(nil, "HIGHLIGHT");
	hl:SetTexture("Interface\\Glues\\CharacterSelect\\Glue-CharacterSelect-Highlight");
	hl:SetBlendMode("ADD");
	hl:SetAlpha(0.5);
	hl:SetAllPoints(b.selected);
	b:SetScript("OnClick", function(self)
		if ( self.id and self.id ~= CharacterSelect.selectedIndex ) then
			if ( CharacterSelectUI ) then CharacterSelectUI.id = self.id; end
			CharacterSelect_SelectCharacter(self.id);
		end
		Refresh();
	end);
	b:SetScript("OnDoubleClick", function(self)
		if ( self.id and self.id ~= CharacterSelect.selectedIndex ) then
			CharacterSelect_SelectCharacter(self.id);
		end
		CharacterSelect_EnterWorld();
	end);
	-- paid customization / race / faction change
	b.paid = CreateFrame("Button", nil, b);
	b.paid:SetWidth(28); b.paid:SetHeight(28);
	b.paid:SetPoint("RIGHT", b, "LEFT", 2, 0);
	b.paid:SetNormalTexture("Interface\\Buttons\\UI-PaidCharacterCustomization-Button");
	b.paid:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
	b.paid:SetScript("OnClick", function(self)
		local card = self:GetParent();
		self:SetID(card.id);
		CharacterSelect_PaidServiceOnClick(self, "LeftButton", false, card.service);
	end);
	b.paid:SetScript("OnEnter", function(self)
		local s = self:GetParent().service;
		Tooltip(self, (s == PAID_FACTION_CHANGE and (PAID_FACTION_CHANGE_TOOLTIP or "Faction Change"))
			or (s == PAID_RACE_CHANGE and (PAID_RACE_CHANGE_TOOLTIP or "Race Change"))
			or (PAID_CHARACTER_CUSTOMIZE_TOOLTIP or "Character Customization"));
	end);
	b.paid:SetScript("OnLeave", HideTooltip);
	b:EnableMouseWheel(true);
	b:SetScript("OnMouseWheel", function(_, delta) offset = offset - delta; Clamp(); Refresh(true); end);
	return b;
end

function Refresh(keepOffset)
	if ( not root or not root:IsShown() ) then
		return;
	end
	local query = root.search:GetText() or "";
	shown = Logic.Filter(list, query);
	if ( query ~= lastQuery ) then
		offset = 0;
		lastQuery = query;
	end
	if ( not keepOffset ) then
		ShowSelected();
	end
	Clamp();
	local sel = CharacterSelect.selectedIndex or 0;
	for n = 1, VISIBLE do
		local b = cards[n];
		local c = shown[offset + n];
		if ( c ) then
			b.id, b.service = c.id, c.paid;
			b.name:SetText(c.name);
			local color = c.classFile and Logic.CLASS_COLORS[c.classFile];
			local class = color and ("|cff"..color..(c.class or "").."|r") or (c.class or "");
			local fmt = c.ghost and CHARACTER_SELECT_INFO_GHOST or CHARACTER_SELECT_INFO;
			if ( fmt ) then
				b.info:SetText(format(fmt, c.level, class));
			else
				b.info:SetText("Level "..c.level.." "..class);
			end
			b.zone:SetText(c.zone);
			if ( c.faction == "Alliance" or c.faction == "Horde" ) then
				b.crest:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..c.faction);
				b.crest:SetTexCoord(0, 0.625, 0, 0.625);
				b.crest:Show();
			else
				b.crest:Hide();
			end
			if ( c.paid ) then b.paid:Show(); else b.paid:Hide(); end
			if ( c.id == sel ) then b.selected:Show(); else b.selected:Hide(); end
			b:Show();
		else
			b:Hide();
		end
	end
	if ( #shown == 0 and #list > 0 ) then
		root.empty:SetText("No character matches");
	elseif ( #list == 0 ) then
		root.empty:SetText(IsConnectedToServer() and "No characters yet" or "");
	else
		root.empty:SetText("");
	end
	root.count:SetText((#shown ~= #list) and (#shown.." / "..#list) or "");
	local connected = IsConnectedToServer();
	if ( connected and CharacterSelect.createIndex and CharacterSelect.createIndex > 0 ) then root.create:Enable(); else root.create:Disable(); end
	if ( (CharacterSelect.selectedIndex or 0) > 0 and #list > 0 ) then root.delete:Enable(); else root.delete:Disable(); end
	if ( root.realm ) then
		root.realm:SetText(GetServerName and GetServerName() or "");
	end
end
TemucraftCharSelect_Refresh = Refresh;

---------------------------------------------------------------------------------------------------------------------
-- Eye: only the scene
---------------------------------------------------------------------------------------------------------------------
local function ToggleEye()
	if ( hiddenByEye ) then
		for _, f in ipairs(hiddenByEye) do f:Show(); end
		hiddenByEye = nil;
		eye.icon:SetDesaturated(nil);
		return;
	end
	hiddenByEye = {};
	local parent = CharacterSelectUI or CharacterSelect;
	for _, f in ipairs({ parent:GetChildren() }) do
		if ( f:IsShown() ) then table.insert(hiddenByEye, f); f:Hide(); end
	end
	for _, r in ipairs({ parent:GetRegions() }) do
		if ( r:IsShown() ) then table.insert(hiddenByEye, r); r:Hide(); end
	end
	if ( menu ) then menu:Hide(); end
	eye.icon:SetDesaturated(1);
end

---------------------------------------------------------------------------------------------------------------------
-- Menu
---------------------------------------------------------------------------------------------------------------------
local MENU = {
	{ text = "Options", func = function()
		PlaySound("gsTitleOptions");
		if ( OptionsSelectFrame ) then OptionsSelectFrame:Show(); elseif ( VideoOptionsFrame ) then VideoOptionsFrame:Show(); end
	end },
	{ text = "AddOns", func = function() if ( AddonList ) then AddonList:Show(); end end },
	{ text = "Credits", func = function()
		returnToSelect = true;
		if ( CreditsFrame ) then CreditsFrame.creditsType = 3; end
		PlaySound("gsTitleCredits");
		SetGlueScreen("credits");
	end },
	{ text = "Cinematics", func = function()
		returnToSelect = true;
		if ( AccountLogin_Cinematics ) then AccountLogin_Cinematics(); end
	end },
	{ text = "Exit", func = function()
		PlaySound("gsTitleQuit");
		QuitGame();
	end },
};

local function BuildMenu()
	menu = Panel(root);
	menu:SetWidth(170); menu:SetHeight(#MENU * 30 + 22);
	menu:SetPoint("TOPLEFT", root.menuButton, "BOTTOMLEFT", 0, -2);
	menu:SetFrameStrata("DIALOG");
	menu:EnableMouse(true);
	for i, item in ipairs(MENU) do
		local b = SmallButton("TemucraftSelectMenu"..i, menu, item.text, 140, function()
			menu:Hide();
			item.func();
		end);
		b:SetPoint("TOP", menu, "TOP", 0, -12 - (i - 1) * 30);
	end
	menu:Hide();
end

---------------------------------------------------------------------------------------------------------------------
-- Building the screen
---------------------------------------------------------------------------------------------------------------------
local function Build()
	local parent = CharacterSelectUI or CharacterSelect;
	root = CreateFrame("Frame", "TemucraftCharSelectFrame", parent);
	root:SetAllPoints(CharacterSelect);
	root:SetFrameLevel(parent:GetFrameLevel() + 5);
	holder = CreateFrame("Frame", nil, CharacterSelect);
	holder:Hide();

	-- top bar
	root.top = Panel(root);
	root.top:SetHeight(44);
	root.top:SetPoint("TOPLEFT", root, "TOPLEFT", 10, -6);
	root.top:SetPoint("TOPRIGHT", root, "TOPRIGHT", -10, -6);
	root.menuButton = SmallButton("TemucraftSelectMenuButton", root.top, "Menu", 110, function()
		if ( menu:IsShown() ) then menu:Hide(); else menu:Show(); end
	end);
	root.menuButton:SetPoint("LEFT", root.top, "LEFT", 14, -1);
	root.realms = SmallButton("TemucraftSelectRealms", root.top, "Realms", 110, function()
		if ( menu ) then menu:Hide(); end
		CharacterSelect_ChangeRealm();
	end);
	root.realms:SetPoint("LEFT", root.menuButton, "RIGHT", 6, 0);
	root.realm = root.top:CreateFontString(nil, "OVERLAY", "GlueFontNormal");
	root.realm:SetPoint("CENTER", root.top, "CENTER", 0, 0);
	BuildMenu();

	-- the cards
	root.list = Panel(root);
	root.list:SetWidth(CARD_WIDTH + 30);
	root.list:SetHeight(VISIBLE * CARD_HEIGHT + 120);
	root.list:SetPoint("TOPRIGHT", root, "TOPRIGHT", -12, -58);
	root.list:EnableMouseWheel(true);
	root.list:SetScript("OnMouseWheel", function(_, delta) offset = offset - delta; Clamp(); Refresh(true); end);
	root.search = CreateFrame("EditBox", "TemucraftSelectSearch", root.list);
	root.search:SetWidth(CARD_WIDTH - 10); root.search:SetHeight(26);
	root.search:SetPoint("TOP", root.list, "TOP", 0, -14);
	root.search:SetFontObject(GlueFontHighlightSmall);
	root.search:SetAutoFocus(false);
	root.search:SetTextInsets(8, 8, 0, 0);
	root.search:SetBackdrop({ bgFile = "Interface\\Glues\\Common\\Glue-Tooltip-Background", edgeFile = "Interface\\Glues\\Common\\Glue-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	root.search:SetBackdropColor(0, 0, 0, 0.9);
	root.search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); end);
	root.search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); end);
	root.search:SetScript("OnTextChanged", function() Refresh(); end);
	root.searchHint = root.search:CreateFontString(nil, "OVERLAY", "GlueFontDisableSmall");
	root.searchHint:SetPoint("LEFT", root.search, "LEFT", 9, 0);
	root.searchHint:SetText("Search: name, level, class, race, zone, tank / heal / dps");
	root.search:SetScript("OnEditFocusGained", function() root.searchHint:Hide(); end);
	root.search:SetScript("OnEditFocusLost", function(self) if ( (self:GetText() or "") == "" ) then root.searchHint:Show(); end end);
	root.count = root.list:CreateFontString(nil, "OVERLAY", "GlueFontDisableSmall");
	root.count:SetPoint("TOPRIGHT", root.search, "BOTTOMRIGHT", -4, -2);
	for n = 1, VISIBLE do
		local b = MakeCard(n);
		b:SetPoint("TOP", root.list, "TOP", 0, -52 - (n - 1) * CARD_HEIGHT);
		cards[n] = b;
	end
	root.empty = root.list:CreateFontString(nil, "OVERLAY", "GlueFontDisableSmall");
	root.empty:SetPoint("TOP", root.list, "TOP", 0, -70);
	root.create = SmallButton("TemucraftSelectCreate", root.list, CREATE_NEW_CHARACTER or "Create New Character", 180, function()
		if ( CharacterSelect.createIndex and CharacterSelect.createIndex > 0 ) then
			CharacterSelect_SelectCharacter(CharacterSelect.createIndex);
		end
	end);
	root.create:SetPoint("BOTTOMLEFT", root.list, "BOTTOMLEFT", 14, 16);
	root.delete = SmallButton("TemucraftSelectDelete", root.list, DELETE or "Delete", 90, function()
		CharacterSelect_Delete();
	end);
	root.delete:SetPoint("LEFT", root.create, "RIGHT", 4, 0);

	-- the eye stays when everything else hides
	eye = CreateFrame("Button", "TemucraftSelectEye", CharacterSelect);
	eye:SetWidth(34); eye:SetHeight(34);
	eye:SetPoint("BOTTOMLEFT", CharacterSelect, "BOTTOMLEFT", 196, 26);
	eye:SetFrameLevel((CharacterSelectUI or CharacterSelect):GetFrameLevel() + 20);
	eye.icon = eye:CreateTexture(nil, "ARTWORK");
	eye.icon:SetTexture("Interface\\Icons\\Ability_EyeOfTheOwl");
	eye.icon:SetAllPoints(eye);
	eye:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
	eye:SetScript("OnClick", ToggleEye);
	eye:SetScript("OnEnter", function(self) Tooltip(self, hiddenByEye and "Show the interface" or "Hide the interface"); end);
	eye:SetScript("OnLeave", HideTooltip);

	root:SetScript("OnUpdate", function(_, elapsed)
		throttle = throttle + (elapsed or 0);
		if ( throttle > 0.3 ) then
			throttle = 0;
			Refresh(true);
		end
	end);
end

local function HideStock()
	for _, f in ipairs({ CharacterSelectCharacterFrame, CharacterSelectDeleteButton, CharacterSelectAddonsButton }) do
		if ( f ) then f:SetParent(holder); end
	end
end

local function OnShow()
	if ( not Active() ) then
		if ( root ) then root:Hide(); end
		if ( eye ) then eye:Hide(); end
		return;
	end
	returnToSelect = false;
	if ( not root ) then
		Build();
	end
	HideStock();
	if ( hiddenByEye ) then ToggleEye(); end
	root:Show();
	eye:Show();
	ReadCharacters();
	Refresh();
end

if ( CharacterSelect.HookScript ) then
	CharacterSelect:HookScript("OnShow", OnShow);
else
	local old = CharacterSelect:GetScript("OnShow");
	CharacterSelect:SetScript("OnShow", function(...) if ( old ) then old(...); end OnShow(); end);
end

-- New list from the server (after create, delete, rename ...), new selection: read them again
for _, name in ipairs({ "UpdateCharacterList", "UpdateCharacterSelection" }) do
	local old = _G[name];
	if ( old ) then
		_G[name] = function(...)
			local r = old(...);
			if ( root and root:IsShown() ) then
				if ( name == "UpdateCharacterList" ) then ReadCharacters(); end
				Refresh();
			end
			return r;
		end
	end
end

-- Credits and cinematics end on the login screen; opened from character select they come back to it
local oldSetGlueScreen = SetGlueScreen;
SetGlueScreen = function(name, ...)
	if ( returnToSelect and name == "login" ) then
		returnToSelect = false;
		if ( IsConnectedToServer() ) then
			name = "charselect";
		end
	elseif ( name ~= "credits" and name ~= "movie" ) then
		returnToSelect = false;
	end
	return oldSetGlueScreen(name, ...);
end
local oldExit = CharacterSelect_Exit;
if ( oldExit ) then
	CharacterSelect_Exit = function(...)
		returnToSelect = false;
		return oldExit(...);
	end
end
