-- Temucraft: spell tooltip details (mod-temucraft-classes, TemucraftSpellInfo.cpp).
-- When the tooltip of one of your spells is shown (spell book or action bar), the server is asked what changes it
-- right now, and the answer is added under the tooltip:
--   Your bonuses: +35% damage, -10% cooldown, -5% cost, -0.5 sec cast
--   Damage: 236 to 265 -> 1031 to 1237           (the base value, then what you really get: green better, red worse)
--   Cost 335 -> 300 mana, Cast 2 -> 1.5 sec
--   Talents:
--   • Improved Wrath (5/5): -0.5 sec cast time
--   • Moonfury (3/3): +10% damage
--   Glyphs: / Other effects: (the same way)
--   7% chance to crit for 200% damage
--   Changed by Temucraft: Cooldown 8 -> 6 sec      (stock 3.3.5 -> this server)
-- The answer is several messages (I, V, C, T..., E; see the .cpp). A server without the E message (older module)
-- gets the old lines after a short wait. The lines go on through TemucraftTooltips.lua (order 20), once per tooltip
-- build: tooltips that are refreshed every 0.2 s (DragonUI's spellbook, the action bars) must look the same each time,
-- so an answer is shown until a newer one is in: after 5 seconds, or when your buffs, talents or gear change, the
-- server is asked again while the old answer stays on; a changed answer redraws the tooltip once.
-- "Your bonuses: +N% damage" only on spells that deal damage or heal (the server's damage bonus is by school, so it
-- would otherwise show on Parachute, mounts...).

local PREFIX = "TSI";
local KEEP = 5;
local WAIT = 0.5;          -- seconds to wait for the end of an answer from an older server
local MAX_LINES = 6;       -- lines per group (talents, glyphs, other effects), then "+N more"
local BULLET = "\226\128\162 ";   -- "• "
local ARROW = " -> ";
local GOOD, BAD, OLD = "|cff20ff20", "|cffff3030", "|cff9d9d9d";
local cache = {};          -- spell id -> answer
local pending = {};        -- spell id -> answer still coming in
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

-- 1.50 -> "1.5", 2.00 -> "2"
local function Num(n)
	local s = string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", "");
	if ( s == "-0" ) then s = "0"; end
	return s;
end

local function SignedNum(n, suffix)
	return (n > 0 and "+" or "") .. Num(n) .. suffix;
end

-- milliseconds as "1.5 sec" / "2 min"
local function Time(ms, signed)
	local v, unit = ms / 1000, " sec";
	if ( math.abs(ms) >= 60000 and ms % 60000 == 0 ) then v, unit = ms / 60000, " min"; end
	if ( signed ) then return SignedNum(v, unit); end
	return Num(v) .. unit;
end

local POWER = { [0] = "mana", [1] = "rage", [2] = "focus", [3] = "energy", [6] = "runic power", [-2] = "health" };
local function Power(amount, power)
	if ( power == 1 or power == 6 ) then amount = amount / 10; end
	return amount, POWER[power] or "mana";
end

-- SpellModOp: label, how a flat value reads ("time", "pct" points, "yd" or plain), and whether less is better
-- (nil: neither better nor worse)
local OPS = {
	[0] = { "damage" }, [1] = { "duration", "time" }, [2] = { "threat", nil, "neutral" }, [3] = { "effect 1" },
	[4] = { "charges" }, [5] = { "range", "yd" }, [6] = { "radius", "yd" }, [7] = { "crit", "pct" },
	[8] = { "effect" }, [9] = { "pushback resistance", "pct" }, [10] = { "cast time", "time", true },
	[11] = { "cooldown", "time", true }, [12] = { "effect 2" }, [13] = { "armor ignored", "pct" },
	[14] = { "cost", "cost", true }, [15] = { "crit damage bonus" }, [16] = { "hit", "pct" }, [17] = { "targets" },
	[18] = { "chance", "pct" }, [19] = { "time between ticks", "time", true }, [20] = { "chained damage" },
	[21] = { "global cooldown", "time", true }, [22] = { "periodic damage" }, [23] = { "effect 3" },
	[24] = { "of spell power", "pct" }, [26] = { "procs per minute" }, [27] = { "effect" },
	[28] = { "dispel resistance", "pct" }, [29] = { "crit damage bonus" }, [30] = { "cost refunded on a miss", "pct" },
};

-- text and colour of one modifier: op, "f" or "p", amount
local function Describe(op, kind, amount, power)
	local o = OPS[op] or { "spell effect " .. op };
	local label, flat, lower = o[1], o[2], o[3];
	local text;
	if ( kind == "p" ) then
		if ( op == 24 ) then label = "spell power coefficient"; end
		text = SignedNum(amount, "% " .. label);
	elseif ( flat == "time" ) then
		text = Time(amount, true) .. " " .. label;
	elseif ( flat == "pct" ) then
		text = SignedNum(amount, "% " .. label);
	elseif ( flat == "yd" ) then
		text = SignedNum(amount, " yd " .. label);
	elseif ( flat == "cost" ) then
		local v, name = Power(amount, power);
		text = SignedNum(v, " " .. name);
	else
		text = SignedNum(amount, " " .. label);
	end
	local good;
	if ( lower == "neutral" ) then good = true;
	elseif ( lower ) then good = amount < 0;
	else good = amount > 0; end
	return (good and GOOD or BAD) .. text .. "|r";
end

-- "key:base:final[:power]" entries of V and C messages
local VALUE_LABEL = { d = "Damage", o = "Damage over time", h = "Healing", g = "Healing over time",
	c = "Cost", t = "Cast", k = "Cooldown", r = "Range", u = "Duration" };
local LOWER_BETTER = { c = true, t = true, k = true };

local function ParseValues(text)
	local out = {};
	for entry in text:gmatch("[^,]+") do
		local key, a, b, extra = entry:match("^(%a):([^:]+):([^:]+):?(.*)$");
		if ( key ) then out[#out + 1] = { key = key, base = a, now = b, power = tonumber(extra) }; end
	end
	return out;
end

local function First(v) return tonumber(v:match("^%-?%d+")) or 0; end

local function ValueText(v)
	local function show(s)
		if ( v.key == "t" or v.key == "k" or v.key == "u" ) then return Time(tonumber(s) or 0); end
		if ( v.key == "r" ) then return s .. " yd"; end
		if ( v.key == "c" ) then return Num((Power(tonumber(s) or 0, v.power))); end
		return (s:gsub("^(%d+)%-(%d+)$", function(x, y) if x == y then return x; end return x .. " to " .. y; end));
	end
	local better = First(v.now) > First(v.base);
	if ( LOWER_BETTER[v.key] ) then better = not better; end
	local text = OLD .. show(v.base) .. "|r" .. ARROW .. (better and GOOD or BAD) .. show(v.now) .. "|r";
	if ( v.key == "c" ) then text = text .. " " .. select(2, Power(0, v.power)); end
	return text, better;
end

local function AddValues(tooltip, values)
	local joined = {};
	for _, v in ipairs(values) do
		local text = ValueText(v);
		if ( v.key == "d" or v.key == "o" or v.key == "h" or v.key == "g" ) then
			tooltip:AddLine(VALUE_LABEL[v.key] .. ": " .. text, 1, 1, 1, true);
		else
			joined[#joined + 1] = VALUE_LABEL[v.key] .. " " .. text;
		end
	end
	if ( #joined > 0 ) then tooltip:AddLine(table.concat(joined, ", "), 1, 1, 1, true); end
end

local function AddEffects(tooltip, header, list, r, g, b, power)
	if ( #list == 0 ) then return; end
	tooltip:AddLine(header, r, g, b, true);
	for i, e in ipairs(list) do
		if ( i > MAX_LINES and #list > MAX_LINES + 1 ) then
			tooltip:AddLine("  +" .. (#list - MAX_LINES) .. " more", 0.6, 0.6, 0.6, true);
			break;
		end
		local mods = {};
		for _, m in ipairs(e.mods) do mods[#mods + 1] = Describe(m.op, m.kind, m.amount, power); end
		local name = e.name;
		if ( e.maxRank > 0 ) then name = name .. " (" .. e.rank .. "/" .. e.maxRank .. ")"; end
		tooltip:AddLine(BULLET .. name .. ": " .. table.concat(mods, ", "), r, g, b, true);
	end
end

-- the spell deals damage or heals (crit chance is only sent for those; or it has damage / heal values)
local function DealsAmount(info)
	if ( info.crit and info.crit > 0 ) then return true; end
	for _, list in ipairs({ info.values or {}, info.changed or {} }) do
		for _, v in ipairs(list) do
			if ( v.key == "d" or v.key == "o" or v.key == "h" or v.key == "g" ) then return true; end
		end
	end
	return false;
end

local function AddLines(tooltip, info)
	local parts = {};
	if ( info.damage ~= 0 and DealsAmount(info) ) then parts[#parts + 1] = Signed(info.damage, "% damage"); end
	if ( info.cooldown ~= 0 ) then parts[#parts + 1] = Signed(info.cooldown, "% cooldown"); end
	if ( info.cost ~= 0 ) then parts[#parts + 1] = Signed(info.cost, "% cost"); end
	if ( info.cast ~= 0 ) then parts[#parts + 1] = Signed(math.floor(info.cast / 100 + 0.5) / 10, " sec cast"); end
	local before = tooltip:NumLines();
	if ( #parts > 0 ) then
		tooltip:AddLine("Your bonuses: " .. table.concat(parts, ", "), 0.1, 1, 0.1, true);
	end
	if ( info.values ) then AddValues(tooltip, info.values); end
	if ( info.effects ) then
		local power = info.power;
		if ( not power ) then power = select(6, GetSpellInfo(info.id)); end
		local groups = { t = {}, g = {}, o = {} };
		for _, e in ipairs(info.effects) do table.insert(groups[e.kind] or groups.o, e); end
		AddEffects(tooltip, "Talents:", groups.t, 0.4, 0.7, 1, power);
		AddEffects(tooltip, "Glyphs:", groups.g, 0.6, 0.8, 1, power);
		AddEffects(tooltip, "Other effects:", groups.o, 1, 0.82, 0.5, power);
	else
		if ( info.talents ~= "" ) then
			tooltip:AddLine("Talents: " .. info.talents:gsub(",", ", "), 0.4, 0.7, 1, true);
		end
		if ( info.others ~= "" ) then
			tooltip:AddLine("Other effects: " .. info.others:gsub(",", ", "), 1, 0.82, 0.5, true);
		end
	end
	if ( info.crit > 0 ) then
		tooltip:AddLine(string.format("%s%% chance to crit for %d%% damage", (math.floor(info.crit * 10 + 0.5) / 10), info.critDamage), 1, 1, 1, true);
	end
	if ( info.changed and #info.changed > 0 ) then
		local parts = {};
		for _, v in ipairs(info.changed) do
			local function show(s)
				local t = ValueText({ key = v.key, base = s, now = s, power = v.power });
				return (t:match("^" .. OLD .. "(.-)|r"));
			end
			local unit = v.key == "c" and (" " .. select(2, Power(0, v.power))) or "";
			parts[#parts + 1] = VALUE_LABEL[v.key] .. " " .. BAD .. show(v.base) .. "|r" .. ARROW .. GOOD .. show(v.now) .. "|r" .. unit;
		end
		tooltip:AddLine("Changed by Temucraft: " .. table.concat(parts, ", "), 1, 0.5, 0.25, true);
	end
	return tooltip:NumLines() > before;
end

-- the answer (even an old one) goes on; an old or missing one is asked for again
local function Add(tooltip, id)
	shown = id;
	local info = cache[id];
	if ( not info or GetTime() - info.time >= KEEP ) then Ask(id); end
	if ( info ) then AddLines(tooltip, info); end
end

-- spells of your spell book and action bars, through TemucraftTooltips.lua
TemucraftTooltipLines = TemucraftTooltipLines or {};
table.insert(TemucraftTooltipLines, { order = 20, kinds = { spell = true }, add = function(tooltip, s)
	if ( tooltip ~= GameTooltip or not ((s.slot and s.book ~= "pet" and s.book ~= BOOKTYPE_PET) or s.action) ) then return; end
	Add(tooltip, s.id);
end });
GameTooltip:HookScript("OnHide", function() shown = nil; end);

-- what an answer says, to tell a changed one from the same one again
local function Signature(info)
	local parts = { info.damage, info.cooldown, info.cost, info.cast, info.crit, info.critDamage, info.talents, info.others };
	for _, list in ipairs({ info.values or {}, info.changed or {} }) do
		for _, v in ipairs(list) do parts[#parts + 1] = v.key .. v.base .. v.now; end
	end
	for _, e in ipairs(info.effects or {}) do
		parts[#parts + 1] = e.kind .. e.name .. e.rank;
		for _, m in ipairs(e.mods) do parts[#parts + 1] = m.op .. m.kind .. m.amount; end
	end
	for i = 1, #parts do parts[i] = tostring(parts[i]); end
	return table.concat(parts, "~");
end

-- the whole answer is in: keep it; when the tooltip on screen shows that spell and the answer is new or changed, it is
-- built again (its owner's own refresh, so every line stays in its place), or the lines are added once
local function Finish(id)
	local info = pending[id];
	if ( not info ) then return; end
	pending[id] = nil;
	info.time = GetTime();
	info.signature = Signature(info);
	local old = cache[id];
	cache[id] = info;
	if ( old and old.signature == info.signature ) then return; end
	local s = TemucraftTooltips_Subject and TemucraftTooltips_Subject(GameTooltip);
	if ( shown ~= id or not GameTooltip:IsShown() or (s and s.id ~= id) ) then return; end
	local owner = GameTooltip:GetOwner();
	if ( owner and type(owner.UpdateTooltip) == "function" ) then
		owner:UpdateTooltip();
	elseif ( not old and AddLines(GameTooltip, info) ) then
		GameTooltip:Show();
	end
end

local frame = CreateFrame("Frame");
frame:RegisterEvent("CHAT_MSG_ADDON");
frame:RegisterEvent("UNIT_AURA");
frame:RegisterEvent("CHARACTER_POINTS_CHANGED");
frame:RegisterEvent("PLAYER_TALENT_UPDATE");
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
frame:SetScript("OnUpdate", function()
	for id, info in pairs(pending) do
		if ( GetTime() - info.started > WAIT ) then Finish(id); end
	end
end);
frame:SetScript("OnEvent", function(self, event, prefix, text, channel, sender)
	if ( event ~= "CHAT_MSG_ADDON" ) then
		-- kept on screen until the new answer is in (asked for at the next look)
		if ( event ~= "UNIT_AURA" or prefix == "player" ) then
			for _, info in pairs(cache) do info.time = -KEEP; end
		end
		return;
	end
	if ( prefix ~= PREFIX or sender ~= UnitName("player") or type(text) ~= "string" ) then return; end
	local kind, id, rest = text:match("^(%a)~(%d+)~?(.*)$");
	id = tonumber(id);
	if ( not id ) then return; end
	if ( kind == "I" ) then
		local damage, cooldown, cost, cast, crit, critDamage, talents, others =
			rest:match("^([%-%d]+)~([%-%d]+)~([%-%d]+)~([%-%d]+)~([%d%.]+)~(%d+)~([^~]*)~?(.*)$");
		if ( not damage ) then return; end
		pending[id] = { id = id, started = GetTime(), damage = tonumber(damage) or 0, cooldown = tonumber(cooldown) or 0,
			cost = tonumber(cost) or 0, cast = tonumber(cast) or 0, crit = tonumber(crit) or 0,
			critDamage = tonumber(critDamage) or 0, talents = talents or "", others = others or "" };
		return;
	end
	local info = pending[id];
	if ( not info ) then return; end
	if ( kind == "V" ) then
		info.values = ParseValues(rest);
		for _, v in ipairs(info.values) do if ( v.key == "c" ) then info.power = v.power; end end
	elseif ( kind == "C" ) then
		info.changed = ParseValues(rest);
	elseif ( kind == "T" ) then
		local ekind, name, rank, maxRank, mods = rest:match("^(%a)~([^~]*)~(%d+)~(%d+)~(.*)$");
		if ( not ekind ) then return; end
		local e = { kind = ekind, name = name, rank = tonumber(rank), maxRank = tonumber(maxRank), mods = {} };
		for op, k, amount in mods:gmatch("(%d+):(%a):([%-%d]+)") do
			e.mods[#e.mods + 1] = { op = tonumber(op), kind = k, amount = tonumber(amount) };
		end
		info.effects = info.effects or {};
		info.effects[#info.effects + 1] = e;
	elseif ( kind == "E" ) then
		info.effects = info.effects or {};
		Finish(id);
	end
end);
