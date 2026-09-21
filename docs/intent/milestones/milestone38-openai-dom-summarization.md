# Milestone 38 — `openai_service`: DOM filtering/summarization

**One-line goal:** turn a page's raw visible text into a clean, narratable job-listing summary, suppressing navigation chrome, ads, and unrelated content.

## Project context
`02-spec.md` §6 item 5 ("AI Filtering & Matching"): suppresses navigation/ad/irrelevant DOM content and summarizes/narrates the actual job-listing content.

## Maps to plan.md task(s)
C1, call type (c)

## Preconditions
Milestone 03; shape-only dependency on milestone 12 (`DomSnapshot.visibleText`)

## Files touched
- `lib/services/openai_service.dart` — edit
- `lib/services/prompts/dom_summarization_prompt.dart` — **create fresh**

## Implementation spec
- Input: `{"pageText": "string (from DomSnapshot.visibleText, already capped at 8000 chars per milestone 12)", "url": "string"}`
- Output JSON — matching the existing `JobListing` model's fields exactly, so the result can construct one directly:
  ```json
  {"title": "string", "company": "string", "requirements": "string", "howToApply": "string", "confidence": 0.0}
  ```
- System prompt gives explicit negative examples of what to ignore: cookie banners, related-job carousels, footer links, ads — not just a general "filter out noise" instruction.

## Definition of Done
- [ ] Against 2–3 hand-crafted sample `pageText` strings (mixing real listing content with realistic nav/ad noise), the returned `JobListing` fields contain only the actual listing content, with the noise excluded

## Size
M
