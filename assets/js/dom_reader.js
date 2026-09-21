// Injected script — enumerates images (src/alt), form fields (tag/label),
// and page text. THE core spike target (plan.md Workstream A1): confirm
// this can reliably read DOM content from the real target platform
// before any real extraction logic is written here. See spec.md §5, §6
// "Web Content Perception".
//
// TODO: enumerate <img> elements lacking meaningful alt text
// TODO: enumerate <input>/<select>/<textarea> fields with associated labels
// TODO: extract visible text content
// TODO: attach a MutationObserver (perceive-act-wait-perceive loop,
//       spec.md §5) so callers know when to re-read after a DOM change
//
// No real extraction logic yet — scaffolding pass only.
