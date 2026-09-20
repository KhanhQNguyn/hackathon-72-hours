# spec.md — [Product Name]

## Starter prompt

> "Based on intent.md, I need you to discuss design requirements, tech stack, and design patterns suitable for the project with me — factoring in WCAG 2.2 AA compliance from the architecture level up (semantic HTML, focus management, contrast, keyboard navigation). Generate a detailed spec.md. Whenever a new idea comes up, update the relevant section of spec.md."

## 1. Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| Frontend | _(để trống)_ | _(để trống)_ |
| Backend | _(để trống)_ | _(để trống)_ |
| Database | _(để trống)_ | _(để trống)_ |
| Deployment | _(để trống)_ | _(để trống)_ |
| Supporting tools (agent, CI, etc.) | _(để trống)_ | _(để trống)_ |

## 2. API

- API style (REST / GraphQL / other): _(để trống)_
- Naming conventions, versioning: _(để trống)_

## 3. Middleware

- Auth middleware, logging, error handling, rate limiting (if needed): _(để trống)_

## 4. Authentication

- Method (email/password, OAuth, magic link...): _(để trống)_
- **Accessibility note:** if using CAPTCHA or multi-step verification, provide an alternative that doesn't rely entirely on vision (WCAG 2.2 SC 3.3.8 Accessible Authentication)

## 5. Architecture

- Overall diagram (client/server, monolith/microservice, etc.): _(để trống)_
- Why this architecture fits a 3-day build: _(để trống)_

## 6. Domain

- Main domains/bounded contexts of the system: _(để trống)_

## 7. Design Requirements (overview — details live in design.md)

- Mandatory UI principles: minimum contrast, minimum touch target size (WCAG 2.2 SC 2.5.8 = 24×24px), support for text resize/zoom

---

> **Note:** if time is tight, schema.md and endpoints.md can be merged into an appendix within this file instead of being kept separate — see the suggestion in 03-schema.md.

## ⚠️ Cần điền khi cuộc thi bắt đầu

- [ ] Toàn bộ nội dung phụ thuộc vào intent.md đã hoàn thiện trước (đặc biệt là Core Features và Constraints).
- [ ] Quyết định team có đủ 2–3 người để giữ schema/endpoints riêng, hay gộp chung vào spec.md.
