# Milestone 36 — `openai_service`: intent parsing

**One-line goal:** turn a recognized voice transcript into a structured request the FSM can act on.

## Project context
`02-spec.md` §6 item 2 ("Intent Parsing"): an OpenAI (`gpt-4o-mini`, text-only) call that turns the transcript into a structured request — e.g. "read this job listing," "fill and submit this application," or Feature 2's "take me to X."

## Maps to plan.md task(s)
C1, call type (a)

## Preconditions
Milestone 03; shape-only dependency on milestone 28 (needs to know `VoiceCommandResult`'s fields)

## Files touched
- `lib/services/openai_service.dart` — edit
- `lib/services/prompts/intent_parsing_prompt.dart` — **create fresh** (this project organizes each of C1's 5 prompt templates into its own small file under a new `lib/services/prompts/` directory — a natural, low-risk organizational addition not anticipated in `05-scaffolder.md`'s original tree, since that tree didn't anticipate needing 5 separate prompt templates; flag this as a minor scaffold-tree extension, not a scope change)

## Implementation spec
**Request/response shape:**
- Input to the model: `{"transcript": "string", "nBestAlternatives": ["string"], "languagePref": "en"|"vi"}`
- System prompt establishes: the assistant's only job is to classify the utterance into one of a fixed set of intents and extract a target description — it does not generate free-form conversational replies.
- Required output JSON:
  ```json
  {"intentType": "read_listing" | "fill_and_submit" | "navigate_to_element" | "unrecognized", "targetDescription": "string|null", "confidence": 0.0}
  ```
  `intentType: "navigate_to_element"` is Feature 2's "take me to X" case (`02-spec.md` §6 item 2).
- **Confidence gating:** `confidence < 0.6` (reuse the same starting threshold as STT, per the established pattern) → treat as `"unrecognized"` regardless of what `intentType` the model actually returned, and trigger the same re-prompt narration path as milestone 29.

## Definition of Done
- [ ] Given 5 hand-crafted sample transcripts (2 EN, 2 VI, 1 deliberately ambiguous), the call returns the expected `intentType` for the 4 clear cases and a low-confidence/`"unrecognized"` result for the ambiguous one

## Size
M
