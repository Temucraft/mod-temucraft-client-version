-- Temucraft spellbook (the Spellbook tab of TemucraftPlayerSpells.lua): a retail-style book with three tabs, the class,
-- General and Skills, a search box, entries in a 3-column grid (icon, name, grey subtitle) under section headings, and
-- page arrows; the expand button at the top right shows two pages side by side.
--   Class:   a section named after the class (class spell tabs that aren't talent trees, when the server has any),
--            then one section per talent tree, in talent order.
--   General: General, Racial, Professions, Guild Perks, then any other spell tab (Temucraft spells).
--   Skills:  the character's skill lines (GetSkillLineInfo: weapons, defense, armour, languages, class skills,
--            professions read-only), each with an icon and a "current / max" bar; refreshed on SKILL_LINES_CHANGED.
-- Ranks ("Show all ranks" box by the search, saved account-wide with TemucraftStore, key ui.bookranks = "all"):
--   off (default) one entry per spell, its highest rank; a spell with lower ranks has a small arrow on its icon that
--                 opens them in a row beside it (a TemucraftFlyouts.lua row: click casts that rank, drag puts it on a bar)
--   on            every rank, grouped under a bar with the spell's name; a click on the bar folds / unfolds it.
-- Passives get the stock passive border.
-- The buttons are SecureActionButtons (type "spell", the spell's id): click casts, drag puts it on an action bar, in
-- and out of combat. They are laid out and given their spells only out of combat; a change in combat waits for it to
-- end. What a spell is (racial, profession, guild perk) comes from TemucraftSpellTabs.lua (server prefix TSB).
-- Flyouts (TemucraftFlyouts.lua): the class's teleports / portals and the Temucraft helper items are one entry each,
-- which opens a row of them beside it (secure, so it works in combat).

----------------------------------------------------------------------------------------------------------------------
-- The logic (no frames: tests/spellbook_test.lua runs it with stubs)
----------------------------------------------------------------------------------------------------------------------
TemucraftSpellBookLogic = {};
local L = TemucraftSpellBookLogic;
L.F_RACIAL, L.F_PROFESSION, L.F_GUILD, L.F_PASSIVE, L.F_TELEPORT, L.F_TALENT = 1, 2, 4, 8, 16, 32;
L.GENERAL_ORDER = { "General", "Racial", "Professions", "Guild Perks" };

function L.Has(f, bit) return f ~= nil and (f % (bit * 2)) >= bit; end

local function lower(s) return string.lower(s or ""); end

-- "Rank 3" (or the client's RANK word) says nothing worth a subtitle
function L.IsRank(sub)
	if ( not sub or sub == "" ) then return true; end
	if ( string.find(sub, "^Rank %d") ) then return true; end
	if ( RANK and string.find(sub, "^"..RANK.." %d") ) then return true; end
	return false;
end

-- e = { name, sub, tab, tabName, passive, flags }; trees = { [lower tree name] = tree name }
-- returns the book ("class" or "general"), the section and the subtitle
function L.Classify(e, trees, className)
	local sub = e.sub or "";
	local subtitle = L.IsRank(sub) and "" or sub;
	local tabKey = lower(e.tabName);
	if ( e.tab ~= 1 and trees[tabKey] ) then
		if ( subtitle == "" and e.passive ) then subtitle = "Passive"; end
		return "class", trees[tabKey], subtitle;
	end
	if ( e.tab ~= 1 and className and tabKey == lower(className) ) then
		if ( subtitle == "" and e.passive ) then subtitle = "Passive"; end
		return "class", className, subtitle;
	end
	if ( L.Has(e.flags, L.F_GUILD) or string.find(sub, "Guild Perk") ) then
		return "general", "Guild Perks", subtitle ~= "" and subtitle or "Guild Perk";
	end
	if ( L.Has(e.flags, L.F_RACIAL) or string.find(sub, "Racial") ) then
		return "general", "Racial", subtitle ~= "" and subtitle or (e.passive and "Racial Passive" or "Racial");
	end
	if ( subtitle == "" and e.passive ) then subtitle = "Passive"; end
	if ( L.Has(e.flags, L.F_PROFESSION) ) then return "general", "Professions", subtitle; end
	if ( e.tab == 1 ) then return "general", "General", subtitle; end
	return "general", e.tabName or "Temucraft", subtitle;
end

-- keeps the last (highest) rank of each name, in the order the names first appear; each kept entry gets .ranks, all
-- its ranks lowest first (the entry itself last) and .key ("tab:name")
function L.HighestRanks(list)
	local out, at, ranks = {}, {}, {};
	for _, e in ipairs(list) do
		local key = e.tab..":"..e.name;
		if ( at[key] ) then out[at[key]] = e; table.insert(ranks[key], e);
		else table.insert(out, e); at[key] = #out; ranks[key] = { e }; end
	end
	for _, e in ipairs(out) do
		e.key = e.tab..":"..e.name;
		e.ranks = ranks[e.key];
	end
	return out;
end

-- the lower ranks of an entry, next lower first (the rank row of the "highest only" view)
function L.LowerRanks(e)
	local out = {};
	if ( e.ranks ) then for i = #e.ranks - 1, 1, -1 do table.insert(out, e.ranks[i]); end end
	return out;
end

-- "Show all ranks": a spell with several ranks becomes a group bar ({ group = true, name, count, folded, groupKey })
-- followed, unless folded[key], by its ranks, highest first (subtitle "Rank n", groupKey set); the rest stays
function L.ExpandRanks(sections, folded)
	folded = folded or {};
	local out = {};
	for _, s in ipairs(sections) do
		local entries = {};
		for _, e in ipairs(s.entries) do
			if ( e.ranks and #e.ranks > 1 and not e.flyout ) then
				local key = e.key or (e.tab..":"..e.name);
				table.insert(entries, { group = true, name = e.name, icon = e.icon, count = #e.ranks, folded = folded[key] and true or false,
					groupKey = key, subtitle = e.subtitle or "", section = s.title });
				if ( not folded[key] ) then
					for i = #e.ranks, 1, -1 do
						local r = e.ranks[i];
						local copy = {};
						for k, v in pairs(r) do copy[k] = v; end
						copy.ranks, copy.groupKey, copy.section = nil, key, s.title;
						copy.subtitle = (r.sub and r.sub ~= "") and r.sub or (e.subtitle or "");
						table.insert(entries, copy);
					end
				end
			else
				table.insert(entries, e);
			end
		end
		table.insert(out, { title = s.title, entries = entries });
	end
	return out;
end

----------------------------------------------------------------------------------------------------------------------
-- Skills (GetSkillLineInfo)
----------------------------------------------------------------------------------------------------------------------
L.SKILL_ORDER = { "Weapon Skills", "Armor Proficiencies", "Secondary Skills", "Languages", "Class Skills", "Professions" };
local I = "Interface\\Icons\\";
L.SKILL_ICONS = {
	["swords"] = "INV_Sword_04", ["two-handed swords"] = "INV_Sword_39", ["axes"] = "INV_Axe_04", ["two-handed axes"] = "INV_Axe_09",
	["maces"] = "INV_Mace_04", ["two-handed maces"] = "INV_Hammer_05", ["staves"] = "INV_Staff_08", ["polearms"] = "INV_Spear_06",
	["daggers"] = "INV_Weapon_ShortBlade_05", ["fist weapons"] = "INV_Gauntlets_04", ["bows"] = "INV_Weapon_Bow_07",
	["crossbows"] = "INV_Weapon_Crossbow_01", ["guns"] = "INV_Weapon_Rifle_01", ["thrown"] = "INV_ThrowingKnife_02",
	["wands"] = "INV_Wand_01", ["unarmed"] = "Ability_GolemThunderClap", ["defense"] = "Ability_Defend", ["shield"] = "INV_Shield_04",
	["cloth"] = "INV_Chest_Cloth_21", ["leather"] = "INV_Chest_Leather_09", ["mail"] = "INV_Chest_Chain_05", ["plate mail"] = "INV_Chest_Plate01",
	["riding"] = "Ability_Mount_RidingHorse", ["first aid"] = "Spell_Holy_SealOfSacrifice", ["cooking"] = "INV_Misc_Food_15",
	["fishing"] = "Trade_Fishing", ["alchemy"] = "Trade_Alchemy", ["blacksmithing"] = "Trade_BlackSmithing",
	["enchanting"] = "Trade_Engraving", ["engineering"] = "Trade_Engineering", ["herbalism"] = "Spell_Nature_NatureTouchGrow",
	["inscription"] = "INV_Inscription_Tradeskill01", ["jewelcrafting"] = "INV_Misc_Gem_01", ["leatherworking"] = "Trade_LeatherWorking",
	["mining"] = "Trade_Mining", ["skinning"] = "INV_Misc_Pelt_Wolf_01", ["tailoring"] = "Trade_Tailoring", ["lockpicking"] = "Spell_Nature_MoonKey",
	["poisons"] = "Trade_BrewPoison",
};
L.SKILL_HEADER_ICONS = {
	["weapon skills"] = "INV_Sword_04", ["armor proficiencies"] = "INV_Chest_Chain_05", ["languages"] = "INV_Misc_Book_09",
	["secondary skills"] = "INV_Misc_Note_01", ["professions"] = "INV_Misc_Note_01", ["class skills"] = "INV_Misc_Book_11",
};

-- treeIcons: { [lower talent tree name] = icon } (class skills are named like the trees)
function L.SkillIcon(name, header, treeIcons)
	local n = lower(name);
	if ( L.SKILL_ICONS[n] ) then return I..L.SKILL_ICONS[n]; end
	if ( string.find(n, "^language") or lower(header) == "languages" ) then return I.."INV_Misc_Book_09"; end
	if ( treeIcons and treeIcons[n] ) then return treeIcons[n]; end
	return I..(L.SKILL_HEADER_ICONS[lower(header)] or "INV_Misc_QuestionMark");
end

-- lines: what GetSkillLineInfo gives, in order ({ name, header, rank, max, modifier, description }); returns sections
-- ({ title, entries }) in SKILL_ORDER, then any other heading in the client's order. A skill without a rank (max <= 1:
-- armour, some class skills) has rank nil.
function L.SkillSections(lines, treeIcons)
	local byTitle, seen, section = {}, {}, nil;
	for _, l in ipairs(lines) do
		if ( l.header ) then
			section = byTitle[l.name];
			if ( not section ) then
				section = { title = l.name, entries = {} };
				byTitle[l.name] = section;
				table.insert(seen, l.name);
			end
		elseif ( l.name ) then
			if ( not section ) then
				section = { title = "Skills", entries = {} }; byTitle["Skills"] = section; table.insert(seen, "Skills");
			end
			local ranked = (l.max or 0) > 1;
			table.insert(section.entries, { skill = true, name = l.name, rank = ranked and (l.rank or 0) or nil,
				max = ranked and l.max or nil, modifier = l.modifier or 0, description = l.description or "",
				icon = L.SkillIcon(l.name, section.title, treeIcons), subtitle = "", section = section.title,
				profession = (section.title == "Professions" or section.title == "Secondary Skills") });
		end
	end
	local out, used = {}, {};
	for _, t in ipairs(L.SKILL_ORDER) do
		if ( byTitle[t] and #byTitle[t].entries > 0 ) then table.insert(out, byTitle[t]); used[t] = true; end
	end
	for _, t in ipairs(seen) do
		if ( not used[t] and #byTitle[t].entries > 0 ) then table.insert(out, byTitle[t]); end
	end
	return out;
end

-- "300 / 450", "300 (+15) / 450", or "" without a rank
function L.SkillRankText(e)
	if ( not e.rank ) then return ""; end
	if ( e.modifier and e.modifier ~= 0 ) then
		return string.format("%d (%s%d) / %d", e.rank, e.modifier > 0 and "+" or "", e.modifier, e.max);
	end
	return string.format("%d / %d", e.rank, e.max);
end

-- { class = { {title, entries}, ... }, general = { ... } }
function L.Group(list, treeOrder, className)
	local trees = {};
	for _, t in ipairs(treeOrder) do trees[lower(t)] = t; end
	local books = { class = {}, general = {} };
	local index = { class = {}, general = {} };
	for _, e in ipairs(L.HighestRanks(list)) do
		local book, section, subtitle = L.Classify(e, trees, className);
		e.subtitle, e.section = subtitle, section;
		local sections = index[book];
		if ( not sections[section] ) then
			sections[section] = { title = section, entries = {} };
		end
		table.insert(sections[section].entries, e);
	end
	local function take(book, title)
		local s = index[book][title];
		if ( s ) then table.insert(books[book], s); index[book][title] = nil; end
	end
	if ( className ) then take("class", className); end
	for _, t in ipairs(treeOrder) do take("class", t); end
	for _, t in ipairs(L.GENERAL_ORDER) do take("general", t); end
	for _, book in ipairs({ "class", "general" }) do
		local rest = {};
		for title in pairs(index[book]) do table.insert(rest, title); end
		table.sort(rest);
		for _, title in ipairs(rest) do take(book, title); end
	end
	return books;
end

-- every word of the query in the name, subtitle, section or description
function L.Matches(e, query, description)
	query = lower(query);
	if ( query == "" ) then return true; end
	local text = lower(e.name).." "..lower(e.subtitle).." "..lower(e.section).." "..lower(description);
	for word in string.gmatch(query, "%S+") do
		if ( not string.find(text, word, 1, true) ) then return false; end
	end
	return true;
end

function L.Filter(sections, query, describe)
	if ( not query or query == "" ) then return sections; end
	local out = {};
	for _, s in ipairs(sections) do
		local keep = {};
		for _, e in ipairs(s.entries) do
			if ( L.Matches(e, query, describe and describe(e) or "") ) then table.insert(keep, e); end
		end
		if ( #keep > 0 ) then table.insert(out, { title = s.title, entries = keep }); end
	end
	return out;
end

-- pages of { kind = "header", text, y }, { kind = "group", entry, y } (a rank group's bar, full width) and
-- { kind = "spell", entry, col, y }; a heading or a group bar never ends a page, and a group starts and ends a row
function L.Paginate(sections, cols, pageHeight, headerHeight, rowHeight, gap, groupHeight)
	groupHeight = groupHeight or 24;
	local pages, page, y = {}, {}, 0;
	local function newPage() table.insert(pages, page); page, y = {}, 0; end
	for _, s in ipairs(sections) do
		if ( y > 0 and y + headerHeight + rowHeight > pageHeight ) then newPage(); end
		table.insert(page, { kind = "header", text = s.title, y = y });
		y = y + headerHeight;
		local col, lastGroup = 0, nil;
		for _, e in ipairs(s.entries) do
			if ( col > 0 and (e.group or e.groupKey ~= lastGroup) ) then col, y = 0, y + rowHeight; end
			lastGroup = e.groupKey;
			if ( e.group ) then
				if ( y > 0 and y + groupHeight + (e.folded and 0 or rowHeight) > pageHeight ) then newPage(); end
				table.insert(page, { kind = "group", entry = e, y = y });
				y = y + groupHeight;
			else
				if ( col == 0 and y + rowHeight > pageHeight ) then newPage(); end
				table.insert(page, { kind = "spell", entry = e, col = col, y = y });
				col = col + 1;
				if ( col == cols ) then col, y = 0, y + rowHeight; end
			end
		end
		if ( col > 0 ) then y = y + rowHeight; end
		y = y + gap;
	end
	if ( #page > 0 or #pages == 0 ) then table.insert(pages, page); end
	return pages;
end

----------------------------------------------------------------------------------------------------------------------
-- The window
----------------------------------------------------------------------------------------------------------------------
if ( not CreateFrame ) then return; end   -- tests load only the logic

-- the window is 860 wide on every tab (TemucraftPlayerSpells.lua): the panel inside is 832, a page 792 with 20 px
-- margins; two pages side by side in the wide view
local COLS, COL_WIDTH, PAGE_WIDTH, PAGE_HEIGHT = 3, 264, 792, 470;
local HEADER_HEIGHT, ROW_HEIGHT, GAP, GROUP_HEIGHT = 30, 50, 8, 24;
local PER_PAGE = COLS * floor(PAGE_HEIGHT / ROW_HEIGHT);
local GROUPS_PER_PAGE = floor(PAGE_HEIGHT / GROUP_HEIGHT);
local RANKS_KEY = "ui.bookranks";

local panel = CreateFrame("Frame", "TemucraftSpellBook", UIParent);
local book, page, wide, query = "class", 1, false, "";
local books, pages = { class = {}, general = {}, skills = {} }, {};
local described = {};      -- spell id -> lower-case tooltip text (search)
local pending = false;     -- a refresh waits for the end of combat
local folded = {};         -- "Show all ranks": the groups folded this session ("tab:name" -> true)
local function ShowAllRanks() return TemucraftStore_Get and TemucraftStore_Get("A", RANKS_KEY) == "all"; end

local combatNote = panel:CreateFontString(nil, "OVERLAY", "GameFontRedSmall");
combatNote:SetPoint("BOTTOM", 0, 38);
combatNote:SetText("In combat: the book updates when combat ends.");
combatNote:Hide();

-- book tabs at the top
local bookTabs = {};
-- retail-sized tabs (the small Options-style tabs were hard to read): dark, the selected one lit with a gold edge
local TAB_BACKDROP = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } };
local function BookTabSelect(tab, on)
	if ( on ) then
		tab:SetBackdropColor(0.35, 0.27, 0.08, 0.95); tab:SetBackdropBorderColor(1, 0.82, 0, 1);
		tab:GetFontString():SetTextColor(1, 1, 1);
	else
		tab:SetBackdropColor(0, 0, 0, 0.75); tab:SetBackdropBorderColor(0.5, 0.5, 0.5, 1);
		tab:GetFontString():SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
	end
end
local function BookTabSize(tab) tab:SetWidth(max(110, tab:GetFontString():GetStringWidth() + 36)); end
local function BookTab(i, key)
	local tab = CreateFrame("Button", "TemucraftSpellBookTab"..i, panel);
	tab:SetHeight(28); tab:SetWidth(110);
	tab:SetBackdrop(TAB_BACKDROP);
	tab:SetNormalFontObject(GameFontNormal); tab:SetHighlightFontObject(GameFontHighlight);
	tab:SetText(" ");
	tab:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD");
	tab.key = key;
	if ( i == 1 ) then tab:SetPoint("TOPLEFT", 20, -26); else tab:SetPoint("LEFT", bookTabs[i - 1], "RIGHT", 4, 0); end
	tab:SetScript("OnClick", function(self)
		PlaySound("igMainMenuOptionCheckBoxOn");
		book, page = self.key, 1;
		TemucraftSpellBook_Refresh();
	end);
	bookTabs[i] = tab;
	return tab;
end
BookTab(1, "class"); BookTab(2, "general"); BookTab(3, "skills");

-- Pet, Collections (and the Train button, below) sit in the middle of the bottom bar: the top row is the book tabs,
-- the ranks box and the search
local petButton = CreateFrame("Button", "TemucraftSpellBookPetButton", panel, "UIPanelButtonTemplate");
petButton:SetWidth(60); petButton:SetHeight(20);
petButton:SetText(PET or "Pet");
petButton:SetPoint("BOTTOM", panel, "BOTTOM", 0, 12);
petButton:SetScript("OnClick", function() TemucraftStockToggleSpellBook(BOOKTYPE_PET); end);

local collectionsButton = CreateFrame("Button", "TemucraftSpellBookCollectionsButton", panel, "UIPanelButtonTemplate");
collectionsButton:SetWidth(96); collectionsButton:SetHeight(20);
collectionsButton:SetText("Collections");
collectionsButton:SetPoint("LEFT", petButton, "RIGHT", 6, 0);
collectionsButton:SetScript("OnClick", function() if ( TemucraftCollections_Toggle ) then TemucraftCollections_Toggle(); end end);

-- search
local search = CreateFrame("EditBox", "TemucraftSpellBookSearch", panel, "InputBoxTemplate");
search:SetWidth(200); search:SetHeight(20);
search:SetAutoFocus(false);
search:SetPoint("TOPRIGHT", -50, -34);
local searchHint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
searchHint:SetPoint("LEFT", 2, 0);
searchHint:SetText("Search abilities, keywords");

-- highest rank only (default) or every rank, grouped
local ranksCheck = CreateFrame("CheckButton", "TemucraftSpellBookRanksCheck", panel, "UICheckButtonTemplate");
ranksCheck:SetWidth(24); ranksCheck:SetHeight(24);
ranksCheck:SetPoint("RIGHT", search, "LEFT", -112, 0);
_G[ranksCheck:GetName().."Text"]:SetText("Show all ranks");
ranksCheck:SetScript("OnClick", function(self)
	if ( InCombatLockdown() ) then
		self:SetChecked(ShowAllRanks());
		UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1);
		return;
	end
	PlaySound(self:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff");
	if ( TemucraftStore_Set ) then TemucraftStore_Set("A", RANKS_KEY, self:GetChecked() and "all" or ""); end
	page = 1;
	TemucraftSpellBook_Refresh();
end);
ranksCheck:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM");
	GameTooltip:SetText("Show all ranks");
	GameTooltip:AddLine("Off: one entry per spell, its highest rank; the arrow on its icon opens the lower ranks.", 1, 1, 1, true);
	GameTooltip:AddLine("On: every rank, under a bar with the spell's name (click the bar to fold it).", 1, 1, 1, true);
	GameTooltip:Show();
end);
ranksCheck:SetScript("OnLeave", function() GameTooltip:Hide(); end);
search:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); end);
search:SetScript("OnEditFocusGained", function() searchHint:Hide(); end);
search:SetScript("OnEditFocusLost", function(self) if ( self:GetText() == "" ) then searchHint:Show(); end end);
search:SetScript("OnTextChanged", function(self)
	local text = self:GetText();
	if ( text ~= "" ) then searchHint:Hide(); end
	if ( text == query ) then return; end
	query, page = text, 1;
	TemucraftSpellBook_Refresh();
end);

-- expand: two pages side by side
local expand = CreateFrame("Button", "TemucraftSpellBookExpandButton", panel);
expand:SetWidth(32); expand:SetHeight(32);
expand:SetPoint("TOPRIGHT", -10, -28);
local function ExpandTextures()
	local base = wide and "Interface\\Buttons\\UI-Panel-SmallerButton-" or "Interface\\Buttons\\UI-Panel-BiggerButton-";
	expand:SetNormalTexture(base.."Up"); expand:SetPushedTexture(base.."Down");
end
expand:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD");
ExpandTextures();
expand:SetScript("OnClick", function()
	if ( InCombatLockdown() ) then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1); return; end
	wide = not wide;
	ExpandTextures();
	TemucraftPlayerSpells_SetWide(wide);
	TemucraftSpellBook_Refresh();
end);
expand:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(wide and "One page" or "Two pages"); GameTooltip:Show();
end);
expand:SetScript("OnLeave", function() GameTooltip:Hide(); end);

-- back to the stock book
local classic = CreateFrame("CheckButton", "TemucraftSpellBookClassicCheck", panel, "UICheckButtonTemplate");
classic:SetWidth(24); classic:SetHeight(24);
classic:SetPoint("BOTTOMLEFT", 16, 8);
_G[classic:GetName().."Text"]:SetText("Classic spellbook");
classic:SetScript("OnClick", function(self)
	self:SetChecked(false);
	TemucraftPlayerSpells_SetClassic("book", true);
	TemucraftStockToggleSpellBook(BOOKTYPE_SPELL);
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffTemucraft:|r classic spellbook on (/tsb new for this one).");
end);

-- pages
local pageFrames, buttons, headers, groups, skills = {}, {}, {}, {}, {};
local scan = CreateFrame("GameTooltip", "TemucraftSpellBookScanTooltip", nil, "GameTooltipTemplate");

local function Describe(e)
	if ( e.skill ) then return string.lower(e.description or ""); end
	if ( e.flyout ) then
		local names = {};
		for _, m in ipairs(e.flyout.members) do table.insert(names, m.name or ""); end
		return string.lower(table.concat(names, " "));
	end
	if ( not e.id ) then return ""; end
	if ( not described[e.id] ) then
		scan:SetOwner(WorldFrame, "ANCHOR_NONE");
		scan:SetSpell(e.slot, BOOKTYPE_SPELL);
		local parts = {};
		for i = 2, scan:NumLines() do
			local left = _G["TemucraftSpellBookScanTooltipTextLeft"..i];
			if ( left and left:GetText() ) then table.insert(parts, left:GetText()); end
		end
		scan:Hide();
		described[e.id] = string.lower(table.concat(parts, " "));
	end
	return described[e.id];
end

local function LinkSpell(self)
	if ( not self.slot ) then return; end
	if ( MacroFrame and MacroFrame:IsShown() ) then
		if ( not self.passive ) then ChatEdit_InsertLink(self.spellName); end
		return;
	end
	local link, tradeLink = GetSpellLink(self.slot, BOOKTYPE_SPELL);
	if ( tradeLink or link ) then ChatEdit_InsertLink(tradeLink or link); end
end

local function UpdateCooldown(b)
	if ( not b.slot ) then b.cooldown:Hide(); return; end
	local start, duration, enable = GetSpellCooldown(b.slot, BOOKTYPE_SPELL);
	CooldownFrame_SetTimer(b.cooldown, start, duration, enable);
	if ( enable == 1 or enable == nil ) then b.icon:SetVertexColor(1, 1, 1); else b.icon:SetVertexColor(0.4, 0.4, 0.4); end
end

local function MakeButton(side, i)
	local name = "TemucraftSpellBookButton"..side.."_"..i;
	local b = CreateFrame("Button", name, pageFrames[side], "SecureActionButtonTemplate");
	b:SetWidth(36); b:SetHeight(36);
	b:RegisterForClicks("AnyUp");
	b:RegisterForDrag("LeftButton");
	local bg = b:CreateTexture(nil, "BACKGROUND");
	bg:SetTexture("Interface\\Spellbook\\UI-Spellbook-SpellBackground");
	bg:SetWidth(64); bg:SetHeight(64); bg:SetPoint("TOPLEFT", -3, 3);
	b.icon = b:CreateTexture(name.."Icon", "ARTWORK");
	b.icon:SetAllPoints();
	b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2");
	b.border = b:GetNormalTexture();
	b.border:ClearAllPoints(); b.border:SetWidth(64); b.border:SetHeight(64); b.border:SetPoint("CENTER", 0, -1);
	b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress");
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
	b.highlight = b:GetHighlightTexture();
	b.cooldown = CreateFrame("Cooldown", name.."Cooldown", b, "CooldownFrameTemplate");
	b.cooldown:SetAllPoints();
	b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	b.label:SetPoint("LEFT", b, "RIGHT", 8, 7);
	b.label:SetWidth(COL_WIDTH - 52); b.label:SetHeight(14); b.label:SetJustifyH("LEFT");
	b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
	b.sub:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -2);
	b.sub:SetWidth(COL_WIDTH - 52); b.sub:SetJustifyH("LEFT");
	-- shift-click links the spell (the secure click calls b.tclink), the rest casts
	b:SetAttribute("shift-type1", "tclink");
	b:SetAttribute("shift-type2", "tclink");
	b.tclink = LinkSpell;
	b:SetScript("OnDragStart", function(self)
		if ( self.slot and not self.flyout ) then PickupSpell(self.slot, BOOKTYPE_SPELL); end
	end);
	b:SetScript("OnEnter", function(self)
		if ( self.flyout ) then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetText(self.flyout.title);
			for _, m in ipairs(self.flyout.members) do GameTooltip:AddLine(m.name, 1, 1, 1); end
			GameTooltip:AddLine("Click to open.", 0.4, 0.78, 1);
			GameTooltip:Show();
			return;
		end
		if ( not self.slot ) then return; end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetSpell(self.slot, BOOKTYPE_SPELL);
	end);
	b:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	if ( TemucraftFlyouts_WrapButton ) then TemucraftFlyouts_WrapButton(b); end
	-- the lower ranks: a small arrow on the icon's right edge opens them in a row beside it (secure, so in combat too)
	local arrow = CreateFrame("Button", name.."RankArrow", b, "SecureActionButtonTemplate");
	arrow:SetWidth(14); arrow:SetHeight(14);
	arrow:SetPoint("LEFT", b, "RIGHT", -5, 0);
	arrow:SetFrameLevel(b:GetFrameLevel() + 3);
	arrow:RegisterForClicks("AnyUp");
	arrow:SetNormalTexture("Interface\\ChatFrame\\ChatFrameExpandArrow");
	arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD");
	arrow:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(b.spellName or "");
		GameTooltip:AddLine("Click for the lower ranks ("..(self.count or 0)..").", 0.4, 0.78, 1);
		GameTooltip:AddLine("Drag a rank to an action bar.", 0.7, 0.7, 0.7);
		GameTooltip:Show();
	end);
	arrow:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	if ( TemucraftFlyouts_WrapButton ) then TemucraftFlyouts_WrapButton(arrow); end
	arrow:Hide();
	b.arrow = arrow;
	b:Hide();
	return b;
end

-- a "Show all ranks" group bar: the spell's name; a click folds / unfolds its ranks (out of combat: the book moves)
local function MakeGroup(side, i)
	local g = CreateFrame("Button", "TemucraftSpellBookGroup"..side.."_"..i, pageFrames[side]);
	g:SetWidth(PAGE_WIDTH - 16); g:SetHeight(GROUP_HEIGHT - 4);
	g:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16 });
	g:SetBackdropColor(0.2, 0.15, 0.05, 0.55);
	g:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD");
	g.toggle = g:CreateTexture(nil, "ARTWORK");
	g.toggle:SetWidth(14); g.toggle:SetHeight(14); g.toggle:SetPoint("LEFT", 4, 0);
	g.icon = g:CreateTexture(nil, "ARTWORK");
	g.icon:SetWidth(16); g.icon:SetHeight(16); g.icon:SetPoint("LEFT", g.toggle, "RIGHT", 6, 0);
	g.label = g:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	g.label:SetPoint("LEFT", g.icon, "RIGHT", 6, 0);
	g.count = g:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
	g.count:SetPoint("LEFT", g.label, "RIGHT", 8, 0);
	g:SetScript("OnClick", function(self)
		if ( InCombatLockdown() ) then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1); return; end
		PlaySound("igMainMenuOptionCheckBoxOn");
		folded[self.key] = not folded[self.key] or nil;
		TemucraftSpellBook_Refresh();
	end);
	g:Hide();
	return g;
end

-- a skill: icon, name and its "current / max" bar (read only)
local function MakeSkill(side, i)
	local name = "TemucraftSpellBookSkill"..side.."_"..i;
	local k = CreateFrame("Button", name, pageFrames[side]);
	k:SetWidth(COL_WIDTH - 10); k:SetHeight(40);
	k.iconFrame = CreateFrame("Frame", nil, k);
	k.iconFrame:SetWidth(36); k.iconFrame:SetHeight(36); k.iconFrame:SetPoint("TOPLEFT");
	local bg = k.iconFrame:CreateTexture(nil, "BACKGROUND");
	bg:SetTexture("Interface\\Spellbook\\UI-Spellbook-SpellBackground");
	bg:SetWidth(64); bg:SetHeight(64); bg:SetPoint("TOPLEFT", -3, 3);
	k.icon = k.iconFrame:CreateTexture(nil, "ARTWORK"); k.icon:SetAllPoints();
	local border = k.iconFrame:CreateTexture(nil, "OVERLAY");
	border:SetTexture("Interface\\Buttons\\UI-Quickslot2");
	border:SetWidth(64); border:SetHeight(64); border:SetPoint("CENTER", 0, -1);
	k.label = k:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	k.label:SetPoint("TOPLEFT", k.iconFrame, "TOPRIGHT", 8, -2);
	k.label:SetWidth(COL_WIDTH - 52); k.label:SetHeight(14); k.label:SetJustifyH("LEFT");
	k.bar = CreateFrame("StatusBar", name.."Bar", k);
	k.bar:SetWidth(COL_WIDTH - 64); k.bar:SetHeight(13);
	k.bar:SetPoint("TOPLEFT", k.label, "BOTTOMLEFT", 0, -4);
	k.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
	k.bar:SetStatusBarColor(0.1, 0.35, 0.85);
	local barBg = k.bar:CreateTexture(nil, "BACKGROUND");
	barBg:SetAllPoints(); barBg:SetTexture(0, 0, 0, 0.55);
	k.bar.text = k.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	k.bar.text:SetPoint("CENTER", 0, 1);
	k:SetScript("OnEnter", function(self)
		local e = self.entry;
		if ( not e ) then return; end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(e.name);
		if ( e.rank ) then GameTooltip:AddLine("Skill "..L.SkillRankText(e), 1, 1, 1); end
		if ( e.description and e.description ~= "" ) then GameTooltip:AddLine(e.description, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true); end
		if ( e.profession ) then GameTooltip:AddLine("Recipes and training: the Professions window.", 0.6, 0.6, 0.6, true); end
		GameTooltip:Show();
	end);
	k:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	k:Hide();
	return k;
end

for side = 1, 2 do
	local p = CreateFrame("Frame", "TemucraftSpellBookPage"..side, panel);
	p:SetWidth(PAGE_WIDTH); p:SetHeight(PAGE_HEIGHT);
	p:SetPoint("TOPLEFT", 20 + (side - 1) * (PAGE_WIDTH + 20), -66);
	p.number = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	p.number:SetPoint("TOP", p, "BOTTOM", 0, -6);
	pageFrames[side] = p;
	buttons[side], headers[side], groups[side], skills[side] = {}, {}, {}, {};
	for i = 1, PER_PAGE do buttons[side][i] = MakeButton(side, i); end
	for i = 1, GROUPS_PER_PAGE do groups[side][i] = MakeGroup(side, i); end
	for i = 1, PER_PAGE do skills[side][i] = MakeSkill(side, i); end
	for i = 1, 8 do
		local h = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
		h:SetJustifyH("LEFT");
		local line = p:CreateTexture(nil, "ARTWORK");
		line:SetTexture(1, 0.82, 0, 0.35); line:SetHeight(1);
		h.line = line;
		headers[side][i] = h;
	end
	if ( side == 2 ) then p:Hide(); end
end

local prev = CreateFrame("Button", "TemucraftSpellBookPrevPageButton", panel);
local nextb = CreateFrame("Button", "TemucraftSpellBookNextPageButton", panel);
for _, a in ipairs({ { prev, "Prev" }, { nextb, "Next" } }) do
	local b, kind = a[1], a[2];
	b:SetWidth(32); b:SetHeight(32);
	b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-"..kind.."Page-Up");
	b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-"..kind.."Page-Down");
	b:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-"..kind.."Page-Disabled");
	b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD");
end
local pageText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal");
pageText:SetPoint("BOTTOMRIGHT", -60, 18);
nextb:SetPoint("LEFT", pageText, "RIGHT", 4, 0);
prev:SetPoint("RIGHT", pageText, "LEFT", -4, 0);
local function Step(delta)
	if ( InCombatLockdown() ) then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1); return; end
	page = page + delta;
	TemucraftSpellBook_Refresh();
end
prev:SetScript("OnClick", function() PlaySound("igAbiliityPageTurn"); Step(-1); end);
nextb:SetScript("OnClick", function() PlaySound("igAbiliityPageTurn"); Step(1); end);
panel:EnableMouseWheel(true);
panel:SetScript("OnMouseWheel", function(self, delta)
	if ( (delta > 0 and prev:IsEnabled() == 1) or (delta < 0 and nextb:IsEnabled() == 1) ) then Step(delta > 0 and -1 or 1); end
end);

-- reads the spellbook
local function Read()
	local list = {};
	local flagsOf = TemucraftSpellTabs_GetFlags or function() return 0; end;
	for tab = 1, GetNumSpellTabs() do
		local tabName, _, offset, numSpells = GetSpellTabInfo(tab);
		for slot = offset + 1, offset + numSpells do
			local name, sub = GetSpellName(slot, BOOKTYPE_SPELL);
			if ( name ) then
				local link = GetSpellLink(slot, BOOKTYPE_SPELL);
				local id = link and tonumber(string.match(link, "spell:(%d+)"));
				table.insert(list, { name = name, sub = sub, slot = slot, id = id, tab = tab, tabName = tabName,
					passive = IsPassiveSpell(slot, BOOKTYPE_SPELL) and true or false, flags = id and flagsOf(id) or 0,
					icon = GetSpellTexture(slot, BOOKTYPE_SPELL) });
			end
		end
	end
	if ( TemucraftFlyouts_Collapse ) then list = TemucraftFlyouts_Collapse(list); end
	local trees = {};
	for t = 1, GetNumTalentTabs() do
		local name = GetTalentTabInfo(t);
		if ( name ) then table.insert(trees, name); end
	end
	return L.Group(list, trees, (UnitClass("player")));
end

-- reads the skill lines (every heading opened first: the client lists only the lines under open ones)
local function ReadSkills()
	for i = GetNumSkillLines(), 1, -1 do
		local _, header, expanded = GetSkillLineInfo(i);
		if ( header and not expanded ) then ExpandSkillHeader(i); end
	end
	local lines = {};
	for i = 1, GetNumSkillLines() do
		local name, header, _, rank, _, modifier, maxRank, _, _, _, _, _, description = GetSkillLineInfo(i);
		if ( name ) then
			table.insert(lines, { name = name, header = header and true or false, rank = rank, max = maxRank,
				modifier = modifier, description = description });
		end
	end
	local treeIcons = {};
	for t = 1, GetNumTalentTabs() do
		local name, icon = GetTalentTabInfo(t);
		if ( name ) then treeIcons[string.lower(name)] = icon; end
	end
	return L.SkillSections(lines, treeIcons);
end

local function SetButton(b, e)
	b.slot, b.spellId, b.passive, b.spellName, b.flyout = e.slot, e.id, e.passive, e.name, e.flyout;
	b.icon:SetTexture(e.icon);
	b.label:SetText(e.name);
	b.sub:SetText(e.subtitle or "");
	if ( e.passive ) then
		b.border:SetVertexColor(0, 0, 0);
		b.highlight:SetTexture("Interface\\Buttons\\UI-PassiveHighlight");
		b.label:SetTextColor(PASSIVE_SPELL_FONT_COLOR.r, PASSIVE_SPELL_FONT_COLOR.g, PASSIVE_SPELL_FONT_COLOR.b);
		b:SetAttribute("type", nil);
		b:SetAttribute("spell", nil);
	else
		b.border:SetVertexColor(1, 1, 1);
		b.highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square");
		b.label:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
		if ( e.flyout ) then
			b:SetAttribute("type", nil);
			b:SetAttribute("spell", nil);
		else
			b:SetAttribute("type", "spell");
			b:SetAttribute("spell", e.id or e.name);
		end
	end
	if ( TemucraftFlyouts_Attach ) then TemucraftFlyouts_Attach(b, e.flyout); end
	-- highest rank only: the lower ranks behind the arrow
	local lowerRanks = (not e.flyout and not ShowAllRanks()) and L.LowerRanks(e) or {};
	if ( #lowerRanks > 0 and TemucraftFlyouts_Attach ) then
		b.arrow.count = #lowerRanks;
		TemucraftFlyouts_Attach(b.arrow, { key = "rank"..b:GetName(), title = e.name, members = lowerRanks }, b);
		b.arrow:Show();
	end
	UpdateCooldown(b);
	b:Show();
end

local function SetSkill(k, e)
	k.entry = e;
	k.icon:SetTexture(e.icon);
	k.label:SetText(e.name);
	if ( e.rank ) then
		k.label:ClearAllPoints(); k.label:SetPoint("TOPLEFT", k.iconFrame, "TOPRIGHT", 8, -2);
		k.bar:SetMinMaxValues(0, max(1, e.max));
		k.bar:SetValue(min(e.max, e.rank));
		k.bar.text:SetText(L.SkillRankText(e));
		k.bar:Show();
	else
		k.label:ClearAllPoints(); k.label:SetPoint("LEFT", k.iconFrame, "RIGHT", 8, 0);
		k.bar:Hide();
	end
	k:Show();
end

local function Draw(side, items, number)
	local p = pageFrames[side];
	for _, b in ipairs(buttons[side]) do
		b:Hide(); b.slot, b.flyout = nil, nil;
		b.arrow:Hide();
		if ( TemucraftFlyouts_Attach ) then TemucraftFlyouts_Attach(b, nil); TemucraftFlyouts_Attach(b.arrow, nil); end
	end
	for _, h in ipairs(headers[side]) do h:Hide(); h.line:Hide(); end
	for _, g in ipairs(groups[side]) do g:Hide(); end
	for _, k in ipairs(skills[side]) do k:Hide(); k.entry = nil; end
	if ( not items ) then p.number:SetText(""); return; end
	p.number:SetText(number);
	local nb, nh, ng, nk = 0, 0, 0, 0;
	for _, item in ipairs(items) do
		if ( item.kind == "header" and nh < #headers[side] ) then
			nh = nh + 1;
			local h = headers[side][nh];
			h:ClearAllPoints(); h:SetPoint("TOPLEFT", p, "TOPLEFT", 4, -item.y - 6);
			h:SetText(item.text); h:Show();
			h.line:ClearAllPoints();
			h.line:SetPoint("LEFT", h, "RIGHT", 8, 0);
			h.line:SetWidth(max(10, PAGE_WIDTH - 30 - h:GetStringWidth()));
			h.line:Show();
		elseif ( item.kind == "group" and ng < #groups[side] ) then
			ng = ng + 1;
			local g, e = groups[side][ng], item.entry;
			g.key = e.groupKey;
			g:ClearAllPoints(); g:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -item.y - 2);
			g.toggle:SetTexture(e.folded and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up");
			g.icon:SetTexture(e.icon);
			g.label:SetText(e.name);
			g.count:SetText(e.count.." ranks"..((e.subtitle and e.subtitle ~= "") and ("  -  "..e.subtitle) or ""));
			g:Show();
		elseif ( item.kind == "spell" and item.entry.skill ) then
			if ( nk < PER_PAGE ) then
				nk = nk + 1;
				local k = skills[side][nk];
				k:ClearAllPoints();
				k:SetPoint("TOPLEFT", p, "TOPLEFT", 8 + item.col * COL_WIDTH, -item.y - 6);
				SetSkill(k, item.entry);
			end
		elseif ( item.kind == "spell" and nb < PER_PAGE ) then
			nb = nb + 1;
			local b = buttons[side][nb];
			b:ClearAllPoints();
			b:SetPoint("TOPLEFT", p, "TOPLEFT", 8 + item.col * COL_WIDTH, -item.y - 6);
			SetButton(b, item.entry);
		end
	end
end

local function Render()
	pending = false;
	if ( TemucraftFlyouts_HideAll ) then TemucraftFlyouts_HideAll(); end
	combatNote:Hide();
	books = Read();
	if ( book == "skills" ) then books.skills = ReadSkills(); end
	local sections = L.Filter(books[book] or {}, query, Describe);
	if ( book ~= "skills" and ShowAllRanks() ) then sections = L.ExpandRanks(sections, folded); end
	pages = L.Paginate(sections, COLS, PAGE_HEIGHT, HEADER_HEIGHT, ROW_HEIGHT, GAP, GROUP_HEIGHT);
	local per = wide and 2 or 1;
	local spreads = max(1, ceil(#pages / per));
	if ( page > spreads ) then page = spreads; end
	if ( page < 1 ) then page = 1; end
	local first = (page - 1) * per + 1;
	if ( #sections == 0 ) then
		Draw(1, nil); Draw(2, nil);
		pageText:SetText(query ~= "" and "Nothing matches." or "");
	else
		Draw(1, pages[first], wide and tostring(first) or "");
		Draw(2, wide and pages[first + 1] or nil, tostring(first + 1));
		pageText:SetText(format("Page %d / %d", page, spreads));
	end
	if ( wide ) then pageFrames[2]:Show(); else pageFrames[2]:Hide(); end
	if ( page > 1 ) then prev:Enable(); else prev:Disable(); end
	if ( page < spreads ) then nextb:Enable(); else nextb:Disable(); end
end
local function UpdateTabs()
	bookTabs[1]:SetText((UnitClass("player")));
	bookTabs[2]:SetText(GENERAL or "General");
	bookTabs[3]:SetText(SKILLS or "Skills");
	ranksCheck:SetChecked(ShowAllRanks());
	if ( book == "skills" ) then ranksCheck:Hide(); else ranksCheck:Show(); end
	searchHint:SetText(book == "skills" and "Search skills" or "Search abilities, keywords");
	for _, tab in ipairs(bookTabs) do
		BookTabSize(tab);
		BookTabSelect(tab, tab.key == book);
	end
	if ( HasPetSpells() ) then petButton:Show(); else petButton:Hide(); end
end

function TemucraftSpellBook_Refresh()
	if ( not panel:IsShown() ) then pending = true; return; end
	UpdateTabs();
	if ( InCombatLockdown() ) then
		pending = true;
		combatNote:Show();
		TemucraftPlayerSpells_AfterCombat("spellbook", function() if ( panel:IsShown() ) then Render(); end end);
		return;
	end
	Render();
end

-- the Train button and automatic-learning checkbox of TemucraftAutoLearn.lua come along while the book is open
local function Borrow(on)
	local train, check = TemucraftTrainButton, TemucraftAutoLearnCheck;
	if ( not train ) then return; end
	train:SetParent(on and panel or SpellBookFrame);
	train:ClearAllPoints();
	if ( on ) then train:SetPoint("RIGHT", petButton, "LEFT", -10, 0);
	else train:SetPoint("TOPRIGHT", SpellBookFrame, "TOPRIGHT", -44, -40); end
	if ( check ) then check:SetParent(on and panel or SpellBookFrame); end
end

panel:SetScript("OnShow", function()
	Borrow(true);
	TemucraftSpellBook_Refresh();
end);
panel:SetScript("OnHide", function()
	Borrow(false);
	search:ClearFocus();
	if ( wide ) then wide = false; ExpandTextures(); TemucraftPlayerSpells_SetWide(false); end
end);

TemucraftPlayerSpells_AddPanel(TEMUCRAFT_PLAYERSPELLS_TAB_SPELLBOOK, panel);

-- changes to the book, throttled to one refresh per frame
local events = CreateFrame("Frame");
local dirty = false;
events:RegisterEvent("SPELLS_CHANGED");
events:RegisterEvent("LEARNED_SPELL_IN_TAB");
events:RegisterEvent("PLAYER_TALENT_UPDATE");
events:RegisterEvent("SPELL_UPDATE_COOLDOWN");
events:RegisterEvent("SKILL_LINES_CHANGED");
events:SetScript("OnEvent", function(self, event)
	if ( event == "SKILL_LINES_CHANGED" and book ~= "skills" ) then return; end
	if ( event == "SPELL_UPDATE_COOLDOWN" ) then
		if ( panel:IsShown() ) then
			for side = 1, 2 do for _, b in ipairs(buttons[side]) do if ( b:IsShown() ) then UpdateCooldown(b); end end end
		end
		return;
	end
	if ( event == "LEARNED_SPELL_IN_TAB" or event == "PLAYER_TALENT_UPDATE" ) then wipe(described); end
	if ( not dirty ) then
		dirty = true;
		self:SetScript("OnUpdate", function(f)
			f:SetScript("OnUpdate", nil);
			dirty = false;
			if ( panel:IsShown() ) then TemucraftSpellBook_Refresh(); end
		end);
	end
end);
-- the server's answer about what each spell is (racial, profession, guild perk)
function TemucraftSpellBook_OnFlags() if ( panel:IsShown() ) then TemucraftSpellBook_Refresh(); end end
