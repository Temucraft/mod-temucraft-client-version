-- Temucraft gossip window, retail look: each gossip option of an NPC gets a big square icon for what it does (the
-- hearthstone for "Make this inn your home", a bag for the vendor, a book for the trainer, a flight mount for the
-- flight master...) with its text beside it, on a taller row. Quests keep their ! / ? icons. It is the stock
-- GossipFrame (its buttons aren't protected): after each GossipFrameUpdate the option buttons are restyled, and put
-- back as they were for quests and when "Classic gossip window" (Interface Options > Temucraft) is on.
TemucraftGossipLogic = {};
local L = TemucraftGossipLogic;

L.ICONS = {
	binder = "INV_Misc_Rune_01",            -- hearthstone
	vendor = "INV_Misc_Bag_10",
	trainer = "INV_Misc_Book_11",
	banker = "INV_Misc_Coin_02",
	battlemaster = "INV_BannerPVP_02",
	healer = "Spell_Holy_Resurrection",
	gossip = "INV_Misc_Note_01",
	petition = "INV_Scroll_03",
	tabard = "INV_Shirt_GuildTabard_01",
	unlearn = "INV_Misc_Book_09",
};
-- the icon for a gossip option type (GetGossipOptions); faction = UnitFactionGroup("player")
function L.Icon(gossipType, faction)
	gossipType = string.lower(gossipType or "");
	if ( gossipType == "taxi" ) then
		return "Interface\\Icons\\"..(faction == "Horde" and "Ability_Mount_Wyvern_01" or "Ability_Mount_Gryphon_01");
	end
	return "Interface\\Icons\\"..(L.ICONS[gossipType] or L.ICONS.gossip);
end

if ( not CreateFrame ) then return; end   -- tests load only the logic

local ICON, ROW = 36, 40;
local saved = {};   -- button -> what the stock layout had

local function Save(button, icon, text)
	if ( saved[button] ) then return saved[button]; end
	local s = { iconW = icon:GetWidth(), iconH = icon:GetHeight(), iconPoints = {}, textPoints = {} };
	for i = 1, icon:GetNumPoints() do s.iconPoints[i] = { icon:GetPoint(i) }; end
	if ( text ) then
		for i = 1, text:GetNumPoints() do s.textPoints[i] = { text:GetPoint(i) }; end
		s.textW = text:GetWidth();
	end
	saved[button] = s;
	return s;
end

local function Restore(button)
	local s = saved[button];
	if ( not s or not button.temucraftBig ) then return; end
	local icon = _G[button:GetName().."GossipIcon"];
	local text = button:GetFontString();
	icon:SetWidth(s.iconW); icon:SetHeight(s.iconH); icon:SetTexCoord(0, 1, 0, 1);
	icon:ClearAllPoints();
	for _, p in ipairs(s.iconPoints) do icon:SetPoint(unpack(p)); end
	if ( text ) then
		text:ClearAllPoints();
		for _, p in ipairs(s.textPoints) do text:SetPoint(unpack(p)); end
		if ( s.textW and s.textW > 0 ) then text:SetWidth(s.textW); end
		text:SetJustifyV("MIDDLE");
	end
	button.temucraftBig = nil;
	if ( GossipResize ) then GossipResize(button); end
end

local function Restyle()
	local classic = TemucraftUI_IsClassic and TemucraftUI_IsClassic("gossip");
	local options = { GetGossipOptions() };
	local faction = UnitFactionGroup("player");
	for i = 1, (NUMGOSSIPBUTTONS or 32) do
		local button = _G["GossipTitleButton"..i];
		if ( not button ) then break; end
		local icon = _G[button:GetName().."GossipIcon"];
		if ( button:IsShown() and button.type == "Gossip" and not classic and icon ) then
			local text = button:GetFontString();
			Save(button, icon, text);
			local gossipType = options[button:GetID() * 2];
			icon:SetTexture(L.Icon(gossipType, faction));
			icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
			icon:SetWidth(ICON); icon:SetHeight(ICON);
			icon:ClearAllPoints(); icon:SetPoint("LEFT", button, "LEFT", 2, 0);
			if ( text ) then
				text:ClearAllPoints();
				text:SetPoint("LEFT", icon, "RIGHT", 8, 0);
				text:SetWidth(max(60, button:GetWidth() - ICON - 14));
				text:SetJustifyH("LEFT");
			end
			button.temucraftBig = true;
			button:SetHeight(max(ROW, (button:GetTextHeight() or 0) + 8));
		else
			Restore(button);
		end
	end
end

if ( GossipFrameUpdate ) then hooksecurefunc("GossipFrameUpdate", Restyle); end
if ( TemucraftUI_OnChange ) then
	TemucraftUI_OnChange("classicgossip", function()
		if ( GossipFrame and GossipFrame:IsShown() and GossipFrameUpdate ) then GossipFrameUpdate(); end
	end);
end
