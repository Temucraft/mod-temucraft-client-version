-- Stub tests for the tooltip line builder (no client): lua5.1 client/tests/tooltips_test.lua (from the module folder)
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
dofile(dir.."/Interface/FrameXML/Temucraft/TemucraftTooltips.lua");
local T = assert(TemucraftTooltipsLogic);
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end

local function p(order, kinds, tag) return { order = order, kinds = kinds, add = function() end, tag = tag }; end
local list = { p(90, { spell = true, item = true }, "hint"), p(20, { spell = true }, "info"), p(50, { spell = true, item = true }, "ids"),
	p(10, { spell = true }, "label"), p(30, { item = true }, "token"), p(50, nil, "any"), { order = 1 } };
local function tags(kind)
	local out = {};
	for _, x in ipairs(T.Sorted(list, kind)) do table.insert(out, x.tag); end
	return table.concat(out, ",");
end
check("spell lines in a fixed order", tags("spell") == "label,info,ids,any,hint");
check("item lines in a fixed order", tags("item") == "token,ids,any,hint");
check("unit lines", tags("unit") == "any");
check("ids fit on one line", T.IdsOnOneLine(80, 120, 260));
check("icon on its own line when narrow", not T.IdsOnOneLine(80, 160, 230));
check("providers table is shared", TemucraftTooltipLines ~= nil);

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
