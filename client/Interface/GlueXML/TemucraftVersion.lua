-- Temucraft: the client version on the login screen (the version comes from the MPQ that carries this file).
TEMUCRAFT_CLIENT_VERSION = "@VERSION@";

local function TemucraftShowVersion()
	if ( AccountLoginVersion ) then
		local _, build = GetBuildInfo();
		AccountLoginVersion:SetText("Temucraft "..TEMUCRAFT_CLIENT_VERSION.."  |cff888888(3.3.5a build "..build..")|r");
	end
end

TemucraftShowVersion();
if ( AccountLogin and AccountLogin.HookScript ) then
	AccountLogin:HookScript("OnShow", TemucraftShowVersion);
end
