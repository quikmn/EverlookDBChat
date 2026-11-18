# EverlookDB Chat

Chat improvements for WoW Forever, from the makers of [EverlookDB.com](https://everlookdb.com).

It is made of about 40 small modules. Each one adds one thing to your chat, and you can turn each one on or off.

- **Timestamps** on every line, in the format and colour you like.
- **Player names** coloured by class, with their level, and an alt's main name.
- **Short channel names**, such as `[G]` for guild and `[1]` for General.
- **Copy chat:** copy a whole chat window, or one line, as plain text.
- **URL copy:** links in chat can be clicked and copied.
- **Chat history:** more lines kept, and the lines you typed are remembered between sessions.
- **Edit box:** move it and restyle it.
- **Tabs, buttons, fading, fonts and scrolling** for the chat windows.
- **Sounds** for incoming whispers and channels.
- **Commands first:** a line that starts with `/` is a command in every chat mode, also while you whisper a Battle.net friend.
- **Search** (`/find`), **highlight words**, **filters**, **aliases**, **tell target** (`/tt`) and more.

Settings: type `/echat`, or open the game's Settings under AddOns.

## Commands

`/echat` (also `/edbchat`) follows the same pattern as every EverlookDB addon:

- `/echat` opens the settings window; it's also under Settings > AddOns.
- Every module switches from chat: `/echat timestamps off`, `/echat off timestamps`, `/echat calm on`. `/echat get` lists the modules and whether each is on.
- `/echat find <words>` searches the current chat window; `/echat clear` (or `clear all`) clears it; `/echat copy` copies it; `/echat focus` hides the numbered channels (Calm). These work even when another addon (Prat-3.0) owns `/find` or `/clear`.
- `/echat blacklist <word>` and `/echat unblacklist <word>` stop or start treating a word as a player name (after a reload).
- `/echat aliases` lists your `/alias` commands.
- `/echat move` (or `unlock`, then `lock`) is placement mode: drag and resize the chat and see exactly where the chat box will open. Escape or right-click locks it.
- `/echat reset` puts every setting in this profile back (type it twice within 10 seconds).
- `/echat status`, `/echat version`; `/echat help` (or `?`) lists every command, and a mistyped one suggests the nearest.

The standalone commands stay as they were: `/find <text>`, `/copychat`, `/chatfocus` (or `/chat focus`), `/tt <message>` (whisper your target), `/edbchatblacklist` and `/edbchatunblacklist`, and, while their modules are on, `/clear`, `/cls`, `/clearall`, `/alias`, `/unalias`, `/listaliases` and `/smart`.

## Install

Not released yet.

By hand: copy the `EverlookDBChat` folder into `World of Warcraft\_forever_\Interface\AddOns`.

If Prat-3.0 is also turned on, both change your chat, and the addon says so in chat when you log in. Turn one of them off.

## Credits and license

EverlookDB Chat is a modified version of **Prat-3.0** by QartemisT and Sylvanaar, and the other Prat contributors listed in its repository's history: <https://github.com/Legacy-of-Sylvanaar/prat-3-0>

It was forked from Prat-3.0 version 3.9.117, commit `3b02cf8595ebd1c4c458d8b698ef5e7d042b046e` (2026-11-08). The bundled libraries and translations come unchanged from the official 3.9.117 release package.

It is licensed under the GNU General Public License version 3 (GPL-3.0); the full text is in `LICENSE.txt`. The source files keep their original copyright and license notices. It comes with no warranty.

Changes made to Prat-3.0 (GPL-3.0 section 5a):

- 2026-11-16: Renamed to EverlookDB Chat (folder, title, author, notes, version v0.1.0). The addon object, global names, frame names, saved variables, slash commands, key bindings, chat link types and AceAddon name were renamed, so it can be installed next to Prat-3.0 without clashing. Says so in chat when Prat-3.0 is also turned on. Uses the EverlookDB icon. Removed the Prat logos, the CurseForge/WoWInterface/Wago packaging and upload files, and the project's own contributing and code of conduct files. Only loads on WoW Forever (interface 16001). The libraries are kept in the repository instead of being fetched by the packager. See `CHANGELOG.md` and the git history for every change.
- 2026-11-17: New module Commands first (`modules/CommandsFirst.lua`): in whisper modes, a line whose first character is `/` is switched to Say so the game's own parser runs it as a command; the whisper target is left as it is.

Bundled libraries, each under its own authors' terms: Ace3 (AceAddon, AceConfig, AceConsole, AceDB, AceDBOptions, AceEvent, AceGUI, AceHook, AceTab, AceTimer, CallbackHandler) by the Ace3 team; LibStub (public domain); LibSharedMedia-3.0 (LGPL 2.1); AceGUI-3.0-SharedMediaWidgets; LibSink-2.0; LibDataBroker-1.1; LibDBIcon-1.0; LibAlts-1.0; LibChatAnims. The fonts in `fonts/` are under the licenses in `fonts/font info and licenses`.

Not affiliated with Blizzard Entertainment or with the Prat project.
