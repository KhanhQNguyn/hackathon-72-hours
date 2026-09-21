# Milestone 40 — `openai_service`: PDF-text structuring

**One-line goal:** turn raw extracted PDF text (and any detected AcroForm fields) into a structured, section-by-section breakdown a screen reader can navigate.

## Project context
`02-spec.md` §6 item 4 ("PDF Perception") / item 7 ("Form-Fill Orchestrator" upstream input): the PDF-parsing service extracts text and, where possible, distinguishes form-field structure from body text — this milestone is the AI layer on top of that raw extraction.

## Maps to plan.md task(s)
C1, call type (d)

## Preconditions
Milestone 03; shape-only dependency on milestones 18/19

## Files touched
- `lib/services/openai_service.dart` — edit
- `lib/services/prompts/pdf_structuring_prompt.dart` — **create fresh**

## Implementation spec
- Input: `{"rawPdfText": "string", "detectedFormFields": [{"name": "string", "type": "string", "value": "string|null"}] }` — `detectedFormFields` comes from milestone 19's `extractFormFields()`, may be an empty array.
- Output JSON:
  ```json
  {"sections": [{"heading": "string", "body": "string"}], "inferredFields": [{"label": "string", "inferredType": "text"|"email"|"phone"|"file"|"unknown"}]}
  ```
  `inferredFields` is used when `detectedFormFields` is empty (a plain-text PDF with no AcroForm) — ask the model to spot field-like patterns from raw text (e.g. "Full name: ___________").

## Definition of Done
- [ ] Against the real chosen PDF sample's extracted text (from milestone 18), returns a structured, navigable breakdown a screen reader could read section by section

## Size
M
