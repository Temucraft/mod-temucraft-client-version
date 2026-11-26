-- Stub tests for the Options window logic (no client): lua5.1 client/tests/options_test.lua (from the module folder)
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
local ui = dir.."/Interface/FrameXML/Temucraft/";
dofile(ui.."TemucraftStyle.lua");
dofile(ui.."TemucraftOptions.lua");
dofile(ui.."TemucraftChangelog.lua");
dofile(ui.."TemucraftGameMenu.lua");
local O, G = TemucraftOptionsLogic, TemucraftGameMenuLogic;
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end

-- the category list
local list = O.GameList();
local names = {};
for _, item in ipairs(list) do table.insert(names, (item.kind == "section" and "#" or "")..item.text); end
check("game list", table.concat(names, ",") == "#Gameplay,Controls,Interface,Action Bars,Combat,Social,Keybindings,Nameplates,"
	.."#Accessibility,General,Colors,#System,Graphics,Audio,Languages,Network");
local keys, dup = {}, false;
for _, p in ipairs(O.PAGES) do if ( keys[p.key] ) then dup = true; end keys[p.key] = true; end
check("page keys unique", not dup and O.Page("graphics").apply and O.Page("keybindings").kind == "keybindings");
local stockOk, families = true, { interface = "InterfaceOptions", video = "VideoOptions", audio = "AudioOptions" };
for _, p in ipairs(O.PAGES) do
	for _, g in ipairs(p.groups or {}) do
		for _, r in ipairs(g.rows) do
			if ( r.stock and string.sub(r.stock, 1, #families[r.family]) ~= families[r.family] ) then stockOk = false; end
			if ( not r.stock and not r.kind ) then stockOk = false; end
			if ( not (r.label or r.text) ) then stockOk = false; end
		end
	end
end
check("rows name a stock control of their family, or a custom kind, and a label", stockOk);
local arach;
for _, r in ipairs(O.Page("a11ygeneral").groups[1].rows) do if ( r.kind == "server" ) then arach = r; end end
local tut, reset;
for _, g in ipairs(O.Page("interface").groups) do
	for _, r in ipairs(g.rows) do
		if ( r.kind == "tutorials" ) then tut = r; elseif ( r.kind == "button" and r.label == "Reset Tutorials" ) then reset = r; end
		if ( r.stock == "InterfaceOptionsHelpPanelShowTutorials" ) then tut = false; end
	end
end
check("Interface > Help: Tutorials box (in place of the stock one) and Reset Tutorials", tut and reset and type(reset.click) == "function");
check("arachnophobia row", arach and arach.name == "arachnophobia" and string.find(arach.tooltip, "spiders"));

-- search
check("search matches case-insensitive, colours ignored", O.Matches("|cffffd100Auto Loot|r", "auto l") and not O.Matches("Auto Loot", "camera"));
check("empty search matches", O.Matches("x", "") and O.Matches("x", nil));
check("search is plain text", O.Matches("Volume (%)", "(%)"));

-- sliders
check("snap", O.Snap(0.53, 0, 1, 0.1) == 0.5 and O.Snap(1.7, 0, 1, 0.1) == 1 and O.Snap(95, 90, 270, 10) == 100);
check("step", O.Step(90, 90, 270, 10, -1) == 90 and O.Step(90, 90, 270, 10, 1) == 100);
check("step without a step: tenths", math.abs(O.Step(0, 0, 1, 0, 1) - 0.1) < 1e-9);
check("format percent", O.Format(0.5, 0, 1, 0.1) == "50%");
check("format integer", O.Format(180, 90, 270, 10) == "180");
check("format decimals", O.Format(1.25, 0.5, 1.5, 0.05) == "1.25" and O.Format(0.9, 0.64, 1, 0.01, "2") == "0.90");
check("format low / high names", O.Format(0, 0, 1, 1, nil, { low = "Low", high = "High" }) == "Low" and O.Format(1, 0, 1, 1, nil, { low = "Low", high = "High" }) == "High");
check("format quality", O.Format(3, 1, 6, 1, "quality", { "Low", "Fair", "Good" }) == "Good");

-- key bindings
check("key with modifiers", O.KeyFromInput("F", true, true, true) == "ALT-CTRL-SHIFT-F" and O.KeyFromInput("1", false, false, false) == "1");
check("lone modifier ignored", O.KeyFromInput("LSHIFT", true) == nil and O.KeyFromInput("RALT", false, false, true) == nil);
check("mouse buttons", O.KeyFromInput("MiddleButton") == "BUTTON3" and O.KeyFromInput("Button4", true) == "SHIFT-BUTTON4");
check("left / right click don't bind", O.KeyFromInput("LeftButton") == nil and O.KeyFromInput("RightButton") == nil);
local texts = { HEADER_MOVEMENT = "Movement Keys", HEADER_BLANK = "", HEADER_CHAT = "Chat" };
local groups = O.GroupBindings({ { "HEADER_MOVEMENT" }, { "MOVEFORWARD", "W", "UP" }, { "HEADER_BLANK" }, { "JUMP", "SPACE" },
	{ "HEADER_CHAT" }, { "OPENCHAT", "ENTER" } }, function(c) return texts[c]; end);
check("binding groups", #groups == 2 and groups[1].text == "Movement Keys" and #groups[1].rows == 2 and groups[2].rows[1][1] == "OPENCHAT");
check("bindings before any header", O.GroupBindings({ { "X" } }, function() end)[1].text == "Other");

-- AddOns tab
local cats = { { name = "zeta" }, { name = "Alpha" }, { name = "Alpha Sub", parent = "Alpha" }, { name = "|cff00ff00Beta|r" } };
local tree = O.AddonTree(cats, {});
check("addons alphabetical, colours ignored, sub-pages folded", #tree == 3 and tree[1].cat.name == "Alpha" and tree[1].children
	and not tree[1].expanded and tree[2].cat.name == "|cff00ff00Beta|r" and tree[3].cat.name == "zeta" and not tree[3].children);
tree = O.AddonTree(cats, { Alpha = true });
check("expanded addon shows its sub-pages indented", #tree == 4 and tree[2].cat.name == "Alpha Sub" and tree[2].depth == 1);

-- server setting rows
local a, v = O.ServerReply("arachnophobia", "Arachnophobia mode: on");
check("server answer on", a == "yes" and v == "on");
a, v = O.ServerReply("arachnophobia", "|cff00ff00Arachnophobia|r is now off.");
check("server answer off", a == "yes" and v == "off");
check("no such command", O.ServerReply("arachnophobia", "There is no such command.") == "no");
check("player settings off", O.ServerReply("arachnophobia", "Player settings are off on this server.") == "no");
check("unrelated system line", O.ServerReply("arachnophobia", "You have learned a new spell.") == nil);

-- the game menu, retail order
local rows = G.Rows(false, false);
names = {};
for _, r in ipairs(rows) do table.insert(names, r[1]..(r[2] and ("+"..r[2]) or "")); end
check("menu rows", table.concat(names, ",") == "options,shop,addons+12,whatsnew,support,GameMenuButtonMacros,GameMenuButtonLogout+12,GameMenuButtonQuit,GameMenuButtonContinue+12");
check("one Options button: no sub rows in the new menu", #G.Rows(true, false) == #rows);
names = {};
for _, r in ipairs(G.Rows(false, false, { editmode = true, dragonui = true })) do table.insert(names, r[1]); end
check("menu rows with DragonUI", table.concat(names, ",") == "options,shop,addons,whatsnew,editmode,dragonui,support,GameMenuButtonMacros,GameMenuButtonLogout,GameMenuButtonQuit,GameMenuButtonContinue");
check("classic options: Options +/- opens the four", #G.Rows(true, false, { classicoptions = true }) == #rows + 4
	and #G.Rows(true, true, { classicoptions = true }) == #rows + 5 and #G.Rows(false, false, { classicoptions = true }) == #rows);

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
