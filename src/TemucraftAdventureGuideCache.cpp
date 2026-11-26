/*
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 */

/*
 * The Adventure Guide's loot lists (TemucraftAdventureGuide.lua). The 3.3.5 client knows an item's name, quality,
 * icon and tooltip only once the item is in its item cache; a boss's loot is mostly items the player has never seen,
 * so their tooltips would stay "Retrieving item information" and shift-click could not link them. The guide whispers
 * addon message "TAG" with a list of item entries ("40384,40385,..."); for each one the world has we answer with the
 * ordinary item query response (SMSG_ITEM_QUERY_SINGLE_RESPONSE, built by the core's own handler, locale included).
 * The client stores a response it did not ask for like any other (also in itemcache.wdb). Each id is asked once per
 * session; it costs the same as the client querying the items itself. Boss models use the Collections window's TCC.
 */
#include "ObjectMgr.h"
#include "Opcodes.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringConvert.h"
#include "TemucraftAddonMessage.h"
#include "WorldPacket.h"
#include "WorldSession.h"

namespace
{
    constexpr char const* PREFIX = "TAG";
    constexpr std::size_t MAX_PER_MESSAGE = 48;   // an addon message holds about 40 ids anyway

    class temucraft_adventure_guide_cache_player : public PlayerScript
    {
    public:
        temucraft_adventure_guide_cache_player() : PlayerScript("temucraft_adventure_guide_cache_player", { PLAYERHOOK_CAN_PLAYER_USE_PRIVATE_CHAT }) { }

        using PlayerScript::OnPlayerCanUseChat;
        bool OnPlayerCanUseChat(Player* player, uint32 type, uint32 language, std::string& msg, Player* receiver) override
        {
            std::string body;
            if (!TemucraftAddonParse(player, type, language, msg, receiver, PREFIX, body))
                return true;
            WorldSession* session = player->GetSession();
            if (!session)
                return false;
            std::size_t n = 0;
            for (std::string_view part : Acore::Tokenize(body, ',', false))
            {
                if (++n > MAX_PER_MESSAGE)
                    break;
                Optional<uint32> entry = Acore::StringTo<uint32>(part);
                if (!entry || !*entry || !sObjectMgr->GetItemTemplate(*entry))
                    continue;
                WorldPacket query(CMSG_ITEM_QUERY_SINGLE, 4);
                query << uint32(*entry);
                session->HandleItemQuerySingleOpcode(query);
            }
            return false;
        }
    };
}

void AddTemucraftAdventureGuideCacheScripts()
{
    new temucraft_adventure_guide_cache_player();
}
