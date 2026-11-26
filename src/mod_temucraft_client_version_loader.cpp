// mod-temucraft-client-version: script loader
void AddTemucraftClientVersionScripts();
void AddTemucraftCollectionsCacheScripts();

void Addmod_temucraft_spellbookScripts();
void Addmod_temucraft_client_versionScripts()
{
    AddTemucraftClientVersionScripts();
    AddTemucraftCollectionsCacheScripts();   // Collections previews (addon messages TCC)
    Addmod_temucraft_spellbookScripts();   // was mod-temucraft-spellbook
}
