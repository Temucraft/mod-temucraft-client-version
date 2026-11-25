-- Temucraft character panel (retail look): the paper doll with the item slots down both sides and the weapons along
-- the bottom, a 3D model in the middle on the race's backdrop, and on the right the item level and the stats in
-- sections (Attributes, Enhancements, Defense). Tabs Character / Pet / Reputation / Currency along the bottom; Pet
-- opens the stock character frame on that tab, Reputation and Currency the Temucraft windows (TemucraftReputation.lua,
-- TemucraftCurrency.lua) unless their Classic option is on.
-- C (ToggleCharacter("PaperDollFrame")), the micro button and the stock frame's Character tab open it. "Classic" (the
-- checkbox, Interface Options > Temucraft or "/tchar classic") brings back the stock paper doll, "/tchar new" this one.
-- The item slots are the stock ones (CharacterHeadSlot ...): they move into this window while it is open and go back
-- when it closes, so clicking, dragging, the equipment flyouts (Alt) and the equipment manager work as they always do.
-- Nothing here is secure: it can open and close in combat.

----------------------------------------------------------------------------------------------------------------------
-- The logic (no frames: tests/interface_test.lua runs it with stubs)
----------------------------------------------------------------------------------------------------------------------
TemucraftCharacterLogic = {};
local L = TemucraftCharacterLogic;

L.LEFT = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" };
L.RIGHT = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" };
L.BOTTOM = { "MainHand", "SecondaryHand", "Ranged" };
-- the slots that count for the item level: everything but the shirt (4) and the tabard (19)
L.ILVL_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 };

-- items[slot] = { level = n, equipLoc = "INVTYPE_..." }; a two-hander with nothing in the off hand counts twice,
-- empty slots count 0 (like retail)
function L.AverageItemLevel(items)
	local total = 0;
	for _, slot in ipairs(L.ILVL_SLOTS) do
		local item = items[slot];
		if ( item and item.level ) then
			total = total + item.level;
		elseif ( slot == 17 ) then
			local main = items[16];
			if ( main and main.level and main.equipLoc == "INVTYPE_2HWEAPON" ) then total = total + main.level; end
		end
	end
	return total / #L.ILVL_SLOTS;
end

local MELEE = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true };
local CASTER = { MAGE = true, WARLOCK = true, PRIEST = true };
-- hybrids: the role of each talent tree
local HYBRID = { PALADIN = { "caster", "melee", "melee" }, SHAMAN = { "caster", "melee", "caster" }, DRUID = { "caster", "melee", "caster" } };

-- "melee", "ranged" or "caster" (tree = the talent tree with the most points, or nil)
function L.Role(class, tree)
	if ( MELEE[class] ) then return "melee"; end
	if ( class == "HUNTER" ) then return "ranged"; end
	if ( CASTER[class] ) then return "caster"; end
	local roles = HYBRID[class];
	return roles and roles[tree or 1] or "melee";
end

function L.Percent(v) return string.format("%.2f%%", v or 0); end
local function Number(v) return tostring(math.floor((v or 0) + 0.5)); end

-- s = the numbers (see Read below); returns { { title, rows = { { label, value }, ... } }, ... }
function L.Sections(s, role)
	local out = {};
	table.insert(out, { title = "Attributes", rows = {
		{ "Strength", Number(s.str) }, { "Agility", Number(s.agi) }, { "Stamina", Number(s.sta) },
		{ "Intellect", Number(s.int) }, { "Spirit", Number(s.spi) }, { "Armor", Number(s.armor) } } });
	local rows = {};
	if ( role == "caster" ) then
		table.insert(rows, { "Spell Power", Number(s.sp) });
		if ( (s.heal or 0) > (s.sp or 0) ) then table.insert(rows, { "Healing", Number(s.heal) }); end
		table.insert(rows, { "Critical Strike", L.Percent(s.spellCrit) });
		table.insert(rows, { "Haste", L.Percent(s.spellHaste) });
		table.insert(rows, { "Hit", L.Percent(s.spellHit) });
		if ( (s.spellPen or 0) > 0 ) then table.insert(rows, { "Spell Penetration", Number(s.spellPen) }); end
		table.insert(rows, { "Mana Regen", Number(s.mp5Casting).." / "..Number(s.mp5) });
	elseif ( role == "ranged" ) then
		table.insert(rows, { "Attack Power", Number(s.rap) });
		table.insert(rows, { "Critical Strike", L.Percent(s.rangedCrit) });
		table.insert(rows, { "Haste", L.Percent(s.rangedHaste) });
		table.insert(rows, { "Hit", L.Percent(s.rangedHit) });
		table.insert(rows, { "Armor Penetration", L.Percent(s.armorPen) });
	else
		table.insert(rows, { "Attack Power", Number(s.ap) });
		table.insert(rows, { "Critical Strike", L.Percent(s.meleeCrit) });
		table.insert(rows, { "Haste", L.Percent(s.meleeHaste) });
		table.insert(rows, { "Hit", L.Percent(s.meleeHit) });
		table.insert(rows, { "Expertise", Number(s.expertise) });
		table.insert(rows, { "Armor Penetration", L.Percent(s.armorPen) });
	end
	table.insert(out, { title = "Enhancements", rows = rows });
	table.insert(out, { title = "Defense", rows = {
		{ "Defense", Number(s.defense) }, { "Dodge", L.Percent(s.dodge) }, { "Parry", L.Percent(s.parry) },
		{ "Block", L.Percent(s.block) }, { "Resilience", Number(s.resilience) } } });
	return out;
end

----------------------------------------------------------------------------------------------------------------------
-- The window
----------------------------------------------------------------------------------------------------------------------
if ( not CreateFrame ) then return; end   -- tests load only the logic

local WIDTH, HEIGHT = 730, 500;
local DOLL_WIDTH = 480;
local MAX_ROWS = 24;

local frame = CreateFrame("Frame", "TemucraftCharacterFrame", UIParent);
frame:SetWidth(WIDTH); frame:SetHeight(HEIGHT);
frame:SetToplevel(true);
frame:EnableMouse(true);
frame:SetMovable(true);
frame:SetClampedToScreen(true);
frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } });
frame:Hide();
UIPanelWindows["TemucraftCharacterFrame"] = { area = "left", pushable = 3, whileDead = 1 };

local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
nameText:SetPoint("TOP", frame, "TOPLEFT", DOLL_WIDTH / 2 + 10, -20);
local levelText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
levelText:SetPoint("TOP", nameText, "BOTTOM", 0, -4);

local close = CreateFrame("Button", "TemucraftCharacterFrameCloseButton", frame, "UIPanelCloseButton");
close:SetPoint("TOPRIGHT", -6, -6);

local drag = CreateFrame("Frame", nil, frame);
drag:SetPoint("TOPLEFT", 12, -8); drag:SetPoint("TOPRIGHT", -40, -8); drag:SetHeight(26);
drag:EnableMouse(true);
drag:RegisterForDrag("LeftButton");
drag:SetScript("OnDragStart", function() frame:StartMoving(); end);
drag:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); end);

-- the model on the race's backdrop (the stock dress-up art, in 4 pieces)
local doll = CreateFrame("Frame", nil, frame);
doll:SetPoint("TOPLEFT", 66, -60);
doll:SetWidth(DOLL_WIDTH - 112); doll:SetHeight(340);
local backdrop = {};
for i, piece in ipairs({ { 0, 0, 0.8, 0.67 }, { 0.8, 0, 0.2, 0.67 }, { 0, 0.67, 0.8, 0.33 }, { 0.8, 0.67, 0.2, 0.33 } }) do
	local t = doll:CreateTexture(nil, "BACKGROUND");
	t:SetPoint("TOPLEFT", doll, "TOPLEFT", piece[1] * doll:GetWidth(), -piece[2] * doll:GetHeight());
	t:SetWidth(piece[3] * doll:GetWidth()); t:SetHeight(piece[4] * doll:GetHeight());
	t:SetAlpha(0.7);
	backdrop[i] = t;
end
local STOCK_RACES = { Human = true, Dwarf = true, NightElf = true, Gnome = true, Draenei = true, Orc = true, Scourge = true,
	Tauren = true, Troll = true, BloodElf = true };
local function SetBackdropRace()
	local _, race = UnitRace("player");
	for i, t in ipairs(backdrop) do
		-- other races: their own art if a patch has it (SetTexture fails without), else the human one
		if ( not (race and STOCK_RACES[race]) and t:SetTexture("Interface\\DressUpFrame\\DressUpBackground-"..(race or "")..i) ) then
			-- found
		else
			t:SetTexture("Interface\\DressUpFrame\\DressUpBackground-"..((race and STOCK_RACES[race]) and race or "Human")..i);
		end
	end
end

local model = CreateFrame("PlayerModel", "TemucraftCharacterModel", doll);
model:SetAllPoints();
model:EnableMouse(true);
model:EnableMouseWheel(true);
local zoom = 0;
model:SetScript("OnMouseDown", function(self, button)
	if ( button == "LeftButton" ) then self.turning = GetCursorPosition(); end
end);
model:SetScript("OnMouseUp", function(self) self.turning = nil; end);
model:SetScript("OnUpdate", function(self)
	if ( not self.turning ) then return; end
	local x = GetCursorPosition();
	self:SetFacing(self:GetFacing() + (x - self.turning) * 0.02);
	self.turning = x;
end);
model:SetScript("OnMouseWheel", function(self, delta)
	zoom = max(0, min(2, zoom + delta * 0.25));
	self:SetPosition(zoom, 0, 0);
end);
local hint = doll:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
hint:SetPoint("BOTTOM", 0, 4);
hint:SetText("Drag to turn, wheel to zoom");

-- the stats panel
local stats = CreateFrame("Frame", nil, frame);
stats:SetPoint("TOPLEFT", DOLL_WIDTH + 10, -16);
stats:SetPoint("BOTTOMRIGHT", -16, 16);
stats:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } });
stats:SetBackdropColor(0, 0, 0, 0.6);
local statsIlvl = stats:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge");
statsIlvl:SetPoint("TOP", 0, -12);
statsIlvl:SetTextColor(0.64, 0.21, 0.93);
local statsIlvlLabel = stats:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
statsIlvlLabel:SetPoint("TOP", statsIlvl, "BOTTOM", 0, -2);
statsIlvlLabel:SetText("Item Level (equipped)");
local rows = {};
for i = 1, MAX_ROWS do
	local r = CreateFrame("Frame", nil, stats);
	r:SetHeight(16);
	r:SetPoint("LEFT", 10, 0); r:SetPoint("RIGHT", -10, 0);
	r.band = r:CreateTexture(nil, "BACKGROUND");
	r.band:SetAllPoints();
	r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	r.label:SetPoint("LEFT", 4, 0);
	r.value = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	r.value:SetPoint("RIGHT", -4, 0);
	r:Hide();
	rows[i] = r;
end

local function TopTree()
	local best, bestPoints = nil, 0;
	for t = 1, GetNumTalentTabs() do
		local name, _, points = GetTalentTabInfo(t);
		if ( points and points > bestPoints ) then best, bestPoints = t, points; end
	end
	return best;
end

local function Read()
	local s = {};
	s.str, s.agi, s.sta, s.int, s.spi = select(2, UnitStat("player", 1)), select(2, UnitStat("player", 2)),
		select(2, UnitStat("player", 3)), select(2, UnitStat("player", 4)), select(2, UnitStat("player", 5));
	s.armor = select(2, UnitArmor("player"));
	local base, pos, neg = UnitAttackPower("player");
	s.ap = base + pos + neg;
	base, pos, neg = UnitRangedAttackPower("player");
	s.rap = base + pos + neg;
	s.sp, s.spellCrit = 0, 0;
	for school = 2, 7 do
		s.sp = max(s.sp, GetSpellBonusDamage(school));
		s.spellCrit = max(s.spellCrit, GetSpellCritChance(school));
	end
	s.heal = GetSpellBonusHealing();
	s.meleeCrit, s.rangedCrit = GetCritChance(), GetRangedCritChance();
	s.meleeHaste, s.rangedHaste, s.spellHaste = GetCombatRatingBonus(CR_HASTE_MELEE), GetCombatRatingBonus(CR_HASTE_RANGED), GetCombatRatingBonus(CR_HASTE_SPELL);
	s.meleeHit, s.rangedHit, s.spellHit = GetCombatRatingBonus(CR_HIT_MELEE), GetCombatRatingBonus(CR_HIT_RANGED), GetCombatRatingBonus(CR_HIT_SPELL);
	s.expertise = GetExpertise();
	s.armorPen = GetArmorPenetration and GetArmorPenetration() or GetCombatRatingBonus(CR_ARMOR_PENETRATION);
	s.spellPen = GetSpellPenetration();
	local regen, casting = GetManaRegen();
	s.mp5, s.mp5Casting = (regen or 0) * 5, (casting or 0) * 5;
	local defBase, defMod = UnitDefense("player");
	s.defense = (defBase or 0) + (defMod or 0);
	s.dodge, s.parry, s.block = GetDodgeChance(), GetParryChance(), GetBlockChance();
	s.resilience = GetCombatRating(CR_CRIT_TAKEN_MELEE);
	return s;
end

local function ItemLevel()
	if ( GetAverageItemLevel ) then return (GetAverageItemLevel()); end
	local items = {};
	for _, slot in ipairs(L.ILVL_SLOTS) do
		local link = GetInventoryItemLink("player", slot);
		if ( link ) then
			local _, _, _, level, _, _, _, _, equipLoc = GetItemInfo(link);
			items[slot] = { level = level, equipLoc = equipLoc };
		end
	end
	return L.AverageItemLevel(items);
end

local function UpdateStats()
	local _, class = UnitClass("player");
	local level = ItemLevel();
	statsIlvl:SetText(format("%.1f", level));
	local sections = L.Sections(Read(), L.Role(class, TopTree()));
	local n, y = 0, -52;
	for _, section in ipairs(sections) do
		if ( n < MAX_ROWS ) then
			n = n + 1;
			local r = rows[n];
			r:SetPoint("TOP", stats, "TOP", 0, y - 6);
			r.label:SetFontObject(GameFontNormal); r.label:SetText(section.title);
			r.value:SetText("");
			r.band:SetTexture(1, 0.82, 0, 0.12);
			r:Show();
			y = y - 24;
		end
		for i, row in ipairs(section.rows) do
			if ( n < MAX_ROWS ) then
				n = n + 1;
				local r = rows[n];
				r:SetPoint("TOP", stats, "TOP", 0, y);
				r.label:SetFontObject(GameFontHighlightSmall); r.label:SetText(row[1]);
				r.value:SetText(row[2]);
				if ( i % 2 == 1 ) then r.band:SetTexture(1, 1, 1, 0.05); else r.band:SetTexture(0, 0, 0, 0); end
				r:Show();
				y = y - 16;
			end
		end
		y = y - 6;
	end
	for i = n + 1, MAX_ROWS do rows[i]:Hide(); end
end

local function UpdateHeader()
	local className, class = UnitClass("player");
	local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class];
	nameText:SetText(UnitPVPName("player"));
	if ( color ) then nameText:SetTextColor(color.r, color.g, color.b); end
	local tree = TopTree();
	local treeName = tree and GetTalentTabInfo(tree);
	levelText:SetText(format("Level %d %s%s", UnitLevel("player"), treeName and (treeName.." ") or "", className or ""));
end

-- the stock slots, the equipment flyout and the equipment manager come into this window while it is open
local moved = {};
local function Save(f)
	if ( not f or moved[f] ) then return; end
	local points = {};
	for i = 1, f:GetNumPoints() do points[i] = { f:GetPoint(i) }; end
	moved[f] = { parent = f:GetParent(), points = points };
end
local function Borrow()
	for _, list in ipairs({ L.LEFT, L.RIGHT, L.BOTTOM }) do
		for _, slot in ipairs(list) do
			local b = _G["Character"..slot.."Slot"];
			if ( b ) then Save(b); b:SetParent(frame); end
		end
	end
	for _, name in ipairs({ "CharacterAmmoSlot", "PaperDollFrameItemFlyout", "GearManagerDialog", "GearManagerToggleButton" }) do
		local f = _G[name];
		if ( f ) then Save(f); f:SetParent(frame); end
	end
	CharacterHeadSlot:ClearAllPoints(); CharacterHeadSlot:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -60);
	CharacterHandsSlot:ClearAllPoints(); CharacterHandsSlot:SetPoint("TOPRIGHT", frame, "TOPLEFT", DOLL_WIDTH - 6, -60);
	CharacterMainHandSlot:ClearAllPoints(); CharacterMainHandSlot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", DOLL_WIDTH / 2 - 22, 22);
	if ( UnitHasRelicSlot("player") ) then CharacterAmmoSlot:Hide(); else CharacterAmmoSlot:Show(); end
	if ( GearManagerDialog ) then
		GearManagerDialog:ClearAllPoints(); GearManagerDialog:SetPoint("TOPLEFT", frame, "TOPRIGHT", -6, -10);
	end
	if ( GearManagerToggleButton ) then
		GearManagerToggleButton:ClearAllPoints(); GearManagerToggleButton:SetPoint("TOPRIGHT", frame, "TOPLEFT", DOLL_WIDTH - 6, -18);
		if ( GetCVarBool("equipmentManager") ) then GearManagerToggleButton:Show(); else GearManagerToggleButton:Hide(); end
	end
end
local function GiveBack()
	if ( GearManagerDialog ) then GearManagerDialog:Hide(); end
	if ( PaperDollFrameItemFlyout ) then PaperDollFrameItemFlyout:Hide(); end
	for f, saved in pairs(moved) do
		f:SetParent(saved.parent);
		f:ClearAllPoints();
		for _, p in ipairs(saved.points) do f:SetPoint(unpack(p)); end
	end
	wipe(moved);
end

-- titles (the stock picker is part of the stock paper doll)
local titleMenu = CreateFrame("Frame", "TemucraftCharacterTitleMenu", frame, "UIDropDownMenuTemplate");
local titleButton = CreateFrame("Button", "TemucraftCharacterTitleButton", frame, "UIPanelButtonTemplate");
titleButton:SetWidth(70); titleButton:SetHeight(20);
titleButton:SetText("Titles");
titleButton:SetPoint("TOPLEFT", 20, -26);
titleButton:SetScript("OnClick", function(self)
	local list = { { text = NONE or "None", func = function() SetCurrentTitle(-1); end, checked = GetCurrentTitle() <= 0 } };
	local known = {};
	for i = 1, GetNumTitles() do
		if ( IsTitleKnown(i) ~= 0 ) then table.insert(known, { id = i, name = strtrim(GetTitleName(i)) }); end
	end
	table.sort(known, function(a, b) return a.name < b.name; end);
	for _, t in ipairs(known) do
		table.insert(list, { text = t.name, checked = GetCurrentTitle() == t.id, func = function() SetCurrentTitle(t.id); end });
	end
	-- the dialog-style list: solid, so the item slots under it don't show through (the "MENU" style is see-through)
	EasyMenu(list, titleMenu, self, 0, 0);
end);

local classic = CreateFrame("CheckButton", "TemucraftCharacterClassicCheck", frame, "UICheckButtonTemplate");
classic:SetWidth(22); classic:SetHeight(22);
classic:SetPoint("BOTTOMLEFT", 16, 14);
-- it sat on the bottom tabs: the choice is in Interface > Temucraft (and /tchar classic) only
classic:Hide();
_G[classic:GetName().."Text"]:SetText("Classic");
classic:SetScript("OnClick", function(self)
	self:SetChecked(false);
	TemucraftUI_SetClassic("char", true);
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffTemucraft:|r classic character panel on (/tchar new for this one).");
end);

-- tabs
local StockToggleCharacter = ToggleCharacter;
TemucraftStockToggleCharacter = StockToggleCharacter;
-- the classic set: Character, Pet, Reputation, Skills, Currency, and Professions when the TemucraftProfGear addon
-- (mod-temucraft-professions) is on. Skills is the stock skill list; Professions its Profession Equipment panel.
-- { label, stock tab, shown?, open = func for a tab that isn't a stock one }
local function ProfGear() return SlashCmdList and SlashCmdList["TEMUCRAFTPROFGEAR"]; end
local TABS = {
	{ CHARACTER or "Character", nil },
	{ PET or "Pet", "PetPaperDollFrame", function() return HasPetUI(); end },
	{ REPUTATION or "Reputation", "ReputationFrame" },
	{ SKILLS or "Skills", "SkillFrame" },
	{ CURRENCY or "Currency", "TokenFrame" },
	{ "Professions", nil, function() return ProfGear() ~= nil; end, open = function() ProfGear()(); end },
};
TEMUCRAFT_CHARACTER_TAB_REPUTATION, TEMUCRAFT_CHARACTER_TAB_CURRENCY = 3, 5;
local tabs = {};
for i, t in ipairs(TABS) do
	local tab = CreateFrame("Button", "TemucraftCharacterFrameTab"..i, frame, "CharacterFrameTabButtonTemplate");
	tab:SetID(i);
	tab:SetText(t[1]);
	tab:SetScript("OnClick", function()
		if ( not t[2] and not t.open ) then return; end
		PlaySound("igCharacterInfoTab");
		HideUIPanel(frame);
		if ( t.open ) then t.open(); return; end
		ToggleCharacter(t[2]);   -- the Temucraft reputation / currency windows (TemucraftCharacter_Redirect), else stock
	end);
	tabs[i] = tab;
end
PanelTemplates_SetNumTabs(frame, #TABS);
local function LayoutTabs()
	local last;
	for i, t in ipairs(TABS) do
		local tab = tabs[i];
		if ( t[3] and not t[3]() ) then
			tab:Hide();
		else
			tab:ClearAllPoints();
			if ( last ) then tab:SetPoint("LEFT", last, "RIGHT", -16, 0); else tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 20, 8); end
			tab:Show();
			last = tab;
		end
	end
	PanelTemplates_SetTab(frame, 1);
end

local function Refresh()
	if ( not frame:IsShown() ) then return; end
	UpdateHeader();
	UpdateStats();
end

frame:SetScript("OnShow", function()
	PlaySound("igCharacterInfoOpen");
	SetBackdropRace();
	model:SetUnit("player");
	zoom = 0; model:SetPosition(0, 0, 0);
	Borrow();
	LayoutTabs();
	Refresh();
	if ( UpdateMicroButtons ) then UpdateMicroButtons(); end
	SetButtonPulse(CharacterMicroButton, 0, 1);
end);
frame:SetScript("OnHide", function()
	PlaySound("igCharacterInfoClose");
	GiveBack();
	if ( UpdateMicroButtons ) then UpdateMicroButtons(); end
end);

function TemucraftCharacter_Toggle()
	if ( frame:IsShown() ) then HideUIPanel(frame); else ShowUIPanel(frame); end
end

-- the same tabs along the bottom of another window of the panel (TemucraftReputation.lua, TemucraftCurrency.lua):
-- selected = its tab (3 Reputation, 5 Currency). Returns the function that lays them out (call it in OnShow).
function TemucraftCharacter_AddTabs(owner, selected)
	local own = {};
	for i, t in ipairs(TABS) do
		local tab = CreateFrame("Button", owner:GetName().."Tab"..i, owner, "CharacterFrameTabButtonTemplate");
		tab:SetID(i);
		tab:SetText(t[1]);
		tab:SetScript("OnClick", function()
			if ( i == selected ) then return; end
			PlaySound("igCharacterInfoTab");
			HideUIPanel(owner);
			if ( t.open ) then t.open(); return; end
			ToggleCharacter(t[2] or "PaperDollFrame");
		end);
		own[i] = tab;
	end
	PanelTemplates_SetNumTabs(owner, #TABS);
	return function()
		local last;
		for i, t in ipairs(TABS) do
			local tab = own[i];
			if ( t[3] and not t[3]() ) then
				tab:Hide();
			else
				tab:ClearAllPoints();
				if ( last ) then tab:SetPoint("LEFT", last, "RIGHT", -16, 0); else tab:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 20, 8); end
				tab:Show();
				last = tab;
			end
		end
		PanelTemplates_SetTab(owner, selected);
	end;
end

-- ToggleCharacter(tab) of another Temucraft window: TemucraftCharacter_Redirect[tab] = { classic = its Classic
-- option ("rep"), open = func }; func() opens or closes that window and returns true, or returns false (Classic on)
-- for the stock frame
TemucraftCharacter_Redirect = {};

-- C, the micro button and the stock Character tab
function ToggleCharacter(tab, ...)
	local redirect = TemucraftCharacter_Redirect[tab];
	if ( redirect ) then
		if ( frame:IsShown() and not TemucraftUI_IsClassic(redirect.classic) ) then HideUIPanel(frame); end
		if ( redirect.open() ) then return; end
	end
	if ( tab ~= "PaperDollFrame" or TemucraftUI_IsClassic("char") ) then
		if ( frame:IsShown() ) then HideUIPanel(frame); end
		return StockToggleCharacter(tab, ...);
	end
	if ( CharacterFrame:IsShown() ) then HideUIPanel(CharacterFrame); ShowUIPanel(frame); return; end
	TemucraftCharacter_Toggle();
end

-- anything else that shows the stock paper doll (the stock frame opened on its last tab): this window instead.
-- Next frame, so that ToggleCharacter("ReputationFrame") has switched the tab by then.
local swap = CreateFrame("Frame");
swap:Hide();
swap:SetScript("OnUpdate", function(self)
	self:Hide();
	if ( PaperDollFrame:IsVisible() and not TemucraftUI_IsClassic("char") ) then
		HideUIPanel(CharacterFrame);
		ShowUIPanel(frame);
	end
end);
PaperDollFrame:HookScript("OnShow", function() if ( not TemucraftUI_IsClassic("char") ) then swap:Show(); end end);

hooksecurefunc("UpdateMicroButtons", function()
	if ( frame:IsShown() and CharacterMicroButton ) then
		CharacterMicroButton:SetButtonState("PUSHED", 1);
		CharacterMicroButton_SetPushed();
	end
end);

TemucraftUI_OnChange("classicchar", function(on)
	if ( on and frame:IsShown() ) then HideUIPanel(frame); StockToggleCharacter("PaperDollFrame"); end
end);

SLASH_TEMUCRAFTCHARACTER1 = "/tchar";
SlashCmdList["TEMUCRAFTCHARACTER"] = function(msg)
	msg = strlower(strtrim(msg or ""));
	if ( msg == "classic" or msg == "old" ) then
		TemucraftUI_SetClassic("char", true);
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffTemucraft:|r C opens the classic character panel now (/tchar new to switch back).");
	elseif ( msg == "new" or msg == "retail" ) then
		TemucraftUI_SetClassic("char", false);
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffTemucraft:|r C opens the new character panel now.");
	else
		ToggleCharacter("PaperDollFrame");
	end
end;

-- stat changes, throttled to one update per frame
local events = CreateFrame("Frame");
local dirty = false;
for _, e in ipairs({ "UNIT_INVENTORY_CHANGED", "UNIT_STATS", "UNIT_AURA", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER",
	"UNIT_RESISTANCES", "UNIT_LEVEL", "UNIT_MODEL_CHANGED", "COMBAT_RATING_UPDATE", "PLAYER_TALENT_UPDATE",
	"PLAYER_EQUIPMENT_CHANGED", "UNIT_PET", "UNIT_NAME_UPDATE", "PLAYER_DAMAGE_DONE_MODS" }) do
	events:RegisterEvent(e);
end
events:SetScript("OnEvent", function(self, event, unit)
	if ( not frame:IsShown() ) then return; end
	if ( event == "UNIT_PET" ) then LayoutTabs(); return; end
	if ( unit and type(unit) == "string" and string.find(event, "^UNIT_") and unit ~= "player" ) then return; end
	if ( event == "UNIT_MODEL_CHANGED" ) then model:SetUnit("player"); return; end
	if ( not dirty ) then
		dirty = true;
		self:SetScript("OnUpdate", function(f)
			f:SetScript("OnUpdate", nil);
			dirty = false;
			Refresh();
		end);
	end
end);
