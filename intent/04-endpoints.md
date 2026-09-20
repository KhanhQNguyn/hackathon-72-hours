# endpoints.md — [Product Name]

## Starter prompt

> "Based on spec.md and schema.md, plan in detail and generate an endpoints.md file summarizing all API endpoints for the project, organized by schema/model. Whenever an idea changes, update the relevant section of endpoints.md."

## [ModelName1]

| Method | Path | Description | Auth required | Request body | Response |
|---|---|---|---|---|---|
| GET | /api/[resource] | _(để trống)_ | _(để trống)_ | _(để trống)_ | _(để trống)_ |
| POST | /api/[resource] | _(để trống)_ | _(để trống)_ | _(để trống)_ | _(để trống)_ |
| PATCH | /api/[resource]/:id | _(để trống)_ | _(để trống)_ | _(để trống)_ | _(để trống)_ |
| DELETE | /api/[resource]/:id | _(để trống)_ | _(để trống)_ | _(để trống)_ | _(để trống)_ |

## [ModelName2]

| Method | Path | Description | Auth required | Request body | Response |
|---|---|---|---|---|---|
| _(để trống)_ | _(để trống)_ | _(để trống)_ | _(để trống)_ | _(để trống)_ | _(để trống)_ |

## Common error format

```json
{ "error": { "code": "", "message": "" } }
```

## Notes

- Mark endpoints that must be done before Day 2 (to demo for user research) with 🔴 high priority

## ⚠️ Cần điền khi cuộc thi bắt đầu

- [ ] Phụ thuộc vào schema.md đã có model cụ thể.
- [ ] Xác định endpoint nào cần xong trước buổi Fireside chat / mentoring Day 2 (9:00–11:45) để demo.
