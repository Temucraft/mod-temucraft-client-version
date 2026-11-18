-- mod-temucraft-client-version: the module's texts
DELETE FROM `module_string` WHERE `module` = 'mod-temucraft-client-version';
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-temucraft-client-version', 1, '|cffff6060Your Temucraft client ({}) is out of date; the server needs {}. Close the game and press UPDATE in the launcher.|r'),
('mod-temucraft-client-version', 2, '|cffff6060The Temucraft interface patch is missing. Start the game from the Temucraft launcher (it installs Temucraft {}).|r'),
('mod-temucraft-client-version', 3, '|cffff6060You will be disconnected in 30 seconds.|r'),
('mod-temucraft-client-version', 4, '{}: Temucraft client {} (the server needs {}).'),
('mod-temucraft-client-version', 5, 'no patch');
-- Translations go in `module_string_locale` (`module`, `id`, `locale`, `string`).
