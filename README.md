# mod-temucraft-client-version

Gives the Temucraft client a version of its own, shown on the login screen and checked by the server, and builds the
Temucraft interface into the client so module windows behave like Blizzard's own UI.

## The client patch (`client/`)

`python3 client/build_mpq.py` makes `Data/<locale>/patch-<locale>-T.MPQ` (needs StormLib; `--stormlib` points at
`libstorm.so` or `StormLib.dll`). It holds:

- [`Interface\GlueXML\TemucraftVersion.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/GlueXML/TemucraftVersion.lua): the login screen shows "Temucraft 1.3.0 (3.3.5a build 12340)".
- [`Interface\FrameXML\Temucraft\TemucraftCore.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftCore.lua): after login the client whispers its version to the server
  (addon message `TCV`, `HELLO~1.0.0`) and shows a popup when the server says it is out of date.
- [`Interface\FrameXML\Temucraft\TemucraftDisguise.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftDisguise.lua): the rogue Disguise button and menu ([mod-temucraft-rogue-disguise](https://github.com/Temucraft/mod-temucraft-rogue-disguise)).
- [`Interface\FrameXML\Temucraft\TemucraftAutoLearn.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftAutoLearn.lua): the spellbook's Train button and automatic-learning checkbox ([mod-temucraft-auto-learn](https://github.com/Temucraft/mod-temucraft-auto-learn)).
- [`Interface\FrameXML\Temucraft\TemucraftHeritage.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftHeritage.lua): the Heritage button beside the character window, with the second racial menu ([mod-temucraft-racials](https://github.com/Temucraft/mod-temucraft-racials)).
- [`Interface\FrameXML\Temucraft\TemucraftSpellTabs.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftSpellTabs.lua): Racials, Professions, Mounts, Companions and Guild tabs beside the spellbook, and a line in spellbook tooltips saying what a spell is ([mod-temucraft-spellbook](https://github.com/Temucraft/mod-temucraft-spellbook)).
- [`Interface\FrameXML\Temucraft\TemucraftMissions.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftMissions.lua): the mission table and companion window
  ([mod-temucraft-followers](https://github.com/Temucraft/mod-temucraft-followers)), loaded by FrameXML, so it can't be turned off or go
  missing like an addon. The AddOns copy shipped with mod-temucraft-followers steps aside when this one is loaded.
- [`Interface\FrameXML\Temucraft\TemucraftExpeditions.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftExpeditions.lua): the expedition window (current run, powers, relics, Wayfinder's Ledger; addon messages `TEX`)
  ([mod-temucraft-expeditions](https://github.com/Temucraft/mod-temucraft-expeditions)). The file is the same as the AddOns copy in mod-temucraft-expeditions, which steps aside when this one is loaded.
- `FrameXML.toc` and `GlueXML.toc`: the client's own lists (copies in `client/base/`) with those files added. They
  come from the highest-priority patches of the client (FrameXML.toc from patch-enUS-3.MPQ, GlueXML.toc from
  patch-enUS-C.MPQ); refresh `client/base/` if another patch changes them.

The version is `client/VERSION`. To release a new client: raise `VERSION`, rebuild the MPQ, put it in the launcher's
`locales/<locale>/` folder, write the same version in the launcher's `client-version.txt` and in
`Temucraft.ClientVersion.Required`.

## The server side

| Setting | Default | What |
|---|---|---|
| `Temucraft.ClientVersion.Enable` | 1 | check versions |
| `Temucraft.ClientVersion.Required` | 1.3.0 | oldest client allowed |
| `Temucraft.ClientVersion.RequirePatch` | 1 | also act on clients that never send a version (`GraceSeconds` after login) |
| `Temucraft.ClientVersion.Action` | 1 | 0 tell them to update, 1 also disconnect after 30 seconds (never GMs) |

`.clientversion` shows your (or your target's) client version.

## Install

Put this folder in `modules/`, copy the conf, re-run CMake and build. The SQL adds the module's texts
(`module_string`, module `mod-temucraft-client-version`; translations in `module_string_locale`).

Part of the Temucraft modules for AzerothCore 3.3.5a.

## Token preview
[`TemucraftTokenPreview.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftTokenPreview.lua): a tier token's tooltip says how many items it buys for your class; alt-click it (or
`/tokenpreview <link>`) for a window with every item, its icon and tooltip, for your class or every class, next to
your character: click an item to try it on, "Try on set" dresses you in the whole tier set. Run
`client/tokens/token_preview.sql` and `set_pieces.sql` on the world database into `tokens.tsv` / `sets.tsv`, then
`build_token_preview.py`. The table comes from the world database: run `client/tokens/token_preview.sql` on it into
`client/tokens/tokens.tsv`, then `python3 client/tokens/build_token_preview.py` and rebuild the patch.

## Wardrobe
[`TemucraftCostumes.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftCostumes.lua): the window of [mod-temucraft-costumes](https://github.com/Temucraft/mod-temucraft-costumes) (`.costume` or `/wardrobe`). Its catalog comes from
`client/costumes/costume_catalog.sql` -> `costumes.tsv` -> `build_costume_window.py` (UI code in [`costume_window.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/costumes/costume_window.lua)).

## Vanity
[`TemucraftVanity.lua`](https://github.com/Temucraft/mod-temucraft-client-version/blob/master/client/Interface/FrameXML/Temucraft/TemucraftVanity.lua): the Vanity window of [mod-temucraft-account-wide](https://github.com/Temucraft/mod-temucraft-account-wide)
(`/vanity`, `.collection vanity`, or the Vanity button of the Wardrobe). It lists the vanity items your account has
unlocked (the Stones and Scrolls of Homecoming of [mod-temucraft-travel](https://github.com/Temucraft/mod-temucraft-travel) and any others in
`mod_temucraft_vanity_item`), each with its icon, name and cooldown, and a Summon button that puts it back in your bags
if this character doesn't have it. "Show locked" also lists the ones still to get. Addon prefix `TVA`.

