-- Stub tests for the flight map's route dots (no client): lua5.1 client/tests/taxi_test.lua (from the module folder)
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
dofile(dir.."/Interface/FrameXML/Temucraft/TemucraftTaxi.lua");
local L = TemucraftTaxiLogic;
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end

check("nothing before a list", not L.IsTransit("Southshore, Hillsbrad", "REACHABLE"));
check("names before B ignored", L.OnMessage("N~Southshore, Hillsbrad") == false and L.incoming == nil);
check("begin", L.OnMessage("B") == false and L.incoming ~= nil);
check("names", L.OnMessage("N~Southshore, Hillsbrad~Refuge Pointe, Arathi") == false);
check("more names", L.OnMessage("N~Menethil Harbor, Wetlands") == false);
check("list not used until the end", not L.IsTransit("Menethil Harbor, Wetlands", "REACHABLE"));
check("end", L.OnMessage("E") == true and L.incoming == nil);
check("transit", L.IsTransit("Southshore, Hillsbrad", "REACHABLE") and L.IsTransit("Menethil Harbor, Wetlands", "REACHABLE"));
check("comma in a name kept", L.IsTransit("Refuge Pointe, Arathi", "DISTANT"));
check("known node not transit", not L.IsTransit("Ironforge, Dun Morogh", "REACHABLE"));
check("current never transit", not L.IsTransit("Southshore, Hillsbrad", "CURRENT"));
check("hidden never transit", not L.IsTransit("Southshore, Hillsbrad", "NONE"));
check("empty list clears", L.OnMessage("B") == false and L.OnMessage("E") == true and not L.IsTransit("Southshore, Hillsbrad", "REACHABLE"));
check("stray end ignored", L.OnMessage("E") == false);
check("not a string", L.OnMessage(nil) == false);

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
