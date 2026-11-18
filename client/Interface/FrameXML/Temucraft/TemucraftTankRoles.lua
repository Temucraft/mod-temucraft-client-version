-- Temucraft tank roles (mod-temucraft-threat, prefix TTR): the group's questions about who tanks, with what each
-- choice means. Server messages:
--   CLAIM~seconds~places~tanks~isTank~pct      more tank specs than places: claim it or not
--   VOTE~seconds~places~candidates~kind~pct    more claims than places: vote (kind tank / standin)
--   NOTANK~seconds~places~members~pct          nobody plays a tank spec: stand in, pick someone, or no thanks
--   PICKED~name~seconds~pct                    someone picked you to stand in
--   RESULT~kind~names / END                    the question is over
local PREFIX = "TTR";
local MAX_BUTTONS = 8;

local function Send(text) SendAddonMessage(PREFIX, text, "WHISPER", UnitName("player")); end

local frame = CreateFrame("Frame", "TemucraftTankRoleFrame", UIParent);
frame:SetWidth(360); frame:SetHeight(200);
frame:SetPoint("TOP", UIParent, "TOP", 0, -140);
frame:SetFrameStrata("DIALOG");
frame:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
});
frame:EnableMouse(true);
frame:SetMovable(true);
frame:RegisterForDrag("LeftButton");
frame:SetScript("OnDragStart", frame.StartMoving);
frame:SetScript("OnDragStop", frame.StopMovingOrSizing);
frame:Hide();
tinsert(UISpecialFrames, "TemucraftTankRoleFrame");

local icon = frame:CreateTexture(nil, "ARTWORK");
icon:SetWidth(32); icon:SetHeight(32);
icon:SetPoint("TOPLEFT", 20, -20);
icon:SetTexture("Interface\\Icons\\Ability_Warrior_DefensiveStance");

local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
title:SetPoint("LEFT", icon, "RIGHT", 10, 0);
title:SetPoint("RIGHT", frame, "RIGHT", -40, 0);
title:SetJustifyH("LEFT");

local body = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
body:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -10);
body:SetWidth(320);
body:SetJustifyH("LEFT");
body:SetJustifyV("TOP");

local timer = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall");
timer:SetPoint("BOTTOMRIGHT", -20, 16);

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
close:SetPoint("TOPRIGHT", -6, -6);

local buttons = {};
for i = 1, MAX_BUTTONS do
	local b = CreateFrame("Button", "TemucraftTankRoleButton"..i, frame, "UIPanelButtonTemplate");
	b:SetWidth(155); b:SetHeight(22);
	b:SetScript("OnClick", function(self)
		if ( self.reply ) then Send(self.reply); end
		if ( self.closes ) then frame:Hide(); else self:Disable(); end
	end);
	buttons[i] = b;
end

local endsAt = 0;
frame:SetScript("OnUpdate", function(self)
	local left = endsAt - GetTime();
	if ( left <= 0 ) then self:Hide(); return; end
	timer:SetText(format("%d sec", left));
end);

-- choices = { { label, reply, closes }, ... }
local function Ask(heading, text, seconds, choices)
	title:SetText(heading);
	body:SetText(text);
	endsAt = GetTime() + (tonumber(seconds) or 30);
	for i, b in ipairs(buttons) do
		local c = choices[i];
		b:ClearAllPoints();
		if ( c ) then
			b:SetText(c[1]); b.reply = c[2]; b.closes = c[3];
			b:Enable(); b:Show();
		else
			b:Hide();
		end
	end
	local rows = math.ceil(#choices / 2);
	for i = 1, #choices do
		local row, col = math.ceil(i / 2), (i - 1) % 2;
		buttons[i]:SetPoint("TOPLEFT", body, "BOTTOMLEFT", col * 165, -12 - (row - 1) * 26);
	end
	frame:SetHeight(90 + body:GetHeight() + rows * 26 + 20);
	frame:Show();
	PlaySound("ReadyCheck");
end

local function Names(list)
	local out = {};
	for n in string.gmatch(list or "", "[^,]+") do table.insert(out, n); end
	return out;
end

local function StandInText(pct)
	return "|cff40ff40+"..pct.."% threat, Taunt, 1% more mana, energy and runic power regeneration|r\n"..
		"|cffff8040-10% health, armor and damage|r\nIt ends when a real tank joins the group.";
end

local handlers = {};

handlers.CLAIM = function(seconds, places, tanks, isTank, pct)
	local list = table.concat(Names(tanks), ", ");
	if ( isTank ~= "1" ) then
		DEFAULT_CHAT_FRAME:AddMessage("|cffc69b6dTank:|r your group has more tanks than places ("..list.."); they are choosing.");
		return;
	end
	Ask("Who tanks?",
		"Your group has "..#Names(tanks).." tanks ("..list..") and "..places.." place(s) for the group's tank.\n\n"..
		"The group's tank gets |cff40ff40+"..pct.."% threat|r. Tanks not chosen play with normal threat: fine for "..
		"off-tanking, or switch to a damage or healing spec.\n\nIf more of you claim than fit, the whole group votes.",
		seconds, { { "I'll tank", "CLAIM", true }, { "Not me", "PASS", true } });
end

handlers.VOTE = function(seconds, places, candidates, kind, pct)
	local choices = {};
	for _, n in ipairs(Names(candidates)) do
		if ( #choices < MAX_BUTTONS - 1 ) then table.insert(choices, { n, "VOTE~"..n, true }); end
	end
	table.insert(choices, { "Don't vote", nil, true });
	local text;
	if ( kind == "standin" ) then
		text = "More players want to stand in as tank than there are places ("..places.."). Vote for who does it.\n\n"..
			"Stand-in Tank:\n"..StandInText(pct);
	else
		text = "More players want to tank than there are places ("..places.."). Vote for the group's tank.\n\n"..
			"The chosen tank gets |cff40ff40+"..pct.."% threat|r; the others play with normal threat.\n"..
			"A tie goes to the group leader's vote.";
	end
	Ask(kind == "standin" and "Vote: stand-in tank" or "Vote: the group's tank", text, seconds, choices);
end

handlers.NOTANK = function(seconds, places, members, pct)
	local choices = { { "I'll tank", "VOLUNTEER", true } };
	local me, more = UnitName("player"), 0;
	for _, n in ipairs(Names(members)) do
		if ( n ~= me ) then
			if ( #choices < MAX_BUTTONS - 1 ) then table.insert(choices, { "Pick "..n, "PICK~"..n, true });
			else more = more + 1; end
		end
	end
	table.insert(choices, { "No thanks", "NOTHANKS", true });
	local text = "Nobody in your group plays a tank spec. Someone can stand in as tank:\n\n"..StandInText(pct)..
		"\n\nStand in yourself, or pick someone (they have to accept).";
	if ( more > 0 ) then text = text.."\nOthers: /run or type .tankrole pick <name>"; end
	Ask("No tank in the group", text, seconds, choices);
end

handlers.PICKED = function(name, seconds, pct)
	Ask("Stand in as tank?", (name or "Someone").." picked you to stand in as the group's tank.\n\n"..StandInText(pct),
		seconds, { { ACCEPT, "ACCEPT", true }, { DECLINE, "DECLINE", true } });
end

handlers.RESULT = function() frame:Hide(); end
handlers.END = function() frame:Hide(); end

local events = CreateFrame("Frame");
events:RegisterEvent("CHAT_MSG_ADDON");
events:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
	if ( prefix ~= PREFIX or channel ~= "WHISPER" or sender ~= UnitName("player") ) then return; end
	local kind, a, b, c, d, e = strsplit("~", message);
	if ( handlers[kind] ) then handlers[kind](a, b, c, d, e); end
end);

SLASH_TEMUCRAFTTANKROLE1 = "/tankrole";
SlashCmdList["TEMUCRAFTTANKROLE"] = function() Send("ASK"); end
