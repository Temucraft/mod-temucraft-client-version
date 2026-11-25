-- Temucraft tooltip lines:
--   - "SpellID: n" and "Icon: <texture>" on spell tooltips (spellbook, action bars, links, buffs and debuffs),
--     "ItemID: n" and "Icon: <texture>" on item tooltips. 3.3.5's interface can't read SpellIcon.dbc / the icon file
--     ids, only the icon's texture path, so the icon line gives the texture name (e.g. Spell_Nature_StarFall).
--     Interface Options > Temucraft (or /tui) turns these lines off; on by default (TemucraftStore "ui.tooltipids").
--   - "Cooldown remaining: N sec" on spell tooltips (spellbook and action bars) while the spell is on cooldown.
--   - "You haven't added this to your action bars" (light blue) on the new spellbook's and the flyouts' spells that
--     aren't on any action bar (passives never).
TemucraftTooltipsLogic = {};
local L = TemucraftTooltipsLogic;

function L.IdFromLink(link, kind)
	return link and tonumber(string.match(link, (kind or "spell")..":(%d+)"));
end

-- "Interface\\Icons\\Spell_Nature_StarFall" -> "Spell_Nature_StarFall"
function L.IconName(path)
	if ( not path or path == "" ) then return nil; end
	return string.match(path, "([^\\/]+)$") or path;
end

-- nil while not on cooldown (or only the global cooldown)
function L.CooldownText(start, duration, now)
	if ( not start or not duration or start <= 0 or duration <= 1.5 ) then return nil; end
	local left = start + duration - now;
	if ( left <= 0 ) then return nil; end
	left = math.ceil(left);
	if ( left >= 60 ) then
		return string.format("Cooldown remaining: %d min %d sec", math.floor(left / 60), left % 60);
	end
	return string.format("Cooldown remaining: %d sec", left);
end

-- actions: { { kind = "spell", spellId, name } or { kind = "macro", name } ... }; true when the spell is on a bar
-- (any rank: the bars may have an older rank)
function L.OnBars(spellId, spellName, actions)
	for _, a in ipairs(actions) do
		if ( spellId and a.spellId == spellId ) then return true; end
		if ( spellName and a.name == spellName ) then return true; end
	end
	return false;
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

local SHOW_IDS = true;
local ID_COLOR = { 0.6, 0.6, 0.6 };
local NOT_ON_BARS = "You haven't added this to your action bars";
local MAX_ACTION_SLOTS = 120;

if ( TemucraftUI_OnChange ) then TemucraftUI_OnChange("tooltipids", function(on) SHOW_IDS = on; end); end

-- what the action bars hold (read when a spellbook tooltip needs it, at most once a second)
local actions, actionsTime = {}, -10;
local function Actions()
	if ( GetTime() - actionsTime < 1 ) then return actions; end
	actionsTime = GetTime();
	wipe(actions);
	for slot = 1, MAX_ACTION_SLOTS do
		local kind, id, _, spellId = GetActionInfo(slot);
		if ( kind == "spell" ) then
			table.insert(actions, { kind = "spell", spellId = spellId, name = spellId and GetSpellInfo(spellId) or nil });
		elseif ( kind == "macro" and id ) then
			local name = GetMacroSpell(id);
			if ( name ) then table.insert(actions, { kind = "macro", name = name }); end
		end
	end
	return actions;
end

local function FromOurBook(tooltip)
	local owner = tooltip:GetOwner();
	local name = owner and owner:GetName();
	return name and (string.find(name, "^TemucraftSpellBookButton") or string.find(name, "^TemucraftFlyoutButton")) and true or false;
end

-- one set of lines per tooltip (several hooks can see the same spell)
local function AddSpellLines(tooltip, id, start, duration, passive)
	if ( not id or tooltip.tcSpellLines == id ) then return; end
	tooltip.tcSpellLines = id;
	local added = false;
	local cooldown = L.CooldownText(start, duration, GetTime());
	if ( cooldown ) then tooltip:AddLine(cooldown, 1, 1, 1); added = true; end
	if ( not passive and FromOurBook(tooltip) ) then
		local name = GetSpellInfo(id);
		if ( not L.OnBars(id, name, Actions()) ) then tooltip:AddLine(NOT_ON_BARS, 0.4, 0.78, 1, true); added = true; end
	end
	if ( SHOW_IDS ) then
		tooltip:AddDoubleLine("SpellID: "..id, "Icon: "..(L.IconName(select(3, GetSpellInfo(id))) or "?"),
			ID_COLOR[1], ID_COLOR[2], ID_COLOR[3], ID_COLOR[1], ID_COLOR[2], ID_COLOR[3]);
		added = true;
	end
	if ( added ) then tooltip:Show(); end
end

local function AddItemLines(tooltip)
	if ( not SHOW_IDS or not tooltip.GetItem ) then return; end
	local _, link = tooltip:GetItem();
	local id = L.IdFromLink(link, "item");
	if ( not id or tooltip.tcItemLines == id ) then return; end
	tooltip.tcItemLines = id;
	local icon = GetItemIcon and GetItemIcon(id) or select(10, GetItemInfo(id));
	tooltip:AddDoubleLine("ItemID: "..id, "Icon: "..(L.IconName(icon) or "?"),
		ID_COLOR[1], ID_COLOR[2], ID_COLOR[3], ID_COLOR[1], ID_COLOR[2], ID_COLOR[3]);
	tooltip:Show();
end

local function Cleared(tooltip) tooltip.tcSpellLines, tooltip.tcItemLines = nil, nil; end

for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3" }) do
	local tooltip = _G[name];
	if ( tooltip ) then
		tooltip:HookScript("OnTooltipCleared", Cleared);
		tooltip:HookScript("OnTooltipSetItem", AddItemLines);
	end
end

hooksecurefunc(GameTooltip, "SetSpell", function(tooltip, slot, book)
	local id = L.IdFromLink(GetSpellLink(slot, book));
	local start, duration = GetSpellCooldown(slot, book);
	AddSpellLines(tooltip, id, start, duration, IsPassiveSpell(slot, book));
end);
hooksecurefunc(GameTooltip, "SetAction", function(tooltip, slot)
	local kind, _, _, spellId = GetActionInfo(slot);
	if ( kind ~= "spell" or not spellId ) then return; end
	local start, duration = GetActionCooldown(slot);
	AddSpellLines(tooltip, spellId, start, duration, true);
end);
local function AuraHook(filter)
	return function(tooltip, unit, index, auraFilter)
		local id = select(11, UnitAura(unit, index, filter or auraFilter));
		AddSpellLines(tooltip, id, nil, nil, true);
	end
end
hooksecurefunc(GameTooltip, "SetUnitAura", AuraHook(nil));
hooksecurefunc(GameTooltip, "SetUnitBuff", AuraHook("HELPFUL"));
hooksecurefunc(GameTooltip, "SetUnitDebuff", AuraHook("HARMFUL"));
for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
	hooksecurefunc(tooltip, "SetHyperlink", function(self, link)
		if ( type(link) == "string" and string.find(link, "spell:%d") ) then AddSpellLines(self, L.IdFromLink(link, "spell"), nil, nil, true); end
	end);
end
-- anything else that shows a spell (talents, trainers, ...): the tooltip's own spell id, when the client gives one.
-- OnTooltipSetSpell runs inside SetSpell / SetAction, before their hooks above (which add the cooldown): wait a frame.
local later = CreateFrame("Frame");
later:Hide();
later:SetScript("OnUpdate", function(self)
	self:Hide();
	local id = GameTooltip.tcPendingSpell;
	GameTooltip.tcPendingSpell = nil;
	if ( id and GameTooltip:IsShown() and not GameTooltip.tcSpellLines ) then AddSpellLines(GameTooltip, id, nil, nil, true); end
end);
GameTooltip:HookScript("OnTooltipSetSpell", function(tooltip)
	if ( tooltip.tcSpellLines ) then return; end
	local _, _, id = tooltip:GetSpell();
	if ( type(id) == "number" ) then
		tooltip.tcPendingSpell = id;
		later:Show();
	end
end);
