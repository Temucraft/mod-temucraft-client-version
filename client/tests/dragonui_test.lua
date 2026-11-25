-- Stub tests for the DragonUI step-aside switch (no client): lua5.1 client/tests/dragonui_test.lua (from the module folder)
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
local file = dir.."/Interface/FrameXML/Temucraft/TemucraftDragonUI.lua";
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end

-- the logic alone
dofile(file);
local D = TemucraftDragonUILogic;
local function enabled(set) return function(module) return set[module] == true; end; end
local all = { characterpanel = true, micromenu = true, spellbook = true, talents = true, questdialog = true, addonmanager = true };
local owned = D.Resolve(true, enabled(all));
check("every overlapping piece taken", owned.char and owned.currency and owned.micro and owned.book and owned.talents and owned.gossip and owned.addons);
check("unique windows stay ours", not owned.rep and not owned.guild and not owned.gbank and not owned.menu and not owned.taxi and not owned.collections);
check("DragonUI not running: nothing taken", next(D.Resolve(false, enabled(all))) == nil);
owned = D.Resolve(true, enabled({ talents = true }));
check("one module off: ours back", owned.talents and not owned.book and not owned.char);
check("character panel covers currency too", D.Resolve(true, enabled({ characterpanel = true })).currency == true);
check("a module that errors counts as off", next(D.Resolve(true, function() error("boom"); end)) == nil);
check("note names the module", D.Note("book", { book = true }) == "DragonUI's Spellbook" and D.Note("book", {}) == nil and D.Note("rep", { rep = true }) == nil);

-- the switch in the client: a stub frame, DragonUI's addon table and PLAYER_LOGIN
local function Load(dragonLoaded, modules, skipLogin)
	local frames = {};
	CreateFrame = function()
		local f = { scripts = {}, events = {} };
		function f:RegisterEvent(e) self.events[e] = true; end
		function f:UnregisterEvent(e) self.events[e] = nil; end
		function f:SetScript(k, fn) self.scripts[k] = fn; end
		function f:Hide() end
		function f:Show() end
		table.insert(frames, f);
		return f;
	end
	local loggedIn = false;
	IsLoggedIn = function() return loggedIn; end
	IsAddOnLoaded = function(name) return dragonLoaded and name == "DragonUI"; end
	DragonUI = dragonLoaded and { db = { profile = { modules = {} } } } or nil;
	if ( DragonUI ) then
		for k, v in pairs(modules) do DragonUI.db.profile.modules[k] = { enabled = v }; end
		function DragonUI:IsModuleEnabled(name) local c = self.db.profile.modules[name]; return c and c.enabled or false; end
	end
	dofile(file);
	local fired = 0;
	TemucraftDragonUI_OnChange(function() fired = fired + 1; end);
	loggedIn = true;
	if ( skipLogin ) then return fired; end
	for _, f in ipairs(frames) do
		if ( f.events.PLAYER_LOGIN and f.scripts.OnEvent ) then f.scripts.OnEvent(f, "PLAYER_LOGIN"); end
	end
	return fired;
end

local fired = Load(true, { characterpanel = true, spellbook = true, talents = false, micromenu = true });
check("login tells the windows once", fired == 1);
check("loaded", TemucraftDragonUI_IsLoaded() == true);
check("character panel and spellbook taken", TemucraftDragonUI_Owns("char") and TemucraftDragonUI_Owns("book") and TemucraftDragonUI_Owns("micro"));
check("talents module off: our talents stay", not TemucraftDragonUI_Owns("talents"));
check("gossip: DragonUI's module not in its profile counts as off", not TemucraftDragonUI_Owns("gossip"));
check("note for the options page", TemucraftDragonUI_Note("char") == "DragonUI's Character Panel" and TemucraftDragonUI_Note("talents") == nil);
check("the player's saved choice is not written", DragonUI.db.profile.modules.talents.enabled == false);

Load(false, {});
check("DragonUI off (after /reload): every window ours again", not TemucraftDragonUI_IsLoaded() and not TemucraftDragonUI_Owns("char")
	and not TemucraftDragonUI_Owns("book") and TemucraftDragonUI_Note("char") == nil);

-- asked before our PLAYER_LOGIN ran (another frame's came first): read at once
fired = Load(true, { questdialog = true }, true);
check("nothing told before anyone asks", fired == 0);
check("gossip taken", TemucraftDragonUI_Owns("gossip"));

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
