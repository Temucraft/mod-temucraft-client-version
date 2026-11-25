-- Stub tests for the Issue Reporter logic (no client): lua5.1 client/tests/issues_test.lua (from the module folder)
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
dofile(dir.."/Interface/FrameXML/Temucraft/TemucraftIssues.lua");
local I = TemucraftIssuesLogic;
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end

-- menu and dialogs
check("three categories", #I.CATEGORIES == 3 and I.CATEGORIES[1].title == "Zone Bug" and I.CATEGORIES[1].desc == "I have encountered a Bug in this Zone."
	and I.CATEGORIES[2].title == "General Bug" and I.CATEGORIES[3].title == "Feedback / Suggestion");
check("hint spell", I.HintText("spell", "F6") == "Press F6 to submit an issue for this Spell");
check("hint creature, other key", I.HintText("creature", "SHIFT-F6") == "Press SHIFT-F6 to submit an issue for this Creature");
check("no hint without key", I.HintText("item", nil) == nil and I.HintText("general", "F6") == nil);
check("titles", I.Title("spell", "Fireball") == "Issue Report: Fireball" and I.Title("general") == "Bug Report");
check("questions", I.KINDS.spell.question == "What was the issue with this spell?" and I.KINDS.quest.question == "What was the issue with this quest?"
	and I.KINDS.general.question == "Please describe the issue:");
check("counter", I.Counter("") == "0 / 255" and I.Counter("abc") == "3 / 255");
check("counter counts letters", I.Utf8Len("\195\164\195\182x") == 3);
check("submit needs text", not I.CanSubmit("spell", "   ", nil) and I.CanSubmit("spell", "broken", nil));
check("quest needs bug or feedback", not I.CanSubmit("quest", "broken", nil) and I.CanSubmit("quest", "broken", "bug"));
check("general needs bug or feedback", not I.CanSubmit("general", "x", nil) and I.CanSubmit("general", "x", "feedback"));
check("feedback types", I.FeedbackType("spell") == "0" and I.FeedbackType("feedback") == "1" and I.FeedbackType("quest", "feedback") == "1"
	and I.FeedbackType("general", "bug") == "0");

-- the JSON, in FeedbackUI's layout (the dashboard filters with LIKE '%"feedbacktype" : "0"%')
local json = I.ToJSON({ feedbacktype = "0", text = "He said \"hi\"\nthen |cffff0000red|r \\o/", reportSubjectId = 133 });
check("feedbackui layout", string.find(json, "\"feedbacktype\" : \"0\"", 1, true) ~= nil);
check("sorted, comma joined", string.sub(json, 1, 2) == "{\"" and string.find(json, "\"feedbacktype\" : \"0\",\"reportSubjectId\" : \"133\",\"text\"", 1, true) ~= nil);
check("quotes escaped, line breaks and pipes gone", string.find(json, "He said \\\"hi\\\" then  cffff0000red r \\\\o/", 1, true) ~= nil);
check("ends", string.sub(json, -2) == "\"}");
local big = { text = string.rep("x", 200), addons = string.rep("a", 3000), equipment = string.rep("1", 3000), feedbacktype = "0" };
local fit = I.Fit(big, 1000);
check("fit drops addons first", #fit <= 1000 and not string.find(fit, "\"addons\"", 1, true) and string.find(fit, "\"text\"", 1, true) ~= nil);
local huge = I.Fit({ text = string.rep("y", 3000), feedbacktype = "0" }, 500);
check("fit cuts the text last", #huge <= 500 and string.find(huge, "\"feedbacktype\" : \"0\"", 1, true) ~= nil);

check("date", I.DateString({ month = 8, day = 18, year = 2025, hour = 14, min = 35, sec = 32 }) == "08 18 2025 14:35:32");
check("character", I.CharacterString(80, "Human", "Female", "Paladin") == "Lvl 80 Human Female Paladin");
check("creature id", I.CreatureId("0xF130001F4A00217C") == 8010 and I.CreatureId("0xF150007D1E000ABC") == 32030);
check("no creature id for players", I.CreatureId("0x0000000000001234") == nil and I.CreatureId(nil) == nil);
local qid, qname = I.QuestFromLink("|cffffff00|Hquest:12345:80|h[The Lost Ones]|h|r");
check("quest link", qid == 12345 and qname == "The Lost Ones");

-- server answers
local k, a, b = I.ParseServer("STATE~1~0");
check("state", k == "STATE" and a == "1" and b == "0");
k, a = I.ParseServer("ACK~42");
check("ack", k == "ACK" and a == "42");
check("rate text", I.RateText(600) == "You have sent a lot of reports. Please wait 10 min before the next one." and string.find(I.RateText(5), "5 sec") ~= nil);
check("position", I.PosText(10.4, -3.6) == "10:-4" and select(2, I.ParsePos("10:-4")) == -4 and I.ParsePos("x") == nil);

print(failed == 0 and "all ok" or (failed.." failed"));
os.exit(failed == 0 and 0 or 1);
