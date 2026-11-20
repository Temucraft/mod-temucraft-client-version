/*
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 */

/*
 * mod-temucraft-client-version: the server knows which Temucraft client each player runs.
 *
 * The client interface patch (client/build_mpq.py -> Data/<locale>/patch-<locale>-T.MPQ) carries the client version
 * and, after login, whispers it to the server as an addon message ("TCV", "HELLO~1.0.0"). The server compares it with
 * Temucraft.ClientVersion.Required: an older client is told to update (a popup in game); with Action = 1 it is
 * disconnected after the grace time. A client that never says hello (no patch) gets the same treatment when
 * Temucraft.ClientVersion.RequirePatch is on. GMs are never kicked. `.clientversion` shows yours / a target's.
 */
#include "Chat.h"
#include "ChatCommand.h"
#include "CommandScript.h"
#include "Config.h"
#include "GameTime.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "PlayerScript.h"
#include "ScriptMgr.h"
#include "TemucraftAddonMessage.h"
#include "TemucraftModuleText.h"
#include "WorldScript.h"
#include "WorldSession.h"
#include <unordered_map>

using namespace Acore::ChatCommands;

namespace
{
    constexpr char const* MODULE = "mod-temucraft-client-version";
    constexpr char const* PREFIX = "TCV";
    enum Str : uint32 { S_OUTDATED = 1, S_NO_PATCH, S_KICK, S_YOURS, S_UNKNOWN };

    struct Settings
    {
        bool enable = true, requirePatch = false;
        std::string required = "1.3.0";
        uint32 action = 0, grace = 60;
    } cfg;

    struct Session { uint32 loginAt = 0; std::string version; bool told = false; uint32 kickAt = 0; };
    std::unordered_map<ObjectGuid::LowType, Session> sessions;

    template<typename T>
    char const* Text(T who, uint32 id, char const* fallback) { return TemucraftModuleText(MODULE, who, id, fallback); }
    uint32 Now() { return uint32(GameTime::GetGameTime().count()); }

    // true when a < b, comparing dotted numbers ("1.0.10" > "1.0.9")
    bool Below(std::string const& a, std::string const& b)
    {
        auto parts = [](std::string const& s)
        {
            std::vector<uint32> out; uint32 n = 0; bool in = false;
            for (char c : s)
            {
                if (c >= '0' && c <= '9') { n = n * 10 + uint32(c - '0'); in = true; }
                else if (in) { out.push_back(n); n = 0; in = false; }
            }
            if (in) out.push_back(n);
            return out;
        };
        std::vector<uint32> x = parts(a), y = parts(b);
        for (size_t i = 0; i < std::max(x.size(), y.size()); ++i)
        {
            uint32 p = i < x.size() ? x[i] : 0, q = i < y.size() ? y[i] : 0;
            if (p != q) return p < q;
        }
        return false;
    }

    void Judge(Player* player, Session& s)
    {
        if (s.told) return;
        bool outdated = !s.version.empty() && Below(s.version, cfg.required);
        bool missing = s.version.empty() && cfg.requirePatch;
        if (!outdated && !missing) return;
        s.told = true;
        ChatHandler h(player->GetSession());
        if (outdated)
        {
            h.PSendSysMessage(Text(player, S_OUTDATED, "|cffff6060Your Temucraft client ({}) is out of date; the server needs {}. Close the game and press UPDATE in the launcher.|r"),
                s.version, cfg.required);
            TemucraftAddonSend(player, PREFIX, "OLD~" + cfg.required);
        }
        else
            h.PSendSysMessage(Text(player, S_NO_PATCH, "|cffff6060The Temucraft interface patch is missing. Start the game from the Temucraft launcher (it installs Temucraft {}).|r"), cfg.required);
        if (cfg.action == 1 && !player->GetSession()->IsGMAccount())
        {
            s.kickAt = Now() + 30;
            h.SendSysMessage(Text(player, S_KICK, "|cffff6060You will be disconnected in 30 seconds.|r"));
        }
    }

    class temucraft_client_version_player : public PlayerScript
    {
    public:
        temucraft_client_version_player() : PlayerScript("temucraft_client_version_player",
            { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LOGOUT, PLAYERHOOK_CAN_PLAYER_USE_PRIVATE_CHAT }) { }

        void OnPlayerLogin(Player* player) override
        {
            if (!cfg.enable) return;
            Session& s = sessions[player->GetGUID().GetCounter()];
            s = Session();
            s.loginAt = Now();
        }
        void OnPlayerLogout(Player* player) override { sessions.erase(player->GetGUID().GetCounter()); }

        using PlayerScript::OnPlayerCanUseChat;
        bool OnPlayerCanUseChat(Player* player, uint32 type, uint32 language, std::string& msg, Player* receiver) override
        {
            std::string body;
            if (!TemucraftAddonParse(player, type, language, msg, receiver, PREFIX, body)) return true;
            std::vector<std::string> a = TemucraftAddonFields(body);
            if (cfg.enable && a.size() >= 2 && a[0] == "HELLO")
            {
                Session& s = sessions[player->GetGUID().GetCounter()];
                s.version = a[1].substr(0, 32);
                Judge(player, s);
            }
            return false;
        }
    };

    class temucraft_client_version_world : public WorldScript
    {
    public:
        temucraft_client_version_world() : WorldScript("temucraft_client_version_world", { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_UPDATE }) { }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            cfg.enable = sConfigMgr->GetOption<bool>("Temucraft.ClientVersion.Enable", true);
            cfg.required = sConfigMgr->GetOption<std::string>("Temucraft.ClientVersion.Required", "1.3.0");
            cfg.requirePatch = sConfigMgr->GetOption<bool>("Temucraft.ClientVersion.RequirePatch", true);
            cfg.action = sConfigMgr->GetOption<uint32>("Temucraft.ClientVersion.Action", 1);
            cfg.grace = sConfigMgr->GetOption<uint32>("Temucraft.ClientVersion.GraceSeconds", 60);
        }

        void OnUpdate(uint32 diff) override
        {
            if (!cfg.enable || (timer += diff) < 1000) return;
            timer = 0;
            uint32 now = Now();
            for (auto& [guid, s] : sessions)
            {
                Player* p = ObjectAccessor::FindPlayerByLowGUID(guid);
                if (!p || !p->IsInWorld()) continue;
                if (s.version.empty() && !s.told && now - s.loginAt >= cfg.grace) Judge(p, s);
                if (s.kickAt && now >= s.kickAt) { s.kickAt = 0; p->GetSession()->KickPlayer("mod-temucraft-client-version: outdated client"); }
            }
        }
    private:
        uint32 timer = 0;
    };

    class temucraft_client_version_commands : public CommandScript
    {
    public:
        temucraft_client_version_commands() : CommandScript("temucraft_client_version_commands") { }
        ChatCommandTable GetCommands() const override
        {
            static ChatCommandTable root = { { "clientversion", Handle, SEC_PLAYER, Console::No } };
            return root;
        }
        static bool Handle(ChatHandler* handler)
        {
            Player* p = handler->getSelectedPlayerOrSelf();
            if (!p) return true;
            auto it = sessions.find(p->GetGUID().GetCounter());
            std::string version = it != sessions.end() && !it->second.version.empty() ? it->second.version : std::string(Text(handler, S_UNKNOWN, "no patch"));
            handler->PSendSysMessage(Text(handler, S_YOURS, "{}: Temucraft client {} (the server needs {})."), p->GetName(), version, cfg.required);
            return true;
        }
    };
}

void AddTemucraftClientVersionScripts()
{
    new temucraft_client_version_player();
    new temucraft_client_version_world();
    new temucraft_client_version_commands();
}
