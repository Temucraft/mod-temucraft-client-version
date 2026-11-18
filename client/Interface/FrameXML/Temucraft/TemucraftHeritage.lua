-- Temucraft heritage (mod-temucraft-heritage, prefix THR): a button beside the character window to take on the
-- racial traits of another race (or go back to your own). /heritage opens the same menu.
local PREFIX = "THR";
local state = { enabled = false, current = 0, own = 0, minLevel = 1, cost = 0, wait = 0 };
local races, pending = {}, nil;
local bonus, bonusPending, bonusCount, bonusCost = {}, nil, 0, 0;

local function Send(text) SendAddonMessage(PREFIX, text, "WHISPER", UnitName("player")); end

local function RaceName(id)
	for _, r in ipairs(races) do if ( r.id == id ) then return r.name; end end
	return UnitRace("player");
end

local function Traits(r)
	local names = {};
	for _, id in ipairs(r.spells) do
		local name = GetSpellInfo(id);
		if ( name ) then table.insert(names, name); end
	end
	return table.concat(names, ", ");
end

local button = CreateFrame("Button", "TemucraftHeritageButton", PaperDollFrame);
button:SetWidth(28); button:SetHeight(28);
button:SetPoint("TOPLEFT", PaperDollFrame, "TOPRIGHT", -36, -76);
button:SetNormalTexture("Interface\\Icons\\Achievement_Character_Human_Male");
button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
button:Hide();

local menuFrame = CreateFrame("Frame", "TemucraftHeritageMenu", UIParent, "UIDropDownMenuTemplate");

StaticPopupDialogs["TEMUCRAFT_HERITAGE"] = {
	text = "Take on the racial traits of the %s?\n\n%s",
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function(self, data) Send(data == "RESET" and "RESET" or ("PICK~"..data)); end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
};

StaticPopupDialogs["TEMUCRAFT_HERITAGE_BONUS"] = {
	text = "%s",
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function(self, data) Send(data); end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
};

local function Ask(r)
	local note = Traits(r);
	if ( r.id == state.own ) then
		note = note.."\n\nYour own traits come back.";
	elseif ( state.cost > 0 ) then
		note = note.."\n\nCosts "..floor(state.cost / 10000).." gold.";
	end
	local dialog = StaticPopup_Show("TEMUCRAFT_HERITAGE", r.name, note);
	if ( dialog ) then dialog.data = (r.id == state.own) and "RESET" or r.id; end
end

local function ShowMenu()
	local menu = { { text = "Heritage", isTitle = 1, notCheckable = 1 } };
	if ( UnitLevel("player") < state.minLevel ) then
		table.insert(menu, { text = "From level "..state.minLevel, notCheckable = 1, disabled = 1 });
	elseif ( state.wait > 0 ) then
		table.insert(menu, { text = format("Changed recently: %d h %d min left", floor(state.wait / 3600), floor(state.wait / 60) % 60), notCheckable = 1, disabled = 1 });
	end
	for _, r in ipairs(races) do
		local race = r;
		table.insert(menu, {
			text = race.name..((race.id == state.own) and " |cff999999(yours)|r" or ""),
			checked = (state.current == race.id),
			tooltipTitle = race.name,
			tooltipText = Traits(race),
			tooltipOnButton = 1,
			func = function() if ( race.id ~= state.current ) then Ask(race); end end,
		});
	end
	if ( bonusCount > 0 and #bonus > 0 ) then
		local carried = 0;
		for _, b in ipairs(bonus) do if ( b.chosen ) then carried = carried + 1; end end
		table.insert(menu, { text = format("Second racial (%d/%d)", carried, bonusCount), isTitle = 1, notCheckable = 1 });
		for _, b in ipairs(bonus) do
			local entry = b;
			local name, _, icon = GetSpellInfo(entry.spell);
			if ( name ) then
				table.insert(menu, {
					text = name, icon = icon,
					checked = entry.chosen,
					tooltipTitle = name,
					tooltipText = entry.chosen and "Click to drop it." or "Carried on top of your heritage.",
					tooltipOnButton = 1,
					func = function()
						local text, data;
						if ( entry.chosen ) then
							text, data = "Drop "..name.."?", "BDROP~"..entry.spell;
						else
							text, data = "Also carry "..name.."?"..((bonusCost > 0) and ("\n\nCosts "..floor(bonusCost / 10000).." gold.") or ""), "BTAKE~"..entry.spell;
						end
						local dialog = StaticPopup_Show("TEMUCRAFT_HERITAGE_BONUS", text);
						if ( dialog ) then dialog.data = data; end
					end,
				});
			end
		end
	end
	table.insert(menu, { text = CANCEL, notCheckable = 1, func = function() end });
	EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU");
end

button:SetScript("OnClick", ShowMenu);
button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText("Heritage");
	GameTooltip:AddLine("Racial traits of the "..RaceName(state.current)..".", 1, 1, 1, 1);
	GameTooltip:AddLine("Click to choose another race's traits.", 0.7, 0.7, 0.7, 1);
	GameTooltip:Show();
end);
button:SetScript("OnLeave", function() GameTooltip:Hide(); end);

local events = CreateFrame("Frame");
events:RegisterEvent("PLAYER_ENTERING_WORLD");
events:RegisterEvent("CHAT_MSG_ADDON");
events:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
	if ( event == "PLAYER_ENTERING_WORLD" ) then Send("LIST"); return; end
	if ( prefix ~= PREFIX or channel ~= "WHISPER" or sender ~= UnitName("player") ) then return; end
	local kind, a, b, c, d, e, f = strsplit("~", message);
	if ( kind == "S" ) then
		state.enabled, state.current, state.own = (a == "1"), tonumber(b) or 0, tonumber(c) or 0;
		state.minLevel, state.cost, state.wait = tonumber(d) or 1, tonumber(e) or 0, tonumber(f) or 0;
		if ( state.enabled ) then button:Show(); else button:Hide(); end
	elseif ( kind == "BEGIN" ) then
		pending, bonusPending = {}, {};
	elseif ( kind == "C" ) then
		bonusCount, bonusCost = tonumber(a) or 0, tonumber(b) or 0;
	elseif ( kind == "B" and bonusPending ) then
		table.insert(bonusPending, { spell = tonumber(a), chosen = (b == "1") });
	elseif ( kind == "R" and pending ) then
		local spells = {};
		for id in string.gmatch(c or "", "%d+") do table.insert(spells, tonumber(id)); end
		table.insert(pending, { id = tonumber(a), name = b, spells = spells });
	elseif ( kind == "END" and pending ) then
		races, pending = pending, nil;
		if ( bonusPending ) then bonus, bonusPending = bonusPending, nil; end
	end
end);

SLASH_TEMUCRAFTHERITAGE1 = "/heritage";
SlashCmdList["TEMUCRAFTHERITAGE"] = function() Send("LIST"); ShowMenu(); end;
