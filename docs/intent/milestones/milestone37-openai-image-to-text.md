# Milestone 37 — `openai_service`: image-to-text

**One-line goal:** transcribe a job description that was posted as an image instead of typed text — the core Stage 2 barrier this whole project targets.

## Project context
`02-spec.md` §1: `gpt-4o` (vision) is used specifically when a job description is posted as an image with no usable alt text, sending the extracted image and asking it to transcribe/describe the actual job-description content.

## Maps to plan.md task(s)
C1, call type (b)

## Preconditions
Milestone 03

## Files touched
- `lib/services/openai_service.dart` — edit
- `lib/services/prompts/image_to_text_prompt.dart` — **create fresh**

## Implementation spec
- Input: `{"imageBase64": "string", "contextHint": "string"}` — `contextHint` is a short fixed string, e.g.: *"This is a job description posted as an image on a job listing page. Transcribe all readable text, preserving structure (title, requirements, how to apply) where identifiable."*
- Output JSON: `{"transcribedText": "string", "confidence": 0.0}`.
- This is a `gpt-4o` vision call per `02-spec.md` §1 — only invoked when an image lacks meaningful alt text (milestone 09's `hasAlt: false` result), not on every image.

## Definition of Done
- [ ] Against 2–3 real screenshots of image-based job postings (can be sourced from example VietnamWorks/LinkedIn image-based postings independent of the team's final chosen listing), returns readable, substantially-correct transcribed text

## Size
S
