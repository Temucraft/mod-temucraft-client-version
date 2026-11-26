/*
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 */

/*
 * The Collections window's 3D previews (TemucraftCollections.lua). Model:SetCreature(entry) in the 3.3.5 client shows
 * only a creature that is already in its creature cache: it looks the entry up without asking the server
 * (Script_SetCreature -> g_creatureDBCache.GetRecord with no callback), so a mount or pet the player has never seen
 * stays an empty preview however often it is retried. The window whispers addon message "TCC" with a list of creature
 * entries ("32158,7561,..."); for each one the world has, we answer with the ordinary creature query response
 * (SMSG_CREATURE_QUERY_RESPONSE, built by the core's own handler, locale included). The client stores a response it
 * did not ask for like any other (DBCache::AddItems), also in creaturecache.wdb, so SetCreature works from then on.
 * Costs the same as the client querying the creatures itself.
 */
#include "ObjectGuid.h"
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
    constexpr char const* PREFIX = "TCC";
    constexpr std::size_t MAX_PER_MESSAGE = 48;   // an addon message holds about 40 entries anyway

    class temucraft_collections_cache_player : public PlayerScript
    {
    public:
        temucraft_collections_cache_player() : PlayerScript("temucraft_collections_cache_player", { PLAYERHOOK_CAN_PLAYER_USE_PRIVATE_CHAT }) { }

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
                if (!entry || !*entry || !sObjectMgr->GetCreatureTemplate(*entry))
                    continue;
                WorldPacket query(CMSG_CREATURE_QUERY, 4 + 8);
                query << uint32(*entry);
                query << ObjectGuid::Empty;
                session->HandleCreatureQueryOpcode(query);
            }
            return false;
        }
    };
}

void AddTemucraftCollectionsCacheScripts()
{
    new temucraft_collections_cache_player();
}
