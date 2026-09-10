# Quire

A quiet, local-first writing room for macOS.

Quire started as a fork of [farzaa/freewrite](https://github.com/farzaa/freewrite) and grew into something larger: a blank page for stream-of-consciousness writing, with a journal, voice, video, and optional offline AI sitting behind the glass. The page stays empty until you ask for more.

This is not the [Freewrite hardware](https://getfreewrite.com/). It is not a cloud notes app.

**One page. Your disk. No account.**

## The idea

Write without ceremony. A timer if you want urgency. Backspace lock if you want momentum. Markdown files you can open in any editor.

Everything lives on your Mac:

```
~/Documents/Freewrite/
```

(or a folder you choose). Sandboxed builds use the app container equivalent. Entries are plain markdown with names like `[UUID]-[YYYY-MM-DD-HH-mm-ss].md`.

## What you can do

**Always there**
- Timed sessions, fullscreen, light/dark
- Optional backspace lock
- Auto-save, a new page each day
- History with search, pins, streak, and a month calendar
- On-this-day, weekly review, session recap
- A daily writing spark on the empty page
- Voice notes (audio + live transcript)
- Editor and chat dictation
- Video journal
- PDF export
- `#tags` — click a chip to find other entries
- Optional daily word goal
- Optional Touch ID / password lock at launch (a gate, not encryption)
- Custom journal folder

**Settings → Advanced (off by default)**
- Paste / capture images; click a thumbnail to draw on it
- `[[wiki links]]` and an entry graph
- `>>` margin notes and `==highlights==`
- Mermaid flowcharts (`graph TD` / `A[Start] --> B`)

**Offline AI (Ollama)**
- Multi-turn chat beside the page
- Personas and editable prompts
- Chat history saved next to the entry
- Weekly review of the last seven days

The first entry you ever see is still Farza’s original freewriting guide. After that, the page is yours.

## Shortcuts

| Shortcut | Action |
|---|---|
| Cmd+N | New entry |
| Cmd+, | Settings |
| Ctrl+Cmd+F | Fullscreen |
| Cmd+Shift+H | History |
| Cmd+Shift+T | Timer |
| Cmd+Shift+D | Light / dark |
| Cmd+Shift+B | Backspace lock |
| Cmd+Shift+M | Dictate |
| Cmd+Shift+A | Voice note |
| Cmd+Shift+O | Ollama chat |
| Cmd+Shift+R | Weekly review |
| Cmd+Shift+Y | Typewriter scroll |

## Build

**Xcode:** open `freewrite.xcodeproj`, run the `freewrite` target (macOS 14+).

**No Xcode IDE:** Command Line Tools are enough.

```bash
./build.sh            # build/Freewrite.app
./build.sh --install  # copy to /Applications
```

Then open the `.app` from Finder (or `open build/Freewrite.app`). Launching the raw binary from another app can confuse macOS privacy prompts.

Microphone, camera, and speech strings are in the bundle. The first voice note or video will ask for permission.

## Storage

| Kind | Where |
|---|---|
| Text entries | `*.md` in the journal folder |
| Images / voice | `Media/[entry-base]/` |
| Videos | `Videos/` |
| Ollama chats | `Chats/` |

Change the folder in Settings → Advanced. Existing files are not moved.

## Name

The Dock name is **Quire** — a gathering of pages. The bundle id is still `app.humansongs.freewrite` so your existing files and permissions keep working.

## Heritage

Fork of [farzaa/freewrite](https://github.com/farzaa/freewrite) (MIT). Farza built the blank page, the timer, and the video journal. This tree adds the journal layer, offline chat, and the Advanced tools.

## License

MIT. See `LICENSE`.
