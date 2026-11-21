# EverlookDB Chat

## Unreleased
- Alt names on unit tooltips use the shared EverlookDB tooltip look, including its solid background (set in any EverlookDB addon's settings).

## v0.2.1 (2026-11-21)
- Importing a profile string works for your character again after the latest WoW Forever update.
- Importing alt names from LOKWhoIsWho or GuildGreet no longer errors or pulls in alts from other realms.

## v0.2.0 (2026-11-20)
- Chat history takes much less disk space: only the newest lines of your open chat windows are saved.
- Calm uses less CPU while you chat or scroll.
- Softer colours and cleaner edges in the settings window.

## v0.1.0 (2026-11-19)
- New: Chat placement. `/echat move` lets you drag and resize the chat, with a preview of where the chat box opens. Choose where the chat box sits.
- New: Calm. Fewer lines on screen while you aren't using the chat, paced channel chat, focus mode in combat (`/chat focus`), and whispers that are never missed.
- New: Idle fade. The chat fades out after a quiet minute and comes back when someone talks to you.
- New: Flat tabs, a clean chat box, no chat background, and hidden scroll bars.
- New: Tidy lines. Repeated system lines show once.
- New: Commands first. A line starting with `/` runs as a command in every chat mode, also while whispering a Battle.net friend.
- Search: Ctrl+F searches the chat, Enter and Shift+Enter jump between matches.
- Chat history keeps 3000 lines per window, and the line between sessions is one quiet grey line.
- Commands follow one pattern across all EverlookDB addons: `/echat help` lists them.
- `/echat ai` copies a description of every setting for an AI assistant, and `/echat apply` runs what it gives back.
- Alt names on tooltips share the EverlookDB tooltip layout.

## v0.1.0 (2026-11-16)

- First version, based on Prat-3.0 (see Credits and licence in the README).
- Settings: `/edbchat`. Can be installed next to Prat-3.0; it tells you in chat when both are turned on.
- Settings from Prat-3.0 are not copied over.
- Only loads on WoW Forever.
