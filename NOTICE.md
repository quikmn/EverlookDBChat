# EverlookDB Chat: credits and licence

EverlookDB Chat is a modified version of **Prat-3.0** by QartemisT and Sylvanaar, and the other Prat contributors listed in its repository's history: <https://github.com/Legacy-of-Sylvanaar/prat-3-0>

It was forked from Prat-3.0 version 3.9.117, commit `3b02cf8595ebd1c4c458d8b698ef5e7d042b046e` (2026-11-08). The bundled libraries and translations come unchanged from the official 3.9.117 release package.

It is licensed under the GNU General Public License version 3 (GPL-3.0); the full text is in `LICENSE.txt`. The source files keep their original copyright and license notices. It comes with no warranty.

Changes made to Prat-3.0 (GPL-3.0 section 5a):

- 2026-11-16: Renamed to EverlookDB Chat (folder, title, author, notes, version v0.1.0). The addon object, global names, frame names, saved variables, slash commands, key bindings, chat link types and AceAddon name were renamed, so it can be installed next to Prat-3.0 without clashing. Says so in chat when Prat-3.0 is also turned on. Uses the EverlookDB icon. Removed the Prat logos, the CurseForge/WoWInterface/Wago packaging and upload files, and the project's own contributing and code of conduct files. Only loads on WoW Forever (interface 16001). The libraries are kept in the repository instead of being fetched by the packager. See `CHANGELOG.md` and the git history for every change.
- 2026-11-17: New module Commands first (`modules/CommandsFirst.lua`): in whisper modes, a line whose first character is `/` is switched to Say so the game's own parser runs it as a command; the whisper target is left as it is.

Bundled libraries, each under its own authors' terms: Ace3 (AceAddon, AceConfig, AceConsole, AceDB, AceDBOptions, AceEvent, AceGUI, AceHook, AceTab, AceTimer, CallbackHandler) by the Ace3 team; LibStub (public domain); LibSharedMedia-3.0 (LGPL 2.1); AceGUI-3.0-SharedMediaWidgets; LibSink-2.0; LibDataBroker-1.1; LibDBIcon-1.0; LibAlts-1.0; LibChatAnims. The fonts in `fonts/` are under the licenses in `fonts/font info and licenses`.

Not affiliated with Blizzard Entertainment or with the Prat project.
