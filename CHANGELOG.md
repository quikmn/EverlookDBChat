# EverlookDB Chat

## Unreleased

- Calm, Your name always shows: a channel line with your character's name in it shows even in focus and is never held back by paced channel chat.
- Calm, Whispers are never missed: an incoming whisper (character or Battle.net) keeps the chat visible with every line, not faded or cut down, until you've seen it (mouse over the chat or the chat box opened). A small "1 whisper" note above the chat shows meanwhile; click it to reply. An extra whisper sound can be turned on (off by default).
- Calm, Focus: in combat, General, Trade and the other numbered channels are hidden completely; whispers, party, raid, guild, say and the other conversations still show. When focus ends nothing is replayed. Optional: focus in dungeons and raids (off by default). Turn it on and off by hand with /chat focus (or /chatfocus) or a new key binding.
- Calm, Gentle line fade: chat lines now fade out 30 seconds after they come in (it was 2 minutes), with a slower, softer fade of 5 seconds. Both are set in Fading, which has a new setting for the length of the fade; the Calm settings link to it.
- Calm, Paced channel chat: lines from General, Trade, LookingForGroup and the other numbered channels come out at most one every 2 seconds instead of all at once, so each can be read. The same line repeated in a channel within a minute shows once, and when more than 10 are waiting the oldest are skipped. Whispers, party, guild, say and other conversations are never held back. Lines the game hides from addons go through as usual.
- New module Calm (on by default), Fewer lines on screen: while you aren't using the chat (mouse elsewhere, chat box closed, not scrolled up) only the newest 6 lines show. Hover, scroll up or type and the whole window is back. Nothing is deleted; history and search still have every line. The number of lines can be set.
- Search: Ctrl+F opens the chat's search box while you're typing in the chat or have the mouse over a chat window (out of combat for the mouse; anywhere else Ctrl+F works as before). Type and the chat jumps to the newest line with that text; Enter or Up goes to the next older match, Shift+Enter or Down to the newer one, and the box shows which match you're on (like 3/12). Esc closes it and scrolls back down. /find still works. Can be turned off in the Search settings.
- Chat history: every chat window now keeps 3000 lines (it was about 128 unless you changed it), so you can scroll and search much further back. The setting goes up to 10000. If you set a number yourself, it is kept. The lines saved for your next session are capped at the newest 1000 per window (a new setting), so the saved file stays small. Turning history on or off for one window now takes effect at once.
- New module Chat background (on by default): the chat windows have no background at all, also when the mouse is over them and in new whisper windows. Tabs and text stay as they are. A slider sets how visible the background may get, from 0% (none) to 100% (the game decides, as before).
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
