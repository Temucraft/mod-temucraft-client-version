-- Temucraft new spells (mod-temucraft-auto-learn, prefix TAL): in the spellbook, a "Train" button that learns every
-- class spell you can learn now (its tooltip lists them and the price) and a checkbox to have new spells learned
-- automatically as you level.
local PREFIX = "TAL";
local state = { enabled = false, on = false, choose = false, cost = false };
local missing, pending, total = {}, nil, 0;

local function Send(text) SendAddonMessage(PREFIX, text, "WHISPER", UnitName("player")); end
-- asks the server for the list again (TemucraftDragonUI.lua: when DragonUI's spellbook opens)
function TemucraftAutoLearn_Ask() Send("LIST"); end

local function Money(copper)
	if ( not copper or copper == 0 ) then return "free"; end
	local g, s, c = floor(copper / 10000), floor(copper / 100) % 100, copper % 100;
	local text = "";
	if ( g > 0 ) then text = text..g.."g "; end
	if ( s > 0 ) then text = text..s.."s "; end
	if ( c > 0 ) then text = text..c.."c"; end
	return strtrim(text);
end

local button = CreateFrame("Button", "TemucraftTrainButton", SpellBookFrame, "UIPanelButtonTemplate");
button:SetWidth(76); button:SetHeight(20);
button:SetPoint("TOPRIGHT", SpellBookFrame, "TOPRIGHT", -44, -40);
button:Hide();

local check = CreateFrame("CheckButton", "TemucraftAutoLearnCheck", SpellBookFrame, "UICheckButtonTemplate");
check:SetWidth(22); check:SetHeight(22);
check:SetPoint("RIGHT", button, "LEFT", -2, 0);
check:Hide();

StaticPopupDialogs["TEMUCRAFT_TRAIN_ALL"] = {
	text = "Learn %d new spell(s) for %s?",
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function() Send("LEARN"); end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
};

local function Refresh()
	if ( not state.enabled ) then button:Hide(); check:Hide(); return; end
	button:Show();
	button:SetText("Train ("..#missing..")");
	if ( #missing > 0 ) then button:Enable(); else button:Disable(); end
	if ( state.choose ) then check:Show(); check:SetChecked(state.on); else check:Hide(); end
end

button:SetScript("OnClick", function()
	if ( #missing == 0 ) then return; end
	if ( state.cost and total > 0 ) then
		StaticPopup_Show("TEMUCRAFT_TRAIN_ALL", #missing, Money(total));
	else
		Send("LEARN");
	end
end);
button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText("New spells");
	if ( #missing == 0 ) then
		GameTooltip:AddLine("Nothing new to learn right now.", 1, 1, 1);
	else
		for i, m in ipairs(missing) do
			if ( i > 25 ) then GameTooltip:AddLine("... and "..(#missing - 25).." more", 0.7, 0.7, 0.7); break; end
			local name, rank, icon = GetSpellInfo(m.id);
			GameTooltip:AddDoubleLine((icon and ("|T"..icon..":14|t ") or "")..(name or ("Spell "..m.id))..((rank and rank ~= "") and (" |cff999999("..rank..")|r") or ""),
				state.cost and Money(m.cost) or "", 1, 1, 1, 1, 0.82, 0);
		end
		if ( state.cost ) then GameTooltip:AddLine("Total: "..Money(total), 1, 0.82, 0); end
	end
	GameTooltip:Show();
end);
button:SetScript("OnLeave", function() GameTooltip:Hide(); end);

check:SetScript("OnClick", function(self) Send(self:GetChecked() and "ON" or "OFF"); end);
check:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText("Learn new spells automatically");
	GameTooltip:AddLine("New class spells are learned as soon as you reach their level"..(state.cost and ", if you can pay for them." or "."), 1, 1, 1, 1);
	GameTooltip:Show();
end);
check:SetScript("OnLeave", function() GameTooltip:Hide(); end);

SpellBookFrame:HookScript("OnShow", function() Send("LIST"); end);

local events = CreateFrame("Frame");
events:RegisterEvent("PLAYER_ENTERING_WORLD");
events:RegisterEvent("CHAT_MSG_ADDON");
events:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
	if ( event == "PLAYER_ENTERING_WORLD" ) then Send("LIST"); return; end
	if ( prefix ~= PREFIX or channel ~= "WHISPER" or sender ~= UnitName("player") ) then return; end
	local kind, a, b, c, d = strsplit("~", message);
	if ( kind == "S" ) then
		state.enabled, state.on, state.choose, state.cost = (a == "1"), (b == "1"), (c == "1"), (d == "1");
		Refresh();
	elseif ( kind == "BEGIN" ) then
		pending = {};
	elseif ( kind == "M" and pending ) then
		table.insert(pending, { id = tonumber(a), cost = tonumber(b) or 0 });
	elseif ( kind == "END" and pending ) then
		missing, pending, total = pending, nil, tonumber(a) or 0;
		Refresh();
	end
end);
