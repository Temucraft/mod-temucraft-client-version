-- Temucraft character window (retail look): ONE window, one size, one place and one style for every tab along its
-- bottom: Character, Pet (only while there is a pet, like stock), Reputation, Skills, Currency and Professions
-- (when the TemucraftProfGear addon of mod-temucraft-professions is on). Switching tabs swaps the page inside; the
-- window and its tab strip stay put. The pages:
--   Character    the paper doll with the item slots down both sides and the weapons along the bottom, a 3D model in
--                the middle on the race's backdrop, and on the right the item level and the stats in sections
--                (Attributes, Enhancements, Defense). The item slots are the stock ones (CharacterHeadSlot ...): they
--                move into this page while it is open and go back when it closes, so clicking, dragging, the
--                equipment flyouts (Alt) and the equipment manager work as they always do.
--   Pet          the pet's model, happiness (hunters) and experience, and its stats in the same panel as the
--                character's.
--   Reputation   TemucraftReputation.lua's page (list left, details right).
--   Skills       the skill lines under collapsible sections (TemucraftSkills_Build below; the sections, icons and
--                "current / max" text are the spellbook's Skills tab's, TemucraftSpellBookLogic), details right.
--   Currency     TemucraftCurrency.lua's page.
--   Professions  TemucraftProfGear's Profession Equipment and Reagent Bag panels side by side
--                (TemucraftProfGear_Host).
-- Size: WIDTH x HEIGHT on every tab, scaled down when the screen is smaller. Movable by the top strip; the place is
-- kept per character (TemucraftStore, key ui.charwin). Esc closes it.
-- C (ToggleCharacter("PaperDollFrame")), U, the micro button and the stock frame's tabs open it on their page.
-- Classic options (Interface > Temucraft, /tui, /tchar classic): "Classic character panel" sends Character, Pet,
-- Skills and Professions to the stock character frame; "Classic reputation window" / "Classic currency window" send
-- those tabs to the stock ones. DragonUI's Character Panel module counts as the classic character panel and currency
-- (TemucraftDragonUI.lua): DragonUI's window is used there, and Reputation stays ours.
-- Pages of other files: TemucraftCharacter_AddPage(key, frame, { title = "..." }); TemucraftCharacter_Open(key,
-- toggle) opens one (true = this window took it, false = its Classic option is on: open the stock one).
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


-- the pet's numbers (see ReadPet below) in the same sections as the character's
function L.PetSections(s)
	local out = {};
	table.insert(out, { title = "Attributes", rows = {
		{ "Strength", Number(s.str) }, { "Agility", Number(s.agi) }, { "Stamina", Number(s.sta) },
		{ "Intellect", Number(s.int) }, { "Spirit", Number(s.spi) }, { "Armor", Number(s.armor) } } });
	local melee = { { "Attack Power", Number(s.ap) }, { "Damage", Number(s.minDamage).." - "..Number(s.maxDamage) },
		{ "Attack Speed", string.format("%.2f", s.speed or 0) } };
	if ( (s.sp or 0) > 0 ) then table.insert(melee, { "Spell Power", Number(s.sp) }); end
	table.insert(out, { title = "Melee", rows = melee });
	table.insert(out, { title = "Resistances", rows = {
		{ "Arcane", Number(s.arcane) }, { "Fire", Number(s.fire) }, { "Frost", Number(s.frost) },
		{ "Nature", Number(s.nature) }, { "Shadow", Number(s.shadow) } } });
	if ( (s.talentPoints or 0) > 0 ) then
		table.insert(out, { title = "Talents", rows = { { "Unspent Points", Number(s.talentPoints) } } });
	end
	return out;
end

----------------------------------------------------------------------------------------------------------------------
-- The pages and where a tab goes
----------------------------------------------------------------------------------------------------------------------
-- the tabs, in order: key, label
L.TABS = { { "character", "Character" }, { "pet", "Pet" }, { "rep", "Reputation" }, { "skills", "Skills" },
	{ "currency", "Currency" }, { "prof", "Professions" } };
-- the stock frame of each page (ToggleCharacter's argument) and the Classic option that sends it there
L.STOCK = { character = "PaperDollFrame", pet = "PetPaperDollFrame", rep = "ReputationFrame", skills = "SkillFrame",
	currency = "TokenFrame" };
L.PAGE_OF = {};
for key, stock in pairs(L.STOCK) do L.PAGE_OF[stock] = key; end
L.CLASSIC = { character = "char", pet = "char", rep = "rep", skills = "char", currency = "currency", prof = "char" };

-- where ToggleCharacter(stockTab) goes: the page's key, or "stock". isClassic(which), has(key) = the page is there
function L.Route(stockTab, isClassic, has)
	local key = L.PAGE_OF[stockTab];
	if ( not key or not has(key) or isClassic(L.CLASSIC[key]) ) then return "stock"; end
	return key;
end

-- the window's scale on a sw x sh screen (room for the tabs under it)
function L.FitScale(sw, sh, width, height)
	return math.min(1, (sw - 20) / width, (sh - 60) / height);
end

-- "x,y" (the window's top left on the screen) and back
function L.PositionText(x, y) return string.format("%d,%d", math.floor(x + 0.5), math.floor(y + 0.5)); end
function L.ParsePosition(text)
	local x, y = string.match(text or "", "^(%-?%d+),(%-?%d+)$");
	if ( not x ) then return nil; end
	return tonumber(x), tonumber(y);
end

----------------------------------------------------------------------------------------------------------------------
-- Skills: the lines of the list and the "how to raise it" text
----------------------------------------------------------------------------------------------------------------------
-- sections: TemucraftSpellBookLogic.SkillSections's ({ title, entries }); returns { kind = "group", key, name,
-- collapsed, count } and { kind = "skill", name, entry }
function L.SkillLines(sections, collapsed)
	collapsed = collapsed or {};
	local out = {};
	for _, s in ipairs(sections or {}) do
		table.insert(out, { kind = "group", key = s.title, name = s.title, collapsed = collapsed[s.title], count = #s.entries });
		if ( not collapsed[s.title] ) then
			for _, e in ipairs(s.entries) do table.insert(out, { kind = "skill", name = e.name, entry = e }); end
		end
	end
	return out;
end

local RAISE = {
	["Weapon Skills"] = "Rises as you hit enemies with a weapon of this kind, up to 5 per level. A weapon master in the capital cities teaches new weapon types.",
	["Armor Proficiencies"] = "You can wear this kind of armor. It has no rank to raise; your class trainer teaches heavier armor at the level your class gets it.",
	["Languages"] = "You speak and read this language. It has no rank to raise.",
	["Class Skills"] = "Rises by itself as you level (up to 5 per level).",
	["Professions"] = "Rises as you craft or gather. A trainer raises the maximum (Apprentice 75, Journeyman 150, Expert 225, Artisan 300, Master 375, Grand Master 450). Recipes: the profession's spell in the spellbook. Equipment and the reagent bag: the Professions tab.",
	["Secondary Skills"] = "Rises as you use it. A trainer raises the maximum (Apprentice 75, Journeyman 150, Expert 225, Artisan 300, Master 375, Grand Master 450).",
};
function L.SkillHelp(e)
	if ( not e ) then return ""; end
	local name = string.lower(e.name or "");
	if ( name == "defense" ) then return "Rises when enemies attack you, up to 5 per level."; end
	if ( name == "riding" ) then return "A riding trainer teaches the next rank (it needs a level and gold)."; end
	if ( name == "lockpicking" ) then return "Rises as you pick locks and lockboxes, up to 5 per level."; end
	if ( name == "poisons" ) then return "Rises as you make poisons; the rogue trainer teaches new ones."; end
	return RAISE[e.section or ""] or "";
end

----------------------------------------------------------------------------------------------------------------------
-- The window
----------------------------------------------------------------------------------------------------------------------
if ( not CreateFrame ) then return; end   -- tests load only the logic

local WIDTH, HEIGHT = 730, 500;
local DOLL_WIDTH = 480;
local MAX_ROWS = 24;
local LIST_WIDTH, LIST_ROWS, ROW_HEIGHT = 430, 17, 24;   -- the list pages (the same as Reputation and Currency)

local frame = CreateFrame("Frame", "TemucraftCharacterFrame", UIParent);
frame:SetWidth(WIDTH); frame:SetHeight(HEIGHT);
frame:SetToplevel(true);
frame:EnableMouse(true);
frame:SetMovable(true);
frame:SetClampedToScreen(true);
frame:Hide();

----------------------------------------------------------------------------------------------------------------------
-- The look: the shared Temucraft window look (TemucraftStyle.lua: the gold border and header over the achievement
-- window's stone, parchment insets with a thin gold edge, the achievement categories' dark bar behind list section
-- headers and their gold highlight). Other files of this window use it through TemucraftCharacter_Panel(parent) (a
-- new inset box), TemucraftCharacter_Inset(frame) and TemucraftCharacter_HeaderBar(row) (a hidden bar behind a list
-- row), which fall back to plain dark boxes without TemucraftStyle.lua.
----------------------------------------------------------------------------------------------------------------------
function TemucraftCharacter_Inset(f)
	if ( TemucraftStyle_Inset ) then
		TemucraftStyle_Inset(f);
	else
		f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } });
		f:SetBackdropColor(0, 0, 0, 0.6);
		f:SetBackdropBorderColor(0.5, 0.45, 0.35, 0.9);
	end
	return f;
end
function TemucraftCharacter_HeaderBar(row)
	local t;
	if ( TemucraftStyle_Bar ) then
		t = TemucraftStyle_Bar(row);
	else
		t = row:CreateTexture(nil, "BACKGROUND");
		t:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Category-Background");
		t:SetTexCoord(0, 0.6640625, 0, 1);
		t:SetAllPoints(row);
	end
	t:Hide();
	return t;
end
-- list rows: the shared gold highlight
function TemucraftCharacter_Highlight(button)
	if ( TemucraftStyle_Highlight ) then return TemucraftStyle_Highlight(button); end
	button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD");
	return button:GetHighlightTexture();
end
local title;
if ( TemucraftStyle_Window ) then
	title = TemucraftStyle_Window(frame, "");
else
	frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } });
	title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	title:SetPoint("TOP", 0, -16);
end
-- not a UI panel (the panel manager would put it back on the left each time): Esc closes it, the place is kept
tinsert(UISpecialFrames, "TemucraftCharacterFrame");

-- the header: the shared gold header with the page's title (the Character and Pet pages: the name in the class
-- colour and "Level 80 ..." under it)
local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
subtitle:SetPoint("TOP", title, "BOTTOM", 0, -3);
local function SetHeader(text, sub, color)
	title:SetText(text or "");
	if ( color ) then title:SetTextColor(color.r, color.g, color.b); else title:SetTextColor(1, 0.82, 0); end
	subtitle:SetText(sub or "");
end

local close = CreateFrame("Button", "TemucraftCharacterFrameCloseButton", frame, "UIPanelCloseButton");
close:SetPoint("TOPRIGHT", -6, -6);

-- where it is: kept per character (TemucraftStore "C", ui.charwin = "x,y", the top left in screen points)
local POS_KEY = "ui.charwin";
local savedX, savedY;
local function Layout()
	local scale = L.FitScale(UIParent:GetWidth(), UIParent:GetHeight(), WIDTH, HEIGHT);
	if ( math.abs(frame:GetScale() - scale) > 0.001 ) then frame:SetScale(scale); end
	if ( not savedX and TemucraftStore_Get ) then savedX, savedY = L.ParsePosition(TemucraftStore_Get("C", POS_KEY)); end
	frame:ClearAllPoints();
	if ( savedX ) then
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", savedX / scale, savedY / scale);
	else
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16 / scale, -104 / scale);
	end
end
local function SavePosition()
	local left, top, scale = frame:GetLeft(), frame:GetTop(), frame:GetScale();
	if ( not left or not top ) then return; end
	savedX, savedY = left * scale, top * scale;
	if ( TemucraftStore_Set ) then TemucraftStore_Set("C", POS_KEY, L.PositionText(savedX, savedY)); end
end

local drag = CreateFrame("Frame", nil, frame);
drag:SetPoint("TOPLEFT", 12, -8); drag:SetPoint("TOPRIGHT", -40, -8); drag:SetHeight(26);
drag:EnableMouse(true);
drag:RegisterForDrag("LeftButton");
drag:SetScript("OnDragStart", function() frame:StartMoving(); end);
drag:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SavePosition(); end);

-- the dark box every page uses (the stats panel, the lists, the details)
local function Panel(parent)
	return TemucraftCharacter_Inset(CreateFrame("Frame", nil, parent));
end
TemucraftCharacter_Panel = Panel;

-- a page: a frame over the whole window, shown while its tab is picked
local function NewPage(name)
	local p = CreateFrame("Frame", name, frame);
	p:SetAllPoints(frame);
	p:Hide();
	return p;
end

-- a model that turns with the mouse and zooms with the wheel
local function Model(name, parent)
	local m = CreateFrame("PlayerModel", name, parent);
	m:SetAllPoints();
	m:EnableMouse(true);
	m:EnableMouseWheel(true);
	m.zoom = 0;
	m:SetScript("OnMouseDown", function(self, button) if ( button == "LeftButton" ) then self.turning = GetCursorPosition(); end end);
	m:SetScript("OnMouseUp", function(self) self.turning = nil; end);
	m:SetScript("OnUpdate", function(self)
		if ( not self.turning ) then return; end
		local x = GetCursorPosition();
		self:SetFacing(self:GetFacing() + (x - self.turning) * 0.02);
		self.turning = x;
	end);
	m:SetScript("OnMouseWheel", function(self, delta)
		self.zoom = max(0, min(2, self.zoom + delta * 0.25));
		self:SetPosition(self.zoom, 0, 0);
	end);
	m.Reset = function(self) self.zoom = 0; self:SetPosition(0, 0, 0); end;
	local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
	hint:SetPoint("BOTTOM", 0, 4);
	hint:SetText("Drag to turn, wheel to zoom");
	return m;
end

-- the stats panel on the right of the Character and Pet pages: a headline (item level, happiness) and the sections
local function StatsPanel(parent)
	local stats = Panel(parent);
	stats:SetPoint("TOPLEFT", DOLL_WIDTH + 10, -60);
	stats:SetPoint("BOTTOMRIGHT", -16, 16);
	stats.big = stats:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge");
	stats.big:SetPoint("TOP", 0, -12);
	stats.label = stats:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
	stats.label:SetPoint("TOP", stats.big, "BOTTOM", 0, -2);
	stats.rows = {};
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
		r.header = TemucraftCharacter_HeaderBar(r);
		r:Hide();
		stats.rows[i] = r;
	end
	-- sections: L.Sections / L.PetSections; big, label, r, g, b: the headline
	function stats:Fill(sections, big, label, cr, cg, cb)
		self.big:SetText(big or "");
		self.big:SetTextColor(cr or 1, cg or 0.82, cb or 0);
		self.label:SetText(label or "");
		local n, y = 0, -46;
		for _, section in ipairs(sections) do
			if ( n < MAX_ROWS ) then
				n = n + 1;
				local r = self.rows[n];
				r:SetPoint("TOP", self, "TOP", 0, y - 6);
				r.label:SetFontObject(GameFontNormal); r.label:SetText(section.title);
				r.value:SetText("");
				r.band:SetTexture(0, 0, 0, 0);
				r.header:Show();
				r:Show();
				y = y - 24;
			end
			for i, row in ipairs(section.rows) do
				if ( n < MAX_ROWS ) then
					n = n + 1;
					local r = self.rows[n];
					r:SetPoint("TOP", self, "TOP", 0, y);
					r.label:SetFontObject(GameFontHighlightSmall); r.label:SetText(row[1]);
					r.value:SetText(row[2]);
					r.header:Hide();
					if ( i % 2 == 1 ) then r.band:SetTexture(1, 1, 1, 0.05); else r.band:SetTexture(0, 0, 0, 0); end
					r:Show();
					y = y - 16;
				end
			end
			y = y - 6;
		end
		for i = n + 1, MAX_ROWS do self.rows[i]:Hide(); end
	end
	return stats;
end

----------------------------------------------------------------------------------------------------------------------
-- Character page
----------------------------------------------------------------------------------------------------------------------
local charPage = NewPage("TemucraftCharacterPaperDoll");

-- the model on the race's backdrop (the stock dress-up art, in 4 pieces)
local doll = CreateFrame("Frame", nil, charPage);
doll:SetPoint("TOPLEFT", 66, -60);
doll:SetWidth(DOLL_WIDTH - 112); doll:SetHeight(340);
TemucraftCharacter_Inset(doll);
-- the race's dress-up art inside an inset box (4 pieces, like the stock dress-up frame)
local function RaceBackdrop(box)
	local list = {};
	local w, h = box:GetWidth() - 8, box:GetHeight() - 8;
	for i, piece in ipairs({ { 0, 0, 0.8, 0.67 }, { 0.8, 0, 0.2, 0.67 }, { 0, 0.67, 0.8, 0.33 }, { 0.8, 0.67, 0.2, 0.33 } }) do
		local t = box:CreateTexture(nil, "BORDER");
		t:SetPoint("TOPLEFT", box, "TOPLEFT", 4 + piece[1] * w, -4 - piece[2] * h);
		t:SetWidth(piece[3] * w); t:SetHeight(piece[4] * h);
		t:SetAlpha(0.75);
		list[i] = t;
	end
	return list;
end
local backdrop = RaceBackdrop(doll);
local STOCK_RACES = { Human = true, Dwarf = true, NightElf = true, Gnome = true, Draenei = true, Orc = true, Scourge = true,
	Tauren = true, Troll = true, BloodElf = true };
local function SetBackdropRace(list)
	local _, race = UnitRace("player");
	for i, t in ipairs(list) do
		-- other races: their own art if a patch has it (SetTexture fails without), else the human one
		if ( not (race and STOCK_RACES[race]) and t:SetTexture("Interface\\DressUpFrame\\DressUpBackground-"..(race or "")..i) ) then
			-- found
		else
			t:SetTexture("Interface\\DressUpFrame\\DressUpBackground-"..((race and STOCK_RACES[race]) and race or "Human")..i);
		end
	end
end
local model = Model("TemucraftCharacterModel", doll);
local charStats = StatsPanel(charPage);

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

local function UpdateCharacter()
	local _, class = UnitClass("player");
	charStats:Fill(L.Sections(Read(), L.Role(class, TopTree())), format("%.1f", ItemLevel()), "Item Level (equipped)", 0.64, 0.21, 0.93);
end

local function CharacterHeader()
	local className, class = UnitClass("player");
	local tree = TopTree();
	local treeName = tree and GetTalentTabInfo(tree);
	return UnitPVPName("player"), format("Level %d %s%s", UnitLevel("player"), treeName and (treeName.." ") or "", className or ""),
		RAID_CLASS_COLORS and RAID_CLASS_COLORS[class];
end

-- the stock slots, the equipment flyout and the equipment manager come into this page while it is open
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
			if ( b ) then Save(b); b:SetParent(charPage); end
		end
	end
	for _, name in ipairs({ "CharacterAmmoSlot", "PaperDollFrameItemFlyout", "GearManagerDialog", "GearManagerToggleButton" }) do
		local f = _G[name];
		if ( f ) then Save(f); f:SetParent(charPage); end
	end
	CharacterHeadSlot:ClearAllPoints(); CharacterHeadSlot:SetPoint("TOPLEFT", charPage, "TOPLEFT", 20, -60);
	CharacterHandsSlot:ClearAllPoints(); CharacterHandsSlot:SetPoint("TOPRIGHT", charPage, "TOPLEFT", DOLL_WIDTH - 6, -60);
	CharacterMainHandSlot:ClearAllPoints(); CharacterMainHandSlot:SetPoint("BOTTOMRIGHT", charPage, "BOTTOMLEFT", DOLL_WIDTH / 2 - 22, 22);
	if ( UnitHasRelicSlot("player") ) then CharacterAmmoSlot:Hide(); else CharacterAmmoSlot:Show(); end
	if ( GearManagerDialog ) then
		GearManagerDialog:ClearAllPoints(); GearManagerDialog:SetPoint("TOPLEFT", frame, "TOPRIGHT", -6, -10);
	end
	if ( GearManagerToggleButton ) then
		GearManagerToggleButton:ClearAllPoints(); GearManagerToggleButton:SetPoint("LEFT", TemucraftCharacterTitleButton, "RIGHT", 4, 0);
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
local titleMenu = CreateFrame("Frame", "TemucraftCharacterTitleMenu", charPage, "UIDropDownMenuTemplate");
local titleButton = CreateFrame("Button", "TemucraftCharacterTitleButton", charPage, "UIPanelButtonTemplate");
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

charPage:SetScript("OnShow", function()
	SetBackdropRace(backdrop);
	model:SetUnit("player");
	model:Reset();
	Borrow();
	UpdateCharacter();
end);
charPage:SetScript("OnHide", GiveBack);

----------------------------------------------------------------------------------------------------------------------
-- Pet page
----------------------------------------------------------------------------------------------------------------------
local petPage = NewPage("TemucraftCharacterPetPage");
local petBox = Panel(petPage);
petBox:SetPoint("TOPLEFT", 20, -60);
petBox:SetWidth(DOLL_WIDTH - 26); petBox:SetHeight(340);
local petBackdrop = RaceBackdrop(petBox);
local petModel = Model("TemucraftCharacterPetModel", petBox);
local petStats = StatsPanel(petPage);

local happyIcon = petPage:CreateTexture(nil, "ARTWORK");
happyIcon:SetWidth(24); happyIcon:SetHeight(24);
happyIcon:SetPoint("TOPLEFT", petBox, "BOTTOMLEFT", 2, -8);
happyIcon:SetTexture("Interface\\PetPaperDollFrame\\UI-PetHappiness");
local happyText = petPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
happyText:SetPoint("LEFT", happyIcon, "RIGHT", 6, 0);
local petXp = CreateFrame("StatusBar", "TemucraftCharacterPetXP", petPage);
petXp:SetPoint("TOPLEFT", petBox, "BOTTOMLEFT", 2, -42);
petXp:SetWidth(DOLL_WIDTH - 30); petXp:SetHeight(14);
petXp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
petXp:SetStatusBarColor(0.58, 0.0, 0.55);
petXp.bg = petXp:CreateTexture(nil, "BACKGROUND");
petXp.bg:SetAllPoints(); petXp.bg:SetTexture(0, 0, 0, 0.5);
petXp.text = petXp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
petXp.text:SetPoint("CENTER", 0, 1);

local HAPPY_COORDS = { { 0.375, 0.5625 }, { 0.1875, 0.375 }, { 0, 0.1875 } };
local HAPPY_COLORS = { { 1, 0.1, 0.1 }, { 1, 0.82, 0 }, { 0.1, 1, 0.1 } };

local function ReadPet()
	local s = {};
	s.str, s.agi, s.sta, s.int, s.spi = select(2, UnitStat("pet", 1)), select(2, UnitStat("pet", 2)),
		select(2, UnitStat("pet", 3)), select(2, UnitStat("pet", 4)), select(2, UnitStat("pet", 5));
	s.armor = select(2, UnitArmor("pet"));
	local base, pos, neg = UnitAttackPower("pet");
	s.ap = (base or 0) + (pos or 0) + (neg or 0);
	s.minDamage, s.maxDamage = UnitDamage("pet");
	s.speed = UnitAttackSpeed("pet");
	s.sp = GetPetSpellBonusDamage and GetPetSpellBonusDamage() or 0;
	s.fire, s.nature, s.frost, s.shadow, s.arcane = select(2, UnitResistance("pet", 2)), select(2, UnitResistance("pet", 3)),
		select(2, UnitResistance("pet", 4)), select(2, UnitResistance("pet", 5)), select(2, UnitResistance("pet", 6));
	s.talentPoints = GetUnspentTalentPoints and GetUnspentTalentPoints(false, true) or 0;
	return s;
end

local function UpdatePet()
	if ( not UnitExists("pet") ) then return; end
	local happiness, damage = GetPetHappiness();
	local big, label, color;
	if ( happiness and HAPPY_COORDS[happiness] ) then
		local c = HAPPY_COORDS[happiness];
		happyIcon:SetTexCoord(c[1], c[2], 0, 0.359375);
		happyIcon:Show();
		big = _G["PET_HAPPINESS"..happiness] or ({ "Unhappy", "Content", "Happy" })[happiness];
		color = HAPPY_COLORS[happiness];
		label = "Happiness";
		happyText:SetText(format("%s: your pet does %d%% damage", big, damage or 100));
	else
		happyIcon:Hide();
		happyText:SetText("");
		big, label = UnitCreatureFamily("pet") or UnitCreatureType("pet") or "", "";
	end
	petStats:Fill(L.PetSections(ReadPet()), big, label, color and color[1], color and color[2], color and color[3]);
	local cur, need = GetPetExperience();
	if ( need and need > 0 ) then
		petXp:SetMinMaxValues(0, need);
		petXp:SetValue(cur or 0);
		petXp.text:SetText(format("%s %d / %d", XP or "XP", cur or 0, need));
		petXp:Show();
	else
		petXp:Hide();
	end
end

local function PetHeader()
	local family = UnitCreatureFamily("pet") or UnitCreatureType("pet") or "";
	return UnitName("pet") or (PET or "Pet"), format("Level %d %s", UnitLevel("pet") or 0, family), nil;
end

petPage:SetScript("OnShow", function()
	SetBackdropRace(petBackdrop);
	petModel:SetUnit("pet");
	petModel:Reset();
	UpdatePet();
end);

----------------------------------------------------------------------------------------------------------------------
-- Skills: TemucraftSkills_Build(parent [, name]) puts the list (left) and the details (right) in parent, in the
-- layout of the Reputation and Currency pages. Returns { Update = func } (it also updates itself when shown and on
-- SKILL_LINES_CHANGED). The sections, icons and rank text are the spellbook's (TemucraftSpellBookLogic).
----------------------------------------------------------------------------------------------------------------------
-- the skill lines (every heading opened first: the client lists only the lines under open ones), as sections
function TemucraftSkills_Read()
	local SB = TemucraftSpellBookLogic;
	if ( not SB or not SB.SkillSections ) then return {}; end
	for i = GetNumSkillLines(), 1, -1 do
		local _, header, expanded = GetSkillLineInfo(i);
		if ( header and not expanded ) then ExpandSkillHeader(i); end
	end
	local lines, abandon = {}, {};
	for i = 1, GetNumSkillLines() do
		local name, header, _, rank, _, modifier, maxRank, abandonable, _, _, _, _, description = GetSkillLineInfo(i);
		if ( name ) then
			table.insert(lines, { name = name, header = header and true or false, rank = rank, max = maxRank,
				modifier = modifier, description = description });
			if ( not header and abandonable ) then abandon[name] = true; end
		end
	end
	local treeIcons = {};
	for t = 1, GetNumTalentTabs() do
		local name, icon = GetTalentTabInfo(t);
		if ( name ) then treeIcons[string.lower(name)] = icon; end
	end
	local sections = SB.SkillSections(lines, treeIcons);
	for _, s in ipairs(sections) do
		for _, e in ipairs(s.entries) do e.abandonable = abandon[e.name] or false; end
	end
	return sections;
end

local function SkillIndex(name)
	for i = 1, GetNumSkillLines() do
		if ( GetSkillLineInfo(i) == name ) then return i; end
	end
	return nil;
end

StaticPopupDialogs["TEMUCRAFT_UNLEARN_SKILL"] = {
	text = UNLEARN_SKILL or "Do you really want to unlearn %s?",
	button1 = OKAY, button2 = CANCEL,
	OnAccept = function(self, name)
		local i = name and SkillIndex(name);
		if ( i ) then AbandonSkill(i); end
	end,
	timeout = 0, whileDead = 1, hideOnEscape = 1, exclusive = 1,
};

local function RankText(e)
	local SB = TemucraftSpellBookLogic;
	if ( SB and SB.SkillRankText ) then return SB.SkillRankText(e); end
	return e.rank and (e.rank.." / "..e.max) or "";
end

local SKILL_BAR_COLOR = { 0.1, 0.35, 0.85 };   -- the spellbook's Skills bars

function TemucraftSkills_Build(parent, name)
	name = name or ((parent:GetName() or "TemucraftSkills").."List");
	local obj = {};
	local collapsed, selectedName, sections = {}, nil, {};

	local listBox = Panel(parent);
	listBox:SetPoint("TOPLEFT", 16, -64);
	listBox:SetWidth(LIST_WIDTH); listBox:SetHeight(LIST_ROWS * ROW_HEIGHT + 12);
	local detail = Panel(parent);
	detail:SetPoint("TOPLEFT", listBox, "TOPRIGHT", 8, 0);
	detail:SetPoint("BOTTOMRIGHT", -16, 24);
	local scroll = CreateFrame("ScrollFrame", name.."Scroll", listBox, "FauxScrollFrameTemplate");
	scroll:SetPoint("TOPLEFT", 6, -6);
	scroll:SetPoint("BOTTOMRIGHT", -28, 6);

	local rows = {};
	for i = 1, LIST_ROWS do
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
		b.bar = CreateFrame("StatusBar", nil, b);
		b.bar:SetWidth(150); b.bar:SetHeight(14);
		b.bar:SetPoint("RIGHT", -4, 0);
		b.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
		b.bar:SetStatusBarColor(SKILL_BAR_COLOR[1], SKILL_BAR_COLOR[2], SKILL_BAR_COLOR[3]);
		b.bar.bg = b.bar:CreateTexture(nil, "BACKGROUND");
		b.bar.bg:SetAllPoints(); b.bar.bg:SetTexture(0, 0, 0, 0.5);
		b.bar.text = b.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		b.bar.text:SetPoint("CENTER", 0, 1);
		b.count = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
		b.count:SetPoint("RIGHT", -8, 0);
		b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		b.name:SetJustifyH("LEFT");
		b.header = TemucraftCharacter_HeaderBar(b);
		TemucraftCharacter_Highlight(b);
		b:SetScript("OnEnter", function(self)
			local e = self.line and self.line.entry;
			if ( not e ) then return; end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetText(e.name);
			if ( e.rank ) then GameTooltip:AddLine("Skill "..RankText(e), 1, 1, 1); end
			if ( e.description and e.description ~= "" ) then GameTooltip:AddLine(e.description, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true); end
			GameTooltip:Show();
		end);
		b:SetScript("OnLeave", function() GameTooltip:Hide(); end);
		b:SetScript("OnClick", function(self)
			local line = self.line;
			if ( not line ) then return; end
			if ( line.kind == "group" ) then
				collapsed[line.key] = not collapsed[line.key] or nil;
				PlaySound(collapsed[line.key] and "igMainMenuOptionCheckBoxOff" or "igMainMenuOptionCheckBoxOn");
			else
				selectedName = line.name;
				PlaySound("igMainMenuOptionCheckBoxOn");
			end
			obj.Draw();
		end);
		rows[i] = b;
	end

	-- the details
	local dIcon = detail:CreateTexture(nil, "ARTWORK");
	dIcon:SetWidth(40); dIcon:SetHeight(40);
	dIcon:SetPoint("TOPLEFT", 12, -12);
	local dName = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	dName:SetPoint("TOPLEFT", dIcon, "TOPRIGHT", 8, -2); dName:SetPoint("RIGHT", -12, 0);
	dName:SetJustifyH("LEFT");
	local dSection = detail:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
	dSection:SetPoint("TOPLEFT", dName, "BOTTOMLEFT", 0, -4);
	local dBar = CreateFrame("StatusBar", nil, detail);
	dBar:SetPoint("TOPLEFT", dIcon, "BOTTOMLEFT", 0, -12);
	dBar:SetPoint("RIGHT", -12, 0);
	dBar:SetHeight(16);
	dBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
	dBar:SetStatusBarColor(SKILL_BAR_COLOR[1], SKILL_BAR_COLOR[2], SKILL_BAR_COLOR[3]);
	local dBarBg = dBar:CreateTexture(nil, "BACKGROUND");
	dBarBg:SetAllPoints(); dBarBg:SetTexture(0, 0, 0, 0.5);
	dBar.text = dBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	dBar.text:SetPoint("CENTER", 0, 1);
	local dDesc = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	dDesc:SetPoint("TOPLEFT", dBar, "BOTTOMLEFT", 0, -12);
	dDesc:SetPoint("RIGHT", -12, 0);
	dDesc:SetJustifyH("LEFT"); dDesc:SetJustifyV("TOP");
	local dHowTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	dHowTitle:SetPoint("TOPLEFT", dDesc, "BOTTOMLEFT", 0, -14);
	dHowTitle:SetText("How to raise it");
	local dHow = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	dHow:SetPoint("TOPLEFT", dHowTitle, "BOTTOMLEFT", 0, -6);
	dHow:SetPoint("RIGHT", -12, 0);
	dHow:SetJustifyH("LEFT"); dHow:SetJustifyV("TOP");
	local dNone = detail:CreateFontString(nil, "OVERLAY", "GameFontDisable");
	dNone:SetPoint("CENTER");
	dNone:SetText("Select a skill");
	local unlearn = CreateFrame("Button", name.."Unlearn", detail, "UIPanelButtonTemplate");
	unlearn:SetWidth(130); unlearn:SetHeight(22);
	unlearn:SetPoint("BOTTOM", 0, 16);
	unlearn:SetText(UNLEARN or "Unlearn");
	unlearn:SetScript("OnClick", function()
		if ( not selectedName ) then return; end
		local dialog = StaticPopup_Show("TEMUCRAFT_UNLEARN_SKILL", selectedName);
		if ( dialog ) then dialog.data = selectedName; end
	end);

	local function UpdateDetail(e)
		local shown = e ~= nil;
		for _, w in ipairs({ dIcon, dName, dSection, dDesc, dHowTitle, dHow }) do if ( shown ) then w:Show(); else w:Hide(); end end
		if ( not shown ) then dNone:Show(); dBar:Hide(); unlearn:Hide(); return; end
		dNone:Hide();
		dIcon:SetTexture(e.icon);
		dName:SetText(e.name);
		dSection:SetText(e.section or "");
		if ( e.rank ) then
			dBar:SetMinMaxValues(0, max(1, e.max));
			dBar:SetValue(min(e.max, e.rank));
			dBar.text:SetText(RankText(e));
			dBar:Show();
			dDesc:SetPoint("TOPLEFT", dBar, "BOTTOMLEFT", 0, -12);
		else
			dBar:Hide();
			dDesc:SetPoint("TOPLEFT", dIcon, "BOTTOMLEFT", 0, -12);
		end
		dDesc:SetText((e.description and e.description ~= "") and e.description or " ");
		local how = L.SkillHelp(e);
		dHow:SetText(how);
		if ( how == "" ) then dHowTitle:Hide(); end
		if ( e.abandonable ) then unlearn:Show(); else unlearn:Hide(); end
	end

	-- the list from what was read last (clicks), Update reads it again first
	function obj.Draw()
		local lines = L.SkillLines(sections, collapsed);
		FauxScrollFrame_Update(scroll, #lines, LIST_ROWS, ROW_HEIGHT);
		local offset = FauxScrollFrame_GetOffset(scroll);
		local selected;
		for _, s in ipairs(sections) do
			for _, e in ipairs(s.entries) do if ( e.name == selectedName ) then selected = e; end end
		end
		for i, b in ipairs(rows) do
			local line = lines[offset + i];
			b.line = line;
			if ( not line ) then
				b:Hide();
			else
				b.name:ClearAllPoints();
				if ( line.kind == "group" ) then
					b.expand:SetTexture(line.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up");
					b.expand:Show(); b.icon:Hide(); b.bar:Hide();
					b.name:SetPoint("LEFT", b.expand, "RIGHT", 4, 0);
					b.name:SetPoint("RIGHT", b.count, "LEFT", -4, 0);
					b.name:SetFontObject(GameFontNormal);
					b.name:SetText(line.name);
					b.count:SetText(line.collapsed and line.count or "");
					b.band:SetTexture(0, 0, 0, 0);
					b.header:Show();
				else
					local e = line.entry;
					b.header:Hide();
					b.expand:Hide();
					b.icon:SetTexture(e.icon); b.icon:Show();
					b.count:SetText("");
					b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, 0);
					b.name:SetPoint("RIGHT", b.bar, "LEFT", -4, 0);
					b.name:SetFontObject(GameFontHighlightSmall);
					b.name:SetText(e.name);
					if ( e.rank ) then
						b.bar:SetMinMaxValues(0, max(1, e.max));
						b.bar:SetValue(min(e.max, e.rank));
						b.bar.text:SetText(RankText(e));
						b.bar:Show();
					else
						b.bar:Hide();
					end
					if ( e.name == selectedName ) then b.band:SetTexture(0.3, 0.5, 1, 0.25);
					elseif ( (offset + i) % 2 == 0 ) then b.band:SetTexture(1, 1, 1, 0.04);
					else b.band:SetTexture(0, 0, 0, 0); end
				end
				b:Show();
			end
		end
		UpdateDetail(selected);
	end

	function obj.Update()
		if ( not parent:IsVisible() ) then return; end
		sections = TemucraftSkills_Read();
		obj.Draw();
	end

	scroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, obj.Draw); end);
	listBox:EnableMouseWheel(true);
	listBox:SetScript("OnMouseWheel", function(_, delta)
		local bar = _G[name.."ScrollScrollBar"];
		if ( bar ) then bar:SetValue(bar:GetValue() - delta * ROW_HEIGHT * 3); end
	end);
	parent:HookScript("OnShow", obj.Update);
	local events = CreateFrame("Frame", nil, parent);
	events:RegisterEvent("SKILL_LINES_CHANGED");
	local dirty = false;
	events:SetScript("OnEvent", function(self)
		if ( dirty or not parent:IsVisible() ) then return; end
		dirty = true;
		self:SetScript("OnUpdate", function(f)
			f:SetScript("OnUpdate", nil);
			dirty = false;
			obj.Update();
		end);
	end);
	return obj;
end

local skillsPage = NewPage("TemucraftCharacterSkillsPage");
TemucraftSkills_Build(skillsPage, "TemucraftCharacterSkills");

----------------------------------------------------------------------------------------------------------------------
-- Professions page: TemucraftProfGear's two panels (the addon loads after this file)
----------------------------------------------------------------------------------------------------------------------
local profPage = NewPage("TemucraftCharacterProfessionsPage");
profPage:SetScript("OnShow", function(self) if ( TemucraftProfGear_Host ) then TemucraftProfGear_Host(self); end end);
profPage:SetScript("OnHide", function() if ( TemucraftProfGear_Host ) then TemucraftProfGear_Host(nil); end end);

----------------------------------------------------------------------------------------------------------------------
-- The pages and the tabs
----------------------------------------------------------------------------------------------------------------------
local StockToggleCharacter = ToggleCharacter;
TemucraftStockToggleCharacter = StockToggleCharacter;

-- [key] = { panel, title = text or header = func() -> text, sub, color, x; available = func; stockOpen = func }
local pages = {};
local current = "character";

function TemucraftCharacter_AddPage(key, panel, def)
	def = def or {};
	def.panel = panel;
	pages[key] = def;
	panel:SetParent(frame);
	panel:ClearAllPoints();
	panel:SetAllPoints(frame);
	panel:Hide();
end

TemucraftCharacter_AddPage("character", charPage, { header = CharacterHeader });
TemucraftCharacter_AddPage("pet", petPage, { header = PetHeader, available = function() return HasPetUI() and UnitExists("pet"); end });
TemucraftCharacter_AddPage("skills", skillsPage, { title = SKILLS or "Skills" });
TemucraftCharacter_AddPage("prof", profPage, { title = "Professions", available = function() return TemucraftProfGear_Host ~= nil; end,
	stockOpen = function()
		local toggle = TemucraftProfGear_StockToggle or (SlashCmdList and SlashCmdList["TEMUCRAFTPROFGEAR"]);
		if ( toggle ) then toggle(); end
	end });

local function Has(key)
	local p = pages[key];
	return p ~= nil and (not p.available or p.available() and true or false);
end
local function IsClassic(which) return TemucraftUI_IsClassic ~= nil and TemucraftUI_IsClassic(which); end

local function UpdateHeader()
	local p = pages[current];
	if ( not p ) then return; end
	if ( p.header ) then SetHeader(p.header()); else SetHeader(p.title); end
end

-- tabs: shown = the tab is on the strip (a page that isn't there yet can still go to the stock frame)
local TAB_SHOWN = {
	pet = function() return HasPetUI() and true or false; end,
	prof = function() return TemucraftProfGear_Host ~= nil or (SlashCmdList and SlashCmdList["TEMUCRAFTPROFGEAR"] ~= nil); end,
};
local tabs, tabIndex = {}, {};
local function LayoutTabs()
	local last;
	for i, t in ipairs(L.TABS) do
		local tab = tabs[i];
		local shown = TAB_SHOWN[t[1]];
		if ( shown and not shown() ) then
			tab:Hide();
		else
			tab:ClearAllPoints();
			if ( last ) then tab:SetPoint("LEFT", last, "RIGHT", -16, 0); else tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 20, 8); end
			tab:Show();
			last = tab;
		end
	end
	PanelTemplates_SetTab(frame, tabIndex[current] or 1);
end

local function ShowPage(key)
	current = key;
	for k, p in pairs(pages) do if ( k ~= key ) then p.panel:Hide(); end end
	if ( not frame:IsShown() ) then frame:Show(); end
	pages[key].panel:Show();
	UpdateHeader();
	LayoutTabs();
	if ( UpdateMicroButtons ) then UpdateMicroButtons(); end
end

-- a page in this window (true), or false when its Classic option is on / it isn't there (open the stock one then).
-- toggle: closes the window when that page is already open.
function TemucraftCharacter_Open(key, toggle)
	if ( not Has(key) or IsClassic(L.CLASSIC[key] or "char") ) then return false; end
	if ( CharacterFrame and CharacterFrame:IsShown() ) then HideUIPanel(CharacterFrame); end
	if ( toggle and frame:IsShown() and current == key ) then frame:Hide(); return true; end
	ShowPage(key);
	return true;
end

-- the stock frame (or the page's own stock way) for a page this window doesn't show
local function OpenStock(key)
	if ( frame:IsShown() ) then frame:Hide(); end
	local p = pages[key];
	if ( p and p.stockOpen ) then p.stockOpen(); return; end
	StockToggleCharacter(L.STOCK[key] or "PaperDollFrame");
end

for i, t in ipairs(L.TABS) do
	local tab = CreateFrame("Button", "TemucraftCharacterFrameTab"..i, frame, "CharacterFrameTabButtonTemplate");
	tab:SetID(i);
	tab:SetText(_G[string.upper(t[2])] or t[2]);
	if ( t[1] == "character" ) then tab:SetText(CHARACTER or t[2]); end
	tab:SetScript("OnClick", function()
		if ( frame:IsShown() and current == t[1] ) then return; end
		PlaySound("igCharacterInfoTab");
		if ( not TemucraftCharacter_Open(t[1]) ) then OpenStock(t[1]); end
	end);
	tabs[i] = tab;
	tabIndex[t[1]] = i;
end
PanelTemplates_SetNumTabs(frame, #L.TABS);

local function Refresh()
	if ( not frame:IsShown() ) then return; end
	if ( current == "character" ) then UpdateCharacter();
	elseif ( current == "pet" ) then
		if ( not Has("pet") ) then ShowPage("character"); return; end
		UpdatePet();
	end
	UpdateHeader();
end

frame:SetScript("OnShow", function()
	PlaySound("igCharacterInfoOpen");
	Layout();
	if ( UpdateMicroButtons ) then UpdateMicroButtons(); end
	SetButtonPulse(CharacterMicroButton, 0, 1);
end);
frame:SetScript("OnHide", function()
	PlaySound("igCharacterInfoClose");
	-- (the open page's OnHide runs too; both are safe twice)
	if ( next(moved) ) then GiveBack(); end
	if ( current == "prof" and TemucraftProfGear_Host ) then TemucraftProfGear_Host(nil); end
	if ( UpdateMicroButtons ) then UpdateMicroButtons(); end
end);

function TemucraftCharacter_Toggle() TemucraftCharacter_Open("character", true); end

-- C, U, the micro button and the stock frame's tabs (CharacterFrameTab_OnClick calls this too)
function ToggleCharacter(tab, ...)
	local key = L.Route(tab, IsClassic, Has);
	if ( key ~= "stock" and TemucraftCharacter_Open(key, true) ) then return; end
	if ( frame:IsShown() ) then frame:Hide(); end
	return StockToggleCharacter(tab, ...);
end

-- anything else that shows the stock paper doll (the stock frame opened on its last tab): this window instead.
-- Next frame, so that ToggleCharacter("ReputationFrame") has switched the tab by then.
local swap = CreateFrame("Frame");
swap:Hide();
swap:SetScript("OnUpdate", function(self)
	self:Hide();
	if ( PaperDollFrame:IsVisible() and not IsClassic("char") ) then
		HideUIPanel(CharacterFrame);
		ShowPage("character");
	end
end);
PaperDollFrame:HookScript("OnShow", function() if ( not IsClassic("char") ) then swap:Show(); end end);

hooksecurefunc("UpdateMicroButtons", function()
	if ( frame:IsShown() and CharacterMicroButton ) then
		CharacterMicroButton:SetButtonState("PUSHED", 1);
		CharacterMicroButton_SetPushed();
	end
end);

-- a Classic option turned on while its page is open: the stock frame takes over
for _, which in ipairs({ "char", "rep", "currency" }) do
	TemucraftUI_OnChange("classic"..which, function(on)
		if ( not on or not frame:IsShown() or L.CLASSIC[current] ~= which ) then return; end
		local key = current;
		OpenStock(key);
	end);
end

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

-- stat changes (the player's and the pet's), throttled to one update per frame
local events = CreateFrame("Frame");
local dirty = false;
for _, e in ipairs({ "UNIT_INVENTORY_CHANGED", "UNIT_STATS", "UNIT_AURA", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER",
	"UNIT_RESISTANCES", "UNIT_LEVEL", "UNIT_MODEL_CHANGED", "COMBAT_RATING_UPDATE", "PLAYER_TALENT_UPDATE",
	"PLAYER_EQUIPMENT_CHANGED", "UNIT_PET", "UNIT_NAME_UPDATE", "PLAYER_DAMAGE_DONE_MODS", "UNIT_HAPPINESS",
	"UNIT_PET_EXPERIENCE", "PET_UI_UPDATE", "UNIT_ATTACK_SPEED", "UNIT_DAMAGE", "PET_BAR_UPDATE" }) do
	events:RegisterEvent(e);
end
events:SetScript("OnEvent", function(self, event, unit)
	if ( not frame:IsShown() ) then return; end
	if ( event == "UNIT_PET" or event == "PET_UI_UPDATE" or event == "PET_BAR_UPDATE" ) then
		LayoutTabs();
		if ( current == "pet" and petPage:IsShown() and UnitExists("pet") ) then petModel:SetUnit("pet"); end
	elseif ( unit and type(unit) == "string" and string.find(event, "^UNIT_") and unit ~= "player" and unit ~= "pet" ) then
		return;
	elseif ( event == "UNIT_MODEL_CHANGED" ) then
		if ( unit == "pet" ) then petModel:SetUnit("pet"); else model:SetUnit("player"); end
		return;
	end
	if ( not dirty ) then
		dirty = true;
		self:SetScript("OnUpdate", function(f)
			f:SetScript("OnUpdate", nil);
			dirty = false;
			Refresh();
		end);
	end
end);
-- the screen size changed: the scale again
local screen = CreateFrame("Frame");
screen:RegisterEvent("DISPLAY_SIZE_CHANGED");
screen:RegisterEvent("UI_SCALE_CHANGED");
screen:SetScript("OnEvent", function() if ( frame:IsShown() ) then Layout(); end end);
