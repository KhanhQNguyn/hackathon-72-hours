# Milestone 18 — `PdfReaderService`: `extractText` + `hasTextLayer`

**One-line goal:** extract text from a real application-form PDF, and cheaply detect whether it even has a text layer at all (vs. being a scanned image).

## Project context
`02-spec.md` §1: `syncfusion_flutter_pdf` is the confirmed PDF-parsing library (free community license, richer field extraction than a pure-text-only alternative). PDF forms aren't readable via the WebView/DOM approach — they need their own extraction path.

## Maps to plan.md task(s)
A4 (part 1 of 2)

## Preconditions
None — but needs a real sample PDF (`01-intent.md` §7 open item — the specific sample isn't picked yet). Build against any real-world application-form PDF with a genuine text layer in the meantime, and swap in the team's actual chosen sample once picked.

## Files touched
- `lib/services/pdf_reader_service.dart` — edit

## Implementation spec
- `Future<bool> hasTextLayer(String pdfPath)`: open via `PdfDocument.fromFile` (Syncfusion), attempt `PdfTextExtractor(document).extractText(startPageIndex: 0, endPageIndex: 0)` on **page 1 only** (cheap check). If the trimmed result length is below **20 characters**, return `false` — a real text-layer PDF's first page will almost always exceed this even if sparse; a scanned-image PDF returns empty or near-empty text.
- `Future<String> extractText(String pdfPath)`: full-document `PdfTextExtractor(document).extractText()`. **Precondition on callers:** only call this after `hasTextLayer` has returned `true` — document this explicitly in the method's doc comment. Do not have `extractText` silently return an empty string as if that were a valid result for a scanned PDF; that ambiguity is exactly what `hasTextLayer` exists to resolve upfront.

## Definition of Done
- [ ] Against a known real-text-layer PDF: `hasTextLayer` → `true`, `extractText` returns non-empty, recognizable text
- [ ] Against a scanned-image-only PDF (a photo of a form saved as PDF, or output from scanning software with OCR disabled): `hasTextLayer` → `false`

## Size
M
