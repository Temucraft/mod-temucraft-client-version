-- Temucraft: retail-style flight paths (mod-temucraft-travel, TemucraftFlightPaths.cpp).
-- At a flight master you can fly to any flight point you know on this continent: the server adds the flight points
-- of your faction on the way (ones you don't know yet) to the flight map, so the client can route through them, and
-- tells us which they are before the map opens: "B", then "N~name~name...", then "E" (prefix TTX). They are drawn
-- as small grey route dots: not destinations, they can't be picked (the server refuses them as a destination too).

TemucraftTaxiLogic = {};
local L = TemucraftTaxiLogic;
local PREFIX = "TTX";
L.PREFIX = PREFIX;
L.transit = {};      -- node name -> true, for the flight map now open
L.incoming = nil;    -- the list still coming in

-- one message from the server; true when a whole list has come in
function L.OnMessage(text)
	if ( type(text) ~= "string" ) then return false; end
	if ( text == "B" ) then
		L.incoming = {};
	elseif ( string.sub(text, 1, 1) == "N" and L.incoming ) then
		for name in string.gmatch(string.sub(text, 2), "[^~]+") do
			L.incoming[name] = true;
		end
	elseif ( text == "E" and L.incoming ) then
		L.transit, L.incoming = L.incoming, nil;
		return true;
	end
	return false;
end

-- whether the flight map's node (its name and TaxiNodeGetType) is only one to fly through
function L.IsTransit(name, nodeType)
	if ( nodeType ~= "REACHABLE" and nodeType ~= "DISTANT" ) then return false; end
	return name ~= nil and L.transit[name] == true;
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

local DOT, SIZE = 8, 16;   -- route dot, the stock button (TaxiButtonTemplate)

local function OnEnter(self, motion)
	if ( self.temucraftTransit ) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:AddLine(TaxiNodeName(self:GetID()), 1.0, 1.0, 1.0);
		GameTooltip:AddLine("On the way: fly there once to land here.", 0.6, 0.6, 0.6, 1);
		GameTooltip:Show();
		return;
	end
	TaxiNodeOnButtonEnter(self, motion);
end

local function OnClick(self)
	if ( self.temucraftTransit ) then return; end
	TakeTaxiNode(self:GetID());
end

local function Style(button, transit)
	if ( not button.temucraftHooked ) then
		button.temucraftHooked = true;
		button:SetScript("OnEnter", OnEnter);
		button:SetScript("OnClick", OnClick);
	end
	button.temucraftTransit = transit or nil;
	local size = transit and DOT or SIZE;
	button:SetWidth(size);
	button:SetHeight(size);
	local normal = button:GetNormalTexture();
	if ( normal ) then
		if ( transit ) then normal:SetVertexColor(0.7, 0.7, 0.7); else normal:SetVertexColor(1, 1, 1); end
	end
	local highlight = button:GetHighlightTexture();
	if ( highlight ) then highlight:SetAlpha(transit and 0 or 1); end
end

local function Restyle()
	local num = NumTaxiNodes();
	for index = 1, num do
		local button = _G["TaxiButton"..index];
		if ( button ) then
			Style(button, L.IsTransit(TaxiNodeName(index), TaxiNodeGetType(index)));
		end
	end
end

TaxiFrame:HookScript("OnEvent", function(self, event)
	if ( event == "TAXIMAP_OPENED" ) then Restyle(); end
end);

local frame = CreateFrame("Frame");
frame:RegisterEvent("CHAT_MSG_ADDON");
frame:SetScript("OnEvent", function(self, event, prefix, text, channel, sender)
	if ( prefix ~= PREFIX or sender ~= UnitName("player") ) then return; end
	if ( L.OnMessage(text) and TaxiFrame:IsShown() ) then Restyle(); end
end);
