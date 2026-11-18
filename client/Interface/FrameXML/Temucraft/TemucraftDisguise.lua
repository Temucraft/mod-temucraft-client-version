-- Temucraft rogue disguises (mod-temucraft-rogue-disguise, prefix TRD): a Disguise button by the minimap for rogues
-- who know a disguise; it opens a menu of the known ones. /disguise opens the same menu.
local PREFIX = "TRD";
local list, worn, pending = {}, 0, nil;

local function Send(text) SendAddonMessage(PREFIX, text, "WHISPER", UnitName("player")); end

local button = CreateFrame("Button", "TemucraftDisguiseButton", Minimap);
button:SetWidth(28); button:SetHeight(28);
button:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", -6, -6);
button:SetFrameStrata("MEDIUM");
button:SetNormalTexture("Interface\\Icons\\Spell_Shadow_Charm");
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD");
button:Hide();

local menuFrame = CreateFrame("Frame", "TemucraftDisguiseMenu", UIParent, "UIDropDownMenuTemplate");

local function ShowMenu()
	local menu = { { text = "Disguises", isTitle = 1, notCheckable = 1 } };
	for _, d in ipairs(list) do
		if ( d.known ) then
			local id = d.id;
			table.insert(menu, {
				text = d.name..(d.reagent ~= "" and ("  |cff999999("..d.reagent.." x"..d.count..")|r") or ""),
				checked = (worn == id),
				func = function() Send("USE~"..id); end,
			});
		end
	end
	if ( worn ~= 0 ) then
		table.insert(menu, { text = "Take off the disguise", notCheckable = 1, func = function() Send("OFF"); end });
	end
	table.insert(menu, { text = CANCEL, notCheckable = 1, func = function() end });
	EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU");
end

button:SetScript("OnClick", ShowMenu);
button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT");
	GameTooltip:SetText("Disguise");
	GameTooltip:AddLine(worn ~= 0 and "You are in disguise." or "Click to put on a disguise.", 1, 1, 1);
	GameTooltip:Show();
end);
button:SetScript("OnLeave", function() GameTooltip:Hide(); end);

local function Refresh()
	local any = false;
	for _, d in ipairs(list) do if ( d.known ) then any = true; end end
	if ( any ) then button:Show(); else button:Hide(); end
	if ( worn ~= 0 ) then button:GetNormalTexture():SetVertexColor(0.4, 1, 0.4); else button:GetNormalTexture():SetVertexColor(1, 1, 1); end
end

local events = CreateFrame("Frame");
events:RegisterEvent("PLAYER_ENTERING_WORLD");
events:RegisterEvent("CHAT_MSG_ADDON");
events:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		local _, class = UnitClass("player");
		if ( class == "ROGUE" ) then Send("LIST"); end
		return;
	end
	if ( prefix ~= PREFIX or channel ~= "WHISPER" or sender ~= UnitName("player") ) then return; end
	local kind, a, b, c, d, e, f = strsplit("~", message);
	if ( kind == "BEGIN" ) then
		pending = {};
	elseif ( kind == "D" and pending ) then
		table.insert(pending, { id = tonumber(a), name = b, known = (c == "1"), level = tonumber(d), reagent = e or "", count = tonumber(f) or 0 });
	elseif ( kind == "A" ) then
		worn = tonumber(a) or 0;
		Refresh();
	elseif ( kind == "END" and pending ) then
		list = pending; pending = nil;
		Refresh();
	end
end);

SLASH_TEMUCRAFTDISGUISE1 = "/disguise";
SlashCmdList["TEMUCRAFTDISGUISE"] = function() Send("LIST"); ShowMenu(); end;
