-- Temucraft core UI: tells the server which client version this is (prefix TCV) and shows the server's answer.
-- Built into FrameXML by the client MPQ, so it is always loaded (no addon to enable).
TEMUCRAFT_CLIENT_VERSION = "@VERSION@";

local function VersionParts(text)
	local parts = {};
	for n in string.gmatch(text or "", "%d+") do table.insert(parts, tonumber(n)); end
	return parts;
end

function TemucraftVersionBelow(a, b)
	local x, y = VersionParts(a), VersionParts(b);
	for i = 1, math.max(#x, #y) do
		local p, q = x[i] or 0, y[i] or 0;
		if ( p ~= q ) then return p < q; end
	end
	return false;
end

StaticPopupDialogs["TEMUCRAFT_OUTDATED"] = {
	text = "Your Temucraft client is out of date (%s, the server needs %s).\n\nClose the game and press UPDATE in the launcher.",
	button1 = OKAY,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
};

local helloSent = false;
local core = CreateFrame("Frame", "TemucraftCoreFrame");
core:RegisterEvent("PLAYER_ENTERING_WORLD");
core:RegisterEvent("CHAT_MSG_ADDON");
core:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		if ( not helloSent ) then
			helloSent = true;
			SendAddonMessage("TCV", "HELLO~"..TEMUCRAFT_CLIENT_VERSION, "WHISPER", UnitName("player"));
		end
		return;
	end
	if ( prefix ~= "TCV" or channel ~= "WHISPER" or sender ~= UnitName("player") ) then return; end
	local kind, required = strsplit("~", message);
	if ( kind == "OLD" and required ) then
		StaticPopup_Show("TEMUCRAFT_OUTDATED", TEMUCRAFT_CLIENT_VERSION, required);
	end
end);
