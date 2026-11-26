// mod-temucraft-client-version: script loader
void AddTemucraftClientVersionScripts();
void AddTemucraftCollectionsCacheScripts();
void AddTemucraftAdventureGuideCacheScripts();

void Addmod_temucraft_spellbookScripts();
void Addmod_temucraft_client_versionScripts()
{
    AddTemucraftClientVersionScripts();
    AddTemucraftCollectionsCacheScripts();   // Collections previews (addon messages TCC)
    AddTemucraftAdventureGuideCacheScripts();   // Adventure Guide loot items (addon messages TAG)
    Addmod_temucraft_spellbookScripts();   // was mod-temucraft-spellbook
}
