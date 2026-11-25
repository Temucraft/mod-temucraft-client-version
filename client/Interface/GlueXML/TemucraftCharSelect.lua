--[[
	Temucraft character select, the retail way: character cards on the right (name, level, class colour, zone with its
	version bracket, faction crest), a search box over them, a top bar with Menu (Options, AddOns, Credits,
	Cinematics, Exit) and Realms, an eye button that hides the interface to show only the scene, Create / Delete
	under the cards. Enter World, Back and the rotate buttons stay the client's own.

	The client's CharacterSelect.lua (patch-<locale>-C) still runs: its character list is only moved into a hidden
	holder, and the cards call its functions (CharacterSelect_SelectCharacter, CharacterSelect_EnterWorld ...). The
	background is the client's too: each character's race scene (SetBackgroundModel in GlueParent.lua, which also
	applies the player's own picks from Interface\TemucraftScenes.lua).

	The cards can be put in any order: drag one onto another, or use the arrows on the selected card. The order is kept
	per account and realm in the client's saved account list (Config.wtf accountList, which AccountLogin.lua already
	uses for the saved accounts) as its own segment after a "~" (see Logic.SplitSaved). The cards always hand the
	client its own character index (c.id), whatever their order on screen.

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

-- "Dalaran" -> "Dalaran (Wrath of the Lich King)": the client only gives the zone's name, so only names whose zones
-- are on more than one map get a bracket, the one of their first row (see docs/zone-brackets.md)
function Logic.ZoneText(zone)
	if ( not zone or zone == "" ) then
		return "";
	end
	-- Our AreaTable names already carry a long bracket ("Valley of Trials (Durotar, Classic)"): keep only the name, then
	-- add the short label below when the name really is on more than one map
	local base = string.match(zone, "^(.-)%s*%b()$");
	if ( base and base ~= "" ) then
		zone = base;
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

-- Character order -------------------------------------------------------------------------------------------------
-- The cards in the saved order (a list of names); characters not in it (new ones) come after, in the client's order.
-- Names in it that are gone (deleted, renamed) are skipped.
function Logic.ApplyOrder(chars, names)
	if ( not names or #names == 0 ) then
		return chars;
	end
	local byName, used, out = {}, {}, {};
	for _, c in ipairs(chars) do
		if ( c.name and not byName[c.name] ) then byName[c.name] = c; end
	end
	for _, name in ipairs(names) do
		local c = byName[name];
		if ( c and not used[c] ) then
			used[c] = true;
			table.insert(out, c);
		end
	end
	for _, c in ipairs(chars) do
		if ( not used[c] ) then
			used[c] = true;
			table.insert(out, c);
		end
	end
	return out;
end

function Logic.Names(chars)
	local out = {};
	for i, c in ipairs(chars) do out[i] = c.name; end
	return out;
end

-- Put chars[from] where chars[to] is (the others move up or down one). Returns true if something moved.
function Logic.Move(chars, from, to)
	if ( not from or not to or from == to or not chars[from] or not chars[to] ) then
		return false;
	end
	local c = table.remove(chars, from);
	table.insert(chars, to, c);
	return true;
end

function Logic.IndexOf(chars, id)
	for i, c in ipairs(chars) do
		if ( c.id == id ) then return i; end
	end
	return nil;
end

-- The saved account list holds AccountLogin.lua's saved accounts ("tc1:" and hex, or the client's own "name|!name|"),
-- then "~" and the orders. The orders use only the letters g-v (two per byte), so AccountLogin's hex reader and the
-- client's own "[%w!]+" reader of that string never mix them up with theirs.
Logic.ORDER_MARK = "~";
Logic.ACCOUNTS_TAG = "tc1:";
Logic.MAX_ORDERS, Logic.MAX_NAMES, Logic.MAX_SAVED = 10, 60, 3000;

function Logic.SplitSaved(raw)
	raw = raw or "";
	local at = string.find(raw, Logic.ORDER_MARK, 1, true);
	if ( not at ) then
		return raw, "";
	end
	return string.sub(raw, 1, at - 1), string.sub(raw, at + 1);
end

function Logic.JoinSaved(accounts, orders)
	accounts = accounts or "";
	if ( not orders or orders == "" ) then
		return accounts == Logic.ACCOUNTS_TAG and "" or accounts;
	end
	if ( accounts == "" ) then
		accounts = Logic.ACCOUNTS_TAG;   -- keeps the client from reading the orders as its own list of names
	end
	return accounts..Logic.ORDER_MARK..orders;
end

-- what AccountLogin.lua (and the client) get from GetSavedAccountList: the saved accounts only
function Logic.AccountsPart(raw)
	local accounts = Logic.SplitSaved(raw);
	if ( accounts == Logic.ACCOUNTS_TAG ) then
		return "";
	end
	return accounts;
end

function Logic.Encode(text)
	return (string.gsub(text, ".", function(ch)
		local b = string.byte(ch);
		return string.char(103 + math.floor(b / 16), 103 + b % 16);
	end));
end

function Logic.Decode(code)
	local out = {};
	for hi, lo in string.gmatch(code or "", "([g-v])([g-v])") do
		out[#out + 1] = string.char((string.byte(hi) - 103) * 16 + string.byte(lo) - 103);
	end
	return table.concat(out);
end

function Logic.OrderKey(account, realm)
	return string.upper(account or "").."\t"..(realm or "");
end

-- orders: { keys = { key, ... } (latest first), [key] = { name, ... } }
function Logic.ParseOrders(code)
	local orders = { keys = {} };
	for line in string.gmatch(Logic.Decode(code), "([^\n]+)") do
		local account, realm, rest = string.match(line, "^([^\t]*)\t([^\t]*)\t?(.*)$");
		if ( account ) then
			local key = Logic.OrderKey(account, realm);
			if ( not orders[key] ) then
				local names = {};
				for name in string.gmatch(rest, "([^\t]+)") do table.insert(names, name); end
				orders[key] = names;
				table.insert(orders.keys, key);
			end
		end
	end
	return orders;
end

function Logic.SerializeOrders(orders)
	local lines = {};
	for _, key in ipairs(orders.keys) do
		if ( #lines >= Logic.MAX_ORDERS ) then break; end
		local names = orders[key];
		if ( names and #names > 0 ) then
			local keep = {};
			for i = 1, math.min(#names, Logic.MAX_NAMES) do keep[i] = names[i]; end
			table.insert(lines, key.."\t"..table.concat(keep, "\t"));
		end
	end
	local code = Logic.Encode(table.concat(lines, "\n"));
	while ( string.len(code) > Logic.MAX_SAVED and #lines > 1 ) do   -- the oldest go first
		table.remove(lines);
		code = Logic.Encode(table.concat(lines, "\n"));
	end
	return code;
end

-- the order saved for an account and realm, from the whole saved account list
function Logic.GetOrder(raw, account, realm)
	local _, code = Logic.SplitSaved(raw);
	return Logic.ParseOrders(code)[Logic.OrderKey(account, realm)];
end

-- the whole saved account list with this order for an account and realm (it becomes the latest)
function Logic.SetOrder(raw, account, realm, names)
	local accounts, code = Logic.SplitSaved(raw);
	local orders = Logic.ParseOrders(code);
	local key = Logic.OrderKey(account, realm);
	for i = #orders.keys, 1, -1 do
		if ( orders.keys[i] == key ) then table.remove(orders.keys, i); end
	end
	local clean = {};
	for _, name in ipairs(names or {}) do
		if ( name ~= "" and not string.find(name, "[\t\n]") ) then table.insert(clean, name); end
	end
	orders[key] = clean;
	table.insert(orders.keys, 1, key);
	return Logic.JoinSaved(accounts, Logic.SerializeOrders(orders));
end

-- Cut a text to n characters (UTF-8), for the one-line zone
function Logic.Utf8Sub(text, n)
	local out, k = {}, 0;
	for ch in string.gmatch(text or "", "[%z\1-\127\192-\253][\128-\191]*") do
		k = k + 1;
		if ( k > n ) then break; end
		out[k] = ch;
	end
	return table.concat(out), k;
end
function Logic.Utf8Len(text)
	local _, n = string.gsub(text or "", "[%z\1-\127\192-\253]", "");
	return n;
end

---------------------------------------------------------------------------------------------------------------------
-- The screen (only in the client)
---------------------------------------------------------------------------------------------------------------------
if ( not CharacterSelect or not CreateFrame ) then
	return;
end

local CARD_HEIGHT, CARD_WIDTH, VISIBLE = 58, 270, 9;
local ZONE_WIDTH, ZONE_WIDTH_SELECTED = CARD_WIDTH - 58, CARD_WIDTH - 80;   -- the zone line ends before the crest (and the order arrows)
local root, holder, cards, eye, menu = nil, nil, {}, nil, nil;
local list, shown, offset, lastQuery = {}, {}, 0, nil;
local hiddenByEye;
local returnToSelect = false;
local throttle = 0;
local dragging, dragEnded, dragFrame, dragTick = nil, false, nil, 0;

-- The saved account list: everyone else (AccountLogin.lua's saved accounts, the client's own code) sees it without
-- the character orders, and keeps them when it writes it (see Logic.SplitSaved)
local rawGetSaved, rawSetSaved = GetSavedAccountList, SetSavedAccountList;
if ( rawGetSaved and rawSetSaved ) then
	GetSavedAccountList = function(...)
		return Logic.AccountsPart(rawGetSaved(...));
	end
	SetSavedAccountList = function(text, ...)
		if ( type(text) == "string" and not string.find(text, Logic.ORDER_MARK, 1, true) ) then
			local _, code = Logic.SplitSaved(rawGetSaved() or "");
			text = Logic.JoinSaved(text, code);
		end
		return rawSetSaved(text, ...);
	end
end

local function CurrentAccount()
	local name = AccountLoginAccountEdit and AccountLoginAccountEdit.GetText and AccountLoginAccountEdit:GetText();
	if ( (not name or name == "") and GetSavedAccountName ) then
		name = GetSavedAccountName();
	end
	return name or "";
end
local function CurrentRealm()
	return GetServerName and GetServerName() or "";
end
local function LoadOrder()
	if ( not rawGetSaved ) then return nil; end
	return Logic.GetOrder(rawGetSaved() or "", CurrentAccount(), CurrentRealm());
end
local function SaveOrder()
	if ( not rawSetSaved ) then return; end
	rawSetSaved(Logic.SetOrder(rawGetSaved() or "", CurrentAccount(), CurrentRealm(), Logic.Names(list)));
end

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
	list = Logic.ApplyOrder(list, LoadOrder());
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

-- Put character <id> where character <targetId> is, in the saved order
local function MoveCharacter(id, targetId)
	if ( Logic.Move(list, Logic.IndexOf(list, id), Logic.IndexOf(list, targetId)) ) then
		SaveOrder();
		return true;
	end
	return false;
end

-- The arrows on the selected card: one place up (-1) or down (1) among the cards on screen
local function MoveSelected(delta)
	local sel = CharacterSelect.selectedIndex or 0;
	local i = Logic.IndexOf(shown, sel);
	local target = i and shown[i + delta];
	if ( target ) then
		MoveCharacter(sel, target.id);
		PlaySound("igMainMenuOptionCheckBoxOn");
	end
	Refresh();
end

-- One line: cut with "..." when it is wider than the card leaves room for
local function SetOneLine(fs, text, width)
	fs:SetText(text);
	if ( not fs.GetStringWidth or (fs:GetStringWidth() or 0) <= width ) then
		return;
	end
	local lo, hi = 0, Logic.Utf8Len(text);
	while ( lo < hi ) do
		local mid = math.floor((lo + hi + 1) / 2);
		fs:SetText(Logic.Utf8Sub(text, mid).."...");
		if ( (fs:GetStringWidth() or 0) <= width ) then lo = mid; else hi = mid - 1; end
	end
	fs:SetText(Logic.Utf8Sub(text, lo).."...");
end

-- Dragging a card: the card under the cursor, and whether the cursor is above the first or below the last card
local function CardUnderCursor()
	if ( not GetCursorPosition ) then return nil; end
	local _, y = GetCursorPosition();
	local first, last;
	for n = 1, VISIBLE do
		local b = cards[n];
		if ( b and b:IsShown() and b.id ) then
			local scale = (b.GetEffectiveScale and b:GetEffectiveScale()) or 1;
			local top, bottom = b:GetTop(), b:GetBottom();
			if ( top and bottom and y ) then
				local cy = y / scale;
				local gap = (CARD_HEIGHT - (top - bottom)) / 2 + 1;
				if ( cy <= top + gap and cy >= bottom - gap ) then
					return b;
				end
				if ( not first ) then first = b; if ( cy > top ) then return b, "above"; end end
				last = b;
			end
		end
	end
	if ( last ) then
		return last, "below";
	end
	return nil;
end

local function DragUpdate(_, elapsed)
	if ( not dragging ) then return; end
	local b, edge = CardUnderCursor();
	dragTick = dragTick + (elapsed or 0);
	if ( edge and dragTick > 0.15 ) then   -- held above or below the cards: scroll
		dragTick = 0;
		offset = offset + ((edge == "above") and -1 or 1);
		Clamp();
		Refresh(true);
	end
	local line = root.dropLine;
	if ( b and b.id and b.id ~= dragging ) then
		local from, to = Logic.IndexOf(list, dragging), Logic.IndexOf(list, b.id);
		line:ClearAllPoints();
		if ( from and to and to > from ) then
			line:SetPoint("TOP", b, "BOTTOM", 0, 1);
		else
			line:SetPoint("BOTTOM", b, "TOP", 0, -1);
		end
		line:Show();
	else
		line:Hide();
	end
end

local function StartDrag(self)
	if ( not self.id or #list < 2 ) then return; end
	dragging, dragTick = self.id, 0;
	HideTooltip();
	dragFrame:Show();
	Refresh(true);
end

local function StopDrag(self)
	if ( not dragging ) then return; end
	local id = dragging;
	local target = CardUnderCursor();
	dragging = nil;
	dragEnded = true;   -- the click that ends a drag does not select
	dragFrame:Hide();
	root.dropLine:Hide();
	if ( target and target.id and target.id ~= id and MoveCharacter(id, target.id) ) then
		PlaySound("igMainMenuOptionCheckBoxOn");
	end
	Refresh(true);
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
	b.zone:SetWidth(ZONE_WIDTH); b.zone:SetJustifyH("LEFT");   -- one line: SetOneLine cuts it to fit
	b.crest = b:CreateTexture(nil, "ARTWORK");
	b.crest:SetWidth(36); b.crest:SetHeight(36);
	b.crest:SetPoint("RIGHT", b, "RIGHT", -6, 0);
	-- its place in the list ("3"), shown in the top right corner; the tooltip says "3 of 6"
	b.order = b:CreateFontString(nil, "OVERLAY", "GlueFontDisableSmall");
	b.order:SetPoint("TOPRIGHT", b, "TOPRIGHT", -46, -6);
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
	-- c.id is the client's own index of the character, whatever the card's place on screen
	-- Dragging without OnDragStart (the glue screens don't always send it): a press that moves more than a few pixels
	-- starts a drag, the release ends it (the card keeps the mouse until the button is let go)
	b:SetScript("OnMouseDown", function(self, button)
		dragEnded = false;
		if ( button == "LeftButton" and GetCursorPosition ) then
			local _, y = GetCursorPosition();
			self.pressY = y;
		end
	end);
	b:SetScript("OnMouseUp", function(self)
		self.pressY = nil;
		if ( dragging ) then
			StopDrag(self);
		end
	end);
	b:SetScript("OnUpdate", function(self)
		if ( self.pressY and not dragging and GetCursorPosition ) then
			local _, y = GetCursorPosition();
			if ( y and math.abs(y - self.pressY) > 8 ) then
				self.pressY = nil;
				StartDrag(self);
			end
		end
	end);
	b:SetScript("OnEnter", function(self)
		if ( self.place and not dragging ) then
			Tooltip(self, self.place.." of "..#list..(#list > 1 and "|n|cffaaaaaaDrag to change the order|r" or ""));
		end
	end);
	b:SetScript("OnLeave", HideTooltip);
	b:SetScript("OnClick", function(self)
		if ( dragEnded ) then
			dragEnded = false;
			return;
		end
		if ( self.id and self.id ~= CharacterSelect.selectedIndex ) then
			if ( CharacterSelectUI ) then CharacterSelectUI.id = self.id; end
			CharacterSelect_SelectCharacter(self.id);
		end
		Refresh();
	end);
	b:SetScript("OnDoubleClick", function(self)
		if ( dragEnded or dragging ) then
			return;
		end
		if ( self.id and self.id ~= CharacterSelect.selectedIndex ) then
			CharacterSelect_SelectCharacter(self.id);
		end
		CharacterSelect_EnterWorld();
	end);
	if ( b.RegisterForDrag ) then
		b:RegisterForDrag("LeftButton");
		b:SetScript("OnDragStart", function(self) self.pressY = nil; if ( not dragging ) then StartDrag(self); end end);
		b:SetScript("OnDragStop", StopDrag);
	end
	-- the order arrows (selected card only)
	for _, dir in ipairs({ { "up", -1, "Up", 8 }, { "down", 1, "Down", -8 } }) do
		local a = CreateFrame("Button", "TemucraftSelectCard"..n..dir[3], b);
		a:SetWidth(20); a:SetHeight(20);
		a:SetPoint("RIGHT", b, "RIGHT", -44, dir[4]);
		a:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-Scroll"..dir[3].."Button-Up");
		a:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-Scroll"..dir[3].."Button-Down");
		a:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-Scroll"..dir[3].."Button-Disabled");
		a:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-Scroll"..dir[3].."Button-Highlight", "ADD");
		a:SetScript("OnClick", function() MoveSelected(dir[2]); end);
		a:SetScript("OnEnter", function(self) Tooltip(self, (dir[2] < 0) and "Move up" or "Move down"); end);
		a:SetScript("OnLeave", HideTooltip);
		a:Hide();
		b[dir[1]] = a;
	end
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
			local width = (c.id == sel) and ZONE_WIDTH_SELECTED or ZONE_WIDTH;
			b.zone:SetWidth(width);
			SetOneLine(b.zone, c.zone or "", width);
			if ( c.faction == "Alliance" or c.faction == "Horde" ) then
				b.crest:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..c.faction);
				b.crest:SetTexCoord(0, 0.625, 0, 0.625);
				b.crest:Show();
			else
				b.crest:Hide();
			end
			if ( c.paid ) then b.paid:Show(); else b.paid:Hide(); end
			b.place = Logic.IndexOf(list, c.id);
			b.order:SetText((#list > 1 and b.place and c.id ~= sel) and tostring(b.place) or "");
			if ( c.id == sel ) then b.selected:Show(); else b.selected:Hide(); end
			local pos = (c.id == sel and not dragging and #shown > 1) and (offset + n) or nil;
			if ( pos ) then b.up:Show(); b.down:Show(); else b.up:Hide(); b.down:Hide(); end
			if ( pos == 1 ) then b.up:Disable(); else b.up:Enable(); end
			if ( pos == #shown ) then b.down:Disable(); else b.down:Enable(); end
			b:SetAlpha((dragging and c.id == dragging) and 0.45 or 1);
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
	-- Temucraft: Live or PTR is chosen in the launcher (it writes realmName), so no realm list in game.
	-- Set TEMUCRAFT_SHOW_REALMS = true (e.g. in TemucraftScenes.lua) to bring the button back.
	if ( not TEMUCRAFT_SHOW_REALMS ) then root.realms:Hide(); end
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
	root.dropLine = root.list:CreateTexture(nil, "OVERLAY");
	root.dropLine:SetTexture(1, 0.82, 0, 0.9);
	root.dropLine:SetWidth(CARD_WIDTH - 8); root.dropLine:SetHeight(2);
	root.dropLine:Hide();
	dragFrame = CreateFrame("Frame", nil, root);
	dragFrame:SetScript("OnUpdate", DragUpdate);
	dragFrame:Hide();
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

-- The arrow keys go through the cards in their order on screen (the client's own go by its index)
local oldKeyDown = CharacterSelect_OnKeyDown;
if ( oldKeyDown ) then
	CharacterSelect_OnKeyDown = function(self, key, ...)
		local step = (key == "UP" or key == "LEFT") and -1 or ((key == "DOWN" or key == "RIGHT") and 1) or nil;
		if ( step and Active() and root and root:IsShown() and #shown > 1 ) then
			local i = Logic.IndexOf(shown, CharacterSelect.selectedIndex or 0);
			local c = i and shown[(i - 1 + step) % #shown + 1] or shown[1];
			if ( CharacterSelectUI ) then CharacterSelectUI.id = c.id; end
			CharacterSelect_SelectCharacter(c.id);
			Refresh();
			return;
		end
		return oldKeyDown(self, key, ...);
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
