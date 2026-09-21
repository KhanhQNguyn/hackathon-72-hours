# Milestone 03 — Secrets/env setup

**One-line goal:** get a real OpenAI API key loaded into the app at runtime, without it ever appearing as a string literal in source or being committed to Git.

## Project context
`job_access_assist` is a Flutter/Dart Android app that calls the OpenAI API directly from the client (no backend — a deliberate, documented scope cut for the 72h build). Full background: `02-spec.md` §2–§3, `05-scaffolder.md` Step 6.

## Maps to plan.md task(s)
C4

## Preconditions
None — start immediately. Milestones 36–40 (the OpenAI prompt calls) need this working before they can be tested against the real API.

## Files touched
- `.env` — already created during scaffolding (currently empty); edit to add the real key locally (never commit this file)
- `.env.example` — already exists with `OPENAI_API_KEY=` (empty) — no change needed
- `lib/services/openai_service.dart` — edit (add the actual key-loading call)
- `pubspec.yaml` — edit, **only if** the team picks the `flutter_dotenv` package (see flag below)

## Implementation spec
- Obtain a real OpenAI API key. Per `06-plan.md` C4: check first with a Day 1 mentor/organizer whether the hackathon provides sponsored API credits, before spending personal money.
- **Flag — genuine small gap in the existing docs, not silently resolved here:** `05-scaffolder.md` Step 6 says to create a `.env` file, but none of `01-intent.md`/`02-spec.md`/`05-scaffolder.md`/`06-plan.md` specifies which Flutter package actually *reads* `.env` at runtime. Two reasonable options — pick one and update `05-scaffolder.md`'s dependency list to match once decided:
  1. Add the `flutter_dotenv` package (not currently in `pubspec.yaml`), call `await dotenv.load(fileName: ".env")` in `main.dart` before `runApp()`, read via `dotenv.env['OPENAI_API_KEY']`.
  2. Use Dart's built-in `String.fromEnvironment('OPENAI_API_KEY')` with a `--dart-define=OPENAI_API_KEY=xxx` flag passed at build/run time instead of a `.env` file at all — avoids adding a dependency, but means the key must be passed on every `flutter run`/`flutter build` command line (and kept out of shell history / CI logs).
  - Recommended for a 3-person hackathon team: option 1 (`flutter_dotenv`) — one-time setup, no per-command-line key-passing to forget.
- `OpenAiService`: add a constructor or lazy getter that reads the key once and reuses it across all HTTP calls (don't re-read the env on every request).

## Definition of Done
- [ ] A trivial `OpenAiService` call (even just a hardcoded "say hello" `chat/completions` request with no real prompt logic) succeeds against the real API using the loaded key
- [ ] `git status` confirms `.env` is not staged or tracked
- [ ] `05-scaffolder.md`'s dependency list is updated to reflect whichever loading approach was actually chosen

## Size
S
