--[[
	Temucraft character select, the retail way. On the right a dark panel with a gold border: a Search box (magnifier,
	"Search") with an (i) tooltip and a square "+" (Create Character) beside it; below, the characters in groups
	("Characters" by default, the player can add, rename and delete groups) with collapsible headers; each card has
	the place number, the name in gold, "Level 80 Mage" (class in its colour), the zone on one line (short version
	bracket) and the faction crest (full colour on the selected card, a little dimmed on the others). Cards are always
	dark; the selected one gets a gold border and a soft gold glow, a hovered one a faint light bar. At the bottom a red Create
	Character button, a square Delete Character (trash) and a square Restore Deleted Character button. A top bar with
	Back on the left (the client's CharacterSelect_Exit), the realm name in the middle and Menu (Options, AddOns,
	Credits, Cinematics, Exit) on the right; an eye button (or Alt-Z) hides the interface. Enter World and the rotate
	buttons stay the client's own.

	The client's CharacterSelect.lua (patch-<locale>-C) still runs: its character list is only moved into a hidden
	holder, and the cards call its functions (CharacterSelect_SelectCharacter, CharacterSelect_EnterWorld ...). The
	background is the client's too: each character's race scene (SetBackgroundModel in GlueParent.lua, which also
	applies the player's own picks from Interface\TemucraftScenes.lua). Delete asks with our own dialog (type DELETE,
	or the client's own word for it) and then calls the client's DeleteCharacter(index).

	Cards are put in any order and group by dragging (onto a card: there; onto a group header: into that group) or by
	right-click (Move to group > ...). The groups and the order are kept per account and realm in the client's saved
	account list (Config.wtf accountList, which AccountLogin.lua already uses for the saved accounts) as its own segment
	after a "~" (see Logic.SplitSaved and Logic.GroupsFromEntries). The cards always hand the client its own character
	index (c.id), whatever their order on screen.

	The card tooltip (left of the list) shows what the character list has (name, realm, class, level, zone) and, from
	TEMUCRAFT_CHAR_SUMMARY (Interface\TemucraftCharSummary.lua, written by the launcher), the spec, professions, gold
	and unread mail; see that file for the format.

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
Logic.MAX_ORDERS, Logic.MAX_NAMES, Logic.MAX_SAVED = 10, 80, 3000;   -- MAX_NAMES: entries (names and group headers)

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

-- orders: { keys = { key, ... } (latest first), [key] = { entry, ... } } (entries: names and group headers, see
-- Logic.GroupsFromEntries; the old saved orders are names only)
function Logic.ParseOrders(code)
	local orders = { keys = {} };
	for line in string.gmatch(Logic.Decode(code), "([^\n]+)") do
		local account, realm, rest = string.match(line, "^([^\t]*)\t([^\t]*)\t?(.*)$");
		if ( account ) then
			local key = Logic.OrderKey(account, realm);
			if ( not orders[key] ) then
				local entries = {};
				for entry in string.gmatch(rest, "([^\t]+)") do table.insert(entries, entry); end
				orders[key] = entries;
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

-- Groups ------------------------------------------------------------------------------------------------------------
-- A saved order is a list of entries: character names and group headers. A header is "#", the kind ("*" the default
-- group, "=" one of the player's), the state ("+" open, "-" collapsed) and the name (the default group's is "" until
-- the player renames it: it shows as "Characters"). The names after a header are in that group, the names before any
-- header in the default group. Only the default group, open and not renamed, is saved as names only: exactly the old
-- format, so orders saved before groups read the same (and an old client reads a header as a name that is gone).
-- groups: { { name = "", default = true, collapsed = nil, names = { "Jaina", ... } }, ... }, always one default group.
Logic.DEFAULT_GROUP = "Characters";
Logic.MAX_GROUP_NAME = 24;

function Logic.NewGroup(name, isDefault)
	return { name = name or "", default = isDefault and true or nil, names = {} };
end

function Logic.GroupName(g)
	return (g and g.name and g.name ~= "") and g.name or Logic.DEFAULT_GROUP;
end

-- the index of the group shown with this name (any case)
function Logic.FindGroup(groups, name)
	name = string.lower(name or "");
	for i, g in ipairs(groups) do
		if ( string.lower(Logic.GroupName(g)) == name ) then return i; end
	end
	return nil;
end

function Logic.DefaultGroup(groups)
	for i, g in ipairs(groups) do
		if ( g.default ) then return g, i; end
	end
	return nil;
end

function Logic.GroupsFromEntries(entries)
	local groups, default, cur, seen = {}, nil, nil, {};
	for _, e in ipairs(entries or {}) do
		local kind, state, name = string.match(e, "^#([%*=])([%+%-])(.*)$");
		if ( kind == "*" ) then
			if ( not default ) then default = Logic.NewGroup("", true); table.insert(groups, default); end
			default.name = name;
			default.collapsed = (state == "-") or nil;
			cur = default;
		elseif ( kind == "=" ) then
			local at = Logic.FindGroup(groups, name);
			if ( at and not groups[at].default ) then
				cur = groups[at];
			elseif ( name ~= "" and not at ) then
				cur = Logic.NewGroup(name);
				cur.collapsed = (state == "-") or nil;
				table.insert(groups, cur);
			end
		elseif ( e ~= "" and not seen[e] ) then
			seen[e] = true;
			if ( not cur ) then
				if ( not default ) then default = Logic.NewGroup("", true); table.insert(groups, default); end
				cur = default;
			end
			table.insert(cur.names, e);
		end
	end
	if ( not default ) then table.insert(groups, Logic.NewGroup("", true)); end
	return groups;
end

function Logic.EntriesFromGroups(groups)
	local out = {};
	local only = groups[1];
	local simple = (#groups == 1 and only.default and not only.collapsed and (only.name or "") == "");
	for _, g in ipairs(groups) do
		if ( not simple ) then
			table.insert(out, "#"..(g.default and "*" or "=")..(g.collapsed and "-" or "+")..(g.name or ""));
		end
		for _, n in ipairs(g.names) do
			if ( n ~= "" and not string.find(n, "[\t\n]") ) then table.insert(out, n); end
		end
	end
	return out;
end

function Logic.FlatNames(groups)
	local out = {};
	for _, g in ipairs(groups) do
		for _, n in ipairs(g.names) do table.insert(out, n); end
	end
	return out;
end

-- The characters (in the client's order) in their groups: each group gets .chars, its .names become the names of
-- the characters it has (gone ones drop out), characters in no group go last into the default group. Every character
-- gets .group (its group's index) and .place (its place counting down all the groups).
function Logic.Arrange(chars, groups)
	groups = groups or { Logic.NewGroup("", true) };
	local byName, used, out, default = {}, {}, {}, nil;
	for _, c in ipairs(chars) do
		if ( c.name and not byName[c.name] ) then byName[c.name] = c; end
	end
	for _, g in ipairs(groups) do
		local ng = { name = g.name or "", default = g.default, collapsed = g.collapsed, names = {}, chars = {} };
		for _, n in ipairs(g.names or {}) do
			local c = byName[n];
			if ( c and not used[c] ) then
				used[c] = true;
				table.insert(ng.chars, c);
				table.insert(ng.names, n);
			end
		end
		if ( ng.default and not default ) then default = ng; elseif ( ng.default ) then ng.default = nil; end
		table.insert(out, ng);
	end
	if ( not default ) then
		default = { name = "", default = true, names = {}, chars = {} };
		table.insert(out, default);
	end
	for _, c in ipairs(chars) do
		if ( not used[c] ) then
			used[c] = true;
			table.insert(default.chars, c);
			if ( c.name ) then table.insert(default.names, c.name); end
		end
	end
	local place = 0;
	for gi, g in ipairs(out) do
		for _, c in ipairs(g.chars) do
			place = place + 1;
			c.group, c.place = gi, place;
		end
	end
	return out;
end

function Logic.Flatten(groups)
	local out = {};
	for _, g in ipairs(groups) do
		for _, c in ipairs(g.chars or {}) do table.insert(out, c); end
	end
	return out;
end

function Logic.FindName(groups, name)
	for gi, g in ipairs(groups) do
		for ni, n in ipairs(g.names) do
			if ( n == name ) then return gi, ni; end
		end
	end
	return nil;
end

-- Move a character into group toGroup: where beforeName is (in its own group: like Logic.Move, it takes the other's
-- place; from another group: just before it), or last when beforeName is nil or not in that group.
function Logic.MoveName(groups, name, toGroup, beforeName)
	local gi, ni = Logic.FindName(groups, name);
	local target = groups[toGroup];
	if ( not gi or not target or beforeName == name ) then return false; end
	local ti;
	if ( beforeName ) then
		local bgi, bni = Logic.FindName(groups, beforeName);
		if ( bgi == toGroup ) then ti = bni; end
	end
	if ( gi == toGroup ) then
		if ( ti ) then return Logic.Move(target.names, ni, ti); end
		if ( ni == #target.names ) then return false; end
		table.insert(target.names, table.remove(target.names, ni));
		return true;
	end
	table.remove(groups[gi].names, ni);
	if ( ti ) then table.insert(target.names, ti, name); else table.insert(target.names, name); end
	return true;
end

function Logic.CleanGroupName(text)
	text = string.gsub(text or "", "[%c|]", "");
	text = string.match(text, "^%s*(.-)%s*$") or "";
	return (Logic.Utf8Sub(text, Logic.MAX_GROUP_NAME));
end

-- a new group (before the default group); returns its index, or nil and "empty" / "exists"
function Logic.AddGroup(groups, text)
	local name = Logic.CleanGroupName(text);
	if ( name == "" ) then return nil, "empty"; end
	if ( Logic.FindGroup(groups, name) ) then return nil, "exists"; end
	local _, at = Logic.DefaultGroup(groups);
	at = at or (#groups + 1);
	table.insert(groups, at, Logic.NewGroup(name));
	return at;
end

function Logic.RenameGroup(groups, index, text)
	local g = groups[index];
	if ( not g ) then return nil, "missing"; end
	local name = Logic.CleanGroupName(text);
	if ( g.default and (name == "" or string.lower(name) == string.lower(Logic.DEFAULT_GROUP)) ) then
		g.name = "";
		return index;
	end
	if ( name == "" ) then return nil, "empty"; end
	local other = Logic.FindGroup(groups, name);
	if ( other and other ~= index ) then return nil, "exists"; end
	g.name = name;
	return index;
end

-- a group goes, its characters go to the end of the default group (the default group itself can't go)
function Logic.DeleteGroup(groups, index)
	local g = groups[index];
	if ( not g or g.default ) then return false; end
	local default = Logic.DefaultGroup(groups);
	for _, n in ipairs(g.names) do table.insert(default.names, n); end
	table.remove(groups, index);
	return true;
end

-- What the list shows: { kind = "header", group = i, count = n } and { kind = "card", c = char, group = i }, and the
-- cards shown, in order. A collapsed group shows only its header; while searching only the groups with a match show,
-- open.
function Logic.Rows(groups, query)
	local rows, shownChars = {}, {};
	local searching = string.find(query or "", "%S") ~= nil;
	for gi, g in ipairs(groups) do
		local chars = searching and Logic.Filter(g.chars or {}, query) or (g.chars or {});
		if ( not searching or #chars > 0 ) then
			table.insert(rows, { kind = "header", group = gi, count = #(g.chars or {}) });
			if ( searching or not g.collapsed ) then
				for _, c in ipairs(chars) do
					table.insert(rows, { kind = "card", c = c, group = gi });
					table.insert(shownChars, c);
				end
			end
		end
	end
	return rows, shownChars;
end

function Logic.SetEntriesRaw(raw, account, realm, entries)
	local accounts, code = Logic.SplitSaved(raw);
	local orders = Logic.ParseOrders(code);
	local key = Logic.OrderKey(account, realm);
	for i = #orders.keys, 1, -1 do
		if ( orders.keys[i] == key ) then table.remove(orders.keys, i); end
	end
	orders[key] = entries;
	table.insert(orders.keys, 1, key);
	return Logic.JoinSaved(accounts, Logic.SerializeOrders(orders));
end

local SetEntries = Logic.SetEntriesRaw;

-- Login-screen settings (the glue screens can't register a CVar of their own): kept in the same saved account list,
-- as one more order line under the account "*" and realm "temucraft", its entries "name=value" (character names
-- have no "="). Setting one makes that line the latest, so the MAX_ORDERS cut never drops it while it is in use.
Logic.SETTINGS_ACCOUNT, Logic.SETTINGS_REALM = "*", "temucraft";
function Logic.GetSetting(raw, name)
	local _, code = Logic.SplitSaved(raw);
	local entries = Logic.ParseOrders(code)[Logic.OrderKey(Logic.SETTINGS_ACCOUNT, Logic.SETTINGS_REALM)];
	for _, e in ipairs(entries or {}) do
		local k, v = string.match(e, "^([^=]+)=(.*)$");
		if ( k == name ) then return v; end
	end
	return nil;
end
function Logic.SetSetting(raw, name, value)
	local _, code = Logic.SplitSaved(raw);
	local old = Logic.ParseOrders(code)[Logic.OrderKey(Logic.SETTINGS_ACCOUNT, Logic.SETTINGS_REALM)] or {};
	local entries = {};
	for _, e in ipairs(old) do
		if ( string.match(e, "^([^=]+)=") ~= name ) then table.insert(entries, e); end
	end
	if ( value ~= nil and value ~= "" ) then table.insert(entries, name.."="..tostring(value)); end
	if ( #entries == 0 ) then entries = { "-=" }; end   -- an empty line would be dropped, and with it the order
	return Logic.SetEntriesRaw(raw, Logic.SETTINGS_ACCOUNT, Logic.SETTINGS_REALM, entries);
end

-- the order saved for an account and realm (the names, down all the groups), from the whole saved account list
function Logic.GetOrder(raw, account, realm)
	local _, code = Logic.SplitSaved(raw);
	local entries = Logic.ParseOrders(code)[Logic.OrderKey(account, realm)];
	return entries and Logic.FlatNames(Logic.GroupsFromEntries(entries)) or nil;
end

-- the groups saved for an account and realm, or nil
function Logic.GetGroups(raw, account, realm)
	local _, code = Logic.SplitSaved(raw);
	local entries = Logic.ParseOrders(code)[Logic.OrderKey(account, realm)];
	return entries and Logic.GroupsFromEntries(entries) or nil;
end

-- the whole saved account list with this order (one group) for an account and realm (it becomes the latest)
function Logic.SetOrder(raw, account, realm, names)
	local g = Logic.NewGroup("", true);
	for _, name in ipairs(names or {}) do table.insert(g.names, name); end
	return SetEntries(raw, account, realm, Logic.EntriesFromGroups({ g }));
end

-- the same with groups
function Logic.SetGroups(raw, account, realm, groups)
	return SetEntries(raw, account, realm, Logic.EntriesFromGroups(groups));
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

-- The PTR client (its character create knows 30 races) logged into a realm that isn't a PTR realm
function Logic.WrongRealm(maxRaces, server)
	return (tonumber(maxRaces) or 0) >= 30 and server ~= nil and server ~= "" and not string.find(string.upper(server), "PTR", 1, true);
end

-- Delete confirmation ------------------------------------------------------------------------------------------------
-- The word to type: the client's own (DELETE_CONFIRM_STRING, e.g. "УДАЛИТЬ" in ruRU), the one for the client's
-- language, always the English DELETE, and the word in Latin letters where it has others (for players without that
-- keyboard), any case.
Logic.DELETE_WORDS = {
	enUS = { "DELETE" }, enGB = { "DELETE" },
	ruRU = { "УДАЛИТЬ", "UDALIT" }, deDE = { "LÖSCHEN", "LOESCHEN", "LOSCHEN" }, frFR = { "SUPPRIMER" },
	esES = { "BORRAR" }, esMX = { "BORRAR" }, koKR = { "삭제" }, zhCN = { "删除" }, zhTW = { "刪除" },
};

-- Upper case for a-z, Cyrillic (а-я, ё ...) and Latin-1 letters (ö, é ...); string.upper only knows a-z, and only
-- a-z is touched here, whatever the C library's locale does to other bytes
function Logic.Upper(text)
	text = string.gsub(text or "", "[a-z]", function(ch) return string.char(string.byte(ch) - 32); end);
	return (string.gsub(text, "([\192-\223])([\128-\191])", function(a, b)
		local x, y = string.byte(a), string.byte(b);
		if ( x == 208 and y >= 176 ) then return string.char(208, y - 32); end                      -- а-п
		if ( x == 209 and y <= 143 ) then return string.char(208, y + 32); end                      -- р-я
		if ( x == 209 and y <= 159 ) then return string.char(208, y - 16); end                      -- ѐ-џ (ё)
		if ( x == 195 and y >= 160 and y <= 190 and y ~= 183 ) then return string.char(195, y - 32); end   -- à-þ
		return a..b;
	end));
end

function Logic.Trim(text)
	return string.match(text or "", "^%s*(.-)%s*$") or "";
end

function Logic.DeleteWords(locale, localized)
	local out, set = {}, {};
	local function add(w)
		w = Logic.Upper(Logic.Trim(w));
		if ( w ~= "" and not set[w] ) then set[w] = true; table.insert(out, w); end
	end
	if ( type(localized) == "string" ) then add(localized); end
	for _, w in ipairs(Logic.DELETE_WORDS[locale or ""] or {}) do add(w); end
	add("DELETE");
	return out, set;
end

function Logic.DeleteOk(text, locale, localized)
	local _, set = Logic.DeleteWords(locale, localized);
	return set[Logic.Upper(Logic.Trim(text))] or false;
end

-- the word the dialog asks for, and its instructions: the client's own text, with "(or DELETE)" when the word isn't
-- the English one
function Logic.DeleteWord(locale, localized)
	if ( type(localized) == "string" and localized ~= "" ) then return localized; end
	local words = Logic.DELETE_WORDS[locale or ""];
	return words and words[1] or "DELETE";
end

function Logic.DeleteInstructions(locale, localized, stock)
	local word = Logic.DeleteWord(locale, localized);
	local text = (type(stock) == "string" and stock ~= "") and stock or ("Type \""..word.."\" into the field to confirm.");
	if ( Logic.Upper(word) ~= "DELETE" ) then
		text = text.." (or DELETE)";
	end
	return text;
end

-- Cards and their tooltip ------------------------------------------------------------------------------------------
-- Retail's list: every card has the same dark background and the same fonts; the selected one only gets a bright gold
-- border, a soft gold glow and its crest at full strength; hovered cards a faint light highlight (see MakeCard). The
-- crest keeps its faction colour on every card, a little dimmed on the ones not selected.
-- "1.": the card's place down all the groups, on every card (also with one character)
function Logic.CardNumber(c)
	local n = c and (c.place or c.id);
	return n and (n..".") or "";
end

-- One frame per card, on its edge: 1 px grey, or 2 px gold on the selected card with a soft gold glow inside it (low
-- alpha, fading inward; no fill, so the card stays as dark as the others). The number in the name's font, a dimmer gold.
function Logic.CardStyle(selected, hovered)
	local st = { bg = { 0.10, 0.10, 0.12, 0.94 }, crestDesaturated = false, name = { 1, 0.82, 0 }, num = { 0.78, 0.64, 0.16 } };
	if ( selected ) then
		st.border, st.borderSize, st.glow, st.glowAlpha, st.crestAlpha = { 1, 0.82, 0.18, 1 }, 2, true, 0.22, 1;
	else
		st.border, st.borderSize, st.glow, st.glowAlpha, st.crestAlpha = { 0.32, 0.32, 0.36, 0.9 }, 1, false, 0, hovered and 1 or 0.65;
	end
	return st;
end

function Logic.Thousands(n)
	local s = tostring(math.floor(tonumber(n) or 0));
	local k;
	repeat s, k = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2"); until ( k == 0 );
	return s;
end

Logic.COIN_ICONS = {
	g = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t", s = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t",
	c = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t",
};
-- 162575561 -> "16,257 g 55 s 61 c" (or with the coin pictures)
function Logic.Money(copper, icons)
	copper = math.floor(tonumber(copper) or 0);
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100;
	local function unit(u) return icons and Logic.COIN_ICONS[u] or (" "..u); end
	local parts = {};
	if ( g > 0 ) then table.insert(parts, Logic.Thousands(g)..unit("g")); end
	if ( g > 0 or s > 0 ) then table.insert(parts, s..unit("s")); end
	table.insert(parts, c..unit("c"));
	return table.concat(parts, " ");
end

-- what the launcher wrote for a character (Interface\TemucraftCharSummary.lua), or nil
function Logic.Summary(data, realm, name)
	local r = type(data) == "table" and data[realm or ""];
	local s = type(r) == "table" and r[name or ""];
	return type(s) == "table" and s or nil;
end

function Logic.MailText(summary)
	local mail = summary and summary.mail;
	if ( type(mail) == "table" and #mail > 0 ) then
		return "Unread mail from:\n"..table.concat(mail, ", ");
	elseif ( mail == true ) then
		return "Unread mail";
	end
	return nil;
end

-- the card tooltip, line by line: name, realm (grey), spec and class (class colour), level, zone (grey), professions,
-- gold; spec, professions and gold only when the launcher's summary has them
function Logic.TooltipLines(c, realm, summary, hint, icons)
	local lines = { "|cffffd100"..(c.name or "").."|r" };
	if ( realm and realm ~= "" ) then table.insert(lines, "|cff9d9d9d"..realm.."|r"); end
	local spec = summary and type(summary.spec) == "string" and summary.spec ~= "" and summary.spec;
	local class = (spec and (spec.." ") or "")..(c.class or "");
	local color = c.classFile and Logic.CLASS_COLORS[c.classFile];
	if ( class ~= "" ) then table.insert(lines, color and ("|cff"..color..class.."|r") or class); end
	table.insert(lines, "|cffffffff".."Level "..(c.level or 0).."|r");
	if ( c.zone and c.zone ~= "" ) then table.insert(lines, "|cff9d9d9d"..c.zone.."|r"); end
	local prof = summary and summary.professions;
	if ( type(prof) == "table" and #prof > 0 ) then prof = table.concat(prof, ", "); end
	if ( type(prof) == "string" and prof ~= "" ) then table.insert(lines, "|cffffffff"..prof.."|r"); end
	if ( summary and tonumber(summary.money) ) then table.insert(lines, "|cffffffff"..Logic.Money(summary.money, icons).."|r"); end
	if ( hint ) then table.insert(lines, "|cff7f7f7f"..hint.."|r"); end
	return lines;
end

---------------------------------------------------------------------------------------------------------------------
-- The screen (only in the client)
---------------------------------------------------------------------------------------------------------------------
if ( not CharacterSelect or not CreateFrame ) then
	return;
end

local CARD_HEIGHT, CARD_WIDTH, HEADER_HEIGHT, VISIBLE = 68, 270, 28, 8;
local AREA = VISIBLE * CARD_HEIGHT;            -- the height the rows (headers and cards) get
local ROWS_TOP = 56;                           -- below the search row
local ZONE_WIDTH = CARD_WIDTH - 66;            -- the zone line ends before the crest
local root, holder, eye, menu, tip = nil, nil, nil, nil, nil;
local cards, headers, rowFrames = {}, {}, {};
local roster, groups, list, rows, shown, offset, lastQuery = {}, nil, {}, {}, {}, 0, nil;
local hiddenByEye;
local returnToSelect = false;
local throttle = 0;
local dragging, dragEnded, dragFrame, dragTick = nil, false, nil, 0;
local deleteDialog, groupDialog, popups, popupBlocker = nil, nil, {}, nil;

-- 3.3.5 art only (Interface\Glues\Common, Interface\DialogFrame, Interface\Tooltips, Interface\AchievementFrame ...)
local ART = {
	panelBg = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
	panelEdge = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
	tipBg = "Interface\\Tooltips\\UI-Tooltip-Background",
	edge = "Interface\\Tooltips\\UI-Tooltip-Border",
	card = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal-Desaturated",
	header = "Interface\\AchievementFrame\\UI-Achievement-Category-Background",
	listHighlight = "Interface\\Buttons\\UI-Listbox-Highlight",     -- gold bar (header hover, selected card's glow)
	listHighlight2 = "Interface\\Buttons\\UI-Listbox-Highlight2",   -- light grey bar (card hover)
	selected = "Interface\\Glues\\CharacterSelect\\Glues-CharacterSelect-Highlight",   -- gold, fading to the right
	buttonUp = "Interface\\Glues\\Common\\Glue-Panel-Button-Up",
	buttonDown = "Interface\\Glues\\Common\\Glue-Panel-Button-Down",
	buttonHighlight = "Interface\\Glues\\Common\\Glue-Panel-Button-Highlight",
	input = "Interface\\Common\\Common-Input-Border",
	search = "Interface\\Common\\UI-Searchbox-Icon",
	plus = "Interface\\Buttons\\UI-PlusButton-Up", minus = "Interface\\Buttons\\UI-MinusButton-Up",
	trash = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
	restore = "Interface\\Icons\\Spell_Holy_Resurrection",
	mail = "Interface\\Minimap\\Tracking\\Mailbox",
	ring = "Interface\\Minimap\\MiniMap-TrackingBorder",
	alert = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew",
	popupHighlight = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
};

-- 3.3.5 has no restore of deleted characters at character select. On Temucraft the Curator (mod-temucraft-shop)
-- brings them back in game, for tokens (CharDelete.Method = 1 keeps them), so the button says where.
local HEADER_HINT = "Click: open or close\nRight-click: rename or delete";
local RESTORE_TEXT ="Restore Deleted Character\n|cffff4040Deleted characters can't be restored here: the Temucraft Curator|r\n|cffff4040(in game, the shop) brings them back for tokens.|r";

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

-- the login-screen settings for the other glue files (character create's Classic race portraits, the Options window)
TemucraftGlueSetting_Get = function(name)
	return rawGetSaved and Logic.GetSetting(rawGetSaved() or "", name) or nil;
end
TemucraftGlueSetting_Set = function(name, value)
	if ( rawGetSaved and rawSetSaved ) then rawSetSaved(Logic.SetSetting(rawGetSaved() or "", name, value)); end
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
local function Locale()
	return GetLocale and GetLocale() or "enUS";
end
local function LoadGroups()
	if ( not rawGetSaved ) then return nil; end
	return Logic.GetGroups(rawGetSaved() or "", CurrentAccount(), CurrentRealm());
end
local function SaveOrder()
	if ( not rawSetSaved or not groups ) then return; end
	rawSetSaved(Logic.SetGroups(rawGetSaved() or "", CurrentAccount(), CurrentRealm(), groups));
end

local function Active()
	return TEMUCRAFT_LOGIN_UI ~= "classic";
end
TemucraftCharSelect_Active = Active;

-- GlueTooltip_SetOwner only adds a point (it never clears the old ones): a tooltip shown with another anchor before
-- stretched between both. So the points are cleared first; point/relTo/relPoint/x/y anchor it somewhere else.
local function Tooltip(owner, text, point, relTo, relPoint, x, y)
	if ( text and GlueTooltip_SetOwner and GlueTooltip ) then
		GlueTooltip:ClearAllPoints();
		if ( point ) then
			GlueTooltip:SetPoint(point, relTo or owner, relPoint or point, x or 0, y or 0);
			GlueTooltip:Show();
		else
			GlueTooltip_SetOwner(owner);
		end
		GlueTooltip_SetText(text);
	end
end
local function HideTooltip()
	if ( GlueTooltip ) then GlueTooltip:Hide(); end
end

---------------------------------------------------------------------------------------------------------------------
-- Look: the glue screens have no FrameXML templates, so the pieces are made here
---------------------------------------------------------------------------------------------------------------------
-- the retail panel: dark, gold metal border
local function Panel(parent, alpha)
	local f = CreateFrame("Frame", nil, parent);
	f:SetBackdrop({ bgFile = ART.panelBg, edgeFile = ART.panelEdge, tile = true, tileSize = 32, edgeSize = 24,
		insets = { left = 6, right = 6, top = 6, bottom = 6 } });
	f:SetBackdropColor(1, 1, 1, alpha or 0.94);
	return f;
end

-- a tooltip-like box (the card tooltip, the popups)
local function TipBox(parent)
	local f = CreateFrame("Frame", nil, parent);
	f:SetBackdrop({ bgFile = ART.tipBg, edgeFile = ART.edge, tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 } });
	f:SetBackdropColor(0.03, 0.03, 0.05, 0.96);
	f:SetBackdropBorderColor(0.8, 0.65, 0.3, 1);
	return f;
end

-- the client's red button
local function SmallButton(name, parent, text, width, onClick, template)
	local b = CreateFrame("Button", name, parent, template or "GlueButtonSmallTemplate");
	b:SetWidth(width); b:SetHeight(28);
	b:SetText(text);
	b:SetScript("OnClick", onClick);
	return b;
end

-- a square red button with a gold edge and an icon (or a "+")
local function SquareButton(name, parent, size, icon, label, onClick)
	local b = CreateFrame("Button", name, parent);
	b:SetWidth(size); b:SetHeight(size);
	b:SetBackdrop({ edgeFile = ART.edge, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	b:SetBackdropBorderColor(1, 0.78, 0.3, 1);
	b.face = b:CreateTexture(nil, "BACKGROUND");
	b.face:SetTexture(ART.buttonUp);
	b.face:SetTexCoord(0.08, 0.54, 0.1, 0.58);
	b.face:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3);
	b.face:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3);
	local hl = b:CreateTexture(nil, "HIGHLIGHT");
	hl:SetTexture(ART.buttonHighlight);
	hl:SetTexCoord(0.08, 0.54, 0.1, 0.58);
	hl:SetBlendMode("ADD");
	hl:SetAllPoints(b.face);
	if ( icon ) then
		b.icon = b:CreateTexture(nil, "ARTWORK");
		b.icon:SetTexture(icon);
		b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -7);
		b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -7, 7);
	end
	if ( label ) then
		b.label = b:CreateFontString(nil, "OVERLAY", "GlueFontNormalLarge");
		b.label:SetPoint("CENTER", b, "CENTER", 1, 1);
		b.label:SetText(label);
	end
	b:SetScript("OnMouseDown", function(self) if ( self:IsEnabled() ) then self.face:SetTexture(ART.buttonDown); end end);
	b:SetScript("OnMouseUp", function(self) self.face:SetTexture(ART.buttonUp); end);
	b:SetScript("OnClick", onClick);
	b:SetScript("OnLeave", HideTooltip);
	return b;
end

local function SetSquareEnabled(b, on)
	if ( on ) then b:Enable(); else b:Disable(); end
	if ( b.icon ) then b.icon:SetDesaturated(not on and 1 or nil); end
	b.face:SetVertexColor(on and 1 or 0.5, on and 1 or 0.5, on and 1 or 0.5);
end

-- an edit box with the client's input border
local function InputBox(name, parent, width, height)
	local e = CreateFrame("EditBox", name, parent);
	e:SetWidth(width); e:SetHeight(height or 26);
	e:SetFontObject(GlueFontHighlightSmall);
	e:SetAutoFocus(false);
	e:SetTextInsets(8, 8, 0, 0);
	local fill = e:CreateTexture(nil, "BACKGROUND");
	fill:SetTexture(0, 0, 0, 0.75);
	fill:SetPoint("TOPLEFT", e, "TOPLEFT", 2, -3);
	fill:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", -2, 3);
	local l = e:CreateTexture(nil, "BORDER");
	l:SetTexture(ART.input); l:SetTexCoord(0, 0.0625, 0, 0.625);
	l:SetWidth(8); l:SetHeight(height or 26);
	l:SetPoint("LEFT", e, "LEFT", -2, 0);
	local r = e:CreateTexture(nil, "BORDER");
	r:SetTexture(ART.input); r:SetTexCoord(0.9375, 1, 0, 0.625);
	r:SetWidth(8); r:SetHeight(height or 26);
	r:SetPoint("RIGHT", e, "RIGHT", 2, 0);
	local m = e:CreateTexture(nil, "BORDER");
	m:SetTexture(ART.input); m:SetTexCoord(0.0625, 0.9375, 0, 0.625);
	m:SetHeight(height or 26);
	m:SetPoint("LEFT", l, "RIGHT", 0, 0);
	m:SetPoint("RIGHT", r, "LEFT", 0, 0);
	return e;
end

---------------------------------------------------------------------------------------------------------------------
-- The characters
---------------------------------------------------------------------------------------------------------------------
local function Rearrange()
	groups = Logic.Arrange(roster, groups);
	list = Logic.Flatten(groups);
end

local function ReadCharacters()
	roster = {};
	for id = 1, GetNumCharacters() do
		local name, race, class, level, zone, sex, ghost, PCC, PRC, PFC = GetCharacterInfo(id);
		if ( name ) then
			local colored = GetColorByClass and GetColorByClass(class) or class;
			local classFile = Logic.ClassFile(class, colored);
			local bgFile = GetSelectBackgroundModel and GetSelectBackgroundModel(id);
			table.insert(roster, {
				id = id, name = name, race = race, class = class, level = level or 0, ghost = ghost,
				zone = Logic.ZoneText(zone), classFile = classFile, faction = Logic.Faction(race, bgFile),
				paid = (PFC and PAID_FACTION_CHANGE) or (PRC and PAID_RACE_CHANGE) or (PCC and PAID_CHARACTER_CUSTOMIZATION) or nil,
			});
		end
	end
	groups = LoadGroups();
	Rearrange();
end

local function CharById(id)
	for _, c in ipairs(list) do
		if ( c.id == id ) then return c; end
	end
	return nil;
end

local Refresh;

local function RowHeight(r)
	return (r.kind == "header") and HEADER_HEIGHT or CARD_HEIGHT;
end
-- the furthest the list scrolls: the last rows just fill it
local function MaxOffset()
	local total, k = 0, #rows;
	while ( k >= 1 and total + RowHeight(rows[k]) <= AREA ) do
		total = total + RowHeight(rows[k]);
		k = k - 1;
	end
	return k;
end
local function Clamp()
	offset = math.max(0, math.min(offset, MaxOffset()));
end
local function Fits(from, to)
	local total = 0;
	for i = from + 1, to do total = total + RowHeight(rows[i]); end
	return total <= AREA;
end
local function RowOf(id)
	for i, r in ipairs(rows) do
		if ( r.kind == "card" and r.c.id == id ) then return i; end
	end
	return nil;
end

local function ShowSelected()
	local i = RowOf(CharacterSelect.selectedIndex or 0);
	if ( i ) then
		if ( i <= offset ) then
			offset = i - 1;
			if ( offset > 0 and rows[offset].kind == "header" ) then offset = offset - 1; end   -- with its header
		else
			while ( offset < i - 1 and not Fits(offset, i) ) do offset = offset + 1; end
		end
	end
	Clamp();
end

-- Put character <id> where character <targetId> is (in its group)
local function MoveCharacter(id, targetId)
	local c, t = CharById(id), CharById(targetId);
	if ( c and t and Logic.MoveName(groups, c.name, t.group, t.name) ) then
		Rearrange();
		SaveOrder();
		return true;
	end
	return false;
end

-- Put character <id> last into group <index> (and open it)
local function MoveToGroup(id, index)
	local c = CharById(id);
	if ( c and groups[index] ) then
		groups[index].collapsed = nil;
		if ( Logic.MoveName(groups, c.name, index, nil) ) then
			Rearrange();
			SaveOrder();
			return true;
		end
	end
	return false;
end

-- The arrows (hidden: the order changes by dragging; kept for code that calls them): one place up (-1) or down (1)
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

---------------------------------------------------------------------------------------------------------------------
-- Popup menus (right-click) and the small dialogs
---------------------------------------------------------------------------------------------------------------------
local function ClosePopups()
	for _, p in ipairs(popups) do p:Hide(); end
	if ( popupBlocker ) then popupBlocker:Hide(); end
end
TemucraftCharSelect_ClosePopups = ClosePopups;

local OpenPopup;
local function PopupFrame(level)
	local p = popups[level];
	if ( p ) then return p; end
	p = TipBox(CharacterSelect);
	p:SetFrameStrata("FULLSCREEN_DIALOG");
	p:SetFrameLevel(10 + level * 5);
	p:EnableMouse(true);
	p:SetWidth(200);
	p.items = {};
	p.title = p:CreateFontString(nil, "OVERLAY", "GlueFontNormalSmall");
	p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -10);
	p:Hide();
	popups[level] = p;
	return p;
end

local function PopupItem(p, level, i)
	local b = p.items[i];
	if ( b ) then return b; end
	b = CreateFrame("Button", "TemucraftSelectPopup"..level.."Item"..i, p);
	b:SetWidth(180); b:SetHeight(20);
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	b.text = b:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall");
	b.text:SetPoint("LEFT", b, "LEFT", 6, 0);
	b.arrow = b:CreateFontString(nil, "OVERLAY", "GlueFontNormalSmall");
	b.arrow:SetPoint("RIGHT", b, "RIGHT", -4, 0);
	local hl = b:CreateTexture(nil, "HIGHLIGHT");
	hl:SetTexture(ART.popupHighlight);
	hl:SetBlendMode("ADD");
	hl:SetAllPoints(b);
	b:SetScript("OnClick", function(self)
		local item = self.item;
		if ( not item or item.disabled ) then return; end
		PlaySound("igMainMenuOptionCheckBoxOn");
		if ( item.sub ) then
			OpenPopup(level + 1, self, item.sub);
		else
			ClosePopups();
			if ( item.func ) then item.func(); end
		end
	end);
	p.items[i] = b;
	return b;
end

-- items: { { text =, func = | sub = items, disabled = }, ... }; level 1 opens left of the anchor, the next ones left
-- of the item that opened them
function OpenPopup(level, anchor, items, title)
	if ( not popupBlocker ) then
		popupBlocker = CreateFrame("Button", "TemucraftSelectPopupBlocker", CharacterSelect);
		popupBlocker:SetAllPoints(CharacterSelect);
		popupBlocker:SetFrameStrata("FULLSCREEN_DIALOG");
		popupBlocker:SetFrameLevel(2);
		popupBlocker:RegisterForClicks("LeftButtonUp", "RightButtonUp");
		popupBlocker:SetScript("OnClick", ClosePopups);
	end
	HideTooltip();
	if ( tip ) then tip:Hide(); end
	popupBlocker:Show();
	for l = level, #popups do popups[l]:Hide(); end
	local p = PopupFrame(level);
	local top = 10;
	if ( title ) then
		p.title:SetText(title);
		p.title:Show();
		top = 28;
	else
		p.title:Hide();
	end
	for i, item in ipairs(items) do
		local b = PopupItem(p, level, i);
		b.item = item;
		b.text:SetText(item.disabled and ("|cff7f7f7f"..item.text.."|r") or item.text);
		b.arrow:SetText(item.sub and ">" or "");
		b:ClearAllPoints();
		b:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -top - (i - 1) * 20);
		b:Show();
	end
	for i = #items + 1, #p.items do p.items[i]:Hide(); p.items[i].item = nil; end
	p:SetHeight(top + #items * 20 + 10);
	p:ClearAllPoints();
	if ( level == 1 ) then
		p:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -6, 0);
	else
		p:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -14, 10);
	end
	p:Show();
	return p;
end

-- a darkened screen with a panel in the middle
local function Modal(name, width, height)
	local m = CreateFrame("Frame", name, CharacterSelect);
	m:SetAllPoints(CharacterSelect);
	m:SetFrameStrata("DIALOG");
	m:EnableMouse(true);
	local shade = m:CreateTexture(nil, "BACKGROUND");
	shade:SetAllPoints(m);
	shade:SetTexture(0, 0, 0, 0.55);
	m.box = Panel(m, 1);
	m.box:SetWidth(width); m.box:SetHeight(height);
	m.box:SetPoint("CENTER", m, "CENTER", 0, 60);
	m:Hide();
	return m;
end

local function ModalShown()
	return (deleteDialog and deleteDialog:IsShown() and deleteDialog) or (groupDialog and groupDialog:IsShown() and groupDialog) or nil;
end

-- Group name: new group / rename. onAccept(text) returns nil when done, else the error to show.
local GROUP_ERRORS = { empty = "Enter a name for the group.", exists = "There is already a group with that name." };
local function OpenGroupDialog(title, text, onAccept)
	if ( not groupDialog ) then
		local d = Modal("TemucraftGroupDialog", 340, 150);
		d.title = d.box:CreateFontString(nil, "OVERLAY", "GlueFontNormalLarge");
		d.title:SetPoint("TOP", d.box, "TOP", 0, -20);
		d.edit = InputBox("TemucraftGroupEdit", d.box, 240, 28);
		d.edit:SetPoint("TOP", d.title, "BOTTOM", 0, -12);
		if ( d.edit.SetMaxLetters ) then d.edit:SetMaxLetters(Logic.MAX_GROUP_NAME); end
		d.error = d.box:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall");
		d.error:SetPoint("TOP", d.edit, "BOTTOM", 0, -4);
		local function accept()
			local err = d.onAccept and d.onAccept(d.edit:GetText() or "");
			if ( err ) then
				d.error:SetText("|cffff4040"..(GROUP_ERRORS[err] or err).."|r");
			else
				d:Hide();
				Refresh();
			end
		end
		d.okay = SmallButton("TemucraftGroupOkay", d.box, OKAY or "Okay", 110, accept);
		d.okay:SetPoint("BOTTOMRIGHT", d.box, "BOTTOM", -4, 16);
		d.cancel = SmallButton("TemucraftGroupCancel", d.box, CANCEL or "Cancel", 110, function() d:Hide(); end);
		d.cancel:SetPoint("BOTTOMLEFT", d.box, "BOTTOM", 4, 16);
		d.edit:SetScript("OnEnterPressed", accept);
		d.edit:SetScript("OnEscapePressed", function() d:Hide(); end);
		d.edit:SetScript("OnTextChanged", function() d.error:SetText(""); end);
		groupDialog = d;
	end
	ClosePopups();
	groupDialog.title:SetText(title);
	groupDialog.onAccept = onAccept;
	groupDialog:Show();
	groupDialog.edit:SetText(text or "");
	groupDialog.error:SetText("");
	groupDialog.edit:SetFocus();
end
TemucraftCharSelect_OpenGroupDialog = OpenGroupDialog;

local function NewGroupFor(id)
	OpenGroupDialog("New group", "", function(text)
		local index, err = Logic.AddGroup(groups, text);
		if ( not index ) then return err; end
		if ( not (id and MoveToGroup(id, index)) ) then
			Rearrange();
			SaveOrder();
		end
		return nil;
	end);
end

-- Delete: retail's dialog (type the word to confirm), then the client's DeleteCharacter
local function DeleteWordOk(text)
	return Logic.DeleteOk(text, Locale(), DELETE_CONFIRM_STRING);
end

local function OpenDelete()
	local id = CharacterSelect.selectedIndex or 0;
	local c = CharById(id);
	if ( not c ) then return; end
	if ( CharacterDeleteDialog and CharacterDeleteDialog.Hide ) then CharacterDeleteDialog:Hide(); end
	if ( not deleteDialog ) then
		local d = Modal("TemucraftDeleteDialog", 420, 210);
		d.icon = d.box:CreateTexture(nil, "ARTWORK");
		d.icon:SetTexture(ART.alert);
		d.icon:SetWidth(48); d.icon:SetHeight(48);
		d.icon:SetPoint("TOPLEFT", d.box, "TOPLEFT", 22, -20);
		d.text = d.box:CreateFontString(nil, "OVERLAY", "GlueFontNormalLarge");
		d.text:SetPoint("TOP", d.box, "TOP", 20, -24);
		d.text:SetWidth(320);
		d.hint = d.box:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall");
		d.hint:SetPoint("TOP", d.text, "BOTTOM", -20, -12);
		d.hint:SetWidth(380);
		d.edit = InputBox("TemucraftDeleteEdit", d.box, 200, 28);
		d.edit:SetPoint("TOP", d.hint, "BOTTOM", 0, -10);
		if ( d.edit.SetMaxLetters ) then d.edit:SetMaxLetters(32); end
		local function confirm()
			if ( not DeleteWordOk(d.edit:GetText()) ) then return; end
			local delId = d.id;
			d:Hide();
			PlaySound("gsCharacterSelectionDelCharacter");
			if ( delId and delId > 0 ) then DeleteCharacter(delId); end
		end
		d.okay = SmallButton("TemucraftDeleteOkay", d.box, OKAY or "Okay", 120, confirm);
		d.okay:SetPoint("BOTTOMRIGHT", d.box, "BOTTOM", -4, 18);
		d.cancel = SmallButton("TemucraftDeleteCancel", d.box, CANCEL or "Cancel", 120, function() d:Hide(); end);
		d.cancel:SetPoint("BOTTOMLEFT", d.box, "BOTTOM", 4, 18);
		d.edit:SetScript("OnTextChanged", function(self)
			if ( DeleteWordOk(self:GetText()) ) then d.okay:Enable(); else d.okay:Disable(); end
		end);
		d.edit:SetScript("OnEnterPressed", confirm);
		d.edit:SetScript("OnEscapePressed", function() d:Hide(); end);
		deleteDialog = d;
	end
	local d = deleteDialog;
	ClosePopups();
	d.id = id;
	local color = c.classFile and Logic.CLASS_COLORS[c.classFile];
	local class = color and ("|cff"..color..(c.class or "").."|r") or (c.class or "");
	local ok, text = false, nil;
	if ( CONFIRM_CHAR_DELETE ) then ok, text = pcall(string.format, CONFIRM_CHAR_DELETE, c.name, c.level, class); end
	d.text:SetText(ok and text or ("Do you want to delete\n"..c.name.." Level "..c.level.." "..class.."?"));
	d.hint:SetText(Logic.DeleteInstructions(Locale(), DELETE_CONFIRM_STRING, CONFIRM_CHAR_DELETE_INSTRUCTIONS));
	d:Show();
	d.edit:SetText("");
	d.okay:Disable();
	d.edit:SetFocus();
	PlaySound("gsCharacterSelectionDelCharacter");
end

---------------------------------------------------------------------------------------------------------------------
-- Dragging a card: the row under the cursor, and whether the cursor is above the first or below the last row
---------------------------------------------------------------------------------------------------------------------
local function CardUnderCursor()
	if ( not GetCursorPosition ) then return nil; end
	local _, y = GetCursorPosition();
	local first, last;
	for _, b in ipairs(rowFrames) do
		if ( b:IsShown() ) then
			local scale = (b.GetEffectiveScale and b:GetEffectiveScale()) or 1;
			local top, bottom = b:GetTop(), b:GetBottom();
			if ( top and bottom and y ) then
				local cy = y / scale;
				local gap = (b.rowHeight - (top - bottom)) / 2 + 1;
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
	if ( edge and dragTick > 0.15 ) then   -- held above or below the rows: scroll
		dragTick = 0;
		offset = offset + ((edge == "above") and -1 or 1);
		Clamp();
		Refresh(true);
	end
	local line = root.dropLine;
	if ( b and (b.header or (b.id and b.id ~= dragging)) ) then
		line:ClearAllPoints();
		local from, to = Logic.IndexOf(list, dragging), b.id and Logic.IndexOf(list, b.id);
		if ( b.header or (from and to and to > from) ) then
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
	if ( tip ) then tip:Hide(); end
	ClosePopups();
	dragFrame:Show();
	Refresh(true);
end

local function StopDrag()
	if ( not dragging ) then return; end
	local id = dragging;
	local target = CardUnderCursor();
	dragging = nil;
	dragEnded = true;   -- the click that ends a drag does not select
	dragFrame:Hide();
	root.dropLine:Hide();
	local moved = false;
	if ( target and target.header ) then
		moved = MoveToGroup(id, target.group);
	elseif ( target and target.id and target.id ~= id ) then
		moved = MoveCharacter(id, target.id);
	end
	if ( moved ) then PlaySound("igMainMenuOptionCheckBoxOn"); end
	Refresh(true);
end

---------------------------------------------------------------------------------------------------------------------
-- The card tooltip, left of the list
---------------------------------------------------------------------------------------------------------------------
local function ShowCardTip(b)
	local c = b.char;
	if ( not c or dragging ) then return; end
	if ( not tip ) then
		tip = TipBox(root);
		tip:SetFrameStrata("TOOLTIP");
		tip.lines = {};
	end
	local summary = Logic.Summary(TEMUCRAFT_CHAR_SUMMARY, CurrentRealm(), c.name);
	local hint = (#list > 1) and "Drag to move, right-click for groups" or nil;
	local lines = Logic.TooltipLines(c, CurrentRealm(), summary, hint, true);
	local width, y = 180, -10;
	for i, text in ipairs(lines) do
		local fs = tip.lines[i];
		if ( not fs ) then
			fs = tip:CreateFontString(nil, "OVERLAY", (i == 1) and "GlueFontNormalLarge" or "GlueFontHighlightSmall");
			fs:SetJustifyH("LEFT");
			tip.lines[i] = fs;
		end
		fs:ClearAllPoints();
		fs:SetPoint("TOPLEFT", tip, "TOPLEFT", 12, y);
		fs:SetText(text);
		fs:Show();
		width = math.max(width, (fs:GetStringWidth() or 0) + 26);
		y = y - ((i == 1) and 20 or 15);
	end
	for i = #lines + 1, #tip.lines do tip.lines[i]:Hide(); end
	tip:SetWidth(width);
	tip:SetHeight(-y + 10);
	tip:ClearAllPoints();
	tip:SetPoint("TOPRIGHT", b, "TOPLEFT", -24, 0);
	tip:Show();
end
local function HideCardTip()
	if ( tip ) then tip:Hide(); end
end

---------------------------------------------------------------------------------------------------------------------
-- Cards and group headers
---------------------------------------------------------------------------------------------------------------------
local function CardMenu(b)
	local c = b.char;
	if ( not c ) then return; end
	local sub = {};
	for gi, g in ipairs(groups) do
		if ( gi ~= c.group ) then
			table.insert(sub, { text = Logic.GroupName(g), func = function() MoveToGroup(c.id, gi); Refresh(); end });
		end
	end
	table.insert(sub, { text = "|cffffd100New group...|r", func = function() NewGroupFor(c.id); end });
	OpenPopup(1, b, {
		{ text = "Move to group", sub = sub },
		{ text = "New group...", func = function() NewGroupFor(nil); end },
	}, c.name);
end

local function HeaderMenu(h)
	local gi = h.group;
	local g = groups[gi];
	if ( not g ) then return; end
	local items = {
		{ text = "Rename", func = function()
			OpenGroupDialog("Rename group", Logic.GroupName(g), function(text)
				local ok, err = Logic.RenameGroup(groups, gi, text);
				if ( not ok ) then return err; end
				SaveOrder();
				return nil;
			end);
		end },
	};
	if ( not g.default ) then
		table.insert(items, { text = "Delete", func = function()
			if ( Logic.DeleteGroup(groups, gi) ) then Rearrange(); SaveOrder(); Refresh(); end
		end });
	end
	table.insert(items, { text = "New group...", func = function() NewGroupFor(nil); end });
	OpenPopup(1, h, items, Logic.GroupName(g));
end

local function MakeHeader(n)
	local h = CreateFrame("Button", "TemucraftSelectHeader"..n, root.list);
	h:SetWidth(CARD_WIDTH); h:SetHeight(HEADER_HEIGHT - 4);
	h.rowHeight, h.header = HEADER_HEIGHT, true;
	h:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	h.bg = h:CreateTexture(nil, "BACKGROUND");
	h.bg:SetTexture(ART.header);
	h.bg:SetTexCoord(0, 0.6640625, 0, 1);
	h.bg:SetAllPoints(h);
	h.bg:SetVertexColor(0.55, 0.55, 0.6);
	-- hover: a faint gold bar (the achievement category highlight is green)
	local hl = h:CreateTexture(nil, "HIGHLIGHT");
	hl:SetTexture(ART.listHighlight);
	hl:SetBlendMode("ADD");
	hl:SetAlpha(0.3);
	hl:SetPoint("TOPLEFT", h, "TOPLEFT", 4, -3);
	hl:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -4, 3);
	h.text = h:CreateFontString(nil, "OVERLAY", "GlueFontNormal");
	h.text:SetPoint("LEFT", h, "LEFT", 12, 0);
	h.count = h:CreateFontString(nil, "OVERLAY", "GlueFontDisableSmall");
	h.count:SetPoint("LEFT", h.text, "RIGHT", 6, 0);
	h.toggle = h:CreateTexture(nil, "ARTWORK");
	h.toggle:SetWidth(18); h.toggle:SetHeight(18);
	h.toggle:SetPoint("RIGHT", h, "RIGHT", -8, 0);
	h:SetScript("OnClick", function(self, button)
		local g = groups[self.group];
		if ( not g ) then return; end
		if ( button == "RightButton" ) then
			HeaderMenu(self);
			return;
		end
		g.collapsed = (not g.collapsed) or nil;
		PlaySound(g.collapsed and "igMainMenuOptionCheckBoxOff" or "igMainMenuOptionCheckBoxOn");
		SaveOrder();
		Refresh(true);
	end);
	-- the hint left of the list (like the card tooltips), not over the card above
	h:SetScript("OnEnter", function(self)
		self.text:SetTextColor(1, 1, 1);
		if ( not dragging ) then
			Tooltip(self, HEADER_HINT, "TOPRIGHT", root.list, "TOPLEFT", -24, (self:GetTop() and root.list:GetTop()) and (self:GetTop() - root.list:GetTop()) or 0);
		end
	end);
	h:SetScript("OnLeave", function(self) self.text:SetTextColor(1, 0.82, 0); HideTooltip(); end);
	h:EnableMouseWheel(true);
	h:SetScript("OnMouseWheel", function(_, delta) offset = offset - delta; Clamp(); Refresh(true); end);
	headers[n] = h;
	return h;
end

local function MakeCard(n)
	local b = CreateFrame("Button", "TemucraftSelectCard"..n, root.list);
	b:SetWidth(CARD_WIDTH); b:SetHeight(CARD_HEIGHT - 4);
	b.rowHeight = CARD_HEIGHT;
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	b.bg = b:CreateTexture(nil, "BACKGROUND");
	b.bg:SetTexture(ART.card);
	b.bg:SetAllPoints(b);
	-- selected: a soft gold glow inside the edge (four strips fading inward, low alpha; never a fill) ...
	b.glow = {};
	local GLOW = 10;
	for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT", "h", "VERTICAL", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", "h", "VERTICAL", 1, 0 },
			{ "TOPLEFT", "BOTTOMLEFT", "w", "HORIZONTAL", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", "w", "HORIZONTAL", 0, 1 } }) do
		local g = b:CreateTexture(nil, "BORDER");
		g:SetTexture(1, 0.82, 0.18, 1);
		g:SetBlendMode("ADD");
		g:SetPoint(p[1], b, p[1], 0, 0);
		g:SetPoint(p[2], b, p[2], 0, 0);
		if ( p[3] == "h" ) then g:SetHeight(GLOW); else g:SetWidth(GLOW); end
		g.orientation, g.from, g.to = p[4], p[5], p[6];   -- alpha factor at the min / max end
		g:Hide();
		b.glow[i] = g;
	end
	-- ... and one frame on the card's own edge: 1 px grey, 2 px gold when selected (FillCard)
	b.frame = {};
	for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
		local e = b:CreateTexture(nil, "OVERLAY");
		e:SetTexture(1, 1, 1, 1);
		e:SetPoint(p[1], b, p[1], 0, 0);
		e:SetPoint(p[2], b, p[2], 0, 0);
		e.vertical = p[3];
		if ( p[3] ) then e:SetWidth(1); else e:SetHeight(1); end
		b.frame[i] = e;
	end
	-- hover: a faint light, nothing else
	local hl = b:CreateTexture(nil, "HIGHLIGHT");
	hl:SetTexture(ART.listHighlight2);
	hl:SetBlendMode("ADD");
	hl:SetAlpha(0.14);
	hl:SetAllPoints(b);
	-- "1." in the name's font, a dimmer gold, then the name; 10 px in from the left and 9 from the top, the three lines
	-- (name, "Level 80 Rogue", zone) spread evenly down the card (FillCard moves the name past the number)
	b.num = b:CreateFontString(nil, "OVERLAY", "GlueFontNormalLarge");
	b.num:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -9);
	b.name = b:CreateFontString(nil, "OVERLAY", "GlueFontNormalLarge");
	b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -9);
	b.info = b:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall");
	b.info:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -30);
	b.zone = b:CreateFontString(nil, "OVERLAY", "GlueFontDisableSmall");
	b.zone:SetPoint("TOPLEFT", b.info, "BOTTOMLEFT", 0, -4);
	b.zone:SetWidth(ZONE_WIDTH); b.zone:SetJustifyH("LEFT");   -- one line: SetOneLine cuts it to fit
	b.crest = b:CreateTexture(nil, "ARTWORK");
	b.crest:SetWidth(44); b.crest:SetHeight(44);
	b.crest:SetPoint("RIGHT", b, "RIGHT", -8, -2);
	-- c.id is the client's own index of the character, whatever the card's place on screen
	-- Dragging without OnDragStart (the glue screens don't always send it): a press that moves more than a few pixels
	-- starts a drag, the release ends it (the card keeps the mouse until the button is let go)
	b:SetScript("OnMouseDown", function(self, button)
		dragEnded = false;
		if ( (button == nil or button == "LeftButton") and GetCursorPosition ) then
			local _, y = GetCursorPosition();
			self.pressY = y;
		end
	end);
	b:SetScript("OnMouseUp", function(self)
		self.pressY = nil;
		if ( dragging ) then
			StopDrag();
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
		self.hovered = true;
		self.crest:SetAlpha(Logic.CardStyle(self.isSelected, true).crestAlpha);
		ShowCardTip(self);
	end);
	b:SetScript("OnLeave", function(self)
		self.hovered = nil;
		self.crest:SetAlpha(Logic.CardStyle(self.isSelected, false).crestAlpha);
		HideCardTip();
	end);
	b:SetScript("OnClick", function(self, button)
		if ( dragEnded ) then
			dragEnded = false;
			return;
		end
		if ( button == "RightButton" ) then
			CardMenu(self);
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
	-- the order arrows: never shown (retail has them, Ryan wanted drag); MoveSelected stays for them
	for _, dir in ipairs({ { "up", -1, "Up", 8 }, { "down", 1, "Down", -8 } }) do
		local a = CreateFrame("Button", "TemucraftSelectCard"..n..dir[3], b);
		a:SetWidth(20); a:SetHeight(20);
		a:SetPoint("RIGHT", b, "RIGHT", -50, dir[4]);
		a:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-Scroll"..dir[3].."Button-Up");
		a:SetScript("OnClick", function() MoveSelected(dir[2]); end);
		a:Hide();
		b[dir[1]] = a;
	end
	-- paid customization / race / faction change, on the card's left edge
	b.paid = CreateFrame("Button", nil, b);
	b.paid:SetWidth(28); b.paid:SetHeight(28);
	b.paid:SetPoint("RIGHT", b, "LEFT", 4, 12);
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
	-- unread mail: a round envelope badge on the left edge (data from the launcher's summary)
	b.mail = CreateFrame("Button", "TemucraftSelectCard"..n.."Mail", b);
	b.mail:SetWidth(26); b.mail:SetHeight(26);
	b.mail:SetPoint("RIGHT", b, "LEFT", 4, -12);
	local mbg = b.mail:CreateTexture(nil, "BACKGROUND");
	mbg:SetTexture(0, 0, 0, 0.8);
	mbg:SetPoint("TOPLEFT", b.mail, "TOPLEFT", 4, -4);
	mbg:SetPoint("BOTTOMRIGHT", b.mail, "BOTTOMRIGHT", -4, 4);
	local micon = b.mail:CreateTexture(nil, "ARTWORK");
	micon:SetTexture(ART.mail);
	micon:SetWidth(16); micon:SetHeight(16);
	micon:SetPoint("TOPLEFT", b.mail, "TOPLEFT", 5, -5);
	local ring = b.mail:CreateTexture(nil, "OVERLAY");
	ring:SetTexture(ART.ring);
	ring:SetWidth(44); ring:SetHeight(44);
	ring:SetPoint("TOPLEFT", b.mail, "TOPLEFT", 0, 0);
	b.mail:SetScript("OnEnter", function(self) Tooltip(self, self:GetParent().mailText); end);
	b.mail:SetScript("OnLeave", HideTooltip);
	b.mail:Hide();
	b:EnableMouseWheel(true);
	b:SetScript("OnMouseWheel", function(_, delta) offset = offset - delta; Clamp(); Refresh(true); end);
	cards[n] = b;
	return b;
end

local function FillCard(b, c, sel)
	b.id, b.service, b.char = c.id, c.paid, c;
	b.num:SetText(Logic.CardNumber(c));
	local numWidth = (b.num:GetText() or "") ~= "" and ((b.num:GetStringWidth() or 0) + 5) or 0;
	b.name:ClearAllPoints();
	b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 10 + numWidth, -9);
	b.name:SetText(c.name);
	local color = c.classFile and Logic.CLASS_COLORS[c.classFile];
	local class = color and ("|cff"..color..(c.class or "").."|r") or (c.class or "");
	local fmt = c.ghost and CHARACTER_SELECT_INFO_GHOST or CHARACTER_SELECT_INFO;
	if ( fmt ) then
		b.info:SetText(format(fmt, c.level, class));
	else
		b.info:SetText("Level "..c.level.." "..class);
	end
	b.zone:SetWidth(ZONE_WIDTH);
	SetOneLine(b.zone, c.zone or "", ZONE_WIDTH);
	local isSel = (c.id == sel);
	local st = Logic.CardStyle(isSel, b.hovered);
	b.isSelected = isSel;
	b.bg:SetVertexColor(st.bg[1], st.bg[2], st.bg[3]);
	b.bg:SetAlpha(st.bg[4]);
	b.name:SetTextColor(st.name[1], st.name[2], st.name[3]);
	b.num:SetTextColor(st.num[1], st.num[2], st.num[3]);
	for _, e in ipairs(b.frame) do
		e:SetVertexColor(st.border[1], st.border[2], st.border[3]);
		e:SetAlpha(st.border[4]);
		if ( e.vertical ) then e:SetWidth(st.borderSize); else e:SetHeight(st.borderSize); end
	end
	for _, g in ipairs(b.glow) do
		if ( st.glow ) then
			if ( g.SetGradientAlpha ) then
				g:SetGradientAlpha(g.orientation, 1, 0.82, 0.18, st.glowAlpha * g.from, 1, 0.82, 0.18, st.glowAlpha * g.to);
			else
				g:SetAlpha(st.glowAlpha * 0.4);
			end
			g:Show();
		else
			g:Hide();
		end
	end
	if ( c.faction == "Alliance" or c.faction == "Horde" ) then
		b.crest:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..c.faction);
		b.crest:SetTexCoord(0, 0.625, 0, 0.625);
		b.crest:SetDesaturated(st.crestDesaturated and 1 or nil);
		b.crest:SetAlpha(st.crestAlpha);
		b.crest:Show();
	else
		b.crest:Hide();
	end
	if ( c.paid ) then b.paid:Show(); else b.paid:Hide(); end
	b.mailText = Logic.MailText(Logic.Summary(TEMUCRAFT_CHAR_SUMMARY, CurrentRealm(), c.name));
	if ( b.mailText ) then b.mail:Show(); else b.mail:Hide(); end
	b.up:Hide(); b.down:Hide();
	b:SetAlpha((dragging and c.id == dragging) and 0.45 or 1);
end

local function FillHeader(h, r)
	local g = groups[r.group];
	h.group = r.group;
	h.text:SetText(Logic.GroupName(g));
	h.count:SetText("("..r.count..")");
	h.toggle:SetTexture(g.collapsed and ART.plus or ART.minus);
end

local function Layout()
	local sel = CharacterSelect.selectedIndex or 0;
	local nCard, nHead, y = 0, 0, 0;
	for k = #rowFrames, 1, -1 do rowFrames[k] = nil; end
	for i = offset + 1, #rows do
		local r = rows[i];
		local h = RowHeight(r);
		if ( y + h > AREA ) then break; end
		local f;
		if ( r.kind == "card" ) then
			nCard = nCard + 1;
			f = cards[nCard] or MakeCard(nCard);
			FillCard(f, r.c, sel);
		else
			nHead = nHead + 1;
			f = headers[nHead] or MakeHeader(nHead);
			FillHeader(f, r);
		end
		f:ClearAllPoints();
		f:SetPoint("TOP", root.list, "TOP", 0, -ROWS_TOP - y - (r.kind == "header" and 2 or 0));
		f:Show();
		table.insert(rowFrames, f);
		y = y + h;
	end
	for n = nCard + 1, #cards do cards[n]:Hide(); cards[n].id, cards[n].char = nil, nil; end
	for n = nHead + 1, #headers do headers[n]:Hide(); end
end

function Refresh(keepOffset)
	if ( not root or not root:IsShown() ) then
		return;
	end
	if ( not groups ) then Rearrange(); end
	local query = root.search:GetText() or "";
	rows, shown = Logic.Rows(groups, query);
	if ( query ~= lastQuery ) then
		offset = 0;
		lastQuery = query;
	end
	if ( not keepOffset ) then
		ShowSelected();
	end
	Clamp();
	Layout();
	if ( #shown == 0 and #list > 0 and string.find(query, "%S") ) then
		root.empty:SetText("No character matches");
	elseif ( #list == 0 ) then
		root.empty:SetText(IsConnectedToServer() and "No characters yet" or "");
	else
		root.empty:SetText("");
	end
	root.count:SetText((string.find(query, "%S") and #shown ~= #list) and (#shown.." / "..#list) or "");
	local connected = IsConnectedToServer();
	local canCreate = connected and CharacterSelect.createIndex and CharacterSelect.createIndex > 0;
	if ( canCreate ) then root.create:Enable(); else root.create:Disable(); end
	SetSquareEnabled(root.plus, canCreate);
	SetSquareEnabled(root.delete, (CharacterSelect.selectedIndex or 0) > 0 and #list > 0);
	if ( root.realm ) then
		local server = CurrentRealm();
		root.realm:SetText(server);
		-- The PTR client (30 races) on a realm that isn't the PTR: the game logged into another realm because the PTR's
		-- was offline. Playing there would mean Live with the PTR's files, so Enter World is off with a warning.
		local wrong = Logic.WrongRealm(MAX_RACES, server);
		if ( root.realmWarning ) then
			if ( wrong ) then root.realmWarning:Show(); else root.realmWarning:Hide(); end
		end
		if ( CharSelectEnterWorldButton ) then
			if ( wrong ) then CharSelectEnterWorldButton:Disable(); else CharSelectEnterWorldButton:Enable(); end
		end
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
	ClosePopups();
	HideCardTip();
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
	menu = Panel(root, 0.97);
	menu:SetWidth(196); menu:SetHeight(#MENU * 34 + 52);
	menu:SetPoint("TOPRIGHT", root.menuButton, "BOTTOMRIGHT", 6, -6);
	menu:SetFrameStrata("DIALOG");
	menu:EnableMouse(true);
	local title = menu:CreateFontString(nil, "OVERLAY", "GlueFontNormal");
	title:SetPoint("TOP", menu, "TOP", 0, -16);
	title:SetText("Menu");
	for i, item in ipairs(MENU) do
		local b = SmallButton("TemucraftSelectMenu"..i, menu, item.text, 160, function()
			menu:Hide();
			item.func();
		end);
		b:SetHeight(30);
		b:SetPoint("TOP", menu, "TOP", 0, -38 - (i - 1) * 34);
	end
	menu:Hide();
end

---------------------------------------------------------------------------------------------------------------------
-- Building the screen
---------------------------------------------------------------------------------------------------------------------
local function OpenCreate()
	if ( CharacterSelect.createIndex and CharacterSelect.createIndex > 0 ) then
		CharacterSelect_SelectCharacter(CharacterSelect.createIndex);
	end
end

local function Build()
	local parent = CharacterSelectUI or CharacterSelect;
	root = CreateFrame("Frame", "TemucraftCharSelectFrame", parent);
	root:SetAllPoints(CharacterSelect);
	root:SetFrameLevel(parent:GetFrameLevel() + 5);
	holder = CreateFrame("Frame", nil, CharacterSelect);
	holder:Hide();

	-- top bar
	root.top = Panel(root, 0.9);
	root.top:SetHeight(48);
	root.top:SetPoint("TOPLEFT", root, "TOPLEFT", 10, -6);
	root.top:SetPoint("TOPRIGHT", root, "TOPRIGHT", -10, -6);
	root.menuButton = SmallButton("TemucraftSelectMenuButton", root.top, "Menu", 110, function()
		if ( menu:IsShown() ) then menu:Hide(); else menu:Show(); end
	end);
	-- Menu at the right of the top bar, Back at its left (Ryan, PTR test of 2026-11-26)
	root.menuButton:SetPoint("RIGHT", root.top, "RIGHT", -14, 0);
	root.realms = SmallButton("TemucraftSelectRealms", root.top, "Realms", 110, function()
		if ( menu ) then menu:Hide(); end
		CharacterSelect_ChangeRealm();
	end);
	root.realms:SetPoint("RIGHT", root.menuButton, "LEFT", -6, 0);
	-- Temucraft: Live or PTR is chosen in the launcher (it writes realmName), so no realm list in game.
	-- Set TEMUCRAFT_SHOW_REALMS = true (e.g. in TemucraftScenes.lua) to bring the button back.
	if ( not TEMUCRAFT_SHOW_REALMS ) then root.realms:Hide(); end
	-- Back sits at the left of the top bar, Menu at its right (the stock one is put away in HideStock): the client's
	-- own CharacterSelect_Exit, as the stock button and Escape do
	root.back = SmallButton("TemucraftSelectBackButton", root.top, BACK or "Back", 110, function()
		if ( menu ) then menu:Hide(); end
		CharacterSelect_Exit();
	end);
	root.back:SetPoint("LEFT", root.top, "LEFT", 14, 0);
	root.realm = root.top:CreateFontString(nil, "OVERLAY", "GlueFontNormal");
	root.realm:SetPoint("CENTER", root.top, "CENTER", 0, 0);
	root.realmWarning = root:CreateFontString(nil, "OVERLAY", "GlueFontNormalLarge");
	root.realmWarning:SetPoint("TOP", root.top, "BOTTOM", 0, -12);
	root.realmWarning:SetWidth(700);
	root.realmWarning:SetText("|cffff4040This is the PTR game, but the PTR realm is offline, so the server put you on another realm.|r\nEnter World is off so you don't play there with the PTR's files. Go back and try again when the PTR is up.");
	root.realmWarning:Hide();
	BuildMenu();

	-- the list panel
	root.list = Panel(root);
	root.list:SetWidth(CARD_WIDTH + 30);
	root.list:SetHeight(ROWS_TOP + AREA + 62);
	root.list:SetPoint("TOPRIGHT", root, "TOPRIGHT", -12, -60);
	root.list:EnableMouseWheel(true);
	root.list:SetScript("OnMouseWheel", function(_, delta) offset = offset - delta; Clamp(); Refresh(true); end);
	-- search row: [magnifier Search ......] (i) [+]
	root.plus = SquareButton("TemucraftSelectPlus", root.list, 30, nil, "+", OpenCreate);
	root.plus:SetPoint("TOPRIGHT", root.list, "TOPRIGHT", -14, -16);
	root.plus:SetScript("OnEnter", function(self) Tooltip(self, "Create Character"); end);
	local info = CreateFrame("Button", "TemucraftSelectSearchInfo", root.list);
	info:SetWidth(22); info:SetHeight(22);
	info:SetPoint("RIGHT", root.plus, "LEFT", -3, 0);
	info.text = info:CreateFontString(nil, "OVERLAY", "GlueFontNormalSmall");
	info.text:SetPoint("CENTER", info, "CENTER", 0, 0);
	info.text:SetText("(i)");
	info:SetScript("OnEnter", function(self)
		Tooltip(self, "Search by name, level (70, 60-70, 70+), class, race, faction or zone,\nor by role: tank, heal, dps. Every word must match.");
	end);
	info:SetScript("OnLeave", HideTooltip);
	root.search = InputBox("TemucraftSelectSearch", root.list, CARD_WIDTH - 62, 26);
	root.search:SetPoint("TOPLEFT", root.list, "TOPLEFT", 17, -18);
	root.search:SetTextInsets(22, 8, 0, 0);
	local glass = root.search:CreateTexture(nil, "OVERLAY");
	glass:SetTexture(ART.search);
	glass:SetWidth(14); glass:SetHeight(14);
	glass:SetPoint("LEFT", root.search, "LEFT", 6, -1);
	root.search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); end);
	root.search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); end);
	root.search:SetScript("OnTextChanged", function() Refresh(); end);
	root.searchHint = root.search:CreateFontString(nil, "OVERLAY", "GlueFontDisableSmall");
	root.searchHint:SetPoint("LEFT", root.search, "LEFT", 23, 0);
	root.searchHint:SetText(SEARCH or "Search");
	root.search:SetScript("OnEditFocusGained", function() root.searchHint:Hide(); end);
	root.search:SetScript("OnEditFocusLost", function(self) if ( (self:GetText() or "") == "" ) then root.searchHint:Show(); end end);
	root.count = root.list:CreateFontString(nil, "OVERLAY", "GlueFontDisableSmall");
	root.count:SetPoint("TOPRIGHT", root.search, "BOTTOMRIGHT", -4, -1);
	for n = 1, VISIBLE do MakeCard(n); cards[n]:Hide(); end
	root.dropLine = root.list:CreateTexture(nil, "OVERLAY");
	root.dropLine:SetTexture(1, 0.82, 0, 0.9);
	root.dropLine:SetWidth(CARD_WIDTH - 8); root.dropLine:SetHeight(2);
	root.dropLine:Hide();
	dragFrame = CreateFrame("Frame", nil, root);
	dragFrame:SetScript("OnUpdate", DragUpdate);
	dragFrame:Hide();
	root.empty = root.list:CreateFontString(nil, "OVERLAY", "GlueFontDisableSmall");
	root.empty:SetPoint("TOP", root.list, "TOP", 0, -ROWS_TOP - 40);
	-- bottom row: [Create Character] [trash] [restore]
	root.create = SmallButton("TemucraftSelectCreate", root.list, "Create Character", CARD_WIDTH - 70, OpenCreate, "GlueButtonTemplate");
	root.create:SetHeight(34);
	root.create:SetPoint("BOTTOMLEFT", root.list, "BOTTOMLEFT", 15, 16);
	root.create:SetScript("OnEnter", function(self) Tooltip(self, "Create Character\n|cff9d9d9d"..CurrentRealm().."|r"); end);
	root.create:SetScript("OnLeave", HideTooltip);
	root.restore = SquareButton("TemucraftSelectRestore", root.list, 32, ART.restore, nil, function()
		PlaySound("igMainMenuOptionCheckBoxOn");
	end);
	root.restore:SetPoint("BOTTOMRIGHT", root.list, "BOTTOMRIGHT", -15, 17);
	root.restore:SetScript("OnEnter", function(self) Tooltip(self, RESTORE_TEXT); end);
	root.delete = SquareButton("TemucraftSelectDelete", root.list, 32, ART.trash, nil, function()
		CharacterSelect_Delete();
	end);
	root.delete:SetPoint("RIGHT", root.restore, "LEFT", -4, 0);
	root.delete:SetScript("OnEnter", function(self) Tooltip(self, DELETE_CHARACTER or "Delete Character"); end);

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
	eye:SetScript("OnEnter", function(self) Tooltip(self, (hiddenByEye and "Show the interface" or "Hide the interface").."\n|cff9d9d9dAlt-Z|r"); end);
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
	for _, name in ipairs({ "CharacterSelectCharacterFrame", "CharacterSelectDeleteButton", "CharacterSelectAddonsButton", "CharacterSelectBackButton" }) do
		local f = _G[name];
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
	ClosePopups();
	HideCardTip();
	if ( deleteDialog ) then deleteDialog:Hide(); end
	if ( groupDialog ) then groupDialog:Hide(); end
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
				if ( name == "UpdateCharacterList" ) then
					ReadCharacters();
					if ( deleteDialog and deleteDialog:IsShown() and not CharById(deleteDialog.id) ) then deleteDialog:Hide(); end
				end
				Refresh();
			end
			return r;
		end
	end
end

-- Delete opens our dialog (the stock CharacterDeleteDialog stays for the classic screen)
local oldDelete = CharacterSelect_Delete;
CharacterSelect_Delete = function(...)
	if ( Active() and root and root:IsShown() ) then
		OpenDelete();
		return;
	end
	if ( oldDelete ) then return oldDelete(...); end
end

-- The arrow keys go through the cards in their order on screen (the client's own go by its index); with a dialog
-- or a popup open, Escape closes it and nothing else happens
-- The glue screens have no IsAltKeyDown: Alt is tracked from the keys themselves (LALT / RALT down and up)
local altDown = false;
local function AltHeld() return altDown or ((IsAltKeyDown and IsAltKeyDown()) and true or false); end
local function SelectKeyUp(self, key)
	if ( key == "LALT" or key == "RALT" ) then altDown = false; end
end
if ( CharacterSelect.HookScript and CharacterSelect:GetScript("OnKeyUp") ) then
	CharacterSelect:HookScript("OnKeyUp", SelectKeyUp);
else
	CharacterSelect:SetScript("OnKeyUp", SelectKeyUp);
end
local oldKeyDown = CharacterSelect_OnKeyDown;
if ( oldKeyDown ) then
	CharacterSelect_OnKeyDown = function(self, key, ...)
		if ( key == "LALT" or key == "RALT" ) then altDown = true; end
		if ( Active() and root and root:IsShown() ) then
			local modal = ModalShown();
			if ( modal ) then
				if ( key == "ESCAPE" ) then modal:Hide(); end
				return;
			end
			if ( popupBlocker and popupBlocker:IsShown() ) then
				if ( key == "ESCAPE" ) then ClosePopups(); return; end
			end
		end
		-- Alt-Z hides / shows the interface (as in game); with it hidden, Escape brings it back
		if ( Active() and root and eye and ((key == "Z" and AltHeld()) or (key == "ESCAPE" and hiddenByEye)) ) then
			ToggleEye();
			return;
		end
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
