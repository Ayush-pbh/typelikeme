# TypeLikeMe — next-gen voice dictation for macOS

## Objective

Ship a working, very lightweight native macOS voice-dictation app (a "next version" of Wispr Flow) powered by Sarvam AI: hold the Fn key anywhere, speak, and polished text appears at the cursor in whatever app is focused. It has a floating live-waveform pill and a beautiful dashboard.

## Original Request

"Build something like Whisper Flow with good visuals in the dashboard. Floating line utility; press the Fn key → it listens → the transcription appears wherever the cursor is. A next version people would love. Use Sarvam (key in .env). Very lightweight. Choose any framework. Make a GoalBuddy goal and start working."

## Intake Summary

- Input shape: `specific`
- Audience: the user plus everyday Mac users who type a lot (English + Indian languages via Sarvam)
- Authority: `approved` (user said "go create it")
- Proof type: `demo` + `artifact`
- Completion proof: a signed `TypeLikeMe.app` builds from one script. Fn hold-to-talk records audio, Sarvam returns text, and the text is pasted at the cursor in another app. The floating pill animates with the voice. The dashboard shows stats, history, dictionary and settings. The live Sarvam pipeline is verified from the CLI.
- Likely misfire: a pretty dashboard with no working global hotkey/paste pipeline; or a heavy Electron app (violates "very lightweight").
- Blind spots considered: macOS Fn/🌐 key triggers emoji/dictation by default; Accessibility permission is lost on every ad-hoc re-sign (use a stable signing identity); Sarvam REST caps audio at ~30s (chunk long takes); the API key must not be baked into the binary; the clipboard must be restored after paste; the app is launched from Finder without shell env.
- Existing plan facts: Sarvam STT (`saaras:v3`, verified 0.6s) + `sarvam-105b-conversations` for cleanup (verified 0.3s). Native Swift/SwiftUI, SwiftPM, no Xcode project.

## Goal Kind

`specific`

## Current Tranche

Continuous: scaffold → audio+STT core → hotkey+paste → floating pill → dashboard → packaging/signing → end-to-end verification → audit.

## Non-Negotiable Constraints

- Native Swift, zero third-party dependencies, small binary and low idle RAM.
- API key read from a local config file / env var, never compiled in.
- Never lose the user's clipboard contents.
- Works in any app with a text cursor.

## Stop Rule

Stop only when a final audit proves the full original outcome is complete.

## Canonical Board

`docs/goals/typelikeme-voice-flow/state.yaml`

## Run Command

```text
/goal Follow docs/goals/typelikeme-voice-flow/goal.md.
```
