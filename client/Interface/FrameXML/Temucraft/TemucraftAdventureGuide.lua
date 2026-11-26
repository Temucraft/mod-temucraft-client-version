-- Temucraft Adventure Guide (retail's Encounter Journal for the 3.3.5 client). Tabs Suggested Content / Dungeons /
-- Raids along the bottom; an expansion menu (Classic, Burning Crusade, Wrath of the Lich King, Temucraft) and a search
-- box at the top. Dungeons and Raids show a card per instance (the stock LFG art); a card opens the instance: its
-- overview (description, zone, levels, players), the bosses down the left, and per boss its description, abilities
-- (spell icons, names, tooltips) and loot for the chosen difficulty (item tooltips; shift-click links, ctrl-click
-- the dressing room, click shows it on your character beside the boss model). Suggested Content picks dungeons,
-- raids and zones for your level. Opening it inside an instance shows that instance at its difficulty.
-- The data is TemucraftAdventureGuideData.lua (client/adventureguide/build_adventure_guide.py, from the server's DBCs
-- and world database); instances in TemucraftJournalData (mod-temucraft-journal's .temucraft journal export) that it
-- doesn't have are added under Temucraft. Items the client has never seen are asked from the server once (addon
-- message TAG, mod-temucraft-client-version), boss models with the Collections window's TCC.
-- Open it with the micro menu's Adventure Guide button, /adventure, /ag or /ej (ToggleEncounterJournal).

----------------------------------------------------------------------------------------------------------------------
-- The logic (no frames: tests/adventureguide_test.lua runs it with stubs)
----------------------------------------------------------------------------------------------------------------------
TemucraftAdventureGuideLogic = {};
local L = TemucraftAdventureGuideLogic;

L.TIERS = { "Classic", "Burning Crusade", "Wrath of the Lich King", "Temucraft" };
L.DUNGEON, L.RAID = 1, 2;
L.INVTYPE = { "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_BODY", "INVTYPE_CHEST", "INVTYPE_WAIST",
	"INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_WEAPON",
	"INVTYPE_SHIELD", "INVTYPE_RANGED", "INVTYPE_CLOAK", "INVTYPE_2HWEAPON", "INVTYPE_BAG", "INVTYPE_TABARD", "INVTYPE_ROBE",
	"INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_HOLDABLE", "INVTYPE_AMMO", "INVTYPE_THROWN",
	"INVTYPE_RANGEDRIGHT", "INVTYPE_QUIVER", "INVTYPE_RELIC" };
L.SLOT_EN = { "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands", "Finger", "Trinket",
	"One-Hand", "Off Hand", "Ranged", "Back", "Two-Hand", "Bag", "Tabard", "Chest", "Main Hand", "Off Hand", "Held In Off-hand",
	"Projectile", "Thrown", "Ranged", "Quiver", "Relic" };
-- item class -> subclass -> name, for items the client hasn't cached (GetItemInfo's own text wins when it has it)
L.SUBCLASS = {
	[2] = { [0] = "Axe", "Axe", "Bow", "Gun", "Mace", "Mace", "Polearm", "Sword", "Sword", nil, "Staff", nil, nil, "Fist Weapon",
		nil, "Dagger", "Thrown", nil, "Crossbow", "Wand", "Fishing Pole" },
	[4] = { [0] = "Miscellaneous", "Cloth", "Leather", "Mail", "Plate", nil, "Shield", "Libram", "Idol", "Totem", "Sigil" },
};
L.CLASS = { [0] = "Consumable", "Container", "Weapon", "Gem", "Armor", "Reagent", "Projectile", "Trade Goods", nil, "Recipe",
	nil, "Quiver", "Quest", "Key", nil, "Miscellaneous", "Glyph" };

function L.Data() return TEMUCRAFT_ADVENTURE_GUIDE or { instances = {}, items = {}, zones = {} }; end
function L.Key(inst) return inst.key or inst.id; end

-- the instances of one kind (1 dungeon, 2 raid) in one tier, in the data's order (by level)
function L.List(data, kind, tier)
	local out = {};
	for _, inst in ipairs(data.instances or {}) do
		if ( inst.kind == kind and (not tier or inst.tier == tier) ) then table.insert(out, inst); end
	end
	return out;
end

-- the tiers that have instances of this kind
function L.Tiers(data, kind)
	local have, out = {}, {};
	for _, inst in ipairs(data.instances or {}) do if ( inst.kind == kind ) then have[inst.tier] = true; end end
	for t = 1, #L.TIERS do if ( have[t] ) then table.insert(out, t); end end
	return out;
end

function L.TierForLevel(level)
	if ( level <= 60 ) then return 1; elseif ( level <= 70 ) then return 2; end
	return 3;
end

-- name of a difficulty row { difficulty, players, min, max, heroic }
function L.DiffLabel(inst, row)
	if ( not row ) then return ""; end
	if ( inst.kind == L.DUNGEON ) then return row[5] == 1 and "Heroic" or "Normal"; end
	return row[2].." Player"..(row[5] == 1 and " (Heroic)" or "");
end

function L.LevelText(lo, hi)
	if ( not lo or lo <= 0 ) then return ""; end
	if ( not hi or hi <= lo ) then return "Level "..lo; end
	return "Levels "..lo.."-"..hi;
end

function L.DiffRow(inst, difficulty)
	for _, row in ipairs(inst.diffs or {}) do if ( row[1] == difficulty ) then return row; end end
	return inst.diffs and inst.diffs[1];
end

-- the row of the instance that suits this level best (nil if none does): within its levels (one below, two above)
function L.BestRow(inst, level)
	local best, score = nil, nil;
	for _, row in ipairs(inst.diffs or {}) do
		local lo, hi = row[3], row[4];
		if ( lo > 0 and level >= lo - 1 and level <= hi + 2 ) then
			local s = math.abs(level - (lo + hi) / 2);
			if ( not score or s < score ) then best, score = row, s; end
		end
	end
	return best, score;
end

-- Suggested Content: up to max entries, dungeons, zones and raids for this level taken in turn, each list closest first.
-- faction: "Horde" / "Alliance" (zones of the other faction are left out)
function L.Suggest(data, level, faction, max)
	max = max or 6;
	local lists = { {}, {}, {} };   -- dungeons, zones, raids
	for _, inst in ipairs(data.instances or {}) do
		local row, score = L.BestRow(inst, level);
		if ( row ) then
			table.insert(lists[inst.kind == L.RAID and 3 or 1], { kind = inst.kind == L.RAID and "raid" or "dungeon", inst = inst,
				diff = row[1], name = inst.name, levels = L.LevelText(row[3], row[4]), score = score });
		end
	end
	local f = (faction == "Horde" and 0) or (faction == "Alliance" and 1) or nil;
	for _, z in ipairs(data.zones or {}) do
		local name, lo, hi, side = z[1], z[2], z[3], z[4];
		if ( level >= lo - 1 and level <= hi + 1 and (side == -1 or f == nil or side == f) ) then
			table.insert(lists[2], { kind = "zone", name = name, levels = L.LevelText(lo, hi), score = math.abs(level - (lo + hi) / 2), zone = z });
		end
	end
	for _, list in ipairs(lists) do
		table.sort(list, function(a, b) if ( a.score ~= b.score ) then return a.score < b.score; end return a.name < b.name; end);
	end
	local out, i = {}, 1;
	while ( #out < max ) do
		local added = false;
		for _, list in ipairs(lists) do
			if ( list[i] and #out < max ) then table.insert(out, list[i]); added = true; end
		end
		if ( not added ) then break; end
		i = i + 1;
	end
	return out;
end

-- instances (of a kind, any tier) whose name, zone or a boss's name has every word of the query
function L.Search(data, kind, query)
	local out = {};
	query = string.lower(query or "");
	for _, inst in ipairs(data.instances or {}) do
		if ( inst.kind == kind ) then
			local text = string.lower(inst.name.." "..(inst.zone or ""));
			for _, b in ipairs(inst.bosses or {}) do text = text.." "..string.lower(b.name); end
			local ok = true;
			for word in string.gmatch(query, "%S+") do
				if ( not string.find(text, word, 1, true) ) then ok = false; break; end
			end
			if ( ok ) then table.insert(out, inst); end
		end
	end
	return out;
end

-- the instance with this name (GetInstanceInfo's), and its difficulty from the client's difficulty index (1-based)
function L.FindByName(data, name, difficultyIndex)
	if ( not name or name == "" ) then return nil; end
	local lower = string.lower(name);
	for _, inst in ipairs(data.instances or {}) do
		if ( string.lower(inst.name) == lower and not inst.key ) then
			local d = (difficultyIndex or 1) - 1;
			return inst, L.DiffRow(inst, d) and L.DiffRow(inst, d)[1] or 0;
		end
	end
	return nil;
end

-- a boss's loot for a difficulty; with no boss, every boss's loot (each item once)
function L.Loot(inst, boss, difficulty)
	if ( boss ) then return (boss.loot and boss.loot[difficulty]) or {}; end
	local out, seen = {}, {};
	for _, b in ipairs(inst.bosses or {}) do
		for _, id in ipairs((b.loot and b.loot[difficulty]) or {}) do
			if ( not seen[id] ) then seen[id] = true; table.insert(out, id); end
		end
	end
	return out;
end

-- slot and type line of an item: "Head, Plate". row = data.items[id] = { quality, invtype, class, subclass, ilvl, name };
-- subType: GetItemInfo's localized subclass (or nil); globals: _G (for the client's INVTYPE_ strings)
function L.SlotText(row, subType, globals)
	if ( not row ) then return subType or ""; end
	local inv, class, sub = row[2], row[3], row[4];
	local slot = "";
	if ( inv and inv > 0 and L.INVTYPE[inv] ) then slot = (globals and globals[L.INVTYPE[inv]]) or L.SLOT_EN[inv] or ""; end
	local kind = subType;
	if ( not kind or kind == "" ) then kind = (L.SUBCLASS[class] and L.SUBCLASS[class][sub]) or L.CLASS[class] or ""; end
	if ( class == 4 and (sub == 0 or inv == 2 or inv == 11 or inv == 12 or inv == 16 or inv == 23) ) then kind = ""; end
	if ( slot ~= "" and kind ~= "" and kind ~= slot ) then return slot..", "..kind; end
	return slot ~= "" and slot or kind;
end

-- a boss's line when the data has no description: title and level
function L.BossLine(boss)
	local parts = {};
	if ( boss.subname and boss.subname ~= "" ) then table.insert(parts, boss.subname); end
	if ( boss.level and boss.level > 0 ) then table.insert(parts, "Level "..boss.level); end
	return table.concat(parts, ". ");
end

-- ids as comma lists of at most maxLen characters / maxCount ids (each once, no 0): the TAG messages
function L.Chunks(ids, maxLen, maxCount)
	local out, cur, n, seen = {}, "", 0, {};
	for _, id in ipairs(ids) do
		if ( id and id > 0 and not seen[id] ) then
			seen[id] = true;
			local s = tostring(id);
			if ( cur ~= "" and (#cur + 1 + #s > maxLen or n >= maxCount) ) then table.insert(out, cur); cur, n = "", 0; end
			cur = (cur == "" and s) or (cur..","..s);
			n = n + 1;
		end
	end
	if ( cur ~= "" ) then table.insert(out, cur); end
	return out;
end

-- add mod-temucraft-journal's export (TemucraftJournalData: { map, name, raid, exp, diff mask, bosses = { name, npc,
-- loot[difficulty] } }) for maps the data doesn't have, under Temucraft. Returns how many were added.
function L.MergeJournal(data, journal)
	if ( type(journal) ~= "table" ) then return 0; end
	local have, added = {}, 0;
	for _, inst in ipairs(data.instances) do if ( not inst.key ) then have[inst.id] = true; end end
	for _, j in ipairs(journal) do
		if ( j.map and not have[j.map] and j.bosses and #j.bosses > 0 ) then
			local kind = j.raid and L.RAID or L.DUNGEON;
			local diffs = {};
			for d = 0, 3 do
				if ( (j.diff or 1) % (2 ^ (d + 1)) >= 2 ^ d ) then
					local heroic = (kind == L.DUNGEON and d == 1) or (kind == L.RAID and d >= 2);
					table.insert(diffs, { d, kind == L.RAID and ((d % 2 == 1) and 25 or 10) or 5, 0, 0, heroic and 1 or 0 });
				end
			end
			if ( #diffs == 0 ) then diffs = { { 0, kind == L.RAID and 10 or 5, 0, 0, 0 } }; end
			local bosses = {};
			for _, b in ipairs(j.bosses) do
				table.insert(bosses, { name = b.name or "?", npc = b.npc or 0, level = 0, subname = "", desc = "", spells = {}, loot = b.loot or {} });
			end
			table.insert(data.instances, { id = j.map, name = j.name or ("Map "..j.map), kind = kind, tier = 4, min = 0, max = 0, rec = 0,
				zone = "", icon = "", bg = "", diffs = diffs, desc = "", bosses = bosses, journal = true });
			have[j.map] = true;
			added = added + 1;
		end
	end
	return added;
end

-- pages of a list
function L.Pages(count, perPage) return math.max(1, math.ceil(count / perPage)); end

if ( not CreateFrame ) then return; end   -- tests load only the logic

----------------------------------------------------------------------------------------------------------------------
-- The window
----------------------------------------------------------------------------------------------------------------------
local WIDTH, HEIGHT = 820, 560;
local CARD_W, CARD_H, CARD_COLS, CARD_ROWS = 252, 128, 3, 3;
local LOOT_ROWS, LOOT_H = 9, 42;
local BG = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-";
local ICON = "Interface\\LFGFrame\\LFGIcon-";
local S = {   -- state
	tab = 1, tier = nil, page = 1, query = "", inst = nil, boss = nil, diff = 0, sub = 1, lootOffset = 0,
	merged = false, suggestions = {},
};
local UI = {};   -- frames

local function Art(inst)
	return BG..((inst and inst.bg ~= "" and inst.bg) or "GENERICDUNGEON");
end
local function IconOf(inst)
	if ( inst and inst.icon ~= "" ) then return ICON..inst.icon; end
	return ICON..((inst and inst.kind == L.RAID) and "Raid" or "Dungeon");
end

local function Data()
	local data = L.Data();
	if ( not S.merged ) then
		S.merged = true;
		if ( not data.instances ) then data.instances = {}; end
		L.MergeJournal(data, TemucraftJournalData);
	end
	return data;
end

-- ask the server (addon message TAG) for items the client hasn't cached, so tooltips and links work; each id once a
-- session, four messages a second
local askedItems, itemQueue = {}, {};
local itemSender = CreateFrame("Frame");
itemSender:Hide();
itemSender.wait = 0;
itemSender:SetScript("OnUpdate", function(self, elapsed)
	self.wait = self.wait + elapsed;
	if ( self.wait < 0.25 ) then return; end
	self.wait = 0;
	local msg = table.remove(itemQueue, 1);
	if ( msg ) then SendAddonMessage("TAG", msg, "WHISPER", UnitName("player")); end
	if ( #itemQueue == 0 ) then self:Hide(); end
end);
local function AskItems(ids)
	local fresh = {};
	for _, id in ipairs(ids) do
		if ( not askedItems[id] and not GetItemInfo(id) ) then askedItems[id] = true; table.insert(fresh, id); end
	end
	for _, chunk in ipairs(L.Chunks(fresh, 200, 40)) do table.insert(itemQueue, chunk); end
	if ( #itemQueue > 0 ) then itemSender:Show(); end
	return #fresh;
end

local frame = CreateFrame("Frame", "TemucraftAdventureGuideFrame", UIParent);
frame:SetWidth(WIDTH); frame:SetHeight(HEIGHT);
frame:SetPoint("CENTER", 0, 20);
frame:SetFrameStrata("HIGH"); frame:SetToplevel(true);
frame:EnableMouse(true); frame:SetMovable(true); frame:SetClampedToScreen(true);
frame:Hide();
tinsert(UISpecialFrames, "TemucraftAdventureGuideFrame");
if ( TemucraftStyle_Window ) then
	TemucraftStyle_Window(frame, "Adventure Guide");
else
	frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
		tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } });
	local t = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	t:SetPoint("TOP", 0, -20); t:SetText("Adventure Guide");
end
CreateFrame("Button", "TemucraftAdventureGuideFrameCloseButton", frame, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -6, -6);
frame:RegisterForDrag("LeftButton");
frame:SetScript("OnDragStart", function(self) self:StartMoving(); end);
frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); end);
frame:SetScript("OnHide", function() PlaySound("igCharacterInfoClose"); end);
-- smaller screens: scale the window down to fit
local function Fit()
	local h = UIParent:GetHeight() or HEIGHT;
	frame:SetScale(math.min(1, (h - 40) / HEIGHT));
end

local function Inset(parent, alpha)
	local f = CreateFrame("Frame", nil, parent);
	if ( TemucraftStyle_Inset ) then TemucraftStyle_Inset(f, alpha or 0.95);
	else
		f:SetBackdrop({ bgFile = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal-Desaturated", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = false, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } });
		f:SetBackdropColor(0.32, 0.30, 0.28, alpha or 0.95);
		f:SetBackdropBorderColor(0.78, 0.62, 0.3, 1);
	end
	f:SetFrameLevel(parent:GetFrameLevel());
	return f;
end

local function Highlight(b)
	if ( TemucraftStyle_Highlight ) then return TemucraftStyle_Highlight(b); end
	b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD");
	return b:GetHighlightTexture();
end

local function Shade(parent, layer, point, size, vertical, a1, a2, inset)
	local t = parent:CreateTexture(nil, layer);
	t:SetTexture("Interface\\Buttons\\WHITE8X8");
	inset = inset or 0;
	local y = (point == "TOP") and -inset or inset;
	if ( vertical ) then
		t:SetHeight(size); t:SetPoint(point.."LEFT", inset, y); t:SetPoint(point.."RIGHT", -inset, y);
		t:SetGradientAlpha("VERTICAL", 0, 0, 0, a1, 0, 0, 0, a2);
	else
		t:SetWidth(size); t:SetPoint("TOP"..point); t:SetPoint("BOTTOM"..point);
		t:SetGradientAlpha("HORIZONTAL", 0, 0, 0, a1, 0, 0, 0, a2);
	end
	return t;
end

-- the top bar: search box on the left, the expansion menu on the right
UI.search = CreateFrame("EditBox", "TemucraftAdventureGuideSearch", frame, "InputBoxTemplate");
UI.search:SetWidth(200); UI.search:SetHeight(20); UI.search:SetAutoFocus(false);
UI.search:SetPoint("TOPLEFT", 40, -42);
do
	local glass = UI.search:CreateTexture(nil, "OVERLAY");
	glass:SetTexture("Interface\\Common\\UI-Searchbox-Icon");
	glass:SetWidth(14); glass:SetHeight(14); glass:SetPoint("RIGHT", UI.search, "LEFT", -6, -1);
	glass:SetVertexColor(0.8, 0.8, 0.8);
	local hint = UI.search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
	hint:SetPoint("LEFT", 2, 0); hint:SetText(SEARCH or "Search");
	UI.searchHint = hint;
end
UI.search:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
UI.search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); end);
UI.search:SetScript("OnEditFocusGained", function() UI.searchHint:Hide(); end);
UI.search:SetScript("OnEditFocusLost", function(self) if ( self:GetText() == "" ) then UI.searchHint:Show(); end end);

UI.tierMenu = CreateFrame("Frame", "TemucraftAdventureGuideTierMenu", frame, "UIDropDownMenuTemplate");
UI.tierMenu:SetPoint("TOPRIGHT", -16, -38);
UIDropDownMenu_SetWidth(UI.tierMenu, 170);

-- three pages
UI.suggest = CreateFrame("Frame", nil, frame);
UI.grid = CreateFrame("Frame", nil, frame);
UI.inst = CreateFrame("Frame", nil, frame);
for _, p in ipairs({ UI.suggest, UI.grid, UI.inst }) do
	p:SetPoint("TOPLEFT", 14, -70); p:SetPoint("BOTTOMRIGHT", -14, 14); p:Hide();
end

local Refresh, OpenInstance, SelectBoss;

----------------------------------------------------------------------------------------------------------------------
-- cards (instance list and suggestions)
----------------------------------------------------------------------------------------------------------------------
local function Card(parent, w, h)
	local c = CreateFrame("Button", nil, parent);
	c:SetWidth(w); c:SetHeight(h);
	c:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	c:SetBackdropColor(0, 0, 0, 1);
	c:SetBackdropBorderColor(0.80, 0.65, 0.30, 1);
	c.art = c:CreateTexture(nil, "BACKGROUND", nil);
	c.art:SetPoint("TOPLEFT", 4, -4); c.art:SetPoint("BOTTOMRIGHT", -4, 4);
	c.art:SetTexCoord(0, 0.64453125, 0.12, 0.12 + 0.64453125 * (h - 8) / (w - 8));
	Shade(c, "BORDER", "BOTTOM", math.floor(h * 0.55), true, 0.9, 0, 4);
	c.icon = c:CreateTexture(nil, "ARTWORK");
	c.icon:SetWidth(36); c.icon:SetHeight(36); c.icon:SetPoint("BOTTOMLEFT", 8, 8);
	c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	c.name:SetPoint("BOTTOMLEFT", c.icon, "RIGHT", 6, 1); c.name:SetPoint("RIGHT", -8, 0);
	c.name:SetJustifyH("LEFT");
	c.sub = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	c.sub:SetPoint("TOPLEFT", c.icon, "RIGHT", 6, -2); c.sub:SetPoint("RIGHT", -8, 0);
	c.sub:SetJustifyH("LEFT");
	c.tag = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	c.tag:SetPoint("TOPRIGHT", -8, -8);
	c.heroic = c:CreateTexture(nil, "OVERLAY");
	c.heroic:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-HEROIC");
	c.heroic:SetWidth(16); c.heroic:SetHeight(20); c.heroic:SetTexCoord(0, 0.5, 0, 0.625);
	c.heroic:SetPoint("RIGHT", c.tag, "LEFT", -2, 0);
	local hl = Highlight(c);
	hl:ClearAllPoints(); hl:SetPoint("TOPLEFT", 4, -4); hl:SetPoint("BOTTOMRIGHT", -4, 4);
	return c;
end

local function ShowCard(c, inst, sub, tag, heroic)
	c.inst = inst;
	c.art:SetTexture(Art(inst));
	c.icon:SetTexture(IconOf(inst));
	c.name:SetText(inst.name);
	c.sub:SetText(sub or "");
	c.tag:SetText(tag or "");
	if ( heroic ) then c.heroic:Show(); else c.heroic:Hide(); end
	c:Show();
end

-- the instance grid (Dungeons / Raids)
UI.cards = {};
for i = 1, CARD_COLS * CARD_ROWS do
	local c = Card(UI.grid, CARD_W, CARD_H);
	local col, row = (i - 1) % CARD_COLS, math.floor((i - 1) / CARD_COLS);
	c:SetPoint("TOPLEFT", 4 + col * (CARD_W + 10), -4 - row * (CARD_H + 8));
	c:SetScript("OnClick", function(self) PlaySound("igMainMenuOptionCheckBoxOn"); OpenInstance(self.inst); end);
	c:SetScript("OnEnter", function(self)
		local inst = self.inst;
		if ( not inst ) then return; end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:AddLine(inst.name, 1, 0.82, 0);
		if ( inst.zone ~= "" ) then GameTooltip:AddLine(inst.zone, 1, 1, 1); end
		for _, row in ipairs(inst.diffs or {}) do
			GameTooltip:AddDoubleLine(L.DiffLabel(inst, row), L.LevelText(row[3], row[4]), 0.8, 0.8, 0.8, 1, 1, 1);
		end
		GameTooltip:AddLine(#(inst.bosses or {}).." bosses", 0.6, 0.6, 0.6);
		GameTooltip:Show();
	end);
	c:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	UI.cards[i] = c;
end
UI.pageText = UI.grid:CreateFontString(nil, "OVERLAY", "GameFontNormal");
UI.pageText:SetPoint("BOTTOM", 0, 6);
local function PageButton(dir)
	local b = CreateFrame("Button", nil, UI.grid);
	b:SetWidth(28); b:SetHeight(28);
	local tex = dir < 0 and "Prev" or "Next";
	b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-"..tex.."Page-Up");
	b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-"..tex.."Page-Down");
	b:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-"..tex.."Page-Disabled");
	b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD");
	b:SetPoint(dir < 0 and "RIGHT" or "LEFT", UI.pageText, dir < 0 and "LEFT" or "RIGHT", dir < 0 and -8 or 8, 0);
	b:SetScript("OnClick", function() PlaySound("igAbiliityPageTurn"); S.page = S.page + dir; Refresh(); end);
	return b;
end
UI.prev, UI.next = PageButton(-1), PageButton(1);
UI.grid:EnableMouseWheel(true);
UI.grid:SetScript("OnMouseWheel", function(self, delta)
	if ( delta > 0 and UI.prev:IsEnabled() == 1 ) then UI.prev:Click(); elseif ( delta < 0 and UI.next:IsEnabled() == 1 ) then UI.next:Click(); end
end);
UI.empty = UI.grid:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge");
UI.empty:SetPoint("CENTER", 0, 20);

-- Suggested Content: one big card and smaller ones
UI.sugg = {};
do
	local big = Card(UI.suggest, 784, 170);
	big:SetPoint("TOPLEFT", 4, -4);
	big.desc = big:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	big.desc:SetPoint("TOPLEFT", 14, -14); big.desc:SetWidth(520); big.desc:SetJustifyH("LEFT");
	UI.sugg[1] = big;
	for i = 2, 7 do
		local c = Card(UI.suggest, 256, 136);
		local col, row = (i - 2) % 3, math.floor((i - 2) / 3);
		c:SetPoint("TOPLEFT", 4 + col * 264, -184 - row * 144);
		UI.sugg[i] = c;
	end
	for _, c in ipairs(UI.sugg) do
		c:SetScript("OnClick", function(self)
			local s = self.suggestion;
			if ( not s ) then return; end
			PlaySound("igMainMenuOptionCheckBoxOn");
			if ( s.inst ) then OpenInstance(s.inst, s.diff);
			elseif ( WorldMapFrame ) then ToggleFrame(WorldMapFrame); end
		end);
		c:SetScript("OnEnter", function(self)
			local s = self.suggestion;
			if ( not s ) then return; end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:AddLine(s.name, 1, 0.82, 0);
			GameTooltip:AddLine(s.levels, 1, 1, 1);
			if ( s.inst and s.inst.desc ~= "" ) then GameTooltip:AddLine(s.inst.desc, 0.8, 0.8, 0.8, 1); end
			GameTooltip:AddLine(s.inst and "Click to open it in the Adventure Guide." or "A zone for your level: click to open the world map.", 0.5, 0.8, 1, 1);
			GameTooltip:Show();
		end);
		c:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	end
	UI.suggestNone = UI.suggest:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge");
	UI.suggestNone:SetPoint("CENTER");
	UI.suggestNone:SetText("Nothing to suggest for your level.");
end

local KIND_TEXT = { dungeon = "Dungeon", raid = "Raid", zone = "Zone" };
local function RefreshSuggest()
	local data = Data();
	local level = UnitLevel("player") or 1;
	S.suggestions = L.Suggest(data, level, UnitFactionGroup("player"), #UI.sugg);
	for i, c in ipairs(UI.sugg) do
		local s = S.suggestions[i];
		c.suggestion = s;
		if ( s ) then
			if ( s.inst ) then
				local row = L.DiffRow(s.inst, s.diff);
				ShowCard(c, s.inst, s.levels..((s.inst.zone ~= "" and ("  -  "..s.inst.zone)) or ""), KIND_TEXT[s.kind].." - "..L.DiffLabel(s.inst, row), row and row[5] == 1);
			else
				ShowCard(c, { name = s.name, bg = "QUESTPAPER", icon = "", kind = 0 }, s.levels, KIND_TEXT.zone, false);
				c.icon:SetTexture(ICON.."Zone");
				c.inst = nil;
			end
			if ( c.desc ) then
				local text = (s.inst and s.inst.desc) or "Explore this zone: its quests suit your level.";
				c.desc:SetText(text);
			end
		else
			c:Hide();
		end
	end
	if ( #S.suggestions == 0 ) then UI.suggestNone:Show(); else UI.suggestNone:Hide(); end
end

local function RefreshGrid()
	local data = Data();
	local kind = S.tab == 3 and L.RAID or L.DUNGEON;
	local list;
	if ( S.query ~= "" ) then list = L.Search(data, kind, S.query); else list = L.List(data, kind, S.tier); end
	local per = #UI.cards;
	local pages = L.Pages(#list, per);
	if ( S.page > pages ) then S.page = pages; end
	if ( S.page < 1 ) then S.page = 1; end
	for i, c in ipairs(UI.cards) do
		local inst = list[(S.page - 1) * per + i];
		if ( inst ) then
			local first = inst.diffs and inst.diffs[1];
			local heroic = false;
			for _, row in ipairs(inst.diffs or {}) do if ( row[5] == 1 ) then heroic = true; end end
			ShowCard(c, inst, (first and L.LevelText(first[3], first[4]) or "")..((inst.zone ~= "" and ("  -  "..inst.zone)) or ""),
				(kind == L.RAID and first) and (first[2].." Player") or "", heroic);
		else
			c:Hide(); c.inst = nil;
		end
	end
	UI.pageText:SetText(format("Page %d / %d", S.page, pages));
	if ( S.page > 1 ) then UI.prev:Enable(); else UI.prev:Disable(); end
	if ( S.page < pages ) then UI.next:Enable(); else UI.next:Disable(); end
	if ( #list == 0 ) then UI.empty:SetText(S.query ~= "" and "Nothing found." or "Nothing here yet."); UI.empty:Show(); else UI.empty:Hide(); end
end

----------------------------------------------------------------------------------------------------------------------
-- the instance page: header, boss list (left), overview / abilities / loot (middle), model (right)
----------------------------------------------------------------------------------------------------------------------
do
	local p = UI.inst;
	local head = CreateFrame("Frame", nil, p);
	head:SetPoint("TOPLEFT", 0, 0); head:SetPoint("TOPRIGHT", 0, 0); head:SetHeight(46);
	head:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	head:SetBackdropColor(0.06, 0.05, 0.04, 0.85);
	head:SetBackdropBorderColor(0.80, 0.65, 0.30, 0.9);
	UI.back = CreateFrame("Button", "TemucraftAdventureGuideBack", head, "UIPanelButtonTemplate");
	UI.back:SetWidth(70); UI.back:SetHeight(22); UI.back:SetPoint("LEFT", 8, 0); UI.back:SetText("< Back");
	UI.back:SetScript("OnClick", function() PlaySound("igMainMenuOptionCheckBoxOff"); S.inst, S.boss = nil, nil; Refresh(); end);
	UI.instIcon = head:CreateTexture(nil, "ARTWORK");
	UI.instIcon:SetWidth(36); UI.instIcon:SetHeight(36); UI.instIcon:SetPoint("LEFT", UI.back, "RIGHT", 8, 0);
	UI.instName = head:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	UI.instName:SetPoint("TOPLEFT", UI.instIcon, "TOPRIGHT", 8, -2);
	UI.instInfo = head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	UI.instInfo:SetPoint("TOPLEFT", UI.instName, "BOTTOMLEFT", 0, -3);
	UI.diffMenu = CreateFrame("Frame", "TemucraftAdventureGuideDifficulty", head, "UIDropDownMenuTemplate");
	UI.diffMenu:SetPoint("RIGHT", 6, -2);
	UIDropDownMenu_SetWidth(UI.diffMenu, 150);
	UI.heroicIcon = head:CreateTexture(nil, "OVERLAY");
	UI.heroicIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-HEROIC");
	UI.heroicIcon:SetWidth(16); UI.heroicIcon:SetHeight(20); UI.heroicIcon:SetTexCoord(0, 0.5, 0, 0.625);
	UI.heroicIcon:SetPoint("RIGHT", UI.diffMenu, "LEFT", 14, 2);

	-- boss list
	local left = Inset(p);
	left:SetPoint("TOPLEFT", 0, -50); left:SetPoint("BOTTOMLEFT", 0, 0); left:SetWidth(196);
	UI.bossButtons = {};
	local function BossButton(i)
		local b = CreateFrame("Button", nil, left);
		b:SetWidth(184); b:SetHeight(28);
		b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 30);
		if ( TemucraftStyle_Bar ) then TemucraftStyle_Bar(b); end
		Highlight(b);
		b.glow = TemucraftStyle_Glow and TemucraftStyle_Glow(b) or b:CreateTexture(nil, "ARTWORK");
		b.skull = b:CreateTexture(nil, "OVERLAY");
		b.skull:SetWidth(20); b.skull:SetHeight(20); b.skull:SetPoint("LEFT", 6, 0);
		b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		b.text:SetPoint("LEFT", b.skull, "RIGHT", 4, 0); b.text:SetPoint("RIGHT", -4, 0);
		b.text:SetJustifyH("LEFT");
		b:SetScript("OnClick", function(self) PlaySound("igMainMenuOptionCheckBoxOn"); SelectBoss(self.index); end);
		return b;
	end
	for i = 1, 15 do UI.bossButtons[i] = BossButton(i); end

	-- middle: sub tabs and the pages
	local mid = Inset(p);
	mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 6, 0); mid:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 6, 0); mid:SetWidth(330);
	UI.mid = mid;
	UI.subTabs = {};
	for i, label in ipairs({ "Overview", "Abilities", "Loot" }) do
		local t = CreateFrame("Button", "TemucraftAdventureGuideSubTab"..i, mid, "UIPanelButtonTemplate");
		t:SetWidth(104); t:SetHeight(22); t:SetText(label);
		t:SetPoint("TOPLEFT", 8 + (i - 1) * 106, -8);
		t:SetScript("OnClick", function() PlaySound("igCharacterInfoTab"); S.sub = i; S.lootOffset = 0; Refresh(); end);
		UI.subTabs[i] = t;
	end
	-- overview and abilities: a scrolling text page
	local scroll = CreateFrame("ScrollFrame", "TemucraftAdventureGuideTextScroll", mid, "UIPanelScrollFrameTemplate");
	scroll:SetPoint("TOPLEFT", 10, -38); scroll:SetPoint("BOTTOMRIGHT", -30, 10);
	local child = CreateFrame("Frame", nil, scroll);
	child:SetWidth(290); child:SetHeight(10);
	scroll:SetScrollChild(child);
	UI.textScroll, UI.textChild = scroll, child;
	UI.title = child:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	UI.title:SetPoint("TOPLEFT", 2, -2); UI.title:SetWidth(286); UI.title:SetJustifyH("LEFT");
	UI.desc = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	UI.desc:SetPoint("TOPLEFT", UI.title, "BOTTOMLEFT", 0, -8); UI.desc:SetWidth(286); UI.desc:SetJustifyH("LEFT");
	UI.facts = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	UI.facts:SetPoint("TOPLEFT", UI.desc, "BOTTOMLEFT", 0, -10); UI.facts:SetWidth(286); UI.facts:SetJustifyH("LEFT");
	UI.abilities = {};
	-- loot: a list of item rows
	local loot = CreateFrame("ScrollFrame", "TemucraftAdventureGuideLootScroll", mid, "FauxScrollFrameTemplate");
	loot:SetPoint("TOPLEFT", 6, -38); loot:SetWidth(296); loot:SetHeight(LOOT_ROWS * LOOT_H);
	UI.lootScroll = loot;
	UI.lootRows = {};
	UI.lootNone = mid:CreateFontString(nil, "OVERLAY", "GameFontDisable");
	UI.lootNone:SetPoint("TOP", 0, -80); UI.lootNone:SetWidth(300);

	-- right: the model on the instance's art
	local right = CreateFrame("Frame", nil, p);
	right:SetPoint("TOPLEFT", mid, "TOPRIGHT", 6, 0); right:SetPoint("BOTTOMRIGHT", 0, 0);
	right:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } });
	right:SetBackdropBorderColor(0.80, 0.65, 0.30);
	UI.stage = right;
	UI.stageArt = right:CreateTexture(nil, "BACKGROUND", nil);
	UI.stageArt:SetPoint("TOPLEFT", 5, -5); UI.stageArt:SetPoint("BOTTOMRIGHT", -5, 5);
	UI.stageArt:SetVertexColor(0.75, 0.75, 0.75);
	Shade(right, "BORDER", "TOP", 60, true, 0, 0.7, 5);
	Shade(right, "BORDER", "BOTTOM", 90, true, 0.85, 0, 5);
	UI.model = CreateFrame("DressUpModel", "TemucraftAdventureGuideModel", right);
	UI.model:SetPoint("TOPLEFT", 6, -6); UI.model:SetPoint("BOTTOMRIGHT", -6, 36);
	UI.modelName = right:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	UI.modelName:SetPoint("BOTTOM", 0, 40); UI.modelName:SetWidth(240);
	UI.noPreview = right:CreateFontString(nil, "OVERLAY", "GameFontDisable");
	UI.noPreview:SetPoint("CENTER", 0, 20);
	UI.showBoss = CreateFrame("Button", "TemucraftAdventureGuideShowBoss", right, "UIPanelButtonTemplate");
	UI.showBoss:SetWidth(110); UI.showBoss:SetHeight(22); UI.showBoss:SetPoint("BOTTOMLEFT", 10, 10);
	UI.showBoss:SetText("Show Boss");
	UI.showChar = CreateFrame("Button", "TemucraftAdventureGuideShowChar", right, "UIPanelButtonTemplate");
	UI.showChar:SetWidth(110); UI.showChar:SetHeight(22); UI.showChar:SetPoint("BOTTOMRIGHT", -10, 10);
	UI.showChar:SetText("Show Character");
end

-- the model: the boss (SetCreature, its entry asked from the server first, retried for 6 s like Collections) or your
-- character trying an item on
local preview = { npc = nil, tries = 0, wait = 0, item = nil };
local function ModelBoss(npc)
	local m = UI.model;
	preview.item = nil;
	m:ClearModel();
	UI.noPreview:SetText("");
	preview.npc = nil;
	if ( not npc or npc <= 0 ) then UI.noPreview:SetText("No preview"); return; end
	if ( TemucraftCollections_Prime ) then TemucraftCollections_Prime({ npc }); end
	m:SetCreature(npc);
	m:SetFacing(0.4);
	if ( not m:GetModel() ) then preview.npc, preview.tries, preview.wait = npc, 0, 0; end
end
local function ModelItem(id)
	local m = UI.model;
	preview.npc = nil;
	UI.noPreview:SetText("");
	m:SetUnit("player");
	m:SetFacing(0);
	if ( id ) then
		preview.item = id;
		m:TryOn("item:"..id);   -- on top of what you wear (only equippable items change anything)
	end
end
UI.model:SetScript("OnUpdate", function(self, elapsed)
	if ( not preview.npc ) then return; end
	preview.wait = preview.wait + elapsed;
	if ( preview.wait < 0.3 ) then return; end
	preview.wait = 0;
	if ( self:GetModel() ) then preview.npc = nil; return; end
	preview.tries = preview.tries + 1;
	if ( preview.tries == 3 and TemucraftCollections_Prime ) then TemucraftCollections_Prime({ preview.npc }, true); end
	if ( preview.tries > 20 ) then preview.npc = nil; UI.noPreview:SetText("No preview"); return; end
	self:SetCreature(preview.npc);
	self:SetFacing(0.4);
end);
do
	local turning, lastX = false, 0;
	UI.model:EnableMouse(true);
	UI.model:SetScript("OnMouseDown", function() turning, lastX = true, GetCursorPosition(); end);
	UI.model:SetScript("OnMouseUp", function() turning = false; end);
	UI.model:SetScript("OnHide", function() turning = false; end);
	UI.model:EnableMouseWheel(true);
	UI.model:SetScript("OnMouseWheel", function(self, delta)
		local z = (self.zoom or 0) + delta * 0.3;
		if ( z < 0 ) then z = 0; elseif ( z > 2.5 ) then z = 2.5; end
		self.zoom = z;
		self:SetPosition(z, 0, 0);
	end);
	local spin = CreateFrame("Frame", nil, UI.model);
	spin:SetScript("OnUpdate", function()
		if ( not turning ) then return; end
		local x = GetCursorPosition();
		UI.model:SetFacing((UI.model:GetFacing() or 0) + (x - lastX) / 100);
		lastX = x;
	end);
end
UI.showBoss:SetScript("OnClick", function()
	local b = S.inst and S.boss and S.inst.bosses[S.boss];
	ModelBoss(b and b.npc or (S.inst and S.inst.bosses[1] and S.inst.bosses[1].npc));
end);
UI.showChar:SetScript("OnClick", function() ModelItem(preview.item); end);

-- spell texts (the client's own tooltip, read once)
local scan = CreateFrame("GameTooltip", "TemucraftAdventureGuideScanTooltip", nil, "GameTooltipTemplate");
local spellText = {};
local function SpellText(id)
	if ( spellText[id] == nil ) then
		scan:SetOwner(WorldFrame, "ANCHOR_NONE");
		scan:SetHyperlink("spell:"..id);
		local text = "";
		for i = 2, scan:NumLines() do
			local line = _G["TemucraftAdventureGuideScanTooltipTextLeft"..i];
			local s = line and line:GetText();
			if ( s and #s > #text ) then text = s; end
		end
		scan:Hide();
		spellText[id] = text;
	end
	return spellText[id];
end

-- one ability row: icon, name, description; returns its height
local function Ability(i)
	local a = UI.abilities[i];
	if ( a ) then return a; end
	a = CreateFrame("Button", nil, UI.textChild);
	a:SetWidth(286); a:SetHeight(40);
	if ( TemucraftStyle_Bar ) then a.bar = TemucraftStyle_Bar(a); a.bar:SetAlpha(0.35); end
	a.icon = a:CreateTexture(nil, "ARTWORK");
	a.icon:SetWidth(26); a.icon:SetHeight(26); a.icon:SetPoint("TOPLEFT", 4, -4);
	a.name = a:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	a.name:SetPoint("TOPLEFT", a.icon, "TOPRIGHT", 6, -1); a.name:SetWidth(246); a.name:SetJustifyH("LEFT");
	a.text = a:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	a.text:SetPoint("TOPLEFT", a.name, "BOTTOMLEFT", 0, -3); a.text:SetWidth(246); a.text:SetJustifyH("LEFT");
	a:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetHyperlink("spell:"..self.spell);
		GameTooltip:Show();
	end);
	a:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	a:SetScript("OnClick", function(self)
		if ( IsModifiedClick("CHATLINK") ) then local link = GetSpellLink(self.spell); if ( link ) then ChatEdit_InsertLink(link); end end
	end);
	UI.abilities[i] = a;
	return a;
end

local function LootRow(i)
	local r = CreateFrame("Button", nil, UI.mid);
	r:SetWidth(292); r:SetHeight(LOOT_H - 2);
	r:SetPoint("TOPLEFT", UI.lootScroll, "TOPLEFT", 4, -(i - 1) * LOOT_H);
	r:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	Highlight(r);
	r.glow = TemucraftStyle_Glow and TemucraftStyle_Glow(r) or r:CreateTexture(nil, "ARTWORK");
	r.icon = r:CreateTexture(nil, "ARTWORK");
	r.icon:SetWidth(34); r.icon:SetHeight(34); r.icon:SetPoint("LEFT", 2, 0);
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -3); r.name:SetWidth(240); r.name:SetJustifyH("LEFT");
	r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
	r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3); r.sub:SetWidth(240); r.sub:SetJustifyH("LEFT");
	r:SetScript("OnEnter", function(self)
		if ( not self.item ) then return; end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetHyperlink("item:"..self.item);
		GameTooltip:Show();
	end);
	r:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	r:SetScript("OnClick", function(self)
		if ( not self.item ) then return; end
		local _, link = GetItemInfo(self.item);
		if ( IsModifiedClick("CHATLINK") ) then if ( link ) then ChatEdit_InsertLink(link); end return; end
		if ( IsModifiedClick("DRESSUP") ) then if ( link ) then DressUpItemLink(link); end return; end
		PlaySound("igMainMenuOptionCheckBoxOn");
		ModelItem(self.item);
		UI.modelName:SetText(link or "");
		Refresh();
	end);
	return r;
end
for i = 1, LOOT_ROWS do UI.lootRows[i] = LootRow(i); end

-- difficulty menu
local function DiffMenuInit()
	local inst = S.inst;
	if ( not inst ) then return; end
	for _, row in ipairs(inst.diffs or {}) do
		local info = UIDropDownMenu_CreateInfo();
		info.text = L.DiffLabel(inst, row);
		info.checked = (row[1] == S.diff);
		info.func = function() S.diff = row[1]; S.lootOffset = 0; Refresh(); end;
		UIDropDownMenu_AddButton(info);
	end
end
local function TierMenuInit()
	local kind = S.tab == 3 and L.RAID or L.DUNGEON;
	for _, t in ipairs(L.Tiers(Data(), kind)) do
		local info = UIDropDownMenu_CreateInfo();
		info.text = L.TIERS[t];
		info.checked = (t == S.tier);
		info.func = function() S.tier = t; S.page = 1; Refresh(); end;
		UIDropDownMenu_AddButton(info);
	end
end

local pendingNames = 0;
local function RefreshInstance()
	local inst = S.inst;
	local data = Data();
	local row = L.DiffRow(inst, S.diff);
	if ( row ) then S.diff = row[1]; end
	UI.instName:SetText(inst.name);
	UI.instIcon:SetTexture(IconOf(inst));
	local info = {};
	if ( inst.zone ~= "" ) then table.insert(info, inst.zone); end
	if ( row and row[3] > 0 ) then table.insert(info, L.LevelText(row[3], row[4])); end
	if ( row ) then table.insert(info, row[2].." players"); end
	UI.instInfo:SetText(table.concat(info, "  -  "));
	UIDropDownMenu_Initialize(UI.diffMenu, DiffMenuInit);
	UIDropDownMenu_SetText(UI.diffMenu, L.DiffLabel(inst, row));
	if ( row and row[5] == 1 ) then UI.heroicIcon:Show(); else UI.heroicIcon:Hide(); end
	UI.stageArt:SetTexture(Art(inst));
	UI.stageArt:SetTexCoord(0.10, 0.54, 0, 0.69921875);

	-- bosses
	local bosses = inst.bosses or {};
	for i, b in ipairs(UI.bossButtons) do
		local boss = bosses[i];
		b.index = i;
		if ( boss ) then
			b.text:SetText(boss.name);
			local on = (S.boss == i);
			b.skull:SetTexture(on and "Interface\\WorldMap\\Skull_64Red" or "Interface\\WorldMap\\Skull_64Grey");
			if ( on ) then b.glow:Show(); else b.glow:Hide(); end
			b:Show();
		else
			b:Hide();
		end
	end
	local boss = S.boss and bosses[S.boss];
	for i, t in ipairs(UI.subTabs) do
		if ( i == S.sub ) then t:LockHighlight(); else t:UnlockHighlight(); end
	end
	if ( boss ) then UI.subTabs[2]:Enable(); else UI.subTabs[2]:Disable(); if ( S.sub == 2 ) then S.sub = 1; end end

	-- the middle page
	local showText = S.sub ~= 3;
	if ( showText ) then UI.textScroll:Show(); else UI.textScroll:Hide(); end
	for _, a in ipairs(UI.abilities) do a:Hide(); end
	if ( S.sub == 1 ) then
		UI.title:SetText(boss and boss.name or inst.name);
		UI.desc:SetText(boss and ((boss.desc ~= "" and boss.desc) or L.BossLine(boss)) or (inst.desc ~= "" and inst.desc or ""));
		local facts = {};
		if ( boss ) then
			if ( boss.desc ~= "" ) then table.insert(facts, L.BossLine(boss)); end
			table.insert(facts, #(boss.spells or {}).." abilities, "..#L.Loot(inst, boss, S.diff).." items ("..L.DiffLabel(inst, row)..")");
		else
			if ( inst.zone ~= "" ) then table.insert(facts, "|cffffd100Location:|r |cffffffff"..inst.zone.."|r"); end
			for _, r in ipairs(inst.diffs or {}) do
				table.insert(facts, "|cffffd100"..L.DiffLabel(inst, r)..":|r |cffffffff"..L.LevelText(r[3], r[4])..(r[3] > 0 and ", " or "")..r[2].." players|r");
			end
			table.insert(facts, "|cffffd100Bosses:|r |cffffffff"..#bosses.."|r");
			table.insert(facts, " ");
			table.insert(facts, "Pick a boss on the left for its abilities and loot, or Loot for everything this instance drops.");
		end
		UI.facts:SetText(table.concat(facts, "\n"));
		UI.desc:Show(); UI.facts:Show();
		UI.textChild:SetHeight(UI.title:GetStringHeight() + UI.desc:GetStringHeight() + UI.facts:GetStringHeight() + 40);
	elseif ( S.sub == 2 and boss ) then
		UI.title:SetText(boss.name);
		UI.desc:Hide(); UI.facts:Hide();
		local y, n = -(UI.title:GetStringHeight() + 12), 0;
		for _, id in ipairs(boss.spells or {}) do
			local name, _, icon = GetSpellInfo(id);
			if ( name ) then
				n = n + 1;
				local a = Ability(n);
				a.spell = id;
				a.icon:SetTexture(icon);
				a.name:SetText(name);
				a.text:SetText(SpellText(id));
				local h = math.max(34, a.name:GetStringHeight() + a.text:GetStringHeight() + 14);
				a:SetHeight(h);
				a:ClearAllPoints(); a:SetPoint("TOPLEFT", UI.textChild, "TOPLEFT", 0, y);
				a:Show();
				y = y - h - 4;
			end
		end
		if ( n == 0 ) then
			UI.facts:SetText("No abilities known for this boss."); UI.facts:Show();
			UI.facts:ClearAllPoints(); UI.facts:SetPoint("TOPLEFT", UI.title, "BOTTOMLEFT", 0, -10);
		end
		UI.textChild:SetHeight(-y + 10);
	end
	if ( S.sub ~= 2 ) then UI.facts:ClearAllPoints(); UI.facts:SetPoint("TOPLEFT", UI.desc, "BOTTOMLEFT", 0, -10); end
	UI.textScroll:UpdateScrollChildRect();

	-- loot
	local ids = (S.sub == 3) and L.Loot(inst, boss, S.diff) or {};
	if ( S.sub == 3 ) then
		UI.lootScroll:Show();
		pendingNames = AskItems(ids);
		FauxScrollFrame_Update(UI.lootScroll, #ids, LOOT_ROWS, LOOT_H);
		local offset = FauxScrollFrame_GetOffset(UI.lootScroll);
		for i, r in ipairs(UI.lootRows) do
			local id = ids[offset + i];
			r.item = id;
			if ( id ) then
				local d = data.items and data.items[id];
				local name, _, quality, _, _, _, subType, _, _, texture = GetItemInfo(id);
				name = name or (d and d[6]) or ("Item "..id);
				quality = quality or (d and d[1]) or 1;
				local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality];
				r.name:SetText(name);
				if ( color ) then r.name:SetTextColor(color.r, color.g, color.b); else r.name:SetTextColor(1, 1, 1); end
				r.sub:SetText(L.SlotText(d, subType, _G));
				r.icon:SetTexture(texture or (GetItemIcon and GetItemIcon(id)) or "Interface\\Icons\\INV_Misc_QuestionMark");
				if ( preview.item == id ) then r.glow:Show(); else r.glow:Hide(); end
				r:Show();
			else
				r:Hide();
			end
		end
		if ( #ids == 0 ) then
			UI.lootNone:SetText(boss and "This boss has no loot listed for this difficulty." or "No loot listed for this difficulty.");
			UI.lootNone:Show();
		else
			UI.lootNone:Hide();
		end
	else
		UI.lootScroll:Hide(); UI.lootNone:Hide();
		for _, r in ipairs(UI.lootRows) do r:Hide(); end
	end
end
UI.lootScroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, LOOT_H, Refresh); end);

-- refresh the loot names a few times while the server sends the items
local namesTimer = CreateFrame("Frame");
namesTimer:Hide();
namesTimer.wait, namesTimer.left = 0, 0;
namesTimer:SetScript("OnUpdate", function(self, elapsed)
	self.wait = self.wait + elapsed;
	if ( self.wait < 1 ) then return; end
	self.wait = 0;
	self.left = self.left - 1;
	if ( frame:IsShown() and S.inst and S.sub == 3 ) then Refresh(); end
	if ( self.left <= 0 ) then self:Hide(); end
end);

----------------------------------------------------------------------------------------------------------------------
-- tabs and switching
----------------------------------------------------------------------------------------------------------------------
local TAB_NAMES = { "Suggested Content", "Dungeons", "Raids" };
UI.tabs = {};
for i, label in ipairs(TAB_NAMES) do
	local tab = CreateFrame("Button", "TemucraftAdventureGuideFrameTab"..i, frame, "CharacterFrameTabButtonTemplate");
	tab:SetID(i); tab:SetText(label);
	if ( i == 1 ) then tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 20, 8); else tab:SetPoint("LEFT", UI.tabs[i - 1], "RIGHT", -16, 0); end
	tab:SetScript("OnClick", function(self)
		PlaySound("igCharacterInfoTab");
		S.tab, S.inst, S.boss, S.page = self:GetID(), nil, nil, 1;
		S.tier = nil;
		Refresh();
	end);
	UI.tabs[i] = tab;
end
PanelTemplates_SetNumTabs(frame, #TAB_NAMES);

function Refresh()
	PanelTemplates_SetTab(frame, S.tab);
	local data = Data();
	if ( S.inst ) then
		UI.suggest:Hide(); UI.grid:Hide(); UI.inst:Show();
		UI.search:Hide(); UI.tierMenu:Hide();
		RefreshInstance();
		if ( pendingNames > 0 ) then namesTimer.left = 5; namesTimer:Show(); pendingNames = 0; end
		return;
	end
	UI.inst:Hide();
	if ( S.tab == 1 ) then
		UI.grid:Hide(); UI.suggest:Show(); UI.search:Hide(); UI.tierMenu:Hide();
		RefreshSuggest();
		return;
	end
	UI.suggest:Hide(); UI.grid:Show(); UI.search:Show(); UI.tierMenu:Show();
	local kind = S.tab == 3 and L.RAID or L.DUNGEON;
	local tiers = L.Tiers(data, kind);
	if ( not S.tier ) then
		local want = L.TierForLevel(UnitLevel("player") or 1);
		for _, t in ipairs(tiers) do if ( t <= want ) then S.tier = t; end end
		S.tier = S.tier or tiers[1] or 1;
	end
	UIDropDownMenu_Initialize(UI.tierMenu, TierMenuInit);
	UIDropDownMenu_SetText(UI.tierMenu, L.TIERS[S.tier] or "");
	if ( S.query ~= "" ) then UIDropDownMenu_SetText(UI.tierMenu, "All expansions"); end
	RefreshGrid();
end

UI.search:SetScript("OnTextChanged", function(self)
	if ( self:GetText() ~= "" ) then UI.searchHint:Hide(); end
	S.query = self:GetText() or "";
	S.page = 1;
	Refresh();
end);

function OpenInstance(inst, difficulty)
	if ( not inst ) then return; end
	S.inst, S.boss, S.sub, S.lootOffset = inst, nil, 1, 0;
	S.tab = inst.kind == L.RAID and 3 or 2;
	S.tier = inst.tier;
	S.diff = difficulty or (inst.diffs and inst.diffs[1] and inst.diffs[1][1]) or 0;
	FauxScrollFrame_SetOffset(UI.lootScroll, 0);
	UI.textScroll:SetVerticalScroll(0);
	UI.modelName:SetText("");
	local first = inst.bosses and inst.bosses[1];
	ModelBoss(first and first.npc);
	Refresh();
end

function SelectBoss(index)
	local inst = S.inst;
	if ( not inst ) then return; end
	if ( S.boss == index ) then S.boss = nil; else S.boss = index; end
	if ( S.sub == 2 and not S.boss ) then S.sub = 1; end
	FauxScrollFrame_SetOffset(UI.lootScroll, 0);
	UI.textScroll:SetVerticalScroll(0);
	local b = inst.bosses[S.boss or 1];
	UI.modelName:SetText(S.boss and b and b.name or "");
	ModelBoss(b and b.npc);
	Refresh();
end

-- open (or close) the guide. tab: 1 Suggested Content, 2 Dungeons, 3 Raids. Inside an instance it opens on it.
function TemucraftAdventureGuide_Toggle(tab)
	if ( frame:IsShown() and not tab ) then frame:Hide(); return; end
	Fit();
	if ( not frame:IsShown() and not tab ) then
		local inInstance = IsInInstance();
		if ( inInstance ) then
			local name, _, difficultyIndex = GetInstanceInfo();
			local inst, d = L.FindByName(Data(), name, difficultyIndex);
			if ( inst ) then frame:Show(); PlaySound("igCharacterInfoOpen"); OpenInstance(inst, d); return; end
		end
	end
	if ( tab ) then S.tab, S.inst, S.boss, S.page, S.tier = tab, nil, nil, 1, nil; end
	if ( not frame:IsShown() ) then PlaySound("igCharacterInfoOpen"); end
	frame:Show();
	Refresh();
end
function TemucraftAdventureGuide_Open(mapId)
	for _, inst in ipairs(Data().instances) do
		if ( L.Key(inst) == mapId ) then Fit(); frame:Show(); OpenInstance(inst); return true; end
	end
	return false;
end
-- retail's name: DragonUI (or anything else) can call it
if ( not ToggleEncounterJournal ) then
	function ToggleEncounterJournal() TemucraftAdventureGuide_Toggle(); end
end

SLASH_TEMUCRAFTADVENTURE1 = "/adventure";
SLASH_TEMUCRAFTADVENTURE2 = "/ag";
SLASH_TEMUCRAFTADVENTURE3 = "/ej";
SLASH_TEMUCRAFTADVENTURE4 = "/adventureguide";
SlashCmdList["TEMUCRAFTADVENTURE"] = function(msg)
	msg = strlower(strtrim(msg or ""));
	if ( msg == "dungeons" or msg == "dungeon" ) then TemucraftAdventureGuide_Toggle(2);
	elseif ( msg == "raids" or msg == "raid" ) then TemucraftAdventureGuide_Toggle(3);
	elseif ( msg == "suggested" ) then TemucraftAdventureGuide_Toggle(1);
	else TemucraftAdventureGuide_Toggle(); end
end;

----------------------------------------------------------------------------------------------------------------------
-- DragonUI's micro menu: it lays out the stock micro buttons and has no Adventure Guide. While it owns the micro menu,
-- a button in its look sits just left of its first button (its art comes from DragonUI's own micro menu sheet).
----------------------------------------------------------------------------------------------------------------------
local DUI_SHEET = "Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\uimicromenu2x";
local duiButton;
local function DragonUIButton()
	if ( duiButton or not (TemucraftDragonUI_Owns and TemucraftDragonUI_Owns("micro")) ) then return; end
	local first = CharacterMicroButton;
	if ( not first or not first:IsShown() ) then return; end
	local b = CreateFrame("Button", "TemucraftDragonUIAdventureButton", first:GetParent() or UIParent);
	local w, h = first:GetWidth(), first:GetHeight();
	b:SetWidth(w); b:SetHeight(h);
	b:SetFrameLevel(first:GetFrameLevel());
	b:SetPoint("RIGHT", first, "LEFT", -2, 0);
	local bg = b:CreateTexture(nil, "BACKGROUND");
	bg:SetAllPoints(b);
	if ( bg:SetTexture(DUI_SHEET) ) then
		bg:SetTexCoord(0.0654297, 0.12793, 0.330078, 0.490234);   -- DragonUI's empty button (its character button's)
	else
		bg:SetTexture("Interface\\Buttons\\UI-MicroButtonCharacter-Up");
	end
	local icon = b:CreateTexture(nil, "ARTWORK");
	icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09");
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
	icon:SetPoint("CENTER", -1, 1);
	icon:SetWidth(w * 0.58); icon:SetHeight(w * 0.58);
	b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD");
	b:SetScript("OnMouseDown", function() icon:SetPoint("CENTER", 0, 0); end);
	b:SetScript("OnMouseUp", function() icon:SetPoint("CENTER", -1, 1); end);
	b:SetScript("OnClick", function() TemucraftAdventureGuide_Toggle(); end);
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText("Adventure Guide", 1, 1, 1);
		GameTooltip:AddLine("Dungeons, raids and what to do at your level.", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1);
		GameTooltip:Show();
	end);
	b:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	-- hide with the strip (vehicles, pet battles of the strip itself)
	hooksecurefunc(first, "Hide", function() b:Hide(); end);
	hooksecurefunc(first, "Show", function() b:Show(); end);
	duiButton = b;
end

local events = CreateFrame("Frame");
events:RegisterEvent("PLAYER_LOGIN");
events:RegisterEvent("PLAYER_LEVEL_UP");
events:RegisterEvent("PLAYER_ENTERING_WORLD");
events.wait = nil;
events:SetScript("OnEvent", function(self, event)
	if ( event == "PLAYER_LOGIN" ) then self.wait = 1.5; self:Show(); return; end   -- after DragonUI's own layout
	if ( frame:IsShown() and S.tab == 1 and not S.inst ) then Refresh(); end
end);
events:SetScript("OnUpdate", function(self, elapsed)
	if ( not self.wait ) then return; end
	self.wait = self.wait - elapsed;
	if ( self.wait <= 0 ) then self.wait = nil; DragonUIButton(); end
end);
