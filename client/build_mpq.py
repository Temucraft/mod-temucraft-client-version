#!/usr/bin/env python3
"""
Builds the Temucraft interface patch: Data/patch-^.MPQ (the same for every language).

It is a Data patch on purpose: the client ranks every Data\patch-?.MPQ above every Data\<locale>\patch-<locale>-?.MPQ
(see claude/temucraft-client-patch-order-and-hd.md), and patch-5 has its own FrameXML.toc. As a locale patch (the old
patch-<locale>-T) our FrameXML.toc lost to it, TemucraftCore.lua never ran, the server never got the version and
kicked everyone. "^" ranks above every other Data patch that has interface files.

It carries
  - Interface\\GlueXML\\TemucraftVersion.lua: "Temucraft <version>" on the login screen,
  - Interface\\GlueXML\\TemucraftCharCreate.lua / TemucraftCharSelect.lua: the retail-style character create and select
    screens, on top of the client's own (TemucraftGlueData.lua: their data, made by gen_glue_data.py),
  - Interface\\TemucraftCharSummary.lua: an empty TEMUCRAFT_CHAR_SUMMARY (the launcher writes the real one, loose),
  - Interface\\TemucraftScenes.lua: the character screen scenes ("old" here; the launcher writes a loose Interface\\TemucraftScenes.lua
    with the player's choice: "new" for Character models HD, plus the scenes they picked per race),
  - Interface\\FrameXML\\Temucraft\\TemucraftIssueBug.blp: the Issue Reporter's bug icon (Blizzard's FeedbackUI icon),
  - Interface\\FrameXML\\Temucraft\\*.lua: the core (sends the version to the server, shows "out of date") and the
    module windows (mission table / companions, wardrobe, vanity, the spellbook / talents window, collections), loaded by
    FrameXML itself, so they always run like Blizzard's UI,
  - FrameXML.toc / GlueXML.toc: copies of the client's own lists (base/) with those files added.

The version comes from VERSION. Put the MPQ in the launcher's patches/ folder, and the same version in
client-version.txt and in mod-temucraft-client-version.conf (Temucraft.ClientVersion.Required).

    python3 build_mpq.py [--out folder] [--stormlib path/to/libstorm.so|StormLib.dll]

base/*.toc must be the highest-priority copies of the client you ship (here: FrameXML.toc from patch-5.MPQ,
GlueXML.toc from patch-enUS-C.MPQ). If another patch changes them later, refresh base/.
"""
import argparse, ctypes, os, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
FRAME_FILES = ["Temucraft\\TemucraftCore.lua",
               # the shared window look (TemucraftStyle_Window / _Inset / _Header ...), before every window that uses it
               "Temucraft\\TemucraftStyle.lua", "Temucraft\\TemucraftMissions.lua", "Temucraft\\TemucraftDisguise.lua",
               "Temucraft\\TemucraftAutoLearn.lua", "Temucraft\\TemucraftHeritage.lua",
               "Temucraft\\TemucraftSpellTabs.lua", "Temucraft\\TemucraftTankRoles.lua",
               "Temucraft\\TemucraftTokenPreview.lua", "Temucraft\\TemucraftCostumes.lua",
               "Temucraft\\TemucraftVanity.lua",
               "Temucraft\\TemucraftExpeditions.lua", "Temucraft\\TemucraftSpellInfo.lua",
               # after TemucraftSpellTabs.lua (the spell flags) and TemucraftAutoLearn.lua (the Train button)
               "Temucraft\\TemucraftStore.lua",
               # what DragonUI has taken over (before everything that asks: TemucraftPlayerSpells.lua, TemucraftInterface.lua)
               "Temucraft\\TemucraftDragonUI.lua", "Temucraft\\TemucraftPlayerSpells.lua",
               "Temucraft\\TemucraftFlyouts.lua", "Temucraft\\TemucraftSpellBook.lua", "Temucraft\\TemucraftTalentsData.lua",
               "Temucraft\\TemucraftTalents.lua", "Temucraft\\TemucraftCollectionsData.lua",
               "Temucraft\\TemucraftCollections.lua",
               # the Adventure Guide (after the style, DragonUI and collections files it uses; before the micro menu)
               "Temucraft\\TemucraftAdventureGuideData.lua", "Temucraft\\TemucraftAdventureGuide.lua",
               # the player UI overhaul (after the spellbook and collections they open)
               "Temucraft\\TemucraftInterface.lua", "Temucraft\\TemucraftGossip.lua", "Temucraft\\TemucraftTooltips.lua",
               "Temucraft\\TemucraftCharacter.lua", "Temucraft\\TemucraftMicroMenu.lua",
               "Temucraft\\TemucraftAddOns.lua", "Temucraft\\TemucraftChangelog.lua",
               # the Options window (after TemucraftInterface.lua, its "Classic options menu"; before the game menu)
               "Temucraft\\TemucraftOptions.lua", "Temucraft\\TemucraftGameMenu.lua", "Temucraft\\TemucraftTaxi.lua",
               # after TemucraftInterface.lua, TemucraftStore.lua and TemucraftMicroMenu.lua (the guild button)
               "Temucraft\\TemucraftGuild.lua", "Temucraft\\TemucraftGuildBank.lua",
               # after TemucraftCharacter.lua (its tabs and ToggleCharacter) and TemucraftInterface.lua
               "Temucraft\\TemucraftReputationData.lua", "Temucraft\\TemucraftReputation.lua",
               "Temucraft\\TemucraftCurrency.lua", "Temucraft\\TemucraftRenown.lua",
               # the Professions window (after TemucraftInterface.lua, its "Classic professions window", and TemucraftDragonUI.lua)
               "Temucraft\\TemucraftProfessions.lua",
               # the Achievements window (after TemucraftInterface.lua, its "Classic achievements window")
               "Temucraft\\TemucraftAchievements.lua",
               # after TemucraftCore.lua (the version), TemucraftStore.lua and TemucraftTooltips.lua (its lines come first)
               "Temucraft\\TemucraftIssues.lua",
               # the new-player tutorial (after TemucraftStore.lua; the Options window's Tutorials row calls it)
               "Temucraft\\TemucraftTutorial.lua"]
# pictures (not in FrameXML.toc): Interface\\FrameXML\\<file>
ART_FILES = ["Temucraft\\TemucraftIssueBug.blp"]
# pictures for the login screens: Interface\\Glues\\<file>
GLUE_ART_FILES = []   # (the race ring now uses the stock MiniMap-TrackingBorder)
# after the client's own glue files (CharacterCreate / CharacterSelect), so they can sit on top of them
GLUE_FILES = ["TemucraftGlueSafety.lua", "TemucraftVersion.lua", "TemucraftGlueData.lua", "TemucraftCharCreate.lua", "TemucraftCharSelect.lua"]
# Interface\\<file> (listed as ..\\<file> in GlueXML.toc, like LoginUI.lua): the launcher writes its own loose copy
# (TemucraftCharSummary.lua: spec, professions, gold and unread mail for the character select tooltips)
ROOT_GLUE_FILES = ["TemucraftScenes.lua", "TemucraftCharSummary.lua"]


def insert_before(text, marker, lines):
    rows = text.replace("\r\n", "\n").split("\n")
    rows = [r for r in rows if r.strip() not in lines]
    at = next((i for i, r in enumerate(rows) if r.strip().lower().startswith(marker)), len(rows))
    return "\r\n".join(rows[:at] + lines + rows[at:])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(HERE, "out"))
    ap.add_argument("--stormlib", default=os.environ.get("STORMLIB", os.path.expanduser("~/StormLib/b/libstorm.so")))
    a = ap.parse_args()
    version = open(os.path.join(HERE, "VERSION")).read().strip()

    files = {}
    def add(name, data): files[name] = data if isinstance(data, bytes) else data.encode("utf-8")
    add("Interface\\FrameXML\\FrameXML.toc",
        insert_before(open(os.path.join(HERE, "base", "FrameXML.toc"), encoding="latin-1").read(), "## add new modules above", FRAME_FILES))
    add("Interface\\GlueXML\\GlueXML.toc",
        insert_before(open(os.path.join(HERE, "base", "GlueXML.toc"), encoding="latin-1").read(), "## this always runs last",
                      GLUE_FILES + ["..\\" + f for f in ROOT_GLUE_FILES]))
    for f in FRAME_FILES:
        add("Interface\\FrameXML\\" + f, open(os.path.join(HERE, "Interface", "FrameXML", *f.split("\\"))).read().replace("@VERSION@", version))
    for f in ART_FILES:
        add("Interface\\FrameXML\\" + f, open(os.path.join(HERE, "Interface", "FrameXML", *f.split("\\")), "rb").read())
    for f in GLUE_ART_FILES:
        add("Interface\\Glues\\" + f, open(os.path.join(HERE, "Interface", "Glues", *f.split("\\")), "rb").read())
    for f in GLUE_FILES:
        add("Interface\\GlueXML\\" + f, open(os.path.join(HERE, "Interface", "GlueXML", f)).read().replace("@VERSION@", version))
    for f in ROOT_GLUE_FILES:
        add("Interface\\" + f, open(os.path.join(HERE, "Interface", f)).read())

    L = ctypes.CDLL(a.stormlib); v = ctypes.c_void_p
    L.SFileCreateArchive.argtypes = [ctypes.c_char_p, ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(v)]
    L.SFileAddFileEx.argtypes = [v, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint]
    L.SFileCloseArchive.argtypes = [v]
    os.makedirs(a.out, exist_ok=True)
    mpq = os.path.join(a.out, "patch-^.MPQ")
    if os.path.exists(mpq): os.remove(mpq)
    h = v()
    # MPQ v1 with a listfile and attributes, like the client's own patches
    if not L.SFileCreateArchive(mpq.encode(), 0x00100000 | 0x00200000, 64, ctypes.byref(h)):
        sys.exit("could not create " + mpq)
    with tempfile.TemporaryDirectory() as tmp:
        for name, data in files.items():
            p = os.path.join(tmp, name.replace("\\", "_"))
            open(p, "wb").write(data)
            if not L.SFileAddFileEx(h, p.encode(), name.encode(), 0x80000200, 0x02, 0x02):
                sys.exit("could not add " + name)
    L.SFileCloseArchive(h)
    print(f"{mpq}: {len(files)} files, Temucraft {version}")


if __name__ == "__main__":
    main()
