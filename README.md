<p align="center"><img src="docs/app-icon.png" width="128" alt="TypeLikeMe icon"></p>

# TypeLikeMe

Voice typing for macOS, powered by [Sarvam AI](https://sarvam.ai). Hold **fn**, talk, let go, and clean, well-formatted text appears wherever your cursor is: Slack, Mail, Zed, Cursor, Terminal, the browser, anywhere.

- **Native and small.** Swift and SwiftUI with Metal, no third-party dependencies. The app is under 2 MB and idles at 0% CPU. The mic is only on while you're dictating.
- **Fast.** Sarvam `saaras:v4` transcribes in well under a second, and `sarvam-105b-conversations` formats in about 0.3–0.5 s.
- **Indian languages and code-mixing.** Auto-detects English, Hindi, Tamil, Telugu, Bengali and more. Output can be native script, English translation, Hinglish or romanized.

## Controls

| Action | Keys |
|---|---|
| Push-to-talk | hold `fn`, speak, release |
| Hands-free | double-press `fn`, press once more to insert (or click the red stop square) |
| Command mode | hold `fn` + `⌃` and say "make this more formal" to rewrite the selection, or "write a polite decline" to write new text |
| Cancel | `esc` |
| Paste last dictation again | `⌃⌘V` |

A single quick press of `fn` does nothing, so a stray press never leaves the mic on. Right ⌥, right ⌘ or right ⌃ can be used as the trigger instead of `fn`.

## Features

- **Pixel bar.** A thin bar on the bottom edge built from crisp square pixels. Pixels stream in from both sides of the screen as you start. Your voice shows as a dithered waveform whose newest sound glows red-hot in the centre, with sparks breaking off on loud moments. A scanner sweeps while Sarvam works. Then a red block cursor types your words in a hand-drawn pixel font, and the letters lift off as the real text pastes. Drag the bar to dock it bottom-left, centre or bottom-right. It moves aside on its own if your text cursor is underneath it. Settings → Particle effects (or macOS Reduce Motion) switches to plain level bars.
- **Prompt mode for AI tools.** In Claude Code, Codex, Cursor, Zed, VS Code, ChatGPT and Claude, dictation is cleaned into a clear prompt. Grammar is fixed, misheard tech terms are corrected (`useEffect`, Supabase, `gh`), and code terms go in backticks. Three or more asks become a numbered list. It edits rather than reinterprets: questions stay questions, replies stay replies, and nothing you said is dropped.
- **Smart formatting everywhere else.** Lists you speak become bullet points, and steps become numbered lists. Long thoughts are split into paragraphs, and emails get a greeting, body and sign-off. Bullets are "-" in Markdown apps and "•" in Mail, Slack and WhatsApp.
- **Writes like you'd type it.** It reads the text before your cursor, so a dictation continues the sentence with the right spacing and capitalization. It also applies self-corrections ("tomorrow, no wait, Friday" becomes "Friday") and writes numbers, times, money and emails the way people type them.
- **Hears your jargon.** Your Dictionary words, plus common coding terms when you're in an AI tool, are sent to Sarvam as keyterms so they're transcribed correctly.
- **Nothing gets lost.** If no text field is focused, the text isn't pasted into nowhere. It stays on your clipboard and a card shows it with a Copy button. `⌃⌘V` pastes your last dictation anywhere, any time.
- **No emoji popup.** fn is freed from the 🌐 emoji picker using the same system call System Settings uses, so it applies without logging out.
- **Dashboard.** A Raycast-style window showing words dictated, words per minute, time saved, streak, a 14-day chart and searchable history (with the original transcript one click away), plus Dictionary, Style and Settings. Everything stays on your Mac.
- **Your clipboard is safe.** It's restored right after each paste.

## Build and install

Requires macOS 14 or later on Apple Silicon, Xcode command-line tools, and a [Sarvam API key](https://dashboard.sarvam.ai).

```bash
cp .env.example .env          # then put your Sarvam key in .env
./scripts/build-app.sh        # builds, signs, installs to /Applications, launches
```

The build script signs with your Apple Development identity if you have one, so macOS keeps the Microphone and Accessibility permissions across rebuilds. Without one, it signs ad-hoc.

On first launch the dashboard shows a short checklist: API key, Microphone, Accessibility, and freeing the fn key.

Your key is copied to `~/Library/Application Support/TypeLikeMe/config.json` (mode 600). It is never compiled into the app, and `.env` is git-ignored.

### Dev helpers

```bash
swift build -c release
.build/release/TypeLikeMe --selftest some16kmono.wav                          # headless Sarvam pipeline test
.build/release/TypeLikeMe --format "um so we ship friday" - Slack com.tinyspeck.slackmacgap   # formatting check
TYPELIKEME_PILL_DEMO=1 .build/release/TypeLikeMe                              # loop the bar animation (no mic, never pastes)
TYPELIKEME_DEMO=1 .build/release/TypeLikeMe                                   # dashboard with sample data
# diagnostics log: ~/Library/Logs/TypeLikeMe.log (never contains your key)
```

## Layout

```
Sources/TypeLikeMe/
  main.swift                   app entry, menu bar, windows, CLI helpers
  Core/
    AudioRecorder              16 kHz capture, live levels, WAV encoding, chunking at pauses
    SarvamClient               speech-to-text (keyterms), formatting, Prompt mode, command mode
    DictationController        hold / double-press / command / cancel state machine and pipeline
    HotkeyMonitor              event tap for fn and modifiers on its own thread
    CursorContext              text before the cursor, caret position, text-field detection
    TextInserter               paste at the cursor and restore the clipboard
    Settings, Store, Permissions, Log
  UI/
    PixelField                 Metal pixel-grid renderer (wave, scanner, typed words)
    PixelFont                  hand-drawn proportional pixel font
    PillOverlay                the dictation bar
    CopyCard, FlightPanel, Theme
  Dashboard/                   Home, History, Dictionary, Style, Settings
```
