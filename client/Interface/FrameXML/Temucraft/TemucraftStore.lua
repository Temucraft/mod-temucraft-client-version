-- Temucraft interface store (mod-temucraft-account-wide, TemucraftUiStore.cpp, addon prefix TUS).
-- FrameXML has no SavedVariables, so what the Temucraft windows keep between sessions (favourite mounts and pets,
-- talent loadouts, the classic spellbook / talent frame choice) is kept on the server, per account ("A") or per
-- character ("C"). Without the server half the values last until logout.
--   TemucraftStore_Get(scope, key)            the text, or nil
--   TemucraftStore_Set(scope, key, text)      saves it ("" or nil deletes); text: no "~", "|" or tabs
--   TemucraftStore_OnReady(func)              func() once the server's values are in (and at once if they are)
local PREFIX = "TUS";
local CHUNK = 200;
local values = { A = {}, C = {} };
local incoming = {};
local ready, waiting, asked = false, {}, false;

local function Send(text) SendAddonMessage(PREFIX, text, "WHISPER", UnitName("player")); end

function TemucraftStore_Get(scope, key)
	return values[scope] and values[scope][key];
end

function TemucraftStore_Set(scope, key, text)
	if ( not values[scope] ) then return; end
	text = text and string.gsub(text, "[~|\t]", " ") or "";
	values[scope][key] = (text ~= "") and text or nil;
	local head = scope.."~"..key;
	Send("SB~"..head);
	for at = 1, #text, CHUNK do
		Send("SD~"..head.."~"..string.sub(text, at, at + CHUNK - 1));
	end
	Send("SE~"..head);
end

local function Ready()
	ready = true;
	for _, func in ipairs(waiting) do func(); end
	wipe(waiting);
end

function TemucraftStore_OnReady(func)
	if ( ready ) then func(); else table.insert(waiting, func); end
end

function TemucraftStore_IsReady() return ready; end

local frame = CreateFrame("Frame", "TemucraftStoreFrame");
frame:RegisterEvent("PLAYER_ENTERING_WORLD");
frame:RegisterEvent("CHAT_MSG_ADDON");
frame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		if ( not asked ) then
			asked = true;
			Send("ALL");
			-- no answer (server without the store): carry on with what this session sets
			local wait = 0;
			self:SetScript("OnUpdate", function(f, elapsed)
				wait = wait + elapsed;
				if ( ready or wait > 10 ) then
					f:SetScript("OnUpdate", nil);
					if ( not ready ) then Ready(); end
				end
			end);
		end
		return;
	end
	if ( prefix ~= PREFIX or channel ~= "WHISPER" or sender ~= UnitName("player") ) then return; end
	local kind, scope, key, text = string.match(message, "^(%a+)~?(%a?)~?([^~]*)~?(.*)$");
	if ( kind == "READY" ) then
		if ( not ready ) then Ready(); end
	elseif ( not values[scope] or not key or key == "" ) then
		return;
	elseif ( kind == "B" ) then
		incoming[scope.."~"..key] = {};
	elseif ( kind == "D" and incoming[scope.."~"..key] ) then
		table.insert(incoming[scope.."~"..key], text);
	elseif ( kind == "E" and incoming[scope.."~"..key] ) then
		values[scope][key] = table.concat(incoming[scope.."~"..key]);
		incoming[scope.."~"..key] = nil;
	end
end);
