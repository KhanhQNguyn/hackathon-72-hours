// Injected script — locates a form field and sets its value, dispatching
// input/change events so the host page's own JS recognizes the fill.
// See spec.md §5, §6 "Form-Fill Orchestrator" (field-by-field confirm
// loop — one field at a time, not a single fill-everything pass).
// Covers milestones 15-16.
//
// Design note: `__formFiller_setValue` and `__formFiller_verifyValue`
// are deliberately two SEPARATE synchronous functions, called from Dart
// with a short delay in between (see WebViewControllerService.fillField)
// — NOT one function returning a Promise. flutter_inappwebview's
// `evaluateJavascript`, in the default content world, does not await a
// returned Promise (confirmed by reading the plugin's native Android
// source, which only wraps for promise-awaiting in a non-default
// content world); relying on that would have silently broken the
// verify-after-action step on a real device.

(function () {
  function __formFiller_valueSetterFor(el) {
    var tag = el.tagName.toLowerCase();
    var proto = window.HTMLInputElement.prototype;
    if (tag === 'textarea') proto = window.HTMLTextAreaElement.prototype;
    else if (tag === 'select') proto = window.HTMLSelectElement.prototype;
    var descriptor = Object.getOwnPropertyDescriptor(proto, 'value');
    return descriptor && descriptor.set ? descriptor.set : null;
  }

  // milestone15 — locate + set value (via the native property setter,
  // to survive React/Vue-controlled inputs) + dispatch input/change.
  function __formFiller_setValue(nodeId, value) {
    var el = document.querySelector('[data-app-node-id="' + nodeId + '"]');
    if (!el) {
      return JSON.stringify({ success: false, reason: 'node_stale' });
    }

    var setter = __formFiller_valueSetterFor(el);
    if (setter) {
      setter.call(el, value);
    } else {
      el.value = value;
    }

    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));

    return JSON.stringify({ success: true });
  }

  // milestone16 — re-read to confirm the value actually stuck. Called by
  // Dart a short delay after __formFiller_setValue, giving the host
  // page's own reactive framework a chance to re-render (spec.md §5
  // "Verify-after-action" — a JS call returning without error is not
  // proof the mutation stuck).
  function __formFiller_verifyValue(nodeId, expectedValue) {
    var el = document.querySelector('[data-app-node-id="' + nodeId + '"]');
    if (!el) {
      return JSON.stringify({ success: false, reason: 'node_stale' });
    }
    if (el.value === expectedValue) {
      return JSON.stringify({ success: true });
    }
    return JSON.stringify({ success: false, reason: 'value_did_not_stick' });
  }

  // milestone21 — CV file attachment. Browsers block scripts from
  // setting `<input type="file">`'s value directly (a real security
  // restriction, not a bug to route around) but DO allow a script to
  // call `.click()` on one, which summons the browser/WebView's own
  // native file chooser. `flutter_inappwebview`'s Android WebChromeClient
  // already handles `onShowFileChooser` internally (launches its own
  // native picker intent) with no Dart-level callback to wire — so this
  // is the entire integration point on the JS side.
  function __formFiller_clickFileInput(nodeId) {
    var el = document.querySelector('[data-app-node-id="' + nodeId + '"]');
    if (!el) return JSON.stringify({ success: false, reason: 'node_stale' });
    if (el.tagName.toLowerCase() !== 'input' || el.type !== 'file') {
      return JSON.stringify({ success: false, reason: 'not_a_file_input' });
    }
    el.click();
    return JSON.stringify({ success: true });
  }

  window.__formFiller_setValue = __formFiller_setValue;
  window.__formFiller_verifyValue = __formFiller_verifyValue;
  window.__formFiller_clickFileInput = __formFiller_clickFileInput;
})();
