# Milestones index

This is a map, not a duplicate of each file's content. Build in this order — numbers reflect real dependencies, not just the A/B/C workstream grouping. Where a milestone can be built earlier against a mock, that's noted in its own file's Preconditions.

Each file is self-contained: give a coding session only that one file and it has everything needed to execute it (it may still need to read/edit the actual codebase files it names live).

`06-plan.md` stays the source of truth for *what*/*why* and is the final audit document once every milestone below is done — see its "Post-Build Audit" section.

| # | File | Goal | Preconditions |
|---|---|---|---|
| 01 | `milestone01-spike-dom-reading-harness.md` | Prove the JS-bridge can read DOM content from the real target | None — start immediately |
| 02 | `milestone02-spike-focus-talkback.md` | Prove `.focus()` via JS injection triggers a real TalkBack announcement | None — parallel with 01 |
| 03 | `milestone03-secrets-env-setup.md` | OpenAI API key wired in, never committed | None — start immediately |
| 04 | `milestone04-fsm-contracts-front-half.md` | Finalize FSM state/event fields; implement `Idle`→`AwaitingUserAction` | None — start immediately |
| 05 | `milestone05-fsm-filling-form-loop.md` | Field-by-field confirm loop logic | 04 |
| 06 | `milestone06-fsm-final-review-editing-field.md` | `FinalReview` + `EditingField` loop-back | 04, 05 |
| 07 | `milestone07-fsm-gated-submit-done.md` | Submit action gated on FSM state, not AI text | 04–06 |
| 08 | `milestone08-fsm-error-retrying.md` | Generic `Error`/`Retrying` wrapper | 04 |
| 09 | `milestone09-dom-reader-images.md` | `dom_reader.js`: image + alt-text enumeration | 01 passed |
| 10 | `milestone10-dom-reader-search-heuristics.md` | `dom_reader.js`: search-field candidate heuristics | 09 |
| 11 | `milestone11-dom-reader-submit-field-heuristics.md` | `dom_reader.js`: submit-button + labeled-field heuristics | 09 |
| 12 | `milestone12-dom-reader-text-mutationobserver-readdom.md` | Text extraction + `MutationObserver` + `readDom()` | 09–11 |
| 13 | `milestone13-captcha-detection-heuristic.md` | Detect a CAPTCHA on the page | 12 |
| 14 | `milestone14-captcha-audio-pause-resume.md` | Try audio challenge first, else pause FSM and resume on "continue" | 13, 07 |
| 15 | `milestone15-form-filler-locate-set-dispatch.md` | `form_filler.js`: locate + set value + dispatch events | 10, 11 |
| 16 | `milestone16-form-filler-verify-fillfield.md` | Verify-after-action + `WebViewControllerService.fillField()` | 15 |
| 17 | `milestone17-webmessagelistener-origin-restriction.md` | Restrict which origins can message back into the app | 15 |
| 18 | `milestone18-pdf-extracttext-hastextlayer.md` | `PdfReaderService`: `extractText` + `hasTextLayer` | None (needs a real sample PDF) |
| 19 | `milestone19-pdf-form-field-structure.md` | Distinguish PDF form-field structure from body text | 18 |
| 20 | `milestone20-ocr-service-fallback-wiring.md` | OCR fallback for scanned PDFs | 18, 19 |
| 21 | `milestone21-file-picker-service-integration.md` | Native CV file picker | 16 |
| 22 | `milestone22-error-handling-page-load.md` | Page-load failure/timeout handling | 08, 12 |
| 23 | `milestone23-error-handling-pdf-parse.md` | PDF-parse failure handling | 08, 18, 20 |
| 24 | `milestone24-error-handling-field-not-found.md` | Zero-candidate field handling | 08, 39 |
| 25 | `milestone25-workstream-a-manual-test.md` | Manually prove A's pieces work together vs. the real target | 09–21 |
| 26 | `milestone26-status-narration-view-wiring.md` | Live narration text bound to FSM state | 04 |
| 27 | `milestone27-voice-trigger-home-screen-semantics.md` | Trigger button wiring + Semantics audit | 04, 26 |
| 28 | `milestone28-speech-service-stt-integration.md` | Real `speech_to_text` integration | 04 |
| 29 | `milestone29-stt-confidence-threshold-gating.md` | Below-threshold STT re-prompts instead of proceeding | 28 |
| 30 | `milestone30-tts-service-integration.md` | Real `flutter_tts` integration | 04 |
| 31 | `milestone31-settings-language-toggle.md` | EN/VI toggle | 04 |
| 32 | `milestone32-applicant-profile-service-storage.md` | `sqflite` + `flutter_secure_storage` profile persistence | None |
| 33 | `milestone33-settings-profile-fields-ui.md` | Settings-screen profile form *(open decision — confirm scope first)* | 31, 32 |
| 34 | `milestone34-mock-webview-pdf-services.md` | Fake `WebViewControllerService`/`PdfReaderService` for B5 | None |
| 35 | `milestone35-wire-b1-b4-against-mocks.md` | Full mocked end-to-end run | 04–08, 26, 27, 28–30, 31–33, 34 |
| 36 | `milestone36-openai-intent-parsing.md` | Intent-parsing prompt/response contract | 03; shape from 28 |
| 37 | `milestone37-openai-image-to-text.md` | Image-to-text vision prompt | 03 |
| 38 | `milestone38-openai-dom-summarization.md` | Listing-content filtering/summarization prompt | 03; shape from 12 |
| 39 | `milestone39-openai-element-field-matching.md` | Element/field matching + confidence threshold (reliability-critical) | 03; shape from 10–12 |
| 40 | `milestone40-openai-pdf-structuring.md` | PDF-text structuring prompt | 03; shape from 18–19 |
| 41 | `milestone41-fuzzy-match-service.md` | Cheap fuzzy-match before falling back to OpenAI | shape from 32, 10–11 |
| 42 | `milestone42-narration-script-content.md` | Exact EN/VI narration strings | 04–08 |
| 43 | `milestone43-talkback-accessibility-scanner-pass.md` | Manual TalkBack pass + Accessibility Scanner | 26, 27 |
| 44 | `milestone44-integration-checkpoint-swap-real.md` | Swap mocks for real A services | 12, 16, 18–21, 35 |
| 45 | `milestone45-repeated-real-e2e-testing.md` | Repeated real-device end-to-end runs | 44 |
| 46 | `milestone46-record-demo-video.md` | Record the submission video | 45, 43 |
| 47 | `milestone47-slide-deck.md` | Build the slide deck | None for first draft; final polish needs 46 |

**Two open decisions, not resolved by `01-intent.md`/`02-spec.md`/`06-plan.md`, flagged in the relevant files rather than silently decided:**
1. How the FSM represents "paused for CAPTCHA" (see `milestone14`) — recommended: `CaptchaPendingState(interruptedState)`, mirroring the existing `ErrorState(failedState, message)` pattern.
2. Whether B4 needs a dedicated Settings-screen profile-entry UI at all (see `milestone33`) vs. capturing profile fields conversationally the first time they're needed during form-fill.
