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
- `/echat find <words>` searches the current chat window; `/echat clear` (or `clear all`) clears it; `/echat copy` copies it; `/echat focus` hides the numbered channels (Calm). These work even when another chat addon owns `/find` or `/clear`.
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

## Credits and licence

Based on [Prat-3.0](https://github.com/Legacy-of-Sylvanaar/prat-3-0) by QartemisT, Sylvanaar and the Prat contributors. Licensed GPL-3.0 (see `LICENSE.txt`); credits, changes and bundled libraries are listed in `NOTICE.md`. Not affiliated with Blizzard Entertainment or the Prat project.
