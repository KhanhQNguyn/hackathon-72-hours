# Milestone 20 — `OcrService` + `PdfReaderService` fallback wiring

**One-line goal:** when a PDF has no real text layer (a scanned image), fall back to on-device OCR instead of failing — the same underlying accessibility problem this whole project addresses, showing up inside its own input pipeline.

## Project context
`02-spec.md` §1: `google_mlkit_text_recognition` is the confirmed OCR fallback — on-device, free, no added API cost/latency vs. routing every scanned PDF through the vision API. Triggered specifically when `hasTextLayer` (milestone 18) returns `false`.

## Maps to plan.md task(s)
A8

## Preconditions
Milestones 18, 19

## Files touched
- `lib/services/ocr_service.dart` — edit
- `lib/services/pdf_reader_service.dart` — edit (new method wiring OCR in)

## Implementation spec
- `OcrService.recognizeText(String imagePath)`: use `google_mlkit_text_recognition`'s `TextRecognizer(script: TextRecognitionScript.latin)` — Vietnamese uses Latin script with diacritics, which this script option supports — against a rendered page image.
- **⚠️ Flag — genuine sub-decision not resolved by `02-spec.md`, which names the OCR engine but not a PDF-page-rasterization approach:** `google_mlkit_text_recognition` takes an **image**, not a PDF page directly, so a page-to-image render step is needed first. Recommended default (avoids adding a *third* PDF-handling dependency alongside `syncfusion_flutter_pdf`): render the PDF page via `flutter_inappwebview`'s own `WebView` (already a project dependency) loading a local `<embed>` of the PDF, then capture a screenshot of that render. If this proves unreliable in testing, the fallback is to add a dedicated small rasterization package (e.g. `pdfx`) — note that choice back into `02-spec.md` §1 if taken.
- `PdfReaderService.extractTextWithOcrFallback(String pdfPath)`: the **single method the rest of the app should call** (never `extractText` directly) — checks `hasTextLayer` first; if `false`, rasterizes and routes through `OcrService.recognizeText`; if `true`, calls the normal `extractText`. Routing all callers through this one method means the fallback can never be accidentally bypassed.

## Definition of Done
- [ ] Against the scanned-image PDF from milestone 18's test: `extractTextWithOcrFallback` returns non-empty, recognizable text (allow for OCR imperfection — spot-check readability, don't require exact match)
- [ ] Against the real-text-layer PDF from milestone 18: `extractTextWithOcrFallback` returns the same result as calling `extractText` directly — confirms the fast path is actually taken, not OCR-ing everything unconditionally

## Size
M
