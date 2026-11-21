-- Temucraft: spell tooltip details (mod-temucraft-classes, TemucraftSpellInfo.cpp).
-- When the tooltip of one of your spells is shown (spell book or action bar), the server is asked what changes it
-- right now, and the answer is added under the tooltip:
--   Your bonuses: +35% damage, -10% cooldown, -5% cost, -0.5 sec cast
--   Talents: Improved Wrath, Moonfury
--   Other effects: Moonkin Form
--   7% chance to crit for 200% damage
-- Answers are kept for 5 seconds, and dropped when your buffs, talents or gear change.

local PREFIX = "TSI";
local KEEP = 5;
local cache = {};          -- spell id -> { time, damage, cooldown, cost, cast, crit, critDamage, talents, others }
local asked = {};          -- spell id -> time asked
local shown = nil;         -- spell id of the tooltip on screen

local function Ask(id)
	if ( asked[id] and GetTime() - asked[id] < 1 ) then return; end
	asked[id] = GetTime();
	SendAddonMessage(PREFIX, "Q~" .. id, "WHISPER", UnitName("player"));
end

local function Signed(n, suffix)
	if ( n > 0 ) then return "+" .. n .. suffix; end
	return n .. suffix;
end

local function AddLines(tooltip, info)
	local parts = {};
	if ( info.damage ~= 0 ) then parts[#parts + 1] = Signed(info.damage, "% damage"); end
	if ( info.cooldown ~= 0 ) then parts[#parts + 1] = Signed(info.cooldown, "% cooldown"); end
	if ( info.cost ~= 0 ) then parts[#parts + 1] = Signed(info.cost, "% cost"); end
	if ( info.cast ~= 0 ) then parts[#parts + 1] = Signed(math.floor(info.cast / 100 + 0.5) / 10, " sec cast"); end
	local added = false;
	if ( #parts > 0 ) then
		tooltip:AddLine("Your bonuses: " .. table.concat(parts, ", "), 0.1, 1, 0.1, true);
		added = true;
	end
	if ( info.talents ~= "" ) then
		tooltip:AddLine("Talents: " .. info.talents:gsub(",", ", "), 0.4, 0.7, 1, true);
		added = true;
	end
	if ( info.others ~= "" ) then
		tooltip:AddLine("Other effects: " .. info.others:gsub(",", ", "), 1, 0.82, 0.5, true);
		added = true;
	end
	if ( info.crit > 0 ) then
		tooltip:AddLine(string.format("%s%% chance to crit for %d%% damage", (math.floor(info.crit * 10 + 0.5) / 10), info.critDamage), 1, 1, 1, true);
		added = true;
	end
	if ( added ) then tooltip:Show(); end
end

local function Show(tooltip, id)
	shown = id;
	if ( not id ) then return; end
	local info = cache[id];
	if ( info and GetTime() - info.time < KEEP ) then
		AddLines(tooltip, info);
	else
		Ask(id);
	end
end

local function IdFromLink(link)
	return link and tonumber(link:match("spell:(%d+)"));
end

hooksecurefunc(GameTooltip, "SetSpell", function(tooltip, slot, book)
	Show(tooltip, IdFromLink(GetSpellLink(slot, book)));
end);
hooksecurefunc(GameTooltip, "SetAction", function(tooltip, slot)
	local kind, id, _, spellID = GetActionInfo(slot);
	if ( kind == "spell" ) then Show(tooltip, spellID); else shown = nil; end
end);
GameTooltip:HookScript("OnHide", function() shown = nil; end);

local frame = CreateFrame("Frame");
frame:RegisterEvent("CHAT_MSG_ADDON");
frame:RegisterEvent("UNIT_AURA");
frame:RegisterEvent("CHARACTER_POINTS_CHANGED");
frame:RegisterEvent("PLAYER_TALENT_UPDATE");
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
frame:SetScript("OnEvent", function(self, event, prefix, text, channel, sender)
	if ( event ~= "CHAT_MSG_ADDON" ) then
		if ( event ~= "UNIT_AURA" or prefix == "player" ) then wipe(cache); end
		return;
	end
	if ( prefix ~= PREFIX or sender ~= UnitName("player") or type(text) ~= "string" ) then return; end
	local id, damage, cooldown, cost, cast, crit, critDamage, talents, others =
		text:match("^I~(%d+)~([%-%d]+)~([%-%d]+)~([%-%d]+)~([%-%d]+)~([%d%.]+)~(%d+)~([^~]*)~?(.*)$");
	id = tonumber(id);
	if ( not id ) then return; end
	local info = { time = GetTime(), damage = tonumber(damage) or 0, cooldown = tonumber(cooldown) or 0,
		cost = tonumber(cost) or 0, cast = tonumber(cast) or 0, crit = tonumber(crit) or 0,
		critDamage = tonumber(critDamage) or 0, talents = talents or "", others = others or "" };
	cache[id] = info;
	-- the tooltip asked for this spell is still on screen: add the lines now
	if ( shown == id and GameTooltip:IsShown() ) then AddLines(GameTooltip, info); end
end);
