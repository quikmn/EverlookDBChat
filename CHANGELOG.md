# EverlookDB Chat

## Unreleased

- New module Idle fade (on by default): after a minute with nothing going on, the whole chat fades out to nothing: text, background, tabs and buttons. It comes back at once when someone talks to you or near you (say, yell, emotes, whispers, party, raid, instance, guild, officer, community channels), when you open the chat box or type, scroll, or move the mouse over the chat. General, Trade and the other numbered channels, loot, money, XP, system, combat and NPC lines don't wake it. Settings: the seconds before it fades (10 to 600) and whether the mouse wakes it.
- Commands first: after a command (or Esc) the chat box stays in whisper mode with the same friend. It used to drop into Say when the whisper was started with R or a name click and nothing had been sent yet.
- The module shows as "Commands first" in the settings (it read "CommandsFirst").
- New module Commands first (on by default): a line that starts with `/` runs as a command in every chat mode, also while you whisper a Battle.net friend. That line is switched to Say for the command only; the friend stays the whisper target and the next line goes to them. If the `/` is erased, the line goes to the friend as usual. A setting writes what it did in chat, for testing.

## v0.1.0 (2026-11-16)

- First version. Forked from Prat-3.0 3.9.117 (commit 3b02cf8595ebd1c4c458d8b698ef5e7d042b046e) by QartemisT and Sylvanaar, GPL-3.0. See Credits and license in the README.
- Renamed to EverlookDB Chat. Settings: `/edbchat`.
- Every name it uses in the game is its own: the addon object, frames, saved settings, slash commands, key bindings and chat link types. It can be installed next to Prat-3.0 without clashing, and it says so in chat when both are turned on.
- Settings are saved in `EverlookDBChatDB`. Settings from Prat-3.0 are not copied over.
- Uses the EverlookDB icon.
- Only loads on WoW Forever.
- Removed the upload and packaging files that pointed at Prat's CurseForge, WoWInterface and Wago pages.
