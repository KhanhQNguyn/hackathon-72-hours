# Milestone 34 — Mock `WebViewControllerService`/`PdfReaderService`

**One-line goal:** build fake, canned-content versions of the WebView and PDF services so Workstream B can prove its FSM/UI works end-to-end without waiting on Workstream A's real implementation.

## Project context
`06-plan.md` B1's own text explicitly sanctions this: *"Write this against mocked services first (fake `WebViewControllerService`/`PdfReaderService` returning canned content) so it doesn't block on Workstream A."* This milestone is not new scope — it's building exactly what that sentence already calls for.

## Maps to plan.md task(s)
B5 (part 1 of 2)

## Preconditions
None

## Files touched
- `test/mocks/fake_webview_controller_service.dart` — **create fresh**
- `test/mocks/fake_pdf_reader_service.dart` — **create fresh**

## Implementation spec
- `FakeWebViewControllerService implements WebViewControllerService`:
  - `readDom()` returns a hardcoded `DomSnapshot` resembling a plausible real job-listing page: 2–3 images, one search field, one submit button, 4 labeled fields matching the applicant-profile shape (name, phone, email, CV upload).
  - `fillField()` always returns `success: true`, after a short `Future.delayed(Duration(milliseconds: 300))` to simulate real latency for UI-testing purposes.
- `FakePdfReaderService implements PdfReaderService`: `extractTextWithOcrFallback()` returns a canned multi-paragraph string resembling a real application form's text.

## Definition of Done
- [ ] Both fakes compile against the real service interfaces — if they don't, this milestone surfaces a signature mismatch between the real services and what's expected, which should be fixed at the source (the real service), not papered over in the fake

## Size
S
