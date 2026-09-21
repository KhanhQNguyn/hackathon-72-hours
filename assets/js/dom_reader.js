// Injected script — enumerates images (src/alt), heuristically narrows
// search/submit-button/labeled-field candidates, extracts visible page
// text, and wires a MutationObserver + WebMessageListener bridge so the
// Dart side knows when to re-read the DOM (perceive-act-wait-perceive
// loop, spec.md §5). See spec.md §5-§6 "Web Content Perception",
// "Heuristic pre-filtering before AI selection". Covers milestones
// 09-12.
//
// All functions are attached to `window` so they're callable on demand
// from Dart via `evaluateJavascript` (e.g. `window.__domReader_getImages()`).

(function () {
  // ---------------------------------------------------------------------
  // Shared: stable element-id tagging (milestone10)
  // ---------------------------------------------------------------------
  var __domReaderNodeIdCounter = 0;

  function __domReader_ensureNodeId(el) {
    var id = el.getAttribute('data-app-node-id');
    if (!id) {
      id = 'n' + __domReaderNodeIdCounter++;
      el.setAttribute('data-app-node-id', id);
    }
    return id;
  }

  // ---------------------------------------------------------------------
  // milestone09 — image + alt-text enumeration
  // ---------------------------------------------------------------------
  function __domReader_getImages() {
    var images = Array.prototype.slice
      .call(document.querySelectorAll('img'))
      .map(function (img) {
        var alt = img.getAttribute('alt');
        var hasAlt = typeof alt === 'string' && alt.trim().length > 0;
        return { src: img.src, alt: alt, hasAlt: hasAlt };
      });
    return JSON.stringify(images);
  }

  // ---------------------------------------------------------------------
  // milestone10 — search-field candidate heuristics
  // ---------------------------------------------------------------------
  var __domReaderSearchKeywords = ['search', 'tìm kiếm', 'từ khóa', 'keyword'];

  function __domReader_containsKeyword(value, keywords) {
    var lower = (value || '').toLowerCase();
    for (var i = 0; i < keywords.length; i++) {
      if (lower.indexOf(keywords[i]) !== -1) return true;
    }
    return false;
  }

  // Returns the heuristic score for a single <input> as a search-field
  // candidate, per the priority-ordered rule set in spec.md §5 /
  // milestone10. 0 means "not a candidate".
  function __domReader_scoreSearchCandidate(el) {
    var tag = el.tagName.toLowerCase();
    if (tag !== 'input') return 0;
    var type = (el.getAttribute('type') || '').toLowerCase();

    // 1. input[type="search"] -> 100
    if (type === 'search') return 100;

    // 2. role="search" on the element itself or an ancestor form/div
    //    within 2 levels -> 90
    if ((el.getAttribute('role') || '').toLowerCase() === 'search') return 90;
    var ancestor = el.parentElement;
    for (var depth = 0; ancestor && depth < 2; depth++) {
      var ancestorTag = ancestor.tagName.toLowerCase();
      if (
        (ancestorTag === 'form' || ancestorTag === 'div') &&
        (ancestor.getAttribute('role') || '').toLowerCase() === 'search'
      ) {
        return 90;
      }
      ancestor = ancestor.parentElement;
    }

    // 3. placeholder/aria-label/name containing a search keyword -> 70
    if (
      __domReader_containsKeyword(el.getAttribute('placeholder'), __domReaderSearchKeywords) ||
      __domReader_containsKeyword(el.getAttribute('aria-label'), __domReaderSearchKeywords) ||
      __domReader_containsKeyword(el.getAttribute('name'), __domReaderSearchKeywords)
    ) {
      return 70;
    }

    // 4. first input[type="text"] inside a <form> whose action/id/class
    //    contains "search" -> 50
    if (type === 'text') {
      var form = el.closest('form');
      if (form) {
        var action = (form.getAttribute('action') || '').toLowerCase();
        var id = (form.getAttribute('id') || '').toLowerCase();
        var cls = (form.getAttribute('class') || '').toLowerCase();
        if (action.indexOf('search') !== -1 || id.indexOf('search') !== -1 || cls.indexOf('search') !== -1) {
          var firstTextInput = form.querySelector('input[type="text"]');
          if (firstTextInput === el) return 50;
        }
      }
    }

    return 0;
  }

  function __domReader_getSearchCandidates() {
    var inputs = Array.prototype.slice.call(document.querySelectorAll('input'));
    var scored = inputs
      .map(function (el) {
        return { el: el, score: __domReader_scoreSearchCandidate(el) };
      })
      .filter(function (item) {
        return item.score > 0;
      });

    scored.sort(function (a, b) {
      return b.score - a.score;
    });
    scored = scored.slice(0, 5); // short candidate list, capped top 5

    var results = scored.map(function (item) {
      var el = item.el;
      return {
        elementId: __domReader_ensureNodeId(el),
        tag: el.tagName.toLowerCase(),
        type: el.getAttribute('type'),
        role: 'search',
        placeholder: el.getAttribute('placeholder'),
        ariaLabel: el.getAttribute('aria-label'),
        name: el.getAttribute('name'),
        heuristicScore: item.score,
      };
    });
    return JSON.stringify(results);
  }

  // ---------------------------------------------------------------------
  // milestone11 — submit-button candidate heuristics
  // ---------------------------------------------------------------------
  var __domReaderSubmitKeywords = ['submit', 'apply', 'nộp', 'gửi', 'ứng tuyển'];

  function __domReader_scoreSubmitCandidate(el) {
    var tag = el.tagName.toLowerCase();
    var type = (el.getAttribute('type') || '').toLowerCase();

    // 1. button[type="submit"], input[type="submit"] -> 100
    if ((tag === 'button' && type === 'submit') || (tag === 'input' && type === 'submit')) {
      return 100;
    }

    var role = (el.getAttribute('role') || '').toLowerCase();
    var text = el.textContent || '';
    var ariaLabel = el.getAttribute('aria-label') || '';

    // 2. role="button" + text/aria-label containing a submit keyword -> 90
    if (
      role === 'button' &&
      (__domReader_containsKeyword(text, __domReaderSubmitKeywords) ||
        __domReader_containsKeyword(ariaLabel, __domReaderSubmitKeywords))
    ) {
      return 90;
    }

    // 3. any clickable element (button/a/role=button) whose visible text
    //    matches the same keywords -> 70
    if (
      (tag === 'button' || tag === 'a' || role === 'button') &&
      __domReader_containsKeyword(text, __domReaderSubmitKeywords)
    ) {
      return 70;
    }

    return 0;
  }

  function __domReader_getSubmitCandidates() {
    var candidates = Array.prototype.slice.call(
      document.querySelectorAll('button, input[type="submit"], a, [role="button"]')
    );
    var scored = candidates
      .map(function (el) {
        return { el: el, score: __domReader_scoreSubmitCandidate(el) };
      })
      .filter(function (item) {
        return item.score > 0;
      });

    scored.sort(function (a, b) {
      return b.score - a.score;
    });
    scored = scored.slice(0, 3); // short candidate list, capped top 3

    var results = scored.map(function (item) {
      var el = item.el;
      return {
        elementId: __domReader_ensureNodeId(el),
        tag: el.tagName.toLowerCase(),
        type: el.getAttribute('type'),
        role: 'submit',
        placeholder: null,
        ariaLabel: el.getAttribute('aria-label'),
        name: el.getAttribute('name'),
        heuristicScore: item.score,
      };
    });
    return JSON.stringify(results);
  }

  // ---------------------------------------------------------------------
  // milestone11 — labeled form-field heuristic (general, not score-filtered)
  // ---------------------------------------------------------------------
  function __domReader_resolveLabel(el) {
    // 1. <label for="...">
    if (el.id) {
      var labelEl = null;
      try {
        labelEl = document.querySelector('label[for="' + CSS.escape(el.id) + '"]');
      } catch (e) {
        labelEl = null;
      }
      if (labelEl && labelEl.textContent && labelEl.textContent.trim()) {
        return { label: labelEl.textContent.trim(), source: 'label_for' };
      }
    }

    // 2. aria-label
    var ariaLabel = el.getAttribute('aria-label');
    if (ariaLabel && ariaLabel.trim()) {
      return { label: ariaLabel.trim(), source: 'aria_label' };
    }

    // 3. placeholder
    var placeholder = el.getAttribute('placeholder');
    if (placeholder && placeholder.trim()) {
      return { label: placeholder.trim(), source: 'placeholder' };
    }

    // 4. name
    var name = el.getAttribute('name');
    if (name && name.trim()) {
      return { label: name.trim(), source: 'name' };
    }

    // 5. nearest preceding text-node/element sibling within the same form
    var node = el.previousSibling;
    while (node) {
      if (node.nodeType === Node.TEXT_NODE && node.textContent && node.textContent.trim()) {
        return { label: node.textContent.trim(), source: 'sibling_text' };
      }
      if (node.nodeType === Node.ELEMENT_NODE && node.textContent && node.textContent.trim()) {
        return { label: node.textContent.trim(), source: 'sibling_text' };
      }
      node = node.previousSibling;
    }

    return { label: null, source: null };
  }

  function __domReader_getLabeledFields() {
    var elements = Array.prototype.slice.call(document.querySelectorAll('input, select, textarea'));
    var results = [];
    for (var i = 0; i < elements.length; i++) {
      var el = elements[i];
      // Not already claimed by the search heuristic (milestone11).
      if (__domReader_scoreSearchCandidate(el) > 0) continue;
      var resolved = __domReader_resolveLabel(el);
      results.push({
        elementId: __domReader_ensureNodeId(el),
        tag: el.tagName.toLowerCase(),
        type: el.getAttribute('type'),
        resolvedLabel: resolved.label,
        labelSource: resolved.source,
      });
    }
    return JSON.stringify(results);
  }

  // ---------------------------------------------------------------------
  // Shared: visibility check (milestone13+)
  // ---------------------------------------------------------------------
  function __domReader_isVisible(el) {
    if (!el) return false;
    if (el.offsetParent === null) return false;
    var style = window.getComputedStyle(el);
    return style.display !== 'none' && style.visibility !== 'hidden';
  }

  // ---------------------------------------------------------------------
  // milestone13 — CAPTCHA detection heuristic
  // ---------------------------------------------------------------------
  function __domReader_detectCaptcha() {
    // 1. iframe[src*="recaptcha"|"hcaptcha"], present and visible.
    var iframes = Array.prototype.slice.call(document.querySelectorAll('iframe'));
    for (var i = 0; i < iframes.length; i++) {
      var src = (iframes[i].getAttribute('src') || '').toLowerCase();
      if (!__domReader_isVisible(iframes[i])) continue;
      if (src.indexOf('recaptcha') !== -1) {
        return JSON.stringify({ detected: true, provider: 'recaptcha' });
      }
      if (src.indexOf('hcaptcha') !== -1) {
        return JSON.stringify({ detected: true, provider: 'hcaptcha' });
      }
    }

    // 2. Any visible element whose class or id contains "captcha"
    //    (case-insensitive) — deliberately permissive, see milestone13's
    //    asymmetric-cost design note.
    var all = document.querySelectorAll('[class], [id]');
    for (var j = 0; j < all.length; j++) {
      var el = all[j];
      var cls = (el.getAttribute('class') || '').toLowerCase();
      var id = (el.getAttribute('id') || '').toLowerCase();
      if ((cls.indexOf('captcha') !== -1 || id.indexOf('captcha') !== -1) && __domReader_isVisible(el)) {
        return JSON.stringify({ detected: true, provider: 'unknown' });
      }
    }

    return JSON.stringify({ detected: false, provider: null });
  }

  // ---------------------------------------------------------------------
  // milestone14 — CAPTCHA accessible audio-challenge button
  // ---------------------------------------------------------------------
  // Searches for a clickable element whose aria-label/title contains
  // "audio" — the standard reCAPTCHA/hCaptcha accessible-audio-challenge
  // affordance. Real-world limitation, stated plainly rather than hidden:
  // reCAPTCHA/hCaptcha widgets are almost always rendered inside a
  // CROSS-ORIGIN <iframe>, and same-origin policy means this top-level
  // page script cannot read that iframe's contentDocument at all — the
  // `try/catch` below exists specifically for that expected failure, not
  // as defensive paranoia. This search only succeeds for same-origin
  // audio-toggle elements (rare for real third-party CAPTCHA widgets);
  // for the common cross-origin case, this correctly (not buggily)
  // returns "not found", and checkpoint 3 falls through to the
  // narrate-and-hand-off path, which is the accessible outcome either
  // way (01-intent.md §4).
  function __domReader_findAndClickAudioChallengeButton() {
    function isAudioButton(el) {
      var ariaLabel = (el.getAttribute('aria-label') || '').toLowerCase();
      var title = (el.getAttribute('title') || '').toLowerCase();
      return ariaLabel.indexOf('audio') !== -1 || title.indexOf('audio') !== -1;
    }

    // Same-origin candidates anywhere on the top-level page.
    var candidates = document.querySelectorAll('[aria-label], [title]');
    for (var i = 0; i < candidates.length; i++) {
      if (isAudioButton(candidates[i]) && __domReader_isVisible(candidates[i])) {
        candidates[i].click();
        return JSON.stringify({ clicked: true });
      }
    }

    // Best-effort same-origin iframe peek — throws/no-ops for the
    // expected cross-origin case, per the function-level note above.
    var iframes = document.querySelectorAll('iframe[src*="recaptcha" i], iframe[src*="hcaptcha" i]');
    for (var j = 0; j < iframes.length; j++) {
      try {
        var innerDoc = iframes[j].contentDocument;
        if (!innerDoc) continue;
        var innerCandidates = innerDoc.querySelectorAll('[aria-label], [title]');
        for (var k = 0; k < innerCandidates.length; k++) {
          if (isAudioButton(innerCandidates[k])) {
            innerCandidates[k].click();
            return JSON.stringify({ clicked: true });
          }
        }
      } catch (e) {
        // Cross-origin — expected, not an error condition.
        continue;
      }
    }

    return JSON.stringify({ clicked: false });
  }

  // ---------------------------------------------------------------------
  // milestone12 — visible text extraction
  // ---------------------------------------------------------------------
  var __domReaderMaxTextLength = 8000;

  function __domReader_getVisibleText() {
    var text = (document.body && document.body.innerText) || '';
    var truncated = text.length > __domReaderMaxTextLength;
    if (truncated) text = text.substring(0, __domReaderMaxTextLength);
    return JSON.stringify({ text: text, truncated: truncated });
  }

  // ---------------------------------------------------------------------
  // milestone12 — MutationObserver wiring (perceive-act-wait-perceive)
  // ---------------------------------------------------------------------
  var __domReaderDebounceTimer = null;
  var __domReaderDebounceMs = 300;

  function __domReader_notifyDomChanged() {
    if (__domReaderDebounceTimer) clearTimeout(__domReaderDebounceTimer);
    __domReaderDebounceTimer = setTimeout(function () {
      if (window.jobAccessAssistBridge && window.jobAccessAssistBridge.postMessage) {
        window.jobAccessAssistBridge.postMessage(JSON.stringify({ type: 'dom_changed' }));
      }
    }, __domReaderDebounceMs);
  }

  function __domReader_attachMutationObserver() {
    if (typeof MutationObserver === 'undefined' || !document.body) return;
    new MutationObserver(__domReader_notifyDomChanged).observe(document.body, {
      childList: true,
      subtree: true,
      attributes: false,
    });
  }

  if (document.body) {
    __domReader_attachMutationObserver();
  } else {
    // Injected at AT_DOCUMENT_START, before <body> may exist yet.
    document.addEventListener('DOMContentLoaded', __domReader_attachMutationObserver);
  }

  // Expose on window so Dart can call these on demand via
  // evaluateJavascript (e.g. `window.__domReader_getImages()`).
  window.__domReader_getImages = __domReader_getImages;
  window.__domReader_getSearchCandidates = __domReader_getSearchCandidates;
  window.__domReader_getSubmitCandidates = __domReader_getSubmitCandidates;
  window.__domReader_getLabeledFields = __domReader_getLabeledFields;
  window.__domReader_getVisibleText = __domReader_getVisibleText;
  window.__domReader_detectCaptcha = __domReader_detectCaptcha;
  window.__domReader_findAndClickAudioChallengeButton = __domReader_findAndClickAudioChallengeButton;
})();
