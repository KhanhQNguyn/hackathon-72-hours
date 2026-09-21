# Milestone 23 — Error handling: PDF-parse failure

**One-line goal:** if a PDF genuinely can't be read — even after the OCR fallback — treat it as a recoverable failure through the same machinery as every other error, not a special case.

## Project context
Continues the "built-in robustness" principle from `02-spec.md` §3, now applied to the final PDF-parse failure mode: the case where **both** the direct text extraction and the OCR fallback (milestone 20) fail.

## Maps to plan.md task(s)
A5 (part 2 of 3)

## Preconditions
Milestone 08, milestone 18, milestone 20

## Files touched
- `lib/services/pdf_reader_service.dart` — edit
- `lib/orchestration/application_flow_fsm.dart` — edit

## Implementation spec
- `extractTextWithOcrFallback` (milestone 20) throws `PdfParseException` **only** if both the direct-extraction path and the OCR fallback path fail — this is the final failure mode after the fallback chain, not a duplicate of milestone 20's own internal fallback logic.
- Routed through the exact same `ErrorOccurred`/`ErrorState` machinery as milestone 22 — reuse it, do not build a parallel error path just for PDFs.

## Definition of Done
- [ ] A deliberately corrupted/truncated PDF file triggers `PdfParseException` after both extraction paths genuinely fail, and the FSM enters `ErrorState` with the correct narration

## Size
S
