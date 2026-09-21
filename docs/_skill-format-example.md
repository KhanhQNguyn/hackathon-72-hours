# Skill format — reference example

*(Not part of the 10-file artifact chain — this is a standalone reference for how to write a custom skill file, copied from the original planning document.)*

```
---
name: secure-api-review
description: Apply the API security standard. Use whenever creating or
  modifying an external-facing endpoint, reviewing API code, or
  generating an OpenAPI spec.
---
# Secure API review
When you create or change an API endpoint:
1. Authentication: every endpoint requires the gateway JWT;
   no anonymous routes outside /health.
2. Input validation: validate request bodies against the OpenAPI
   schema and reject unknown fields.
3. Audit: every state-changing endpoint emits an audit event with
   actor, action, entity and timestamp.
4. Data classification: fields tagged pii in the schema must never
   appear in logs or error messages.
Run scripts/check-endpoints.sh and include its output in your summary.
```

Use this format if you want to turn `10-accessibility-wcag.md` (or any other file) into an actual loadable Claude skill instead of a plain reference document.
