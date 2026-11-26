--[[
	Temucraft character creation, the retail way (Ryan's call: that and nothing more).

	Step 1 (race and class): Alliance races in two columns on the left, Horde on the right, the classes in a row along
	the bottom (the ones the race can't be greyed out), male / female at the top. Step 2 (Customize): the name at the
	top with a random name dice and a check mark, the appearance options with arrows and "Face 3 / 9" counters,
	Randomize Appearance, rotate left / right. Back / Next / Finish at the bottom corners.

	It sits on top of the client's own character create (CharacterCreate.lua / .xml from patch-A, patch-~ and the
	locale patch-<locale>-C): that code still runs and still does the work (SetCharacterRace, SetCharacterGender,
	CharacterCreate_Forward ...), its frames are only moved into a hidden holder. So it works with the 30-race
	CharacterCreate.lua (patch-~-races-30) and with the older 20-race one alike.

	3.3.5 can't tell Lua which appearance choice is shown, only cycle them (CycleCharCustomization). The counters count
	the clicks and wrap around at the totals in TemucraftGlueData.lua (generated from the DBCs). The client rolls a
	random look the first time a race and sex is shown: that look is "1". Randomize Appearance clicks a random number of
	times per option, so the counters stay right.

	Settings (Interface\TemucraftScenes.lua, written by the launcher; defaults below):
	  TEMUCRAFT_LOGIN_UI = "classic"        the character screens as they were before (this file does nothing)
	  TEMUCRAFT_CREATE_SCENES = "race"      character create shows each race's own scene instead of its faction's
	  TEMUCRAFT_SCENE_PICKS[race or class]  the player's own scene for that race (or class) wins, as on select
--]]

TemucraftCreateLogic = {};
local Logic = TemucraftCreateLogic;

-- Column of each race: 1 = the faction's original races (outer column), 2 = the allied races (inner column)
Logic.COLUMNS = {
	{ "HUMAN", "DWARF", "NIGHTELF", "GNOME", "DRAENEI", "WORGEN", "ALLIANCEPANDAREN", "ALLIANCEDRACTHYR" },
	{ "VOIDELF", "LIGHTFORGEDDRAENEI", "DARKIRONDWARF", "KULTIRAN", "MECHAGNOME", "ALLIANCEEARTHEN", "ALLIANCEHARANIR" },
	{ "ORC", "SCOURGE", "TAUREN", "TROLL", "BLOODELF", "GOBLIN", "HORDEPANDAREN", "HORDEDRACTHYR" },
	{ "NIGHTBORNE", "HIGHMOUNTAINTAUREN", "MAGHAR", "ZANDALARITROLL", "VULPERA", "HORDEEARTHEN", "HORDEHARANIR" },
};
Logic.MAX_ROWS = 8;

-- races: { { index, name, file, enabled, faction }, ... } -> { [index] = { side = "Alliance"|"Horde", column = 1|2, row } }
function Logic.Layout(races)
	local slot, placed, rows = {}, {}, { {}, {}, {}, {} };
	for col, list in ipairs(Logic.COLUMNS) do
		for row, file in ipairs(list) do
			slot[file] = { col, row };
		end
	end
	local function put(race, col, row)
		rows[col][row] = race.index;
		placed[race.index] = { side = (col <= 2) and "Alliance" or "Horde", column = (col - 1) % 2 + 1, row = row };
	end
	local rest = {};
	for _, race in ipairs(races) do
		local s = slot[string.upper(race.file or "")];
		local col = s and s[1];
		-- a race in the other faction's list (or unknown) goes to its own faction's allied column
		if ( col and race.faction and ((col <= 2) ~= (race.faction == "Alliance")) ) then
			col = nil;
		end
		if ( col and not rows[col][s[2]] ) then
			put(race, col, s[2]);
		else
			table.insert(rest, race);
		end
	end
	for _, race in ipairs(rest) do
		local cols = (race.faction == "Horde") and { 4, 3 } or { 2, 1, 4, 3 };
		local done = false;
		for _, col in ipairs(cols) do
			for row = 1, Logic.MAX_ROWS do
				if ( not done and not rows[col][row] ) then
					put(race, col, row);
					done = true;
				end
			end
		end
	end
	return placed;
end

-- How many choices each option cycles through: { skin, face, hair style, hair colour, facial } (nil = unknown)
function Logic.Totals(file, male, deathKnight, hd)
	local key = string.upper(file or "").."_"..(male and "MALE" or "FEMALE");
	local row = (hd and TEMUCRAFT_CUSTOMIZE_COUNTS_HD and TEMUCRAFT_CUSTOMIZE_COUNTS_HD[key])
		or (TEMUCRAFT_CUSTOMIZE_COUNTS and TEMUCRAFT_CUSTOMIZE_COUNTS[key]);
	if ( not row ) then
		return {};
	end
	if ( deathKnight ) then
		return { row[6] or row[1], row[7] or row[2], row[3], row[8] or row[4], row[5] };
	end
	return { row[1], row[2], row[3], row[4], row[5] };
end

-- One step of a counter that wraps around: Step(9, 9, 1) = 1
function Logic.Step(pos, total, delta)
	if ( not total or total < 1 ) then
		return pos;
	end
	return ((pos or 1) - 1 + delta) % total + 1;
end

-- Randomize as counted clicks: { [option] = clicks (negative = left) }, the shorter way round
function Logic.RandomClicks(totals, random)
	local clicks = {};
	for id = 1, 5 do
		local total = totals[id];
		if ( total and total > 1 ) then
			local k = random(0, total - 1);
			if ( k > total / 2 ) then
				k = k - total;
			end
			clicks[id] = k;
		end
	end
	return clicks;
end

-- The name check mark: "ok", or why not ("empty", "short", "long", "letters"). Letters only (UTF-8 letters count as
-- letters), at least MIN_CHAR_NAME_LENGTH, at most 47 bytes (the server's limit, see NameLength_CharacterCreate.lua).
Logic.MAX_NAME_BYTES = 47;
function Logic.NameStatus(text)
	text = text or "";
	if ( text == "" ) then
		return "empty";
	end
	if ( string.find(text, "[%z\1-\64\91-\96\123-\127]") ) then
		return "letters";
	end
	local letters = 0;
	for i = 1, string.len(text) do
		local b = string.byte(text, i);
		if ( b < 128 or b >= 192 ) then
			letters = letters + 1;
		end
	end
	if ( letters < (MIN_CHAR_NAME_LENGTH or 2) ) then
		return "short";
	end
	if ( string.len(text) > Logic.MAX_NAME_BYTES ) then
		return "long";
	end
	return "ok";
end

-- Breaks long text into lines of about `width` characters (the glue tooltip doesn't wrap: one long line would run
-- across the whole screen). Keeps |n breaks and colour codes.
function Logic.Wrap(text, width)
	width = width or 52;
	local out = {};
	local src = string.gsub(text or "", "|n", "\n");
	for para in string.gmatch(src.."\n", "(.-)\n") do
		local line, len = "", 0;
		for word in string.gmatch(para, "%S+") do
			local visible = string.len((string.gsub(string.gsub(word, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")));
			if ( len > 0 and len + 1 + visible > width ) then
				table.insert(out, line);
				line, len = word, visible;
			else
				line = (len > 0) and (line.." "..word) or word;
				len = len + ((len > 0) and 1 or 0) + visible;
			end
		end
		table.insert(out, line);
	end
	return table.concat(out, "\n");
end

-- Faction and class colours for the "Race - Class" line (the glue screens have no RAID_CLASS_COLORS)
Logic.FACTION_COLORS = { Alliance = "ff4a9cff", Horde = "ffe8352a" };
Logic.CLASS_COLORS = {
	WARRIOR = "ffc79c6e", PALADIN = "fff58cba", HUNTER = "ffabd473", ROGUE = "fffff569", PRIEST = "ffffffff",
	DEATHKNIGHT = "ffc41f3b", SHAMAN = "ff0070de", MAGE = "ff69ccf0", WARLOCK = "ff9482c9", MONK = "ff00ff96",
	DRUID = "ffff7d0a", DEMONHUNTER = "ffa330c9", EVOKER = "ff33937f",
};
-- "|cff4a9cffHighmountain Tauren|r  -  |cfff58cbaPaladin|r"
function Logic.Title(race, faction, className, classFile)
	local parts = {};
	if ( race and race ~= "" ) then
		local c = Logic.FACTION_COLORS[faction or ""];
		table.insert(parts, c and ("|c"..c..race.."|r") or race);
	end
	if ( className and className ~= "" ) then
		local c = Logic.CLASS_COLORS[string.upper(classFile or "")];
		table.insert(parts, c and ("|c"..c..className.."|r") or className);
	end
	return table.concat(parts, "  -  ");
end

---------------------------------------------------------------------------------------------------------------------
-- The screen (only in the client)
---------------------------------------------------------------------------------------------------------------------
if ( not CharacterCreate or not CreateFrame ) then
	return;
end

local NAME_HINTS = {
	short = "Too short", long = "Too long", letters = "Letters only",
};
local OPTION_LABELS = { "Skin Color", "Face", "Hair Style", "Hair Color", "Facial Hair" };
local ICON_SIZE, ICON_STEP = 46, 54;
local SIDE_MARGIN, TOP_MARGIN = 40, -96;

local root, holder, raceButtons, classButtons, optionRows = nil, nil, {}, {}, {};
local positions = {};      -- ["NIGHTELF_FEMALE"] = { 1, 1, 1, 1, 1 }: the counters of each race and sex
local lastDeathKnight;     -- the counters' skin / face reset when death knight is picked or dropped (other skins)
local throttle = 0;

local function Active()
	return TEMUCRAFT_LOGIN_UI ~= "classic";
end
TemucraftCharCreate_Active = Active;

-- side: "right" puts the tooltip to the right of the button (Alliance column), "left" to its left (Horde column)
local function Tooltip(owner, text, side)
	if ( text and GlueTooltip_SetOwner and CharacterCreateTooltip ) then
		GlueTooltip_SetOwner(owner, CharacterCreateTooltip, -3, -5);
		-- one line at a time: the glue tooltip sizes itself by its longest line, and a text with line breaks in one
		-- piece came out as a huge empty box
		local lines = {};
		for line in string.gmatch(Logic.Wrap(text).."\n", "(.-)\n") do table.insert(lines, line); end
		if ( GlueTooltip_AddLine and #lines > 1 ) then
			GlueTooltip_SetText(lines[1], CharacterCreateTooltip);
			for i = 2, #lines do
				GlueTooltip_AddLine(lines[i], CharacterCreateTooltip, 1, 1, 1);
			end
		else
			GlueTooltip_SetText(Logic.Wrap(text), CharacterCreateTooltip);
		end
		if ( side ) then
			CharacterCreateTooltip:ClearAllPoints();
			if ( side == "top" ) then
				CharacterCreateTooltip:SetPoint("BOTTOM", owner, "TOP", 0, 12);
			elseif ( side == "left" ) then
				CharacterCreateTooltip:SetPoint("TOPRIGHT", owner, "TOPLEFT", -10, 4);
			else
				CharacterCreateTooltip:SetPoint("TOPLEFT", owner, "TOPRIGHT", 10, 4);
			end
		end
	end
end
local function HideTooltip()
	if ( CharacterCreateTooltip ) then
		CharacterCreateTooltip:Hide();
	end
end

-- The stock functions only ask a button whether it's enabled and tell it to check itself
local proxy = { IsEnabled = function() return 1; end, SetChecked = function() end };

-- The faction crests (the PvP badges the character list uses too): the badge fills the top left of its 64x64 file
local FACTION_CREST_FILE = { Alliance = "Interface\\TargetingFrame\\UI-PVP-Alliance", Horde = "Interface\\TargetingFrame\\UI-PVP-Horde" };
local FACTION_CREST = { Alliance = { 0, 0.66, 0, 0.66 }, Horde = { 0, 0.66, 0, 0.66 } };

local function SelectedFaction()
	local index = GetSelectedRace();
	if ( not index ) then
		return nil;
	end
	local _, faction = GetFactionForRace(index);
	if ( faction == "Alliance" or faction == "Horde" ) then
		return faction;
	end
	local _, file = GetNameForRace();
	return TemucraftRaceFaction and TemucraftRaceFaction(file) or nil;
end

local function SelectedFile()
	local _, file = GetNameForRace();
	return string.upper(file or "");
end
local function IsMale()
	return GetSelectedSex() == SEX_MALE;
end
local function IsDeathKnight()
	local _, classFile = GetSelectedClass();
	return classFile == "DEATHKNIGHT";
end
local function IsHD()
	if ( type(TEMUCRAFT_HD_RACES) == "table" ) then
		return TEMUCRAFT_HD_RACES[SelectedFile()] and true or false;
	end
	return TEMUCRAFT_CHARACTER_SCENES == "new";
end
local function CounterKey()
	return SelectedFile().."_"..(IsMale() and "MALE" or "FEMALE");
end
local function Counters()
	local key = CounterKey();
	positions[key] = positions[key] or { 1, 1, 1, 1, 1 };
	return positions[key];
end

local function MakeIconButton(name, parent, size)
	local b = CreateFrame("CheckButton", name, parent);
	b:SetWidth(size); b:SetHeight(size);
	b.icon = b:CreateTexture(nil, "ARTWORK");
	b.icon:SetAllPoints(b);
	b.ring = b:CreateTexture(nil, "OVERLAY");
	b.ring:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreatePatchwerk");
	b.ring:SetTexCoord(0.79296875, 0.953125, 0.00097656, 0.08105469);
	b.ring:SetBlendMode("ADD");
	b.ring:SetWidth(size + 14); b.ring:SetHeight(size + 14);
	b.ring:SetPoint("CENTER", b, "CENTER", 1, -1);
	b.ring:Hide();
	local hl = b:CreateTexture(nil, "HIGHLIGHT");
	hl:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreatePatchwerk");
	hl:SetTexCoord(0.79296875, 0.953125, 0.08300781, 0.16308594);
	hl:SetBlendMode("ADD");
	hl:SetWidth(size + 14); hl:SetHeight(size + 14);
	hl:SetPoint("CENTER", b, "CENTER", 1, -1);
	b:SetScript("OnEnter", function(self) Tooltip(self, self.tooltip, self.tooltipSide); end);
	b:SetScript("OnLeave", HideTooltip);
	return b;
end

-- A round frame around a race icon (the race art has none)
local function AddRing(b, size)
	b.border = b:CreateTexture(nil, "OVERLAY");
	-- the stock round minimap-button border: the ring fills about the top left 58% of its 64x64 file
	b.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder");
	b.border:SetTexCoord(0, 0.58, 0, 0.58);
	b.border:SetWidth(size * 1.36); b.border:SetHeight(size * 1.36);
	b.border:SetPoint("CENTER", b, "CENTER", 1, -1);
end


local function SetIconState(b, selected, enabled)
	if ( selected ) then b.ring:Show(); else b.ring:Hide(); end
	b.icon:SetDesaturated(not enabled);
	b.icon:SetAlpha(enabled and 1 or 0.45);
	b.enabled = enabled;
end

local function Panel(parent)
	local f = CreateFrame("Frame", nil, parent);
	f:SetBackdrop({ bgFile = "Interface\\Glues\\Common\\Glue-Tooltip-Background", edgeFile = "Interface\\Glues\\Common\\Glue-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16, insets = { left = 10, right = 5, top = 4, bottom = 9 } });
	f:SetBackdropColor(0, 0, 0, 0.75);
	return f;
end

local function NavButton(name, parent, text, onClick)
	local b = CreateFrame("Button", name, parent, "GlueButtonTemplate");
	b:SetWidth(160); b:SetHeight(36);
	b:SetText(text);
	b:SetScript("OnClick", onClick);
	return b;
end

---------------------------------------------------------------------------------------------------------------------
-- Refresh: our widgets show what the stock code has selected (it is the one that knows)
---------------------------------------------------------------------------------------------------------------------
local Refresh;

local function StockRaceEnabled(index, enabled)
	-- the stock buttons know about paid race changes (CharacterChangeFixup) on top of GetAvailableRaces
	for i = 1, MAX_RACES or 30 do
		local b = _G["CharCreateRaceButton"..i];
		if ( b and b.raceIndex == index ) then
			return b:IsEnabled() and true or false, b.tooltip;
		end
	end
	return enabled, nil;
end

local function RefreshRaces()
	local list, data = {}, { GetAvailableRaces() };
	for i = 1, #data, 3 do
		local index = (i - 1) / 3 + 1;
		local _, faction = GetFactionForRace(index);
		faction = (faction == "Alliance" or faction == "Horde") and faction
			or (TemucraftRaceFaction and TemucraftRaceFaction(data[i + 1])) or "Alliance";
		table.insert(list, { index = index, name = data[i], file = data[i + 1], enabled = (data[i + 2] == 1), faction = faction });
	end
	local placed = Logic.Layout(list);
	local gender = IsMale() and "MALE" or "FEMALE";
	local selected = GetSelectedRace();
	for _, b in ipairs(raceButtons) do b:Hide(); end
	for n, race in ipairs(list) do
		local p = placed[race.index];
		local b = raceButtons[n];
		if ( not b ) then
			b = MakeIconButton("TemucraftCreateRace"..n, root.races, ICON_SIZE);
			AddRing(b, ICON_SIZE);
			b.icon:SetTexture("Interface\\Glues\\CharacterCreate\\RyansRacesRound");
			b:SetScript("OnClick", function(self)
				self:SetChecked(nil);
				if ( self.enabled and self.raceIndex ) then
					CharacterRace_OnClick(proxy, self.raceIndex);
					Refresh();
				end
			end);
			raceButtons[n] = b;
		end
		local enabled, stockTip = StockRaceEnabled(race.index, race.enabled);
		local coords = GetSafeRaceIconCoords and GetSafeRaceIconCoords(race.file, gender)
			or (RACE_ICON_TCOORDS and RACE_ICON_TCOORDS[string.upper(race.file).."_"..gender]) or { 0, 1, 0, 1 };
		b.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]);
		b.raceIndex = race.index;
		local info = GetFlavorText and GetFlavorText("RACE_INFO_"..string.upper(race.file), GetSelectedSex());
		b.tooltip = enabled and (info and (race.name.."|n|cffffffff"..info.."|r") or race.name) or (stockTip or race.name);
		b.tooltipSide = (p.side == "Alliance") and "right" or "left";
		b:ClearAllPoints();
		local x = SIDE_MARGIN + (p.column - 1) * ICON_STEP + ICON_SIZE / 2;
		local y = TOP_MARGIN - (p.row - 1) * ICON_STEP - ICON_SIZE / 2;
		if ( p.side == "Alliance" ) then
			b:SetPoint("CENTER", root, "TOPLEFT", x, y);
		else
			b:SetPoint("CENTER", root, "TOPRIGHT", -x, y);
		end
		SetIconState(b, race.index == selected, enabled);
		b:Show();
	end
end

local function RefreshClasses()
	-- GetClassesForRace() isn't used: only the races-30 exe gives it the Lua stack room for its values
	local data = { GetAvailableClasses() };
	local _, _, selected = GetSelectedClass();
	local count = 0;
	for i = 1, #data, 3 do
		if ( data[i] ) then count = count + 1; end
	end
	for _, b in ipairs(classButtons) do b:Hide(); end
	local n = 0;
	for i = 1, #data, 3 do
		local index = (i - 1) / 3 + 1;
		local name, file, available = data[i], data[i + 1], data[i + 2];
		if ( name and file ) then
			n = n + 1;
			local b = classButtons[n];
			if ( not b ) then
				b = MakeIconButton("TemucraftCreateClass"..n, root.classes, 40);
			b.tooltipSide = "top";
				b.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes");
				b:SetScript("OnClick", function(self)
					self:SetChecked(nil);
					if ( self.enabled and self.classIndex ) then
						CharacterClass_OnClick(proxy, self.classIndex);
						Refresh();
					end
				end);
				classButtons[n] = b;
			end
			local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[string.upper(file)];
			if ( coords ) then
				b.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes");
				b.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]);
			else
				b.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");
				b.icon:SetTexCoord(0, 1, 0, 1);
			end
			local stock = _G["CharCreateClassButton"..index];
			local enabled = (available == 1) and IsRaceClassValid(GetSelectedRace(), index) and true or false;
			if ( stock and stock:IsShown() and not stock:IsEnabled() ) then
				enabled = false;   -- paid services lock the class
			end
			b.classIndex = index;
			b.tooltip = enabled and name or (name.."|n|cffff2020"..((stock and stock.tooltip) or CLASS_DISABLED or "").."|r");
			b:ClearAllPoints();
			b:SetPoint("CENTER", root.classes, "CENTER", (n - (count + 1) / 2) * 50, 0);
			SetIconState(b, index == selected, enabled);
			b:Show();
		end
	end
	root.classes:SetWidth(math.max(count * 50 + 30, 200));
end

local function OptionLabel(id)
	local hair = GetHairCustomization and GetHairCustomization() or "NORMAL";
	local facial = GetFacialHairCustomization and GetFacialHairCustomization() or "NORMAL";
	local labels = {
		CHAR_CUSTOMIZATION1_DESC, CHAR_CUSTOMIZATION2_DESC,
		_G["HAIR_"..hair.."_STYLE"], _G["HAIR_"..hair.."_COLOR"], _G["FACIAL_HAIR_"..facial],
	};
	return labels[id], (id <= 2) and (labels[id] or OPTION_LABELS[id]) or labels[id];
end

local function RefreshOptions()
	local totals = Logic.Totals(SelectedFile(), IsMale(), IsDeathKnight(), IsHD());
	local counters = Counters();
	local dk = IsDeathKnight();
	if ( lastDeathKnight ~= nil and lastDeathKnight ~= dk ) then
		counters[1], counters[2] = 1, 1;
	end
	lastDeathKnight = dk;
	local y = -50;
	for id = 1, NUM_CHAR_CUSTOMIZATIONS or 5 do
		local row = optionRows[id];
		local _, label = OptionLabel(id);
		if ( label and label ~= "" ) then
			local total = totals[id];
			if ( total and total > 0 ) then
				if ( counters[id] > total ) then counters[id] = total; end
				row.text:SetText(label.."  |cffffffff"..counters[id].." / "..total.."|r");
			else
				row.text:SetText(label);
			end
			row.total = total;
			row:ClearAllPoints();
			row:SetPoint("TOP", root.options, "TOP", 0, y);
			y = y - 40;
			row:Show();
		else
			row:Hide();
		end
	end
	root.randomize:ClearAllPoints();
	root.randomize:SetPoint("TOP", root.options, "TOP", 0, y - 6);
	root.options:SetHeight(-y + 56);
end

local function RefreshName()
	local status = Logic.NameStatus(CharacterCreateNameEdit:GetText());
	if ( status == "ok" ) then
		root.nameMark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check");
		root.nameMark:Show();
		root.nameHint:SetText("");
	elseif ( status == "empty" ) then
		root.nameMark:Hide();
		root.nameHint:SetText("");
	else
		root.nameMark:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up");
		root.nameMark:Show();
		root.nameHint:SetText(NAME_HINTS[status] or "");
	end
end

function Refresh()
	if ( not root or not root:IsShown() ) then
		return;
	end
	local customize = (CharacterCreateFrame.state == "CUSTOMIZATION");
	local male = IsMale();
	root.male.ring[male and "Show" or "Hide"](root.male.ring);
	root.female.ring[male and "Hide" or "Show"](root.female.ring);
	if ( customize ) then
		root.races:Hide(); root.classes:Hide();
		root.options:Show(); root.nameBar:Show();
		root.next:SetText(FINISH or "Finish");
		RefreshOptions();
		RefreshName();
	else
		root.options:Hide(); root.nameBar:Hide();
		root.races:Show(); root.classes:Show();
		root.next:SetText(CUSTOMIZE or "Customize");
		RefreshRaces();
		RefreshClasses();
	end
	local race = GetNameForRace();
	local className, classFile = GetSelectedClass();
	local faction = SelectedFaction();
	root.title:SetText(Logic.Title(race, faction, className, classFile));
	-- step 2 shows the faction crest and the class icon either side of the line
	local crest = faction and FACTION_CREST[faction];
	if ( customize and crest ) then
		root.titleFaction:SetTexture(FACTION_CREST_FILE[faction]);
		root.titleFaction:SetTexCoord(crest[1], crest[2], crest[3], crest[4]);
		root.titleFaction:Show();
	else
		root.titleFaction:Hide();
	end
	local coords = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[string.upper(classFile)];
	if ( customize and coords ) then
		root.titleClass:SetTexCoord(coords[1], coords[2], coords[3], coords[4]);
		root.titleClass:Show();
	else
		root.titleClass:Hide();
	end
	if ( CharCreateOkayButton and CharCreateOkayButton:IsEnabled() ) then
		root.next:Enable();
	else
		root.next:Disable();
	end
	-- the altered form (worgen / human) portraits stay ours to see
	if ( CharacterCreateAlteredFormSelector and CharacterCreateAlteredFormSelector:GetParent() ~= root ) then
		CharacterCreateAlteredFormSelector:SetParent(root);
		CharacterCreateAlteredFormSelector:ClearAllPoints();
		CharacterCreateAlteredFormSelector:SetPoint("LEFT", root, "LEFT", 150, -40);
	end
end
TemucraftCharCreate_Refresh = Refresh;

---------------------------------------------------------------------------------------------------------------------
-- Appearance: counted clicks
---------------------------------------------------------------------------------------------------------------------
local function Cycle(id, delta)
	local counters = Counters();
	local total = Logic.Totals(SelectedFile(), IsMale(), IsDeathKnight(), IsHD())[id];
	local step = (delta > 0) and 1 or -1;
	for _ = 1, math.abs(delta) do
		CycleCharCustomization(id, step);
	end
	counters[id] = Logic.Step(counters[id], total, delta);
end

local function Randomize()
	PlaySound("gsCharacterCreationLook");
	local totals = Logic.Totals(SelectedFile(), IsMale(), IsDeathKnight(), IsHD());
	-- skin before face (faces depend on it), hair style before colour
	local clicks = Logic.RandomClicks(totals, math.random);
	for id = 1, 5 do
		if ( clicks[id] and clicks[id] ~= 0 ) then
			Cycle(id, clicks[id]);
		end
	end
	if ( CharCreate_ResetFeaturesDisplay ) then
		CharCreate_ResetFeaturesDisplay();
	end
	Refresh();
end

---------------------------------------------------------------------------------------------------------------------
-- Building the screen
---------------------------------------------------------------------------------------------------------------------
local function Build()
	root = CreateFrame("Frame", "TemucraftCharCreateFrame", CharacterCreateFrame);
	root:SetAllPoints(CharacterCreate);
	root:SetFrameLevel(CharacterCreateFrame:GetFrameLevel() + 5);
	holder = CreateFrame("Frame", nil, CharacterCreate);
	holder:Hide();

	-- male / female
	for _, sex in ipairs({ "male", "female" }) do
		local b = MakeIconButton("TemucraftCreate"..sex, root, 40);
		b.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Gender");
		if ( sex == "male" ) then
			b.icon:SetTexCoord(0, 0.5, 0, 1);
			b:SetPoint("TOP", root, "TOP", -28, -22);
			b.tooltip = MALE or "Male";
		else
			b.icon:SetTexCoord(0.5, 1, 0, 1);
			b:SetPoint("TOP", root, "TOP", 28, -22);
			b.tooltip = FEMALE or "Female";
		end
		b:SetScript("OnClick", function(self)
			self:SetChecked(nil);
			local want = (self == root.male) and SEX_MALE or SEX_FEMALE;
			if ( GetSelectedSex() ~= want ) then
				PlaySound("gsCharacterCreationClass");
				SetCharacterGender(want);
			end
			Refresh();
		end);
		root[sex] = b;
	end
	root.title = root:CreateFontString(nil, "OVERLAY", "GlueFontNormalLarge");
	root.title:SetPoint("BOTTOM", root, "BOTTOM", 0, 112);
	root.titleFaction = root:CreateTexture(nil, "OVERLAY");
	root.titleFaction:SetWidth(44); root.titleFaction:SetHeight(44);
	root.titleFaction:SetPoint("RIGHT", root.title, "LEFT", -8, 0);
	root.titleClass = root:CreateTexture(nil, "OVERLAY");
	root.titleClass:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes");
	root.titleClass:SetWidth(40); root.titleClass:SetHeight(40);
	root.titleClass:SetPoint("LEFT", root.title, "RIGHT", 8, 0);

	-- step 1: race columns and the class row
	root.races = CreateFrame("Frame", nil, root);
	root.races:SetAllPoints(root);
	for _, side in ipairs({ "Alliance", "Horde" }) do
		local label = root.races:CreateFontString(nil, "OVERLAY", "GlueFontNormalLarge");
		label:SetText(side == "Alliance" and (FACTION_ALLIANCE or "Alliance") or (FACTION_HORDE or "Horde"));
		local x = SIDE_MARGIN + ICON_STEP - (ICON_STEP - ICON_SIZE) / 2;
		if ( side == "Alliance" ) then
			label:SetPoint("BOTTOM", root, "TOPLEFT", x, TOP_MARGIN + 10);
		else
			label:SetPoint("BOTTOM", root, "TOPRIGHT", -x, TOP_MARGIN + 10);
		end
		local crest = root.races:CreateTexture(nil, "ARTWORK");
		crest:SetTexture(FACTION_CREST_FILE[side]);
		local c = FACTION_CREST[side];
		crest:SetTexCoord(c[1], c[2], c[3], c[4]);
		crest:SetWidth(56); crest:SetHeight(56);
		crest:SetPoint("BOTTOM", label, "TOP", 0, 2);
	end
	root.classes = Panel(root);
	root.classes:SetHeight(64);
	root.classes:SetPoint("BOTTOM", root, "BOTTOM", 0, 28);

	-- step 2: the name at the top, the options on the left
	root.nameBar = CreateFrame("Frame", nil, root);
	root.nameBar:SetWidth(320); root.nameBar:SetHeight(40);
	root.nameBar:SetPoint("BOTTOM", root, "BOTTOM", 0, 32);
	root.dice = CreateFrame("Button", "TemucraftCreateNameDice", root.nameBar);
	root.dice:SetWidth(32); root.dice:SetHeight(32);
	root.dice:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up");
	root.dice:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Down");
	root.dice:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Highlight", "ADD");
	root.dice:SetPoint("RIGHT", root.nameBar, "RIGHT", 0, 0);
	root.dice.tooltip = RANDOMIZE or "Random name";
	root.dice:SetScript("OnEnter", function(self) Tooltip(self, self.tooltip); end);
	root.dice:SetScript("OnLeave", HideTooltip);
	root.dice:SetScript("OnClick", function()
		PlaySound("gsCharacterCreationLook");
		CharacterCreateNameEdit:SetText(GetRandomName());
		RefreshName();
	end);
	root.nameMark = root.nameBar:CreateTexture(nil, "OVERLAY");
	root.nameMark:SetWidth(24); root.nameMark:SetHeight(24);
	root.nameMark:SetPoint("RIGHT", root.dice, "LEFT", -2, 0);
	root.nameHint = root.nameBar:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall");
	root.nameHint:SetPoint("BOTTOM", root.nameBar, "TOP", -20, 2);

	root.options = Panel(root);
	root.options:SetWidth(270);
	root.options:SetPoint("TOPLEFT", root, "TOPLEFT", 30, -130);
	local head = root.options:CreateFontString(nil, "OVERLAY", "GlueFontNormalLarge");
	head:SetPoint("TOP", root.options, "TOP", 0, -16);
	head:SetText(CUSTOMIZE_OPTIONS or "Appearance");
	for id = 1, NUM_CHAR_CUSTOMIZATIONS or 5 do
		local row = CreateFrame("Button", "TemucraftCreateOption"..id, root.options);
		row:SetWidth(230); row:SetHeight(34);
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp");
		row.text = row:CreateFontString(nil, "OVERLAY", "GlueFontNormal");
		row.text:SetPoint("CENTER", row, "CENTER", 0, 0);
		local bg = row:CreateTexture(nil, "BACKGROUND");
		bg:SetTexture(0, 0, 0, 0.5);
		bg:SetPoint("TOPLEFT", row, "TOPLEFT", 30, -3);
		bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -30, 3);
		for _, dir in ipairs({ "Left", "Right" }) do
			local arrow = CreateFrame("Button", row:GetName()..dir, row);
			arrow:SetWidth(32); arrow:SetHeight(32);
			arrow:SetPoint(dir == "Left" and "LEFT" or "RIGHT", row, dir == "Left" and "LEFT" or "RIGHT", 0, 0);
			arrow:SetNormalTexture("Interface\\Glues\\Common\\Glue-"..dir.."Arrow-Button-Up");
			arrow:SetPushedTexture("Interface\\Glues\\Common\\Glue-"..dir.."Arrow-Button-Down");
			arrow:SetHighlightTexture("Interface\\Glues\\Common\\Glue-"..dir.."Arrow-Button-Highlight", "ADD");
			local delta = (dir == "Left") and -1 or 1;
			arrow:SetScript("OnClick", function()
				PlaySound("gsCharacterCreationLook");
				Cycle(id, delta);
				Refresh();
			end);
		end
		-- a click on the row itself: left = next, right = back (like the stock buttons)
		row:SetScript("OnClick", function(self, button)
			PlaySound("gsCharacterCreationLook");
			Cycle(id, (button == "RightButton") and -1 or 1);
			Refresh();
		end);
		optionRows[id] = row;
	end
	root.randomize = CreateFrame("Button", "TemucraftCreateRandomize", root.options, "GlueButtonSmallTemplate");
	root.randomize:SetWidth(200); root.randomize:SetHeight(28);
	root.randomize:SetText("Randomize Appearance");
	root.randomize:SetScript("OnClick", Randomize);

	-- rotate the character
	for _, dir in ipairs({ "Left", "Right" }) do
		local b = CreateFrame("Button", "TemucraftCreateRotate"..dir, root);
		b:SetWidth(40); b:SetHeight(40);
		b:SetPoint("BOTTOM", root, "BOTTOM", dir == "Left" and -150 or 150, 150);
		b:SetNormalTexture("Interface\\Glues\\CharacterCreate\\UI-RotationRight-Big-Up");
		b:SetPushedTexture("Interface\\Glues\\CharacterCreate\\UI-RotationRight-Big-Down");
		b:SetHighlightTexture("Interface\\Glues\\Common\\Glue-RightArrow-Button-Highlight", "ADD");
		if ( dir == "Left" ) then
			b:GetNormalTexture():SetTexCoord(1, 0, 0, 1);
			b:GetPushedTexture():SetTexCoord(1, 0, 0, 1);
		end
		local step = (dir == "Left") and -1 or 1;
		b:SetScript("OnUpdate", function(self)
			if ( self:GetButtonState() == "PUSHED" ) then
				SetCharacterCreateFacing(GetCharacterCreateFacing() + step * (CHARACTER_FACING_INCREMENT or 2));
			end
		end);
	end

	-- Back / Next (Customize) / Finish
	root.back = NavButton("TemucraftCreateBack", root, BACK or "Back", function()
		CharacterCreate_Back();
		Refresh();
	end);
	root.back:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 30, 30);
	root.next = NavButton("TemucraftCreateNext", root, CUSTOMIZE or "Customize", function()
		CharacterCreate_Forward();
		Refresh();
	end);
	root.next:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -30, 30);

	-- Only cheap checks every frame: the whole screen is redrawn on clicks and when something changes, not on a timer
	-- (redrawing 30 race buttons four times a second made every click lag).
	local lastState, lastRace, lastClass, lastSex, lastOkay;
	root:SetScript("OnUpdate", function(self, elapsed)
		throttle = throttle + (elapsed or 0);
		if ( throttle < 0.2 ) then
			return;
		end
		throttle = 0;
		local state, race, class, sex = CharacterCreateFrame.state, GetSelectedRace(), select(3, GetSelectedClass()), GetSelectedSex();
		local okay = CharCreateOkayButton and CharCreateOkayButton:IsEnabled() and true or false;
		if ( state ~= lastState or race ~= lastRace or class ~= lastClass or sex ~= lastSex or okay ~= lastOkay ) then
			lastState, lastRace, lastClass, lastSex, lastOkay = state, race, class, sex, okay;
			Refresh();
		end
	end);
end

-- Move the stock frames out of sight (they keep working); the name box comes to our name bar
local function HideStock()
	for _, child in ipairs({ CharacterCreateFrame:GetChildren() }) do
		if ( child ~= root and child ~= CharacterCreateNameEdit and child ~= CharacterCreateAlteredFormSelector ) then
			child:SetParent(holder);
		end
	end
	CharacterCreateNameEdit:SetParent(root.nameBar);
	CharacterCreateNameEdit:ClearAllPoints();
	CharacterCreateNameEdit:SetPoint("LEFT", root.nameBar, "LEFT", 6, 0);
	CharacterCreateNameEdit:SetWidth(250);
	CharacterCreateNameEdit:Show();
end

local function OnShow()
	if ( not Active() ) then
		if ( root ) then root:Hide(); end
		return;
	end
	if ( not root ) then
		Build();
	end
	HideStock();
	-- The client rolled a new look for the race and sex it starts on (ResetCharCustomize); the other races and sexes
	-- keep the look they had (CCharacterCreation::m_charPreferences), and so their counters. A paid change starts from
	-- the character's own look: every counter starts again.
	if ( PAID_SERVICE_TYPE ) then
		positions = {};
	else
		positions[CounterKey()] = nil;
	end
	lastDeathKnight = nil;
	root:Show();
	Refresh();
end

if ( CharacterCreate.HookScript ) then
	CharacterCreate:HookScript("OnShow", OnShow);
else
	local old = CharacterCreate:GetScript("OnShow");
	CharacterCreate:SetScript("OnShow", function(...) if ( old ) then old(...); end OnShow(); end);
end

-- Character create shows the faction's scene by default (Alliance or Horde), not the race's; the player's own pick
-- (TEMUCRAFT_SCENE_PICKS) still wins, and TEMUCRAFT_CREATE_SCENES = "race" keeps each race's scene.
local oldBackground = SetBackgroundModel;
if ( oldBackground ) then
	SetBackgroundModel = function(model, name, race)
		if ( model == CharacterCreate and Active() and TEMUCRAFT_CREATE_SCENES ~= "race" ) then
			local saved = TEMUCRAFT_CHARACTER_SCENES;
			TEMUCRAFT_CHARACTER_SCENES = "faction";
			local ok, err = pcall(oldBackground, model, name, race);
			TEMUCRAFT_CHARACTER_SCENES = saved;
			if ( not ok ) then
				error(err, 0);
			end
			return;
		end
		return oldBackground(model, name, race);
	end
end

-- The edit box's own changes update the check mark
if ( CharacterCreateNameEdit and CharacterCreateNameEdit.HookScript ) then
	CharacterCreateNameEdit:HookScript("OnTextChanged", function()
		if ( root and root:IsShown() ) then
			RefreshName();
		end
	end);
end
