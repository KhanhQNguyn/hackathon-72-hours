# Milestone 19 — `PdfReaderService`: form-field-structure distinction

**One-line goal:** where the PDF library supports it, distinguish actual fillable form-field structure from plain body text, instead of returning an undifferentiated text blob.

## Project context
`02-spec.md` §1: preferring `syncfusion_flutter_pdf` over a lighter pure-text extractor specifically because it can "distinguish form fields from body text, not just dump raw text." This milestone is where that capability actually gets used.

## Maps to plan.md task(s)
A4's "distinguish form-field structure from body text" clause

## Preconditions
Milestone 18

## Files touched
- `lib/services/pdf_reader_service.dart` — edit
- `lib/models/pdf_form_field.dart` — **create fresh**: `class PdfFormField { final String name; final String type; final String? value; }`

## Implementation spec
- `Future<List<PdfFormField>> extractFormFields(String pdfPath)`: uses Syncfusion's `PdfDocument.form.fields` (AcroForm field enumeration) — only meaningful if the PDF actually has a real fillable-form layer.
- If `document.form.fields.count == 0` — a text-only PDF with no AcroForm, common for "print and fill by hand" application forms — **return an empty list**. This is an expected, normal outcome, not an error condition. The caller (milestone 40's PDF-structuring AI call) falls back to inferring field-like patterns from `extractText()`'s plain-text output instead.

## Definition of Done
- [ ] Against a PDF with real AcroForm fields: `extractFormFields` returns entries matching the visible field count on the actual PDF
- [ ] Against a plain-text-only application-form PDF (no AcroForm): returns `[]` without throwing

## Size
S
