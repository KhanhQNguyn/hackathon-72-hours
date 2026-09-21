# Milestone 39 — `openai_service`: element/field matching + confidence

**One-line goal:** given a short, heuristically-narrowed candidate list, have the AI pick the right element for a target description, with a confidence score that gates whether the app acts on it or asks the user to disambiguate. **This is the reliability-critical milestone in Workstream C.**

## Project context
`02-spec.md` §6 item 5: *"Element-selection confidence threshold — a separate mechanism from STT confidence... when deciding which detected element (search bar, submit button, a specific labeled field) is the right one to act on, the AI's confidence in that match is checked against an agreed threshold... Below it, the flow does not silently proceed with the top guess — it narrates the ambiguity... and asks the user to disambiguate."*

## Maps to plan.md task(s)
C1, call type (e)

## Preconditions
Milestone 03; shape-only dependency on milestones 10/11/12 (the candidate-list shape)

## Files touched
- `lib/services/openai_service.dart` — edit
- `lib/services/prompts/element_matching_prompt.dart` — **create fresh**
- `lib/models/element_match_result.dart` — **create fresh**

## Implementation spec
**Request/response shape — this is the exact `{elementId, confidence, reasoning}` shape `02-spec.md` §6 already commits to:**
- Input: `{"targetDescription": "string (e.g. 'search bar', 'phone number field')", "candidates": [{"elementId": "string", "tag": "string", "type": "string|null", "role": "string|null", "label": "string|null", "labelSource": "string|null", "heuristicScore": 0}]}` — this `candidates` array is exactly milestones 10/11's heuristic-narrowed output, **never** the raw DOM.
- Output JSON:
  ```json
  {"elementId": "string|null", "confidence": 0.0, "reasoning": "string", "alternativeElementIds": ["string"]}
  ```
  `elementId: null` is a valid, expected output — the model may determine none of the candidates actually match.
- `ElementMatchResult` model: `{String? elementId, double confidence, String reasoning, List<String> alternativeElementIds}`.
- **Confidence threshold: 0.7** (proposed starting value — higher than the 0.6 STT threshold, since a wrong click/fill is a more consequential and harder-to-notice failure than a misheard word, which downstream confirmation steps can still catch; still explicitly a starting value to tune empirically, same convention as the STT threshold).
  - **≥ 0.7:** act on `elementId` directly.
  - **< 0.7:** do not act. Surface `reasoning` plus the candidates named in `alternativeElementIds` (resolved back to their `label`s) in the disambiguation narration — `02-spec.md` §6 already gives the example wording: *"I see two fields that could be the search box — one labeled 'Từ khóa', one labeled 'Vị trí' — which one did you mean?"*

## Definition of Done
- [ ] Given a hand-crafted candidate list with one clearly-correct match, returns that `elementId` with confidence ≥ 0.7
- [ ] Given a hand-crafted candidate list with two similarly-labeled, genuinely ambiguous fields (mirroring `02-spec.md` §6's own "Từ khóa"/"Vị trí" example), returns confidence < 0.7 and both fields in `alternativeElementIds`
- [ ] This is the exact scenario the `06-plan.md` Success Proof checklist item "a low-confidence element match... triggers a disambiguating question" tests end-to-end once wired into the FSM

## Size
L — the prompt design + confidence calibration is genuinely iterative. If the two Definition-of-Done cases above don't hold reliably on the first pass, treat further prompt tuning as its own follow-up milestone rather than blocking everything else on getting this perfect immediately.
