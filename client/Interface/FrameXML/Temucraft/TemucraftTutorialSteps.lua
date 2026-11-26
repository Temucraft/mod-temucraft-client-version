-- Temucraft new-player tutorial: the steps (texts, icons, pointers, where and for whom). TemucraftTutorial.lua runs them.
-- Edit this file to change a text or add a step, then rebuild the interface patch (client/build_mpq.py). How-to with
-- examples: README.md of mod-temucraft-client-version, "How to add or change a tutorial step".
--
-- Every step:
--   id        a name, unique. The main chain's ids (hands ... turnin, xp, book) are what TemucraftTutorial.lua knows;
--             keep them, change the rest freely.
--   text      what it says. {npc} {mob} {a} {spell} {key} {objective} are filled in; if one isn't known, "fallback"
--             is shown instead.
--   kind      "panel" (the centred keyboard panel), "bar" (the dark bar at the lower centre) or "pointer" (a gold box
--             with an arrow at a frame).
--   icon      on a bar: "look" (mouse, turning), "wasd", "talk" (right-click + speech cursor), "left" (left-click),
--             "right" (right-click), "quest" (the ! icon), or a texture path.
--   pointer   for kind = "pointer": "action" (the action button of the spell), "xp", "tracker", "book", "bags",
--             "map", "micro", or the name of any frame ("PlayerFrame", "MinimapCluster" ...).
--   zones     only in these zones or subzones: names ("Valley of Trials", "Durotar") or map area ids (4 = Durotar,
--             see GetCurrentMapAreaID). Missing = everywhere.
--   races     only for these races ("Orc", "Troll", "Scourge" (Undead), "BloodElf" ...: the English race token).
--   classes   only for these classes ("WARRIOR", "MAGE", "HUNTER" ...).
--   off       true = never shown.
-- A main chain step whose zones / races / classes don't match the character is skipped (as if done).
--
-- Extra steps (any other id) are shown beside the chain, once per character, when their "trigger" happens, and go
-- away when their "done" happens or the player clicks the x:
--   trigger = { start = true }                   as soon as the tutorial runs (and the filters match)
--   trigger = { after = "walk" }                 when the chain reaches that step
--   trigger = { quest = 4641, on = "accepted" }  a quest accepted / "complete" (objectives done) / "turnedin"
--   trigger = { level = 3 }                      at that level
--   trigger = { event = "MERCHANT_SHOW" }        any game event
--   done    = the same kinds, or { seconds = 15 }; missing = only the x closes it
--   quest   = <id>                               shorthand: trigger = accepted, done = turned in, unless given
TemucraftTutorialSteps = {
	-- [[ the main chain, in this order (after "accept": a kill quest goes to "target", any other to "follow") ]]
	{ id = "hands",  kind = "panel",   text = "Position your hands and click Okay" },
	{ id = "look",   kind = "bar",     icon = "look", text = "Look around" },
	{ id = "walk",   kind = "bar",     icon = "wasd", text = "Walk around" },
	{ id = "talk",   kind = "bar",     icon = "talk", text = "Talk to {npc}", fallback = "Talk to the quest giver (!)" },
	{ id = "accept", kind = "bar",     icon = "left", text = "Accept the quest" },
	{ id = "follow", kind = "bar",     icon = "quest", text = "Your quest: {objective}", fallback = "Follow your quest" },
	{ id = "target", kind = "bar",     icon = "left", text = "Target {a} {mob}", fallback = "Target an enemy" },
	{ id = "cast",   kind = "pointer", pointer = "action", text = "Press {key} to cast {spell}",
		moving = "Don't move while casting.", again = "Again!",
		melee = "Right-click the enemy to attack", meleeIcon = "right" },
	{ id = "turnin", kind = "pointer", pointer = "tracker", text = "Quest complete! Return to the questgiver." },
	-- [[ beside the chain ]]
	{ id = "xp",     kind = "pointer", pointer = "xp", text = "You've gained experience! You'll level up when this bar is filled." },
	{ id = "book",   kind = "pointer", pointer = "book", text = "Open your Spellbook and find {spell}",
		fallback = "Open your Spellbook to see your new spell" },

	-- [[ extra steps: examples, remove the -- to use them ]]
	-- { id = "vot_cactus", zones = { "Valley of Trials" }, kind = "bar", icon = "quest",
	--   text = "Cactus Apples grow all over the valley: right-click one to pick it.", trigger = { after = "follow" }, done = { seconds = 20 } },
	-- { id = "hunter_pet", classes = { "HUNTER" }, kind = "pointer", pointer = "PlayerFrame",
	--   text = "At level 10 you can tame a pet.", trigger = { level = 2 }, done = { seconds = 15 } },
};
