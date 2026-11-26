-- Temucraft spellbook flyouts (like retail's): one entry in the spellbook (TemucraftSpellBook.lua) opens a row of
-- spells or items beside it. The groups are in FLYOUTS below:
--   Teleports, Portals   the class's teleport and portal spells (ids below, "Teleport..." / "Portal:" names, or the
--                        server's teleport flag), when there are at least 2
--   Temucraft Helpers    the account helper items you have in your bags (Courier's Bell, Folding Mirror, Almanac,
--                        Lantern, Banker's Writ, Guild Vault Charter, the Waygates and the Beacon)
-- Secure: the row's buttons are SecureActionButtons (type spell / item), so they cast in combat. The book's entry
-- opens and closes the row in a secure snippet (SecureHandlerWrapScript on the book's button, header
-- TemucraftFlyoutHeader), and a click in the row closes it the same way; what the row holds and where it sits is only
-- changed out of combat (the book lays itself out only out of combat).

----------------------------------------------------------------------------------------------------------------------
-- The logic (no frames: tests/interface_test.lua runs it with stubs)
----------------------------------------------------------------------------------------------------------------------
TemucraftFlyoutLogic = {};
local F = TemucraftFlyoutLogic;
local F_TELEPORT = 16;   -- TemucraftSpellTabs.lua's flag bit

local function Set(list) local s = {}; for _, v in ipairs(list) do s[v] = true; end return s; end
-- mage teleports (cities, Shattrath, Stonard, Theramore, Dalaran), Teleport: Moonglade, Astral Recall, Death Gate
F.TELEPORT_IDS = Set({ 3561, 3562, 3563, 3565, 3566, 3567, 32271, 32272, 33690, 35715, 49358, 49359, 53140, 18960, 556, 50977 });
-- mage portals
F.PORTAL_IDS = Set({ 10059, 11416, 11417, 11418, 11419, 11420, 32266, 32267, 33691, 35717, 49360, 49361, 53142 });
-- Temucraft helper items (mod-temucraft-courier 610140-610145, mod-temucraft-travel waygates and beacon 610150-610152)
F.HELPER_ITEMS = { 610140, 610141, 610142, 610143, 610144, 610145, 610150, 610151, 610152 };
F.MIN_MEMBERS = 2;

local function Has(f, bit) return f ~= nil and (f % (bit * 2)) >= bit; end

-- which spell group an entry belongs to ("teleports", "portals" or nil)
function F.SpellGroup(e)
	if ( e.passive ) then return nil; end
	local name = e.name or "";
	if ( (e.id and F.PORTAL_IDS[e.id]) or string.find(name, "^Portal:") ) then return "portals"; end
	if ( (e.id and F.TELEPORT_IDS[e.id]) or string.find(name, "^Teleport") or Has(e.flags, F_TELEPORT) ) then return "teleports"; end
	return nil;
end

F.FLYOUTS = {
	teleports = { title = "Teleports", icon = "Interface\\Icons\\Spell_Arcane_TeleportDalaran" },
	portals   = { title = "Portals",   icon = "Interface\\Icons\\Spell_Arcane_PortalDalaran" },
	helpers   = { title = "Temucraft Helpers", icon = "Interface\\Icons\\INV_Misc_Bell_01" },
};

-- list: the book's entries ({ name, sub, slot, id, tab, tabName, passive, flags, icon }), items: helper items you
-- have ({ item, name, icon }); groups of MIN_MEMBERS or more become one entry where their first member was
function F.Collapse(list, items)
	local members, first = {}, {};
	for i, e in ipairs(list) do
		local g = F.SpellGroup(e);
		if ( g ) then
			members[g] = members[g] or {};
			table.insert(members[g], e);
			first[g] = first[g] or i;
		end
	end
	local out = {};
	for i, e in ipairs(list) do
		local g = F.SpellGroup(e);
		if ( g and #members[g] >= F.MIN_MEMBERS ) then
			if ( first[g] == i ) then
				local def = F.FLYOUTS[g];
				table.insert(out, { name = def.title, sub = #members[g].." spells", tab = e.tab, tabName = e.tabName, passive = false,
					flags = 0, icon = e.icon or def.icon, flyout = { key = g, title = def.title, members = members[g] } });
			end
		else
			table.insert(out, e);
		end
	end
	if ( items and #items > 0 ) then
		local def = F.FLYOUTS.helpers;
		table.insert(out, { name = def.title, sub = #items.." items", tab = 1, tabName = "General", passive = false, flags = 0,
			icon = items[1].icon or def.icon, flyout = { key = "helpers", title = def.title, members = items } });
	end
	return out;
end

----------------------------------------------------------------------------------------------------------------------
-- The rows (secure)
----------------------------------------------------------------------------------------------------------------------
if ( not CreateFrame ) then return; end   -- tests load only the logic

local SIZE, GAP, MAX = 34, 4, 16;
local header = CreateFrame("Frame", "TemucraftFlyoutHeader", UIParent, "SecureHandlerBaseTemplate");
local bars = {};

-- the book's button: a flyout entry opens / closes its row, anything else clicks as usual
local TOGGLE = [[
	if ( not self:GetAttribute("tcflyout") ) then return; end
	local bar = self:GetFrameRef("tcflyoutbar");
	if ( bar ) then
		if ( bar:IsShown() ) then bar:Hide(); else bar:Show(); end
	end
	return false;
]];
-- a click in a row closes it (after the spell went off)
local CLOSE_PRE, CLOSE_POST = [[ return nil, true; ]], [[ self:GetParent():Hide(); ]];

local function Bar(key)
	if ( bars[key] ) then return bars[key]; end
	-- a child of the book: it closes with it
	local bar = CreateFrame("Frame", "TemucraftFlyoutBar_"..key, TemucraftSpellBook or UIParent, "SecureHandlerBaseTemplate");
	bar:SetHeight(SIZE + 8);
	bar:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	bar:SetBackdropColor(0, 0, 0, 0.85);
	bar:SetFrameStrata("DIALOG");
	bar:SetClampedToScreen(true);
	bar:EnableMouse(true);
	bar:Hide();
	bar.buttons = {};
	for i = 1, MAX do
		local b = CreateFrame("Button", "TemucraftFlyoutButton"..key.."_"..i, bar, "SecureActionButtonTemplate");
		b:SetWidth(SIZE); b:SetHeight(SIZE);
		b:SetPoint("LEFT", bar, "LEFT", 4 + (i - 1) * (SIZE + GAP), 0);
		b:RegisterForClicks("AnyUp");
		b:RegisterForDrag("LeftButton");
		b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints();
		b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress");
		b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
		b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate");
		b.cooldown:SetAllPoints();
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP");
			if ( self.slot ) then GameTooltip:SetSpell(self.slot, BOOKTYPE_SPELL);
			elseif ( self.item ) then GameTooltip:SetHyperlink("item:"..self.item); end
			GameTooltip:Show();
		end);
		b:SetScript("OnLeave", function() GameTooltip:Hide(); end);
		b:SetScript("OnDragStart", function(self)
			if ( InCombatLockdown() ) then return; end
			if ( self.slot ) then PickupSpell(self.slot, BOOKTYPE_SPELL); elseif ( self.item ) then PickupItem(self.item); end
		end);
		header:WrapScript(b, "OnClick", CLOSE_PRE, CLOSE_POST);
		b:Hide();
		bar.buttons[i] = b;
	end
	bar:SetScript("OnShow", function(self)
		for _, b in ipairs(self.buttons) do
			if ( b:IsShown() ) then
				local start, duration, enable;
				if ( b.slot ) then start, duration, enable = GetSpellCooldown(b.slot, BOOKTYPE_SPELL);
				elseif ( b.item ) then start, duration, enable = GetItemCooldown(b.item); end
				if ( start ) then CooldownFrame_SetTimer(b.cooldown, start, duration, enable); end
			end
		end
	end);
	bars[key] = bar;
	return bar;
end

-- once per book button (at load)
function TemucraftFlyouts_WrapButton(b)
	header:WrapScript(b, "OnClick", TOGGLE);
end

-- out of combat only (the book's layout): point a book button at a flyout, or (flyout nil) at none; the row opens to
-- the right of anchor (default b itself). The spellbook's rank arrows use this too (flyout key "rank..", members the
-- lower ranks of a spell), with the arrow as b and the spell's icon as anchor.
function TemucraftFlyouts_Attach(b, flyout, anchor)
	if ( InCombatLockdown() ) then return; end
	if ( not flyout ) then b:SetAttribute("tcflyout", nil); return; end
	local bar = Bar(flyout.key);
	bar:Hide();
	local n = 0;
	for i, b2 in ipairs(bar.buttons) do
		local m = flyout.members[i];
		if ( m ) then
			n = i;
			b2.slot, b2.item = m.slot, m.item;
			b2.icon:SetTexture(m.icon);
			if ( m.item ) then
				b2:SetAttribute("type", "item"); b2:SetAttribute("item", "item:"..m.item); b2:SetAttribute("spell", nil);
			else
				b2:SetAttribute("type", "spell"); b2:SetAttribute("spell", m.id or m.name); b2:SetAttribute("item", nil);
			end
			b2:Show();
		else
			b2.slot, b2.item = nil, nil;
			b2:SetAttribute("type", nil);
			b2:Hide();
		end
	end
	bar:SetWidth(8 + n * SIZE + max(0, n - 1) * GAP);
	bar:ClearAllPoints();
	bar:SetPoint("LEFT", anchor or b, "RIGHT", 4, 0);
	b:SetAttribute("tcflyout", flyout.key);
	SecureHandlerSetFrameRef(b, "tcflyoutbar", bar);
end

function TemucraftFlyouts_HideAll()
	if ( InCombatLockdown() ) then return; end
	for _, bar in pairs(bars) do bar:Hide(); end
end

-- the helper items you have
local function Items()
	local out = {};
	for _, id in ipairs(F.HELPER_ITEMS) do
		if ( GetItemCount(id) > 0 ) then
			local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(id);
			table.insert(out, { item = id, name = name or ("Item "..id), icon = icon or (GetItemIcon and GetItemIcon(id)) });
		end
	end
	return out;
end

function TemucraftFlyouts_Collapse(list) return F.Collapse(list, Items()); end

-- the book refreshes when the helpers in your bags change
local owned = "";
local events = CreateFrame("Frame");
events:RegisterEvent("BAG_UPDATE");
events:SetScript("OnEvent", function(self)
	self:SetScript("OnUpdate", function(f)
		f:SetScript("OnUpdate", nil);
		local now = {};
		for _, i in ipairs(Items()) do table.insert(now, i.item); end
		now = table.concat(now, ",");
		if ( now ~= owned ) then
			owned = now;
			if ( TemucraftSpellBook_OnFlags ) then TemucraftSpellBook_OnFlags(); end
		end
	end);
end);

-- Esc closes an open row (out of combat; in combat a click in the row or on the entry does)
hooksecurefunc("CloseAllWindows", function() TemucraftFlyouts_HideAll(); end);
