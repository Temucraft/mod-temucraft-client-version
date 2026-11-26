-- Stub tests for the new-player tutorial's step machine (no client): lua5.1 client/tests/tutorial_test.lua (from the module folder)
local dir = string.match(arg and arg[0] or "", "^(.*)[/\\]tests[/\\]") or "client";
dofile(dir.."/Interface/FrameXML/Temucraft/TemucraftTutorial.lua");
local L = TemucraftTutorialLogic;
local failed = 0;
local function check(name, ok) if ( not ok ) then failed = failed + 1; print("FAIL "..name); else print("ok   "..name); end end
local function main(m) return L.View(m).main; end
local function side(m) return L.View(m).side; end

-- starting
check("new character starts", L.Start({ enabled = true, level = 1, played = 30 }) == "start");
check("tutorials off", L.Start({ enabled = false, level = 1, played = 30 }) == nil);
check("account finished it: ask", L.Start({ enabled = true, level = 1, played = 30, accountSeen = true }) == "ask");
check("played too long", L.Start({ enabled = true, level = 1, played = 20 * 60 }) == nil);
check("no played time: experience decides", L.Start({ enabled = true, level = 1, xp = 0 }) == "start"
	and L.Start({ enabled = true, level = 1, xp = 40 }) == nil);
check("level 2 doesn't start", L.Start({ enabled = true, level = 2, played = 30 }) == nil);
check("resume a saved step", L.Start({ enabled = true, level = 3, progress = "target" }) == "resume");
check("done stays done", L.Start({ enabled = true, level = 1, played = 1, progress = "done" }) == nil);

-- helpers
check("kill objective mob", L.KillTarget({ { text = "Kobold Vermin slain: 0/6", type = "monster" } }) == "Kobold Vermin");
check("no kill objective", L.KillTarget({ { text = "Wolf Meat: 0/4", type = "item" } }) == nil and L.KillTarget({}) == nil);
check("spell on the bar skips Attack", select(2, L.PickSpell({ [1] = { kind = "spell", name = "Attack" },
	[2] = { kind = "spell", name = "Heroic Strike" } })) == "Heroic Strike");
check("slot 1 spell", L.PickSpell({ [1] = { kind = "spell", name = "Fireball" } }) == 1);
check("no spell", L.PickSpell({ [1] = { kind = "macro" } }) == nil);
local pats = { "You have learned a new spell: %s.", "You have learned a new ability: %s." };
check("learned spell from a link", L.LearnedName("You have learned a new spell: |cff71d5ff|Hspell:116|h[Frostbolt]|h|r.", pats) == "Frostbolt");
check("learned ability, plain", L.LearnedName("You have learned a new ability: Battle Shout.", pats) == "Battle Shout");
check("other line", L.LearnedName("You are now Away.", pats) == nil);
check("pointer side", L.Side(500, 40, 1024, 768) == "above" and L.Side(900, 500, 1024, 768) == "left" and L.Side(100, 500, 1024, 768) == "right");

-- a kill quest, all the way
local m = L.New(nil);
check("hands panel first", main(m).kind == "panel");
L.Handle(m, "LOOK");
check("look before Okay is ignored", m.step == "hands");
L.Handle(m, "OKAY");
check("look around", main(m).text == "Look around" and main(m).icon == "look");
L.Handle(m, "MOVE");
check("walking doesn't finish looking", m.step == "look");
L.Handle(m, "LOOK");
check("walk around", main(m).text == "Walk around" and main(m).icon == "wasd");
L.Handle(m, "MOVE");
check("talk to the quest giver", main(m).text == "Talk to the quest giver (!)");
L.Handle(m, "TALK", "Marshal McBride");
check("accept", main(m).text == "Accept the quest");
L.Handle(m, "TALK_CLOSED");
check("closed without accepting: talk again", m.step == "talk" and main(m).text == "Talk to the quest giver (!)");
L.Handle(m, "TALK", "Marshal McBride");
L.Handle(m, "ACCEPT", { title = "Kobold Camp Cleanup", kill = "Kobold Vermin" });
check("target the quest mob", main(m).text == "Target a Kobold Vermin" and m.npc == "Marshal McBride");
L.Handle(m, "TARGET", { hostile = false });
check("a friendly target doesn't count", m.step == "target");
L.Handle(m, "XP");
check("xp pointer", side(m) and side(m).anchor == "xp" and string.find(side(m).text, "level up"));
L.Handle(m, "XP_TIMEOUT");
check("xp pointer goes", side(m) == nil);
L.Handle(m, "TARGET", { hostile = true, spell = { slot = 1, name = "Fireball", key = "1" } });
check("press 1", main(m).kind == "pointer" and main(m).anchor == "action" and main(m).text == "Press 1 to cast Fireball");
L.Handle(m, "CAST_MOVED");
check("don't move", main(m).text == "Don't move while casting.");
L.Handle(m, "CAST_DONE");
check("again", main(m).text == "Again!");
L.Handle(m, "TARGET", { hostile = false });
check("target lost: target again", m.step == "target");
L.Handle(m, "TARGET", { hostile = true, spell = { slot = 1, name = "Fireball", key = "1" } });
L.Handle(m, "KILL");
check("waiting for the quest: nothing shown", m.step == "turnin" and main(m) == nil);
L.Handle(m, "READY");
check("return to the questgiver", main(m).anchor == "tracker" and main(m).text == "Quest complete! Return to the questgiver.");
check("saved step", L.Progress(m) == "turnin;x");
L.Handle(m, "TURNIN", "Marshal McBride");
check("chain over, spellbook still to come", m.mainDone and not m.done and main(m) == nil and L.Progress(m) == "end;x");
L.Handle(m, "LEARN", "Frost Armor");
check("spellbook pointer", side(m).anchor == "book" and side(m).glow and side(m).text == "Open your Spellbook and find Frost Armor");
L.Handle(m, "BOOK_OPEN");
check("done when the book opens", m.done and L.Progress(m) == "done");

-- the quest is done before the kill step ends; melee without a spell
m = L.New("target");
L.Handle(m, "READY");
L.Handle(m, "TARGET", { hostile = true });
check("no spell: right-click", main(m).kind == "bar" and main(m).text == "Right-click the enemy to attack");
L.Handle(m, "KILL");
check("ready already: pointer at once", main(m) and main(m).anchor == "tracker");

-- a talk / deliver quest first
m = L.New("talk");
L.Handle(m, "ACCEPT", { title = "A Threat Within", objective = "Speak with Marshal McBride." });
check("quest accepted from the talk step (no window event)", m.step == "follow" and main(m).text == "Your quest: Speak with Marshal McBride.");
L.Handle(m, "QUEST_INFO", { title = "A Threat Within", objective = "Speak with Marshal McBride." });
check("same quest info: no change", m.step == "follow");
L.Handle(m, "TURNIN", "Marshal McBride");
check("next quest giver by name", m.step == "talk" and main(m).text == "Talk to Marshal McBride");
L.Handle(m, "TALK", "Marshal McBride");
L.Handle(m, "ACCEPT", { title = "Wolves", objective = "Kill wolves." });
L.Handle(m, "QUEST_INFO", { title = "Wolves", kill = "Young Wolf" });
check("kill objective that came later", m.step == "target" and main(m).text == "Target a Young Wolf");
check("an before a vowel", (function() local x = L.New("target"); x.mob = "Infected Boar"; return main(x).text == "Target an Infected Boar"; end)());

-- x and skip
m = L.New(nil);
L.Handle(m, "CLOSE", "main");
check("x skips the panel", m.step == "look");
L.Handle(m, "CLOSE", "main"); L.Handle(m, "CLOSE", "main");
check("x skips steps", m.step == "talk");
L.Handle(m, "LEARN", nil);
check("spellbook without a name", side(m).text == "Open your Spellbook to see your new spell");
L.Handle(m, "CLOSE", "side");
check("x on the spellbook pointer", side(m) == nil and m.bookDone);
L.Handle(m, "SKIP");
check("skip tutorial", m.done and L.Progress(m) == "done" and next(L.View(m)) == nil);

-- the spellbook prompt waits for the xp pointer; resume
m = L.New("look");
L.Handle(m, "XP"); L.Handle(m, "LEARN", "Renew");
check("book waits behind xp", side(m).anchor == "xp");
L.Handle(m, "XP_TIMEOUT");
check("then the book", side(m).anchor == "book");
check("resume: window steps go back", L.New("accept").step == "talk" and L.New("cast").step == "target" and L.New("turnin;x").step == "talk"
	and L.New("turnin;x").xpShown and L.New("end;b").mainDone and L.New("bogus").step == "look");
m = L.New("end");
L.Handle(m, "LEVEL", 6);
check("gives up the spellbook at level 6", m.done);

if ( failed > 0 ) then print(failed.." failed"); os.exit(1); end
print("all passed");
