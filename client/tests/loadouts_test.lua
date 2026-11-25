-- Stub tests for the server talent loadouts protocol (no client): lua5.1 client/tests/loadouts_test.lua (from the module folder)
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
dofile(dir.."/Interface/FrameXML/Temucraft/TemucraftTalents.lua");
local LO = assert(TemucraftLoadoutsLogic);
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end

-- fields
local f = LO.Fields("L~3~4~2~500~0/51/20~Fire ~ PvP", 7);
check("fields keep the rest", f[2] == "3" and f[6] == "0/51/20" and f[7] == "Fire ~ PvP");
check("few fields", #LO.Fields("X~2", 4) == 2 and LO.Fields("E")[1] == "E");

-- nothing before the server answered
check("inactive at start", not LO.Active());

-- a list
LO.OnMessage("S~1~10~3000~0~1~1~608000");
check("not active before the end", not LO.Active());
LO.OnMessage("L~1~4~0~0~0/51/20~Fire");
LO.OnMessage("L~2~2~0~0~0/0/0~Loadout 2");
LO.OnMessage("L~3~1~2~500~0/0/0~Loadout 3");
LO.OnMessage("L~4~0~3~1000~0/0/0~Loadout 4");
LO.OnMessage("L~5~3~0~0~0/0/0~Arcane");
check("end", LO.OnMessage("E") == "E");
check("active", LO.Active() and LO.server.count == 10 and LO.server.castMs == 3000 and LO.server.actions and LO.server.tokenItem == 608000);
check("slots", LO.slots[1].name == "Fire" and LO.slots[1].state == 4 and LO.slots[3].tokens == 2 and LO.slots[3].gold == 500);
check("unlocked", LO.Unlocked(LO.slots[1]) and LO.Unlocked(LO.slots[5]) and not LO.Unlocked(LO.slots[2]) and not LO.Unlocked(LO.slots[3]));

-- labels and costs
check("saved label", string.find(LO.Label(LO.slots[1]), "1. Fire", 1, true) and string.find(LO.Label(LO.slots[1]), "0/51/20", 1, true));
check("empty label", string.find(LO.Label(LO.slots[5]), "(empty)", 1, true));
check("dual label", string.find(LO.Label(LO.slots[2]), "Dual Talent", 1, true));
check("next label has the cost", string.find(LO.Label(LO.slots[3]), "2 Temucraft Tokens or 500 gold", 1, true));
check("locked label", string.find(LO.Label(LO.slots[4]), "Locked", 1, true) and not string.find(LO.Label(LO.slots[4]), "gold", 1, true));
check("gold thousands", LO.Gold(7500) == "7,500 gold" and LO.Gold(1234567) == "1,234,567 gold" and LO.Gold(500) == "500 gold");
check("one token", LO.Cost({ tokens = 1, gold = 0 }) == "1 Temucraft Token");
check("free", LO.Cost({ tokens = 0, gold = 0 }) == "free");
check("gold only", LO.Cost({ tokens = 0, gold = 2000 }) == "2,000 gold");

-- loading
LO.OnMessage("C~1~3000");
check("loading", LO.loading and LO.loading.slot == 1 and LO.loading.ms == 3000);
LO.OnMessage("X~1");
check("interrupted", LO.loading == nil);
LO.OnMessage("C~5~3000"); LO.OnMessage("D~5");
check("loaded", LO.loading == nil);

-- a second list replaces the first only when complete
LO.OnMessage("S~1~3~0~0~0~0~0");
LO.OnMessage("L~1~3~0~0~0/0/0~One");
check("old list kept while the new one comes", LO.slots[5] ~= nil and LO.server.count == 10);
LO.OnMessage("E");
check("new list", LO.server.count == 3 and LO.slots[5] == nil and LO.slots[1].name == "One" and not LO.server.actions);
LO.OnMessage("S~0~10~0~0~1~1~608000"); LO.OnMessage("E");
check("turned off", not LO.Active());

-- requests
check("hello", LO.Request("HELLO") == "HELLO" and LO.Request("LIST") == "LIST");
check("save", LO.Request("SAVE", 3) == "SAVE~3");
check("unlock", LO.Request("UNLOCK", 4, "gold") == "UNLOCK~4~gold");
check("rename cleans separators", LO.Request("RENAME", 2, "a~b|c") == "RENAME~2~a b c");
check("bad slot", LO.Request("LOAD", nil) == nil and LO.Request("LOAD", "x") == nil);
check("short", #LO.Request("RENAME", 1, string.rep("x", 400)) <= 240);

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
