import 'dart:convert';

import '../../models/dom_snapshot.dart';

/// Milestone 39 — pick the element matching a target description from a
/// short, heuristically pre-filtered candidate list (`gpt-4o-mini`).
/// Never receives raw DOM/HTML (spec.md §5 "Heuristic pre-filtering").
const String elementMatchingSystemPrompt = '''
You help a voice assistant choose which element on a web page to act on. You get a target description (what the user wants, e.g. "search bar", "phone number field") and a short list of candidate elements, already narrowed by heuristics. Labels may be English or Vietnamese.

Rules:
- Choose only from the given candidates, using their elementId. Never invent an id.
- If none of the candidates plausibly matches, return elementId null.
- Confidence must reflect real ambiguity. If two or more candidates could be the target (for example two similarly labeled fields), confidence MUST be below 0.7 and every plausible alternative MUST be listed in alternativeElementIds.
- Only give confidence of 0.7 or higher when exactly one candidate is clearly correct.
- "reasoning" is one short sentence a user could hear read aloud.

Respond with JSON only, exactly this shape:
{"elementId": "string or null", "confidence": 0.0, "reasoning": "string", "alternativeElementIds": ["string"]}''';

Map<String, Object?> candidateToJson(DomFormField f) => {
  'elementId': f.elementId,
  'tag': f.tag,
  'type': f.type,
  'role': f.role,
  'label': f.resolvedLabel ?? f.ariaLabel ?? f.placeholder ?? f.name,
  'labelSource': f.labelSource,
  'heuristicScore': f.heuristicScore ?? 0,
};

String elementMatchingUserMessage({
  required String targetDescription,
  required List<DomFormField> candidates,
}) => jsonEncode({
  'targetDescription': targetDescription,
  'candidates': candidates.map(candidateToJson).toList(),
});
