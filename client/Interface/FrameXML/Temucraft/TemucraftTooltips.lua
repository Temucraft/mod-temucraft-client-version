-- Temucraft tooltip lines, all added in ONE place, once per tooltip build, in a fixed order.
-- Every file that adds lines to GameTooltip / ItemRefTooltip registers a provider here instead of hooking the tooltip
-- itself (several hooks each adding a part, some a frame later, made tooltips that DragonUI's spellbook, the action
-- bars and the bags refresh every 0.2 s alternate between two builds and flicker):
--   TemucraftTooltipLines = TemucraftTooltipLines or {};
--   table.insert(TemucraftTooltipLines, { order = 20, kinds = { spell = true }, add = function(tooltip, s) ... end });
-- s (what the tooltip shows): { kind = "spell" | "item" | "unit", id, slot, book, passive, action, aura, link, unit }
--   spell: slot/book from SetSpell (a spell of the player's book), action from SetAction, aura from the aura setters
-- The providers run in order (lower first) right after the tooltip's Set... call, once per build: a flag on the tooltip,
-- cleared by OnTooltipCleared (every Set... call clears the tooltip first) and OnHide. Providers only AddLine; one
-- Show() at the end of the build sizes the tooltip to the new lines (only when lines were added).
-- Orders: 10 what the spell is (TemucraftSpellTabs.lua), 20 the server's spell details (TemucraftSpellInfo.lua),
-- 30 token preview (TemucraftTokenPreview.lua), 40 "not on your action bars", 50 ids, 90 the F6 issue hint
-- (TemucraftIssues.lua).
-- This file's own lines:
--   - "SpellID: n" and "Icon: <texture>" on spell tooltips, "ItemID: n" and "Icon: <texture>" on item tooltips (one
--     line when both fit in the tooltip's width, else two). 3.3.5's interface can't read SpellIcon.dbc / the icon file
--     ids, only the icon's texture path, so the icon line gives the texture name (e.g. Spell_Nature_StarFall).
--     Interface Options > Temucraft (or /tui) turns these lines off; on by default (TemucraftStore "ui.tooltipids").
--   - "You haven't added this to your action bars" (light blue) on the new spellbook's and the flyouts' spells that
--     aren't on any action bar (passives never).
-- No cooldown line: the client's own "Cooldown remaining" is the only one.
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

-- nil while not on cooldown (or only the global cooldown); no longer added to tooltips (the client has its own line)
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

-- the providers that apply to a kind, in order (equal orders keep their registration order)
function L.Sorted(providers, kind)
	local list = {};
	for i, p in ipairs(providers) do
		if ( type(p) == "table" and type(p.add) == "function" and (not p.kinds or p.kinds[kind]) ) then
			table.insert(list, { p = p, i = i });
		end
	end
	table.sort(list, function(a, b)
		local oa, ob = a.p.order or 50, b.p.order or 50;
		if ( oa ~= ob ) then return oa < ob; end
		return a.i < b.i;
	end);
	local out = {};
	for _, x in ipairs(list) do table.insert(out, x.p); end
	return out;
end

-- the id and the icon on one line when both fit in the tooltip's width (24 px between them), else two lines
function L.IdsOnOneLine(leftWidth, rightWidth, tooltipWidth)
	if ( not leftWidth or not rightWidth or not tooltipWidth ) then return true; end
	return leftWidth + rightWidth + 24 <= tooltipWidth - 20;
end

TemucraftTooltipLines = TemucraftTooltipLines or {};
local providers = TemucraftTooltipLines;

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

-- text widths in the tooltip's font, for the id line
local measure;
local function Width(text)
	if ( not measure ) then
		measure = UIParent:CreateFontString(nil, "BACKGROUND", "GameTooltipText");
		measure:Hide();
	end
	measure:SetText(text);
	return measure:GetStringWidth();
end

local function AddIds(tooltip, left, right)
	if ( L.IdsOnOneLine(Width(left), Width(right), tooltip:GetWidth()) ) then
		tooltip:AddDoubleLine(left, right, ID_COLOR[1], ID_COLOR[2], ID_COLOR[3], ID_COLOR[1], ID_COLOR[2], ID_COLOR[3]);
	else
		tooltip:AddLine(left, ID_COLOR[1], ID_COLOR[2], ID_COLOR[3]);
		tooltip:AddLine(right, ID_COLOR[1], ID_COLOR[2], ID_COLOR[3]);
	end
end

table.insert(providers, { order = 40, kinds = { spell = true }, add = function(tooltip, s)
	if ( s.passive or s.aura or not FromOurBook(tooltip) ) then return; end
	if ( not L.OnBars(s.id, GetSpellInfo(s.id), Actions()) ) then tooltip:AddLine(NOT_ON_BARS, 0.4, 0.78, 1, true); end
end });
table.insert(providers, { order = 50, kinds = { spell = true, item = true }, add = function(tooltip, s)
	if ( not SHOW_IDS ) then return; end
	if ( s.kind == "spell" ) then
		AddIds(tooltip, "SpellID: "..s.id, "Icon: "..(L.IconName(select(3, GetSpellInfo(s.id))) or "?"));
	else
		local icon = GetItemIcon and GetItemIcon(s.id) or select(10, GetItemInfo(s.id));
		AddIds(tooltip, "ItemID: "..s.id, "Icon: "..(L.IconName(icon) or "?"));
	end
end });

----------------------------------------------------------------------------------------------------------------------
-- the builder
----------------------------------------------------------------------------------------------------------------------
local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3" };
local waiting = {};        -- tooltip -> true: OnTooltipSet... saw a subject, no hooked setter built it yet

local function Build(tooltip)
	local s = tooltip.tcSubject;
	waiting[tooltip] = nil;
	if ( not s or tooltip.tcBuilt or not s.id ) then return; end
	tooltip.tcBuilt = true;
	local before = tooltip:NumLines();
	for _, p in ipairs(L.Sorted(providers, s.kind)) do
		local ok, err = pcall(p.add, tooltip, s);
		if ( not ok and geterrorhandler ) then geterrorhandler()(err); end
	end
	if ( tooltip:NumLines() > before ) then tooltip:Show(); end
end
-- for providers whose data comes later (TemucraftSpellInfo.lua): what the tooltip shows now, or nil
function TemucraftTooltips_Subject(tooltip) return tooltip and tooltip:IsShown() and tooltip.tcSubject or nil; end

local function Subject(tooltip, s)
	if ( s and not tooltip.tcBuilt ) then tooltip.tcSubject = s; end
end

local function Cleared(tooltip)
	tooltip.tcSubject, tooltip.tcBuilt = nil, nil;
	waiting[tooltip] = nil;
end

-- tooltips filled by a setter not hooked below: built on the next frame (only then; never twice)
local later = CreateFrame("Frame");
later:Hide();
later:SetScript("OnUpdate", function(self)
	self:Hide();
	for tooltip in pairs(waiting) do
		waiting[tooltip] = nil;
		if ( tooltip:IsShown() ) then Build(tooltip); end
	end
end);
local function Wait(tooltip)
	if ( tooltip.tcBuilt ) then return; end
	waiting[tooltip] = true;
	later:Show();
end

local function SpellSubject(id, extra)
	if ( type(id) ~= "number" ) then return nil; end
	local s = extra or {};
	s.kind, s.id = "spell", id;
	return s;
end

for _, name in ipairs(TOOLTIPS) do
	local tooltip = _G[name];
	if ( tooltip ) then
		tooltip:HookScript("OnTooltipCleared", Cleared);
		tooltip:HookScript("OnHide", Cleared);
		-- (can fire twice for one item: the second sees tcSubject / tcBuilt and does nothing)
		tooltip:HookScript("OnTooltipSetItem", function(self)
			if ( self.tcBuilt or self.tcSubject ) then return; end
			local _, link = self:GetItem();
			local id = L.IdFromLink(link, "item");
			if ( id ) then Subject(self, { kind = "item", id = id, link = link }); Wait(self); end
		end);
		tooltip:HookScript("OnTooltipSetSpell", function(self)
			if ( self.tcBuilt or self.tcSubject ) then return; end
			local _, _, id = self:GetSpell();
			local s = SpellSubject(id);
			if ( s ) then Subject(self, s); Wait(self); end
		end);
		-- units at once: the world's mouseover tooltip has no Lua setter, and DragonUI reserves its health bar's line a
		-- frame later, after everything else
		if ( tooltip.GetUnit ) then
			tooltip:HookScript("OnTooltipSetUnit", function(self)
				if ( self.tcBuilt ) then return; end
				local unitName, unit = self:GetUnit();
				if ( unit ) then
					Subject(self, { kind = "unit", id = UnitGUID(unit) or unitName, unit = unit, name = unitName });
					Build(self);
				end
			end);
		end
	end
end

-- the setters: their own facts first (book slot, action, aura), then the build
hooksecurefunc(GameTooltip, "SetSpell", function(tooltip, slot, book)
	Subject(tooltip, SpellSubject(L.IdFromLink(GetSpellLink(slot, book)),
		{ slot = slot, book = book, passive = IsPassiveSpell(slot, book) and true or false }));
	Build(tooltip);
end);
hooksecurefunc(GameTooltip, "SetAction", function(tooltip, slot)
	local kind, _, _, spellId = GetActionInfo(slot);
	if ( kind == "spell" and spellId ) then Subject(tooltip, SpellSubject(spellId, { action = slot, passive = true })); end
	Build(tooltip);
end);
local function AuraHook(filter)
	return function(tooltip, unit, index, auraFilter)
		local id = select(11, UnitAura(unit, index, filter or auraFilter));
		Subject(tooltip, SpellSubject(id, { aura = true, passive = true }));
		Build(tooltip);
	end
end
hooksecurefunc(GameTooltip, "SetUnitAura", AuraHook(nil));
hooksecurefunc(GameTooltip, "SetUnitBuff", AuraHook("HELPFUL"));
hooksecurefunc(GameTooltip, "SetUnitDebuff", AuraHook("HARMFUL"));
for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
	hooksecurefunc(tooltip, "SetHyperlink", function(self, link)
		if ( type(link) == "string" ) then
			local id = tonumber(string.match(link, "spell:(%d+)") or string.match(link, "enchant:(%d+)"));
			if ( id ) then Subject(self, SpellSubject(id, { link = link, passive = true })); end
		end
		Build(self);
	end);
end
-- every other setter: the subject OnTooltipSet... saw
local OTHER = { "SetBagItem", "SetInventoryItem", "SetMerchantItem", "SetBuybackItem", "SetLootItem", "SetLootRollItem",
	"SetQuestItem", "SetQuestLogItem", "SetQuestRewardSpell", "SetQuestLogRewardSpell", "SetTradeSkillItem",
	"SetAuctionItem", "SetAuctionSellItem", "SetGuildBankItem", "SetInboxItem", "SetSendMailItem", "SetTradePlayerItem",
	"SetTradeTargetItem", "SetHyperlinkCompareItem", "SetTalent", "SetTrainerService", "SetPetAction", "SetShapeshift",
	"SetGlyph", "SetUnit", "SetCurrencyToken", "SetSocketGem", "SetExistingSocketGem", "SetEquipmentSet",
	"SetMerchantCostItem", "SetBackpackToken" };
for _, name in ipairs(TOOLTIPS) do
	local tooltip = _G[name];
	if ( tooltip ) then
		for _, method in ipairs(OTHER) do
			if ( type(tooltip[method]) == "function" ) then hooksecurefunc(tooltip, method, Build); end
		end
	end
end
